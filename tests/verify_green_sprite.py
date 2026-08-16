#!/usr/bin/env python3
"""Pixel-exact guards for the approved Green and Blue character art."""

from hashlib import sha256
from pathlib import Path
import importlib.util

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location(
    "build_character_demo_assets", ROOT / "tools/build_character_demo_assets.py"
)
builder = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(builder)


def pixels(path: Path):
    with Image.open(path) as image:
        return image.convert("RGBA").size, tuple(image.convert("RGBA").getdata())


expected_walk = builder.decode_rle(
    16, 96, builder.GREEN_WALK_RLE, builder.GREEN_OVERWORLD
)
expected_front = builder.decode_rle(
    56, 56, builder.GREEN_FRONT_RLE, builder.GREEN_OVERWORLD
)
expected_blue_back = builder.decode_rle(
    32, 32, builder.BLUE_BACK_RLE, builder.GREEN_OVERWORLD
)
expected_green_back = builder.decode_rle(
    32, 32, builder.GREEN_BACK_RLE, builder.DMG
)
expected = {
    "green_walk.png": (expected_walk.size, tuple(expected_walk.getdata())),
    "green_front.png": (expected_front.size, tuple(expected_front.getdata())),
    "blue_back.png": (expected_blue_back.size,
                      tuple(expected_blue_back.getdata())),
    "green_back.png": (expected_green_back.size,
                       tuple(expected_green_back.getdata())),
}

for name, golden in expected.items():
    path = ROOT / "assets/characters" / name
    actual = pixels(path)
    assert actual == golden, f"pixel drift in {path}"
    print(f"PASS pixel-exact {path.relative_to(ROOT)} sha256={sha256(path.read_bytes()).hexdigest()}")

print("CHARACTER SPRITE RESULT pass=4 fail=0")
