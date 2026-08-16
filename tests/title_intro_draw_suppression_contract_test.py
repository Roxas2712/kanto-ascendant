#!/usr/bin/env python3
"""Static contract for the native-cycle atomic title compositor."""

import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SOURCE = (ROOT / "title_intro.lua").read_text("utf-8")
CRYSTAL = (ROOT / "crystal_v15_features.lua").read_text("utf-8")
ANIMATION = (ROOT / "crystal_animation.lua").read_text("utf-8")
DRIVER = (ROOT / "tests/title_intro_natural_draw_regression_driver.lua").read_text(
    "utf-8"
)

for token in (
    'self.kaTitlePhase = "pair"',
    'self.kaTitleAtomicCycle = true',
    '{ id = "GREEN", image = green, source = "ascendant" }',
    '{ id = "BLUE", image = blue, source = "ascendant" }',
    '{ id = "RED", image = red, source = "vanilla" }',
    'self.kaTitlePairId = entry.id .. ":" .. tostring(species)',
    "self.cycleIndex ~= cycleBefore",
    "speciesAfter ~= speciesBefore",
    "publishTitleIdentity(self, nextTrainer, speciesAfter)",
    "return originalCurrentSprite(self)",
    "return originalDraw(screen)",
    "self.player = entry.image",
):
    assert token in SOURCE, token

# The mod may observe the engine-owned rotation but can never replace it with
# a private starter list or write its index from the trainer cycle.
assert not re.search(r"\bself\.cycleSpecies\s*=(?!=)", SOURCE)
for forbidden in (
    "timerBefore",
    "timerBefore > self.timer",
    "kaTitlePairs",
    'species = "BULBASAUR"',
    'species = "SQUIRTLE"',
    'species = "CHARMANDER"',
    "M.species",
):
    assert forbidden not in SOURCE, forbidden

for token in (
    "screen.kaTitleAtomicCycle == true",
    "screen.kaTitleSpecies",
    "forceBundled = forcedCycle",
    "if screen.kaTitleAtomicCycle then return nil, false end",
):
    assert token in CRYSTAL, token
for token in (
    "local forceBundled = opts.forceBundled == true",
    'local which = forceBundled and "normal"',
    "full engine-owned title rotation",
):
    assert token in ANIMATION, token

# A paired beat must never hide either native half of the compositor.
for forbidden in (
    "screen.player = nil",
    "screen.playerQuads = nil",
    "screen.ballQuad = nil",
    'if self.kaTitlePhase == "trainer" then return nil',
):
    assert forbidden not in SOURCE, forbidden
assert 'if screen.kaTitlePhase == "trainer" then return nil' not in CRYSTAL

for token in (
    "local expectedCycle = {",
    '"WEEDLE", "NIDORAN_M"',
    'transitionTo("NIDORAN_M", "BLUE")',
    'transitionTo("SCYTHER", "RED")',
    'transitionTo("DITTO", "GREEN")',
    '"GREEN:CHARMANDER", "BLUE:NIDORAN_M"',
    '"RED:SCYTHER", "GREEN:DITTO"',
    "cycleSnapshot",
    "nativeRandom = love.math.random",
    "observedTrainer",
    "observedPokemon",
    "state.animated",
    "timer-only resets",
    "injected downstream title draw failure",
    "title.title.copyrightText == footer",
    "title.title.germanFullVersionRibbon == ribbon",
    "native_cycle_unchanged_after=16/16",
    "runtime_options_changed=0",
    "status=PASS",
    "fail=0",
):
    assert token in DRIVER, token

for forbidden in (
    "table.insert(title.cycleSpecies",
    "table.remove(title.cycleSpecies",
):
    assert forbidden not in DRIVER, forbidden
assert not re.search(
    r"title\.cycleSpecies(?:\s*\[[^]]+\])?\s*=(?!=)", DRIVER
)

print("title intro native-cycle paired-compositor contract PASS")
