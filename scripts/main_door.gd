extends StaticBody2D
## Main door to the next floor. Opens when GameManager reports 3 levers on this floor.
## Child "ExitZone" (Area2D) triggers the floor change once the door is open.

@export var floor_num: int = 1
@export_file("*.tscn") var next_floor_path: String = ""

var is_open: bool = false

@onready var body_shape: CollisionShape2D = $CollisionShape2D
@onready var sprite: Sprite2D = $Sprite2D
@onready var exit_zone: Area2D = $ExitZone


func _ready() -> void:
	GameManager.main_door_unlocked.connect(_on_main_door_unlocked)
	exit_zone.body_entered.connect(_on_exit_zone_body_entered)
	# If the levers were already pulled before this scene loaded, start open.
	if GameManager.levers_pulled.get(floor_num, 0) >= GameManager.LEVERS_NEEDED:
		open()


func _on_main_door_unlocked(unlocked_floor: int) -> void:
	if unlocked_floor == floor_num:
		open()


func open() -> void:
	if is_open:
		return
	is_open = true
	body_shape.set_deferred("disabled", true)
	sprite.modulate.a = 0.35 # placeholder "open" look; swap for an open-door animation later


func _on_exit_zone_body_entered(body: Node2D) -> void:
	if not is_open or not body.is_in_group("player"):
		return
	if next_floor_path.is_empty():
		print("MainDoor: next_floor_path not set yet (next floor scene doesn't exist).")
		return
	get_tree().change_scene_to_file(next_floor_path)
