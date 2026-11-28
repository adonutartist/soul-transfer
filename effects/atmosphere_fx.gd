class_name AtmosphereFX
extends Node2D

@export_group("Toggles")
@export var dust_enabled := true
@export var feathers_enabled := true
@export var rays_enabled := true
@export var fog_enabled := true
@export var lights_enabled := true
@export_group("Dust")
@export_range(0, 300) var dust_amount := 60
@export var dust_color := Color(1.0, 0.95, 0.8, 0.35)
@export var dust_z := 30
@export_group("Feathers")
@export_range(0, 60) var feather_amount := 8
@export var feather_color := Color(0.5, 0.46, 0.44, 0.85)
@export var feather_texture: Texture2D
@export var feather_z := 29
@export_group("Light rays")
@export_range(1, 12) var ray_count := 4
@export var ray_color := Color(1.0, 0.88, 0.62, 0.2)
@export_range(1.0, 4.0, 0.05) var ray_hdr_boost := 1.0
@export_range(-80.0, 80.0, 0.5) var ray_angle_deg := 25.0
@export var ray_length := 650.0
@export var ray_width := 130.0
@export var rays_follow_camera := false
@export var rays_anchor := Vector2.ZERO
@export var rays_cell_size := Vector2(560.0, 420.0)
@export_range(0.0, 1.0, 0.01) var rays_coverage := 0.5
@export var rays_z := -2
@export_group("Fog")
@export var fog_color := Color(0.95, 0.96, 1.0, 1.0)
@export_range(0.0, 1.0, 0.01) var fog_density := 0.05
@export var fog_scroll := Vector2(0.012, 0.004)
@export var fog_cloud_size := 1200.0
@export var fog_background_enabled := true
@export_range(0.0, 10.0, 0.1) var fog_background_boost := 2.4
@export var fog_background_z := -6
@export var fog_z := 3
@export_group("Extra lights")
@export var light_points: Array[Vector2] = []
@export var light_color := Color(1.0, 0.72, 0.38)
@export_range(0.0, 8.0, 0.05) var light_energy := 1.2
@export_range(0.5, 20.0, 0.1) var light_scale := 4.0
@export_range(0.0, 0.5, 0.01) var light_flicker := 0.06

var _dust: CPUParticles2D
var _feathers: CPUParticles2D
var _rays: RayLayer
var _fog: ColorRect
var _fog_mat: ShaderMaterial
var _bg_fog: ColorRect
var _bg_mat: ShaderMaterial
var _lights: Array[PointLight2D] = []
var _light_phase: Array[float] = []
var _ray_boost := 1.0
var _time := 0.0
var _last_view_size := Vector2.ZERO

const FOG_SHADER := """
shader_type canvas_item;
uniform sampler2D noise_tex : repeat_enable, filter_linear;
uniform vec4 fog_color : source_color = vec4(1.0, 0.8, 0.6, 1.0);
uniform vec2 scroll = vec2(0.012, 0.004);
uniform float density = 0.3;
uniform float cloud_size = 900.0;
uniform vec2 world_origin = vec2(0.0);
uniform vec2 rect_size = vec2(1280.0, 720.0);
void fragment() {
	vec2 wp = world_origin + UV * rect_size;
	vec2 p = wp / cloud_size;
	float n1 = texture(noise_tex, p + scroll * TIME).r;
	float n2 = texture(noise_tex, p * 2.3 - scroll * TIME * 1.7).r;
	float n = mix(n1, n2, 0.4);
	n = smoothstep(0.2, 0.9, n);
	COLOR = vec4(fog_color.rgb, n * density);
}
"""

func _ready() -> void:
	_build_dust()
	_build_feathers()
	_build_rays()
	_build_fog()
	_build_lights()
	_apply_toggles()
	_follow_camera()

func _process(delta: float) -> void:
	_time += delta
	_follow_camera()
	_update_rays()
	_update_lights()

func pulse_rays(peak := 2.2, rise := 0.35, fall := 1.6) -> void:
	var tw := create_tween()
	tw.tween_property(self, "_ray_boost", peak, rise).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "_ray_boost", 1.0, fall).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func fade_fog_to(color: Color, density: float, duration := 1.5) -> void:
	if _fog_mat == null:
		return
	var tw := create_tween().set_parallel(true)
	tw.tween_method(func(c: Color):
		_fog_mat.set_shader_parameter("fog_color", c)
		if _bg_mat: _bg_mat.set_shader_parameter("fog_color", c), fog_color, color, duration)
	tw.tween_method(func(d: float):
		_fog_mat.set_shader_parameter("density", d)
		if _bg_mat: _bg_mat.set_shader_parameter("density", clampf(d * fog_background_boost, 0.0, 1.0)), fog_density, density, duration)
	fog_color = color
	fog_density = density

func set_ambient_particles(on: bool) -> void:
	dust_enabled = on
	feathers_enabled = on
	_apply_toggles()

func set_rays_visible(on: bool) -> void:
	rays_enabled = on
	_apply_toggles()

func fade_lights_to(energy: float, duration := 1.0) -> void:
	for l in _lights:
		create_tween().tween_property(l, "energy", energy, duration)
	light_energy = energy

func _make_soft_circle(size := 32) -> Texture2D:
	var g := GradientTexture2D.new()
	g.width = size
	g.height = size
	g.fill = GradientTexture2D.FILL_RADIAL
	g.fill_from = Vector2(0.5, 0.5)
	g.fill_to = Vector2(1.0, 0.5)
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	grad.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.35), Color(1, 1, 1, 0)])
	g.gradient = grad
	return g

func _make_feather_texture() -> Texture2D:
	var w := 14
	var h := 34
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 0))
	for y in range(h):
		var t := float(y) / float(h - 1)
		var half := sin(PI * pow(t, 0.8)) * (w * 0.5 - 1.0)
		for x in range(w):
			var dx := absf(float(x) + 0.5 - w * 0.5)
			if dx <= half:
				var edge := 1.0 - dx / maxf(half, 0.001)
				var a := clampf(0.55 + edge * 0.6, 0.0, 1.0)
				if dx < 0.6:
					a = 1.0 # quill
				img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)

func _add_material(item: CanvasItem, additive: bool) -> void:
	if additive:
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		item.material = m

func _fade_gradient(c: Color) -> Gradient:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.2, 0.8, 1.0])
	g.colors = PackedColorArray([
		Color(c.r, c.g, c.b, 0.0), c, c, Color(c.r, c.g, c.b, 0.0)])
	return g

func _build_dust() -> void:
	_dust = CPUParticles2D.new()
	_dust.name = "Dust"
	_dust.amount = dust_amount
	_dust.lifetime = 10.0
	_dust.preprocess = 10.0
	_dust.local_coords = false
	_dust.texture = _make_soft_circle(16)
	_dust.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_dust.emission_rect_extents = Vector2(700, 400)
	_dust.direction = Vector2(0.3, -1.0)
	_dust.spread = 180.0
	_dust.gravity = Vector2.ZERO
	_dust.initial_velocity_min = 2.0
	_dust.initial_velocity_max = 9.0
	_dust.scale_amount_min = 0.15
	_dust.scale_amount_max = 0.5
	_dust.color_ramp = _fade_gradient(dust_color)
	_dust.z_as_relative = false
	_dust.z_index = dust_z
	_add_material(_dust, true)
	add_child(_dust)

func _build_feathers() -> void:
	_feathers = CPUParticles2D.new()
	_feathers.name = "Feathers"
	_feathers.amount = feather_amount
	_feathers.lifetime = 12.0
	_feathers.preprocess = 12.0
	_feathers.local_coords = false
	_feathers.texture = feather_texture if feather_texture else _make_feather_texture()
	_feathers.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_feathers.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_feathers.emission_rect_extents = Vector2(800, 120)
	_feathers.direction = Vector2(0.35, 1.0)
	_feathers.spread = 18.0
	_feathers.gravity = Vector2.ZERO
	_feathers.initial_velocity_min = 22.0
	_feathers.initial_velocity_max = 42.0
	_feathers.tangential_accel_min = -10.0
	_feathers.tangential_accel_max = 10.0
	_feathers.angle_min = -40.0
	_feathers.angle_max = 40.0
	_feathers.angular_velocity_min = -35.0
	_feathers.angular_velocity_max = 35.0
	_feathers.scale_amount_min = 0.7
	_feathers.scale_amount_max = 1.3
	_feathers.color_ramp = _fade_gradient(feather_color)
	_feathers.z_as_relative = false
	_feathers.z_index = feather_z
	add_child(_feathers)

func _build_rays() -> void:
	_rays = RayLayer.new()
	_rays.name = "Rays"
	_rays.tex = _make_ray_texture()
	_rays.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_rays.z_as_relative = false
	_rays.z_index = rays_z
	_add_material(_rays, true)
	add_child(_rays)

func _make_ray_texture() -> Texture2D:
	var w := 64
	var h := 256
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in range(h):
		var tt := float(y) / float(h - 1)
		var along := smoothstep(0.0, 0.22, tt) * (1.0 - smoothstep(0.2, 1.0, tt))
		for x in range(w):
			var across := 1.0 - absf((float(x) + 0.5) / w * 2.0 - 1.0)
			across = across * across * (3.0 - 2.0 * across)
			img.set_pixel(x, y, Color(1, 1, 1, along * across))
	return ImageTexture.create_from_image(img)

func _make_fog_material(nt: Texture2D, density: float, cloud_mult: float, scroll_mult: float) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = FOG_SHADER
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("noise_tex", nt)
	m.set_shader_parameter("fog_color", fog_color)
	m.set_shader_parameter("density", density)
	m.set_shader_parameter("scroll", fog_scroll * scroll_mult)
	m.set_shader_parameter("cloud_size", fog_cloud_size * cloud_mult)
	return m

func _make_fog_rect(mat: ShaderMaterial, rect_name: String) -> ColorRect:
	var r := ColorRect.new()
	r.name = rect_name
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.material = mat
	add_child(r)
	return r

func _build_fog() -> void:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.012
	noise.fractal_octaves = 3
	var nt := NoiseTexture2D.new()
	nt.noise = noise
	nt.width = 256
	nt.height = 256
	nt.seamless = true
	_fog_mat = _make_fog_material(nt, fog_density, 1.0, 1.0)
	_fog = _make_fog_rect(_fog_mat, "Fog")
	_fog.z_index = fog_z
	_bg_mat = _make_fog_material(nt, clampf(fog_density * fog_background_boost, 0.0, 1.0), 1.4, 0.6)
	_bg_fog = _make_fog_rect(_bg_mat, "FogBackground")
	_bg_fog.z_as_relative = false
	_bg_fog.z_index = fog_background_z

func _build_lights() -> void:
	var tex := GradientTexture2D.new()
	tex.width = 256
	tex.height = 256
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.6, 1.0])
	grad.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.3), Color(1, 1, 1, 0)])
	tex.gradient = grad
	for p in light_points:
		var l := PointLight2D.new()
		l.texture = tex
		l.position = p
		l.color = light_color
		l.energy = light_energy
		l.texture_scale = light_scale
		l.shadow_enabled = false
		add_child(l)
		_lights.append(l)
		_light_phase.append(randf() * TAU)

func _camera_rect() -> Rect2:
	var vp := get_viewport()
	var size := vp.get_visible_rect().size
	var cam := vp.get_camera_2d()
	if cam == null:
		return Rect2(Vector2.ZERO, size)
	size /= cam.zoom
	return Rect2(cam.get_screen_center_position() - size * 0.5, size)

func _follow_camera() -> void:
	var r := _camera_rect()
	var margin := Vector2(160, 160)
	var padded := r.grow_individual(margin.x, margin.y, margin.x, margin.y)
	if _dust:
		_dust.global_position = r.get_center()
		if padded.size != _last_view_size:
			_dust.emission_rect_extents = padded.size * 0.5
			_feathers.emission_rect_extents = Vector2(padded.size.x * 0.6, 80)
	if _feathers:
		_feathers.global_position = Vector2(r.get_center().x, r.position.y - 40.0)
	if _fog:
		_fog.global_position = padded.position
		_fog.size = padded.size
		_fog_mat.set_shader_parameter("world_origin", padded.position)
		_fog_mat.set_shader_parameter("rect_size", padded.size)
	if _bg_fog:
		_bg_fog.global_position = padded.position
		_bg_fog.size = padded.size
		_bg_mat.set_shader_parameter("world_origin", padded.position)
		_bg_mat.set_shader_parameter("rect_size", padded.size)
	if _rays:
		_rays.rect_size = r.size
		_rays.view = r
		_rays.world_mode = not rays_follow_camera
		if rays_follow_camera:
			_rays.global_position = Vector2(r.get_center().x, r.position.y - 40.0)
		else:
			_rays.global_position = Vector2.ZERO
	_last_view_size = padded.size

func _update_rays() -> void:
	if _rays == null:
		return
	_rays.ray_count = ray_count
	_rays.ray_width = ray_width
	_rays.ray_length = ray_length
	_rays.angle = deg_to_rad(ray_angle_deg)
	_rays.spread_width = _rays.rect_size.x * 1.3
	_rays.cell_size = rays_cell_size
	_rays.coverage = rays_coverage
	_rays.grid_offset = rays_anchor
	var c := ray_color
	c.r *= ray_hdr_boost
	c.g *= ray_hdr_boost
	c.b *= ray_hdr_boost
	_rays.base_color = c
	_rays.boost = _ray_boost
	_rays.t = _time
	_rays.queue_redraw()

func _update_lights() -> void:
	for i in range(_lights.size()):
		var flick := 1.0 + sin(_time * 3.1 + _light_phase[i]) * light_flicker \
			+ sin(_time * 7.7 + _light_phase[i] * 2.0) * light_flicker * 0.5
		if is_instance_valid(_lights[i]):
			_lights[i].texture_scale = light_scale * (1.0 + (flick - 1.0) * 0.25)

func _apply_toggles() -> void:
	if _dust: _dust.emitting = dust_enabled
	if _feathers: _feathers.emitting = feathers_enabled
	if _rays: _rays.visible = rays_enabled
	if _fog: _fog.visible = fog_enabled
	if _bg_fog: _bg_fog.visible = fog_enabled and fog_background_enabled
	for l in _lights:
		l.visible = lights_enabled

class RayLayer extends Node2D:
	var tex: Texture2D
	var ray_count := 4
	var ray_width := 90.0
	var ray_length := 650.0
	var angle := 0.4
	var spread_width := 1200.0
	var base_color := Color(1.0, 0.88, 0.62, 0.2)
	var boost := 1.0
	var t := 0.0
	var rect_size := Vector2(1280, 720)
	var view := Rect2(0, 0, 1280, 720)
	var world_mode := true
	var cell_size := Vector2(560.0, 420.0)
	var coverage := 0.4
	var grid_offset := Vector2.ZERO
	func _hash(ix: int, iy: int, seed_i: int) -> float:
		var n: int = ix * 374761393 + iy * 668265263 + seed_i * 1274126177
		n = (n ^ (n >> 13)) * 1274126177
		n = n ^ (n >> 16)
		return float(n & 0xffff) / 65535.0
	func _shaft(pos: Vector2, w: float, phase: float, strength: float) -> void:
		var shimmer := 0.65 + 0.35 * sin(t * 0.5 + phase)
		var c := base_color
		c.a = clampf(c.a * shimmer * boost * strength, 0.0, 1.0)
		c.r *= 1.0 + (boost - 1.0) * 0.3
		draw_set_transform(pos, angle, Vector2.ONE)
		draw_texture_rect(tex, Rect2(-w * 0.5, 0.0, w, ray_length), false, c)
	func _draw() -> void:
		if tex == null:
			return
		if world_mode:
			var reach := ray_length + ray_width
			var cs := cell_size
			var x0 := floori((view.position.x - reach - grid_offset.x) / cs.x)
			var x1 := floori((view.end.x + reach - grid_offset.x) / cs.x)
			var y0 := floori((view.position.y - reach - grid_offset.y) / cs.y)
			var y1 := floori((view.end.y + reach - grid_offset.y) / cs.y)
			for cx in range(x0, x1 + 1):
				for cy in range(y0, y1 + 1):
					if _hash(cx, cy, 1) > coverage:
						continue
					var pos := grid_offset + Vector2((float(cx) + _hash(cx, cy, 2)) * cs.x, (float(cy) + _hash(cx, cy, 3)) * cs.y)
					var w := ray_width * (0.6 + 0.9 * _hash(cx, cy, 4))
					var strength := 0.6 + 0.6 * _hash(cx, cy, 5)
					_shaft(pos, w, _hash(cx, cy, 6) * TAU, strength)
		else:
			for i in range(ray_count):
				var f := (float(i) + 0.5) / float(ray_count)
				var x := (f - 0.5) * spread_width
				var w := ray_width * (0.7 + 0.6 * fposmod(float(i) * 0.37, 1.0))
				_shaft(Vector2(x, 0.0), w, float(i) * 1.9, 1.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
