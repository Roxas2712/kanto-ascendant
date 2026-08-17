#!/usr/bin/env python3
"""Build the optional CRYSTAL CHARS runtime sheets from reviewed source boards.

The source boards deliberately stay large and editable. Runtime art is reduced
to the fixed retro grids consumed by gen1recomp: six vertical directional
frames for field sprites, native FRLG-size 64x64 fronts/backs and five-frame
trainer throw sequences.
"""

from __future__ import annotations

from collections import deque
import os
from pathlib import Path
import shutil

from PIL import Image, ImageEnhance, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets" / "sources" / "characters" / "crystal_chars"
CHARACTER_SOURCE = ROOT / "assets" / "sources" / "characters"
OUT = ROOT / "assets" / "characters" / "crystal_chars"
CHARACTERS = ("red", "green", "blue")
GEN1 = SOURCE / "gen1"
APPROVED_WALK = SOURCE / "approved_walk"
FALLBACK_WALK = APPROVED_WALK / "fallback_walk_v1"
FALLBACK_WALK_V2 = APPROVED_WALK / "fallback_walk_v2"
ENGINE_ROOT = Path(os.environ.get(
    "KANTO_GEN1RECOMP",
    str(ROOT.parents[1] / "gen1recomp"),
))
ENGINE_SPRITES = ENGINE_ROOT / "assets" / "generated" / "sprites"

PALETTES = {
    "red": {
        "outline": (24, 21, 25), "skin": (244, 174, 126),
        "skin_shadow": (196, 105, 77), "hair": (45, 34, 33),
        "hair_light": (91, 59, 43), "head": (211, 53, 47),
        "head_light": (245, 239, 220), "outfit": (172, 38, 43),
        "outfit_light": (231, 64, 54), "legs": (44, 91, 132),
        "legs_light": (63, 120, 159), "shoe": (183, 45, 43),
    },
    "green": {
        "outline": (23, 20, 24), "skin": (240, 167, 122),
        "skin_shadow": (184, 93, 69), "hair": (63, 36, 29),
        "hair_light": (104, 58, 43), "head": (63, 36, 29),
        "head_light": (104, 58, 43), "outfit": (34, 34, 40),
        "outfit_light": (92, 91, 102), "legs": (39, 39, 45),
        "legs_light": (102, 100, 111), "shoe": (27, 27, 32),
    },
    "blue": {
        "outline": (25, 20, 25), "skin": (244, 170, 119),
        "skin_shadow": (195, 96, 58), "hair": (148, 64, 22),
        "hair_light": (222, 113, 31), "head": (148, 64, 22),
        "head_light": (222, 113, 31), "outfit": (35, 36, 42),
        "outfit_light": (76, 78, 88), "legs": (102, 69, 145),
        "legs_light": (143, 91, 181), "shoe": (43, 37, 49),
    },
}


def chroma_alpha(image: Image.Image) -> Image.Image:
    """Remove the generated green screen without erasing dark green detail."""
    rgba = image.convert("RGBA")
    pixels = list(rgba.getdata())
    cleaned = []
    for red, green, blue, alpha in pixels:
        chroma = green > 72 and green > red * 1.34 and green > blue * 1.27
        cleaned.append((red, green, blue, 0 if chroma else alpha))
    rgba.putdata(cleaned)
    return rgba


def cell(image: Image.Image, column: int, row: int, columns: int, rows: int) -> Image.Image:
    left = round(image.width * column / columns)
    right = round(image.width * (column + 1) / columns)
    top = round(image.height * row / rows)
    bottom = round(image.height * (row + 1) / rows)
    return image.crop((left, top, right, bottom))


def largest_component(image: Image.Image) -> Image.Image:
    """Drop isolated chroma-key debris while retaining the main connected pose."""
    alpha = image.getchannel("A")
    width, height = image.size
    visible = alpha.load()
    seen: set[tuple[int, int]] = set()
    best: list[tuple[int, int]] = []
    for y in range(height):
        for x in range(width):
            if visible[x, y] < 48 or (x, y) in seen:
                continue
            queue = deque(((x, y),))
            seen.add((x, y))
            component = []
            while queue:
                px, py = queue.popleft()
                component.append((px, py))
                for nx, ny in ((px - 1, py), (px + 1, py), (px, py - 1), (px, py + 1)):
                    if (0 <= nx < width and 0 <= ny < height
                            and (nx, ny) not in seen and visible[nx, ny] >= 48):
                        seen.add((nx, ny))
                        queue.append((nx, ny))
            if len(component) > len(best):
                best = component
    if not best:
        return image
    mask = Image.new("L", image.size, 0)
    target = mask.load()
    for x, y in best:
        target[x, y] = visible[x, y]
    result = image.copy()
    result.putalpha(mask)
    return result


def significant_components(image: Image.Image) -> Image.Image:
    """Keep character, bicycle frame and wheels while rejecting key debris."""
    alpha = image.getchannel("A")
    width, height = image.size
    visible = alpha.load()
    seen: set[tuple[int, int]] = set()
    components: list[list[tuple[int, int]]] = []
    for y in range(height):
        for x in range(width):
            if visible[x, y] < 48 or (x, y) in seen:
                continue
            queue = deque(((x, y),))
            seen.add((x, y))
            component = []
            while queue:
                px, py = queue.popleft()
                component.append((px, py))
                for nx, ny in ((px - 1, py), (px + 1, py),
                               (px, py - 1), (px, py + 1)):
                    if (0 <= nx < width and 0 <= ny < height
                            and (nx, ny) not in seen and visible[nx, ny] >= 48):
                        seen.add((nx, ny))
                        queue.append((nx, ny))
            components.append(component)
    largest = max((len(component) for component in components), default=0)
    minimum = max(12, largest // 80)
    mask = Image.new("L", image.size, 0)
    target = mask.load()
    for component in components:
        if len(component) < minimum:
            continue
        for x, y in component:
            target[x, y] = visible[x, y]
    result = image.copy()
    result.putalpha(mask)
    return result


def trim(image: Image.Image, *, ignore_thin_rod: bool = False,
         keep_components: bool = False) -> Image.Image:
    image = significant_components(image) if keep_components else largest_component(image)
    alpha = image.getchannel("A")
    if ignore_thin_rod:
        # Rod pixels are one narrow diagonal connected to the hands.  Dense
        # columns identify the trainer body while the engine draws its own rod.
        counts = [sum(alpha.getpixel((x, y)) >= 48 for y in range(image.height))
                  for x in range(image.width)]
        dense = [x for x, count in enumerate(counts) if count >= max(5, image.height // 28)]
        if dense:
            margin = max(2, image.width // 60)
            alpha.paste(0, (0, 0, max(0, min(dense) - margin), image.height))
            alpha.paste(0, (min(image.width, max(dense) + margin + 1), 0,
                            image.width, image.height))
            image.putalpha(alpha)
    bbox = image.getchannel("A").getbbox()
    return image.crop(bbox) if bbox else Image.new("RGBA", (1, 1))


def reduce_pose(image: Image.Image, width: int, height: int, *, pad: int = 1,
                keep_components: bool = False) -> Image.Image:
    image = trim(image, keep_components=keep_components)
    limit_w, limit_h = width - 2 * pad, height - 2 * pad
    scale = min(limit_w / image.width, limit_h / image.height)
    size = (max(1, round(image.width * scale)), max(1, round(image.height * scale)))
    # LANCZOS retains faces and garment bands during the large reduction; the
    # final adaptive palette and hard alpha turn it back into exact pixel art.
    resized = image.resize(size, Image.Resampling.LANCZOS)
    alpha = resized.getchannel("A").point(lambda value: 255 if value >= 96 else 0)
    rgb = resized.convert("RGB").quantize(colors=15, method=Image.Quantize.MEDIANCUT,
                                           dither=Image.Dither.NONE).convert("RGB")
    reduced = rgb.convert("RGBA")
    reduced.putalpha(alpha)
    canvas = Image.new("RGBA", (width, height))
    canvas.alpha_composite(reduced, ((width - size[0]) // 2, height - pad - size[1]))
    return canvas


def reduce_pixel_pose(image: Image.Image, width: int, height: int,
                      *, pad: int = 1) -> Image.Image:
    """Nearest-neighbour reduction for authored hard-grid player art."""
    image = trim(image)
    limit_w, limit_h = width - 2 * pad, height - 2 * pad
    scale = min(limit_w / image.width, limit_h / image.height)
    size = (max(1, round(image.width * scale)),
            max(1, round(image.height * scale)))
    resized = image.resize(size, Image.Resampling.NEAREST)
    alpha = resized.getchannel("A").point(lambda value: 255 if value >= 96 else 0)
    rgb = resized.convert("RGB").quantize(
        colors=15, method=Image.Quantize.MEDIANCUT,
        dither=Image.Dither.NONE).convert("RGB")
    reduced = rgb.convert("RGBA")
    reduced.putalpha(alpha)
    canvas = Image.new("RGBA", (width, height))
    canvas.alpha_composite(reduced, ((width - size[0]) // 2,
                                     height - pad - size[1]))
    return canvas


def reduce_frlg_pose(image: Image.Image, width: int, height: int,
                     *, pad: int = 1, colors: int = 24,
                     resample: Image.Resampling = Image.Resampling.LANCZOS,
                     contrast: float = 1.0, sharpen: int = 0) -> Image.Image:
    """Reduce detailed authored art without crushing faces into eight colours.

    Generated source boards are much larger than the native 64px trainer
    canvas.  Nearest-neighbour sampling skips most of their deliberate facial
    and garment clusters; a high-quality reduction followed by a controlled
    hard-alpha palette produces a considerably cleaner FRLG-sized result.
    """
    image = trim(image)
    limit_w, limit_h = width - 2 * pad, height - 2 * pad
    scale = min(limit_w / image.width, limit_h / image.height)
    size = (max(1, round(image.width * scale)),
            max(1, round(image.height * scale)))
    resized = image.resize(size, resample)
    if sharpen:
        resized = resized.filter(ImageFilter.UnsharpMask(
            radius=1, percent=sharpen, threshold=3))
    if contrast != 1.0:
        resized = ImageEnhance.Contrast(resized).enhance(contrast)
    alpha = resized.getchannel("A").point(
        lambda value: 255 if value >= 80 else 0)
    rgb = resized.convert("RGB").quantize(
        colors=colors, method=Image.Quantize.MEDIANCUT,
        dither=Image.Dither.NONE).convert("RGB")
    reduced = rgb.convert("RGBA")
    reduced.putalpha(alpha)
    canvas = Image.new("RGBA", (width, height))
    canvas.alpha_composite(reduced, ((width - size[0]) // 2,
                                     height - pad - size[1]))
    return canvas


def fit_voxel_front(image: Image.Image, width: int = 64, height: int = 64,
                    *, side_pad: int = 1, bottom_pad: int = 3) -> Image.Image:
    """Leave a real transparent floor gap below full standing trainer art."""
    image = trim(image)
    limit_w = width - 2 * side_pad
    limit_h = height - bottom_pad
    # Native Red/Blue art is never enlarged.  Blue is one pixel too tall for
    # the explicit Voxel floor gap, so it is reduced once with nearest pixels.
    scale = min(1.0, limit_w / image.width, limit_h / image.height)
    size = (max(1, round(image.width * scale)),
            max(1, round(image.height * scale)))
    resized = image.resize(size, Image.Resampling.NEAREST)
    canvas = Image.new("RGBA", (width, height))
    canvas.alpha_composite(resized, ((width - size[0]) // 2,
                                     height - bottom_pad - size[1]))
    return canvas


def reduce_pixel_sequence(images: list[Image.Image], width: int, height: int,
                          *, pad: int = 1) -> list[Image.Image]:
    """Reduce poses at one shared scale and palette so the actor never pops."""
    trimmed = [trim(image, keep_components=True) for image in images]
    limit_w, limit_h = width - 2 * pad, height - 2 * pad
    scale = min(
        min(limit_w / image.width, limit_h / image.height)
        for image in trimmed
    )
    sheet = Image.new("RGBA", (width * len(trimmed), height))
    for index, image in enumerate(trimmed):
        size = (max(1, round(image.width * scale)),
                max(1, round(image.height * scale)))
        resized = image.resize(size, Image.Resampling.NEAREST)
        alpha = resized.getchannel("A").point(
            lambda value: 255 if value >= 96 else 0)
        resized.putalpha(alpha)
        sheet.alpha_composite(
            resized,
            (index * width + (width - size[0]) // 2,
             height - pad - size[1]),
        )

    # One quantization pass gives every frame the exact same limited palette.
    alpha = sheet.getchannel("A")
    rgb = sheet.convert("RGB").quantize(
        colors=15, method=Image.Quantize.MEDIANCUT,
        dither=Image.Dither.NONE).convert("RGB")
    sheet = rgb.convert("RGBA")
    sheet.putalpha(alpha)
    return [sheet.crop((index * width, 0, (index + 1) * width, height))
            for index in range(len(trimmed))]


def build_vertical(frames: list[Image.Image], path: Path) -> None:
    width, height = frames[0].size
    sheet = Image.new("RGBA", (width, height * len(frames)))
    for index, frame in enumerate(frames):
        sheet.alpha_composite(frame, (0, index * height))
    path.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(path, optimize=True)


def split_gen1_sheet(path: Path) -> list[Image.Image]:
    """Read the native engine layout: six vertical 16x16 frames."""
    sheet = Image.open(path).convert("RGBA")
    if sheet.size != (16, 96):
        raise ValueError(f"{path} must be a native 16x96 Gen-I sheet")
    return [sheet.crop((0, frame * 16, 16, (frame + 1) * 16))
            for frame in range(6)]


def has_transparent_neighbour(frame: Image.Image, x: int, y: int) -> bool:
    for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
        if not (0 <= nx < 16 and 0 <= ny < 16):
            return True
        if frame.getpixel((nx, ny))[3] == 0:
            return True
    return False


def field_colour(character: str, state: str, frame: Image.Image,
                 x: int, y: int, shade: int,
                 frame_index: int = 0) -> tuple[int, int, int]:
    """Apply design colours without changing one pixel of Gen-I geometry."""
    palette = PALETTES[character]
    boundary = has_transparent_neighbour(frame, x, y)

    # The bicycle and rod remain engine-sized props; only the rider/body is
    # character-specific.  Rows 11-15 are therefore neutral hardware.
    if state == "bike" and y >= 11:
        if shade >= 160:
            return (184, 195, 205)
        if shade >= 80:
            return (83, 94, 105)
        return palette["outline"]

    # Headwear/hair. Red keeps his FireRed cap, but only one native pixel row
    # is white: two rows read as a broad sailor-cap band at 16x16. Blue and
    # Green use hair.
    if y <= 4:
        if shade == 0:
            # Green's source has four enclosed black hair-detail pixels over
            # the forehead. At native scale they merge into a horizontal
            # shadow. Keep the outer contour black but lift enclosed detail
            # into the lighter brown strand colour, so it reads as a soft
            # fringe instead of a second dark hairpiece on her forehead.
            if character == "green" and not boundary:
                return palette["hair_light"]
            return palette["outline"]
        if character == "red":
            # Front-facing FireRed cap: a small rounded white crown, not the
            # old full-width white ring that read like a sailor hat.
            if (frame_index in (0, 3) and y == 2
                    and 5 <= x <= 10 and shade >= 80):
                return palette["head_light"]
            if frame_index not in (0, 3) and y == 3 and shade >= 80:
                return palette["head_light"]
            return palette["head"]
        return palette["head_light"] if shade >= 160 else palette["head"]

    # Face and arms use the light Game Boy value. Dark pixels in this band are
    # hair or outlines, never flood-filled skin.
    if y <= 9:
        # Casey's up-facing cells are hair, not a skin-coloured horizontal
        # stripe.  Keep only the two exposed edge pixels as ears.
        if character == "green" and frame_index in (1, 4):
            if shade >= 160 and x in (2, 3, 12, 13):
                return palette["skin"]
            if shade == 0:
                return palette["outline"] if boundary else palette["hair"]
            # A horizontal highlight across the full back read as the rim of
            # a backpack/hump. One short vertical strand describes long hair
            # without creating a second silhouette.
            if x == 10 and 4 <= y <= 8 and not boundary:
                return palette["hair_light"]
            return palette["hair"]

        # In the side cells the long hair continues below the face.  The old
        # row-only recolour turned its lower half grey, producing an
        # inexplicable third hair colour.  Keep the rear half consistently
        # brown while the forward half remains skin.
        if character == "green" and frame_index in (2, 5) and x <= 7:
            if shade == 0:
                return palette["outline"] if boundary else palette["hair"]
            return palette["hair_light"] if shade >= 160 else palette["hair"]

        if shade >= 160:
            return palette["skin"]
        if shade >= 80:
            return palette["hair_light"] if character != "red" else palette["hair"]
        return palette["outline"]

    # Recolour only enclosed black fill. Boundary and seam pixels stay dark,
    # preserving the exact readable silhouette of the original 16x16 art.
    if y <= 11:
        if character == "green" and frame_index in (2, 5) and x <= 7:
            if shade == 0:
                return palette["outline"] if boundary else palette["hair"]
            return palette["hair_light"] if shade >= 160 else palette["hair"]
        # Red's black T-shirt must remain visible between the red vest sides.
        if character == "red" and frame_index in (0, 3) and 6 <= x <= 9:
            return palette["outline"]
        if shade >= 160:
            return palette["skin"]
        if shade >= 80:
            return palette["outfit_light"]
        return palette["outline"] if boundary else palette["outfit"]

    if y <= 14:
        if shade >= 160:
            return palette["legs_light"]
        if shade >= 80:
            return palette["legs"]
        return palette["outline"] if boundary else palette["legs"]

    if shade >= 160:
        return palette["shoe"]
    return palette["outline"]


def colour_gen1_frame(character: str, state: str,
                      frame: Image.Image, frame_index: int = 0) -> Image.Image:
    result = Image.new("RGBA", (16, 16))
    for y in range(16):
        for x in range(16):
            red, green, blue, alpha = frame.getpixel((x, y))
            if alpha == 0:
                continue
            shade = round((red + green + blue) / 3)
            result.putpixel((x, y), (*field_colour(
                character, state, frame, x, y, shade, frame_index), 255))
    return result


def refine_walk_geometry(character: str,
                         frames: list[Image.Image]) -> list[Image.Image]:
    """Apply tiny reviewed silhouette fixes without resampling the grid."""
    revised = [frame.copy() for frame in frames]
    if character == "green":
        # The authored stand-down and stand-up cells ended in one continuous
        # eight-pixel black strip. In game that reads as a detached oval drop
        # shadow. Split only that last row into two grounded feet; all hair,
        # clothing, animation poses and the 16x16 footprint stay unchanged.
        for index in (0, 1):
            for x in (7, 8):
                revised[index].putpixel((x, 15), (0, 0, 0, 0))

        # Remove the enclosed forehead blocks from both down-facing cells;
        # they read as a separate toupee/shadow at native scale.  Turn the
        # two-pixel mouth into real dark ink instead of the brown hair shade.
        for index in (0, 3):
            for y in (3, 4):
                for x in range(16):
                    red, green, blue, alpha = revised[index].getpixel((x, y))
                    if alpha and red < 48 and not has_transparent_neighbour(
                            revised[index], x, y):
                        revised[index].putpixel((x, y), (112, 112, 112, 255))
            for x in (7, 8):
                revised[index].putpixel((x, 9), (0, 0, 0, 255))

        # A narrower top breaks the round backpack/hump silhouette when Casey
        # walks upward without moving or enlarging the native 16px footprint.
        for index in (1, 4):
            top = 0 if index == 1 else 1
            for x in (6, 9):
                revised[index].putpixel((x, top), (0, 0, 0, 0))
    return revised


def rider_frames(character: str, walk_frames: list[Image.Image],
                 bike_frames: list[Image.Image]) -> list[Image.Image]:
    """Put each character's native 16px head on the native 16px bicycle."""
    result = []
    for walk, bike in zip(walk_frames, bike_frames):
        merged = bike.copy()
        # Replace only the head/hair area. The body, wheels and baseline remain
        # byte-for-byte in the engine's supported Gen-I footprint.
        merged.paste((0, 0, 0, 0), (0, 0, 16, 9))
        merged.alpha_composite(walk.crop((0, 0, 16, 9)), (0, 0))
        result.append(merged)
    return result


def build() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    fallback_out = OUT / "fallback_walk_v1"
    fallback_out.mkdir(parents=True, exist_ok=True)
    for character in CHARACTERS:
        source = FALLBACK_WALK / f"{character}_walk.png"
        if not source.is_file():
            raise FileNotFoundError(
                f"missing approved walking fallback: {source}")
        # Preserve the frozen v1 PNG bytes exactly; do not pass fallback art
        # through Pillow or any of the current-primary authoring transforms.
        shutil.copyfile(source, fallback_out / source.name)
    fallback_v2_out = OUT / "fallback_walk_v2"
    fallback_v2_out.mkdir(parents=True, exist_ok=True)
    green_v2 = FALLBACK_WALK_V2 / "green_walk.png"
    if not green_v2.is_file():
        raise FileNotFoundError(
            f"missing approved Green 6.5.5 walking fallback: {green_v2}")
    # This is the exact public 6.5.5 Green sheet. Preserve its PNG bytes so a
    # corrupt hotfix primary can recover without rebuilding/re-encoding it.
    shutil.copyfile(green_v2, fallback_v2_out / green_v2.name)
    green_front = chroma_alpha(Image.open(
        SOURCE / "casey_front_frlg_chroma.png"))
    throw_sources = {
        "red": SOURCE / "red_throw_frlg_upper_chroma.png",
        "green": SOURCE / "casey_throw_frlg_upper_chroma.png",
        "blue": SOURCE / "blue_throw_frlg_upper_chroma.png",
    }
    throw_frames = {}
    for character, source in throw_sources.items():
        board = chroma_alpha(Image.open(source))
        throw_frames[character] = reduce_pixel_sequence(
            [cell(board, index, 0, 5, 1) for index in range(5)],
            64, 64, pad=1)
    bike_base = split_gen1_sheet(ENGINE_SPRITES / "red_bike.png")

    # Keep the classic 2D opponent portraits independent from the Voxel
    # standing figures. The source files make this build idempotent.
    native_fronts = {
        # Red deliberately has no bundled front source. Runtime front/card/
        # Hall-of-Fame surfaces use gen1recomp's ROM-derived Gen-I Red image;
        # the custom throw and Voxel families are still built below.
        "blue": Image.open(CHARACTER_SOURCE / "frlg_blue_front.png").convert("RGBA"),
        "green": reduce_frlg_pose(
            green_front, 64, 64, pad=1, colors=20,
            resample=Image.Resampling.BOX, contrast=1.10, sharpen=100),
    }
    standing_board = chroma_alpha(Image.open(
        SOURCE / "unified_battle_board_v2_chroma.png"))
    voxel_fronts = {
        character: reduce_frlg_pose(
            cell(standing_board, column, 0, 3, 2), 64, 64, pad=3)
        for column, character in enumerate(CHARACTERS)
    }
    voxel_fronts_hd = {
        character: reduce_frlg_pose(
            cell(standing_board, column, 0, 3, 2), 128, 128,
            pad=6, colors=48)
        for column, character in enumerate(CHARACTERS)
    }

    for row, character in enumerate(CHARACTERS):
        if character in native_fronts:
            native_fronts[character].save(
                OUT / f"{character}_front.png", optimize=True)
        voxel_fronts[character].save(
            OUT / f"{character}_voxel_front.png", optimize=True)
        voxel_fronts_hd[character].save(
            OUT / f"{character}_voxel_front_hd.png", optimize=True)
        if character in throw_frames:
            for index, frame in enumerate(throw_frames[character], start=1):
                frame.save(OUT / f"{character}_back_throw_{index}.png",
                           optimize=True)
            throw_frames[character][0].save(
                OUT / f"{character}_back.png", optimize=True)

        walk_source = (GEN1 / "green_walk_base.png" if character == "green"
                       else ENGINE_SPRITES / f"{character}.png")
        walk_base = refine_walk_geometry(
            character, split_gen1_sheet(walk_source))

        # Walking masters have received native-grid, frame-specific visual
        # review that cannot be reproduced safely by broad recolouring rules.
        # Copy them pixel-for-pixel. Bike and fishing remain separate surfaces
        # and continue to use their own build paths below.
        approved_walk = APPROVED_WALK / f"{character}_walk.png"
        if not approved_walk.is_file():
            raise FileNotFoundError(
                f"missing approved walking master: {approved_walk}")
        walk_frames = split_gen1_sheet(approved_walk)
        build_vertical(walk_frames, OUT / f"{character}_walk.png")

        native_riders = rider_frames(character, walk_base, bike_base)
        bike_frames = [colour_gen1_frame(character, "bike", frame, index)
                       for index, frame in enumerate(native_riders)]
        build_vertical(bike_frames, OUT / f"{character}_bike.png")

        # gen1recomp draws the rod separately. A matching 16x16 body is all the
        # optional character set must supply, so no tall or wide overlay exists.
        fish_frames = [colour_gen1_frame(character, "fish", frame, index)
                       for index, frame in enumerate(walk_base)]
        build_vertical(fish_frames, OUT / f"{character}_fish.png")

    # One enlarged review board makes alignment/style regressions obvious.
    preview = Image.new("RGBA", (3 * 128, 6 * 128), (238, 238, 238, 255))
    for column, character in enumerate(CHARACTERS):
        assets = [
            Image.open(OUT / f"{character}_front.png"),
            Image.open(OUT / f"{character}_voxel_front.png"),
            Image.open(OUT / f"{character}_back.png"),
            Image.open(OUT / f"{character}_walk.png").crop((0, 0, 16, 16)),
            Image.open(OUT / f"{character}_bike.png").crop((0, 0, 16, 16)),
            Image.open(OUT / f"{character}_fish.png").crop((0, 0, 16, 16)),
        ]
        for row, asset in enumerate(assets):
            scale = min(112 // asset.width, 112 // asset.height)
            enlarged = asset.resize((asset.width * scale, asset.height * scale),
                                     Image.Resampling.NEAREST)
            preview.alpha_composite(enlarged,
                                    (column * 128 + (128 - enlarged.width) // 2,
                                     row * 128 + (128 - enlarged.height) // 2))
    preview.save(OUT / "review_board.png", optimize=True)


if __name__ == "__main__":
    build()
