extends CharacterBody2D
@export var is_possessable := true
@export var ice_smash_cooldown: float = 3.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var target_area: Area2D = $TargetArea
@onready var target_particles: GPUParticles2D = $TargetParticles
@onready var soul_line_particles: GPUParticles2D = $SoulLineParticles

var is_dead := false
var reversing_death := false
var is_possessed := false
var can_be_selected := false
var just_possessed := false
var attacking := false
var mouse_over_corpse := false
var ice_smash_ready := true
var ice_smash_scene: PackedScene = preload("res://scenes/IceSmash.tscn")
var ice_smash_active := false

signal selected

func _ready() -> void:
	add_to_group("possessable_bodies")
	sprite.animation_finished.connect(_on_animation_finished)
	target_area.input_event.connect(_on_target_area_input_event)
	target_area.mouse_entered.connect(_on_mouse_entered_corpse)
	target_area.mouse_exited.connect(_on_mouse_exited_corpse)
	var chain_texture := preload("res://assets/Sprites&Tiles/Chain.png")
	target_particles.texture = chain_texture
	soul_line_particles.texture = chain_texture
	target_particles.emitting = false
	target_particles.one_shot = false
	soul_line_particles.emitting = false
	soul_line_particles.visible = false
	var target_mat := target_particles.process_material as ParticleProcessMaterial
	target_mat.scale_min = 0.1
	target_mat.scale_max = 0.4
	var soul_mat := soul_line_particles.process_material as ShaderMaterial
	soul_mat.set_shader_parameter("scale_min", 0.1)
	soul_mat.set_shader_parameter("scale_max", 0.4)
	target_particles.material.set_shader_parameter(
		"tint", Color(0.062, 0.733, 0.871, 1.0)
	)
	soul_line_particles.material.set_shader_parameter(
		"tint", Color(0.062, 0.733, 0.871, 1.0)
	)
	sprite.play("death")

func _process(delta: float) -> void:
	z_index = int(global_position.y)
	var player := get_parent().get_node_or_null("Player")
	if player == null:
		return
	if just_possessed:
		just_possessed = false
		return
	if is_possessed:
		target_particles.emitting = false
		hide_soul_chain()
		if not attacking and Input.is_action_just_pressed("mage_attack_left"):
			start_ice_smash()
		if not attacking and Input.is_action_just_pressed("mage_attack_right"):
			throw_axe()
		return
	var in_range : bool = (
		global_position.distance_to(player.global_position) <= player.warp_area.warp_radius
	)
	if can_be_selected and is_dead and in_range and mouse_over_corpse:
		target_particles.emitting = true
		update_soul_chain()
	else:
		target_particles.emitting = false
		hide_soul_chain()

func _on_animation_finished() -> void:
	if sprite.animation == "death" and not reversing_death:
		is_dead = true
		sprite.stop()
		sprite.frame = sprite.sprite_frames.get_frame_count("death") - 1

func play_reverse_death() -> void:
	reversing_death = true
	is_dead = false
	sprite.visible = true
	sprite.animation = "death"
	sprite.frame = sprite.sprite_frames.get_frame_count("death") - 1
	sprite.play_backwards("death")
	await sprite.animation_finished
	if not is_inside_tree():
		return
	sprite.play("idle")
	reversing_death = false

func _on_target_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if not is_dead or not can_be_selected or is_possessed:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var player = get_parent().get_node_or_null("Player")
			if player == null:
				return
			if global_position.distance_to(player.global_position) > player.warp_area.warp_radius:
				return
			selected.emit()
			player.possess_mage(self)

func _on_mouse_entered_corpse() -> void:
	mouse_over_corpse = true

func _on_mouse_exited_corpse() -> void:
	mouse_over_corpse = false
	target_particles.emitting = false
	hide_soul_chain()

func update_soul_chain() -> void:
	var player := get_parent().get_node_or_null("Player")
	if player == null:
		hide_soul_chain()
		return
	var target_mat := target_particles.process_material as ParticleProcessMaterial
	var target_radius: float = target_mat.emission_ring_radius
	target_mat.emission_ring_inner_radius = target_radius - 5.0
	var circle_center: Vector2 = target_particles.global_position
	var player_position: Vector2 = player.global_position
	var direction := (player_position - circle_center).normalized()
	if direction == Vector2.ZERO:
		hide_soul_chain()
		return
	var start := circle_center + direction * target_radius
	var end := player_position
	var line := end - start
	var line_length: float = line.length()
	if line_length <= 1.0:
		hide_soul_chain()
		return
	soul_line_particles.global_position = start + line * 0.5
	soul_line_particles.rotation = line.angle()
	var mat := soul_line_particles.process_material as ShaderMaterial
	mat.set_shader_parameter("line_half_length", line_length * 0.5)
	mat.set_shader_parameter("line_half_width", 2.5)
	soul_line_particles.amount = 30
	soul_line_particles.lifetime = 0.15
	soul_line_particles.preprocess = 0.5
	soul_line_particles.local_coords = true
	soul_line_particles.emitting = true
	soul_line_particles.visible = true

func hide_soul_chain() -> void:
	soul_line_particles.emitting = false
	soul_line_particles.visible = false

func start_ice_smash() -> void:
	if not is_possessed or not ice_smash_ready or ice_smash_active:
		return
	ice_smash_ready = false
	ice_smash_active = true
	attacking = true
	var attack_sprite: AnimatedSprite2D = $AttackSprite
	var mouse_position := get_global_mouse_position()
	var facing_right := mouse_position.x >= global_position.x
	sprite.flip_h = not facing_right
	attack_sprite.flip_h = not facing_right
	sprite.visible = false
	attack_sprite.visible = true
	attack_sprite.play("sword_slam")
	await get_tree().create_timer(0.333).timeout
	if not is_inside_tree():
		return
	var smash = ice_smash_scene.instantiate()
	get_parent().add_child(smash)
	smash.start(global_position)
	await attack_sprite.animation_finished
	if not is_inside_tree():
		return
	sprite.visible = true
	sprite.play("idle")
	attack_sprite.visible = false
	attacking = false
	ice_smash_active = false
	await get_tree().create_timer(ice_smash_cooldown).timeout
	if is_inside_tree():
		ice_smash_ready = true

func throw_axe() -> void:
	if not is_possessed or attacking:
		return
	attacking = true
	var attack_sprite: AnimatedSprite2D = $AttackSprite
	var axe: AnimatedSprite2D = $FlyingAxe
	var mouse_position := get_global_mouse_position()
	var facing_right := mouse_position.x >= global_position.x
	sprite.flip_h = not facing_right
	attack_sprite.flip_h = not facing_right
	sprite.visible = false
	attack_sprite.visible = true
	attack_sprite.play("axe_throw")
	while attack_sprite.animation == "axe_throw" and attack_sprite.frame < 3:
		await get_tree().process_frame
	if not is_inside_tree():
		return
	axe.launch(global_position, mouse_position)
	await attack_sprite.animation_finished
	if not is_inside_tree():
		return
	sprite.visible = true
	sprite.play("idle")
	attack_sprite.visible= false
	attacking = false
