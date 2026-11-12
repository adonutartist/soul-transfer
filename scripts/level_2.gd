extends Node2D
@export var shop_scene: PackedScene
@export var souls_reward: int = 1
var souls_awarded: bool = false

@onready var door: AnimatedSprite2D = $Map/Sprite2D
@onready var exit_trigger: Area2D = $ExitTrigger

var remaining_enemies: int = 0
var door_opening: bool = false
var level_unlocked: bool = false

func _ready() -> void:
	door.stop()
	door.frame = 0
	door.sprite_frames.set_animation_loop(&"default", false)
	exit_trigger.monitoring = false
	door.animation_finished.connect(_on_door_animation_finished)
	exit_trigger.body_entered.connect(_on_exit_trigger_body_entered)
	for enemy in $Enemies.get_children():
		if enemy is EnemyAI:
			if not enemy.dead_on_start and not enemy.is_dead:
				remaining_enemies += 1
				enemy.died.connect(_on_enemy_died)
	print("Enemies remaining: ", remaining_enemies)
	if remaining_enemies == 0:
		_open_door()

func _on_enemy_died(_body: EnemyAI) -> void:
	remaining_enemies = maxi(0, remaining_enemies - 1)
	print("Enemies remaining: ", remaining_enemies)
	if remaining_enemies == 0:
		_open_door()

func _open_door() -> void:
	if door_opening:
		return
	door_opening = true
	door.play("default")

func _on_door_animation_finished() -> void:
	if door.animation == &"default":
		level_unlocked = true
		exit_trigger.monitoring = true
		if not souls_awarded:
			souls_awarded = true
			SoulManager.add_souls(souls_reward)
		print("Level 2 completed. Exit unlocked")

func _on_exit_trigger_body_entered(body: Node2D) -> void:
	if not level_unlocked:
		return
	if not body.is_in_group("player"):
		return
	if shop_scene == null:
		push_error("level 3 scene has not been assigned")
		return
	get_parent().change_level(shop_scene)
