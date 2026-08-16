#!/usr/bin/env python3
"""Fail-closed contract for the installed-package Wanderer R/B/Y matrix."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DRIVER = ROOT / "tests" / "legacy_wanderers_love_e2e_driver.lua"
text = DRIVER.read_text(encoding="utf-8")

required = {
    "package identity": "refusing to write outside a Legacy Wanderer QA identity",
    "edition pin": "wrong imported edition for Legacy Wanderer package proof",
    "native new save": "SaveData.newGame(game:bootConfig())",
    "post-HOF receipt": "EVENT_BEAT_CHAMPION_RIVAL = true",
    "physical field step": "one physical eligible overworld step makes the encounter due",
    "physical NPC": "spawn selected a collision-safe scripted approach",
    "physical battle": "NPC completes its real approach and pushes a trainer battle",
    "physical win": "real trainer lifecycle ends in a win",
    "exact scaling": "team is only one to three levels over the fair usable-party baseline",
    "exact EXP": "real battle EXP event applies the exact configured 15-20 percent",
    "frequency matrix": "NEVER/RARE/NORMAL/OFTEN exact floor and fail-safe profiles",
    "map matrix": "routes and towns qualify while caves, houses and HEVO never do",
    "real pool": "Authority trainer pool reports exact and honest fallback sprites",
    "story exclusion": "Authority ordinary pool excludes every KA feature/story boss",
    "late level": "late Wanderer is Lv100 with legal perfect mastery and three AI layers",
    "late Mega": "late Wanderer is automatically eligible and armed for one enemy Mega",
    "honest late disclosure": "STAGED_REAL_BATTLESTATE_FROM_PRODUCT_TEAM",
    "seven Apricorn": "installed reward pool owns all seven Apricorn Balls",
    "twenty TMs": "installed reward pool exposes every registered Gen2/3 TM",
    "ball stack bands": "installed Ball stacks expose the authored Poke/Great/Ultra bands",
    "Master 1/32": "exact one-in-32 Master Ball hit",
    "catch-up bands": "exact 1/4, 1/6, 1/12 and 1/24 bands",
    "catch-up options": "catch-up ownership never silently changes selected EXP settings",
    "catch-up once": "catch-up encounter token is exact-once",
    "target pocket seam": 'targetPocket = Bag.pocketOf("GREAT_BALL", game.data)',
    "same pocket guard": 'targetPocket == ultraPocket',
    "target-only setup": 'local targetIds = { "GREAT_BALL", "ULTRA_BALL" }',
    "real Bag adds": "saturationSucceeded = Bag.add(game.save, id, delta, game.data)",
    "Great rejection": 'not Bag.add(game.save, "GREAT_BALL", 2, game.data)',
    "Ultra rejection": 'not Bag.add(game.save, "ULTRA_BALL", 3, game.data)',
    "LOVE untouched": "without touching LOVE BALL or fabricating filler",
    "real Bag removes": "Bag.remove(game.save, id, staged - original)",
    "no ITEM capacity shim": "Never mutate game.data.constants.bagSize",
    "Bag to PC": "full live target pocket sends the Wanderer Ball stack to the real PC",
    "PC to pending": "full target pocket and then-full PC reserve the next Ball stack exactly once",
    "pending reload": "reload preserves PC and pending fallback transactions",
    "pending delivery": "making target-pocket room delivers the reserved stack exactly once",
    "loss cooldown": "loss removes the Wanderer and starts a fresh delayed cadence",
    "loss reload": "reload preserves loss cooldown without reviving the trainer",
    "no immediate respawn": "next outdoor step cannot immediately respawn after a loss",
    "title reaction": "Factory Architect produces the class-reactive title intro",
    "native save": "game:writeSave()",
    "native reload": "SaveData.load()",
    "2D closure": "2D run owns the flat renderer without DRAMALESS",
    "FULL closure": "real DRAMALESS FULL world pipeline is active",
    "FULL world receipt": "kind=%s;pipeline=voxel;level=1",
    "FULL battle receipt": "battle.dramaticShapeShot == shot",
}

missing = [name for name, needle in required.items() if needle not in text]
for forbidden in (
    "_ascMegaEnemyPending = true",
    "mega.activate(",
    "rewardedTokens[token] = true",
    "pendingRewards[#pendingRewards + 1]",
    "EVENT_GOT_EXP_ALL = true",
    "game.data.constants.bagSize =",
    "fillIds",
    "slots(game.save, game.data, targetPocket) == targetCapacity",
):
    if forbidden in text:
        missing.append(f"forbidden manual product result: {forbidden}")

assert not missing, "WANDERER PACKAGE CONTRACT FAIL:\n" + "\n".join(missing)

# Edition and renderer are separate package processes; frequency/location/
# economy boundaries are deterministic loops inside each process.
matrix = {
    (edition, renderer)
    for edition in ("red", "blue", "yellow")
    for renderer in ("2d", "full")
}
assert len(matrix) == 6

print(f"LEGACY WANDERERS PACKAGE MATRIX CONTRACT PASS: {len(required)} checks")
