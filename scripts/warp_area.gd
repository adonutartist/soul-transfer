extends Node2D
@export var warp_radius := 250.0
@export var ember_count := 400
@export var warp_duration: float = 3.0
@onready var particles: GPUParticles2D = $EmberParticles
@onready var warp_lights: PointLight2D = $WarpLights
var warp_active: bool = false
var warp_timer: float = 0.0

func _ready():
	particles.emitting = false
	particles.amount = ember_count
	particles.lifetime = 2.5
	particles.local_coords = true
	create_ember_texture()
	create_warp_light()

func _process(delta):
	if warp_active:
		warp_timer -= delta
		if warp_timer <= 0.0:
			hide_warp()
			warp_active = false

func create_warp_light():
	var padding: int = 60
	var size := int(warp_radius * 2.0) + padding * 2
	var image := Image.create(
		size,
		size,
		false,
		Image.FORMAT_RGBA8
	)
	var center : Vector2 = Vector2(size, size) * 0.5
	for y in range(size):
		for x in range(size):
			var distance : float = Vector2(x, y).distance_to(center)
			var difference : float = abs(distance - warp_radius)
			var alpha : float = clampf(
				1.0 - difference / 70.0,
				0.0,
				1.0
			)
			alpha = alpha * alpha * alpha
			image.set_pixel(
				x,
				y,
				Color(1.0, 0.65, 0.15, alpha)
			)
	var texture : ImageTexture = ImageTexture.create_from_image(image)
	warp_lights.texture = texture
	warp_lights.energy = 0.6
	warp_lights.position = Vector2.ZERO
	warp_lights.visible = false

func create_ember_texture():
	var size: int = 64
	var image : Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center : Vector2 = Vector2(size, size) * 0.5
	var max_distance: float = size * 0.7
	for y in range(size):
		for x in range(size):
			var distance: float = Vector2(x, y).distance_to(center)
			var t: float = clampf(distance / max_distance, 0.0, 1.0)
			var color: Color
			if t < 0.25:
				color = Color(1.0, 1.0, 0.9, 1.0)
			elif t < 0.5:
				color = Color(1.0, 0.85, 0.25, 1.0)
			elif t < 0.8:
				color = Color(1.0, 0.45, 0.05, 0.7)
			else:
				var alpha: float = 1.0 - t
				color = Color(1.0, 0.25, 0.02, alpha)
			image.set_pixel(x, y, color)
	var texture: ImageTexture = ImageTexture.create_from_image(image)
	particles.texture = texture

func show_warp():
	visible = true
	particles.emitting = true
	warp_lights.visible = true
	warp_active = true
	warp_timer = warp_duration

func hide_warp():
	visible = false
	particles.emitting = false
	warp_lights.visible = false
	var tween := get_parent().create_tween()
	tween.tween_property(
		get_parent().camera,
		"zoom",
		get_parent().normal_zoom,
		0.35
	)
