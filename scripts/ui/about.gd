extends Control
## About / credits screen: development team, practicum assistant, lecturer, engine and asset credits.
## Opened from the main menu (TENTANG); KEMBALI or Esc returns to it.

@onready var back_btn: Button = $Margin/VBox/FooterRow/BackBtn


func _ready() -> void:
	if get_tree() != null:
		get_tree().paused = false
	back_btn.pressed.connect(_on_back_pressed)
	var am := get_node_or_null("/root/AudioManager")
	if am != null:
		am.play_dungeon_bgm(1)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()
		get_viewport().set_input_as_handled()


func _on_back_pressed() -> void:
	var am := get_node_or_null("/root/AudioManager")
	if am != null:
		am.play_sfx("ui_confirm")
	get_tree().change_scene_to_file.call_deferred("res://scenes/ui/main_menu.tscn")
