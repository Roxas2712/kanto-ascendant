#!/usr/bin/env python3
"""Author original four-shade Mega battle sprites from pixel primitives.

The image generator refused the direct character-reference conversion, so
these assets deliberately use the repository's provenance-safe primitive
pipeline: 28x28 drawings, four grayscale shades and nearest-neighbour 2x.
They are original reductions guided only by the forms' public silhouettes.
"""

from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "mega"
INK = (0, 0, 0, 255)
DARK = (85, 85, 85, 255)
LIGHT = (170, 170, 170, 255)
WHITE = (255, 255, 255, 255)


def canvas():
    image = Image.new("RGBA", (28, 28), (0, 0, 0, 0))
    return image, ImageDraw.Draw(image)


def poly(draw, points, fill=LIGHT):
    draw.polygon(points, fill=fill, outline=INK)


def oval(draw, box, fill=LIGHT):
    draw.ellipse(box, fill=fill, outline=INK)


def line(draw, points, fill=INK, width=1):
    draw.line(points, fill=fill, width=width)


def face(draw, back=False, y=9):
    if back:
        line(draw, [(12, y + 1), (14, y), (16, y + 1)], DARK, 2)
        return
    draw.point((11, y), fill=INK)
    draw.point((16, y), fill=INK)
    line(draw, [(13, y + 2), (14, y + 3), (15, y + 2)], INK)


def mega_raichu_x(back=False):
    image, d = canvas()
    # The independent twin tail-arms form the defining X silhouette.
    poly(d, [(10, 16), (5, 11), (3, 5), (5, 1), (7, 6), (7, 11), (12, 14)], DARK)
    poly(d, [(18, 16), (23, 11), (25, 5), (23, 1), (21, 6), (21, 11), (16, 14)], DARK)
    poly(d, [(3, 5), (5, 1), (7, 5), (6, 7), (4, 7)], WHITE)
    poly(d, [(21, 5), (23, 1), (25, 5), (24, 7), (22, 7)], WHITE)
    # Floating feet and compact body.
    oval(d, (9, 12, 19, 23), LIGHT)
    poly(d, [(10, 21), (8, 25), (12, 24)], DARK)
    poly(d, [(18, 21), (20, 25), (16, 24)], DARK)
    # Huge charged forearms.
    oval(d, (3, 13, 10, 20), DARK)
    oval(d, (18, 13, 25, 20), DARK)
    oval(d, (7, 5, 21, 16), LIGHT)
    poly(d, [(9, 8), (6, 3), (11, 5)], DARK)
    poly(d, [(19, 8), (22, 3), (17, 5)], DARK)
    poly(d, [(12, 5), (14, 0), (16, 5)], WHITE)
    oval(d, (11, 16, 17, 21), WHITE)
    face(d, back, 10)
    if back:
        line(d, [(14, 6), (14, 20)], DARK, 2)
    return image


def mega_raichu_y(back=False):
    image, d = canvas()
    # Fast, upright body with horn-like crown and a long lightning tail.
    line(d, [(18, 18), (24, 15), (21, 12), (26, 8)], INK, 2)
    poly(d, [(24, 16), (20, 14), (23, 11), (20, 10), (27, 6),
             (24, 12), (27, 14)], DARK)
    oval(d, (9, 11, 18, 24), LIGHT)
    poly(d, [(10, 22), (8, 27), (12, 25)], DARK)
    poly(d, [(17, 22), (20, 26), (16, 25)], DARK)
    line(d, [(10, 15), (5, 11), (6, 18)], DARK, 2)
    line(d, [(18, 15), (22, 10), (22, 17)], DARK, 2)
    oval(d, (7, 4, 21, 16), LIGHT)
    poly(d, [(9, 7), (5, 1), (11, 4)], DARK)
    poly(d, [(19, 7), (23, 1), (17, 4)], DARK)
    # Three swept lightning horns make Y distinct from normal Raichu.
    poly(d, [(11, 5), (10, 0), (14, 4)], WHITE)
    poly(d, [(14, 4), (15, 0), (17, 5)], WHITE)
    poly(d, [(16, 5), (20, 1), (18, 7)], WHITE)
    oval(d, (11, 16, 17, 22), WHITE)
    face(d, back, 9)
    if back:
        line(d, [(14, 5), (14, 22)], DARK, 2)
    return image


def save_pair(name, renderer):
    for side, back in (("front", False), ("back", True)):
        sprite = renderer(back).resize((56, 56), Image.Resampling.NEAREST)
        sprite.save(OUT / f"{name}_{side}.png", optimize=True)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    save_pair("mega_raichu_x", mega_raichu_x)
    save_pair("mega_raichu_y", mega_raichu_y)
    print("generated 4 original four-shade Mega Raichu battle sprites")


if __name__ == "__main__":
    main()
