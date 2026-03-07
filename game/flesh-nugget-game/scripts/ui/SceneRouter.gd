extends Node

const MAIN_MENU := "res://scenes/ui/MainMenu.tscn"
const GAMEPLAY  := "res://scenes/Main.tscn"
const DEATH     := "res://scenes/ui/DeathScreen.tscn"

# Tune this to match your room fade feel
const FADE_TIME := 0.25

var _last_gameplay_path := GAMEPLAY

var _fade_layer: CanvasLayer
var _fade_rect: ColorRect


func _ready() -> void:
	_ensure_fader()


func _ensure_fader() -> void:
	if _fade_layer:
		return

	_fade_layer = CanvasLayer.new()
	_fade_layer.layer = 1000 # above everything
	add_child(_fade_layer)

	_fade_rect = ColorRect.new()
	_fade_rect.color = Color.BLACK
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_rect.offset_left = 0
	_fade_rect.offset_top = 0
	_fade_rect.offset_right = 0
	_fade_rect.offset_bottom = 0

	# Use modulate alpha so we can tween it easily
	_fade_rect.modulate = Color(1, 1, 1, 0)
	_fade_layer.add_child(_fade_rect)


func _fade_to(alpha: float, duration: float) -> void:
	_ensure_fader()
	var t := create_tween()
	t.tween_property(_fade_rect, "modulate:a", alpha, duration)
	await t.finished


func _change_scene_with_fade(path: String, duration: float = FADE_TIME) -> void:
	await _fade_to(1.0, duration)
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	await _fade_to(0.0, duration)


func go_to_main_menu() -> void:
	await _change_scene_with_fade(MAIN_MENU)

func start_run() -> void:
	_last_gameplay_path = GAMEPLAY
	await _change_scene_with_fade(GAMEPLAY)

func retry_run() -> void:
	await _change_scene_with_fade(_last_gameplay_path)

func go_to_death_screen() -> void:
	await _change_scene_with_fade(DEATH)

func quit_game() -> void:
	get_tree().quit()
