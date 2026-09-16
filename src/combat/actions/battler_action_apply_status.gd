## A [BattlerAction] that applies a [StatusEffect] (poison, stun, a timed buff/debuff, etc.) to its
## targets, optionally dealing direct damage first.
##
## If [member base_damage] is 0, the effect is applied unconditionally (e.g. a self-buff, or a
## status inflicted by something other than a physical blow). If [member base_damage] is greater
## than 0, the effect is only applied to targets the accompanying hit actually connects with, same
## as [AttackBattlerAction].
class_name ApplyStatusBattlerAction extends BattlerAction

@export var base_damage: = 0
@export var hit_chance: = 100.0
@export var status_effect: StatusEffect


func execute() -> void:
	assert(status_effect != null, "ApplyStatusBattlerAction requires a status_effect.")
	assert(not cached_targets.is_empty(), "This action requires a target.")

	await source.get_tree().create_timer(0.2).timeout

	for target in cached_targets:
		if base_damage > 0:
			var modified_damage: = base_damage + source.stats.attack
			var to_hit: = hit_chance * (source.stats.hit_chance / 100.0)
			var hit: = BattlerHit.new(modified_damage, to_hit)
			target.take_hit(hit)
			if hit.is_successful():
				target.apply_status_effect(status_effect)
		else:
			target.apply_status_effect(status_effect)

		await source.get_tree().create_timer(0.15).timeout
