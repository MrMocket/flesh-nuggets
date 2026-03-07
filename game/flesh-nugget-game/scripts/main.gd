extends Node2D

@onready var player := $Actors/Player
@onready var hud: HUD = $UI/HUD
@onready var pause_menu := $PauseUI/PauseMenu
@onready var dark_overlay: ColorRect = $PauseUI/DarkOverlay

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

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not get_tree().paused:
		dark_overlay.visible = true
		get_tree().paused = true
		pause_menu.open_menu()
		get_viewport().set_input_as_handled()
