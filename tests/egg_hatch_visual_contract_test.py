#!/usr/bin/env python3
"""Fail-closed contract for TEST-RC-002 hatch colour/fragment lifecycle."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SOURCE = (ROOT / "egg_hatch_animation.lua").read_text("utf-8")
PHASE = (ROOT / "tests/breeding_phase7_test.lua").read_text("utf-8")

for token in (
    "if okImage then return image, true end",
    "return ok and image or nil, trueColor == true",
    "return frame >= CRACK_END and frame < FRAGMENT_END",
    "PaletteFX.markTrueColor(math.floor(x), math.floor(y), size + 1, size + 1)",
    "if M.fragmentsVisible(self.frame) then drawFragments(self.frame) end",
    "fragmentEnd = FRAGMENT_END",
):
    assert token in SOURCE, token

for forbidden in (
    "if okImage then return image, false end",
    "drawFragments(self.frame)\n    end",
):
    assert forbidden not in SOURCE, forbidden

for token in (
    'hatchAnimation.fragmentsVisible(154), true',
    'hatchAnimation.fragmentsVisible(189), false',
    'hatchAnimation.fragmentsVisible(210), false',
):
    assert token in PHASE, token

print("egg hatch true-color/fragment lifecycle contract PASS")
