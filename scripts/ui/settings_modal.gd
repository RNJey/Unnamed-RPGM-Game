extends Control
## Audio, Dungeon BGM track selection, and display mode settings modal.

signal closed

@onready var master_slider: HSlider = $Center/Modal/Margin/VBox/AudioCard/AMargin/AVBox/MasterRow/MasterSlider
@onready var master_val: Label = $Center/Modal/Margin/VBox/AudioCard/AMargin/AVBox/MasterRow/MasterVal
@onready var bgm_slider: HSlider = $Center/Modal/Margin/VBox/AudioCard/AMargin/AVBox/BgmRow/BgmSlider
@onready var bgm_val: Label = $Center/Modal/Margin/VBox/AudioCard/AMargin/AVBox/BgmRow/BgmVal
@onready var sfx_slider: HSlider = $Center/Modal/Margin/VBox/AudioCard/AMargin/AVBox/SfxRow/SfxSlider
@onready var sfx_val: Label = $Center/Modal/Margin/VBox/AudioCard/AMargin/AVBox/SfxRow/SfxVal

@onready var opt5_btn: Button = $Center/Modal/Margin/VBox/BgmCard/BMargin/BVBox/TrackRow/Opt5Btn
@onready var opt3_btn: Button = $Center/Modal/Margin/VBox/BgmCard/BMargin/BVBox/TrackRow/Opt3Btn
@onready var base_btn: Button = $Center/Modal/Margin/VBox/BgmCard/BMargin/BVBox/TrackRow/BaseBtn

@onready var fs_btn: Button = $Center/Modal/Margin/VBox/DisplayCard/DMargin/DRow/FullscreenBtn
@onready var win_btn: Button = $Center/Modal/Margin/VBox/DisplayCard/DMargin/DRow/WindowedBtn
@onready var data_info_label: Label = $Center/Modal/Margin/VBox/DataCard/DMargin/DRow/DataInfoLabel
@onready var delete_data_btn: Button = $Center/Modal/Margin/VBox/DataCard/DMargin/DRow/DeleteDataBtn
@onready var dev_mode_btn: Button = $Center/Modal/Margin/VBox/FooterRow/DevModeBtn
@onready var save_close_btn: Button = $Center/Modal/Margin/VBox/FooterRow/SaveCloseBtn

var _confirm_delete_pending: bool = false


func _ready() -> void:
	visible = false
	master_slider.value_changed.connect(_on_volume_changed)
	bgm_slider.value_changed.connect(_on_volume_changed)
	sfx_slider.value_changed.connect(_on_volume_changed)

	opt5_btn.pressed.connect(func(): _select_bgm("bgm_opt5"))
	opt3_btn.pressed.connect(func(): _select_bgm("bgm_opt3"))
	base_btn.pressed.connect(func(): _select_bgm("bgm_basement"))

	fs_btn.pressed.connect(func(): _set_fullscreen(true))
	win_btn.pressed.connect(func(): _set_fullscreen(false))
	if delete_data_btn != null:
		delete_data_btn.pressed.connect(_on_delete_data_pressed)
	if dev_mode_btn != null:
		dev_mode_btn.pressed.connect(_on_dev_mode_pressed)
	save_close_btn.pressed.connect(close_settings)


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		close_settings()
		get_viewport().set_input_as_handled()


func open_settings() -> void:
	_sync_from_state()
	visible = true


func close_settings() -> void:
	var am := get_node_or_null("/root/AudioManager")
	if am != null:
		am.play_sfx("ui_confirm")
	GameManager.save_settings_only()
	visible = false
	closed.emit()


func _sync_from_state() -> void:
	var am := get_node_or_null("/root/AudioManager")
	var mv: float = float(am.master_volume) if am != null else 0.85
	var bv: float = float(am.music_volume) if am != null else 0.65
	var sv: float = float(am.sfx_volume) if am != null else 0.80
	var track: String = str(am.selected_dungeon_bgm) if am != null else "bgm_opt5"

	master_slider.set_value_no_signal(roundf(mv * 100.0))
	bgm_slider.set_value_no_signal(roundf(bv * 100.0))
	sfx_slider.set_value_no_signal(roundf(sv * 100.0))
	_update_volume_labels()
	_refresh_track_buttons(track)
	_refresh_display_buttons()
	_confirm_delete_pending = false
	_refresh_delete_data_ui()


func _on_volume_changed(_val: float) -> void:
	var am := get_node_or_null("/root/AudioManager")
	if am != null:
		am.set_volumes(master_slider.value / 100.0, bgm_slider.value / 100.0, sfx_slider.value / 100.0)
	_update_volume_labels()


func _update_volume_labels() -> void:
	master_val.text = "%d%%" % int(roundf(master_slider.value))
	bgm_val.text = "%d%%" % int(roundf(bgm_slider.value))
	sfx_val.text = "%d%%" % int(roundf(sfx_slider.value))


func _select_bgm(track_id: String) -> void:
	var am := get_node_or_null("/root/AudioManager")
	if am != null:
		am.play_sfx("ui_confirm")
		am.set_dungeon_bgm_choice(track_id, true)
		if am.current_bgm.is_empty():
			am.play_music(track_id, true)
	_refresh_track_buttons(track_id)


func _refresh_track_buttons(active_id: String) -> void:
	opt5_btn.text = ("[*] " if active_id == "bgm_opt5" else "") + "Opt 5: Dungeon Ambience (Default)"
	opt3_btn.text = ("[*] " if active_id == "bgm_opt3" else "") + "Opt 3: Cave Theme"
	base_btn.text = ("[*] " if active_id == "bgm_basement" else "") + "Loopable Ambience"


func _set_fullscreen(enable: bool) -> void:
	var am := get_node_or_null("/root/AudioManager")
	if am != null:
		am.play_sfx("ui_confirm")
	GameManager.apply_fullscreen_mode(enable)
	_refresh_display_buttons()


func _refresh_display_buttons() -> void:
	fs_btn.text = "[*] Fullscreen" if GameManager.fullscreen_enabled else "[ ] Fullscreen"
	win_btn.text = "[ ] Windowed / Max" if GameManager.fullscreen_enabled else "[*] Windowed / Max"


func _refresh_delete_data_ui() -> void:
	if data_info_label == null or delete_data_btn == null:
		return
	var has_any_data: bool = GameManager.has_save() or not GameManager.get_all_unlocked_achievements().is_empty()
	if _confirm_delete_pending:
		data_info_label.text = "PERINGATAN: Save, lantai terbuka & semua pencapaian akan dihapus permanen!"
		data_info_label.add_theme_color_override("font_color", Color(1.0, 0.62, 0.42, 1.0))
		delete_data_btn.text = "YAKIN HAPUS? (KLIK LAGI)"
		delete_data_btn.disabled = false
	elif has_any_data:
		var ach_n: int = GameManager.get_all_unlocked_achievements().size()
		var ach_tot: int = GameManager.get_achievement_total_count()
		data_info_label.text = "Hapus semua data save & pencapaian (%d/%d terbuka). Pengaturan audio tetap aman." % [ach_n, ach_tot]
		data_info_label.add_theme_color_override("font_color", Color(0.92, 0.86, 0.78, 1.0))
		delete_data_btn.text = "HAPUS SEMUA DATA"
		delete_data_btn.disabled = false
	else:
		data_info_label.text = "Data save & pencapaian bersih (0/%d terbuka)." % GameManager.get_achievement_total_count()
		data_info_label.add_theme_color_override("font_color", Color(0.65, 0.88, 0.68, 1.0))
		delete_data_btn.text = "TIDAK ADA DATA"
		delete_data_btn.disabled = true


func _on_delete_data_pressed() -> void:
	var am := get_node_or_null("/root/AudioManager")
	if not _confirm_delete_pending:
		if am != null:
			am.play_sfx("query_error")
		_confirm_delete_pending = true
		_refresh_delete_data_ui()
		return
	GameManager.delete_all_save_data()
	_confirm_delete_pending = false
	if am != null:
		am.play_sfx("ui_confirm")
	_refresh_delete_data_ui()
	if data_info_label != null:
		data_info_label.text = "Semua data save, progres lantai & pencapaian berhasil dihapus!"
		data_info_label.add_theme_color_override("font_color", Color(0.62, 0.96, 0.65, 1.0))
	if delete_data_btn != null:
		delete_data_btn.text = "DATA TERHAPUS"
		delete_data_btn.disabled = true
	var p := get_parent()
	if p != null:
		if p.has_method("_refresh_summary"):
			p._refresh_summary()
		if p.has_method("_refresh_menu_state"):
			p._refresh_menu_state()


func _on_dev_mode_pressed() -> void:
	var am := get_node_or_null("/root/AudioManager")
	if am != null:
		am.play_sfx("ui_confirm")
	GameManager.open_dev_panel()
