## A piece of equipment that grants one or more [StatModifierEffect]s while equipped in a
## [member slot]. Equipping a second item in the same slot replaces the first.
class_name EquipmentItem extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
## Free-form slot name (e.g. &"weapon", &"armor", &"trinket"). Only one item per slot may be
## equipped at a time; see [CharacterLoadout.equip].
@export var slot: StringName = &"weapon"
@export var modifiers: Array[StatModifierEffect] = []
