#!/usr/bin/env python3
"""Fail closed unless MOD-002 has real replacement and singleton proofs."""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DRIVER = ROOT / "tests" / "integrated_hooks_package_driver.lua"
FIXTURES = ROOT / "tests" / "fixtures" / "final_integrated_hooks"
MANIFEST = json.loads((ROOT / "manifest.json").read_text("utf-8"))
text = DRIVER.read_text("utf-8")

required = {
    "package only": 'KA_PACKAGE_GATE") == "1"',
    "real loader status": "game.mods:status()",
    "blocked execution registry": "loadedById[id] == nil",
    "external exports absent": "or exports[id] == nil",
    "Wilds export belongs to Ascendant": "exports[id] == internal.exports",
    "two renderers": 'mode == "2d" or mode == "full"',
    "real full pipeline": 'Pipelines.worldPipeline() == "voxel"',
    "bundled wilds": "internal.bundled == true",
    "wild hook identity": "captures(row.callback, wilds.logic)",
    "wild hook singleton": "wildHooks == 1",
    "wild actor equality": "entities == visible",
    "surf state reset before dry handoff": "game.save.player.surfing = false",
    "dry follower map handoff": 'U.teleport(game, "ROUTE_22", 8, 8, "down")',
    "surf false-positive guard": "game.overworld.player.surfing ~= true",
    "native follower refresh": "follower.refresh(game)",
    "follower singleton": "#followers == 1 and fieldFollowers == 1",
    "follower species": 'followers[1].followerSpecies == "RAICHU"',
    "follower wrapper": "__kantoAscendantNativeSingleFollower",
    "integrated bag": "bag.__ascendantModernBag == true",
    "bag item help": 'type(bag.__ascendantShowItemInfo) == "function"',
    "bag sort owner": 'bag.__ascendantBagSecondary == "sort"',
    "qol singleton": "handlerCount == 1",
    "qol owner": "handlers.kanto_ascendant ~= nil",
    "qol overlay": "__qolLocationBannerOverlay",
    "visual receipt": "01_integrated_hooks.png",
    "machine receipt": "driver_result.txt",
}
missing = [name for name, needle in required.items() if needle not in text]
if 'and exports[id] == nil)' in text:
    missing.append("blanket export ban rejects Ascendant's Wilds compatibility export")
wilds_witness = text.find('U.teleport(game, "ROUTE_22", 24, 8, "down")')
surf_reset = text.find("game.save.player.surfing = false")
dry_witness = text.find('U.teleport(game, "ROUTE_22", 8, 8, "down")')
follower_refresh = text.find("follower.refresh(game)")
if not (0 <= wilds_witness < surf_reset < dry_witness < follower_refresh):
    missing.append(
        "follower proof must leave the Route 22 water witness for a dry cell"
    )

ids = {
    "overworld_wild_spawns",
    "FOLLOWERS_EX",
    "quality_of_life",
    "useful_bag",
}
replacement_ids = {
    mod_id
    for row in MANIFEST.get("compatibility_conflicts", [])
    if row.get("policy") == "replace"
    for mod_id in row.get("ids", [])
}
if not ids <= replacement_ids:
    missing.append("product manifest does not replace all four fixture ids")

for mod_id in sorted(ids):
    root = FIXTURES / mod_id
    manifest = json.loads((root / "manifest.json").read_text("utf-8"))
    entry = (root / manifest["entry"]).read_text("utf-8")
    if manifest.get("id") != mod_id or manifest.get("api") != 2:
        missing.append(f"invalid fixture manifest: {mod_id}")
    if "error(" not in entry or "replacement probe executed" not in entry:
        missing.append(f"fixture would not fail visibly if loaded: {mod_id}")

assert not missing, "INTEGRATED HOOKS PACKAGE CONTRACT FAIL:\n" + "\n".join(missing)
print(f"INTEGRATED HOOKS PACKAGE CONTRACT PASS: {len(required) + 5} checks")
