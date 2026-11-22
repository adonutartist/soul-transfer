extends Control
@onready var play_button: Button = $CenterContainer/MenuBox/PlayButton
@onready var quit_button: Button = $CenterContainer/MenuBox/QuitButton
@onready var music_slider: HSlider = $CenterContainer/MenuBox/MusicRow/MusicSlider
@onready var music_value: Label = $CenterContainer/MenuBox/MusicRow/MusicValue
@onready var sfx_slider: HSlider = $CenterContainer/MenuBox/SFXRow/SFXSlider
@onready var sfx_value: Label = $CenterContainer/MenuBox/SFXRow/SFXValue

const BUTTON_BORDER_ATLAS: Texture2D = preload("res://assets/Sprites&Tiles/Border All 10.png")
const BUTTON_BORDER_REGION := Rect2(448, 0, 64, 64)
const BUTTON_CORNER_SIZE := 16

func _ready() -> void:
	play_button.pressed.connect(_on_play_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	_add_button_border(play_button)
	_add_button_border(quit_button)
	music_slider.value_changed.connect(_on_music_slider_changed)
	sfx_slider.value_changed.connect(_on_sfx_slider_changed)
	_update_music_value(music_slider.value)
	_update_sfx_value(sfx_slider.value)

func _on_play_pressed() -> void:
	var error := get_tree().change_scene_to_file("res://scenes/World.tscn")
	if error != OK:
		push_error("Could not load world scene")

func _on_quit_pressed() -> void:
	get_tree().quit()

func _on_music_slider_changed(value: float) -> void:
	_update_music_value(value)

func _on_sfx_slider_changed(value: float) -> void:
	_update_sfx_value(value)

func _update_music_value(value: float) -> void:
	music_value.text = str(int(value)) + "%"

func _update_sfx_value(value: float) -> void:
	sfx_value.text = str(int(value)) + "%"

func _add_button_border(button: Button) -> void:
	var atlas_texture := AtlasTexture.new()
	atlas_texture.atlas = BUTTON_BORDER_ATLAS
	atlas_texture.region = BUTTON_BORDER_REGION
	var frame := NinePatchRect.new()
	frame.name = "DecorativeBorder"
	frame.texture = atlas_texture
	frame.draw_center = false
	frame.patch_margin_left = BUTTON_CORNER_SIZE
	frame.patch_margin_right = BUTTON_CORNER_SIZE
	frame.patch_margin_top = BUTTON_CORNER_SIZE
	frame.patch_margin_bottom = BUTTON_CORNER_SIZE
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var empty_style := StyleBoxEmpty.new()
	button.add_theme_stylebox_override("normal", empty_style)
	button.add_theme_stylebox_override("hover", empty_style)
	button.add_theme_stylebox_override("pressed", empty_style)
	button.add_theme_stylebox_override("focus", empty_style)
	button.add_theme_stylebox_override("disabled", empty_style)
	button.add_child(frame)
	button.move_child(frame, 0)
