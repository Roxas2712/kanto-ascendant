#!/usr/bin/env python3
"""Prepare deterministic, review-only FRLG authority previews for 24 classes."""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
FRLG = ROOT / "assets" / "characters" / "frlg_trainers"
OUT = ROOT / "qa" / "trainer_full_normal_rework_20260812"
REFS = OUT / "reference_previews"

CLASSES = [
    ("beauty", "Schönheit / Beauty"),
    ("biker", "Biker / Biker"),
    ("bird_keeper", "Vogelfänger / Bird Keeper"),
    ("black_belt", "Schwarzgurt / Black Belt"),
    ("burglar", "Dieb / Burglar"),
    ("channeler", "Exorzistin / Channeler"),
    ("rocket_grunt_m", "Rocket-Rüpel / Rocket Grunt"),
    ("scientist", "Wissenschaftler / Scientist"),
    ("gentleman", "Gentleman / Gentleman"),
    ("super_nerd", "Super-Nerd / Super Nerd"),
    ("pokemaniac", "Pokémaniac / Poké Maniac"),
    ("cool_trainer_m", "Ass-Trainer / Cooltrainer M"),
    ("cool_trainer_f", "Ass-Trainerin / Cooltrainer F"),
    ("cue_ball", "Rowdy / Cue Ball"),
    ("engineer", "Ingenieur / Engineer"),
    ("fisherman", "Angler / Fisherman"),
    ("gamer", "Spieler / Gamer"),
    ("hiker", "Wanderer / Hiker"),
    ("juggler", "Jongleur / Juggler"),
    ("psychic_m", "Psycho / Psychic"),
    ("rocker", "Rocker / Rocker"),
    ("sailor", "Matrose / Sailor"),
    ("swimmer_m", "Schwimmer / Swimmer"),
    ("tamer", "Bändiger / Tamer"),
]


def font(size: int):
    for path in ("/System/Library/Fonts/Supplemental/Arial Bold.ttf",
                 "/System/Library/Fonts/SFNS.ttf"):
        try:
            return ImageFont.truetype(path, size)
        except OSError:
            pass
    return ImageFont.load_default(size=size)


def main() -> None:
    REFS.mkdir(parents=True, exist_ok=True)
    cards = []
    for stem, label in CLASSES:
        source = FRLG / f"{stem}_front_pic.png"
        if not source.is_file():
            raise FileNotFoundError(source)
        with Image.open(source) as im:
            rgba = im.convert("RGBA")
            preview = Image.new("RGBA", (512, 512), (255, 255, 255, 255))
            scaled = rgba.resize((448, 448), Image.Resampling.NEAREST)
            preview.alpha_composite(scaled, (32, 32))
            path = REFS / f"{stem}_frlg_512.png"
            preview.convert("RGB").save(path)
            cards.append((path, label))

    sheet = Image.new("RGB", (2048, 6 * 620), (22, 25, 32))
    draw = ImageDraw.Draw(sheet)
    label_font = font(24)
    for index, (path, label) in enumerate(cards):
        x = (index % 4) * 512
        y = (index // 4) * 620
        with Image.open(path) as preview:
            sheet.paste(preview, (x, y))
        draw.text((x + 16, y + 524), label, font=label_font, fill=(245, 247, 252))
        draw.text((x + 16, y + 558), CLASSES[index][0], font=label_font, fill=(151, 169, 201))
    sheet.save(OUT / "REFERENCE_AUTHORITY_CONTACT_SHEET.png")
    print(f"PASS normal trainer authority refs: {len(cards)}/24")


if __name__ == "__main__":
    main()
