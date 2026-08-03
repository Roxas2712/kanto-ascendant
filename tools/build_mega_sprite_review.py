#!/usr/bin/env python3
"""Build review-only 96x96 sprite sheets for every supported Mega form.

All Mega sprites come from the public PokeAPI 96x96 Gen-V-style master set.
Matching Showdown animations are retained alongside the 21 classic forms.

This script deliberately writes to art_review/, not assets/. Nothing generated
here is used by the mod until the artwork has been reviewed and approved.
"""

from __future__ import annotations

import argparse
import io
import shutil
import urllib.request
import zipfile
from dataclasses import dataclass
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, ImageSequence


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OUTPUT = ROOT / "art_review" / "mega_sprites_v1"
POKEAPI_SHOWDOWN = (
    "https://raw.githubusercontent.com/PokeAPI/sprites/master/"
    "sprites/pokemon/other/showdown"
)
POKEAPI_STATIC = (
    "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon"
)


@dataclass(frozen=True)
class Mega:
    key: str
    label: str
    classic_id: int | None = None
    has_showdown_animation: bool = True


MEGAS = (
    Mega("mega_venusaur", "Mega Venusaur", 10033),
    Mega("mega_charizard_x", "Mega Charizard X", 10034),
    Mega("mega_charizard_y", "Mega Charizard Y", 10035),
    Mega("mega_blastoise", "Mega Blastoise", 10036),
    Mega("mega_beedrill", "Mega Beedrill", 10090),
    Mega("mega_pidgeot", "Mega Pidgeot", 10073),
    Mega("mega_alakazam", "Mega Alakazam", 10037),
    Mega("mega_slowbro", "Mega Slowbro", 10071),
    Mega("mega_gengar", "Mega Gengar", 10038),
    Mega("mega_kangaskhan", "Mega Kangaskhan", 10039),
    Mega("mega_pinsir", "Mega Pinsir", 10040),
    Mega("mega_gyarados", "Mega Gyarados", 10041),
    Mega("mega_aerodactyl", "Mega Aerodactyl", 10042),
    Mega("mega_mewtwo_x", "Mega Mewtwo X", 10043),
    Mega("mega_mewtwo_y", "Mega Mewtwo Y", 10044),
    Mega("mega_ampharos", "Mega Ampharos", 10045),
    Mega("mega_steelix", "Mega Steelix", 10072),
    Mega("mega_scizor", "Mega Scizor", 10046),
    Mega("mega_heracross", "Mega Heracross", 10047),
    Mega("mega_houndoom", "Mega Houndoom", 10048),
    Mega("mega_tyranitar", "Mega Tyranitar", 10049),
    Mega("mega_clefable", "Mega Clefable", 10278, False),
    Mega("mega_victreebel", "Mega Victreebel", 10279, False),
    Mega("mega_starmie", "Mega Starmie", 10280, False),
    Mega("mega_dragonite", "Mega Dragonite", 10281, False),
    Mega("mega_meganium", "Mega Meganium", 10282, False),
    Mega("mega_feraligatr", "Mega Feraligatr", 10283, False),
    Mega("mega_skarmory", "Mega Skarmory", 10284, False),
    Mega("mega_raichu_x", "Mega Raichu X", 10304, False),
    Mega("mega_raichu_y", "Mega Raichu Y", 10305, False),
)

VIEWS = {
    "front": ("", "gen5"),
    "back": ("back", "gen5-back"),
    "front_shiny": ("shiny", "gen5-shiny"),
    "back_shiny": ("back/shiny", "gen5-back-shiny"),
}


def fetch(url: str) -> bytes:
    request = urllib.request.Request(
        url, headers={"User-Agent": "Kanto-Ascendant-sprite-review/1.0"}
    )
    with urllib.request.urlopen(request, timeout=60) as response:
        return response.read()


def font(size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    candidates = (
        "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
        "/System/Library/Fonts/Supplemental/Arial.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
    )
    for candidate in candidates:
        try:
            return ImageFont.truetype(candidate, size)
        except OSError:
            continue
    return ImageFont.load_default()


def representative_gif_frame(payload: bytes) -> Image.Image:
    """Return the sharp idle frame without interpolating or resampling."""
    with Image.open(io.BytesIO(payload)) as gif:
        frames = [frame.convert("RGBA") for frame in ImageSequence.Iterator(gif)]
    if not frames:
        raise ValueError("animated source did not contain a frame")
    # Showdown's first frame is the canonical idle pose. Preserve it exactly.
    return frames[0]


def normalized_canvas(image: Image.Image) -> Image.Image:
    """Place source art on a 96x96 canvas without scaling a single pixel."""
    source = image.convert("RGBA")
    if source.size == (96, 96):
        return source
    bbox = source.getbbox()
    if bbox is None:
        raise ValueError("source sprite is fully transparent")
    cropped = source.crop(bbox)
    if cropped.width > 96 or cropped.height > 96:
        raise ValueError(
            f"source {source.size} has visible area {cropped.size}, larger than 96x96"
        )
    canvas = Image.new("RGBA", (96, 96), (0, 0, 0, 0))
    x = (96 - cropped.width) // 2
    y = 96 - cropped.height
    canvas.alpha_composite(cropped, (x, y))
    return canvas


def classic_url(sprite_id: int, view: str) -> str:
    path, _ = VIEWS[view]
    middle = f"/{path}" if path else ""
    return f"{POKEAPI_SHOWDOWN}{middle}/{sprite_id}.gif"


def classic_static_url(sprite_id: int, view: str) -> str:
    path, _ = VIEWS[view]
    middle = f"/{path}" if path else ""
    return f"{POKEAPI_STATIC}{middle}/{sprite_id}.png"


def build_sources(output: Path) -> dict[tuple[str, str], Path]:
    sources = output / "sources"
    animated_sources = sources / "animated"
    sprites = output / "sprites"
    sources.mkdir(parents=True, exist_ok=True)
    animated_sources.mkdir(parents=True, exist_ok=True)
    sprites.mkdir(parents=True, exist_ok=True)

    results: dict[tuple[str, str], Path] = {}
    for mega in MEGAS:
        for view, (_, gen5_dir) in VIEWS.items():
            source_path = sources / f"{mega.key}_{view}.png"
            if mega.classic_id is not None:
                if not source_path.exists():
                    source_path.write_bytes(
                        fetch(classic_static_url(mega.classic_id, view))
                    )
                if mega.has_showdown_animation:
                    animated_path = (
                        animated_sources / f"{mega.key}_{view}.gif"
                    )
                    if not animated_path.exists():
                        animated_path.write_bytes(
                            fetch(classic_url(mega.classic_id, view))
                        )
            else:
                raise ValueError(f"no source configured for {mega.key}")

            image = Image.open(source_path).convert("RGBA")
            target = sprites / f"{mega.key}_{view}.png"
            normalized_canvas(image).save(target, optimize=True)
            results[(mega.key, view)] = target
    return results


def checker_tile(size: tuple[int, int], square: int = 12) -> Image.Image:
    tile = Image.new("RGBA", size, (236, 239, 244, 255))
    draw = ImageDraw.Draw(tile)
    for y in range(0, size[1], square):
        for x in range(0, size[0], square):
            if (x // square + y // square) % 2:
                draw.rectangle(
                    (x, y, x + square - 1, y + square - 1),
                    fill=(212, 217, 225, 255),
                )
    return tile


def contact_sheet(
    output: Path,
    paths: dict[tuple[str, str], Path],
    view: str,
    filename: str,
) -> None:
    columns, rows = 5, 6
    cell_w, cell_h = 330, 360
    sheet = Image.new(
        "RGB", (columns * cell_w, rows * cell_h), (24, 28, 36)
    )
    title_font = font(22)
    small_font = font(16)

    for index, mega in enumerate(MEGAS):
        column, row = index % columns, index // columns
        ox, oy = column * cell_w, row * cell_h
        cell = Image.new("RGBA", (cell_w, cell_h), (35, 41, 52, 255))
        draw = ImageDraw.Draw(cell)
        draw.rounded_rectangle(
            (8, 8, cell_w - 9, cell_h - 9),
            radius=16,
            outline=(78, 91, 112, 255),
            width=2,
            fill=(35, 41, 52, 255),
        )

        source = Image.open(paths[(mega.key, view)]).convert("RGBA")
        large = source.resize((288, 288), Image.Resampling.NEAREST)
        preview = checker_tile((288, 288))
        preview.alpha_composite(large)
        cell.alpha_composite(preview, (21, 42))

        # Actual-size inset: this prevents a magnified preview from hiding
        # whether the sprite still reads clearly at its native battle size.
        inset = checker_tile((104, 104), 8)
        inset.alpha_composite(source, (4, 4))
        cell.alpha_composite(inset, (cell_w - 118, 224))
        draw.rectangle(
            (cell_w - 118, 224, cell_w - 14, 328),
            outline=(20, 24, 31, 255),
            width=2,
        )
        draw.text(
            (cell_w - 112, 306),
            "1:1",
            font=small_font,
            fill=(255, 255, 255, 255),
            stroke_width=2,
            stroke_fill=(20, 24, 31, 255),
        )

        text_box = draw.textbbox((0, 0), mega.label, font=title_font)
        text_w = text_box[2] - text_box[0]
        draw.text(
            ((cell_w - text_w) // 2, 14),
            mega.label,
            font=title_font,
            fill=(248, 250, 253, 255),
        )
        draw.text(
            (18, 334),
            f"{index + 1:02d}  •  native 96×96  •  nearest-neighbor",
            font=small_font,
            fill=(166, 177, 195, 255),
        )
        sheet.paste(cell.convert("RGB"), (ox, oy))

    sheet.save(output / filename, quality=95)


def silhouette_sheet(
    output: Path, paths: dict[tuple[str, str], Path]
) -> None:
    columns, rows = 5, 6
    cell_w, cell_h = 250, 260
    sheet = Image.new("RGB", (columns * cell_w, rows * cell_h), (246, 247, 249))
    label_font = font(18)

    for index, mega in enumerate(MEGAS):
        column, row = index % columns, index // columns
        source = Image.open(paths[(mega.key, "front")]).convert("RGBA")
        alpha = source.getchannel("A")
        silhouette = Image.new("RGBA", source.size, (14, 18, 24, 0))
        silhouette.putalpha(alpha.point(lambda value: 255 if value >= 128 else 0))
        large = silhouette.resize((192, 192), Image.Resampling.NEAREST)
        x = column * cell_w + (cell_w - 192) // 2
        y = row * cell_h + 18
        sheet.paste(large, (x, y), large)
        draw = ImageDraw.Draw(sheet)
        box = draw.textbbox((0, 0), mega.label, font=label_font)
        text_w = box[2] - box[0]
        draw.text(
            (column * cell_w + (cell_w - text_w) // 2, row * cell_h + 220),
            mega.label,
            font=label_font,
            fill=(25, 30, 38),
        )

    sheet.save(output / "05_front_silhouette_readability.png", optimize=True)


FLYING_OR_HOVERING = {
    "mega_beedrill",
    "mega_pidgeot",
    "mega_alakazam",
    "mega_gengar",
    "mega_pinsir",
    "mega_aerodactyl",
    "mega_mewtwo_x",
    "mega_mewtwo_y",
    "mega_clefable",
    "mega_starmie",
    "mega_dragonite",
    "mega_skarmory",
    "mega_raichu_x",
    "mega_raichu_y",
}

HEAVY_FORMS = {
    "mega_venusaur",
    "mega_blastoise",
    "mega_slowbro",
    "mega_kangaskhan",
    "mega_steelix",
    "mega_tyranitar",
    "mega_meganium",
    "mega_feraligatr",
}

SERPENTINE_FORMS = {
    "mega_gyarados",
    "mega_steelix",
}


def idle_offsets(mega: Mega) -> list[tuple[int, int]]:
    """Small integer-only motion that survives voxel conversion cleanly."""
    if mega.key in FLYING_OR_HOVERING:
        vertical = (0, -1, -1, -2, -2, -1, 0, 0, 1, 1, 0, 0)
    elif mega.key in HEAVY_FORMS:
        vertical = (0, 0, 0, 0, -1, -1, 0, 0, 0, 1, 0, 0)
    else:
        vertical = (0, 0, -1, -1, 0, 0, 0, 1, 1, 0, 0, 0)

    if mega.key in SERPENTINE_FORMS:
        horizontal = (0, 0, 1, 1, 1, 0, 0, -1, -1, -1, 0, 0)
    else:
        horizontal = (0,) * len(vertical)
    return list(zip(horizontal, vertical))


def canvas_safe_offsets(
    source: Image.Image, offsets: list[tuple[int, int]]
) -> list[tuple[int, int]]:
    """Keep every visible master pixel inside the native 96x96 canvas."""
    bbox = source.getchannel("A").getbbox()
    if bbox is None:
        raise ValueError("cannot animate an empty master")
    left, top, right, bottom = bbox
    min_x, max_x = -left, 96 - right
    min_y, max_y = -top, 96 - bottom
    safe = [
        (
            max(min_x, min(max_x, x)),
            max(min_y, min(max_y, y)),
        )
        for x, y in offsets
    ]
    if len(set(safe)) < 2:
        # A full-height sprite cannot bob without losing pixels. It usually
        # still has horizontal breathing room, so retain visible motion there.
        pulse = (0, 1, 1, 0, -1, -1, 0, 1, 1, 0, -1, 0)
        safe = [
            (max(min_x, min(max_x, x)), 0)
            for x in pulse[:len(offsets)]
        ]
    return safe


def save_gif(frames: list[Image.Image], target: Path, duration: int = 90) -> None:
    frames[0].save(
        target,
        save_all=True,
        append_images=frames[1:],
        duration=duration,
        loop=0,
        disposal=2,
        optimize=False,
    )


def build_pixel_animations(
    output: Path, paths: dict[tuple[str, str], Path]
) -> dict[tuple[str, str], Path]:
    """Animate approved masterframes using integer pixel translation only."""
    animations = output / "animations"
    animations.mkdir(parents=True, exist_ok=True)
    results: dict[tuple[str, str], Path] = {}

    for mega in MEGAS:
        for view in VIEWS:
            source = Image.open(paths[(mega.key, view)]).convert("RGBA")
            offsets = canvas_safe_offsets(source, idle_offsets(mega))
            frames = []
            for x, y in offsets:
                frame = Image.new("RGBA", (96, 96), (0, 0, 0, 0))
                frame.alpha_composite(source, (x, y))
                frames.append(frame)
            target = animations / f"{mega.key}_{view}.gif"
            save_gif(frames, target)
            results[(mega.key, view)] = target
    return results


def animated_contact_sheet(
    output: Path,
    animations: dict[tuple[str, str], Path],
    view: str,
    filename: str,
) -> None:
    columns, rows = 5, 6
    cell_w, cell_h = 224, 236
    frame_count = 12
    label_font = font(15)
    all_sprite_frames: dict[str, list[Image.Image]] = {}

    for mega in MEGAS:
        with Image.open(animations[(mega.key, view)]) as gif:
            all_sprite_frames[mega.key] = [
                frame.convert("RGBA") for frame in ImageSequence.Iterator(gif)
            ]

    sheets: list[Image.Image] = []
    for frame_index in range(frame_count):
        sheet = Image.new(
            "RGB", (columns * cell_w, rows * cell_h), (24, 28, 36)
        )
        for index, mega in enumerate(MEGAS):
            column, row = index % columns, index // columns
            cell = Image.new("RGBA", (cell_w, cell_h), (35, 41, 52, 255))
            draw = ImageDraw.Draw(cell)
            draw.rounded_rectangle(
                (4, 4, cell_w - 5, cell_h - 5),
                radius=12,
                outline=(78, 91, 112, 255),
                width=2,
                fill=(35, 41, 52, 255),
            )
            preview = checker_tile((192, 192), 12)
            sprite_frames = all_sprite_frames[mega.key]
            source = sprite_frames[frame_index % len(sprite_frames)]
            preview.alpha_composite(
                source.resize((192, 192), Image.Resampling.NEAREST)
            )
            cell.alpha_composite(preview, (16, 28))
            box = draw.textbbox((0, 0), mega.label, font=label_font)
            text_w = box[2] - box[0]
            draw.text(
                ((cell_w - text_w) // 2, 8),
                mega.label,
                font=label_font,
                fill=(248, 250, 253, 255),
            )
            sheet.paste(
                cell.convert("RGB"),
                (column * cell_w, row * cell_h),
            )
        sheets.append(sheet)
    save_gif(sheets, output / filename)


def charizard_x_detail(
    output: Path, paths: dict[tuple[str, str], Path]
) -> None:
    canvas = Image.new("RGB", (1400, 760), (24, 28, 36))
    draw = ImageDraw.Draw(canvas)
    heading = font(34)
    body = font(20)
    draw.text(
        (40, 24),
        "MEGA CHARIZARD X — 96×96 MASTERFRAME / NO INTERPOLATION",
        font=heading,
        fill=(248, 250, 253),
    )
    entries = (
        ("FRONT", "front", 45),
        ("BACK", "back", 715),
    )
    for label, view, x in entries:
        source = Image.open(
            paths[("mega_charizard_x", view)]
        ).convert("RGBA")
        checker = checker_tile((576, 576), 24)
        checker.alpha_composite(
            source.resize((576, 576), Image.Resampling.NEAREST)
        )
        canvas.paste(checker.convert("RGB"), (x, 104))
        draw.rectangle((x, 104, x + 575, 679), outline=(78, 91, 112), width=3)
        draw.text((x, 690), f"{label} • 6× nearest-neighbor", font=body,
                  fill=(198, 207, 221))
        actual = checker_tile((104, 104), 8)
        actual.alpha_composite(source, (4, 4))
        canvas.paste(actual.convert("RGB"), (x + 472, 576))
        draw.rectangle(
            (x + 472, 576, x + 575, 679),
            outline=(20, 24, 31),
            width=2,
        )
        draw.text(
            (x + 478, 650),
            "1:1",
            font=body,
            fill=(255, 255, 255),
            stroke_width=2,
            stroke_fill=(20, 24, 31),
        )
    canvas.save(output / "08_mega_charizard_x_detail.png", optimize=True)


def write_qa_report(
    output: Path,
    paths: dict[tuple[str, str], Path],
    animations: dict[tuple[str, str], Path],
) -> None:
    issues = []
    for mega in MEGAS:
        for view in VIEWS:
            path = paths[(mega.key, view)]
            image = Image.open(path).convert("RGBA")
            alpha_values = set(image.getchannel("A").getdata())
            if image.size != (96, 96):
                issues.append(f"{path.name}: size {image.size}")
            if alpha_values - {0, 255}:
                issues.append(f"{path.name}: semi-transparent pixels")
            with Image.open(animations[(mega.key, view)]) as gif:
                if getattr(gif, "n_frames", 1) < 3:
                    issues.append(f"{gif.filename}: insufficient idle motion")
                master_pixels = sum(
                    1 for value in image.getchannel("A").getdata() if value)
                for frame in ImageSequence.Iterator(gif):
                    visible = sum(
                        1 for value in frame.convert("RGBA")
                        .getchannel("A").getdata() if value)
                    if visible != master_pixels:
                        issues.append(
                            f"{gif.filename}: clipped frame "
                            f"{visible}/{master_pixels}")
                        break

    lines = [
        "MEGA SPRITE REVIEW QA",
        f"Forms: {len(MEGAS)}",
        f"Views per form: {len(VIEWS)}",
        f"Master PNGs checked: {len(MEGAS) * len(VIEWS)}",
        f"Idle GIFs checked: {len(MEGAS) * len(VIEWS)}",
        "Canvas: 96x96",
        "Resampling: none / nearest-neighbor previews only",
        "Alpha: binary 0/255",
        f"Issues: {len(issues)}",
    ]
    lines.extend(issues)
    (output / "QA_REPORT.txt").write_text(
        "\n".join(lines) + "\n", encoding="utf-8"
    )


def write_manifest(output: Path) -> None:
    lines = [
        "# Mega sprite review v1",
        "",
        "Review-only artwork. Nothing in this directory is loaded by the mod.",
        "",
        "## Source groups",
        "",
        "- All 30 forms: PokeAPI 96x96 Gen-V-style master PNGs.",
        f"  - {POKEAPI_STATIC}",
        "- Classic 21 forms: matching Smogon/Pokémon Showdown animation GIFs.",
        f"  - {POKEAPI_SHOWDOWN}",
        "",
        "All approval PNGs retain a native 96x96 canvas and use no interpolation.",
        "Review GIFs use integer-only 1-2 px idle movement; sprite pixels are",
        "never blurred, rotated or resampled.",
        "",
        "## Forms",
        "",
    ]
    lines.extend(f"{index:02d}. {mega.label}" for index, mega in enumerate(MEGAS, 1))
    (output / "README.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--clean", action="store_true")
    args = parser.parse_args()

    output = args.output.resolve()
    if args.clean and output.exists():
        shutil.rmtree(output)
    output.mkdir(parents=True, exist_ok=True)

    paths = build_sources(output)
    for view, filename in (
        ("front", "01_front_normal.png"),
        ("back", "02_back_normal.png"),
        ("front_shiny", "03_front_shiny.png"),
        ("back_shiny", "04_back_shiny.png"),
    ):
        contact_sheet(output, paths, view, filename)
    silhouette_sheet(output, paths)
    animations = build_pixel_animations(output, paths)
    animated_contact_sheet(
        output, animations, "front", "06_front_normal_animated.gif"
    )
    animated_contact_sheet(
        output, animations, "back", "07_back_normal_animated.gif"
    )
    charizard_x_detail(output, paths)
    write_qa_report(output, paths, animations)
    write_manifest(output)
    print(f"Built {len(MEGAS) * len(VIEWS)} review PNGs in {output}")


if __name__ == "__main__":
    main()
