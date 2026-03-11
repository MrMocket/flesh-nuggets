extends Node2D
class_name RoomController

# ----------------------------
# Debug (temporary)
# ----------------------------
@export var debug_open_doors_key := true # remove later (dash will use space)
@export var min_open_doors := 1
@export var max_open_doors := 3

# ----------------------------
# Content spawns (MVP)
# ----------------------------
@export var enemy_scene: PackedScene

# NEW: scaling settings
@export var starting_enemies := 2
@export var enemies_per_room := 1
@export var max_enemies := 12
@export var web_spawn_batch_size := 2

# Spawn behaviour
@export var min_spawn_dist_from_player := 180.0
@export var min_spawn_dist_between_enemies := 90.0
@export var spawn_attempts_per_enemy := 20
@export var web_cleanup_batch_size := 8
@export var web_cleanup_settle_frames := 2

# Random spread around room center (tweak to change spawn zone)
@export var spawn_range_x := 260.0
@export var spawn_range_y := 150.0

# ----------------------------
# Fade transition
# ----------------------------
@onready var fade_rect: ColorRect = (
	get_node_or_null("TransitionLayer/UI/Fade") as ColorRect
	if get_node_or_null("TransitionLayer/UI/Fade") != null
	else get_node_or_null("TransitionLayer/Control/Fade") as ColorRect
)

@onready var doors_root: Node = $Gameplay/Doors
@onready var spawn_points: Node = $Gameplay/SpawnPoints
@onready var decals_root: Node = $Decals

var _fade_tween: Tween = null
var entered_from_current: StringName = &"Bottom"
var _is_transitioning := false

var doors: Dictionary = {}
var live_enemies: Array[Node] = []

var enemies_alive: int = 0
var _suppress_enemy_callbacks := false

# NEW: room progression counter
var rooms_entered := 0

# IMPORTANT: we find the global enemies container in Main
@onready var enemies_container: Node = get_tree().get_first_node_in_group("enemies_root")

func _ready() -> void:
	randomize()
	_cache_doors()
	_connect_triggers()

	entered_from_current = &"Bottom"
	if Engine.has_singleton("RunState"):
		entered_from_current = RunState.entered_from

	_reset_room_for_new_entry(entered_from_current)
	_teleport_player_to_spawn(entered_from_current)

	if fade_rect:
		fade_rect.modulate.a = 0.0

func _process(_delta: float) -> void:
	if debug_open_doors_key and Input.is_action_just_pressed("ui_accept"):
		open_random_doors()

# -------------------------------------------------
# Door setup
# -------------------------------------------------
func _cache_doors() -> void:
	doors.clear()
	for door_node in doors_root.get_children():
		var door_name: StringName = door_node.name

		var slab := door_node.get_node_or_null("DoorSlab") as CanvasItem

		var blocker := door_node.get_node_or_null("Blocker") as StaticBody2D
		var blocker_shape: CollisionShape2D = null
		if blocker:
			blocker_shape = blocker.get_node_or_null("CollisionShape2D") as CollisionShape2D

		var data := {
			"node": door_node,
			"slab": slab,
			"red": door_node.get_node_or_null("LightRed") as CanvasItem,
			"green": door_node.get_node_or_null("LightGreen") as CanvasItem,
			"trigger": door_node.get_node_or_null("Trigger") as Area2D,
			"blocker": blocker,
			"blocker_shape": blocker_shape,
			"is_open": false,
		}
		doors[door_name] = data

func _connect_triggers() -> void:
	for door_name in doors.keys():
		var d: Dictionary = doors[door_name]
		var trigger: Area2D = d["trigger"]
		if trigger == null:
			push_warning("Door %s missing Trigger Area2D" % String(door_name))
			continue

		if not trigger.body_entered.is_connected(_on_door_trigger_entered):
			trigger.body_entered.connect(_on_door_trigger_entered.bind(door_name))

# -------------------------------------------------
# Core loop
# -------------------------------------------------
func _reset_room_for_new_entry(entered_from: StringName) -> void:
	entered_from_current = entered_from

	# NEW: bump difficulty each time we enter a room
	rooms_entered += 1

	close_all_doors()
	reroll_decals()

	# Clear global “room leftovers”
	_clear_world_decals_and_drops()

	_suppress_enemy_callbacks = true
	clear_enemies()
	enemies_alive = 0
	_suppress_enemy_callbacks = false

	spawn_enemies_mvp()

	if Engine.has_singleton("RunState"):
		RunState.entered_from = entered_from_current

func close_all_doors() -> void:
	for door_name in doors.keys():
		set_door_open(door_name, false)

func open_random_doors() -> void:
	close_all_doors()

	var candidates: Array[StringName] = []
	for door_name in doors.keys():
		if door_name == entered_from_current:
			continue
		candidates.append(door_name)

	if candidates.is_empty():
		return

	candidates.shuffle()
	var count: int = clamp(randi_range(min_open_doors, max_open_doors), 1, candidates.size())
	for i in range(count):
		set_door_open(candidates[i], true)

func set_door_open(door_name: StringName, open: bool) -> void:
	if not doors.has(door_name):
		return

	var d: Dictionary = doors[door_name]
	d["is_open"] = open
	doors[door_name] = d

	var blocker_shape: CollisionShape2D = d["blocker_shape"]
	if blocker_shape:
		blocker_shape.set_deferred("disabled", open)

	var slab: CanvasItem = d["slab"]
	if slab:
		slab.visible = not open

	var red: CanvasItem = d["red"]
	var green: CanvasItem = d["green"]
	if red:
		red.visible = not open
	if green:
		green.visible = open

# -------------------------------------------------
# Triggers / Travel
# -------------------------------------------------
func _on_door_trigger_entered(body: Node, door_name: StringName) -> void:
	if _is_transitioning:
		return
	if body == null or not body.is_in_group("player"):
		return
	if not doors.has(door_name):
		return
	if doors[door_name]["is_open"] != true:
		return

	_is_transitioning = true
	var entered_from := _opposite_door(door_name)

	await _fade_to(1.0, 0.12)

	print("DOOR TRIGGERED:", door_name)
	RunState.next_room(door_name)
	print("RunState room_index now: ", RunState.room_index)
	RunState.entered_from = entered_from

	await _reset_room_for_transition(entered_from)
	_teleport_player_to_spawn(entered_from)

	await _fade_to(0.0, 0.12)
	_is_transitioning = false

func _opposite_door(door_name: StringName) -> StringName:
	match String(door_name):
		"Top": return &"Bottom"
		"Bottom": return &"Top"
		"Left": return &"Right"
		"Right": return &"Left"
		_: return &"Bottom"

func _teleport_player_to_spawn(door_name: StringName) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return

	var marker_name := "Spawn%s" % String(door_name)
	var marker := spawn_points.get_node_or_null(marker_name)
	if marker == null:
		push_warning("Missing spawn point: %s" % marker_name)
		return

	player.global_position = marker.global_position

# -------------------------------------------------
# Fade
# -------------------------------------------------
func _fade_to(alpha: float, time: float = 0.15) -> void:
	if fade_rect == null:
		return

	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()

	_fade_tween = create_tween()
	_fade_tween.tween_property(fade_rect, "modulate:a", alpha, time)
	await _fade_tween.finished

# -------------------------------------------------
# Decals (room art decals)
# -------------------------------------------------
func reroll_decals() -> void:
	if decals_root == null:
		return
	for child in decals_root.get_children():
		if child is CanvasItem:
			(child as CanvasItem).visible = (randi() % 2) == 0

# -------------------------------------------------
# World cleanup (blood + drops that live in Main/World)
# -------------------------------------------------
func _clear_world_decals_and_drops() -> void:
	var world := get_tree().current_scene.get_node_or_null("World")
	if world == null:
		return

	var drops := world.get_node_or_null("Drops")
	if drops:
		for c in drops.get_children():
			c.queue_free()

	var decals := world.get_node_or_null("Decals")
	if decals:
		for c in decals.get_children():
			c.queue_free()


func _clear_world_decals_and_drops_batched(batch_size: int) -> void:
	var world := get_tree().current_scene.get_node_or_null("World")
	if world == null:
		return

	var drops := world.get_node_or_null("Drops")
	if drops:
		await _queue_free_children_batched(drops, batch_size)

	var decals := world.get_node_or_null("Decals")
	if decals:
		await _queue_free_children_batched(decals, batch_size)

# -------------------------------------------------
# Enemies
# -------------------------------------------------
func clear_enemies() -> void:
	for e in live_enemies:
		if is_instance_valid(e):
			e.queue_free()
	live_enemies.clear()


func _clear_enemies_batched(batch_size: int) -> void:
	var processed := 0
	for e in live_enemies:
		if is_instance_valid(e):
			e.queue_free()
			processed += 1

			if batch_size > 0 and processed % batch_size == 0:
				await get_tree().process_frame
	live_enemies.clear()


func _queue_free_children_batched(parent: Node, batch_size: int) -> void:
	if parent == null:
		return

	var processed := 0
	for c in parent.get_children():
		(c as Node).queue_free()
		processed += 1

		if batch_size > 0 and processed % batch_size == 0:
			await get_tree().process_frame


func _reset_room_for_transition(entered_from: StringName) -> void:
	entered_from_current = entered_from
	rooms_entered += 1

	close_all_doors()
	reroll_decals()

	if _is_web_build():
		await _clear_world_decals_and_drops_batched(web_cleanup_batch_size)
		_suppress_enemy_callbacks = true
		await _clear_enemies_batched(web_cleanup_batch_size)
		enemies_alive = 0
		_suppress_enemy_callbacks = false
		for _i in range(web_cleanup_settle_frames):
			await get_tree().process_frame
		await spawn_enemies_mvp()
	else:
		_clear_world_decals_and_drops()
		_suppress_enemy_callbacks = true
		clear_enemies()
		enemies_alive = 0
		_suppress_enemy_callbacks = false
		spawn_enemies_mvp()

	if Engine.has_singleton("RunState"):
		RunState.entered_from = entered_from_current

# NEW: calculates how many enemies to spawn this room
func _get_enemy_spawn_count() -> int:
	var n := starting_enemies + (rooms_entered - 1) * enemies_per_room
	return clamp(n, starting_enemies, max_enemies)

func spawn_enemies_mvp() -> void:
	if enemy_scene == null:
		push_warning("RoomController: enemy_scene is not assigned in the Inspector.")
		return

	if enemies_container == null:
		push_warning("RoomController: No node in group 'enemies_root'. Add Main/Enemies to that group.")
		return

	var enemy_count := _get_enemy_spawn_count()

	var player := get_tree().get_first_node_in_group("player") as Node2D
	var player_pos := player.global_position if player else Vector2.INF

	var top := spawn_points.get_node_or_null("SpawnTop") as Node2D
	var bottom := spawn_points.get_node_or_null("SpawnBottom") as Node2D
	var left := spawn_points.get_node_or_null("SpawnLeft") as Node2D
	var right := spawn_points.get_node_or_null("SpawnRight") as Node2D

	if top == null or bottom == null or left == null or right == null:
		push_warning("RoomController: Missing SpawnPoints (SpawnTop/Bottom/Left/Right).")
		return

	var center := (top.global_position + bottom.global_position + left.global_position + right.global_position) * 0.25
	var chosen_positions: Array[Vector2] = []

	for _i in range(enemy_count):
		var spawn_pos := center

		for _attempt in range(spawn_attempts_per_enemy):
			var candidate := center + Vector2(
				randf_range(-spawn_range_x, spawn_range_x),
				randf_range(-spawn_range_y, spawn_range_y)
			)

			if player and candidate.distance_to(player_pos) < min_spawn_dist_from_player:
				continue

			var ok := true
			for p in chosen_positions:
				if candidate.distance_to(p) < min_spawn_dist_between_enemies:
					ok = false
					break
			if not ok:
				continue

			spawn_pos = candidate
			break

		chosen_positions.append(spawn_pos)

	var do_stagger := _is_web_build() and web_spawn_batch_size > 0
	for i in range(chosen_positions.size()):
		_spawn_enemy_at(chosen_positions[i])

		if do_stagger and (i + 1) % web_spawn_batch_size == 0 and i + 1 < chosen_positions.size():
			await get_tree().process_frame


func _spawn_enemy_at(spawn_pos: Vector2) -> void:
	var enemy := enemy_scene.instantiate()

	# Force sane z so container decides layering
	if enemy is CanvasItem:
		(enemy as CanvasItem).z_index = 0
		(enemy as CanvasItem).z_as_relative = true
		(enemy as CanvasItem).y_sort_enabled = false

	live_enemies.append(enemy)
	_register_enemy(enemy)

	enemies_container.add_child(enemy)
	(enemy as Node2D).global_position = spawn_pos


func _is_web_build() -> bool:
	return OS.has_feature("web")

# -------------------------------------------------
# Enemy clear detection
# -------------------------------------------------
func _register_enemy(enemy: Node) -> void:
	enemies_alive += 1

	if enemy.has_signal("died"):
		var c := Callable(self, "_on_enemy_died")
		if not enemy.is_connected("died", c):
			enemy.connect("died", c)
		return

	if not enemy.tree_exited.is_connected(_on_enemy_tree_exited):
		enemy.tree_exited.connect(_on_enemy_tree_exited)

func _on_enemy_died() -> void:
	if _suppress_enemy_callbacks:
		return
	enemies_alive -= 1
	_check_room_clear()

func _on_enemy_tree_exited() -> void:
	if _suppress_enemy_callbacks:
		return
	enemies_alive -= 1
	_check_room_clear()

func _check_room_clear() -> void:
	if enemies_alive <= 0:
		enemies_alive = 0
		open_random_doors()
