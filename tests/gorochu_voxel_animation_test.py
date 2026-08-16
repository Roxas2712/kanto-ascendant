#!/usr/bin/env python3
"""Asset-level gate for Gorochu's authored high-resolution Voxel cycle."""

from __future__ import annotations

import hashlib
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
ANIMATION = ROOT / "assets/voxel/gorochu/animation"
checks = 0
EXPECTED_FALLBACK_DIGEST = (
    "61a1f068e03ad632f60e20e6176a78d88f9ba8c3acf771844133220b8fdac439"
)


def require(value: bool, message: str) -> None:
    global checks
    checks += 1
    if not value:
        raise AssertionError(message)


loaded: dict[str, list[Image.Image]] = {}
fallback_paths = sorted(ANIMATION.glob("*/*.png"))
fallback_digest = hashlib.sha256("".join(
    hashlib.sha256(path.read_bytes()).hexdigest()
    for path in fallback_paths
).encode()).hexdigest()
require(fallback_digest == EXPECTED_FALLBACK_DIGEST,
        "approved illustrated fallback bytes changed")
for variant in ("normal", "shiny"):
    paths = sorted((ANIMATION / variant).glob("*.png"))
    require(len(paths) == 6, f"{variant}: expected six authored Voxel frames")
    frames = [Image.open(path).convert("RGBA") for path in paths]
    loaded[variant] = frames
    require(all(frame.size == (96, 96) for frame in frames),
            f"{variant}: Voxel frame geometry changed")
    require(len({frame.tobytes() for frame in frames}) == 6,
            f"{variant}: authored pose cycle contains a duplicate frame")

    for index, frame in enumerate(frames, 1):
        alpha = frame.getchannel("A")
        box = alpha.getbbox()
        require(box is not None, f"{variant} frame {index}: empty artwork")
        require(box[0] > 0 and box[1] > 0 and box[2] < 96 and box[3] < 96,
                f"{variant} frame {index}: artwork clips the Voxel canvas: {box}")
        require(set(alpha.getdata()) <= {0, 255},
                f"{variant} frame {index}: alpha matte is not clean")
        colors = {pixel for pixel in frame.getdata() if pixel[3]}
        require(len(colors) > 1000,
                f"{variant} frame {index}: high-resolution art was quantized")
        green_matte = [
            pixel for pixel in colors
            if pixel[1] >= 180
            and pixel[1] >= pixel[0] * 1.8
            and pixel[1] >= pixel[2] * 1.8
            and pixel[1] - pixel[0] >= 80
            and pixel[1] - pixel[2] >= 80
        ]
        require(not green_matte,
                f"{variant} frame {index}: green-screen matte remains")

for index, (normal, shiny) in enumerate(zip(loaded["normal"], loaded["shiny"]), 1):
    require(normal.getchannel("A").tobytes() == shiny.getchannel("A").tobytes(),
            f"frame {index}: normal/shiny pose silhouettes diverged")
    require(normal.tobytes() != shiny.tobytes(),
            f"frame {index}: shiny palette is not distinct")

for variant, suffix in (("normal", ""), ("shiny", "_shiny")):
    static = Image.open(
        ROOT / f"assets/voxel/gorochu/gorochu_front{suffix}.png"
    ).convert("RGBA")
    require(static.tobytes() == loaded[variant][0].tobytes(),
            f"{variant}: Dex/static master is not authored Voxel frame one")
    catalogue = Image.open(
        ROOT / f"assets/voxel/gorochu/gorochu_dex{suffix}.png"
    ).convert("RGBA")
    require(catalogue.size == (56, 56),
            f"{variant}: catalogue card does not fit the Dex renderer")
    box = catalogue.getchannel("A").getbbox()
    require(box is not None and box[2] - box[0] >= 48
            and box[3] - box[1] >= 50,
            f"{variant}: fallback card crushes the approved silhouette")
    require(len({pixel for pixel in catalogue.getdata() if pixel[3]}) > 1000,
            f"{variant}: catalogue card was over-quantized")

placeholder = Image.open(
    ROOT / "assets/voxel/gorochu/gorochu_catalogue_placeholder.png"
).convert("RGBA")
require(placeholder.size == (56, 56),
        "catalogue overlay placeholder changed geometry")
require(placeholder.getchannel("A").getbbox() is None,
        "catalogue overlay placeholder is not fully transparent")

print(f"GOROCHU VOXEL ANIMATION PASS: {checks} checks")
