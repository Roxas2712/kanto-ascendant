#!/usr/bin/env python3
"""Build the secret Ascendant Typhlosion battle-sprite review pack.

The accepted armored front concept is translated through a controlled crop,
palette reduction and binary-alpha pass. The rear view starts from a sharp
96x96 master and continues the same volcanic armor language. All animation
compositing remains deterministic and uses integer pixel coordinates.
"""

from __future__ import annotations

import argparse
import math
import shutil
from collections import Counter
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parents[1]
REVIEW = ROOT / "art_review" / "ascendant_typhlosion_v1"
REFERENCE = REVIEW / "reference"
SPRITES = REVIEW / "sprites"
ANIMATIONS = REVIEW / "animations"
FRAMES = REVIEW / "animation_frames"
CRYSTAL = ROOT / "assets" / "crystal_animated" / "front"
APPROVED_CONCEPT = (
    ROOT / "art_review" / "ascendant_typhlosion_v2"
    / "imagegen_armored_alpha.png"
)

# Manual body-selection polygon for the accepted full-resolution front
# concept. It excludes the large cyan eruption while retaining the connected
# armor, head, hands, feet and volcanic spine.
CONCEPT_BODY_POLYGON = (
    (340, 430), (440, 375), (610, 405), (690, 485),
    (760, 500), (820, 525), (875, 500), (930, 560),
    (950, 650), (1035, 700), (1015, 1130), (860, 1190),
    (700, 1110), (550, 1180), (380, 1140), (365, 1010),
    (415, 875), (350, 790), (380, 705), (330, 615),
)

CRYSTAL_TIMINGS = (
    20, 150, 50, 100, 100, 50, 50, 100, 100, 100, 50, 50,
    100, 50, 100, 50, 50, 100, 450, 50, 200, 100, 990,
)

VIEWS = ("front", "back", "front_shiny", "back_shiny")

# The authentic 23-frame Crystal rhythm now drives a complete eruption:
# quiet mantle -> pressure build -> full burst -> falling embers -> rest.
FRONT_ERUPTION = (
    0, 0, 1, 1, 2, 2, 3, 4, 5, 5, 4, 5,
    4, 3, 2, 4, 3, 2, 1, 2, 2, 1, 0,
)
BACK_ERUPTION = (0, 1, 2, 3, 5, 4, 3, 2, 1, 0, 0, 0)

NORMAL_BODY = {
    (255, 238, 148): (255, 238, 148),
    (213, 197, 115): (213, 197, 115),
    (164, 139, 74): (164, 139, 74),
    (106, 82, 41): (106, 82, 41),
}
SHINY_BODY = {
    (246, 222, 131): (222, 231, 232),
    (205, 180, 98): (169, 187, 191),
    (156, 123, 57): (113, 137, 144),
    (98, 74, 24): (67, 85, 93),
}

BASE_DARK = {
    (8, 32, 90),
    (32, 65, 106),
    (65, 90, 148),
    (90, 123, 189),
    (90, 0, 24),
    (131, 32, 65),
    (172, 74, 90),
    (213, 115, 139),
}
BASE_FIRE = {
    (222, 0, 0),
    (255, 98, 0),
    (255, 156, 0),
    (255, 222, 0),
}

PALETTES = {
    False: {
        "outline": (13, 16, 20, 255),
        "deep": (25, 31, 37, 255),
        "mid": (45, 54, 62, 255),
        "light": (72, 83, 91, 255),
        "crack": (255, 91, 0, 255),
        "crack_hi": (255, 181, 20, 255),
        "flame_outline": (0, 77, 132, 255),
        "flame_outer": (0, 157, 230, 255),
        "flame_mid": (54, 225, 255, 255),
        "flame_white": (239, 255, 253, 255),
        "flame_core": (255, 100, 0, 255),
        "flame_hot": (255, 203, 24, 255),
    },
    True: {
        "outline": (17, 13, 31, 255),
        "deep": (35, 27, 67, 255),
        "mid": (67, 48, 112, 255),
        "light": (104, 79, 151, 255),
        "crack": (255, 164, 0, 255),
        "crack_hi": (255, 230, 94, 255),
        "flame_outline": (52, 24, 123, 255),
        "flame_outer": (111, 61, 224, 255),
        "flame_mid": (190, 126, 255, 255),
        "flame_white": (255, 245, 255, 255),
        "flame_core": (0, 204, 230, 255),
        "flame_hot": (126, 255, 246, 255),
    },
}


def font(size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    for candidate in (
        "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
    ):
        try:
            return ImageFont.truetype(candidate, size)
        except OSError:
            pass
    return ImageFont.load_default()


def recolor_base(source: Image.Image, shiny: bool) -> Image.Image:
    palette = PALETTES[shiny]
    body_map = SHINY_BODY if shiny else NORMAL_BODY
    out = source.convert("RGBA")
    pixels = out.load()
    for y in range(out.height):
        for x in range(out.width):
            red, green, blue, alpha = pixels[x, y]
            if not alpha:
                continue
            rgb = (red, green, blue)
            if rgb in body_map:
                mapped = body_map[rgb]
                pixels[x, y] = (*mapped, 255)
            elif rgb in BASE_DARK:
                luminance = red + green + blue
                color = (
                    palette["light"] if luminance > 330
                    else palette["mid"] if luminance > 190
                    else palette["deep"] if luminance > 90
                    else palette["outline"]
                )
                pixels[x, y] = color
            elif rgb in BASE_FIRE:
                if rgb == (222, 0, 0):
                    color = palette["flame_outline"]
                elif rgb == (255, 98, 0):
                    color = palette["flame_outer"]
                elif rgb == (255, 156, 0):
                    color = palette["flame_mid"]
                else:
                    color = palette["flame_white"]
                pixels[x, y] = color
    return out


def plate(
    draw: ImageDraw.ImageDraw,
    points: list[tuple[int, int]],
    palette: dict[str, tuple[int, int, int, int]],
    crack: list[tuple[int, int]] | None = None,
) -> None:
    draw.polygon(points, fill=palette["outline"])
    # Pull a smaller hard-edged facet toward the polygon's centroid.
    cx = sum(x for x, _ in points) // len(points)
    cy = sum(y for _, y in points) // len(points)
    inset = []
    for x, y in points:
        dx = 1 if x < cx else (-1 if x > cx else 0)
        dy = 1 if y < cy else (-1 if y > cy else 0)
        inset.append((x + dx, y + dy))
    draw.polygon(inset, fill=palette["deep"])
    if len(inset) >= 3:
        draw.line((inset[0], inset[1], inset[2]), fill=palette["mid"], width=1)
    if crack and len(crack) > 1:
        draw.line(crack, fill=palette["crack"], width=1)
        draw.point(crack[len(crack) // 2], fill=palette["crack_hi"])


def add_front_details(image: Image.Image, shiny: bool) -> None:
    p = PALETTES[shiny]
    draw = ImageDraw.Draw(image)

    # Five volcanic dorsal plates. Their bases overlap the original back so
    # the additions read as anatomy rather than detached decorations.
    plates = (
        ([(60, 35), (67, 27), (70, 39), (65, 43)], [(64, 37), (67, 34), (67, 39)]),
        ([(65, 43), (74, 36), (74, 49), (68, 52)], [(69, 47), (72, 43), (72, 48)]),
        ([(68, 51), (80, 47), (76, 59), (70, 61)], [(72, 56), (76, 52), (74, 58)]),
        ([(71, 60), (83, 59), (78, 69), (72, 70)], [(74, 66), (78, 63), (76, 68)]),
        ([(72, 69), (83, 72), (76, 78), (70, 76)], [(74, 74), (78, 73)]),
    )
    for points, crack in plates:
        plate(draw, points, p, crack)

    # Head ridge and magma seam, still following the unmistakable snout.
    draw.line([(24, 30), (31, 25), (40, 23), (48, 25), (54, 28)],
              fill=p["light"], width=1)
    draw.line([(31, 29), (37, 27), (42, 29), (48, 28)],
              fill=p["crack"], width=1)

    # Fitted battle armor based on the approved full concept. Every piece
    # overlaps the original body/limb by several pixels, so it reads as worn
    # armor instead of floating shards. The broad shoulder pieces join in a
    # low open V like the concept's obsidian chest mantle, while the cream
    # belly, hands and feet remain readable at native 96x96.
    armor = (
        (
            [(29, 40), (36, 37), (43, 40), (46, 46),
             (43, 52), (38, 55), (33, 50), (29, 47)],
            [(33, 47), (37, 42), (42, 48), (39, 52)],
        ),
        (
            [(45, 43), (50, 38), (58, 39), (63, 44),
             (60, 50), (55, 52), (50, 56), (45, 52)],
            [(49, 49), (52, 43), (58, 47), (54, 51)],
        ),
        (
            [(25, 50), (30, 48), (34, 52), (33, 58), (29, 62), (25, 59)],
            [(28, 57), (31, 53), (32, 58)],
        ),
        (
            [(53, 49), (58, 49), (62, 54), (60, 60), (56, 62), (53, 57)],
            [(56, 57), (59, 53), (59, 58)],
        ),
        (
            [(24, 74), (31, 72), (38, 76), (37, 81), (32, 83), (25, 80)],
            [(28, 79), (32, 75), (35, 80)],
        ),
        (
            [(57, 74), (64, 72), (70, 77), (68, 82), (63, 83), (57, 79)],
            [(60, 79), (64, 75), (67, 80)],
        ),
    )
    for points, crack in armor:
        plate(draw, points, p, crack)

    # The outlined V is the lower edge of the connected chest mantle. It
    # deliberately stops above the stomach to preserve the iconic body shape.
    draw.line([(35, 49), (44, 59), (53, 49)],
              fill=p["outline"], width=4)
    draw.line([(36, 49), (44, 57), (52, 49)],
              fill=p["crack"], width=1)


def add_back_details(image: Image.Image, shiny: bool) -> None:
    p = PALETTES[shiny]
    draw = ImageDraw.Draw(image)

    # The back view reveals the full volcanic spine.
    plates = (
        ([(42, 29), (47, 20), (51, 31), (48, 38), (42, 37)], [(46, 34), (47, 28), (49, 33)]),
        ([(38, 38), (44, 29), (48, 41), (45, 48), (38, 47)], [(42, 43), (44, 36), (46, 42)]),
        ([(34, 47), (40, 38), (44, 50), (41, 57), (34, 56)], [(38, 52), (40, 45), (42, 51)]),
        ([(30, 56), (36, 48), (40, 59), (36, 66), (29, 64)], [(33, 61), (36, 55), (37, 61)]),
        ([(26, 65), (32, 57), (36, 68), (31, 74), (24, 72)], [(29, 69), (32, 63), (33, 69)]),
    )
    for points, crack in plates:
        plate(draw, points, p, crack)

    # Subtle shoulder fissures prevent the large back mass from looking flat.
    draw.line([(48, 44), (53, 47), (52, 52), (58, 55)],
              fill=p["crack"], width=1)
    draw.line([(37, 66), (43, 68), (45, 73)],
              fill=p["crack_hi"], width=1)

    # The recolored rear body is already the connected obsidian mantle. Do not
    # stack extra geometric pads over its arms or feet: that was the source of
    # the broken black diamonds in the rejected revision.


def quantize_with_alpha(image: Image.Image, colors: int = 20) -> Image.Image:
    """Reduce a true-color concept to a crisp, transparent sprite palette."""
    rgba = sanitize_alpha(image)
    alpha = rgba.getchannel("A")
    rgb = Image.new("RGB", rgba.size, (0, 0, 0))
    rgb.paste(rgba.convert("RGB"), mask=alpha)
    quantized = rgb.quantize(
        colors=colors,
        method=Image.Quantize.MEDIANCUT,
        dither=Image.Dither.NONE,
    ).convert("RGBA")
    quantized.putalpha(alpha)
    return sanitize_alpha(quantized)


def concept_front_body(shiny: bool) -> Image.Image:
    """Translate the accepted large concept directly into a 96px master.

    The previous hand-added chest polygons obscured the original arms. This
    path keeps the approved concept's own connected anatomy and armor, removes
    only its background eruption, then performs one controlled downsample.
    """
    source = Image.open(APPROVED_CONCEPT).convert("RGBA")
    selection = Image.new("L", source.size, 0)
    ImageDraw.Draw(selection).polygon(CONCEPT_BODY_POLYGON, fill=255)

    cyan = Image.new("L", source.size, 0)
    cyan_pixels = cyan.load()
    source_pixels = source.load()
    for y in range(source.height):
        for x in range(source.width):
            red, green, blue, alpha = source_pixels[x, y]
            if (
                alpha
                and blue > 120
                and green > 80
                and blue > red * 1.18
            ):
                cyan_pixels[x, y] = 255

    # Remove the cyan rays and their adjacent white-hot cores, but preserve
    # isolated pale details such as claws, teeth and the cream body.
    cyan_neighbourhood = cyan.filter(ImageFilter.MaxFilter(25))
    selected = selection.load()
    hot = cyan_neighbourhood.load()
    for y in range(source.height):
        for x in range(source.width):
            red, green, blue, alpha = source_pixels[x, y]
            near_white_core = (
                red > 205 and green > 220 and blue > 220 and hot[x, y]
            )
            if cyan_pixels[x, y] or near_white_core or not alpha:
                selected[x, y] = 0

    body = Image.new("RGBA", source.size, (0, 0, 0, 0))
    body.paste(source, (0, 0), selection)
    bounds = body.getbbox()
    if not bounds:
        raise ValueError("approved Ascendant Typhlosion concept is empty")
    reduced = body.crop(bounds)
    reduced.thumbnail((82, 88), Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (96, 96), (0, 0, 0, 0))
    canvas.alpha_composite(
        reduced, ((96 - reduced.width) // 2, 96 - reduced.height))
    canvas = quantize_with_alpha(canvas)

    if shiny:
        pixels = canvas.load()
        p = PALETTES[True]
        for y in range(canvas.height):
            for x in range(canvas.width):
                red, green, blue, alpha = pixels[x, y]
                if not alpha:
                    continue
                if green > 55 and red / max(1, green) < 1.36:
                    luminance = (red * 3 + green * 5 + blue * 2) // 10
                    pixels[x, y] = (
                        min(231, 112 + luminance // 2),
                        min(238, 126 + luminance // 2),
                        min(242, 136 + luminance // 2),
                        255,
                    )
                elif red > 90 and red / max(1, green) >= 1.36:
                    pixels[x, y] = (
                        p["crack_hi"] if green > 105 else p["crack"])
                else:
                    luminance = red + green + blue
                    pixels[x, y] = (
                        p["light"] if luminance > 135
                        else p["mid"] if luminance > 75
                        else p["deep"] if luminance > 30
                        else p["outline"]
                    )

    # The accepted artwork shows a living cyan mantle. Strength one restores a
    # small calm flame behind the body; later animation frames expand it.
    return eruptive_frame(
        sanitize_alpha(canvas), shiny, "front", strength=1, phase=0)


def sanitize_alpha(image: Image.Image) -> Image.Image:
    out = image.convert("RGBA")
    pixels = out.load()
    for y in range(out.height):
        for x in range(out.width):
            red, green, blue, alpha = pixels[x, y]
            pixels[x, y] = (red, green, blue, 255 if alpha else 0)
    return out


def build_sprite(view: str) -> Image.Image:
    shiny = view.endswith("_shiny")
    side = "back" if view.startswith("back") else "front"
    if side == "front":
        return concept_front_body(shiny)
    source = Image.open(REFERENCE / f"typhlosion_{view}.png")
    image = recolor_base(source, shiny)
    add_back_details(image, shiny)
    return sanitize_alpha(image)


def shimmer_frame(image: Image.Image, shiny: bool, phase: int) -> Image.Image:
    """Animate only selected flame pixels; body position never changes."""
    p = PALETTES[shiny]
    out = image.copy()
    pixels = out.load()
    swaps = {
        p["flame_outer"][:3]: p["flame_mid"],
        p["flame_mid"][:3]: p["flame_white"],
        p["flame_white"][:3]: p["flame_mid"],
    }
    for y in range(out.height):
        for x in range(out.width):
            red, green, blue, alpha = pixels[x, y]
            replacement = swaps.get((red, green, blue))
            if alpha and replacement and (x + y + phase) % 5 == 0:
                pixels[x, y] = replacement
    return sanitize_alpha(out)


def flame_spike(
    draw: ImageDraw.ImageDraw,
    base: tuple[int, int],
    peak: tuple[int, int],
    width: int,
    palette: dict[str, tuple[int, int, int, int]],
    phase: int,
) -> None:
    """Draw one hard-edged, layered pixel flame without antialiasing."""
    bx, by = base
    px, py = peak
    dx, dy = px - bx, py - by
    length = max(1.0, math.hypot(dx, dy))
    nx, ny = -dy / length, dx / length

    def point(x: float, y: float) -> tuple[int, int]:
        return round(x), round(y)

    outer = [
        point(bx + nx * width, by + ny * width),
        point(px - dx * 0.20 + nx * max(1, width - 1),
              py - dy * 0.20 + ny * max(1, width - 1)),
        (px, py),
        point(px - dx * 0.32 - nx * max(1, width - 1),
              py - dy * 0.32 - ny * max(1, width - 1)),
        point(bx - nx * width, by - ny * width),
    ]
    draw.polygon(outer, fill=palette["flame_outline"])

    inner_peak = point(px - dx * 0.10, py - dy * 0.10)
    inner = [
        point(bx + nx * max(1, width - 2), by + ny * max(1, width - 2)),
        inner_peak,
        point(bx - nx * max(1, width - 2), by - ny * max(1, width - 2)),
    ]
    draw.polygon(inner, fill=palette["flame_outer"])
    hot_peak = point(px - dx * (0.34 + 0.03 * (phase % 3)),
                     py - dy * (0.34 + 0.03 * (phase % 3)))
    hot = [
        point(bx + nx, by + ny),
        hot_peak,
        point(bx - nx, by - ny),
    ]
    draw.polygon(hot, fill=palette["flame_mid"])
    draw.line((base, point(
        px - dx * 0.48, py - dy * 0.48)),
        fill=palette["flame_white"], width=1)


def eruptive_frame(
    master: Image.Image,
    shiny: bool,
    side: str,
    strength: int,
    phase: int,
) -> Image.Image:
    """Place an expanding volcanic burst behind an intact body silhouette."""
    if strength <= 0:
        return sanitize_alpha(master.copy())
    p = PALETTES[shiny]
    layer = Image.new("RGBA", (96, 96), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    origin = (49, 34) if side == "front" else (43, 34)
    front_peaks = (
        (39, 8), (49, 1), (59, 10), (70, 4), (76, 18),
        (88, 14), (83, 31), (23, 6), (11, 18), (5, 34),
        (28, 20), (65, 25),
    )
    back_peaks = (
        (34, 7), (44, 1), (55, 8), (66, 4), (76, 18),
        (86, 28), (18, 9), (8, 23), (4, 38), (26, 24),
    )
    peaks = front_peaks if side == "front" else back_peaks
    reach = 0.23 + strength * 0.15
    count = min(len(peaks), 3 + strength * 2)
    for index, target in enumerate(peaks[:count]):
        bx = origin[0] + ((index % 3) - 1) * 5
        by = origin[1] + (index % 2) * 3
        tx = round(bx + (target[0] - bx) * reach)
        ty = round(by + (target[1] - by) * reach)
        flame_spike(
            draw, (bx, by), (tx, ty),
            3 + (1 if strength >= 3 else 0)
            + (1 if strength >= 5 and index % 2 == 0 else 0),
            p, phase,
        )

    # Orange pressure core: visible around the collar but behind head/body.
    core = 2 + strength
    draw.polygon([
        (origin[0] - core, origin[1] + 2),
        (origin[0] - 2, origin[1] - core),
        (origin[0] + 1, origin[1] - 1),
        (origin[0] + core, origin[1] - core + 1),
        (origin[0] + core - 1, origin[1] + 3),
    ], fill=p["flame_core"])
    draw.line([
        (origin[0] - 1, origin[1] + 1),
        (origin[0], origin[1] - core + 1),
        (origin[0] + 2, origin[1] + 1),
    ], fill=p["flame_hot"], width=1)

    out = layer
    out.alpha_composite(master)
    pixels = out.load()
    ember_positions = (
        (12, 12), (81, 9), (91, 43), (15, 48),
        (73, 35), (29, 3), (87, 61), (4, 55),
    )
    ember_count = max(0, strength - 2)
    for index in range(ember_count):
        ex, ey = ember_positions[(phase + index * 2) % len(ember_positions)]
        ex += (phase * 3 + index) % 5 - 2
        ey += (phase + index * 3) % 4
        if 0 <= ex < 96 and 0 <= ey < 96 and pixels[ex, ey][3] == 0:
            pixels[ex, ey] = (
                p["flame_hot"] if index % 2 else p["flame_core"])
            if ex + 1 < 96 and pixels[ex + 1, ey][3] == 0:
                pixels[ex + 1, ey] = p["flame_hot"]
    return sanitize_alpha(out)


def crystal_fire_mask(source: Image.Image, shiny: bool) -> Image.Image:
    """Extract Crystal Typhlosion's changing upper flame silhouette."""
    rgba = source.convert("RGBA")
    mask = Image.new("L", rgba.size, 0)
    src, dst = rgba.load(), mask.load()
    for y in range(min(25, rgba.height)):
        for x in range(rgba.width):
            red, green, blue, alpha = src[x, y]
            if not alpha:
                continue
            fire = (
                red > 120 and blue > 75 and green < 90
                if shiny
                else red > 170 and green < 120 and blue < 100
            )
            if fire:
                dst[x, y] = 255
    return mask.resize((56, 32), Image.Resampling.NEAREST)


def crystal_front_frame(
    master: Image.Image,
    source: Image.Image,
    shiny: bool,
    phase: int,
) -> Image.Image:
    """Merge the approved form with a real Crystal animation frame.

    The body, armor, dorsal plates and approved sharp flame silhouette remain
    intact. Crystal's changing fire mask drives the white-hot flow inside that
    silhouette, preserving the custom form instead of shrinking a 56px frame.
    """
    p = PALETTES[shiny]
    out = master.copy().convert("RGBA")
    pixels = out.load()
    flame_colors = {
        p["flame_outline"][:3], p["flame_outer"][:3],
        p["flame_mid"][:3], p["flame_white"][:3],
        p["flame_core"][:3], p["flame_hot"][:3],
    }
    mask = crystal_fire_mask(source, shiny)
    for y in range(10, 39):
        for x in range(26, 70):
            red, green, blue, alpha = pixels[x, y]
            if not alpha or (red, green, blue) not in flame_colors:
                continue
            if (red, green, blue) == p["flame_outline"][:3]:
                continue
            sx = max(0, min(55, round((x - 26) * 55 / 43)))
            sy = max(0, min(31, round((y - 10) * 31 / 28)))
            active = mask.getpixel((sx, sy)) > 0
            if y > 31 and active and (x + phase) % 4 == 0:
                pixels[x, y] = p["flame_hot"]
            elif active:
                pixels[x, y] = (
                    p["flame_white"] if (x + y + phase) % 3
                    else p["flame_mid"]
                )
            else:
                pixels[x, y] = (
                    p["flame_mid"] if (x * 2 + y + phase) % 5
                    else p["flame_outer"]
                )

    # Crystal also controls two one-pixel embers; their changing positions
    # make the source motion visible without damaging the approved outline.
    hot_points = [
        (31 + ((phase * 3) % 7), 15 + (phase % 3)),
        (61 - ((phase * 2) % 6), 25 - (phase % 2)),
    ]
    for x, y in hot_points:
        if out.getpixel((x, y))[3] == 0:
            pixels[x, y] = p["flame_outer"]
    return eruptive_frame(
        sanitize_alpha(out), shiny, "front", FRONT_ERUPTION[phase], phase)


def crystal_front_frames(master: Image.Image, shiny: bool) -> list[Image.Image]:
    variant = "shiny" if shiny else "normal"
    paths = sorted((CRYSTAL / variant / "157").glob("*.png"))
    if len(paths) != len(CRYSTAL_TIMINGS):
        raise ValueError(
            f"Crystal Typhlosion needs {len(CRYSTAL_TIMINGS)} frames, "
            f"found {len(paths)}"
        )
    return [
        crystal_front_frame(master, Image.open(path), shiny, index)
        for index, path in enumerate(paths)
    ]


def breathing_back_frames(master: Image.Image, shiny: bool) -> list[Image.Image]:
    frames = []
    for phase, strength in enumerate(BACK_ERUPTION):
        shimmer = shimmer_frame(master, shiny, phase)
        frames.append(eruptive_frame(
            shimmer, shiny, "back", strength, phase))
    return frames


def checker(size: tuple[int, int], square: int = 12) -> Image.Image:
    out = Image.new("RGBA", size, (233, 237, 242, 255))
    draw = ImageDraw.Draw(out)
    for y in range(0, size[1], square):
        for x in range(0, size[0], square):
            if (x // square + y // square) % 2:
                draw.rectangle((x, y, x + square - 1, y + square - 1),
                               fill=(205, 212, 221, 255))
    return out


def make_contact_sheet(images: dict[str, Image.Image]) -> None:
    canvas = Image.new("RGB", (1280, 720), (18, 22, 29))
    draw = ImageDraw.Draw(canvas)
    title = font(38)
    label = font(24)
    small = font(16)
    draw.text((42, 28), "ASCENDANT TYPHLOSION — SECRET FORM REVIEW",
              fill=(244, 248, 252), font=title)
    draw.text((44, 78),
              "Concept-derived 96x96 masters • binary alpha • nearest-neighbor preview",
              fill=(133, 207, 224), font=small)
    positions = {
        "front": (32, 120),
        "back": (344, 120),
        "front_shiny": (656, 120),
        "back_shiny": (968, 120),
    }
    names = {
        "front": "FRONT • NORMAL",
        "back": "BACK • NORMAL",
        "front_shiny": "FRONT • SHINY",
        "back_shiny": "BACK • SHINY",
    }
    for view, (x, y) in positions.items():
        draw.rounded_rectangle((x, y, x + 280, y + 468), radius=16,
                               fill=(34, 41, 52), outline=(73, 88, 108),
                               width=2)
        bg = checker((280, 360), 16)
        bounds = images[view].getchannel("A").getbbox()
        if bounds:
            cropped = images[view].crop(bounds)
            scale = min(264 / cropped.width, 328 / cropped.height)
            preview = cropped.resize(
                (
                    max(1, round(cropped.width * scale)),
                    max(1, round(cropped.height * scale)),
                ),
                Image.Resampling.NEAREST,
            )
            bg.alpha_composite(
                preview,
                ((280 - preview.width) // 2, (344 - preview.height) // 2),
            )
        canvas.paste(bg.convert("RGB"), (x, y + 48))
        draw.text((x + 16, y + 14), names[view],
                  fill=(255, 255, 255), font=label)
        inset = checker((104, 104), 8)
        inset.alpha_composite(images[view], (4, 4))
        canvas.paste(inset.convert("RGB"), (x + 88, y + 352))
        draw.rectangle((x + 88, y + 352, x + 192, y + 456),
                       outline=(12, 15, 20), width=2)
        draw.text((x + 98, y + 430), "96×96", fill=(20, 25, 32), font=small)
    draw.rounded_rectangle((32, 606, 1248, 692), radius=13,
                           fill=(27, 33, 43), outline=(69, 85, 106), width=2)
    draw.text((52, 618),
              "NORMAL  obsidian armor • cyan-white mantle • magma seams",
              fill=(70, 226, 255), font=small)
    draw.text((52, 654),
              "SHINY   indigo armor • violet-white mantle • gold seams",
              fill=(217, 154, 255), font=small)
    canvas.save(REVIEW / "01_battle_sprite_review.png", optimize=True)


def make_silhouette_sheet(images: dict[str, Image.Image]) -> None:
    canvas = Image.new("RGB", (800, 400), (242, 244, 247))
    draw = ImageDraw.Draw(canvas)
    draw.text((28, 18), "NATIVE-SIZE SILHOUETTE / VOXEL READABILITY",
              fill=(20, 24, 30), font=font(28))
    for index, view in enumerate(VIEWS):
        source = images[view]
        mask = source.getchannel("A")
        black = Image.new("RGBA", source.size, (9, 12, 16, 255))
        black.putalpha(mask)
        x = 50 + index * 190
        enlarged = black.resize((288, 288), Image.Resampling.NEAREST)
        canvas.paste(enlarged, (x - 48, 66), enlarged)
        canvas.paste(black, (x + 48, 280), black)
    canvas.save(REVIEW / "02_silhouette_readability.png", optimize=True)


def write_qa(images: dict[str, Image.Image]) -> None:
    lines = [
        "ASCENDANT TYPHLOSION SPRITE QA",
        "================================",
    ]
    issues: list[str] = []
    for view, image in images.items():
        alpha = Counter(image.getchannel("A").getdata())
        colors = len({pixel for pixel in image.getdata() if pixel[3]})
        bbox = image.getbbox()
        binary = set(alpha).issubset({0, 255})
        lines.append(
            f"{view}: {image.width}x{image.height}; "
            f"{colors} visible colors; bbox={bbox}; binary_alpha={binary}"
        )
        if image.size != (96, 96):
            issues.append(f"{view}: wrong dimensions")
        if not binary:
            issues.append(f"{view}: non-binary alpha")
        if bbox is None:
            issues.append(f"{view}: empty sprite")
        side = "back" if view.startswith("back") else "front"
        variant = "shiny" if view.endswith("_shiny") else "normal"
        frame_paths = sorted((FRAMES / side / variant).glob("*.png"))
        expected = len(BACK_ERUPTION) if side == "back" else len(FRONT_ERUPTION)
        if len(frame_paths) != expected:
            issues.append(
                f"{view}: {len(frame_paths)} frames, expected {expected}")
        master_box = image.getchannel("A").getbbox()
        master_area = (
            (master_box[2] - master_box[0])
            * (master_box[3] - master_box[1])
            if master_box else 0
        )
        max_area = master_area
        for frame_path in frame_paths:
            frame = Image.open(frame_path).convert("RGBA")
            frame_alpha = set(frame.getchannel("A").getdata())
            frame_box = frame.getchannel("A").getbbox()
            if frame.size != (96, 96):
                issues.append(f"{frame_path.name}: wrong dimensions")
            if frame_alpha - {0, 255}:
                issues.append(f"{frame_path.name}: non-binary alpha")
            if frame_box:
                max_area = max(
                    max_area,
                    (frame_box[2] - frame_box[0])
                    * (frame_box[3] - frame_box[1]),
                )
        lines.append(
            f"{view} animation: {len(frame_paths)} frames; "
            f"master_bbox_area={master_area}; peak_bbox_area={max_area}"
        )
        if max_area <= master_area:
            issues.append(f"{view}: eruption never expands the silhouette")
    lines.extend(("", f"ISSUES: {len(issues)}"))
    lines.extend(issues or ["none"])
    (REVIEW / "QA_REPORT.txt").write_text("\n".join(lines) + "\n")
    if issues:
        raise SystemExit("\n".join(issues))


def install_assets(images: dict[str, Image.Image]) -> None:
    asset_dir = ROOT / "assets" / "mega"
    animation_dir = ROOT / "assets" / "mega_animated" / "ascendant_typhlosion"
    asset_dir.mkdir(parents=True, exist_ok=True)
    animation_dir.mkdir(parents=True, exist_ok=True)
    for view, image in images.items():
        target_view = (
            "back_shiny" if view == "back_shiny"
            else "front_shiny" if view == "front_shiny"
            else view
        )
        image.save(
            asset_dir / f"ascendant_typhlosion_{target_view}.png",
            optimize=True,
        )
        side = "back" if view.startswith("back") else "front"
        variant = "shiny" if view.endswith("_shiny") else "normal"
        source_dir = FRAMES / side / variant
        target_dir = animation_dir / side / variant
        target_dir.mkdir(parents=True, exist_ok=True)
        for old in target_dir.glob("*.png"):
            old.unlink()
        for frame_path in sorted(source_dir.glob("*.png")):
            shutil.copy2(frame_path, target_dir / frame_path.name)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--install",
        action="store_true",
        help="also install the reviewed masters and animation frames into assets/",
    )
    args = parser.parse_args()
    SPRITES.mkdir(parents=True, exist_ok=True)
    ANIMATIONS.mkdir(parents=True, exist_ok=True)
    FRAMES.mkdir(parents=True, exist_ok=True)
    images: dict[str, Image.Image] = {}
    for view in VIEWS:
        image = build_sprite(view)
        images[view] = image
        image.save(SPRITES / f"ascendant_typhlosion_{view}.png", optimize=True)

        shiny = view.endswith("_shiny")
        side = "back" if view.startswith("back") else "front"
        variant = "shiny" if view.endswith("_shiny") else "normal"
        if side == "front":
            frames = crystal_front_frames(image, shiny)
            durations = CRYSTAL_TIMINGS
        else:
            frames = breathing_back_frames(image, shiny)
            durations = (120,) * len(frames)
        frame_dir = FRAMES / side / variant
        frame_dir.mkdir(parents=True, exist_ok=True)
        for old in frame_dir.glob("*.png"):
            old.unlink()
        for index, frame in enumerate(frames, 1):
            frame.save(frame_dir / f"{index:03d}.png", optimize=True)
        frames[0].save(
            ANIMATIONS / f"ascendant_typhlosion_{view}.gif",
            save_all=True,
            append_images=frames[1:],
            duration=durations,
            loop=0,
            disposal=2,
            transparency=0,
            optimize=False,
        )

    make_contact_sheet(images)
    make_silhouette_sheet(images)
    write_qa(images)
    if args.install:
        install_assets(images)
    print(f"Built Ascendant Typhlosion review pack at {REVIEW}")
    if args.install:
        print("Installed approved sprite masters into assets/mega.")


if __name__ == "__main__":
    main()
