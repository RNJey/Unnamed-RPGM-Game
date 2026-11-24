extends Control
## Merchant shop UI modal:
## - Regular Merchant (Floors 1 & 3): Pedang Kristal, Sepatu Cepat, Kunci Rahasia, Token Petunjuk, Ramuan HP, Tempa Kristal (+Max HP & +Max Energi)
## - Secret Room Trader (Floor 2 Secret): Exclusive rare items (Max HP Amulet, Max Energy Core, Key Bundle, Energy Refill, Bundel Ramuan HP, Tempa Kristal Diskon)

const ITEMS_TEX := preload("res://assets/tilesets/Valley Ruin Asset Pack V0.3/Objects/Items.png")

const COST_SWORD: int = 20
const COST_BOOTS: int = 15
const COST_KEY: int = 10
const COST_HINT: int = 5
const COST_POTION: int = 8

const COST_AMULET: int = 25
const COST_CORE: int = 20
const COST_BUNDLE_KEYS: int = 15
const COST_ENERGY_CHIP: int = 8
const COST_SECRET_POTION_BUNDLE: int = 12
const SECRET_CRYSTALS_PER_UPGRADE: int = 2

const COLOR_OK := Color(0.55, 0.96, 0.65, 1)
const COLOR_ERR := Color(1.0, 0.55, 0.55, 1)
const COLOR_INFO := Color(0.88, 0.9, 0.82, 1)

var _secret_mode: bool = false

@onready var cat_label: Label = $Center/Modal/Margin/VBox/HeaderPanel/HMargin/HRow/CatPill/CatLabel
@onready var title_label: Label = $Center/Modal/Margin/VBox/HeaderPanel/HMargin/HRow/TitleLabel
@onready var coin_label: Label = $Center/Modal/Margin/VBox/HeaderPanel/HMargin/HRow/CoinLabel
@onready var crystal_label: Label = $Center/Modal/Margin/VBox/HeaderPanel/HMargin/HRow/CrystalLabel
@onready var key_label: Label = $Center/Modal/Margin/VBox/HeaderPanel/HMargin/HRow/KeyLabel
@onready var hint_label: Label = $Center/Modal/Margin/VBox/HeaderPanel/HMargin/HRow/HintLabel
@onready var potion_label: Label = $Center/Modal/Margin/VBox/HeaderPanel/HMargin/HRow/PotionLabel
@onready var hp_label: Label = $Center/Modal/Margin/VBox/HeaderPanel/HMargin/HRow/HPLabel
@onready var close_btn: Button = $Center/Modal/Margin/VBox/HeaderPanel/HMargin/HRow/CloseBtn

@onready var c1_icon: TextureRect = $Center/Modal/Margin/VBox/Grid/SwordCard/Margin/Row/IconFrame/Icon
@onready var c1_name: Label = $Center/Modal/Margin/VBox/Grid/SwordCard/Margin/Row/InfoCol/NameLabel
@onready var c1_desc: Label = $Center/Modal/Margin/VBox/Grid/SwordCard/Margin/Row/InfoCol/DescLabel
@onready var c1_price: Label = $Center/Modal/Margin/VBox/Grid/SwordCard/Margin/Row/InfoCol/ActionRow/PriceTag
@onready var sword_btn: Button = $Center/Modal/Margin/VBox/Grid/SwordCard/Margin/Row/InfoCol/ActionRow/BuyBtn

@onready var c2_icon: TextureRect = $Center/Modal/Margin/VBox/Grid/BootsCard/Margin/Row/IconFrame/Icon
@onready var c2_name: Label = $Center/Modal/Margin/VBox/Grid/BootsCard/Margin/Row/InfoCol/NameLabel
@onready var c2_desc: Label = $Center/Modal/Margin/VBox/Grid/BootsCard/Margin/Row/InfoCol/DescLabel
@onready var c2_price: Label = $Center/Modal/Margin/VBox/Grid/BootsCard/Margin/Row/InfoCol/ActionRow/PriceTag
@onready var boots_btn: Button = $Center/Modal/Margin/VBox/Grid/BootsCard/Margin/Row/InfoCol/ActionRow/BuyBtn

@onready var c3_icon: TextureRect = $Center/Modal/Margin/VBox/Grid/KeyCard/Margin/Row/IconFrame/Icon
@onready var c3_name: Label = $Center/Modal/Margin/VBox/Grid/KeyCard/Margin/Row/InfoCol/NameLabel
@onready var c3_desc: Label = $Center/Modal/Margin/VBox/Grid/KeyCard/Margin/Row/InfoCol/DescLabel
@onready var c3_price: Label = $Center/Modal/Margin/VBox/Grid/KeyCard/Margin/Row/InfoCol/ActionRow/PriceTag
@onready var key_btn: Button = $Center/Modal/Margin/VBox/Grid/KeyCard/Margin/Row/InfoCol/ActionRow/BuyBtn

@onready var c4_icon: TextureRect = $Center/Modal/Margin/VBox/Grid/HintCard/Margin/Row/IconFrame/Icon
@onready var c4_name: Label = $Center/Modal/Margin/VBox/Grid/HintCard/Margin/Row/InfoCol/NameLabel
@onready var c4_desc: Label = $Center/Modal/Margin/VBox/Grid/HintCard/Margin/Row/InfoCol/DescLabel
@onready var c4_price: Label = $Center/Modal/Margin/VBox/Grid/HintCard/Margin/Row/InfoCol/ActionRow/PriceTag
@onready var hint_btn: Button = $Center/Modal/Margin/VBox/Grid/HintCard/Margin/Row/InfoCol/ActionRow/BuyBtn

@onready var pot_icon: TextureRect = $Center/Modal/Margin/VBox/BottomRow/PotionCard/Margin/Row/IconFrame/Icon
@onready var pot_name: Label = $Center/Modal/Margin/VBox/BottomRow/PotionCard/Margin/Row/InfoCol/NameLabel
@onready var pot_desc: Label = $Center/Modal/Margin/VBox/BottomRow/PotionCard/Margin/Row/InfoCol/DescLabel
@onready var pot_price: Label = $Center/Modal/Margin/VBox/BottomRow/PotionCard/Margin/Row/InfoCol/ActionRow/PriceTag
@onready var potion_btn: Button = $Center/Modal/Margin/VBox/BottomRow/PotionCard/Margin/Row/InfoCol/ActionRow/BuyBtn

@onready var ex_name: Label = $Center/Modal/Margin/VBox/BottomRow/ExchangeCard/Margin/Row/InfoCol/NameLabel
@onready var ex_desc: Label = $Center/Modal/Margin/VBox/BottomRow/ExchangeCard/Margin/Row/InfoCol/DescLabel
@onready var exchange_btn: Button = $Center/Modal/Margin/VBox/BottomRow/ExchangeCard/Margin/Row/ExchangeBtn
@onready var status_label: Label = $Center/Modal/Margin/VBox/StatusBanner/SMargin/StatusLabel


func _ready() -> void:
	visible = false
	close_btn.pressed.connect(close_shop)
	sword_btn.pressed.connect(func(): buy_item("secret_amulet" if _secret_mode else "sword"))
	boots_btn.pressed.connect(func(): buy_item("secret_core" if _secret_mode else "boots"))
	key_btn.pressed.connect(func(): buy_item("secret_keys" if _secret_mode else "key"))
	hint_btn.pressed.connect(func(): buy_item("secret_chip" if _secret_mode else "hint"))
	potion_btn.pressed.connect(func(): buy_item("secret_potion" if _secret_mode else "potion"))
	exchange_btn.pressed.connect(func(): buy_item("secret_exchange" if _secret_mode else "exchange_hp"))

	GameManager.coins_changed.connect(func(_c): _refresh_ui())
	GameManager.hp_changed.connect(func(_h, _m): _refresh_ui())
	GameManager.inventory_changed.connect(_refresh_ui)
	_apply_catalog_mode()
	_refresh_ui()


func _exit_tree() -> void:
	if visible and get_tree() != null:
		get_tree().paused = false


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		close_shop()
		get_viewport().set_input_as_handled()


func is_secret_mode() -> bool:
	return _secret_mode


func open_shop(secret_mode: bool = false) -> void:
	_secret_mode = secret_mode
	var am := get_node_or_null("/root/AudioManager")
	if am != null:
		am.play_sfx("ui_confirm")
	_apply_catalog_mode()
	_refresh_ui()
	if _secret_mode:
		_set_status("Selamat datang di Toko Rahasia! Koleksi langka khusus penjelajah ruang tersembunyi.", COLOR_INFO)
	else:
		_set_status("Selamat datang! Pilih perlengkapan atau tukar Syntax Crystal.", COLOR_INFO)
	visible = true
	if get_tree() != null:
		get_tree().paused = true


func close_shop() -> void:
	var am := get_node_or_null("/root/AudioManager")
	if am != null:
		am.play_sfx("ui_confirm")
	visible = false
	if get_tree() != null:
		get_tree().paused = false


func _set_atlas(rect_node: TextureRect, region: Rect2) -> void:
	if rect_node == null:
		return
	var at := AtlasTexture.new()
	at.atlas = ITEMS_TEX
	at.region = region
	rect_node.texture = at


func _apply_catalog_mode() -> void:
	if _secret_mode:
		cat_label.text = "TOKO RAHASIA"
		title_label.text = "Pedagang Bawah Tanah — Koleksi Langka"
		c1_name.text = "Jimat Hati Kuno"
		c1_desc.text = "Eksklusif: menambah +25 Max HP permanen (jadi %d) & pulihkan +25 HP." % (GameManager.max_hp + 25 if not GameManager.secret_hp_amulet_bought else GameManager.max_hp)
		c1_price.text = "%d Koin · 1x" % COST_AMULET
		_set_atlas(c1_icon, Rect2(80, 16, 16, 16))

		c2_name.text = "Inti Energi Overclock"
		c2_desc.text = "Eksklusif: menambah +4 Max Energi SQL permanen & isi energi penuh."
		c2_price.text = "%d Koin · 1x" % COST_CORE
		_set_atlas(c2_icon, Rect2(144, 16, 16, 16))

		c3_name.text = "Bundel 2 Kunci Rahasia"
		c3_desc.text = "Paket hemat: langsung dapat +2 Kunci Ruang Rahasia untuk Lantai 3."
		c3_price.text = "%d Koin · Bundel" % COST_BUNDLE_KEYS
		_set_atlas(c3_icon, Rect2(144, 32, 16, 16))

		c4_name.text = "Chip Energi Penuh"
		c4_desc.text = "Eksklusif: langsung mengisi penuh Energi SQL sekarang +1 Energy Chip."
		c4_price.text = "%d Koin · Habis pakai" % COST_ENERGY_CHIP
		_set_atlas(c4_icon, Rect2(0, 0, 16, 16))

		pot_name.text = "Bundel 2 Ramuan HP"
		pot_desc.text = "Eksklusif: dapat +2 Ramuan HP (+35 HP/botol). Tekan [H] di dungeon untuk pakai."
		pot_price.text = "%d Koin · +2 botol" % COST_SECRET_POTION_BUNDLE
		_set_atlas(pot_icon, Rect2(128, 16, 16, 16))

		ex_name.text = "Tempa Kristal Diskon -> +10 Max HP & +2 Energi"
		ex_desc.text = "Diskon Toko Rahasia: cukup 2 Syntax Crystal untuk upgrade permanen +10 Max HP, +2 Max Energi SQL & isi penuh Energi."
	else:
		cat_label.text = "TOKO DUNGEON"
		title_label.text = "Saudagar Tinkerer"
		c1_name.text = "Pedang Kristal"
		c1_desc.text = "Upgrade permanen: damage pedang 1 -> 3 & ayunan lebih cepat."
		c1_price.text = "%d Koin · 1x" % COST_SWORD
		_set_atlas(c1_icon, Rect2(16, 16, 16, 16))

		c2_name.text = "Sepatu Cepat"
		c2_desc.text = "Upgrade permanen: kecepatan gerak meningkat (120 -> 170)."
		c2_price.text = "%d Koin · 1x" % COST_BOOTS
		_set_atlas(c2_icon, Rect2(160, 16, 16, 16))

		c3_name.text = "Kunci Ruang Rahasia"
		c3_desc.text = "Membuka 1 pintu ruang rahasia di Lantai 2 atau Lantai 3."
		c3_price.text = "%d Koin · Habis pakai" % COST_KEY
		_set_atlas(c3_icon, Rect2(144, 32, 16, 16))

		c4_name.text = "Token Petunjuk SQL"
		c4_desc.text = "Menambah +1 token untuk membuka 1 kartu sintaks di Terminal SQL."
		c4_price.text = "%d Koin · Habis pakai" % COST_HINT
		_set_atlas(c4_icon, Rect2(96, 16, 16, 16))

		pot_name.text = "Ramuan HP (+35 HP)"
		pot_desc.text = "Disimpan di tas. Tekan [H] atau klik tombol di HUD kapan saja untuk +35 HP."
		pot_price.text = "%d Koin · Habis pakai" % COST_POTION
		_set_atlas(pot_icon, Rect2(128, 16, 16, 16))

		ex_name.text = "Tempa Kristal -> +10 Max HP & +2 Max Energi"
		ex_desc.text = "Tukar 3 Syntax Crystal untuk upgrade permanen +10 Max HP, +2 Max Energi SQL & isi penuh Energi."


func buy_item(item_id: String) -> bool:
	var ok := false
	var am := get_node_or_null("/root/AudioManager")
	match item_id:
		"sword":
			if GameManager.sword_upgraded:
				_set_status("Pedang Kristal sudah kamu miliki.", COLOR_INFO)
			elif GameManager.spend_coins(COST_SWORD):
				GameManager.sword_upgraded = true
				GameManager.inventory_changed.emit()
				_set_status("Berhasil membeli Pedang Kristal! Damage pedang 1 -> 3.", COLOR_OK)
				ok = true
			else:
				_set_status("Koin tidak cukup untuk Pedang Kristal (butuh %d Koin)." % COST_SWORD, COLOR_ERR)
		"boots":
			if GameManager.has_speed_boots:
				_set_status("Sepatu Cepat sudah kamu miliki.", COLOR_INFO)
			elif GameManager.spend_coins(COST_BOOTS):
				GameManager.has_speed_boots = true
				GameManager.inventory_changed.emit()
				_set_status("Berhasil membeli Sepatu Cepat! Kecepatan gerak meningkat.", COLOR_OK)
				ok = true
			else:
				_set_status("Koin tidak cukup untuk Sepatu Cepat (butuh %d Koin)." % COST_BOOTS, COLOR_ERR)
		"key":
			if GameManager.spend_coins(COST_KEY):
				GameManager.special_keys += 1
				GameManager.inventory_changed.emit()
				_set_status("Berhasil membeli 1 Kunci Ruang Rahasia! (Total: %d)" % GameManager.special_keys, COLOR_OK)
				ok = true
			else:
				_set_status("Koin tidak cukup untuk Kunci Ruang Rahasia (butuh %d Koin)." % COST_KEY, COLOR_ERR)
		"hint":
			if GameManager.spend_coins(COST_HINT):
				GameManager.hint_tokens += 1
				GameManager.inventory_changed.emit()
				_set_status("Berhasil membeli 1 Token Petunjuk SQL! (Total: %d)" % GameManager.hint_tokens, COLOR_OK)
				ok = true
			else:
				_set_status("Koin tidak cukup untuk Token Petunjuk SQL (butuh %d Koin)." % COST_HINT, COLOR_ERR)
		"potion":
			if GameManager.spend_coins(COST_POTION):
				GameManager.hp_potions += 1
				GameManager.inventory_changed.emit()
				_set_status("Berhasil membeli 1 Ramuan HP (+35 HP)! Tekan [H] saat bertarung. (Stok: %d)" % GameManager.hp_potions, COLOR_OK)
				ok = true
			else:
				_set_status("Koin tidak cukup untuk Ramuan HP (butuh %d Koin)." % COST_POTION, COLOR_ERR)
		"secret_potion":
			if GameManager.spend_coins(COST_SECRET_POTION_BUNDLE):
				GameManager.hp_potions += 2
				GameManager.inventory_changed.emit()
				_set_status("Berhasil membeli Bundel 2 Ramuan HP! Tekan [H] untuk pakai. (Stok: %d)" % GameManager.hp_potions, COLOR_OK)
				ok = true
			else:
				_set_status("Koin tidak cukup untuk Bundel Ramuan HP (butuh %d Koin)." % COST_SECRET_POTION_BUNDLE, COLOR_ERR)
		"exchange_hp":
			if GameManager.exchange_crystals(GameManager.CRYSTALS_PER_UPGRADE):
				_set_status("Berhasil menukar %d Kristal: +%d Max HP (%d) & +%d Max Energi (%d)!" % [
					GameManager.CRYSTALS_PER_UPGRADE,
					GameManager.CRYSTAL_UPGRADE_MAX_HP,
					GameManager.max_hp,
					GameManager.CRYSTAL_UPGRADE_MAX_ENERGY,
					GameManager.max_energy,
				], COLOR_OK)
				ok = true
			else:
				_set_status("Syntax Crystal tidak cukup (butuh %d Kristal)." % GameManager.CRYSTALS_PER_UPGRADE, COLOR_ERR)
		"secret_amulet":
			if GameManager.secret_hp_amulet_bought:
				_set_status("Jimat Hati Kuno sudah kamu miliki.", COLOR_INFO)
			elif GameManager.spend_coins(COST_AMULET):
				GameManager.secret_hp_amulet_bought = true
				GameManager.max_hp += 25
				GameManager.heal(25)
				GameManager.inventory_changed.emit()
				_set_status("Berhasil membeli Jimat Hati Kuno! Max HP naik jadi %d!" % GameManager.max_hp, COLOR_OK)
				ok = true
			else:
				_set_status("Koin tidak cukup untuk Jimat Hati Kuno (butuh %d Koin)." % COST_AMULET, COLOR_ERR)
		"secret_core":
			if GameManager.secret_energy_core_bought:
				_set_status("Inti Energi Overclock sudah kamu miliki.", COLOR_INFO)
			elif GameManager.spend_coins(COST_CORE):
				GameManager.secret_energy_core_bought = true
				GameManager.max_energy += 4
				GameManager.energy = GameManager.max_energy
				GameManager.inventory_changed.emit()
				_set_status("Berhasil membeli Inti Energi! Max Energi naik jadi %d!" % GameManager.max_energy, COLOR_OK)
				ok = true
			else:
				_set_status("Koin tidak cukup untuk Inti Energi (butuh %d Koin)." % COST_CORE, COLOR_ERR)
		"secret_keys":
			if GameManager.spend_coins(COST_BUNDLE_KEYS):
				GameManager.special_keys += 2
				GameManager.inventory_changed.emit()
				_set_status("Berhasil membeli Bundel 2 Kunci Rahasia! (Total: %d)" % GameManager.special_keys, COLOR_OK)
				ok = true
			else:
				_set_status("Koin tidak cukup untuk Bundel Kunci (butuh %d Koin)." % COST_BUNDLE_KEYS, COLOR_ERR)
		"secret_chip":
			if GameManager.spend_coins(COST_ENERGY_CHIP):
				GameManager.energy_chips += 1
				GameManager.energy = GameManager.max_energy
				GameManager.inventory_changed.emit()
				_set_status("Energi terisi penuh & +1 Energy Chip tersimpan!", COLOR_OK)
				ok = true
			else:
				_set_status("Koin tidak cukup untuk Chip Energi (butuh %d Koin)." % COST_ENERGY_CHIP, COLOR_ERR)
		"secret_exchange":
			if GameManager.exchange_crystals(SECRET_CRYSTALS_PER_UPGRADE):
				_set_status("Diskon Toko Rahasia: %d Kristal -> +%d Max HP (%d) & +%d Max Energi (%d)!" % [
					SECRET_CRYSTALS_PER_UPGRADE,
					GameManager.CRYSTAL_UPGRADE_MAX_HP,
					GameManager.max_hp,
					GameManager.CRYSTAL_UPGRADE_MAX_ENERGY,
					GameManager.max_energy,
				], COLOR_OK)
				ok = true
			else:
				_set_status("Syntax Crystal tidak cukup (butuh %d Kristal)." % SECRET_CRYSTALS_PER_UPGRADE, COLOR_ERR)

	if am != null:
		am.play_sfx("coin" if ok else "query_error")
	if ok:
		GameManager.save_game()
	_refresh_ui()
	return ok


func _set_status(msg: String, color: Color) -> void:
	if status_label == null:
		return
	status_label.text = msg
	status_label.add_theme_color_override("font_color", color)


func _refresh_ui() -> void:
	if coin_label != null:
		coin_label.text = str(GameManager.coins)
	if crystal_label != null:
		crystal_label.text = str(GameManager.syntax_crystals)
	if key_label != null:
		key_label.text = str(GameManager.special_keys)
	if hint_label != null:
		hint_label.text = str(GameManager.hint_tokens)
	if potion_label != null:
		potion_label.text = str(GameManager.hp_potions)
	if hp_label != null:
		hp_label.text = "%d/%d" % [GameManager.hp, GameManager.max_hp]

	if _secret_mode:
		if sword_btn != null:
			sword_btn.text = "SUDAH DIMILIKI" if GameManager.secret_hp_amulet_bought else "BELI (%d Koin)" % COST_AMULET
			sword_btn.disabled = GameManager.secret_hp_amulet_bought or GameManager.coins < COST_AMULET
		if boots_btn != null:
			boots_btn.text = "SUDAH DIMILIKI" if GameManager.secret_energy_core_bought else "BELI (%d Koin)" % COST_CORE
			boots_btn.disabled = GameManager.secret_energy_core_bought or GameManager.coins < COST_CORE
		if key_btn != null:
			key_btn.text = "BELI (%d Koin)" % COST_BUNDLE_KEYS
			key_btn.disabled = GameManager.coins < COST_BUNDLE_KEYS
		if hint_btn != null:
			hint_btn.text = "BELI (%d Koin)" % COST_ENERGY_CHIP
			hint_btn.disabled = GameManager.coins < COST_ENERGY_CHIP
		if potion_btn != null:
			potion_btn.text = "BELI (%d Koin)" % COST_SECRET_POTION_BUNDLE
			potion_btn.disabled = GameManager.coins < COST_SECRET_POTION_BUNDLE
		if exchange_btn != null:
			exchange_btn.text = "TEMPA (%d Kristal)" % SECRET_CRYSTALS_PER_UPGRADE
			exchange_btn.disabled = GameManager.syntax_crystals < SECRET_CRYSTALS_PER_UPGRADE
	else:
		if sword_btn != null:
			sword_btn.text = "SUDAH DIMILIKI" if GameManager.sword_upgraded else "BELI (%d Koin)" % COST_SWORD
			sword_btn.disabled = GameManager.sword_upgraded or GameManager.coins < COST_SWORD
		if boots_btn != null:
			boots_btn.text = "SUDAH DIMILIKI" if GameManager.has_speed_boots else "BELI (%d Koin)" % COST_BOOTS
			boots_btn.disabled = GameManager.has_speed_boots or GameManager.coins < COST_BOOTS
		if key_btn != null:
			key_btn.text = "BELI (%d Koin)" % COST_KEY
			key_btn.disabled = GameManager.coins < COST_KEY
		if hint_btn != null:
			hint_btn.text = "BELI (%d Koin)" % COST_HINT
			hint_btn.disabled = GameManager.coins < COST_HINT
		if potion_btn != null:
			potion_btn.text = "BELI (%d Koin)" % COST_POTION
			potion_btn.disabled = GameManager.coins < COST_POTION
		if exchange_btn != null:
			exchange_btn.text = "TEMPA (%d Kristal)" % GameManager.CRYSTALS_PER_UPGRADE
			exchange_btn.disabled = GameManager.syntax_crystals < GameManager.CRYSTALS_PER_UPGRADE
