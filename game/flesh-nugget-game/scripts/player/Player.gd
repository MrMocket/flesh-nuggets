extends CharacterBody2D

signal ammo_changed(current: int, max: int)
signal damaged_feedback

# ----------------------------
# Movement feel
# ----------------------------
@export var max_speed := 260.0
@export var acceleration := 1600.0
@export var friction := 1400.0

# ----------------------------
# Hit reaction feel
# ----------------------------
@export var contact_knockback := 180.0
@export var hit_stutter_time := 0.18

@export var flash_time := 0.08
@export var flash_alpha := 0.5
@export var hit_flash_color := Color(1.0, 0.45, 0.45, 1.0)

# ----------------------------
# Weapon / firing
# ----------------------------
@export var projectile_scene: PackedScene
@export var mag_size := 5
@export var shot_cooldown := 0.40
@export var reload_time := 1.20
@export var muzzle_distance := 20.0 # unused now, safe to keep

# Fixed muzzle position relative to player (tweak in Inspector)
@export var muzzle_local_offset := Vector2(10, 8) # +Y is down

# ----------------------------
# Animation timing
# ----------------------------
@export var shoot_anim_hold := 0.12
@export var reload_anim_delay := 0.10
@export var crosshair_distance := 40.0
@export var crosshair_fire_hold := 0.08

# ----------------------------
# Idle/Walk feel (no new art needed)
# ----------------------------
@export var move_blend_smoothing := 10.0
@export var idle_pulse_hz := 1.7
@export var idle_squash_amount := 0.025
@export var move_squash_amount := 0.012

# ----------------------------
# Walk puff particles (procedural)
# ----------------------------
@export var enable_walk_puffs := true
@export var walk_puff_color := Color(0.92, 0.92, 0.92, 0.96)
@export var walk_puff_step_interval := 0.14
@export var walk_puff_speed_threshold := 45.0

var aim_dir := Vector2.RIGHT
var facing_right := true
var using_mouse_aim := true
var last_mouse_pos := Vector2.ZERO
var was_paused_last_frame := false

# Keyboard aim support
var keyboard_aim: Vector2 = Vector2.RIGHT
var using_keyboard_aim := false

var ammo := 0
var reloading := false
var can_attack := true

# Animation
@onready var anim: AnimatedSprite2D = $Visual/AnimatedSprite2D
var current_anim := ""
var shoot_anim_timer := 0.0
var reload_anim_delay_timer := 0.0
var reload_anim_speed_restore := 1.0
var crosshair_fire_timer := 0.0
var move_blend := 0.0
var idle_pulse_time := 0.0
var walk_step_timer := 0.0
var visual_base_scale := Vector2.ONE

# Nodes
@onready var visual: Node2D = $Visual
@onready var shadow: Sprite2D = $Shadow
@onready var muzzle: Marker2D = $Muzzle
@onready var crosshair: Node2D = $Crosshair
@onready var crosshair_sprite: AnimatedSprite2D = $Crosshair/AnimatedSprite2D

@onready var shot_timer: Timer = $ShotTimer
@onready var reload_timer: Timer = $ReloadTimer
@onready var hit_timer: Timer = $HitStutterTimer

@onready var health := $Health as HealthComponent
@onready var hurtbox := $Hurtbox as Hurtbox

var flash_token := 0

# Dash placeholder
var is_dashing := false

# Nugget counter
var nuggets: int = 0

func add_nuggets(amount: int) -> void:
	nuggets += amount


func _ready() -> void:
	ammo = mag_size
	emit_signal("ammo_changed", ammo, mag_size)

	shot_timer.one_shot = true
	reload_timer.one_shot = true
	hit_timer.one_shot = true

	shot_timer.timeout.connect(_on_shot_timer_finished)
	reload_timer.timeout.connect(_on_reload_finished)
	hit_timer.timeout.connect(_on_hit_stutter_finished)

	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)

	reload_anim_speed_restore = anim.speed_scale
	visual_base_scale = visual.scale
	play_anim("idle")
	_set_crosshair_idle()

	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	last_mouse_pos = get_global_mouse_position()


func _physics_process(delta: float) -> void:
	if get_tree().paused:
		if not was_paused_last_frame:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			was_paused_last_frame = true

		if crosshair != null:
			crosshair.visible = false
		return
	else:
		if was_paused_last_frame:
			Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
			was_paused_last_frame = false

	# ----------------------------
	# Tick animation timers
	# ----------------------------
	idle_pulse_time += delta

	if shoot_anim_timer > 0.0:
		shoot_anim_timer = max(0.0, shoot_anim_timer - delta)

	if reloading and reload_anim_delay_timer > 0.0:
		reload_anim_delay_timer = max(0.0, reload_anim_delay_timer - delta)

	if crosshair_fire_timer > 0.0:
		crosshair_fire_timer = max(0.0, crosshair_fire_timer - delta)

	# ----------------------------
	# 1) Movement (360)
	# ----------------------------
	var input_vec := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	)

	if input_vec.length() > 0.0:
		input_vec = input_vec.normalized()
		velocity = velocity.move_toward(input_vec * max_speed, acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)

	move_and_slide()

	# Smoothly blend movement feel between idle and moving.
	var speed_ratio: float = clampf(velocity.length() / maxf(1.0, max_speed), 0.0, 1.0)
	move_blend = move_toward(move_blend, speed_ratio, move_blend_smoothing * delta)
	_update_visual_squash()
	_handle_walk_puffs(delta)

	# ----------------------------
	# 2) Aim input (arrow keys + mouse fallback)
	# ----------------------------
	var arrow_input := Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
	var mouse_pos := get_global_mouse_position()
	var mouse_moved := mouse_pos.distance_to(last_mouse_pos) > 0.5

	if arrow_input != Vector2.ZERO:
		keyboard_aim = arrow_input.normalized()
		using_keyboard_aim = true
		using_mouse_aim = false
		aim_dir = keyboard_aim
	elif mouse_moved:
		using_mouse_aim = true
		using_keyboard_aim = false

		var mouse_dir := mouse_pos - global_position
		if mouse_dir.length() > 0.001:
			aim_dir = mouse_dir.normalized()

	last_mouse_pos = mouse_pos

	_update_crosshair_transform()

	var is_keyboard_shooting := using_keyboard_aim and arrow_input != Vector2.ZERO
	var is_mouse_shooting := Input.is_action_pressed("attack")

	if is_mouse_shooting or is_keyboard_shooting:
		update_facing(aim_dir)
	elif input_vec != Vector2.ZERO:
		update_facing(input_vec)

	# ----------------------------
	# 2.5) Muzzle positioning (fixed spot)
	# ----------------------------
	var off := muzzle_local_offset
	off.x *= (1.0 if facing_right else -1.0)
	muzzle.global_position = global_position + off

	# ----------------------------
	# 3) Manual reload (R)
	# ----------------------------
	if InputMap.has_action("reload") and Input.is_action_just_pressed("reload"):
		start_reload(false)

	# ----------------------------
	# 4) Dash placeholder (Space)
	# ----------------------------
	if InputMap.has_action("dash") and Input.is_action_just_pressed("dash"):
		try_dash()

	# ----------------------------
	# 5) Shooting
	# Mouse = normal fire
	# Arrow aim = auto-fire while held
	# ----------------------------
	var fired_this_frame := false
	if Input.is_action_pressed("attack"):
		fired_this_frame = try_attack()
	elif using_keyboard_aim and arrow_input != Vector2.ZERO:
		fired_this_frame = try_attack()

	# ----------------------------
	# 6) Animation priority
	# ----------------------------
	_update_animation()
	_update_crosshair_state(fired_this_frame)


func _update_animation() -> void:
	# Highest priority: dash
	if is_dashing:
		_set_anim_speed_default()
		play_anim("dash")
		return

	# Reload visual (with delay so last shot reads)
	if reloading:
		if reload_anim_delay_timer > 0.0:
			_set_anim_speed_default()
			if shoot_anim_timer > 0.0:
				play_anim("shoot")
			else:
				play_anim("idle")
			return

		_fit_reload_anim_to_reload_time()
		play_anim("reload")
		return

	# Shoot hold window
	if shoot_anim_timer > 0.0:
		_set_anim_speed_default()
		play_anim("shoot")
		return

	# Default: idle
	_set_anim_speed_default()
	if move_blend > 0.08 and anim != null and anim.sprite_frames != null and anim.sprite_frames.has_animation("walk"):
		play_anim("walk")
	else:
		play_anim("idle")


func update_facing(dir: Vector2) -> void:
	if dir.x == 0.0:
		return

	var face_right := dir.x > 0.0
	if face_right == facing_right:
		return

	facing_right = face_right
	anim.flip_h = not facing_right
	shadow.flip_h = not facing_right


func try_attack() -> bool:
	if reloading or not can_attack:
		return false

	# Auto reload when empty
	if ammo <= 0:
		start_reload(true)
		return false

	return attack()


func attack() -> bool:
	if projectile_scene == null:
		return false

	ammo -= 1
	emit_signal("ammo_changed", ammo, mag_size)
	can_attack = false

	shot_timer.wait_time = shot_cooldown
	shot_timer.start()

	var p := projectile_scene.instantiate()
	get_tree().current_scene.add_child(p)
	p.global_position = muzzle.global_position
	p.call("fire", aim_dir, self)

	# Keep shoot visible for a moment
	shoot_anim_timer = shoot_anim_hold
	crosshair_fire_timer = crosshair_fire_hold

	# If we just emptied the mag, start reload immediately
	if ammo <= 0:
		start_reload(true)

	return true


# force_delay:
# - true  = use reload_anim_delay so the last shot reads
# - false = same for now, left here for future control
func start_reload(force_delay: bool) -> void:
	if reloading:
		return

	if ammo >= mag_size:
		return

	reloading = true
	can_attack = false

	reload_timer.wait_time = reload_time
	reload_timer.start()

	reload_anim_delay_timer = reload_anim_delay if force_delay else reload_anim_delay


func try_dash() -> void:
	# Reserved for future unlock
	# Add real dash logic later when progression unlock is live
	pass


func _on_shot_timer_finished() -> void:
	if not reloading:
		can_attack = true


func _on_reload_finished() -> void:
	ammo = mag_size
	emit_signal("ammo_changed", ammo, mag_size)
	reloading = false
	can_attack = true

	reload_anim_delay_timer = 0.0
	_set_anim_speed_default()


func play_anim(anim_name: String) -> void:
	if current_anim == anim_name:
		return

	current_anim = anim_name

	if anim != null and anim.sprite_frames != null and anim.sprite_frames.has_animation(anim_name):
		anim.play(anim_name)


# ----------------------------
# Reload anim timing helpers
# ----------------------------
func _fit_reload_anim_to_reload_time() -> void:
	if anim == null or anim.sprite_frames == null:
		return
	if not anim.sprite_frames.has_animation("reload"):
		return

	var frames := anim.sprite_frames.get_frame_count("reload")
	if frames <= 1:
		anim.speed_scale = 1.0
		return

	var fps := anim.sprite_frames.get_animation_speed("reload")
	if fps <= 0.0:
		fps = 5.0

	var desired := reload_time
	if desired <= 0.01:
		desired = 0.01

	# Duration = frames / (fps * speed_scale)
	# speed_scale = frames / (fps * desired)
	anim.speed_scale = float(frames) / (fps * desired)


func _set_anim_speed_default() -> void:
	anim.speed_scale = reload_anim_speed_restore


func _update_visual_squash() -> void:
	if visual == null:
		return

	var pulse: float = sin(TAU * idle_pulse_hz * idle_pulse_time)
	var amount: float = lerpf(idle_squash_amount, move_squash_amount, move_blend) * pulse
	var sy: float = 1.0 - amount
	var sx: float = 1.0 + (amount * 0.35)
	visual.scale = Vector2(visual_base_scale.x * sx, visual_base_scale.y * sy)


func _handle_walk_puffs(delta: float) -> void:
	if not enable_walk_puffs:
		return

	if velocity.length() < walk_puff_speed_threshold:
		walk_step_timer = 0.0
		return

	if walk_step_timer > 0.0:
		walk_step_timer -= delta
		return

	_spawn_walk_puff()
	var speed_ratio: float = clampf(velocity.length() / maxf(1.0, max_speed), 0.0, 1.0)
	walk_step_timer = lerpf(walk_puff_step_interval * 1.2, walk_puff_step_interval * 0.7, speed_ratio)


func _spawn_walk_puff() -> void:
	var puff := GPUParticles2D.new()
	puff.one_shot = true
	puff.emitting = false
	puff.amount = 16
	puff.lifetime = 0.40
	puff.explosiveness = 0.95
	puff.preprocess = 0.0
	puff.local_coords = false
	puff.draw_order = GPUParticles2D.DRAW_ORDER_LIFETIME
	puff.modulate = walk_puff_color
	puff.global_position = global_position + Vector2(0.0, 10.0)

	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0.0, -0.2, 0.0)
	mat.spread = 60.0
	mat.initial_velocity_min = 22.0
	mat.initial_velocity_max = 58.0
	mat.gravity = Vector3(0.0, 40.0, 0.0)
	mat.scale_min = 2.8
	mat.scale_max = 4.4
	mat.damping_min = 14.0
	mat.damping_max = 22.0
	mat.angular_velocity_min = -180.0
	mat.angular_velocity_max = 180.0
	mat.color = walk_puff_color
	puff.process_material = mat

	var parent := get_tree().current_scene
	if parent == null:
		parent = get_parent()
	if parent == null:
		return

	parent.add_child(puff)
	puff.emitting = true
	get_tree().create_timer(0.65).timeout.connect(puff.queue_free)


func _update_crosshair_transform() -> void:
	if crosshair == null:
		return

	if get_tree().paused:
		crosshair.visible = false
		return

	crosshair.visible = using_mouse_aim
	if not crosshair.visible:
		return

	crosshair.global_position = get_global_mouse_position()


func _update_crosshair_state(_fired_this_frame: bool) -> void:
	if crosshair_sprite == null:
		return
	if crosshair_sprite.sprite_frames == null:
		return

	if not using_mouse_aim:
		_set_crosshair_idle()
		return

	if crosshair_fire_timer > 0.0:
		_set_crosshair_fire()
	else:
		_set_crosshair_idle()


func _set_crosshair_idle() -> void:
	if crosshair_sprite == null:
		return
	if crosshair_sprite.sprite_frames == null:
		return
	if not crosshair_sprite.sprite_frames.has_animation("idle"):
		return

	if crosshair_sprite.animation != "idle":
		crosshair_sprite.play("idle")
		crosshair_sprite.stop()


func _set_crosshair_fire() -> void:
	if crosshair_sprite == null:
		return
	if crosshair_sprite.sprite_frames == null:
		return
	if not crosshair_sprite.sprite_frames.has_animation("fire"):
		return

	if crosshair_sprite.animation != "fire":
		crosshair_sprite.play("fire")
		crosshair_sprite.stop()


# ----------------------------
# HEALTH-DRIVEN REACTIONS
# ----------------------------
func _on_damaged(info: DamageInfo) -> void:
	var kb_dir: Vector2 = info.direction
	if kb_dir == Vector2.ZERO:
		kb_dir = (global_position - info.world_pos).normalized()

	velocity = kb_dir * contact_knockback

	can_attack = false
	hit_timer.wait_time = hit_stutter_time
	hit_timer.start()
	emit_signal("damaged_feedback")
	get_tree().call_group("hud", "show_damage_feedback")

	flash_token += 1
	var t := flash_token

	anim.modulate = hit_flash_color

	await get_tree().create_timer(flash_time).timeout
	if t != flash_token:
		return

	anim.modulate = Color(1, 1, 1, 1)


func _on_died(_info: DamageInfo) -> void:
	pass


func _on_hit_stutter_finished() -> void:
	if not reloading:
		can_attack = true
