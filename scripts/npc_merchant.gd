extends Area2D
## Merchant NPC interactable. Press E to open ShopUI.

const COLOR_PROMPT := Color(1.0, 0.88, 0.38, 1.0)
const FRAME_REGIONS: Array[Rect2] = [
	Rect2(0, 24, 32, 40),
	Rect2(32, 24, 32, 40),
	Rect2(64, 24, 32, 40),
]

@export var proximity_text: String = "[E] BUKA TOKO"
@export var is_secret_trader: bool = false

var _player: Node2D = null
var _anim_timer: float = 0.0
var _frame_idx: int = 0

@onready var sprite: Sprite2D = $Sprite2D
@onready var status_label: Label = get_node_or_null("Status")


func _ready() -> void:
	if sprite != null:
		sprite.region_enabled = true
		sprite.region_rect = FRAME_REGIONS[0]
	if status_label != null:
		status_label.visible = false
		status_label.text = proximity_text
		status_label.add_theme_color_override("font_color", COLOR_PROMPT)


func _process(delta: float) -> void:
	if sprite == null:
		return
	_anim_timer += delta
	if _anim_timer >= 0.22:
		_anim_timer = 0.0
		_frame_idx = (_frame_idx + 1) % FRAME_REGIONS.size()
		sprite.region_rect = FRAME_REGIONS[_frame_idx]


func prompt_text() -> String:
	return proximity_text


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
		status_label.text = prompt_text()
		status_label.add_theme_color_override("font_color", COLOR_PROMPT)


func interact(_by: Node) -> void:
	var ui := _find_shop_ui()
	if ui != null and ui.has_method("open_shop"):
		ui.open_shop(is_secret_trader)


func _find_shop_ui() -> Node:
	var root := get_tree().current_scene
	if root == null and get_parent() != null:
		root = get_parent().get_parent()
	if root == null:
		return null
	return root.get_node_or_null("CanvasLayer/ShopUI")
