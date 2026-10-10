extends Area2D
@export var speed: float = 350.0
@export var lifetime: float = 3.0
@export var damage: float = 2.0

@onready var vial_sprite: AnimatedSprite2D = $VialSprite

var direction := Vector2.RIGHT
var launched := false
var hit_bodies: Array[Node2D] = []

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	vial_sprite.play("poison_flying")

func launch(start_position: Vector2, target_position: Vector2) -> void:
	global_position = start_position
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
	if not launched or body in hit_bodies:
		return
	hit_bodies.append(body)
	if body.has_method("take_damage"):
		body.take_damage(damage)
	queue_free()
