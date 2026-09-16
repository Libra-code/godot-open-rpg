## The persistent equipment/skill choices for one named party member (matched by [Battler.name]).
##
## This is intentionally separate from [BattlerStats]: a fresh [BattlerStats] duplicate is created
## for every single battle (see [method Battler._ready]), so equipping gear or unlocking a skill
## can't be represented as a one-time mutation of some "live" stats object. Instead, the loadout
## re-applies itself in full to whichever [BattlerStats] duplicate shows up at the start of the
## next battle (see [method PartyLoadouts.apply_to]).
class_name CharacterLoadout extends Resource

@export var character_name: String = ""
## slot (StringName) -> EquipmentItem
@export var equipped_items: Dictionary = {}
@export var unlocked_skill_ids: Array[StringName] = []


func equip(item: EquipmentItem) -> void:
	equipped_items[item.slot] = item


func unequip(slot: StringName) -> void:
	equipped_items.erase(slot)


## Unlocks a skill if [param skill_tree] allows it. Returns true if the skill was newly unlocked.
func unlock_skill(skill_tree: SkillTree, skill_id: StringName) -> bool:
	if not skill_tree.can_unlock(skill_id, unlocked_skill_ids):
		return false

	unlocked_skill_ids.append(skill_id)
	return true


## Applies every equipped item's and unlocked skill's effects to [param stats]. Called once per
## battle, right after [Battler] duplicates its stats resource.
func apply_to_stats(stats: BattlerStats, skill_tree: SkillTree = null) -> void:
	for slot in equipped_items:
		var item: EquipmentItem = equipped_items[slot]
		if item:
			for effect in item.modifiers:
				effect.apply(stats)

	if skill_tree:
		for skill_id in unlocked_skill_ids:
			var node: = skill_tree.get_node_by_id(skill_id)
			if node:
				for effect in node.effects:
					effect.apply(stats)
