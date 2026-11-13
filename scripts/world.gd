extends Node2D
@export_range(0.0, 1.0, 0.01) var darkness := 0.65

@onready var fade: ColorRect = $TransitionLayer/Fade

const EXCLUDED_ROOTS := [
	"Player",
	"EnergyBall",
	"Fireball"
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

var current_level: Node2D
var transition_in_progress := false

func _ready() -> void:
	fade.color = Color(0, 0, 0, 0)
	fade.show()
	current_level = $Level1
	get_tree().node_added.connect(_on_node_added)
	_apply_recursive(self)

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
	if player.possessing and is_instance_valid(player.controlled_body):
		player.controlled_body.reparent(self, true)
		player.controlled_body.global_position = spawn_position
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
