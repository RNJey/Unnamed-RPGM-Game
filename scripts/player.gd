extends CharacterBody2D
## Top-down player: 4-direction movement, sword attack, and interaction.

const BASE_SPEED: float = 120.0
const BOOTS_SPEED: float = 170.0 # ~ +40%
const ATTACK_DURATION: float = 0.2
const UPGRADED_ATTACK_DURATION: float = 0.14 # ASSUMPTION: upgraded sword swings faster
const SWORD_OFFSET: float = 16.0
const INTERACT_OFFSET: float = 20.0

var last_facing_direction: Vector2 = Vector2.DOWN
var is_attacking: bool = false
var _hit_this_swing: Array[Node] = []

@onready var sword_hitbox: Area2D = $SwordHitbox
@onready var sword_shape: CollisionShape2D = $SwordHitbox/CollisionShape2D
@onready var interaction_area: Area2D = $InteractionArea


func _ready() -> void:
	add_to_group("player")
	sword_shape.disabled = true
	sword_hitbox.area_entered.connect(_on_sword_hit)
	_update_aim_nodes()


func _physics_process(_delta: float) -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = input_dir * _get_speed()
	move_and_slide()
	if input_dir != Vector2.ZERO:
		_update_facing(input_dir)


# _unhandled_input means UI buttons (Bengkel Query, Shop) swallow clicks first.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("attack") and not is_attacking:
		_attack()
	elif event.is_action_pressed("interact"):
		_try_interact()


# ---------- Movement ----------
func _get_speed() -> float:
	return BOOTS_SPEED if GameManager.has_speed_boots else BASE_SPEED


## Snap facing to 4 directions so the sword and interaction sensor stay aligned.
func _update_facing(dir: Vector2) -> void:
	if absf(dir.x) > absf(dir.y):
		last_facing_direction = Vector2(signf(dir.x), 0.0)
	else:
		last_facing_direction = Vector2(0.0, signf(dir.y))
	_update_aim_nodes()


func _update_aim_nodes() -> void:
	sword_hitbox.position = last_facing_direction * SWORD_OFFSET
	sword_hitbox.rotation = last_facing_direction.angle()
	interaction_area.position = last_facing_direction * INTERACT_OFFSET


# ---------- Combat ----------
func _get_sword_damage() -> int:
	return 3 if GameManager.sword_upgraded else 1


func _attack() -> void:
	is_attacking = true
	_hit_this_swing.clear()
	_update_aim_nodes()
	sword_shape.set_deferred("disabled", false)
	var duration := UPGRADED_ATTACK_DURATION if GameManager.sword_upgraded else ATTACK_DURATION
	await get_tree().create_timer(duration).timeout
	sword_shape.set_deferred("disabled", true)
	is_attacking = false


## Any Hurtbox (Area2D) whose parent has take_hit(damage) can be hit: boxes, guards, boss.
func _on_sword_hit(area: Area2D) -> void:
	var target: Node = area.get_parent()
	if target in _hit_this_swing:
		return
	if target.has_method("take_hit"):
		_hit_this_swing.append(target)
		target.take_hit(_get_sword_damage())


# ---------- Interaction ----------
## Anything in the InteractionArea that has interact(player) gets called.
## Lever, SQLTerminal, NPCMerchant, SecretDoor, LoreObject each implement it themselves.
func _try_interact() -> void:
	for area in interaction_area.get_overlapping_areas():
		if area.has_method("interact"):
			area.interact(self)
			return
