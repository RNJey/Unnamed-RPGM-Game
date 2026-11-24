extends Control
## Game Over overlay triggered by GameManager.player_died.
## Restarts current floor with XP, coins, and solved puzzles kept intact.

@onready var stats_label: Label = $Center/Modal/Margin/VBox/StatsCard/Margin/StatsLabel
@onready var retry_btn: Button = $Center/Modal/Margin/VBox/ActionRow/RetryBtn
@onready var menu_btn: Button = $Center/Modal/Margin/VBox/ActionRow/MenuBtn


func _ready() -> void:
	visible = false
	GameManager.player_died.connect(_on_player_died)
	retry_btn.pressed.connect(retry_floor)
	menu_btn.pressed.connect(_go_menu)


func _exit_tree() -> void:
	if visible and get_tree() != null:
		get_tree().paused = false


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("interact"):
		retry_floor()
		get_viewport().set_input_as_handled()


func _on_player_died() -> void:
	var am := get_node_or_null("/root/AudioManager")
	if am != null:
		am.play_sfx("query_error")
	stats_label.text = "Lantai Saat Ini : Lantai %d\nRank & XP       : %s (%d XP)\nKoin Tersimpan  : %d Koin" % [
		GameManager.current_floor,
		GameManager.rank,
		GameManager.xp,
		GameManager.coins,
	]
	visible = true
	if get_tree() != null:
		get_tree().paused = true


func retry_floor() -> void:
	var am := get_node_or_null("/root/AudioManager")
	if am != null:
		am.play_sfx("ui_confirm")
	GameManager.reset_invulnerability()
	GameManager.hp = GameManager.max_hp
	GameManager.energy = GameManager.max_energy
	visible = false
	if get_tree() != null:
		get_tree().paused = false
		var target: String = GameManager.current_floor_path
		if target.is_empty():
			target = str(GameManager.FLOOR_SCENES_BY_NUM.get(GameManager.current_floor, "res://scenes/floors/floor_1_dungeon.tscn"))
		get_tree().change_scene_to_file.call_deferred(target)


func _go_menu() -> void:
	var am := get_node_or_null("/root/AudioManager")
	if am != null:
		am.play_sfx("ui_confirm")
	GameManager.reset_invulnerability()
	GameManager.hp = GameManager.max_hp
	GameManager.energy = GameManager.max_energy
	GameManager.save_game()
	visible = false
	if get_tree() != null:
		get_tree().paused = false
		get_tree().change_scene_to_file.call_deferred("res://scenes/ui/main_menu.tscn")
