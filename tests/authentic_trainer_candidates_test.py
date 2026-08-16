#!/usr/bin/env python3
"""Fail-closed source/provenance gate for four approved trainer redraws."""

from __future__ import annotations

import csv
from pathlib import Path

from PIL import Image, ImageChops


ROOT = Path(__file__).resolve().parents[1]
QA = ROOT / "qa" / "trainer_authentic_rework_20260812"
ASSETS = ROOT / "assets" / "characters" / "frlg_trainers"
ROWS = list(csv.DictReader((QA / "PROVENANCE.tsv").open(encoding="utf-8"), delimiter="\t"))

assert len(ROWS) == 4, len(ROWS)
assert {row["stem"] for row in ROWS} == {
    "leader_misty", "leader_brock", "lass", "youngster",
}

for row in ROWS:
    assert row["status"] == "REVIEW_ONLY_NOT_INTEGRATED", row
    authority = ROOT / row["frlg_authority"]
    assert authority.is_file(), authority
    assert Image.open(authority).size == (64, 64), authority
    for key, size, max_colours, margin in (
        ("candidate_64", (64, 64), 32, 3),
        ("candidate_128", (128, 128), 32, 6),
    ):
        path = ROOT / row[key]
        image = Image.open(path).convert("RGBA")
        assert image.size == size, (path, image.size)
        alpha = set(image.getchannel("A").getdata())
        assert alpha == {0, 255}, (path, alpha)
        assert image.getpixel((0, 0))[3] == 0, path
        assert image.getpixel((size[0] - 1, size[1] - 1))[3] == 0, path
        colours = {pixel for pixel in image.getdata() if pixel[3]}
        assert len(colours) <= max_colours, (path, len(colours))
        box = image.getbbox()
        assert box is not None
        assert box[1] >= margin and box[3] <= size[1] - margin, (path, box)

    # The low candidate is exactly a nearest-neighbour 2x reduction of HD.
    low = Image.open(ROOT / row["candidate_64"]).convert("RGBA")
    hd = Image.open(ROOT / row["candidate_128"]).convert("RGBA")
    reduced = hd.resize((64, 64), Image.Resampling.NEAREST)
    assert ImageChops.difference(low, reduced).getbbox() is None, row["stem"]

# Explicit approval promotes each pair byte-for-byte to its versioned target.
for row in ROWS:
    stem = row["stem"]
    assert (ASSETS / f"{stem}_voxel_front_v2.png").read_bytes() == (
        ROOT / row["candidate_64"]).read_bytes()
    assert (ASSETS / f"{stem}_voxel_front_hd_v2.png").read_bytes() == (
        ROOT / row["candidate_128"]).read_bytes()

print("AUTHENTIC TRAINER SOURCES PASS: 4/4 approved pairs promoted")
