extends Control
## Achievements modal listing all 8 SQL Vault achievements, unlocked state, and progress counter.

signal closed

const ITEMS_TEX := preload("res://assets/tilesets/Valley Ruin Asset Pack V0.3/Objects/Items.png")

const ICON_RECTS := {
	"diamond": Rect2(0, 0, 16, 16),
	"emerald": Rect2(16, 0, 16, 16),
	"coin": Rect2(32, 0, 16, 16),
	"sword": Rect2(16, 16, 16, 16),
	"ruby": Rect2(80, 16, 16, 16),
	"hint": Rect2(96, 16, 16, 16),
	"tablet": Rect2(96, 16, 16, 16),
	"potion": Rect2(128, 16, 16, 16),
	"key": Rect2(144, 32, 16, 16),
}

@onready var count_label: Label = $Center/Modal/Margin/VBox/HeaderCard/HMargin/HRow/CountBadge/CountLabel
@onready var close_btn: Button = $Center/Modal/Margin/VBox/HeaderCard/HMargin/HRow/CloseBtn
@onready var grid: GridContainer = $Center/Modal/Margin/VBox/Scroll/Grid
@onready var footer_label: Label = $Center/Modal/Margin/VBox/StatusBanner/SMargin/FooterLabel

var _style_unlocked_card: StyleBoxFlat
var _style_locked_card: StyleBoxFlat
var _style_unlocked_pill: StyleBoxFlat
var _style_locked_pill: StyleBoxFlat
var _style_icon_box: StyleBoxFlat


func _ready() -> void:
	visible = false
	_init_styles()
	close_btn.pressed.connect(close_achievements)
	GameManager.achievement_unlocked.connect(func(_id): _refresh_list())
	_refresh_list()


func _init_styles() -> void:
	_style_unlocked_card = StyleBoxFlat.new()
	_style_unlocked_card.bg_color = Color(0.16, 0.25, 0.17, 0.98)
	_style_unlocked_card.set_border_width_all(2)
	_style_unlocked_card.border_color = Color(0.92, 0.78, 0.34, 1.0)
	_style_unlocked_card.set_corner_radius_all(6)

	_style_locked_card = StyleBoxFlat.new()
	_style_locked_card.bg_color = Color(0.14, 0.16, 0.14, 0.94)
	_style_locked_card.set_border_width_all(1)
	_style_locked_card.border_color = Color(0.35, 0.4, 0.33, 0.85)
	_style_locked_card.set_corner_radius_all(6)

	_style_unlocked_pill = StyleBoxFlat.new()
	_style_unlocked_pill.bg_color = Color(0.18, 0.44, 0.24, 1.0)
	_style_unlocked_pill.set_border_width_all(1)
	_style_unlocked_pill.border_color = Color(0.55, 0.94, 0.62, 1.0)
	_style_unlocked_pill.set_corner_radius_all(4)
	_style_unlocked_pill.content_margin_left = 6
	_style_unlocked_pill.content_margin_right = 6
	_style_unlocked_pill.content_margin_top = 2
	_style_unlocked_pill.content_margin_bottom = 2

	_style_locked_pill = StyleBoxFlat.new()
	_style_locked_pill.bg_color = Color(0.22, 0.24, 0.21, 1.0)
	_style_locked_pill.set_border_width_all(1)
	_style_locked_pill.border_color = Color(0.45, 0.48, 0.42, 0.9)
	_style_locked_pill.set_corner_radius_all(4)
	_style_locked_pill.content_margin_left = 6
	_style_locked_pill.content_margin_right = 6
	_style_locked_pill.content_margin_top = 2
	_style_locked_pill.content_margin_bottom = 2

	_style_icon_box = StyleBoxFlat.new()
	_style_icon_box.bg_color = Color(0.1, 0.12, 0.09, 0.98)
	_style_icon_box.set_border_width_all(1)
	_style_icon_box.border_color = Color(0.38, 0.44, 0.34, 0.9)
	_style_icon_box.set_corner_radius_all(5)


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		close_achievements()
		get_viewport().set_input_as_handled()


func open_achievements() -> void:
	var am := get_node_or_null("/root/AudioManager")
	if am != null:
		am.play_sfx("ui_confirm")
	_refresh_list()
	visible = true


func close_achievements() -> void:
	var am := get_node_or_null("/root/AudioManager")
	if am != null:
		am.play_sfx("ui_confirm")
	visible = false
	closed.emit()


func _refresh_list() -> void:
	if grid == null:
		return
	for ch in grid.get_children():
		grid.remove_child(ch)
		ch.queue_free()

	var unlocked_list: Array[String] = GameManager.get_all_unlocked_achievements()
	var defs: Array[Dictionary] = GameManager.ACHIEVEMENT_DEFS
	var unlocked_count: int = 0

	for def: Dictionary in defs:
		var aid: String = str(def.get("id", ""))
		var is_unlocked: bool = aid in unlocked_list
		if is_unlocked:
			unlocked_count += 1
		grid.add_child(_build_card(def, is_unlocked))

	if count_label != null:
		count_label.text = "Terbuka: %d / %d" % [unlocked_count, defs.size()]
	if footer_label != null:
		if unlocked_count >= defs.size():
			footer_label.text = "Selamat! Seluruh pencapaian SQL Vault telah terbuka!"
			footer_label.add_theme_color_override("font_color", Color(0.62, 0.96, 0.65, 1.0))
		else:
			footer_label.text = "Pencapaian otomatis terbuka saat menyelesaikan misi SQL, kotak kayu, dan ruang rahasia."
			footer_label.add_theme_color_override("font_color", Color(0.84, 0.88, 0.8, 1.0))


func _build_card(def: Dictionary, is_unlocked: bool) -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(340, 82)
	card.add_theme_stylebox_override("panel", _style_unlocked_card if is_unlocked else _style_locked_card)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	card.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	margin.add_child(row)

	var icon_box := PanelContainer.new()
	icon_box.custom_minimum_size = Vector2(44, 44)
	icon_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon_box.add_theme_stylebox_override("panel", _style_icon_box)
	row.add_child(icon_box)

	var icon := TextureRect.new()
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.custom_minimum_size = Vector2(28, 28)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var ic_key: String = str(def.get("icon", "coin"))
	var at := AtlasTexture.new()
	at.atlas = ITEMS_TEX
	at.region = ICON_RECTS.get(ic_key, Rect2(32, 0, 16, 16))
	icon.texture = at
	icon.modulate = Color(1, 1, 1, 1) if is_unlocked else Color(0.45, 0.48, 0.45, 0.65)
	icon_box.add_child(icon)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 3)
	row.add_child(info)

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 6)
	info.add_child(top_row)

	var title_lbl := Label.new()
	title_lbl.text = str(def.get("title", "Achievement"))
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.add_theme_font_size_override("font_size", 13)
	title_lbl.add_theme_color_override("font_color", Color(0.99, 0.9, 0.54, 1) if is_unlocked else Color(0.68, 0.72, 0.66, 1))
	top_row.add_child(title_lbl)

	var badge := PanelContainer.new()
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge.add_theme_stylebox_override("panel", _style_unlocked_pill if is_unlocked else _style_locked_pill)
	top_row.add_child(badge)

	var badge_lbl := Label.new()
	badge_lbl.text = "TERBUKA" if is_unlocked else "TERKUNCI"
	badge_lbl.add_theme_font_size_override("font_size", 10)
	badge_lbl.add_theme_color_override("font_color", Color(0.84, 1, 0.88, 1) if is_unlocked else Color(0.7, 0.72, 0.68, 1))
	badge.add_child(badge_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = str(def.get("desc", ""))
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_font_size_override("font_size", 11)
	desc_lbl.add_theme_color_override("font_color", Color(0.86, 0.9, 0.82, 1) if is_unlocked else Color(0.56, 0.6, 0.54, 1))
	info.add_child(desc_lbl)

	return card
