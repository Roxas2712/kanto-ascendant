#!/usr/bin/env python3
"""Preserve the historical <=0.1.86 Battle Art package proof.

This immutable regression receipt is not a claim that the archived package
loads under the current 0.1.90 sandbox. Current admission is governed by
manifest.json plus voxel_renderer_compat.lua and deliberately excludes it.
"""

from __future__ import annotations

import hashlib
import json
from pathlib import Path
import re
import zipfile


ROOT = Path(__file__).resolve().parents[1]
current_manifest = json.loads((ROOT / "manifest.json").read_text())
assert all("BATTLE_ART_VOXEL_FORK" not in entry.get("ids", [])
           for entry in current_manifest["exclusive"]["allow_packages"])
driver_path = ROOT / "tests/mew_provenance_rby_visual_driver.lua"
driver = driver_path.read_text()
driver_code = "\n".join(line.split("--", 1)[0] for line in driver.splitlines())
deps = ROOT / "qa/rc28_release_gate_20260812/dependencies"
# The immutable dependency and its real public export shape are one receipt
# boundary with the package driver, rather than an approximate local install.
expected_sha = "10d7e80a58d9046b41ec446900f2f15aa6021335a1547d9209117f3a22a0604e"
row = {
    "version": "1.8.3",
    "archive": "BATTLE_ART_VOXEL_FORK-1.8.3.zip",
    "sha256": expected_sha,
    "source": "https://github.com/absol89/DramaticShapeVoxelMod/releases/tag/1.8.3",
    "manifest_id": "BATTLE_ART_VOXEL_FORK",
    "manifest_github": "absol89/DramaticShapeVoxelMod",
    "closure": "alternative to DRAMALESS_SHAPE; upstream manifests conflict",
}
archive = deps / row["archive"]
assert hashlib.sha256(archive.read_bytes()).hexdigest() == expected_sha
with zipfile.ZipFile(archive) as package:
    assert package.testzip() is None
    manifest = json.loads(package.read("manifest.json"))
    main = package.read("main.lua").decode()
assert manifest["id"] == "BATTLE_ART_VOXEL_FORK"
assert manifest["version"] == "1.8.3"
assert manifest["github"] == "absol89/DramaticShapeVoxelMod"
assert "mod.exports.lib = V" in main

# Source runs and empty/surrogate receipts must not be accepted as package QA.
for token in (
    "KA_PACKAGE_GATE",
    "KA_ENGINE_PAYLOAD_SHA256",
    "KA_AUTHORITY_PACKAGE_SHA256",
    "KA_DEUTSCH_PACKAGE_SHA256",
    "KA_BATTLE_ART_PACKAGE_SHA256",
    expected_sha,
    'renderer == "2D" or renderer == "BATTLE_ART_FULL"',
    "must be a lowercase SHA256 receipt",
):
    assert token in driver, token

# Both cells resolve the installed reviewed package through Kanto Ascendant's
# shared fail-closed seam.  OFF is therefore a real installed-but-disabled
# comparison, not the absence of the optional renderer.
for token in (
    "voxelRendererCompat",
    'rendererId == "BATTLE_ART_VOXEL_FORK"',
    'rendererExport.version == "1.8.3"',
    'voxelResolver.module(game, "OverworldBattle")',
    'voxelResolver.module(game, "BattleArt")',
    "rendererExport.lib.require",
    'overworldBattle.setting:setIndex(renderer == "BATTLE_ART_FULL" and 1 or 2',
    'battleArt.setting:setIndex(2, game)',
    'Pipelines.setLevel("voxel", renderer == "BATTLE_ART_FULL" and 1 or 0)',
    'Pipelines.levelLabel("voxel") == "FULL"',
    'Pipelines.worldPipeline() == "voxel"',
    "Battle Art is installed but explicitly OFF for 2D evidence",
):
    assert token in driver, token

# The renderer receipt is produced by the authored Route-24 encounter and
# native BattleState draw path.  A non-nil controller or staged fake canvas is
# insufficient: the live shot, its canvas and BattleState field must agree.
for token in (
    "REAL_ROUTE24_WILD_BATTLE",
    "REAL_BATTLESTATE_RENDER",
    'game.overworld.map.id == "ROUTE_24"',
    "overworldBattle.arena() ~= nil",
    "local shot = overworldBattle.shot()",
    "shot and shot.canvas and battle.dramaticShapeShot",
    "Battle Art FULL produces a real rendered battle canvas",
    "2D battle has no staged Battle Art shot",
    "Battle Art FULL remains live through Master Ball toss",
    "Battle Art FULL remains live through the caught result",
    '"/09_mew_battle_" .. rendererTag .. ".png"',
    '"/10_master_ball_toss_" .. rendererTag .. ".png"',
    '"/11_mew_caught_" .. rendererTag .. ".png"',
):
    assert token in driver, token

# Preserve the existing end-to-end provenance proof in all six cells.
for token in (
    'version == "red" or version == "blue" or version == "yellow"',
    "Journal visibly offers the external-Mew repair",
    "KEEP preserves the completed state and records the decision",
    "RESTORE reopens only the authored investigation",
    "OAKSLAB_OAK1",
    "MRFUJISHOUSE_MR_FUJI",
    "CINNABARLABFOSSILROOM_SCIENTIST2",
    "Route 24 starts a provenance-marked real wild battle",
    'battle.menuIndex = 3',
    'row.value == "MASTER_BALL"',
    "real Bag use consumes exactly one Master Ball immediately",
    "save/reload retains external and authored Mew separately",
):
    assert token in driver, token

# No renderer acceptance may be manufactured by injecting an export, shot or
# BattleState receipt into the package.  Reads/assertions of the live fields
# remain allowed.
for pattern in (
    r"game\.mods\.exports\.BATTLE_ART_VOXEL_FORK\s*=(?!=)",
    r"rendererExport\.version\s*=(?!=)",
    r"overworldBattle\.shot\s*=(?!=)",
    r"battle\.dramaticShapeShot\s*=(?!=)",
):
    assert not re.search(pattern, driver_code), pattern

print("Historical <=0.1.86 Mew/Battle Art package receipt: 6 cells PASS")
