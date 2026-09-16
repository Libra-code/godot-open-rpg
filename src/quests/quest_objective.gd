## One measurable condition of a [QuestDefinition], expressed as a comparison against an existing
## Dialogic variable — the same variables interactions like [code]fan_interaction.gd[/code] already
## read and write directly. This wraps that mechanism with a schema instead of replacing it.
class_name QuestObjective extends Resource

enum Comparison { EQUAL, GREATER_OR_EQUAL }

@export var description: String = ""
@export var dialogic_variable: String = ""
@export var comparison: Comparison = Comparison.GREATER_OR_EQUAL
@export var required_value: Variant = 1


func is_met() -> bool:
	var current: Variant = Dialogic.VAR.get_variable(dialogic_variable, 0, true)
	match comparison:
		Comparison.EQUAL:
			return current == required_value
		Comparison.GREATER_OR_EQUAL:
			return current >= required_value
	return false
