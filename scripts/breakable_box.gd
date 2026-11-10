extends StaticBody2D
## Breakable box. Child "Hurtbox" (Area2D) receives the sword hit.

@export var min_coins: int = 2
@export var max_coins: int = 5

var _destroyed: bool = false

@onready var body_shape: CollisionShape2D = $CollisionShape2D
@onready var hurtbox_shape: CollisionShape2D = $Hurtbox/CollisionShape2D
@onready var sprite: Sprite2D = $Sprite2D


func take_hit(_damage: int) -> void:
	destroy_box()


func destroy_box() -> void:
	if _destroyed:
		return
	_destroyed = true
	body_shape.set_deferred("disabled", true)
	hurtbox_shape.set_deferred("disabled", true)

	GameManager.add_coins(randi_range(min_coins, max_coins))
	GameManager.register_box_destroyed()

	# Placeholder "break" effect. Swap for an AnimationPlayer / AnimatedSprite2D later.
	var tween := create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, 0.2)
	await tween.finished
	queue_free()
