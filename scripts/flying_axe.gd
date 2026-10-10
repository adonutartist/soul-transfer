extends AnimatedSprite2D

@export var speed: float = 450.0
@export var damage: float = 3.0

var direction: Vector2 = Vector2.ZERO
var launched := false

func _ready() -> void:
	visible = false
	animation_finished.connect(_on_animation_finished)

func launch(start_position: Vector2, target_position: Vector2) -> void:
	global_position = start_position
	direction = (target_position - start_position).normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	rotation = direction.angle()
	visible = true
	launched = true
	play("axe_flying")

func _physics_process(delta: float) -> void:
	if launched:
		global_position += direction * speed * delta

func _on_animation_finished() -> void:
	if launched:
		play("axe_flying")
