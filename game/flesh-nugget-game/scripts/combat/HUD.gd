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

var _player: Node = null
var _max_hearts := 0
var _max_ammo := 0

var nugget_count := 0
var _damage_fx_token := 0
var _nugget_fx_token := 0
var _nugget_icon_base_scale := Vector2.ONE
var _nugget_label_base_scale := Vector2.ONE

var _nugget_fly_overlay: Control = null

func _ready() -> void:
	add_to_group("hud") # so NuggetDrop can find us
	_apply_row_settings()
	_setup_nugget_ui()
	_ensure_nugget_fly_overlay()

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
