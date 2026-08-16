#!/usr/bin/env python3
"""Fail-closed source contract for the additive Espeon battle-EXP proof."""

from __future__ import annotations

import hashlib
from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[1]
DRIVER = ROOT / "tests/espeon_psybeam_battle_exp_visual_driver.lua"
OLD_DRIVER = ROOT / "tools/espeon_psybeam_love_qa_driver.lua"
FROZEN_OLD_DRIVER = (
    ROOT
    / "qa/blitz_real_save_forensic_20260812/package_candidate/inputs"
    / "harness_snapshot/tools/espeon_psybeam_love_qa_driver.lua"
)
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

EXPECTED_AUTHORITY_HASHES = {
    PLAN: "dbb78fcc28bf9e10fe673a2d00bc5f20820db175c4425b2ae68e81356f6b4862",
    RECEIPT: "dc71b38eae1fe0fa91a8091bf38a27294a754d6455f7ebd65c4db451dc877410",
    ORCHESTRATOR: "bb5c84abfc19a70344b83c374ada3a61ae4d3ef4b9e74773675d49b6a401264f",
}
EXPECTED_OLD_DRIVER_SHA256 = (
    "93613b90b4ecf551c521be7de86fe07997e74801dcc002aa51f555b8f2288ac2"
)


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


source = DRIVER.read_text(encoding="utf-8")
code = "\n".join(line.split("--", 1)[0] for line in source.splitlines())

# This is an additive, non-planned probe.  It must not alter the existing
# Rare-Candy/Reminder proof or any immutable same-hash authority.
assert digest(OLD_DRIVER) == EXPECTED_OLD_DRIVER_SHA256, digest(OLD_DRIVER)
assert digest(FROZEN_OLD_DRIVER) == EXPECTED_OLD_DRIVER_SHA256, digest(
    FROZEN_OLD_DRIVER
)
for path, expected in EXPECTED_AUTHORITY_HASHES.items():
    assert digest(path) == expected, f"immutable authority changed: {path}"

identities = tuple(
    f"ka65-probe-espeon-battle-exp-{edition}-20260813-03"
    for edition in ("red", "blue", "yellow")
)
for authority in (PLAN, RECEIPT, ORCHESTRATOR):
    authority_text = authority.read_text(encoding="utf-8")
    assert DRIVER.name not in authority_text, (
        f"additive battle probe became plan-bound via {authority}"
    )
    for identity in identities:
        assert identity not in authority_text, (
            f"non-planned identity became gate authority via {authority}"
        )

# Fail-closed evidence and exact fresh R/B/Y identity boundary.
required = (
    'local SCHEMA = "ka-espeon-battle-exp-visual/v1"',
    'red = "ka65-probe-espeon-battle-exp-red-20260813-03"',
    'blue = "ka65-probe-espeon-battle-exp-blue-20260813-03"',
    'yellow = "ka65-probe-espeon-battle-exp-yellow-20260813-03"',
    'envRequired("KA_ESPEON_BATTLE_OUTPUT_DIR")',
    'envRequired("KA_TEST_UTIL")',
    'love.filesystem.getIdentity()',
    'envIdentity == EXPECTED_IDENTITY',
    'loveIdentity == EXPECTED_IDENTITY',
    'local diskBefore = SaveData.load(EDITION)',
    'disk_save_absent_before_setup = diskBefore == nil and 1 or 0',
    'status = "FAIL"',
    'fail = 1',
    'phase = "module-load"',
    'writeReceipt()',
    'xpcall(function() run(game) end, debug.traceback)',
    'love.event.quit(1)',
    'receiptState.status = "PASS"',
    'receiptState.fail = 0',
    'receiptState.phase = "complete"',
    'love.event.quit(0)',
)
for token in required:
    assert token in source, f"missing fail-closed/identity contract: {token}"

module_receipt = source.index("-- Arm fail-closed output")
run_function = source.index("local function run(game)")
returned_driver = source.index("return function(game)")
first_input = source.index('tap("a") -- FIGHT')
pass_promotion = source.index('receiptState.status = "PASS"')
assert module_receipt < run_function < first_input < pass_promotion < returned_driver
receipt_order = source[source.index("local order = {") : source.index(
    "local body, emitted", source.index("local order = {")
)]
assert receipt_order.index('"status"') < receipt_order.index('"fail"')
assert receipt_order.index('"fail"') < receipt_order.index('"schema"')
wrapper_xpcall = source.index("local ok, why = xpcall", returned_driver)
wrapper_restore = source.index("restoreObserver()", wrapper_xpcall)
wrapper_branch = source.index("if ok then", wrapper_restore)
assert returned_driver < wrapper_xpcall < wrapper_restore < wrapper_branch

# The setup is exactly L35 and one EXP point below 36.  Pokemon.new must
# derive the four production moves; the driver may not author a replacement
# moveset of its own.
for token in (
    'local espeon = Pokemon.new(game.data, "ESPEON", 35,',
    'espeon.exp = threshold36 - 1',
    'Growth.expForLevel(espeonDef.growthRate, 36,',
    'Growth.expForLevel(espeonDef.growthRate, 37,',
    'threshold36 - espeon.exp == 1',
    '"SAND_ATTACK", "CONFUSION", "QUICK_ATTACK", "SWIFT"',
    'local naturalMovesExact = #espeon.moves == #expectedNaturalMoves',
    'espeon.moves[index] and espeon.moves[index].id == moveId',
    'naturalMovesExact and not hasPsybeamBefore',
    'not hasPsybeamBefore',
    'game.save.party = { espeon }',
    'local expSettings = rematchRewards.state(game)',
    'expSettings.expShareSetting == "off"',
    'expSettings.expMultiplierSetting == 0',
    '(game.save.inventory.EXP_ALL or 0) == 0',
    'game.save.options.battleLayout = "og"',
):
    assert token in source, f"missing exact level-35 setup: {token}"

# The only progression is a real BattleState wild KO selected via FIGHT and
# natural QUICK_ATTACK.  Bounding target HP/speed/RNG is permitted;
# queue/result/level/move
# injection is not.
for token in (
    'BattleState.newWild(game, "PIDGEY", 2, {',
    'randomizerProtected = true',
    'battle.enemy.mon.species == "PIDGEY"',
    'battle.enemy.mon.level == 2',
    'battle.randomizerProtected == true',
    'overworld:pushBattle(battle)',
    'battle.kind == "wild"',
    'battle.rng = function(low) return low end',
    'battle.enemy.mon.hp = 1',
    'battle.enemy.mon.stats.speed = 1',
    'battle.phase == "menu"',
    'tap("a") -- FIGHT',
    'battle.phase == "moveSelect"',
    'tap("down")',
    'battle.moveIndex == 3',
    'battle.player.curMoves[battle.moveIndex].id == "QUICK_ATTACK"',
    'tap("a") -- QUICK_ATTACK; the real damage/faint/EXP pipeline starts here',
    'name == "battle.started"',
    'name == "battle.exp_gained"',
    'name == "battle.ended"',
    '#observed.exp.levels == 1',
    'observed.exp.levels[1] == 36',
    'observed.exp.gained == expectedGain',
    'battle.enemy.mon.hp <= 0',
    'observed.ended == "win"',
    'battle.current.text ~= expectedText',
    'battle.charIndex >= battle.total and battle.msgPrompt == true\n'
    '            and (battle.msgPromptWait or 0) <= 0',
    'battle.msgWaiting == true\n'
    '            and (battle.msgPreWait or 0) <= 0',
    'preExpPromptsAdvanced = preExpPromptsAdvanced + 1',
    'receiptState.pre_exp_prompts_advanced = preExpPromptsAdvanced',
):
    assert token in source, f"missing real battle path: {token}"

for forbidden in (
    "RARE_CANDY",
    "Bag.add",
    "Move Reminder",
    "fieldTech",
    "battle:say(",
    "battle:sayNext(",
    "battle:ui(",
    "battle:uiNext(",
    "battle:learnMove(",
    "battle:awardExp(",
    "Experience.apply(",
    "table.insert(battle.queue",
    "battle.queue =",
    "battle.result =",
    "espeon.level = 36",
    "espeon.moves[1] =",
    "SaveData.newGame(",
    "SaveData.writeSlot(",
    "SaveData.save(",
    "/private/tmp/ka-final-same-hash",
):
    assert forbidden not in code, f"probe bypasses production path: {forbidden}"
assert code.count('U.teleport(game, "ROUTE_1", 5, 5, "down")') == 1

# Four precisely named renderer captures bind the requested UI states.  Each
# capture is guarded by state/model evidence and validates PNG signature/size.
for token in (
    '"/01_battle_exp_gained.png"',
    '"/02_grew_level36.png"',
    '"/03_psybeam_offer.png"',
    '"/04_psybeam_learned.png"',
    'signature == "\\137PNG\\r\\n\\26\\n"',
    'size >= 1000',
    'battleMessageReady(battle, function(text)',
    'if battle.msgWaiting == true and (battle.msgPreWait or 0) <= 0 then',
    'return battle.charIndex >= battle.total and battle.msgPrompt == true\n'
    '      and (battle.msgPromptWait or 0) <= 0',
    'local expectedText = observed.exp and Strings(',
    '"%s gained\\n%d EXP. Points!", battle.player.name, observed.exp.gained)',
    'return text == expectedText',
    'text == Strings("%s grew\\nto level %d!", battle.player.name, 36)',
    'learnMenu.newMoveId == "PSYBEAM"',
    'reachTextPage(offerBox, offerPage,',
    'not hasMove(espeon, "PSYBEAM")',
    'tap("a") -- YES, through the real ChoiceBox',
    'learnMenu.index == 1 and espeon.moves[1].id == "SAND_ATTACK"',
    'tap("a") -- replace SAND_ATTACK; MoveLearnMenu performs the production mutation',
    'reachTextPage(learnedBox, learnedPage,',
    'learned and learnedCount == 1 and #espeon.moves == 4',
    'receiptState.screenshots_written = "4/4"',
):
    assert token in source, f"missing visual-state proof: {token}"

capture_order = [
    source.index("capture(SCREENSHOTS.exp"),
    source.index("capture(SCREENSHOTS.level"),
    source.index("capture(SCREENSHOTS.offer"),
    source.index("capture(SCREENSHOTS.learned"),
]
assert capture_order == sorted(capture_order)
assert capture_order[-1] < pass_promotion

# Persistence must cross the engine's native write/load/restore boundary.
for token in (
    'local saved = game:writeSave()',
    'local loaded, recovered = SaveData.load(EDITION)',
    'game:restoreSave(loaded, recovered)',
    'persisted.species == "ESPEON"',
    'persisted.level == 36',
    '#persisted.moves == 4',
    'persistedPsybeam and persistedCount == 1',
    'native_save_reload=1/1 fail=0',
):
    assert token in source, f"missing native persistence proof: {token}"
assert source.index("capture(SCREENSHOTS.learned") < source.index(
    "local saved = game:writeSave()"
)
assert source.index("game:restoreSave(loaded, recovered)") < pass_promotion

# Only the explicitly documented setup may assign progression-bearing fields.
assert len(re.findall(r"\bespeon\.exp\s*=(?!=)", code)) == 1
assert len(re.findall(r"\bgame\.save\.party\s*=(?!=)", code)) == 1
assert not re.search(r"\bespeon\.moves\s*=(?!=)", code)
assert code.count('tap("down")') == 2
assert not re.search(r"\b(?:battle|espeon)\.phase\s*=(?!=)", code)
assert not re.search(r"\b(?:battle|espeon)\.result\s*=(?!=)", code)
assert not re.search(r"\b(?:battle|espeon)\.level\s*=(?!=)", code)

print(
    "Espeon battle-EXP visual driver contract PASS: R/B/Y fresh non-planned "
    "identities; natural moves + real FIGHT/QUICK_ATTACK wild KO; four PNGs; "
    "native save/reload; "
    "immutable same-hash authority and Rare-Candy driver unchanged"
)
