extends Control

@onready var stats_label: Label = %StatsLabel
@onready var mint_btn: Button = %MintButton
@onready var retry_btn: Button = %RetryButton
@onready var menu_btn: Button = %MenuButton

func _ready() -> void:
	var flesh := RunState.flesh_collected
	var rooms := RunState.room_index
	stats_label.text = "Flesh Collected: %d\nRooms Cleared: %d" % [flesh, rooms]

	mint_btn.pressed.connect(_on_mint_pressed)
	retry_btn.pressed.connect(_on_retry_pressed)
	menu_btn.pressed.connect(_on_menu_pressed)

func _on_mint_pressed() -> void:
	print("Mint Memory Cube placeholder")

func _on_retry_pressed() -> void:
	Router.retry_run()

func _on_menu_pressed() -> void:
	Router.go_to_main_menu()
