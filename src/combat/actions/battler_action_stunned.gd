## A no-op action automatically assigned by [method Battler.get_stunned_action] to a Battler
## affected by a status effect with [member StatusEffect.prevents_action] set. Lets a stunned
## Battler skip its turn without requiring player input or AI selection.
class_name StunnedBattlerAction extends BattlerAction


func _init() -> void:
	target_scope = TargetScope.SELF
	name = "Stordito"
	description = "Non puo' agire a causa di uno stato alterato."


func can_execute() -> bool:
	return true


func execute() -> void:
	cached_targets = [source]
	await source.get_tree().create_timer(0.4).timeout
