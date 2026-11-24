extends Node

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel") or event.is_echo():
		return
	var world := get_parent()
	if world.transition_in_progress:
		return
	if world.pause_menu_open:
		world._resume_game()
	else:
		world._open_pause_menu()
	get_viewport().set_input_as_handled()
