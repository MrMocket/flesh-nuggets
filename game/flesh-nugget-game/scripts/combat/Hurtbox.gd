extends Area2D
class_name Hurtbox

@export var invuln_time: float = 0.15

var _invulnerable := false

@onready var _health: HealthComponent = get_parent().get_node("Health") as HealthComponent
@onready var _timer: Timer = Timer.new()


func _ready() -> void:
	add_child(_timer)
	_timer.one_shot = true
	_timer.timeout.connect(_on_invuln_finished)


func _on_invuln_finished() -> void:
	_invulnerable = false


func receive_hit(info: DamageInfo) -> bool:
	if _invulnerable:
		return false

	_invulnerable = true
	_timer.wait_time = invuln_time
	_timer.start()

	if _health:
		_health.apply_damage(info)

	return true
