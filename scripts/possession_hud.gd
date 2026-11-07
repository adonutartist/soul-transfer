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

func _ready() -> void:
	hide()

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
	show()
	update_cooldowns()

func hide_hud() -> void:
	active_body = null
	hide()

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
		_set_cooldown(primary_cooldown, active_body._cooldowns[0], active_body.dash_cooldown)
		_set_cooldown(secondary_cooldown, active_body._cooldowns[1], active_body.poison_cooldown)

func _set_cooldown(bar: TextureProgressBar, remaining: float, duration: float) -> void:
	if duration <= 0.0:
		bar.value = 0.0
		return
	bar.value = clampf((remaining / duration) * 100.0, 0.0, 100.0)
