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

# Maintainer-approved 2026-08-18 character family. Any byte change is intentional artwork
# work and must update this fingerprint explicitly; ordinary feature/bugfix
# work is not allowed to silently alter a selected, intro, battle, walking,
# bike, fishing or throw sprite.
FROZEN_TREE_SHA256 = "d3f2868ec9815d7f65b35b0591a8cf75028dddf5d11ff2eb6865b54d6d37340b"

PRIMARY_SHA256 = {
    "red": "7695f40c70e7895d58b2d578b440ca441bacd5b082c9ef666be50a0e1bd0d108",
    "green": "240a48a253dbff69ac30129d9e601a3eac84b25f63dbd7457ebe5001aec7677e",
    "blue": "fdc8590438df553d7c231c3869bc1933c705d35f6a1ca84ee7d4a1931e402466",
}

FALLBACK_WALK = ASSETS / "fallback_walk_v1"
FALLBACK_WALK_V2 = ASSETS / "fallback_walk_v2"
FALLBACK_WALK_V3 = ASSETS / "fallback_walk_v3"
FALLBACK_SHA256 = {
    "red": "9610ec76545c3e4483a99037719ec28d2b13df3e671534e745a047a6ef693116",
    "green": "6bd2e838436af982ea031e59463f956904c68e9cd7a6b1d8f333e20e97440727",
    "blue": "69a71acb78d5137204e40298cbeee3d82a5012576ed278b860797ada96fabb3c",
}


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
      "approved character sprites changed without explicit re-approval")
checks += 1

for character in ("red", "green", "blue"):
    for state, dimensions in EXPECTED.items():
        path = ASSETS / f"{character}_{state}.png"
        # Red's compact 2D front is intentionally ROM-derived at runtime;
        # unlike Blue and Green it has no redistributed PNG in this family.
        if character == "red" and state == "front":
            check(not path.exists(),
                  "Red unexpectedly bundled a non-walking 2D front asset")
            checks += 1
            continue
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
                if state == "walk":
                    # A native Crystal walk cycle keeps the three idle poses
                    # at local Y=0 and lowers each matching gait pose by one
                    # pixel. Missing that phase made Red's down/left motion
                    # read as a static frame even though its pixels differed.
                    expected_top = 0 if frame < 3 else 1
                    check(bbox[1] == expected_top,
                          f"{path.name} frame {frame}: alpha top {bbox[1]} "
                          f"!= walking phase {expected_top}")
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
    check(hashlib.sha256(walk_runtime).hexdigest() == PRIMARY_SHA256[character],
          f"{character}: approved 2026-08-18 primary hash drift")
    checks += 2

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

    fallback_path = FALLBACK_WALK / f"{character}_walk.png"
    check(fallback_path.is_file(), f"missing {fallback_path}")
    check(hashlib.sha256(fallback_path.read_bytes()).hexdigest()
          == FALLBACK_SHA256[character],
          f"{character}: approved walking fallback changed")
    fallback_image = Image.open(fallback_path).convert("RGBA")
    check(fallback_image.size == (16, 96),
          f"{character}: walking fallback must remain 16x96")
    check(set(fallback_image.getchannel("A").getdata()) <= {0, 255},
          f"{character}: walking fallback alpha is not hard-edged")
    checks += 4

    fallback_v2_path = FALLBACK_WALK_V2 / f"{character}_walk.png"
    check(fallback_v2_path.is_file(), f"missing {fallback_v2_path}")
    check(hashlib.sha256(fallback_v2_path.read_bytes()).hexdigest() == {
        "red": "301321946b885e9bd978ae239f5b67fb318e035118ce6f04c628d657a04b3c86",
        "green": "c4f44ce40df9d30372a881cd3af6c25060ec48c4ad610fc7f4bd9f804397aa72",
        "blue": "6ecc6fe6a55549950b69fb25f42d9ce81b148b8231e8f6a3140ab09e7edd18dd",
    }[character], f"{character}: walking fallback v2 changed")
    fallback_v2_image = Image.open(fallback_v2_path).convert("RGBA")
    check(fallback_v2_image.size == (16, 96),
          f"{character}: walking fallback v2 must remain 16x96")
    check(set(fallback_v2_image.getchannel("A").getdata()) <= {0, 255},
          f"{character}: walking fallback v2 alpha is not hard-edged")
    checks += 4

    if character == "green":
        fallback_v3_path = FALLBACK_WALK_V3 / "green_walk.png"
        check(fallback_v3_path.is_file(), f"missing {fallback_v3_path}")
        check(hashlib.sha256(fallback_v3_path.read_bytes()).hexdigest()
              == "bdfb9f19f57da47cb32d6f5d82c94a507ee86eb6eae4e38bc715469f6d00e6d4",
              "Green: preceding primary fallback changed")
        fallback_v3_image = Image.open(fallback_v3_path).convert("RGBA")
        check(fallback_v3_image.size == (16, 96),
              "Green: walking fallback v3 must remain 16x96")
        check(set(fallback_v3_image.getchannel("A").getdata()) <= {0, 255},
              "Green: walking fallback v3 alpha is not hard-edged")
        checks += 4

check(not (FALLBACK_WALK_V3 / "red_walk.png").exists()
      and not (FALLBACK_WALK_V3 / "blue_walk.png").exists(),
      "Green-only hotfix fallback v3 must not replace Red or Blue")
checks += 1

print(f"CRYSTAL CHARACTER ASSETS PASS: {checks} checks")
