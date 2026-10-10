extends Node2D
class_name IceSpike
signal finished

var _down_delay := 0.6
var _delay_done := false
var _up_done := false

@onready var sprite: AnimatedSprite2D = $Sprite

func setup(kind: String, down_delay: float) -> void:
	_down_delay = down_delay
	sprite.sprite_frames = IceFrames.get_frames(kind)
	sprite.play("up")
	sprite.animation_finished.connect(_on_anim_finished)
	get_tree().create_timer(down_delay).timeout.connect(func():
		_delay_done = true
		_try_down())

func _on_anim_finished() -> void:
	if sprite.animation == "up":
		_up_done = true
		sprite.pause()
		sprite.frame = sprite.sprite_frames.get_frame_count("up") - 1
		_try_down()
	else:
		finished.emit()
		queue_free()

func _try_down() -> void:
	if _delay_done and _up_done and sprite.animation == "up":
		sprite.play("down")
