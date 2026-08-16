#!/usr/bin/env python3
from __future__ import annotations

import json
import os
from pathlib import Path

from PIL import Image


ROOT = Path(os.environ.get("TRAINER_REMATCH_MOD_DIR", Path(__file__).parents[1]))


def png(path: Path) -> None:
    with Image.open(path) as image:
        image.verify()


front_root = ROOT / "assets" / "crystal_animated" / "front"
back = ROOT / "assets" / "crystal_animated" / "back"
front_count = 0
for variant in ("normal", "shiny", "grayscale"):
    for dex in range(1, 252):
        species_dir = front_root / variant / str(dex)
        frames = sorted(species_dir.glob("*.png"))
        assert frames, species_dir
        for frame in frames:
            png(frame)
            front_count += 1

# Pidgey was the visible report that exposed a runtime grayscale selection,
# not a missing asset.  Keep a direct asset assertion so both authored
# choices remain distinct and readable in every future package.
with (
    Image.open(front_root / "normal" / "16" / "001.png") as normal_pidgey,
    Image.open(front_root / "grayscale" / "16" / "001.png") as gray_pidgey,
):
    assert normal_pidgey.convert("RGBA").tobytes() != \
        gray_pidgey.convert("RGBA").tobytes()
back_count = 0
for variant in ("normal", "shiny", "grayscale"):
    for dex in range(1, 152):
        species_dir = back / variant / str(dex)
        frames = sorted(species_dir.glob("*.png"))
        assert frames, species_dir
        for frame in frames:
            png(frame)
            back_count += 1

# Decode every static Crystal fallback, every #001-251 menu icon, and every
# authored normal/shiny follower sheet.  Runtime mapping is covered by the
# Lua tests; this catches corrupt, truncated or wrongly sized files.
static_count = 0
for frame in (ROOT / "assets" / "crystal").rglob("*.png"):
    png(frame)
    static_count += 1

menu_icons = ROOT / "assets" / "crystal_menu_icons"
for dex in range(1, 252):
    frame = menu_icons / f"{dex:03d}.png"
    assert frame.is_file(), frame
    png(frame)

follower_count = 0
for folder in (
    ROOT / "assets" / "followers_kanto",
    ROOT / "assets" / "followers_runtime" / "normal",
    ROOT / "assets" / "followers_runtime" / "shiny",
):
    for frame in folder.glob("*.png"):
        with Image.open(frame) as image:
            assert image.size == (16, 96), (frame, image.size)
            image.verify()
        follower_count += 1

extra = ROOT / "assets" / "crystal_v15"
for variant in ("normal", "grayscale"):
    trainers = list((extra / "trainers" / variant).glob("*.png"))
    assert len(trainers) == 47, (variant, len(trainers))
    for path in trainers:
        png(path)
    png(extra / "front" / variant / "ghost.png")

provenance = json.loads((extra / "provenance.json").read_text())
assert provenance["tag"] == "v1.5"
assert provenance["commit"] == "9d48cc921da4db88043cb2a14e9f8803aefffad7"
assert (ROOT / "crystal_animation_data_grayscale.lua").is_file()
print("CRYSTAL V1.5 ASSET PASS: "
      f"{front_count} front frames, {back_count} animated Kanto back frames, "
      f"{static_count} static Crystal files, 251 menu icons, "
      f"{follower_count} follower sheets, 94 portraits; "
      "Pidgey colour pair distinct")
