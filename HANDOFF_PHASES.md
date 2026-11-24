# SQL Vault — Status & Remaining Work

Rewritten after an audit run on the current project (headless, assertions pasted below).
Everything in §2 was measured, not read off a plan. If a number here disagrees with the code,
the code changed after this audit — re-measure before editing.

---

## 1. Header

```
PROJECT      E:\Hermes\Output\PPLG\SQL Vault animated
ARCHIVE      E:\Hermes\Output\PPLG\SQL Vault release v.1     (contains the 9 enemy/NPC scenes; do not edit)
GODOT BIN    C:\Users\M.Fajar\OneDrive\Desktop\Godot_v4.7.2-stable_win64.exe
ENGINE       Godot 4.7.2, Forward Plus, GDScript
MAIN SCENE   res://scenes/floors/floor_1_dungeon.tscn
TILE SIZE    16 x 16
SHELL        Windows 11, PowerShell. No bash. Python 3 + Pillow available.
```

---

## 2. VERIFIED WORKING (do not rebuild, do not "improve")

### 2.1 SQL engine — `scripts/sql/` (1135 lines total)

| File | Lines | What it does |
|---|---|---|
| `query_engine.gd` | 965 | tokenizer + executor: `CREATE/ALTER/DROP TABLE`, `INSERT/UPDATE/DELETE`, `SELECT` (columns, `WHERE` with `= != < > <= >= AND OR LIKE BETWEEN IN`, `ORDER BY`, `LIMIT`, aggregates `COUNT/SUM/AVG/MIN/MAX`), `GRANT/REVOKE` + per-user permissions. Unsupported clauses (e.g. `JOIN`) return a readable Indonesian error |
| `query_judge.gd` | 170 | `judge_select()` result-set comparison; `judge_terminal()` evaluates `target_conditions` (`table_exists`, `columns`, `column_type`, …) |
| `sql_sandbox.gd` | 278 | dev harness + 25-case regression suite |

**Measured:** sandbox suite **25/25 PASS**, including 4 negative cases (wrong row count, reversed
`ORDER BY`, wrong column names, `JOIN` rejected) and 4 syntax errors.
**Measured:** all **12** terminal specs in `data/levels.json` reach `ok=true` when executed with their own
`expected_sql` against their `initial_db_state`.

### 2.2 Progression gating — verified live on floor 1

```
before solve: pulled=0  label=SELESAIKAN SOAL DAHULU
after  solve: pulled=1  label=TUAS AKTIF
```
`GameManager.mark_terminal_solved(lever_id, xp, crystals)` emits `terminal_solved(lever_id)`;
`lever.gd` refuses to pull until its terminal is solved. `mark_terminal_solved()` also **refills energy**,
which removes the softlock risk.

### 2.3 Content — `data/levels.json`

12 terminals: floor 1 ×2 (`1:Lever`, `1:Lever2`), floor 2 ×3, floor 3 ×3, floor 4 ×3, floor 5 ×1 (`5:Final`).
Each spec carries `question`, `hint`, `expected_sql`, `expected_rows`, `schema`, `target_conditions`,
`initial_db_state`, `reward{xp,crystals}`, `quick_tokens`, `terminal_cell`, `target_item`.

### 2.4 UI — instances placed and working

| Scene | Placed on | Verified |
|---|---|---|
| `exploration_hud.tscn` | all 8 floors | 9 labels (`FloorLabel, HPLabel, EnergyLabel, CoinLabel, CrystalLabel, KeyLabel, XPLabel, LeverLabel, ToastLabel`) + `EnergyBar` ProgressBar. `take_damage(1)` → `HPLabel` went `3/3` → `2/3` |
| `bengkel_query_ui.tscn` | all 8 floors | `terminal.interact()` → `visible=false` → `true` |
| `shop_ui.tscn` | all 8 floors | items: sword 20, boots 15, key 10, hint 5, crystal→HP exchange |
| `sql_terminal.tscn` | floors 1–4 (2/3/3/3 = **11**) | opens the query UI |
| `npc_merchant.tscn` | floor_1, floor_3 | opens shop |
| `breakable_box.tscn` | floors 1–4 (**4 each = 16**) | `SwordHitbox` mask 16 matches `Hurtbox` layer 16 |

### 2.5 Shop effects are real, not cosmetic

`scripts/player.gd` reads the flags: `_get_speed()` → `BOOTS_SPEED` when `has_speed_boots`;
`_get_sword_damage()` → `3` when `sword_upgraded`; attack duration shortens accordingly.
Secret doors: `requires_key = true` on all 3 (`floor_2 Secret1`, `floor_3 Secret1`, `floor_3 Secret2`);
`GameManager.unlock_secret_door()` **consumes** one `special_keys`.

### 2.6 Reachability — audited, all 8 scenes pass

Set-based flood fill from each Player spawn (floor cells minus wall cells):

| Scene | reachable / walkable | interactables | unreachable |
|---|---|---|---|
| floor_1_dungeon | 362 / 362 | 10 | 0 |
| floor_2_dungeon | 517 / 520 | 13 | 0 |
| floor_2_secret | 204 / 204 | 1 | 0 |
| floor_3_catacomb | 1065 / 1065 | 15 | 0 |
| floor_3_secret1 | 323 / 323 | 1 | 0 |
| floor_3_secret2 | 170 / 170 | 1 | 0 |
| floor_4_catacomb | 801 / 801 | 12 | 0 |
| floor_5_ground | 1555 / 1555 | 2 | 0 |

All **55** interactables (levers, terminals, boxes, merchants, doors) are reachable. Floor_2's 3-cell
difference is the closed door `Block` + lever bodies, not a severed wing.

---

## 3. WHAT IS MISSING

### 3.1 Floor 5 cannot be completed  ← the only thing blocking "finishable"

Two defects, both on `floor_5_ground.tscn`:

1. `Main_Door` has `starts_open = true` and **`next_floor_path = ""`** → `interact()` only calls
   `push_warning`. There is no ending scene.
2. `data/levels.json` defines a `5:Final` terminal, but **floor_5 has no `sql_terminal.tscn` instance and
   no lever**. The final SQL challenge is orphaned content.

### 3.2 No enemies at all

`scenes/entities/` in this project contains only `player.tscn`. The 9 enemy/NPC scenes exist **only** in
`E:\Hermes\Output\PPLG\SQL Vault release v.1\scenes\entities\`:

`goblin_scout`, `goblin_ward`, `skeleton_walker`, `cultist`, `mushroom_man` (monsters) ·
`trader` (NPC) · `jar_explorer`, `king_jey`, `mikael` (custom NPCs from the user's own sprite sheets).

They are `CharacterBody2D + AnimatedSprite2D + CollisionShape2D`, **no script**, default layers `1/1`.
Their custom sprite sheets (`Sprite_Sheet_Idle_Pria…`, `Sprite_Pixel_Enam_Bingkai…`,
`Lembaran_Sprite_Pixel_Pria…`) are **also only in the archive folder**.

### 3.3 No menus / pause / save / audio / export

No `scenes/ui/main_menu`, no pause, no game-over, no `user://save.cfg`, no `AudioStreamPlayer`,
no `export_presets.cfg`, no `README.md` / credits, and the Valley Ruin pack still has no license file.

---

## 4. REMAINING PHASES

### PHASE A — Make the game finishable (~1 session)

1. **Place the final terminal.** Instance `sql_terminal.tscn` into `floor_5_ground.tscn` `YSortObjects`
   at a reachable cell, set `floor_num = 5` and `lever_id = "5:Final"` (the spec already exists).
   Verify the cell is walkable (floor_5 has 1555 walkable cells, all reachable).
2. **Ending scene.** `scenes/ui/ending.tscn` + `ending.gd`:
   `CanvasLayer` → dark `ColorRect` → `VBoxContainer` with `LANTAI 5 SELESAI`, xp/rank/coins/crystals/
   keys/waktu, and `[E] Mulai Ulang`. On interact: `GameManager.reset_run()` then
   `change_scene_to_file("res://scenes/floors/floor_1_dungeon.tscn")`.
3. **`GameManager.finish_run()`** → `signal run_completed(stats: Dictionary)`; record `run_started_at`
   in `reset_run()`. Set floor_5 `Main_Door.next_floor_path = "res://scenes/ui/ending.tscn"`.
4. Gate it: the ending door should only open once `is_terminal_solved("5:Final")` is true — otherwise
   floor 5 is a free win.

Assert: `5:Final` terminal instance exists in floor 5 and is reachable; door target resolves and the file
loads; `ending.tscn` renders real GameManager values; E returns to floor 1 with state reset; before
solving `5:Final` the door refuses with a visible reason.

### PHASE B — Enemies + boss (~2 sessions)

1. **Copy** the 9 entity `.tscn` files and the 3 custom sprite sheets from the archive into this project
   (`scenes/entities/`, `assets/sprites/`). Do not modify the archive.
2. **One `scripts/enemy.gd`** attached to the 5 monsters:
   - `@export` per-scene: `max_hp`, `contact_damage`, `aggro_radius`, `speed`, `coin_drop`
   - patrol between waypoints, chase inside `aggro_radius`, `take_hit(dmg)` (already how
     `player.gd` calls it: `target.take_hit(_get_sword_damage())`)
   - a `Hurtbox` `Area2D` on **layer 16** (matches `SwordHitbox` mask 16 — same as `breakable_box`)
   - contact damage → `GameManager.take_damage(contact_damage)`
3. **Player damage response is missing:** there is no player hurtbox and no invulnerability window, so
   contact damage would tick every physics frame. Add ~1 s i-frames + knockback + blink in
   `player.gd`, and assert measured damage per second.
4. **`trader`** → point at the existing `shop_ui.tscn` (reuse `npc_merchant.gd`; it already finds the
   shop UI). **`jar_explorer` / `king_jey` / `mikael`** → decide: lore/dialogue NPC or scenery. If
   dialogue, reuse the `prompt_text()` + `_physics_process` overlap pattern from `main_door.gd`.
5. **Boss on floor 5**: `boss_guardian.gd` exists in the archive (`SQL-Vault\scripts\entities\`) as a
   reference. Give it 2 phases, an HP bar in the HUD, and make `5:Final` unlockable only after it dies —
   or make the boss the reward for solving `5:Final`, whichever you decide (document the choice).

Assert: a monster dies in N hits and awards coins; player loses at most 1 HP per i-frame window;
`player_died` → game over scene → restart same floor with xp intact; boss death unlocks the ending.

### PHASE C — Menus, pause, save (~1–2 sessions)

Main menu (`Mulai` / `Lanjut` / `Keluar`), level select gated by progress, ESC pause that freezes the
tree, settings (volume, fullscreen), and `user://save.cfg` persisting floor, xp, coins, crystals, keys,
`has_speed_boots`, `sword_upgraded`, `solved_terminals`, `pulled_lever_ids`, `levers_pulled`,
`unlocked_secret_doors`. `reset_run()` already clears all of it.

Assert: play → save → quit → relaunch → Continue restores the exact state; pause halts enemy movement.

### PHASE D — Ship (~1 session)

Windows export preset + test the **exported** build. Audio: 1 BGM loop + lever/door/hit/SQL-error SFX
(CC0: Kenney Interface Sounds, Kenney RPG Audio, "Loopable Dungeon Ambience"). `README.md` with controls
(`WASD`, `J`/LMB attack, `E` interact) and per-pack credits. Replace the Valley Ruin tiles or document
that their rights are unproven.

---

## 5. Verification harness

Headless stdout from `--script` is buffered and lost if the process is killed. Write to a file, flush per
line:

```gdscript
extends SceneTree
var f: FileAccess
func w(s: String) -> void:
    f.store_line(s); f.flush()

func _initialize() -> void:
    f = FileAccess.open("E:/HermesData/cache/scratch/probe.txt", FileAccess.WRITE)
    await process_frame
    # ... measure ...
    f.close()
    quit()
```

Run: `Godot_v4.7.2-stable_win64.exe --headless --path "<PROJECT>" --script res://_probe.gd`

**Two measured traps:**

- Do **not** flood-fill with a `PhysicsPointQueryParameters2D` per cell on floors 3–5 — it exceeded a
  300 s timeout. Use set membership instead: `floor_cells.has(c) and not wall_cells.has(c)`. That runs
  all 8 scenes in ~2 s.
- Do **not** call `change_scene_to_file` inside a `--script` run — it frees the nodes the script holds and
  the run dies before `quit()`, which looks like a hang.

Delete every temp script/scene (`.gd`, `.tscn`, `.uid`) when done.

---

## 6. REPORT BACK

Files changed, pasted PASS/FAIL lines, any number that differs from §2 (say which and why), and what you
could not do. **Stop at the end of the phase you were given.**

---

## 7. Anti-instructions

1. **Do not rebuild the SQL engine, judge, HUD, shop, or terminals.** 25/25 suite passes, 12/12 specs
   pass, HUD and shop are live on all 8 floors. §2 lists every file.
2. **Do not re-add Player instances, wall collision, door wiring, breakable boxes, or merchant
   instances.** All placed and verified reachable.
3. **Do not change `spawn_offset`.** `(0,0)` is correct — every scene authors its Player on its own
   return door; measured arrival error 0.00–9.07 px, always on a walkable cell.
4. **Do not add a 3rd lever to floor 1.** `levers_needed(1) == 2`.
5. **Do not treat `5:Final` as done because it exists in `levels.json`.** It has no scene instance.
6. **Do not ship a door with an empty `next_floor_path`.** That is exactly floor 5's defect today.
7. **Do not use a distance check for an interaction prompt.** `main_door.gd`, `lever.gd`,
   `sql_terminal.gd` and `npc_merchant.gd` all use the player's `InteractionArea` overlap; copy that
   pattern.
8. **Do not edit `E:\Hermes\Output\PPLG\SQL Vault release v.1`** — copy out of it.
