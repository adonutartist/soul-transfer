extends CharacterBody2D
class_name EnemyAI

signal died(body: EnemyAI)
signal became_corpse(body: EnemyAI)
signal possessed(body: EnemyAI)

const PX: float = 32.0

@export_group("Lifecycle")

@export var max_health: float = 5.0
@export var dead_on_start: bool = false
@export var speed: float = 2.0
@export var alert_radius: float = 6.0
@export var time_to_lose_detection: float = 2.0
@export var stopping_distance: float = 0.2
@export var visual: Node2D
@export var patrol_points: Array[Node2D] = []
@export var patrol_waits: Array[float] = []
@export var abilities: Array[Node] = []
@export var primary_unlocked: bool = true
@export var secondary_unlocked: bool = true

var alerted: bool = false
var is_dead: bool = false
var health: float = 5.0
var corpse_ready: bool = false
var casting: bool = false
var is_possessed: bool = false
var movement_dir: Vector2 = Vector2.ZERO
var _alert_timer: float = 0.0
var _was_alerted: bool = false
var _cooldowns: Array[float] = [0.0, 0.0, 0.0]
var _patrol_started: bool = false
var _patrol_idx: int = 0
var _patrol_wait_timer: float = 0.0
var _patrol_waiting: bool = false
var _patrol_stopped: bool = false

@onready var agent: NavigationAgent2D = $NavigationAgent2D
@onready var detector: Area2D = $PlayerDetector

func _ready() -> void:
	var shape_node := detector.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node == null:
		push_error(name + ": PlayerDetector needs a CollisionShape2D.")
		return
	var circle := CircleShape2D.new()
	circle.radius = alert_radius * PX
	shape_node.shape = circle
	agent.target_desired_distance = stopping_distance * PX
	add_to_group("enemies")
	health = max_health
	if dead_on_start:
		start_as_corpse.call_deferred()

func _physics_process(delta: float) -> void:
	if is_dead or is_possessed or is_in_group("player"):
		velocity = Vector2.ZERO
		return
	_tick_cooldowns(delta)
	_tick_timers(delta)
	_update_detection(delta)
	if casting:
		movement_dir = Vector2.ZERO
		velocity = Vector2.ZERO
		_was_alerted = alerted
		return
	if alerted:
		if not _was_alerted:
			_on_alert_enter()
		_alerted_update(delta)
	else:
		if _was_alerted:
			_patrol_started = false
			_patrol_stopped = false
			_patrol_wait_timer = 0.0
			_patrol_waiting = false
		_patrol_update(delta)
	_was_alerted = alerted
	_update_facing()
	velocity = movement_dir.normalized() * speed * PX
	move_and_slide()

func _tick_cooldowns(delta: float) -> void:
	for i in range(_cooldowns.size()):
		_cooldowns[i] = maxf(0.0, _cooldowns[i] - delta)

func _update_detection(delta: float) -> void:
	var player_in_range: bool = false
	for body in detector.get_overlapping_bodies():
		if body.is_in_group("player"):
			player_in_range = true
			break
	if player_in_range:
		alerted = true
		_alert_timer = time_to_lose_detection
	else:
		_alert_timer = maxf(0.0, _alert_timer - delta)
		if _alert_timer <= 0.0:
			alerted = false

func go_to(pos: Vector2) -> void:
	agent.target_position = pos

func path_dir() -> Vector2:
	if agent.is_navigation_finished():
		return Vector2.ZERO
	return (agent.get_next_path_position() - global_position).normalized()

func has_arrived() -> bool:
	return (
		agent.is_navigation_finished()
		or global_position.distance_to(agent.target_position)
		<= stopping_distance * PX
	)

func get_player() -> Node2D:
	return get_tree().get_first_node_in_group("player") as Node2D

func dist_to(node: Node2D) -> float:
	return global_position.distance_to(node.global_position) / PX

func _patrol_update(delta: float) -> void:
	movement_dir = Vector2.ZERO
	if patrol_points.is_empty() or _patrol_stopped:
		return
	if not _patrol_started:
		_patrol_started = true
		_patrol_idx = 0
		go_to(patrol_points[_patrol_idx].global_position)
	if _patrol_waiting:
		_patrol_wait_timer = maxf(0.0, _patrol_wait_timer - delta)
		if _patrol_wait_timer > 0.0:
			return
		_patrol_waiting = false
		_advance_patrol_point()
		return
	if has_arrived():
		var wait_time: float = 0.0
		if _patrol_idx < patrol_waits.size():
			wait_time = patrol_waits[_patrol_idx]
		if wait_time < 0.0:
			_patrol_stopped = true
			return
		if wait_time > 0.0:
			_patrol_wait_timer = wait_time
			_patrol_waiting = true
			return
		_advance_patrol_point()
		return
	movement_dir = path_dir()

func _advance_patrol_point() -> void:
	_patrol_idx = (_patrol_idx + 1) % patrol_points.size()
	go_to(patrol_points[_patrol_idx].global_position)

func try_enqueue(slot: int, target: Vector2) -> Dictionary:
	if slot < 0 or slot >= mini(abilities.size(), _cooldowns.size()):
		return {"did_cast": false}
	var ability: Node = abilities[slot]
	if not is_instance_valid(ability):
		return {"did_cast": false}
	if slot == 0 and not primary_unlocked:
		return {"did_cast": false}
	if slot == 1 and not secondary_unlocked:
		return {"did_cast": false}
	if _cooldowns[slot] > 0.0 or not ability.has_method("cast"):
		return {"did_cast": false}
	var cooldown: float = float(ability.get("cooldown"))
	var duration: float = float(ability.get("duration"))
	_cooldowns[slot] = cooldown
	ability.call("cast", self, target)
	return {
		"did_cast": true,
		"cooldown": cooldown,
		"duration": duration
	}

func take_damage(amount: float, _source: Node = null) -> void:
	if is_dead or amount <= 0.0:
		return
	health = maxf(0.0, health - amount)
	if health <= 0.0:
		die()

func die() -> void:
	if is_dead:
		return
	is_dead = true
	corpse_ready = false
	alerted = false
	casting = false
	movement_dir = Vector2.ZERO
	velocity = Vector2.ZERO
	_abort_actions()
	if abilities.size() > 2 and is_instance_valid(abilities[2]):
		abilities[2].call("cast", self, global_position)
	died.emit(self)
	_play_death()

func start_as_corpse() -> void:
	if is_dead:
		return
	is_dead = true
	corpse_ready = false
	alerted = false
	casting = false
	movement_dir = Vector2.ZERO
	velocity = Vector2.ZERO
	_show_corpse_pose()
	_finish_corpse()

func _finish_corpse() -> void:
	if corpse_ready:
		return
	corpse_ready = true
	became_corpse.emit(self)

func on_possessed() -> void:
	is_dead = false
	corpse_ready = false
	health = max_health
	is_possessed = true
	alerted = false
	casting = false
	movement_dir = Vector2.ZERO
	velocity = Vector2.ZERO
	add_to_group("player")
	_play_revive()
	possessed.emit(self)

func on_released() -> void:
	is_possessed = false
	remove_from_group("player")

func _play_death() -> void:
	_finish_corpse()

func _show_corpse_pose() -> void:
	pass

func _play_revive() -> void:
	pass

func _abort_actions() -> void:
	pass

func _on_damaged() -> void:
	pass

func _update_facing() -> void:
	if visual == null:
		return
	if movement_dir.x > 0.001:
		visual.scale.x = 1.0
	elif movement_dir.x < -0.001:
		visual.scale.x = -1.0

func _tick_timers(_delta: float) -> void:
	pass

func _on_alert_enter() -> void:
	pass

func _alerted_update(_delta: float) -> void:
	pass
