#!/usr/bin/env python3
"""Fail-closed static contract for the localized run-rules visual driver."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DRIVER = ROOT / "tests/run_rules_legacy_visual_driver.lua"
SOURCE = DRIVER.read_text(encoding="utf-8")


def require(fragment: str, label: str) -> None:
    assert fragment in SOURCE, f"run-rules visual driver lost {label}"


require(
    "local language = assert(api.language and api.language()",
    "export-derived language",
)
require(
    'and "SEL:HILFE GESP." or "SEL:HELP  LOCKED"',
    "exact localized main footer values",
)
require(
    'locked.footer == expectedReadOnly',
    "exact localized main footer comparison",
)
require(
    "local expectedLocked = expectedReadOnly",
    "exact localized submenu footer values",
)
require(
    'local PlayerPC = require("src.ui.PlayerPC")',
    "production PlayerPC integration",
)
require(
    'return PlayerPC.new(game, direct and { direct = true } or nil).items',
    "production PlayerPC menu rows",
)
require(
    "local outside = playerPcRows(false)",
    "non-bedroom PlayerPC probe",
)
require(
    'check("Pokemon Center Player PC has no duplicate ASC RUN row"',
    "normal Player PC remains free of duplicate KASC rows",
)
require("remoteRun == nil", "normal Player PC exclusion witness")
require(
    "for _, index in ipairs({ 1, 2, 3, 6, 7 }) do",
    "all locked main-rule mutation probes",
)
require(
    "local restored = unwindTo(locked, 3)",
    "bounded main-screen dismissal",
)
require(
    "restored and game.stack:top() == locked",
    "retained main-menu stack witness",
)
require(
    "visibleRows(locked) == lockedRows",
    "all main-menu rows immutable after every action",
)
require(
    "#lockedRandomizer.items == 9",
    "exact Randomizer row count",
)
require(
    "lockedRandomizer.footer == expectedLocked",
    "exact localized Randomizer footer comparison",
)
require(
    "for index = 1, 9 do",
    "all nine locked Randomizer mutation probes",
)
require(
    "game.stack:top() == lockedRandomizer",
    "Randomizer stack retention after every action",
)
require(
    "visibleRows(lockedRandomizer) == lockedRandomizerRows",
    "all Randomizer rows immutable after every action",
)
require(
    "#lockedNuzlocke.items == 4",
    "exact Nuzlocke row count",
)
require(
    "lockedNuzlocke.footer == expectedLocked",
    "exact localized Nuzlocke footer comparison",
)
require(
    "for index = 1, 4 do",
    "all four locked Nuzlocke mutation probes",
)
require(
    "game.stack:top() == lockedNuzlocke",
    "Nuzlocke stack retention after every action",
)
require(
    "visibleRows(lockedNuzlocke) == lockedNuzlockeRows",
    "all Nuzlocke rows immutable after every action",
)
require(
    'SaveData.encode(state) == lockedState',
    "deep state immutability witness after every action",
)
require(
    '(fail == 0 and "PASS" or "FAIL")',
    "fail-closed result status",
)
require("love.event.quit(fail == 0 and 0 or 1)", "fail-closed process status")

assert 'result:write(("PASS\\npass=%d' not in SOURCE, (
    "run-rules visual driver must not report PASS when a check failed"
)

assert ':find("READ%-ONLY")' not in SOURCE
assert ':find("NUR LESBAR"' not in SOURCE

print("PASS run-rules visual-driver contract: 26 checks")
