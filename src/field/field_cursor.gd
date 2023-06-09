## Handles mouse/touch events for the field gamestate.
##
## The field cursor's role is to determine whether or not the input event occurs over a particular
## cell and how that cell should be highlighted.
class_name FieldCursor
extends TileMap

# Emitted whenever [member is_active] changes.
signal is_active_changed

## Emitted when the highlighted cell changes to a new value. An invalid cell is indicated by a value
## of [constant Gameboard.INVALID_CELL].
signal focus_changed(old_focus: Vector2i, new_focus: Vector2i)

## Emitted when a cell is selected via input event.
signal selected(selected_cell: Vector2i)

enum Images { DEFAULT, WARNING }

const TEXTURES: = {
	Images.DEFAULT: preload("res://assets/gui/cursors/cursor_default.png"),
	Images.WARNING: preload("res://assets/gui/cursors/cursor_default.png")
}

## The [Gameboard] object used to convert touch/mouse coordinates to game coordinates. The reference
## must be valid for the cursor to function properly.
@export var gameboard: Gameboard

## An active cursor will interact with the gameboard, whereas an inactive cursor will do nothing.
var is_active: = true:
	set(value):
		if not value == is_active:
			is_active = value
			if not is_active:
				set_focus(Gameboard.INVALID_CELL)
			
			set_process(is_active)
			set_physics_process(is_active)
			set_process_input(is_active)
			set_process_unhandled_input(is_active)
			
			is_active_changed.emit()

## The cursor may focus on any cell from those included in valid_cells.
## The valid cell list may be used to change what is 'highlightable' at any given moment (e.g. an
## ability that only affects neighbouring cells or limiting movement to a given direction).
## An empty valid_cells list will allow the cursor to select any cell.
var valid_cells: Array[Vector2i] = []:
	set = set_valid_cells

## The cell currently highlighted by the cursor.
##
## [br][br]A focus of [constant Gameboard.INVALID_CELL] indicates that there is no highlight.
var focus: = Gameboard.INVALID_CELL:
	set = set_focus


func _ready() -> void:
	assert(gameboard, "\n%s::initialize error - Invalid Gameboard reference!" % name)
	
	Input.set_custom_mouse_cursor(TEXTURES[Images.DEFAULT])
	
	# The cursor must be disabled by cinematic mode by responding to the following signals:
	FieldEvents.cinematic_mode_enabled.connect(_on_cinematic_mode_enabled)
	FieldEvents.cinematic_mode_disabled.connect(_on_cinematic_mode_disabled)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		get_viewport().set_input_as_handled()
		set_focus(_get_cell_under_mouse())
	
	elif event.is_action_released("select"):
		get_viewport().set_input_as_handled()
		
		selected.emit(_get_cell_under_mouse())
		FieldEvents.cell_selected.emit(_get_cell_under_mouse())


## Limit cursor selection to a particular subset of cells.
## [br][br][b]Note:[/b] Providing an empty array will allow any cell to be highlighted (negative to
## positive infinity). Default behaviour assumes that all cells are valid.
func set_valid_cells(cells: Array[Vector2i]) -> void:
	valid_cells = cells
	
	if _is_cell_invalid(focus):
		set_focus(Gameboard.INVALID_CELL)


## Change the highlighted cell to a new value. A value of [constant Gameboard.INVALID_CELL] will
## indicate that there is no highlighted cell.
## [br][br][b]Note:[/b] Values will be limited to [member valid_cells] if valid_cells is not empty.
## Values outside of valid_cells will not be focused.
func set_focus(value: Vector2i) -> void:
	if _is_cell_invalid(value):
		value = Gameboard.INVALID_CELL
	
	if value == focus:
		return
	
	var old_focus: = focus
	focus = value
	
	clear()
	
	if focus != Gameboard.INVALID_CELL:
		set_cell(0, focus, 0, Vector2(1, 5))
	
	focus_changed.emit(old_focus, focus)
	FieldEvents.cell_highlighted.emit(focus)


# Convert mouse/touch coordinates to a gameboard cell.
func _get_cell_under_mouse() -> Vector2i:
	# The mouse coordinates need to be corrected for any scale or position changes in the scene.
	var mouse_position: = ((get_global_mouse_position()-global_position) / global_scale)
	var cell_under_mouse: = gameboard.pixel_to_cell(mouse_position)
	
	if not gameboard.boundaries.has_point(cell_under_mouse):
		cell_under_mouse = Gameboard.INVALID_CELL
	
	return cell_under_mouse


# A wrapper for cell validity criteria.
func _is_cell_invalid(cell: Vector2i) -> bool:
	return not valid_cells.is_empty() and not cell in valid_cells


func _on_interaction_highlighted(image: Images, interaction: CollisionObject2D) -> void:
	pass


func _on_interaction_unhighlighted(interaction: CollisionObject2D) -> void:
	pass


# The cursor should not affect the field while in cinematic mode.
func _on_cinematic_mode_enabled() -> void:
	is_active = false


func _on_cinematic_mode_disabled() -> void:
	is_active = true
