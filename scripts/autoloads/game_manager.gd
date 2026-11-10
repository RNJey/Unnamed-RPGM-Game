extends Node
## Global game state. Register as Autoload with the name "GameManager".

# ---------- Signals (UI and world objects listen to these) ----------
signal hp_changed(hp: int, max_hp: int)
signal coins_changed(coins: int)
signal energy_changed(energy: int, max_energy: int)
signal xp_changed(xp: int, rank: String)
signal lever_pulled(floor_num: int, total: int)
signal main_door_unlocked(floor_num: int)
signal achievement_unlocked(id: String)
signal player_died

# ---------- Constants ----------
const LEVERS_NEEDED: int = 3
const CRYSTALS_PER_HP: int = 5
const BOX_BREAKER_TARGET: int = 50
const BONUS_ENERGY_PER_RANK: int = 2 # ASSUMPTION: spec only says rank raises max_energy
const RANKS := [ # ASSUMPTION: XP thresholds are placeholders, tune with the designer
	{"name": "Trainee", "xp": 0},
	{"name": "Junior", "xp": 100},
	{"name": "Senior", "xp": 300},
	{"name": "DBA", "xp": 600},
]

# ---------- Core stats (setters emit signals automatically) ----------
var max_hp: int = 3
var hp: int = 3:
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
var levers_pulled: Dictionary = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0}

# ---------- Inventory and equipment ----------
var has_speed_boots: bool = false
var sword_upgraded: bool = false
var special_keys: int = 0
var syntax_crystals: int = 0
var hint_tokens: int = 0
var energy_chips: int = 0

# ---------- Achievements and counters ----------
var unlocked_achievements: Array[String] = []
var boxes_destroyed: int = 0


# =====================================================================
# Health, coins, energy, XP
# =====================================================================
func take_damage(amount: int = 1) -> void:
	hp -= amount
	if hp <= 0:
		player_died.emit()


func heal(amount: int = 1) -> void:
	hp += amount


func add_coins(amount: int) -> void:
	coins += amount


func spend_coins(amount: int) -> bool:
	if coins < amount:
		return false
	coins -= amount
	return true


## Called when the player presses RUN in the terminal. Returns false if no energy.
func use_energy() -> bool:
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
func pull_lever(floor_num: int) -> void:
	if not levers_pulled.has(floor_num):
		push_warning("GameManager.pull_lever: unknown floor %d" % floor_num)
		return
	if levers_pulled[floor_num] >= LEVERS_NEEDED:
		return
	levers_pulled[floor_num] += 1
	lever_pulled.emit(floor_num, levers_pulled[floor_num])
	if levers_pulled[floor_num] == LEVERS_NEEDED:
		main_door_unlocked.emit(floor_num)


# =====================================================================
# Items and achievements
# =====================================================================
## Used by the NPC shop's "Exchange Syntax Crystals" button.
func exchange_crystals() -> bool:
	if syntax_crystals < CRYSTALS_PER_HP or hp >= max_hp:
		return false
	syntax_crystals -= CRYSTALS_PER_HP
	hp += 1
	return true


func register_box_destroyed() -> void:
	boxes_destroyed += 1
	if boxes_destroyed >= BOX_BREAKER_TARGET:
		unlock_achievement("box_breaker")


func unlock_achievement(id: String) -> void:
	if id in unlocked_achievements:
		return
	unlocked_achievements.append(id)
	achievement_unlocked.emit(id) # ExplorationHUD shows the small notification


# =====================================================================
# New game
# =====================================================================
func reset_run() -> void:
	max_hp = 3
	max_energy = 10
	hp = max_hp
	energy = max_energy
	coins = 0
	xp = 0
	rank = "Trainee"
	_rank_index = 0
	levers_pulled = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0}
	has_speed_boots = false
	sword_upgraded = false
	special_keys = 0
	syntax_crystals = 0
	hint_tokens = 0
	energy_chips = 0
	unlocked_achievements.clear()
	boxes_destroyed = 0
