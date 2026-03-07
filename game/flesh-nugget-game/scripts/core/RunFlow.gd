extends Node
class_name RunFlow

# Tries these signal names on Player or its HealthComponent.
const DEATH_SIGNALS := ["died", "death", "player_died"]

func _ready() -> void:
	# Run after scene is fully in tree
	call_deferred("_bind_to_player_death")

func _bind_to_player_death() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		push_warning("RunFlow: No node in group 'player' found.")
		return

	# 1) Try signals directly on Player
	if _try_connect_death_signal(player):
		return

	# 2) Try a child HealthComponent by common names
	var hc := player.get_node_or_null("HealthComponent")
	if hc and _try_connect_death_signal(hc):
		return

	# 3) Try any child that has a death-ish signal
	for child in player.get_children():
		if _try_connect_death_signal(child):
			return

	push_warning("RunFlow: Could not find a death signal on Player/HealthComponent.")

func _try_connect_death_signal(node: Node) -> bool:
	for s in DEATH_SIGNALS:
		if node.has_signal(s):
			# Prevent double-connecting
			if not node.is_connected(s, Callable(self, "_on_player_died")):
				node.connect(s, Callable(self, "_on_player_died"))
			return true
	return false

func _on_player_died(_info = null) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player and "nuggets" in player:
		RunState.flesh_collected = player.nuggets

	Router.go_to_death_screen()
