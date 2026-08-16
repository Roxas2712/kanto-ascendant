#!/usr/bin/env python3
"""Fail-closed static contract for the isolated Run-F Oak Lab real probe."""

from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[1]
DRIVER = ROOT / "tests/oaks_lab_runf_passable_follower_real_probe.lua"
PLAN = (
    ROOT
    / "qa/blitz_real_save_forensic_20260812/package_candidate"
    / "final_same_hash_plan.json"
)
RECEIPT = (
    ROOT
    / "qa/blitz_real_save_forensic_20260812/package_candidate"
    / "final_same_hash_receipt.json"
)
ORCHESTRATOR = (
    ROOT
    / "qa/blitz_real_save_forensic_20260812/package_candidate"
    / "final_same_hash_orchestrator.py"
)

source = DRIVER.read_text(encoding="utf-8")

required = (
    'local EXPECTED_IDENTITY =\n  "ka65-probe-oak-follower-passable-runf-20260813-01"',
    'local SCHEMA = "ka-oaks-lab-passable-follower-real-probe/v1"',
    'envRequired("KA_OAK_PROBE_OUTPUT_DIR")',
    'envRequired("KA_OAK_PROBE_SOURCE_SAVE_SHA256")',
    'envRequired("KA_OAK_PROBE_CLOSURE_TREE_SHA256")',
    'status = "FAIL"',
    'fail = 1',
    'phase = "module-load"',
    "writeReceipt()",
    'love.filesystem.getIdentity()',
    'envIdentity == EXPECTED_IDENTITY',
    'loveIdentity == EXPECTED_IDENTITY',
    'os.getenv("POKEPORT_VERSION") == "red"',
    'local continueLabel = Strings("CONTINUE")',
    'type(item.onSelect) == "function"',
    'selected.index == continueRow',
    'tap(game, "a")',
    'fieldIdle(game, "OAKS_LAB")',
    'player.cellX == 6 and player.cellY == 2',
    'player.facing == "down"',
    'ow.map:isWalkableCell(7, 2)',
    'atCell(entity, 7, 2)',
    'for _, list in ipairs({ ow.entities or {}, ow.npcs or {} }) do',
    'not seenRight[entity]',
    'right.pikachuFollower == true',
    'right.passable == true',
    'right.ambientSpecies == nil',
    'right.wildsAmbientPokemon ~= true',
    'Collision.occupied(ow.entities, 7, 2, player)',
    'capture(game, BEFORE_PATH)',
    'table.insert(game.input.pressQueue, "right")',
    'game.input.state.right = true',
    'coroutine.yield()',
    'game.input.state.right = false',
    'holdRightUntilLanding(game, 7, 2, 48)',
    'player.cellX == 7 and player.cellY == 2 and not player.moving',
    'capture(game, AFTER_PATH)',
    'receiptState.status = "PASS"',
    'receiptState.fail = 0',
    'receiptState.phase = "complete"',
)
for needle in required:
    assert needle in source, f"missing real-probe contract: {needle}"

# Receipt is armed before the returned coroutine can accept any input; PASS is
# written only after collision, live input, landing, and both PNG captures.
module_arm = source.index("-- Arm a fail-closed receipt")
return_driver = source.index("return function(game)")
first_field_input = source.index('tap(game, "start")', return_driver)
collision = source.index("Collision.occupied(ow.entities, 7, 2, player)")
before = source.index("capture(game, BEFORE_PATH)")
right_input = source.index("holdRightUntilLanding(game, 7, 2, 48)")
landing = source.index(
    "player.cellX == 7 and player.cellY == 2 and not player.moving",
    right_input,
)
after = source.index("capture(game, AFTER_PATH)")
passed = source.index('receiptState.status = "PASS"')
assert module_arm < return_driver < first_field_input
assert collision < before < right_input < landing < after < passed

# Physical proof must go through the same queue+hold seam as driver util.  It
# may observe Collision.occupied but cannot call a movement permission/action
# API or write a coordinate, map, save, or stack state directly.
banned = (
    "U.teleport",
    "OverworldState",
    "game:restoreSave",
    "SaveData.save",
    "SaveData.write",
    "game:writeSave",
    "player:tryMove",
    "Collision.canMove",
    "ow:setMap",
    "game.stack:pop",
    "game.stack:push",
)
for needle in banned:
    assert needle not in source, f"probe bypasses live input boundary: {needle}"
for assignment in (
    r"\bplayer\.cellX\s*=(?!=)",
    r"\bplayer\.cellY\s*=(?!=)",
    r"\bplayer\.facing\s*=(?!=)",
    r"\bgame\.save\.player\.x\s*=(?!=)",
    r"\bgame\.save\.player\.y\s*=(?!=)",
):
    assert not re.search(assignment, source), (
        f"probe bypasses live input boundary: coordinate assignment {assignment}"
    )

# The probe remains explicitly outside the immutable same-hash authority.  Its
# presence in source tests must not silently add a cell or mutate the frozen
# plan/receipt/orchestrator contract.
driver_name = DRIVER.name
for authority in (PLAN, RECEIPT, ORCHESTRATOR):
    assert driver_name not in authority.read_text(encoding="utf-8"), (
        f"isolated probe became plan-bound via {authority}"
    )

print(
    "oak lab Run-F passable-follower real-probe contract PASS: "
    "nonplanned fused identity; semantic CONTINUE; exact (6,2)->(7,2) "
    "queue input; Collision.occupied nil; fail-closed receipt; two PNGs"
)
