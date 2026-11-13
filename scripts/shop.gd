extends Node2D
const SKILL_TREE_SCENE: PackedScene = preload("res://scenes/SkillTree.tscn")

@onready var interaction_area: Area2D = $Sprite2D/InteractionArea

var player_in_range := false
var player_controller: Node = null
var skill_tree: Control
var interaction_prompt: Label
var enter_was_pressed := false

func _ready() -> void:
	interaction_area.body_entered.connect(_on_body_entered)
	interaction_area.body_exited.connect(_on_body_exited)
	player_controller = get_parent().get_node_or_null("Player")
	SoulManager.balance_changed.connect(_on_souls_changed)
	_create_interaction_prompt()
	_create_skill_tree()

func _process(_delta: float) -> void:
	var enter_pressed := (
		Input.is_key_pressed(KEY_ENTER)
		or Input.is_key_pressed(KEY_KP_ENTER)
	)
	if enter_pressed and not enter_was_pressed:
		if player_in_range and not skill_tree.visible:
			open_skill_tree()
	enter_was_pressed = enter_pressed

func _create_interaction_prompt() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 20
	add_child(canvas)
	interaction_prompt = Label.new()
	interaction_prompt.text = "Press ENTER to browse upgrades"
	interaction_prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	interaction_prompt.offset_left = -180
	interaction_prompt.offset_right = 180
	interaction_prompt.offset_top = -90
	interaction_prompt.offset_bottom = -45
	interaction_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	interaction_prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	interaction_prompt.add_theme_font_size_override("font_size", 18)
	interaction_prompt.visible = false
	canvas.add_child(interaction_prompt)

func _create_skill_tree() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 30
	add_child(canvas)
	skill_tree = SKILL_TREE_SCENE.instantiate() as Control
	canvas.add_child(skill_tree)
	skill_tree.visible = false

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = true
		interaction_prompt.visible = true

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = false
		interaction_prompt.visible = false

func open_skill_tree() -> void:
	if not player_in_range:
		return
	if SoulManager.souls <= 0:
		return
	skill_tree.visible = true
	interaction_prompt.visible = false
	if is_instance_valid(player_controller):
		player_controller.transitioning = true

func _on_souls_changed(new_balance: int) -> void:
	if new_balance <= 0 and skill_tree.visible:
		skill_tree.visible = false
		if is_instance_valid(player_controller):
			player_controller.transitioning = false
		if player_in_range:
			interaction_prompt.visible = true
