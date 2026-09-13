extends Node

signal state_changed(state: SoulStrainState)
signal turn_resolved(summary: Dictionary)
signal essence_assimilated(result: Dictionary)
signal flaw_triggered(result: Dictionary)

const LOW_COMPATIBILITY_THRESHOLD: float = 0.45
const REJECTION_DEBUFF_STEP: float = 25.0

var state: SoulStrainState = SoulStrainState.new()


func _ready() -> void:
	state_changed.emit(state)
	turn_resolved.emit(state.get_summary())


func setup(new_state: SoulStrainState) -> void:
	assert(new_state, "SoulStrain.setup requires a valid SoulStrainState.")
	state = new_state
	_enforce_ability_slots()
	_emit_state()


func resolve_turn(action: StringName = &"turn") -> Dictionary:
	var flaw_result: Dictionary = record_action(action)
	var summary: Dictionary = state.get_summary()
	summary["flaw_result"] = flaw_result
	turn_resolved.emit(summary)
	return summary


func spend_soul_fragments(stat_name: String, amount: int = 1, cost_per_point: int = 1) -> bool:
	if amount <= 0 or cost_per_point <= 0:
		return false
	if not state.stats.has(stat_name):
		push_warning("Unknown Soul Strain stat: %s" % stat_name)
		return false

	var total_cost: int = amount * cost_per_point
	if state.soul_fragments < total_cost:
		return false

	state.soul_fragments -= total_cost
	state.stats[stat_name] = int(state.stats[stat_name]) + amount
	_emit_state()
	return true


func set_core_grade(core_grade: StringName) -> void:
	state.core_grade = core_grade
	_enforce_ability_slots()
	_emit_state()


func equip_ability(ability_id: StringName) -> bool:
	if state.equipped_abilities.has(ability_id):
		return true
	if state.equipped_abilities.size() >= state.get_skill_slot_count():
		return false

	state.equipped_abilities.append(ability_id)
	_emit_state()
	return true


func summon_memory(memory: SoulStrainMemory) -> bool:
	if not memory:
		return false
	if state.active_memories.has(memory):
		return true
	if state.get_available_mana() < memory.mana_reserved:
		return false

	state.active_memories.append(memory)
	_emit_state()
	return true


func dismiss_memory(memory: SoulStrainMemory) -> void:
	state.active_memories.erase(memory)
	_emit_state()


func assimilate_essence(essence: SoulStrainEssence) -> Dictionary:
	assert(essence, "SoulStrain.assimilate_essence requires a valid SoulStrainEssence.")

	var compatibility: float = get_essence_compatibility(essence)
	var rejection_added: float = 0.0
	var debuffs_applied: Dictionary = {}

	if compatibility < LOW_COMPATIBILITY_THRESHOLD:
		rejection_added = essence.rejection_on_low_compatibility * (1.0 - compatibility)
		_add_rejection(rejection_added)
		debuffs_applied = _apply_rejection_debuffs()
	else:
		state.soul_fragments += max(0, essence.soul_fragments)
		if essence.id != &"":
			state.assimilated_essences.append(essence.id)

	var result: Dictionary = {
		"essence": essence,
		"compatibility": compatibility,
		"rejection_added": rejection_added,
		"debuffs_applied": debuffs_applied,
		"summary": state.get_summary(),
	}
	essence_assimilated.emit(result)
	_emit_state()
	return result


func get_essence_compatibility(essence: SoulStrainEssence) -> float:
	if essence.aspect_tags.is_empty() or state.aspect_tags.is_empty():
		return clampf(essence.base_compatibility, 0.0, 1.0)

	var matches: int = 0
	for tag in essence.aspect_tags:
		if state.aspect_tags.has(tag):
			matches += 1

	var tag_score: float = float(matches) / float(essence.aspect_tags.size())
	return clampf((essence.base_compatibility + tag_score) * 0.5, 0.0, 1.0)


func record_action(action: StringName, context: Dictionary = {}) -> Dictionary:
	match state.flaw_id:
		&"blood_price":
			if action == &"ability_used":
				return _trigger_flaw("Prezzo di Sangue", {"hit_points": -max(1, int(context.get("hp_loss", 4)))})
		&"stillness_curse":
			if action == &"turn" or action == &"wait":
				return _trigger_flaw("Maledizione dell'Immobilita", {"soul_rejection": 5.0})
		&"cowardice":
			if action == &"retreat":
				return _trigger_flaw("Codardia Incisa", {"volonta": -1, "soul_rejection": 8.0})
		&"oathbound":
			if action == &"oath_broken":
				return _trigger_flaw("Giuramento Spezzato", {"hit_points": -12, "soul_rejection": 12.0})

	return {}


func apply_damage(amount: int) -> void:
	state.hit_points = clampi(state.hit_points - max(0, amount), 0, state.max_hit_points)
	_emit_state()


func heal(amount: int) -> void:
	state.hit_points = clampi(state.hit_points + max(0, amount), 0, state.max_hit_points)
	_emit_state()


func use_ability(ability_id: StringName, context: Dictionary = {}) -> Dictionary:
	if not state.equipped_abilities.has(ability_id):
		return {
			"ok": false,
			"reason": "ability_not_equipped",
			"summary": state.get_summary(),
		}

	var flaw_result: Dictionary = record_action(&"ability_used", context)
	var result: Dictionary = {
		"ok": true,
		"ability": ability_id,
		"flaw_result": flaw_result,
		"summary": state.get_summary(),
	}
	turn_resolved.emit(result["summary"])
	return result


func _trigger_flaw(display_name: String, penalties: Dictionary) -> Dictionary:
	var applied: Dictionary = {}
	for key in penalties.keys():
		var value = penalties[key]
		if key == "hit_points":
			state.hit_points = clampi(state.hit_points + int(value), 0, state.max_hit_points)
		elif key == "soul_rejection":
			_add_rejection(float(value))
		elif state.stats.has(key):
			state.stats[key] = int(state.stats[key]) + int(value)
		applied[key] = value

	var result: Dictionary = {
		"flaw": display_name,
		"penalties": applied,
		"summary": state.get_summary(),
	}
	flaw_triggered.emit(result)
	_emit_state()
	return result


func _add_rejection(amount: float) -> void:
	state.soul_rejection = clampf(state.soul_rejection + maxf(0.0, amount), 0.0, 100.0)


func _apply_rejection_debuffs() -> Dictionary:
	var tier: int = int(floor(state.soul_rejection / REJECTION_DEBUFF_STEP))
	var penalties: Dictionary = {
		"resistenza": -tier,
		"volonta": -tier,
	}

	state.debuffs["rigetto_anima"] = penalties
	return penalties


func _enforce_ability_slots() -> void:
	var max_slots: int = state.get_skill_slot_count()
	while state.equipped_abilities.size() > max_slots:
		state.equipped_abilities.pop_back()


func _emit_state() -> void:
	state_changed.emit(state)
