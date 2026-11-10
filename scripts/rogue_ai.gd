extends EnemyAI
class_name RogueAI

const FLEE_DIST := 1.5
const CIRCLE_DIST := 3.0
const ATTACK_RANGE := 5.0

var _attack_timer: float = 0.0
var _circle_timer: float = 1.0
var _circle_left: bool = false
var _next_attack_is_poison := true

var _ai_dash_timer: float = 0.0
var _ai_dash_direction := Vector2.ZERO
var _dash_original_speed: float = -1.0

func _on_alert_enter() -> void:
	_attack_timer = 1.0
	_circle_timer = 1.0

func _tick_timers(delta: float) -> void:
	_attack_timer = maxf(0.0, _attack_timer - delta)
	_circle_timer -= delta
	if _circle_timer <= 0.0:
		_circle_timer = randf() * 2.0
		_circle_left = not _circle_left
	if _ai_dash_timer > 0.0:
		_ai_dash_timer = maxf(0.0, _ai_dash_timer - delta)
		if _ai_dash_timer <= 0.0:
			if _dash_original_speed >= 0.0:
				speed = _dash_original_speed
			_dash_original_speed = -1.0

func start_ai_dash(direction: Vector2, duration: float, distance: float) -> void:
	_ai_dash_direction = direction
	_ai_dash_timer = duration
	_dash_original_speed = speed
	speed = distance / maxf(duration, 0.01) / PX

func _alerted_update(_delta: float) -> void:
	var player := get_player()
	if player == null:
		return
	if player is EnemyAI and player.is_dead:
		return
	if _ai_dash_timer > 0.0:
		movement_dir = _ai_dash_direction
		return
	if bool(get("attacking")) or casting:
		movement_dir = Vector2.ZERO
		return
	var distance := dist_to(player)
	var away := (global_position - player.global_position).normalized()
	if distance < FLEE_DIST:
		movement_dir = away
	elif distance < CIRCLE_DIST:
		if _circle_left:
			movement_dir = Vector2(-away.y, away.x)
		else:
			movement_dir = Vector2(away.y, -away.x)
	else:
		go_to(player.global_position)
		movement_dir = path_dir()
	if bool(get("attacking")) or casting:
		movement_dir = Vector2.ZERO
		return
	if distance > ATTACK_RANGE or _attack_timer > 0.0:
		return
	if _next_attack_is_poison:
		if not is_ability_ready(1):
			return
		start_ability_cooldown(1, float(get("poison_cooldown")))
		call("throw_poison", player.global_position)
	else:
		if not is_ability_ready(0):
			return
		start_ability_cooldown(0, float(get("dash_cooldown")))
		call("dash_slash", player.global_position)
	_next_attack_is_poison = not _next_attack_is_poison
	_attack_timer = 1.0
