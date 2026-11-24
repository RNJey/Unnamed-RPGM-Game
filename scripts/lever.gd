extends Area2D
## Lever. Player presses E in front of it -> GameManager.pull_lever(floor_num, _lever_id()).

const COLOR_PROMPT := Color(1.0, 0.88, 0.4)
const COLOR_ACTIVE := Color(0.2, 0.83, 0.6)
const COLOR_LOCKED := Color(1.0, 0.45, 0.55)

@export var floor_num: int = 1
@export var pulled_texture: Texture2D # optional: green lever sprite
@export var proximity_text: String = "[E] TARIK TUAS"

var is_pulled: bool = false
var _player: Node2D = null

@onready var sprite: Sprite2D = $Sprite2D
@onready var status_label: Label = get_node_or_null("Status")


func _ready() -> void:
	var needed := GameManager.levers_needed(floor_num)
	var all_floor_levers_done := needed > 0 and int(GameManager.levers_pulled.get(floor_num, 0)) >= needed
	if GameManager.is_lever_pulled(_lever_id()) or all_floor_levers_done:
		is_pulled = true
		_apply_pulled_visual()
	GameManager.terminal_solved.connect(_on_terminal_solved)
	if status_label != null:
		status_label.visible = false
		_refresh_label()


func _on_terminal_solved(solved_id: String) -> void:
	if solved_id == _lever_id():
		_refresh_label()


func _lever_id() -> String:
	return "%d:%s" % [floor_num, name]


func _apply_pulled_visual() -> void:
	if pulled_texture:
		sprite.texture = pulled_texture
	else:
		sprite.modulate = Color.GREEN # placeholder until the art is ready


func prompt_text() -> String:
	if is_pulled:
		return "TUAS AKTIF"
	if not GameManager.is_terminal_solved(_lever_id()):
		return "SELESAIKAN SOAL DAHULU"
	return proximity_text


func _refresh_label() -> void:
	if status_label == null:
		return
	status_label.text = prompt_text()
	var col := COLOR_ACTIVE if is_pulled else (COLOR_PROMPT if GameManager.is_terminal_solved(_lever_id()) else COLOR_LOCKED)
	status_label.add_theme_color_override("font_color", col)


func _physics_process(_delta: float) -> void:
	if status_label == null:
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
		if _player == null:
			return
	var near := false
	var ia = _player.get("interaction_area")
	if ia != null:
		near = ia.get_overlapping_areas().has(self)
	if near == status_label.visible:
		return
	status_label.visible = near
	if near:
		_refresh_label()


func interact(_by: Node) -> void:
	if is_pulled:
		return
	if not GameManager.is_terminal_solved(_lever_id()):
		_refresh_label()
		if status_label != null:
			status_label.visible = true
		return
	is_pulled = true
	_apply_pulled_visual()
	_refresh_label()
	GameManager.pull_lever(floor_num, _lever_id())
