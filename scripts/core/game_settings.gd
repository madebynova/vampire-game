extends Node
## Autoload: the handful of player-facing options, saved to user://settings.cfg and applied at
## once. Deliberately small: volumes, look sensitivity, vibration, window mode. Everything
## else (key rebinding, graphics quality...) is future work.

signal changed

const DEFAULT_PATH := "user://settings.cfg"

## Linear 0..1 volumes.
var master_volume := 0.85
var effects_volume := 1.0
var ambience_volume := 1.0
var music_volume := 1.0
## Multipliers on the base look speed (1.0 = as tuned).
var mouse_sensitivity := 1.0
var stick_sensitivity := 1.0
var vibration := true
var fullscreen := false

## Tests turn this off so they never touch the player's real settings file.
var persist := true
var path := DEFAULT_PATH


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	AudioBuses.ensure()
	load_settings()
	apply()


func load_settings() -> void:
	if not persist:
		return
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return
	master_volume = clampf(float(cfg.get_value("audio", "master", master_volume)), 0.0, 1.0)
	effects_volume = clampf(float(cfg.get_value("audio", "effects", effects_volume)), 0.0, 1.0)
	ambience_volume = clampf(float(cfg.get_value("audio", "ambience", ambience_volume)), 0.0, 1.0)
	music_volume = clampf(float(cfg.get_value("audio", "music", music_volume)), 0.0, 1.0)
	mouse_sensitivity = clampf(float(cfg.get_value("input", "mouse_sensitivity", mouse_sensitivity)), 0.2, 3.0)
	stick_sensitivity = clampf(float(cfg.get_value("input", "stick_sensitivity", stick_sensitivity)), 0.2, 3.0)
	vibration = bool(cfg.get_value("input", "vibration", vibration))
	fullscreen = bool(cfg.get_value("display", "fullscreen", fullscreen))


func save_settings() -> void:
	if not persist:
		return
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master", master_volume)
	cfg.set_value("audio", "effects", effects_volume)
	cfg.set_value("audio", "ambience", ambience_volume)
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("input", "mouse_sensitivity", mouse_sensitivity)
	cfg.set_value("input", "stick_sensitivity", stick_sensitivity)
	cfg.set_value("input", "vibration", vibration)
	cfg.set_value("display", "fullscreen", fullscreen)
	cfg.save(path)


## Push the current values to the engine (audio buses, window mode).
func apply() -> void:
	AudioBuses.set_volume(&"Master", master_volume)
	AudioBuses.set_volume(AudioBuses.EFFECTS, effects_volume)
	AudioBuses.set_volume(AudioBuses.AMBIENCE, ambience_volume)
	AudioBuses.set_volume(AudioBuses.MUSIC, music_volume)
	if DisplayServer.get_name() != "headless":
		var want := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != want:
			DisplayServer.window_set_mode(want)
	changed.emit()


## Set one option by name (the Options menu calls this) and save.
func set_option(key: StringName, value: Variant) -> void:
	match key:
		&"master_volume": master_volume = clampf(float(value), 0.0, 1.0)
		&"effects_volume": effects_volume = clampf(float(value), 0.0, 1.0)
		&"ambience_volume": ambience_volume = clampf(float(value), 0.0, 1.0)
		&"music_volume": music_volume = clampf(float(value), 0.0, 1.0)
		&"mouse_sensitivity": mouse_sensitivity = clampf(float(value), 0.2, 3.0)
		&"stick_sensitivity": stick_sensitivity = clampf(float(value), 0.2, 3.0)
		&"vibration": vibration = bool(value)
		&"fullscreen": fullscreen = bool(value)
		_:
			push_warning("GameSettings: unknown option %s" % key)
			return
	apply()
	save_settings()


func reset_defaults() -> void:
	master_volume = 0.85
	effects_volume = 1.0
	ambience_volume = 1.0
	music_volume = 1.0
	mouse_sensitivity = 1.0
	stick_sensitivity = 1.0
	vibration = true
	fullscreen = false
	apply()
	save_settings()
