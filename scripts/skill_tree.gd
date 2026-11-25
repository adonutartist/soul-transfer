extends Control
@export var start_open_for_testing: bool = false
@export_group("Mage Textures")
@export var mage_root_border: Texture2D
@export var mage_node_border: Texture2D
@export var mage_lock: Texture2D
@export_group("Rogue Textures")
@export var rogue_root_border: Texture2D
@export var rogue_node_border: Texture2D
@export var rogue_lock: Texture2D
@export_group("Tank Textures")
@export var tank_root_border: Texture2D
@export var tank_node_border: Texture2D
@export var tank_lock: Texture2D
@export_group("Tree Icons")
@export var mage_tree_icon: Texture2D
@export var rogue_tree_icon: Texture2D
@export var tank_tree_icon: Texture2D
@export_group("Menu Frames")
@export var details_panel_border: Texture2D
@export var buy_button_border: Texture2D
@export_group("Frame Margins")
@export_range(0, 128) var panel_corner_size: int = 24
@export_range(0, 128) var button_corner_size: int = 16

const TREE_WIDTH := 270.0
const TREE_HEIGHT := 440.0
const ROOT_POSITION := Vector2(94, 32)
const ROOT_SIZE := Vector2(82, 82)
const NODE_WIDTH := 70.0
const NODE_HEIGHT := 70.0
const NODE_START_Y := 150.0
const NODE_SPACING := 96.0
const BRANCH_X_POSITIONS := [0.0, 100.0, 200.0]
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
@onready var details_panel: PanelContainer = $MainContainer/Content/Body/DetailsPanel
@onready var header_title: Label = $MainContainer/Content/Header/Title

var upgrade_data: Dictionary = {}
var upgrade_buttons: Dictionary = {}
var unlocked_nodes: Dictionary = {}
var purchased_nodes: Dictionary = {}
var children_by_id: Dictionary = {}
var connectors: Dictionary = {}
var selected_upgrade_id: String = ""
var upgrade_warning: Label

func _ready() -> void:
	buy_button.pressed.connect(buy_selected)
	SoulManager.balance_changed.connect(_on_souls_changed)
	_configure_layout()
	_add_menu_frames()
	_build_all_trees()
	_restore_purchased_upgrades()
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
					_make_upgrade("orb_3", "Electric Orb Level III", "ORB III", "Double Electric Orb speed and AOE", "ElectricOrbSpeedAndAOE", 2),
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
					_make_upgrade("dash_2", "Dash Attack Level II", "DASH II", "Double the distance traveled by Dash Attack", "DashDistance", 1.0),
					_make_upgrade("dash_3", "Dash Attack Level III", "DASH III", "Gain one second of invincibility if Dash Attack Hits", "DashInvincibility", 1),
					_make_upgrade("dash_4", "Dash Attack Level IV", "DASH IV", "Dash Attack deals double damage.", "DashDamage", 7)
				],
				[
					_make_upgrade("poison_1", "Rogue Ability 2", "POISON I", "Double Poison Bottle AOE", "PoisonAOEMult", 2),
					_make_upgrade("poison_2", "Rogue Ability 2", "POISON II", "Double Poison duration", "IncreasedPoisonDuration", 2),
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
	tree.custom_minimum_size = Vector2(TREE_WIDTH, TREE_HEIGHT)
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
	data: Dictionary,
	accent: Color,
	is_root: bool
) -> Button:
	var button := Button.new()
	var id: String = data["id"]
	var character_class: String = data["upgrade_class"]
	button.text = ""
	button.custom_minimum_size = (
		ROOT_SIZE if is_root else Vector2(NODE_WIDTH, NODE_HEIGHT))
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(_on_upgrade_pressed.bind(id))
	_style_upgrade_button(button, accent, false, false)
	var border_texture: Texture2D
	match character_class:
		"Mage": border_texture = mage_root_border if is_root else mage_node_border
		"Rogue": border_texture = rogue_root_border if is_root else rogue_node_border
		"Tank": border_texture = tank_root_border if is_root else tank_node_border
	if border_texture != null:
		var frame := TextureRect.new()
		frame.name = "Border"
		frame.texture = border_texture
		frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		frame.stretch_mode = TextureRect.STRETCH_SCALE
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(frame)
	var icon := TextureRect.new()
	icon.name = "TreeIcon"
	match character_class:
		"Mage": icon.texture = mage_tree_icon
		"Rogue": icon.texture = rogue_tree_icon
		"Tank": icon.texture = tank_tree_icon
	icon.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	var icon_size := 38.0 if is_root else 32.0
	icon.offset_left = -icon_size / 2.0
	icon.offset_top = -icon_size / 2.0
	icon.offset_right = icon_size / 2.0
	icon.offset_bottom = icon_size / 2.0
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(icon)
	var lock := TextureRect.new()
	lock.name = "LockIcon"
	match character_class:
		"Mage": lock.texture = mage_lock
		"Rogue": lock.texture = rogue_lock
		"Tank": lock.texture = tank_lock
	lock.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	lock.offset_left = -14
	lock.offset_top = -14
	lock.offset_right = 14
	lock.offset_bottom = 14
	lock.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	lock.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lock.visible = not is_root
	button.add_child(lock)
	return button

func _style_upgrade_button(
	button: Button, _accent: Color,
	_is_unlocked: bool, _is_purchased: bool) -> void:
	var empty_style := StyleBoxEmpty.new()
	button.add_theme_stylebox_override("normal", empty_style)
	button.add_theme_stylebox_override("hover", empty_style)
	button.add_theme_stylebox_override("pressed", empty_style)
	button.add_theme_stylebox_override("focus", empty_style)
	button.add_theme_stylebox_override("disabled", empty_style)

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
	var is_unlocked: bool = unlocked_nodes[id]
	var lock: TextureRect = button.get_node("LockIcon")
	var icon: TextureRect = button.get_node("TreeIcon")
	lock.visible = not is_unlocked
	icon.visible = is_unlocked and icon.texture != null

func _on_upgrade_pressed(id: String) -> void:
	selected_upgrade_id = id
	_show_upgrade_details(id)

func _show_upgrade_details(id: String) -> void:
	var data: Dictionary = upgrade_data[id]
	upgrade_name.add_theme_color_override("font_color", CLASS_COLORS[data["upgrade_class"]])
	upgrade_warning.visible = true
	upgrade_icon.visible = false
	upgrade_name.text = data["title"]
	upgrade_description.text = data["description"]
	upgrade_cost.text = "Cost: %d Soul" % data["cost"]
	_refresh_buy_button()

func _clear_details() -> void:
	selected_upgrade_id = ""
	upgrade_warning.visible = false
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
	SoulManager.purchase_upgrade(id, data["upgrade_class"],
	data["stat"], data["amount"])
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

func _make_nine_patch(texture: Texture2D, corner_size: int) -> NinePatchRect:
	if texture == null:
		return null
	var frame := NinePatchRect.new()
	frame.texture = texture
	frame.draw_center = false
	frame.patch_margin_left = corner_size
	frame.patch_margin_right = corner_size
	frame.patch_margin_top = corner_size
	frame.patch_margin_bottom = corner_size
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return frame

func _add_menu_frames() -> void:
	details_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var fill_holder := Control.new()
	fill_holder.name = "PanelFillHolder"
	fill_holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fill_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	details_panel.add_child(fill_holder)
	details_panel.move_child(fill_holder, 0)
	var panel_fill := ColorRect.new()
	panel_fill.name = "PanelFill"
	panel_fill.color = Color("#201e26")
	panel_fill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel_fill.offset_left = panel_corner_size
	panel_fill.offset_top = panel_corner_size
	panel_fill.offset_right = -panel_corner_size
	panel_fill.offset_bottom = -panel_corner_size
	panel_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill_holder.add_child(panel_fill)
	var panel_frame := _make_nine_patch(details_panel_border, panel_corner_size)
	if panel_frame != null:
		panel_frame.name = "DecorativeBorder"
		details_panel.add_child(panel_frame)
		details_panel.move_child(panel_frame, 1)
	var button_frame := _make_nine_patch(
		buy_button_border, button_corner_size
	)
	if button_frame != null:
		button_frame.name = "DecorativeBorder"
		button_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		buy_button.add_child(button_frame)
		buy_button.move_child(button_frame, 0)

func _configure_layout() -> void:
	var tree_columns := $MainContainer/Content/Body/TreeColumns
	tree_columns.custom_minimum_size = Vector2(TREE_WIDTH * 3, TREE_HEIGHT)
	for tree in [mage_tree, rogue_tree, tank_tree]:
		tree.custom_minimum_size = Vector2(TREE_WIDTH, TREE_HEIGHT)
		tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	details_panel.custom_minimum_size = Vector2(250, 0)
	details_panel.size_flags_horizontal = Control.SIZE_SHRINK_END
	details_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var details_content := $MainContainer/Content/Body/DetailsPanel/DetailsContent
	var margin_wrapper := MarginContainer.new()
	margin_wrapper.name = "DetailsMargin"
	margin_wrapper.add_theme_constant_override("margin_left", 14)
	margin_wrapper.add_theme_constant_override("margin_right", 14)
	margin_wrapper.add_theme_constant_override("margin_top", 14)
	margin_wrapper.add_theme_constant_override("margin_bottom", 14)
	details_panel.remove_child(details_content)
	details_panel.add_child(margin_wrapper)
	margin_wrapper.add_child(details_content)
	margin_wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin_wrapper.size_flags_vertical = Control.SIZE_EXPAND_FILL
	details_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	details_content.add_theme_constant_override("separation", 38)
	upgrade_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	upgrade_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	upgrade_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	upgrade_description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	header_title.add_theme_color_override("font_color", Color(0.92, 0.88, 1.0))
	header_title.add_theme_font_size_override("font_size", 22)
	souls_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	souls_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.48))
	souls_label.add_theme_font_size_override("font_size", 18)
	upgrade_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	upgrade_name.add_theme_color_override("font_color", Color(0.92, 0.88, 1.0))
	upgrade_name.add_theme_font_size_override("font_size", 20)
	upgrade_description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	upgrade_description.add_theme_color_override("font_color", Color(0.76, 0.74, 0.82))
	upgrade_description.add_theme_font_size_override("font_size", 15)
	upgrade_cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	upgrade_cost.add_theme_color_override("font_color", Color(1.0, 0.82, 0.48))
	upgrade_cost.add_theme_font_size_override("font_size", 16)
	buy_button.add_theme_color_override("font_color", Color(0.95, 0.91, 1.0))
	buy_button.add_theme_font_size_override("font_size", 16)
	upgrade_warning = Label.new()
	upgrade_warning.name = "UpgradeWarning"
	upgrade_warning.text = "UPGRADE WITH CAUTION\nEnemies become stronger too..."
	upgrade_warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	upgrade_warning.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	upgrade_warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	upgrade_warning.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	upgrade_warning.add_theme_color_override("font_color", Color(1.0, 0.65, 0.25))
	upgrade_warning.add_theme_font_size_override("font_size", 14)
	upgrade_warning.visible = false
	details_content.add_child(upgrade_warning)
	details_content.move_child(upgrade_warning, upgrade_cost.get_index() + 1)
	buy_button.custom_minimum_size = Vector2(0, 48)
	buy_button.custom_maximum_size = Vector2(10000, 48)
	buy_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buy_button.size_flags_vertical = Control.SIZE_SHRINK_END
	var spacer := Control.new()
	spacer.name = "DetailsFlexibleSpacer"
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	details_content.add_child(spacer)
	details_content.move_child(spacer, buy_button.get_index())

func _restore_purchased_upgrades() -> void:
	for id in upgrade_data.keys():
		if SoulManager.has_upgrade(id):
			purchased_nodes[id] = true
	for parent_id in children_by_id.keys():
		if purchased_nodes.get(parent_id, false):
			for child_id in children_by_id[parent_id]:
				unlocked_nodes[child_id] = true
	for child_id in connectors.keys():
		if unlocked_nodes.get(child_id, false):
			var line: Line2D = connectors[child_id]
			var data: Dictionary = upgrade_data[child_id]
			var accent: Color = CLASS_COLORS[data["upgrade_class"]]
			line.default_color = accent
	for id in upgrade_buttons.keys():
		_refresh_upgrade_button(id)
