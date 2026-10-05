extends Node2D
@export var warp_radius := 280.0
@export var ember_count := 400
@export var warp_duration: float = 3.0
@onready var particles: GPUParticles2D = $EmberParticles
@onready var warp_lights: PointLight2D = $WarpLights
var warp_active: bool = false
var warp_timer: float = 0.0

func _ready():
	particles.emitting = false
	particles.amount = 500
	particles.lifetime = 0.25
	particles.local_coords = true
	particles.emitting = false
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	mat.emission_ring_radius = 200.0
	mat.emission_ring_inner_radius = 198.0
	mat.direction = Vector3.ZERO
	mat.initial_velocity_min = 0.0
	mat.initial_velocity_max = 0.0
	mat.scale_min = 0.012
	mat.scale_max = 0.025
	particles.process_material = mat
	particles.material = preload("res://materials/soul_glow_material.tres")

func _process(delta):
	if warp_active:
		warp_timer -= delta / Engine.time_scale
		if warp_timer <= 0.0:
			hide_warp()
			warp_active = false

func create_warp_light():
	var radius: float = 200.0
	var padding: int = 60
	var size := int(radius * 2.0) + padding * 2
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
			var difference : float = abs(distance - radius)
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

func show_warp():
	visible = true
	particles.emitting = true
	warp_lights.visible = true
	warp_active = true
	warp_timer = warp_duration
	Engine.time_scale = 0.3

func hide_warp():
	Engine.time_scale = 1.0
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
