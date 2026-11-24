# Player animation — SQL Vault (level-art build)

## What was added
| File | Purpose |
|---|---|
| `assets/sprites/player_walk.png` | 12 cols x 4 rows of 48px frames (down, left, right, up) |
| `assets/sprites/player_attack.png` | 4 cols x 4 rows of 48px frames (down, left, right, up) |
| `resources/player_frames.tres` | `SpriteFrames` — 12 animations (walk/idle/attack x 4 directions) |
| `scenes/entities/player.tscn` | rebuilt: sprites, collisions, camera, fixed `SwordHitbox` node name |
| `scripts/player.gd` | walk/idle/attack state machine |
| `tools/build_player_frames.py` | regenerates both sheets from the DampDungeons source |
| `preview/` | in-game GIFs, stills, frame contact sheet |

## Source art
Walking comes from `Dungeon_HeroMan1.png` (288x256), bands 0-3, 12 frames each
(down, left, right, up).

Attacks come from `Dungeon_HeroManSword1.png` (188x252), 4 bands, 4 frames each
(down, left, right, up) — a real sword with a pale slash arc.

Do NOT use HeroMan1 bands 4-7 for attacks: that is a PICKAXE swing (straight
shaft with a curved head, vertical chop), not a blade. Those 24 frames are still
in the pack and would suit a "break the box" action if you want one later.

The pack is exported with per-frame trimming, so the frames are NOT on a uniform
grid (horizontal pitch alternates 24/25px). `tools/build_player_frames.py` finds
every frame by scanning alpha and repacks it into a 48x48 cell, anchored so the
feet sit at `(24, 46)`. That is why the scene uses `offset = (0, -21)`.

Do not slice the original sheet on a 32px grid — frames will be cut in half.

## Regenerating
```
python tools/build_player_frames.py
```
Then re-open the project in Godot (or run `--headless --import`) so the PNGs re-import.

## Animation names
`walk_down|left|right|up` (12f @ 12 fps, loop), `idle_*` (1 frame), `attack_*` (4f @ 20 fps).
The attack speed matches `ATTACK_DURATION = 0.2 s`; `ATTACK_FRAMES`/`ATTACK_BASE_FPS`
in `player.gd` must be updated together with the frame count if you change it.
`player.gd` switches on `last_facing_direction`; the attack clip's `speed_scale` is
derived from `ATTACK_DURATION` so the swing stays in sync with the sword hitbox
window (and with the faster upgraded sword).

## Reusing this for enemies
`Dungeon_Monsters1.png`, `Dungeon_Monsters2.png` and `Dungeon_Slimes1.png` use the
same band layout (4 walk bands + 4 more), so the same script works after changing
`SRC` and the band table. `Slimes1` rows 4-7 are wide multi-frame blobs — keep 8
columns there.

## Still missing on the floors
Levers and doors have no scripts attached, there is no SQL terminal, no HUD and no
enemy placement. The player can walk and swing, but nothing in the map reacts yet.
