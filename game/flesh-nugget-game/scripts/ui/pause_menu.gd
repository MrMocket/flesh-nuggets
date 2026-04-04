extends PopupPanel

@onready var title_label: Label = $Content/TitleLabel
@onready var resume_button: Button = $Content/ResumeButton
@onready var main_menu_button: Button = $Content/MainMenuButton
@onready var settings_button: Button = $Content/SettingsButton
@onready var restart_button: Button = $Content/RestartButton
@onready var settings_content: Control = $Content/SettingsContent

var _closing_intentionally := false
var _settings_view_open := false

func _ready() -> void:
	hide()

	resume_button.pressed.connect(_on_resume_pressed)
	restart_button.pressed.connect(_on_restart_pressed)
	main_menu_button.pressed.connect(_on_main_menu_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	if settings_content and settings_content.has_signal("close_requested"):
		settings_content.close_requested.connect(_on_settings_close_requested)

	var _no_focus := StyleBoxEmpty.new()
	main_menu_button.add_theme_stylebox_override("focus", _no_focus)
	resume_button.add_theme_stylebox_override("focus", _no_focus)
	settings_button.add_theme_stylebox_override("focus", _no_focus)
	restart_button.add_theme_stylebox_override("focus", _no_focus)
	popup_hide.connect(_on_popup_hidden)

	if title_label:
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_show_pause_buttons()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	if event.is_action_pressed("ui_cancel"):
		_resume_game()
		get_viewport().set_input_as_handled()

func open_menu(reset_to_main_view: bool = true) -> void:
	_closing_intentionally = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if reset_to_main_view:
		_show_pause_buttons()
	elif _settings_view_open:
		_show_settings_content()
	else:
		_show_pause_buttons()
	popup_centered(Vector2i(320, 220))
	if not _settings_view_open:
		resume_button.grab_focus()

func close_menu() -> void:
	_closing_intentionally = true
	hide()
	_set_overlay_visible(false)

func _resume_game() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	get_tree().paused = false
	close_menu()

func _on_resume_pressed() -> void:
	_resume_game()

func _on_restart_pressed() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	get_tree().paused = false
	close_menu()
	Router.retry_run()

func _on_main_menu_pressed() -> void:
	get_tree().paused = false
	close_menu()
	Router.go_to_main_menu()

func _on_settings_pressed() -> void:
	_show_settings_content()

func _on_settings_close_requested() -> void:
	_show_pause_buttons()

func _on_popup_hidden() -> void:
	if get_tree().paused and not _closing_intentionally:
		call_deferred("open_menu", false)

func _set_overlay_visible(value: bool) -> void:
	var overlay := get_node_or_null("../DarkOverlay")
	if overlay:
		overlay.visible = value

func _show_pause_buttons() -> void:
	_settings_view_open = false
	title_label.visible = true
	resume_button.visible = true
	main_menu_button.visible = true
	settings_button.visible = true
	restart_button.visible = true
	settings_content.visible = false
	_request_layout_refresh()

func _show_settings_content() -> void:
	_settings_view_open = true
	title_label.visible = false
	resume_button.visible = false
	main_menu_button.visible = false
	settings_button.visible = false
	restart_button.visible = false
	settings_content.visible = true
	_request_layout_refresh()

func _request_layout_refresh() -> void:
	if visible:
		call_deferred("_refresh_popup_layout")

func _refresh_popup_layout() -> void:
	if not visible:
		return
	reset_size()
	popup_centered()
