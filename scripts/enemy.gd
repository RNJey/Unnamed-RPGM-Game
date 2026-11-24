extends CharacterBody2D
## Base enemy controller: patrols around spawn, chases player within field of vision,
## attacks with an explicit cooldown, stuns/knocks back on hit, and receives sword hits on Hurtbox (layer 16).

@export var max_hp: int = 2
@export var patrol_speed: float = 26.0
@export var chase_speed: float = 45.0
@export var patrol_radius: float = 42.0
@export var vision_range: float = 128.0
@export var vision_fov_deg: float = 140.0
@export var close_sense_range: float = 40.0
@export var attack_range: float = 18.0
@export var attack_damage: int = 10
@export var attack_cooldown: float = 1.5
@export var coin_reward: int = 4

var hp: int = 2
var _spawn_pos: Vector2 = Vector2.ZERO
var _facing: Vector2 = Vector2.DOWN
var _patrol_idx: int = 0
var _patrol_dir: Vector2 = Vector2.RIGHT
var _patrol_pause: float = 0.0
var _patrol_leg_timer: float = 0.0
var _patrol_initialized: bool = false
var _last_pos: Vector2 = Vector2.ZERO
var _stuck_timer: float = 0.0
var _aggro_timer: float = 0.0
var _attack_cd_timer: float = 0.0
var _hit_stun_timer: float = 0.0
var _chasing: bool = false
var _dead: bool = false
var _player: Node2D = null

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var body_shape: CollisionShape2D = $CollisionShape2D
@onready var hurtbox_shape: CollisionShape2D = $Hurtbox/CollisionShape2D


func _ready() -> void:
	hp = max_hp
	_spawn_pos = global_position
	_last_pos = global_position


func is_chasing() -> bool:
	return _chasing


func _physics_process(delta: float) -> void:
	if _dead:
		return
	if not _patrol_initialized:
		_patrol_initialized = true
		_pick_open_patrol_dir(false)
	if _attack_cd_timer > 0.0:
		_attack_cd_timer = maxf(0.0, _attack_cd_timer - delta)
	if _hit_stun_timer > 0.0:
		_hit_stun_timer = maxf(0.0, _hit_stun_timer - delta)
		velocity = Vector2.ZERO
		move_and_slide()
		_last_pos = global_position
		_update_walk_anim()
		return

	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D

	if _player != null and _can_see_player():
		_chasing = true
		_aggro_timer = 1.25
	elif _chasing:
		_aggro_timer -= delta
		if _aggro_timer <= 0.0 or _player == null or global_position.distance_to(_player.global_position) > vision_range * 1.45:
			_chasing = false
			_patrol_leg_timer = 0.0
			_pick_open_patrol_dir(false)

	if _chasing and _player != null:
		_do_chase()
	else:
		_do_patrol(delta)

	var intended_patrol_move := (not _chasing) and velocity.length_squared() > 1.0
	var pre_pos := global_position
	move_and_slide()

	if intended_patrol_move:
		var moved_dist := global_position.distance_to(pre_pos)
		if is_on_wall() or moved_dist < patrol_speed * delta * 0.35:
			_stuck_timer += delta
			if is_on_wall() or _stuck_timer >= 0.18:
				_stuck_timer = 0.0
				_patrol_pause = 0.0
				_pick_open_patrol_dir(true)
		else:
			_stuck_timer = 0.0
	else:
		_stuck_timer = 0.0

	_last_pos = global_position
	_update_walk_anim()


func _can_see_player() -> bool:
	if _player == null or GameManager.hp <= 0:
		return false
	var to_p: Vector2 = _player.global_position - global_position
	var dist: float = to_p.length()
	if dist > vision_range or dist < 0.001:
		return false
	var dir: Vector2 = to_p / dist
	if dist > close_sense_range:
		var cos_half: float = cos(deg_to_rad(vision_fov_deg * 0.5))
		if _facing.dot(dir) < cos_half:
			return false
	var space := get_world_2d().direct_space_state
	if space == null:
		return true
	var params := PhysicsRayQueryParameters2D.create(global_position, _player.global_position, 1)
	params.exclude = [get_rid(), _player.get_rid()]
	params.collide_with_bodies = true
	params.collide_with_areas = false
	return space.intersect_ray(params).is_empty()


func _do_chase() -> void:
	var to_p: Vector2 = _player.global_position - global_position
	var dist: float = to_p.length()
	if dist <= 0.001:
		velocity = Vector2.ZERO
		return
	var dir: Vector2 = to_p / dist
	_facing = _cardinal_dir(dir)
	if dist <= attack_range:
		velocity = Vector2.ZERO
		if _attack_cd_timer <= 0.0:
			_attack_cd_timer = attack_cooldown
			GameManager.take_enemy_damage(attack_damage, dir * 10.0)
	elif _attack_cd_timer > 0.0 and dist <= attack_range * 1.4:
		velocity = Vector2.ZERO
	else:
		velocity = dir * chase_speed


func _do_patrol(delta: float) -> void:
	if _patrol_pause > 0.0:
		_patrol_pause -= delta
		velocity = Vector2.ZERO
		if _patrol_pause <= 0.0:
			_pick_open_patrol_dir(false)
		return

	if test_move(global_transform, _patrol_dir * 4.0):
		_pick_open_patrol_dir(true)
	elif _patrol_leg_timer <= 0.0:
		_advance_patrol_target()
		return

	# Pull back gently toward spawn area if patrol drifted beyond patrol_radius.
	if global_position.distance_to(_spawn_pos) > patrol_radius * 1.45:
		var back_dir := (_spawn_pos - global_position).normalized()
		if back_dir.dot(_patrol_dir) < 0.25:
			_pick_open_patrol_dir(false)

	_patrol_leg_timer -= delta
	_facing = _cardinal_dir(_patrol_dir)
	velocity = _patrol_dir * patrol_speed


func _advance_patrol_target() -> void:
	_patrol_idx = (_patrol_idx + 1) % 4
	_patrol_pause = 0.35
	velocity = Vector2.ZERO


func _ray_clear_distance(dir: Vector2, max_dist: float = 48.0) -> float:
	if test_move(global_transform, dir * 4.0):
		return 0.0
	var world := get_world_2d()
	if world == null or world.direct_space_state == null:
		return max_dist
	var space := world.direct_space_state
	var perp := Vector2(-dir.y, dir.x) * 5.0
	var best_clear: float = max_dist
	var offsets: Array[Vector2] = [Vector2.ZERO, perp, -perp]
	for side: Vector2 in offsets:
		var origin: Vector2 = global_position + side
		var params := PhysicsRayQueryParameters2D.create(origin, origin + dir * max_dist, 1)
		params.exclude = [get_rid()]
		params.collide_with_bodies = true
		params.collide_with_areas = false
		var hit := space.intersect_ray(params)
		if not hit.is_empty():
			var d: float = origin.distance_to(hit["position"])
			if d < best_clear:
				best_clear = d
	return best_clear


func _pick_open_patrol_dir(escaping_wall: bool) -> void:
	var cardinals: Array[Vector2] = [
		Vector2.RIGHT,
		Vector2.DOWN,
		Vector2.LEFT,
		Vector2.UP,
	]
	var diagonals: Array[Vector2] = [
		Vector2(1.0, 1.0).normalized(),
		Vector2(-1.0, 1.0).normalized(),
		Vector2(-1.0, -1.0).normalized(),
		Vector2(1.0, -1.0).normalized(),
	]
	var candidates: Array[Vector2] = []
	for i in cardinals.size():
		candidates.append(cardinals[(i + _patrol_idx) % cardinals.size()])
	candidates.append_array(diagonals)

	var dist_from_spawn := global_position.distance_to(_spawn_pos)
	var to_spawn := (_spawn_pos - global_position).normalized() if dist_from_spawn > 1.0 else Vector2.ZERO
	var prev_dir := _patrol_dir

	var best_dir := cardinals[_patrol_idx % cardinals.size()]
	var best_score := -1e9
	for idx in candidates.size():
		var d: Vector2 = candidates[idx]
		var clear_d := _ray_clear_distance(d, 56.0)
		var score := clear_d
		if clear_d < 16.0:
			score -= 100.0
		if escaping_wall and d.dot(prev_dir) > 0.7:
			score -= 80.0
		elif not escaping_wall and d.dot(-prev_dir) > 0.8 and clear_d >= 20.0:
			# Avoid oscillating 180 degrees immediately unless forced by walls.
			score -= 18.0
		if dist_from_spawn > patrol_radius * 1.25 and to_spawn.length_squared() > 0.01:
			score += to_spawn.dot(d) * 28.0
		# Prefer cardinal directions slightly when equally clear so sprite animation looks crisp.
		if idx < cardinals.size():
			score += 4.0
		if score > best_score:
			best_score = score
			best_dir = d

	_patrol_dir = best_dir
	_facing = _cardinal_dir(best_dir)
	_patrol_leg_timer = clampf(_ray_clear_distance(best_dir, 48.0) / maxf(1.0, patrol_speed), 0.75, 1.65)
	_patrol_idx = (_patrol_idx + 1) % 4


func _cardinal_dir(v: Vector2) -> Vector2:
	if absf(v.x) > absf(v.y):
		return Vector2.RIGHT if v.x >= 0.0 else Vector2.LEFT
	return Vector2.DOWN if v.y >= 0.0 else Vector2.UP


func _update_walk_anim() -> void:
	if sprite == null:
		return
	var clip: String = "walk_down"
	if absf(_facing.x) > absf(_facing.y):
		clip = "walk_right" if _facing.x > 0.0 else "walk_left"
	elif _facing.y < 0.0:
		clip = "walk_up"
	if sprite.animation != StringName(clip):
		sprite.play(clip)
	elif velocity.length_squared() < 1.0:
		sprite.pause()
	elif not sprite.is_playing():
		sprite.play(clip)


func take_hit(damage: int) -> void:
	if _dead:
		return
	hp -= maxi(1, damage)
	var am := get_node_or_null("/root/AudioManager")
	if am != null:
		am.play_sfx("guard_hit")
	if hp <= 0:
		_die()
		return
	_hit_stun_timer = 0.38
	_attack_cd_timer = maxf(_attack_cd_timer, 0.65)
	if _player != null and is_instance_valid(_player):
		var away: Vector2 = (global_position - _player.global_position).normalized()
		if away.length_squared() > 0.01:
			move_and_collide(away * 14.0)
	if sprite != null:
		sprite.modulate = Color(1.0, 0.38, 0.38, 1.0)
		var tw := create_tween()
		tw.tween_property(sprite, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.18)


func _die() -> void:
	_dead = true
	velocity = Vector2.ZERO
	if body_shape != null:
		body_shape.set_deferred("disabled", true)
	if hurtbox_shape != null:
		hurtbox_shape.set_deferred("disabled", true)
	GameManager.add_coins(coin_reward)
	if sprite != null:
		var tw := create_tween()
		tw.tween_property(sprite, "modulate:a", 0.0, 0.18)
		await tw.finished
	queue_free()
