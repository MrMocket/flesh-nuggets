extends Control

@onready var settings_content = $Panel/MarginContainer/SettingsContent

func _ready() -> void:
	visible = false
	if settings_content != null and settings_content.has_signal("close_requested"):
		settings_content.close_requested.connect(_on_close_requested)
	else:
		push_warning("MainMenuSettingsPanel: SettingsContent is missing or does not expose close_requested.")

func open_panel() -> void:
	visible = true

func close_panel() -> void:
	visible = false

func _on_close_requested() -> void:
	close_panel()
