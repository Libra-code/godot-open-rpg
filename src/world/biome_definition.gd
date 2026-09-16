## Data describing how tough combat should feel in one area of the world. A biome doesn't spawn or
## place anything itself (this project's encounters are hand-placed, not randomly generated) — it
## scales the stats of whichever enemies an encounter already carries, based on how far along the
## player's own party is. See [SpawnDirector].
class_name BiomeDefinition extends Resource

@export var id: StringName = &""
@export var display_name: String = ""

## Optional: x = player level normalized against [member level_normalization_cap] (0..1), y = the
## multiplier applied to enemy attack/defense/max health. Leave unset to use the simpler
## [member min_multiplier]/[member max_multiplier] linear ramp instead — a hand-authored curve
## isn't required just to get sensible scaling.
@export var difficulty_curve: Curve
## Multiplier at player level 1 (t = 0), used when [member difficulty_curve] is unset.
@export var min_multiplier: float = 1.0
## Multiplier at [member level_normalization_cap] and beyond (t = 1), used when
## [member difficulty_curve] is unset.
@export var max_multiplier: float = 1.5
## The player level at which max scaling is reached. A party well past this level still just gets
## the maximum multiplier rather than scaling further.
@export var level_normalization_cap: int = 20


## The scaling multiplier for a party at [param player_level], from either the curve or the linear
## fallback — whichever this biome defines.
func get_multiplier(player_level: int) -> float:
	var t: = clampf(float(player_level) / float(maxi(1, level_normalization_cap)), 0.0, 1.0)
	if difficulty_curve:
		return difficulty_curve.sample(t)
	return lerpf(min_multiplier, max_multiplier, t)
