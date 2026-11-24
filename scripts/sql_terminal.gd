extends Area2D
## SQL Terminal crystal interactable. Press E to open BengkelQueryUI and unlock paired lever.

const COLOR_PROMPT := Color(0.62, 0.95, 1.0)
const COLOR_SOLVED := Color(0.2, 0.83, 0.6)

@export var floor_num: int = 1
@export var lever_id: String = ""
@export var solved_texture: Texture2D
@export var proximity_text: String = "[E] BUKA TERMINAL"

var is_solved: bool = false
var _player: Node2D = null

@onready var sprite: Sprite2D = $Sprite2D
@onready var status_label: Label = get_node_or_null("Status")


func _ready() -> void:
	if lever_id.is_empty():
		lever_id = "%d:Lever" % floor_num
	GameManager.terminal_solved.connect(_on_terminal_solved)
	if GameManager.is_terminal_solved(lever_id):
		is_solved = true
		_apply_solved_visual()
	if status_label != null:
		status_label.visible = false
		_refresh_label()


func _on_terminal_solved(solved_id: String) -> void:
	if solved_id == lever_id:
		is_solved = true
		_apply_solved_visual()
		_refresh_label()


func _apply_solved_visual() -> void:
	if solved_texture:
		sprite.texture = solved_texture
	else:
		sprite.modulate = COLOR_SOLVED


func prompt_text() -> String:
	return "TERMINAL SELESAI" if is_solved else proximity_text


func _refresh_label() -> void:
	if status_label == null:
		return
	status_label.text = prompt_text()
	status_label.add_theme_color_override("font_color", COLOR_SOLVED if is_solved else COLOR_PROMPT)


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
	var ui := _find_bengkel_ui()
	if ui != null and ui.has_method("open_for_terminal"):
		ui.open_for_terminal(floor_num, lever_id)


func _find_bengkel_ui() -> Node:
	var root := get_tree().current_scene
	if root == null and get_parent() != null:
		root = get_parent().get_parent()
	if root == null:
		return null
	return root.get_node_or_null("CanvasLayer/BengkelQueryUI")
