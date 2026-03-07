extends Node

var run_floor_name: String = "Lab"
var room_index: int = 0          # 0 = first room, 1 = next, etc.
var entered_from: StringName = &"Bottom"  # Top/Left/Right/Bottom (where player came from)

var flesh_collected: int = 0

func next_room(from_door: StringName) -> void:
	room_index += 1
	entered_from = from_door
