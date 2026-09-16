## Tracks which fixed-size chunks of a [RegionLayout] should be "loaded" around a moving viewer.
##
## This prototype has no real per-chunk scene to instantiate (that only makes sense once actual
## game content exists per chunk), so "loaded" here means active/rendered rather than
## instantiated from disk — but the load-order, radius, and hysteresis logic is the same shape a
## real streaming system would use, and [signal chunk_loaded]/[signal chunk_unloaded] are the
## exact hook points a real loader would replace with [method ResourceLoader.load_threaded_request]
## and [method Node.queue_free].
class_name ChunkManager extends RefCounted

signal chunk_loaded(chunk_coord: Vector2i)
signal chunk_unloaded(chunk_coord: Vector2i)

var chunk_size: int = 8
## Chunks within this many chunk-widths of the viewer are loaded.
var load_radius: int = 1
## Chunks beyond this many chunk-widths are unloaded. Kept larger than [member load_radius] so a
## viewer sitting near a boundary doesn't thrash a chunk in and out every other frame.
var unload_radius: int = 2

var _loaded_chunks: Dictionary = {} # Vector2i (chunk coord) -> true


func cell_to_chunk_coord(cell: Vector2i) -> Vector2i:
	return Vector2i(floori(float(cell.x) / chunk_size), floori(float(cell.y) / chunk_size))


func get_loaded_chunks() -> Array[Vector2i]:
	var coords: Array[Vector2i] = []
	coords.assign(_loaded_chunks.keys())
	return coords


func is_chunk_loaded(chunk_coord: Vector2i) -> bool:
	return _loaded_chunks.has(chunk_coord)


## Re-evaluates which chunks should be loaded/unloaded given the viewer's current cell. Call this
## when the viewer moves to a new cell, not every frame — exactly like [method
## LandmarkRegistry.refresh_visibility] in the main game, this is cheap but has no reason to run at
## 60fps for something that only changes when someone actually walks somewhere.
func refresh(viewer_cell: Vector2i, region_bounds: Rect2i) -> void:
	var viewer_chunk: = cell_to_chunk_coord(viewer_cell)
	var region_chunk_min: = cell_to_chunk_coord(region_bounds.position)
	var region_chunk_max: = cell_to_chunk_coord(region_bounds.position + region_bounds.size)

	for x in range(region_chunk_min.x, region_chunk_max.x + 1):
		for y in range(region_chunk_min.y, region_chunk_max.y + 1):
			var chunk_coord: = Vector2i(x, y)
			var distance: = maxi(absi(chunk_coord.x - viewer_chunk.x),
				absi(chunk_coord.y - viewer_chunk.y))

			if distance <= load_radius and not is_chunk_loaded(chunk_coord):
				_loaded_chunks[chunk_coord] = true
				chunk_loaded.emit(chunk_coord)
			elif distance > unload_radius and is_chunk_loaded(chunk_coord):
				_loaded_chunks.erase(chunk_coord)
				chunk_unloaded.emit(chunk_coord)
