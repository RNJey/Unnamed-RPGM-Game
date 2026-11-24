extends Area2D
## Interactive Story / Cutscene NPC (Hikari, King Jey, Mikael).
## Shows crisp proximity prompt on Player InteractionArea overlap and opens NPCDialogueModal.
## On Floor 5 (Mikael), auto_trigger_cutscene starts the congratulatory cutscene once as Player approaches.

const COLOR_REWARD := Color(0.98, 0.9, 0.42, 1.0)
const COLOR_DONE := Color(0.62, 0.95, 1.0, 1.0)

@export var npc_id: String = "hikari"
@export var auto_trigger_cutscene: bool = false
@export var auto_trigger_radius: float = 95.0

var _player: Node2D = null
var _auto_triggered: bool = false

@onready var status_label: Label = get_node_or_null("Status")


func _ready() -> void:
	var gm := _gm()
	if gm != null and gm.has_signal("npc_reward_claimed"):
		gm.npc_reward_claimed.connect(_on_reward_claimed)
	if status_label != null:
		status_label.visible = false
		_refresh_label()


func _gm() -> Node:
	return get_node_or_null("/root/GameManager")


func _on_reward_claimed(claimed_id: String) -> void:
	if claimed_id == npc_id:
		_refresh_label()


func prompt_text() -> String:
	var gm := _gm()
	var claimed: bool = bool(gm != null and gm.has_method("is_npc_reward_claimed") and gm.is_npc_reward_claimed(npc_id))
	return "[E] BICARA" if claimed else "[E] BICARA (+HADIAH)"


func _refresh_label() -> void:
	if status_label == null:
		return
	var gm := _gm()
	var claimed: bool = bool(gm != null and gm.has_method("is_npc_reward_claimed") and gm.is_npc_reward_claimed(npc_id))
	status_label.text = prompt_text()
	status_label.add_theme_color_override("font_color", COLOR_DONE if claimed else COLOR_REWARD)


func _physics_process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
		if _player == null:
			return

	var gm := _gm()
	if auto_trigger_cutscene and not _auto_triggered:
		if get_tree() != null and not get_tree().paused:
			var already_claimed: bool = bool(gm != null and gm.has_method("is_npc_reward_claimed") and gm.is_npc_reward_claimed(npc_id))
			var dlg_open: bool = bool(gm != null and gm.has_method("is_dialogue_open") and gm.is_dialogue_open())
			if not already_claimed and not dlg_open and _player.global_position.distance_to(global_position) <= auto_trigger_radius:
				_auto_triggered = true
				interact(_player)
				return

	if status_label == null:
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
	var gm := _gm()
	if gm != null and gm.has_method("open_npc_dialogue"):
		gm.open_npc_dialogue(npc_id, self)
