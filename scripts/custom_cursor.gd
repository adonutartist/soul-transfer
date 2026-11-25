extends CanvasLayer
@onready var cursor_sprite: AnimatedSprite2D = $CursorSprite
@onready var cursor_emission: AnimatedSprite2D = $CursorEmission

var pause_cursor_layer: CanvasLayer
var pause_cursor: AnimatedSprite2D

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	cursor_sprite.play("default")
	cursor_emission.play("default")
	pause_cursor_layer = CanvasLayer.new()
	pause_cursor_layer.name = "PauseCursorLayer"
	pause_cursor_layer.layer = 110
	pause_cursor_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child(pause_cursor_layer)
	pause_cursor = AnimatedSprite2D.new()
	pause_cursor.name = "PauseCursor"
	pause_cursor.sprite_frames = cursor_sprite.sprite_frames
	pause_cursor.scale = cursor_sprite.scale
	pause_cursor_layer.add_child(pause_cursor)
	pause_cursor.play("default")

func _process(_delta: float) -> void:
	var mouse_position := get_viewport().get_mouse_position()
	cursor_sprite.global_position = mouse_position
	cursor_emission.global_position = mouse_position
	if pause_cursor != null:
		pause_cursor.global_position = mouse_position
		pause_cursor.visible = get_tree().paused

func _exit_tree() -> void:
	if is_instance_valid(pause_cursor_layer):
		pause_cursor_layer.queue_free()
