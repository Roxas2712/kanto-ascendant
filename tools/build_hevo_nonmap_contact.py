#!/usr/bin/env python3
"""Build labeled review sheets from HEVO non-map LÖVE captures."""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageDraw


def sheet(paths: list[Path], output: Path, columns: int) -> None:
    thumb_w, thumb_h, label_h = 256, 192, 34
    rows = (len(paths) + columns - 1) // columns
    canvas = Image.new("RGB", (columns * thumb_w, rows * (thumb_h + label_h)), "white")
    draw = ImageDraw.Draw(canvas)
    for index, path in enumerate(paths):
        row, column = divmod(index, columns)
        x, y = column * thumb_w, row * (thumb_h + label_h)
        with Image.open(path) as source:
            frame = source.convert("RGB")
            frame.thumbnail((thumb_w, thumb_h), Image.Resampling.NEAREST)
            canvas.paste(frame, (x + (thumb_w - frame.width) // 2, y))
        label = path.stem
        if len(label) > 40:
            label = label[:38] + ".."
        draw.text((x + 4, y + thumb_h + 4), label, fill="black")
    output.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(output, optimize=True)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    captures = sorted(args.source.glob("*.png"))
    groups = {
        "items": [path for path in captures if path.name.startswith("item_")],
        "knowledge": [path for path in captures if path.name.startswith("knowledge_")],
        "post_reload": [path for path in captures if path.name.startswith("post_reload_")],
    }
    for name, paths in groups.items():
        if not paths:
            raise SystemExit(f"no {name} captures in {args.source}")
        sheet(paths, args.output / f"{name}_contact.png", 4 if name == "items" else 2)


if __name__ == "__main__":
    main()
