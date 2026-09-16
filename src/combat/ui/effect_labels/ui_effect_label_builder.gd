## A builder class responsible for adding visual feedback to [BattlerActions].
##
## This feedback takes the form of different UI elements (such as an animated label) that may
## demonstrate how much damage was done or if an action missed the target completely.
class_name UIEffectLabelBuilder extends Node2D

const STATUS_APPLIED_COLOR: = Color(0.85, 0.55, 0.95, 1)
const STATUS_EXPIRED_COLOR: = Color(0.7, 0.7, 0.7, 1)
const STATUS_TICK_COLOR: = Color(0.6, 0.85, 0.4, 1)

@export var damage_label_scene: PackedScene
@export var missed_label_scene: PackedScene
@export var status_label_scene: PackedScene


func setup(battler_data: BattlerRoster) -> void:
	for battler in battler_data.get_battlers():

		battler.hit_missed.connect(func _on_battler_hit_missed() -> void:
			var label: = missed_label_scene.instantiate()
			add_child(label)
			label.global_position = battler.anim.top.global_position
		)

		battler.hit_received.connect(func _on_battler_hit_received(amount: int) -> void:
			var label: = damage_label_scene.instantiate() as UIDamageLabel
			add_child(label)
			label.setup(battler.anim.top.global_position, amount)
		)

		battler.status_effect_applied.connect(func _on_status_effect_applied(effect: StatusEffect) -> void:
			var label: = status_label_scene.instantiate() as UIStatusLabel
			add_child(label)
			label.setup(battler.anim.top.global_position, effect.display_name + "!", STATUS_APPLIED_COLOR)
		)

		battler.status_effect_expired.connect(func _on_status_effect_expired(effect: StatusEffect) -> void:
			var label: = status_label_scene.instantiate() as UIStatusLabel
			add_child(label)
			label.setup(
				battler.anim.top.global_position,
				"%s svanito" % effect.display_name,
				STATUS_EXPIRED_COLOR
			)
		)

		battler.status_effect_ticked.connect(
			func _on_status_effect_ticked(_effect: StatusEffect, amount: int) -> void:
				if amount > 0:
					var label: = damage_label_scene.instantiate() as UIDamageLabel
					add_child(label)
					label.setup(battler.anim.top.global_position, amount)
				else:
					var label: = status_label_scene.instantiate() as UIStatusLabel
					add_child(label)
					label.setup(battler.anim.top.global_position, str(-amount), STATUS_TICK_COLOR)
		)
