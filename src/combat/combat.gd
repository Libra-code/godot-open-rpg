## The Combat class manages combat logic from beginning to end.
##
## The battle is composed from several components which should all be wrapped up in a [CombatArena].
## The Combat class instantiates the arena as a child before instantiating the player battlers and
## assigning them as descendants of the arena's [BattlerRoster].[br][br]
##
## The combat logic follows the pattern set by early JRPGs, where each combat round includes two
## phases:
## [br]	1) Action selection: each Battler selects an action, AI battlers followed by the player.
## [br]	2) Action execution: the Battlers carry out their selected actions.[br][br]
## If the player and enemy sides are both still alive, combat procedes to the next round. Combat
## logic may be illustrated as follows:[br][br]
## [method setup] combat with a [CombatArena] (usually triggered by
## [signal FieldEvents.combat_triggered]).
## [br]	- Begin new combat round
## [br]		- AI Battlers select their actions.
## [br]		- Until all player Battlers have a [member Battler.cached_action]:
## [br]			- The next player Battler selects their action via the [UICombat].
## [br]			- If all player Battlers have a [member Battler.cached_action], move to action
## execution.
## [br][br]		- For each Battler with a cached action (sorted by speed):
## [br]			- [method Battler.act]
## [br]		- If player and enemy Battlers are still alive, go to the next round.[br]
## [method shutdown] combat, cleaning up combat objects
## [br]	- Emit the [signal CombatEvents.combat_finished] signal.
class_name Combat extends CanvasLayer

## Tracks which combat round is currently being played. Every round, all active [Battler]s will get
## a turn to act.
var round_count: int = 0

# Keep track of what music track was playing previously, and return to it once combat has finished.
var _previous_music_track: AudioStream = null

# Battler name -> new level, for any player Battler that leveled up this battle. Populated by
# _award_victory_xp() and consumed by _get_victory_message_events().
var _level_ups_this_battle: = {}

# Item rows (from ItemDatabase.get_item()) granted this battle. Populated by _roll_enemy_loot()
# and consumed by _get_victory_message_events().
var _loot_this_battle: Array[Dictionary] = []

# A reference to 
@onready var _battler_roster: BattlerRoster
@onready var _combat_container: = $CenterContainer as CenterContainer
@onready var _transition_delay_timer: = $UI/TransitionDelay as Timer
@onready var _ui: = $UI as UICombat


func _ready() -> void:
	hide()
	FieldEvents.combat_triggered.connect(setup)


## Begin a combat. Takes a PackedScene as its only parameter, expecting it to be a CombatState
## object once instantiated. [param biome], if given, rescales every enemy Battler's stats to the
## party's current level (see [SpawnDirector]) in place, after each Battler has already wired up
## its own signals — never by replacing the stats object itself (see
## [method SpawnDirector.apply_scaling] for why that would break defeat detection).
## This is normally a response to [signal FieldEvents.combat_triggered].
func setup(arena: PackedScene, biome: BiomeDefinition = null) -> void:
	await Transition.cover(0.2)
	show()

	var new_arena := arena.instantiate()
	assert(
		new_arena != null,
		"Failed to initiate combat. Provided 'arena' arugment is not a CombatArena."
	)

	var combat_arena: CombatArena = new_arena
	_combat_container.add_child(combat_arena)
	_battler_roster = combat_arena.get_battler_roster()

	if biome:
		var party_level: = SpawnDirector.get_party_level()
		for enemy in _battler_roster.get_enemy_battlers():
			SpawnDirector.apply_scaling(enemy.stats, biome, party_level)

	# Wait a frame for the arena and its children (VFX, Battlers, etc.) to be ready.
	await get_tree().process_frame
	
	_ui.setup(_battler_roster)

	_previous_music_track = Music.get_playing_track()
	Music.play(combat_arena.music)

	CombatEvents.combat_initiated.emit()

	# Before starting combat itself, reveal the screen again.
	# The Transition.clear() call is deferred since it follows on the heels of cover(), and needs a
	# frame to allow everything else to respond to Transition.finished.
	Transition.clear.call_deferred(0.2)
	await Transition.finished
	
	# Fade in the combat UI elements.
	_ui.animation.play("fade_in")
	await _ui.animation.animation_finished
	
	# Begin the combat logic. The turn queue takes over from here.
	round_count = 0
	next_round.call_deferred()


# Moves combat to the next round. At the beginning of the round, all Battlers will choose an action.
func next_round() -> void:
	round_count += 1

	# Status effects (poison, stun, timed buffs/debuffs) tick down once per round, for every living
	# Battler, before anyone selects an action - a Battler's own status effects should always
	# resolve at the start of their round, whether or not they're the one acting.
	for battler in _battler_roster.find_live_battlers(_battler_roster.get_battlers()):
		battler.tick_status_effects()

	# Damage-over-time effects may have just ended the battle on their own; check before starting
	# another round of action selection.
	if _battler_roster.are_battlers_defeated(_battler_roster.get_player_battlers()):
		_on_combat_finished.call_deferred(false)
		return
	elif _battler_roster.are_battlers_defeated(_battler_roster.get_enemy_battlers()):
		_on_combat_finished.call_deferred(true)
		return

	# Stunned Battlers skip the action selection below entirely: they're auto-assigned a no-op
	# action so the turn queue can process their turn (and thus their next status effect tick)
	# without asking the player or their AI to choose something they won't get to perform.
	for battler in _battler_roster.find_live_battlers(_battler_roster.get_battlers()):
		if battler.is_stunned():
			battler.cached_action = battler.get_stunned_action()

	# First of all, let enemy (necessarily AI) battlers pick their actions.
	for battler in _battler_roster.find_live_battlers(_battler_roster.get_enemy_battlers()):
		if battler.ai != null and battler.cached_action == null:
			battler.ai.select_action(battler)

	# Secondly, allow player Battlers to pick their action.
	# This will be iterative as the player selects and cancels their choices. The turn queue will
	# move to the action phase once all player Battlers have an action selected.
	_select_next_player_action()


# Player Battlers select their actions by repeatedly calling _select_next_player_action. The method
# looks for player Battlers who have no cached action and prioritizes those further up in the scene
# tree. This allows the player to go "backwards" and "forwards" between Battlers, choosing actions
# and cancelling them as needed.
# At this point, all AI Battlers should have a cached actoin.
# Once all Battlers have an action cached (see Battler.cached_action), _select_next_player_action
# calls _next_turn to move into the second phase.
func _select_next_player_action() -> void:
	# Find any remaining player Battlers that need an action selected.
	var player_battlers: = _battler_roster.get_player_battlers()
	var remaining_battlers: = _battler_roster.find_battlers_needing_actions(player_battlers)
	
	# If there are no player Battlers needing actions, move on to the second phase of a round:
	# taking action!
	if remaining_battlers.is_empty():
		# De-select the last Battler that was receiving orders.
		CombatEvents.player_battler_selected.emit(null)
		_play_next_action.call_deferred()
		return
	
	# If there are player Battlers needing cached actions, pick the first one and allow it to search
	# for an action using either its AI controller (if present) or player input.
	var next_player_battler: Battler = remaining_battlers.front()
	
	# When the player selects an action (or presses 'back'), the current Battler needs to move back
	# to its rest position before moving on to the next battler, hence the await call below.
	next_player_battler.action_cached.connect(
		(func _on_selected_battler_action_cached(battler: Battler) -> void:
			# Check to see if the player cancelled action selection (pressed "back" from the
			# UIActionMenu). If so, the player wishes to reissue orders for the previous Battler.
			# If there IS a previous Battler, remove its cached action. Stunned Battlers are
			# skipped when looking backwards: they were never offered a real choice for this
			# round (see Combat.next_round), so "going back" to one would just reassign the same
			# auto-resolved no-op action right back to it.
			if battler.cached_action == null:
				var battlers: = _battler_roster.get_player_battlers()
				var previous_index: = battlers.find(battler) - 1
				while previous_index >= 0 and battlers[previous_index].is_stunned():
					previous_index -= 1
				if previous_index >= 0:
					var previous_battler: Battler = battlers[previous_index]
					previous_battler.cached_action = null
			
			await battler.anim.move_to_rest(0.15)
			_select_next_player_action()
			).bind(next_player_battler), 
		CONNECT_DEFERRED | CONNECT_ONE_SHOT)
	
	await next_player_battler.anim.move_forward(0.15)
	
	# Activate the player UI elements for the currently selected battler.
	CombatEvents.player_battler_selected.emit(next_player_battler)


# The second phase of combat has each Battler act in order of speed. This is done by repeatedly
# calling _next_turn until no active Battlers have a cached action waiting to be executed.
func _play_next_action() -> void:
	# Check for battle end conditions, that one side has been downed.
	if _battler_roster.are_battlers_defeated(_battler_roster.get_player_battlers()):
		_on_combat_finished.call_deferred(false)
		return
	elif _battler_roster.are_battlers_defeated(_battler_roster.get_enemy_battlers()):
		_on_combat_finished.call_deferred(true)
		return

	# Check for an active Battler. If neither side has lost yet there are no active actors, it's
	# time to start the next round.
	var next_actor: = _get_next_actor()
	if next_actor == null:
		next_round()
		return
	
	# Connect to the actor's turn_finished signal. The actor is guaranteed to emit the signal,
	# even if it will be freed at the end of this frame.
	# However, we'll call_defer the next turn, since the current actor may have been downed on its
	# turn and we need a frame to process the change.
	next_actor.turn_finished.connect(_play_next_action, CONNECT_DEFERRED | CONNECT_ONE_SHOT)
	next_actor.act()


func _get_next_actor() -> Battler:
	var battlers: = _battler_roster.get_battlers()
	var ready_to_act_battlers: = _battler_roster.find_ready_to_act_battlers(battlers)
	if ready_to_act_battlers.is_empty():
		return null
	
	ready_to_act_battlers.sort_custom(Battler.sort)
	return ready_to_act_battlers.front()


func _on_combat_finished(is_player_victory: bool) -> void:
	if is_player_victory:
		_award_victory_xp()
	else:
		# A lost battle is the one moment the field layer can't already cover: failing to protect
		# the party is the closest thing to "breaking your oath" that currently exists in-game (see
		# the "oathbound" flaw in soul_strain_engine.gd, and the Wizard/pedestal story beat that can
		# assign it). Harmless no-op if the player's Core hasn't been awakened with that flaw yet.
		SoulStrain.resolve_turn(&"oath_broken")

	# Fade out the combat UI elements.
	_ui.animation.play("fade_out")
	await _ui.animation.animation_finished
	await _display_combat_results_dialog(is_player_victory)

	_battler_roster = null
	
	# Wait a short period of time and then fade the screen to black.
	_transition_delay_timer.start()
	await _transition_delay_timer.timeout
	await Transition.cover(0.2)
	hide()
	
	# Clean up the combat arena.
	for child in _combat_container.get_children():
		child.free()

	Music.play(_previous_music_track)
	_previous_music_track = null

	# Whatever object started the combat will now be responsible for flow of the game. In
	# particular, the screen is still covered, so the combat-starting object will want to 
	# decide what to do now that the outcome of the combat is known.
	CombatEvents.combat_finished.emit(is_player_victory)


# Grants xp (summed from the defeated enemies' xp_reward) to every surviving player Battler.
# Records any level-ups in _level_ups_this_battle so the results dialogue can mention them.
func _award_victory_xp() -> void:
	var total_xp: int = 0
	_loot_this_battle.clear()

	for enemy in _battler_roster.get_enemy_battlers():
		total_xp += enemy.stats.xp_reward
		_roll_enemy_loot(enemy.stats.enemy_id)

	_level_ups_this_battle.clear()
	for battler in _battler_roster.get_player_battlers():
		var levels_gained: = battler.stats.add_xp(total_xp)
		if levels_gained > 0:
			_level_ups_this_battle[battler.name] = battler.stats.level

		# The Battler (and its BattlerStats duplicate) is freed once combat wraps up; persist the
		# level/xp it ended up with or the next battle would start back at level 1.
		PartyLoadouts.get_loadout(battler.name).capture_progress(battler.stats)


# Looks up enemy_id in ItemDatabase for its loot_table_id (see database/schema_enemies_quests.sql)
# and rolls it once. "equipment" drops are auto-equipped onto the party leader immediately (there
# is no ownership/equip-choice UI for equipment yet — see FUNZIONALITA.md). Every other item type
# (consumable, material, ...) is granted into Inventory by database id via Inventory.add_item(),
# the same generic storage the shop uses to sell/buy them.
func _roll_enemy_loot(enemy_id: StringName) -> void:
	if enemy_id == &"":
		return

	var enemy_row: = ItemDatabase.get_enemy(enemy_id)
	# loot_table_id is a nullable TEXT column: an enemy with no loot table at all reads back as
	# GDScript null here, not an empty string, so that has to be ruled out before the String cast.
	var raw_loot_table_id: Variant = enemy_row.get("loot_table_id")
	if raw_loot_table_id == null:
		return

	var loot_table_id: String = raw_loot_table_id
	if loot_table_id.is_empty():
		return

	var inventory: Inventory = Inventory.restore()

	for drop: Dictionary in ItemDatabase.roll_loot_table(loot_table_id, 1):
		var item_row: = ItemDatabase.get_item(drop.item_id)
		if item_row.is_empty():
			continue

		var quantity: int = drop.get("quantity", 1)
		_loot_this_battle.append({"item_row": item_row, "quantity": quantity})

		if item_row.get("item_type") == "equipment":
			var party_leader_name: = _battler_roster.get_player_battlers()[0].name
			PartyLoadouts.equip(party_leader_name, PartyLoadouts.get_item_by_id(drop.item_id))
		else:
			inventory.add_item(drop.item_id, quantity)

	if not _loot_this_battle.is_empty():
		inventory.save()


## Displays a series of dialogue bubbles using Dialogic with information about the combat's outcome.
func _display_combat_results_dialog(is_player_victory: bool):
	var player_party_leader_name: = _battler_roster.get_player_battlers()[0].name

	var timeline_events: Array[String]
	if is_player_victory:
		timeline_events = _get_victory_message_events(player_party_leader_name)
	else:
		timeline_events = _get_loss_message_events(player_party_leader_name)

	var combat_rewards_timeline: DialogicTimeline = DialogicTimeline.new()
	combat_rewards_timeline.events = timeline_events
	Dialogic.start_timeline(combat_rewards_timeline)
	await Dialogic.timeline_ended


# These two functions are placeholders for future logic for deciding combat outcomes.
func _get_victory_message_events(leader_name: String) -> Array[String]:
	var events: Array[String] = [
		"%s's party won the battle!" % leader_name
	]

	for battler_name in _level_ups_this_battle:
		events.append("%s reached level %d!" % [battler_name, _level_ups_this_battle[battler_name]])

	for loot in _loot_this_battle:
		var item_row: Dictionary = loot.item_row
		var display_name: String = item_row.get("display_name", item_row.get("id"))
		var quantity: int = loot.quantity
		if quantity > 1:
			events.append("Found: %s x%d!" % [display_name, quantity])
		else:
			events.append("Found: %s!" % display_name)

	return events
	

func _get_loss_message_events(leader_name: String) -> Array[String]:
	var events: Array[String] = [
		"%s's party lost the battle!" % leader_name
	]
	return events
