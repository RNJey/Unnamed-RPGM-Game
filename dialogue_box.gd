extends Control

signal dialogue_finished

@onready var speaker_label: Label = $PanelContainer/VBoxContainer/SpeakerLabel
@onready var dialogue_label: RichTextLabel = $PanelContainer/VBoxContainer/DialogueLabel
@onready var hint_label: Label = $PanelContainer/VBoxContainer/HintLabel

var _lines: Array[String] = []
var _index: int = 0
var _is_open: bool = false

func _ready() -> void:
	visible = false
	if hint_label:
		hint_label.text = "[E] Lanjut"

func start_dialogue(speaker: String, lines: Array[String]) -> void:
	if lines.is_empty():
		return
	_lines = lines
	_index = 0
	_is_open = true
	visible = true
	speaker_label.text = speaker
	_show_current_line()

func _show_current_line() -> void:
	dialogue_label.text = _lines[_index]
	if hint_label:
		hint_label.text = "[E] Tutup" if _index == _lines.size() - 1 else "[E] Lanjut"

func advance_or_close() -> void:
	if not _is_open:
		return
	_index += 1
	if _index < _lines.size():
		_show_current_line()
	else:
		close_dialogue()

func close_dialogue() -> void:
	_is_open = false
	visible = false
	_lines.clear()
	_index = 0
	dialogue_finished.emit()

func is_active() -> bool:
	return _is_open
