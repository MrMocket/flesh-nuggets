extends Area2D

@export var speed := 800.0
@export var max_distance := 280.0
@export var damage := 1
@export var knockback := 120.0
@export var hitstun := 0.0
@export var impact_backstep := 6.0

# Shadow layering (tweak if needed)
@export var shadow_z := -100
@export var bullet_z := 10

var dir := Vector2.RIGHT
var shooter: Node = null
var traveled := 0.0
var active := false
var impacting := false

@onready var anim: AnimatedSprite2D = $Visual/AnimatedSprite2D
@onready var shadow: CanvasItem = null


func _ready() -> void:
	# Find shadow in either common location
	shadow = get_node_or_null("Shadow")
	if shadow == null:
		shadow = get_node_or_null("Visual/Shadow")

	# Layer setup (so shadow goes behind characters)
	if shadow:
		shadow.z_index = shadow_z
		shadow.visible = true
		shadow.y_sort_enabled = false

	if anim:
		anim.z_index = bullet_z
		anim.y_sort_enabled = false

	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)

	_play_fly()


func fire(direction: Vector2, shooter_node: Node) -> void:
	dir = direction.normalized()
	shooter = shooter_node

	traveled = 0.0
	active = true
	impacting = false

	set_deferred("monitoring", true)
	set_deferred("monitorable", true)

	if shadow:
		shadow.visible = true

	_play_fly()


func _physics_process(delta: float) -> void:
	if not active:
		return

	var step := speed * delta
	global_position += dir * step
	traveled += step

	if traveled >= max_distance:
		impact()


func _on_area_entered(area: Area2D) -> void:
	if not active or impacting:
		return

	# Prevent hitting shooter / shooter children
	if shooter != null and (area == shooter or shooter.is_ancestor_of(area) or shooter.is_ancestor_of(area.get_parent())):
		return

	if area is Hurtbox:
		var hb := area as Hurtbox

		var info := DamageInfo.new()
		info.amount = damage
		info.knockback = knockback
		info.hitstun = hitstun
		info.source = shooter
		info.direction = dir
		info.world_pos = global_position

		hb.receive_hit(info)

		global_position -= dir * impact_backstep
		impact()


func impact() -> void:
	if not active or impacting:
		return

	active = false
	impacting = true

	# Hide shadow instantly on impact
	if shadow:
		shadow.visible = false

	set_deferred("monitoring", false)
	set_deferred("monitorable", false)

	if anim and anim.sprite_frames and anim.sprite_frames.has_animation("impact"):
		anim.sprite_frames.set_animation_loop("impact", false)
		anim.play("impact")
		await anim.animation_finished

	queue_free()


func _play_fly() -> void:
	if anim == null or anim.sprite_frames == null:
		return

	if anim.sprite_frames.has_animation("fly"):
		anim.sprite_frames.set_animation_loop("fly", true)
		anim.play("fly")
