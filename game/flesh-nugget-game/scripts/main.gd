extends Node2D

@onready var player := $Actors/Player
@onready var hud: HUD = $UI/HUD
@onready var pause_menu := $PauseUI/PauseMenu
@onready var dark_overlay: ColorRect = $PauseUI/DarkOverlay
@onready var world: Node2D = $World
@onready var actors: Node2D = $Actors

@export var damage_shake_duration := 0.10
@export var damage_shake_strength := 8.0

var _shake_time_left := 0.0
var _world_base_pos := Vector2.ZERO
var _actors_base_pos := Vector2.ZERO

func _ready() -> void:
	if player == null:
		push_error("Main.gd: Player not found at $Actors/Player")
		return

	if hud == null:
		push_error("Main.gd: HUD not found at $UI/HUD")
		return

	if pause_menu == null:
		push_error("Main.gd: PauseMenu not found at $PauseUI/PauseMenu")
		return

	if dark_overlay == null:
		push_error("Main.gd: DarkOverlay not found at $PauseUI/DarkOverlay")
		return

	dark_overlay.visible = false
	hud.bind_player(player)

	_world_base_pos = world.position
	_actors_base_pos = actors.position

	if player.has_signal("damaged_feedback") and not player.damaged_feedback.is_connected(_on_player_damaged_feedback):
		player.damaged_feedback.connect(_on_player_damaged_feedback)


func _process(delta: float) -> void:
	if _shake_time_left > 0.0:
		_shake_time_left = max(0.0, _shake_time_left - delta)
		var safe_duration: float = damage_shake_duration if damage_shake_duration > 0.001 else 0.001
		var fade: float = _shake_time_left / safe_duration
		var offset := Vector2(
			randf_range(-1.0, 1.0),
			randf_range(-1.0, 1.0)
		) * damage_shake_strength * fade

		world.position = _world_base_pos + offset
		actors.position = _actors_base_pos + offset
	else:
		if world.position != _world_base_pos:
			world.position = _world_base_pos
		if actors.position != _actors_base_pos:
			actors.position = _actors_base_pos

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not get_tree().paused:
		dark_overlay.visible = true
		get_tree().paused = true
		pause_menu.open_menu()
		get_viewport().set_input_as_handled()


func _on_player_damaged_feedback() -> void:
	_shake_time_left = max(_shake_time_left, damage_shake_duration)
