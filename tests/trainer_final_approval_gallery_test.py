#!/usr/bin/env python3
"""Fail-closed contract test for the 48-identity user approval gallery."""

from __future__ import annotations

import csv
import json
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "qa" / "trainer_final_user_approval_20260812"


def main() -> None:
    with (OUT / "MANIFEST.tsv").open(encoding="utf-8", newline="") as handle:
        rows = list(csv.DictReader(handle, delimiter="\t"))
    assert len(rows) == 48
    assert len({row["stem"] for row in rows}) == 48
    assert {row["group"] for row in rows} == {"fixed", "leaders", "elite_four", "normal_trainers"}
    assert sum(row["group"] == "fixed" for row in rows) == 6
    assert sum(row["group"] == "leaders" for row in rows) == 9
    assert sum(row["group"] == "elite_four" for row in rows) == 4
    assert sum(row["group"] == "normal_trainers" for row in rows) == 29
    fixed_stems = {"red", "blue", "green", "silver", "kris", "gold"}
    oak_stem = "professor_oak"

    required = ("authority", "current_64", "current_128")
    optional = ("candidate_64", "candidate_128")
    for row in rows:
        for slot in required + optional:
            value = row[slot]
            if slot in required:
                assert value, f"{row['stem']} missing {slot}"
            if not value:
                continue
            path = ROOT / value
            assert not Path(value).is_absolute()
            assert path.resolve().is_relative_to(ROOT.resolve())
            assert path.is_file(), f"{row['stem']} missing file {value}"
        has_candidate = any(row[slot] for slot in optional)
        if row["stem"] in fixed_stems:
            assert not has_candidate
            assert row["approval_decision"] == "CURRENT_ONLY"
            assert row["selected_build"] == "CURRENT"
            assert row["selected_64"] == row["current_64"]
            assert row["selected_128"] == row["current_128"]
        else:
            assert all(row[slot] for slot in optional), f"{row['stem']} incomplete candidate pair"
            for candidate_slot, current_slot in (("candidate_64", "current_64"),
                                                  ("candidate_128", "current_128")):
                assert (ROOT / row[candidate_slot]).read_bytes() != (ROOT / row[current_slot]).read_bytes(), (
                    row["stem"], candidate_slot, "duplicates CURRENT")
            if row["stem"] == oak_stem:
                assert row["approval_decision"] == "REJECTED_KEEP_CURRENT"
                assert row["selected_build"] == "CURRENT"
                assert row["selected_64"] == row["current_64"]
                assert row["selected_128"] == row["current_128"]
            else:
                assert row["approval_decision"] == "APPROVED_NEW_BUILD"
                assert row["selected_build"] == "CANDIDATE"
                assert row["selected_64"] == row["candidate_64"]
                assert row["selected_128"] == row["candidate_128"]

    receipt = json.loads((OUT / "RECEIPT.json").read_text(encoding="utf-8"))
    assert receipt["inventory_count"] == 48
    assert receipt["unique_stems"] == 48
    assert receipt["schema"] == 2
    assert receipt["candidate_asset_identity_count"] == 42
    assert receipt["approval_decision_counts"] == {
        "CURRENT_ONLY": 6,
        "REJECTED_KEEP_CURRENT": 1,
        "APPROVED_NEW_BUILD": 41,
    }
    assert receipt["selected_current_count"] == 7
    assert receipt["selected_candidate_count"] == 41
    assert receipt["all_paths_repository_relative"] is True
    assert len(receipt["pages"]) == 6
    for page in receipt["pages"]:
        path = ROOT / page["path"]
        assert path.is_file()
        with Image.open(path) as im:
            assert im.width == 3600
            assert im.height == page["height"]
            assert im.mode == "RGB"

    with (OUT / "IMAGE_RECEIPTS.tsv").open(encoding="utf-8", newline="") as handle:
        images = list(csv.DictReader(handle, delimiter="\t"))
    assert len(images) == receipt["source_image_count"]
    assert all(row["width"].isdigit() and int(row["width"]) > 0 for row in images)
    assert all(row["height"].isdigit() and int(row["height"]) > 0 for row in images)
    assert all(len(row["sha256"]) == 64 for row in images)

    approval = json.loads((OUT / "APPROVAL_RECORD.json").read_text(encoding="utf-8"))
    assert approval["integration_status"] == "QA_ONLY_NOT_INTEGRATED"
    assert approval["decision_counts"] == receipt["approval_decision_counts"]
    assert len(approval["decisions"]) == 48
    assert len({row["stem"] for row in approval["decisions"]}) == 48
    print(f"PASS trainer approval gallery: {len(rows)}/48 identities, {len(images)} image receipts")


if __name__ == "__main__":
    main()
