#!/usr/bin/env python3
"""Fail closed if the connected-Johto package proof becomes a state script."""

from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[1]
driver = (ROOT / "tools/johto_masters_passages_pure_qa.lua").read_text()
setup = (ROOT / "tools/johto_masters_passages_qa_setup.lua").read_text()
passages = (ROOT / "johto_masters_passages.lua").read_text()
driver_code = "\n".join(line.split("--", 1)[0] for line in driver.splitlines())
setup_code = "\n".join(line.split("--", 1)[0] for line in setup.splitlines())

# The setup may strengthen a disposable party and choose a safe start cell.
# BLITZ progression authority remains the immutable input; FRESH must start
# at the engine's native New Game hook before its explicit bounded Hall gate.
assert "KA_PACKAGE_GATE" in setup
assert 'variant=="BLITZ" or variant=="FRESH"' in setup
assert 'renderer=="2D" or renderer=="FULL"' in setup
assert 'expectedIdentity=("ka65-final-johto-connected-%s-%s")' in setup
assert 'source==expectedSource' in setup
assert 'fileSha256(source)==sourceSha' in setup
assert 'KA_PACKAGE_GATE_RECEIPT_SHA256' in setup
assert 'KA_SOURCE_SAVE_SHA256' in setup
assert "Application Support/pokemon-love2d/saves" in setup
assert "/qa/blitz_real_save_forensic_20260812/source_snapshot/" not in setup
assert "old.version==2 and old.clears==4 and old.gifts==4" in setup
assert "setup itself migrated or fabricated BLITZ Johto progression" in setup
assert "immutable BLITZ save no longer supports the legal post-credits FLY return" in setup
for token in (
    "SaveData.newGame(boot)",
    'loaded.player.name=="FRESH" and loaded.money==3000',
    "native Fresh skeleton already contains story/postgame progress",
    "native Fresh skeleton already contains Johto progression",
    'kind=variant=="FRESH" and "native-save-new-game"',
    "Fresh setup fabricated Johto progression before package reload",
    "packageGateReceiptSha256=gateSha",
    "JOHTO CONNECTED SETUP PASS variant=%s renderer=%s origin=%s",
):
    assert token in setup, token
assert 'loaded.lastOutdoor={id="INDIGO_PLATEAU",x=9,y=5}' in setup
assert "isolated prerequisite slot lost the real outdoor LAST_MAP return" in setup
assert 'loaded.hallOfFame={{{species="CHARIZARD",level=80}}}' in setup
assert "physically clearing Lorelei, Bruno, Agatha, Lance and the Champion" in setup
for forbidden in (
    "johtoMastersPassages", "P.enter(", "P.inspect(", "P.choose(",
    "P.solve(", "P.startBattle(", "table.insert(loaded.hallOfFame",
):
    assert forbidden not in setup_code, forbidden
for field in ("connectedClears", "journeyClears", "activeRun", "gifts"):
    assert not re.search(rf"\.{field}\s*(?<![=])=(?!=)", setup_code), field

# Every package/renderer identity is part of the receipt boundary.
for token in (
    "KA_ENGINE_PAYLOAD_SHA256",
    "KA_AUTHORITY_PACKAGE_SHA256",
    "KA_DEUTSCH_PACKAGE_SHA256",
    "KA_PACKAGE_GATE_RECEIPT_SHA256",
    "KA_SOURCE_SAVE_SHA256",
    "KA_DRAMALESS_PACKAGE_SHA256",
    "QA_RENDERER",
    'renderer=="2D" or renderer=="FULL"',
    'variant=="BLITZ" or variant=="FRESH"',
    'expectedIdentity=("ka65-final-johto-connected-%s-%s")',
    "native-save-new-game",
    "immutable-blitz-migration",
    "connected Johto package origin is not pinned to this cell",
):
    assert token in driver, token

# The accepted host copy is exact in both languages and is observed twice:
# BLITZ migration and the physical Elite-Four re-clear cadence.
for text in (
    "The Johto Masters' host awaits you. SILVER, KRIS and GOLD challenge you in three arenas. He leads you to the Gate Hall now - SILVER waits first.",
    "Der Gastgeber der Johto-Meister erwartet dich. SILVER, KRIS und GOLD fordern dich in drei Arenen heraus. Er führt dich jetzt zur Torhalle - SILVER wartet zuerst.",
    "00b_initial_host_reloaded",
    "05_host_after_e4_reclear",
    "post-reclear reload duplicated or lost the Johto host",
    "Exact-copy receipts intentionally keep the production TextBox open",
    "mt and mt.__index==TextBox",
):
    assert text in driver, text

# Connected route: wrong answer, native saves, loss/retry, all three masters,
# exact-once Gold reward, real League rooms, HoF receipt and physical Fly back.
for token in (
    "TEXT_KA_JOHTO_SILVER_DECISION_2",
    "native save write failed after Silver step 2",
    'finishRoute("kris")',
    'finishRoute("gold")',
    "Gold reward did not persist exactly once",
    'awaitMap("INDIGO_PLATEAU","Gate Hall return")',
    'walkToCell(9,5,"Indigo lobby return door")',
    "Indigo lobby did not reset prior League flag",
    "Indigo lobby did not re-arm League trainer",
    "returning from Gate Hall manufactured a League cadence receipt",
    'walkToCell(8,0,"Lorelei entrance warp")',
    '"OPP_LORELEI"',
    '"OPP_BRUNO"',
    '"OPP_AGATHA"',
    '"OPP_LANCE"',
    '"OPP_RIVAL3"',
    'current.id:find("^KA_JOHTO_")',
    "unexpected native overworld FULL capture",
    "non-overworld FULL capture is not a Johto/League battle",
    "Champion re-clear did not record one Hall row and return to title",
    'mapId=="INDIGO_PLATEAU"',
    "one Elite-Four receipt did not unlock exactly one fresh Silver-first run",
    "JOHTO CONNECTED PHYSICAL START variant=%s renderer=%s hall=%d",
    "JOHTO CONNECTED PHYSICAL PASS variant=%s renderer=%s",
    "host_to_silver_kris_gold=PASS",
    "loss_retry_reload_music=PASS",
    "e4_reclear_host_respawn=PASS",
):
    assert token in driver, token

# Johto music must start audibly and restore after both losses and wins.
for token in (
    "ChipAudio.awaitingFirstBuffer",
    "Music_KA_GSC_RivalBattle",
    "Music_KA_GSC_IndigoPlateau",
    "Silver loss map-theme restore",
    "Silver win map-theme restore",
    'key.." loss map-theme restore"',
    'key.." win map-theme restore"',
):
    assert token in driver, token

# No acceptance result may be manufactured through controller calls, a QA
# teleport or a direct Hall/reward/passages assignment.
for forbidden in (
    "U.teleport",
    "P.enter(",
    "P.inspect(",
    "P.choose(",
    "P.solve(",
    "P.startBattle(",
    "table.insert(game.save.hallOfFame",
    "game.save.hallOfFame[",
):
    assert forbidden not in driver_code, forbidden
for field in ("connectedClears", "journeyClears", "activeRun", "gifts"):
    assert not re.search(rf"\.{field}\s*(?<![=])=(?!=)", driver_code), field

# FRESH and BLITZ may differ only in their setup/origin assertions.  Once the
# title CONTINUE settles, there is one shared physical implementation rather
# than a shorter Fresh-only state script.
assert driver_code.count('variant=="FRESH"') == 2
assert "if variant" not in driver_code
assert "SaveData.newGame" not in driver_code
assert "loaded.hallOfFame=" not in driver_code

# Exactly four final cells are required: variant changes save provenance;
# renderer changes the loaded closure.  Edition/locale do not change this
# feature's authority and deterministic rolls stay inside each process.
matrix = {
    (variant, renderer):
        f"ka65-final-johto-connected-{variant.lower()}-{renderer.lower()}"
    for variant in ("BLITZ", "FRESH")
    for renderer in ("2D", "FULL")
}
assert len(matrix) == 4 and len(set(matrix.values())) == 4

# Gold's run-serial transaction is the exact-once authority.  It must commit
# before the local passage receipt, so an interruption can leave only stale
# presentation state and can never strand or duplicate the shiny reward.
reward_commit = passages.index("local message=baseline.completeRun(game)")
passage_receipt = passages.index(
    'p.status="cleared";p.puzzle=false;p.rewarded=true', reward_commit
)
assert reward_commit < passage_receipt
assert "shouldReward" not in passages

print("Johto Masters package driver contract: PASS")
