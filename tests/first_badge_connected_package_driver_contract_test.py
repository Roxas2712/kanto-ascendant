#!/usr/bin/env python3
"""Fail-closed contract for DRV-EARLY-BALANCE-FIRST-BADGE-PACKAGE."""

from __future__ import annotations

import hashlib
from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[1]
DRIVER = ROOT / "tools/first_badge_connected_package_driver.lua"
ROUTE = ROOT / "tools/first_badge_connected_route.lua"
RUNNER = (
    ROOT
    / "qa/blitz_real_save_forensic_20260812/package_candidate/inputs"
    / "harness_snapshot/tests/drivers/route.lua"
)
EXPECTED_RUNNER_SHA256 = (
    "8cad0bc24ba92f01bae136f6f1aec4c029256c44f8db9570cc23493d26ad0842"
)


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


driver = DRIVER.read_text("utf-8")
route = ROUTE.read_text("utf-8")
runner = RUNNER.read_text("utf-8")

assert digest(RUNNER) == EXPECTED_RUNNER_SHA256, digest(RUNNER)

# The route planner must mirror live Collision.occupied: a passable party
# follower is traversable, while authored/default NPCs and moving blockers'
# target cells remain walls.  The frozen runner SHA binds the full file; these
# executable tokens keep the reason for the pin reviewable.
for token in (
    "if inMap and not npc.passable then",
    'type(npc.targetX) == "number"',
    'type(npc.targetY) == "number"',
    "blocked[id(npc.targetX, npc.targetY)] = true",
):
    assert token in runner, token
assert runner.count("not npc.passable") == 6

# The wrapper must establish installed-package provenance, a fresh native
# slot, real battle event evidence, every connected milestone and an actual
# SaveData write/load/restore.  Result rows are executable cell assertions.
for token in (
    'os.getenv("KA_PACKAGE_GATE") == "1"',
    'requiredSha("KA_ENGINE_PAYLOAD_SHA256")',
    'requiredSha("KA_AUTHORITY_PACKAGE_SHA256")',
    'requiredSha("KA_DEUTSCH_PACKAGE_SHA256")',
    '"KA_PACKAGE_GATE_RECEIPT_SHA256"',
    'os.getenv("GEN1RECOMP_DIR")',
    '"/tools/first_badge_connected_route.lua"',
    '"/tests/drivers/route.lua"',
    'love.filesystem.getSource()',
    'loaded.kanto_ascendant',
    'SaveData.setActiveSlot(edition, slot)',
    'battle.started',
    'battle.ended',
    'payload.result == "win"',
    'trace.labWon',
    'mapId == "OAKS_LAB"',
    'mapId == "ROUTE_22"',
    'mapId == "PEWTER_GYM"',
    'battle.oppClass == "OPP_RIVAL1"',
    'battle.oppClass == "OPP_BROCK"',
    'payload.result == "win"',
    'package.loaded["tests.drivers.bot_route"] = dofile(routePath)',
    'runConnectedRoute(game)',
    'EVENT_FOLLOWED_OAK_INTO_LAB == true',
    'EVENT_GOT_STARTER == true',
    'EVENT_BATTLED_RIVAL_IN_OAKS_LAB == true',
    'EVENT_GOT_POKEDEX == true',
    'EVENT_BEAT_ROUTE22_RIVAL_1ST_BATTLE == true',
    'EVENT_BEAT_BROCK == true',
    'inventory.BOULDERBADGE == 1',
    'inventory.TM_BIDE',
    'game:writeSave()',
    'SaveData.load(edition)',
    'game:restoreSave(reloaded, recovered)',
    'status=PASS',
    'scope=EARLY-BALANCE-FIRST-BADGE',
    'edition=',
    'connected_new_game=1/1',
    'oak_escort=1/1',
    'lab_battle_state=1/1',
    'pokedex=1/1',
    'route22_battle_state=1/1',
    'pewter_reached=1/1',
    'brock_battle_state=1/1',
    'boulder_badge=1/1',
    'tm_bide=1/1',
    'native_save_reload=1/1',
    'no_ngplus_leak=1/1',
    'connected_first_badge=1/1',
    'fail=0',
    'love.event.quit(0)',
):
    assert token in driver, token

# Ambient checkpoint/resume settings must not turn this into a developer
# continuation.  They are fixed to the fresh package cell and evidence dir.
for name in (
    "POKEPORT_ROUTE_ATTEMPTS",
    "POKEPORT_ROUTE_CHECKPOINT",
    "POKEPORT_ROUTE_LOG",
    "POKEPORT_ROUTE_MEMORY",
    "POKEPORT_ROUTE_RESUME",
    "POKEPORT_ROUTE_STOP_ON_STUCK",
    "POKEPORT_ROUTE_STUCK_REPORT",
    "POKEPORT_ROUTE_WATCHDOG",
):
    assert name in driver, name
assert 'POKEPORT_ROUTE_RESUME = "0"' in driver
assert 'POKEPORT_ROUTE_STOP_ON_STUCK = "0"' in driver

# The bounded route is the complete connected prefix, not a teleport or a
# synthetic battle roster.  It has the one edition-specific Pallet seam,
# walks onto the real Route 22 ambush coordinate, and ends after Brock.
expected_maps = [
    "REDS_HOUSE_2F",
    "REDS_HOUSE_1F",
    "PALLET_TOWN",
    "OAKS_LAB",
    "PALLET_TOWN",
    "ROUTE_1",
    "VIRIDIAN_CITY",
    "VIRIDIAN_MART",
    "VIRIDIAN_CITY",
    "ROUTE_1",
    "PALLET_TOWN",
    "OAKS_LAB",
    "PALLET_TOWN",
    "ROUTE_1",
    "VIRIDIAN_CITY",
    "VIRIDIAN_MART",
    "VIRIDIAN_CITY",
    "ROUTE_22",
    "VIRIDIAN_CITY",
    "ROUTE_2",
    "VIRIDIAN_FOREST_SOUTH_GATE",
    "VIRIDIAN_FOREST",
    "VIRIDIAN_FOREST_NORTH_GATE",
    "ROUTE_2",
    "PEWTER_CITY",
    "PEWTER_GYM",
]
assert re.findall(r'\bmap\s*=\s*"([A-Z0-9_]+)"', route) == expected_maps
for token in (
    'local palletOakTriggerY = edition == "yellow" and 0 or 1',
    '{ op = "goto", x = 10, y = palletOakTriggerY }',
    '{ op = "talk" }',
    '{ op = "allowCatch", mon = "nidoran" }',
    '{ op = "manual", name = "catchNidoran" }',
    '{ op = "goto", x = 29, y = 5 }',
    '{ op = "talk", face = "up" }',
    '{ op = "battle" }',
    '{ op = "goto", x = 4, y = 14 }',
):
    assert token in route, token
ops = set(re.findall(r'\bop\s*=\s*"([A-Za-z]+)"', route))
assert ops == {
    "goto",
    "talk",
    "battle",
    "shop",
    "allowCatch",
    "manual",
    "pickup",
    "heal",
}, ops
assert "ROUTE_3" not in route

# Both the wrapper and route table are observation/input only.  In
# particular, no acceptance code may award the badge, set a story flag,
# install a party, force a battle finish or bypass walking.
joined = driver + "\n" + route
for forbidden in (
    "SaveData.newGame(",
    "U.teleport(",
    "Flags.set(",
    "Flags.clear(",
    "BattleState.newTrainer(",
    ":onFinish(",
    ".onFinish =",
    "tests/fixtures",
    "/Users/",
    ".worktrees/ka-",
):
    assert forbidden not in joined, forbidden
for pattern in (
    r"game\.save\s*=(?!=)",
    r"game\.save\.flags\s*=(?!=)",
    r"game\.save\.party\s*=(?!=)",
    r"game\.save\.inventory\s*=(?!=)",
    r"flags\.EVENT_[A-Z0-9_]+\s*=(?!=)\s*true",
    r"inventory\.[A-Z0-9_]+\s*=(?!=)",
    r"inventory\[[^]]+\]\s*=(?!=)",
    r"BOULDERBADGE\s*=(?!=)",
    r"EVENT_BEAT_BROCK\s*=(?!=)",
):
    assert not re.search(pattern, joined), pattern

# The frozen general interpreter itself must stay the audited real-input
# implementation and must not smuggle the required outcome into save data.
for token in (
    'local ROUTE = require("tests.drivers.bot_route")',
    'function ops.goto_',
    'function ops.battle',
    'local function fightBattle',
    'local function runRoute(startIndex)',
    'local function runRouteGuarded(startIndex)',
    'local newGameLabel = require("src.core.Strings")("NEW GAME")',
    'if t.titleUiBox then',
    'it.label == newGameLabel',
    'type(it.onSelect) == "function"',
    'if matches ~= 1 or not newRow then',
    'selected ~= titleMenu',
    'selectedItem.label ~= newGameLabel',
    'type(selectedItem.onSelect) ~= "function"',
    'refusing blind NEW GAME input',
    'G:writeSave()',
):
    assert token in runner, token
for forbidden in (
    'it.label == "NEW GAME"',
    "U.newGame(game)",
    "falling back to U.newGame",
):
    assert forbidden not in runner, forbidden
for pattern in (
    r"G\.save\.flags\s*=(?!=)",
    r"G\.save\.party\s*=(?!=)",
    r"G\.save\.inventory\s*=(?!=)",
    r"G\.save\.flags\[[^]]+\]\s*=(?!=)",
    r"G\.save\.inventory\[[^]]+\]\s*=(?!=)",
    r"Flags\.(?:set|clear)\(",
    r"EVENT_BEAT_BROCK\s*=(?!=)",
    r"BOULDERBADGE\s*=(?!=)",
):
    assert not re.search(pattern, runner), pattern

print(
    "connected first-badge package contract PASS: "
    "R/B/Y real input + BattleState + Boulder Badge + native reload"
)
