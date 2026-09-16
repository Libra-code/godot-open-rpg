## Autoloaded as "PartyLoadouts". Holds each party member's [CharacterLoadout] (equipment, unlocked
## skills) and the [SkillTree] definitions they unlock from, keyed by character name
## ([member Battler.name] / [member BattlerStats] owner name).
##
## This is the bridge between the persistent field/meta layer and the disposable per-battle
## [Battler]: nothing here is ever read directly by combat math, it only configures a fresh
## [BattlerStats] duplicate at the start of a battle (see [method apply_to]).
extends Node

var _loadouts: Dictionary = {} # character_name (String) -> CharacterLoadout
var _skill_trees: Dictionary = {} # character_name (String) -> SkillTree

# Default demo content. A larger game would register these from a proper new-game/character-setup
# flow instead of hardcoding them here.
const _DEFAULT_SKILL_TREES: = {
	"Baloo": preload("res://combat/battlers/bear/baloo_skill_tree.tres"),
}


func _ready() -> void:
	for character_name in _DEFAULT_SKILL_TREES:
		register_skill_tree(character_name, _DEFAULT_SKILL_TREES[character_name])


func get_loadout(character_name: String) -> CharacterLoadout:
	if not _loadouts.has(character_name):
		var loadout: = CharacterLoadout.new()
		loadout.character_name = character_name
		_loadouts[character_name] = loadout

	return _loadouts[character_name]


func register_skill_tree(character_name: String, skill_tree: SkillTree) -> void:
	_skill_trees[character_name] = skill_tree


func get_skill_tree(character_name: String) -> SkillTree:
	return _skill_trees.get(character_name)


func equip(character_name: String, item: EquipmentItem) -> void:
	get_loadout(character_name).equip(item)


func unequip(character_name: String, slot: StringName) -> void:
	get_loadout(character_name).unequip(slot)


func unlock_skill(character_name: String, skill_id: StringName) -> bool:
	var skill_tree: = get_skill_tree(character_name)
	if not skill_tree:
		push_warning("PartyLoadouts: no SkillTree registered for '%s'." % character_name)
		return false

	return get_loadout(character_name).unlock_skill(skill_tree, skill_id)


## Applies [param battler]'s stored loadout to its (already-duplicated) stats. Called from
## [method Battler._ready] for player battlers only — enemies have no loadout.
func apply_to(battler: Battler) -> void:
	if not _loadouts.has(battler.name):
		return

	var loadout: CharacterLoadout = _loadouts[battler.name]
	loadout.apply_to_stats(battler.stats, get_skill_tree(battler.name))


## Serializes every loadout to a plain Dictionary, suitable for [SaveGame].
func to_save_dict() -> Dictionary:
	var data: = {}
	for character_name in _loadouts:
		var loadout: CharacterLoadout = _loadouts[character_name]

		var equipped: = {}
		for slot in loadout.equipped_items:
			var item: EquipmentItem = loadout.equipped_items[slot]
			if item:
				equipped[String(slot)] = String(item.id)

		var unlocked: = []
		for skill_id in loadout.unlocked_skill_ids:
			unlocked.append(String(skill_id))

		data[character_name] = {"equipped_items": equipped, "unlocked_skill_ids": unlocked}

	return data


## Restores loadouts saved via [method to_save_dict]. [param item_lookup] resolves an equipment id
## (String) back to its [EquipmentItem] resource, since only ids are persisted.
func load_from_dict(data: Dictionary, item_lookup: Callable) -> void:
	_loadouts.clear()

	for character_name in data:
		var saved: Dictionary = data[character_name]
		var loadout: = get_loadout(character_na