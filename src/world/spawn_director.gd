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


## Returns a *new* [BattlerStats] (the original is left untouched) with attack/defense/max health
## scaled by [param biome]'s difficulty curve, sampled at [param player_level]. If [param biome] is
## null, returns an unscaled duplicate — encounters with no biome assigned behave exactly as
## before this system existed.
static func scale_enemy_stats(base_stats: BattlerStats, biome: BiomeDefinition,
		player_level: int) -> BattlerStats:
	var scaled: BattlerStats = base_stats.duplicate()
	if not biome:
		return scaled

	var multiplier: = biome.get_multiplier(player_level)

	scaled.base_attack = roundi(scaled.base_attack * multiplier)
	scaled.base_defense = roundi(scaled.base_defense * multiplier)
	scaled.base_max_health = roundi(scaled.base_max_health * multiplier)
	scaled.max_health = roundi(scaled.max_health * multiplier)
	scaled.health = scaled.max_health

	return scaled
