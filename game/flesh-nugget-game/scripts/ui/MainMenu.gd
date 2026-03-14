extends Control

@onready var start_btn: Button = %StartRunButton
@onready var lab_btn: Button = %LabButton
@onready var settings_btn: Button = %SettingsButton
@onready var quit_btn: Button = %QuitButton
@onready var wallet_btn: Button = %WalletButton

func _ready() -> void:
	start_btn.pressed.connect(_on_start_pressed)
	lab_btn.pressed.connect(_on_lab_pressed)
	settings_btn.pressed.connect(_on_settings_pressed)
	quit_btn.pressed.connect(_on_quit_pressed)
	wallet_btn.pressed.connect(_on_wallet_pressed)

func _on_start_pressed() -> void:
	await Router.start_run()

func _on_lab_pressed() -> void:
	push_warning("MainMenu: Lab is not implemented yet.")

func _on_settings_pressed() -> void:
	push_warning("MainMenu: Settings is not implemented yet.")

func _on_quit_pressed() -> void:
	Router.quit_game()

func _on_wallet_pressed() -> void:
	push_warning("MainMenu: Wallet connect is not implemented yet.")
