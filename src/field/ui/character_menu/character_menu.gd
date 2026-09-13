## The in-fiction character menu: Stato (Soul Strain status) and Inventario.
##
## Opened directly to a page with dedicated keys ([kbd]T[/kbd] for Stato, [kbd]I[/kbd] for
## Inventario) rather than through a hub, and pressing the other key while open just switches
## page. This is kept separate from [PauseMenu] (Esc), which holds display/system settings.
extends CanvasLayer

enum Page {STATUS, INVENTORY}

@onready var _status_page: Control = %StatusPage
@onready var _inventory_page: Control = %InventoryPage

# The pause menu is a sibling scene. We check its state so this menu can't be opened on top of it.
@onready var _pause_menu: CanvasLayer = get_parent().get_node_or_null("PauseMenu")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if _pause_menu and _pause_menu.visible:
		return

	if event.is_action_pressed(&"open_status"):
		get_viewport().set_input_as_handled()
		_open_page(Page.STATUS)
	elif event.is_action_pressed(&"open_inventory"):
		get_viewport().set_input_as_handled()
		_open_page(Page.INVENTORY)
	elif event.is_action_pressed(&"back") and visible:
		get_viewport().set_input_as_handled()
		close()


func close() -> void:
	visible = false
	get_tree().paused = false


func _open_page(page: Page) -> void:
	visible = true
	get_tree().paused = true
	_status_page.visible = page == Page.STATUS
	_inventory_page.visible = page == Page.INVENTORY
