extends Area2D

@export var value: int = 1
@export var play_spawn: bool = true

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var col: CollisionShape2D = $CollisionShape2D

var _picked := false


func _ready() -> void:
	# (optional) useful for debugging / organization
	add_to_group("drops")

	body_entered.connect(_on_body_entered)

	# Optional spawn anim
	if play_spawn and anim and anim.sprite_frames and anim.sprite_frames.has_animation("spawn"):
		anim.play("spawn")
		await anim.animation_finished

	_play_idle()


func _play_idle() -> void:
	if anim and anim.sprite_frames and anim.sprite_frames.has_animation("idle"):
		anim.play("idle")


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

	# Tell HUD (BEST METHOD): broadcast to any HUD in group "hud"
	get_tree().call_group("hud", "add_nuggets", value)

	# Play pickup anim if it exists
	if anim and anim.sprite_frames and anim.sprite_frames.has_animation("pickup"):
		anim.play("pickup")
		await anim.animation_finished

	# Defer freeing too (safe)
	call_deferred("queue_free")
