extends AnimatedSprite2D

@export var speed: float = 450.0
@export var damage: float = 3.0

var direction: Vector2 = Vector2.ZERO
var launched := false
var impacted := false
var tank_parent: Node2D
var owner_was_possessed: bool = false

@onready var hit_detector: Area2D = $HitDetector
@onready var hit_shape: CollisionShape2D = $HitDetector/CollisionShape2D

func _ready() -> void:
	tank_parent = get_parent() as Node2D
	visible = false
	hit_detector.body_entered.connect(_on_body_entered)
	animation_finished.connect(_on_animation_finished)

func launch(start_position: Vector2, target_position: Vector2) -> void:
	if not is_instance_valid(tank_parent):
		queue_free()
		return
	if get_parent() != tank_parent:
		reparent(tank_parent, true)
	owner_was_possessed = (tank_parent as EnemyAI).is_possessed
	var world_parent := tank_parent.get_parent().get_parent()
	reparent(world_parent, true)
	set_physics_process(true)
	global_position = start_position
	direction = (target_position - start_position).normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	rotation = direction.angle()
	impacted = false
	visible = true
	launched = true
	hit_shape.disabled = false
	hit_detector.monitoring = true
	play("axe_flying")

func _physics_process(delta: float) -> void:
	if launched and not impacted:
		global_position += direction * speed * delta

func _on_body_entered(body: Node2D) -> void:
	if not is_instance_valid(body):
		return
	if impacted:
		return
	if body is TileMapLayer and body.name == "Walls":
		_impact()
		return
	if body is not EnemyAI:
		return
	var target := body as EnemyAI
	if target.is_dead:
		return
	if target.is_possessed == owner_was_possessed:
		return
	target.take_damage(damage)
	_impact()

func _impact() -> void:
	if impacted:
		return
	impacted = true
	launched = false
	set_physics_process(false)
	hit_detector.monitoring = false
	hit_shape.set_deferred("disabled", true)
	play("axe_hit_ground")

func _on_animation_finished() -> void:
	if animation == "axe_hit_ground":
		await get_tree().create_timer(5.0).timeout
		if is_instance_valid(tank_parent):
			reparent(tank_parent, true)
			hide()
			launched = false
			impacted = false
			set_physics_process(false)
		else:
			queue_free()
		return
	if launched and not impacted:
		play("axe_flying")
