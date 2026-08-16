#!/usr/bin/env python3
"""Static authority gate for the selected 42 Kanto trainer HD pairs."""

from pathlib import Path
import csv
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
APPROVAL = ROOT / "qa/trainer_approved_live_integration_20260812/APPROVAL_RECORD.tsv"
FIXED = {"red", "blue", "green", "silver", "kris", "gold"}

rows = list(csv.DictReader(APPROVAL.open(encoding="utf-8"), delimiter="\t"))
rows = [row for row in rows if row["stem"] not in FIXED]
assert len(rows) == 42
assert len({row["class_id"] for row in rows}) == 42

for row in rows:
    for key, expected_size in (("chosen_64", 64), ("chosen_128", 128)):
        path = ROOT / row[key]
        assert path.is_file(), path
        image = Image.open(path).convert("RGBA")
        assert image.size == (expected_size, expected_size), (path, image.size)
        alpha = set(image.getchannel("A").getdata())
        assert alpha == {0, 255}, (path, alpha)
        assert image.getpixel((0, 0))[3] == 0
        assert image.getpixel((expected_size - 1, expected_size - 1))[3] == 0
        opaque = [pixel for pixel in image.getdata() if pixel[3]]
        assert len(set(opaque)) <= 48, (path, len(set(opaque)))
        assert sum(max(pixel[:3]) <= 64 for pixel in opaque) / len(opaque) >= 0.04
        assert max(max(pixel[:3]) - min(pixel[:3]) for pixel in opaque) >= 80

print("TRAINER VOXEL PORTRAITS PASS: 42 approved Kanto 64/128 pairs")
