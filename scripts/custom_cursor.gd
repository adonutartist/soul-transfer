extends CanvasLayer
@onready var cursor_sprite: AnimatedSprite2D = $CursorSprite
@onready var cursor_emission: AnimatedSprite2D = $CursorEmission

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	cursor_sprite.play("default")
	cursor_emission.play("default")

func _process(_delta: float) -> void:
	cursor_sprite.global_position = get_viewport().get_mouse_position()
	cursor_emission.global_position = get_viewport().get_mouse_position()
