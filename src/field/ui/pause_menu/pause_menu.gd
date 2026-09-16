## The system/options menu, toggled with the "back" input action ([kbd]Esc[/kbd]).
##
## This is deliberately separate from [CharacterMenu] (Stato/Inventario): it holds settings that
## live outside the game's fiction (display and audio options, quitting), not character
## information.
extends CanvasLayer

@onready var _master_volume_slider: HSlider = %MasterVolumeSlider
@onready var _music_volume_slider: HSlider = %MusicVolumeSlider
@onready var _sfx_volume_slider: HSlider = %SFXVolumeSlider
@onready var _vsync_check: CheckButton = %VSyncCheck
@onready var _fullscreen_check: CheckButton = %FullscreenCheck
@onready var _resume_button: Button = %ResumeButton
@onready var _quit_button: Button = %QuitButton
@onready var _save_button: Button = %SaveButton
@onready var _load_button: Button = %LoadButton
@onready var _save_status_label: Label = %SaveStatusLabel
@onready var _panel_container: PanelContainer = %PanelContainer
@onready var _scroll_container: ScrollContainer = %ScrollContainer

# The character menu and game over screen are sibling scenes. We check their state so that "back"
# doesn't open this menu on top of them, and so it can't be opened while one of them is up.
@onready var _character_menu: CanvasLayer = get_parent().get_node_or_null("CharacterMenu")
@onready var _game_over_screen: CanvasLayer = get_parent().get_node_or_null("GameOverScreen")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	_update_responsive_size()
	get_viewport().size_changed.connect(_update_responsive_size)

	_master_volume_slider.value = Settings.master_volume
	_music_volume_slider.value = Settings.music_volume
	_sfx_volume_slider.value = Settings.sfx_volume
	_vsync_check.button_pressed = Settings.vsync_enabled
	_fullscreen_check.button_pressed = Settings.fullscreen_enabled

	_master_volume_slider.value_changed.connect(
		func(value: float) -> void:
			Settings.master_volume = value
	)
	_music_volume_slider.value_changed.connect(
		func(value: float) -> void:
			Settings.music_volume = value
	)
	_sfx_volume_slider.value_changed.connect(
		func(value: float) -> void:
			Settings.sfx_volume = value
	)
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
	_save_button.pressed.connect(
		func() -> void:
			SaveGame.save_game()
			_save_status_label.text = "Partita salvata."
	)
	_load_button.pressed.connect(
		func() -> void:
			if SaveGame.has_save():
				SaveGame.load_game()
				_save_status_label.text = "Partita caricata."
			else:
				_save_status_label.text = "Nessun salvataggio trovato."
	)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"back"):
		if visible:
			get_viewport().set_input_as_handled()
			close()
		elif not ((_character_menu and _character_menu.visible)
				or (_game_over_screen and _game_over_screen.visible)):
			get_viewport().set_input_as_handled()
			open()


# Keeps the panel a sensible, readable size at any viewport size/aspect ratio: a percentage of
# the viewport, clamped between a minimum (readability floor on tiny/narrow windows) and a
# maximum (avoids an absurdly stretched dialog on ultrawide/large windows). The panel's own
# ScrollContainer takes over if content ever exceeds the clamped height.
func _update_responsive_size() -> void:
	var viewport_size: = get_viewport().get_visible_rect().size
	_panel_container.custom_minimum_size.x = clampf(viewport_size.x * 0.3, 460.0, 680.0)
	_scroll_container.custom_minimum_size.y = clampf(viewport_size.y * 0.7, 420.0, 820.0)


func open() -> void:
	visible = true
	get_tree().paused = true
	_resume_button.grab_focus()


func close() -> void:
	visible = false
	get_tree().paused = false
