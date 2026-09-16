## Scales an enemy's [BattlerStats] according to a [BiomeDefinition] and the party's current
## level, so the same hand-placed encounter can feel appropriately easy or hard depending on how
## far the player has progressed — without needing to hand-author a separate stats resource per
## difficulty tier.
class_name SpawnDirector extends RefCounted


## Returns the party's level to scale against: the highest level among the player's battlers, so a
## single under-leveled party member doesn't make every encounter trivially easy to balance around.
static func get_party_level() -> int:
	var highest_level: = 1
	for character_name in PartyLoadouts.get_all_character_names():
		highest_level = maxi(highest_level, PartyLoadouts.get_loadout(character_name).level)
	return highest_level


## Scales attack/defense/max health of [param stats] *in place*, according to [param biome]'s
## difficulty at [param player_level]. Does nothing if [param biome] is null.
##
## This mutates the given [BattlerStats] directly rather than returning a scaled duplicate on
## purpose: by the time [Combat.setup] calls this, [param stats] is already the private duplicate
## [method Battler._ready] made for this one battle, with [signal BattlerStats.health_depleted]
## already connected to it. Swapping in yet another duplicate here would silently leave that
## connection wired to an orphaned object — the enemy's health would still drop, but it would
## never register as defeated, since [member Battler.is_active] never flips.
static func apply_scaling(stats: BattlerStats, biome: BiomeDefinition, player_level: int) -> void:
	if not biome:
		return

	var multiplier: = biome.get_multiplier(player_level)

	stats.base_attack = roundi(stats.base_attack * multiplier)
	stats.base_defense = roundi(stats.base_defense * multiplier)
	stats.base_max_health = roundi(stats.base_max_health * multiplier)
	stats.max_health = roundi(stats.max_health * multiplier)
	stats.health = stats.max_health
