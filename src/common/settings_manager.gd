## Persists and applies user-configurable display settings.
##
## Autoloaded as "Settings". Loads saved preferences on startup and immediately re-applies them to
## the [DisplayServer], so the window matches the player's choice from the very first frame.
extends Node

const SAVE_PATH: = "user://settings.cfg"

var vsync_enabled: = true:
	set(value):
		vsync_enabled = value
		_apply_vsync()
		_save()

var fullscreen_enabled: = false:
	set(value):
		fullscreen_enabled = value
		_apply_fullscreen()
		_save()


func _ready() -> void:
	_load()
	_apply_vsync()
	_apply_fullscreen()


func _apply_vsync() -> void:
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if vsync_enabled else DisplayServer.VSYNC_DISABLED
	)


func _apply_fullscreen() -> void:
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen_enabled else DisplayServer.WINDOW_MODE_WINDOWED
	)


func _load() -> void:
	var config: = ConfigFile.new()
	if config.load(SAVE_PATH) == OK:
		vsync_enabled = config.get_value("display", "vsync_enabled", vsync_enabled)
		fullscreen_enabled = config.get_value("display", "fullscreen_enabled", fullscreen_enabled)


func _save() -> void:
	var config: = ConfigFile.new()
	config.set_value("display", "vsync_enabled", vsync_enabled)
	config.set_value("display", "fullscreen_enabled", fullscreen_enabled)
	config.save(SAVE_PATH)
