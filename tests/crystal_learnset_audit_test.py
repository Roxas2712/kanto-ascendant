#!/usr/bin/env python3
"""Deterministic acceptance test for the Crystal learnset audit artifact."""

from __future__ import annotations

import importlib.util
import json
import os
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def engine_root() -> Path:
    candidates = []
    if os.environ.get("GEN1RECOMP_ROOT"):
        candidates.append(Path(os.environ["GEN1RECOMP_ROOT"]))
    candidates.extend((ROOT.parent / "gen1recomp", ROOT.parents[1] / "gen1recomp"))
    for candidate in candidates:
        if (candidate / "data/generated/moves.lua").is_file():
            return candidate.resolve()
    raise AssertionError("set GEN1RECOMP_ROOT to a Gen1 Recomp checkout")


spec = importlib.util.spec_from_file_location(
    "audit_crystal_learnsets", ROOT / "tools/audit_crystal_learnsets.py")
assert spec and spec.loader
audit = importlib.util.module_from_spec(spec)
spec.loader.exec_module(audit)

actual = audit.build_report(
    ROOT / "crystal_learnsets.lua",
    engine_root() / "data/generated/moves.lua",
    ROOT / "postgame_species.lua",
)
expected = json.loads((ROOT / "qa/crystal_learnsets_audit.json").read_text(
    encoding="utf-8"))

assert actual == expected, "regenerate qa/crystal_learnsets_audit.json"
assert actual["canonicalSpecies"] == 251
assert actual["canonicalRows"] == 2215
assert actual["checks"]["espeonLearnsPsybeamAt36"] is True
assert actual["checks"]["psybeamRegistered"] is True
assert actual["checks"]["allActiveMoveIdsRegistered"] is True
assert actual["checks"]["unknownIdsInActiveLearnsets"] == []
assert actual["missingMoveCount"] == len(actual["missingMoveIds"]) == 47

print("crystal_learnset_audit_test: ok")
