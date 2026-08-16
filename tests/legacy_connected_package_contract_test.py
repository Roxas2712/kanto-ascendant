#!/usr/bin/env python3
"""Fail-closed static contract for the L04 connected Legacy package matrix."""

from __future__ import annotations

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    path = ROOT / relative
    assert path.is_file(), f"missing connected Legacy harness file: {relative}"
    return path.read_text("utf-8")


LANGUAGE = read("tests/legacy_connected_language_setup_driver.lua")
STORY = read("tests/legacy_story_partner_fresh_e2e_driver.lua")
ARCHIVE = read("tools/legacy_archive_transaction_package_driver.lua")
DAYCARE = read("tests/legacy_archive_daycare_visual_driver.lua")
WORKSHOP = read("tools/ngplus_legacy_workshop_e2e_driver.lua")
RESONANCE = read("tools/ngplus_legacy_workshop_resonance_e2e_driver.lua")
TITLE = read("tests/legacy_wanderer_title_visual_driver.lua")
MATRIX = read("tools/legacy_connected_package_matrix_manifest.lua")
PACT = read("tests/legacy_pact_three_journeys_visual_driver.lua")

PACKAGE_DRIVERS = {
    "language setup": LANGUAGE,
    "connected story/partner": STORY,
    "archive transaction": ARCHIVE,
    "archive Day-Care": DAYCARE,
    "Workshop product": WORKSHOP,
    "Workshop resonance": RESONANCE,
    "title/archive card": TITLE,
}

for label, source in PACKAGE_DRIVERS.items():
    for token in (
        'os.getenv("KA_PACKAGE_GATE") == "1"',
        'os.getenv("KA_CLOSURE_PROFILE")',
        'KA_ENGINE_PAYLOAD_SHA256',
        'KA_AUTHORITY_PACKAGE_SHA256',
        'KA_DEUTSCH_PACKAGE_SHA256',
        'KA_PACKAGE_GATE_RECEIPT_SHA256',
        '".worktrees"',
        '"/Documents/Recompile/"',
    ):
        assert token in source, f"{label} lacks package boundary: {token}"
    assert "/Users/" not in source, f"{label} embeds a developer path"

for label, source in {
    "connected story/partner": STORY,
    "archive transaction": ARCHIVE,
    "archive Day-Care": DAYCARE,
    "Workshop product": WORKSHOP,
    "Workshop resonance": RESONANCE,
    "title/archive card": TITLE,
}.items():
    for token in (
        "installed package registry is unavailable",
        "loadedMods.kanto_ascendant" if label != "archive transaction"
        else "loaded.kanto_ascendant",
        "love.filesystem.getSource()",
        'not path:find("/tests/", 1, true)',
        'not path:find("/tools/", 1, true)',
    ):
        assert token in source, f"{label} lacks provenance seam: {token}"

# R/B/Y x EN/DE language is a persisted launcher state, never a mocked i18n
# table.  A subsequent process reads the exact same isolated identity.
for token in (
    'red = "deutsch", blue = "deutsch-blau", yellow = "deutsch-gelb"',
    "LauncherMods.setEnabled(languageId, false, edition)",
    "SaveData.modEnabled(options, languageId",
    'exports.language() == "de"',
    "count == 2",
    "language_setup_result.txt",
):
    assert token in LANGUAGE, f"language setup bypassed native state: {token}"

# The connected story starts at a real Hall sequence, uses physical PC/ball/
# Oak input, proves both independent default-NO boundaries, reloads while the
# Lab is locked, physically collides with the exit, and reloads the committed
# partner/rival once more.
for token in (
    'U.teleport(game, "HALL_OF_FAME", 4, 7, "up")',
    'physicalInteract("OAKS_LAB", 1, 2, "up")',
    "firstConfirm and firstConfirm.index == 2",
    "finalConfirm and finalConfirm.index == 2",
    'physicalInteract("OAKS_LAB", 7, 4, "up")',
    'physicalInteractNpc("OAKSLAB_OAK1")',
    "partnerConfirm and partnerConfirm.index == 2",
    "partnerFinal and partnerFinal.index == 2",
    "proveReloadedLockedLab",
    "game:writeSave()",
    "SaveData.load()",
    "game:restoreSave(loaded, recovered)",
    "starters.labExitLocked(game.save)",
    'U.tap(game, "down")',
    'game.overworld.map.id == "OAKS_LAB"',
    "state().rivalBallTaken == true",
    "state().rivalPartner.sourcePartner == chosenSpecies",
    'result:write("fresh_confirm_default_no=2/2',
    'result:write("partner_confirm_default_no=2/2',
    'result:write("mid_phase_native_reload="',
    'result:write("physical_lab_exit_lock="',
    'result:write("partner_rival_durable="',
):
    assert token in STORY, f"connected story contract missing: {token}"
for forbidden in (
    "journey.resumeFreshLab",
    "starters.choose(",
    "archive.write(",
    "bucket.legacy_journey =",
):
    assert forbidden not in STORY, f"connected story stages product state: {forbidden}"

# The transaction lane compiles the installed module and failure-injects its
# real two-file protocol.  It must prove immutable outgoing saves, committed
# witness recovery, exact-once replay and additive exactly-once migration.
for token in (
    'installed:read("legacy_archive.lua")',
    "loadstring(source",
    "requireRegistryValidation = true",
    "rollbackArchive.normalize({ version = 1 })",
    "currentVersion == 7",
    "rollbackFs.failAt[rollbackArchive.filename .. \".tmp\"]",
    "recoveryFs.failAt[recoveryArchive.filename]",
    "Serializer.encode(rollbackSave) == rollbackSaveBefore",
    "Serializer.encode(recoverySave) == recoverySaveBefore",
    "#exactOnce.bank == 1",
    "#exactOnce.hallOfLegacy == 1",
    "migrationSentinel.partner == \"KEEP\"",
    "writesAfter - writesBefore == 1",
    "failed_witness_rollback=1/1",
    "committed_witness_recovery=1/1",
    "same_source_retry_exact_once=1/1",
    "v1_to_v7_migration=1/1",
):
    assert token in ARCHIVE, f"archive transaction contract missing: {token}"
for forbidden in (
    'loadfile("legacy_archive.lua")',
    'dofile("legacy_archive.lua")',
    "rollbackArchive.version",
    "recoveryArchive.version",
    "migrationArchive.version",
):
    assert forbidden not in ARCHIVE, f"archive lane uses a forbidden shortcut: {forbidden}"

for token in (
    "game.overworld:openPC",
    "game.save.daycare and game.save.daycare.mon",
    "daycare_plus.parents",
    "daycare_plus.reservedEggs",
    "pageText(retry) == plusText and emptyArchive()",
    "actual New Game hook seeds cycle one",
    "game:writeSave()",
    "SaveData.load()",
    "game:restoreSave(reloaded, recovered)",
    "blocked_retry_side_effect_free=1/1",
    "native_save_reload=1/1",
):
    assert token in DAYCARE, f"Day-Care package contract missing: {token}"
assert "archive.beginJourney" not in DAYCARE
assert "SaveData.newGame" not in DAYCARE

# Exactly one connected addition is FULL: Workshop product.  Resonance stays
# in the lean base closure and retains every state/input/durability boundary.
for token in (
    'os.getenv("KA_CLOSURE_PROFILE") == "dramaless_fp"',
    "loadedMods.DRAMALESS_SHAPE",
    "loadedMods.ds_fp_ceiling",
    "physical_gallery_return=1/1",
    "seal_states=0/1/2/3",
    "native_save_reload=4/4",
):
    assert token in WORKSHOP, f"FULL Workshop contract missing: {token}"
for token in (
    'os.getenv("KA_CLOSURE_PROFILE") == "base_deutsch"',
    'identity == "ka65-final-legacy-workshop-resonance-2d"',
    "unsolved.state == \"unsolved\" and not unsolved.usable",
    "noChoice.index == 2",
    "game:writeSave()",
    "SaveData.load()",
    "ow.map:isWalkableCell(destination.x, destination.y)",
    "not ow:npcAtCell(destination.x, destination.y)",
    "workshop.resonanceReturnState() == nil",
    "return_token_exact_once=3/3",
    "native_save_reload=10/10",
):
    assert token in RESONANCE, f"2D resonance contract missing: {token}"
for forbidden in ("Pipelines", "DRAMALESS_SHAPE", "ds_fp_ceiling"):
    assert forbidden not in RESONANCE, f"2D resonance leaked FULL dependency: {forbidden}"

for token in (
    'ascendant.unlockAchievement("factory_architect")',
    'hall.selectTitle("factory_architect")',
    "archive.beginJourney(game.save",
    "SaveData.newGame(game:bootConfig())",
    "game:writeSave()",
    "SaveData.load()",
    "game:restoreSave(loaded, false)",
    'Screens.push(game, "TrainerCard")',
    'titleName == "FABRIK-ARCHITEKT"',
    'hall.pactCardText(game.save) == "PAKT:VERM."',
    'wanderers.reactionContext(active).kind == "title_factory"',
    'wanderers.reactionContext(active).kind == "partner_match"',
    'driver_result.txt',
    "archive_title_handoff=1/1",
    "trainer_card_title=FABRIK-ARCHITEKT",
    "trainer_card_pact=PAKT:VERM.",
):
    assert token in TITLE, f"title/archive-card contract missing: {token}"
assert "bucket.legacy_journey =" not in TITLE

# Matrix shape: six connected story cells plus archive transaction, Day-Care,
# one FULL Workshop representative, 2D resonance and title/card = eleven.
for token in (
    'for _, edition in ipairs({ "red", "blue", "yellow" })',
    'storyCell(edition, "en"',
    'storyCell(edition, "de"',
    'storyCell(edition, "en", "catalog")',
    'edition == "yellow" and "pikachu"',
    'id = "l04-archive-transaction"',
    'id = "l04-archive-daycare-de"',
    'id = "l04-workshop-full"',
    'id = "l04-workshop-resonance-2d"',
    'id = "l04-title-archive-card-de"',
    'path = "driver_result.txt"',
    'assert(#cells == 11',
    'images = { min_count = 20, min_bytes = 1000 }',
    'images = { exact_count = 12, min_bytes = 1000 }',
    'images = { exact_count = 4, min_bytes = 1000 }',
):
    assert token in MATRIX, f"connected matrix shape missing: {token}"
assert MATRIX.count('closure = "dramaless_fp"') == 1
assert 'driver = "tests/legacy_pact_three_journeys_visual_driver.lua"' not in MATRIX
for receipt in (
    "physical_lab_pc=PASS",
    "fresh_confirm_default_no=2/2",
    "partner_confirm_default_no=2/2",
    "mid_phase_native_reload=1/1",
    "physical_lab_exit_lock=1/1",
    "partner_rival_durable=1/1",
    "failed_witness_rollback=1/1",
    "blocked_retry_side_effect_free=1/1",
    "seal_states=0/1/2/3",
    "return_token_exact_once=3/3",
    "trainer_card_title=FABRIK-ARCHITEKT",
    "fail=0",
):
    assert receipt in MATRIX, f"matrix lacks explicit receipt: {receipt}"

# The existing Pact/three-Journey authority is intentionally reused, not
# duplicated or weakened by this connected supplement.
for token in (
    'mode == "pact4x4"',
    'mode == "three_journeys"',
    "archive.beginJourney(game.save",
    "SaveData.newGame(game:bootConfig())",
    "game:writeSave()",
    "SaveData.load()",
):
    assert token in PACT, f"existing Pact/three-Journey proof drifted: {token}"

print("LEGACY CONNECTED PACKAGE CONTRACT PASS: 11 cells; R/B/Y x EN/DE; one FULL")
