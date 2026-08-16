#!/usr/bin/env python3
"""Fail-closed static contract for the installed-package Rematch driver."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DRIVER = ROOT / "tests" / "rematch_longitudinal_package_driver.lua"
text = DRIVER.read_text(encoding="utf-8")

required = {
    "two launch persistence": "probe and probe.stage == 1",
    "exact provider count": "classCount == 47",
    "production overworld path": "Overworld.talkTo(fakeWorld, npc)",
    "production trainer battle": "battle and battle.rematch",
    "level 100 mastery": "report.allLevel100 == true",
    "bounded AI": "battle.aiUses <= 3",
    "multiple progress bands": "multiple rematch and silent-training bands reach real battles",
    "badge contexts": "zero/four/eight-badge saves all reach real rematch battles",
    "real world step": 'game.mods.events:emit("world.stepped"',
    "anti-repeat": "first[2].species ~= second[2].species",
    "story boss exclusion": "Route-22 story rival never becomes a generic rematch provider",
    "automatic Mega event": "Runtime\").emit(\"battle.started\"",
    "no manual Mega activation": "eligible L100 field trainer is armed",
    "pre-Hall zero": "pre-Hall Master Ball chance is exactly zero",
    "post-Hall 1 of 50": "boundary rolls 1..50 yield exactly one Master Ball",
    "receipt idempotency": "Master Ball receipt is idempotent",
    "Bag to PC": "full Bag sends rare rematch Master Ball to PC",
    "PC to pending": "full Bag and PC reserve rare rematch Master Ball safely",
    "ordinary item loot": "ordinary rematch loot grants its registered item stack",
    "normal money": "ordinary level-band rematch grants its normal money fallback",
    "mastery money": "level-100 mastery band grants its premium money fallback",
    "EXP share default off": "EXP Share unlock starts OFF before explicit TEAM selection",
    "ordered multipliers": "3x and 5x unlocks preserve the selected prior stage",
    "EXP runtime hooks": "TEAM allocation and selected 3x hook execute exactly once",
    "native save": "game:writeSave()",
    "real trainer atlas": "Screens.push(game, \"AscendantTrainerAtlas\")",
    "visual receipts": "02_level100_rematch_battle.png",
}

missing = [name for name, needle in required.items() if needle not in text]
for forbidden in (
    "mega.activate(",
    "_ascMegaEnemyPending = true",
    "masterReceipts[",
    "rewardState.pendingItems[#rewardState.pendingItems + 1]",
    "states = {}",
):
    if forbidden in text:
        missing.append(f"forbidden manual mutation: {forbidden}")

assert not missing, "REMATCH PACKAGE CONTRACT FAIL:\n" + "\n".join(missing)
print(f"REMATCH LONGITUDINAL PACKAGE CONTRACT PASS: {len(required)} checks")
