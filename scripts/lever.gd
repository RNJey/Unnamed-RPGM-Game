extends Area2D
## Lever. Player presses E in front of it -> GameManager.pull_lever(floor_num).

@export var floor_num: int = 1
@export var pulled_texture: Texture2D # optional: green lever sprite

var is_pulled: bool = false

@onready var sprite: Sprite2D = $Sprite2D


func interact(_player: Node) -> void:
	if is_pulled:
		return
	is_pulled = true
	if pulled_texture:
		sprite.texture = pulled_texture
	else:
		sprite.modulate = Color.GREEN # placeholder until the art is ready
	GameManager.pull_lever(floor_num)
