extends Node

const BUS_MASTER := "Master"
const BUS_MUSIC := "Music"
const BUS_SFX := "SFX"

var menu_tracks: Array[AudioStream] = []
var game_tracks: Array[AudioStream] = []

var _music_player: AudioStreamPlayer
var _last_menu_index := -1
var _last_game_index := -1

var _shoot_streams: Array[AudioStream] = []
var _player_hit_streams: Array[AudioStream] = []
var _enemy_dog_death_streams: Array[AudioStream] = []
var _flesh_nugget_pickup_streams: Array[AudioStream] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	_music_player = AudioStreamPlayer.new()
	_music_player.name = "MusicPlayer"
	_music_player.bus = BUS_MUSIC
	_music_player.finished.connect(_on_music_finished)
	add_child(_music_player)

	_load_music()
	_load_sfx()

func _load_music() -> void:
	menu_tracks.clear()
	game_tracks.clear()

	var menu_paths := [
		"res://sound/music/menu/menu_1.mp3",
		"res://sound/music/menu/menu_2.mp3",
	]

	var game_paths := [
		"res://sound/music/lab/lab_1.mp3",
		"res://sound/music/lab/lab_2.mp3",
	]

	for path in menu_paths:
		var stream := load(path) as AudioStream
		if stream:
			menu_tracks.append(stream)
		else:
			push_warning("AudioManager: Failed to load menu track: %s" % path)

	for path in game_paths:
		var stream := load(path) as AudioStream
		if stream:
			game_tracks.append(stream)
		else:
			push_warning("AudioManager: Failed to load game track: %s" % path)

func _load_sfx() -> void:
	_shoot_streams.clear()
	_player_hit_streams.clear()
	_enemy_dog_death_streams.clear()
	_flesh_nugget_pickup_streams.clear()

	var shoot_paths := [
		"res://sound/sfx/player/shoot/player-shoot-1.mp3",
		"res://sound/sfx/player/shoot/player-shoot-2.mp3",
		"res://sound/sfx/player/shoot/player-shoot-3.mp3",
		"res://sound/sfx/player/shoot/player-shoot-4.mp3",
		"res://sound/sfx/player/shoot/player-shoot-5.mp3",
		"res://sound/sfx/player/shoot/player-shoot-6.mp3",
		"res://sound/sfx/player/shoot/player-shoot-7.mp3",
		"res://sound/sfx/player/shoot/player-shoot-8.mp3",
	]

	for path in shoot_paths:
		var stream := load(path) as AudioStream
		if stream:
			_shoot_streams.append(stream)
		else:
			push_warning("AudioManager: Failed to load shoot SFX: %s" % path)

	var player_hit_paths := [
		"res://sound/sfx/player/hit/player-hit-1.mp3",
		"res://sound/sfx/player/hit/player-hit-2.mp3",
		"res://sound/sfx/player/hit/player-hit-3.mp3",
		"res://sound/sfx/player/hit/player-hit-4.mp3",
	]

	for path in player_hit_paths:
		var stream := load(path) as AudioStream
		if stream:
			_player_hit_streams.append(stream)
		else:
			push_warning("AudioManager: Failed to load player hit SFX: %s" % path)

	var enemy_dog_death_paths := [
		"res://sound/sfx/enemy/dog/death/enemy-dog-death-1.mp3",
		"res://sound/sfx/enemy/dog/death/enemy-dog-death-2.mp3",
		"res://sound/sfx/enemy/dog/death/enemy-dog-death-3.mp3",
		"res://sound/sfx/enemy/dog/death/enemy-dog-death-4.mp3",
		"res://sound/sfx/enemy/dog/death/enemy-dog-death-5.mp3",
		"res://sound/sfx/enemy/dog/death/enemy-dog-death-6.mp3",
	]

	for path in enemy_dog_death_paths:
		var stream := load(path) as AudioStream
		if stream:
			_enemy_dog_death_streams.append(stream)
		else:
			push_warning("AudioManager: Failed to load enemy dog death SFX: %s" % path)

	var flesh_nugget_pickup_paths := [
		"res://sound/sfx/player/pickup/fleshnugget-1.mp3",
		"res://sound/sfx/player/pickup/fleshnugget-2.mp3",
		"res://sound/sfx/player/pickup/fleshnugget-3.mp3",
		"res://sound/sfx/player/pickup/fleshnugget-4.mp3",
		"res://sound/sfx/player/pickup/fleshnugget-5.mp3",
		"res://sound/sfx/player/pickup/fleshnugget-6.mp3",
		"res://sound/sfx/player/pickup/fleshnugget-7.mp3",
		"res://sound/sfx/player/pickup/fleshnugget-8.mp3",
	]

	for path in flesh_nugget_pickup_paths:
		var stream := load(path) as AudioStream
		if stream:
			_flesh_nugget_pickup_streams.append(stream)
		else:
			push_warning("AudioManager: Failed to load flesh nugget pickup SFX: %s" % path)

func play_menu_music() -> void:
	_play_random_from_list(menu_tracks, true)

func play_game_music() -> void:
	_play_random_from_list(game_tracks, false)

func stop_music() -> void:
	if _music_player:
		_music_player.stop()

func _play_random_from_list(list: Array[AudioStream], is_menu: bool) -> void:
	if list.is_empty():
		push_warning("AudioManager: Tried to play from an empty track list.")
		return

	var chosen_index := 0

	if list.size() == 1:
		chosen_index = 0
	else:
		var last_index := _last_menu_index if is_menu else _last_game_index
		chosen_index = randi_range(0, list.size() - 1)

		while chosen_index == last_index:
			chosen_index = randi_range(0, list.size() - 1)

	if is_menu:
		_last_menu_index = chosen_index
	else:
		_last_game_index = chosen_index

	_music_player.stream = list[chosen_index]
	_music_player.play()

func _on_music_finished() -> void:
	if _music_player.stream in menu_tracks:
		play_menu_music()
	elif _music_player.stream in game_tracks:
		play_game_music()

func play_player_shoot() -> void:
	if _shoot_streams.is_empty():
		push_warning("AudioManager: No shoot SFX loaded.")
		return

	var chosen := _shoot_streams[randi_range(0, _shoot_streams.size() - 1)]

	var player := AudioStreamPlayer.new()
	player.bus = BUS_SFX
	player.stream = chosen
	player.finished.connect(player.queue_free)
	add_child(player)
	player.play()

func play_player_hit() -> void:
	if _player_hit_streams.is_empty():
		push_warning("AudioManager: No player hit SFX loaded.")
		return

	var chosen := _player_hit_streams[randi_range(0, _player_hit_streams.size() - 1)]

	var player := AudioStreamPlayer.new()
	player.bus = BUS_SFX
	player.stream = chosen
	player.finished.connect(player.queue_free)
	add_child(player)
	player.play()

func play_enemy_dog_death() -> void:
	if _enemy_dog_death_streams.is_empty():
		push_warning("AudioManager: No enemy dog death SFX loaded.")
		return

	var chosen := _enemy_dog_death_streams[randi_range(0, _enemy_dog_death_streams.size() - 1)]

	var player := AudioStreamPlayer.new()
	player.bus = BUS_SFX
	player.stream = chosen
	player.finished.connect(player.queue_free)
	add_child(player)
	player.play()

func play_flesh_nugget_pickup() -> void:
	if _flesh_nugget_pickup_streams.is_empty():
		push_warning("AudioManager: No flesh nugget pickup SFX loaded.")
		return

	var chosen := _flesh_nugget_pickup_streams[randi_range(0, _flesh_nugget_pickup_streams.size() - 1)]

	var player := AudioStreamPlayer.new()
	player.bus = BUS_SFX
	player.stream = chosen
	player.finished.connect(player.queue_free)
	add_child(player)
	player.play()

func set_master_volume(linear_value: float) -> void:
	_set_bus_volume_linear(BUS_MASTER, linear_value)

func set_music_volume(linear_value: float) -> void:
	_set_bus_volume_linear(BUS_MUSIC, linear_value)

func set_sfx_volume(linear_value: float) -> void:
	_set_bus_volume_linear(BUS_SFX, linear_value)

func get_master_volume() -> float:
	return _get_bus_volume_linear(BUS_MASTER)

func get_music_volume() -> float:
	return _get_bus_volume_linear(BUS_MUSIC)

func get_sfx_volume() -> float:
	return _get_bus_volume_linear(BUS_SFX)

func _set_bus_volume_linear(bus_name: String, linear_value: float) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index == -1:
		push_warning("AudioManager: Bus not found: %s" % bus_name)
		return

	var safe_value: float = clampf(linear_value, 0.0, 1.0)

	if safe_value <= 0.001:
		AudioServer.set_bus_volume_db(bus_index, -80.0)
	else:
		AudioServer.set_bus_volume_db(bus_index, linear_to_db(safe_value))

func _get_bus_volume_linear(bus_name: String) -> float:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index == -1:
		push_warning("AudioManager: Bus not found: %s" % bus_name)
		return 1.0

	var db := AudioServer.get_bus_volume_db(bus_index)
	if db <= -79.0:
		return 0.0

	return db_to_linear(db)
