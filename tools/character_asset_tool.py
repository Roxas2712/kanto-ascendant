#!/usr/bin/env python3
"""Safe first stage of the Kanto Ascendant character asset tool.

This command is intentionally read-only with respect to approved and runtime
assets. It validates the reviewed walking masters and can render a nearest-
neighbour QA board. Editing and approval/export belong to a later UI phase.
"""

from __future__ import annotations

import argparse
from hashlib import sha256
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
MASTER_DIR = (ROOT / "assets" / "sources" / "characters" /
              "crystal_chars" / "approved_walk")
RUNTIME_DIR = ROOT / "assets" / "characters" / "crystal_chars"
MANIFEST_PATH = MASTER_DIR / "manifest.json"
DEFAULT_BOARD = MASTER_DIR / "review_board.png"


def digest(path: Path) -> str:
    return sha256(path.read_bytes()).hexdigest()


def load_manifest() -> dict:
    with MANIFEST_PATH.open(encoding="utf-8") as handle:
        manifest = json.load(handle)
    if manifest.get("schema") != "kanto-ascendant.character-walk.v1":
        raise ValueError(f"unsupported manifest schema in {MANIFEST_PATH}")
    return manifest


def validate() -> None:
    manifest = load_manifest()
    expected_size = tuple(manifest["runtime_format"]["sheet_size"])
    frame_size = tuple(manifest["runtime_format"]["frame_size"])
    frame_count = len(manifest["runtime_format"]["frame_order"])
    if expected_size != (frame_size[0], frame_size[1] * frame_count):
        raise AssertionError("manifest sheet/frame geometry is inconsistent")

    checks = 0
    for character, spec in manifest["characters"].items():
        master = MASTER_DIR / spec["file"]
        runtime = RUNTIME_DIR / spec["file"]
        if not master.is_file() or not runtime.is_file():
            raise FileNotFoundError(f"missing master/runtime for {character}")
        if digest(master) != spec["sha256"]:
            raise AssertionError(f"{character}: approved-master hash drift")
        if master.read_bytes() != runtime.read_bytes():
            raise AssertionError(f"{character}: runtime differs from approved master")
        checks += 4

        image = Image.open(master).convert("RGBA")
        if image.size != expected_size:
            raise AssertionError(
                f"{character}: {image.size} != {expected_size}")
        alpha_values = set(image.getchannel("A").getdata())
        if not alpha_values <= {0, 255}:
            raise AssertionError(f"{character}: alpha is not hard-edged")
        checks += 2

        for frame in range(frame_count):
            top = frame * frame_size[1]
            crop = image.crop((0, top, frame_size[0], top + frame_size[1]))
            if crop.getchannel("A").getbbox() is None:
                raise AssertionError(f"{character}: frame {frame} is empty")
            if any(crop.getpixel(point)[3] != 0 for point in (
                    (0, 0), (frame_size[0] - 1, 0),
                    (0, frame_size[1] - 1),
                    (frame_size[0] - 1, frame_size[1] - 1))):
                raise AssertionError(
                    f"{character}: frame {frame} needs transparent corners")
            checks += 2

    fallback = manifest["fallback"]
    fallback_master_dir = MASTER_DIR / fallback["source_directory"]
    fallback_runtime_dir = ROOT / fallback["runtime_directory"]
    for character, expected_hash in fallback["sha256"].items():
        master = fallback_master_dir / f"{character}_walk.png"
        runtime = fallback_runtime_dir / f"{character}_walk.png"
        if not master.is_file() or not runtime.is_file():
            raise FileNotFoundError(f"missing fallback master/runtime for {character}")
        if digest(master) != expected_hash:
            raise AssertionError(f"{character}: fallback hash drift")
        if master.read_bytes() != runtime.read_bytes():
            raise AssertionError(
                f"{character}: runtime fallback differs from source fallback")
        image = Image.open(master).convert("RGBA")
        if image.size != expected_size:
            raise AssertionError(
                f"{character}: fallback {image.size} != {expected_size}")
        if not set(image.getchannel("A").getdata()) <= {0, 255}:
            raise AssertionError(
                f"{character}: fallback alpha is not hard-edged")
        checks += 6

    print(f"CHARACTER ASSET TOOL PASS: {checks} checks")


def font(size: int) -> ImageFont.ImageFont:
    candidates = (
        Path("/System/Library/Fonts/Helvetica.ttc"),
        Path("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"),
    )
    for candidate in candidates:
        if candidate.is_file():
            return ImageFont.truetype(str(candidate), size)
    return ImageFont.load_default()


def checkerboard(size: tuple[int, int], cell: int) -> Image.Image:
    image = Image.new("RGB", size, (250, 250, 250))
    draw = ImageDraw.Draw(image)
    for y in range(0, size[1], cell):
        for x in range(0, size[0], cell):
            if (x // cell + y // cell) % 2:
                draw.rectangle((x, y, x + cell - 1, y + cell - 1),
                               fill=(208, 208, 208))
    return image


def render_board(output: Path) -> None:
    manifest = load_manifest()
    frames = manifest["runtime_format"]["frame_order"]
    characters = tuple(manifest["characters"])
    scale = 12
    tile = 16 * scale
    gap = 18
    left = 118
    top = 52
    row_gap = 48
    width = left + len(frames) * tile + (len(frames) - 1) * gap + 28
    height = top + len(characters) * tile + (len(characters) - 1) * row_gap + 28
    board = Image.new("RGB", (width, height), (238, 238, 238))
    draw = ImageDraw.Draw(board)
    label_font = font(17)
    name_font = font(20)

    for index, label in enumerate(frames):
        x = left + index * (tile + gap)
        draw.text((x, 18), label.replace("_", " ").upper(),
                  fill=(28, 28, 28), font=label_font)

    for row, character in enumerate(characters):
        y = top + row * (tile + row_gap)
        draw.text((22, y + tile // 2 - 12), character.upper(),
                  fill=(28, 28, 28), font=name_font)
        sheet = Image.open(MASTER_DIR / f"{character}_walk.png").convert("RGBA")
        for frame in range(len(frames)):
            x = left + frame * (tile + gap)
            crop = sheet.crop((0, frame * 16, 16, frame * 16 + 16))
            crop = crop.resize((tile, tile), Image.Resampling.NEAREST)
            cell = checkerboard((tile, tile), scale)
            cell.paste(crop, (0, 0), crop)
            board.paste(cell, (x, y))
            draw.rectangle((x, y, x + tile - 1, y + tile - 1),
                           outline=(40, 40, 40), width=2)

    output.parent.mkdir(parents=True, exist_ok=True)
    board.save(output)
    print(output)


def main() -> None:
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest="command", required=True)
    subparsers.add_parser("validate", help="validate approved masters/runtime")
    board_parser = subparsers.add_parser(
        "board", help="render a nearest-neighbour six-frame review board")
    board_parser.add_argument("--output", type=Path, default=DEFAULT_BOARD)
    args = parser.parse_args()
    if args.command == "validate":
        validate()
    else:
        render_board(args.output.resolve())


if __name__ == "__main__":
    main()
