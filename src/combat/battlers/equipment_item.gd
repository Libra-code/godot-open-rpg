## A piece of equipment that grants one or more [StatModifierEffect]s while equipped in a
## [member slot]. Equipping a second item in the same slot replaces the first.
class_name EquipmentItem extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
## Free-form slot name (e.g. &"weapon", &"armor", &"trinket"). Only one item per slot may be
## equipped at a time; see [CharacterLoadout.equip].
@export var slot: StringName = &"weapon"
@export var modifiers: Array[StatModifierEffect] = []
## Flavor/explanation text shown in the equipment page's detail panel. If left empty, one is
## generated from [member modifiers] instead (see [method get_effective_description]).
@export_multiline var description: String = ""


## Returns [member description] if set, otherwise a plain listing of what [member modifiers] do
## (e.g. "+8 speed"), so every item shows something useful in the detail panel even without
## hand-written flavor text.
func get_effective_description() -> String:
	if not description.is_empty():
		return description

	if modifiers.is_empty():
		return "Nessun effetto."

	var parts: PackedStringArray = []
	for modifier in modifiers:
		if modifier.is_multiplier:
			parts.append("%+d%% %s" % [roundi(modifier.amount * 100), modifier.stat_name])
		else:
			parts.append("%+d %s" % [roundi(modifier.amount), modifier.stat_name])
	return ", ".join(parts)
