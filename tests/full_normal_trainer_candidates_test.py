#!/usr/bin/env python3
"""Fail-closed source/provenance gate for nine approved normal trainers."""

from __future__ import annotations

import csv
from pathlib import Path

from PIL import Image, ImageChops


ROOT = Path(__file__).resolve().parents[1]
QA = ROOT / "qa" / "trainer_full_normal_rework_20260812"
ASSETS = ROOT / "assets" / "characters" / "frlg_trainers"
EXPECTED = {"fisherman", "gamer", "hiker", "juggler", "psychic_m", "rocker",
            "sailor", "swimmer_m", "tamer"}


def main() -> None:
    with (QA / "PROVENANCE.tsv").open(encoding="utf-8", newline="") as handle:
        rows = list(csv.DictReader(handle, delimiter="\t"))
    assert len(rows) == 9
    assert {row["stem"] for row in rows} == EXPECTED
    for row in rows:
        assert row["status"] == "REVIEW_ONLY_NOT_INTEGRATED"
        authority = ROOT / row["frlg_authority"]
        assert authority.is_file() and Image.open(authority).size == (64, 64)
        low = Image.open(ROOT / row["candidate_64"]).convert("RGBA")
        hd = Image.open(ROOT / row["candidate_128"]).convert("RGBA")
        for image, size, margin in ((low, (64, 64), 3), (hd, (128, 128), 6)):
            assert image.size == size
            assert set(image.getchannel("A").getdata()) == {0, 255}
            assert image.getpixel((0, 0))[3] == 0
            box = image.getbbox()
            assert box is not None and box[1] >= margin and box[3] <= size[1] - margin
            assert len({p for p in image.getdata() if p[3]}) <= 48
        assert ImageChops.difference(low, hd.resize((64, 64), Image.Resampling.NEAREST)).getbbox() is None
        assert (ROOT / row["candidate_64"]).read_bytes() != (ASSETS / f"{row['stem']}_voxel_front_v1.png").read_bytes()
        assert (ROOT / row["candidate_128"]).read_bytes() != (ASSETS / f"{row['stem']}_voxel_front_hd_v1.png").read_bytes()
        assert (ASSETS / f"{row['stem']}_voxel_front_v2.png").read_bytes() == (
            ROOT / row["candidate_64"]).read_bytes()
        assert (ASSETS / f"{row['stem']}_voxel_front_hd_v2.png").read_bytes() == (
            ROOT / row["candidate_128"]).read_bytes()
    print("FULL NORMAL TRAINER SOURCES PASS: 9/9 approved pairs promoted")


if __name__ == "__main__":
    main()
