class_name PostFX
extends CanvasLayer

@export_range(0.0, 1.0, 0.01) var vignette := 0.4
@export_range(0.0, 0.01, 0.0001) var chromatic_aberration := 0.0018
@export_range(0.0, 4.0, 0.1) var edge_blur := 0.0
@export var tint := Color(1.04, 1.0, 0.94)
@export_range(0.0, 2.0, 0.01) var saturation := 1.1
@export_range(0.5, 1.5, 0.01) var contrast := 1.05

var _rect: ColorRect
var _mat: ShaderMaterial

func _ready() -> void:
	layer = 1
	_rect = ColorRect.new()
	_rect.name = "Lens"
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://effects/post_fx.gdshader")
	_rect.material = _mat
	add_child(_rect)
	apply()

func apply() -> void:
	if _mat == null:
		return
	_mat.set_shader_parameter("vignette", vignette)
	_mat.set_shader_parameter("ca_strength", chromatic_aberration)
	_mat.set_shader_parameter("edge_blur", edge_blur)
	_mat.set_shader_parameter("tint", Vector3(tint.r, tint.g, tint.b))
	_mat.set_shader_parameter("saturation", saturation)
	_mat.set_shader_parameter("contrast", contrast)

func tweem_vignette(to: float, duration := 1.0) -> void:
	create_tween().tween_method(func(v: float):
		vignette = v
		apply(), vignette, to, duration)
