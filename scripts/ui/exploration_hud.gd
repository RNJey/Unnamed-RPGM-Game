extends Control
## Signal-driven top exploration HUD synced with GameManager state.

@export var floor_num: int = 1

var _toast_tween: Tween

@onready var floor_label: Label = $TopBar/Margin/Row/FloorLabel
@onready var hp_bar: ProgressBar = $TopBar/Margin/Row/HPGroup/HPBar
@onready var hp_label: Label = $TopBar/Margin/Row/HPGroup/HPLabel
@onready var energy_bar: ProgressBar = $TopBar/Margin/Row/EnergyGroup/EnergyBar
@onready var energy_label: Label = $TopBar/Margin/Row/EnergyGroup/EnergyLabel
@onready var coin_label: Label = $TopBar/Margin/Row/CoinGroup/CoinLabel
@onready var crystal_label: Label = $TopBar/Margin/Row/CrystalGroup/CrystalLabel
@onready var key_label: Label = $TopBar/Margin/Row/KeyGroup/KeyLabel
@onready var potion_label: Label = $TopBar/Margin/Row/PotionGroup/PotionLabel
@onready var use_potion_btn: Button = $TopBar/Margin/Row/PotionGroup/UsePotionBtn
@onready var xp_label: Label = $TopBar/Margin/Row/XPGroup/XPLabel
@onready var lever_label: Label = $TopBar/Margin/Row/LeverGroup/LeverLabel
@onready var toast_label: Label = $ToastLabel


func _ready() -> void:
	GameManager.hp_changed.connect(_on_hp_changed)
	GameManager.energy_changed.connect(_on_energy_changed)
	GameManager.coins_changed.connect(_on_coins_changed)
	GameManager.xp_changed.connect(_on_xp_changed)
	GameManager.lever_pulled.connect(_on_lever_pulled)
	GameManager.inventory_changed.connect(_on_inventory_changed)
	GameManager.achievement_unlocked.connect(_on_achievement_unlocked)
	if use_potion_btn != null:
		use_potion_btn.pressed.connect(_try_use_potion)

	floor_label.text = "LANTAI %d" % floor_num
	_on_hp_changed(GameManager.hp, GameManager.max_hp)
	_on_energy_changed(GameManager.energy, GameManager.max_energy)
	_on_coins_changed(GameManager.coins)
	_on_xp_changed(GameManager.xp, GameManager.rank)
	_on_inventory_changed()
	_refresh_levers()

	var cur_path := ""
	if get_tree() != null and get_tree().current_scene != null:
		cur_path = get_tree().current_scene.scene_file_path
	GameManager.set_current_floor(floor_num, cur_path)
	var am := get_node_or_null("/root/AudioManager")
	if am != null:
		am.play_dungeon_bgm(floor_num)


func _unhandled_input(event: InputEvent) -> void:
	if get_tree() == null or get_tree().paused:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_H:
		_try_use_potion()
		get_viewport().set_input_as_handled()


func _try_use_potion() -> void:
	var am := get_node_or_null("/root/AudioManager")
	if GameManager.hp_potions <= 0:
		if am != null:
			am.play_sfx("query_error")
		_show_toast("Ramuan HP habis! Beli di Pedagang.")
		return
	if GameManager.hp >= GameManager.max_hp:
		if am != null:
			am.play_sfx("query_error")
		_show_toast("HP sudah penuh (%d/%d)!" % [GameManager.hp, GameManager.max_hp])
		return
	if GameManager.use_hp_potion():
		if am != null:
			am.play_sfx("coin")
		_show_toast("Meminum Ramuan HP (+%d HP)!" % GameManager.POTION_HEAL_AMOUNT)


func _on_hp_changed(hp: int, max_hp: int) -> void:
	hp_bar.max_value = max_hp
	hp_bar.value = hp
	hp_label.text = "%d/%d" % [hp, max_hp]
	crystal_label.text = str(GameManager.syntax_crystals)
	if use_potion_btn != null:
		use_potion_btn.disabled = (GameManager.hp_potions <= 0 or hp >= max_hp)


func _on_energy_changed(energy: int, max_energy: int) -> void:
	energy_bar.max_value = max_energy
	energy_bar.value = energy
	energy_label.text = "%d/%d" % [energy, max_energy]


func _on_coins_changed(coins: int) -> void:
	coin_label.text = str(coins)


func _on_xp_changed(xp: int, rank: String) -> void:
	xp_label.text = "%s · %d XP" % [rank, xp]
	crystal_label.text = str(GameManager.syntax_crystals)


func _on_inventory_changed() -> void:
	crystal_label.text = str(GameManager.syntax_crystals)
	if key_label != null:
		key_label.text = str(GameManager.special_keys)
	if potion_label != null:
		potion_label.text = str(GameManager.hp_potions)
	if use_potion_btn != null:
		use_potion_btn.disabled = (GameManager.hp_potions <= 0 or GameManager.hp >= GameManager.max_hp)


func _on_lever_pulled(pulled_floor: int, _total: int) -> void:
	if pulled_floor == floor_num:
		_refresh_levers()


func _refresh_levers() -> void:
	var pulled: int = int(GameManager.levers_pulled.get(floor_num, 0))
	var needed: int = GameManager.levers_needed(floor_num)
	lever_label.text = "TUAS %d/%d" % [pulled, needed]


func _show_toast(msg: String) -> void:
	toast_label.text = msg
	toast_label.modulate = Color(1, 1, 1, 1)
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(1.8)
	_toast_tween.tween_property(toast_label, "modulate:a", 0.0, 0.8)


func _on_achievement_unlocked(id: String) -> void:
	var def: Dictionary = GameManager.get_achievement_def(id)
	var title: String = str(def.get("title", id))
	_show_toast("PENCAPAIAN TERBUKA: %s" % title)
