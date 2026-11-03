extends EnemyAI
class_name MageAI

const HOLD_DIST: float = 7.5
const FLEE_DIST: float = 4.0

@export_flags_2d_physics var blocker_mask: int = 1

var _attack_timer: float = 0.0
var _counter: int = 0
var _can_see: bool = false
var next_attack_is_fireball := true

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
	movement_dir = Vector2.ZERO

	var player := get_player()
	if player == null:
		return

	_can_see = _line_of_sight(player)

	if not _can_see or _attack_timer > 0.0 or casting:
		return

	if next_attack_is_fireball:
		call("attack_left", player.global_position)
	else:
		call("attack_right", player.global_position)

	next_attack_is_fireball = not next_attack_is_fireball
	_attack_timer = 2.5
