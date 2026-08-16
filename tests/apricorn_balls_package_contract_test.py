#!/usr/bin/env python3
"""Fail-closed source/plan contract for the installed Apricorn matrix."""

from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path


ROOT = Path(os.environ.get("TRAINER_REMATCH_MOD_DIR", Path(__file__).resolve().parents[1]))
DRIVER = ROOT / "tests/apricorn_balls_package_driver.lua"
VISUAL = ROOT / "tests/journeys_ball_skins_visual_driver.lua"
PLAN = ROOT / "qa/blitz_real_save_forensic_20260812/package_candidate/final_same_hash_plan.json"


def need(text: str, needle: str, label: str) -> None:
    assert needle in text, f"missing {label}: {needle}"


driver = DRIVER.read_text("utf-8")
visual = VISUAL.read_text("utf-8")
plan = json.loads(PLAN.read_text("utf-8"))

for needle in (
    'KA_PACKAGE_GATE") == "1"',
    'GameVersion.get()',
    'SaveData.setActiveSlot',
    'BattleState.catchAttempt',
    'ItemEffects.use(game.data, testSave, id, nil, legal)',
    'apricorn.quote("HEAVY_BALL"',
    'apricorn.quote("LEVEL_BALL"',
    'apricorn.quote("LURE_BALL"',
    'apricorn.quote("FAST_BALL"',
    'apricorn.quote("LOVE_BALL"',
    'Runtime.emit("pokemon.caught"',
    'apricorn.quote("MOON_BALL"',
    'journey.completeHevoPath',
    'workshop.purchaseBall(game, id, true)',
    'workshop.purchaseBall(game, "GS_BALL", true)',
    'PlayerPC.new(game, { direct = true })',
    'list.kind == "pc_item_" .. kind',
    'U.tap(game, "a")',
    'game:writeSave()',
    'SaveData.load()',
    'game:restoreSave(loaded, recovered)',
    'formula_matrix=7/7',
    'preflight_matrix=7/7',
    'blocked_preserved=14/14',
    'workshop_acquisition=7/7',
    'bag_pc_reload=PASS',
    'visual_states=49/49',
):
    need(driver, needle, "package mechanics/transaction contract")

for forbidden in (
    "game.save.inventory[id] = 1",
    "game.save.pcItems[id] = 1",
    "apricorn.applyFriendship(friend)",
    "battle.apricornBallQuote =",
    "love.filesystem.write",
):
    assert forbidden not in driver, f"driver bypasses product path: {forbidden}"

for needle in (
    'JOURNEYS_APRICORN_ONLY") == "1"',
    '"HEAVY_BALL", "LEVEL_BALL", "LURE_BALL", "FAST_BALL"',
    '"LOVE_BALL", "FRIEND_BALL", "MOON_BALL"',
    'observeAnimations',
    'BattleState.newWild',
    'BattleState.newTrainer',
    'battle:throwBall(ball)',
    'Bag.remove(game.save, ball, 1)',
    'trainer preflight changed the Bag',
    'BLOCKBALL_ANIM',
    'Pipelines.setLevel("voxel", 1)',
    'states = #BALLS * 7',
    'legal_consumptions=',
    'blocked_preserved=',
    'love.event.quit(0)',
):
    need(visual, needle, "Journeys visual contract")

lanes = {lane["lane_id"]: lane for lane in plan["lanes"]}
l07 = lanes["L07_BALLS_TMS_ITEM_UI"]
cells = {cell["id"]: cell for cell in l07["cells"]}
expected = {
    f"l07-apricorn-{edition}-{mode}"
    for edition in ("red", "blue", "yellow")
    for mode in ("2d", "full")
}
assert expected <= cells.keys(), f"missing Apricorn cells: {sorted(expected - cells.keys())}"
for cell_id in sorted(expected):
    cell = cells[cell_id]
    edition = cell_id.split("-")[2]
    mode = cell_id.split("-")[3]
    assert cell["edition"] == edition
    assert cell["closure"] == ("base_deutsch" if mode == "2d" else "dramaless_fp")
    assert cell["driver"] == "tests/apricorn_balls_package_driver.lua"
    assert cell["env"]["QA_RENDER_MODE"] == mode
    passes = cell.get("passes")
    assert isinstance(passes, list) and len(passes) == 3
    assert passes[0]["driver"] == "tests/apricorn_balls_package_driver.lua"
    assert passes[0]["env"] == {"QA_APRICORN_PHASE": "acquire"}
    assert passes[1]["driver"] == "tests/journeys_ball_skins_visual_driver.lua"
    assert passes[1]["env"] == {
        "JOURNEYS_APRICORN_ONLY": "1",
        "JOURNEYS_SKIN": "modern",
    }
    assert passes[2]["driver"] == "tests/apricorn_balls_package_driver.lua"
    assert passes[2]["env"] == {"QA_APRICORN_PHASE": "reload"}
    assert cell["images"] == {"exact_count": 52, "min_bytes": 1000}
    required = set(cell["result"]["contains"])
    assert {
        f"edition={edition}", f"renderer={mode}", "formula_matrix=7/7",
        "preflight_matrix=7/7", "blocked_preserved=14/14",
        "legal_consumptions=14/14",
        "workshop_acquisition=7/7", "bag_pc_reload=PASS",
        "visual_states=49/49", "status=PASS", "fail=0",
    } <= required

coverage = l07["coverage"]
for gate in ("BALL-001", "RC65-APRICORN-BALLS", "RC65-JOURNEYS-BALL-ART"):
    assert expected <= set(coverage[gate]), f"{gate} does not own all six cells"
assert "l07-blocked-ball-matrix" not in json.dumps(coverage, sort_keys=True)

print(
    "apricorn_balls_package_contract_test: PASS "
    f"(driver={hashlib.sha256(DRIVER.read_bytes()).hexdigest()[:12]} "
    f"visual={hashlib.sha256(VISUAL.read_bytes()).hexdigest()[:12]} "
    "cells=6 states=49/cell)"
)
