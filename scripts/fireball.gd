extends Area2D
@export var speed := 180.0
@export var lifetime := 3.0
@export var damage: float = 0.6

var direction := Vector2.RIGHT
var launched := false
var impacted := false
var owner_body: Node2D = null

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	$AnimatedSprite2D.play("fireball")
	$ExplosionSprite.hide()
	$ExplosionEmission.hide()
	await get_tree().create_timer(lifetime).timeout
	if is_inside_tree() and not impacted:
		queue_free()

func _physics_process(delta: float) -> void:
	if launched and not impacted:
		global_position += direction * speed * delta

func _on_body_entered(body: Node2D) -> void:
	print("Fireball collided with: ", body.name, " | Type: ", body.get_class())
	if impacted:
		return
	if body == owner_body:
		return
	if body.name == "Background" or body.name == "Ground" or body.name == "GroundWall":
		return
	if body is EnemyAI:
		if body.is_dead:
			return
		if owner_body is EnemyAI:
			if body.is_possessed == owner_body.is_possessed:
				return
			body.take_damage(damage, owner_body)
	_impact()

func _impact() -> void:
	impacted = true
	launched = false
	set_physics_process(false)
	monitoring = false
	$CollisionShape2D.set_deferred("disabled", true)
	$AnimatedSprite2D.hide()
	var effect_parent := get_parent()
	var explosion := $ExplosionSprite.duplicate() as AnimatedSprite2D
	var emission := $ExplosionEmission.duplicate() as AnimatedSprite2D
	var glow_material := ShaderMaterial.new()
	# glow_material.shader = preload("res://materials/Fireball_Explosion_Glow.gdshader")
	glow_material.shader = preload("res://materials/EnergyBall_Glow.gdshader")
	glow_material.set_shader_parameter("hdr_color", Color(1.0, 0.8, 0.15, 1.0))
	glow_material.set_shader_parameter("brightness", 12.0)
	emission.material = glow_material
	effect_parent.add_child(emission)
	effect_parent.add_child(explosion)
	explosion.global_position = global_position
	explosion.self_modulate = Color.WHITE
	explosion.modulate = Color.WHITE
	explosion.use_parent_material = false
	explosion.material = null
	emission.global_position = global_position
	emission.scale = explosion.scale * 1.02
	emission.modulate = Color(1.0, 1.0, 1.0, 0.75)
	explosion.visible = true
	emission.visible = true
	explosion.animation = "default"
	emission.animation = "default"
	explosion.frame = 0
	emission.frame = 0
	explosion.animation_finished.connect(explosion.queue_free)
	emission.animation_finished.connect(emission.queue_free)
	explosion.play()
	emission.play()
	queue_free()
