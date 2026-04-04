extends Control

@onready var start_btn: Button = %StartRunButton
@onready var lab_btn: Button = %LabButton
@onready var settings_btn: Button = %SettingsButton
@onready var quit_btn: Button = %QuitButton
@onready var settings_panel = $MainMenuSettingsPanel

func _ready() -> void:
	AudioManager.play_menu_music()
	start_btn.pressed.connect(_on_start_pressed)
	lab_btn.pressed.connect(_on_lab_pressed)
	settings_btn.pressed.connect(_on_settings_pressed)
	quit_btn.pressed.connect(_on_quit_pressed)

func _on_start_pressed() -> void:
	await Router.start_run()

func _on_lab_pressed() -> void:
	push_warning("MainMenu: Lab is not implemented yet.")

func _on_settings_pressed() -> void:
	if settings_panel != null and settings_panel.has_method("open_panel"):
		settings_panel.open_panel()
	else:
		push_error("MainMenu: MainMenuSettingsPanel is missing or is not the scripted scene instance (open_panel not found).")

func _on_quit_pressed() -> void:
	Router.quit_game()
