extends Control
## Main Menu with Continue, New Game, Progress-gated Level Select, Settings, and Quit.

const FLOOR_DEFS := [
	{"num": 1, "title": "LANTAI 1 — Dungeon Awal", "desc": "2 Tuas · DDL CREATE/ALTER & SELECT Dasar"},
	{"num": 2, "title": "LANTAI 2 — Ruang Bawah Tanah", "desc": "3 Tuas · DML INSERT, UPDATE & WHERE"},
	{"num": 3, "title": "LANTAI 3 — Katakombe Kuno", "desc": "3 Tuas · WHERE LIKE, IN & ORDER BY"},
	{"num": 4, "title": "LANTAI 4 — Lorong Arsip", "desc": "3 Tuas · Agregasi COUNT/SUM & DCL GRANT"},
	{"num": 5, "title": "LANTAI 5 — Aula Boss Penjaga", "desc": "Final Challenge · Pintu Keluar Vault"},
]

@onready var save_info_label: Label = $Center/Modal/Margin/VBox/HeroCard/HMargin/HRow/TitleCol/SaveInfoLabel
@onready var continue_btn: Button = $Center/Modal/Margin/VBox/MenuButtons/ContinueBtn
@onready var new_game_btn: Button = $Center/Modal/Margin/VBox/MenuButtons/NewGameBtn
@onready var level_select_btn: Button = $Center/Modal/Margin/VBox/MenuButtons/LevelSelectBtn
@onready var achievements_btn: Button = $Center/Modal/Margin/VBox/MenuButtons/AchievementsBtn
@onready var settings_btn: Button = $Center/Modal/Margin/VBox/MenuButtons/BottomRow/SettingsBtn
@onready var about_btn: Button = $Center/Modal/Margin/VBox/MenuButtons/BottomRow/AboutBtn
@onready var quit_btn: Button = $Center/Modal/Margin/VBox/MenuButtons/BottomRow/QuitBtn

@onready var level_overlay: Control = $LevelSelectOverlay
@onready var level_rows_box: VBoxContainer = $LevelSelectOverlay/Center/Panel/Margin/VBox/RowsBox
@onready var level_back_btn: Button = $LevelSelectOverlay/Center/Panel/Margin/VBox/HeaderRow/BackBtn
@onready var settings_modal: Control = $SettingsModal
@onready var achievements_modal: Control = $AchievementsModal


func _ready() -> void:
	if get_tree() != null:
		get_tree().paused = false
	continue_btn.pressed.connect(_on_continue_pressed)
	new_game_btn.pressed.connect(_on_new_game_pressed)
	level_select_btn.pressed.connect(_on_level_select_pressed)
	if achievements_btn != null:
		achievements_btn.pressed.connect(_on_achievements_pressed)
	settings_btn.pressed.connect(_on_settings_pressed)
	about_btn.pressed.connect(_on_about_pressed)
	quit_btn.pressed.connect(_on_quit_pressed)
	level_back_btn.pressed.connect(func():
		_play_click()
		level_overlay.visible = false
	)
	if settings_modal != null and settings_modal.has_signal("closed"):
		settings_modal.closed.connect(_refresh_menu_state)
	if achievements_modal != null and achievements_modal.has_signal("closed"):
		achievements_modal.closed.connect(_refresh_menu_state)

	level_overlay.visible = false
	_refresh_menu_state()
	var am := get_node_or_null("/root/AudioManager")
	if am != null:
		am.play_dungeon_bgm(1)


func _input(event: InputEvent) -> void:
	if level_overlay.visible and event.is_action_pressed("ui_cancel"):
		_play_click()
		level_overlay.visible = false
		get_viewport().set_input_as_handled()


func _play_click() -> void:
	var am := get_node_or_null("/root/AudioManager")
	if am != null:
		am.play_sfx("ui_confirm")


func get_unlocked_floor_cap(save_path: String = GameManager.SAVE_PATH) -> int:
	var summary := GameManager.read_save_summary(save_path)
	var saved_high: int = int(summary.get("highest_floor_unlocked", 1)) if bool(summary.get("exists", false)) else 1
	return maxi(GameManager.highest_floor_unlocked, saved_high)


func _refresh_menu_state() -> void:
	var summary := GameManager.read_save_summary()
	var ach_unlocked: int = int(summary.get("achievements_unlocked", GameManager.get_all_unlocked_achievements().size()))
	var ach_total: int = int(summary.get("achievements_total", GameManager.get_achievement_total_count()))
	if achievements_btn != null:
		achievements_btn.text = "PENCAPAIAN (Achievements · %d/%d)" % [ach_unlocked, ach_total]
	if bool(summary.get("exists", false)):
		continue_btn.disabled = false
		var fl: int = int(summary.get("current_floor", 1))
		continue_btn.text = "LANJUTKAN (Lantai %d)" % fl
		save_info_label.text = "Save Aktif: Lantai %d · %s (%d XP) · %d Koin · Pencapaian %d/%d" % [
			fl,
			str(summary.get("rank", "Trainee")),
			int(summary.get("xp", 0)),
			int(summary.get("coins", 0)),
			ach_unlocked,
			ach_total,
		]
	else:
		continue_btn.disabled = true
		continue_btn.text = "LANJUTKAN (Belum Ada Save)"
		save_info_label.text = "Pencapaian: %d/%d terbuka · Tekan MULAI BARU untuk memulai petualangan." % [ach_unlocked, ach_total]
	_populate_level_select(get_unlocked_floor_cap())


func _populate_level_select(unlocked_cap: int) -> void:
	for i in FLOOR_DEFS.size():
		if i >= level_rows_box.get_child_count():
			break
		var fdef: Dictionary = FLOOR_DEFS[i]
		var fnum: int = int(fdef["num"])
		var row := level_rows_box.get_child(i)
		var title_lbl := row.get_node("Margin/HRow/Info/Title") as Label
		var desc_lbl := row.get_node("Margin/HRow/Info/Desc") as Label
		var go_btn := row.get_node("Margin/HRow/EnterBtn") as Button
		title_lbl.text = str(fdef["title"])
		desc_lbl.text = str(fdef["desc"])
		for conn in go_btn.pressed.get_connections():
			go_btn.pressed.disconnect(conn["callable"])
		var is_unlocked: bool = fnum <= unlocked_cap
		go_btn.disabled = not is_unlocked
		go_btn.text = "MASUK ->" if is_unlocked else "TERKUNCI"
		title_lbl.add_theme_color_override("font_color", Color(0.98, 0.93, 0.72, 1) if is_unlocked else Color(0.55, 0.58, 0.52, 1))
		if is_unlocked:
			go_btn.pressed.connect(func(): _enter_floor(fnum))


func _on_continue_pressed() -> void:
	_play_click()
	if not GameManager.load_game():
		return
	var target: String = GameManager.current_floor_path
	if target.is_empty():
		target = str(GameManager.FLOOR_SCENES_BY_NUM.get(GameManager.current_floor, "res://scenes/floors/floor_1_dungeon.tscn"))
	get_tree().change_scene_to_file.call_deferred(target)


func _on_new_game_pressed() -> void:
	_play_click()
	GameManager.reset_run()
	GameManager.save_game()
	get_tree().change_scene_to_file.call_deferred("res://scenes/floors/floor_1_dungeon.tscn")


func _on_level_select_pressed() -> void:
	_play_click()
	_populate_level_select(get_unlocked_floor_cap())
	level_overlay.visible = true


func _on_settings_pressed() -> void:
	_play_click()
	if settings_modal != null and settings_modal.has_method("open_settings"):
		settings_modal.open_settings()


func _on_achievements_pressed() -> void:
	_play_click()
	if achievements_modal != null and achievements_modal.has_method("open_achievements"):
		achievements_modal.open_achievements()


func _on_about_pressed() -> void:
	_play_click()
	get_tree().change_scene_to_file.call_deferred("res://scenes/ui/about.tscn")


func _on_quit_pressed() -> void:
	_play_click()
	get_tree().quit()


func _enter_floor(floor_num: int) -> void:
	_play_click()
	if GameManager.has_save():
		GameManager.load_game()
	else:
		GameManager.reset_run()
	var target: String = str(GameManager.FLOOR_SCENES_BY_NUM.get(floor_num, "res://scenes/floors/floor_1_dungeon.tscn"))
	GameManager.set_current_floor(floor_num, target)
	get_tree().change_scene_to_file.call_deferred(target)
