## Shown when [signal SoulStrainEngine.game_over] fires (Soul Strain hit points reach 0).
##
## Stops the game and offers to retry (reload the field from scratch) or quit. While this screen
## is up, [PauseMenu] and [CharacterMenu] refuse to open on top of it (see their "back" handling).
extends CanvasLayer

@onready var _retry_button: Button = %RetryButton
@onready var _quit_button: Button = %QuitButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	var soul_strain: Node = get_tree().get_first_node_in_group(&"soul_strain_engine")
	if soul_strain:
		soul_strain.game_over.connect(open)

	_retry_button.pressed.connect(_on_retry_pressed)
	_quit_button.pressed.connect(
		func() -> void:
			get_tree().quit()
	)


func open() -> void:
	if visible:
		return

	visible = true
	get_tree().paused = true
	_retry_button.grab_focus()


func _on_retry_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()
