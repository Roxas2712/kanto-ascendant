#!/usr/bin/env python3
"""Build the authored RED basalt tileset used by Kanto Ascendant 6.5.

The palette is sampled by eye from the checked-in RBY CAVERN sheet, then
expanded into original low-noise basalt, ember, water and abyss motifs.  No
third-party bitmap is embedded.  Output is deterministic and nearest-neighbour
pixel art; the Lua metatile table owns collision and Voxel semantics.
"""
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets/hidden_evolution/red_basalt_tileset.png"
TILE = 8
COLS, ROWS = 16, 12

P = {
    "void": (12, 9, 13, 255), "void2": (20, 13, 18, 255),
    "floor": (54, 39, 39, 255), "floor2": (64, 45, 42, 255),
    "stone": (83, 57, 50, 255), "stone_hi": (111, 73, 59, 255),
    "ember": (209, 79, 39, 255), "ember_hi": (255, 153, 68, 255),
    "cliff": (34, 22, 26, 255), "cliff2": (46, 28, 29, 255),
    "ridge": (117, 69, 51, 255), "ridge_hi": (168, 102, 67, 255),
    "water": (12, 25, 34, 255), "water2": (22, 48, 61, 255),
    "water_hi": (49, 83, 91, 255), "rune": (242, 161, 73, 255),
}


def tile_base(color):
    return Image.new("RGBA", (TILE, TILE), color)


def floor_variant(seed):
    im = tile_base(P["floor"] if seed % 2 == 0 else P["floor2"])
    d = ImageDraw.Draw(im)
    # Sparse two-pixel mineral marks: low contrast and four authored phases.
    marks = [((1, 2), (2, 2)), ((5, 5), (6, 5)), ((4, 1), (4, 2))]
    for i, (a, b) in enumerate(marks):
        if (i + seed) % 3 != 1:
            d.point([a, b], fill=P["stone"])
    if seed == 3:
        d.point([(1, 6), (2, 6)], fill=P["stone_hi"])
    return im


def cliff_cap(phase):
    im = tile_base(P["void2"])
    d = ImageDraw.Draw(im)
    d.rectangle((0, 3, 7, 7), fill=P["cliff"])
    d.line((0, 3, 7, 3), fill=P["ridge_hi"])
    d.line((0, 4, 7, 4), fill=P["ridge"])
    d.point([(1 + phase * 3, 5), (5 - phase, 6)], fill=P["cliff2"])
    return im


def cliff_face(phase):
    im = tile_base(P["cliff"])
    d = ImageDraw.Draw(im)
    d.line((phase + 1, 0, phase, 7), fill=P["cliff2"])
    d.line((6 - phase, 1, 5 - phase, 6), fill=P["ridge"])
    d.point([(2, 2 + phase), (7, 6 - phase)], fill=P["ridge_hi"])
    return im


def water_variant(phase):
    im = tile_base(P["water"] if phase != 1 else P["water2"])
    d = ImageDraw.Draw(im)
    y = 2 + phase
    d.line((0, y, 3, y), fill=P["water_hi"])
    d.line((5, 6 - phase, 7, 6 - phase), fill=P["water2"])
    return im


def rune_tile(hole=False):
    im = floor_variant(1)
    d = ImageDraw.Draw(im)
    if hole:
        d.ellipse((1, 1, 6, 6), fill=P["void"])
        d.point([(2, 1), (5, 2), (1, 5), (6, 5)], fill=P["ridge_hi"])
    else:
        d.line((3, 1, 6, 4), fill=P["rune"])
        d.line((6, 4, 3, 7), fill=P["rune"])
        d.point((2, 4), fill=P["ember_hi"])
    return im


def accent(kind):
    im = floor_variant(kind % 4)
    d = ImageDraw.Draw(im)
    if kind == 0:  # ember crack
        d.line((0, 7, 3, 4, 5, 4, 7, 1), fill=P["ember"])
        d.point((3, 4), fill=P["ember_hi"])
    elif kind == 1:  # relief line
        d.line((0, 1, 7, 1), fill=P["stone_hi"])
        d.line((1, 3, 6, 3), fill=P["stone"])
    elif kind == 2:  # dais quarter
        d.rectangle((1, 1, 7, 7), outline=P["ridge"])
        d.point((4, 4), fill=P["ember_hi"])
    elif kind == 3:  # pebble
        d.rectangle((2, 4, 4, 5), fill=P["stone"])
    elif kind == 4:  # shadow
        d.rectangle((0, 6, 7, 7), fill=P["void2"])
    elif kind == 5:  # edge marker
        d.line((0, 0, 7, 0), fill=P["ridge"])
    elif kind == 6:  # ladder/rung marker
        d.line((2, 0, 2, 7), fill=P["ridge_hi"])
        d.line((5, 0, 5, 7), fill=P["ridge_hi"])
        for y in (1, 4, 7): d.line((2, y, 5, y), fill=P["stone_hi"])
    elif kind == 7:  # broad bridge slab
        d.line((0, 0, 7, 0), fill=P["stone_hi"])
        d.line((0, 7, 7, 7), fill=P["void2"])
    elif kind == 8:  # reflected ember
        d.line((1, 2, 3, 2), fill=P["ember"])
        d.point((2, 3), fill=P["ember_hi"])
    else:  # scar
        d.line((1, 6, 3, 3, 6, 2), fill=P["stone_hi"])
    return im


tiles = [
    tile_base(P["void"]),
    floor_variant(0), floor_variant(1), floor_variant(2), floor_variant(3),
    cliff_cap(0), cliff_cap(1), cliff_face(0), cliff_face(1),
    water_variant(0), water_variant(1), water_variant(2),
    rune_tile(False), rune_tile(True),
]
tiles.extend(accent(i) for i in range(10))

atlas = Image.new("RGBA", (COLS * TILE, ROWS * TILE), (0, 0, 0, 0))
for idx, im in enumerate(tiles):
    atlas.alpha_composite(im, ((idx % COLS) * TILE, (idx // COLS) * TILE))
OUT.parent.mkdir(parents=True, exist_ok=True)
atlas.save(OUT, optimize=False)
print(OUT)
