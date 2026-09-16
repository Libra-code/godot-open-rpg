## A playable combatant that carries out [BattlerActions] as its [member readiness] charges.
##
## Battlers are the playable characters or enemies that show up in battle. They have [BattlerStats],
## a list of [BattlerAction]s to choose from, and respond to a variety of stimuli such as status
## effects and [BattlerHit]s, which typically deal damage or heal the Battler.
##
## [br][br]Battlers have [BattlerAnim]ation children which play out the Battler's actions.
@tool
class_name Battler extends Node2D

## Emitted whenever the Battler caches a valid action.
signal action_cached
## Emitted whenever the Battler's turn is finished. Thos should emit only after all actions and 
## animations are complete.
signal turn_finished
## Forwarded from the receiving of [signal BettlerStats.health_depleted].
signal health_depleted
## Emitted when taking damage or being healed from a [BattlerHit].
## [br][br]Note the difference between this and [signal BattlerStats.health_changed]:
## 'hit_received' is always the direct result of an action, requiring graphical feedback.
signal hit_received(value: int)
## Emitted whenever a hit targeting this battler misses.
signal hit_missed
## Emitted when modifying `is_selected`. The user interface will react to this for
## player-controlled battlers.
signal selection_toggled(value: bool)
## Emitted when a [StatusEffect] (poison, stun, a timed buff/debuff, etc.) is applied or refreshed.
signal status_effect_applied(effect: StatusEffect)
## Emitted when a [StatusEffect]'s duration runs out and its stat changes are removed.
signal status_effect_expired(effect: StatusEffect)
## Emitted each round a [StatusEffect] deals its damage-over-time (see
## [member StatusEffect.damage_per_round]).
signal status_effect_ticked(effect: StatusEffect, amount: int)

## The name of the node group that will contain all combat Battlers.
const GROUP: = "_COMBAT_BATTLER_GROUP"

## A Battler must have [BattlerStats] to act and receive actions.
@export var stats: BattlerStats = null
## Each action's data stored in this array represents an action the battler can perform.
## These can be anything: attacks, healing spells, etc.

@export var actions: Array[BattlerAction]

## Each Battler is shown on the screen by a [BattlerAnim] object. The object is created dynamically
## from a PackedScene, which must yield a [BattlerAnim] object when instantiated.
@export var battler_anim_scene: PackedScene:
	set(value):
		battler_anim_scene = value

		if not is_inside_tree():
			await ready

		# Free an already existing BattlerAnim.
		if anim:
			anim.queue_free()
			anim = null

		# Add the new BattlerAnim class as a child and link it to this Battler instance.
		if battler_anim_scene:
			# Normally we could wrap a check for battler_anim_scene's type (should be BattlerAnim)
			# in a call to assert, but we want the following code to run in the editor and clean up
			# dynamically if the user drops an incorrect PackedScene (i.e. not a BattlerAnim) into
			# the battler_anim_scene slot.
			var new_scene: = battler_anim_scene.instantiate()
			anim = new_scene as BattlerAnim
			if not anim:
				push_warning("Battler '%s' cannot accept '%s' as " % [name, new_scene.name],
					"battler_anim_scene. '%s' is not a BattlerAnim!" % new_scene.name)
				new_scene.free()
				battler_anim_scene = null
				return

			add_child(anim)
			var facing: = BattlerAnim.Direction.LEFT if is_player else BattlerAnim.Direction.RIGHT
			anim.setup(self, facing)

## A CombatAI object that will determine the Battler's combat behaviour.
## If the battler has an `ai_scene`, we will instantiate it and let the AI make decisions.
## If not, the player controls this battler. The system should allow for ally AIs.
@export var ai_scene: PackedScene:
	set(value):
		ai_scene = value

		if ai_scene != null:
			# In the editor, check to make sure that the value set to ai_scene is actually a
			# CombatAI bject.
			var new_instance: = ai_scene.instantiate()
			if Engine.is_editor_hint():
				if new_instance is not CombatAI:
					printerr("Cannot assign '%s' to Battler '%s'" % [new_instance.name, self.name] +
						" as ai_scene property. Assigned PackedScene is not a CombatAI type!")
					ai_scene = null
				new_instance.free()

			else:
				ai = new_instance
				add_child(ai)

## If this is [b]true[/b], this actor is controlled by the player. Use this to
## differentiate between player-controlled actors and AI-controlled ones.
## [/n][/n] Note that player Battlers may be controlled by an AI controller, but enemy Battlers may
## not be controlled by the player.
@export var is_player: = false:
	set(value):
		is_player = value
		if anim:
			var facing: = BattlerAnim.Direction.LEFT if is_player else BattlerAnim.Direction.RIGHT
			anim.direction = facing

## Reference to this Battler's child [CombatAI] node, if applicable.
var ai: CombatAI = null

## Reference to this Battler's child [BattlerAnim] node.
var anim: BattlerAnim = null

## If this is [b]true[/b], this Battler can take turns.
var is_active: bool = true:
	set(value):
		is_active = value

		set_process(is_active)

## If `true`, the battler is selected, which makes it move forward.
var is_selected: bool = false:
	set(value):
		if value:
			assert(is_selectable)

		is_selected = value
		selection_toggled.emit(is_selected)

## If `false`, the battler cannot be targeted by any action.
var is_selectable: bool = true:
	set(value):
		is_selectable = value
		if not is_selectable:
			is_selected = false

## Combat happens in two phases. In the first phase each Battler - player and enemy - select an
## action. In the second phase that action is carried out.
## When selecting actions, a Battler caches it in the following memeber. The cached action is set
## to null after execution.
var cached_action: BattlerAction = null:
	set(value):
		cached_action = value
		action_cached.emit()

# Active status effects, keyed by StatusEffect.id. Each entry is a Dictionary:
# {effect: StatusEffect, remaining_rounds: int, modifier_ids: Dictionary, multiplier_ids: Dictionary}
var _active_status_effects: = {}


static func sort(a: Battler, b: Battler) -> bool:
	return a.stats.speed > b.stats.speed


func _ready() -> void:
	if not Engine.is_editor_hint():
		assert(stats, "Battler %s does not have stats assigned!" % name)

		add_to_group(GROUP)

		# Resources are NOT unique, so treat the currently assigned BattlerStats as a prototype.
		# That is, copy what it is now and use the copy, so that the original remains unaltered.
		stats = stats.duplicate()
		if is_player:
			PartyLoadouts.apply_to(self)
		stats.initialize()
		stats.health_depleted.connect(func on_stats_health_depleted() -> void:
			is_active = false
			is_selectable = false
			health_depleted.emit()
		)
		
		# Similarly, duplicate all actions since some may be shared across multiple Battlers and
		# each needs to point to the action source (i.e. this Battler).
		var battler_roster: = _get_roster()
		assert(battler_roster != null, "%s is not a descendent of the BattlerRoster!" % name)
		
		var duplicate_actions: Array[BattlerAction] = []
		for battler_action in actions:
			var duplicate_action: = battler_action.duplicate()
			duplicate_action.source = self
			duplicate_action.battler_roster = battler_roster
			duplicate_actions.append(duplicate_action)
		actions = duplicate_actions


## [method BattlerAction.execute] the Battler's [member cached_action].
func act() -> void:
	if cached_action:
		stats.energy -= cached_action.energy_cost

		# cached_action.execute() is almost certainly is a coroutine.
		@warning_ignore("redundant_await")
		await cached_action.execute()
	
	# Flag that the Battler has acted by resetting the cached action.
	cached_action = null
	turn_finished.emit.call_deferred()


func take_hit(hit: BattlerHit) -> void:
	if hit.is_successful():
		hit_received.emit(hit.damage)
		stats.health -= hit.damage
	else:
		hit_missed.emit()


## Applies [param effect] to this Battler for [member StatusEffect.duration_rounds] of its own
## rounds. Re-applying an effect with the same [member StatusEffect.id] while already active
## refreshes its duration instead of stacking a second, independent copy.
func apply_status_effect(effect: StatusEffect) -> void:
	if _active_status_effects.has(effect.id):
		_remove_status_effect(effect.id)

	var modifier_ids: = {}
	for stat_name in effect.stat_modifiers:
		modifier_ids[stat_name] = stats.add_modifier(stat_name, effect.stat_modifiers[stat_name])

	var multiplier_ids: = {}
	for stat_name in effect.stat_multipliers:
		multiplier_ids[stat_name] = stats.add_multiplier(stat_name, effect.stat_multipliers[stat_name])

	_active_status_effects[effect.id] = {
		"effect": effect,
		"remaining_rounds": effect.duration_rounds,
		"modifier_ids": modifier_ids,
		"multiplier_ids": multiplier_ids,
	}
	status_effect_applied.emit(effect)


## True if any active status effect prevents this Battler from acting (see
## [member StatusEffect.prevents_action]). Used by [method Combat.next_round] to auto-skip the
## Battler's turn instead of letting the player or AI select a real action for it.
func is_stunned() -> bool:
	for entry: Dictionary in _active_status_effects.values():
		if (entry.effect as StatusEffect).prevents_action:
			return true
	return false


## Applies damage-over-time and counts down every active status effect by one round, removing (and
## cleaning up the stat changes of) any that expire. Called once per round for every living Battler,
## from [method Combat.next_round], before actions are selected.
func tick_status_effects() -> void:
	if not is_active:
		return

	for status_id: StringName in _active_status_effects.keys().duplicate():
		var entry: Dictionary = _active_status_effects[status_id]
		var effect: StatusEffect = entry.effect

		if effect.damage_per_round != 0:
			stats.health -= effect.damage_per_round
			status_effect_ticked.emit(effect, effect.damage_per_round)

		entry.remaining_rounds -= 1
		if entry.remaining_rounds <= 0:
			_remove_status_effect(status_id)


func _remove_status_effect(status_id: StringName) -> void:
	var entry: Dictionary = _active_status_effects[status_id]
	var effect: StatusEffect = entry.effect

	for stat_name: String in entry.modifier_ids:
		stats.remove_modifier(stat_name, entry.modifier_ids[stat_name])
	for stat_name: String in entry.multiplier_ids:
		stats.remove_multiplier(stat_name, entry.multiplier_ids[stat_name])

	_active_status_effects.erase(status_id)
	status_effect_expired.emit(effect)


## Returns a fresh no-op [BattlerAction] used to auto-resolve this Battler's turn while stunned
## (see [method is_stunned]), wired up the same way [method _ready] wires up [member actions].
func get_stunned_action() -> BattlerAction:
	var action: = StunnedBattlerAction.new()
	action.source = self
	action.battler_roster = _get_roster()
	return action


# Iteratively search this node's parents for the BattlerRoster. Battler's must be descendants of the
# BattlerRoster. Used to setup this Battler's BattlerActions.
func _get_roster() -> BattlerRoster:
	var parent: = get_parent()
	while parent != null:
		if parent is BattlerRoster:
			return parent as BattlerRoster
		parent = parent.get_parent()
	return null


func _to_string() -> String:
	var msg: = "%s (Battler)" % name
	if not is_active:
		msg += " - INACTIVE"
	elif cached_action == null:
		msg += " - HAS ACTED"
	return msg
