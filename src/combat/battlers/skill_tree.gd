## A designer-authored graph of [SkillTreeNode]s for one character or class. This resource only
## describes what's *unlockable* and in what order; which nodes a given character has actually
## unlocked lives in that character's [CharacterLoadout] instead, so the same tree definition can
## be shared and the unlocked set can still be saved per-save-file.
class_name SkillTree extends Resource

@export var character_name: String = ""
@export var nodes: Array[SkillTreeNode] = []


func get_node_by_id(skill_id: StringName) -> SkillTreeNode:
	for node in nodes:
		if node.id == skill_id:
			return node
	return null


## Returns true if [param skill_id] exists, isn't already unlocked, and every prerequisite is
## already present in [param already_unlocked].
func can_unlock(skill_id: StringName, already_unlocked: Array[StringName]) -> bool:
	var node: = get_node_by_id(skill_id)
	if not node or already_unlocked.has(skill_id):
		return false

	for prereq in node.prerequisites:
		if not already_unlocked.has(prereq):
			return false

	return true
