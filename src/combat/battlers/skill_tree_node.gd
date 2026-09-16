## A single unlockable node in a [SkillTree]. Prerequisites are other node ids that must already be
## unlocked before this one becomes available.
class_name SkillTreeNode extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
@export var description: String = ""
@export var cost: int = 1
@export var prerequisites: Array[StringName] = []
@export var effects: Array[StatModifierEffect] = []
