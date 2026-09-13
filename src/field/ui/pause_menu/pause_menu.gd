## A pause menu, toggled with the "back" input action, that stops the game.
##
## Acts as a small hub: from here the player may resume, adjust display settings, check their
## Soul Strain status, browse their inventory, or quit the game. "Stato" and "Inventario" open as
## sub-pages of this same menu; "back" steps back one page at a time.
extends CanvasLayer

enum Page {HUB, STATUS, INVENTORY}

@onready var _hub_page: Control = %HubPage
@onready var _status_page: Control = %StatusPage
@onready var _inventory_page: Control = %InventoryPage

@onready var _vsync_check: CheckButton = %VSyncCheck
@onready var _fullscreen_check: CheckButton = %FullscreenCheck
@onready var _resume_button: Button = %ResumeButton
@onready var _status_button: Button = %StatusButton
@onready var _inventory_button: Button = %InventoryButton
@onready var _quit_button: Button = %QuitButton
@onready var _status_back_button: Button = %StatusBackButton
@onready var _inventory_back_button: Button = %InventoryBackButton

var _current_page: = Page.HUB


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	_vsync_check.button_pressed = Settings.vsync_enabled
	_fullscreen_check.button_pressed = Settings.fullscreen_enabled

	_vsync_check.toggled.connect(
		func(value: bool) -> void:
			Settings.vsync_enabled = value
	)
	_fullscreen_check.toggled.connect(
		func(value: bool) -> void:
			Settings.fullscreen_enabled = value
	)

	_resume_button.pressed.connect(close)
	_quit_button.pressed.connect(
		func() -> void:
			get_tree().quit()
	)
	_status_button.pressed.connect(_show_page.bind(Page.STATUS))
	_inventory_button.pressed.connect(_show_page.bind(Page.INVENTORY))
	_status_back_button.pressed.connect(_show_page.bind(Page.HUB))
	_inventory_back_button.pressed.connect(_show_page.bind(Page.HUB))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"back"):
		get_viewport().set_input_as_handled()
		if not visible:
			open()
		elif _current_page != Page.HUB:
			_show_page(Page.HUB)
		else:
			close()


func open() -> void:
	visible = true
	get_tree().paused = true
	_show_page(Page.HUB)


func close() -> void:
	visible = false
	get_tree().paused = false


func _show_page(page: Page) -> void:
	_current_page = page
	_hub_page.visible = page == Page.HUB
	_status_page.visible = page == Page.STATUS
	_inventory_page.visible = page == Page.INVENTORY

	if page == Page.HUB:
		_resume_button.grab_focus()
