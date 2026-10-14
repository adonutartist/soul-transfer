extends EnemyAI
class_name RogueAI

const FLEE_DIST := 1.5
const CIRCLE_DIST := 3.0
const ATTACK_RANGE := 5.0
const COMBO_TIME := 0.6

var _attack_timer: float = 0.0
var _combo_timer: float = 0.0
var _circle_timer: float = 1.0
var _circle_left: bool = false

func _on_alert_enter() -> void:
	_attack_timer = 1.5 + randf()
	_circle_timer = 1.0

func _tick_timers(delta: float) -> void:
	_attack_timer -= delta
	_circle_timer -= delta
	if _circle_timer <= 0.0:
		_circle_timer = randf() * 2.0
		_circle_left = not _circle_left
	if _combo_timer > 0.0:
		_combo_timer -= delta
		if _combo_timer <= 0.0 and alerted:
			var player := get_player()
			if player != null:
				try_enqueue(1, player.global_position)

func _alerted_update(_delta: float) -> void:
	var player := get_player()
	if player == null:
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
	if distance < ATTACK_RANGE and _attack_timer <= 0.0:
		_attack_timer = 1.5 + randf()
		_combo_timer = COMBO_TIME
		try_enqueue(0, player.global_position)
