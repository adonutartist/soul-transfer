extends CharacterBody2D
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var target_area: Area2D = $TargetArea
@onready var target_particles: GPUParticles2D = $TargetParticles
var is_dead := false
var is_possessed := false
var can_be_selected := false
signal selected

func _ready():
	sprite.animation_finished.connect(_on_animation_finished)
	sprite.play("death")
	target_particles.emitting = false
	create_target_texture()

func _on_animation_finished():
	if sprite.animation == "death":
		is_dead = true
		sprite.stop()
		sprite.frame = sprite.sprite_frames.get_frame_count("death") - 1

func _input_event(_viewport, event, _shape_idx): 
	if not is_dead:
		return
	if not can_be_selected:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			selected.emit()

func create_target_texture():
	var size : int = 32
	var image : Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center : Vector2 = Vector2(size, size) * 0.5
	for y in range(size):
		for x in range(size):
			var pixel_position: Vector2 = Vector2(x, y)
			var pixel_distance: float = pixel_position.distance_to(center)
			var alpha: float = clampf(1.0 - pixel_distance / 16.0, 0.0, 1.0)
			alpha = alpha * alpha
			image.set_pixel(
				x,
				y,
				Color(0.25, 0.7, 1.0, alpha)
			)
	target_particles.texture = ImageTexture.create_from_image(image)
