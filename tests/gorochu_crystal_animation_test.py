#!/usr/bin/env python3
"""Strict release contract for Gorochu's connected-tail 64 px matrix."""

from __future__ import annotations

import hashlib
import subprocess
import sys
import tempfile
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
BUILDER = ROOT / "tools/build_gorochu_crystal_animation.py"
DEX = "1026"
FRAME_COUNT = 6
TRANSPARENT = (0, 0, 0, 0)
checks = 0

SOURCE_SHA256 = {
    "assets/sources/gorochu/pinfinity_wiki_732_front_normal.png": "b2402d1fd6d6370571d0df59cadc978558785788f9b17144211d5ea9c0e9d498",
    "assets/sources/gorochu/pinfinity_wiki_732_back_normal.png": "1f3102fbfeed10979d02361fcda182e9317df9b79690f6b521c0075f08c6e88e",
    "assets/sources/gorochu/pinfinity_wiki_732_front_shiny.png": "aa794f5f6ba794a1de7f14e569ff1156249a4e83ab5b87c355c0a5d383ba5ed5",
    "assets/sources/gorochu/pinfinity_wiki_732_back_shiny.png": "9a31e2e71e295452ab0f8c0650a4a46bfeb0d96cbed18fa13bb97c58f22e75c4",
    "assets/sources/gorochu/pinfinity_v540_front_normal_56.png": "5f09edea0a186df794a549a5a8d2db2d42a96df7fab90beff9cdc8c27eb40d16",
    "assets/sources/gorochu/pinfinity_v540_front_shiny_56.png": "605f2f9ccbb973de0ce5e7c20b994db7f716eae4d153fa718262da140159e274",
    "assets/sources/gorochu/pinfinity_v540_back_normal_56.png": "6ca9669687ca68ebfb9ebfc99eaa6644dc312fc4e18c701f83dab33f069886b1",
    "assets/sources/gorochu/pinfinity_v540_back_shiny_56.png": "942bed4b1e789ca0db45d221ec67e734f9f849030de0ea0eee29805760d31292",
}

# Filled after the deterministic build below; sets remain explicit release
# contracts and reject interpolated/halo colours.
EXPECTED_PALETTES = {
    ("back", "normal"): {
        (0, 0, 0, 255), (75, 35, 27, 255), (217, 84, 46, 255),
        (245, 139, 69, 255), (248, 184, 0, 255), (248, 216, 88, 255),
    },
    ("back", "shiny"): {
        (0, 0, 0, 255), (32, 32, 32, 255), (96, 88, 186, 255),
        (180, 143, 239, 255), (248, 183, 0, 255), (248, 215, 88, 255),
    },
    ("front", "normal"): {
        (0, 0, 0, 255), (75, 35, 27, 255), (117, 56, 42, 255),
        (157, 47, 35, 255), (182, 122, 82, 255), (217, 84, 46, 255),
        (224, 157, 129, 255), (224, 200, 160, 255), (245, 139, 69, 255),
        (248, 184, 0, 255), (248, 216, 88, 255), (248, 232, 208, 255),
    },
    ("front", "shiny"): {
        (0, 0, 0, 255), (32, 32, 32, 255), (50, 50, 50, 255),
        (75, 76, 141, 255), (83, 83, 83, 255), (96, 88, 186, 255),
        (157, 47, 35, 255), (174, 87, 9, 255), (180, 143, 239, 255),
        (224, 157, 129, 255), (224, 200, 160, 255), (248, 183, 0, 255),
        (248, 215, 88, 255), (248, 232, 208, 255),
    },
    ("front", "grayscale"): {
        (0, 0, 0, 255), (85, 85, 85, 255), (170, 170, 170, 255), (255, 255, 255, 255),
    },
    ("back", "grayscale"): {
        (0, 0, 0, 255), (85, 85, 85, 255), (170, 170, 170, 255), (255, 255, 255, 255),
    },
}


def require(value: bool, message: str) -> None:
    global checks
    checks += 1
    if not value:
        raise AssertionError(message)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def rgba(path: Path) -> Image.Image:
    with Image.open(path) as opened:
        return opened.convert("RGBA")


def animated_path(root: Path, side: str, variant: str, index: int) -> Path:
    return root / f"assets/crystal_animated/{side}/{variant}/{DEX}/{index:03d}.png"


def product_paths(root: Path) -> list[Path]:
    paths = [
        root / "assets/crystal/gorochu_front.png",
        root / "assets/crystal/gorochu_front_shiny.png",
        root / "assets/crystal/gorochu_back.png",
        root / "assets/crystal/gorochu_back_shiny.png",
    ]
    for side in ("front", "back"):
        for variant in ("normal", "shiny", "grayscale"):
            paths.extend(animated_path(root, side, variant, index) for index in range(1, FRAME_COUNT + 1))
    return paths


def mask(image: Image.Image) -> set[tuple[int, int]]:
    return {(x, y) for y in range(64) for x in range(64) if image.getpixel((x, y))[3]}


def components(points: set[tuple[int, int]]) -> list[set[tuple[int, int]]]:
    pending = set(points)
    result = []
    while pending:
        component = set()
        stack = [pending.pop()]
        while stack:
            x, y = stack.pop()
            component.add((x, y))
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    neighbour = (x + dx, y + dy)
                    if neighbour in pending:
                        pending.remove(neighbour)
                        stack.append(neighbour)
        result.append(component)
    return sorted(result, key=len, reverse=True)


def translated(image: Image.Image, dx: int, dy: int) -> bytes:
    target = Image.new("RGBA", image.size, TRANSPARENT)
    target.alpha_composite(image, (dx, dy))
    return target.tobytes()


def pure_translation(first: Image.Image, second: Image.Image) -> bool:
    second_bytes = second.tobytes()
    return any(
        translated(first, dx, dy) == second_bytes
        for dy in range(-3, 4)
        for dx in range(-3, 4)
    )


for relative, expected in SOURCE_SHA256.items():
    require(sha256(ROOT / relative) == expected, f"source provenance changed: {relative}")

ignore_lines = {line.strip() for line in (ROOT / ".modkitignore").read_text().splitlines()}
require("assets/sources/" in ignore_lines, "source originals must remain excluded from the package")

with tempfile.TemporaryDirectory(prefix="ka-gorochu-64-") as temporary:
    generated_root = Path(temporary)
    subprocess.run([sys.executable, str(BUILDER), "--output-root", str(generated_root)], cwd=ROOT, check=True)
    actual_paths = product_paths(ROOT)
    generated_paths = product_paths(generated_root)
    require(len(actual_paths) == 40, "Gorochu matrix must bind exactly 40 product PNGs")
    require(all(path.is_file() for path in actual_paths), "actual 64 px matrix is incomplete")
    require(all(path.is_file() for path in generated_paths), "temporary 64 px matrix is incomplete")
    for actual, generated in zip(actual_paths, generated_paths):
        require(sha256(actual) == sha256(generated), f"actual tree is stale: {actual.relative_to(ROOT)}")

    for side in ("front", "back"):
        by_variant = {}
        for variant in ("normal", "shiny", "grayscale"):
            directory = ROOT / f"assets/crystal_animated/{side}/{variant}/{DEX}"
            require(
                sorted(path.name for path in directory.glob("*.png"))
                == [f"{index:03d}.png" for index in range(1, FRAME_COUNT + 1)],
                f"{side}/{variant}: frame directory is not exactly 001..006",
            )
            frames = [rgba(animated_path(ROOT, side, variant, index)) for index in range(1, FRAME_COUNT + 1)]
            by_variant[variant] = frames
            require(all(frame.size == (64, 64) for frame in frames), f"{side}/{variant}: not 64x64")
            require(len({frame.tobytes() for frame in frames}) == 6, f"{side}/{variant}: frames are not byte-unique")
            for frame in frames:
                require(set(frame.getchannel("A").getdata()) <= {0, 255}, f"{side}/{variant}: non-binary alpha")
                require(
                    all(pixel == TRANSPARENT for pixel in frame.getdata() if pixel[3] == 0),
                    f"{side}/{variant}: transparent RGB is not zero",
                )
                bounds = frame.getchannel("A").getbbox()
                require(bounds is not None and bounds[0] >= 1 and bounds[1] >= 1 and bounds[2] <= 63,
                        f"{side}/{variant}: unsafe top/horizontal placement")
                require(bounds[3] == 64, f"{side}/{variant}: not bottom-anchored")

            visible = {pixel for frame in frames for pixel in frame.getdata() if pixel[3]}
            expected_palette = EXPECTED_PALETTES[(side, variant)]
            if expected_palette:
                require(visible == expected_palette, f"{side}/{variant}: exact palette changed: {sorted(visible)}")

        normal = by_variant["normal"]
        shiny = by_variant["shiny"]
        grayscale = by_variant["grayscale"]
        base_masks = [mask(normal[0]), mask(shiny[0]), mask(grayscale[0])]
        require(base_masks[0] == base_masks[1] == base_masks[2], f"{side}: base variant masks differ")
        base_mask = base_masks[0]
        require(len(components(base_mask)) == 1, f"{side}: body/tail/blade is not one connected component")

        for variant, frames in by_variant.items():
            base = frames[0]
            for index, frame in enumerate(frames):
                frame_mask = mask(frame)
                require(base_mask <= frame_mask, f"{side}/{variant}/{index + 1}: core/tail pixels disappeared")
                require(
                    all(frame.getpixel(point) == base.getpixel(point) for point in base_mask),
                    f"{side}/{variant}/{index + 1}: body or complete tail changed",
                )
                frame_components = components(frame_mask)
                require(base_mask in frame_components, f"{side}/{variant}/{index + 1}: core/tail component broke")
                for point in frame_mask - base_mask:
                    distance = min(max(abs(point[0] - bx), abs(point[1] - by)) for bx, by in base_mask)
                    require(distance >= 2, f"{side}/{variant}/{index + 1}: free charge touches body/tail")

        for index in range(FRAME_COUNT):
            require(
                normal[index].getchannel("A").tobytes()
                == shiny[index].getchannel("A").tobytes()
                == grayscale[index].getchannel("A").tobytes(),
                f"{side}/{index + 1}: frame masks differ across variants",
            )
        for first_index, first in enumerate(normal):
            for second in normal[first_index + 1:]:
                require(not pure_translation(first, second), f"{side}: charge cadence is image translation")

        for frame in normal:
            for red, green, blue, alpha in frame.getdata():
                if alpha:
                    require(not (blue >= 120 and green >= 120 and blue > red),
                            f"{side}/normal: cyan/light-blue is forbidden")

        for variant, suffix in (("normal", ""), ("shiny", "_shiny")):
            static = rgba(ROOT / f"assets/crystal/gorochu_{side}{suffix}.png")
            require(static.tobytes() == by_variant[variant][0].tobytes(),
                    f"{side}/{variant}: static differs from frame 001")

print(f"GOROCHU CONNECTED-TAIL 64PX MATRIX PASS: {checks} checks")
