extends Node2D
@export_range(0.0, 1.0, 0.01) var darkness := 0.65

@onready var fade: ColorRect = $TransitionLayer/Fade

const EXCLUDED_ROOTS := [
	"Player",
	"EnergyBall",
	"Fireball",
	"CustomCursor"
]
const GLOW_PREFIXES := [
	"LightningSprite",
	"LightningEmission",
	"DestroySprite",
	"DestroyEmission",
	"ExplosionSprite",
	"ExplosionEmission"
]
const ORIGINAL_MODULATE := "environment_original_modulate"
const MENU_BORDER_ATLAS: Texture2D = preload("res://assets/Sprites&Tiles/Border All 10.png")
const MENU_BORDER_REGION := Rect2(448, 0, 64, 64)
const MENU_CORNER_SIZE := 16

var current_level: Node2D
var transition_in_progress := false
var shop_next_scene_path: String = ""
var pause_menu: Control
var pause_background: ColorRect
var pause_panel: Control
var resume_button: Button
var quit_button: Button
var music_slider: HSlider
var sfx_slider: HSlider
var quit_confirmed := false
var pause_menu_open := false
var pause_canvas: CanvasLayer

func _ready() -> void:
	fade.color = Color.BLACK
	fade.color.a = 1.0
	fade.show()
	var test_scene: PackedScene = load("res://scenes/Level_6.tscn")
	var test_level: Node2D = test_scene.instantiate() as Node2D
	add_child(test_level)
	test_level.z_index = -5
	$Level1.queue_free()
	current_level = test_level
	get_tree().node_added.connect(_on_node_added)
	_apply_recursive(self)
	var fade_in := create_tween()
	fade_in.set_trans(Tween.TRANS_SINE)
	fade_in.set_ease(Tween.EASE_IN_OUT)
	fade_in.tween_property(fade, "color:a", 0.0, 1.2)
	_create_pause_menu()

func _on_node_added(node: Node) -> void:
	_apply_recursive(node)

func _apply_recursive(node: Node) -> void:
	if _is_excluded(node):
		return
	if node is Sprite2D \
	or node is AnimatedSprite2D \
	or node is Polygon2D \
	or node is TileMapLayer:
		if not node.has_meta(ORIGINAL_MODULATE):
			node.set_meta(ORIGINAL_MODULATE, node.modulate)
		var original: Color = node.get_meta(ORIGINAL_MODULATE)
		node.modulate = original * Color(darkness, darkness, darkness, 1.0)
	for child in node.get_children():
		_apply_recursive(child)

func _is_excluded(node: Node) -> bool:
	var current: Node = node
	while current != null:
		var node_name := str(current.name)
		if EXCLUDED_ROOTS.has(node_name):
			return true
		for prefix in GLOW_PREFIXES:
			if node_name.begins_with(prefix):
				return true
		current = current.get_parent()
	return false

func change_level(next_scene: PackedScene) -> void:
	if transition_in_progress:
		return
	transition_in_progress = true
	var player := get_node_or_null("Player") as Node2D
	if player == null:
		push_error("World couldnt find player")
		transition_in_progress = false
		return
	player.set("transitioning", true)
	fade.color.a = 0.0
	var fade_out := create_tween()
	fade_out.tween_property(fade, "color:a", 1.0, 0.8)
	await fade_out.finished
	var next_level := next_scene.instantiate() as Node2D
	if next_level == null:
		push_error("could not instantiate next level")
		return
	add_child(next_level)
	next_level.z_index = -5
	var spawn := next_level.get_node_or_null("PlayerSpawn") as Node2D
	if spawn == null:
		push_error("next level needs a marker2d named PlayerSpawn")
		next_level.queue_free()
		return
	var spawn_position := spawn.global_position
	player.end_possession_for_level_transition()
	player.global_position = spawn_position
	if is_instance_valid(current_level):
		current_level.queue_free()
	current_level = next_level
	await get_tree().process_frame
	await get_tree().create_timer(0.8).timeout
	var fade_in := create_tween()
	fade_in.tween_property(fade, "color:a", 0.0, 1.2)
	await fade_in.finished
	player.set("transitioning", false)
	transition_in_progress = false
	print("Level transition complete")

func reset_current_level() -> void:
	if transition_in_progress:
		return
	var player := get_node_or_null("Player") as CharacterBody2D
	if player == null:
		push_error("cant reset level player is missing")
		return
	if not is_instance_valid(current_level):
		push_error("Cannot reset level current level is missing")
		return
	var scene_path := current_level.scene_file_path
	if scene_path.is_empty():
		push_error("cant reset level current scene path is missing")
		return
	var packed_scene := load(scene_path) as PackedScene
	if packed_scene == null:
		push_error("cant reload cirretnt level" + scene_path)
		return
	transition_in_progress = true
	player.set("transitioning", true)
	fade.color.a = 0.0
	var fade_out := create_tween()
	fade_out.tween_property(fade, "color:a", 1.0, 0.8)
	await fade_out.finished
	var old_level := current_level
	var new_level := packed_scene.instantiate() as Node2D
	if new_level == null:
		push_error("failed to instantiate current level")
		player.set("transitioning", false)
		transition_in_progress = false
		return
	add_child(new_level)
	new_level.z_index = -5
	var spawn := new_level.get_node_or_null("PlayerSpawn") as Node2D
	if spawn == null:
		push_error("reloaded level has no playerspawn")
		new_level.queue_free()
		player.set("transitioning", false)
		return
	var spawn_position := spawn.global_position
	player.end_possession_for_level_transition()
	player.global_position = spawn_position
	old_level.queue_free()
	current_level = new_level
	await get_tree().process_frame
	var fade_in := create_tween()
	fade_in.tween_property(fade, "color:a", 0.0, 1.0)
	await fade_in.finished
	player.set("transitioning", false)
	transition_in_progress = false
	print("level reset complete", scene_path)

func _create_pause_menu() -> void:
	pause_menu = Control.new()
	pause_menu.name = "PauseMenu"
	pause_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_menu.process_mode = Node.PROCESS_MODE_ALWAYS
	pause_menu.visible = false
	add_child(pause_menu)
	pause_canvas = CanvasLayer.new()
	pause_canvas.name = "PauseCanvas"
	pause_canvas.layer = 90
	pause_canvas.visible = false
	pause_menu.add_child(pause_canvas)
	var full_screen := Control.new()
	full_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_canvas.add_child(full_screen)
	pause_background = ColorRect.new()
	pause_background.color = Color(0, 0, 0, 0.72)
	pause_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_background.mouse_filter = Control.MOUSE_FILTER_STOP
	full_screen.add_child(pause_background)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	full_screen.add_child(center)
	pause_panel = Control.new()
	pause_panel.custom_minimum_size = Vector2(430, 350)
	pause_panel.size = Vector2(430, 350)
	center.add_child(pause_panel)
	var panel_frame := NinePatchRect.new()
	panel_frame.texture = _get_menu_border_texture()
	panel_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel_frame.patch_margin_left = MENU_CORNER_SIZE
	panel_frame.patch_margin_right = MENU_CORNER_SIZE
	panel_frame.patch_margin_top = MENU_CORNER_SIZE
	panel_frame.patch_margin_bottom = MENU_CORNER_SIZE
	panel_frame.draw_center = false
	var panel_fill := ColorRect.new()
	panel_fill.name = "PanelFill"
	panel_fill.color = Color("#201e26")
	panel_fill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel_fill.offset_left = MENU_CORNER_SIZE
	panel_fill.offset_top = MENU_CORNER_SIZE
	panel_fill.offset_right = -MENU_CORNER_SIZE
	panel_fill.offset_bottom = -MENU_CORNER_SIZE
	panel_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pause_panel.add_child(panel_fill)
	panel_frame.modulate = Color.WHITE
	panel_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pause_panel.add_child(panel_frame)
	var content := VBoxContainer.new()
	content.name = "PauseContent"
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 28
	content.offset_top = 24
	content.offset_right = -28
	content.offset_bottom = -24
	content.add_theme_constant_override("separation", 12)
	pause_panel.add_child(content)
	var title := Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.custom_minimum_size = Vector2(0, 38)
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.92, 0.88, 1.0))
	content.add_child(title)
	resume_button = _create_pause_button("RESUME")
	resume_button.pressed.connect(_resume_game)
	content.add_child(resume_button)
	quit_button = _create_pause_button("QUIT TO MENU")
	quit_button.pressed.connect(_on_pause_quit_pressed)
	content.add_child(quit_button)
	music_slider = _create_pause_slider(content, "MUSIC")
	sfx_slider = _create_pause_slider(content, "SFX")
	var pause_controller := Node.new()
	pause_controller.name = "PauseController"
	pause_controller.set_script(load("res://scripts/pause_controller.gd"))
	pause_controller.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(pause_controller)

func _get_menu_border_texture() -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = MENU_BORDER_ATLAS
	atlas.region = MENU_BORDER_REGION
	return atlas

func _create_pause_button(button_text: String) -> Button:
	var button: Button = Button.new()
	button.text = button_text
	button.custom_minimum_size = Vector2(0, 52)
	button.add_theme_constant_override("v_separation", 2)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", Color(0.95, 0.91, 1.0))
	button.add_theme_color_override("font_hover_color", Color(0.92, 0.88, 1.0))
	var empty_style := StyleBoxEmpty.new()
	button.add_theme_stylebox_override("normal", empty_style)
	button.add_theme_stylebox_override("hover", empty_style)
	button.add_theme_stylebox_override("pressed", empty_style)
	button.add_theme_stylebox_override("focus", empty_style)
	button.add_theme_stylebox_override("disabled", empty_style)
	var frame := NinePatchRect.new()
	frame.name = "DecorativeBorder"
	frame.texture = _get_menu_border_texture()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.patch_margin_left = MENU_CORNER_SIZE
	frame.patch_margin_right = MENU_CORNER_SIZE
	frame.patch_margin_top = MENU_CORNER_SIZE
	frame.patch_margin_bottom = MENU_CORNER_SIZE
	frame.draw_center = false
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(frame)
	button.move_child(frame, 0)
	return button

func _create_pause_slider(parent: VBoxContainer, slider_title: String) -> HSlider:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 28)
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)
	var label := Label.new()
	label.text = slider_title
	label.add_theme_color_override("font_color", Color(0.76, 0.74, 0.82))
	label.custom_minimum_size = Vector2(70, 0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.value = 80
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(slider)
	var value_label := Label.new()
	value_label.text = "80%"
	value_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.48))
	value_label.custom_minimum_size = Vector2(42, 0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(value_label)
	slider.value_changed.connect(func(value: float) -> void: value_label.text = str(int(value)) + "%")
	return slider

func _open_pause_menu() -> void:
	if transition_in_progress:
		return
	pause_menu_open = true
	quit_confirmed = false
	quit_button.text = "QUIT TO MENU"
	quit_button.custom_minimum_size.y = 48
	_update_pause_panel_size()
	pause_canvas.visible = true
	get_tree().paused = true

func _resume_game() -> void:
	pause_menu_open = false
	quit_confirmed = false
	pause_canvas.visible = false
	get_tree().paused = false

func _on_pause_quit_pressed() -> void:
	if not quit_confirmed:
		quit_confirmed = true
		quit_button.text = "ARE YOU SURE?\nYOU WILL LOOSE ALL YOUR PROGRESS"
		quit_button.custom_minimum_size.y = 72
		_update_pause_panel_size()
		return
	fade.color = Color.BLACK
	fade.color.a = 0.0
	var fade_out := create_tween()
	fade_out.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	fade_out.set_trans(Tween.TRANS_SINE)
	fade_out.set_ease(Tween.EASE_IN_OUT)
	fade_out.tween_property(fade, "color:a", 1.0, 0.6)
	await fade_out.finished
	get_tree().paused = false
	var error := get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
	if error != OK:
		push_error("Could not return to main menu")

func _update_pause_panel_size() -> void:
	var content := pause_panel.get_node("PauseContent") as VBoxContainer
	var content_height := content.get_combined_minimum_size().y
	var panel_height := maxf(350.0, content_height + 48.0)
	pause_panel.custom_minimum_size = Vector2(430, panel_height)
	pause_panel.size = Vector2(430, panel_height)
