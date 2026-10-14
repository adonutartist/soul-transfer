extends EnemyAI
class_name MageAI

const HOLD_DIST: float = 7.5
const FLEE_DIST: float = 4.0

@export_flags_2d_physics var blocker_mask: int = 1

var _attack_timer: float = 0.0
var _counter: int = 0
var _can_see: bool = false

func _on_alert_enter() -> void:
	_attack_timer = 0.5 + randf() * 0.75

func _line_of_sight(player: Node2D) -> bool:
	var query := PhysicsRayQueryParameters2D.create(
		global_position,
		player.global_position,
		blocker_mask
	)
	query.exclude = [self]
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()

func _tick_timers(delta: float) -> void:
	_attack_timer = maxf(0.0, _attack_timer - delta)

func _alerted_update(_delta: float) -> void:
	var player := get_player()
	if player == null:
		movement_dir = Vector2.ZERO
		return
	var distance: float = dist_to(player)
	_can_see = _line_of_sight(player)
	if distance < FLEE_DIST:
		movement_dir = (global_position - player.global_position).normalized()
	elif distance < HOLD_DIST and _can_see:
		movement_dir = Vector2.ZERO
	else:
		go_to(player.global_position)
		movement_dir = path_dir()
	if _can_see and _attack_timer <= 0.0:
		var result: Dictionary = try_enqueue(
			_counter,
			player.global_position
		)
		if result.get("did_cast", false):
			_attack_timer = (
				float(result.get("duration", 0.0))
				+ float(result.get("cooldown", 0.0))
				+ randf() * 0.75
			)
		_counter = (_counter + 1) % 2
