## A reference card listing every input action with a short explanation, opened from anywhere
## with the "help" action ([kbd]H[/kbd]) and closed the same way or with "back" ([kbd]Esc[/kbd]).
##
## Purely informational: unlike [PauseMenu]/[CharacterMenu] it layers on top of them instead of
## refusing to open while they're up, since knowing the controls is useful in any context. It only
## takes ownership of pausing the game if nothing else already has, and only releases it on close
## if nothing else still needs it — so it never fights with PauseMenu/CharacterMenu's own pause
## handling.
extends CanvasLayer

@onready var _panel_container: PanelContainer = %PanelContainer
@onready var _scroll_container: ScrollContainer = %ScrollContainer

# Sibling scenes whose own paused/visible state this modal must not clobber.
@onready var _pause_menu: CanvasLayer = get_parent().get_node_or_null("PauseMenu")
@onready var _character_menu: CanvasLayer = get_parent().get_node_or_null("CharacterMenu")
@onready var _game_over_screen: CanvasLayer = get_parent().get_node_or_null("GameOverScreen")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	_update_responsive_size()
	get_viewport().size_changed.connect(_update_responsive_size)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"help"):
		get_viewport().set_input_as_handled()
		if visible:
			close()
		elif not (_game_over_screen and _game_over_screen.visible):
			open()
	elif event.is_action_pressed(&"back") and visible:
		get_viewport().set_input_as_handled()
		close()


# Keeps the panel a sensible, readable size at any viewport size/aspect ratio. Mirrors
# PauseMenu._update_responsive_size().
func _update_responsive_size() -> void:
	var viewport_size: = get_viewport().get_visible_rect().size
	_panel_container.custom_minimum_size.x = clampf(viewport_size.x * 0.35, 460.0, 720.0)
	_scroll_container.custom_minimum_size.y = clampf(viewport_size.y * 0.7, 360.0, 760.0)


func open() -> void:
	visible = true
	get_tree().paused = true


func close() -> void:
	visible = false
	if not ((_pause_menu and _pause_menu.visible) or (_character_menu and _character_menu.visible)):
		get_tree().paused = false
