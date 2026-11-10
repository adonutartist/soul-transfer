extends RogueAI
@export var is_possessable := true
@export var dash_distance: float = 150.0
@export var dash_duration: float = 0.22
@export var dash_cooldown: float = 2.0
@export var poison_cooldown: float = 3.0
@export var dash_end_offset: float = 20.0
@export var slash_damage: float = 2.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var slash_sprite: AnimatedSprite2D = $SlashSprite
@onready var poison_sprite: AnimatedSprite2D = $PoisonSprite
@onready var attack_area: Area2D = $AttackArea
@onready var attack_shape: CollisionShape2D = $AttackArea/CollisionShape2D
@onready var target_area: Area2D = $TargetArea
@onready var target_particles: GPUParticles2D = $TargetParticles
@onready var soul_line_particles: GPUParticles2D = $SoulLineParticles

var reversing_death := false
var can_be_selected := false
var just_possessed := false
var attacking := false
var mouse_over_corpse := false
var dash_ready := true
var poison_ready := true
var dash_slash_cooldown_timer: float = 0.0
var poison_throw_cooldown_timer: float = 0.0
var soul_transfer_active := false
var poison_vial_scene: PackedScene = preload("res://scenes/PoisonVial.tscn")
var slash_hit_bodies: Array[Node2D] = []
var slash_collision_exceptions: Array[EnemyAI] = []
var action_sequence: int = 0

signal selected

func _ready() -> void:
	super._ready()
	visual = sprite
	sprite.scale.x = absf(sprite.scale.x)
	add_to_group("possessable_bodies")
	sprite.animation_finished.connect(_on_animation_finished)
	target_area.input_event.connect(_on_target_area_input_event)
	target_area.mouse_entered.connect(_on_mouse_entered_corpse)
	target_area.mouse_exited.connect(_on_mouse_exited_corpse)
	slash_sprite.visible = false
	poison_sprite.visible = false
	attack_area.monitoring = false
	target_particles.emitting = false
	soul_line_particles.emitting = false
	soul_line_particles.visible = false
	var chain_texture := preload("res://assets/Sprites&Tiles/Chain.png")
	target_particles.texture = chain_texture
	soul_line_particles.texture = chain_texture
	target_particles.one_shot = false
	attack_area.body_entered.connect(_on_attack_area_body_entered)
	var target_mat := target_particles.process_material as ParticleProcessMaterial
	if target_mat:
		target_mat.scale_min = 0.1
		target_mat.scale_max = 0.4
	var soul_mat := soul_line_particles.process_material as ShaderMaterial
	if soul_mat:
		soul_mat.set_shader_parameter("scale_min", 0.1)
		soul_mat.set_shader_parameter("scale_max", 0.4)
	if target_particles.material is ShaderMaterial:
		target_particles.material.set_shader_parameter(
			"tint", Color(0.062, 0.733, 0.871, 1.0)
		)
	if soul_line_particles.material is ShaderMaterial:
		soul_line_particles.material.set_shader_parameter(
			"tint", Color(0.062, 0.733, 0.871, 1.0)
		)
	if not dead_on_start:
		sprite.play("idle")

func _update_facing() -> void:
	if movement_dir.x > 0.001:
		sprite.flip_h = false
	elif movement_dir.x < -0.001:
		sprite.flip_h = true

func _process(delta: float) -> void:
	if not is_dead and not is_possessed and not attacking:
		if movement_dir.length_squared() > 0.01:
			if sprite.animation != "walk":
				sprite.play("walk")
		else:
			if sprite.animation != "idle":
				sprite.play("idle")
	dash_slash_cooldown_timer = maxf(0.0, dash_slash_cooldown_timer - delta)
	poison_throw_cooldown_timer = maxf(0.0, poison_throw_cooldown_timer - delta)
	if dash_slash_cooldown_timer <= 0.0:
		dash_ready = true
	if poison_throw_cooldown_timer <= 0.0:
		poison_ready = true
	var player := get_parent().get_tree().get_first_node_in_group("player")
	if player == null:
		return
	if just_possessed:
		just_possessed = false
		return
	if is_possessed:
		target_particles.emitting = false
		hide_soul_chain()
		if not attacking and not reversing_death:
			if Input.is_action_just_pressed("mage_attack_left"):
				dash_slash()
			elif Input.is_action_just_pressed("mage_attack_right"):
				throw_poison()
		return
	if soul_transfer_active:
		return
	var in_range: bool = (
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
		_finish_corpse()

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

func _on_target_area_input_event(
	_viewport: Node, event: InputEvent, _shape_idx: int
) -> void:
	if not is_dead or not can_be_selected or is_possessed:
		return
	if event is InputEventMouseButton:
		if event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
			return
		var player := get_parent().get_tree().get_first_node_in_group("player")
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
	var player := get_parent().get_tree().get_first_node_in_group("player")
	if player == null:
		hide_soul_chain()
		return
	var target_mat := target_particles.process_material as ParticleProcessMaterial
	if target_mat == null:
		return
	var target_radius: float = target_mat.emission_ring_radius
	target_mat.emission_ring_inner_radius = target_radius - 5.0
	var circle_center := target_particles.global_position
	var player_position : Vector2 = player.global_position
	var direction := (player_position - circle_center).normalized()
	if direction == Vector2.ZERO:
		hide_soul_chain()
		return
	var start := circle_center + direction * target_radius
	var line := player_position - start
	var line_length := line.length()
	if line_length <= 1.0:
		hide_soul_chain()
		return
	soul_line_particles.global_position = start + line * 0.5
	soul_line_particles.rotation = line.angle()
	var mat := soul_line_particles.process_material as ShaderMaterial
	if mat:
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

func dash_slash(target_position: Vector2 = Vector2.ZERO) -> void:
	if attacking or not dash_ready or is_dead:
		return
	action_sequence += 1
	var sequence := action_sequence
	var ai_controlled := not is_possessed
	if is_possessed:
		target_position = get_global_mouse_position()
	elif target_position == Vector2.ZERO:
		return
	attacking = true
	dash_ready = false
	dash_slash_cooldown_timer = dash_cooldown
	slash_hit_bodies.clear()
	var direction := (target_position - global_position).normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	sprite.flip_h = direction.x < 0.0
	slash_sprite.flip_h = direction.x < 0.0
	var facing := signf(direction.x)
	if facing == 0.0:
		facing = 1.0
	attack_area.position.x = absf(attack_area.position.x) * facing
	attack_shape.position.x = absf(attack_shape.position.x) * facing
	sprite.visible = false
	slash_sprite.visible = true
	slash_sprite.play("dash_slash")
	attack_area.monitoring = true
	if is_possessed:
		var elapsed := 0.0
		while elapsed < dash_duration:
			if not is_inside_tree() or sequence != action_sequence or is_dead:
				return
			velocity = direction * (dash_distance / dash_duration)
			move_and_slide()
			elapsed += get_physics_process_delta_time()
			await get_tree().physics_frame
		velocity = Vector2.ZERO
	else:
		start_ai_dash(direction, dash_duration, dash_distance)
		await get_tree().create_timer(dash_duration).timeout
		if not is_inside_tree() or sequence != action_sequence or is_dead:
			return
	attack_area.monitoring = false
	_clear_slash_collision_exceptions()
	while slash_sprite.is_playing():
		if not is_inside_tree() or sequence != action_sequence or is_dead:
			return
		await get_tree().process_frame
	slash_sprite.visible = false
	sprite.visible = true
	sprite.play("idle")
	attacking = false

func throw_poison(target_position: Vector2 = Vector2.ZERO) -> void:
	if attacking or not poison_ready or is_dead:
		return
	action_sequence += 1
	var sequence := action_sequence
	if is_possessed:
		target_position = get_global_mouse_position()
	elif target_position == Vector2.ZERO:
		return
	attacking = true
	poison_ready = false
	poison_throw_cooldown_timer = poison_cooldown
	var direction := (target_position - global_position).normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	sprite.flip_h = direction.x < 0.0
	poison_sprite.flip_h = direction.x < 0.0
	sprite.visible = false
	poison_sprite.visible = true
	poison_sprite.play("poison_throw")
	while poison_sprite.animation == "poison_throw" and poison_sprite.frame < 3:
		if not is_inside_tree() or sequence != action_sequence or is_dead:
			return
		await get_tree().process_frame
	var vial := poison_vial_scene.instantiate()
	get_parent().add_child(vial)
	vial.launch(global_position, target_position, self)
	await poison_sprite.animation_finished
	if not is_inside_tree() or sequence != action_sequence or is_dead:
		return
	sprite.visible = true
	sprite.play("idle")
	poison_sprite.visible = false
	attacking = false

func _play_death() -> void:
	reversing_death = false
	sprite.play("death")

func _show_corpse_pose() -> void:
	reversing_death = false
	sprite.stop()
	sprite.animation = "death"
	sprite.frame = sprite.sprite_frames.get_frame_count("death") - 1

func _play_revive() -> void:
	play_reverse_death()

func _abort_actions() -> void:
	action_sequence += 1
	attacking = false
	attack_area.monitoring = false
	_clear_slash_collision_exceptions()
	hide_soul_chain()
	slash_sprite.visible = false
	poison_sprite.visible = false
	sprite.visible = true

func _on_attack_area_body_entered(body: Node2D) -> void:
	if not body is EnemyAI:
		return
	if body.is_dead:
		return
	if body.is_in_group("player") == is_possessed:
		return
	if slash_hit_bodies.has(body):
		return
	slash_hit_bodies.append(body)
	if not slash_collision_exceptions.has(body):
		add_collision_exception_with(body)
		slash_collision_exceptions.append(body)
	body.take_damage(slash_damage, self)

func _clear_slash_collision_exceptions() -> void:
	for body in slash_collision_exceptions:
		if is_instance_valid(body):
			remove_collision_exception_with(body)
	slash_collision_exceptions.clear()
