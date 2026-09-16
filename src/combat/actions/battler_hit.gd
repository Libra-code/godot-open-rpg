## Represents a damage-dealing hit to be applied to a target Battler.
## Encapsulates calculations for how hits are applied based on some properties.
class_name BattlerHit extends RefCounted

var damage: = 0
var hit_chance: = 100.0

# Rolled once and cached: callers that need to know whether a hit landed after something else
# already checked it (e.g. ApplyStatusBattlerAction deciding whether to also inflict a status
# effect once Battler.take_hit() has resolved the hit) must see the same result, not a fresh and
# possibly different coin flip.
var _rolled_success: bool


func _init(dmg: int, to_hit := 100.0) -> void:
	damage = dmg
	hit_chance = to_hit
	_rolled_success = randf() * 100.0 < hit_chance


func is_successful() -> bool:
	return _rolled_success
