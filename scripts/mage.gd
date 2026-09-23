extends CharacterBody2D
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var target_area: Area2D = $TargetArea
@onready var target_particles: GPUParticles2D = $TargetParticles
@onready var soul_line_particles: GPUParticles2D = $SoulLineParticles
@onready var soul_light:  PointLight2D = $SoulLight
var is_dead := false
var is_possessed := false
var can_be_selected := false
var soul_particle_timer: float = 0.0
var soul_dots: Array[Sprite2D] = []
var soul_dot_count: int = 30
signal selected

func _ready():
	sprite.animation_finished.connect(_on_animation_finished)
	sprite.play("death")
	target_particles.emitting = false
	target_particles.one_shot = false
	soul_line_particles.emitting = false
	soul_line_particles.visible = false
	create_soul_light()
	create_target_texture()
	create_soul_dots()

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
	var player = get_parent().get_node("Player")
	if global_position.distance_to(player.global_position) > player.warp_area.warp_radius:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			selected.emit()
			player.possess_mage(self)

func _process(_delta):
	var player = get_parent().get_node("Player")
	var distance_to_player: float = global_position.distance_to(player.global_position)
	var in_range: bool = distance_to_player <= player.warp_area.warp_radius
	if can_be_selected and in_range:
		target_particles.emitting = true
		update_soul_chain()
		soul_light.visible = true
	else:
		target_particles.emitting = false
		hide_soul_chain()
		soul_light.visible = false

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
	var texture := ImageTexture.create_from_image(image)
	target_particles.texture = texture
	soul_line_particles.texture = texture

func create_soul_light():
	var radius: float = 90.0
	var padding: int = 40
	var size := int(radius * 2.0) + padding * 2
	var image := Image.create(
		size,
		size,
		false,
		Image.FORMAT_RGBA8
	)
	var center: Vector2 = Vector2(size, size) * 0.5
	for y in range(size):
		for x in range(size):
			var distance: float = Vector2(x, y).distance_to(center)
			var alpha: float = clampf(
				1.0 - distance / radius,
				0.0,
				1.0
			)
			alpha = alpha * alpha * alpha
			image.set_pixel(
				x,
				y,
				Color(0.15, 0.55, 1.0, alpha)
			)
	var texture: ImageTexture = ImageTexture.create_from_image(image)
	soul_light.texture = texture
	soul_light.energy = 0.6
	soul_light.position = Vector2.ZERO
	soul_light.visible = false

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
	var start: Vector2 = global_position
	var end: Vector2 = player.global_position
	var direction: Vector2 = end - start
	var distance: float = direction.length()
	if distance <= 1.0:
		hide_soul_chain()
		return 
	var perpendicular := Vector2(
		-direction.y,
		direction.x
	).normalized()
	for i in range(soul_dots.size()):
		var dot := soul_dots[i]
		var t: float = float(i) / float(soul_dots.size() - 1)
		t += sin(i * 2.37) * 0.015
		t = clampf(t, 0.0, 1.0)
		var time := Time.get_ticks_msec() * 0.003
		var wave_1 := sin(time + i * 1.7) * 6.0
		var wave_2 := sin(time * 1.7 + i * 3.1) * 3.0
		var offset := perpendicular * (wave_1 + wave_2)
		dot.global_position = start.lerp(end, t) + offset
		dot.visible = true

func hide_soul_chain():
	for dot in soul_dots:
		dot.visible = false

func play_reverse_death():
	sprite.stop()
	var death_frames := sprite.sprite_frames.get_frame_count("death")
	for frame in range(death_frames -1, -1, -1):
		sprite.frame = frame
		await  get_tree().create_timer(0.06).timeout
	sprite.play("idle")
