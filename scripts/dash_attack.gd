extends Node
class_name RogueDashAttack

signal started
signal finished

const PX: float = 32.0
const DASH_SPEED_FACTOR: float = 2.5
const DURATION: float = 0.4
const COOLDOWN: float = 3.0
const HITBOX_LIFETIME: float = 0.9
const HITBOX_FORWARD: float = 16.0
const HITBOX_RADIUS: float = 32.0
const CELL := Vector2i(79, 61)
const SPRITE_OFFSET := Vector2(-4.5, -22.5)
const FRAME_DURATIONS: Array[float] = [
	0.067, 0.083, 0.083, 0.067, 0.067, 0.083,
	0.067, 0.083, 0.067, 0.083, 0.0167
]

@export var body: CharacterBody2D
@export var visual: Node2D
@export var sprite: AnimatedSprite2D
@export var sheet: Texture2D
@export var speed_stat: float = 5.0
@export var dash_distance_mult: float = 1.0
@export var dash_damage_mult: float = 1.0
@export var base_damage: float = 4.0
@export_flags_2d_physics var hit_mask: int = 1

var is_dashing: bool = false
var _cooldown: float = 0.0
var _time: float = 0.0
var _dir: Vector2 = Vector2.ZERO

func _ready() -> void:
	if body == null or visual == null or sprite == null or sheet == null:
		push_error("DashAttack: assign Body, Visual, Sprite and Sheet in the Inspector.")
		set_physics_process(false)
		return
	sprite.centered = true
	sprite.offset = SPRITE_OFFSET
	sprite.sprite_frames = _build_frames()

func _build_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	frames.add_animation("dash_slash")
	frames.set_animation_loop("dash_slash", false)
	frames.set_animation_speed("dash_slash", 1.0)
	for i in range(FRAME_DURATIONS.size()):
		var texture := AtlasTexture.new()
		texture.atlas = sheet
		texture.region = Rect2(i * CELL.x, 0, CELL.x, CELL.y)
		frames.add_frame("dash_slash", texture, FRAME_DURATIONS[i])
	return frames

func can_cast() -> bool:
	return _cooldown <= 0.0 and not is_dashing

func try_cast(target_pos: Vector2) -> bool:
	if not can_cast():
		return false
	_dir = (target_pos - body.global_position).normalized()
	if _dir == Vector2.ZERO:
		_dir = Vector2.RIGHT
	visual.scale.x = 1.0 if _dir.x > 0.0 else -1.0
	sprite.stop()
	sprite.play("dash_slash")
	_spawn_hitbox()
	is_dashing = true
	_time = 0.0
	_cooldown = COOLDOWN
	started.emit()
	return true

func _physics_process(delta: float) -> void:
	if _cooldown > 0.0:
		_cooldown = maxf(0.0, _cooldown - delta)
	if not is_dashing:
		return
	_time += delta
	body.velocity = _dir * speed_stat * DASH_SPEED_FACTOR \
		* dash_distance_mult * PX
	body.move_and_slide()
	if _time >= DURATION:
		is_dashing = false
		body.velocity = Vector2.ZERO
		finished.emit()

func _spawn_hitbox() -> void:
	var area := Area2D.new()
	area.collision_layer = 0
	area.collision_mask = hit_mask
	area.monitoring = true
	var collision := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = HITBOX_RADIUS
	collision.shape = circle
	area.add_child(collision)
	area.position = _dir * HITBOX_FORWARD
	body.add_child(area)
	area.body_entered.connect(_on_hit)
	area.area_entered.connect(_on_hit)
	get_tree().create_timer(HITBOX_LIFETIME).timeout.connect(
		area.queue_free
	)

func _on_hit(other: Node) -> void:
	if other == body:
		return
	if other.has_method("take_damage"):
		other.take_damage(base_damage * dash_damage_mult)
