## A floating text label used for status-effect feedback in combat (applied/expired messages).
## Reuses the same "float up and fade" animation as [UIDamageLabel], but shows arbitrary text
## instead of a number, since status effects don't always have a single numeric value to show.
class_name UIStatusLabel extends Marker2D

@export var move_distance: = 96.0
@export var move_time: = 0.6
@export var fade_time: = 0.2

var _tween: Tween = null

@onready var _label: = $Label as Label


func setup(origin: Vector2, text: String, color: Color) -> void:
	global_position = origin
	_label.text = text
	_label.modulate = color

	var angle: = randf_range(-PI / 6.0, PI / 6.0)
	var target: = Vector2.UP.rotated(angle) * move_distance + _label.position

	_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_tween.tween_property(_label, "position", target, move_time)

	_tween.parallel().tween_property(
		self,
		"modulate",
		Color.TRANSPARENT,
		fade_time
	).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_LINEAR).set_delay(move_time - fade_time)

	_tween.tween_callback(queue_free)
