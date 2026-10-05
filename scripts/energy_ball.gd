extends Area2D
@export var speed := 280.0
@export var lifetime := 5.0

var direction := Vector2.RIGHT

func _ready():
	$AnimatedSprite2D.play("energy_ball")
	$EmissionSprite.play("energy_ball")
	await get_tree().create_timer(lifetime).timeout
	queue_free()

func _physics_process(delta):
	global_position += direction * speed * delta
