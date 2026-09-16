## Generates a room-and-corridor dungeon layout via Binary Space Partitioning, from a deterministic
## seed — the same seed always produces the same layout, which matters for save-compatibility
## (regenerating a chunk on load must reproduce exactly what the player saw before).
##
## [method generate] never returns a layout that fails [ConnectivityValidator]: it retries with a
## derived seed up to [constant MAX_ATTEMPTS] times, then falls back to a single guaranteed room
## rather than ever handing back something unplayable.
class_name BSPDungeonGenerator extends RefCounted

const MAX_ATTEMPTS: = 8
const MIN_PARTITION_SIZE: = 6
const ROOM_MARGIN: = 1


## Generates a validated layout for a [param bounds]-sized region. [param region_seed] makes the
## whole region (including its retry sequence) fully reproducible.
static func generate(bounds: Rect2i, region_seed: int) -> RegionLayout:
	for attempt in range(MAX_ATTEMPTS):
		var rng: = RandomNumberGenerator.new()
		rng.seed = hash("%d:%d" % [region_seed, attempt])

		var layout: = _generate_once(bounds, rng)
		if ConnectivityValidator.all_rooms_reachable(layout):
			return layout

	push_warning("BSPDungeonGenerator: no valid layout for seed %d after %d attempts; " %
		[region_seed, MAX_ATTEMPTS] + "falling back to a single room.")
	return _fallback_single_room(bounds)


static func _generate_once(bounds: Rect2i, rng: RandomNumberGenerator) -> RegionLayout:
	var layout: = RegionLayout.new()
	layout.bounds = bounds

	var leaves: Array[Rect2i] = []
	_split(bounds, rng, leaves)

	var room_centers: Array[Vector2i] = []
	for leaf in leaves:
		var room: = _carve_room(leaf, rng)
		layout.mark_room_walkable(room)
		room_centers.append(room.get_center())

	# Connecting each room to the next in traversal order forms one continuous chain, which is
	# connected by construction — ConnectivityValidator should always pass on the first attempt
	# for this particular strategy. The retry loop in generate() stays in place anyway: it's the
	# safety net that keeps paying off if this corridor strategy is later swapped for one that
	# only links spatially-nearby rooms (where a stray leaf really could end up isolated).
	for i in range(1, room_centers.size()):
		layout.carve_corridor(room_centers[i - 1], room_centers[i])

	return layout


# Recursively splits [param area] into leaf partitions, appending each leaf to [param out_leaves].
static func _split(area: Rect2i, rng: RandomNumberGenerator, out_leaves: Array[Rect2i]) -> void:
	var can_split_horizontally: = area.size.x > MIN_PARTITION_SIZE * 2
	var can_split_vertically: = area.size.y > MIN_PARTITION_SIZE * 2

	if not can_split_horizontally and not can_split_vertically:
		out_leaves.append(area)
		return

	var split_horizontally: = can_split_horizontally
	if can_split_horizontally and can_split_vertically:
		split_horizontally = rng.randf() < 0.5

	if split_horizontally:
		var split_x: = rng.randi_range(MIN_PARTITION_SIZE, area.size.x - MIN_PARTITION_SIZE)
		var left: = Rect2i(area.position, Vector2i(split_x, area.size.y))
		var right: = Rect2i(area.position + Vector2i(split_x, 0),
			Vector2i(area.size.x - split_x, area.size.y))
		_split(left, rng, out_leaves)
		_split(right, rng, out_leaves)
	else:
		var split_y: = rng.randi_range(MIN_PARTITION_SIZE, area.size.y - MIN_PARTITION_SIZE)
		var top: = Rect2i(area.position, Vector2i(area.size.x, split_y))
		var bottom: = Rect2i(area.position + Vector2i(0, split_y),
			Vector2i(area.size.x, area.size.y - split_y))
		_split(top, rng, out_leaves)
		_split(bottom, rng, out_leaves)


# Carves a room somewhere inside a leaf partition, leaving at least ROOM_MARGIN cells of empty
# space around it so rooms from neighboring leaves never touch by accident.
static func _carve_room(leaf: Rect2i, rng: RandomNumberGenerator) -> Rect2i:
	var max_width: = maxi(2, leaf.size.x - ROOM_MARGIN * 2)
	var max_height: = maxi(2, leaf.size.y - ROOM_MARGIN * 2)

	var room_width: = rng.randi_range(mini(2, max_width), max_width)
	var room_height: = rng.randi_range(mini(2, max_height), max_height)

	var max_offset_x: = leaf.size.x - room_width - ROOM_MARGIN
	var max_offset_y: = leaf.size.y - room_height - ROOM_MARGIN
	var offset_x: = rng.randi_range(ROOM_MARGIN, maxi(ROOM_MARGIN, max_offset_x))
	var offset_y: = rng.randi_range(ROOM_MARGIN, maxi(ROOM_MARGIN, max_offset_y))

	return Rect2i(leaf.position + Vector2i(offset_x, offset_y), Vector2i(room_width, room_height))


static func _fallback_single_room(bounds: Rect2i) -> RegionLayout:
	var layout: = RegionLayout.new()
	layout.bounds = bounds
	var room: = Rect2i(bounds.position + Vector2i.ONE, bounds.size - Vector2i(2, 2))
	layout.mark_room_walkable(room)
	return layout
