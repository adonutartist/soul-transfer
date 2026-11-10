extends Area2D
@export var speed: float = 350.0
@export var lifetime: float = 3.0
@export var damage: float = 2.0

@onready var vial_sprite: AnimatedSprite2D = $VialSprite
@onready var explosion_sprite: AnimatedSprite2D = $ExplosionSprite

var impacted := false
var direction := Vector2.RIGHT
var launched := false
var hit_bodies: Array[Node2D] = []
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
		body.take_damage(damage, self)
		body.apply_poison(0.5, 5.0)
		_impact()
		return
	if body is TileMapLayer and body.name == "Walls":
		_impact()

func _impact() -> void:
	if impacted:
		return
	impacted = true
	launched = false
	set_physics_process(false)
	monitoring = false
	$CollisionShape2D.set_deferred("disabled", true)
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
