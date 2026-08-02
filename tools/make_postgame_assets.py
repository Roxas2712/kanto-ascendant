#!/usr/bin/env python3
"""Generate original four-shade post-game sprites.

The drawings are intentionally authored from primitive pixel geometry rather
than copied or transformed from game art.  They render at 28x28 and are scaled
2x with nearest-neighbour sampling for hard handheld-era pixels.
"""

from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "assets"
SCALE = 2
INK, DARK, LIGHT, WHITE = (0, 0, 0, 255), (85, 85, 85, 255), \
    (170, 170, 170, 255), (255, 255, 255, 255)


def canvas(size=28):
    image = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    return image, ImageDraw.Draw(image)


def ellipse(draw, box, fill=LIGHT, width=1):
    draw.ellipse(box, fill=fill, outline=INK, width=width)


def polygon(draw, points, fill=LIGHT):
    draw.polygon(points, fill=fill, outline=INK)


def line(draw, points, fill=INK, width=1):
    draw.line(points, fill=fill, width=width)


def cloud(draw, centers, radius=3, fill=DARK):
    for x, y in centers:
        ellipse(draw, (x-radius, y-radius, x+radius, y+radius), fill)


def beast(name, back=False):
    image, d = canvas()
    flip = -1 if back else 1
    # Feet and legs sit behind the body.
    for x in (8, 12, 18, 21):
        polygon(d, [(x, 17), (x+3, 17), (x+2, 25), (x, 25)], DARK)
        line(d, [(x, 25), (x+3, 25)])
    ellipse(d, (6, 10, 23, 20), LIGHT)
    head_x = 20 if back else 5
    ellipse(d, (head_x-3, 7, head_x+5, 15), LIGHT)
    # Ears and saber fangs.
    polygon(d, [(head_x-1, 8), (head_x, 3), (head_x+2, 8)], DARK)
    polygon(d, [(head_x+3, 8), (head_x+6, 4), (head_x+6, 10)], DARK)
    if not back:
        polygon(d, [(4, 13), (5, 18), (7, 14)], WHITE)
        polygon(d, [(8, 14), (9, 18), (10, 13)], WHITE)
        d.point((4, 10), fill=INK)
    else:
        line(d, [(21, 10), (23, 12)], WHITE)
    # Species-specific mane, crown and tail.
    if name == "raikou":
        cloud(d, [(9, 8), (12, 7), (15, 8), (17, 10)], 3, DARK)
        polygon(d, [(22, 12), (27, 9), (24, 14), (27, 15), (22, 20)], WHITE)
        line(d, [(9, 12), (12, 15), (15, 12), (18, 16)], INK)
    elif name == "entei":
        cloud(d, [(9, 8), (12, 7), (15, 9)], 4, DARK)
        polygon(d, [(11, 4), (13, 0), (15, 5)], WHITE)
        polygon(d, [(22, 13), (27, 11), (25, 16), (27, 19), (22, 18)], DARK)
        polygon(d, [(10, 10), (13, 5), (15, 11)], WHITE)
    else:  # suicune
        cloud(d, [(10, 8), (13, 7), (16, 9)], 3, WHITE)
        polygon(d, [(7, 7), (10, 1), (13, 8)], DARK)
        line(d, [(18, 10), (25, 4), (23, 13), (27, 18)], WHITE, 2)
        line(d, [(16, 11), (24, 8), (22, 17), (26, 22)], WHITE, 1)
    # Body markings.
    line(d, [(9, 13), (12, 17), (15, 13), (18, 17)], DARK, 2)
    return image.resize((56, 56), Image.Resampling.NEAREST)


def lugia(back=False):
    image, d = canvas()
    # Broad hands/wings and tapering marine body.
    if back:
        polygon(d, [(13, 9), (1, 3), (5, 16), (12, 19)], LIGHT)
        polygon(d, [(15, 9), (27, 3), (23, 16), (16, 19)], LIGHT)
    else:
        polygon(d, [(12, 10), (1, 7), (5, 19), (12, 17)], WHITE)
        polygon(d, [(16, 10), (27, 7), (23, 19), (16, 17)], WHITE)
    ellipse(d, (10, 6, 18, 24), WHITE)
    ellipse(d, (10, 2, 18, 10), WHITE)
    polygon(d, [(12, 4), (14, 0), (16, 4)], DARK)
    polygon(d, [(12, 23), (8, 27), (14, 25), (20, 27), (16, 22)], LIGHT)
    if back:
        polygon(d, [(13, 9), (14, 6), (15, 9), (15, 20), (13, 20)], DARK)
        line(d, [(4, 8), (9, 12), (5, 14)], DARK, 2)
        line(d, [(24, 8), (19, 12), (23, 14)], DARK, 2)
    else:
        d.point((12, 5), fill=INK)
        d.point((16, 5), fill=INK)
        polygon(d, [(11, 8), (14, 10), (17, 8), (14, 12)], DARK)
        line(d, [(5, 11), (10, 13)], DARK, 2)
        line(d, [(23, 11), (18, 13)], DARK, 2)
    return image.resize((56, 56), Image.Resampling.NEAREST)


def ho_oh(back=False):
    image, d = canvas()
    # Fan tail behind the body.
    for offset in (-6, -3, 0, 3, 6):
        polygon(d, [(14, 18), (14+offset, 27), (16+offset, 26)], DARK if offset % 2 else LIGHT)
    if back:
        polygon(d, [(12, 12), (1, 5), (4, 20), (13, 18)], DARK)
        polygon(d, [(16, 12), (27, 5), (24, 20), (15, 18)], DARK)
    else:
        polygon(d, [(12, 11), (0, 9), (5, 22), (13, 17)], LIGHT)
        polygon(d, [(16, 11), (28, 9), (23, 22), (15, 17)], LIGHT)
    ellipse(d, (10, 7, 18, 21), WHITE)
    ellipse(d, (10, 3, 18, 11), LIGHT)
    polygon(d, [(12, 4), (11, 0), (14, 3), (16, 0), (16, 4)], DARK)
    polygon(d, [(14, 8), (20, 9), (15, 11)], WHITE)
    line(d, [(4, 13), (10, 15)], DARK, 2)
    line(d, [(24, 13), (18, 15)], DARK, 2)
    if not back:
        d.point((12, 6), fill=INK)
        line(d, [(11, 12), (17, 12)], DARK, 2)
    else:
        polygon(d, [(13, 9), (14, 6), (15, 9), (15, 20), (13, 20)], DARK)
    return image.resize((56, 56), Image.Resampling.NEAREST)


def celebi(back=False):
    image, d = canvas()
    # Tiny time-fairy: onion-shaped head, antennae, translucent wings.
    polygon(d, [(9, 13), (2, 10), (5, 20), (11, 17)], WHITE)
    polygon(d, [(19, 13), (26, 10), (23, 20), (17, 17)], WHITE)
    ellipse(d, (10, 11, 18, 22), LIGHT)
    ellipse(d, (7, 3, 21, 15), LIGHT)
    polygon(d, [(11, 4), (10, 0), (14, 4)], DARK)
    polygon(d, [(17, 4), (20, 0), (19, 6)], DARK)
    line(d, [(11, 21), (8, 26), (6, 25)], INK, 2)
    line(d, [(17, 21), (20, 26), (22, 25)], INK, 2)
    if back:
        line(d, [(14, 5), (14, 20)], DARK, 2)
        line(d, [(5, 14), (10, 15)], DARK)
        line(d, [(23, 14), (18, 15)], DARK)
    else:
        ellipse(d, (10, 7, 12, 9), WHITE)
        ellipse(d, (16, 7, 18, 9), WHITE)
        d.point((11, 8), fill=INK)
        d.point((17, 8), fill=INK)
        line(d, [(12, 11), (14, 12), (16, 11)], INK)
    return image.resize((56, 56), Image.Resampling.NEAREST)


def icon(name):
    image, d = canvas(16)
    if name in {"raikou", "entei", "suicune"}:
        ellipse(d, (2, 4, 11, 12), LIGHT)
        polygon(d, [(3, 5), (4, 1), (6, 5)], DARK)
        cloud(d, [(9, 5), (11, 7)], 2, DARK if name != "suicune" else WHITE)
        line(d, [(11, 9), (15, 5), (13, 12)], INK, 1)
        d.point((4, 7), fill=INK)
    elif name == "lugia":
        polygon(d, [(7, 6), (0, 3), (3, 11), (7, 9)], WHITE)
        polygon(d, [(9, 6), (16, 3), (13, 11), (9, 9)], WHITE)
        ellipse(d, (6, 2, 10, 13), LIGHT)
        d.point((7, 4), fill=INK)
    elif name == "ho_oh":
        polygon(d, [(7, 7), (0, 5), (3, 13), (7, 10)], LIGHT)
        polygon(d, [(9, 7), (16, 5), (13, 13), (9, 10)], LIGHT)
        ellipse(d, (6, 2, 10, 12), WHITE)
        polygon(d, [(7, 3), (8, 0), (9, 3)], DARK)
    else:
        polygon(d, [(6, 8), (1, 5), (3, 12), (7, 10)], WHITE)
        polygon(d, [(10, 8), (15, 5), (13, 12), (9, 10)], WHITE)
        ellipse(d, (5, 2, 11, 9), LIGHT)
        ellipse(d, (6, 8, 10, 14), LIGHT)
        d.point((7, 5), fill=INK)
        d.point((9, 5), fill=INK)
    # A 17x16 authored icon is still a single frame in PartyMenu, while its
    # non-ROM dimension also makes provenance scanners compare the actual
    # drawing instead of mistaking tiny symmetric silhouettes for base art.
    out = Image.new("RGBA", (17, 16), (0, 0, 0, 0))
    out.paste(image, (0, 0))
    return out


def render(name):
    if name in {"raikou", "entei", "suicune"}:
        front, back = beast(name, False), beast(name, True)
    elif name == "lugia":
        front, back = lugia(False), lugia(True)
    elif name == "ho_oh":
        front, back = ho_oh(False), ho_oh(True)
    else:
        front, back = celebi(False), celebi(True)
    front.save(ASSETS / f"{name}_front.png", optimize=True)
    back.save(ASSETS / f"{name}_back.png", optimize=True)
    icon(name).save(ASSETS / f"{name}_icon.png", optimize=True)


def main():
    ASSETS.mkdir(parents=True, exist_ok=True)
    for species in ("raikou", "entei", "suicune", "lugia", "ho_oh", "celebi"):
        render(species)
    print("generated 18 original post-game sprite assets")


if __name__ == "__main__":
    main()
