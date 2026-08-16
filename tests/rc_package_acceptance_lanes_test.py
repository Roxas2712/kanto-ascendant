#!/usr/bin/env python3
"""The RC package plan must cover every user and feature row on one receipt."""

from __future__ import annotations

import csv
from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[1]
GATE = ROOT / "qa/rc28_release_gate_20260812"
LANE_COLUMNS = [
    "order", "lane_id", "workstream", "source_status", "package_status",
    "user_state", "user_gates", "feature_ids", "reusable_driver_paths",
    "missing_driver_ids", "blocking_gap_ids", "receipt_contract",
]


def values(value: str) -> list[str]:
    return [] if value == "NONE" else value.split(";")


user_text = (GATE / "USER_CHAT_REGRESSION_GATE.md").read_text()
expected_user = set(re.findall(
    r"^\| ([A-Z]+-[0-9]+) \|.*\| (?:OFFEN|GALERIE_FREIGEGEBEN) \|$",
    user_text,
    re.MULTILINE,
))

feature_text = (GATE / "FEATURE_ACCEPTANCE_MATRIX.md").read_text()
expected_features = set(re.findall(
    r"^\| ((?:RC65|LEGACY|REMATCH|MEW)-[^| ]+) \|",
    feature_text,
    re.MULTILINE,
))

lane_path = GATE / "PACKAGE_ACCEPTANCE_LANES.tsv"
lane_text = lane_path.read_text(encoding="utf-8")
assert lane_text.endswith("\n"), "package lane TSV must end with one newline"
lane_lines = lane_text.splitlines()
assert lane_lines and all(lane_lines), "package lane TSV contains a blank row"
parsed_lanes = list(csv.reader(lane_lines, delimiter="\t"))
assert parsed_lanes[0] == LANE_COLUMNS, (
    "package lane header drifted", parsed_lanes[0],
)
for line_number, (raw, row) in enumerate(zip(lane_lines[1:], parsed_lanes[1:]), 2):
    assert len(row) == len(LANE_COLUMNS), (
        f"package lane line {line_number} has {len(row)} columns"
    )
    assert raw == "\t".join(row), (
        f"package lane line {line_number} uses quoting or non-canonical TSV"
    )
    assert all(value and value == value.strip() for value in row), (
        f"package lane line {line_number} has an empty/padded field"
    )
rows = [dict(zip(LANE_COLUMNS, row)) for row in parsed_lanes[1:]]

assert [row["order"] for row in rows] == [f"{index:02d}" for index in range(11)]
assert len({row["lane_id"] for row in rows}) == len(rows) == 11

actual_user: list[str] = []
actual_features: list[str] = []
for row in rows:
    assert row["package_status"] == "PENDING_PACKAGE", row["lane_id"]
    assert row["receipt_contract"] == "BLITZ_PACKAGE_RECEIPT_V1", row["lane_id"]
    lists = {
        field: values(row[field])
        for field in (
            "user_gates", "feature_ids", "reusable_driver_paths",
            "missing_driver_ids", "blocking_gap_ids",
        )
    }
    for field, items in lists.items():
        assert items == list(dict.fromkeys(items)), (
            f"{row['lane_id']} repeats {field}: {items}"
        )
        assert all(items), f"{row['lane_id']} has an empty {field} token"
    actual_user.extend(lists["user_gates"])
    actual_features.extend(lists["feature_ids"])
    for relative in lists["reusable_driver_paths"]:
        assert (ROOT / relative).is_file(), f"missing reusable driver: {relative}"
    if row["source_status"] == "PARTIAL_SOURCE":
        assert lists["blocking_gap_ids"], (
            f"{row['lane_id']} is PARTIAL_SOURCE without a blocking gap id"
        )
        assert lists["missing_driver_ids"], (
            f"{row['lane_id']} is PARTIAL_SOURCE without a missing driver id"
        )
    if lists["blocking_gap_ids"]:
        assert row["source_status"] == "PARTIAL_SOURCE", (
            f"{row['lane_id']} hides a source blocker behind {row['source_status']}"
        )

assert set(actual_user) == expected_user, (
    sorted(expected_user - set(actual_user)),
    sorted(set(actual_user) - expected_user),
)
assert len(actual_user) == len(set(actual_user)) == len(expected_user) == 44
assert set(actual_features) == expected_features, (
    sorted(expected_features - set(actual_features)),
    sorted(set(actual_features) - expected_features),
)
assert len(actual_features) == len(set(actual_features)) == len(expected_features) == 34

required_red_gaps: dict[str, set[str]] = {}
all_gaps = {item for row in rows for item in values(row["blocking_gap_ids"])}
all_missing = {item for row in rows for item in values(row["missing_driver_ids"])}
assert all_gaps == set(required_red_gaps), (
    "source blocker inventory drifted",
    sorted(set(required_red_gaps) - all_gaps),
    sorted(all_gaps - set(required_red_gaps)),
)
for gap, drivers in required_red_gaps.items():
    missing = sorted(drivers - all_missing)
    assert not missing, f"{gap} lost missing driver ids: {', '.join(missing)}"
for fixed_gap, fixed_driver in {
    "SRC-CRYSTAL-252-279-MOTION": "DRV-CRYSTAL-252-279-MOTION-SURFACES",
    "SRC-ITEM-HELP-PC-SHOP": "DRV-ITEM-HELP-PC-SHOP",
    "SRC-JOHTO-CONNECTED-PROGRESSION": "DRV-JOHTO-CONNECTED-PROGRESSION",
    "SRC-LEAGUE-RENDERED-ROSTER": "DRV-LEAGUE-RENDERED-ROSTER",
    "SRC-HEVO15-FIELD-ALTARS-PARTIAL": "DRV-HEVO15-ALL-GRANTS-PACKAGE",
    "SRC-MEW-BATTLEART-PARTIAL": "DRV-MEW-BATTLEART-PACKAGE",
    "SRC-LEGACY-PACT-THREE-JOURNEYS-PARTIAL":
        "DRV-LEGACY-PACT-4X4-PACKAGE",
    "SRC-MODULE-REVERSE-RUNTIME-PARTIAL": "DRV-MODULE-REVERSE-RUNTIME",
}.items():
    assert fixed_gap not in all_gaps, f"closed source gap returned: {fixed_gap}"
    assert fixed_driver not in all_missing, f"implemented driver still missing: {fixed_driver}"
assert "DRV-LEGACY-THREE-JOURNEYS-PACKAGE" not in all_missing, (
    "implemented three-Journey package driver still marked missing"
)

plan = (GATE / "PACKAGE_ACCEPTANCE_PLAN.md").read_text()
for gap in required_red_gaps:
    assert f"`{gap}`" in plan
assert "`SPR-010` bleibt als einzige Nutzergalerie-Milestone erhalten" in plan

with (GATE / "MODULE_ACCEPTANCE_MAP.tsv").open(newline="") as handle:
    module_rows = list(csv.DictReader(handle, delimiter="\t"))
module_count = len(module_rows)
l09 = next(row for row in rows if row["lane_id"] == "L09_REVERSE_MODULE_SURFACES")
assert f"all {module_count} mapped product modules" in l09["workstream"]

print(
    f"RC package lanes: 44 user + 34 feature + {module_count}-module reverse "
    f"lane PASS; {len(required_red_gaps)} source blockers declared fail-closed"
)
