extends Node
## Global AudioManager Autoload: manages BGM loops, SFX pool, and volume/track settings.
## Available dungeon BGM choices:
##   - "bgm_opt5"     (Default: OpenGameArt Dungeon Ambience by yd, CC0)
##   - "bgm_opt3"     (OpenGameArt Cave Theme by Brandon Morris, CC0)
##   - "bgm_basement" (OpenGameArt Loopable Dungeon Ambience by JaggedStone, CC0)
## Floor 5 Boss BGM:
##   - "bgm_boss"     (OpenGameArt Boss Battle #2 [8-bit] by nene, CC0)

const BGM_DIR: String = "res://assets/audio/bgm/"
const SFX_DIR: String = "res://assets/audio/sfx/"
const POOL_SIZE: int = 8
const DUNGEON_BGM_IDS: Array[String] = ["bgm_opt5", "bgm_opt3", "bgm_basement"]
const BGM_LABELS := {
	"bgm_opt5": "Opt 5 — Dungeon Ambience (Default)",
	"bgm_opt3": "Opt 3 — Cave Theme",
	"bgm_basement": "Loopable Dungeon Ambience",
}

var music_player: AudioStreamPlayer
var _sfx_pool: Array[AudioStreamPlayer] = []
var _cache: Dictionary = {}

var master_volume: float = 0.85
var music_volume: float = 0.65
var sfx_volume: float = 0.80
var selected_dungeon_bgm: String = "bgm_opt5"
var current_bgm: String = ""

var _last_hp: int = 100
var _last_coins: int = 0
var _gm_connected: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	music_player = AudioStreamPlayer.new()
	music_player.bus = "Master"
	add_child(music_player)
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_sfx_pool.append(p)
	call_deferred("_connect_game_manager")


func _connect_game_manager() -> void:
	if _gm_connected:
		return
	var gm := get_node_or_null("/root/GameManager")
	if gm == null:
		return
	_gm_connected = true
	_last_hp = int(gm.hp)
	_last_coins = int(gm.coins)
	gm.lever_pulled.connect(func(_f, _t): play_sfx("lever"))
	gm.main_door_unlocked.connect(func(_f): play_sfx("door"))
	gm.terminal_solved.connect(func(_id): play_sfx("query_ok"))
	gm.achievement_unlocked.connect(func(_id): play_sfx("achievement"))
	gm.hp_changed.connect(_on_hp_changed)
	gm.coins_changed.connect(_on_coins_changed)


func _on_hp_changed(new_hp: int, _max_hp: int) -> void:
	if new_hp < _last_hp:
		play_sfx("guard_hit")
	_last_hp = new_hp


func _on_coins_changed(new_coins: int) -> void:
	if new_coins > _last_coins:
		play_sfx("coin")
	_last_coins = new_coins


func _unhandled_input(event: InputEvent) -> void:
	if get_tree() != null and not get_tree().paused:
		if event.is_action_pressed("attack") and get_tree().get_first_node_in_group("player") != null:
			play_sfx("sword")


func _to_db(linear_vol: float) -> float:
	if linear_vol <= 0.001:
		return -80.0
	return linear_to_db(clampf(linear_vol, 0.001, 1.5))


func _apply_music_volume() -> void:
	if music_player != null:
		music_player.volume_db = _to_db(master_volume * music_volume)


func set_volumes(master_v: float, music_v: float, sfx_v: float) -> void:
	master_volume = clampf(master_v, 0.0, 1.0)
	music_volume = clampf(music_v, 0.0, 1.0)
	sfx_volume = clampf(sfx_v, 0.0, 1.0)
	_apply_music_volume()


func set_dungeon_bgm_choice(track_id: String, restart_if_playing: bool = true) -> void:
	if not (track_id in DUNGEON_BGM_IDS):
		track_id = "bgm_opt5"
	selected_dungeon_bgm = track_id
	if restart_if_playing and current_bgm != "bgm_boss" and not current_bgm.is_empty():
		play_music(selected_dungeon_bgm, true)


func play_dungeon_bgm(floor_num: int = 1) -> void:
	if floor_num == 5:
		play_music("bgm_boss", true)
	else:
		play_music(selected_dungeon_bgm, true)


func play_music(track_name: String, loop: bool = true) -> void:
	if track_name == current_bgm and music_player != null and music_player.playing:
		return
	var stream := _load_stream(BGM_DIR + track_name)
	if stream == null:
		return
	current_bgm = track_name
	music_player.stream = stream
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = loop
	elif stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD if loop else AudioStreamWAV.LOOP_DISABLED
	_apply_music_volume()
	if not DisplayServer.get_name().begins_with("headless"):
		music_player.play()


func stop_music() -> void:
	current_bgm = ""
	if music_player != null:
		music_player.stop()


func play_sfx(sfx_name: String, pitch: float = 1.0) -> void:
	var stream := _load_stream(SFX_DIR + sfx_name)
	if stream == null or DisplayServer.get_name().begins_with("headless"):
		return
	for p: AudioStreamPlayer in _sfx_pool:
		if not p.playing:
			p.stream = stream
			p.volume_db = _to_db(master_volume * sfx_volume)
			p.pitch_scale = pitch
			p.play()
			return


func has_audio_stream(category: String, track_name: String) -> bool:
	var dir := BGM_DIR if category == "bgm" else SFX_DIR
	return _load_stream(dir + track_name) != null


func _load_stream(path_no_ext: String) -> AudioStream:
	for ext: String in [".ogg", ".wav", ".mp3"]:
		var full: String = path_no_ext + ext
		if _cache.has(full):
			return _cache[full] as AudioStream
		if ResourceLoader.exists(full):
			var loaded = ResourceLoader.load(full)
			if loaded is AudioStream:
				_cache[full] = loaded
				return loaded as AudioStream
	return null
