extends EnemyAI
class_name TankAI

const HOLD_DIST := 3.5
const SMASH_DISTANCE := 4.0
const AXE_SPEED_UNITS := 14.0

@export_flags_2d_physics var blocker_mask: int = 1

var _attack_timer: float = 0.0

func _on_alert_enter() -> void:
	_attack_timer = 0.5 + randf() * 0.75

func _tick_timers(delta: float) -> void:
	_attack_timer = maxf(0.0, _attack_timer - delta)

func _line_of_sight(target: Node2D) -> bool:
	var query := PhysicsRayQueryParameters2D.create(global_position, target.global_position, blocker_mask)
	query.exclude = [self]
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()

func _alerted_update(_delta: float) -> void:
	movement_dir = Vector2.ZERO
	var target := get_player()
	if target == null:
		return
	if target is EnemyAI and (target as EnemyAI).is_dead:
		return
	var distance := dist_to(target)
	if distance > HOLD_DIST:
		go_to(target.global_position)
		movement_dir = path_dir()
		print(
			"Tank:", global_position,
			" | Target:", target.global_position,
			" | Path direction:", movement_dir,
			" | Distance:", distance)
	if casting or bool(get("attacking")):
		movement_dir = Vector2.ZERO
		return
	if _attack_timer > 0.0:
		return
	if not _line_of_sight(target):
		return
	if distance <= SMASH_DISTANCE:
		if is_ability_ready(1):
			start_ability_cooldown(1, float(get("ice_smash_cooldown")))
			call("start_ice_smash", target.global_position)
			_attack_timer = 1.5
			return
	if is_ability_ready(0):
		start_ability_cooldown(0, float(get("axe_throw_cooldown")))
		var aim_position := lead_target(target, AXE_SPEED_UNITS)
		call("throw_axe_at", aim_position)
		_attack_timer = 1.5

func lead_target(target: Node2D, projectile_speed_units: float) -> Vector2:
	var target_velocity := Vector2.ZERO
	if target is CharacterBody2D:
		target_velocity = (target as CharacterBody2D).velocity / PX
	var target_position := target.global_position / PX
	var relative_position := target_position - global_position / PX
	var a := target_velocity.dot(target_velocity) - projectile_speed_units * projectile_speed_units
	var b := 2.0 * relative_position.dot(target_velocity)
	var c := relative_position.dot(relative_position)
	var discriminant := b * b - 4.0 * a * c
	if discriminant < 0.0 or is_zero_approx(a):
		return target.global_position
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
		return target.global_position
	return (target_position + target_velocity * travel_time) * PX
