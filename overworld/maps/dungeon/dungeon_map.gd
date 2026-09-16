## Procedurally generates a dungeon layout at runtime with [BSPDungeonGenerator] (see
## `src/worldgen_prototype/`), then paints the result onto a sibling [GameboardLayer] so the
## existing [Gameboard]/[Pathfinder] pipeline treats it exactly like any hand-drawn area.
##
## A single script instanced with different exported values (bounds, seed, palette) drives every
## dungeon variant, the same way [AreaTransition] or [Landmark] are one script reused per-instance
## rather than one script per map. Nothing about the generator itself changes: the same seeded
## retry-with-fallback loop and [ConnectivityValidator] check still guarantee every generated room
## is reachable from every other one.
class_name DungeonMap extends Node2D

## Bounds are fixed, far-away cell coordinates so no two dungeon variants — and none of Town/House/
## Forest's hand-drawn areas (all of which stay within roughly x:-12..71, y:-8..42) — ever share a
## cell. Every [GameboardLayer] in this project shares one global cell space rather than each
## having its own local origin (their Node2D positions are all (0, 0)).
@export var region_bounds: = Rect2i(150, 0, 30, 20)

## Deterministic on purpose: a given variant looks the same every time it's entered in a given
## build, matching [BSPDungeonGenerator]'s own reproducibility guarantee (same seed, same layout).
@export var region_seed: int = 1

## Where the player always arrives (from Town or from the previous dungeon level), regardless of
## the generated layout. Forced walkable and connected below (see [method _force_cell_reachable])
## so this is never the one cell an unlucky seed stranded from the rest of the dungeon.
@export var entrance_cell: = Vector2i(152, 10)

## A second forced-reachable point used to chain dungeon variants together (a "descend further" or
## "way out" transition placed elsewhere in the scene). Left at (-1, -1) — an impossible cell,
## since [member region_bounds] never covers negative coordinates — when a variant has no such
## second point (e.g. a dead-end level whose only way out is back the way the player came in).
@export var exit_cell: = Vector2i(-1, -1)

## The floor and wall art below all comes from `overworld/maps/tilesets/dungeon_tilemap.png`,
## registered as source [member terrain_source_id] on the shared `kenney_terrain.tres` [TileSet]
## (alongside Town's tileset) but never painted anywhere until this feature — every atlas
## coordinate here was already hand-authored with walkable/blocked [TileData] custom data, so
## reusing it is just a matter of picking which coordinates to stamp.
@export var terrain_source_id: int = 1

## Floor variants to scatter across walkable cells for a less uniform look than a single repeated
## tile. All must be registered as *unblocked* tiles on [member terrain_source_id].
@export var floor_atlas_coords: Array[Vector2i] = [
	Vector2i(0, 4), Vector2i(1, 4), Vector2i(2, 4), Vector2i(3, 4), Vector2i(4, 4), Vector2i(5, 4),
]

## The wall tile stamped around the border of every walkable area. Must be registered as a
## *blocked* tile on [member terrain_source_id] — see [method _paint_walls].
@export var wall_atlas_coord: = Vector2i(3, 1)

@onready var _ground: GameboardLayer = $Ground


func _ready() -> void:
	var region: = BSPDungeonGenerator.generate(region_bounds, region_seed)
	_force_cell_reachable(region, entrance_cell)
	if exit_cell.x >= 0:
		_force_cell_reachable(region, exit_cell)
	_paint(region)


# BSPDungeonGenerator's retry+fallback loop guarantees every *generated* room connects to every
# other one, but a fixed entrance/exit point is ours, not the generator's — it isn't part of that
# guarantee. Carve a small room there and a straight corridor to the nearest generated room to fold
# it into the same connected layout, the same way a hand-drawn map would.
func _force_cell_reachable(region: RegionLayout, cell: Vector2i) -> void:
	# Find the nearest room BEFORE adding the forced cell's own room below — [method
	# RegionLayout.mark_room_walkable] appends to [member RegionLayout.rooms], so searching
	# afterwards would always find the just-added room itself at distance 0 and carve a
	# zero-length corridor, silently leaving the forced cell isolated unless a generated room
	# happened to already touch it by chance.
	var nearest_center: Vector2i = Vector2i.ZERO
	var nearest_distance: int = -1
	for room in region.rooms:
		var center: = room.get_center()
		var distance: = cell.distance_squared_to(center)
		if nearest_distance < 0 or distance < nearest_distance:
			nearest_distance = distance
			nearest_center = center

	region.mark_room_walkable(Rect2i(cell - Vector2i(1, 1), Vector2i(3, 3)))

	if nearest_distance >= 0:
		region.carve_corridor(cell, nearest_center)


func _paint(region: RegionLayout) -> void:
	_paint_floor(region)
	_paint_walls(region)


# Variant is picked with a seeded RNG (rather than randi()) so a given region_seed always paints
# the same floor pattern too, consistent with the rest of this generator's reproducibility
# guarantee — otherwise two players on the same build could see different-looking floors for
# "the same" dungeon.
func _paint_floor(region: RegionLayout) -> void:
	var rng: = RandomNumberGenerator.new()
	rng.seed = region_seed

	for cell: Vector2i in region.walkable_cells:
		var variant: = floor_atlas_coords[rng.randi() % floor_atlas_coords.size()]
		_ground.set_cell(cell, terrain_source_id, variant)


# Stamps a wall tile on every cell that is itself not walkable but touches a walkable cell, so
# rooms and corridors read as enclosed spaces instead of floor tiles floating in the engine's
# default clear color.
func _paint_walls(region: RegionLayout) -> void:
	var wall_cells: = {}
	for cell: Vector2i in region.walkable_cells:
		for direction in range(4):
			var neighbor: = cell + Vector2i(
				[1, -1, 0, 0][direction], [0, 0, 1, -1][direction]
			)
			if not region.is_walkable(neighbor):
				wall_cells[neighbor] = true

	for cell: Vector2i in wall_cells:
		_ground.set_cell(cell, terrain_source_id, wall_atlas_coord)
