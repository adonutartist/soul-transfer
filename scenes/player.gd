extends CharacterBody2D
@export var speed := 200.0
@export var dash_speed := 800.0
@export var dash_duration := 0.25
@export var afterimage_count := 3
@export var afterimage_spacing := 0.08
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var warp_area = $WarpArea
var facing_right := false
var is_dashing := false
var dash_timer := 0.0
var dash_direction := Vector2.LEFT
var afterimage_timer := 0.0
var afterimages_created := 0

func _ready():
	sprite.play("idle")

func _physics_process(delta):
	if Input.is_action_pressed("warp_area"):
		warp_area.show_warp()
	else:
		warp_area.hide_warp()
	if Input.is_action_just_pressed("dash") and not is_dashing:
		start_dash()
	if is_dashing:
		dash_timer -= delta
		afterimage_timer -= delta
		velocity = dash_direction * dash_speed
		move_and_slide()
		if afterimages_created < afterimage_count and afterimage_timer <= 0:
			create_afterimage()
			afterimages_created += 1
			afterimage_timer = afterimage_spacing
		if dash_timer <= 0:
			is_dashing = false
		return
	var direction := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down")
	)
	if direction.length() > 1.0:
		direction = direction.normalized()
	velocity = direction * speed
	move_and_slide()
	if direction != Vector2.ZERO:
		sprite.play("run")
		if direction.x < 0:
			facing_right = false
		elif direction.x > 0:
			facing_right = true
		sprite.flip_h = facing_right
	else:
		sprite.play("idle")

func start_dash():
	is_dashing = true
	dash_timer = dash_duration
	afterimages_created = 0
	afterimage_timer = 0.0
	if facing_right:
		dash_direction = Vector2.RIGHT
	else:
		dash_direction = Vector2.LEFT
	sprite.play("run")

func create_afterimage():
	var ghost := AnimatedSprite2D.new()
	ghost.sprite_frames = sprite.sprite_frames
	ghost.animation = "run"
	var ghost_frames = [2, 5, 8]
	ghost.frame = ghost_frames[afterimages_created]
	ghost.flip_h = sprite.flip_h
	ghost.global_position = sprite.global_position
	ghost.global_scale = sprite.global_scale
	ghost.modulate = Color(1, 1, 1, 0.5)
	get_parent().add_child(ghost)
	var tween := create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, 0.18)
	tween.tween_callback(ghost.queue_free)
