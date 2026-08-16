#!/usr/bin/env python3
"""Structural acceptance gate for the complete CRYSTAL CHARS family."""

from pathlib import Path
import hashlib

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "assets" / "characters" / "crystal_chars"
APPROVED_WALK = (ROOT / "assets" / "sources" / "characters" /
                 "crystal_chars" / "approved_walk")
EXPECTED = {
    "front": (64, 64),
    "voxel_front": (64, 64),
    "voxel_front_hd": (128, 128),
    "back": (64, 64),
    "walk": (16, 96),
    "bike": (16, 96),
    "fish": (16, 96),
}

# User-approved RC17 character family. Any byte change is intentional artwork
# work and must update this fingerprint explicitly; ordinary feature/bugfix
# work is not allowed to silently alter a selected, intro, battle, walking,
# bike, fishing or throw sprite.
FROZEN_TREE_SHA256 = "aa8f3bc9109da1c68d217a192796f3b1ceee5aa6d0374558278aae242e8f8a34"


def check(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


checks = 0
frozen = hashlib.sha256()
for frozen_path in sorted(ASSETS.glob("*.png")):
    frozen.update(frozen_path.relative_to(ASSETS).as_posix().encode())
    frozen.update(b"\0")
    frozen.update(frozen_path.read_bytes())
check(frozen.hexdigest() == FROZEN_TREE_SHA256,
      "approved RC17 character sprites changed without explicit re-approval")
checks += 1

for character in ("red", "green", "blue"):
    for state, dimensions in EXPECTED.items():
        path = ASSETS / f"{character}_{state}.png"
        check(path.is_file(), f"missing {path}")
        image = Image.open(path).convert("RGBA")
        check(image.size == dimensions, f"{path.name}: {image.size} != {dimensions}")
        checks += 2
        alpha = image.getchannel("A")
        check(alpha.getextrema() == (0, 255), f"{path.name}: alpha is not hard-edged")
        check(all(image.getpixel(point)[3] == 0 for point in (
            (0, 0), (image.width - 1, 0), (0, image.height - 1),
            (image.width - 1, image.height - 1))),
            f"{path.name}: transparent frame corners required")
        checks += 2

        frame_height = 16 if state in ("walk", "bike", "fish") else image.height
        frame_count = 6 if state in ("walk", "bike", "fish") else 1
        for frame in range(frame_count):
            frame_alpha = alpha.crop((0, frame * frame_height,
                                      image.width, (frame + 1) * frame_height))
            bbox = frame_alpha.getbbox()
            check(bbox is not None, f"{path.name} frame {frame}: empty")
            if state in ("walk", "bike", "fish"):
                check(bbox[3] >= frame_height - 1,
                      f"{path.name} frame {frame}: feet are not baseline-aligned")
                checks += 1
            elif state == "voxel_front":
                check(bbox[3] <= 61,
                      f"{path.name}: transparent floor gap below shoes required")
                check(bbox[3] - bbox[1] >= 54,
                      f"{path.name}: standing figure lost its feet or full height")
                checks += 2
            elif state == "voxel_front_hd":
                check(bbox[3] <= 122,
                      f"{path.name}: HD floor gap below shoes required")
                check(bbox[3] - bbox[1] >= 108,
                      f"{path.name}: HD standing figure lost its full height")
                checks += 2
            checks += 1

        # Keying errors are conspicuous neon pixels and must never enter a
        # runtime sheet. Dark clothing/hair colors are unaffected.
        green_screen = sum(1 for red, green, blue, alpha_value in image.getdata()
                           if alpha_value and green > 180
                           and green > red * 1.35 and green > blue * 1.25)
        check(green_screen == 0, f"{path.name}: {green_screen} chroma pixels remain")
        checks += 1

    walk_runtime = (ASSETS / f"{character}_walk.png").read_bytes()
    walk_master = (APPROVED_WALK / f"{character}_walk.png").read_bytes()
    check(walk_runtime == walk_master,
          f"{character}: runtime walk differs from approved master")
    checks += 1

    throw_frames = []
    for frame in range(1, 6):
        path = ASSETS / f"{character}_back_throw_{frame}.png"
        check(path.is_file(), f"missing {path}")
        image = Image.open(path).convert("RGBA")
        check(image.size == (64, 64), f"{path.name}: must stay native 64x64")
        check(image.getchannel("A").getextrema() == (0, 255),
              f"{path.name}: alpha is not hard-edged")
        bbox = image.getchannel("A").getbbox()
        check(bbox is not None and bbox[3] >= 63,
              f"{path.name}: throw pose is not baseline-aligned")
        throw_frames.append(image.tobytes())
        checks += 4
    check(len(set(throw_frames)) == 5,
          f"{character}: all five throw poses must be visually distinct")
    check(throw_frames[0] == Image.open(
        ASSETS / f"{character}_back.png").convert("RGBA").tobytes(),
        f"{character}: neutral back must equal throw frame one")
    checks += 2

print(f"CRYSTAL CHARACTER ASSETS PASS: {checks} checks")
