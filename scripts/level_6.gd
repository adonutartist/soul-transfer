extends Node2D
@onready var door: AnimatedSprite2D = $Map/Sprite2D
@onready var exit_trigger: Area2D = $ExitTrigger
@onready var player_spawn: Marker2D = $PlayerSpawn
@onready var enemies: Node2D = $Enemies

var remaining_enemies := 0
var door_opening := false
var door_unlocked := false
var loop_count := 0
var final_sequence_started := false

func _ready() -> void:
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
				enemy.died.connect(_on_enemy_died)
	if remaining_enemies == 0:
		_open_door()

func _on_enemy_died(_body: EnemyAI) -> void:
	remaining_enemies = maxi(0, remaining_enemies - 1)
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
	loop_count += 1
	if loop_count < 2:
		await _send_player_back_to_spawn(body)
	else:
		final_sequence_started = true
		exit_trigger.set_deferred("monitoring", false)
		print("Level6 final sequence shall begin :>")

func _send_player_back_to_spawn(player: Node2D) -> void:
	var world := get_parent()
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
