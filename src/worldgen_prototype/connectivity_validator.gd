## Verifies that a generated [RegionLayout] doesn't strand the player: every room must be reachable
## from every other room by walking only [member RegionLayout.walkable_cells]. This is the gate a
## generated region must pass before it's ever shown to a player (see
## [method BSPDungeonGenerator.generate]'s retry loop).
class_name ConnectivityValidator extends RefCounted


static func all_rooms_reachable(layout: RegionLayout) -> bool:
	if layout.rooms.is_empty():
		return false

	var start: = layout.rooms[0].get_center()
	var reachable: = _flood_fill(layout, start)

	for room in layout.rooms:
		if not reachable.has(room.get_center()):
			return false
	return true


static func _flood_fill(layout: RegionLayout, start: Vector2i) -> Dictionary:
	var visited: Dictionary = {}
	if not layout.is_walkable(start):
		return visited

	var frontier: Array[Vector2i] = [start]
	visited[start] = true

	const NEIGHBOR_OFFSETS: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]

	while not frontier.is_empty():
		var current: Vector2i = frontier.pop_back()
		for offset in NEIGHBOR_OFFSETS:
			var neighbor: = current + offset
			if layout.is_walkable(neighbor) and not visited.has(neighbor):
				visited[neighbor] = true
				frontier.append(neighbor)

	return visited
