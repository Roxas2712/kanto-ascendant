#!/usr/bin/env python3
"""Static fail-closed contract for the focused Gorochu 2D LÖVE driver."""

from __future__ import annotations

import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DRIVER = ROOT / "tests/gorochu_2d_release_visual_driver.lua"
IGNORE = ROOT / ".modkitignore"
source = DRIVER.read_text(encoding="utf-8")
ignored = IGNORE.read_text(encoding="utf-8").splitlines()
checks = 0


def require(value: bool, message: str) -> None:
    global checks
    checks += 1
    if not value:
        raise AssertionError(message)


for token in (
    'os.getenv("KA_GOROCHU_2D_RELEASE_QA") == "1"',
    'os.getenv("POKEPORT_VERSION") == "red"',
    'os.getenv("POKEPORT_SPEED") == "1"',
    'local nonce = assert(os.getenv("KA_GOROCHU_QA_NONCE")',
    'local expectedIdentity = "ka65-gorochu-2d-release-" .. nonce',
    'love.filesystem.getIdentity() == expectedIdentity',
    'SHOT_DIR must be a throwaway /private/tmp or /tmp directory',
    'KA_GOROCHU_MOD_ROOT',
    'mounted bytes differ from KA_GOROCHU_MOD_ROOT:',
    '"bound_files=" .. #boundFiles',
    'local diskBefore = SaveData.load(edition)',
    'local diskAfter = SaveData.load(edition)',
    'assert(diskBefore == nil',
    'diskAfter.player.name == "GORO QA"',
    'throwaway identity does not own its save directory',
    'Sprites.path(game.data, "GOROCHU", side',
    'battler.__ascendantCrystalAnimation = nil',
    'battler.__ascendantCrystalAnimation,',
    'crystal.selected[battler.mon]',
    'Pipelines.setLevel("voxel", 0)',
    'setOption("pokemon_sprite_style", "crystal")',
    'setOption("pokemon_sprite_style", "original")',
    'PaletteFX.setMode("redpp")',
    'classic sprite stage escaped its neutral 2D display contract',
    'captureStage("color-normal-back-shiny-front", "normal", "shiny"',
    'captureStage("color-shiny-back-normal-front", "shiny", "normal"',
    'captureStage("classic-grayscale", "grayscale", "grayscale"',
    'state.image:getFilter()',
    'BattleState.resolveBattleScale(',
    'game.data, "back", nil, "GOROCHU") == 1',
    'screenshots=6/6',
):
    require(token in source, f"missing contract token: {token}")

screens = [
    "01_color_normal_back_shiny_front_a.png",
    "02_color_normal_back_shiny_front_b.png",
    "03_color_shiny_back_normal_front_a.png",
    "04_color_shiny_back_normal_front_b.png",
    "05_classic_grayscale_a.png",
    "06_classic_grayscale_b.png",
]
for screen in screens:
    require(source.count(f'"{screen}"') == 1,
            f"screenshot name missing or duplicated: {screen}")

require(source.count("BattleState.newWild(") == 1,
        "driver must construct exactly one battle")
require("BattleState.newTrainer(" not in source,
        "driver must not construct a second trainer battle")
require("U.newGame(" not in source,
        "driver must not traverse or persist a normal new-game flow")
require("ASH" not in source and "BLITZ" not in source,
        "driver must not reference user acceptance saves")

for forbidden in (
    "game:writeSave(",
    "game.writeSave(",
    "SaveData.save(",
    "game:writeOptions(",
    "game.writeOptions(",
    "SaveData.saveOptions(",
):
    require(forbidden not in source, f"driver contains a disk write: {forbidden}")

route = source.index("local function routeAndReset")
live = source.index("local function assertLiveState")
stage = source.index("local function reselectStage")
capture = source.index("local function captureStage")
first_capture = source.index('captureStage("color-normal-back-shiny-front"')
swap = source.index("shinySystem.forceMon(\n    battle.player.mon", first_capture)
second_capture = source.index('captureStage("color-shiny-back-normal-front"')
classic = source.index('setOption("pokemon_sprite_style", "original")')
third_capture = source.index('captureStage("classic-grayscale"')
disk_after = source.index("local diskAfter = SaveData.load(edition)")
receipt = source.index('normalizedOutput .. "/driver_result.txt", "wb"')
require(route < live < stage < capture < first_capture < swap
        < second_capture < classic < third_capture < disk_after < receipt,
        "normal/shiny/classic/reacquire/receipt order drifted")

require(re.search(
    r"for _ = 1, 180 do\s+U\.wait\(1\)\s+"
    r"-- Reacquire[\s\S]+?assertLiveState\(battle\.player[\s\S]+?"
    r"assertLiveState\(battle\.enemy",
    source,
) is not None, "capture loop does not reacquire both live battler states")

require("tests/gorochu_2d_release_visual_driver.lua" in ignored,
        "visual driver would leak into the mod package")
require("tests/gorochu_2d_release_visual_driver_contract_test.py" in ignored,
        "driver contract would leak into the mod package")

print(f"GOROCHU 2D RELEASE DRIVER CONTRACT PASS: {checks} checks")
