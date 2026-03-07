extends PopupPanel

@onready var main_menu_button: Button = %MainMenuButton
@onready var resume_button: Button = %ResumeButton
@onready var restart_button: Button = %RestartButton
@onready var title_label: Label = %TitleLabel

var _closing_intentionally := false

func _ready() -> void:
	hide()

	resume_button.pressed.connect(_on_resume_pressed)
	restart_button.pressed.connect(_on_restart_pressed)
	main_menu_button.pressed.connect(_on_main_menu_pressed)
	popup_hide.connect(_on_popup_hidden)

	if title_label:
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	if event.is_action_pressed("ui_cancel"):
		_resume_game()
		get_viewport().set_input_as_handled()

func open_menu() -> void:
	_closing_intentionally = false
	popup_centered(Vector2i(320, 220))
	resume_button.grab_focus()

func close_menu() -> void:
	_closing_intentionally = true
	hide()
	_set_overlay_visible(false)

func _resume_game() -> void:
	get_tree().paused = false
	close_menu()

func _on_resume_pressed() -> void:
	_resume_game()

func _on_restart_pressed() -> void:
	get_tree().paused = false
	close_menu()
	Router.retry_run()

func _on_main_menu_pressed() -> void:
	get_tree().paused = false
	close_menu()
	Router.go_to_main_menu()

func _on_popup_hidden() -> void:
	if get_tree().paused and not _closing_intentionally:
		call_deferred("open_menu")

func _set_overlay_visible(value: bool) -> void:
	var overlay := get_node_or_null("../DarkOverlay")
	if overlay:
		overlay.visible = value
