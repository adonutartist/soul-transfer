extends CharacterBody2D
@export var speed := 200.0
@export var dash_speed := 800.0
@export var dash_duration := 0.25
@export var afterimage_count := 3
@export var afterimage_spacing := 0.08
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var warp_area = $WarpArea
@onready var camera: Camera2D = $Camera2D
var facing_right := false
var is_dashing := false
var dash_timer := 0.0
var dash_direction := Vector2.LEFT
var afterimage_timer := 0.0
var afterimages_created := 0
var normal_zoom := Vector2(2.0, 2.0)
var warp_zoom := Vector2(1.0, 1.0)
var last_move_direction := Vector2.LEFT
var transfer_active := false

func _ready():
	sprite.play("idle")

func _physics_process(delta):
	if Input.is_action_just_pressed("warp_area"):
		transfer_active = true
		var mage = get_parent().get_node("Mage")
		mage.can_be_selected = true
		mage.target_particles.emitting = true
		warp_area.show_warp()
		var tween := create_tween()
		tween.tween_property(camera, "zoom", warp_zoom, 0.35)
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
		last_move_direction = direction.normalized()
	if direction != Vector2.ZERO:
		sprite.play("run")
		if direction.x < 0:
			facing_right = false
		elif direction.x > 0:
			facing_right = true
		sprite.flip_h = facing_right
	else:
		sprite.play("idle")
	if transfer_active and not warp_area.warp_active:
		transfer_active = false
		var mage = get_parent().get_node("Mage")
		mage.can_be_selected = false
		mage.target_particles.emitting = false

func start_dash():
	is_dashing = true
	dash_timer = dash_duration
	afterimages_created = 0
	afterimage_timer = 0.0
	dash_direction = last_move_direction
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
	ghost.modulate = Color(0.75, 1.0, 0.8, 0.5)
	get_parent().add_child(ghost)
	var tween := create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, 0.18)
	tween.tween_callback(ghost.queue_free)
