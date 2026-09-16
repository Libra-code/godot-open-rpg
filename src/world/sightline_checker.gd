## Checks whether a straight line between two cells crosses any blocked cell.
##
## This project's terrain has no physics colliders for walls (see [GameboardLayer]: blocking is
## purely a custom-data-layer + [AStar2D] concept, not a [PhysicsBody2D] one), so a
## [PhysicsDirectSpaceState2D] raycast would never actually detect an obstruction. Walking the
## line of cells against the pathfinder — which already knows exactly which cells are walkable —
## is the check that actually matches how this game represents its world.
class_name SightlineChecker extends RefCounted


## Returns true if every cell strictly between [param from_cell] and [param to_cell] (exclusive of
## both endpoints) is currently walkable. An endpoint that is itself blocked doesn't count against
## visibility — you can still see a landmark standing right at the edge of a wall.
static func has_line_of_sight(from_cell: Vector2i, to_cell: Vector2i) -> bool:
	for cell in _cells_between(from_cell, to_cell):
		if cell == from_cell or cell == to_cell:
			continue
		if not Gameboard.pathfinder.has_point(Gameboard.cell_to_index(cell)):
			return false
	return true


# Bresenham's line algorithm: the set of grid cells forming a straight line between two points.
static func _cells_between(from_cell: Vector2i, to_cell: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []

	var x0: = from_cell.x
	var y0: = from_cell.y
	var x1: = to_cell.x
	var y1: = to_cell.y

	var dx: = absi(x1 - x0)
	var dy: = -absi(y1 - y0)
	var step_x: = 1 if x0 < x1 else -1
	var step_y: = 1 if y0 < y1 else -1
	var error: = dx + dy

	while true:
		cells.append(Vector2i(x0, y0))
		if x0 == x1 and y0 == y1:
			break

		var doubled_error: = 2 * error
		if doubled_error >= dy:
			error += dy
			x0 += step_x
		if doubled_error <= dx:
			error += dx
			y0 += step_y

	return cells
