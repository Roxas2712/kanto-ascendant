#!/usr/bin/env python3
"""Fail closed if the 12-cell package Oak-finale proof becomes decorative."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path
import re
import zipfile


ROOT = Path(__file__).resolve().parents[1]
DRIVER_PATH = ROOT / "tests/legacy_oak_finale_visual_driver.lua"
SETUP_PATH = ROOT / "tests/legacy_oak_finale_language_setup_driver.lua"
PLAN_PATH = (
    ROOT
    / "qa/blitz_real_save_forensic_20260812/package_candidate"
    / "final_same_hash_plan.json"
)
driver = DRIVER_PATH.read_text("utf-8")
setup = SETUP_PATH.read_text("utf-8")
driver_code = "\n".join(line.split("--", 1)[0] for line in driver.splitlines())
setup_code = "\n".join(line.split("--", 1)[0] for line in setup.splitlines())

# The package matrix is tied to the same reviewed immutable renderer archive as
# the separately frozen closure receipt.  Controller-shaped substitutes do not
# satisfy FULL-intro evidence.
deps = ROOT / "qa/rc28_release_gate_20260812/dependencies"
lock = json.loads((deps / "LOCK.json").read_text("utf-8"))
row = lock["BATTLE_ART_VOXEL_FORK"]
archive = deps / row["archive"]
expected_sha = "10d7e80a58d9046b41ec446900f2f15aa6021335a1547d9209117f3a22a0604e"
assert row == {
    "version": "1.8.3",
    "archive": "BATTLE_ART_VOXEL_FORK-1.8.3.zip",
    "sha256": expected_sha,
    "source": "https://github.com/absol89/DramaticShapeVoxelMod/releases/tag/1.8.3",
    "manifest_id": "BATTLE_ART_VOXEL_FORK",
    "manifest_github": "absol89/DramaticShapeVoxelMod",
    "closure": "alternative to DRAMALESS_SHAPE; upstream manifests conflict",
}
assert hashlib.sha256(archive.read_bytes()).hexdigest() == expected_sha
with zipfile.ZipFile(archive) as package:
    assert package.testzip() is None
    manifest = json.loads(package.read("manifest.json"))
    main = package.read("main.lua").decode("utf-8")
assert manifest["id"] == "BATTLE_ART_VOXEL_FORK"
assert manifest["version"] == "1.8.3"
assert "mod.exports.lib = V" in main

# English must be a real clean-process language state.  The setup process uses
# the engine launcher API, edition-scoped options and a physically present
# package; it may not counterfeit Authority's language export in memory.
for token in (
    'os.getenv("KA_PACKAGE_GATE") == "1"',
    'os.getenv("KA_CLOSURE_PROFILE") == "battle_art"',
    'os.getenv("QA_LANGUAGE") == "en"',
    'renderer == "2D" or renderer == "BATTLE_ART_FULL"',
    'red = "deutsch", blue = "deutsch-blau", yellow = "deutsch-gelb"',
    'require("src.mods.LauncherMods")',
    'LauncherMods.setEnabled(languageId, false, version)',
    "SaveData.modEnabled(options, languageId",
    "SaveData.modScope(version)",
    'exports.language() == "de"',
    "language.enabled == true",
    "count == 3",
    expected_sha,
    "source/worktree path is not package evidence",
    'scope=RC65-OAK-FINALE-LANGUAGE-SETUP',
):
    assert token in setup, token
for pattern in (
    r"game\.mods\.exports\.kanto_ascendant\.language\s*=(?!=)",
    r"language\.enabled\s*=(?!=)",
    r"options\.mods(?:ByVersion)?\s*=(?!=)",
    r"game\.mods\.mods\[[^]]+\]\s*=(?!=)",
):
    assert not re.search(pattern, setup_code), pattern

# Main proof refuses source runs and empty/surrogate receipts, validates the
# exact physical closure, and distinguishes installed-but-disabled EN from the
# normal enabled DE package before observing Authority's public language seam.
for token in (
    'os.getenv("KA_PACKAGE_GATE") == "1"',
    'os.getenv("KA_CLOSURE_PROFILE") == "battle_art"',
    "KA_ENGINE_PAYLOAD_SHA256",
    "KA_AUTHORITY_PACKAGE_SHA256",
    "KA_DEUTSCH_PACKAGE_SHA256",
    "KA_BATTLE_ART_PACKAGE_SHA256",
    "KA_PACKAGE_GATE_RECEIPT_SHA256",
    "must be a lowercase SHA256 receipt",
    expected_sha,
    'renderer == "2D" or renderer == "BATTLE_ART_FULL"',
    'version == "red" or version == "blue" or version == "yellow"',
    "unexpected package leaked into Oak closure",
    "loadedCount == 3",
    "source/worktree path is not package evidence",
    'languagePackage.state == "disabled"',
    "exports.language() == locale",
    "requested locale is visible in the live Oak builder",
    "requested locale owns the live Oak trainer intro",
):
    assert token in driver, token

# Both renderer cells resolve the installed reviewed mod through Authority's
# compatibility seam.  FULL must own the live Oak Lab trainer-intro canvas;
# 2D must prove that the exact installed renderer is actively switched off.
for token in (
    "voxelRendererCompat",
    'rendererId == "BATTLE_ART_VOXEL_FORK"',
    'rendererExport.version == "1.8.3"',
    'voxelResolver.module(game, "OverworldBattle")',
    'voxelResolver.module(game, "BattleArt")',
    "rendererExport.lib.require",
    'overworldBattle.setting:setIndex(',
    'renderer == "BATTLE_ART_FULL" and 1 or 2',
    'battleArt.setting:setIndex(2, game)',
    'Pipelines.setLevel("voxel", renderer == "BATTLE_ART_FULL" and 1 or 0)',
    'Pipelines.levelLabel("voxel") == "FULL"',
    'Pipelines.worldPipeline() == "voxel"',
    "Battle Art is installed but explicitly OFF for 2D evidence",
    "local current = overworldBattle.shot()",
    "current and current.canvas and battle.dramaticShapeShot",
    "overworldBattle.battle() == battle",
    'game.overworld.map.id == "OAKS_LAB"',
    "Oak trainer intro",
    "stays on the native 2D BattleState",
    "overworldBattle.arena() == nil",
    "overworldBattle.shot() == nil",
    "battle.dramaticShapeShot == nil",
):
    assert token in driver, token

# Preserve the original strong product proof: lawful party+archive UI, real
# loss and retry win, one-time reward, no-prize rematch, and native slot I/O.
for token in (
    "illegal ghost archive row is not selectable",
    "real builder visibly offers lawful archived Pokemon",
    "chosen source cannot be selected a second time",
    "builder cancel leaves party byte-for-byte selection-equivalent",
    "first confirmation is default NO",
    "second confirmation is independently default NO",
    'battle.oppClass == "KA_OAK_BETA"',
    'driveBattle(battle, 4200) == "lose"',
    "loss restores the original legal party",
    "loss leaves every archive row byte-for-byte selection-equivalent",
    'driveBattle(battle, 30000) == "win"',
    "first victory records legacy pass exactly once",
    "rematch grants no second reward",
    "SaveData.setActiveSlot(version, slot)",
    "game:writeSave()",
    "SaveData.load(version)",
    "game:restoreSave(reloaded, false)",
    "SaveData.activeSlot(version) == slot",
    "status=",
    "oak_finale=",
    "native_save_reload=",
    "real_loss_retry_win_rematch=",
):
    assert token in driver, token

# Every YES answer must wait out ChoiceBox's authored answer hold before the
# caller may look for the next prompt.  Otherwise the still-top first box
# (index=YES, pending=true) is a false positive for the second confirmation.
for token in (
    "local function chooseYes(choice)",
    "game.stack:top() == choice",
    "game.stack:top() ~= choice",
    "confirmed ChoiceBox did not finish its answer hold",
    "chooseYes(first)",
    "chooseYes(second)",
):
    assert token in driver_code, token
assert not re.search(r"\bchooseYes\(\s*\)", driver_code)

# A fixture may create the legal teams and all-three-path precondition, but it
# cannot stamp a BattleState result/reward, replace the renderer receipt, or
# bypass the real finish callback.
for pattern in (
    r"battle\.result\s*=(?!=)",
    r"battle\.onFinish\s*=(?!=)",
    r"battle\.dramaticShapeShot\s*=(?!=)",
    r"overworldBattle\.shot\s*=(?!=)",
    r"game\.mods\.exports\.BATTLE_ART_VOXEL_FORK\s*=(?!=)",
    r"paths\.profile\(\)\.legacyPass\s*=(?!=)",
    r"journey\.completeFinale\s*\(",
):
    assert not re.search(pattern, driver_code), pattern

# The package orchestrator must execute the complete Cartesian product.  EN
# cells use the clean-process setup pass; DE cells may not run that pass.
plan = json.loads(PLAN_PATH.read_text("utf-8"))
lane = next(row for row in plan["lanes"] if row["lane_id"] == "L08_OAK_MEW_ROUTE22")
oak_cells = [
    cell
    for cell in lane["cells"]
    if cell.get("driver") == "tests/legacy_oak_finale_visual_driver.lua"
]
assert len(oak_cells) == 12
matrix = {}
for cell in oak_cells:
    assert cell["closure"] == "battle_art"
    assert cell["edition"] in ("red", "blue", "yellow")
    env = cell["env"]
    assert set(env) == {"QA_LANGUAGE", "QA_RENDERER"}
    key = (cell["edition"], env["QA_LANGUAGE"], env["QA_RENDERER"])
    assert key not in matrix
    matrix[key] = cell
    assert cell["timeout_seconds"] >= 3600
    contains = set(cell["result"]["contains"])
    assert {
        "status=PASS",
        "scope=RC65-OAK-FINALE",
        f"edition={cell['edition']}",
        f"locale={env['QA_LANGUAGE']}",
        f"renderer={env['QA_RENDERER']}",
        "oak_finale=1/1",
        "native_save_reload=1/1",
        "real_loss_retry_win_rematch=1/1",
        "fail=0",
    }.issubset(contains)
    assert cell["images"] == {"exact_count": 12, "min_bytes": 1000}
    if env["QA_LANGUAGE"] == "en":
        assert cell.get("passes") == [
            {
                "name": "language_setup",
                "driver": "tests/legacy_oak_finale_language_setup_driver.lua",
                "env": {},
            },
            {
                "name": "oak_finale",
                "driver": "tests/legacy_oak_finale_visual_driver.lua",
                "env": {},
            },
        ]
    else:
        assert "passes" not in cell

expected_matrix = {
    (edition, locale, renderer)
    for edition in ("red", "blue", "yellow")
    for locale in ("en", "de")
    for renderer in ("2D", "BATTLE_ART_FULL")
}
assert set(matrix) == expected_matrix
assert not any(
    cell.get("blocker") == "DRV-OAK-FINALE-RBY-EN-DE-PACKAGE"
    for cell in lane["cells"]
)
oak_ids = set(cell["id"] for cell in oak_cells)
assert oak_ids.issubset(set(lane["coverage"]["OAK-001"]))
assert oak_ids.issubset(set(lane["coverage"]["RC65-OAK-FINALE"]))
assert "tests/legacy_oak_finale_package_driver_contract_test.py" in lane["source_references"]
assert "tests/legacy_oak_finale_language_setup_driver.lua" in lane["source_references"]

print("Legacy Oak package contract: 12 R/B/Y x EN/DE x 2D/FULL cells PASS")
