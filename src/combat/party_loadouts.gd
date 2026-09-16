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
	"Nutsy": preload("res://combat/battlers/squirrel/nutsy_skill_tree.tres"),
}

# Every EquipmentItem in the game, keyed by its id. Lets SaveGame resolve an equipped item back
# from the string id it persists (see load_from_dict), instead of saving whole item resources.
const _ITEM_REGISTRY: = {
	"claw_gauntlets": preload("res://combat/battlers/bear/claw_gauntlets.tres"),
	"lucky_tail": preload("res://combat/battlers/squirrel/lucky_tail.tres"),
}

# EquipmentItem resources built on demand from ItemDatabase rows (see _equipment_item_from_db_row),
# cached by id so repeated lookups (equip UI redraws, save/load) don't rebuild the same Resource
# and don't lose reference identity for CharacterLoadout.equipped_items comparisons.
var _db_item_cache: Dictionary = {} # item_id (String) -> EquipmentItem


func _ready() -> void:
	reset_to_defaults()


## Wipes every loadout back to level 1 / starting gear and re-registers the default skill trees.
## Used both at boot (see [method _ready]) and when the main menu's "Nuova Partita" starts a fresh
## run without restarting the process — without this, a second playthrough in the same session
## would inherit levels/equipment/unlocks from whatever the player did before returning to the
## main menu. Does NOT touch [Inventory] (a separate, disk-backed Resource, not autoload state);
## see FUNZIONALITA.md for that known gap.
func reset_to_defaults() -> void:
	_loadouts.clear()
	_skill_trees.clear()
	_db_item_cache.clear()

	for character_name in _DEFAULT_SKILL_TREES:
		register_skill_tree(character_name, _DEFAULT_SKILL_TREES[character_name])

	# Starting gear, so the system is active from the very first battle rather than sitting unused
	# until a shop/loot UI exists to grant equipment.
	equip("Baloo", _ITEM_REGISTRY["claw_gauntlets"])
	equip("Nutsy", _ITEM_REGISTRY["lucky_tail"])


## Resolves an equipment id to its [EquipmentItem]. Checks the hand-authored [constant
## _ITEM_REGISTRY] first, then falls back to [autoload ItemDatabase] — this is what lets loot
## tables and future content scale into the thousands without a `.tres` file (and a registry
## entry) hand-authored for each one.
func get_item_by_id(item_id: String) -> EquipmentItem:
	if _ITEM_REGISTRY.has(item_id):
		return _ITEM_REGISTRY[item_id]

	if _db_item_cache.has(item_id):
		return _db_item_cache[item_id]

	var row: = ItemDatabase.get_item(item_id)
	if row.is_empty() or row.get("item_type") != "equipment":
		return null

	var item: = _equipment_item_from_db_row(row)
	_db_item_cache[item_id] = item
	return item


## Every EquipmentItem that exists in the game, for a UI to offer as equip choices: the
## hand-authored [constant _ITEM_REGISTRY] plus every 'equipment' row in [autoload ItemDatabase].
func get_all_items() -> Array[EquipmentItem]:
	var items: Array[EquipmentItem] = []
	items.assign(_ITEM_REGISTRY.values())

	for row: Dictionary in ItemDatabase.get_items_by_filter({"item_type": "equipment"}):
		var item_id: String = row.id
		if _ITEM_REGISTRY.has(item_id):
			continue # already listed above; the hand-authored resource wins over the DB row.
		items.append(get_item_by_id(item_id))

	return items


# Converts an ItemDatabase row (a plain Dictionary, stats_json already merged in — see
# ItemDatabase._resolve_row) into a real EquipmentItem/StatModifierEffect Resource pair, since
# CharacterLoadout.equip() and apply_to_stats() only know how to work with those, not raw rows.
func _equipment_item_from_db_row(row: Dictionary) -> EquipmentItem:
	var item: = EquipmentItem.new()
	item.id = StringName(row.id)
	item.display_name = row.display_name
	item.slot = StringName(row.get("slot", "weapon"))

	var modifiers: Array[StatModifierEffect] = []
	for mod: Dictionary in row.get("modifiers", []):
		var effect: = StatModifierEffect.new()
		effect.stat_name = mod.get("stat_name", "attack")
		effect.is_multiplier = mod.get("is_multiplier", false)
		effect.amount = float(mod.get("amount", 0.0))
		modifiers.append(effect)
	item.modifiers = modifiers

	return item


## Every character with content worth showing an equipment/skills screen for: anyone with a
## registered [SkillTree] and/or a loadout already on record. This is narrower than "every player
## Battler that ever existed" on purpose — a character with neither isn't missing data, there's
## simply nothing yet to manage for them.
func get_managed_character_names() -> Array[String]:
	var names: Dictionary = {}
	for character_name in _skill_trees:
		names[character_name] = true
	for character_name in _loadouts:
		names[character_name] = true

	var result: Array[String] = []
	result.assign(names.keys())
	return result


## Every character with a loadout on record. A character only appears here once something has
## actually touched their loadout (equipping gear, unlocking a skill, finishing a battle) — anyone
## absent from this list is still at the default level 1 / no gear.
func get_all_character_names() -> Array[String]:
	var names: Array[String] = []
	for character_name in _loadouts:
		names.append(character_name)
	return names


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

		data[character_name] = {
			"equipped_items": equipped,
			"unlocked_skill_ids": unlocked,
			"level": loadout.level,
			"xp": loadout.xp,
		}

	return data


## Restores loadouts saved via [method to_save_dict]. [param item_lookup] resolves an equipment id
## (String) back to its [EquipmentItem] resource, since only ids are persisted.
func load_from_dict(data: Dictionary, item_lookup: Callable) -> void:
	_loadouts.clear()

	for character_name in data:
		var saved: Dictionary = data[character_name]
		var loadout: = get_loadout(character_name)

		for slot in saved.get("equipped_items", {}):
			var item_id: String = saved["equipped_items"][slot]
			var item: EquipmentItem = item_lookup.call(item_id)
			if item:
				loadout.equipped_items[slot] = item

		var unlocked: Array[StringName] = []
		for skill_id in saved.get("unlocked_skill_ids", []):
			unlocked.append(StringName(skill_id))
		loadout.unlocked_skill_ids = unlocked

		loadout.level = saved.get("level", 1)
		loadout.xp = saved.get("xp", 0)
