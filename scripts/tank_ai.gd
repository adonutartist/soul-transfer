extends EnemyAI
class_name TankAI

const HOLD_DIST := 1.5
const SMASH_DISTANCE := 4.0
const PROJECTILE_SPEED := 10.0

var _attack_timer: float = 0.0
var _counter: int = 0

func _on_alert_enter() -> void:
	_attack_timer = 0.5 + randf() * 0.75

func _tick_timers(delta: float) -> void:
	_attack_timer -= delta

func _alerted_update(_delta: float) -> void:
	var player := get_player()
	if player == null:
		return
	var distance := dist_to(player)
	if distance < HOLD_DIST:
		movement_dir = Vector2.ZERO
	else:
		go_to(player.global_position)
		movement_dir = path_dir()
	if _attack_timer > 0.0:
		return
	var aim := lead_target(player, PROJECTILE_SPEED)
	var result: Dictionary
	if distance < SMASH_DISTANCE:
		if _counter % 2 == 0 and primary_unlocked:
			result = try_enqueue(0, aim)
		else:
			result = try_enqueue(1, aim)
	else:
		result = try_enqueue(1, aim)
	if result.get("did_cast", false):
		_attack_timer = (
			result["cooldown"]
			+ result["duration"]
			+ 0.75 * randf()
		)
	_counter += 1

func lead_target(player: Node2D, projectile_speed_units: float) -> Vector2:
	var player_velocity := Vector2.ZERO
	if player is CharacterBody2D:
		player_velocity = (player as CharacterBody2D).velocity / PX
	var target_position := player.global_position / PX
	var relative_position := target_position - global_position / PX
	var a := player_velocity.dot(player_velocity) - projectile_speed_units * projectile_speed_units
	var b := 2.0 * relative_position.dot(player_velocity)
	var c := relative_position.dot(relative_position)
	var discriminant := b * b - 4.0 * a * c
	if discriminant < 0.0 or is_zero_approx(a):
		return player.global_position
	var root := sqrt(discriminant)
	var t1 := (-b - root) / (2.0 * a)
	var t2 := (-b + root) / (2.0 * a)
	var travel_time: float
	if t1 > 0.0 and t2 > 0.0:
		travel_time = minf(t1, t2)
	elif t1 > 0.0:
		travel_time = t1
	elif t2 > 0.0:
		travel_time = t2
	else:
		return player.global_position
	return (target_position + player_velocity * travel_time) * PX
