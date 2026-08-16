#!/usr/bin/env python3
"""Fail-closed source contract for the L02 presentation/motion package matrix.

This test intentionally does not launch LÖVE.  It freezes the exact package
cells and the observable seams which the later same-hash package run must
execute; source/headless success is never treated as package evidence.
"""

from __future__ import annotations

import hashlib
from pathlib import Path
import re
import zipfile


ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "tools/presentation_motion_package_matrix_manifest.lua"
COMPOSITE = ROOT / "tools/presentation_motion_package_composite.lua"
DRIVER = ROOT / "tests/presentation_motion_package_driver.lua"
FIXED_MATRIX = ROOT / "tools/blitz_character_presentation_matrix.lua"

BATTLE_ART_ARCHIVE = (
    ROOT / "qa/rc28_release_gate_20260812/dependencies"
    / "BATTLE_ART_VOXEL_FORK-1.8.3.zip"
)
BLITZ_SAVE = (
    ROOT / "qa/blitz_real_save_forensic_20260812/source_snapshot"
    / "slot7_original_readonly.lua"
)
BLITZ_OPTIONS = (
    ROOT / "qa/blitz_real_save_forensic_20260812/source_snapshot"
    / "options_original_readonly.lua"
)

BATTLE_ART_SHA256 = (
    "10d7e80a58d9046b41ec446900f2f15aa6021335a1547d9209117f3a22a0604e"
)
BLITZ_SAVE_SHA256 = (
    "f0d8c1925c09ad8ba825240f6218b81fd1f7dbd6c30348f6304fb006dcf2f8a0"
)
BLITZ_OPTIONS_SHA256 = (
    "2f5ca783613d1ecefd12b3942ef7b12f0c78180e9b6a3820ba2637f21b91e540"
)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def uncommented_lua(text: str) -> str:
    """Remove comments for assignment/load/loop prohibitions.

    This is deliberately conservative rather than a Lua parser.  Authored
    harness strings do not contain comment delimiters, and the positive
    contract below still inspects the unmodified source.
    """

    text = re.sub(r"--\[(=*)\[.*?\]\1\]", "", text, flags=re.DOTALL)
    return "\n".join(line.split("--", 1)[0] for line in text.splitlines())


manifest = MANIFEST.read_text(encoding="utf-8")
composite = COMPOSITE.read_text(encoding="utf-8")
driver = DRIVER.read_text(encoding="utf-8")
fixed_matrix = FIXED_MATRIX.read_text(encoding="utf-8")
harness = manifest + "\n" + composite + "\n" + driver
harness_code = uncommented_lua(composite + "\n" + driver)
full_harness_code = uncommented_lua(harness)
fixed_matrix_code = uncommented_lua(fixed_matrix)

# The optional renderer and the two user-supplied BLITZ inputs are immutable
# provenance boundaries.  Merely accepting arbitrary 64-character values in
# the process environment would not pin the reviewed sources.
assert sha256(BATTLE_ART_ARCHIVE) == BATTLE_ART_SHA256
with zipfile.ZipFile(BATTLE_ART_ARCHIVE) as archive:
    assert archive.testzip() is None
    manifest_json = archive.read("manifest.json")
    renderer_main = archive.read("main.lua").decode("utf-8")
assert b'"id": "BATTLE_ART_VOXEL_FORK"' in manifest_json
assert b'"version": "1.8.3"' in manifest_json
assert "mod.exports.lib = V" in renderer_main
assert sha256(BLITZ_SAVE) == BLITZ_SAVE_SHA256
assert sha256(BLITZ_OPTIONS) == BLITZ_OPTIONS_SHA256

# Freeze the exact eight cells.  FRESH owns all three editions and BLITZ is
# honestly Red-only because that is the only immutable imported save supplied
# by the user.  Battle Art remains installed in both renderer cells; 2D means
# its public renderer switch is OFF, not that the package is absent.
expected_cells = {
    "l02-presentation-red-2d": (
        "ka65-presentation-motion-red-2d", "red", "2D", "FRESH"
    ),
    "l02-presentation-red-battle-art-full": (
        "ka65-presentation-motion-red-battle-art-full",
        "red", "BATTLE_ART_FULL", "FRESH",
    ),
    "l02-presentation-blue-2d": (
        "ka65-presentation-motion-blue-2d", "blue", "2D", "FRESH"
    ),
    "l02-presentation-blue-battle-art-full": (
        "ka65-presentation-motion-blue-battle-art-full",
        "blue", "BATTLE_ART_FULL", "FRESH",
    ),
    "l02-presentation-yellow-2d": (
        "ka65-presentation-motion-yellow-2d", "yellow", "2D", "FRESH"
    ),
    "l02-presentation-yellow-battle-art-full": (
        "ka65-presentation-motion-yellow-battle-art-full",
        "yellow", "BATTLE_ART_FULL", "FRESH",
    ),
    "l02-presentation-blitz-red-2d": (
        "ka65-presentation-motion-blitz-red-2d",
        "red", "2D", "BLITZ",
    ),
    "l02-presentation-blitz-red-battle-art-full": (
        "ka65-presentation-motion-blitz-red-battle-art-full",
        "red", "BATTLE_ART_FULL", "BLITZ",
    ),
}

assert 'schema = "ka-l02-presentation-motion-package-matrix/v1"' in manifest
assert 'blocker = "DRV-PRESENTATION-MOTION-PACKAGE-MATRIX"' in manifest
assert 'missingDriver = "DRV-BATTLEART-PRESENTATION-CLOSURE"' in manifest
assert 'replacementCell = "l02-blocked-complete-presentation"' in manifest
assert re.search(r"assert\s*\(\s*#cells\s*==\s*8\b", manifest)
assert 'closure = "battle_art"' in manifest

# Parse the literal expectedCells rows.  The runtime cell builder is separately
# required to assert that its generated rows equal this closed list.
literal_rows: dict[str, tuple[str, str, str, str]] = {}
for match in re.finditer(
    r"\{(?=[^{}]*\bid\s*=\s*\"l02-presentation-[^\"]+\")[^{}]*\}",
    manifest,
    flags=re.DOTALL,
):
    row = match.group(0)
    fields = {}
    for field in ("id", "identity", "edition", "renderer", "source"):
        value = re.search(rf"\b{field}\s*=\s*\"([^\"]+)\"", row)
        assert value, (field, row)
        fields[field] = value.group(1)
    assert fields["id"] not in literal_rows, fields["id"]
    literal_rows[fields["id"]] = (
        fields["identity"], fields["edition"], fields["renderer"],
        fields["source"],
    )
assert literal_rows == expected_cells, literal_rows
assert re.search(
    r'local\s+FRESH_PHASES\s*=\s*\{\s*"characters"\s*,\s*'
    r'"crystal_title_gorochu"\s*,\s*"follower_wilds"\s*,\s*'
    r'"reload_verify"\s*,\s*"aggregate"\s*,?\s*\}',
    manifest,
    flags=re.DOTALL,
)
assert re.search(
    r'local\s+BLITZ_PHASES\s*=\s*\{\s*"blitz_restore"\s*,\s*'
    r'"reload_verify"\s*,\s*"aggregate"\s*,?\s*\}',
    manifest,
    flags=re.DOTALL,
)
renderer_contract_code = driver + "\n" + composite
for token in (
    '"characters"',
    '"crystal_title_gorochu"',
    '"follower_wilds"',
    '"blitz_restore"',
    '"reload_verify"',
    '"aggregate"',
    'local DRIVER = "tests/presentation_motion_package_driver.lua"',
    'QA_PRESENTATION_PHASE',
    'QA_PRESENTATION_SOURCE',
    'QA_RENDERER',
):
    assert token in manifest, token

# The installed-package wrapper must bind every process to its package closure,
# hashes, edition/renderer/source and clean identity before loading the bounded
# harness module.  The reviewed Battle Art identity is checked through the
# product's public resolver in both the ON and OFF cells.
for token in (
    'os.getenv("KA_PACKAGE_GATE") == "1"',
    'os.getenv("KA_CLOSURE_PROFILE") == "battle_art"',
    'requiredSha("KA_ENGINE_PAYLOAD_SHA256")',
    'requiredSha("KA_AUTHORITY_PACKAGE_SHA256")',
    'requiredSha("KA_DEUTSCH_PACKAGE_SHA256")',
    'requiredSha("KA_BATTLE_ART_PACKAGE_SHA256")',
    'requiredSha("KA_PACKAGE_GATE_RECEIPT_SHA256")',
    '"must be a lowercase SHA256 receipt"',
    BATTLE_ART_SHA256,
    'os.getenv("QA_PRESENTATION_PHASE")',
    'renderer == "2D" or renderer == "BATTLE_ART_FULL"',
    'source == "FRESH" or source == "BLITZ"',
    'local expectedIdentity = source == "FRESH"',
    '"ka65-presentation-motion-%s-%s"',
    '"ka65-presentation-motion-blitz-red-%s"',
    'identity == expectedIdentity',
    'love.filesystem.getSource()',
    '/tools/presentation_motion_package_composite.lua',
    'exports.kanto_ascendant',
    'voxelRendererCompat',
    'rendererId == "BATTLE_ART_VOXEL_FORK"',
    'rendererExport.version == "1.8.3"',
    'module(game, "OverworldBattle")',
    'module(game, "BattleArt")',
    'Pipelines.setLevel("voxel", expectedLevel)',
    'Pipelines.levelLabel("voxel") == "FULL"',
    'Pipelines.worldPipeline() == "voxel"',
    'love.event.quit(fail == 0 and 0 or 1)',
):
    assert token in driver + "\n" + composite, token
# QA-only modules are not members of game.love/the installed product closure.
# They must come from the orchestrator's separately materialized, pinned
# /private/tmp/.../qa_harness tree; getSource remains only product provenance.
for token in (
    'os.getenv("GEN1RECOMP_DIR")',
    'os.getenv("KA_TEST_UTIL")',
    'os.getenv("KA_PRESENTATION_COMPOSITE")',
    'os.getenv("KA_CHARACTER_MATRIX")',
    'harnessRoot:find("/private/tmp/", 1, true)',
    'harnessRoot:find("/qa_harness", 1, true)',
    'not harnessRoot:find(".worktrees", 1, true)',
    'not harnessRoot:find("/Documents/Recompile/", 1, true)',
    'path:sub(1, #harnessRoot + 1) == harnessRoot .. "/"',
    'pinnedHarnessPath(utilPath, "/tests/drivers/util.lua")',
    'pinnedHarnessPath(compositePath,',
    'pinnedHarnessPath(characterMatrixPath,',
    'dofile(ctx.characterMatrixPath)',
):
    assert token in driver + "\n" + composite, token
assert 'packageRoot .. "/tools/presentation_motion_package_composite.lua"' not in driver
assert 'ctx.packageRoot .. "/tools/blitz_character_presentation_matrix.lua"' not in composite
assert re.search(
    r'setting:setIndex\s*\(\s*full'
    r'\s+and\s+1\s+or\s+2',
    driver + "\n" + composite,
)
assert "DRAMALESS_SHAPE" not in harness_code
assert "DRAMATIC_SHAPE" not in harness_code
assert "DRAMALESS_SHAPE" not in fixed_matrix_code
assert "DRAMATIC_SHAPE" not in fixed_matrix_code
for token in (
    "voxelRendererCompat",
    'module(game, "OverworldBattle")',
    'rendererId == "BATTLE_ART_VOXEL_FORK"',
    'rendererExport.version == "1.8.3"',
    'module(game, "BattleArt")',
):
    assert token in fixed_matrix, token

# Presentation coverage is executable, not a list of desired receipt labels.
# Existing bounded visual drivers are reused for their large inventories, and
# the composite directly observes the remaining cross-surface lifecycle seams.
for token in (
    # Three ordinary styles, all ordinary classes and the fixed six.
    'tools/blitz_character_presentation_matrix.lua',
    '"original"',
    '"frlg"',
    '"crystal_hd"',
    '42',
    '"RED"',
    '"BLUE"',
    '"GREEN"',
    '"SILVER"',
    '"KRIS"',
    '"GOLD"',
    # Exact title cadence and Crystal animation surfaces for #252-279.
    'TitleState.new',
    'kaTitlePhase',
    'kaTitleTrainerId',
    '"GREEN"',
    '"POKEMON"',
    '"BLUE"',
    '"RED"',
    '252',
    '279',
    '"title"',
    '"battle_front"',
    '"battle_back"',
    '"pokedex"',
    '"summary"',
    '"box"',
    '"hall_of_fame"',
    '"follower"',
    '"visible_wild"',
    '"normal"',
    '"shiny"',
    'presentationAnimation',
    'advancePresentation',
    'titleSprite',
    'hallSprite',
    'tools/extended_species_runtime_qa_driver.lua',
    # Exactly-one follower lifecycle, including the missing Surf seam.
    'tools/follower_phase2_e2e_driver.lua',
    'native.refresh',
    ':useSurfFieldMove()',
    ':trySurf(',
    ':stepForwardOrCrossEdge(',
    ':reloadMap(',
    # Visible Wilds motion, SpawnFX, one mapping, protected Johto and contact.
    'tools/follower_wilds_motion_qa_driver.lua',
    'signalsWilds',
    'runRules',
    'mapVisibleWild',
    'rememberVisibleWild',
    'kaProtected',
    'kaEncounterSource',
    ':trySpawn(',
    'SpawnFx.updateEntity',
    'mapped.species ~= native.species',
    'mapped.species == remembered.species',
    'entity.spawnFx and entity.spawnFx.done == true',
    'entity.hiddenBody ~= true',
    'entity.canTriggerBattle == true',
    ':_attach(',
    ':_startBattle(',
    # Gorochu is absent from the trainer intro, attached at sendout and live
    # on the real Hall-of-Fame surface in either renderer.
    '"GOROCHU"',
    'BattleState.newTrainer',
    'showEnemyTrainer',
    'showPlayerBack',
    '__ascendantCrystalAnimation',
    'HallOfFame.new',
    'spriteFor',
):
    assert token in renderer_contract_code, token

# Every required observation must survive into the aggregate cell receipt.
# These are exact counts/identities, not vague screenshot-count substitutes.
receipt_tokens = (
    "fixed_identities=6/6",
    "ordinary_modes=3/3",
    "ordinary_classes=42/42",
    "title_rhythm=GREEN>POKEMON>BLUE>POKEMON>RED>POKEMON>GREEN",
    "crystal_species=28/28",
    "crystal_surfaces=9/9",
    "crystal_variants=2/2",
    "follower_exactly_one=1/1",
    "follower_map=1/1",
    "follower_door=1/1",
    "follower_surf=1/1",
    "follower_evolution=1/1",
    "follower_reload=1/1",
    "wilds_spawnfx=1/1",
    "wilds_randomizer_once=1/1",
    "wilds_johto_protection=1/1",
    "wilds_contact=1/1",
    "gorochu_intro_absent=1/1",
    "gorochu_sendout_present=1/1",
    "gorochu_hof=1/1",
    "blitz_natural_restore=1/1",
    "blitz_evolution_scope=fresh-only-immutable-lead-already-evolved",
    "native_save_write=1/1",
    "native_options_write=1/1",
    "native_process_boot_without_progress_marker=1/1",
    "native_save_load=1/1",
    "native_save_recovery=main",
    "native_save_restore=1/1",
    "durable_follower_exactly_one=1/1",
    "durable_follower_option=1/1",
    "durable_follower_species=",
    "immutable_blitz_snapshot_unchanged=1/1",
)
for token in receipt_tokens:
    assert token in harness, token
for token in (
    "status=PASS",
    "scope=PRESENTATION-MOTION-PACKAGE",
    "engine_payload_sha256=",
    "authority_package_sha256=",
    "deutsch_package_sha256=",
    "battle_art_package_sha256=",
    "package_gate_receipt_sha256=",
    "fail=0",
):
    assert token in manifest + "\n" + driver, token

# The BLITZ phase validates immutable inputs before decode/restore and observes
# the natural Pallet follower before any QA teleport.  It then proves exactly
# one follower after a map transition and native reload; it never fabricates
# Blue/Yellow imported-save rows.
for token in (
    'os.getenv("KA_SOURCE_SAVE")',
    'os.getenv("KA_SOURCE_OPTIONS")',
    'requiredSha("KA_SOURCE_SAVE_SHA256")',
    'requiredSha("KA_SOURCE_OPTIONS_SHA256")',
    BLITZ_SAVE_SHA256,
    BLITZ_OPTIONS_SHA256,
    'sha256(saveBody) == ctx.sourceSaveSha',
    'sha256(optionsBody) == ctx.sourceOptionsSha',
    'SaveData.decode',
    'game:restoreSave(',
):
    assert token in driver + "\n" + composite, token
blitz_start = composite.index("runBlitzRestore")
aggregate_start = composite.index("aggregate", blitz_start)
blitz = composite[blitz_start:aggregate_start]
natural_label = "BLITZ natural restore spawned exactly one follower"
for token in (
    "game:restoreSave(", natural_label, "native.refresh(game)", "U.teleport(",
    ":reloadMap(", 'top.screenId == "QuarantineReport"',
    'U.tap(game, "a")', "blitz_load_report_dismissed=1/1",
):
    assert token in blitz, token
assert blitz.index("game:restoreSave(") < blitz.index(natural_label)
assert blitz.index('top.screenId == "QuarantineReport"') \
    < blitz.index('U.tap(game, "a")')
assert blitz.index('U.tap(game, "a")') \
    < blitz.index("BLITZ natural Pallet screenshot")
aggregate_body = composite[composite.index("function C.aggregate"):]
assert '"blitz_load_report_dismissed=1/1"' in aggregate_body
assert blitz.index(natural_label) < blitz.index("native.refresh(game)")
assert blitz.index("native.refresh(game)") < blitz.index("U.teleport(")
assert blitz.index("U.teleport(") < blitz.index(":reloadMap(")
assert blitz.index("sha256(saveBody) == ctx.sourceSaveSha") \
    < blitz.index("SaveData.decode(saveBody)")
assert blitz.index("sha256(optionsBody) == ctx.sourceOptionsSha") \
    < blitz.index("SaveData.decode(optionsBody)")

# Native durability is deliberately a separate process pass.  The writer
# uses Game's SaveData-backed write (which also flushes options.lua), while
# reload_verify begins from the engine's fresh boot save, loads the identity's
# main save through SaveData.load, then restores it through Game.  It creates
# no screenshots and never writes to either immutable BLITZ input.
renderer_durability_code = driver + "\n" + composite
for token in (
    'local DURABILITY_SCHEMA = "ka-l02-native-durability/v1"',
    'local DURABILITY_KEY = "l02_presentation_native_durability"',
    'game:writeSave() == true',
    'game.writeOptions',
    'SaveData.loadOptions()',
    'local function applyRendererContract(label, persist)',
    'local function assertRendererContract(label, options)',
    'ctx.applyRendererContract("Fresh save restore renderer", true)',
    'ctx.applyRendererContract("BLITZ save restore renderer", true)',
    'ctx.assertRendererContract("Native save restore renderer")',
    'renderer_contract_persisted=1/1',
    'renderer_contract_reloaded=1/1',
    'SaveData.setActiveSlot(ctx.edition, nativeSlot) == "slot7"',
    'SaveData.activeSlot(ctx.edition) == "slot7"',
    'native_active_slot=slot7',
    'SaveData.loadOptions()',
    'function C.runReloadVerify(ctx)',
    'durabilityMarker(game.save) == nil',
    'SaveData.load(ctx.edition)',
    'game:restoreSave(loaded, recovered)',
    'ctx.ascendant.singleFollower.getCount() == 1',
    'followerCount(game) == 1',
    'immutable BLITZ snapshot unchanged after native write',
    'immutable BLITZ snapshot unchanged after native reload',
):
    assert token in renderer_durability_code, token
reload_start = composite.index("function C.runReloadVerify")
aggregate_start = composite.index("function C.aggregate", reload_start)
reload_verify = composite[reload_start:aggregate_start]
assert reload_verify.index("durabilityMarker(game.save) == nil") \
    < reload_verify.index("SaveData.activeSlot(ctx.edition)")
assert reload_verify.index("SaveData.activeSlot(ctx.edition)") \
    < reload_verify.index("SaveData.load(ctx.edition)")
assert reload_verify.index("SaveData.load(ctx.edition)") \
    < reload_verify.index("game:restoreSave(loaded, recovered)")
assert reload_verify.index("game:restoreSave(loaded, recovered)") \
    < reload_verify.index('follower(ctx, "Native process reload", expected)')
assert "U.shot" not in reload_verify
for forbidden_write in (
    "writeRows(ctx.sourceSave", "writeRows(ctx.sourceOptions",
    'io.open(ctx.sourceSave, "w', 'io.open(ctx.sourceOptions, "w',
):
    assert forbidden_write not in composite, forbidden_write

# Polling is mechanically bounded.  Collection loops are finite `ipairs` or
# numeric ranges, while every asynchronous wait uses one of these explicit
# frame budgets.  There is no unconditional while/repeat escape hatch.
for budget in (
    "INTRO_FRAME_BUDGET",
    "SURF_FRAME_BUDGET",
    "BATTLE_FRAME_BUDGET",
    "MOTION_FRAME_BUDGET",
    "RESTORE_FRAME_BUDGET",
):
    assert re.search(rf"\blocal\s+{budget}\s*=\s*[1-9][0-9]*\b", composite), budget
    assert re.search(rf"\bfor\s+_\s*=\s*1\s*,\s*{budget}\s+do\b", composite), budget
assert not re.search(r"\bwhile\b", harness_code)
assert not re.search(r"\brepeat\b", harness_code)

# Acceptance code may configure disposable inputs, but it may not write the
# presentation/motion result it is supposed to observe.
for pattern in (
    r"\bplayer\.surfing\s*=(?!=)",
    r"\b(?:title|state)\.kaTitlePhase\s*=(?!=)",
    r"\b(?:title|state)\.kaTitleTrainerId\s*=(?!=)",
    r"\b(?:record|entity|encounter|proposal)\.species\s*=(?!=)",
    r"\b(?:record|entity|encounter|proposal)\.kaProtected\s*=(?!=)",
    r"\b(?:record|entity|encounter|proposal)\.kaEncounterSource\s*=(?!=)",
    r"\bbattle\.showEnemyTrainer\s*=(?!=)",
    r"\bbattle\.showPlayerBack\s*=(?!=)",
    r"\bbattle\.__ascendantCrystalAnimation\s*=(?!=)",
    r"\bbattle\.dramaticShapeShot\s*=(?!=)",
    r"\bgame\.save\.hallOfFame\s*=(?!=)",
    r"table\.insert\s*\([^\n]*hallOfFame",
    r"\bgame\.overworld\.entities\s*=(?!=)",
    r"table\.insert\s*\([^\n]*entities",
    r"\.onFinish\s*=(?!=)",
):
    assert not re.search(pattern, harness_code), pattern

# Product behavior comes only from the installed current package export.  The
# harness may load its frozen helper modules, but never a source checkout's
# main/run_rules/Wilds implementation or a developer worktree path.
for forbidden in (
    "/Users/",  # Synthetic sentinel: reject every absolute macOS home path.
    ".worktrees/ka-",
    "TRAINER_REMATCH_MOD_DIR",
    "KANTO_SIGNALS_MOD_DIR",
    "GEN1RECOMP_ROOT",
    "final_same_hash",
    "final_same_hash_plan",
    "final_same_hash_receipt",
):
    assert forbidden not in full_harness_code, forbidden
for pattern in (
    r'not\s+packageRoot:find\s*\(\s*"\.worktrees"\s*,\s*1\s*,\s*true\s*\)',
    r'not\s+packageRoot:find\s*\(\s*"/Documents/Recompile/"'
    r'\s*,\s*1\s*,\s*true\s*\)',
):
    assert re.search(pattern, driver), pattern
for token in (
    "game.mods.mods.kanto_ascendant",
    "installedPath",
    'not installedPath:find(".worktrees", 1, true)',
    'not installedPath:find("/Documents/Recompile/", 1, true)',
    'not installedPath:find("/tests/", 1, true)',
):
    assert token in driver, token
for pattern in (
    r"(?:dofile|loadfile)\s*\([^\n)]*(?:run_rules|johto_signals_wilds|main\.lua)",
    r"require\s*\(\s*[\"'](?:run_rules|johto_signals_wilds|main)[\"']",
    r"kanto_ascendant[^\n]*\.path[^\n]*(?:run_rules|johto_signals_wilds|main\.lua)",
):
    assert not re.search(pattern, full_harness_code), pattern

print(
    "Presentation/motion package driver contract PASS: "
    "6 Fresh R/B/Y x 2D/Battle Art + 2 immutable Red BLITZ cells"
)
