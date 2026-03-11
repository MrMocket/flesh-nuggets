extends Area2D

@export var value: int = 1
@export var play_spawn: bool = true
@export var idle_bob_height := 2.2
@export var idle_bob_speed := 1.7
@export var idle_tilt_degrees := 1.8
@export var spawn_settle_time := 0.11

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var col: CollisionShape2D = $CollisionShape2D

var _picked := false
var _idle_t := 0.0
var _base_sprite_pos := Vector2.ZERO
var _base_rot := 0.0


func _ready() -> void:
	# (optional) useful for debugging / organization
	add_to_group("drops")
	if anim:
		_base_sprite_pos = anim.position
		_base_rot = anim.rotation

	body_entered.connect(_on_body_entered)

	# Optional spawn anim
	if play_spawn and anim and anim.sprite_frames and anim.sprite_frames.has_animation("spawn"):
		_play_spawn_settle()
		anim.play("spawn")
		await anim.animation_finished

	_play_idle()


func _process(delta: float) -> void:
	if _picked:
		return
	if anim == null:
		return

	_idle_t += delta
	anim.position.y = _base_sprite_pos.y + sin(_idle_t * TAU * idle_bob_speed) * idle_bob_height
	anim.rotation = _base_rot + deg_to_rad(sin(_idle_t * TAU * (idle_bob_speed * 0.6)) * idle_tilt_degrees)


func _play_idle() -> void:
	if anim and anim.sprite_frames and anim.sprite_frames.has_animation("idle"):
		anim.speed_scale = 0.82
		anim.play("idle")


func _play_spawn_settle() -> void:
	if anim == null:
		return

	anim.scale = Vector2(0.11, 0.11)
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_BACK)
	tw.set_ease(Tween.EASE_OUT)
	tw.tween_property(anim, "scale", Vector2(0.125, 0.125), spawn_settle_time)


func _on_body_entered(body: Node) -> void:
	if _picked:
		return
	if body == null:
		return
	if not body.is_in_group("player"):
		return

	_picked = true

	# IMPORTANT: defer changes to avoid "Can't change this state while flushing queries"
	if col:
		col.set_deferred("disabled", true)
	set_deferred("monitoring", false)

	# Give value to player (optional)
	if body.has_method("add_nuggets"):
		body.add_nuggets(value)

	# Send screen-space pickup point so the fly animation lands consistently in HUD space.
	var pickup_screen_pos := get_global_transform_with_canvas().origin
	get_tree().call_group("hud", "collect_nugget_from_screen", pickup_screen_pos, value)

	# Play pickup anim if it exists
	if anim and anim.sprite_frames and anim.sprite_frames.has_animation("pickup"):
		anim.play("pickup")
		await anim.animation_finished

	# Defer freeing too (safe)
	call_deferred("queue_free")
