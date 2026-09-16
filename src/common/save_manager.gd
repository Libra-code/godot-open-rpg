## Saves and restores overall game progress.
##
## Autoloaded as "SaveGame". Delegates dialogue/quest variables and timeline state to Dialogic's
## own save system (which already handles that robustly), and stores everything else (player
## position, Soul Strain state) as a custom file inside that same save slot. The inventory has its
## own persistence (see [Inventory]) and is just told to write itself out alongside everything
## else.
extends Node

const SLOT_NAME: = "game"
const STATE_FILE: = "game_state"


func has_save() -> bool:
	return Dialogic.Save.has_slot(SLOT_NAME)


func save_game() -> void:
	Inventory.restore().save()
	Dialogic.Save.save(SLOT_NAME)
	Dialogic.Save.save_file(SLOT_NAME, STATE_FILE, _build_state_dict())


func load_game() -> void:
	if not has_save():
		return

	Dialogic.Save.load(SLOT_NAME)
	_apply_state_dict(Dialogic.Save.load_file(SLOT_NAME, STATE_FILE, {}))

	# Quest completion is derived from the Dialogic variables just restored above; reconcile
	# QuestLog's cached state immediately instead of waiting for the next timeline to end.
	QuestLog.refresh_all()


func _build_state_dict() -> Dictionary:
	var data: = {}

	if Player.gamepiece:
		data["player_position"] = [Player.gamepiece.position.x, Player.gamepiece.position.y]

	var soul_strain: Node = get_tree().get_first_node_in_group(&"soul_strain_engine")
	if soul_strain:
		var state: SoulStrainState = soul_strain.state

		var equipped_abilities: = []
		for ability_id in state.equipped_abilities:
			equipped_abilities.append(String(ability_id))

		var assimilated_essences: = []
		for essence_id in state.assimilated_essences:
			assimilated_essences.append(String(essence_id))

		data["soul_strain"] = {
			"character_name": state.character_name,
			"aspect": state.aspect,
			"flaw_id": String(state.flaw_id),
			"flaw_display_name": state.flaw_display_name,
			"core_grade": String(state.core_grade),
			"max_hit_points": state.max_hit_points,
			"hit_points": state.hit_points,
			"max_mana": state.max_mana,
			"soul_rejection": state.soul_rejection,
			"soul_fragments": state.soul_fragments,
			"stats": state.stats.duplicate(),
			"equipped_abilities": equipped_abilities,
			"debuffs": state.debuffs.duplicate(true),
			"assimilated_essences": assimilated_essences,
		}

	data["party_loadouts"] = PartyLoadouts.to_save_dict()

	return data


func _apply_state_dict(data: Dictionary) -> void:
	if Player.gamepiece and data.has("player_position"):
		var pos: Array = data["player_position"]
		Player.gamepiece.position = Vector2(pos[0], pos[1])

	var soul_strain: Node = get_tree().get_first_node_in_group(&"soul_strain_engine")
	if soul_strain and data.has("soul_strain"):
		var saved: Dictionary = data["soul_strain"]
		var state: SoulStrainState = soul_strain.state
		state.character_name = saved.get("character_name", state.character_name)
		state.aspect = saved.get("aspect", state.aspect)
		state.flaw_id = saved.get("flaw_id", state.flaw_id)
		state.flaw_display_name = saved.get("flaw_display_name", state.flaw_display_name)
		state.core_grade = saved.get("core_grade", state.core_grade)
		state.max_hit_points = saved.get("max_hit_points", state.max_hit_points)
		state.hit_points = saved.get("hit_points", state.hit_points)
		state.max_mana = saved.get("max_mana", state.max_mana)
		state.soul_rejection = saved.get("soul_rejection", state.soul_rejection)
		state.soul_fragments = saved.get("soul_fragments", state.soul_fragments)
		state.stats = saved.get("stats", state.stats)
		state.equipped_abilities.assign(saved.get("equipped_abilities", state.equipped_abilities))
		state.debuffs = saved.get("debuffs", state.debuffs)
		state.assimilated_essences.assign(
			saved.get("assimilated_essences", state.assimilated_essences)
		)
		soul_strain.state_changed.emit(state)

	if data.has("party_loadouts"):
		PartyLoadouts.load_from_dict(data["party_loadouts"], PartyLoadouts.get_item_by_id)
