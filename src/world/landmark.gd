## Marks its parent [Node2D] as a navigational landmark — something the player should be able to
## recognize and orient by (a door, a bridge, a distinctive building) without needing a minimap.
##
## This is a plain child node rather than a resource so any existing scene object (a [Door], an
## [AreaTransition], a hand-placed prop) can become a landmark just by adding one as a child — no
## new art, no change to the object's own script.
class_name Landmark extends Node

@export var display_name: String = ""
## How close the player must be for this landmark to count as "visible" at all, before line of
## sight is even checked. Keeps a distant, technically-unobstructed landmark from counting just
## because nothing happens to be in the way over a huge distance.
@export var min_visibility_radius: float = 200.0

@onready var _anchor: Node2D = get_parent()


func _ready() -> void:
	assert(_anchor, "Landmark's parent must be a Node2D.")
	LandmarkRegistry.register(self)


func get_world_position() -> Vector2:
	return _anchor.global_position


func is_visible_from(viewer_position: Vector2) -> bool:
	if get_world_position().distance_to(viewer_position) > min_visibility_radius:
		return false

	var from_cell: = Gameboard.pixel_to_cell(viewer_position)
	var to_cell: = Gameboard.pixel_to_cell(get_world_position())
	return SightlineChecker.has_line_of_sight(from_cell, to_cell)
