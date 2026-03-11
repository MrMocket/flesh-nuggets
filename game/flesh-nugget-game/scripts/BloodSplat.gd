extends Node2D

@export var fixed_scale := 0.7  # tweak: 0.6–0.8 usually good
@export var random_scale_jitter := 0.16
@export var random_rotation := false
@export var alpha_min := 0.52
@export var alpha_max := 0.74
@export var settle_in_time := 0.10
@export var settle_start_scale_mul := 0.72

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	if random_rotation:
		global_rotation = randf_range(0.0, TAU)
	else:
		global_rotation = 0.0

	var jitter := randf_range(1.0 - random_scale_jitter, 1.0 + random_scale_jitter)
	var final_scale := Vector2.ONE * (fixed_scale * jitter)
	scale = final_scale * settle_start_scale_mul

	if sprite:
		sprite.modulate.a = randf_range(alpha_min, alpha_max)

	var tw := create_tween()
	tw.set_trans(Tween.TRANS_CUBIC)
	tw.set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", final_scale, settle_in_time)
