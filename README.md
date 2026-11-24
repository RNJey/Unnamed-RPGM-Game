# SQL Vault: Escape the Database

A top-down 2D educational dungeon RPG built in **Godot 4.7.2** where you explore underground floors, break dungeon crates for coins, trade with a tinkerer merchant, and solve **SQL missions (DDL → DML → DCL & SELECT)** at rune terminals to unlock levers and escape the database.

---

## Controls

| Action | Key / Input |
|---|---|
| Move | `W` `A` `S` `D` or Arrow Keys |
| Attack (Sword) | `J` or Left Mouse Click |
| Interact (Terminals, Levers, Doors, Merchant) | `E` |
| Pause Menu / Close Active Modal | `Esc` |

---

## Progression & Features

- **5 Floors + 3 Secret Rooms:** Progress from the Dungeon Entrance (Floor 1) through the Catacombs (Floors 2–4) to the Ground Exit (Floor 5).
- **Step-by-Step SQL Curriculum (`data/levels.json`):**
  - **DDL:** `CREATE TABLE`, `ALTER TABLE`, `DROP TABLE`
  - **DML:** `INSERT INTO`, `UPDATE`, `DELETE`
  - **Queries:** `SELECT`, `WHERE`, `AND`/`OR`, `LIKE`, `BETWEEN`, `IN`, `ORDER BY`, `LIMIT`, and aggregates (`COUNT`, `SUM`, `AVG`, `MIN`, `MAX`)
  - **DCL:** `GRANT`, `REVOKE`
- **Shop & Upgrades (`NPCMerchant` on Floors 1 & 3):**
  - **Pedang Kristal** (`20` Coins): Increases sword damage (`1 → 3`) and swing speed
  - **Sepatu Cepat** (`15` Coins): Increases walk speed (`120 → 170`)
  - **Kunci Ruang Rahasia** (`10` Coins): Unlocks secret doors on Floors 2 & 3
  - **Token Petunjuk SQL** (`5` Coins): Reveals syntax hints in `BengkelQueryUI`
  - **Crystal Exchange** (`5` Syntax Crystals): Restores `+30 HP`
- **Save & Load (`user://save.cfg`):** Automatically saves progress on terminal completion, shop purchases, and floor transitions, or manually from the Pause Menu (`Esc`).
- **Audio Options (`Pengaturan`):** Switch live between 3 CC0 dungeon loops — **Opt 5: Dungeon Ambience (Default)**, **Opt 3: Cave Theme**, and **Loopable Dungeon Ambience** — plus Floor-5 Boss music and SFX volume controls.

---

## Credits & Licenses

- **Engine:** [Godot Engine 4.7.2](https://godotengine.org/) (MIT License)
- **Audio (CC0 1.0 Universal — Public Domain):**
  - *Dungeon Ambience* (`bgm_opt5.ogg`) by **yd** — OpenGameArt
  - *Cave Theme* (`bgm_opt3.ogg`) by **Brandon Morris** — OpenGameArt
  - *Loopable Dungeon Ambience* (`bgm_basement.ogg`) by **JaggedStone** — OpenGameArt
  - *Boss Battle #2 [8-bit]* (`bgm_boss.ogg`) by **nene** — OpenGameArt
  - *RPG Audio* & *Interface Sounds* (`assets/audio/sfx/*.ogg`) by **Kenney** (kenney.nl)
- **Tilesets & Sprites:**
  - *DampDungeons* & *RF_Catacombs_v1.0* (`assets/tilesets/`)
  - Custom generated/composed player animations (`assets/sprites/`)
  - *Note:* `assets/tilesets/Valley Ruin Asset Pack V0.3` items/merchant art origin does not include an embedded license file in this repository; verify pack rights or swap before public commercial release.
