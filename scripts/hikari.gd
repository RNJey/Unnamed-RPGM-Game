extends Node2D

@export var speaker_name: String = "HIKARI THE ADVENTURER"
@export var dialogue_lines: Array[String] = [
	"Wahhh, akhirnya ketemu traveler lain juga! Kirain aku bakal sendirian terus di dalam sini!",
	"Eh, tunggu... kamu beneran sampai ke ruangan tersembunyi ini? Keren banget!",
	"Jujur aja, aku sebenarnya salah satu pembuat dunia ini yang lagi iseng mampir. Semangat terus ya jalanin petualangannya!"
]
@export var dialogue_box_path: NodePath

@onready var interact_area: Area2D = $InteractArea

var _player_in_range: bool = false
var _dialogue_box: Control = null

func _ready() -> void:
	if not dialogue_box_path.is_empty():
		_dialogue_box = get_node_or_null(dialogue_box_path)
	if not _dialogue_box:
		_dialogue_box = get_tree().get_first_node_in_group("dialogue_box")

	if interact_area:
		interact_area.body_entered.connect(_on_body_entered)
		interact_area.body_exited.connect(_on_body_exited)

func _unhandled_input(event: InputEvent) -> void:
	if not _dialogue_box:
		return

	var pressed_e: bool = event.is_action_pressed("interact")
	if not pressed_e:
		return

	# Jika dialog sedang terbuka, tekan E untuk lanjut / tutup
	if _dialogue_box.has_method("is_active") and _dialogue_box.is_active():
		_dialogue_box.advance_or_close()
		get_viewport().set_input_as_handled()
		return

	# Jika belum terbuka dan Player ada di dalam area NPC, mulai dialog
	if _player_in_range:
		_dialogue_box.start_dialogue(speaker_name, dialogue_lines)
		get_viewport().set_input_as_handled()

func _on_body_entered(body: Node) -> void:
	if body.name == "Player" or body.is_in_group("player"):
		_player_in_range = true

func _on_body_exited(body: Node) -> void:
	if body.name == "Player" or body.is_in_group("player"):
		_player_in_range = false
