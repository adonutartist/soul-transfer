extends Node2D
@export_range(0.0, 1.0, 0.01) var darkness := 0.65

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

func _ready() -> void:
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
