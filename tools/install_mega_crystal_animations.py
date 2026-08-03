#!/usr/bin/env python3
"""Build Crystal-style Mega Charizard X battle art from pixel animations.

Pokémon Showdown's Smogon-community animation already supplies coherent
front/back motion for this form. This tool converts that source into the
constraints used by Kanto Ascendant's bundled Crystal pack:

- 56x56 transparent canvases
- four opaque colors plus transparency
- nearest-neighbour pixels without antialiasing
- reduced, Crystal-like frame cadence
- normal and shiny front animations plus static player backs
"""

from __future__ import annotations

import io
import tempfile
import urllib.request
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
STATIC_DEST = ROOT / "assets" / "mega"
ANIM_DEST = ROOT / "assets" / "mega_animated" / "mega_charizard_x"
DATA_DEST = ROOT / "mega_animation_data.lua"
BASE = (
    "https://raw.githubusercontent.com/PokeAPI/sprites/master/"
    "sprites/pokemon/other/showdown"
)
SOURCES = {
    ("front", "normal"): f"{BASE}/10034.gif",
    ("back", "normal"): f"{BASE}/back/10034.gif",
    ("front", "shiny"): f"{BASE}/shiny/10034.gif",
    ("back", "shiny"): f"{BASE}/back/shiny/10034.gif",
}
PALETTES = {
    "normal": (
        (0, 0, 0, 255),
        (255, 255, 255, 255),
        (48, 72, 120, 255),
        (80, 184, 224, 255),
    ),
    "shiny": (
        (0, 0, 0, 255),
        (255, 255, 255, 255),
        (48, 168, 112, 255),
        (208, 72, 72, 255),
    ),
}
CANVAS = 56
VISIBLE = 54
FRAME_STEP = 4


def fetch(url: str) -> bytes:
    request = urllib.request.Request(
        url,
        headers={"User-Agent": "kanto-ascendant-mega-crystal-builder/1.0"},
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        body = response.read()
    if not body.startswith((b"GIF87a", b"GIF89a")):
        raise ValueError(f"{url} did not return a GIF")
    return body


def gif_frames(body: bytes) -> tuple[list[Image.Image], list[int]]:
    gif = Image.open(io.BytesIO(body))
    frames, durations = [], []
    for index in range(gif.n_frames):
        gif.seek(index)
        frames.append(gif.convert("RGBA").copy())
        durations.append(max(20, int(gif.info.get("duration") or 50)))
    return frames, durations


def union_bounds(frames: list[Image.Image]) -> tuple[int, int, int, int]:
    bounds = [frame.getchannel("A").getbbox() for frame in frames]
    bounds = [box for box in bounds if box]
    if not bounds:
        raise ValueError("animation is completely transparent")
    return (
        min(box[0] for box in bounds),
        min(box[1] for box in bounds),
        max(box[2] for box in bounds),
        max(box[3] for box in bounds),
    )


def crystal_dither(image: Image.Image, variant: str) -> Image.Image:
    """Quantize with Game-Boy-style error diffusion, preserving transparency."""
    alpha = image.getchannel("A")
    palette = Image.new("P", (1, 1))
    flat = []
    for color in PALETTES[variant]:
        flat.extend(color[:3])
    flat.extend([0] * (768 - len(flat)))
    palette.putpalette(flat)
    indexed = image.convert("RGB").quantize(
        palette=palette,
        dither=Image.Dither.FLOYDSTEINBERG,
    )
    output = indexed.convert("RGBA")
    output.putalpha(alpha.point(lambda value: 255 if value >= 128 else 0))
    return output


def crystal_frame(
    frame: Image.Image,
    bounds: tuple[int, int, int, int],
    variant: str,
) -> Image.Image:
    cropped = frame.crop(bounds)
    # Showdown's Mega Charizard canvas is much wider than a Crystal battle
    # slot. A proportional fit left only ~32 visible rows and looked tiny
    # beside Crystal's original Charizard, whose silhouette occupies almost
    # the full 56-pixel height. Crystal sprites routinely compress broad
    # silhouettes into their square tile, so normalize both axes to the
    # 54-pixel drawing area while retaining the source's stable canvas.
    width = VISIBLE
    height = VISIBLE
    resized = cropped.resize((width, height), Image.Resampling.NEAREST)
    resized = crystal_dither(resized, variant)
    canvas = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    canvas.alpha_composite(resized, ((CANVAS - width) // 2, CANVAS - height))
    return canvas


def sampled_frames(
    frames: list[Image.Image],
    durations: list[int],
    variant: str,
) -> tuple[list[Image.Image], list[int]]:
    bounds = union_bounds(frames)
    output, output_durations = [], []
    for start in range(0, len(frames), FRAME_STEP):
        converted = crystal_frame(frames[start], bounds, variant)
        duration = sum(durations[start : start + FRAME_STEP])
        if output and converted.tobytes() == output[-1].tobytes():
            output_durations[-1] += duration
        else:
            output.append(converted)
            output_durations.append(duration)
    return output, output_durations


def write_png(image: Image.Image, target: Path) -> None:
    target.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(
        dir=target.parent, prefix=".mega-frame-", suffix=".png", delete=False
    ) as handle:
        temp = Path(handle.name)
    try:
        image.save(temp, format="PNG", optimize=True)
        temp.replace(target)
    finally:
        temp.unlink(missing_ok=True)


def write_data(timings: dict[str, list[int]]) -> None:
    lines = [
        "-- Generated by tools/install_mega_crystal_animations.py.",
        "-- Durations are milliseconds after Crystal-style frame reduction.",
        "return {",
        '  ["CHARIZARD_X"] = {',
    ]
    for variant in ("normal", "shiny"):
        duration = ", ".join(str(value) for value in timings[variant])
        lines.append(f"    {variant} = {{ {duration} }},")
    lines.extend(("  },", "}", ""))
    DATA_DEST.write_text("\n".join(lines), encoding="utf-8")


def main() -> int:
    timings: dict[str, list[int]] = {}
    converted: dict[tuple[str, str], list[Image.Image]] = {}
    for key, url in SOURCES.items():
        side, variant = key
        source, source_durations = gif_frames(fetch(url))
        frames, durations = sampled_frames(source, source_durations, variant)
        converted[key] = frames
        if side == "front":
            timings[variant] = durations
            target = ANIM_DEST / variant
            target.mkdir(parents=True, exist_ok=True)
            for old in target.glob("*.png"):
                old.unlink()
            for index, frame in enumerate(frames, 1):
                write_png(frame, target / f"{index:03d}.png")
        suffix = "_shiny" if variant == "shiny" else ""
        write_png(
            frames[0],
            STATIC_DEST / f"mega_charizard_x_{side}{suffix}.png",
        )
        print(f"{variant:6} {side:5}: {len(frames)} Crystal-style frames")
    write_data(timings)
    print("installed Mega Charizard X normal/shiny Crystal battle art")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
