extends Control
class_name HUD

@export var full_heart: Texture2D
@export var empty_heart: Texture2D
@export var full_bullet: Texture2D
@export var empty_bullet: Texture2D

# Nugget UI
@export var nugget_icon: Texture2D
@export var nugget_prefix := "x "

# Use a fixed UI slot size
@export var icon_size := Vector2i(48, 48)
@export var heart_spacing := 12
@export var ammo_spacing := 12
@export var nugget_spacing := 8
@export var damage_pulse_in_time := 0.04
@export var damage_pulse_out_time := 0.10
@export var damage_flash_color := Color(1.0, 0.65, 0.65, 1.0)

# Nugget collection flight
@export var nugget_fly_duration := 0.22
@export var nugget_fly_arc_height := 46.0
@export var nugget_fly_start_scale := 1.0
@export var nugget_fly_end_scale := 1.0
@export var nugget_ui_pop_scale := 1.15
@export var nugget_ui_pop_in_time := 0.07
@export var nugget_ui_pop_out_time := 0.09

@onready var hearts_row: HBoxContainer = $Hearts
@onready var ammo_row: HBoxContainer = $Ammo

# Nugget row (add these nodes in the scene)
@onready var nugget_row: HBoxContainer = $NuggetRow
@onready var nugget_icon_rect: TextureRect = $NuggetRow/NuggetIcon
@onready var nugget_label: Label = $NuggetRow/NuggetLabel
@onready var xp_bar_fill: TextureProgressBar = $XPBar/BarFill
@onready var level_label: Label = $XPBar/LevelLabel
@onready var level_panel = $LevelUpPanel

@onready var choice_a = $LevelUpPanel/ChoiceA
@onready var choice_b = $LevelUpPanel/ChoiceB

@onready var choice_a_name = $LevelUpPanel/ChoiceA/NameLabel
@onready var choice_a_desc = $LevelUpPanel/ChoiceA/DescLabel

@onready var choice_b_name = $LevelUpPanel/ChoiceB/NameLabel
@onready var choice_b_desc = $LevelUpPanel/ChoiceB/DescLabel
@onready var level_up_panel: Control = get_node_or_null("LevelUpPanel")
@onready var choice_a_button: BaseButton = get_node_or_null("LevelUpPanel/ChoiceA")
@onready var choice_b_button: BaseButton = get_node_or_null("LevelUpPanel/ChoiceB")
@onready var level_up_title_label: Label = get_node_or_null("LevelUpPanel/TitleLabel")

var _player: Node = null
var _max_hearts := 0
var _max_ammo := 0

var nugget_count := 0
var _damage_fx_token := 0
var _nugget_fx_token := 0
var _nugget_icon_base_scale := Vector2.ONE
var _nugget_label_base_scale := Vector2.ONE

var _nugget_fly_overlay: Control = null
var _level_up_player: Node = null
var _choice_a_upgrade_id := ""
var _choice_b_upgrade_id := ""
var _choice_a_press_cb: Callable
var _choice_b_press_cb: Callable

var _upgrade_pool = [
	{ "id":"move_speed", "name":"Leg Day", "desc":"+15% Move Speed", "value":0.15, "category":"utility" },
	{ "id":"reload_speed", "name":"Grease Feed", "desc":"+20% Reload Speed", "value":0.20, "category":"utility" },
	{ "id":"damage_up", "name":"Dense Meat", "desc":"+50% Damage", "value":0.50, "category":"attack" },
	{ "id":"burst_dump", "name":"Burst Dump", "desc":"Fire your whole clip at once", "value":0, "category":"mutation" }
]

var _category_colors := {
	"attack":   Color(1.0,  0.3,  0.3),
	"defense":  Color(0.3,  0.55, 1.0),
	"recovery": Color(0.3,  0.9,  0.5),
	"utility":  Color(1.0,  0.85, 0.3),
	"mutation": Color(0.75, 0.4,  1.0)
}

func _ready() -> void:
	add_to_group("hud") # so NuggetDrop can find us
	process_mode = Node.PROCESS_MODE_ALWAYS
	_apply_row_settings()
	_setup_nugget_ui()
	_ensure_nugget_fly_overlay()
	if level_up_panel:
		level_up_panel.visible = false
		level_up_panel.process_mode = Node.PROCESS_MODE_ALWAYS
		level_up_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var _no_focus_style := StyleBoxEmpty.new()
	if choice_a_button:
		choice_a_button.process_mode = Node.PROCESS_MODE_ALWAYS
		choice_a_button.mouse_filter = Control.MOUSE_FILTER_STOP
		choice_a_button.add_theme_stylebox_override("focus", _no_focus_style)
		if not choice_a_button.pressed.is_connected(_on_choice_a_pressed):
			choice_a_button.pressed.connect(_on_choice_a_pressed)
	if choice_b_button:
		choice_b_button.process_mode = Node.PROCESS_MODE_ALWAYS
		choice_b_button.mouse_filter = Control.MOUSE_FILTER_STOP
		choice_b_button.add_theme_stylebox_override("focus", _no_focus_style)
		if not choice_b_button.pressed.is_connected(_on_choice_b_pressed):
			choice_b_button.pressed.connect(_on_choice_b_pressed)
	if level_up_title_label:
		level_up_title_label.process_mode = Node.PROCESS_MODE_ALWAYS

func _apply_row_settings() -> void:
	hearts_row.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	hearts_row.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	ammo_row.size_flags_horizontal = Control.SIZE_SHRINK_END
	ammo_row.size_flags_vertical = Control.SIZE_SHRINK_END

	hearts_row.add_theme_constant_override("separation", heart_spacing)
	ammo_row.add_theme_constant_override("separation", ammo_spacing)

func _setup_nugget_ui() -> void:
	# Container spacing
	nugget_row.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	nugget_row.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	nugget_row.add_theme_constant_override("separation", nugget_spacing)

	# Icon
	if nugget_icon_rect:
		nugget_icon_rect.stretch_mode = TextureRect.STRETCH_SCALE
		nugget_icon_rect.custom_minimum_size = Vector2(icon_size.x, icon_size.y)
		nugget_icon_rect.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		nugget_icon_rect.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		if nugget_icon != null:
			nugget_icon_rect.texture = nugget_icon

	# Label initial text
	if nugget_icon_rect:
		_nugget_icon_base_scale = nugget_icon_rect.scale
	if nugget_label:
		_nugget_label_base_scale = nugget_label.scale

	_refresh_nugget_label()

func add_nuggets(amount: int) -> void:
	nugget_count += amount
	if nugget_count < 0:
		nugget_count = 0
	_refresh_nugget_label()


func collect_nugget_from_screen(screen_pos: Vector2, amount: int) -> void:
	if amount <= 0:
		return
	if nugget_icon_rect == null:
		add_nuggets(amount)
		return

	_ensure_nugget_fly_overlay()
	if _nugget_fly_overlay == null:
		add_nuggets(amount)
		_pop_nugget_ui()
		return

	var fly := TextureRect.new()
	fly.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fly.texture = nugget_icon if nugget_icon != null else nugget_icon_rect.texture
	fly.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fly.stretch_mode = TextureRect.STRETCH_SCALE
	var hud_icon_size := nugget_icon_rect.get_global_rect().size
	if hud_icon_size.x <= 0.0 or hud_icon_size.y <= 0.0:
		hud_icon_size = Vector2(icon_size.x, icon_size.y)
	fly.custom_minimum_size = hud_icon_size
	fly.size = hud_icon_size
	fly.pivot_offset = fly.size * 0.5
	fly.z_index = 1000

	var source := screen_pos - fly.size * 0.5
	var icon_rect := nugget_icon_rect.get_global_rect()
	var target := icon_rect.position

	fly.position = source
	fly.scale = Vector2.ONE * nugget_fly_start_scale
	_nugget_fly_overlay.add_child(fly)

	var p0 := source
	var p2 := target
	var dir := p2 - p0
	var p1 := p0 + (dir * 0.5)
	p1.y -= nugget_fly_arc_height

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_method(func(t: float) -> void:
		fly.position = _quadratic_bezier(p0, p1, p2, t)
	, 0.0, 1.0, nugget_fly_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(fly, "scale", Vector2.ONE * nugget_fly_end_scale, nugget_fly_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	await tw.finished
	if is_instance_valid(fly):
		fly.queue_free()

	add_nuggets(amount)
	_pop_nugget_ui()

func _refresh_nugget_label() -> void:
	if nugget_label:
		nugget_label.text = "%s%d" % [nugget_prefix, nugget_count]


func _ensure_nugget_fly_overlay() -> void:
	if _nugget_fly_overlay != null and is_instance_valid(_nugget_fly_overlay):
		return

	_nugget_fly_overlay = Control.new()
	_nugget_fly_overlay.name = "NuggetFlyOverlay"
	_nugget_fly_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_nugget_fly_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_nugget_fly_overlay.offset_left = 0
	_nugget_fly_overlay.offset_top = 0
	_nugget_fly_overlay.offset_right = 0
	_nugget_fly_overlay.offset_bottom = 0
	_nugget_fly_overlay.z_index = 100
	add_child(_nugget_fly_overlay)


func _quadratic_bezier(p0: Vector2, p1: Vector2, p2: Vector2, t: float) -> Vector2:
	var u := 1.0 - t
	return (u * u * p0) + (2.0 * u * t * p1) + (t * t * p2)


func _pop_nugget_ui() -> void:
	_nugget_fx_token += 1
	var token := _nugget_fx_token

	if nugget_icon_rect:
		nugget_icon_rect.scale = _nugget_icon_base_scale
	if nugget_label:
		nugget_label.scale = _nugget_label_base_scale

	var tw := create_tween()
	tw.set_parallel(true)

	if nugget_icon_rect:
		tw.tween_property(nugget_icon_rect, "scale", _nugget_icon_base_scale * nugget_ui_pop_scale, nugget_ui_pop_in_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if nugget_label:
		tw.tween_property(nugget_label, "scale", _nugget_label_base_scale * nugget_ui_pop_scale, nugget_ui_pop_in_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	await tw.finished
	if token != _nugget_fx_token:
		return

	var tw_back := create_tween()
	tw_back.set_parallel(true)
	if nugget_icon_rect:
		tw_back.tween_property(nugget_icon_rect, "scale", _nugget_icon_base_scale, nugget_ui_pop_out_time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if nugget_label:
		tw_back.tween_property(nugget_label, "scale", _nugget_label_base_scale, nugget_ui_pop_out_time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func bind_player(player: Node) -> void:
	_player = player
	if _player == null:
		return

	# Health -> hearts
	if _player.has_node("Health"):
		var health := _player.get_node("Health")
		if health is HealthComponent:
			if not health.containers_changed.is_connected(_on_hearts_changed):
				health.containers_changed.connect(_on_hearts_changed)
			_on_hearts_changed(health.containers, health.max_containers)

	# Ammo -> bullets
	if _player.has_signal("ammo_changed"):
		if not _player.ammo_changed.is_connected(_on_ammo_changed):
			_player.ammo_changed.connect(_on_ammo_changed)
		_on_ammo_changed(_player.ammo, _player.mag_size)

func _on_hearts_changed(current: int, maxv: int) -> void:
	if maxv != _max_hearts:
		_max_hearts = maxv
		_rebuild_row(hearts_row, _max_hearts)
	_update_row(hearts_row, current, _max_hearts, full_heart, empty_heart)

func _on_ammo_changed(current: int, maxv: int) -> void:
	if maxv != _max_ammo:
		_max_ammo = maxv
		_rebuild_row(ammo_row, _max_ammo)
	_update_row(ammo_row, current, _max_ammo, full_bullet, empty_bullet)

func _rebuild_row(row: HBoxContainer, count: int) -> void:
	for c in row.get_children():
		c.queue_free()

	for _i in range(count):
		var t := TextureRect.new()
		t.stretch_mode = TextureRect.STRETCH_SCALE
		t.custom_minimum_size = Vector2(icon_size.x, icon_size.y)
		t.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		t.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(t)

func _update_row(row: HBoxContainer, current: int, maxv: int, full_tex: Texture2D, empty_tex: Texture2D) -> void:
	current = clamp(current, 0, maxv)
	for i in range(maxv):
		var t := row.get_child(i) as TextureRect
		if t:
			t.texture = full_tex if i < current else empty_tex


func update_xp(current_xp: int, xp_to_next: int, level: int) -> void:
	if xp_bar_fill:
		xp_bar_fill.max_value = max(1, xp_to_next)
		xp_bar_fill.value = clamp(current_xp, 0, xp_bar_fill.max_value)
	if level_label:
		level_label.text = "LV %d" % level


func show_level_up_choices(player: Node) -> void:
	if level_up_panel == null or choice_a_button == null or choice_b_button == null:
		return

	_level_up_player = player

	var choices: Array = []
	for upgrade in _upgrade_pool:
		if _is_upgrade_available_for_player(upgrade, player):
			choices.append(upgrade)
	choices.shuffle()
	if choices.size() < 2:
		print("Not enough available upgrades to present choices")
		return

	var a = choices[0]
	var b = choices[1]

	_choice_a_upgrade_id = a["id"]
	_choice_b_upgrade_id = b["id"]

	choice_a_name.text = a["name"]
	choice_a_name.add_theme_color_override("font_color", _category_colors.get(a.get("category", ""), Color.WHITE))
	choice_a_desc.text = a["desc"]

	choice_b_name.text = b["name"]
	choice_b_name.add_theme_color_override("font_color", _category_colors.get(b.get("category", ""), Color.WHITE))
	choice_b_desc.text = b["desc"]

	if choice_a.pressed.is_connected(_on_choice_a_pressed):
		choice_a.pressed.disconnect(_on_choice_a_pressed)
	if choice_b.pressed.is_connected(_on_choice_b_pressed):
		choice_b.pressed.disconnect(_on_choice_b_pressed)

	if _choice_a_press_cb.is_valid() and choice_a.pressed.is_connected(_choice_a_press_cb):
		choice_a.pressed.disconnect(_choice_a_press_cb)
	if _choice_b_press_cb.is_valid() and choice_b.pressed.is_connected(_choice_b_press_cb):
		choice_b.pressed.disconnect(_choice_b_press_cb)

	_choice_a_press_cb = func():
		_player.apply_upgrade(a["id"])
		level_panel.hide()
		get_tree().paused = false
		Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)

	_choice_b_press_cb = func():
		_player.apply_upgrade(b["id"])
		level_panel.hide()
		get_tree().paused = false
		Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)

	choice_a.pressed.connect(_choice_a_press_cb)
	choice_b.pressed.connect(_choice_b_press_cb)
	if level_up_title_label:
		level_up_title_label.text = "Choose one."
		level_up_title_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))

	# Defer actual show+pause to idle time so this doesn't run mid-physics-callback
	call_deferred("_show_level_up_panel")


func _is_upgrade_available_for_player(upgrade: Dictionary, player: Node) -> bool:
	if not upgrade.has("id"):
		return true
	if player == null or not is_instance_valid(player):
		return true
	if player.has_method("is_upgrade_available"):
		return player.is_upgrade_available(str(upgrade["id"]))
	return true


func _show_level_up_panel() -> void:
	if level_up_panel == null:
		return
	level_up_panel.visible = true
	level_up_panel.show()
	print("Level-up panel opening")
	choice_a_button.grab_focus()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().paused = true


func _input(event: InputEvent) -> void:
	if level_up_panel == null or not level_up_panel.visible:
		return
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
		return
	if choice_a_button != null and choice_a_button.get_global_rect().has_point(mb.position):
		accept_event()
		print("ChoiceA clicked via _input")
		choice_a.emit_signal("pressed")
	elif choice_b_button != null and choice_b_button.get_global_rect().has_point(mb.position):
		accept_event()
		print("ChoiceB clicked via _input")
		choice_b.emit_signal("pressed")


func show_damage_feedback() -> void:
	if hearts_row == null:
		return

	_damage_fx_token += 1
	var token := _damage_fx_token

	hearts_row.modulate = damage_flash_color

	await get_tree().create_timer(damage_pulse_in_time).timeout
	if token != _damage_fx_token:
		return

	var tw := create_tween()
	tw.tween_property(hearts_row, "modulate", Color(1, 1, 1, 1), damage_pulse_out_time)


func _on_choice_a_pressed() -> void:
	print("ChoiceA pressed")
	_apply_level_up_choice(_choice_a_upgrade_id)


func _on_choice_b_pressed() -> void:
	print("ChoiceB pressed")
	_apply_level_up_choice(_choice_b_upgrade_id)


func _apply_level_up_choice(upgrade_id: String) -> void:
	if _level_up_player != null and is_instance_valid(_level_up_player) and _level_up_player.has_method("apply_upgrade"):
		_level_up_player.apply_upgrade(upgrade_id)

	if level_up_panel:
		level_up_panel.visible = false

	_level_up_player = null
	_choice_a_upgrade_id = ""
	_choice_b_upgrade_id = ""
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
