#!/usr/bin/env python3
"""Install the approved 30-form Mega sprite and animation pack.

The review masters are sharp 96x96 PokeAPI pixel sprites. Their approved idle
loops use only integer translation, so every frame remains binary-alpha and
nearest-neighbor safe in both the 2D and Voxel renderers. Ascendant Typhlosion
is installed by build_ascendant_typhlosion.py and contributes its separate
Crystal-driven front animation to the generated timing table.
"""

from __future__ import annotations

import shutil
from pathlib import Path

from PIL import Image, ImageSequence


ROOT = Path(__file__).resolve().parents[1]
REVIEW = ROOT / "art_review" / "mega_sprites_v1"
SPRITES = REVIEW / "sprites"
ANIMATIONS = REVIEW / "animations"
ASSET_SPRITES = ROOT / "assets" / "mega"
ASSET_ANIMATIONS = ROOT / "assets" / "mega_animated"
TIMING_FILE = ROOT / "mega_animation_data.lua"
QA_FILE = REVIEW / "INSTALL_QA_REPORT.txt"

PROFILES = (
    ("VENUSAUR", "mega_venusaur"),
    ("CHARIZARD_X", "mega_charizard_x"),
    ("CHARIZARD_Y", "mega_charizard_y"),
    ("BLASTOISE", "mega_blastoise"),
    ("BEEDRILL", "mega_beedrill"),
    ("PIDGEOT", "mega_pidgeot"),
    ("ALAKAZAM", "mega_alakazam"),
    ("SLOWBRO", "mega_slowbro"),
    ("GENGAR", "mega_gengar"),
    ("KANGASKHAN", "mega_kangaskhan"),
    ("PINSIR", "mega_pinsir"),
    ("GYARADOS", "mega_gyarados"),
    ("AERODACTYL", "mega_aerodactyl"),
    ("MEWTWO_X", "mega_mewtwo_x"),
    ("MEWTWO_Y", "mega_mewtwo_y"),
    ("AMPHAROS", "mega_ampharos"),
    ("STEELIX", "mega_steelix"),
    ("SCIZOR", "mega_scizor"),
    ("HERACROSS", "mega_heracross"),
    ("HOUNDOOM", "mega_houndoom"),
    ("TYRANITAR", "mega_tyranitar"),
    ("CLEFABLE", "mega_clefable"),
    ("VICTREEBEL", "mega_victreebel"),
    ("STARMIE", "mega_starmie"),
    ("DRAGONITE", "mega_dragonite"),
    ("MEGANIUM", "mega_meganium"),
    ("FERALIGATR", "mega_feraligatr"),
    ("SKARMORY", "mega_skarmory"),
    ("RAICHU_X", "mega_raichu_x"),
    ("RAICHU_Y", "mega_raichu_y"),
)

VIEWS = {
    "front": ("front", "normal"),
    "back": ("back", "normal"),
    "front_shiny": ("front", "shiny"),
    "back_shiny": ("back", "shiny"),
}


def binary_rgba(image: Image.Image) -> Image.Image:
    out = image.convert("RGBA")
    pixels = out.load()
    for y in range(out.height):
        for x in range(out.width):
            red, green, blue, alpha = pixels[x, y]
            pixels[x, y] = (red, green, blue, 255 if alpha else 0)
    return out


def install_master(key: str, view: str) -> None:
    source = SPRITES / f"{key}_{view}.png"
    if not source.exists():
        raise FileNotFoundError(source)
    image = binary_rgba(Image.open(source))
    if image.size != (96, 96):
        raise ValueError(f"{source}: expected 96x96, got {image.size}")
    image.save(ASSET_SPRITES / source.name, optimize=True)


def install_loop(key: str, view: str) -> list[int]:
    side, variant = VIEWS[view]
    source = ANIMATIONS / f"{key}_{view}.gif"
    if not source.exists():
        raise FileNotFoundError(source)
    # Versions <=5.1 stored flat normal/shiny folders for the single
    # Charizard-X prototype. All current forms are side-aware, so remove
    # those generated legacy branches when replacing a form's pack.
    form_root = ASSET_ANIMATIONS / key
    for legacy_variant in ("normal", "shiny"):
        legacy = form_root / legacy_variant
        if legacy.is_dir():
            shutil.rmtree(legacy)
    target = ASSET_ANIMATIONS / key / side / variant
    target.mkdir(parents=True, exist_ok=True)
    for old in target.glob("*.png"):
        old.unlink()

    durations: list[int] = []
    with Image.open(source) as gif:
        frames = [
            binary_rgba(frame)
            for frame in ImageSequence.Iterator(gif)
        ]
        for frame in ImageSequence.Iterator(gif):
            durations.append(max(20, int(frame.info.get("duration", 90))))
    if len(frames) < 3:
        raise ValueError(f"{source}: animation needs at least three frames")
    for index, frame in enumerate(frames, 1):
        if frame.size != (96, 96):
            raise ValueError(f"{source} frame {index}: got {frame.size}")
        frame.save(target / f"{index:03d}.png", optimize=True)
    if len(durations) != len(frames):
        durations = [90] * len(frames)
    return durations


def lua_array(values: list[int]) -> str:
    return "{ " + ", ".join(str(value) for value in values) + " }"


def secret_timings() -> dict[str, dict[str, list[int]]]:
    root = ASSET_ANIMATIONS / "ascendant_typhlosion"
    crystal = [
        20, 150, 50, 100, 100, 50, 50, 100, 100, 100, 50, 50,
        100, 50, 100, 50, 50, 100, 450, 50, 200, 100, 990,
    ]
    result = {
        "front": {"normal": crystal, "shiny": crystal},
        "back": {"normal": [120] * 12, "shiny": [120] * 12},
    }
    for side, variants in result.items():
        for variant, timings in variants.items():
            count = len(list((root / side / variant).glob("*.png")))
            if count != len(timings):
                raise ValueError(
                    f"secret {side}/{variant}: {count} frames, "
                    f"{len(timings)} timings"
                )
    return result


def write_timing_data(
    timing: dict[str, dict[str, dict[str, list[int]]]]
) -> None:
    lines = [
        "-- Generated by tools/install_all_mega_sprites.py.",
        "-- All official forms use side-aware 96x96 integer-pixel loops.",
        "-- Ascendant Typhlosion's front preserves Crystal #157 timing.",
        "return {",
    ]
    for profile_id, _ in PROFILES:
        lines.append(f'  ["{profile_id}"] = {{')
        for side in ("front", "back"):
            lines.append(f"    {side} = {{")
            for variant in ("normal", "shiny"):
                lines.append(
                    f"      {variant} = "
                    f"{lua_array(timing[profile_id][side][variant])},"
                )
            lines.append("    },")
        lines.append("  },")
    lines.append('  ["TYPHLOSION_ASCENDANT"] = {')
    for side, variants in secret_timings().items():
        lines.append(f"    {side} = {{")
        for variant, values in variants.items():
            lines.append(f"      {variant} = {lua_array(values)},")
        lines.append("    },")
    lines.extend(("  },", "}", ""))
    TIMING_FILE.write_text("\n".join(lines), encoding="utf-8")


def main() -> None:
    ASSET_SPRITES.mkdir(parents=True, exist_ok=True)
    ASSET_ANIMATIONS.mkdir(parents=True, exist_ok=True)
    timing: dict[str, dict[str, dict[str, list[int]]]] = {}
    checks: list[str] = []
    for profile_id, key in PROFILES:
        timing[profile_id] = {"front": {}, "back": {}}
        for view, (side, variant) in VIEWS.items():
            install_master(key, view)
            values = install_loop(key, view)
            timing[profile_id][side][variant] = values
            checks.append(
                f"{profile_id} {side}/{variant}: {len(values)} frames"
            )
    write_timing_data(timing)

    total_frames = 0
    issues: list[str] = []
    for profile_id, key in PROFILES:
        for side in ("front", "back"):
            for variant in ("normal", "shiny"):
                suffix = side + ("_shiny" if variant == "shiny" else "")
                master = Image.open(
                    ASSET_SPRITES / f"{key}_{suffix}.png"
                ).convert("RGBA")
                master_pixels = sum(
                    1 for value in master.getchannel("A").getdata() if value
                )
                directory = ASSET_ANIMATIONS / key / side / variant
                frames = sorted(directory.glob("*.png"))
                total_frames += len(frames)
                for frame in frames:
                    image = Image.open(frame).convert("RGBA")
                    if image.size != (96, 96):
                        issues.append(f"{frame}: wrong size {image.size}")
                    if set(image.getchannel("A").getdata()) - {0, 255}:
                        issues.append(f"{frame}: non-binary alpha")
                    visible = sum(
                        1 for value in image.getchannel("A").getdata() if value
                    )
                    if visible != master_pixels:
                        issues.append(
                            f"{frame}: clipped pixels "
                            f"{visible}/{master_pixels}"
                        )
    QA_FILE.write_text(
        "\n".join(
            [
                "ALL MEGA INSTALL QA",
                "===================",
                f"Official forms: {len(PROFILES)}",
                f"Static masters: {len(PROFILES) * 4}",
                f"Official animation frames: {total_frames}",
                "Canvas: 96x96",
                "Interpolation: none",
                f"Issues: {len(issues)}",
                "",
                *checks,
                *issues,
                "",
            ]
        ),
        encoding="utf-8",
    )
    if issues:
        raise SystemExit("\n".join(issues))
    print(
        f"Installed {len(PROFILES)} Mega forms, "
        f"{len(PROFILES) * 4} masters and {total_frames} animation frames."
    )


if __name__ == "__main__":
    main()
