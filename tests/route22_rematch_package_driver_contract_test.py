#!/usr/bin/env python3
"""Fail closed if the six-cell Route 22 package bridge becomes decorative."""

from pathlib import Path
import json
import re


ROOT = Path(__file__).resolve().parents[1]
SETUP_PATH = ROOT / "tools/route22_rematch_qa_setup.lua"
DRIVER_PATH = ROOT / "tools/route22_rematch_package_driver.lua"
PLAN_PATH = (
    ROOT
    / "qa/blitz_real_save_forensic_20260812/package_candidate"
    / "final_same_hash_plan.json"
)
setup = SETUP_PATH.read_text("utf-8")
driver = DRIVER_PATH.read_text("utf-8")
setup_code = "\n".join(line.split("--", 1)[0] for line in setup.splitlines())
driver_code = "\n".join(line.split("--", 1)[0] for line in driver.splitlines())

# The setup is a package-gated prerequisite builder, not an acceptance
# controller.  Fresh uses the real empty New Game skeleton; ALT imports the
# orchestrator-pinned immutable BLITZ source and proves its completed Route 22
# shape before clearing only this bounded lifecycle.  Neither may touch a live
# user slot or infer an ambient developer path.
for token in (
    'os.getenv("KA_PACKAGE_GATE") == "1"',
    'expectedIdentity = ("ka65-final-route22-%s-%s")',
    'variant == "FRESH" or variant == "ALT"',
    '"/immutable_inputs/source_snapshot/slot7_original_readonly.lua"',
    'source == expectedSource',
    'fileSha256(source) == sourceSha',
    'KA_SOURCE_SAVE_SHA256',
    'KA_PACKAGE_GATE_RECEIPT_SHA256',
    'Application Support/pokemon-love2d/saves',
    'source/worktree path is not installed-package setup evidence',
    'SaveData.newGame(boot)',
    'native Fresh Route22 skeleton already contains campaign progress',
    'immutable ALT source lost its real completed Route22 migration shape',
    'immutable-blitz-cross-edition-clone',
    'red = { player = "RED", rival = "BLUE", third = "GREEN" }',
    'blue = { player = "BLUE", rival = "GREEN", third = "RED" }',
    'yellow = { player = "GREEN", rival = "RED", third = "BLUE" }',
    'characters.select(character.player)',
    'game:restoreSave(loaded, false)',
    'game:writeSave()',
    'SaveData.load(edition)',
    'SaveData.writeSlot(edition, lateSlot, late)',
    'slot65route22_',
    'qaRoute22Origin',
    'sourceSha256 = sourceSha',
    'packageGateReceiptSha256 = gateSha',
    'Pokemon.new(game.data, "MEWTWO", 100',
    '{ id = "SELFDESTRUCT", pp = 5 }',
    'loaded.lastHeal = { map = "PALLET_TOWN", x = 5, y = 6 }',
    'ROUTE22 PACKAGE SETUP PASS edition=%s variant=%s origin=%s',
):
    assert token in setup, token

# Only explicit prerequisite state is legal in the setup.  First starts with
# both story flags clear; late owns the documented first/Brock/Giovanni wins
# and still leaves the second flag clear.  The acceptance driver must earn all
# four requested battle outcomes itself.
for token in (
    'loaded.flags.EVENT_BEAT_ROUTE22_RIVAL_1ST_BATTLE = nil',
    'loaded.flags.EVENT_BEAT_ROUTE22_RIVAL_2ND_BATTLE = nil',
    'late.flags.EVENT_BEAT_ROUTE22_RIVAL_1ST_BATTLE = true',
    'late.flags.EVENT_BEAT_BROCK = true',
    'late.flags.EVENT_BEAT_GIOVANNI = true',
    'late.flags.EVENT_BEAT_ROUTE22_RIVAL_2ND_BATTLE = nil',
):
    assert token in setup, token
for forbidden in (
    'route22.onStep(',
    '_kantoAscendantTalkRuntime.handle(',
    'BattleState.newTrainer(',
    'Runtime.emit("battle.ended"',
    'U.teleport(',
):
    assert forbidden not in setup_code, forbidden

# The runtime driver is tied to all package receipts and exact isolated cell
# identity.  It loads the first slot through title CONTINUE, then uses native
# write/load/restore boundaries for both loss/retry/win sequences.
for token in (
    'DRV-ROUTE22-REMATCH-ALT',
    'KA_ENGINE_PAYLOAD_SHA256',
    'KA_AUTHORITY_PACKAGE_SHA256',
    'KA_DEUTSCH_PACKAGE_SHA256',
    'KA_SOURCE_SAVE_SHA256',
    'KA_PACKAGE_GATE_RECEIPT_SHA256',
    'source/worktree path is not installed-package evidence',
    'expectedIdentity = ("ka65-final-route22-%s-%s")',
    'U.tap(game, "start")',
    'title CONTINUE did not load the Route22 first slot',
    'SaveData.setActiveSlot(edition, slot)',
    'SaveData.load(edition)',
    'game:restoreSave(loaded, recovered)',
    'game:writeSave()',
    'assertOrigin("first")',
    'assertOrigin("late")',
):
    assert token in driver, token

# Both authored encounters must start by walking onto the actual map-script
# trigger and resolve through ordinary BattleState menu input.  Runtime events
# are observation only; party indexes/class/identity also prove this was not a
# generic or scaled rematch.
for token in (
    'U.tap(game, "right")',
    'getmetatable(top) == BattleState',
    'battle.started',
    'battle.ended',
    'world.blacked_out',
    'payload.result',
    '"OPP_RIVAL1"',
    '"OPP_RIVAL2"',
    'battle.partyIndex == wantedParty',
    'battle.rematch ~= true',
    'battle.rematchLevelBoost == nil',
    'battle.trainer.ascendantCharacter == expectedCharacter.rival',
    'driveBattle("first_loss", 1, "lose")',
    'driveBattle("first_win", "best", "win")',
    'driveBattle("late_loss", 1, "lose")',
    'driveBattle("late_win", "best", "win")',
    'first_loss_reload_win=PASS',
    'late_loss_reload_win=PASS',
    'physical_battle_states=4/4',
    'physical_blackouts=2/2',
    'native_save_reload=4/4',
):
    assert token in driver, token

# Route 22's authored rivals must never enter the Authority generic-rematch
# state.  A ChoiceBox on the physical ambush step is an immediate failure.
for token in (
    'local states = api.trainerStates()',
    'game.save.defeatedTrainers',
    'states[key] == nil',
    'getmetatable(top) == ChoiceBox',
    'opened a generic rematch ChoiceBox',
    'generic_rematch_conflict=NONE',
):
    assert token in driver, token

# Coexistence is real map interaction, not a static asset lookup: one wall
# decal and one passable anchor remain beside exactly one instance of each
# rival.  The driver finds a collision-valid route, walks to (35,2), turns via
# ordinary UP input, presses A and reads the product TextBox without accepting
# a warp.  Non-RED identities must receive the rightful-path denial.
for token in (
    'object.name == "ROUTE22_RIVAL1"',
    'object.name == "ROUTE22_RIVAL2"',
    'decal.id == "KA_HEVO_WALL_FISSURE_RED"',
    'decal.cellX == 35 and decal.cellY == 1',
    'hidden_evolution/sealed_fissure.png',
    'npc.def.name == "KA_HEVO_FISSURE_RED"',
    'npc.passable == true',
    'walkToCell(35, 2)',
    'map:isWalkableCell(x, y)',
    'U.tap(game, "up")',
    'U.tap(game, "a")',
    'fissureBox and fissureBox.pages',
    'Feldforscher',
    'field researcher',
    'nicht deiner',
    'not yours',
    'game.overworld.map.id == "ROUTE_22"',
    'fissure_coexistence=PASS',
):
    assert token in driver, token

# Five independently named captures are required in every cell.
shots = re.findall(r'"(0[1-5]_[a-z_]+)"', driver)
assert shots == [
    "01_first_loss_intro",
    "02_first_retry_intro",
    "03_late_loss_intro",
    "04_late_retry_intro",
], shots
assert '"/05_fissure_coexistence.png"' in driver

# The driver is input/observation only.  In particular it cannot set story,
# identity, party, generic-rematch, battle result/damage/HP or fissure state.
for forbidden in (
    'SaveData.newGame(',
    'U.teleport(',
    'BattleState.newTrainer(',
    'route22.onStep(',
    '_kantoAscendantTalkRuntime.handle(',
    'Runtime.emit("battle.ended"',
    ':onFinish(',
    '.onFinish =',
    'characters.select(',
    'P.enter(',
    'A.enter(',
):
    assert forbidden not in driver_code, forbidden
for pattern in (
    r'game\.save\.flags(?:\[[^]]+\]|\.[A-Z0-9_]+)\s*=(?!=)',
    r'game\.save\.party\s*=(?!=)',
    r'game\.save\.defeatedTrainers(?:\[[^]]+\])?\s*=(?!=)',
    r'game\.save\.modData\s*=(?!=)',
    r'\.player_character\s*=(?!=)',
    r'\.rival_character\s*=(?!=)',
    r'\.third_character\s*=(?!=)',
    r'\.result\s*=(?!=)',
    r'\.hp\s*=(?!=)',
    r'\.damage\s*=(?!=)',
    r'\.facing\s*=(?!=)',
):
    assert not re.search(pattern, driver_code), pattern

# Exact required Cartesian product.  The orchestration contract imports this
# set after static green; until then no blocked row may be called covered.
matrix = {
    (edition, variant): f"ka65-final-route22-{edition}-{variant.lower()}"
    for edition in ("red", "blue", "yellow")
    for variant in ("FRESH", "ALT")
}
assert len(matrix) == 6 and len(set(matrix.values())) == 6

plan = json.loads(PLAN_PATH.read_text("utf-8"))
lane = next(row for row in plan["lanes"] if row["lane_id"] == "L08_OAK_MEW_ROUTE22")
cells = {
    (cell["edition"], cell.get("env", {}).get("ROUTE22_QA_VARIANT")): cell
    for cell in lane["cells"]
    if cell.get("driver") == "tools/route22_rematch_package_driver.lua"
}
assert set(cells) == set(matrix), set(cells)
expected_characters = {
    "red": ("RED", "BLUE"),
    "blue": ("BLUE", "GREEN"),
    "yellow": ("GREEN", "RED"),
}
for (edition, variant), identity in matrix.items():
    cell = cells[(edition, variant)]
    assert cell["id"] == f"l08-route22-{edition}-{variant.lower()}"
    assert cell["identity"] == identity
    assert cell["closure"] == "base_deutsch"
    assert cell["setup"] == "tools/route22_rematch_qa_setup.lua"
    assert cell["timeout_seconds"] >= 2400
    assert cell["env"] == {"ROUTE22_QA_VARIANT": variant}
    player, rival = expected_characters[edition]
    assert cell["result"]["path"] == "driver_result.txt"
    assert set(cell["result"]["contains"]) == {
        "status=PASS",
        "scope=ROUTE22-REMATCH-ALT",
        f"edition={edition}",
        f"variant={variant}",
        f"player_character={player}",
        f"rival_character={rival}",
        "first_loss_reload_win=PASS",
        "late_loss_reload_win=PASS",
        "fissure_coexistence=PASS",
        "generic_rematch_conflict=NONE",
        "native_save_reload=4/4",
        "physical_battle_states=4/4",
        "physical_blackouts=2/2",
        "fail=0",
    }
    assert cell["images"] == {"exact_count": 5, "min_bytes": 1000}

cell_ids = {cell["id"] for cell in cells.values()}
assert set(lane["coverage"]["RC65-ROUTE22-REMATCH"]) == cell_ids
assert not any(
    cell.get("blocker") == "DRV-ROUTE22-REMATCH-ALT"
    for cell in lane["cells"]
)
for reference in (
    "tools/route22_rematch_qa_setup.lua",
    "tools/route22_rematch_package_driver.lua",
    "tests/route22_rematch_package_driver_contract_test.py",
):
    assert reference in lane["source_references"], reference

for source in (setup, driver):
    assert "/Users/" not in source
    assert ".worktrees/ka-" not in source

print(
    "Route22 package driver contract PASS: R/B/Y x Fresh/Alt physical "
    "first+late loss/reload/win + fissure/no-generic"
)
