extends Area2D
@export var speed := 180.0
@export var lifetime := 3.0

var direction := Vector2.RIGHT
var launched := false

func _ready():
	$AnimatedSprite2D.play("fireball")
	await get_tree().create_timer(lifetime).timeout
	if is_inside_tree():
		queue_free()

func _physics_process(delta):
	if launched:
		global_position += direction * speed * delta
