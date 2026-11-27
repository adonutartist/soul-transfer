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

@export var gate_activation_range: float = 600.0
@export var shopkeeper_arrival_offset := Vector2(0, 350)
@export_group("Shopkeeper Voice Sync")
@export_range(0.1, 60.0, 0.1) var opening_typing_duration: float = 5.0
@export_range(0.1, 60.0, 0.1) var choice_prompt_typing_duration: float = 3.5
@export_range(0.1, 60.0, 0.1) var win_response_typing_duration: float = 5.0
@export_range(0.1, 60.0, 0.1) var kill_response_typing_duration: float = 8.0
@export_group("Final Figure Transformation")
@export_range(0.5, 6.0, 0.1) var figure_rearrage_duration:float = 1.7
@export_range(0.2, 5.0, 0.1) var figure_reveal_duration: float = 1.4

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
	var cursor_canvas := get_tree().root.find_child("CustomCursor", true, false) as CanvasLayer
	var original_cursor_layer := -1
	if cursor_canvas != null:
		original_cursor_layer = cursor_canvas.layer
		cursor_canvas.layer = maxi(cursor_canvas.layer, 100)
	var screen := Control.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_STOP
	dialogue_layer.add_child(screen)
	var portrait_sheet := load("res://assets/Sprites&Tiles/All Full Portaits.png") as Texture2D
	var unknown_portrait_atlas := AtlasTexture.new()
	unknown_portrait_atlas.atlas = portrait_sheet
	unknown_portrait_atlas.region = Rect2(1220, 55, 170, 217)
	var unknown_portrait := TextureRect.new()
	unknown_portrait.name = "UnknownFigurePortrait"
	unknown_portrait.texture = unknown_portrait_atlas
	unknown_portrait.anchor_left = 0.0
	unknown_portrait.anchor_top = 0.04
	unknown_portrait.anchor_right = 0.40
	unknown_portrait.anchor_bottom = 0.82
	unknown_portrait.offset_left = -25
	unknown_portrait.offset_right = 0
	unknown_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	unknown_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	unknown_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(unknown_portrait)
	var player_portrait_atlas := AtlasTexture.new()
	player_portrait_atlas.atlas = portrait_sheet
	player_portrait_atlas.region = Rect2(920, 55, 175, 217)
	var player_portrait := TextureRect.new()
	player_portrait.name = "PlayerPortrait"
	player_portrait.texture = player_portrait_atlas
	player_portrait.anchor_left = 0.60
	player_portrait.anchor_top = 0.04
	player_portrait.anchor_bottom = 0.82
	player_portrait.anchor_right = 1.0
	player_portrait.offset_left = 0
	player_portrait.offset_right = 25
	player_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	player_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	player_portrait.flip_h = true
	player_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(player_portrait)
	var panel := Panel.new()
	panel.name = "DialoguePanel"
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.anchor_left = 0.02
	panel.anchor_top = 0.52
	panel.anchor_right = 0.98
	panel.anchor_bottom = 0.98
	panel.offset_left = 0
	panel.offset_top = 0
	panel.offset_right = 0
	panel.offset_bottom = 0
	panel.clip_contents = true
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	screen.add_child(panel)
	panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var panel_fill_holder := Control.new()
	panel_fill_holder.name = "PanelFillHolder"
	panel_fill_holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel_fill_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(panel_fill_holder)
	var panel_fill := ColorRect.new()
	panel_fill.name = "PanelFill"
	panel_fill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel_fill.offset_left = 16
	panel_fill.offset_top = 16
	panel_fill.offset_right = -16
	panel_fill.offset_bottom = -16
	panel_fill.color = Color("#201e26")
	panel_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel_fill_holder.add_child(panel_fill)
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
	var margins := MarginContainer.new()
	margins.name = "DialogueMargins"
	margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margins.add_theme_constant_override("margin_left", 28)
	margins.add_theme_constant_override("margin_right", 28)
	margins.add_theme_constant_override("margin_top", 14)
	margins.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margins)
	var layout := VBoxContainer.new()
	layout.name = "DialogueLayout"
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_theme_constant_override("separation", 12)
	margins.add_child(layout)
	var top_row := HBoxContainer.new()
	top_row.name = "PortraitAndText"
	top_row.custom_minimum_size.y = 120
	top_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	top_row.add_theme_constant_override("separation", 20)
	layout.add_child(top_row)
	var message_scroll := ScrollContainer.new()
	message_scroll.name = "DialogueScroll"
	message_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	message_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	message_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	message_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	message_scroll.custom_minimum_size.y = 120
	top_row.add_child(message_scroll)
	var message := RichTextLabel.new()
	message.bbcode_enabled = true
	message.fit_content = true
	message.scroll_active = false
	message.clip_contents = false
	message.name = "DialogueText"
	message.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	message.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	message.custom_minimum_size.y = 120
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	message.add_theme_color_override("default_color", Color("#eee9f4"))
	message.add_theme_font_size_override("normal_font_size", 17)
	message_scroll.add_child(message)
	var choices_scroll := ScrollContainer.new()
	choices_scroll.name = "ChoiceScroll"
	choices_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	choices_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	choices_scroll.custom_minimum_size.y = 90
	choices_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	choices_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	choices_scroll.visible = false
	layout.add_child(choices_scroll)
	var choices_list := VBoxContainer.new()
	choices_list.name = "ChoiceButtons"
	choices_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	choices_list.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	choices_list.add_theme_constant_override("separation", 10)
	choices_scroll.add_child(choices_list)
	var bottom_row := HBoxContainer.new()
	bottom_row.name = "DialogueBottomRow"
	bottom_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_row.custom_minimum_size.y = 52
	bottom_row.alignment = BoxContainer.ALIGNMENT_END
	layout.add_child(bottom_row)
	var continue_button := _create_dialogue_button("CONTINUE")
	continue_button.name = "ContinueButton"
	continue_button.custom_minimum_size = Vector2(170, 52)
	bottom_row.add_child(continue_button)
	message.text = (
		"I seee you have cleared every level... "
		+ "and now you believe you can simply leave?\n\n"
		+ "I can't allow that. The soulsss you stole from my pawns, "
		+ "your [shake rate=15 level=5]LIFEFORCE[/shake]... they belong to thissss game."
	)
	continue_button.disabled = true
	await _type_dialogue_text(message, message.text, opening_typing_duration)
	continue_button.disabled = false
	await continue_button.pressed
	message.text = (
		"Then tell me, player.\n\n"
		+ "How do you wish to end thisssss? "
		+ "Because there's no end to thiss that you seeeeek."
	)
	await _type_dialogue_text(message, message.text, choice_prompt_typing_duration)
	message_scroll.scroll_vertical = 0
	bottom_row.visible = false
	choices_scroll.visible = true
	var win_button := _create_dialogue_button(
		"I WILL WIN THIS GAME, GAMES ARE MADE TO BE BEATEN :p"
	)
	win_button.name = "WinChoice"
	choices_list.add_child(win_button)
	var kill_button := _create_dialogue_button(
		"I WILL KILL YOU IF I MUST TO GET THE TRUE ENDING FOR THIS GAME :D"
	)
	kill_button.name = "KillChoice"
	choices_list.add_child(kill_button)
	win_button.pressed.connect(
		_on_dialogue_choice_pressed.bind("win")
	)
	kill_button.pressed.connect(
		_on_dialogue_choice_pressed.bind("kill")
	)
	await get_tree().process_frame
	await get_tree().process_frame
	_fit_dialogue_button_height(win_button)
	_fit_dialogue_button_height(kill_button)
	await get_tree().process_frame
	_fit_dialogue_button_height(win_button)
	_fit_dialogue_button_height(kill_button)
	dialogue_choice = ""
	var choice: String = await dialogue_choice_made
	dialogue_choice = choice
	choices_scroll.visible = false
	choices_list.queue_free()
	if dialogue_choice == "win":
		message.text = (
			"I already told youuu there is no end that you seeeek...\n\n"
			+ "I never made an end to this. "
			+ "You aren't meant to leave this game, "
			+ "you must keep playing..."
		)
	else:
		message.text = (
			"Kill me [shake rate=22 level=7][color=#c58aff]HAHAHAHAHA[/color][/shake]\n\n"
			+ "You can't do anything without my help. "
			+ "I was the one who put those corpses in each level "
			+ "for you to possess...\n\n"
			+ "Without me the best you can do is roll around "
			+ "like a little pesky dungworm and dodge attacks "
			+ "as you try to cling to your dear life...\n\n"
			+ "[shake rate=30 level=12][color=#ff3030]DIEEEEEEEEEEEE[/color][/shake]"
		)
	continue_button.disabled = true
	var response_duration := win_response_typing_duration
	if dialogue_choice == "kill":
		response_duration = kill_response_typing_duration
	await _type_dialogue_text(message, message.text, response_duration)
	continue_button.disabled = false
	message_scroll.scroll_vertical = 0
	bottom_row.visible = true
	continue_button.visible = true
	await continue_button.pressed
	if cursor_canvas != null and is_instance_valid(cursor_canvas):
		cursor_canvas.layer = original_cursor_layer
	dialogue_layer.queue_free()
	await get_tree().process_frame
	await _play_final_figure_transformation()
	if player != null:
		player.transitioning = false

func _play_final_figure_transformation() -> void:
	if shopkeeper.texture == null or final_figure.texture == null:
		push_error("Level 6: Missing shopkeeper or final figure texture.")
		return
	var transformation_position := shopkeeper.global_position
	var final_figure_original_scale := final_figure.scale
	shopkeeper.visible = true
	shopkeeper.global_position = transformation_position
	shopkeeper.scale = shopkeeper_target_scale
	shopkeeper.modulate = Color.WHITE
	shopkeeper.material = _make_white_shader()
	final_figure.visible = false
	final_figure.material = null
	final_figure.modulate = Color.WHITE
	final_figure.global_position = transformation_position
	final_figure.scale = final_figure_original_scale
	var blob := _create_white_blob()
	blob.global_position = transformation_position
	blob.scale = Vector2(0.65, 0.65)
	blob.modulate = Color.WHITE
	blob.z_index = final_figure.z_index - 1
	blob.z_as_relative = false
	var become_blob_tween := create_tween()
	become_blob_tween.set_parallel(true)
	become_blob_tween.tween_property(shopkeeper, "modulate:a", 0.0, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	become_blob_tween.tween_property(blob, "scale", Vector2(3.5, 3.5), 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await become_blob_tween.finished
	shopkeeper.visible = false
	shopkeeper.modulate = Color.WHITE
	shopkeeper.material = null
	var final_white_material := _make_white_shader()
	final_figure.global_position = blob.global_position
	final_figure.scale = final_figure_original_scale * 0.05
	final_figure.material = final_white_material
	final_figure.modulate = Color.WHITE
	final_figure.visible = true
	var form_tween := create_tween()
	form_tween.set_parallel(true)
	form_tween.tween_property(final_figure, "scale", final_figure_original_scale, figure_rearrage_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	form_tween.tween_property(blob, "scale", Vector2(0.02, 0.02), figure_rearrage_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	form_tween.tween_property(blob, "modulate:a", 0.0, figure_rearrage_duration * 0.65).set_delay(figure_rearrage_duration * 0.2)
	await form_tween.finished
	blob.queue_free()
	var reveal_tween := create_tween()
	reveal_tween.tween_method(func(value: float):final_white_material.set_shader_parameter("white_amount", value), 1.0, 0.0, figure_reveal_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await reveal_tween.finished
	final_figure.material = null
	final_figure.modulate = Color.WHITE
	final_figure.scale = final_figure_original_scale
	final_figure.global_position = transformation_position
	final_figure.visible = true

func _on_dialogue_choice_pressed(choice: String) -> void:
	dialogue_choice_made.emit(choice)

func _create_dialogue_button(button_text: String) -> Button:
	var button := Button.new()
	button.text = ""
	button.name = "DialogueButton"
	button.clip_contents = false
	button.focus_mode = Control.FOCUS_NONE
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(0, 58)
	var empty_style := StyleBoxEmpty.new()
	button.add_theme_stylebox_override("normal", empty_style)
	button.add_theme_stylebox_override("hover", empty_style)
	button.add_theme_stylebox_override("pressed", empty_style)
	button.add_theme_stylebox_override("focus", empty_style)
	var label := Label.new()
	label.name = "WrappedButtonText"
	label.text = button_text
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.offset_left = 18
	label.offset_right = -18
	label.offset_top = 10
	label.offset_bottom = -10
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.clip_text = false
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color("#f2edf7"))
	label.add_theme_color_override("font_hover_color", Color("#ffcf75"))
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

func _fit_dialogue_button_height(button: Button) -> void:
	var label := button.get_node_or_null("WrappedButtonText") as Label
	if label == null:
		return
	var line_count := maxi(1, label.get_line_count())
	var font := label.get_theme_font("font")
	var font_size := label.get_theme_font_size("font_size")
	var line_height := 20.0
	if font != null:
		line_height = font.get_height(font_size)
	var required_height := float(line_count) * line_height + 24.0
	button.custom_minimum_size.y = maxf(58.0, required_height)

func _type_dialogue_text(label: RichTextLabel, full_text: String, duration: float) -> void:
	label.text = full_text
	label.visible_characters = 0
	var character_count := label.get_total_character_count()
	if character_count <= 0:
		return
	if duration <= 0.0:
		label.visible_characters = -1
		return
	var typing_tween := create_tween()
	typing_tween.tween_property(label, "visible_characters", character_count, duration)
	await typing_tween.finished
	label.visible_characters = -1
