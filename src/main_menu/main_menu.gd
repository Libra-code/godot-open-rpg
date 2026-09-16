## The game's boot screen (see `run/main_scene` in project.godot). Lets the player start a fresh
## game or resume a previous one, instead of `main.tscn`'s fixed starting state being the only way
## into the game.
extends Control

const MAIN_SCENE: = "res://src/main.tscn"

@onready var _continue_button: Button = %ContinueButton
@onready var _new_game_button: Button = %NewGameButton
@onready var _quit_button: Button = %QuitButton


func _ready() -> void:
	_continue_button.disabled = not SaveGame.has_save()

	if _continue_button.disabled:
		_new_game_button.grab_focus()
	else:
		_continue_button.grab_focus()

	_new_game_button.pressed.connect(_on_new_game_pressed)
	_continue_button.pressed.connect(_on_continue_pressed)
	_quit_button.pressed.connect(func() -> void: get_tree().quit())


func _on_new_game_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_SCENE)


func _on_continue_pressed() -> void:
	SaveGame.pending_load = true
	get_tree().change_scene_to_file(MAIN_SCENE)
