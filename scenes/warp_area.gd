extends Node2D
@export var warp_radius := 300.0
@export var ember_count := 100
@onready var particles: GPUParticles2D = $EmberParticles

func _ready():
	particles.emitting = false
	particles.amount = ember_count
	particles.lifetime = 1.0
	particles.local_coords = true

func show_warp():
	visible = true
	particles.emitting = true

func hide_warp():
	visible = false
	particles.emitting = false
