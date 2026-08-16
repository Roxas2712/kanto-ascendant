#!/usr/bin/env python3
"""Fail-closed source/provenance gate for Oak/Leader/Elite redraws."""

from __future__ import annotations

import csv
from pathlib import Path

from PIL import Image, ImageChops


ROOT = Path(__file__).resolve().parents[1]
QA = ROOT / "qa" / "trainer_authentic_authority_20260812"
LIVE = ROOT / "assets" / "characters" / "frlg_trainers"
ROWS = list(csv.DictReader((QA / "PROVENANCE.tsv").open(encoding="utf-8"), delimiter="\t"))
APPROVAL = {
    row["stem"]: row for row in csv.DictReader((
        ROOT / "qa/trainer_approved_live_integration_20260812/APPROVAL_RECORD.tsv"
    ).open(encoding="utf-8"), delimiter="\t")
}

EXPECTED = {
    "professor_oak",
    "leader_lt_surge", "leader_erika", "leader_koga",
    "leader_sabrina", "leader_blaine", "leader_giovanni",
    "elite_four_lorelei", "elite_four_bruno",
    "elite_four_agatha", "elite_four_lance",
}
assert len(ROWS) == 11, len(ROWS)
assert {row["stem"] for row in ROWS} == EXPECTED

for row in ROWS:
    assert row["status"] == "REVIEW_ONLY_NOT_INTEGRATED", row
    authority = ROOT / row["frlg_authority"]
    assert authority.is_file() and Image.open(authority).size == (64, 64), authority
    low_path = ROOT / row["candidate_64"]
    hd_path = ROOT / row["candidate_128"]
    for path, size, margin in ((low_path, 64, 3), (hd_path, 128, 6)):
        image = Image.open(path).convert("RGBA")
        assert image.size == (size, size), (path, image.size)
        assert set(image.getchannel("A").getdata()) == {0, 255}, path
        assert image.getpixel((0, 0))[3] == image.getpixel((size - 1, size - 1))[3] == 0
        assert len({pixel for pixel in image.getdata() if pixel[3]}) <= 32, path
        box = image.getbbox()
        assert box and box[1] >= margin and box[3] <= size - margin, (path, box)
    low = Image.open(low_path).convert("RGBA")
    reduced = Image.open(hd_path).convert("RGBA").resize((64, 64), Image.Resampling.NEAREST)
    assert ImageChops.difference(low, reduced).getbbox() is None, row["stem"]

    decision = APPROVAL[row["stem"]]
    if decision["decision"] == "KEEP_CURRENT":
        assert row["stem"] == "professor_oak"
        assert not (LIVE / low_path.name).exists(), low_path.name
        assert not (LIVE / hd_path.name).exists(), hd_path.name
    else:
        assert (ROOT / decision["chosen_64"]).read_bytes() == low_path.read_bytes()
        assert (ROOT / decision["chosen_128"]).read_bytes() == hd_path.read_bytes()

print("AUTHENTIC AUTHORITY SOURCES PASS: 10 promoted pairs + Oak CURRENT")
