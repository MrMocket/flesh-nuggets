extends Node
class_name HealthComponent

signal containers_changed(current: int, max: int)
signal damaged(info: DamageInfo)
signal died(info: DamageInfo)

@export var max_containers: int = 3
@export var start_full: bool = true

var containers: int


func _ready() -> void:
	containers = max_containers if start_full else 1
	emit_signal("containers_changed", containers, max_containers)


func set_max_containers(new_max: int, keep_ratio: bool = false) -> void:
	new_max = max(1, new_max)

	if keep_ratio:
		var ratio := float(containers) / float(max_containers)
		max_containers = new_max
		containers = clamp(int(round(ratio * max_containers)), 0, max_containers)
	else:
		max_containers = new_max
		containers = clamp(containers, 0, max_containers)

	emit_signal("containers_changed", containers, max_containers)


func heal(amount: int) -> void:
	if amount <= 0:
		return
	containers = clamp(containers + amount, 0, max_containers)
	emit_signal("containers_changed", containers, max_containers)


func apply_damage(info: DamageInfo) -> void:
	if containers <= 0:
		return

	containers = max(0, containers - max(1, info.amount))
	emit_signal("containers_changed", containers, max_containers)
	emit_signal("damaged", info)

	if containers <= 0:
		emit_signal("died", info)
