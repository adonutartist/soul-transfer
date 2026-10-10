extends CharacterBody2D
@export var is_possessable := true
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
var mouse_over_corpse := false
var attacking := false
var just_possessed := false
var soul_transfer_active := false

signal selected

func _ready():
	add_to_group("possessable_bodies")
	sprite.animation_finished.connect(_on_animation_finished)
	target_area.input_event.connect(_on_target_area_input_event)
	target_area.mouse_entered.connect(_on_mouse_entered_corpse)
	target_area.mouse_exited.connect(_on_mouse_exited_corpse)
	sprite.play("death")
	var ember_texture = preload("res://assets/Sprites&Tiles/Chain.png")
	target_particles.texture = ember_texture
	soul_line_particles.texture = preload("res://assets/Sprites&Tiles/Chain.png")
	target_particles.emitting = false
	target_particles.one_shot = false
	soul_line_particles.emitting = false
	soul_line_particles.visible = false


	var target_mat := target_particles.process_material as ParticleProcessMaterial
	target_mat.scale_min = 0.1
	target_mat.scale_max = 0.4
	var soul_line_mat := soul_line_particles.process_material as ShaderMaterial
	soul_line_mat.set_shader_parameter("scale_min", 0.1)
	soul_line_mat.set_shader_parameter("scale_max", 0.4)
	target_particles.material.set_shader_parameter("tint", Color(0.062, 0.733, 0.871, 1.0))
	soul_line_particles.material.set_shader_parameter("tint", Color(0.062, 0.733, 0.871, 1.0))

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
			play_soul_transfer()
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
			play_soul_transfer()
			player.possess_mage(self)

func _process(_delta):
	z_index = int(global_position.y)
	var player = get_parent().get_node("Player")
	if is_possessed and not attacking and not just_possessed:
		if Input.is_action_just_pressed("mage_attack_right"):
			attack_right()
		if Input.is_action_just_pressed("mage_attack_left"):
			attack_left()
	if just_possessed:
		just_possessed = false
	if is_possessed:
		target_particles.emitting = false
		if not soul_transfer_active:
			hide_soul_chain()
		return
	if soul_transfer_active:
		return
	var distance_to_player: float = global_position.distance_to(player.global_position)
	var in_range: bool = distance_to_player <= player.warp_area.warp_radius
	if can_be_selected and in_range and mouse_over_corpse:
		target_particles.emitting = true
		update_soul_chain()
	else:
		target_particles.emitting = false
		hide_soul_chain()

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
	var mat := soul_line_particles.process_material as ShaderMaterial
	mat.set_shader_parameter(
		"line_half_length",
		line_length * 0.5
	)
	mat.set_shader_parameter(
		"line_half_width",
		2.5
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

func _on_mouse_entered_corpse():
	mouse_over_corpse = true
	if can_be_selected and is_dead and not is_possessed:
		target_particles.emitting = true

func _on_mouse_exited_corpse():
	mouse_over_corpse = false
	target_particles.emitting = false
	hide_soul_chain()

func attack_right():
	attacking = true
	var mouse_position := get_global_mouse_position()
	var direction := (mouse_position - global_position).normalized()
	sprite.visible = false
	$AttackSprite.visible = true
	$AttackSprite.play("slam")
	while $AttackSprite.frame < 11:
		await get_tree().process_frame
	var ball = preload("res://scenes/EnergyBall.tscn").instantiate()
	get_parent().add_child(ball)
	ball.global_position = global_position
	ball.direction = direction
	while $AttackSprite.frame < 15:
		await get_tree().process_frame
	sprite.visible = true
	$AttackSprite.visible = false
	attacking = false

func attack_left():
	attacking = true
	sprite.visible = false
	$AttackSprite.visible = true
	$AttackSprite.play("slam")
	var mouse_position := get_global_mouse_position()
	var direction := (mouse_position - global_position).normalized()
	var fireballs: Array[Area2D] = []
	var fireball_count := 8
	var circle_radius := 35.0
	for i in range(fireball_count):
		var fireball = preload("res://scenes/Fireball.tscn").instantiate()
		get_parent().add_child(fireball)
		var angle := (TAU / fireball_count) * i
		fireball.global_position = global_position + Vector2(cos(angle), sin(angle)) * circle_radius
		fireballs.append(fireball)
		await get_tree().create_timer(0.08).timeout
	while $AttackSprite.frame < 11:
		await get_tree().process_frame
	for fireball in fireballs:
		if is_instance_valid(fireball):
			var random_angle := deg_to_rad(randf_range(-0.5, 0.5))
			var random_speed := randf_range(280.0, 300.0)
			fireball.direction = direction.rotated(random_angle)
			fireball.speed = random_speed
			fireball.launched = true
	while $AttackSprite.frame < 15:
		await get_tree().process_frame
	sprite.visible = true
	$AttackSprite.visible = false
	attacking = false

func play_soul_transfer():
	soul_transfer_active = true
	var chain_shader := soul_line_particles.material as ShaderMaterial
	soul_line_particles.visible = true
	soul_line_particles.emitting = true
	chain_shader.set_shader_parameter("dissolve_position", -1.0)
	var duration := 10.0
	var elapsed := 0.0
	while elapsed < duration:
		await get_tree().process_frame
		if not is_inside_tree():
			return
		elapsed += get_process_delta_time()
		var progress := elapsed / duration
		chain_shader.set_shader_parameter(
			"dissolve_position",
			progress
		)
	soul_line_particles.emitting = false
	soul_line_particles.visible = false
	soul_transfer_active = false
