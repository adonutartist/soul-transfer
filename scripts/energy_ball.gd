extends Area2D
@export var speed := 100.0
@export var lifetime := 5.0

var direction := Vector2.RIGHT
var impacted := false
var owner_body: Node2D = null
var ground_layer: TileMapLayer
var ground_wall_layer: TileMapLayer

func _ready() -> void:
	ground_layer = get_tree().current_scene.find_child("Ground", true, false) as TileMapLayer
	ground_wall_layer = get_tree().current_scene.find_child("GroundWall", true, false) as TileMapLayer
	body_entered.connect(_on_body_entered)
	$AnimatedSprite2D.play("energy_ball")
	$EmissionSprite.visible = true
	$EmissionSprite.play("energy_ball")
	await get_tree().create_timer(lifetime).timeout
	if is_inside_tree() and not impacted:
		queue_free()

func _physics_process(delta):
	if not impacted:
		global_position += direction * speed * delta

func _on_body_entered(body: Node2D) -> void:
	if impacted:
		return
	if body == owner_body:
		return
	if body.is_in_group("player"):
		return
	if body is EnemyAI and body.is_dead:
		return
	_impact()

func _impact() -> void:
	if impacted:
		return
	impacted = true
	set_physics_process(false)
	monitoring = false
	$CollisionShape2D.set_deferred("disabled", true)
	$AnimatedSprite2D.hide()
	$EmissionSprite.hide()
	$Lens.hide()
	_spawn_destruction_effect()
	if ground_layer == null or ground_wall_layer == null:
		push_warning("EnergyBall: Ground or GroundWall TileMapLayer not found.")
		queue_free()
		return
	var positions: Array[Vector2] = []
	var attempts := 0
	var effect_count := randi_range(3, 4)
	while positions.size() < effect_count and attempts < effect_count * 15:
		attempts += 1
		var offset := Vector2.from_angle(randf() * TAU) * randf_range(12.0, 35.0)
		var pos := global_position + offset
		var cell := ground_layer.local_to_map(ground_layer.to_local(pos))
		if ground_layer.get_cell_source_id(cell) == -1:
			continue
		var wall_cell := ground_wall_layer.local_to_map(ground_wall_layer.to_local(pos))
		if ground_wall_layer.get_cell_source_id(wall_cell) != -1:
			continue
		var overlapping := false
		for existing in positions:
			if existing.distance_to(pos) < 28.0:
				overlapping = true
				break
		if overlapping:
			continue
		positions.append(pos)
	await get_tree().create_timer(0.5).timeout
	for i in range(positions.size()):
		var pos := positions[i]
		if i > 0:
			await get_tree().create_timer(randf_range(0.25, 0.55)).timeout
		_spawn_lightning_strike(pos)
		if randf() < 0.4:
			var second_offset := Vector2(
				randf_range(-30.0, 30.0),
				randf_range(-30.0, 30.0)
			)
			await get_tree().create_timer(randf_range(0.18, 0.35)).timeout
			_spawn_lightning_strike(pos + second_offset)
	queue_free()

func _spawn_destruction_effect() -> void:
	var effect_parent := get_parent()
	var normal := $DestroySprite.duplicate() as AnimatedSprite2D
	var emission := $DestroyEmission.duplicate() as AnimatedSprite2D
	var glow_material := ShaderMaterial.new()
	glow_material.shader = preload("res://materials/EnergyBall_Glow.gdshader")
	glow_material.set_shader_parameter("hdr_color", Color(0.12907735, 0.62275136, 0.7653253, 1.0))
	glow_material.set_shader_parameter("brightness", 15.0)
	emission.material = glow_material
	effect_parent.add_child(emission)
	effect_parent.add_child(normal)
	emission.global_position = global_position
	normal.global_position = global_position
	emission.visible = true
	normal.visible = true
	emission.z_index = 10
	normal.z_index = 10
	var normal_animation: StringName = normal.sprite_frames.get_animation_names()[0]
	var emission_animation: StringName = emission.sprite_frames.get_animation_names()[0]
	normal.animation_finished.connect(normal.queue_free)
	emission.animation_finished.connect(emission.queue_free)
	normal.play(normal_animation)
	emission.play(emission_animation)

func _spawn_lightning_strike(spawn_position: Vector2) -> void:
	var lightning := $LightningSprite.duplicate() as AnimatedSprite2D
	var ground := $LightningEmission.duplicate() as AnimatedSprite2D
	var glow_material := ShaderMaterial.new()
	glow_material.shader = preload("res://materials/Lightning_Glow.gdshader")
	glow_material.set_shader_parameter("hdr_color", Color(0.12907735, 0.62275136, 0.7653253, 1.0))
	glow_material.set_shader_parameter("brightness", 15.0)
	lightning.material = glow_material
	lightning.self_modulate = Color(1.8247963, 1.8247963, 1.8247963, 1.0)
	get_parent().add_child(lightning)
	get_parent().add_child(ground)
	lightning.global_position = spawn_position
	ground.global_position = spawn_position
	lightning.visible = true
	ground.visible = true
	lightning.animation_finished.connect(lightning.queue_free)
	ground.animation_finished.connect(ground.queue_free)
	lightning.play()
	ground.play()
