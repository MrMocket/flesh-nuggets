extends Node2D

@export var fixed_scale := 0.7  # tweak: 0.6–0.8 usually good

func _ready() -> void:
	global_rotation = 0.0
	scale = Vector2.ONE * fixed_scale
