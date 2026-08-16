#!/usr/bin/env python3
"""Build the Legacy-Journey Oak host portrait from its approved v1 master.

The live 64/128px trainer pair remains immutable. This script only crops the
transparent, already-authored v1 master so the Legacy PicBox can downsample
real source detail in screen space instead of enlarging a 34x58px subject.
"""

from __future__ import annotations

import hashlib
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SOURCE = (ROOT / "qa" / "trainer_voxel_asset_authoring_20260812" / "keyed"
          / "professor_oak_voxel_front_hd_v1_alpha.png")
DESTINATION = (ROOT / "assets" / "characters" / "frlg_trainers"
               / "professor_oak_legacy_host_hd_v1.png")
EXPECTED_SOURCE_SHA256 = (
    "a586b11480249da9af0685ffc759468a9a85144b623268a690faa1c0e2fff881"
)
EXPECTED_SOURCE_SIZE = (1122, 1402)
EXPECTED_ALPHA_BBOX = (222, 143, 812, 1152)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> None:
    if sha256(SOURCE) != EXPECTED_SOURCE_SHA256:
        raise RuntimeError("approved Professor Oak v1 master hash changed")
    source = Image.open(SOURCE).convert("RGBA")
    if source.size != EXPECTED_SOURCE_SIZE:
        raise RuntimeError(f"unexpected source size: {source.size}")
    bbox = source.getchannel("A").getbbox()
    if bbox != EXPECTED_ALPHA_BBOX:
        raise RuntimeError(f"unexpected Oak alpha bounds: {bbox}")

    portrait = source.crop(bbox)
    if portrait.size != (590, 1009):
        raise RuntimeError(f"unexpected cropped portrait size: {portrait.size}")
    if portrait.getchannel("A").getbbox() != (0, 0, 590, 1009):
        raise RuntimeError("cropped Oak portrait lost its edge-to-edge bounds")

    DESTINATION.parent.mkdir(parents=True, exist_ok=True)
    portrait.save(DESTINATION, optimize=True)
    print(
        "LEGACY OAK HOST HD ASSET PASS: "
        f"{portrait.width}x{portrait.height}; sha256={sha256(DESTINATION)}"
    )


if __name__ == "__main__":
    main()
