## Standalone test bed for the "Fondazione nuova" pillars (Mappa Ibrida / Generazione & Seed /
## Streaming & Chunking) — deliberately kept out of the main game scene while the generation
## strategy is still being proven out. Run this scene directly to try it.
##
## Controls: SPACE regenerates with a new random seed. Arrow keys move the "viewer" (a stand-in for
## the player) around the generated region, which drives the chunk manager exactly like the
## player's own movement would drive it in the real game.
extends Node2D

const CELL_PIXEL_SIZE: = 16
const REGION_SIZE: = Vector2i(48, 32)

@export var seed_value: int = 1

var _layout: RegionLayout
var _chunk_manager: ChunkManager
var _viewer_cell: Vector2i = Vector2i.ZERO
var _is_connected: bool = false


func _ready() -> void:
	_generate()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_select") or (event is InputEventKey and event.pressed
			and event.keycode == KEY_SPACE):
		seed_value = randi()
		_generate()
		queue_redraw()
		return

	var move: = Vector2i.ZERO
	if event.is_action_pressed("ui_up"):
		move = Vector2i.UP
	elif event.is_action_pressed("ui_down"):
		move = Vector2i.DOWN
	elif event.is_action_pressed("ui_left"):
		move = Vector2i.LEFT
	elif event.is_action_pressed("ui_right"):
		move = Vector2i.RIGHT

	if move != Vector2i.ZERO:
		var target: = _viewer_cell + move
		if _layout.is_walkable(target):
			_viewer_cell = target
			_chunk_manager.refresh(_viewer_cell, _layout.bounds)
			queue_redraw()


func _generate() -> void:
	var bounds: = Rect2i(Vector2i.ZERO, REGION_SIZE)
	_layout = BSPDungeonGenerator.generate(bounds, seed_value)
	_is_connected = ConnectivityValidator.all_rooms_reachable(_layout)

	_viewer_cell = _layout.rooms[0].get_center() if not _layout.rooms.is_empty() else Vector2i.ZERO
	_chunk_manager = ChunkManager.new()
	_chunk_manager.chunk_size = 8
	_chunk_manager.load_radius = 1
	_chunk_manager.unload_radius = 2
	_chunk_manager.refresh(_viewer_cell, _layout.bounds)
	queue_redraw()


func _draw() -> void:
	if not _layout:
		return

	# Unloaded chunks first (dim background), then loaded chunks (bright), then walkable cells on
	# top, so it's visually obvious which chunks the streaming system currently considers active.
	var region_chunk_min: = _chunk_manager.cell_to_chunk_coord(_layout.bounds.position)
	var region_chunk_max: = _chunk_manager.cell_to_chunk_coord(
		_layout.bounds.position + _layout.bounds.size
	)
	for x in range(region_chunk_min.x, region_chunk_max.x + 1):
		for y in range(region_chunk_min.y, region_chunk_max.y + 1):
			var chunk_coord: = Vector2i(x, y)
			var chunk_rect: = Rect2(
				Vector2(chunk_coord * _chunk_manager.chunk_size) * CELL_PIXEL_SIZE,
				Vector2(_chunk_manager.chunk_size, _chunk_manager.chunk_size) * CELL_PIXEL_SIZE
			)
			var color: = Color(0.2, 0.8, 0.4, 0.15) if _chunk_manager.is_chunk_loaded(chunk_coord) \
				else Color(0.5, 0.5, 0.5, 0.05)
			draw_rect(chunk_rect, color, true)
			draw_rect(chunk_rect, Color(1, 1, 1, 0.15), false, 1.0)

	for cell in _layout.walkable_cells:
		var cell_rect: = Rect2(Vector2(cell) * CELL_PIXEL_SIZE, Vector2.ONE * CELL_PIXEL_SIZE)
		draw_rect(cell_rect, Color(0.85, 0.78, 0.6), true)

	for room in _layout.rooms:
		var room_rect: = Rect2(Vector2(room.position) * CELL_PIXEL_SIZE,
			Vector2(room.size) * CELL_PIXEL_SIZE)
		draw_rect(room_rect, Color(0.6, 0.45, 0.25), false, 2.0)

	var viewer_center: = Vector2(_viewer_cell) * CELL_PIXEL_SIZE + Vector2.ONE * CELL_PIXEL_SIZE * 0.5
	draw_circle(viewer_center, CELL_PIXEL_SIZE * 0.35, Color(0.9, 0.2, 0.2))

	var status: = "Seed %d — %s — %d/%d celle percorribili — %d chunk caricati — SPAZIO: rigenera, frecce: muovi" % [
		seed_value,
		"CONNESSO" if _is_connected else "NON CONNESSO (fallback attivo)",
		_layout.walkable_cells.size(),
		REGION_SIZE.x * REGION_SIZE.y,
		_chunk_manager.get_loaded_chunks().size(),
	]
	draw_string(ThemeDB.fallback_font, Vector2(8, -12), status, HORIZONTAL_ALIGNMENT_LEFT, -1, 14,
		Color(0.9, 0.9, 0.9))
