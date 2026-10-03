extends CharacterBody2D
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var target_area: Area2D = $TargetArea
@onready var target_particles: GPUParticles2D = $TargetParticles
@onready var soul_line_particles: GPUParticles2D = $SoulLineParticles
var is_dead := false
var reversing_death := false
var is_possessed := false
var can_be_selected := false
var soul_particle_timer: float = 0.0
var soul_dots: Array[Sprite2D] = []
var soul_dot_count: int = 30
signal selected

func _ready():
	sprite.animation_finished.connect(_on_animation_finished)
	target_area.input_event.connect(_on_target_area_input_event)
	sprite.play("death")
	target_particles.emitting = false
	target_particles.one_shot = false
	soul_line_particles.emitting = false
	soul_line_particles.visible = false
	create_target_texture()
	target_particles.material = preload("res://materials/soul_glow_material.tres").duplicate()
	soul_line_particles.material = preload("res://materials/soul_glow_material.tres").duplicate()
	target_particles.material.set_shader_parameter("tint", Color(0.0, 0.2, 1.0, 1.0))
	soul_line_particles.material.set_shader_parameter("tint", Color(0.0, 0.2, 1.0, 1.0))

func _on_animation_finished():
	if sprite.animation == "death" and not reversing_death:
		is_dead = true
		sprite.stop()
		sprite.frame = sprite.sprite_frames.get_frame_count("death") - 1

func _input_event(_viewport, event, _shape_idx): 
	if not is_dead:
		return
	if not can_be_selected:
		return
	var player = get_parent().get_node("Player")
	if global_position.distance_to(player.global_position) > player.warp_area.warp_radius:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			selected.emit()
			player.possess_mage(self)

func _on_target_area_input_event(_viewport, event, _shape_idx):
	if not is_dead:
		return
	if not can_be_selected:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var player = get_parent().get_node("Player")
			if global_position.distance_to(player.global_position) > player.warp_area.warp_radius:
				return
			selected.emit()
			player.possess_mage(self)

func _process(_delta):
	z_index = int(global_position.y)
	var player = get_parent().get_node("Player")
	var distance_to_player: float = global_position.distance_to(player.global_position)
	var in_range: bool = distance_to_player <= player.warp_area.warp_radius
	if can_be_selected and in_range:
		target_particles.emitting = true
		update_soul_chain()
	else:
		target_particles.emitting = false
		hide_soul_chain()

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
				Color(0.1, 0.45, 1.0, alpha)
			)
	var texture := ImageTexture.create_from_image(image)
	target_particles.texture = texture
	soul_line_particles.texture = texture

func create_soul_dots():
	var dot_texture := target_particles.texture
	for i in range(soul_dot_count):
		var dot := Sprite2D.new()
		dot.texture = dot_texture
		dot.scale = Vector2(0.3, 0.3)
		dot.modulate = Color(1.0, 1.0, 1.0, 0.8)
		dot.z_index = 100
		dot.visible = false
		add_child(dot)
		soul_dots.append(dot)

func update_soul_chain():
	var player = get_parent().get_node("Player")
	var target_mat := target_particles.process_material as ParticleProcessMaterial
	var target_radius: float = target_mat.emission_ring_radius
	target_mat.emission_ring_inner_radius = target_radius - 5.0
	var circle_center: Vector2 = target_particles.global_position
	var player_position: Vector2 = player.global_position
	var direction := (player_position - circle_center).normalized()
	if direction == Vector2.ZERO:
		soul_line_particles.emitting = false
		return
	var start := circle_center + direction * target_radius
	var end := player_position
	var line := end - start
	var line_length: float = line.length()
	if line_length <= 1.0:
		soul_line_particles.emitting = false
		return
	soul_line_particles.global_position = start + line * 0.5
	soul_line_particles.rotation = line.angle()
	var mat := soul_line_particles.process_material as ParticleProcessMaterial
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(
		line_length * 0.5,
		2.5,
		1.0
	)
	soul_line_particles.amount = 30
	soul_line_particles.lifetime = 0.15
	soul_line_particles.preprocess = 0.5
	soul_line_particles.local_coords = true
	soul_line_particles.emitting = true
	soul_line_particles.visible = true

func hide_soul_chain():
	soul_line_particles.emitting = false
	soul_line_particles.visible = false

func play_reverse_death():
	reversing_death = true
	is_dead = false
	var death_frames := sprite.sprite_frames.get_frame_count("death")
	sprite.visible = true
	sprite.animation = "death"
	sprite.frame = death_frames - 1
	sprite.play_backwards("death")
	await sprite.animation_finished
	sprite.play("idle")
	reversing_death = false
