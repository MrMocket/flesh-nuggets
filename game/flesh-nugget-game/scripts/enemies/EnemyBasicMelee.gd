extends CharacterBody2D

enum State { ACQUIRE, CHASE, WINDUP, LUNGE, RECOVERY, EVADE }

# ----------------------------
# Blood drop (NEW)
# ----------------------------
@export var blood_splat_scene: PackedScene
@export var blood_z_index := -10

# ----------------------------
# Nugget Drop
# ----------------------------
@export var nugget_drop_scene: PackedScene
@export var drop_chance := 1.0 # 1.0 = always
# ----------------------------
# Engagement
# ----------------------------
@export var wake_delay := 0.6
@export var web_wake_jitter := 1.5
@export var web_spawn_grace_time := 1.1
@export var aggro_range := 900.0
@export var disengage_range := 1400.0
var wake_timer := 0.0
var aggroed := false

# ----------------------------
# Movement feel
# ----------------------------
@export var max_speed := 175.0
@export var acceleration := 1100.0
@export var friction := 900.0

# Subtle squash while idle/moving
@export var squash_pulse_hz := 1.6
@export var idle_squash_amount := 0.020
@export var move_squash_amount := 0.010
@export var squash_move_smoothing := 8.0

# Enemy walk puffs
@export var enable_walk_puffs := true
@export var disable_walk_puffs_on_web := false
@export var web_walk_puff_amount_scale := 0.5
@export var web_walk_puff_lifetime_scale := 0.75
@export var web_walk_puff_interval_scale := 1.35
@export var walk_puff_color := Color(0.92, 0.92, 0.92, 0.92)
@export var walk_puff_step_interval := 0.17
@export var walk_puff_speed_threshold := 40.0

@export var close_bump_range := 55.0
@export var orbit_strength := 0.75
@export var approach_bias := 0.35

@export var strafe_change_time := 0.7
var strafe_timer := 0.0
var strafe_sign := 1.0

# ----------------------------
# Idle roam (before aggro)
# ----------------------------
@export var roam_enabled := true
@export var roam_speed := 90.0
@export var roam_change_time := 1.2
var roam_timer := 0.0
var roam_dir := Vector2.ZERO

# ----------------------------
# Pack steering
# ----------------------------
@export var separation_radius := 70.0
@export var separation_strength := 0.95
@export var pack_flank_strength := 0.35
@export var neighbor_max := 6

# ----------------------------
# Lunge tuning
# ----------------------------
@export var lunge_min_range := 85.0
@export var lunge_max_range := 175.0

@export var windup_time := 0.30
@export var lunge_time := 0.30
@export var recovery_time := 0.55

@export var lunge_speed := 390.0
@export var lunge_cooldown := 1.15

# Slide/skid
@export var recovery_friction := 350.0
@export var post_lunge_slide_time := 0.15

var lunge_cd := 0.0
var lunge_direction := Vector2.ZERO
var post_slide_timer := 0.0

# ----------------------------
# Windup backstep
# ----------------------------
@export var windup_backstep_speed := 95.0
@export var windup_backstep_max := 22.0
var windup_backstepped := 0.0

# ----------------------------
# Pack lunge coordination
# ----------------------------
@export var max_pack_lunges := 1
@export var pack_lunge_radius := 260.0
@export var lunge_retry_min := 0.10
@export var lunge_retry_max := 0.22
var lunge_retry_timer := 0.0

# ----------------------------
# Contact damage
# ----------------------------
@export var contact_damage := 1
@export var contact_knockback := 200.0
@export var contact_hitstun := 0.0
@export var contact_interval := 0.55
var hit_cd := 0.0

# ----------------------------
# Evade when shot
# ----------------------------
@export var enable_evade_on_hit := true
@export var evade_speed := 260.0
@export var evade_time := 0.18
@export var evade_cooldown := 1.2
var evade_cd := 0.0
var evade_dir := Vector2.ZERO
var evade_timer := 0.0

# ----------------------------
# Hit feedback
# ----------------------------
@export var flash_time := 0.08
@export var flash_alpha := 0.5
@export var hit_flash_color := Color(1.0, 0.45, 0.45, 1.0)
var _flash_token := 0

# Death pop (visual only, does not move root/drop spawn point)
@export var death_pop_in_scale := 1.18
@export var death_pop_out_scale := 0.88
@export var death_pop_in_time := 0.055
@export var death_pop_out_time := 0.08

# ----------------------------
# Lunge bounce + anti-tunneling
# ----------------------------
@export var lunge_bounce_enabled := true
@export var lunge_bounce_damping_world := 0.85
@export var lunge_max_bounces := 2
@export var lunge_bounce_pushout := 2.0
@export var lunge_substep_px := 8.0
@export var lunge_substep_max := 12

@export var debug_lunge_hits := false

var lunge_bounces_left := 0

@onready var health := $Health as HealthComponent
@onready var damage_hitbox: Area2D = $DamageHitbox
@onready var visual: Node2D = $Visual
@onready var anim: AnimatedSprite2D = $Visual/AnimatedSprite2D
@onready var shadow: Sprite2D = $Shadow

var player: Node2D = null
var player_hurtbox: Hurtbox = null

var state: State = State.ACQUIRE
var state_timer := 0.0
var _current_anim := ""
var _squash_time := 0.0
var _move_blend := 0.0
var _visual_base_scale := Vector2.ONE
var _walk_step_timer := 0.0
var _life_time := 0.0

static var _enemies_cache_frame: int = -1
static var _enemies_cache: Array = []


func _ready() -> void:
	if disable_walk_puffs_on_web and OS.has_feature("web"):
		enable_walk_puffs = false

	add_to_group("enemies")
	randomize()

	roam_timer = randf_range(0.0, roam_change_time)
	roam_dir = Vector2.RIGHT.rotated(randf() * TAU)

	health.died.connect(_on_died)
	health.damaged.connect(_on_damaged)

	if OS.has_feature("web"):
		wake_timer = wake_delay + randf_range(0.0, web_wake_jitter)
	else:
		wake_timer = wake_delay
	player = get_tree().get_first_node_in_group("player") as Node2D

	damage_hitbox.area_entered.connect(_on_damage_area_entered)
	damage_hitbox.area_exited.connect(_on_damage_area_exited)

	strafe_sign = -1.0 if randi() % 2 == 0 else 1.0
	strafe_timer = randf_range(0.0, strafe_change_time)

	lunge_cd = randf_range(0.0, lunge_cooldown * 0.75)
	evade_cd = randf_range(0.0, evade_cooldown * 0.75)
	lunge_retry_timer = randf_range(0.0, 0.25)
	_walk_step_timer = randf_range(0.0, walk_puff_step_interval * (web_walk_puff_interval_scale if OS.has_feature("web") else 1.0))
	_visual_base_scale = visual.scale

	state = State.ACQUIRE
	_play_anim("idle")


func _physics_process(delta: float) -> void:
	_squash_time += delta
	_life_time += delta

	if wake_timer > 0.0:
		wake_timer -= delta
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
		move_and_slide()
		_update_movement_fx(delta)
		return

	if player == null:
		player = get_tree().get_first_node_in_group("player") as Node2D
		if player == null:
			_update_movement_fx(delta)
			return

	# cooldown timers
	if hit_cd > 0.0: hit_cd = max(0.0, hit_cd - delta)
	if lunge_cd > 0.0: lunge_cd = max(0.0, lunge_cd - delta)
	if evade_cd > 0.0: evade_cd = max(0.0, evade_cd - delta)
	if lunge_retry_timer > 0.0: lunge_retry_timer = max(0.0, lunge_retry_timer - delta)

	# strafing timer
	strafe_timer -= delta
	if strafe_timer <= 0.0:
		strafe_timer = strafe_change_time
		strafe_sign *= -1.0

	# aggro
	var dist_to_player := global_position.distance_to(player.global_position)
	if not aggroed and dist_to_player <= aggro_range:
		aggroed = true
	if aggroed and dist_to_player > disengage_range:
		aggroed = false

	# pre-aggro behaviour
	if not aggroed:
		_process_roam(delta)
		_update_movement_fx(delta)
		return

	# main state machine
	match state:
		State.ACQUIRE: _enter_chase()
		State.CHASE: _process_chase(delta)
		State.WINDUP: _process_windup(delta)
		State.LUNGE: _process_lunge(delta)
		State.RECOVERY: _process_recovery(delta)
		State.EVADE: _process_evade(delta)

	# bump damage always, obey contact_interval
	if player_hurtbox != null and hit_cd <= 0.0:
		_apply_contact_hit(player_hurtbox)

	_update_movement_fx(delta)


# ----------------------------
# Roam
# ----------------------------
func _process_roam(delta: float) -> void:
	_play_anim("idle")

	if not roam_enabled:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
		move_and_slide()
		return

	roam_timer -= delta
	if roam_timer <= 0.0 or roam_dir == Vector2.ZERO:
		roam_timer = roam_change_time
		roam_dir = Vector2.RIGHT.rotated(randf() * TAU)

	velocity = velocity.move_toward(roam_dir * roam_speed, acceleration * delta)
	move_and_slide()

	# If we bonked a wall, bounce roam direction
	if get_slide_collision_count() > 0:
		var n := get_slide_collision(0).get_normal()
		if n != Vector2.ZERO:
			roam_dir = roam_dir.bounce(n).normalized()
			roam_timer = roam_change_time * 0.6

	_update_facing(velocity.normalized())


# ----------------------------
# Chase
# ----------------------------
func _process_chase(delta: float) -> void:
	var to_player := player.global_position - global_position
	var dist := to_player.length()
	var chase_dir := to_player.normalized() if dist > 0.001 else Vector2.ZERO
	var is_web_grace := OS.has_feature("web") and _life_time < web_spawn_grace_time

	if is_web_grace:
		velocity = velocity.move_toward(chase_dir * max_speed, acceleration * delta)
		move_and_slide()
		_update_facing(velocity.normalized() if velocity.length() > 0.001 else chase_dir)
		_play_anim("idle")
		return

	var perp := Vector2(-chase_dir.y, chase_dir.x) * strafe_sign

	var sep := _compute_separation()
	var flank := perp * pack_flank_strength

	var desired_dir := chase_dir
	if dist <= close_bump_range:
		desired_dir = (perp * orbit_strength) + (chase_dir * approach_bias) + sep
	else:
		desired_dir = chase_dir + (perp * 0.25) + flank + sep

	if desired_dir.length() > 0.001:
		desired_dir = desired_dir.normalized()

	velocity = velocity.move_toward(desired_dir * max_speed, acceleration * delta)
	move_and_slide()

	_update_facing(velocity.normalized() if velocity.length() > 0.001 else chase_dir)
	_play_anim("idle")

	# Lunge gating
	if lunge_cd <= 0.0 and lunge_retry_timer <= 0.0 and dist >= lunge_min_range and dist <= lunge_max_range:
		if _pack_lunge_slots_used() < max_pack_lunges:
			_enter_windup()
		else:
			lunge_retry_timer = randf_range(lunge_retry_min, lunge_retry_max)


func _compute_separation() -> Vector2:
	var sum := Vector2.ZERO
	var count := 0
	var enemies := _get_enemies_group_cached()

	for e in enemies:
		if e == self:
			continue
		if not (e is Node2D):
			continue
		var other := e as Node2D
		var d := global_position.distance_to(other.global_position)
		if d <= 0.001 or d > separation_radius:
			continue

		var away := (global_position - other.global_position).normalized()
		sum += away * (1.0 - (d / separation_radius))
		count += 1
		if count >= neighbor_max:
			break

	if count == 0:
		return Vector2.ZERO

	return (sum / float(count)) * separation_strength


# ----------------------------
# Pack lunge coordination helpers
# ----------------------------
func is_pack_lunging() -> bool:
	return state == State.WINDUP or state == State.LUNGE


func _pack_lunge_slots_used() -> int:
	var used := 0
	var enemies := _get_enemies_group_cached()

	for e in enemies:
		if e == self:
			continue
		if not (e is Node2D):
			continue
		var other := e as Node2D

		if other.global_position.distance_to(player.global_position) > pack_lunge_radius:
			continue

		if other.has_method("is_pack_lunging") and other.is_pack_lunging():
			used += 1
			if used >= max_pack_lunges:
				break

	return used


func _get_enemies_group_cached() -> Array:
	var frame := Engine.get_process_frames()
	if _enemies_cache_frame != frame:
		_enemies_cache_frame = frame
		_enemies_cache = get_tree().get_nodes_in_group("enemies")
	return _enemies_cache


# ----------------------------
# Windup / Lunge / Recovery
# ----------------------------
func _process_windup(delta: float) -> void:
	state_timer -= delta

	if windup_backstep_speed > 0.0 and windup_backstepped < windup_backstep_max and lunge_direction != Vector2.ZERO:
		var step := windup_backstep_speed * delta
		if windup_backstepped + step > windup_backstep_max:
			step = windup_backstep_max - windup_backstepped
		windup_backstepped += step
		velocity = -lunge_direction * (step / max(delta, 0.00001))
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)

	move_and_slide()

	if state_timer <= 0.0:
		_enter_lunge()


func _process_lunge(delta: float) -> void:
	state_timer -= delta

	# Move in small steps so we can't tunnel through walls/enemies
	var total_move := lunge_direction * lunge_speed * delta
	var steps := int(ceil(total_move.length() / max(lunge_substep_px, 0.001)))
	steps = clamp(steps, 1, lunge_substep_max)
	var step_vec := total_move / float(steps)

	for _i in range(steps):
		var col := move_and_collide(step_vec)
		if col:
			var n := col.get_normal()
			if debug_lunge_hits:
				print("LUNGE HIT: ", col.get_collider(), " normal=", n)

			# IMPORTANT: ignore player bounce, but bounce off world/enemies
			var collider := col.get_collider()
			var hit_player := false
			if collider is Node:
				hit_player = (collider as Node).is_in_group("player")

			if hit_player:
				# stop lunge on player contact (no bounce)
				_enter_recovery()
				return

			# bounce off walls + enemies
			if lunge_bounce_enabled and lunge_bounces_left > 0 and n != Vector2.ZERO:
				lunge_direction = lunge_direction.bounce(n).normalized()
				lunge_speed *= lunge_bounce_damping_world
				lunge_bounces_left -= 1
				global_position += n * lunge_bounce_pushout

			break

	# Fallback: if we slid into a wall, still bounce
	if lunge_bounce_enabled and lunge_bounces_left > 0 and get_slide_collision_count() > 0:
		var c := get_slide_collision(0)
		var n2 := c.get_normal()
		if n2 != Vector2.ZERO:
			var collider2 := c.get_collider()
			var hit_player2 := false
			if collider2 is Node:
				hit_player2 = (collider2 as Node).is_in_group("player")
			if not hit_player2:
				lunge_direction = lunge_direction.bounce(n2).normalized()
				lunge_speed *= lunge_bounce_damping_world
				lunge_bounces_left -= 1
				global_position += n2 * lunge_bounce_pushout

	velocity = lunge_direction * lunge_speed
	_update_facing(lunge_direction)
	_play_anim("lunge")

	if state_timer <= 0.0:
		_enter_recovery()


func _process_recovery(delta: float) -> void:
	state_timer -= delta

	if post_slide_timer > 0.0:
		post_slide_timer -= delta
		velocity = velocity.move_toward(Vector2.ZERO, recovery_friction * 0.4 * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, recovery_friction * delta)

	move_and_slide()

	if state_timer <= 0.0:
		_enter_chase()


func _enter_chase() -> void:
	state = State.CHASE


func _enter_windup() -> void:
	state = State.WINDUP
	state_timer = windup_time

	var to_player := player.global_position - global_position
	lunge_direction = to_player.normalized() if to_player.length() > 0.001 else Vector2.ZERO

	windup_backstepped = 0.0

	_update_facing(lunge_direction)
	_play_anim("windup")


func _enter_lunge() -> void:
	state = State.LUNGE
	state_timer = lunge_time
	lunge_cd = lunge_cooldown + randf_range(0.0, 0.3)

	lunge_bounces_left = lunge_max_bounces

	_update_facing(lunge_direction)
	_play_anim("lunge")


func _enter_recovery() -> void:
	state = State.RECOVERY
	state_timer = recovery_time
	post_slide_timer = post_lunge_slide_time
	_play_anim("recovery")


# ----------------------------
# Evade
# ----------------------------
func _process_evade(delta: float) -> void:
	evade_timer -= delta
	velocity = evade_dir * evade_speed
	move_and_slide()

	_update_facing(evade_dir)
	_play_anim("evade")

	if evade_timer <= 0.0:
		_enter_chase()


func _try_evade(from_dir: Vector2) -> void:
	if not enable_evade_on_hit:
		return
	if evade_cd > 0.0:
		return
	if state == State.LUNGE:
		return

	var side := Vector2(-from_dir.y, from_dir.x)
	if randf() < 0.5:
		side = -side

	evade_dir = (side * 0.85 + (-from_dir) * 0.15).normalized()
	state = State.EVADE
	evade_timer = evade_time
	evade_cd = evade_cooldown + randf_range(0.0, 0.3)

	_update_facing(evade_dir)
	_play_anim("evade")


# ----------------------------
# Damage hitbox overlap tracking
# ----------------------------
func _on_damage_area_entered(area: Area2D) -> void:
	if area is Hurtbox:
		player_hurtbox = area as Hurtbox


func _on_damage_area_exited(area: Area2D) -> void:
	if area == player_hurtbox:
		player_hurtbox = null


func _apply_contact_hit(hb: Hurtbox) -> void:
	hit_cd = contact_interval
	var info := DamageInfo.new()
	info.amount = contact_damage
	info.knockback = contact_knockback
	info.hitstun = contact_hitstun
	info.source = self
	info.direction = (hb.global_position - global_position).normalized()
	info.world_pos = global_position
	hb.receive_hit(info)


# ----------------------------
# Health signals
# ----------------------------
func _on_damaged(info: DamageInfo) -> void:
	_flash_token += 1
	var t := _flash_token

	anim.modulate = hit_flash_color

	if info != null and info.direction != Vector2.ZERO:
		_try_evade(info.direction)

	await get_tree().create_timer(flash_time).timeout
	if t != _flash_token:
		return

	anim.modulate = Color(1, 1, 1, 1)


func _on_died(_info: DamageInfo) -> void:
	_spawn_blood()
	_spawn_drop()
	await _play_death_pop()
	queue_free()


func _play_death_pop() -> void:
	if visual == null:
		return

	var base_scale := _visual_base_scale if _visual_base_scale != Vector2.ZERO else visual.scale
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_BACK)
	tw.set_ease(Tween.EASE_OUT)
	tw.tween_property(visual, "scale", base_scale * death_pop_in_scale, death_pop_in_time)
	tw.tween_property(visual, "scale", base_scale * death_pop_out_scale, death_pop_out_time)
	await tw.finished
	
	
# ----------------------------
# Drop spawn helper (NEW)
# ----------------------------
func _spawn_drop() -> void:
	if nugget_drop_scene == null:
		return
	if randf() > drop_chance:
		return

	var drops := get_tree().get_first_node_in_group("drops")
	if drops == null:
		drops = get_tree().current_scene

	var d := nugget_drop_scene.instantiate() as Node2D
	drops.call_deferred("add_child", d)
	d.set_deferred("global_position", global_position)
	
	
# ----------------------------
# Blood spawn helper (NEW)
# ----------------------------
func _spawn_blood() -> void:
	if blood_splat_scene == null:
		return

	var decals := get_tree().get_first_node_in_group("decals")
	if decals == null:
		decals = get_tree().current_scene

	var b := blood_splat_scene.instantiate() as Node2D
	decals.add_child(b)

	b.global_position = global_position


# ----------------------------
# Facing + Anim helpers
# ----------------------------
func _update_facing(dir: Vector2) -> void:
	if dir.x == 0.0:
		return

	var facing_left := dir.x < 0.0
	anim.flip_h = facing_left
	shadow.flip_h = facing_left

func _play_anim(anim_name: String) -> void:
	if _current_anim == anim_name:
		return
	_current_anim = anim_name
	if anim.sprite_frames and anim.sprite_frames.has_animation(anim_name):
		anim.play(anim_name)


func _update_visual_squash(delta: float) -> void:
	if visual == null:
		return

	var speed_ratio: float = clampf(velocity.length() / maxf(1.0, max_speed), 0.0, 1.0)
	_move_blend = move_toward(_move_blend, speed_ratio, squash_move_smoothing * delta)

	var pulse: float = sin(TAU * squash_pulse_hz * _squash_time)
	var amount: float = lerpf(idle_squash_amount, move_squash_amount, _move_blend) * pulse
	var sy: float = 1.0 - amount
	var sx: float = 1.0 + (amount * 0.35)
	visual.scale = Vector2(_visual_base_scale.x * sx, _visual_base_scale.y * sy)


func _handle_walk_puffs(delta: float) -> void:
	if not enable_walk_puffs:
		return

	if velocity.length() < walk_puff_speed_threshold:
		_walk_step_timer = 0.0
		return

	if _walk_step_timer > 0.0:
		_walk_step_timer -= delta
		return

	_spawn_walk_puff()
	var speed_ratio: float = clampf(velocity.length() / maxf(1.0, max_speed), 0.0, 1.0)
	var interval_scale := web_walk_puff_interval_scale if OS.has_feature("web") else 1.0
	_walk_step_timer = lerpf(walk_puff_step_interval * 1.2, walk_puff_step_interval * 0.7, speed_ratio) * interval_scale


func _spawn_walk_puff() -> void:
	var puff := GPUParticles2D.new()
	var is_web := OS.has_feature("web")
	var amount_scale := web_walk_puff_amount_scale if is_web else 1.0
	var life_scale := web_walk_puff_lifetime_scale if is_web else 1.0
	var puff_amount: int = maxi(4, int(round(16.0 * amount_scale)))
	puff.one_shot = true
	puff.emitting = false
	puff.amount = puff_amount
	puff.lifetime = 0.42 * life_scale
	puff.explosiveness = 0.95
	puff.preprocess = 0.0
	puff.local_coords = false
	puff.draw_order = GPUParticles2D.DRAW_ORDER_LIFETIME
	puff.modulate = walk_puff_color
	puff.global_position = global_position + Vector2(0.0, 10.0)

	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0.0, -0.2, 0.0)
	mat.spread = 60.0
	mat.initial_velocity_min = 20.0
	mat.initial_velocity_max = 54.0
	mat.gravity = Vector3(0.0, 40.0, 0.0)
	mat.scale_min = 3.2
	mat.scale_max = 4.9
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
	if not puff.finished.is_connected(puff.queue_free):
		puff.finished.connect(puff.queue_free, CONNECT_ONE_SHOT)
	puff.emitting = true


func _update_movement_fx(delta: float) -> void:
	_update_visual_squash(delta)
	_handle_walk_puffs(delta)
