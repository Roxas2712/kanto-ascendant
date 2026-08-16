#!/usr/bin/env python3
"""Build battle-ready Mega assets from the approved 96px masters.

The masters are later-generation pixel art with more source pixels than the
Gen-I battle card can display. A straight nearest-neighbour reduction drops
whole outline/detail pixels and makes large forms look noisy. Runtime cards
therefore use a palette-locked high-quality reduction: resampling decides
which source colour owns each destination pixel, then every result is snapped
back to the exact authored palette. The output is still hard-edged pixel art
with no translucent or invented colours.
"""

from __future__ import annotations

import argparse
from pathlib import Path
import re

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
STATIC_SOURCE = ROOT / "assets" / "mega"
STATIC_TARGET = ROOT / "assets" / "mega_runtime"
GEN1_TARGET = ROOT / "assets" / "mega_gen1_runtime"
ANIM_SOURCE = ROOT / "assets" / "mega_animated"
ANIM_TARGET = ROOT / "assets" / "mega_animated_runtime"
GEN1_SHADES = (0, 85, 170, 255)
# Mega fronts deliberately occupy a wider card than the ordinary 56px Gen-I
# enemy slot. Player backs deliberately extend beneath the player HUD: the HUD
# is redrawn above active Mega rear art, matching the tilemap-style occlusion
# and allowing the transformed Pokémon to feel substantially larger.
GEOMETRY = {
    "front": {
        "size": (66, 60),
        "content": (64, 56),
        "bottom_margin": 4,
        "left_bias": 1,
    },
    "back": {
        "size": (90, 84),
        "content": (88, 80),
        "bottom_margin": 4,
        "left_bias": 0,
    },
}


def union_alpha_box(sources: list[Path]) -> tuple[int, int, int, int]:
    box: tuple[int, int, int, int] | None = None
    for source in sources:
        with Image.open(source) as image:
            hit = image.convert("RGBA").getchannel("A").getbbox()
        if not hit:
            continue
        if box is None:
            box = hit
        else:
            box = (
                min(box[0], hit[0]),
                min(box[1], hit[1]),
                max(box[2], hit[2]),
                max(box[3], hit[3]),
            )
    return box or (0, 0, 1, 1)


def geometry(
    box: tuple[int, int, int, int],
    side: str,
) -> tuple[int, int, int, int]:
    layout = GEOMETRY[side]
    size = layout["size"]
    content_limit = layout["content"]
    width, height = box[2] - box[0], box[3] - box[1]
    scale = min(content_limit[0] / width, content_limit[1] / height)
    target_width = max(1, round(width * scale))
    target_height = max(1, round(height * scale))
    # Later-generation Mega designs tend to be airier than their compact
    # Gen-I bases. A restrained horizontal boost makes their occupied area
    # read larger while each side's vertical ceiling protects the HUD.
    target_width = min(
        content_limit[0],
        max(target_width, round(target_width * 1.05)),
    )
    # The classic enemy slot begins at x=96 and the 160px screen clips the
    # rightmost two columns of this wider card. Bias left by one so those
    # clipped columns are always transparent rather than authored pixels.
    x = max(
        0,
        (size[0] - target_width) // 2 - int(layout["left_bias"]),
    )
    y = size[1] - int(layout["bottom_margin"]) - target_height
    return x, y, target_width, target_height


def opaque_palette(sources: list[Path]) -> tuple[tuple[int, int, int, int], ...]:
    colors: set[tuple[int, int, int, int]] = set()
    for source in sources:
        with Image.open(source) as image:
            rgba = image.convert("RGBA")
            for _, color in rgba.getcolors(maxcolors=1_000_000) or []:
                if color[3] > 0:
                    colors.add(color)
    return tuple(sorted(colors))


def palette_lock(
    image: Image.Image,
    palette: tuple[tuple[int, int, int, int], ...],
) -> Image.Image:
    """Return opaque authored colours plus fully transparent background."""
    out = Image.new("RGBA", image.size, (0, 0, 0, 0))
    source = image.load()
    target = out.load()
    for y in range(image.height):
        for x in range(image.width):
            pixel = source[x, y]
            # Lanczos creates only a temporary coverage edge. Keep a slightly
            # generous threshold so horns, flames and whiskers survive, then
            # remove the coverage value entirely in the final pixel card.
            if pixel[3] < 96:
                continue
            target[x, y] = min(
                palette,
                key=lambda color: sum(
                    (color[channel] - pixel[channel]) ** 2
                    for channel in range(3)
                ),
            )
    return out


def convert(
    source: Path,
    target: Path,
    box: tuple[int, int, int, int],
    palette: tuple[tuple[int, int, int, int], ...],
    side: str,
) -> None:
    with Image.open(source) as image:
        cropped = image.convert("RGBA").crop(box)
    x, y, width, height = geometry(box, side)
    resized = cropped.resize((width, height), Image.Resampling.LANCZOS)
    resized = palette_lock(resized, palette)
    frame = Image.new("RGBA", GEOMETRY[side]["size"], (0, 0, 0, 0))
    frame.alpha_composite(resized, (x, y))
    target.parent.mkdir(parents=True, exist_ok=True)
    frame.save(target, "PNG", optimize=False)


def gen1_convert(source: Path, target: Path) -> None:
    """Quantize an approved runtime card to the exact four Gen-I shades.

    The engine recolours these values through the active Red, Blue or Yellow
    monster palette at load time. Keeping this derivative static also mirrors
    the original games instead of leaking the Crystal animation setting into
    the fallback presentation.
    """
    with Image.open(source) as image:
        rgba = image.convert("RGBA")
    out = Image.new("RGBA", rgba.size, (0, 0, 0, 0))
    source_pixels = rgba.load()
    target_pixels = out.load()
    for y in range(rgba.height):
        for x in range(rgba.width):
            red, green, blue, alpha = source_pixels[x, y]
            if alpha == 0:
                continue
            # Integer Rec.709 luminance followed by the same canonical DMG
            # levels used by BattleState's palette bake.
            luminance = (54 * red + 183 * green + 19 * blue) // 256
            if luminance >= 218:
                shade = GEN1_SHADES[3]
            elif luminance >= 142:
                shade = GEN1_SHADES[2]
            elif luminance >= 58:
                shade = GEN1_SHADES[1]
            else:
                shade = GEN1_SHADES[0]
            target_pixels[x, y] = (shade, shade, shade, 255)
    target.parent.mkdir(parents=True, exist_ok=True)
    out.save(target, "PNG", optimize=False)


def make_shiny_distinct(normal: Path, shiny: Path) -> None:
    """Give an identical approved shiny source a four-shade Gen-I tell.

    Generation I had no native shiny palettes. If the approved normal and
    shiny rear masters are byte-identical, exchanging the two middle shades
    preserves the outline and highlights while still making the rare variant
    visibly different under every edition palette.
    """
    with Image.open(normal) as normal_image, Image.open(shiny) as shiny_image:
        normal_rgba = normal_image.convert("RGBA")
        shiny_rgba = shiny_image.convert("RGBA")
    if normal_rgba.tobytes() != shiny_rgba.tobytes():
        return
    pixels = shiny_rgba.load()
    for y in range(shiny_rgba.height):
        for x in range(shiny_rgba.width):
            red, green, blue, alpha = pixels[x, y]
            if alpha == 0:
                continue
            if red == 85 and green == 85 and blue == 85:
                pixels[x, y] = (170, 170, 170, 255)
            elif red == 170 and green == 170 and blue == 170:
                pixels[x, y] = (85, 85, 85, 255)
    shiny_rgba.save(shiny, "PNG", optimize=False)


def source_groups() -> dict[tuple[str, str, str], list[Path]]:
    groups: dict[tuple[str, str, str], list[Path]] = {}
    pattern = re.compile(r"(.+)_(front|back)(_shiny)?\.png$")
    for source in sorted(STATIC_SOURCE.glob("*.png")):
        match = pattern.fullmatch(source.name)
        if not match:
            continue
        key = (
            match.group(1),
            match.group(2),
            "shiny" if match.group(3) else "normal",
        )
        groups.setdefault(key, []).append(source)
    for source in sorted(ANIM_SOURCE.rglob("*.png")):
        relative = source.relative_to(ANIM_SOURCE)
        if len(relative.parts) != 4:
            continue
        asset, side, variant, _ = relative.parts
        groups.setdefault((asset, side, variant), []).append(source)
    return groups


def build(only_assets: set[str] | None = None,
          include_static: bool = True) -> tuple[int, int, int]:
    static_count = animation_count = gen1_count = 0
    pattern = re.compile(r"(.+)_(front|back)(_shiny)?\.png$")
    for (asset, side, variant), sources in sorted(source_groups().items()):
        if only_assets and asset not in only_assets:
            continue
        box = union_alpha_box(sources)
        palette = opaque_palette(sources)
        if not palette:
            continue
        static_name = (
            f"{asset}_{side}{'_shiny' if variant == 'shiny' else ''}.png"
        )
        static_source = STATIC_SOURCE / static_name
        if include_static and static_source.is_file():
            runtime_target = STATIC_TARGET / static_name
            convert(
                static_source,
                runtime_target,
                box,
                palette,
                side,
            )
            gen1_convert(runtime_target, GEN1_TARGET / static_name)
            static_count += 1
            gen1_count += 1
        animation_dir = ANIM_SOURCE / asset / side / variant
        for source in sorted(animation_dir.glob("*.png")):
            convert(
                source,
                ANIM_TARGET / asset / side / variant / source.name,
                box,
                palette,
                side,
            )
            animation_count += 1
    for normal in sorted(GEN1_TARGET.glob("*_front.png")):
        shiny = normal.with_name(normal.stem + "_shiny.png")
        if shiny.is_file():
            make_shiny_distinct(normal, shiny)
    for normal in sorted(GEN1_TARGET.glob("*_back.png")):
        shiny = normal.with_name(normal.stem + "_shiny.png")
        if shiny.is_file():
            make_shiny_distinct(normal, shiny)
    return static_count, animation_count, gen1_count


def source_side(source_root: Path, source: Path) -> str | None:
    relative = source.relative_to(source_root)
    if source_root == STATIC_SOURCE:
        match = re.fullmatch(r".+_(front|back)(?:_shiny)?\.png", source.name)
        return match.group(1) if match else None
    return relative.parts[1] if len(relative.parts) >= 2 else None


def check_tree(source_root: Path, target_root: Path,
               only_assets: set[str] | None = None) -> list[str]:
    errors: list[str] = []
    for source in sorted(source_root.rglob("*.png")):
        if source_root == STATIC_SOURCE:
            match = re.fullmatch(r"(.+)_(front|back)(?:_shiny)?\.png", source.name)
            asset = match.group(1) if match else None
        else:
            asset = source.relative_to(source_root).parts[0]
        if only_assets and asset not in only_assets:
            continue
        target = target_root / source.relative_to(source_root)
        if not target.is_file():
            errors.append(f"missing: {target.relative_to(ROOT)}")
            continue
        side = source_side(source_root, source)
        if side not in GEOMETRY:
            errors.append(f"unknown side: {source.relative_to(ROOT)}")
            continue
        size = GEOMETRY[side]["size"]
        content_limit = GEOMETRY[side]["content"]
        with Image.open(target) as image:
            if image.size != size:
                errors.append(
                    f"wrong size {image.size}: {target.relative_to(ROOT)}"
                )
            box = image.convert("RGBA").getchannel("A").getbbox()
            if box:
                width, height = box[2] - box[0], box[3] - box[1]
                if width > content_limit[0] or height > content_limit[1]:
                    errors.append(
                        f"oversized content {width}x{height}: "
                        f"{target.relative_to(ROOT)}"
                    )
    return errors


def check_gen1_tree() -> list[str]:
    errors = check_tree(STATIC_SOURCE, GEN1_TARGET)
    allowed = {
        (shade, shade, shade, 255)
        for shade in GEN1_SHADES
    } | {(0, 0, 0, 0)}
    for target in sorted(GEN1_TARGET.glob("*.png")):
        with Image.open(target) as image:
            rgba = image.convert("RGBA")
            colors = {
                color
                for _, color in rgba.getcolors(maxcolors=1_000_000) or []
            }
        unexpected = colors - allowed
        if unexpected:
            errors.append(
                f"non-Gen-I colors {sorted(unexpected)}: "
                f"{target.relative_to(ROOT)}"
            )
    for side in ("front", "back"):
        for normal in sorted(GEN1_TARGET.glob(f"*_{side}.png")):
            shiny = normal.with_name(normal.stem + "_shiny.png")
            if not shiny.is_file():
                continue
            with Image.open(normal) as normal_image, Image.open(shiny) as shiny_image:
                if (normal_image.convert("RGBA").tobytes()
                        == shiny_image.convert("RGBA").tobytes()):
                    errors.append(
                        f"indistinguishable shiny: {shiny.relative_to(ROOT)}"
                    )
    return errors


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--check", action="store_true", help="verify generated files only"
    )
    parser.add_argument(
        "--asset", action="append", default=[], metavar="ASSET",
        help="limit generation/checking to an asset key (repeatable)"
    )
    parser.add_argument(
        "--animations-only", action="store_true",
        help="do not rewrite static Crystal/Gen-I derivatives"
    )
    args = parser.parse_args()
    selected = set(args.asset) or None

    if args.check:
        errors = check_tree(STATIC_SOURCE, STATIC_TARGET, selected)
        errors += check_tree(ANIM_SOURCE, ANIM_TARGET, selected)
        if not selected:
            errors += check_gen1_tree()
        if errors:
            print("\n".join(errors))
            return 1
        print(
            "Mega runtime assets: Crystal + four-shade Gen-I fronts 66x60, "
            "backs 90x84"
        )
        return 0

    static_count, animation_count, gen1_count = build(
        selected, include_static=not args.animations_only)
    print(
        f"Built {static_count} Crystal static, {animation_count} animated "
        f"and {gen1_count} four-shade Gen-I Mega runtime assets "
        "(fronts 66x60, backs 90x84)"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
