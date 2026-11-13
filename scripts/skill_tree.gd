extends Control
@export var start_open_for_testing: bool = false

const TREE_WIDTH := 270.0
const ROOT_POSITION := Vector2(20, 32)
const ROOT_SIZE := Vector2(230, 48)
const NODE_WIDTH := 82.0
const NODE_HEIGHT := 58.0
const NODE_START_Y := 126.0
const NODE_SPACING := 74.0
const BRANCH_X_POSITIONS := [4.0, 94.0, 184.0]
const CLASS_COLORS := {
	"Mage": Color(0.35, 0.72, 1.0),
	"Rogue": Color(0.45, 0.95, 0.55),
	"Tank": Color(1.0, 0.65, 0.3)
}

@onready var souls_label: Label = $MainContainer/Content/Header/SoulsLabel
@onready var mage_tree: Control = $MainContainer/Content/Body/TreeColumns/MageTree
@onready var rogue_tree: Control = $MainContainer/Content/Body/TreeColumns/RogueTree
@onready var tank_tree: Control = $MainContainer/Content/Body/TreeColumns/TankTree
@onready var upgrade_icon: TextureRect = $MainContainer/Content/Body/DetailsPanel/DetailsContent/UpgradeIcon
@onready var upgrade_name: Label = $MainContainer/Content/Body/DetailsPanel/DetailsContent/UpgradeName
@onready var upgrade_description: Label = $MainContainer/Content/Body/DetailsPanel/DetailsContent/UpgradeDescription
@onready var upgrade_cost: Label = $MainContainer/Content/Body/DetailsPanel/DetailsContent/UpgradeCost
@onready var buy_button: Button = $MainContainer/Content/Body/DetailsPanel/DetailsContent/BuyButton

var upgrade_data: Dictionary = {}
var upgrade_buttons: Dictionary = {}
var unlocked_nodes: Dictionary = {}
var purchased_nodes: Dictionary = {}
var children_by_id: Dictionary = {}
var connectors: Dictionary = {}
var selected_upgrade_id: String = ""

func _ready() -> void:
	SoulManager.add_souls(10)
	buy_button.pressed.connect(buy_selected)
	SoulManager.balance_changed.connect(_on_souls_changed)
	_build_all_trees()
	_on_souls_changed(SoulManager.souls)
	_clear_details()
	visible = start_open_for_testing

func _make_upgrade(
	id: String, title: String, short_title: String,
	description: String, stat: String, amount: float
) -> Dictionary:
	return{
			"id": id, "title": title, "short_title": short_title,
			"description": description, "stat": stat, "amount": amount, "cost": 1
	}

func _get_tree_definitions() -> Dictionary:
	return{
		"Mage": {
			"root": _make_upgrade(
				"mage_booster",
				"Mage Booster",
				"MAGE BOOSTER",
				"Mage's spells gain a 20% damage boost",
				"MageDamageBoost",
				0.2
			),
			"branches": [
				[
					_make_upgrade("mage_booster_2", "Mage Booster II", "BOOSTER II", "Mage's spells gain a 20% damage boost", "MageDamageBoost", 0.2),
					_make_upgrade("mage_booster_3", "Mage Booster III", "BOOSTER III", "Mage's spells gain a 20% damage boost", "MageDamageBoost", 0.2)
				],
				[
					_make_upgrade("fireball_2", "Fireball Level II", "FIREBALL II", "Increase Fireball spawn rate and spread", "AdditionalFireballs", 2),
					_make_upgrade("fireball_3", "Fireball Level III", "FIREBALL III", "Increase Fireball spawn rate and spread", "AdditionalFireballs", 2),
					_make_upgrade("fireball_death", "Fireball On Death", "ON DEATH", "Cast fireball on death", "FireballOnDeath", 1)
				],
				[
					_make_upgrade("orb_2", "Electric Orb Level II", "ORB II", "Spawn 2 additional Electric Orbs", "AdditionalLightningBalls", 2),
					_make_upgrade("orb_3", "Electric Orb Level III", "ORB III", "Double Electric Orb speed and AOE", "ElectricOrbSpeedAndAOE", 3),
					_make_upgrade("orb_4", "Electric Orb Level IV", "ORB IV", "Spawn 4 additional Electric Orbs", "AdditionalLightningBalls", 4)
				]
			]
		},
		"Rogue": {
			"root": _make_upgrade(
				"rogue_booster",
				"Rogue Booster",
				"ROGUE BOOSTER",
				"Rogue gains a 20% speed boost",
				"Speed",
				0.2
			),
			"branches": [
				[
					_make_upgrade("rogue_booster_2", "Rogue Booster II", "BOOSTER II", "Rogue gains another 20% speed boost", "Speed", 0.2),
					_make_upgrade("rogue_booster_3", "Rogue Booster III", "BOOSTER III", "Rogue gains another 20% speed boost", "Speed", 0.2)
				],
				[
					_make_upgrade("dash_2", "Dash Attack Level II", "DASH II", "Double the distance traveled by Dash Attack", "DashDistance", 0.2),
					_make_upgrade("dash_3", "Dash Attack Level III", "DASH III", "Gain one second of invincibility if Dash Attack Hits", "DashDistance", 1),
					_make_upgrade("dash_4", "Dash Attack Level IV", "DASH IV", "Dash Attack deals double damage.", "DashDamage", 7)
				],
				[
					_make_upgrade("poison_1", "Rogue Ability 2", "POISON I", "Double Poison Bottle AOE", "PoisonAOEMult", 2),
					_make_upgrade("poison_2", "Rogue Ability 2", "POISON II", "Double Poison duration", "IncreasedPoisonDuration", 3),
					_make_upgrade("poison_3", "Rogue Ability 2", "POISON III", "Spawn 4 Poison Bottles on death", "PoisonOnDeath", 1)
				]
			]
		},
		"Tank": {
			"root": _make_upgrade(
				"tank_booster",
				"Tank Booster",
				"TANK BOOSTER",
				"Tank gains 25% damage reduction",
				"DamageReduction",
				0.25
			),
			"branches": [
				[
					_make_upgrade("tank_booster_2", "Tank Booster II", "BOOSTER II", "Tanks gains a temporary speed boost when any of their attacks hit", "SpeedBootOnHit", 1),
					_make_upgrade("tank_booster_3", "Tank Booster III", "BOOSTER III", "Tank gains 25% more damage reduction", "DamageReduction", 0.25)
				],
				[
					_make_upgrade("ice_2", "Ice Smash Level II", "ICE SMASH II", "Increase range of Ice Smash by 75%", "IceSmashRange", 0.75),
					_make_upgrade("ice_3", "Ice Smash Level III", "ICE SMASH III", "Increase range of Ice Smash by 75% more", "IceSmashRange", 0.75),
					_make_upgrade("ice_death", "Spawn Ice Smash On Death", "ON DEATH", "Spawn Ice Smash on death (Damages both player and enemies)", "IceSmashOnDeath", 1)
				],
				[
					_make_upgrade("axe_2", "Axe Level II", "AXE II", "Throw 2 additional axes", "AdditionalAxes", 2),
					_make_upgrade("axe_slow", "Slow Damages", "SLOW DAMAGE", "Applying slow to an enemy applies damage over time", "SlowDOT", 1),
					_make_upgrade("axe_3", "Axe Level III", "AXE III", "Throw 2 more additional axes", "AdditionalAxes", 2)
				]
			]
		}
	}

func _build_all_trees() -> void:
	var definitions := _get_tree_definitions()
	_build_class_tree("Mage", mage_tree, definitions["Mage"])
	_build_class_tree("Rogue", rogue_tree, definitions["Rogue"])
	_build_class_tree("Tank", tank_tree, definitions["Tank"])
	for id in upgrade_buttons.keys():
		_refresh_upgrade_button(id)

func _build_class_tree(character_class: String, tree: Control, data: Dictionary) -> void:
	var accent: Color = CLASS_COLORS[character_class]
	tree.custom_minimum_size = Vector2(TREE_WIDTH, 370)
	tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var heading := Label.new()
	heading.text = character_class.to_upper()
	heading.position = Vector2(0, 0)
	heading.size = Vector2(TREE_WIDTH, 26)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_color_override("font_color", accent)
	heading.add_theme_font_size_override("font_size", 18)
	tree.add_child(heading)
	var root_data: Dictionary = data["root"]
	root_data["upgrade_class"] = character_class
	var root_id: String = root_data["id"]
	_register_upgrade(root_data)
	children_by_id[root_id] = []
	unlocked_nodes[root_id] = true
	var root_button := _create_upgrade_button(root_data, accent, true)
	root_button.position = ROOT_POSITION
	root_button.size = ROOT_SIZE
	tree.add_child(root_button)
	upgrade_buttons[root_id] = root_button
	var branches: Array = data["branches"]
	for branch_index in range(branches.size()):
		var branch: Array = branches[branch_index]
		var column_x: float = BRANCH_X_POSITIONS[branch_index]
		var center_x: float = column_x + NODE_WIDTH / 2.0
		var previous_id: String = root_id
		for node_index in range(branch.size()):
			var node_data: Dictionary = branch[node_index]
			node_data["upgrade_class"] = character_class
			var node_id: String = node_data["id"]
			var node_y: float = NODE_START_Y + node_index * NODE_SPACING
			_register_upgrade(node_data)
			unlocked_nodes[node_id] = false
			children_by_id[node_id] = []
			children_by_id[previous_id].append(node_id)
			var connector_start: Vector2
			if node_index == 0:
				connector_start = Vector2(
					ROOT_POSITION.x + ROOT_SIZE.x / 2.0,
					ROOT_POSITION.y + ROOT_SIZE.y
				)
			else:
				var previous_y: float = NODE_START_Y + (node_index - 1) * NODE_SPACING
				connector_start = Vector2(
					center_x,
					previous_y + NODE_HEIGHT
				)
			var connector_end := Vector2(center_x, node_y)
			_add_connector(
				tree,
				node_id,
				connector_start,
				connector_end,
				accent
			)
			var node_button := _create_upgrade_button(node_data, accent, false)
			node_button.position = Vector2(column_x, node_y)
			node_button.size = Vector2(NODE_WIDTH, NODE_HEIGHT)
			tree.add_child(node_button)
			upgrade_buttons[node_id] = node_button
			previous_id = node_id
	
func _register_upgrade(data: Dictionary) -> void:
	var id: String = data["id"]
	upgrade_data[id] = data
	
func _create_upgrade_button(
	data: Dictionary, accent: Color,
	is_root: bool
) -> Button:
	var button := Button.new()
	var id: String = data["id"]
	button.text = data["short_title"]
	button.custom_minimum_size = (ROOT_SIZE if is_root else Vector2(NODE_WIDTH, NODE_HEIGHT))
	button.add_theme_font_size_override("font_size", 11)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.pressed.connect(_on_upgrade_pressed.bind(id))
	_style_upgrade_button(button, accent, false, false)
	return button

func _style_upgrade_button(
	button: Button, accent: Color,
	is_unlocked: bool, is_purchased: bool
) -> void:
	var background := Color(0.10, 0.10, 0.15)
	var border := Color(0.30, 0.30, 0.36)
	if is_purchased:
		background = accent.darkened(0.65)
		border = accent
	elif is_unlocked:
		background = accent.darkened(0.8)
		border = accent
	var normal := StyleBoxFlat.new()
	normal.bg_color = background
	normal.border_color = border
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(5)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = background.lightened(0.15)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = background.lightened(0.25)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", normal)

func _add_connector(
	tree: Control, node_id: String,
	start_position: Vector2, end_position: Vector2, accent: Color
) -> void:
	var line := Line2D.new()
	line.points = PackedVector2Array([
		start_position,
		end_position
	])
	line.width = 4.0
	line.default_color = accent.darkened(0.75)
	line.antialiased = true
	tree.add_child(line)
	tree.move_child(line, 0)
	connectors[node_id] = line

func _refresh_upgrade_button(id: String) -> void:
	var button: Button = upgrade_buttons[id]
	var data: Dictionary = upgrade_data[id]
	var character_class: String = data["upgrade_class"]
	var accent: Color = CLASS_COLORS[character_class]
	var is_unlocked: bool = unlocked_nodes[id]
	var is_purchased: bool = purchased_nodes.get(id, false)
	if is_purchased:
		button.text = "PURCHASED\n" + data["short_title"]
	elif is_unlocked:
		button.text = "AVAILABLE\n" + data["short_title"]
	else:
		button.text = "LOCKED\n" + data["short_title"]
	_style_upgrade_button(button, accent, is_unlocked, is_purchased)

func _on_upgrade_pressed(id: String) -> void:
	selected_upgrade_id = id
	_show_upgrade_details(id)

func _show_upgrade_details(id: String) -> void:
	var data: Dictionary = upgrade_data[id]
	upgrade_icon.visible = false
	upgrade_name.text = data["title"]
	upgrade_description.text = data["description"]
	upgrade_cost.text = "Cost: %d Soul" % data["cost"]
	_refresh_buy_button()

func _clear_details() -> void:
	selected_upgrade_id = ""
	upgrade_icon.visible = false
	upgrade_name.text = "Select an upgrade"
	upgrade_description.text = "Choose a node from one of the three class trees to view its details."
	upgrade_cost.text = ""
	buy_button.text = "BUY"
	buy_button.disabled = true

func _refresh_buy_button() -> void:
	if selected_upgrade_id.is_empty():
		return
	var id := selected_upgrade_id
	var data : Dictionary = upgrade_data[id]
	var is_unlocked: bool = unlocked_nodes[id]
	var is_purchased: bool = purchased_nodes.get(id, false)
	var can_afford: bool = SoulManager.can_afford(data["cost"])
	if is_purchased:
		buy_button.text = "PURCHASED"
		buy_button.disabled = true
	elif not is_unlocked:
		buy_button.text = "LOCKED"
		buy_button.disabled = true
	elif not can_afford:
		buy_button.text = "NOT ENOUGH SOULS"
		buy_button.disabled = true
	else:
		buy_button.text = "BUY - 1 SOUL"
		buy_button.disabled = false

func buy_selected() -> void:
	if selected_upgrade_id.is_empty():
		return
	var id := selected_upgrade_id
	var data: Dictionary = upgrade_data[id]
	if not unlocked_nodes[id]:
		return
	if purchased_nodes.get(id, false):
		return
	if not SoulManager.spend_souls(data["cost"]):
		return
	purchased_nodes[id] = true
	_refresh_upgrade_button(id)
	_show_upgrade_details(id)
	await _animate_child_unlocks(id)

func _animate_child_unlocks(parent_id: String) -> void:
	var child_ids: Array = children_by_id.get(parent_id, [])
	for child_id in child_ids:
		var line: Line2D = connectors.get(child_id)
		var data: Dictionary = upgrade_data[child_id]
		var accent: Color = CLASS_COLORS[data["upgrade_class"]]
		if is_instance_valid(line):
			var tween := create_tween()
			tween.tween_property(line, "default_color", accent, 0.4)
			await tween.finished
		unlocked_nodes[child_id] = true
		_refresh_upgrade_button(child_id)
	_refresh_buy_button()

func _on_souls_changed(new_balance: int) -> void:
	souls_label.text = "Souls: %d" % new_balance
	_refresh_buy_button()

func open_tree() -> void:
	visible = true
	_on_souls_changed(SoulManager.souls)

func close_tree() -> void:
	visible = false
