#!/usr/bin/env python3
"""Build native 16x16 Prism Grotto objects for 2D and voxel rendering.

The approved concept sheet remains the visual source, but the shipped objects
are authored pixel-for-pixel.  Downscaling an illustrated pillar to one Gen I
overworld cell made the six glyphs unreadable after voxel extrusion.
"""

from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets/prism_grotto"

DARK = (7, 18, 39, 255)
INK = (4, 65, 111, 255)
SHADOW = (5, 132, 174, 255)
MID = (45, 190, 224, 255)
GLASS = (151, 231, 247, 255)
LIGHT = (240, 253, 255, 255)

# Each mark uses most of the pillar face.  It intentionally favours a bold
# silhouette over fine detail so it survives the 2D, true-colour and voxel
# pipelines at native resolution.
GLYPHS = {
    "sun": (
        "...#...",
        ".#.#.#.",
        "..###..",
        "#.###.#",
        "..###..",
        ".#.#.#.",
        "...#...",
    ),
    "moon": (
        "..####.",
        ".##....",
        "##.....",
        "##.....",
        "##.....",
        ".##....",
        "..####.",
    ),
    "wave": (
        ".......",
        ".##..##",
        "#..##..",
        ".......",
        ".##..##",
        "#..##..",
        ".......",
    ),
    "crown": (
        ".......",
        "#..#..#",
        ".#.#.#.",
        ".#####.",
        ".#...#.",
        ".#####.",
        ".......",
    ),
    "dragon": (
        "...#.#.",
        "..####.",
        ".##o#..",
        "###.##.",
        ".##....",
        "..####.",
        "....##.",
    ),
    "gear": (
        "..###..",
        ".#.#.#.",
        "##...##",
        ".#...#.",
        "##...##",
        ".#.#.#.",
        "..###..",
    ),
}


def px(draw, box, fill):
    draw.rectangle(box, fill=fill)


def pillar(glyph):
    image = Image.new("RGBA", (16, 16))
    draw = ImageDraw.Draw(image)

    # A pointed crystal monolith reads as an ancient object rather than a
    # framed display.  Its broad pale centre leaves the outlined rune alone.
    draw.polygon(
        [(6, 0), (9, 0), (14, 5), (13, 12), (15, 14),
         (14, 15), (1, 15), (0, 14), (2, 12), (1, 5)],
        fill=DARK,
    )
    draw.polygon(
        [(7, 1), (8, 1), (13, 5), (12, 12), (3, 12),
         (2, 5)],
        fill=GLASS,
    )
    draw.line([(7, 1), (4, 5), (4, 11)], fill=LIGHT, width=1)
    draw.line([(9, 2), (12, 5), (11, 11)], fill=MID, width=1)
    px(draw, (3, 13, 12, 14), GLASS)
    px(draw, (4, 13, 5, 14), LIGHT)
    px(draw, (10, 13, 11, 14), SHADOW)

    glyph_height = len(glyph)
    glyph_width = max(len(row) for row in glyph)
    x_offset = (16 - glyph_width) // 2
    y_offset = 5 + (7 - glyph_height) // 2
    for y, row in enumerate(glyph):
        for x, mark in enumerate(row):
            if mark == "#":
                draw.point((x_offset + x, y_offset + y), fill=INK)
            elif mark == "o":
                draw.point((x_offset + x, y_offset + y), fill=LIGHT)
    return image


def seam():
    image = Image.new("RGBA", (16, 16))
    draw = ImageDraw.Draw(image)
    # One broken crystal face with a broad, jagged black opening.  It matches
    # the pointed monolith family without looking like a constructed doorway.
    draw.polygon(
        [(5, 0), (10, 0), (15, 4), (14, 12), (11, 15),
         (8, 14), (4, 15), (0, 12), (1, 4)],
        fill=DARK,
    )
    draw.polygon(
        [(6, 1), (9, 1), (14, 5), (13, 11), (10, 14),
         (8, 13), (5, 14), (1, 11), (2, 5)],
        fill=GLASS,
    )
    draw.line([(5, 2), (3, 5), (3, 10), (5, 12)], fill=LIGHT, width=1)
    draw.line([(10, 2), (13, 5), (12, 10)], fill=MID, width=1)
    # The fissure widens toward the bottom so it reads as a passage, not a
    # decorative rune.  Small branches make the glass visibly fractured.
    draw.polygon(
        [(8, 1), (6, 4), (8, 6), (6, 9), (8, 11), (6, 15),
         (11, 15), (9, 12), (11, 9), (9, 6), (10, 3)],
        fill=DARK,
    )
    draw.line([(6, 5), (4, 4)], fill=INK, width=1)
    draw.line([(10, 8), (13, 7)], fill=INK, width=1)
    draw.line([(7, 11), (4, 12)], fill=INK, width=1)
    draw.line([(8, 2), (8, 5)], fill=INK, width=1)
    return image


def tablet():
    image = Image.new("RGBA", (16, 16))
    draw = ImageDraw.Draw(image)
    # A full-cell, chipped crystal inscription slab.  Its one asymmetrical
    # spiral reads as an ancient carving rather than a modern keypad.
    draw.polygon(
        [(3, 0), (12, 0), (15, 3), (14, 13), (11, 15),
         (2, 15), (0, 12), (1, 3)],
        fill=DARK,
    )
    draw.polygon(
        [(4, 1), (11, 1), (14, 4), (13, 12), (10, 14),
         (3, 14), (1, 11), (2, 4)],
        fill=GLASS,
    )
    draw.line([(3, 3), (4, 2), (7, 2)], fill=LIGHT, width=1)
    draw.line([(12, 4), (13, 6), (12, 9)], fill=MID, width=1)
    # Square-pixel spiral, deliberately open at the bottom.
    draw.line(
        [(4, 5), (5, 4), (9, 4), (11, 6), (11, 10),
         (9, 12), (6, 12), (4, 10), (4, 7), (6, 5),
         (9, 5), (10, 7), (10, 9), (8, 10), (6, 9),
         (6, 7), (8, 6), (9, 7)],
        fill=INK,
        width=1,
    )
    draw.line([(2, 11), (4, 13)], fill=SHADOW, width=1)
    draw.point((12, 12), fill=SHADOW)
    return image


def checker_preview(sprites):
    scale = 12
    width = len(sprites) * 20 * scale
    preview = Image.new("RGBA", (width, 20 * scale), (30, 34, 52, 255))
    draw = ImageDraw.Draw(preview)
    for index, (_, sprite) in enumerate(sprites):
        x0 = index * 20 * scale
        for y in range(20):
            for x in range(20):
                shade = 54 if (x // 4 + y // 4) % 2 else 72
                draw.rectangle(
                    (
                        x0 + x * scale,
                        y * scale,
                        x0 + (x + 1) * scale - 1,
                        (y + 1) * scale - 1,
                    ),
                    fill=(shade, shade + 5, shade + 15, 255),
                )
        preview.alpha_composite(
            sprite.resize((16 * scale, 16 * scale), Image.Resampling.NEAREST),
            (x0 + 2 * scale, 2 * scale),
        )
    return preview


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    sprites = [("seam", seam())]
    sprites.extend((name, pillar(glyph)) for name, glyph in GLYPHS.items())
    sprites.append(("tablet", tablet()))
    for name, sprite in sprites:
        sprite.save(OUT / f"prism_{name}.png", optimize=False)
    checker_preview(sprites).save(
        OUT / "prism_objects_preview.png", optimize=False
    )


if __name__ == "__main__":
    main()
