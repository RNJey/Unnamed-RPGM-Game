extends CanvasLayer
## Global NPC Dialogue & Floor 5 Mikael Cutscene overlay (Layer 95).
## Styled as a bottom-center RPG dialogue box (leaving the dungeon map visible above),
## supporting Hikari, King Jey, and Mikael (with End Game vs Continue Exploring choices).

const ENDING_SCENE_PATH: String = "res://scenes/ui/ending.tscn"

const NPC_DIALOGUES := {
	"hikari": {
		"name": "HIKARI THE ADVENTURER",
		"role": "PENJELAJAH ARSIP RAHASIA",
		"cutscene": false,
		"focus_camera": false,
		"has_end_choices": false,
		"sprite": "res://assets/sprites/Sprite_Sheet_Idle_Pria_Pixel_Art-removebg-preview.png",
		"name_color": Color(0.62, 0.95, 1.0, 1.0),
		"lines": [
			"Wahhh, akhirnya ketemu traveler lain juga! Kirain aku bakal sendirian terus di dalam sini!",
			"Eh, tunggu... kamu beneran sampai ke ruangan tersembunyi ini? Keren banget!",
			"Jujur aja, aku sebenarnya salah satu pembuat dunia ini yang lagi iseng mampir. Ambil perbekalan dan kristal dariku ini—semangat terus ya jalanin petualangannya!",
		],
		"repeat_lines": [
			"Tetap semangat ya jalanin petualangannya, Traveler! Jangan ragu memakai Ramuan HP [H] atau Kartu Hint jika menemui query yang sulit.",
		],
		"reward_preview": "Hadiah Pertama: +25 Koin, +2 Kristal, +2 Hint Token, +1 Ramuan HP & +75 XP",
	},
	"king_jey": {
		"name": "KING JEY",
		"role": "RAJA AULA KATAKOMBE",
		"cutscene": false,
		"focus_camera": false,
		"has_end_choices": false,
		"sprite": "res://assets/sprites/Sprite_Pixel_Enam_Bingkai_Transparan-removebg-preview.png",
		"name_color": Color(0.98, 0.9, 0.54, 1.0),
		"lines": [
			"Jadi kamu berhasil menyusup sampai sejauh ini, Traveler?",
			"Ingatlah... di balik kode dan lorong gelap ini, akulah yang mengatur aturannya.",
			"Terimalah Berkah Kerajaan dariku! Kekuatan tubuhmu akan bertambah permanen beserta perbekalan untuk menaklukkan lantai terakhir!",
		],
		"repeat_lines": [
			"Ingatlah... di balik kode dan lorong gelap ini, akulah yang mengatur aturannya. Melangkahlah terus hingga puncak SQL Vault!",
		],
		"reward_preview": "Berkah Pertama: +40 Koin, +3 Kristal, +2 Ramuan HP, +15 Max HP Permanen & +100 XP",
	},
	"mikael": {
		"name": "MIKAEL BUDI SANTOSA",
		"role": "PENJAGA AKHIR — CUTSCENE LANTAI 5",
		"cutscene": true,
		"focus_camera": true,
		"focus_offset": Vector2(4.0, 10.0),
		"has_end_choices": true,
		"sprite": "res://assets/sprites/Lembaran_Sprite_Pixel_Pria_Beranimasi-removebg-preview.png",
		"name_color": Color(1.0, 0.82, 0.48, 1.0),
		"lines": [
			"Luar biasa... kau benar-benar berhasil menembus seluruh lorong gelap di bawah sana dan mencapai ground.",
			"Tidak banyak yang sanggup bertahan sampai sejauh ini, apalagi hingga berdiri di hadapan Tree Wisdom.",
			"Jujur aku cukup terkesan. Selamat datang, Traveler—akhirnya kita bisa bertemu langsung di sini. Terimalah penghargaan dariku atas keberhasilanmu keluar dari dungeon ini!",
			"Sekarang keputusan ada di tanganmu, Traveler: apakah kau ingin menamatkan petualangan ini sekarang, atau masih ingin lanjut menjelajahi map?",
		],
		"repeat_lines": [
			"Selamat datang kembali di hadapan Tree Wisdom, Traveler! Apakah sekarang kau siap menamatkan petualangan ini, atau masih ingin lanjut menjelajahi map?",
		],
		"reward_preview": "Penghargaan Lantai 5: +50 Koin, +5 Kristal, HP & Energi Penuh & +150 XP",
	},
}

var _root: Control
var _top_cinema: ColorRect
var _bottom_cinema: ColorRect
var _name_label: Label
var _page_label: Label
var _body_label: Label
var _reward_label: Label
var _hint_label: Label
var _next_btn: Button
var _close_btn: Button
var _choices_row: HBoxContainer
var _end_game_btn: Button
var _continue_explore_btn: Button

var _cur_npc_id: String = ""
var _lines: Array[String] = []
var _page_idx: int = 0
var _reward_claimed_before: bool = false
var _choice_mode_active: bool = false
var _opened_at_msec: int = 0
var _was_paused_before: bool = false
var _focused_camera: Camera2D = null
var _focus_world_pos: Vector2 = Vector2.ZERO
var _saved_cam_pos: Vector2 = Vector2.ZERO
var _saved_cam_process_mode: Node.ProcessMode = Node.PROCESS_MODE_INHERIT
var _saved_cam_smoothing: bool = true


func _ready() -> void:
	layer = 95
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_root.visible = false


func _process(_delta: float) -> void:
	if _root != null and _root.visible and _focused_camera != null and is_instance_valid(_focused_camera):
		_focused_camera.global_position = _focus_world_pos
		_focused_camera.force_update_scroll()


func is_dialogue_open() -> bool:
	return _root != null and _root.visible


func is_choice_active() -> bool:
	return _root != null and _root.visible and _choice_mode_active


func is_camera_focused_on_speaker() -> bool:
	return _focused_camera != null and is_instance_valid(_focused_camera) and _focused_camera.global_position.distance_to(_focus_world_pos) < 1.0


func start_dialogue(npc_id: String, speaker_node: Node2D = null) -> void:
	if not NPC_DIALOGUES.has(npc_id):
		push_warning("NPCDialogueModal: unknown npc_id=%s" % npc_id)
		return
	var spec: Dictionary = NPC_DIALOGUES[npc_id]
	var gm := _gm()
	_cur_npc_id = npc_id
	_choice_mode_active = false
	_reward_claimed_before = bool(gm != null and gm.has_method("is_npc_reward_claimed") and gm.is_npc_reward_claimed(npc_id))

	_lines.clear()
	var raw_lines: Array = spec.get("repeat_lines", []) if _reward_claimed_before else spec.get("lines", [])
	for line in raw_lines:
		_lines.append(str(line))
	if _lines.is_empty():
		_lines.append("...")
	_page_idx = 0

	# Middle-bottom dialogue box keeps map & characters clearly visible without cinema bars.
	_top_cinema.visible = false
	_bottom_cinema.visible = false
	_name_label.text = str(spec.get("name", npc_id))
	var col: Color = spec.get("name_color", Color(0.98, 0.93, 0.72, 1))
	_name_label.add_theme_color_override("font_color", col)

	if bool(spec.get("focus_camera", false)):
		var offset_v: Vector2 = spec.get("focus_offset", Vector2(4.0, 10.0))
		_apply_camera_focus(npc_id, speaker_node, offset_v)
	else:
		_restore_camera_focus()

	if get_tree() != null:
		_was_paused_before = get_tree().paused
		get_tree().paused = true
	_opened_at_msec = Time.get_ticks_msec()

	var am := get_node_or_null("/root/AudioManager")
	if am != null:
		am.play_sfx("ui_confirm")

	_root.visible = true
	_refresh_page()


func close_dialogue() -> void:
	if _root == null or not _root.visible:
		return
	_restore_camera_focus()
	_choice_mode_active = false
	if _choices_row != null:
		_choices_row.visible = false
	_root.visible = false
	if get_tree() != null:
		get_tree().paused = _was_paused_before


func _find_speaker_node(npc_id: String, provided: Node2D) -> Node2D:
	if provided != null and is_instance_valid(provided):
		return provided
	if get_tree() == null or get_tree().root == null:
		return null
	return _find_node_by_npc_id(get_tree().root, npc_id)


func _find_node_by_npc_id(node: Node, npc_id: String) -> Node2D:
	if node is Node2D and node.get("npc_id") != null and str(node.get("npc_id")) == npc_id:
		return node as Node2D
	for ch in node.get_children():
		var hit := _find_node_by_npc_id(ch, npc_id)
		if hit != null:
			return hit
	return null


func _apply_camera_focus(npc_id: String, speaker_node: Node2D, focus_offset: Vector2) -> void:
	_restore_camera_focus()
	var target: Node2D = _find_speaker_node(npc_id, speaker_node)
	var vp := get_viewport()
	var cam: Camera2D = vp.get_camera_2d() if vp != null else null
	if cam != null and target != null:
		_focused_camera = cam
		_saved_cam_pos = cam.position
		_saved_cam_process_mode = cam.process_mode
		_saved_cam_smoothing = cam.position_smoothing_enabled
		_focus_world_pos = target.global_position + focus_offset
		cam.process_mode = Node.PROCESS_MODE_ALWAYS
		cam.position_smoothing_enabled = false
		cam.global_position = _focus_world_pos
		cam.force_update_scroll()


func _restore_camera_focus() -> void:
	if _focused_camera != null and is_instance_valid(_focused_camera):
		_focused_camera.position = _saved_cam_pos
		_focused_camera.position_smoothing_enabled = _saved_cam_smoothing
		_focused_camera.process_mode = _saved_cam_process_mode
		_focused_camera.force_update_scroll()
	_focused_camera = null


func choose_end_game() -> void:
	var am := get_node_or_null("/root/AudioManager")
	if am != null:
		am.play_sfx("ui_confirm")
	close_dialogue()
	if get_tree() != null:
		get_tree().paused = false
		get_tree().change_scene_to_file.call_deferred(ENDING_SCENE_PATH)


func choose_continue_exploring() -> void:
	var am := get_node_or_null("/root/AudioManager")
	if am != null:
		am.play_sfx("ui_confirm")
	close_dialogue()


func _advance_or_finish() -> void:
	var am := get_node_or_null("/root/AudioManager")
	if _page_idx + 1 < _lines.size():
		_page_idx += 1
		if am != null:
			am.play_sfx("ui_confirm")
		_refresh_page()
	elif _choice_mode_active:
		# Wait for the player to explicitly choose End Game or Continue Exploring.
		return
	else:
		if am != null:
			am.play_sfx("ui_confirm")
		close_dialogue()


func _refresh_page() -> void:
	var total: int = _lines.size()
	_page_label.text = "%d / %d" % [_page_idx + 1, total]
	_body_label.text = _lines[_page_idx]
	var spec: Dictionary = NPC_DIALOGUES.get(_cur_npc_id, {})
	var on_last_page: bool = (_page_idx >= total - 1)

	if _reward_claimed_before:
		_reward_label.text = "Hadiah dari %s sudah diterima" % str(spec.get("name", "NPC"))
		_reward_label.add_theme_color_override("font_color", Color(0.72, 0.84, 0.72, 1.0))
	elif on_last_page:
		var gm := _gm()
		var res: Dictionary = gm.claim_npc_reward(_cur_npc_id) if (gm != null and gm.has_method("claim_npc_reward")) else {}
		if bool(res.get("claimed_now", false)):
			var am := get_node_or_null("/root/AudioManager")
			if am != null:
				am.play_sfx("achievement")
			_reward_claimed_before = true
			_reward_label.text = "HADIAH DITERIMA: %s" % str(res.get("summary", ""))
			_reward_label.add_theme_color_override("font_color", Color(0.62, 0.98, 0.68, 1.0))
	else:
		_reward_label.text = str(spec.get("reward_preview", ""))
		_reward_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45, 1.0))

	_choice_mode_active = on_last_page and bool(spec.get("has_end_choices", false))
	if _choice_mode_active:
		_choices_row.visible = true
		_next_btn.visible = false
		_close_btn.visible = false
		_hint_label.text = "Pilih: [1] Tamatkan Game  |  [2 / Esc] Lanjut Eksplorasi"
		_end_game_btn.grab_focus()
	else:
		_choices_row.visible = false
		_next_btn.visible = true
		_close_btn.visible = true
		_hint_label.text = "[E] Tutup" if on_last_page else "[E] Lanjut"
		_next_btn.text = "[E] Tutup" if on_last_page else "[E] Lanjut ->"


func _input(event: InputEvent) -> void:
	if _root == null or not _root.visible:
		return
	if Time.get_ticks_msec() - _opened_at_msec < 160:
		if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
			var vp_early := get_viewport()
			if vp_early != null:
				vp_early.set_input_as_handled()
		return

	if _choice_mode_active:
		if event is InputEventKey and event.pressed and not event.echo:
			var key_ev := event as InputEventKey
			if key_ev.physical_keycode == KEY_1 or key_ev.keycode == KEY_1:
				choose_end_game()
				_mark_handled()
				return
			elif key_ev.physical_keycode == KEY_2 or key_ev.keycode == KEY_2:
				choose_continue_exploring()
				_mark_handled()
				return
		if event.is_action_pressed("ui_cancel"):
			choose_continue_exploring()
			_mark_handled()
			return
		if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
			_mark_handled()
			return
		return

	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		_advance_or_finish()
		_mark_handled()
	elif event.is_action_pressed("ui_cancel"):
		close_dialogue()
		_mark_handled()


func _mark_handled() -> void:
	var vp := get_viewport()
	if vp != null:
		vp.set_input_as_handled()


func _gm() -> Node:
	return get_node_or_null("/root/GameManager")


func _make_style(bg: Color, border: Color, bw: int = 1, radius: int = 6) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_border_width_all(bw)
	sb.border_color = border
	sb.set_corner_radius_all(radius)
	return sb


func _build_ui() -> void:
	_root = Control.new()
	_root.name = "DialogueRoot"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_root)

	_top_cinema = ColorRect.new()
	_top_cinema.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_top_cinema.offset_bottom = 44.0
	_top_cinema.color = Color(0.02, 0.02, 0.03, 0.94)
	_top_cinema.visible = false
	_root.add_child(_top_cinema)

	_bottom_cinema = ColorRect.new()
	_bottom_cinema.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_bottom_cinema.offset_top = -44.0
	_bottom_cinema.color = Color(0.02, 0.02, 0.03, 0.94)
	_bottom_cinema.visible = false
	_root.add_child(_bottom_cinema)

	# Bottom-center anchor container (mirrors Primary DialogueBox middle-bottom placement)
	var bottom_wrap := MarginContainer.new()
	bottom_wrap.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_wrap.offset_top = -205.0
	bottom_wrap.offset_bottom = 0.0
	bottom_wrap.add_theme_constant_override("margin_left", 24)
	bottom_wrap.add_theme_constant_override("margin_right", 24)
	bottom_wrap.add_theme_constant_override("margin_bottom", 20)
	_root.add_child(bottom_wrap)

	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bottom_wrap.add_child(center)

	var modal := PanelContainer.new()
	modal.custom_minimum_size = Vector2(892, 162)
	modal.add_theme_stylebox_override("panel", _make_style(Color(0.11, 0.14, 0.11, 0.95), Color(0.75, 0.72, 0.44, 1.0), 2, 8))
	center.add_child(modal)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 12)
	modal.add_child(margin)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 8)
	margin.add_child(col)

	# Top header: SpeakerLabel + Reward info + Page counter
	var hdr := HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 10)
	col.add_child(hdr)

	_name_label = Label.new()
	_name_label.name = "SpeakerLabel"
	_name_label.text = "MIKAEL"
	_name_label.add_theme_font_size_override("font_size", 15)
	hdr.add_child(_name_label)

	_reward_label = Label.new()
	_reward_label.text = ""
	_reward_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_reward_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_reward_label.add_theme_font_size_override("font_size", 11)
	hdr.add_child(_reward_label)

	_page_label = Label.new()
	_page_label.text = "1 / 3"
	_page_label.add_theme_font_size_override("font_size", 12)
	_page_label.add_theme_color_override("font_color", Color(0.76, 0.82, 0.74, 1.0))
	hdr.add_child(_page_label)

	# Body panel: Dialogue text
	var body_card := PanelContainer.new()
	body_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_card.add_theme_stylebox_override("panel", _make_style(Color(0.08, 0.10, 0.08, 0.92), Color(0.35, 0.42, 0.32, 0.85), 1, 6))
	col.add_child(body_card)

	var bmargin := MarginContainer.new()
	bmargin.add_theme_constant_override("margin_left", 12)
	bmargin.add_theme_constant_override("margin_top", 8)
	bmargin.add_theme_constant_override("margin_right", 12)
	bmargin.add_theme_constant_override("margin_bottom", 8)
	body_card.add_child(bmargin)

	_body_label = Label.new()
	_body_label.name = "DialogueLabel"
	_body_label.text = "..."
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_label.add_theme_font_size_override("font_size", 14)
	_body_label.add_theme_color_override("font_color", Color(0.95, 0.96, 0.92, 1.0))
	bmargin.add_child(_body_label)

	# Bottom footer: HintLabel + standard advance/close OR Floor 5 End/Explore choices
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 10)
	col.add_child(footer)

	_hint_label = Label.new()
	_hint_label.name = "HintLabel"
	_hint_label.text = "[E] Lanjut"
	_hint_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hint_label.add_theme_font_size_override("font_size", 12)
	_hint_label.add_theme_color_override("font_color", Color(0.92, 0.88, 0.6, 1.0))
	footer.add_child(_hint_label)

	_close_btn = Button.new()
	_close_btn.text = "Tutup [Esc]"
	_close_btn.add_theme_font_size_override("font_size", 12)
	_close_btn.pressed.connect(close_dialogue)
	footer.add_child(_close_btn)

	_next_btn = Button.new()
	_next_btn.text = "[E] Lanjut ->"
	_next_btn.custom_minimum_size = Vector2(150, 30)
	_next_btn.add_theme_font_size_override("font_size", 12)
	_next_btn.pressed.connect(_advance_or_finish)
	footer.add_child(_next_btn)

	_choices_row = HBoxContainer.new()
	_choices_row.visible = false
	_choices_row.add_theme_constant_override("separation", 10)
	footer.add_child(_choices_row)

	_end_game_btn = Button.new()
	_end_game_btn.name = "EndGameBtn"
	_end_game_btn.text = "Tamatkan Game (Ke Ending)"
	_end_game_btn.custom_minimum_size = Vector2(215, 32)
	_end_game_btn.add_theme_font_size_override("font_size", 12)
	_end_game_btn.add_theme_stylebox_override("normal", _make_style(Color(0.18, 0.42, 0.25, 1.0), Color(0.62, 0.94, 0.65, 1.0), 1, 5))
	_end_game_btn.pressed.connect(choose_end_game)
	_choices_row.add_child(_end_game_btn)

	_continue_explore_btn = Button.new()
	_continue_explore_btn.name = "ContinueExploreBtn"
	_continue_explore_btn.text = "Lanjut Eksplorasi Map"
	_continue_explore_btn.custom_minimum_size = Vector2(185, 32)
	_continue_explore_btn.add_theme_font_size_override("font_size", 12)
	_continue_explore_btn.add_theme_stylebox_override("normal", _make_style(Color(0.22, 0.27, 0.23, 1.0), Color(0.75, 0.72, 0.44, 1.0), 1, 5))
	_continue_explore_btn.pressed.connect(choose_continue_exploring)
	_choices_row.add_child(_continue_explore_btn)
