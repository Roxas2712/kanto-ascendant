#!/usr/bin/env python3
"""The concrete user-reported 6.5 regressions may not disappear from release QA."""

from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[1]
text = (ROOT / "qa/rc28_release_gate_20260812/USER_CHAT_REGRESSION_GATE.md").read_text()
expected = {
    "SPR-001", "SPR-002", "SPR-003", "SPR-004", "SPR-005", "SPR-006",
    "SPR-007", "SPR-008", "SPR-009", "SPR-010", "JHT-001", "JHT-002", "JHT-003", "JHT-004",
    "LEAGUE-001", "HEVO-001", "HEVO-002", "HEVO-003", "HEVO-004",
    "HEVO-005", "HEVO-006", "HEVO-007", "HEVO-008", "HEVO-009",
    "NGP-001", "NGP-002", "NGP-003", "NGP-004", "NGP-005", "NGP-006",
    "WANDER-001", "WANDER-002", "REMATCH-001", "REMATCH-002", "BALL-001",
    "UI-001", "TECH-001", "RULE-001", "MOD-001", "MOD-002", "MEW-001", "OAK-001",
    "DOC-001", "RELEASE-001",
}
rows = re.findall(
    r"^\| ([A-Z]+-[0-9]+) \|.*\| (OFFEN|GALERIE_FREIGEGEBEN) \|$",
    text, re.MULTILINE,
)
found = [gate for gate, status in rows]
assert set(found) == expected, (sorted(expected - set(found)), sorted(set(found) - expected))
assert len(found) == len(set(found)) == len(expected) == 44
statuses = dict(rows)
assert statuses["SPR-010"] == "GALERIE_FREIGEGEBEN"
assert all(status == "OFFEN" for gate, status in rows if gate != "SPR-010")
assert "Quellcode-,\nFixture- und alte RC-Bilder allein schließen keine Zeile" in text
print("user chat regression gate: 44/44 tracked and fail-closed PASS")
