extends CharacterBody2D
signal ammo_changed(current: int, max: int)
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

# ----------------------------
# Weapon / firing
# ----------------------------
@export var projectile_scene: PackedScene
@export var mag_size := 5
@export var shot_cooldown := 0.40
@export var reload_time := 1.20
@export var muzzle_distance := 20.0 # unused now, safe to keep

# Fixed muzzle position relative to player (tweak in Inspector)
@export var muzzle_local_offset := Vector2(10, 8)  # +Y is down

# ----------------------------
# Animation timing
# ----------------------------
@export var shoot_anim_hold := 0.12          # how long "shoot" stays visible
@export var reload_anim_delay := 0.10        # delay before showing "reload" anim

var aim_dir := Vector2.RIGHT
var facing_right := true

var ammo := 0
var reloading := false
var can_attack := true

# Animation
@onready var anim: AnimatedSprite2D = $Visual/AnimatedSprite2D
var current_anim := ""
var shoot_anim_timer := 0.0
var reload_anim_delay_timer := 0.0
var reload_anim_speed_restore := 1.0

# Nodes
@onready var visual: Node2D = $Visual
@onready var shadow: Sprite2D = $Shadow
@onready var muzzle: Marker2D = $Muzzle

@onready var shot_timer: Timer = $ShotTimer
@onready var reload_timer: Timer = $ReloadTimer
@onready var hit_timer: Timer = $HitStutterTimer

@onready var health := $Health as HealthComponent
@onready var hurtbox := $Hurtbox as Hurtbox

var flash_token := 0

# Dash placeholder (we’ll wire this later)
var is_dashing := false

# nugget counter
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
	play_anim("idle")


func _physics_process(delta: float) -> void:
	# tick animation timers
	if shoot_anim_timer > 0.0:
		shoot_anim_timer = max(0.0, shoot_anim_timer - delta)

	if reloading and reload_anim_delay_timer > 0.0:
		reload_anim_delay_timer = max(0.0, reload_anim_delay_timer - delta)

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

	# ----------------------------
	# 2) Aim direction from mouse
	# ----------------------------
	var mouse_pos := get_global_mouse_position()
	aim_dir = (mouse_pos - global_position).normalized()

	update_facing(aim_dir)

	# ----------------------------
	# 2.5) Muzzle positioning (fixed spot)
	# ----------------------------
	var off := muzzle_local_offset
	off.x *= (1.0 if facing_right else -1.0)
	muzzle.global_position = global_position + off

	# ----------------------------
	# 3) Manual reload (R) — only if action exists + mag not full
	# ----------------------------
	if InputMap.has_action("reload") and Input.is_action_just_pressed("reload"):
		start_reload(false) # false = don't force delay; uses normal delay settings

	# ----------------------------
	# 4) Shooting (hold to fire)
	# ----------------------------
	if Input.is_action_pressed("attack"):
		try_attack()

	# ----------------------------
	# 5) Animation priority
	# ----------------------------
	_update_animation()


func _update_animation() -> void:
	# Highest priority: dash (later)
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


func try_attack() -> void:
	if reloading or not can_attack:
		return

	# Auto reload when empty
	if ammo <= 0:
		start_reload(true) # true = use delay after last shot feel
		return

	attack()


func attack() -> void:
	if projectile_scene == null:
		return

	ammo -= 1
	emit_signal("ammo_changed", ammo, mag_size)
	can_attack = false
	
	shot_timer.wait_time = shot_cooldown
	shot_timer.start()

	var p := projectile_scene.instantiate()
	get_tree().current_scene.add_child(p)
	p.global_position = muzzle.global_position
	p.call("fire", aim_dir, self)

	# keep shoot visible for a moment (or sustained while holding fire)
	shoot_anim_timer = shoot_anim_hold

	# If we just emptied the mag, start reload immediately (but delay the reload anim)
	if ammo <= 0:
		start_reload(true)


# force_delay:
# - true  = use reload_anim_delay so the last shot reads
# - false = still uses delay, but this flag exists if you want to change behavior later
func start_reload(force_delay: bool) -> void:
	# Don't restart reload if already reloading
	if reloading:
		return

	# Only reload if mag is not full
	if ammo >= mag_size:
		return

	reloading = true
	can_attack = false

	reload_timer.wait_time = reload_time
	reload_timer.start()

	# Delay the reload animation so the shot reads first
	# (same behaviour for auto + manual reload)
	reload_anim_delay_timer = reload_anim_delay if force_delay else reload_anim_delay


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

	# Duration = frames / (fps * speed_scale) -> speed_scale = frames / (fps * desired)
	anim.speed_scale = float(frames) / (fps * desired)


func _set_anim_speed_default() -> void:
	anim.speed_scale = reload_anim_speed_restore


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

	flash_token += 1
	var t := flash_token

	anim.modulate.a = flash_alpha

	await get_tree().create_timer(flash_time).timeout
	if t != flash_token:
		return

	anim.modulate.a = 1.0


func _on_died(_info: DamageInfo) -> void:
	pass


func _on_hit_stutter_finished() -> void:
	if not reloading:
		can_attack = true
