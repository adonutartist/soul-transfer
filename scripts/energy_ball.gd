extends Area2D
@export var speed := 100.0
@export var lifetime := 5.0

var direction := Vector2.RIGHT
var impacted := false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	$AnimatedSprite2D.play("energy_ball")
	$EmissionSprite.visible = true
	$EmissionSprite.play("energy_ball")
	await get_tree().create_timer(lifetime).timeout
	if is_inside_tree() and not impacted:
		queue_free()

func _physics_process(delta):
	if not impacted:
		global_position += direction * speed * delta

func _on_body_entered(body: Node2D) -> void:
	if impacted:
		return
	if body.is_in_group("player"):
		return
	if body is EnemyAI and body.is_dead:
		return
	_impact()

func _impact() -> void:
	impacted = true
	set_physics_process(false)
	monitoring = false
	$CollisionShape2D.set_deferred("disabled", true)
	$AnimatedSprite2D.hide()
	$EmissionSprite.hide()
	$Lens.hide()
	var effect_parent := get_parent()
	var effect_count := randi_range(3, 4)
	for i in range(effect_count):
		var lightning := $LightningSprite.duplicate() as AnimatedSprite2D
		var ground := $LightningEmission.duplicate()as AnimatedSprite2D
		effect_parent.add_child(lightning)
		effect_parent.add_child(ground)
		var offset := Vector2.from_angle(randf() * TAU) * randf_range(12.0, 35.0)
		var spawn_position := global_position + offset
		lightning.global_position = spawn_position
		ground.global_position = spawn_position
		lightning.visible = true
		ground.visible = true
		lightning.animation_finished.connect(lightning.queue_free)
		ground.animation_finished.connect(ground.queue_free)
		lightning.play()
		ground.play()
	queue_free()
