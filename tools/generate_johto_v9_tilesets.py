"""Build the two authored Johto-Passage v9 tile atlases from local Gen-II art.

No downloaded or generated image is involved: the source atlases stay intact;
only unused tile slots 160..167 receive small palette-matched 8x8 details.
"""
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets" / "johto_masters" / "tilesets"


def tile_box(index):
    return ((index % 16) * 8, (index // 16) * 8,
            (index % 16 + 1) * 8, (index // 16 + 1) * 8)


def paint_radio():
    image = Image.open(SOURCE / "radio_tower.png").convert("RGBA")
    neutral, line, cyan, red, steel = "#303744", "#4b5869", "#79d8e8", "#df5b63", "#aab7c7"
    for index in range(160, 176):
        ImageDraw.Draw(image).rectangle(tile_box(index), fill=neutral)
    draw = ImageDraw.Draw(image)
    # 161: thin grey floor seam; 162: cyan cable; 163: red signal lamp.
    draw.line((tile_box(161)[0], tile_box(161)[1] + 6, tile_box(161)[2] - 1, tile_box(161)[1] + 6), fill=line)
    draw.line((tile_box(162)[0], tile_box(162)[1] + 4, tile_box(162)[2] - 1, tile_box(162)[1] + 4), fill=cyan)
    x0, y0, _, _ = tile_box(163); draw.rectangle((x0 + 3, y0 + 3, x0 + 4, y0 + 4), fill=red)
    # 164/165: bounded steel wall and glass inset.  The old single stripe
    # read as an accidental full-screen barcode once repeated by a metatile.
    x0, y0, x1, y1 = tile_box(164)
    draw.rectangle((x0, y0, x1 - 1, y1 - 1), fill="#202833")
    draw.line((x0, y0 + 1, x1 - 1, y0 + 1), fill=steel)
    draw.point((x0 + 2, y0 + 5), fill=line); draw.point((x0 + 5, y0 + 4), fill=line)
    x0, y0, x1, y1 = tile_box(165)
    draw.rectangle((x0, y0, x1 - 1, y1 - 1), fill="#202833")
    draw.rectangle((x0 + 1, y0 + 2, x1 - 2, y1 - 2), fill="#315466")
    draw.line((x0 + 1, y0 + 2, x1 - 2, y0 + 2), fill=cyan)
    x0, y0, x1, y1 = tile_box(166); draw.rectangle((x0 + 1, y0 + 1, x1 - 2, y1 - 2), outline=steel)
    x0, y0, x1, y1 = tile_box(167)
    for y in (y0 + 2, y0 + 4, y0 + 6): draw.line((x0 + 1, y, x1 - 2, y), fill=steel)
    # 168/169: framed entry screen; 170/171: relay body and three-lamp
    # switch bank; 172/173: sealed gate and lock; 174/175: cable junction.
    x0, y0, x1, y1 = tile_box(168)
    draw.rectangle((x0, y0, x1 - 1, y1 - 1), fill="#1c2530")
    draw.rectangle((x0 + 1, y0 + 1, x1 - 2, y1 - 2), outline=steel)
    x0, y0, x1, y1 = tile_box(169)
    draw.rectangle((x0 + 2, y0 + 2, x1 - 3, y1 - 3), fill=cyan)
    x0, y0, x1, y1 = tile_box(170)
    draw.rectangle((x0, y0, x1 - 1, y1 - 1), fill="#202833")
    draw.line((x0 + 1, y0 + 2, x1 - 2, y0 + 2), fill=steel)
    draw.line((x0 + 1, y0 + 5, x1 - 2, y0 + 5), fill=line)
    x0, y0, x1, y1 = tile_box(171)
    for x in (x0 + 1, x0 + 3, x0 + 5): draw.rectangle((x, y0 + 3, x, y0 + 4), fill=red)
    x0, y0, x1, y1 = tile_box(172)
    draw.rectangle((x0, y0, x1 - 1, y1 - 1), fill="#1b222c")
    draw.line((x0 + 1, y0, x0 + 1, y1 - 1), fill=steel)
    x0, y0, x1, y1 = tile_box(173)
    draw.rectangle((x0 + 2, y0 + 2, x1 - 3, y1 - 3), outline=red)
    x0, y0, x1, y1 = tile_box(174)
    draw.line((x0, y0 + 4, x1 - 1, y0 + 4), fill=cyan)
    draw.line((x0 + 4, y0, x0 + 4, y1 - 1), fill=cyan)
    x0, y0, x1, y1 = tile_box(175)
    draw.line((x0 + 1, y0 + 1, x1 - 2, y1 - 2), fill=line)
    draw.line((x0 + 1, y1 - 2, x1 - 2, y0 + 1), fill=line)
    image.save(SOURCE / "silver_signal_v9.png")


def paint_archive():
    image = Image.open(SOURCE / "ruins_of_alph.png").convert("RGBA")
    stone, seam, rune, gold, shelf = "#30332f", "#53584d", "#94a58c", "#c6a35b", "#6f6250"
    for index in range(160, 176):
        ImageDraw.Draw(image).rectangle(tile_box(index), fill=stone)
    draw = ImageDraw.Draw(image)
    x0, y0, x1, y1 = tile_box(161); draw.line((x0, y0 + 6, x1 - 1, y0 + 6), fill=seam)
    x0, y0, x1, y1 = tile_box(162); draw.rectangle((x0 + 2, y0 + 2, x1 - 3, y1 - 3), outline=rune)
    x0, y0, x1, y1 = tile_box(163); draw.rectangle((x0 + 2, y0 + 2, x1 - 3, y1 - 3), fill=gold)
    x0, y0, x1, y1 = tile_box(164)
    draw.rectangle((x0, y0, x1 - 1, y1 - 1), fill="#242821")
    draw.line((x0, y0 + 2, x1 - 1, y0 + 2), fill=shelf)
    draw.point((x0 + 2, y0 + 5), fill=shelf); draw.point((x0 + 5, y0 + 5), fill=shelf)
    x0, y0, x1, y1 = tile_box(165)
    draw.rectangle((x0, y0, x1 - 1, y1 - 1), fill="#242821")
    draw.line((x0 + 1, y0 + 1, x0 + 1, y1 - 2), fill=seam)
    x0, y0, x1, y1 = tile_box(166); draw.line((x0, y0 + 4, x1 - 1, y0 + 4), fill=rune)
    x0, y0, x1, y1 = tile_box(167); draw.rectangle((x0 + 3, y0 + 3, x0 + 4, y0 + 4), fill=gold)
    # 168/169 make a bounded rune island; 170 is its slim bridge; 171/172
    # are a reading lectern and stele.  Gold remains one small key accent.
    x0, y0, x1, y1 = tile_box(168)
    draw.ellipse((x0 + 1, y0 + 1, x1 - 2, y1 - 2), outline=rune)
    x0, y0, x1, y1 = tile_box(169)
    draw.rectangle((x0 + 3, y0 + 3, x0 + 4, y0 + 4), fill=gold)
    x0, y0, x1, y1 = tile_box(170)
    draw.line((x0, y0 + 4, x1 - 1, y0 + 4), fill=rune)
    x0, y0, x1, y1 = tile_box(171)
    draw.rectangle((x0 + 2, y0 + 3, x1 - 3, y1 - 2), fill=shelf)
    draw.line((x0 + 1, y1 - 2, x1 - 2, y1 - 2), fill=rune)
    x0, y0, x1, y1 = tile_box(172)
    draw.rectangle((x0 + 3, y0 + 1, x0 + 4, y1 - 2), fill=seam)
    draw.point((x0 + 3, y0 + 2), fill=gold)
    x0, y0, x1, y1 = tile_box(173)
    draw.line((x0 + 1, y0 + 1, x1 - 2, y1 - 2), fill=rune)
    x0, y0, x1, y1 = tile_box(174)
    draw.line((x0 + 1, y1 - 2, x1 - 2, y0 + 1), fill=rune)
    x0, y0, x1, y1 = tile_box(175); draw.rectangle((x0 + 3, y0 + 3, x0 + 4, y0 + 4), fill=gold)
    image.save(SOURCE / "kris_archive_v9.png")


if __name__ == "__main__":
    paint_radio()
    paint_archive()
