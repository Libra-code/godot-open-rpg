## Procedurally generates a small dungeon layout at runtime with [BSPDungeonGenerator] (see
## `src/worldgen_prototype/`), then paints the result onto a sibling [GameboardLayer] so the
## existing [Gameboard]/[Pathfinder] pipeline treats it exactly like any hand-drawn area.
##
## This is the first integration of that prototype into the real game — it was deliberately kept
## isolated until now (see `FUNZIONALITA.md`). Nothing about the generator itself changes: the
## same seeded retry-with-fallback loop and [ConnectivityValidator] check still guarantee every
## generated room is reachable from every other one.
class_name DungeonMap extends Node2D

## Bounds are fixed, far-away cell coordinates so this area's tiles never collide with Town/House/
## Forest's hand-drawn ones (all of which stay within roughly x:-12..71, y:-8..42) — every
## [GameboardLayer] in this project shares one global cell space rather than each having its own
## local origin (their Node2D positions are all (0, 0)).
const BOUNDS: = Rect2i(150, 0, 30, 20)

## Where the player always arrives from Town, regardless of the generated layout. Forced walkable
## and connected below (see [method _force_entrance_reachable]) so the entrance is never the one
## cell an unlucky seed stranded from the rest of the dungeon.
const ENTRANCE_CELL: = Vector2i(152, 10)

## Deterministic on purpose: this dungeon looks the same every time the area is entered in a given
## build, matching [BSPDungeonGenerator]'s own reproducibility guarantee (same seed, same layout).
@export var region_seed: int = 1

@onready var _ground: GameboardLayer = $Ground


func _ready() -> void:
	var region: = BSPDungeonGenerator.generate(BOUNDS, region_seed)
	_force_entrance_reachable(region)
	_paint(region)


# BSPDungeonGenerator's retry+fallback loop guarantees every *generated* room connects to every
# other one, but the fixed entrance point above is ours, not the generator's — it isn't part of
# that guarantee. Carve a small room there and a straight corridor to the nearest generated room
# to fold it into the same connected layout, the same way a hand-drawn map would.
func _force_entrance_reachable(region: RegionLayout) -> void:
	region.mark_room_walkable(Rect2i(ENTRANCE_CELL - Vector2i(1, 1), Vector2i(3, 3)))

	if region.rooms.is_empty():
		return

	var nearest_center: = region.rooms[0].get_center()
	var nearest_distance: = ENTRANCE_CELL.distance_squared_to(nearest_center)
	for room in region.rooms:
		var center: = room.get_center()
		var distance: = ENTRANCE_CELL.distance_squared_to(center)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_center = center

	region.carve_corridor(ENTRANCE_CELL, nearest_center)


# Source 0 / atlas (0, 0) on kenney_terrain.tres is a plain, unblocked ground tile — the same one
# already used throughout Town — so the generated dungeon is walkable via the existing
# GameboardLayer.is_cell_clear() rule (a cell blocks movement unless a placed tile explicitly says
# otherwise) without needing any new tileset content.
func _paint(region: RegionLayout) -> void:
	for cell: Vector2i in region.walkable_cells:
		_ground.set_cell(cell, 0, Vector2i(0, 0))
