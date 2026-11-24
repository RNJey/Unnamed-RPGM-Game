extends Node
## Global game state. Register as Autoload with the name "GameManager".

# ---------- Signals (UI and world objects listen to these) ----------
signal hp_changed(hp: int, max_hp: int)
signal coins_changed(coins: int)
signal energy_changed(energy: int, max_energy: int)
signal xp_changed(xp: int, rank: String)
signal lever_pulled(floor_num: int, total: int)
signal main_door_unlocked(floor_num: int)
signal terminal_solved(lever_id: String)
signal inventory_changed
signal npc_reward_claimed(npc_id: String)
signal achievement_unlocked(id: String)
signal run_completed(stats: Dictionary)
signal player_died

# ---------- Constants ----------
const INVULN_DURATION_MS: int = 1000
const SAVE_PATH: String = "user://save.cfg"
const FLOOR_SCENES_BY_NUM := {
	1: "res://scenes/floors/floor_1_dungeon.tscn",
	2: "res://scenes/floors/floor_2_dungeon.tscn",
	3: "res://scenes/floors/floor_3_catacomb.tscn",
	4: "res://scenes/floors/floor_4_catacomb.tscn",
	5: "res://scenes/floors/floor_5_ground.tscn",
}
const LEVERS_NEEDED_BY_FLOOR := {1: 2, 2: 3, 3: 3, 4: 3, 5: 0}
const CRYSTALS_PER_UPGRADE: int = 3
const SECRET_CRYSTALS_PER_UPGRADE: int = 2
const CRYSTALS_PER_HP: int = 3
const DEFAULT_MAX_HP: int = 100
const CRYSTAL_UPGRADE_MAX_HP: int = 10
const CRYSTAL_UPGRADE_MAX_ENERGY: int = 2
const HP_RESTORE_PER_EXCHANGE: int = 30
const POTION_HEAL_AMOUNT: int = 35
const BOX_BREAKER_TARGET: int = 5
const BONUS_ENERGY_PER_RANK: int = 2 # ASSUMPTION: spec only says rank raises max_energy
const RANKS := [ # ASSUMPTION: XP thresholds are placeholders, tune with the designer
	{"name": "Trainee", "xp": 0},
	{"name": "Junior", "xp": 100},
	{"name": "Senior", "xp": 300},
	{"name": "DBA", "xp": 600},
]
const ACHIEVEMENT_DEFS: Array[Dictionary] = [
	{
		"id": "first_query",
		"title": "Hello Database!",
		"desc": "Selesaikan terminal SQL pertamamu di dalam dungeon.",
		"category": "DASAR",
		"icon": "tablet",
	},
	{
		"id": "ddl_architect",
		"title": "Arsitek Skema (DDL)",
		"desc": "Selesaikan seluruh misi CREATE & ALTER TABLE di Lantai 1.",
		"category": "LANTAI 1",
		"icon": "diamond",
	},
	{
		"id": "dml_operator",
		"title": "Operator Data (DML)",
		"desc": "Selesaikan seluruh misi INSERT, UPDATE & DELETE di Lantai 2.",
		"category": "LANTAI 2",
		"icon": "emerald",
	},
	{
		"id": "query_detective",
		"title": "Detektif Query (SELECT)",
		"desc": "Selesaikan seluruh misi SELECT, WHERE & ORDER BY di Lantai 3.",
		"category": "LANTAI 3",
		"icon": "hint",
	},
	{
		"id": "dcl_guardian",
		"title": "Penjaga Otorisasi (DCL)",
		"desc": "Selesaikan seluruh misi GRANT & REVOKE di Lantai 4.",
		"category": "LANTAI 4",
		"icon": "ruby",
	},
	{
		"id": "secret_explorer",
		"title": "Penjelajah Rahasia",
		"desc": "Buka pintu ruang rahasia menggunakan Kunci Ruang Rahasia.",
		"category": "EKSPLORASI",
		"icon": "key",
	},
	{
		"id": "box_breaker",
		"title": "Penghancur Kotak",
		"desc": "Hancurkan 5 kotak kayu di dalam dungeon.",
		"category": "AKSI",
		"icon": "sword",
	},
	{
		"id": "vault_master",
		"title": "Master SQL Vault",
		"desc": "Capai pintu keluar Lantai 5 dan selesaikan petualangan.",
		"category": "TAMAT",
		"icon": "coin",
	},
]

# ---------- Core stats (setters emit signals automatically) ----------
var max_hp: int = 100
var hp: int = 100:
	set(value):
		hp = clampi(value, 0, max_hp)
		hp_changed.emit(hp, max_hp)

var coins: int = 0:
	set(value):
		coins = maxi(value, 0)
		coins_changed.emit(coins)

var max_energy: int = 10
var energy: int = 10:
	set(value):
		energy = clampi(value, 0, max_energy)
		energy_changed.emit(energy, max_energy)

var xp: int = 0
var rank: String = "Trainee"
var _rank_index: int = 0

# ---------- Lever progress per floor ----------
var current_floor: int = 1
var current_floor_path: String = "res://scenes/floors/floor_1_dungeon.tscn"
var highest_floor_unlocked: int = 1
var run_started_at: int = 0
var fullscreen_enabled: bool = false
var levers_pulled: Dictionary = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0}
var pulled_lever_ids: Dictionary = {}
var solved_terminals: Dictionary = {}
var terminal_hints_revealed: Dictionary = {}
var unlocked_secret_doors: Dictionary = {}
var claimed_npc_rewards: Dictionary = {}
var transition_from_scene: String = ""

# ---------- Inventory and equipment ----------
var has_speed_boots: bool = false
var sword_upgraded: bool = false
var secret_hp_amulet_bought: bool = false
var secret_energy_core_bought: bool = false
var special_keys: int = 0
var syntax_crystals: int = 0
var hint_tokens: int = 0
var energy_chips: int = 0
var hp_potions: int = 0
var _invulnerable_until_ms: int = 0

# ---------- Developer Mode & Counters ----------
var dev_mode_enabled: bool = false
var dev_god_mode: bool = false
var dev_noclip: bool = false
var _dev_panel_layer: CanvasLayer = null
var _dialogue_layer: CanvasLayer = null

var unlocked_achievements: Array[String] = []
var boxes_destroyed: int = 0
var destroyed_box_ids: Dictionary = {}


# =====================================================================
# Health, coins, energy, XP
# =====================================================================
func take_damage(amount: int = 1) -> void:
	if dev_god_mode:
		return
	hp -= amount
	if hp <= 0:
		player_died.emit()


func reset_invulnerability() -> void:
	_invulnerable_until_ms = 0


func is_player_invulnerable() -> bool:
	return Time.get_ticks_msec() < _invulnerable_until_ms


## Called by enemies on contact/melee hit. Enforces a 1.0s i-frame window and blinks the player.
func take_enemy_damage(amount: int = 1, knockback_vec: Vector2 = Vector2.ZERO) -> bool:
	if dev_god_mode or hp <= 0 or is_player_invulnerable():
		return false
	_invulnerable_until_ms = Time.get_ticks_msec() + INVULN_DURATION_MS
	take_damage(amount)
	if get_tree() != null:
		var player := get_tree().get_first_node_in_group("player") as CharacterBody2D
		if player != null and is_instance_valid(player):
			if knockback_vec.length_squared() > 0.01:
				player.move_and_collide(knockback_vec)
			var tw := player.create_tween()
			for _i in 4:
				tw.tween_property(player, "modulate:a", 0.35, 0.12)
				tw.tween_property(player, "modulate:a", 1.0, 0.12)
	return true


func heal(amount: int = 1) -> void:
	hp += amount


## Consumes one HP Potion from inventory and heals POTION_HEAL_AMOUNT HP.
func use_hp_potion() -> bool:
	if hp_potions <= 0 or hp <= 0 or hp >= max_hp:
		return false
	hp_potions -= 1
	heal(POTION_HEAL_AMOUNT)
	inventory_changed.emit()
	save_game()
	return true


func add_coins(amount: int) -> void:
	coins += amount


func spend_coins(amount: int) -> bool:
	if coins < amount:
		return false
	coins -= amount
	return true


## Called when the player presses RUN in the terminal. Returns false if no energy.
func use_energy() -> bool:
	if dev_god_mode:
		energy = max_energy
		return true
	if energy <= 0:
		return false
	energy -= 1
	return true


## Consumes one Energy Chip and refills energy to full.
func use_energy_chip() -> bool:
	if energy_chips <= 0:
		return false
	energy_chips -= 1
	energy = max_energy
	return true


func add_xp(amount: int) -> void:
	xp += amount
	var new_index := 0
	for i in RANKS.size():
		if xp >= RANKS[i]["xp"]:
			new_index = i
	var ranks_gained := new_index - _rank_index
	if ranks_gained > 0:
		_rank_index = new_index
		rank = str(RANKS[new_index]["name"])
		max_energy += ranks_gained * BONUS_ENERGY_PER_RANK
		energy += ranks_gained * BONUS_ENERGY_PER_RANK
	xp_changed.emit(xp, rank)


# =====================================================================
# Levers and doors
# =====================================================================
func levers_needed(floor_num: int) -> int:
	return int(LEVERS_NEEDED_BY_FLOOR.get(floor_num, 0))


func is_lever_pulled(lever_id: String) -> bool:
	return bool(pulled_lever_ids.get(lever_id, false))


func is_terminal_solved(lever_id: String) -> bool:
	return bool(solved_terminals.get(lever_id, false))


func get_terminal_hints_revealed(lever_id: String) -> int:
	return int(terminal_hints_revealed.get(lever_id, 0))


func reveal_next_terminal_hint(lever_id: String, max_cards: int) -> bool:
	if lever_id.is_empty() or max_cards <= 0:
		return false
	var cur := get_terminal_hints_revealed(lever_id)
	if cur >= max_cards or hint_tokens <= 0:
		return false
	hint_tokens -= 1
	terminal_hints_revealed[lever_id] = cur + 1
	inventory_changed.emit()
	save_game()
	return true


func is_secret_door_unlocked(door_id: String) -> bool:
	return bool(unlocked_secret_doors.get(door_id, false))


func unlock_secret_door(door_id: String) -> bool:
	if not door_id.is_empty() and bool(unlocked_secret_doors.get(door_id, false)):
		return true
	if special_keys <= 0:
		return false
	special_keys -= 1
	if not door_id.is_empty():
		unlocked_secret_doors[door_id] = true
	inventory_changed.emit()
	unlock_achievement("secret_explorer")
	return true


func mark_terminal_solved(lever_id: String, xp_reward: int = 0, crystal_reward: int = 0) -> void:
	if lever_id.is_empty():
		return
	var first_time := not bool(solved_terminals.get(lever_id, false))
	solved_terminals[lever_id] = true
	if first_time:
		if crystal_reward > 0:
			syntax_crystals += crystal_reward
			inventory_changed.emit()
		if xp_reward > 0:
			add_xp(xp_reward)
	# Refill energy when a terminal puzzle is completed so players never softlock.
	energy = max_energy
	terminal_solved.emit(lever_id)
	check_progress_achievements()


func pull_lever(floor_num: int, lever_id: String = "") -> void:
	if not lever_id.is_empty():
		if pulled_lever_ids.get(lever_id, false):
			return
		pulled_lever_ids[lever_id] = true
	if not levers_pulled.has(floor_num):
		push_warning("GameManager.pull_lever: unknown floor %d" % floor_num)
		return
	var needed := levers_needed(floor_num)
	if needed > 0 and levers_pulled[floor_num] >= needed:
		return
	levers_pulled[floor_num] += 1
	lever_pulled.emit(floor_num, levers_pulled[floor_num])
	if needed > 0 and levers_pulled[floor_num] == needed:
		main_door_unlocked.emit(floor_num)


# =====================================================================
# Items and achievements
# =====================================================================
## Used by the NPC shop's "Tempa Syntax Crystal" button: permanent +10 Max HP & +2 Max Energy upgrade.
func exchange_crystals(cost: int = CRYSTALS_PER_UPGRADE) -> bool:
	if syntax_crystals < cost:
		return false
	syntax_crystals -= cost
	max_hp += CRYSTAL_UPGRADE_MAX_HP
	hp += CRYSTAL_UPGRADE_MAX_HP
	max_energy += CRYSTAL_UPGRADE_MAX_ENERGY
	energy = max_energy
	inventory_changed.emit()
	save_game()
	return true


func is_box_destroyed(box_id: String) -> bool:
	return bool(destroyed_box_ids.get(box_id, false))


func register_box_destroyed(box_id: String = "") -> void:
	if not box_id.is_empty():
		if destroyed_box_ids.get(box_id, false):
			return
		destroyed_box_ids[box_id] = true
	boxes_destroyed += 1
	if boxes_destroyed >= BOX_BREAKER_TARGET:
		unlock_achievement("box_breaker")


func unlock_achievement(id: String) -> void:
	if id.is_empty() or id in unlocked_achievements:
		return
	unlocked_achievements.append(id)
	_save_achievements_only()
	achievement_unlocked.emit(id) # ExplorationHUD shows the small notification


func get_achievement_def(id: String) -> Dictionary:
	for item: Dictionary in ACHIEVEMENT_DEFS:
		if str(item.get("id", "")) == id:
			return item
	return {"id": id, "title": id, "desc": "", "category": "", "icon": "coin"}


func get_achievement_total_count() -> int:
	return ACHIEVEMENT_DEFS.size()


func get_all_unlocked_achievements(save_path: String = SAVE_PATH) -> Array[String]:
	var merged: Array[String] = []
	for a: String in unlocked_achievements:
		if not (a in merged):
			merged.append(a)
	var cfg := ConfigFile.new()
	if cfg.load(save_path) == OK:
		for sec_key in [["achievements", "unlocked"], ["upgrades", "unlocked_achievements"]]:
			var arr = cfg.get_value(sec_key[0], sec_key[1], [])
			if arr is Array:
				for item in arr:
					var s := str(item)
					if not s.is_empty() and not (s in merged):
						merged.append(s)
	return merged


func check_progress_achievements() -> void:
	if not solved_terminals.is_empty():
		unlock_achievement("first_query")
	if is_terminal_solved("1:Lever") and is_terminal_solved("1:Lever2"):
		unlock_achievement("ddl_architect")
	if is_terminal_solved("2:Lever") and is_terminal_solved("2:Lever2") and is_terminal_solved("2:Lever3"):
		unlock_achievement("dml_operator")
	if is_terminal_solved("3:Lever") and is_terminal_solved("3:Lever2") and is_terminal_solved("3:Lever3"):
		unlock_achievement("query_detective")
	if is_terminal_solved("4:Lever") and is_terminal_solved("4:Lever2") and is_terminal_solved("4:Lever3"):
		unlock_achievement("dcl_guardian")
	if not unlocked_secret_doors.is_empty():
		unlock_achievement("secret_explorer")
	if boxes_destroyed >= BOX_BREAKER_TARGET:
		unlock_achievement("box_breaker")


# =====================================================================
# Run progress, Ending & Save/Load (user://save.cfg)
# =====================================================================
func _ready() -> void:
	run_started_at = Time.get_ticks_msec()
	_spawn_dev_panel()
	_spawn_dialogue_modal()
	call_deferred("load_settings_only")


func _spawn_dialogue_modal() -> void:
	if _dialogue_layer != null:
		return
	var dlg_script := load("res://scripts/ui/npc_dialogue_modal.gd") as GDScript
	if dlg_script != null:
		_dialogue_layer = dlg_script.new()
		_dialogue_layer.name = "NPCDialogueLayer"
		add_child(_dialogue_layer)


func is_dialogue_open() -> bool:
	return _dialogue_layer != null and _dialogue_layer.has_method("is_dialogue_open") and _dialogue_layer.is_dialogue_open()


func open_npc_dialogue(npc_id: String, speaker_node: Node2D = null) -> void:
	_spawn_dialogue_modal()
	if _dialogue_layer != null and _dialogue_layer.has_method("start_dialogue"):
		_dialogue_layer.start_dialogue(npc_id, speaker_node)


func is_npc_reward_claimed(npc_id: String) -> bool:
	return bool(claimed_npc_rewards.get(npc_id, false))


func claim_npc_reward(npc_id: String) -> Dictionary:
	if npc_id.is_empty() or is_npc_reward_claimed(npc_id):
		return {"claimed_now": false, "summary": ""}
	claimed_npc_rewards[npc_id] = true
	var summary := ""
	match npc_id:
		"hikari":
			coins += 25
			syntax_crystals += 2
			hint_tokens += 2
			hp_potions += 1
			add_xp(75)
			summary = "Hadiah Hikari: +25 Koin, +2 Kristal, +2 Hint, +1 Ramuan HP & +75 XP!"
		"king_jey":
			coins += 40
			syntax_crystals += 3
			hp_potions += 2
			max_hp += 15
			hp = max_hp
			energy = max_energy
			add_xp(100)
			summary = "Berkah King Jey: +40 Koin, +3 Kristal, +2 Ramuan HP, +15 Max HP & +100 XP!"
		"mikael":
			coins += 50
			syntax_crystals += 5
			hp = max_hp
			energy = max_energy
			add_xp(150)
			summary = "Penghargaan Mikael: +50 Koin, +5 Kristal, HP/Energi Penuh & +150 XP!"
	inventory_changed.emit()
	npc_reward_claimed.emit(npc_id)
	save_game()
	return {"claimed_now": true, "summary": summary}


func _spawn_dev_panel() -> void:
	if _dev_panel_layer != null:
		return
	var dev_script := load("res://scripts/ui/dev_panel_modal.gd") as GDScript
	if dev_script != null:
		_dev_panel_layer = dev_script.new()
		_dev_panel_layer.name = "DevPanelLayer"
		add_child(_dev_panel_layer)


func open_dev_panel() -> void:
	_spawn_dev_panel()
	if _dev_panel_layer != null and _dev_panel_layer.has_method("open_panel"):
		_dev_panel_layer.open_panel()


func toggle_dev_panel() -> void:
	_spawn_dev_panel()
	if _dev_panel_layer != null and _dev_panel_layer.has_method("toggle_panel"):
		_dev_panel_layer.toggle_panel()


func set_dev_noclip(enabled: bool) -> void:
	dev_noclip = enabled
	if get_tree() == null:
		return
	var player := get_tree().get_first_node_in_group("player") as CharacterBody2D
	if player != null and is_instance_valid(player):
		player.collision_mask = 0 if dev_noclip else 1


func dev_grant_resources() -> void:
	dev_mode_enabled = true
	coins += 100
	syntax_crystals += 15
	special_keys += 5
	hint_tokens += 10
	hp_potions += 5
	energy_chips += 3
	hp = max_hp
	energy = max_energy
	inventory_changed.emit()


func dev_unlock_all_floors_and_upgrades() -> void:
	dev_mode_enabled = true
	highest_floor_unlocked = 5
	sword_upgraded = true
	has_speed_boots = true
	hp = max_hp
	energy = max_energy
	inventory_changed.emit()


func dev_solve_current_floor(floor_num: int = current_floor) -> void:
	dev_mode_enabled = true
	var needed := levers_needed(floor_num)
	if needed <= 0:
		return
	var lever_names: Array[String] = ["Lever", "Lever2", "Lever3"]
	for i in mini(needed, lever_names.size()):
		var lid := "%d:%s" % [floor_num, lever_names[i]]
		mark_terminal_solved(lid, 50, 1)
		pull_lever(floor_num, lid)
	if get_tree() != null and get_tree().current_scene != null:
		var ysort := get_tree().current_scene.get_node_or_null("YSortObjects")
		if ysort != null:
			for ch in ysort.get_children():
				if ch.has_method("_apply_pulled_visual") and "is_pulled" in ch:
					ch.is_pulled = true
					ch._apply_pulled_visual()
					if ch.has_method("_refresh_label"):
						ch._refresh_label()


func dev_kill_floor_enemies() -> int:
	dev_mode_enabled = true
	if get_tree() == null or get_tree().current_scene == null:
		return 0
	var count := 0
	var ysort := get_tree().current_scene.get_node_or_null("YSortObjects")
	if ysort != null:
		for ch in ysort.get_children():
			if ch is CharacterBody2D and ch.has_method("take_hit"):
				count += 1
				ch.take_hit(999)
	return count


func dev_unlock_all_achievements() -> void:
	dev_mode_enabled = true
	for def: Dictionary in ACHIEVEMENT_DEFS:
		unlock_achievement(str(def.get("id", "")))


func dev_teleport_to(scene_path: String, floor_num: int = 0) -> void:
	dev_mode_enabled = true
	transition_from_scene = ""
	reset_invulnerability()
	if floor_num > 0:
		set_current_floor(floor_num, scene_path)
	if get_tree() != null:
		get_tree().paused = false
		get_tree().change_scene_to_file.call_deferred(scene_path)


func set_current_floor(floor_num: int, scene_path: String = "") -> void:
	current_floor = clampi(floor_num, 1, 5)
	if not scene_path.is_empty():
		current_floor_path = scene_path
	elif FLOOR_SCENES_BY_NUM.has(current_floor):
		current_floor_path = str(FLOOR_SCENES_BY_NUM[current_floor])
	if current_floor > highest_floor_unlocked:
		highest_floor_unlocked = current_floor
	if dev_noclip:
		call_deferred("set_dev_noclip", true)


func finish_run() -> Dictionary:
	unlock_achievement("vault_master")
	var elapsed_s: int = maxi(0, int((Time.get_ticks_msec() - run_started_at) / 1000))
	var stats := {
		"floor": current_floor,
		"xp": xp,
		"rank": rank,
		"coins": coins,
		"crystals": syntax_crystals,
		"time_s": elapsed_s,
	}
	save_game()
	run_completed.emit(stats)
	return stats


func has_save(path: String = SAVE_PATH) -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return false
	return bool(cfg.get_value("meta", "has_run_save", false))


func read_save_summary(path: String = SAVE_PATH) -> Dictionary:
	var ach_count: int = get_all_unlocked_achievements(path).size()
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK or not bool(cfg.get_value("meta", "has_run_save", false)):
		return {"exists": false, "achievements_unlocked": ach_count, "achievements_total": get_achievement_total_count()}
	return {
		"exists": true,
		"current_floor": int(cfg.get_value("progress", "current_floor", 1)),
		"highest_floor_unlocked": int(cfg.get_value("progress", "highest_floor_unlocked", 1)),
		"xp": int(cfg.get_value("stats", "xp", 0)),
		"rank": str(cfg.get_value("stats", "rank", "Trainee")),
		"coins": int(cfg.get_value("economy", "coins", 0)),
		"achievements_unlocked": ach_count,
		"achievements_total": get_achievement_total_count(),
	}


func save_game(path: String = SAVE_PATH) -> bool:
	var cfg := ConfigFile.new()
	cfg.load(path)
	cfg.set_value("meta", "has_run_save", true)
	cfg.set_value("progress", "current_floor", current_floor)
	cfg.set_value("progress", "current_floor_path", current_floor_path)
	cfg.set_value("progress", "highest_floor_unlocked", highest_floor_unlocked)
	cfg.set_value("stats", "max_hp", max_hp)
	cfg.set_value("stats", "hp", hp)
	cfg.set_value("stats", "max_energy", max_energy)
	cfg.set_value("stats", "energy", energy)
	cfg.set_value("stats", "xp", xp)
	cfg.set_value("stats", "rank", rank)
	cfg.set_value("stats", "rank_index", _rank_index)
	cfg.set_value("economy", "coins", coins)
	cfg.set_value("economy", "syntax_crystals", syntax_crystals)
	cfg.set_value("economy", "special_keys", special_keys)
	cfg.set_value("economy", "hint_tokens", hint_tokens)
	cfg.set_value("economy", "energy_chips", energy_chips)
	cfg.set_value("economy", "hp_potions", hp_potions)
	cfg.set_value("upgrades", "has_speed_boots", has_speed_boots)
	cfg.set_value("upgrades", "sword_upgraded", sword_upgraded)
	cfg.set_value("upgrades", "secret_hp_amulet_bought", secret_hp_amulet_bought)
	cfg.set_value("upgrades", "secret_energy_core_bought", secret_energy_core_bought)
	cfg.set_value("upgrades", "boxes_destroyed", boxes_destroyed)
	cfg.set_value("upgrades", "unlocked_achievements", unlocked_achievements)
	cfg.set_value("achievements", "unlocked", unlocked_achievements)
	cfg.set_value("world", "levers_pulled", levers_pulled)
	cfg.set_value("world", "pulled_lever_ids", pulled_lever_ids)
	cfg.set_value("world", "solved_terminals", solved_terminals)
	cfg.set_value("world", "terminal_hints_revealed", terminal_hints_revealed)
	cfg.set_value("world", "unlocked_secret_doors", unlocked_secret_doors)
	cfg.set_value("world", "claimed_npc_rewards", claimed_npc_rewards)
	cfg.set_value("world", "destroyed_box_ids", destroyed_box_ids)
	_write_settings_to_cfg(cfg)
	return cfg.save(path) == OK


func load_game(path: String = SAVE_PATH) -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK or not bool(cfg.get_value("meta", "has_run_save", false)):
		return false
	current_floor = clampi(int(cfg.get_value("progress", "current_floor", 1)), 1, 5)
	current_floor_path = str(cfg.get_value("progress", "current_floor_path", FLOOR_SCENES_BY_NUM.get(current_floor, FLOOR_SCENES_BY_NUM[1])))
	highest_floor_unlocked = maxi(current_floor, int(cfg.get_value("progress", "highest_floor_unlocked", current_floor)))
	max_hp = int(cfg.get_value("stats", "max_hp", DEFAULT_MAX_HP))
	var saved_hp: int = int(cfg.get_value("stats", "hp", max_hp))
	var saved_secret_amulet: bool = bool(cfg.get_value("upgrades", "secret_hp_amulet_bought", false))
	if max_hp <= 10:
		max_hp = DEFAULT_MAX_HP + (25 if saved_secret_amulet else 0)
		saved_hp = max_hp
	hp = clampi(saved_hp, 1, max_hp)
	max_energy = int(cfg.get_value("stats", "max_energy", 10))
	energy = clampi(int(cfg.get_value("stats", "energy", max_energy)), 0, max_energy)
	xp = int(cfg.get_value("stats", "xp", 0))
	rank = str(cfg.get_value("stats", "rank", "Trainee"))
	_rank_index = int(cfg.get_value("stats", "rank_index", 0))
	coins = int(cfg.get_value("economy", "coins", 0))
	syntax_crystals = int(cfg.get_value("economy", "syntax_crystals", 0))
	special_keys = int(cfg.get_value("economy", "special_keys", 0))
	hint_tokens = int(cfg.get_value("economy", "hint_tokens", 0))
	energy_chips = int(cfg.get_value("economy", "energy_chips", 0))
	hp_potions = int(cfg.get_value("economy", "hp_potions", 0))
	has_speed_boots = bool(cfg.get_value("upgrades", "has_speed_boots", false))
	sword_upgraded = bool(cfg.get_value("upgrades", "sword_upgraded", false))
	secret_hp_amulet_bought = bool(cfg.get_value("upgrades", "secret_hp_amulet_bought", false))
	secret_energy_core_bought = bool(cfg.get_value("upgrades", "secret_energy_core_bought", false))
	boxes_destroyed = int(cfg.get_value("upgrades", "boxes_destroyed", 0))
	unlocked_achievements.clear()
	for sec_key in [["achievements", "unlocked"], ["upgrades", "unlocked_achievements"]]:
		var saved_ach = cfg.get_value(sec_key[0], sec_key[1], [])
		if saved_ach is Array:
			for a in saved_ach:
				var s := str(a)
				if not s.is_empty() and not (s in unlocked_achievements):
					unlocked_achievements.append(s)
	var saved_levers = cfg.get_value("world", "levers_pulled", {1: 0, 2: 0, 3: 0, 4: 0, 5: 0})
	levers_pulled = saved_levers.duplicate() if saved_levers is Dictionary else {1: 0, 2: 0, 3: 0, 4: 0, 5: 0}
	for k: int in [1, 2, 3, 4, 5]:
		if not levers_pulled.has(k):
			levers_pulled[k] = 0
	var saved_pl = cfg.get_value("world", "pulled_lever_ids", {})
	pulled_lever_ids = saved_pl.duplicate() if saved_pl is Dictionary else {}
	var saved_st = cfg.get_value("world", "solved_terminals", {})
	solved_terminals = saved_st.duplicate() if saved_st is Dictionary else {}
	var saved_hr = cfg.get_value("world", "terminal_hints_revealed", {})
	terminal_hints_revealed = saved_hr.duplicate() if saved_hr is Dictionary else {}
	var saved_sd = cfg.get_value("world", "unlocked_secret_doors", {})
	unlocked_secret_doors = saved_sd.duplicate() if saved_sd is Dictionary else {}
	var saved_nr = cfg.get_value("world", "claimed_npc_rewards", {})
	claimed_npc_rewards = saved_nr.duplicate() if saved_nr is Dictionary else {}
	var saved_bx = cfg.get_value("world", "destroyed_box_ids", {})
	destroyed_box_ids = saved_bx.duplicate() if saved_bx is Dictionary else {}
	transition_from_scene = ""
	_read_settings_from_cfg(cfg)
	check_progress_achievements()
	hp_changed.emit(hp, max_hp)
	energy_changed.emit(energy, max_energy)
	coins_changed.emit(coins)
	xp_changed.emit(xp, rank)
	inventory_changed.emit()
	return true


## Permanently deletes all saved run progress, unlocked floors, upgrades, and achievements while preserving audio/display settings.
func delete_all_save_data(path: String = SAVE_PATH) -> bool:
	dev_god_mode = false
	set_dev_noclip(false)
	reset_run(true)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "has_run_save", false)
	cfg.set_value("achievements", "unlocked", [])
	cfg.set_value("upgrades", "unlocked_achievements", [])
	_write_settings_to_cfg(cfg)
	var err := cfg.save(path)
	hp_changed.emit(hp, max_hp)
	energy_changed.emit(energy, max_energy)
	coins_changed.emit(coins)
	xp_changed.emit(xp, rank)
	inventory_changed.emit()
	return err == OK


func save_settings_only(path: String = SAVE_PATH) -> void:
	var cfg := ConfigFile.new()
	cfg.load(path)
	_write_settings_to_cfg(cfg)
	cfg.save(path)


func _save_achievements_only(path: String = SAVE_PATH) -> void:
	var cfg := ConfigFile.new()
	cfg.load(path)
	cfg.set_value("achievements", "unlocked", unlocked_achievements)
	cfg.set_value("upgrades", "unlocked_achievements", unlocked_achievements)
	cfg.save(path)


func load_settings_only(path: String = SAVE_PATH) -> void:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return
	_read_settings_from_cfg(cfg)
	for sec_key in [["achievements", "unlocked"], ["upgrades", "unlocked_achievements"]]:
		var saved_ach = cfg.get_value(sec_key[0], sec_key[1], [])
		if saved_ach is Array:
			for a in saved_ach:
				var s := str(a)
				if not s.is_empty() and not (s in unlocked_achievements):
					unlocked_achievements.append(s)


func _write_settings_to_cfg(cfg: ConfigFile) -> void:
	cfg.set_value("settings", "fullscreen", fullscreen_enabled)
	var am := get_node_or_null("/root/AudioManager")
	if am != null:
		cfg.set_value("settings", "master_volume", float(am.master_volume))
		cfg.set_value("settings", "music_volume", float(am.music_volume))
		cfg.set_value("settings", "sfx_volume", float(am.sfx_volume))
		cfg.set_value("settings", "selected_dungeon_bgm", str(am.selected_dungeon_bgm))


func _read_settings_from_cfg(cfg: ConfigFile) -> void:
	fullscreen_enabled = bool(cfg.get_value("settings", "fullscreen", false))
	apply_fullscreen_mode(fullscreen_enabled)
	var am := get_node_or_null("/root/AudioManager")
	if am != null:
		var mv: float = float(cfg.get_value("settings", "master_volume", am.master_volume))
		var bgmv: float = float(cfg.get_value("settings", "music_volume", am.music_volume))
		var sfxv: float = float(cfg.get_value("settings", "sfx_volume", am.sfx_volume))
		var track: String = str(cfg.get_value("settings", "selected_dungeon_bgm", am.selected_dungeon_bgm))
		am.set_volumes(mv, bgmv, sfxv)
		am.set_dungeon_bgm_choice(track, false)


func apply_fullscreen_mode(is_fullscreen: bool) -> void:
	fullscreen_enabled = is_fullscreen
	if DisplayServer.get_name().begins_with("headless"):
		return
	if is_fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)


# =====================================================================
# New game
# =====================================================================
func reset_run(clear_achievements: bool = false) -> void:
	current_floor = 1
	current_floor_path = str(FLOOR_SCENES_BY_NUM[1])
	highest_floor_unlocked = 1
	run_started_at = Time.get_ticks_msec()
	max_hp = DEFAULT_MAX_HP
	max_energy = 10
	hp = max_hp
	energy = max_energy
	coins = 0
	xp = 0
	rank = "Trainee"
	_rank_index = 0
	levers_pulled = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0}
	pulled_lever_ids.clear()
	solved_terminals.clear()
	terminal_hints_revealed.clear()
	unlocked_secret_doors.clear()
	claimed_npc_rewards.clear()
	transition_from_scene = ""
	has_speed_boots = false
	sword_upgraded = false
	secret_hp_amulet_bought = false
	secret_energy_core_bought = false
	special_keys = 0
	syntax_crystals = 0
	hint_tokens = 0
	energy_chips = 0
	hp_potions = 0
	_invulnerable_until_ms = 0
	if clear_achievements:
		unlocked_achievements.clear()
	boxes_destroyed = 0
	destroyed_box_ids.clear()
	inventory_changed.emit()
