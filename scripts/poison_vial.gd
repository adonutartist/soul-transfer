extends Area2D
@export var speed: float = 350.0
@export var lifetime: float = 3.0
@export var damage: float = 2.0
@export var base_aoe_radius: float = 48.0

@onready var vial_sprite: AnimatedSprite2D = $VialSprite
@onready var explosion_sprite: AnimatedSprite2D = $ExplosionSprite

var impacted := false
var direction := Vector2.RIGHT
var launched := false
var owner_instance_id: int = 0
var owner_was_possessed := false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	vial_sprite.play("poison_flying")

func launch(start_position: Vector2, target_position: Vector2, owner: Node2D) -> void:
	global_position = start_position
	owner_instance_id = owner.get_instance_id()
	owner_was_possessed = owner.is_possessed
	direction = (target_position - start_position).normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	rotation = direction.angle()
	launched = true
	get_tree().create_timer(lifetime).timeout.connect(queue_free)

func _physics_process(delta: float) -> void:
	if launched:
		global_position += direction * speed * delta


func _on_body_entered(body: Node2D) -> void:
	if not launched or impacted:
		return
	if body.get_instance_id() == owner_instance_id:
		return
	if body is EnemyAI:
		if body.is_dead:
			return
		if body.is_in_group("player") == owner_was_possessed:
			return
		_impact(body)
		return
	if body.is_in_group("player") and not owner_was_possessed:
		_impact()
		return
	if body is TileMapLayer and body.name == "Walls":
		_impact()

func _apply_poison_splash(direct_target: EnemyAI = null) -> void:
	var aoe_multiplier := 2.0 if SoulManager.has_upgrade("poison_1") else 1.0
	var poison_duration := 10.0 if SoulManager.has_upgrade("poison_2") else 5.0
	var splash_radius := base_aoe_radius * aoe_multiplier
	var affected: Array[EnemyAI] = []
	if is_instance_valid(direct_target):
		affected.append(direct_target)
	for body in get_tree().get_nodes_in_group("enemies"):
		if not body is EnemyAI:
			continue
		if body.is_dead:
			continue
		if body.get_instance_id() == owner_instance_id:
			continue
		if body.is_in_group("player") == owner_was_possessed:
			continue
		if global_position.distance_to(body.global_position) > splash_radius:
			continue
		if not affected.has(body):
			affected.append(body)
	for body in affected:
		if not is_instance_valid(body) or body.is_dead:
			continue
		body.take_damage(damage, self)
		body.apply_poison(0.5, poison_duration)


func _impact(direct_target: EnemyAI = null) -> void:
	if impacted:
		return
	impacted = true
	launched = false
	set_physics_process(false)
	monitoring = false
	$CollisionShape2D.set_deferred("disabled", true)
	_apply_poison_splash(direct_target)
	vial_sprite.hide()
	var explosion := explosion_sprite.duplicate() as AnimatedSprite2D
	get_parent().add_child(explosion)
	explosion.global_position = global_position
	explosion.global_rotation = 0.0
	explosion.visible = true
	explosion.animation = "default"
	explosion.frame = 0
	explosion.animation_finished.connect(explosion.queue_free)
	explosion.play()
	queue_free()
