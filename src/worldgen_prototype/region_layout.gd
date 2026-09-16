## The cell-level output of a generator: which cells are walkable, plus the room rectangles that
## produced them (kept around for debugging/visualization, not needed for gameplay logic).
class_name RegionLayout extends RefCounted

var bounds: Rect2i
var rooms: Array[Rect2i] = []
var walkable_cells: Dictionary = {} # Vector2i -> true


func is_walkable(cell: Vector2i) -> bool:
	return walkable_cells.has(cell)


func mark_walkable(cell: Vector2i) -> void:
	walkable_cells[cell] = true


func mark_room_walkable(room: Rect2i) -> void:
	rooms.append(room)
	for x in range(room.position.x, room.end.x):
		for y in range(room.position.y, room.end.y):
			mark_walkable(Vector2i(x, y))


## Carves a 1-cell-wide corridor between two points, moving horizontally then vertically (an
## "L-shaped" corridor — simple, always connects, and cheap to reason about for validation).
func carve_corridor(from: Vector2i, to: Vector2i) -> void:
	var x: = from.x
	var y: = from.y

	while x != to.x:
		mark_walkable(Vector2i(x, y))
		x += 1 if to.x > x else -1
	while y != to.y:
		mark_walkable(Vector2i(x, y))
		y += 1 if to.y > y else -1

	mark_walkable(to)
