#!/usr/bin/env python3
"""Rebuild the player sprite sheets from the DampDungeons HeroMan source.

The source sheet (assets/tilesets/DampDungeons/Animations/Dungeon_HeroMan1.png)
was exported by Aseprite with per-frame trimming, so frames are NOT on a
uniform grid: vertical pitch is 32px, horizontal pitch alternates 24/25px.
Slicing it on a 32x32 grid cuts frames in half.

This script detects every frame by scanning alpha, then repacks them onto a
clean uniform CELL x CELL grid, anchored by the feet so the character does not
wobble and so the sword swing keeps its reach.

Output (CELL = 48 px):
  assets/sprites/player_walk.png    12 cols x 4 rows  (down, left, right, up)
  assets/sprites/player_attack.png   4 cols x 4 rows  (down, left, right, up)
                                     from Dungeon_HeroManSword1.png, NOT the
                                     pickaxe bands 4-7 of HeroMan1

Anchor inside a cell: feet centre at (CELL/2, CELL - FOOT_MARGIN).
In the scene the AnimatedSprite2D offset is (0, -(CELL - FOOT_MARGIN - CELL/2)).
"""
from PIL import Image, ImageDraw
import os
import sys

CELL = 48
FOOT_MARGIN = 2
FEET_ROWS = 8

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WALK_SRC = os.path.join(ROOT, "assets", "tilesets", "DampDungeons", "Animations",
                     "Dungeon_HeroMan1.png")
# Bands 4-7 of HeroMan1 are a PICKAXE swing (shaft + curved head), not a sword.
# The sword swing lives in its own sheet: 4 bands x 4 frames, same direction order.
ATTACK_SRC = os.path.join(ROOT, "assets", "tilesets", "DampDungeons", "Animations",
                          "Dungeon_HeroManSword1.png")
SRC = WALK_SRC
OUT_DIR = os.path.join(ROOT, "assets", "sprites")


def runs(flags, min_gap=3):
    out, start, gap = [], None, 0
    for i, v in enumerate(flags):
        if v:
            if start is None:
                start = i
            gap = 0
        elif start is not None:
            gap += 1
            if gap >= min_gap:
                out.append((start, i - gap))
                start, gap = None, 0
    if start is not None:
        out.append((start, len(flags) - 1))
    return out


def detect_bands(img):
    px = img.load()
    W, H = img.size
    row_any = [any(px[x, y][3] > 10 for x in range(W)) for y in range(H)]
    bands = []
    for y0, y1 in runs(row_any, min_gap=3):
        sub = img.crop((0, y0, W, y1 + 1))
        spx = sub.load()
        col_any = [any(spx[x, y][3] > 10 for y in range(sub.height)) for x in range(W)]
        bands.append((y0, y1, runs(col_any, min_gap=3)))
    return bands


def feet_centre(frame):
    bbox = frame.getbbox()
    if not bbox:
        return frame.width / 2.0
    x0, y0, x1, y1 = bbox
    feet = frame.crop((0, max(y0, y1 - FEET_ROWS), frame.width, y1))
    b = feet.getbbox()
    if not b:
        return (x0 + x1) / 2.0
    return (b[0] + b[2]) / 2.0


def repack(img, bands, cols, name):
    rows = len(bands)
    sheet = Image.new("RGBA", (cols * CELL, rows * CELL), (0, 0, 0, 0))
    for r, (y0, y1, rects) in enumerate(bands):
        for c, (x0, x1) in enumerate(rects[:cols]):
            frame = img.crop((x0, y0, x1 + 1, y1 + 1))
            cx = feet_centre(frame)
            dx = int(round(CELL / 2.0 - cx))
            dy = CELL - FOOT_MARGIN - frame.height
            if dx < 0 or dy < 0 or dx + frame.width > CELL:
                print("  !! overflow band %d col %d (%dx%d at %d,%d)"
                      % (r, c, frame.width, frame.height, dx, dy), file=sys.stderr)
            sheet.alpha_composite(frame, (c * CELL + max(dx, 0), r * CELL + max(dy, 0)))
    path = os.path.join(OUT_DIR, name)
    sheet.save(path)
    print("  wrote %s  %dx%d" % (os.path.relpath(path, ROOT), sheet.width, sheet.height))
    return path


def preview(items, out_path):
    pad, label_h = 6, 16
    max_cols = max(len(b[2]) for _, bands, _ in items for b in bands)
    rows_total = sum(len(bands) for _, bands, _ in items)
    w = pad + max_cols * (CELL + pad)
    h = pad + rows_total * (CELL + pad + label_h)
    img = Image.new("RGB", (w, h), (26, 28, 34))
    d = ImageDraw.Draw(img)
    y = pad
    for path, bands, tag in items:
        sheet = Image.open(path).convert("RGBA")
        for r in range(len(bands)):
            d.text((pad, y + 2), "%s band%d (%d frames)" % (tag, r, len(bands[r][2])),
                   fill=(255, 214, 96))
            y += label_h
            for c in range(len(bands[r][2])):
                frame = sheet.crop((c * CELL, r * CELL, (c + 1) * CELL, (r + 1) * CELL))
                img.paste(frame, (pad + c * (CELL + pad), y), frame)
            y += CELL + pad
    img.save(out_path)
    print("  wrote %s  %dx%d" % (out_path, img.width, img.height))


def main():
    if not os.path.exists(SRC):
        sys.exit("source sheet missing: %s" % SRC)
    os.makedirs(OUT_DIR, exist_ok=True)
    walk_img = Image.open(WALK_SRC).convert("RGBA")
    walk_bands = detect_bands(walk_img)[:4]
    attack_img = Image.open(ATTACK_SRC).convert("RGBA")
    attack_bands = detect_bands(attack_img)
    for name, im, bands in (("walk", walk_img, walk_bands), ("attack", attack_img, attack_bands)):
        print("source [%s] %dx%d: %d bands" % (name, im.width, im.height, len(bands)))
        for i, (y0, y1, rects) in enumerate(bands):
            print("  band%d: y%d-%d  %d frames" % (i, y0, y1, len(rects)))
    walk = repack(walk_img, walk_bands, 12, "player_walk.png")
    attack = repack(attack_img, attack_bands, 4, "player_attack.png")
    scratch = os.environ.get("PREVIEW_DIR", "")
    if scratch:
        preview([(walk, walk_bands, "walk"), (attack, attack_bands, "attack")],
                os.path.join(scratch, "player_frames_preview.png"))
    print("done")


if __name__ == "__main__":
    main()
