extends Interaction

var _conversation: = preload("res://data/maps/town/warrior.dtl")


func interact() -> void:
	Dialogic.start_timeline(_conversation)
