extends CanvasLayer

@onready var mana_label: Label = %ManaLabel
@onready var hp_label: Label = %HitPointsLabel
@onready var core_label: Label = %CoreGradeLabel
@onready var rejection_label: Label = %RejectionLabel


func _ready() -> void:
	SoulStrain.state_changed.connect(_on_state_changed)
	SoulStrain.turn_resolved.connect(_on_turn_resolved)
	_on_state_changed(SoulStrain.state)


func _on_state_changed(state: SoulStrainState) -> void:
	_set_summary(state.get_summary())


func _on_turn_resolved(summary: Dictionary) -> void:
	_set_summary(summary)


func _set_summary(summary: Dictionary) -> void:
	mana_label.text = "M_disp: %d" % int(summary.get("available_mana", 0))
	hp_label.text = "Punti Vita: %d/%d" % [
		int(summary.get("hit_points", 0)),
		int(summary.get("max_hit_points", 0)),
	]
	core_label.text = "Nucleo: %s" % str(summary.get("core_grade", SoulStrainState.CORE_DORMANT))
	rejection_label.text = "Rigetto: %.1f%%" % float(summary.get("soul_rejection", 0.0))
