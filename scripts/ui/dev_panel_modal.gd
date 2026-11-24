extends CanvasLayer
## Global Developer & Debug Console overlay (Layer 100).
## Toggle anywhere with [F12] or via Pause Menu / Settings -> Developer Mode.

var _root: Control
var _modal: PanelContainer
var _stats_label: Label
var _status_label: Label
var _god_btn: Button
var _noclip_btn: Button
var _was_paused_before_open: bool = false

const TELEPORT_TARGETS := [
	{"label": "Menu Utama", "path": "res://scenes/ui/main_menu.tscn", "floor": 0},
	{"label": "Lantai 1", "path": "res://scenes/floors/floor_1_dungeon.tscn", "floor": 1},
	{"label": "Lantai 2", "path": "res://scenes/floors/floor_2_dungeon.tscn", "floor": 2},
	{"label": "Secret L2 (Trader)", "path": "res://scenes/floors/floor_2_secret.tscn", "floor": 2},
	{"label": "Lantai 3", "path": "res://scenes/floors/floor_3_catacomb.tscn", "floor": 3},
	{"label": "Secret L3-1 (Hikari)", "path": "res://scenes/floors/floor_3_secret1.tscn", "floor": 3},
	{"label": "Secret L3-2 (King Jey)", "path": "res://scenes/floors/floor_3_secret2.tscn", "floor": 3},
	{"label": "Lantai 4", "path": "res://scenes/floors/floor_4_catacomb.tscn", "floor": 4},
	{"label": "Lantai 5 (Mikael)", "path": "res://scenes/floors/floor_5_ground.tscn", "floor": 5},
	{"label": "Layar Ending", "path": "res://scenes/ui/ending.tscn", "floor": 5},
]


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_root.visible = false


func is_panel_open() -> bool:
	return _root != null and _root.visible


func open_panel() -> void:
	var gm := _gm()
	if gm != null:
		gm.dev_mode_enabled = true
	if _root.visible:
		_refresh_state()
		return
	if get_tree() != null:
		_was_paused_before_open = get_tree().paused
		get_tree().paused = true
	_refresh_state()
	_set_status("Developer Mode aktif. Tekan [F12] atau [Esc] untuk menutup.", Color(0.75, 0.94, 0.8, 1))
	_root.visible = true


func close_panel() -> void:
	if not _root.visible:
		return
	_root.visible = false
	if get_tree() != null:
		# Keep PauseMenu/Bengkel/Shop paused if one was already open behind us.
		var keep_paused := _was_paused_before_open or _any_modal_visible_in_scene()
		get_tree().paused = keep_paused


func toggle_panel() -> void:
	if is_panel_open():
		close_panel()
	else:
		open_panel()


func _any_modal_visible_in_scene() -> bool:
	if get_tree() == null or get_tree().current_scene == null:
		return false
	var cl := get_tree().current_scene.get_node_or_null("CanvasLayer")
	if cl == null:
		return false
	for node_name: String in ["BengkelQueryUI", "ShopUI", "PauseMenu", "GameOverUI"]:
		var n := cl.get_node_or_null(node_name) as CanvasItem
		if n != null and n.visible:
			return true
	return false


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_F12:
			toggle_panel()
			var vp := get_viewport()
			if vp != null:
				vp.set_input_as_handled()
			return
	if _root != null and _root.visible and event.is_action_pressed("ui_cancel"):
		close_panel()
		var vp := get_viewport()
		if vp != null:
			vp.set_input_as_handled()


func _gm() -> Node:
	return get_node_or_null("/root/GameManager")


func _play_click() -> void:
	var am := get_node_or_null("/root/AudioManager")
	if am != null:
		am.play_sfx("ui_confirm")


func _make_style(bg: Color, border: Color, bw: int = 1, radius: int = 6) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_border_width_all(bw)
	sb.border_color = border
	sb.set_corner_radius_all(radius)
	return sb


func _build_ui() -> void:
	_root = Control.new()
	_root.name = "DevRoot"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_root)

	var backdrop := ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.02, 0.04, 0.03, 0.78)
	_root.add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)

	_modal = PanelContainer.new()
	_modal.custom_minimum_size = Vector2(780, 500)
	_modal.add_theme_stylebox_override("panel", _make_style(Color(0.2, 0.25, 0.2, 0.98), Color(0.55, 0.85, 0.6, 1), 3, 10))
	center.add_child(_modal)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 14)
	_modal.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	# Header
	var header_card := PanelContainer.new()
	header_card.add_theme_stylebox_override("panel", _make_style(Color(0.14, 0.18, 0.14, 0.96), Color(0.4, 0.55, 0.42, 0.9), 1, 6))
	vbox.add_child(header_card)

	var hmargin := MarginContainer.new()
	hmargin.add_theme_constant_override("margin_left", 12)
	hmargin.add_theme_constant_override("margin_top", 8)
	hmargin.add_theme_constant_override("margin_right", 12)
	hmargin.add_theme_constant_override("margin_bottom", 8)
	header_card.add_child(hmargin)

	var hrow := HBoxContainer.new()
	hrow.add_theme_constant_override("separation", 10)
	hmargin.add_child(hrow)

	var pill := PanelContainer.new()
	var pill_sb := _make_style(Color(0.15, 0.4, 0.25, 1), Color(0.45, 0.95, 0.65, 1), 1, 4)
	pill_sb.content_margin_left = 8
	pill_sb.content_margin_right = 8
	pill_sb.content_margin_top = 3
	pill_sb.content_margin_bottom = 3
	pill.add_theme_stylebox_override("panel", pill_sb)
	hrow.add_child(pill)

	var pill_lbl := Label.new()
	pill_lbl.text = "DEV MODE"
	pill_lbl.add_theme_font_size_override("font_size", 11)
	pill_lbl.add_theme_color_override("font_color", Color(0.84, 1, 0.88, 1))
	pill.add_child(pill_lbl)

	var title_lbl := Label.new()
	title_lbl.text = "Developer & Debug Console [F12]"
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.add_theme_font_size_override("font_size", 15)
	title_lbl.add_theme_color_override("font_color", Color(0.98, 0.93, 0.72, 1))
	hrow.add_child(title_lbl)

	var close_btn := Button.new()
	close_btn.text = "TUTUP [F12 / Esc]"
	close_btn.add_theme_font_size_override("font_size", 12)
	close_btn.pressed.connect(func():
		_play_click()
		close_panel()
	)
	hrow.add_child(close_btn)

	# Live telemetry bar
	var stats_card := PanelContainer.new()
	stats_card.add_theme_stylebox_override("panel", _make_style(Color(0.1, 0.12, 0.1, 0.98), Color(0.32, 0.42, 0.32, 0.9), 1, 5))
	vbox.add_child(stats_card)

	var smargin := MarginContainer.new()
	smargin.add_theme_constant_override("margin_left", 10)
	smargin.add_theme_constant_override("margin_top", 6)
	smargin.add_theme_constant_override("margin_right", 10)
	smargin.add_theme_constant_override("margin_bottom", 6)
	stats_card.add_child(smargin)

	_stats_label = Label.new()
	_stats_label.text = "Statistik..."
	_stats_label.add_theme_font_size_override("font_size", 12)
	_stats_label.add_theme_color_override("font_color", Color(0.65, 0.95, 1, 1))
	smargin.add_child(_stats_label)

	# Action Grid (Toggles & Cheats)
	var actions_card := PanelContainer.new()
	actions_card.add_theme_stylebox_override("panel", _make_style(Color(0.14, 0.18, 0.14, 0.96), Color(0.38, 0.48, 0.38, 0.9), 1, 6))
	vbox.add_child(actions_card)

	var amargin := MarginContainer.new()
	amargin.add_theme_constant_override("margin_left", 10)
	amargin.add_theme_constant_override("margin_top", 8)
	amargin.add_theme_constant_override("margin_right", 10)
	amargin.add_theme_constant_override("margin_bottom", 8)
	actions_card.add_child(amargin)

	var avbox := VBoxContainer.new()
	avbox.add_theme_constant_override("separation", 6)
	amargin.add_child(avbox)

	var act_hdr := Label.new()
	act_hdr.text = "ALAT DEBUG & CHEAT PENGUJIAN:"
	act_hdr.add_theme_font_size_override("font_size", 12)
	act_hdr.add_theme_color_override("font_color", Color(0.98, 0.9, 0.54, 1))
	avbox.add_child(act_hdr)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	avbox.add_child(grid)

	_god_btn = _add_grid_btn(grid, "GOD MODE (HP & Energi Kebal): OFF", _on_toggle_god)
	_noclip_btn = _add_grid_btn(grid, "TEMBUS TEMBOK (No-Clip): OFF", _on_toggle_noclip)
	_add_grid_btn(grid, "+100 Koin, +15 Kristal, +5 Kunci, +10 Hint, +5 Ramuan", _on_grant_resources)
	_add_grid_btn(grid, "Buka Semua Lantai (1-5) + Pedang & Sepatu Cepat", _on_unlock_all)
	_add_grid_btn(grid, "Selesaikan Semua SQL & Tuas Lantai Ini", _on_solve_floor)
	_add_grid_btn(grid, "Kalahkan Semua Musuh di Lantai Ini", _on_kill_enemies)
	_add_grid_btn(grid, "Pulihkan Penuh HP & Energi (+50 Max HP)", _on_boost_heal)
	_add_grid_btn(grid, "Buka Semua 8 Pencapaian (Achievements)", _on_unlock_achievements)

	# Teleport Card
	var tp_card := PanelContainer.new()
	tp_card.add_theme_stylebox_override("panel", _make_style(Color(0.14, 0.18, 0.14, 0.96), Color(0.38, 0.48, 0.38, 0.9), 1, 6))
	vbox.add_child(tp_card)

	var tmargin := MarginContainer.new()
	tmargin.add_theme_constant_override("margin_left", 10)
	tmargin.add_theme_constant_override("margin_top", 8)
	tmargin.add_theme_constant_override("margin_right", 10)
	tmargin.add_theme_constant_override("margin_bottom", 8)
	tp_card.add_child(tmargin)

	var tvbox := VBoxContainer.new()
	tvbox.add_theme_constant_override("separation", 6)
	tmargin.add_child(tvbox)

	var tp_hdr := Label.new()
	tp_hdr.text = "TELEPORT INSTAN KE SCENE / LANTAI:"
	tp_hdr.add_theme_font_size_override("font_size", 12)
	tp_hdr.add_theme_color_override("font_color", Color(0.62, 0.96, 0.68, 1))
	tvbox.add_child(tp_hdr)

	var tp_grid := GridContainer.new()
	tp_grid.columns = 5
	tp_grid.add_theme_constant_override("h_separation", 6)
	tp_grid.add_theme_constant_override("v_separation", 6)
	tvbox.add_child(tp_grid)

	for item: Dictionary in TELEPORT_TARGETS:
		var lbl := str(item["label"])
		var path := str(item["path"])
		var fnum := int(item["floor"])
		var btn := Button.new()
		btn.text = lbl
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 32)
		btn.add_theme_font_size_override("font_size", 11)
		btn.pressed.connect(func(): _on_teleport(lbl, path, fnum))
		tp_grid.add_child(btn)

	# Status Banner
	var status_card := PanelContainer.new()
	status_card.add_theme_stylebox_override("panel", _make_style(Color(0.1, 0.12, 0.1, 0.98), Color(0.32, 0.42, 0.32, 0.9), 1, 5))
	vbox.add_child(status_card)

	var stmargin := MarginContainer.new()
	stmargin.add_theme_constant_override("margin_left", 10)
	stmargin.add_theme_constant_override("margin_top", 6)
	stmargin.add_theme_constant_override("margin_right", 10)
	stmargin.add_theme_constant_override("margin_bottom", 6)
	status_card.add_child(stmargin)

	_status_label = Label.new()
	_status_label.text = "Siap."
	_status_label.add_theme_font_size_override("font_size", 12)
	_status_label.add_theme_color_override("font_color", Color(0.84, 0.9, 0.8, 1))
	stmargin.add_child(_status_label)


func _add_grid_btn(grid: GridContainer, label_txt: String, cb: Callable) -> Button:
	var btn := Button.new()
	btn.text = label_txt
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(0, 34)
	btn.add_theme_font_size_override("font_size", 12)
	btn.pressed.connect(cb)
	grid.add_child(btn)
	return btn


func _refresh_state() -> void:
	var gm := _gm()
	if gm == null:
		return
	var pos_str := "-"
	if get_tree() != null:
		var player := get_tree().get_first_node_in_group("player") as Node2D
		if player != null and is_instance_valid(player):
			pos_str = "(%d, %d)" % [int(roundf(player.global_position.x)), int(roundf(player.global_position.y))]
	_stats_label.text = "Lantai %d · HP %d/%d · Energi %d/%d · Koin %d · Kristal %d · Kunci %d · Hint %d · Pos %s" % [
		int(gm.current_floor),
		int(gm.hp),
		int(gm.max_hp),
		int(gm.energy),
		int(gm.max_energy),
		int(gm.coins),
		int(gm.syntax_crystals),
		int(gm.special_keys),
		int(gm.hint_tokens),
		pos_str,
	]
	_god_btn.text = "GOD MODE (HP & Energi Kebal): " + ("ON [AKTIF]" if gm.dev_god_mode else "OFF")
	_noclip_btn.text = "TEMBUS TEMBOK (No-Clip): " + ("ON [AKTIF]" if gm.dev_noclip else "OFF")


func _set_status(msg: String, color: Color) -> void:
	if _status_label != null:
		_status_label.text = msg
		_status_label.add_theme_color_override("font_color", color)


func _on_toggle_god() -> void:
	_play_click()
	var gm := _gm()
	if gm == null:
		return
	gm.dev_god_mode = not gm.dev_god_mode
	if gm.dev_god_mode:
		gm.hp = gm.max_hp
		gm.energy = gm.max_energy
	_refresh_state()
	_set_status("God Mode " + ("AKTIF! HP & Energi SQL tidak berkurang." if gm.dev_god_mode else "DIMATIKAN."), Color(0.62, 0.96, 0.65, 1))


func _on_toggle_noclip() -> void:
	_play_click()
	var gm := _gm()
	if gm == null:
		return
	gm.set_dev_noclip(not gm.dev_noclip)
	_refresh_state()
	_set_status("No-Clip (Tembus Tembok) " + ("AKTIF! Player bisa menembus tembok/pintu." if gm.dev_noclip else "DIMATIKAN (Collision normal)."), Color(0.62, 0.96, 0.65, 1))


func _on_grant_resources() -> void:
	_play_click()
	var gm := _gm()
	if gm == null:
		return
	gm.dev_grant_resources()
	_refresh_state()
	_set_status("Berhasil menambah +100 Koin, +15 Kristal, +5 Kunci, +10 Hint, +5 Ramuan HP, +3 Chip!", Color(0.98, 0.9, 0.45, 1))


func _on_unlock_all() -> void:
	_play_click()
	var gm := _gm()
	if gm == null:
		return
	gm.dev_unlock_all_floors_and_upgrades()
	_refresh_state()
	_set_status("Semua lantai (1-5) di Pilih Lantai + Pedang Kristal & Sepatu Cepat diaktifkan!", Color(0.62, 0.96, 0.65, 1))


func _on_solve_floor() -> void:
	_play_click()
	var gm := _gm()
	if gm == null:
		return
	gm.dev_solve_current_floor(int(gm.current_floor))
	_refresh_state()
	_set_status("Semua terminal SQL & tuas Lantai %d diselesaikan — pintu keluar lantai terbuka!" % int(gm.current_floor), Color(0.62, 0.96, 0.65, 1))


func _on_kill_enemies() -> void:
	_play_click()
	var gm := _gm()
	if gm == null:
		return
	var killed: int = gm.dev_kill_floor_enemies()
	_refresh_state()
	_set_status("%d musuh di scene aktif dikalahkan (+koin otomatis masuk)." % killed, Color(0.98, 0.85, 0.45, 1))


func _on_boost_heal() -> void:
	_play_click()
	var gm := _gm()
	if gm == null:
		return
	gm.max_hp += 50
	gm.hp = gm.max_hp
	gm.energy = gm.max_energy
	gm.inventory_changed.emit()
	_refresh_state()
	_set_status("HP penuh & Max HP ditambah +50 (sekarang %d/%d), Energi penuh!" % [gm.hp, gm.max_hp], Color(0.62, 0.96, 0.65, 1))


func _on_unlock_achievements() -> void:
	_play_click()
	var gm := _gm()
	if gm == null:
		return
	gm.dev_unlock_all_achievements()
	_refresh_state()
	_set_status("Seluruh 8 pencapaian SQL Vault telah dibuka!", Color(0.98, 0.9, 0.45, 1))


func _on_teleport(label_txt: String, scene_path: String, floor_num: int) -> void:
	_play_click()
	var gm := _gm()
	if gm == null:
		return
	_root.visible = false
	_was_paused_before_open = false
	gm.dev_teleport_to(scene_path, floor_num)
	_set_status("Teleport ke %s..." % label_txt, Color(0.62, 0.95, 1, 1))
