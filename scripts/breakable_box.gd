extends StaticBody2D
## Breakable box. Child "Hurtbox" (Area2D) receives the sword hit.

@export var min_coins: int = 2
@export var max_coins: int = 5

var _destroyed: bool = false

@onready var body_shape: CollisionShape2D = $CollisionShape2D
@onready var hurtbox_shape: CollisionShape2D = $Hurtbox/CollisionShape2D
@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	if GameManager.is_box_destroyed(_box_id()):
		visible = false
		body_shape.set_deferred("disabled", true)
		hurtbox_shape.set_deferred("disabled", true)
		queue_free()


func _box_id() -> String:
	var scene_key := owner.scene_file_path if owner != null else ""
	if scene_key.is_empty() and get_tree() and get_tree().current_scene:
		scene_key = get_tree().current_scene.scene_file_path
	if scene_key.is_empty() and get_parent() and get_parent().get_parent():
		scene_key = get_parent().get_parent().name
	return "%s:%s" % [scene_key, name]


func take_hit(_damage: int) -> void:
	destroy_box()


func destroy_box() -> void:
	if _destroyed:
		return
	_destroyed = true
	body_shape.set_deferred("disabled", true)
	hurtbox_shape.set_deferred("disabled", true)

	var am := get_node_or_null("/root/AudioManager")
	if am != null:
		am.play_sfx("box_hit")

	GameManager.add_coins(randi_range(min_coins, max_coins))
	GameManager.register_box_destroyed(_box_id())

	# Placeholder "break" effect. Swap for an AnimationPlayer / AnimatedSprite2D later.
	var tween := create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, 0.2)
	await tween.finished
	queue_free()
