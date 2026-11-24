extends Area2D
## Main door to the next floor. Player presses E (interact) when open to transition.

const COLOR_OPEN := Color(0.2, 0.83, 0.6)
const COLOR_LOCKED := Color(1.0, 0.45, 0.55)

@export var floor_num: int = 1
@export_file("*.tscn") var next_floor_path: String = ""
@export var starts_open: bool = false
@export var requires_key: bool = false
@export var spawn_offset: Vector2 = Vector2.ZERO
## When set, this door keeps its Status label hidden until the player is close,
## then shows this text instead of a permanent "PINTU TERBUKA".
@export var proximity_text: String = ""
@export var proximity_radius: float = 56.0
@export var block_offset: Vector2 = Vector2(0, -54)
@export var block_size: Vector2 = Vector2(64, 80)

var is_open: bool = false
var _proximity_mode: bool = false
var _player: Node2D = null

@onready var status_label: Label = get_node_or_null("Status")
@onready var interact_shape: CollisionShape2D = get_node_or_null("InteractShape")
@onready var block_shape: CollisionShape2D = $Block/CollisionShape2D


func _ready() -> void:
	if interact_shape != null:
		var dir := Vector2(signf(block_offset.x), 0.0) if absf(block_offset.x) > absf(block_offset.y) else Vector2(0.0, signf(block_offset.y))
		interact_shape.position = dir * 14.0
		var irect := RectangleShape2D.new()
		irect.size = Vector2(32, 32) if absf(dir.x) > 0.0 else Vector2(36, 36)
		interact_shape.shape = irect

	if block_shape != null:
		block_shape.position = block_offset
		var rect := RectangleShape2D.new()
		rect.size = block_size
		block_shape.shape = rect
		block_shape.disabled = false

	GameManager.main_door_unlocked.connect(_on_main_door_unlocked)
	GameManager.lever_pulled.connect(_on_lever_pulled)
	GameManager.inventory_changed.connect(_on_inventory_changed)

	var needed := GameManager.levers_needed(floor_num)
	if starts_open or (needed > 0 and GameManager.levers_pulled.get(floor_num, 0) >= needed):
		open()
	else:
		_refresh_label()

	_proximity_mode = not proximity_text.is_empty()
	if _proximity_mode and status_label != null:
		status_label.text = ""
		status_label.visible = false

	if not GameManager.transition_from_scene.is_empty() and next_floor_path == GameManager.transition_from_scene:
		call_deferred("_place_returning_player")


func _place_returning_player() -> void:
	if GameManager.transition_from_scene.is_empty() or next_floor_path != GameManager.transition_from_scene:
		return
	GameManager.transition_from_scene = ""
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player != null:
		player.global_position = global_position + spawn_offset


func _on_main_door_unlocked(unlocked_floor: int) -> void:
	if unlocked_floor == floor_num:
		open()


func _on_lever_pulled(pulled_floor: int, _total: int) -> void:
	if pulled_floor == floor_num:
		_refresh_label()


func _on_inventory_changed() -> void:
	if _proximity_mode and status_label != null and status_label.visible:
		_update_proximity_prompt()
	elif not _proximity_mode:
		_refresh_label()


func _door_id() -> String:
	var scene_key := owner.scene_file_path if owner != null else ""
	if scene_key.is_empty() and get_tree() and get_tree().current_scene:
		scene_key = get_tree().current_scene.scene_file_path
	if scene_key.is_empty() and get_parent() and get_parent().get_parent():
		scene_key = get_parent().get_parent().name
	return "%s:%s" % [scene_key, name]


func _is_key_locked() -> bool:
	return requires_key and not GameManager.is_secret_door_unlocked(_door_id())


func open() -> void:
	if is_open:
		return
	is_open = true
	_refresh_label()


func _refresh_label() -> void:
	if status_label == null or _proximity_mode:
		return
	if _is_key_locked():
		status_label.text = "[E] BUKA KUNCI" if GameManager.special_keys > 0 else "BUTUH KUNCI"
		status_label.add_theme_color_override("font_color", COLOR_OPEN if GameManager.special_keys > 0 else COLOR_LOCKED)
	elif is_open:
		status_label.text = "PINTU TERBUKA"
		status_label.add_theme_color_override("font_color", COLOR_OPEN)
	else:
		var pulled: int = int(GameManager.levers_pulled.get(floor_num, 0))
		var needed: int = GameManager.levers_needed(floor_num)
		status_label.text = "PINTU %d/%d TUAS" % [pulled, needed]
		status_label.add_theme_color_override("font_color", COLOR_LOCKED)


func prompt_text() -> String:
	if _is_key_locked():
		return "[E] BUKA KUNCI" if GameManager.special_keys > 0 else "BUTUH KUNCI"
	if _proximity_mode:
		return proximity_text
	if not is_open:
		var pulled: int = int(GameManager.levers_pulled.get(floor_num, 0))
		return "TERKUNCI \u2014 %d/%d TUAS" % [pulled, GameManager.levers_needed(floor_num)]
	return "[E] TURUN"


func _update_proximity_prompt() -> void:
	if status_label == null:
		return
	status_label.text = prompt_text()
	var locked_no_key := _is_key_locked() and GameManager.special_keys <= 0
	status_label.add_theme_color_override("font_color", COLOR_LOCKED if locked_no_key else COLOR_OPEN)


func _physics_process(_delta: float) -> void:
	if not _proximity_mode or status_label == null:
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
		if _player == null:
			return
	# Show the prompt exactly when pressing E would work: ask the player's own
	# InteractionArea whether it currently overlaps this door (same test interact uses).
	var near := false
	var ia = _player.get("interaction_area")
	if ia != null:
		near = ia.get_overlapping_areas().has(self)
	else:
		near = _player.global_position.distance_to(global_position) <= proximity_radius
	if near == status_label.visible:
		return
	status_label.visible = near
	if near:
		_update_proximity_prompt()


func interact(_by: Node) -> void:
	var am := get_node_or_null("/root/AudioManager")
	if _is_key_locked():
		if not GameManager.unlock_secret_door(_door_id()):
			if am != null:
				am.play_sfx("query_error")
			if status_label != null:
				status_label.visible = true
				status_label.text = "BUTUH KUNCI"
				status_label.add_theme_color_override("font_color", COLOR_LOCKED)
			return
		if am != null:
			am.play_sfx("door")
	if not is_open:
		if am != null:
			am.play_sfx("query_error")
		_refresh_label()
		return
	if next_floor_path.is_empty():
		push_warning("MainDoor: next_floor_path is empty on floor %d" % floor_num)
		return
	if am != null:
		am.play_sfx("door")
	if get_tree().current_scene != null:
		GameManager.transition_from_scene = get_tree().current_scene.scene_file_path
	GameManager.save_game()
	get_tree().change_scene_to_file.call_deferred(next_floor_path)
