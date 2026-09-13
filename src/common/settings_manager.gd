## Persists and applies user-configurable display and audio settings.
##
## Autoloaded as "Settings". Loads saved preferences on startup and immediately re-applies them to
## the [DisplayServer]/[AudioServer], so the window and volume match the player's choice from the
## very first frame.
extends Node

const SAVE_PATH: = "user://settings.cfg"

const MASTER_BUS: = &"Master"
const MUSIC_BUS: = &"Music"
const SFX_BUS: = &"SFX"

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

## Linear volume (0.0 to 1.0) for each bus. 0.0 mutes the bus entirely.
var master_volume: = 1.0:
	set(value):
		master_volume = clampf(value, 0.0, 1.0)
		_apply_bus_volume(MASTER_BUS, master_volume)
		_save()

var music_volume: = 1.0:
	set(value):
		music_volume = clampf(value, 0.0, 1.0)
		_apply_bus_volume(MUSIC_BUS, music_volume)
		_save()

var sfx_volume: = 1.0:
	set(value):
		sfx_volume = clampf(value, 0.0, 1.0)
		_apply_bus_volume(SFX_BUS, sfx_volume)
		_save()


func _ready() -> void:
	_load()
	_apply_vsync()
	_apply_fullscreen()
	_apply_bus_volume(MASTER_BUS, master_volume)
	_apply_bus_volume(MUSIC_BUS, music_volume)
	_apply_bus_volume(SFX_BUS, sfx_volume)


func _apply_vsync() -> void:
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if vsync_enabled else DisplayServer.VSYNC_DISABLED
	)


func _apply_fullscreen() -> void:
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen_enabled else DisplayServer.WINDOW_MODE_WINDOWED
	)


func _apply_bus_volume(bus_name: StringName, linear_volume: float) -> void:
	var bus_index: = AudioServer.get_bus_index(bus_name)
	if bus_index == -1:
		return

	AudioServer.set_bus_mute(bus_index, linear_volume <= 0.0)
	if linear_volume > 0.0:
		AudioServer.set_bus_volume_db(bus_index, linear_to_db(linear_volume))


func _load() -> void:
	var config: = ConfigFile.new()
	if config.load(SAVE_PATH) == OK:
		vsync_enabled = config.get_value("display", "vsync_enabled", vsync_enabled)
		fullscreen_enabled = config.get_value("display", "fullscreen_enabled", fullscreen_enabled)
		master_volume = config.get_value("audio", "master_volume", master_volume)
		music_volume = config.get_value("audio", "music_volume", music_volume)
		sfx_volume = config.get_value("audio", "sfx_volume", sfx_volume)


func _save() -> void:
	var config: = ConfigFile.new()
	config.set_value("display", "vsync_enabled", vsync_enabled)
	config.set_value("display", "fullscreen_enabled", fullscreen_enabled)
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("audio", "music_volume", music_volume)
	config.set_value("audio", "sfx_volume", sfx_volume)
	config.save(SAVE_PATH)
