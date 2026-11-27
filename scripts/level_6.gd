extends Node2D
@onready var door: AnimatedSprite2D = $Map/Sprite2D
@onready var exit_trigger: Area2D = $ExitTrigger
@onready var player_spawn: Marker2D = $PlayerSpawn
@onready var enemies: Node2D = $Enemies
@onready var shopkeeper: Sprite2D = $Shopkeeper
@onready var final_figure: Sprite2D = $FinalFigure
@onready var gate_sprite: AnimatedSprite2D = $Map/Sprite2D

var remaining_enemies := 0
var door_opening := false
var door_unlocked := false
var loop_count := 0
var final_sequence_started := false
var shopkeeper_material: ShaderMaterial
var shopkeeper_target_scale: Vector2
var encounter_running := false
var counted_enemy_ids: Dictionary = {}

@export var gate_activation_range: float = 370.0
@export var shopkeeper_arrival_offset := Vector2(0, 350)

func _ready() -> void:
	shopkeeper.visible = false
	final_figure.visible = false
	shopkeeper_target_scale = shopkeeper.scale
	door.stop()
	door.frame = 0
	door.sprite_frames.set_animation_loop(&"default", false)
	exit_trigger.monitoring = false
	door.animation_finished.connect(_on_door_animation_finished)
	exit_trigger.body_entered.connect(_on_exit_trigger_body_entered)
	for enemy in enemies.get_children():
		if enemy is EnemyAI:
			if not enemy.dead_on_start and not enemy.is_dead:
				remaining_enemies += 1
				var enemy_id := enemy.get_instance_id()
				counted_enemy_ids[enemy_id] = true
				enemy.died.connect(_on_enemy_died)
	if remaining_enemies == 0:
		_open_door()

func _on_enemy_died(body: EnemyAI) -> void:
	var enemy_id := body.get_instance_id()
	if not counted_enemy_ids.has(enemy_id):
		return
	counted_enemy_ids.erase(enemy_id)
	remaining_enemies = maxi(0, remaining_enemies - 1)
	print("Level 6 enemies remaining: ", remaining_enemies)
	if remaining_enemies == 0:
		_open_door()

func _open_door() -> void:
	if door_opening:
		return
	door_opening = true
	door.play("default")

func _on_door_animation_finished() -> void:
	if door.animation != &"default":
		return
	door_unlocked = true
	exit_trigger.monitoring = true

func _on_exit_trigger_body_entered(body: Node2D) -> void:
	if not door_unlocked:
		return
	if not body.is_in_group("player"):
		return
	var distance_to_gate := body.global_position.distance_to(gate_sprite.global_position)
	if distance_to_gate > gate_activation_range:
		return
	if encounter_running:
		return
	loop_count += 1
	if loop_count < 2:
		await _send_player_back_to_spawn()
	else:
		encounter_running = true
		final_sequence_started = true
		exit_trigger.set_deferred("monitoring", false)
		await _play_shopkeeper_entrance()

func _send_player_back_to_spawn() -> void:
	var world := get_parent()
	var player := world.get_node_or_null("Player") as CharacterBody2D
	if player == null:
		push_error("Level 6 could not find the original Player")
		return
	world.transition_in_progress = true
	player.transitioning = true
	var fade: ColorRect = world.get_node("TransitionLayer/Fade")
	fade.color.a = 0.0
	var fade_out := world.create_tween()
	fade_out.tween_property(fade, "color:a", 1.0, 0.45)
	await fade_out.finished
	player.end_possession_for_level_transition()
	player.global_position = player_spawn.global_position
	player.velocity = Vector2.ZERO
	await get_tree().process_frame
	var fade_in := world.create_tween()
	fade_in.tween_property(fade, "color:a", 0.0, 0.6)
	await fade_in.finished
	player.transitioning = false
	world.transition_in_progress = false

func _create_white_blob() -> Polygon2D:
	var blob := Polygon2D.new()
	var points := PackedVector2Array()
	var segments := 40
	var radius := 20.0
	for i in range(segments):
		var angle := TAU * float(i) / float(segments)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	blob.polygon = points
	blob.color = Color.WHITE
	blob.z_index = 100
	blob.z_as_relative = false
	add_child(blob)
	return blob

func _make_white_shader() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
	shader_type canvas_item;
	uniform float white_amount: hint_range(0.0, 1.0) = 1.0;
	void fragment() {
		vec4 tex = texture(TEXTURE, UV);
		vec3 original = tex.rgb * COLOR.rgb;
		vec3 result = mix(original, vec3(1.0), white_amount);
		COLOR = vec4(result, tex.a * COLOR.a);
	}"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("white_amount", 1.0)
	return material

func _play_shopkeeper_entrance() -> void:
	var gate_position := gate_sprite.global_position
	var blob := _create_white_blob()
	blob.global_position = gate_position + Vector2(0, -15)
	blob.scale = Vector2(0.65, 0.65)
	var destination := gate_position + shopkeeper_arrival_offset
	var blob_tween := create_tween()
	blob_tween.set_parallel(true)
	blob_tween.tween_property(blob, "global_position", destination, 1.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	blob_tween.tween_property(blob, "scale", Vector2(3.5, 3.5), 1.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await blob_tween.finished
	shopkeeper.global_position = destination
	shopkeeper.scale = Vector2.ZERO
	shopkeeper.visible = true
	shopkeeper_material = _make_white_shader()
	shopkeeper.material = shopkeeper_material
	blob.queue_free()
	var shape_tween := create_tween()
	shape_tween.tween_property(shopkeeper, "scale", shopkeeper_target_scale, 0.9).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await shape_tween.finished
	await get_tree().create_timer(0.45).timeout
	var reveal_tween := create_tween()
	reveal_tween.tween_method(
		func(value: float):
			shopkeeper_material.set_shader_parameter("white_amount", value), 1.0, 0.0, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await reveal_tween.finished
	shopkeeper.material = null
