## A single stat change, applicable to any [BattlerStats]. Used by both [EquipmentItem] and
## [SkillTreeNode] so equipment and skills share one mechanism instead of two.
class_name StatModifierEffect extends Resource

@export var stat_name: String = "attack"
## A flat modifier (e.g. +5 attack) if false, a multiplier (e.g. +0.2 = +20%) if true.
@export var is_multiplier: bool = false
@export var amount: float = 0.0


## Applies this effect to [param stats] and returns the modifier/multiplier id, so the caller can
## remove it later via [method BattlerStats.remove_modifier]/[method BattlerStats.remove_multiplier].
func apply(stats: BattlerStats) -> int:
	if is_multiplier:
		return stats.add_multiplier(stat_name, amount)
	return stats.add_modifier(stat_name, int(amount))


func remove(stats: BattlerStats, id: int) -> void:
	if is_multiplier:
		stats.remove_multiplier(stat_name, id)
	else:
		stats.remove_modifier(stat_name, id)
