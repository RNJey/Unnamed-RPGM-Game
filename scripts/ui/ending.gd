extends CanvasLayer
## Floor 5 Victory / Run Ending screen. Press E or click Restart to begin a fresh run.

@onready var title_label: Label = $Center/Modal/Margin/VBox/HeaderCard/Margin/VBox/TitleLabel
@onready var stats_label: Label = $Center/Modal/Margin/VBox/StatsCard/Margin/StatsLabel
@onready var restart_btn: Button = $Center/Modal/Margin/VBox/ActionRow/RestartBtn
@onready var menu_btn: Button = $Center/Modal/Margin/VBox/ActionRow/MenuBtn


func _ready() -> void:
	if get_tree() != null:
		get_tree().paused = false
	var stats: Dictionary = GameManager.finish_run()
	var total_s: int = int(stats.get("time_s", 0))
	var mins: int = total_s / 60
	var secs: int = total_s % 60
	var waktu_str: String = "%02d:%02d (%ds)" % [mins, secs, total_s]

	title_label.text = "LANTAI 5 SELESAI"
	stats_label.text = (
		"Rank Database   : %s\n" +
		"Total XP        : %d XP\n" +
		"Koin Terkumpul  : %d Koin\n" +
		"Syntax Crystals : %d Kristal\n" +
		"Waktu Selesai   : %s"
	) % [
		str(stats.get("rank", "Trainee")),
		int(stats.get("xp", 0)),
		int(stats.get("coins", 0)),
		int(stats.get("crystals", 0)),
		waktu_str,
	]

	restart_btn.pressed.connect(restart_run)
	menu_btn.pressed.connect(_go_main_menu)
	var am := get_node_or_null("/root/AudioManager")
	if am != null:
		am.play_sfx("achievement")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		restart_run()
		get_viewport().set_input_as_handled()


func restart_run() -> void:
	var am := get_node_or_null("/root/AudioManager")
	if am != null:
		am.play_sfx("ui_confirm")
	GameManager.reset_run()
	if get_tree() != null:
		get_tree().change_scene_to_file.call_deferred("res://scenes/floors/floor_1_dungeon.tscn")


func _go_main_menu() -> void:
	var am := get_node_or_null("/root/AudioManager")
	if am != null:
		am.play_sfx("ui_confirm")
	GameManager.reset_run()
	if get_tree() != null:
		get_tree().change_scene_to_file.call_deferred("res://scenes/ui/main_menu.tscn")
