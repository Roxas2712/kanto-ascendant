#!/usr/bin/env python3
"""Author local, integer-pixel motion loops for the three Hoenn Mega masters.

The four supplied masters per form remain the untouched Voxel source.  This
tool makes a separate, documented fan-project animation derivative for the
Crystal 2D path.  It never mirrors a view, interpolates a pixel, or reuses a
byte-identical frame: every front/back normal/shiny key is independently
derived from that view's own master and checked below.
"""
from __future__ import annotations

import hashlib
import shutil
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
MASTERS = ROOT / "assets" / "mega"
OUT = ROOT / "assets" / "mega_animated"
FORMS = ("mega_blaziken", "mega_swampert", "mega_sceptile")
SIDES = ("front", "back")
VARIANTS = ("normal", "shiny")
FRAME_COUNT = 5

# Five deliberate beats, all integer translations.  Separating crown, torso
# and grounded lower-body bands gives anticipation/strike/recovery posture
# rather than a camera pan.  The two orientations use their own independently
# painted masters; these offsets are never a front-to-back transform.
BEATS = (
    ((0, 0), (0, 0), (0, 0)),       # settled ready pose
    ((0, 1), (-1, 0), (0, 0)),      # compress / anticipate
    ((1, -1), (1, -1), (0, -1)),    # release / strike
    ((-1, 0), (0, 0), (0, 1)),      # recover through the planted foot
    ((0, -1), (1, 0), (0, 0)),      # breathing return, not duplicate idle
)


def opaque_colours(image: Image.Image) -> list[tuple[int, int, int, int]]:
    colours = {
        colour for _, colour in image.convert("RGBA").getcolors(1_000_000) or []
        if colour[3]
    }
    return sorted(colours, key=lambda value: sum(value[:3]))


def band_pose(master: Image.Image, beat: int) -> Image.Image:
    """Compose three independently shifted pose bands on a transparent 96px card."""
    source = master.convert("RGBA")
    out = Image.new("RGBA", source.size, (0, 0, 0, 0))
    width, height = source.size
    bands = ((0, height // 3), (height // 3, height * 2 // 3),
             (height * 2 // 3, height))
    for (top, bottom), (dx, dy) in zip(bands, BEATS[beat]):
        strip = source.crop((0, top, width, bottom))
        out.alpha_composite(strip, (dx, top + dy))
    return out


def accent_points(form: str, side: str, beat: int,
                  box: tuple[int, int, int, int]) -> tuple[tuple[int, int], ...]:
    left, top, right, bottom = box
    if form == "mega_blaziken":
        # Ember trail follows the independently authored flame side of each pose.
        edge = right + 1 if side == "front" else left - 2
        direction = 1 if side == "front" else -1
        return tuple((edge + direction * step, bottom - 16 - (step % 3))
                     for step in range(beat + 1, beat + 4))
    if form == "mega_swampert":
        # Low water kick: a three-pixel crest changes length at each key.
        return tuple((left - 2 + step * 2, bottom - 3 - ((step + beat) % 2))
                     for step in range(beat + 1, beat + 4))
    # Sceptile's leaf/tail swish is a sparse diagonal, preserving HUD space.
    edge = right + 1 if side == "front" else left - 2
    direction = 1 if side == "front" else -1
    return tuple((edge + direction * step, top + 18 + step * 2 + beat % 2)
                 for step in range(beat + 1, beat + 4))


def apply_accents(frame: Image.Image, form: str, side: str, beat: int,
                  colours: list[tuple[int, int, int, int]]) -> Image.Image:
    out = frame.copy()
    box = out.getchannel("A").getbbox()
    if not box:
        raise ValueError(f"{form}/{side}: empty source pose")
    # Highlight + shadow retain the corresponding normal/shiny master palette.
    accent = colours[-2] if len(colours) > 1 else colours[-1]
    shadow = colours[1] if len(colours) > 2 else colours[0]
    draw = ImageDraw.Draw(out)
    for index, (x, y) in enumerate(accent_points(form, side, beat, box)):
        if 0 <= x < out.width and 0 <= y < out.height:
            draw.point((x, y), fill=accent)
            if index % 2 == 0 and y + 1 < out.height:
                draw.point((x, y + 1), fill=shadow)
    return out


def build_variant(form: str, side: str, variant: str) -> list[Path]:
    suffix = "_shiny" if variant == "shiny" else ""
    master_path = MASTERS / f"{form}_{side}{suffix}.png"
    with Image.open(master_path) as source:
        master = source.convert("RGBA")
    if master.size != (96, 96):
        raise ValueError(f"{master_path}: expected 96x96, got {master.size}")
    colours = opaque_colours(master)
    target = OUT / form / side / variant
    target.mkdir(parents=True, exist_ok=True)
    for old in target.glob("*.png"):
        old.unlink()
    frames: list[Path] = []
    for beat in range(FRAME_COUNT):
        frame = apply_accents(band_pose(master, beat), form, side, beat, colours)
        path = target / f"{beat + 1:03d}.png"
        frame.save(path, "PNG", optimize=False)
        frames.append(path)
    hashes = [hashlib.sha256(path.read_bytes()).hexdigest() for path in frames]
    if len(set(hashes)) != FRAME_COUNT:
        raise ValueError(f"{form}/{side}/{variant}: duplicate authored frame")
    return frames


def main() -> None:
    made: list[Path] = []
    for form in FORMS:
        for side in SIDES:
            for variant in VARIANTS:
                made.extend(build_variant(form, side, variant))
    # Leave a self-contained source manifest beside the frame tree.  Hashes
    # make accidental replacement with static placeholder frames detectable.
    lines = ["HOENN MEGA ANIMATION DERIVATIVE MANIFEST", ""]
    for path in sorted(made):
        lines.append(f"{hashlib.sha256(path.read_bytes()).hexdigest()}  {path.relative_to(ROOT)}")
    (OUT / "HOENN_MEGA_DERIVATIVE_SHA256.txt").write_text(
        "\n".join(lines) + "\n", encoding="utf-8")
    print(f"authored {len(made)} Hoenn Mega animation frames")


if __name__ == "__main__":
    main()
