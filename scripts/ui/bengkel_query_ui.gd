extends Control
## Bengkel Query SQL terminal UI: step-by-step DDL / DML / DCL missions with live schema & judge feedback.

const QueryEngineScript := preload("res://scripts/sql/query_engine.gd")
const QueryJudgeScript := preload("res://scripts/sql/query_judge.gd")
const ITEMS_TEX := preload("res://assets/tilesets/Valley Ruin Asset Pack V0.3/Objects/Items.png")
const DECOR_TEX := preload("res://assets/tilesets/DampDungeons/Tiles/DungeonDecorations.png")

const TARGET_ICONS := {
	"box": {"tex": DECOR_TEX, "rect": Rect2(320, 38, 16, 19)},
	"ruby": {"tex": ITEMS_TEX, "rect": Rect2(80, 16, 16, 16)},
	"emerald": {"tex": ITEMS_TEX, "rect": Rect2(16, 0, 16, 16)},
	"diamond": {"tex": ITEMS_TEX, "rect": Rect2(0, 0, 16, 16)},
	"coin": {"tex": ITEMS_TEX, "rect": Rect2(32, 0, 16, 16)},
	"flask": {"tex": ITEMS_TEX, "rect": Rect2(144, 16, 16, 16)},
	"tablet": {"tex": ITEMS_TEX, "rect": Rect2(96, 16, 16, 16)},
	"key": {"tex": ITEMS_TEX, "rect": Rect2(144, 32, 16, 16)},
	"sword": {"tex": ITEMS_TEX, "rect": Rect2(16, 16, 16, 16)},
}

static var _cached_levels: Dictionary = {}

var _cur_floor: int = 1
var _cur_lever_id: String = ""
var _cur_spec: Dictionary = {}
var _revealed_cards: int = 0

@onready var cat_label: Label = $Center/Modal/Margin/VBox/HeaderPanel/HMargin/HRow/CatPill/CatLabel
@onready var title_label: Label = $Center/Modal/Margin/VBox/HeaderPanel/HMargin/HRow/TitleLabel
@onready var energy_label: Label = $Center/Modal/Margin/VBox/HeaderPanel/HMargin/HRow/EnergyLabel
@onready var hint_count_label: Label = $Center/Modal/Margin/VBox/HeaderPanel/HMargin/HRow/HintCountLabel
@onready var close_btn: Button = $Center/Modal/Margin/VBox/HeaderPanel/HMargin/HRow/CloseBtn

@onready var target_icon: TextureRect = $Center/Modal/Margin/VBox/BodySplit/LeftCol/MissionCard/MMargin/MVBox/TargetRow/IconFrame/TargetIcon
@onready var step_label: Label = $Center/Modal/Margin/VBox/BodySplit/LeftCol/MissionCard/MMargin/MVBox/TargetRow/TargetTextCol/StepLabel
@onready var target_name_label: Label = $Center/Modal/Margin/VBox/BodySplit/LeftCol/MissionCard/MMargin/MVBox/TargetRow/TargetTextCol/TargetNameLabel
@onready var question_label: Label = $Center/Modal/Margin/VBox/BodySplit/LeftCol/MissionCard/MMargin/MVBox/QuestionLabel

@onready var schema_label: RichTextLabel = $Center/Modal/Margin/VBox/BodySplit/LeftCol/SchemaCard/SMargin/SVBox/SchemaText
@onready var reward_xp_label: Label = $Center/Modal/Margin/VBox/BodySplit/LeftCol/RewardCard/RMargin/RVBox/RewardRow/XPRewardLabel
@onready var reward_crystal_label: Label = $Center/Modal/Margin/VBox/BodySplit/LeftCol/RewardCard/RMargin/RVBox/RewardRow/CrystalRewardLabel
@onready var hint_text_label: Label = $Center/Modal/Margin/VBox/BodySplit/LeftCol/RewardCard/RMargin/RVBox/HintBox/HintTextLabel

@onready var token_bar: HBoxContainer = $Center/Modal/Margin/VBox/BodySplit/RightCol/TokenBar
@onready var query_edit: TextEdit = $Center/Modal/Margin/VBox/BodySplit/RightCol/EditorCard/EMargin/EVBox/QueryEdit
@onready var run_btn: Button = $Center/Modal/Margin/VBox/BodySplit/RightCol/EditorCard/EMargin/EVBox/ActionRow/RunBtn
@onready var hint_btn: Button = $Center/Modal/Margin/VBox/BodySplit/RightCol/EditorCard/EMargin/EVBox/ActionRow/HintBtn
@onready var reset_btn: Button = $Center/Modal/Margin/VBox/BodySplit/RightCol/EditorCard/EMargin/EVBox/ActionRow/ResetBtn
@onready var result_text: RichTextLabel = $Center/Modal/Margin/VBox/BodySplit/RightCol/ResultCard/ResMargin/ResVBox/ResultText
@onready var status_banner: PanelContainer = $Center/Modal/Margin/VBox/BodySplit/RightCol/ResultCard/ResMargin/ResVBox/StatusBanner
@onready var status_label: Label = $Center/Modal/Margin/VBox/BodySplit/RightCol/ResultCard/ResMargin/ResVBox/StatusBanner/StatusMargin/StatusLabel


func _ready() -> void:
	visible = false
	close_btn.pressed.connect(close_ui)
	run_btn.pressed.connect(_on_run_pressed)
	hint_btn.pressed.connect(_on_hint_pressed)
	reset_btn.pressed.connect(_on_reset_pressed)
	GameManager.energy_changed.connect(func(_a, _b): _refresh_header_stats())
	GameManager.inventory_changed.connect(_refresh_header_stats)


func _exit_tree() -> void:
	if visible and get_tree() != null:
		get_tree().paused = false


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		close_ui()
		get_viewport().set_input_as_handled()


static func load_levels() -> Dictionary:
	if _cached_levels.is_empty():
		var raw := FileAccess.get_file_as_string("res://data/levels.json")
		var parsed = JSON.parse_string(raw)
		if parsed is Dictionary:
			_cached_levels = parsed
	return _cached_levels


static func find_terminal_spec(floor_num: int, lever_id: String) -> Dictionary:
	var data := load_levels()
	var floors: Dictionary = data.get("floors", {})
	var arr: Array = floors.get(str(floor_num), [])
	for item: Dictionary in arr:
		if str(item.get("lever_id", "")) == lever_id:
			return item
	return arr[0] if not arr.is_empty() else {}


func open_for_terminal(floor_num: int, lever_id: String) -> void:
	_cur_floor = floor_num
	_cur_lever_id = lever_id
	_cur_spec = find_terminal_spec(floor_num, lever_id)
	if _cur_spec.is_empty():
		push_warning("BengkelQueryUI: no mission spec found for floor=%d lever=%s" % [floor_num, lever_id])
		return

	var total_cards: int = _cur_spec.get("quick_tokens", []).size()
	if GameManager.is_terminal_solved(lever_id):
		_revealed_cards = total_cards
	else:
		_revealed_cards = clampi(GameManager.get_terminal_hints_revealed(lever_id), 0, total_cards)
	_populate_ui()
	visible = true
	if get_tree() != null:
		get_tree().paused = true
	query_edit.grab_focus()


func close_ui() -> void:
	visible = false
	if get_tree() != null:
		get_tree().paused = false


func _populate_ui() -> void:
	cat_label.text = str(_cur_spec.get("category", "SQL"))
	title_label.text = str(_cur_spec.get("title", "Terminal SQL"))
	step_label.text = str(_cur_spec.get("step_label", "MISI SQL"))
	question_label.text = str(_cur_spec.get("question", ""))

	var t_item: Dictionary = _cur_spec.get("target_item", {"name": "Objek", "icon": "box"})
	target_name_label.text = str(t_item.get("name", "Objek"))
	var ic_key := str(t_item.get("icon", "box"))
	if TARGET_ICONS.has(ic_key):
		var at := AtlasTexture.new()
		at.atlas = TARGET_ICONS[ic_key]["tex"]
		at.region = TARGET_ICONS[ic_key]["rect"]
		target_icon.texture = at

	var rew: Dictionary = _cur_spec.get("reward", {})
	reward_xp_label.text = "+%d XP" % int(rew.get("xp", 50))
	reward_crystal_label.text = "+%d Kristal" % int(rew.get("crystals", 1))

	_render_db_state(_cur_spec.get("initial_db_state", {}))
	_refresh_hint_ui()
	_refresh_header_stats()
	_populate_tokens()

	if GameManager.is_terminal_solved(_cur_lever_id):
		query_edit.text = str(_cur_spec.get("expected_sql", ""))
		_show_checklist(_cur_spec.get("target_conditions", []), [], true)
		_set_banner("SELESAI! Terminal ini sudah terbuka dan tuas siap ditarik.", true)
	else:
		query_edit.text = ""
		_show_checklist(_cur_spec.get("target_conditions", []), [], false)
		_set_banner("Ketik query SQL atau klik bantuan sintaks, lalu tekan RUN QUERY.", false, true)


func _refresh_header_stats() -> void:
	if energy_label != null:
		if GameManager.energy_chips > 0:
			energy_label.text = "Energi: %d/%d (Chip: %d)" % [GameManager.energy, GameManager.max_energy, GameManager.energy_chips]
		else:
			energy_label.text = "Energi: %d/%d" % [GameManager.energy, GameManager.max_energy]
	if hint_count_label != null:
		hint_count_label.text = "Hint: %d" % GameManager.hint_tokens


func _refresh_hint_ui() -> void:
	var tokens: Array = _cur_spec.get("quick_tokens", [])
	var total_cards: int = tokens.size()
	if hint_btn != null:
		if _revealed_cards >= total_cards:
			hint_btn.text = "KARTU (%d/%d)" % [total_cards, total_cards]
			hint_btn.disabled = true
		else:
			hint_btn.text = "BUKA 1 KARTU (-1)"
			hint_btn.disabled = false

	if _revealed_cards <= 0:
		hint_text_label.text = "Kartu bantuan terkunci (0/%d). Tekan BUKA 1 KARTU (1 Hint Token) untuk membuka 1 kartu sintaks." % total_cards
		hint_text_label.add_theme_color_override("font_color", Color(0.75, 0.78, 0.7, 1))
	elif _revealed_cards < total_cards:
		var opened: Array[String] = []
		for i in _revealed_cards:
			opened.append(str(tokens[i]))
		hint_text_label.text = "Kartu terbuka (%d/%d): %s" % [_revealed_cards, total_cards, "  |  ".join(opened)]
		hint_text_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.45, 1))
	else:
		hint_text_label.text = "Semua kartu terbuka (%d/%d)! HINT: %s" % [total_cards, total_cards, str(_cur_spec.get("hint", ""))]
		hint_text_label.add_theme_color_override("font_color", Color(0.62, 0.96, 0.68, 1))


func _populate_tokens() -> void:
	var tokens: Array = _cur_spec.get("quick_tokens", [])
	for i in token_bar.get_child_count():
		var btn := token_bar.get_child(i) as Button
		if btn == null:
			continue
		for conn in btn.pressed.get_connections():
			btn.pressed.disconnect(conn["callable"])
		if i < tokens.size():
			btn.visible = true
			if i < _revealed_cards:
				var tok_txt := str(tokens[i])
				btn.text = tok_txt
				btn.disabled = false
				btn.pressed.connect(func(): _insert_token(tok_txt))
			else:
				btn.text = "[? Kartu %d]" % (i + 1)
				btn.disabled = true
		else:
			btn.visible = false


func _insert_token(tok_txt: String) -> void:
	var cur := query_edit.text
	if cur.is_empty():
		query_edit.text = tok_txt
	elif cur.ends_with(" ") or cur.ends_with("\n"):
		query_edit.text = cur + tok_txt
	else:
		query_edit.text = cur + " " + tok_txt
	query_edit.grab_focus()
	query_edit.set_caret_line(query_edit.get_line_count() - 1)
	query_edit.set_caret_column(query_edit.get_line(query_edit.get_line_count() - 1).length())


func _render_db_state(db_state: Dictionary) -> void:
	var lines: Array[String] = []
	var tables: Dictionary = db_state.get("tables", {})
	if tables.is_empty():
		lines.append("(Belum ada tabel dibuat)")
	else:
		for tname: String in tables.keys():
			var tbl: Dictionary = tables[tname]
			var cols: Array[String] = []
			for c: Dictionary in tbl.get("columns", []):
				cols.append("%s (%s)" % [c["name"], c["type"]])
			lines.append("TABEL %s: %s [%d baris]" % [tname, ", ".join(cols), tbl.get("rows", []).size()])
			for r: Dictionary in tbl.get("rows", []).slice(0, 3):
				lines.append("  • " + str(r))

	var perms: Dictionary = db_state.get("permissions", {})
	if not perms.is_empty():
		lines.append("")
		lines.append("IZIN DCL: " + str(perms))
	schema_label.text = "\n".join(lines)


func _on_hint_pressed() -> void:
	var am := get_node_or_null("/root/AudioManager")
	var tokens: Array = _cur_spec.get("quick_tokens", [])
	var total_cards: int = tokens.size()
	if _revealed_cards >= total_cards:
		_set_banner("Semua kartu bantuan (%d/%d) sudah terbuka!" % [total_cards, total_cards], true)
		return
	if not GameManager.reveal_next_terminal_hint(_cur_lever_id, total_cards):
		if am != null:
			am.play_sfx("query_error")
		_set_banner("Hint Token habis (0). Beli Token Petunjuk di Pedagang untuk membuka kartu bantuan.", false)
		return
	_revealed_cards = clampi(GameManager.get_terminal_hints_revealed(_cur_lever_id), 0, total_cards)
	if am != null:
		am.play_sfx("ui_confirm")
	_populate_tokens()
	_refresh_header_stats()
	_refresh_hint_ui()
	_set_banner("Kartu bantuan %d/%d terbuka: \"%s\" (Klik kartu di atas editor)." % [_revealed_cards, total_cards, str(tokens[_revealed_cards - 1])], true)


func _on_reset_pressed() -> void:
	var am := get_node_or_null("/root/AudioManager")
	if am != null:
		am.play_sfx("ui_confirm")
	query_edit.text = ""
	_render_db_state(_cur_spec.get("initial_db_state", {}))
	_show_checklist(_cur_spec.get("target_conditions", []), [], false)
	_set_banner("Editor direset. Ketik ulang query SQL kamu.", false, true)


func submit_query(sql: String) -> Dictionary:
	query_edit.text = sql
	return _run_current_query()


func _on_run_pressed() -> void:
	_run_current_query()


func _run_current_query() -> Dictionary:
	var am := get_node_or_null("/root/AudioManager")
	var used_chip := false
	if GameManager.energy <= 0 and GameManager.energy_chips > 0:
		used_chip = GameManager.use_energy_chip()
		if used_chip:
			GameManager.save_game()
			if am != null:
				am.play_sfx("ui_confirm")
	if not GameManager.use_energy():
		if am != null:
			am.play_sfx("query_error")
		_refresh_header_stats()
		_set_banner("Energi habis! Beli Chip Energi di Toko Rahasia atau keluar masuk terminal.", false)
		return {"ok": false, "error": "Energi habis."}

	_refresh_header_stats()
	var sql := query_edit.text.strip_edges()
	var res: Dictionary = QueryEngineScript.execute(sql, _cur_spec.get("initial_db_state", {}))
	if not res["ok"]:
		if am != null:
			am.play_sfx("query_error")
		_show_checklist(_cur_spec.get("target_conditions", []), [], false)
		var chip_note := " (1 Energy Chip dipakai!)" if used_chip else ""
		_set_banner("ERROR SQL%s: %s" % [chip_note, str(res["error"])], false)
		return res

	_render_db_state(res.get("db_state", {}))
	var judge: Dictionary = QueryJudgeScript.judge_terminal(res, _cur_spec.get("target_conditions", []))
	_show_checklist(_cur_spec.get("target_conditions", []), judge.get("checks", []), judge["ok"], res.get("rows", []))

	if not judge["ok"]:
		if am != null:
			am.play_sfx("query_error")
		_set_banner("BELUM TEPAT: %s" % str(judge["error"]), false)
		return {"ok": false, "error": judge["error"], "exec": res}

	var rew: Dictionary = _cur_spec.get("reward", {})
	GameManager.mark_terminal_solved(_cur_lever_id, int(rew.get("xp", 50)), int(rew.get("crystals", 1)))
	GameManager.save_game()
	_revealed_cards = _cur_spec.get("quick_tokens", []).size()
	_populate_tokens()
	_refresh_header_stats()
	_refresh_hint_ui()
	_set_banner("BENAR! Tuas terbuka (+%d XP, +%d Kristal, Energi penuh)." % [int(rew.get("xp", 50)), int(rew.get("crystals", 1))], true)
	return {"ok": true, "error": "", "exec": res}


func _show_checklist(conditions: Array, checks: Array, all_ok: bool, rows: Array = []) -> void:
	var out: Array[String] = []
	if not rows.is_empty():
		out.append("Baris hasil / isi tabel (%d):" % rows.size())
		for r: Dictionary in rows.slice(0, 4):
			out.append("  • " + str(r))
		out.append("")
	out.append("Syarat Blueprint:")
	if not checks.is_empty():
		for ch: Dictionary in checks:
			out.append("  %s %s" % ["[OK]" if ch["ok"] else "[ ]", str(ch["label"])])
	else:
		for cond: Dictionary in conditions:
			out.append("  %s %s" % ["[OK]" if all_ok else "[ ]", str(cond.get("label", ""))])
	result_text.text = "\n".join(out)


func _set_banner(msg: String, is_ok: bool, is_neutral: bool = false) -> void:
	status_label.text = msg
	var sb := StyleBoxFlat.new()
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_left = 4
	sb.corner_radius_bottom_right = 4
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	if is_neutral:
		sb.bg_color = Color(0.16, 0.19, 0.14, 1)
		sb.border_color = Color(0.45, 0.52, 0.4, 1)
		status_label.add_theme_color_override("font_color", Color(0.9, 0.92, 0.85, 1))
	elif is_ok:
		sb.bg_color = Color(0.14, 0.34, 0.21, 1)
		sb.border_color = Color(0.35, 0.85, 0.5, 1)
		status_label.add_theme_color_override("font_color", Color(0.75, 1.0, 0.8, 1))
	else:
		sb.bg_color = Color(0.38, 0.15, 0.16, 1)
		sb.border_color = Color(0.9, 0.4, 0.45, 1)
		status_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.82, 1))
	status_banner.add_theme_stylebox_override("panel", sb)
