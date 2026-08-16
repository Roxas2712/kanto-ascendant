#!/usr/bin/env python3
"""Fail-closed asset gate for the screen-space Legacy Oak portrait."""

from __future__ import annotations

import hashlib
from pathlib import Path

from PIL import Image, ImageChops


ROOT = Path(__file__).resolve().parents[1]
SOURCE = (ROOT / "qa" / "trainer_voxel_asset_authoring_20260812" / "keyed"
          / "professor_oak_voxel_front_hd_v1_alpha.png")
LIVE = (ROOT / "assets" / "characters" / "frlg_trainers"
        / "professor_oak_legacy_host_hd_v1.png")
LOW = (ROOT / "assets" / "characters" / "frlg_trainers"
       / "professor_oak_voxel_front_v1.png")
OLD_HD = (ROOT / "assets" / "characters" / "frlg_trainers"
          / "professor_oak_voxel_front_hd_v1.png")


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


assert sha256(SOURCE) == (
    "a586b11480249da9af0685ffc759468a9a85144b623268a690faa1c0e2fff881"
)
assert sha256(LOW) == (
    "a7999c98d9e4c98f087f113b9d5a6a6b2583b09acacf8626003fb2e7e40238a5"
)
assert sha256(OLD_HD) == (
    "16c4ab75a3ea37a6e876726f85baa4e568d5ac14ffdb2e7e52cac7298858e209"
)
assert sha256(LIVE) == (
    "0223e15ca070e4ac03d1633f61803e6eb2aef0ed31fdd423cca0670b6919686f"
)

source = Image.open(SOURCE).convert("RGBA")
live = Image.open(LIVE).convert("RGBA")
low = Image.open(LOW).convert("RGBA")
old_hd = Image.open(OLD_HD).convert("RGBA")
assert source.size == (1122, 1402)
assert source.getchannel("A").getbbox() == (222, 143, 812, 1152)
assert live.size == (590, 1009)
assert live.getchannel("A").getbbox() == (0, 0, 590, 1009)
assert ImageChops.difference(
    live, source.crop(source.getchannel("A").getbbox())
).getbbox() is None

# The legacy bug was not a missing filter: the 128px sibling is merely the
# same 15-colour, nearest-neighbour artwork as the 64px file. The screen-space
# master contains genuine authored detail and more than 17x the source height
# of the old 58px-alpha subject before the window is enlarged.
assert low.getchannel("A").getbbox() == (15, 3, 49, 61)
assert old_hd.getchannel("A").getbbox() == (30, 7, 98, 122)
assert low == old_hd.resize((64, 64), Image.Resampling.NEAREST)
opaque_live = {pixel for pixel in live.getdata() if pixel[3]}
opaque_old = {pixel for pixel in old_hd.getdata() if pixel[3]}
assert len(opaque_old) == 15
assert len(opaque_live) > 70_000
assert live.height / 58 > 17

lua = (ROOT / "legacy_journey.lua").read_text(encoding="utf-8")
assert "professor_oak_legacy_host_hd_v1.png" in lua
assert 'mod.hooks:wrap("render.hud"' in lua
assert "portrait.image = nil" in lua
assert "kascLegacyOakFallbackImage" in lua

print(
    "LEGACY OAK HOST HD ASSET PASS: approved 590x1009 v1 crop; "
    "64/128 protected pair unchanged; screen-space source has >70k colours"
)
