extends Node
const CELL := 64
const DATA := {
  "large":  {"sheet": "res://assets/Sprites&Tiles/ice_large.png",
	"up":   {"f": [0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21],
			 "d": [0.05,0.05,0.05,0.05,0.05,0.0333,0.05,0.05,0.05,0.05,0.05,0.05,0.05,0.05,0.05,0.0334,0.05,0.05,0.05,0.05,0.05,0.0166]},
	"down": {"f": [16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,31],
			 "d": [0.0333,0.0333,0.0333,0.0333,0.0333,0.0333,0.0333,0.0333,0.0333,0.0333,0.0333,0.0333,0.0333,0.0333,0.0333,0.0333,0.05]}},
  "medium": {"sheet": "res://assets/Sprites&Tiles/ice_medium.png",
	"up":   {"f": [0,1,2,3,4,5,6], "d": [0.1,0.1167,0.1,0.1,0.1166,0.1,0.0167]},
	"down": {"f": [7,8,9,10,11,12,13,14,15,16,17], "d": [0.1,0.0833,0.1,0.0834,0.1,0.1,0.0833,0.1,0.0833,0.1,0.0834]}},
  "small":  {"sheet": "res://assets/Sprites&Tiles/ice_small.png",
	"up":   {"f": [0,1,2,3,4,5,6], "d": [0.1167,0.1,0.1166,0.1167,0.1,0.1167,0.0166]},
	"down": {"f": [7,8,9,10,11,12,13], "d": [0.1167,0.1,0.1166,0.1167,0.1,0.1167,0.1333]}},
}

var _cache := {}

func get_frames(kind: String) -> SpriteFrames:
	if _cache.has(kind): return _cache[kind]
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	var tex: Texture2D = load(DATA[kind]["sheet"])
	for anim in ["up", "down"]:
		sf.add_animation(anim)
		sf.set_animation_loop(anim, false)
		sf.set_animation_speed(anim, 1.0)
		var f: Array = DATA[kind][anim]["f"]
		var d: Array = DATA[kind][anim]["d"]
		for i in f.size():
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2(f[i] * CELL, 0, CELL, CELL)
			sf.add_frame(anim, at, d[i])
	_cache[kind] = sf
	return sf
