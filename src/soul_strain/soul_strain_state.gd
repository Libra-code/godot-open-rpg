class_name SoulStrainState
extends Resource

const CORE_DORMANT: StringName = &"Dormiente"
const CORE_AWAKENED: StringName = &"Risvegliato"
const CORE_ASCENDED: StringName = &"Asceso"

const CORE_SKILL_SLOTS: Dictionary = {
	CORE_DORMANT: 2,
	CORE_AWAKENED: 4,
	CORE_ASCENDED: 6,
}

@export var character_name: String = "Senza Nome"
@export var aspect: String = "Vuoto"
@export var aspect_tags: Array[StringName] = [&"void"]
@export var flaw_id: StringName = &""
@export var flaw_display_name: String = ""
@export var core_grade: StringName = CORE_DORMANT
@export var max_hit_points: int = 100
@export var hit_points: int = 100
@export var max_mana: int = 60
@export_range(0.0, 100.0, 0.1) var soul_rejection: float = 0.0
@export var soul_fragments: int = 0
@export var stats: Dictionary = {
	"forza": 8,
	"agilita": 8,
	"resistenza": 8,
	"percezione": 8,
	"volonta": 8,
	"intelletto": 8,
}
@export var active_memories: Array[SoulStrainMemory] = []
@export var equipped_abilities: Array[StringName] = []
@export var debuffs: Dictionary = {}
@export var assimilated_essences: Array[StringName] = []


func get_skill_slot_count() -> int:
	return CORE_SKILL_SLOTS.get(core_grade, CORE_SKILL_SLOTS[CORE_DORMANT])


func get_reserved_mana() -> int:
	var reserved_mana: int = 0
	for memory in active_memories:
		if memory:
			reserved_mana += max(0, memory.mana_reserved)
	return reserved_mana


func get_available_mana() -> int:
	return max(0, max_mana - get_reserved_mana())


func get_effective_stats() -> Dictionary:
	var effective_stats: Dictionary = stats.duplicate(true)
	for debuff in debuffs.values():
		if debuff is Dictionary:
			for stat_name in debuff.keys():
				if effective_stats.has(stat_name):
					effective_stats[stat_name] = int(effective_stats[stat_name]) + int(debuff[stat_name])
	return effective_stats


func get_summary() -> Dictionary:
	return {
		"available_mana": get_available_mana(),
		"hit_points": hit_points,
		"max_hit_points": max_hit_points,
		"core_grade": core_grade,
		"soul_rejection": soul_rejection,
	}
