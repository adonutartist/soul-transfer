extends Node2D
const SKILL_TREE_SCENE: PackedScene = preload("res://scenes/SkillTree.tscn")

@onready var interaction_area: Area2D = $Sprite2D/InteractionArea
@onready var shop_door: AnimatedSprite2D = $Map/Sprite2D

var player_in_range := false
var player_controller: Node = null
var skill_tree: Control
var enter_was_pressed := false
var door_opened := false

func _ready() -> void:
	interaction_area.body_entered.connect(_on_body_entered)
	interaction_area.body_exited.connect(_on_body_exited)
	player_controller = get_parent().get_node_or_null("Player")
	SoulManager.balance_changed.connect(_on_souls_changed)
	shop_door.stop()
	shop_door.frame = 0
	_create_skill_tree()
	if SoulManager.souls <= 0:
		_open_shop_door()

func _process(_delta: float) -> void:
	var enter_pressed := (
		Input.is_key_pressed(KEY_ENTER)
		or Input.is_key_pressed(KEY_KP_ENTER)
	)
	if enter_pressed and not enter_was_pressed:
		if player_in_range and not skill_tree.visible:
			open_skill_tree()
	enter_was_pressed = enter_pressed

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

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = false

func open_skill_tree() -> void:
	if not player_in_range or SoulManager.souls <= 0 or door_opened:
		return
	skill_tree.visible = true
	if is_instance_valid(player_controller):
		player_controller.transitioning = true

func _on_souls_changed(new_balance: int) -> void:
	if new_balance <= 0:
		if is_instance_valid(skill_tree) and skill_tree.visible:
			skill_tree.visible = false
		if is_instance_valid(player_controller):
			player_controller.transitioning = false
		_open_shop_door()

func _open_shop_door() -> void:
	if door_opened:
		return
	door_opened = true
	shop_door.play("default")
