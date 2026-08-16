#!/usr/bin/env python3
"""Fail-closed source/provenance gate for nine approved normal trainers."""

from __future__ import annotations

import csv
import hashlib
from pathlib import Path

from PIL import Image, ImageChops


ROOT = Path(__file__).resolve().parents[1]
QA = ROOT / "qa" / "trainer_normal_extra_20260812"
ASSETS = ROOT / "assets" / "characters" / "frlg_trainers"
ROWS = list(csv.DictReader((QA / "PROVENANCE.tsv").open(encoding="utf-8"), delimiter="\t"))
EXPECTED = {
    "rocket_grunt_m", "scientist", "gentleman", "super_nerd", "pokemaniac",
    "cool_trainer_m", "cool_trainer_f", "cue_ball", "engineer",
}


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


assert len(ROWS) == 9, len(ROWS)
assert {row["stem"] for row in ROWS} == EXPECTED
assert (QA / "PROMPTS.md").is_file()

for row in ROWS:
    assert row["status"] == "REVIEW_ONLY_NOT_INTEGRATED", row
    authority = ROOT / row["frlg_authority"]
    source = ROOT / row["generated_source"]
    assert authority.is_file() and Image.open(authority).size == (64, 64), authority
    assert source.is_file(), source
    assert sha256(authority) == row["authority_sha256"], authority
    assert sha256(source) == row["source_sha256"], source
    assert len(row["prompt_sha256"]) == 64
    for key, size, margin in (
        ("candidate_64", (64, 64), 3),
        ("candidate_128", (128, 128), 6),
    ):
        path = ROOT / row[key]
        image = Image.open(path).convert("RGBA")
        assert image.size == size, (path, image.size)
        assert set(image.getchannel("A").getdata()) == {0, 255}, path
        assert image.getpixel((0, 0))[3] == 0, path
        assert image.getpixel((size[0] - 1, size[1] - 1))[3] == 0, path
        assert len({pixel for pixel in image.getdata() if pixel[3]}) <= 31, path
        box = image.getbbox()
        assert box is not None
        assert box[1] >= margin and box[3] <= size[1] - margin, (path, box)

    low = Image.open(ROOT / row["candidate_64"]).convert("RGBA")
    hd = Image.open(ROOT / row["candidate_128"]).convert("RGBA")
    reduced = hd.resize((64, 64), Image.Resampling.NEAREST)
    assert ImageChops.difference(low, reduced).getbbox() is None, row["stem"]

    # Explicit approval promotes this exact candidate pair to versioned live files.
    stem = row["stem"]
    assert (ASSETS / f"{stem}_voxel_front_v2.png").read_bytes() == (
        ROOT / row["candidate_64"]).read_bytes(), stem
    assert (ASSETS / f"{stem}_voxel_front_hd_v2.png").read_bytes() == (
        ROOT / row["candidate_128"]).read_bytes(), stem

print("NORMAL EXTRA TRAINER SOURCES PASS: 9/9 approved pairs promoted")
