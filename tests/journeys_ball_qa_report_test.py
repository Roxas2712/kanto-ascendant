#!/usr/bin/env python3
"""Validate durable Journeys renderer evidence, not just asset filenames."""
from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageChops

ROOT = Path(__file__).resolve().parents[1]
QA = ROOT / "qa" / "journeys_ball_matrix"
REPORT = json.loads((QA / "matrix_report.json").read_text())

assert REPORT["format"] == 4
assert REPORT["fileMatrixPass"] is True
assert REPORT["contactGridPass"] is True
assert len(REPORT["balls"]) == 12
assert len(REPORT["phases"]) == 7
assert set(REPORT["runs"]) == {
    "red_modern", "red_original", "blue_modern", "blue_original",
    "yellow_modern", "yellow_original",
}

for run_id, run in REPORT["runs"].items():
    assert run["captured"] == run["archived"] == run["expected"] == 84
    assert run["fileMatrixPass"] is True
    assert run["contactGridPass"] is True
    assert len(run["contactSheets"]) == 12
    assert len(run["reviewSheets"]) == 12
    archive = QA / run["archive"]
    raw = QA / run["rawArchive"]
    assert len(list(archive.glob("*.png"))) == 84
    assert len(list(raw.glob("*.png"))) == 84
    assert (QA / run["ballIdentitySheet"]).is_file()
    assert (QA / run["ballIdentityReview"]).is_file()

    # A frozen Frame-0 matrix could still satisfy file counts.  Require each
    # ball's real renderer captures to contain visibly different states.
    for ball in REPORT["balls"]:
        states = []
        for phase in REPORT["phases"]:
            path = archive / f"{ball}_{phase}.png"
            with Image.open(path) as image:
                assert image.size == (160, 144)
                states.append(image.convert("RGB").copy())
        assert any(ImageChops.difference(states[0], state).getbbox()
                   for state in states[1:]), f"{run_id}/{ball} is frozen"

if REPORT["visualStatus"] == "pass":
    assert REPORT["pass"] is True
    assert REPORT["manualReview"]["status"] == "pass"
    assert len(REPORT["manualReview"]["contactSheetSha256"]) == 156
else:
    assert REPORT["pass"] is False

print("journeys_ball_qa_report_test: PASS "
      "(6 real runs, 504 raw + 504 native frames, 72 exact state strips)")
