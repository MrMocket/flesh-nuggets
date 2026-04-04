extends VBoxContainer

signal close_requested

const SFX_PREVIEW_INTERVAL_MS := 120

@onready var master_slider: HSlider = $MasterSlider
@onready var music_slider: HSlider = $MusicSlider
@onready var sfx_slider: HSlider = $SfxSlider
@onready var close_button: Button = $CloseButton

var _last_sfx_preview_ms := 0

func _ready() -> void:
	master_slider.value_changed.connect(_on_master_slider_changed)
	music_slider.value_changed.connect(_on_music_slider_changed)
	sfx_slider.value_changed.connect(_on_sfx_slider_changed)
	close_button.pressed.connect(_on_close_pressed)

	master_slider.value = AudioManager.get_master_volume()
	music_slider.value = AudioManager.get_music_volume()
	sfx_slider.value = AudioManager.get_sfx_volume()

func _on_master_slider_changed(value: float) -> void:
	AudioManager.set_master_volume(value)

func _on_music_slider_changed(value: float) -> void:
	AudioManager.set_music_volume(value)

func _on_sfx_slider_changed(value: float) -> void:
	AudioManager.set_sfx_volume(value)

	var now_ms := Time.get_ticks_msec()
	if now_ms - _last_sfx_preview_ms >= SFX_PREVIEW_INTERVAL_MS:
		_last_sfx_preview_ms = now_ms
		AudioManager.play_player_shoot()

func _on_close_pressed() -> void:
	close_requested.emit()
