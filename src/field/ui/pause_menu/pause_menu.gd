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

# The character menu (Stato/Inventario) is a sibling scene. We check its state so that "back"
# doesn't open this menu on top of it, and so it can't be opened while this one is up.
@onready var _character_menu: CanvasLayer = get_parent().get_node_or_null("CharacterMenu")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

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


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"back"):
		if visible:
			get_viewport().set_input_as_handled()
			close()
		elif not (_character_menu and _character_menu.visible):
			get_viewport().set_input_as_handled()
			open()


func open() -> void:
	visible = true
	get_tree().paused = true
	_resume_button.grab_focus()


func close() -> void:
	visible = false
	get_tree().paused = false
