extends CanvasLayer
@export_group("Portraits")
@export var mage_portrait: Texture2D
@export var tank_portrait: Texture2D
@export var rogue_portrait: Texture2D

@export_group("Mage Attacks")
@export var mage_energy_ball: Texture2D
@export var mage_fireball_burst: Texture2D

@export_group("Tank Attacks")
@export var tank_ice_smash: Texture2D
@export var tank_axe_throw: Texture2D

@export_group("Rogue Attacks")
@export var rogue_dash_slash: Texture2D
@export var rogue_poison_throw: Texture2D

@onready var portrait: TextureRect = $Control/HBoxContainer/Portrait
@onready var primary_image: TextureRect = $Control/HBoxContainer/PrimaryAttack/AttackImage
@onready var primary_cooldown: TextureProgressBar = $Control/HBoxContainer/PrimaryAttack/CooldownOverlay
@onready var secondary_image: TextureRect = $Control/HBoxContainer/SecondaryAttack/AttackImage
@onready var secondary_cooldown: TextureProgressBar = $Control/HBoxContainer/SecondaryAttack/CooldownOverlay

var active_body: Node = null
var warp_left_bar: Control
var warp_right_bar: Control

const WARP_BAR_WIDTH := 500.0
const WARP_BAR_INSET := 48.0

func _ready() -> void:
	$Control/HBoxContainer.hide()
	_set_frame_visible(false)
	_create_warp_bars()

func show_for_body(body: Node) -> void:
	active_body = body
	if body is MageAI:
		portrait.texture = mage_portrait
		_set_slot(primary_image, mage_fireball_burst)
		_set_slot(secondary_image, mage_energy_ball)
	elif body is TankAI:
		portrait.texture = tank_portrait
		_set_slot(primary_image, tank_axe_throw)
		_set_slot(secondary_image, tank_ice_smash)
	elif body is RogueAI:
		portrait.texture = rogue_portrait
		_set_slot(primary_image, rogue_dash_slash)
		_set_slot(secondary_image, rogue_poison_throw)
	else:
		hide()
		return
	_set_frame_visible(true)
	$Control/HBoxContainer.show()
	update_cooldowns()

func hide_hud() -> void:
	active_body = null
	$Control/HBoxContainer.hide()
	_set_frame_visible(false)
	hide_warp_timer()

func _set_slot(image: TextureRect, attack_texture: Texture2D) -> void:
	image.texture = attack_texture

func _process(_delta: float) -> void:
	if not is_instance_valid(active_body):
		return
	update_cooldowns()

func update_cooldowns() -> void:
	if active_body is MageAI:
		_set_cooldown(primary_cooldown, active_body._cooldowns[0], active_body.fireball_burst_cooldown)
		_set_cooldown(secondary_cooldown, active_body._cooldowns[1], active_body.energy_ball_cooldown)
	elif active_body is TankAI:
		_set_cooldown(primary_cooldown, active_body._cooldowns[0], active_body.axe_throw_cooldown)
		_set_cooldown(secondary_cooldown, active_body._cooldowns[1], active_body.ice_smash_cooldown)
	elif active_body is RogueAI:
		_set_cooldown(primary_cooldown, active_body.dash_slash_cooldown_timer, active_body.dash_cooldown)
		_set_cooldown(secondary_cooldown, active_body.poison_throw_cooldown_timer, active_body.poison_cooldown)

func _set_cooldown(bar: TextureProgressBar, remaining: float, duration: float) -> void:
	if duration <= 0.0:
		bar.value = 0.0
		return
	bar.value = clampf((remaining / duration) * 100.0, 0.0, 100.0)

func _create_warp_bars() -> void:
	var blood_texture := _create_blood_texture()
	warp_left_bar = Control.new()
	warp_right_bar = Control.new()
	for bar in [warp_left_bar, warp_right_bar]:
		bar.clip_contents = true
		bar.size = Vector2(WARP_BAR_WIDTH, 20.0)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var texture_rect := TextureRect.new()
		texture_rect.texture = blood_texture
		texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		texture_rect.stretch_mode = TextureRect.STRETCH_SCALE
		texture_rect.size = Vector2(WARP_BAR_WIDTH, 20.0)
		texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.add_child(texture_rect)
		$Control.add_child(bar)
	warp_left_bar.position = Vector2(-211.0 - WARP_BAR_WIDTH, 50.0)
	warp_right_bar.position = Vector2(181.0, 50.0)
	hide_warp_timer()

func _create_blood_texture() -> Texture2D:
	var width := 128
	var height := 16
	var img := Image.create(width, height, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var spots: Array[Dictionary] = []
	for i in range(35):
		spots.append({
			"x": rng.randf_range(0.0, width),
			"y": rng.randf_range(0.0, height),
			"radius": rng.randf_range(1.0, 5.0),
			"strength": rng.randf_range(0.25, 0.85)
		})
	for y in range(height):
		for x in range(width):
			var darkness := 0.0
			for spot in spots:
				var dx: float = x - spot.x
				var dy: float = y - spot.y
				var distance := sqrt(dx * dx + dy * dy)
				var radius: float = spot.radius
				var blur := exp(-pow(distance / (radius * 1.8), 2.0) * 2.0)
				darkness += blur * spot.strength
			darkness = clampf(darkness, 0.0, 0.9)
			var base := Color(0.75, 0.025, 0.045)
			var dark := Color(0.12, 0.0, 0.015)
			img.set_pixel(x, y, base.lerp(dark, darkness))
	return ImageTexture.create_from_image(img)

func set_warp_progress(remaining: float, duration: float) -> void:
	if not is_instance_valid(warp_left_bar):
		return
	var progress := clampf(remaining / duration, 0.0, 1.0)
	var current_width := WARP_BAR_WIDTH * progress
	warp_left_bar.size.x = current_width
	warp_left_bar.position.x = -211.0 - current_width
	var left_texture: TextureRect = warp_left_bar.get_child(0)
	left_texture.position.x = -(WARP_BAR_WIDTH - current_width)
	warp_right_bar.size.x = current_width
	warp_right_bar.position.x = 181.0
	warp_left_bar.show()
	warp_right_bar.show()

func hide_warp_timer() -> void:
	if is_instance_valid(warp_left_bar):
		warp_left_bar.hide()
	if is_instance_valid(warp_right_bar):
		warp_right_bar.hide()

func _set_frame_visible(value: bool) -> void:
	for child in $Control.get_children():
		if child is TextureRect:
			child.visible = value
