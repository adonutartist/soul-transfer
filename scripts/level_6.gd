extends Node2D
signal dialogue_choice_made(choice: String)

@onready var door: AnimatedSprite2D = $Map/Sprite2D
@onready var exit_trigger: Area2D = $ExitTrigger
@onready var player_spawn: Marker2D = $PlayerSpawn
@onready var enemies: Node2D = $Enemies
@onready var shopkeeper: Sprite2D = $Shopkeeper
@onready var final_figure: Sprite2D = $FinalFigure
@onready var gate_sprite: AnimatedSprite2D = $Map/Sprite2D

var remaining_enemies := 0
var door_opening := false
var door_unlocked := false
var loop_count := 0
var final_sequence_started := false
var shopkeeper_material: ShaderMaterial
var shopkeeper_target_scale: Vector2
var encounter_running := false
var counted_enemy_ids: Dictionary = {}
var gate_interaction_armed := true
var dialogue_choice := ""

@export var gate_activation_range: float = 400.0
@export var shopkeeper_arrival_offset := Vector2(0, 350)

func _ready() -> void:
	shopkeeper.visible = false
	final_figure.visible = false
	shopkeeper_target_scale = shopkeeper.scale
	door.stop()
	door.frame = 0
	door.sprite_frames.set_animation_loop(&"default", false)
	exit_trigger.monitoring = false
	door.animation_finished.connect(_on_door_animation_finished)
	for enemy in enemies.get_children():
		if enemy is EnemyAI:
			if not enemy.dead_on_start and not enemy.is_dead:
				remaining_enemies += 1
				var enemy_id := enemy.get_instance_id()
				counted_enemy_ids[enemy_id] = true
				enemy.died.connect(_on_enemy_died)
	if remaining_enemies == 0:
		_open_door()

func _on_enemy_died(body: EnemyAI) -> void:
	var enemy_id := body.get_instance_id()
	if not counted_enemy_ids.has(enemy_id):
		return
	counted_enemy_ids.erase(enemy_id)
	remaining_enemies = maxi(0, remaining_enemies - 1)
	print("Level 6 enemies remaining: ", remaining_enemies)
	if remaining_enemies == 0:
		_open_door()

func _open_door() -> void:
	if door_opening:
		return
	door_opening = true
	door.play("default")

func _on_door_animation_finished() -> void:
	if door.animation != &"default":
		return
	door_unlocked = true
	exit_trigger.monitoring = true

func _process(_delta: float) -> void:
	if not door_unlocked:
		return
	if encounter_running:
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	var distance_to_gate: float = player.global_position.distance_to(gate_sprite.global_position)
	if distance_to_gate > gate_activation_range:
		gate_interaction_armed = true
		return
	if not gate_interaction_armed:
		return
	gate_interaction_armed = false
	_handle_gate_proximity()

func _handle_gate_proximity() -> void:
	loop_count += 1
	if loop_count < 2:
		await _send_player_back_to_spawn()
	else:
		encounter_running = true
		final_sequence_started = true
		exit_trigger.set_deferred("monitoring", false)
		await _play_shopkeeper_entrance()

func _send_player_back_to_spawn() -> void:
	var world := get_parent()
	var player := world.get_node_or_null("Player") as CharacterBody2D
	if player == null:
		push_error("Level 6 could not find the original Player")
		return
	world.transition_in_progress = true
	player.transitioning = true
	var fade: ColorRect = world.get_node("TransitionLayer/Fade")
	fade.color.a = 0.0
	var fade_out := world.create_tween()
	fade_out.tween_property(fade, "color:a", 1.0, 0.45)
	await fade_out.finished
	player.end_possession_for_level_transition()
	player.global_position = player_spawn.global_position
	player.velocity = Vector2.ZERO
	await get_tree().process_frame
	var fade_in := world.create_tween()
	fade_in.tween_property(fade, "color:a", 0.0, 0.6)
	await fade_in.finished
	player.transitioning = false
	world.transition_in_progress = false

func _create_white_blob() -> Polygon2D:
	var blob := Polygon2D.new()
	var points := PackedVector2Array()
	var segments := 40
	var radius := 20.0
	for i in range(segments):
		var angle := TAU * float(i) / float(segments)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	blob.polygon = points
	blob.color = Color.WHITE
	blob.z_index = 100
	blob.z_as_relative = false
	add_child(blob)
	return blob

func _make_white_shader() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
	shader_type canvas_item;
	uniform float white_amount: hint_range(0.0, 1.0) = 1.0;
	void fragment() {
		vec4 tex = texture(TEXTURE, UV);
		vec3 original = tex.rgb * COLOR.rgb;
		vec3 result = mix(original, vec3(1.0), white_amount);
		COLOR = vec4(result, tex.a * COLOR.a);
	}"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("white_amount", 1.0)
	return material

func _play_shopkeeper_entrance() -> void:
	var gate_position := gate_sprite.global_position
	var blob := _create_white_blob()
	blob.global_position = gate_position + Vector2(0, -15)
	blob.scale = Vector2(0.65, 0.65)
	var destination := gate_position + shopkeeper_arrival_offset
	var blob_tween := create_tween()
	blob_tween.set_parallel(true)
	blob_tween.tween_property(blob, "global_position", destination, 1.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	blob_tween.tween_property(blob, "scale", Vector2(3.5, 3.5), 1.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await blob_tween.finished
	shopkeeper.global_position = destination
	shopkeeper.scale = Vector2.ZERO
	shopkeeper.visible = true
	shopkeeper_material = _make_white_shader()
	shopkeeper.material = shopkeeper_material
	blob.queue_free()
	var shape_tween := create_tween()
	shape_tween.tween_property(shopkeeper, "scale", shopkeeper_target_scale, 0.9).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await shape_tween.finished
	await get_tree().create_timer(0.45).timeout
	var reveal_tween := create_tween()
	reveal_tween.tween_method(
		func(value: float):
			shopkeeper_material.set_shader_parameter("white_amount", value), 1.0, 0.0, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await reveal_tween.finished
	shopkeeper.material = null
	await _show_shopkeeper_dialogue()

func _show_shopkeeper_dialogue() -> void:
	var world := get_parent()
	var player := world.get_node_or_null("Player") as CharacterBody2D
	if player != null:
		player.transitioning = true
	var dialogue_layer := CanvasLayer.new()
	dialogue_layer.name = "ShopkeeperDialogue"
	dialogue_layer.layer = 80
	dialogue_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(dialogue_layer)
	var cursor_node := get_tree().root.find_child("CustomCursor", true, false)
	var cursor_canvas: CanvasLayer = cursor_node as CanvasLayer
	while cursor_node == null and cursor_node != null:
		cursor_node = cursor_node.get_parent()
		cursor_canvas = cursor_node as CanvasLayer
	if cursor_canvas != null:
		cursor_canvas.layer = 100
	var screen := Control.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_STOP
	dialogue_layer.add_child(screen)
	var panel := Panel.new()
	panel.name = "DialoguePanel"
	panel.anchor_left = 0.07
	panel.anchor_top = 0.50
	panel.anchor_right = 0.93
	panel.anchor_bottom = 0.97
	panel.clip_contents = true
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	screen.add_child(panel)
	var panel_style := StyleBoxEmpty.new()
	panel.add_theme_stylebox_override("panel", panel_style)
	var panel_fill := ColorRect.new()
	panel_fill.name = "PanelBackground"
	panel_fill.anchor_left = 0.025
	panel_fill.anchor_top = 0.025
	panel_fill.anchor_right = 0.975
	panel_fill.anchor_bottom = 0.975
	panel_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel_fill.color = Color("#201e26")
	panel.add_child(panel_fill)
	panel.move_child(panel_fill, 0)
	var border_atlas := load("res://assets/Sprites&Tiles/Border All 10.png") as Texture2D
	var border_texture := AtlasTexture.new()
	border_texture.atlas = border_atlas
	border_texture.region = Rect2(448, 0, 64, 64)
	var panel_frame := NinePatchRect.new()
	panel_frame.name = "DecorativeBorder"
	panel_frame.texture = border_texture
	panel_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel_frame.patch_margin_left = 16
	panel_frame.patch_margin_right = 16
	panel_frame.patch_margin_top = 16
	panel_frame.patch_margin_bottom = 16
	panel_frame.draw_center = false
	panel_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(panel_frame)
	var portrait := TextureRect.new()
	portrait.name = "ShopkeeperPortrait"
	portrait.texture = shopkeeper.texture
	portrait.position = Vector2(28, 24)
	portrait.size = Vector2(130, 175)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(portrait)
	var message := Label.new()
	message.name = "DialogueText"
	message.anchor_left = 0.17
	message.anchor_top = 0.07
	message.anchor_right = 0.94
	message.anchor_bottom = 0.43
	message.offset_left = 8
	message.offset_top = 4
	message.offset_right = -12
	message.offset_bottom = -4
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.clip_text = true
	message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message.add_theme_color_override("font_color", Color("#eee9f4"))
	message.add_theme_font_size_override("font_size", 17)
	panel.add_child(message)
	var continue_button := _create_dialogue_button("CONTINUE")
	continue_button.name = "ContinueButton"
	continue_button.anchor_left = 1.0
	continue_button.anchor_top = 1.0
	continue_button.anchor_bottom = 1.0
	continue_button.anchor_right = 1.0
	continue_button.offset_left = -190
	continue_button.offset_right = -24
	continue_button.offset_top = -65
	continue_button.offset_bottom = -20
	panel.add_child(continue_button)
	message.text = (
		"I seee you have cleared every level... "
		+ "and now you believe you can simply leave?\n\n"
		+ "I can't allow that. The soulsss you stole from my pawns, "
		+ "your LIFEFORCE... they belong to thissss game."
	)
	await continue_button.pressed
	continue_button.visible = false
	message.text = (
		"Then tell me, player.\n\n"
		+ "How do you wish to end thisssss? "
		+ "Because there's no end to thiss that you seeeeek."
	)
	var choices := HBoxContainer.new()
	choices.name = "ChoiceButtons"
	choices.anchor_left = 0.17
	choices.anchor_right = 0.94
	choices.anchor_top = 0.48
	choices.anchor_bottom = 0.94
	choices.offset_left = 8
	choices.offset_right = -12
	choices.offset_top = 4
	choices.offset_bottom = -4
	choices.add_theme_constant_override("separation", 8)
	choices.mouse_filter = Control.MOUSE_FILTER_PASS
	choices.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(choices)
	var win_button := _create_dialogue_button(
		"I WILL WIN THIS GAME, GAMES ARE MADE TO BE BEATEN :p"
	)
	win_button.name = "WinChoice"
	win_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	win_button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	choices.add_child(win_button)
	var kill_button := _create_dialogue_button("I WILL KILL YOU IF I MUST TO GET THE TRUE ENDING FOR THIS GAME :D")
	kill_button.name = "KillChoice"
	kill_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kill_button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	choices.add_child(kill_button)
	win_button.pressed.connect(_on_dialogue_choice_pressed.bind("win"))
	kill_button.pressed.connect(_on_dialogue_choice_pressed.bind("kill"))
	dialogue_choice = ""
	var choice: String = await dialogue_choice_made
	dialogue_choice = choice
	choices.queue_free()
	if dialogue_choice == "win":
		message.text = (
			"I already told youuu there is no end that you seeeek...\n\n"
			+ "I never made an end to this. "
			+ "You aren't meant to leave this game, "
			+ "you must keep playing... "
		)
	else:
		message.text = (
			"Kill me HAHAHAHAHA \n\n"
			+ "You can't do anything without my help. "
			+ "I was the one who put those corpses in each level for you to possess...\n\n"
			+ "Without me the best you can do is roll around like a little pesky dungworm "
			+ "and dodge attacks as you try to cling to your dear life...\n\n"
			+ "DIEEEEEEEEEEEE"
		)
	continue_button.text = "CONTINUE"
	continue_button.visible = true
	await continue_button.pressed
	dialogue_layer.queue_free()
	if player != null:
		player.transitioning = false

func _on_dialogue_choice_pressed(choice: String) -> void:
	dialogue_choice_made.emit(choice)

func _create_dialogue_button(button_text: String) -> Button:
	var button := Button.new()
	button.text = ""
	button.clip_contents = true
	button.focus_mode = Control.FOCUS_NONE
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_color_override("font_color", Color("#f2edf7"))
	button.add_theme_color_override("font_hover_color", Color("#ffcf75"))
	var viewport_width := get_viewport().get_visible_rect().size.x
	var max_chars_per_line := maxi(28, int((viewport_width * 0.62) / 9.0))
	var estimated_lines := maxi(1, ceili(float(button_text.length()) / float(max_chars_per_line)))
	button.custom_minimum_size = Vector2(0, maxf(58.0, float(estimated_lines * 24 + 24)))
	var empty_style := StyleBoxEmpty.new()
	button.add_theme_stylebox_override("normal", empty_style)
	button.add_theme_stylebox_override("hover", empty_style)
	button.add_theme_stylebox_override("pressed", empty_style)
	button.add_theme_stylebox_override("focus", empty_style)
	var label := Label.new()
	label.name = "WrappedButtonText"
	label.text = button_text
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.offset_left = 14
	label.offset_right = -14
	label.offset_top = 8
	label.offset_bottom = -8
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = true
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color("#f2edf7"))
	button.add_child(label)
	var border_atlas := load("res://assets/Sprites&Tiles/Border All 10.png") as Texture2D
	var border_texture := AtlasTexture.new()
	border_texture.atlas = border_atlas
	border_texture.region = Rect2(448, 0, 64, 64)
	var frame := NinePatchRect.new()
	frame.name = "DecorativeBorder"
	frame.texture = border_texture
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.patch_margin_left = 16
	frame.patch_margin_right = 16
	frame.patch_margin_top = 16
	frame.patch_margin_bottom = 16
	frame.draw_center = false
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(frame)
	button.move_child(frame, button.get_child_count() - 1)
	return button
