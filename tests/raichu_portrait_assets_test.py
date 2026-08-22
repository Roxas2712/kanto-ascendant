#!/usr/bin/env python3
"""Fail closed on clipped/detached Raichu dialogue portraits."""

from collections import deque
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
MOODS = ("sleepy", "unwell", "upset", "wary", "content", "devoted", "excited")
STYLES = (
    "yellow_partner_raichu_portraits",
    "yellow_partner_raichu_classic_portraits",
)
VARIANTS = ("normal", "shiny")


def alpha_components(image: Image.Image):
    alpha = image.getchannel("A")
    opaque = {(x, y) for y in range(40) for x in range(40) if alpha.getpixel((x, y))}
    components = []
    while opaque:
        start = opaque.pop()
        queue = deque([start])
        component = {start}
        while queue:
            x, y = queue.popleft()
            for point in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                if point in opaque:
                    opaque.remove(point)
                    component.add(point)
                    queue.append(point)
        components.append(component)
    return components


checked = 0
for style in STYLES:
    for variant in VARIANTS:
        for mood in MOODS:
            for frame in range(1, 4):
                path = ROOT / "assets" / style / variant / mood / f"{frame:03}.png"
                assert path.is_file(), f"missing portrait: {path}"
                image = Image.open(path).convert("RGBA")
                assert image.size == (40, 40), f"wrong canvas: {path} {image.size}"
                assert image.getbbox(), f"empty portrait: {path}"
                components = alpha_components(image)
                edge_fragments = [
                    component
                    for component in components
                    if any(x in (0, 39) for x, _ in component) and len(component) < 40
                ]
                assert not edge_fragments, f"detached edge fragment: {path}"
                if style == "yellow_partner_raichu_portraits" and frame == 1:
                    alpha = image.getchannel("A")
                    assert not any(alpha.getpixel((0, y)) for y in range(40)), path
                    assert not any(alpha.getpixel((39, y)) for y in range(40)), path
                if style.endswith("classic_portraits"):
                    pixels = (
                        image.get_flattened_data()
                        if hasattr(image, "get_flattened_data")
                        else image.getdata()
                    )
                    colors = {
                        pixel[:3] for pixel in pixels if pixel[3]
                    }
                    assert len(colors) <= 5, f"classic fringe colors leaked: {path}"
                    assert min(map(len, components)) >= 3, f"classic speck leaked: {path}"
                checked += 1

assert checked == 84, checked
print("raichu portrait assets: 84/84 clean and packaged PASS")
