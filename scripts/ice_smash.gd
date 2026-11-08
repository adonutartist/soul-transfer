extends Node2D
const PX := 32.0

@export var spike_scene: PackedScene
@export var base_damage := 3.0
@export var radius_units := 4.0
@export var range_multiplier := 1.0
@export var spike_count := 350
@export var ripple_duration := 0.5
@export var down_delay := 0.6
@export var slow_factor := 0.5
@export var slow_time := 2.0

@onready var damage_area: Area2D = $Damage
@onready var shape: CircleShape2D = $Damage/CollisionShape2D.shape

var is_ground: Callable
var is_blocked: Callable
var _elapsed := 0.0
var _next := 0
var _alive := 0
var _done_spawning := false
var _hit := {}
var ground_layer: TileMapLayer

func start(pos: Vector2) -> void:
	global_position = pos
	ground_layer = get_tree().current_scene.find_child(
		"Ground", true, false
	) as TileMapLayer
	if ground_layer == null:
		push_error("IceSmash: Ground TileMapLayer not found.")
		return
	shape = shape.duplicate(); $Damage/CollisionShape2D.shape = shape
	shape.radius = 0.0
	damage_area.body_entered.connect(_on_body)
	set_process(true)

func _process(delta: float) -> void:
	_elapsed += delta
	var per := ripple_duration / spike_count
	var r_max := radius_units * range_multiplier * PX
	while _next < spike_count and _elapsed >= _next * per:
		var t := float(_next) / float(spike_count - 1)
		var inner_radius := 1.1 * PX
		var dist := lerpf(inner_radius, r_max, sqrt(t))
		var ang := randf() * TAU
		var pos := global_position + Vector2(cos(ang), sin(ang)) * dist
		shape.radius = dist
		_spawn(pos, t)
		_next += 1
	if _next >= spike_count:
		_done_spawning = true
		_check_end()

func _pick_kind(t: float) -> String:
	var p_large := lerpf(0.5, 0.05, t)
	var p_med := lerpf(0.4, 0.1, t)
	var v := randf()
	if v < p_large: return "large"
	if v < p_large + p_med: return "medium"
	return "small"


func _spawn(pos: Vector2, t: float) -> void:
	var cell := ground_layer.local_to_map(ground_layer.to_local(pos))
	if ground_layer.get_cell_source_id(cell) == -1:
		return
	var s: IceSpike = spike_scene.instantiate()
	add_child(s)
	s.global_position = pos
	s.setup(_pick_kind(t), down_delay)
	_alive += 1
	s.finished.connect(func():
		_alive -= 1
		_check_end()
	)

func _check_end() -> void:
	if _done_spawning and _alive <= 0:
		queue_free()

func _on_body(body: Node2D) -> void:
	if body is not EnemyAI:
		return
	var target := body as EnemyAI
	var owner_body := get_parent() as EnemyAI
	if target.is_dead or target == owner_body:
		return
	if owner_body != null and target.is_possessed == owner_body.is_possessed:
		return
	if _hit.has(target):
		return
	_hit[target] = true
	target.take_damage(base_damage, owner_body)
	if target.has_method("apply_seed_multiplier"):
		target.apply_seed_multiplier(slow_factor, slow_time)
