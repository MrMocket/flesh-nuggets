extends Resource
class_name DamageInfo

@export var amount: int = 1
@export var knockback: float = 0.0
@export var hitstun: float = 0.0

var source: Node = null
var direction: Vector2 = Vector2.ZERO
var world_pos: Vector2 = Vector2.ZERO
