extends Control
## Escape-key Pause Menu overlay (freezes full SceneTree while open).

@onready var modal_panel: PanelContainer = $Center/Modal
@onready var summary_label: Label = $Center/Modal/Margin/VBox/SummaryLabel
@onready var status_label: Label = $Center/Modal/Margin/VBox/StatusBanner/SMargin/StatusLabel
@onready var resume_btn: Button = $Center/Modal/Margin/VBox/ResumeBtn
@onready var save_btn: Button = $Center/Modal/Margin/VBox/SaveBtn
@onready var achievements_btn: Button = $Center/Modal/Margin/VBox/AchievementsBtn
@onready var settings_btn: Button = $Center/Modal/Margin/VBox/SettingsBtn
@onready var dev_mode_btn: Button = $Center/Modal/Margin/VBox/DevModeBtn
@onready var menu_btn: Button = $Center/Modal/Margin/VBox/MenuBtn
@onready var settings_modal: Control = $SettingsModal
@onready var achievements_modal: Control = $AchievementsModal


func _ready() -> void:
	visible = false
	resume_btn.pressed.connect(close_pause)
	save_btn.pressed.connect(_on_save_pressed)
	if achievements_btn != null:
		achievements_btn.pressed.connect(_on_achievements_pressed)
	settings_btn.pressed.connect(_on_settings_pressed)
	if dev_mode_btn != null:
		dev_mode_btn.pressed.connect(_on_dev_mode_pressed)
	menu_btn.pressed.connect(_on_menu_pressed)
	if settings_modal != null and settings_modal.has_signal("closed"):
		settings_modal.closed.connect(func(): modal_panel.visible = true)
	if achievements_modal != null and achievements_modal.has_signal("closed"):
		achievements_modal.closed.connect(func(): modal_panel.visible = true)


func _exit_tree() -> void:
	if visible and get_tree() != null:
		get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if settings_modal != null and settings_modal.visible:
		return
	if achievements_modal != null and achievements_modal.visible:
		return
	if visible:
		close_pause()
		get_viewport().set_input_as_handled()
		return
	if _is_other_modal_open():
		return
	open_pause()
	get_viewport().set_input_as_handled()


func _is_other_modal_open() -> bool:
	if GameManager.is_dialogue_open():
		return true
	var dev := GameManager.get_node_or_null("DevPanelLayer")
	if dev != null and dev.has_method("is_panel_open") and dev.is_panel_open():
		return true
	var cl := get_parent()
	if cl == null:
		return false
	for node_name: String in ["BengkelQueryUI", "ShopUI", "GameOverUI"]:
		var n := cl.get_node_or_null(node_name) as CanvasItem
		if n != null and n.visible:
			return true
	return false


func open_pause() -> void:
	var am := get_node_or_null("/root/AudioManager")
	if am != null:
		am.play_sfx("ui_confirm")
	_refresh_summary()
	status_label.text = "Permainan dijeda. Tekan [Esc] untuk lanjut."
	modal_panel.visible = true
	if settings_modal != null:
		settings_modal.visible = false
	if achievements_modal != null:
		achievements_modal.visible = false
	visible = true
	if get_tree() != null:
		get_tree().paused = true


func close_pause() -> void:
	var am := get_node_or_null("/root/AudioManager")
	if am != null:
		am.play_sfx("ui_confirm")
	if settings_modal != null:
		settings_modal.visible = false
	if achievements_modal != null:
		achievements_modal.visible = false
	visible = false
	if get_tree() != null:
		get_tree().paused = false


func _refresh_summary() -> void:
	var ach_n: int = GameManager.get_all_unlocked_achievements().size()
	var ach_tot: int = GameManager.get_achievement_total_count()
	if achievements_btn != null:
		achievements_btn.text = "PENCAPAIAN (%d/%d Terbuka)" % [ach_n, ach_tot]
	summary_label.text = "Lantai %d · HP %d/%d · Ramuan %d · Koin %d · %d XP" % [
		GameManager.current_floor,
		GameManager.hp,
		GameManager.max_hp,
		GameManager.hp_potions,
		GameManager.coins,
		GameManager.xp,
	]


func _on_save_pressed() -> void:
	var am := get_node_or_null("/root/AudioManager")
	if GameManager.save_game():
		if am != null:
			am.play_sfx("ui_confirm")
		status_label.text = "Progres tersimpan ke user://save.cfg!"
	else:
		if am != null:
			am.play_sfx("query_error")
		status_label.text = "Gagal menyimpan progres."


func _on_settings_pressed() -> void:
	var am := get_node_or_null("/root/AudioManager")
	if am != null:
		am.play_sfx("ui_confirm")
	if settings_modal != null and settings_modal.has_method("open_settings"):
		modal_panel.visible = false
		settings_modal.open_settings()


func _on_achievements_pressed() -> void:
	var am := get_node_or_null("/root/AudioManager")
	if am != null:
		am.play_sfx("ui_confirm")
	if achievements_modal != null and achievements_modal.has_method("open_achievements"):
		modal_panel.visible = false
		achievements_modal.open_achievements()


func _on_dev_mode_pressed() -> void:
	var am := get_node_or_null("/root/AudioManager")
	if am != null:
		am.play_sfx("ui_confirm")
	GameManager.open_dev_panel()


func _on_menu_pressed() -> void:
	var am := get_node_or_null("/root/AudioManager")
	if am != null:
		am.play_sfx("ui_confirm")
	GameManager.save_game()
	close_pause()
	if get_tree() != null:
		get_tree().change_scene_to_file.call_deferred("res://scenes/ui/main_menu.tscn")
