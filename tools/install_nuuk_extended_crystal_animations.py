#!/usr/bin/env python3
"""Install identity-correct authored Crystal motion for private slots #252-279.

The source archives are pokecrystal-ready sprite packs.  Their ``front.png``
files are vertical sheets containing the base pose followed by every authored
animation pose; ``anim.asm`` is the exact frame script.  This builder expands
that script (including its real repeat commands), crops only those authored
poses and applies the archive's own normal/shiny palettes.  It never creates
movement by shifting, scaling or otherwise deforming a still image.

Crystal has no animated rear-pic format.  Each supplied ``back.png`` is kept
as one honest static normal/shiny frame instead of pretending it is animated.
The supplied Nuuk archive set covers twenty-one registered species.  The seven
remaining exact identities are sourced from Polished Crystal's authored
vertical sheets and ``anim.asm`` scripts at a pinned public source commit.
Both formats contain real drawn poses; neither path invents movement by
shifting, scaling or deforming one image.
"""

from __future__ import annotations

import argparse
import hashlib
import io
import json
import re
import subprocess
import tempfile
import zipfile
from collections import deque
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / "assets" / "crystal_animated"
DATA = ROOT / "extended_crystal_animation_data.lua"
MANIFEST = ROOT / "assets" / "crystal_animated" / "extended_252_279_motion_sources.json"
DEFAULT_SOURCE = Path.home() / "Downloads" / "Crystal GFX files"
DEFAULT_POLISHED_SOURCE = Path.home() / "Downloads" / "polishedcrystal"
POLISHED_SOURCE_COMMIT = "4a440ffdecd821ae1b724d6df88280a3f89f158d"
POLISHED_SOURCE_ARCHIVE_SHA256 = (
    "184ac0ef4eb50db3dea78e2a4dad03807e7dc4b696e9a3248aa0b7bb84a9deb5"
)

# (private/runtime Dex, registered species, National/source Dex, Nuuk slug).
# A nil Nuuk slug is deliberate: that exact identity comes from the pinned
# Polished Crystal source below. Never substitute another National-Dex species
# merely because its number matches the private slot.
SPECIES = (
    (252, "TREECKO", 252, "treecko"),
    (253, "GROVYLE", 253, "grovyle"),
    (254, "SCEPTILE", 254, "sceptile"),
    (255, "TORCHIC", 255, "torchic"),
    (256, "COMBUSKEN", 256, "combusken"),
    (257, "BLAZIKEN", 257, "blaziken"),
    (258, "MUDKIP", 258, "mudkip"),
    (259, "MARSHTOMP", 259, "marshtomp"),
    (260, "SWAMPERT", 260, "swampert"),
    (261, "AMBIPOM", 424, None),
    (262, "MISMAGIUS", 429, None),
    (263, "HONCHKROW", 430, "honchkrow"),
    (264, "WEAVILE", 461, "weavile"),
    (265, "MAGNEZONE", 462, "magnezone"),
    (266, "LICKILICKY", 463, None),
    (267, "RHYPERIOR", 464, None),
    (268, "TANGROWTH", 465, None),
    (269, "ELECTIVIRE", 466, "electivire"),
    (270, "MAGMORTAR", 467, "magmortar"),
    (271, "TOGEKISS", 468, "togekiss"),
    (272, "YANMEGA", 469, None),
    (273, "LEAFEON", 470, "leafeon"),
    (274, "GLACEON", 471, "glaceon"),
    (275, "GLISCOR", 472, "gliscor"),
    (276, "MAMOSWINE", 473, "mamoswine"),
    (277, "PORYGON_Z", 474, "porygon_z"),
    (278, "AZURILL", 298, "azurill"),
    (279, "WYNAUT", 360, None),
)

POLISHED_SLUGS = {
    261: "ambipom",
    262: "mismagius",
    266: "lickilicky",
    267: "rhyperior",
    268: "tangrowth",
    272: "yanmega",
    279: "wynaut",
}

TICK_MS = 1000.0 / 60.0
BASE_HOLD_TICKS = 18  # pokecrystal PokeAnim_SetWait


def sha256(body: bytes) -> str:
    return hashlib.sha256(body).hexdigest()


def png_bytes(image: Image.Image) -> bytes:
    output = io.BytesIO()
    image.save(output, format="PNG", optimize=True)
    return output.getvalue()


def write_if_changed(path: Path, body: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists() and path.read_bytes() == body:
        return
    with tempfile.NamedTemporaryFile(
        dir=path.parent, prefix=".nuuk-frame-", suffix=path.suffix, delete=False
    ) as handle:
        temp = Path(handle.name)
        handle.write(body)
    try:
        temp.replace(path)
    finally:
        temp.unlink(missing_ok=True)


def parse_number(raw: str) -> int:
    raw = raw.strip()
    if raw.startswith("$"):
        return int(raw[1:], 16)
    return int(raw, 10)


def parse_animation(body: str) -> tuple[list[int], list[int]]:
    """Return expanded authored frame indices and durations in GB ticks."""
    commands: list[tuple[str, int, int | None]] = []
    for source_line in body.splitlines():
        line = source_line.split(";", 1)[0].strip()
        if not line:
            continue
        match = re.fullmatch(r"frame\s+([^,]+),\s*(\S+)", line)
        if match:
            commands.append(
                ("frame", parse_number(match.group(1)), parse_number(match.group(2)))
            )
            continue
        match = re.fullmatch(r"setrepeat\s+(\S+)", line)
        if match:
            commands.append(("setrepeat", parse_number(match.group(1)), None))
            continue
        match = re.fullmatch(r"dorepeat\s+(\S+)", line)
        if match:
            commands.append(("dorepeat", parse_number(match.group(1)), None))
            continue
        if line == "endanim":
            commands.append(("endanim", 0, None))
            continue
        raise ValueError(f"unsupported pokecrystal animation command: {line!r}")

    frames = [0]
    durations = [BASE_HOLD_TICKS]
    pc, repeat_timer, guard = 0, 0, 0
    while pc < len(commands):
        guard += 1
        if guard > 4096:
            raise ValueError("animation script did not terminate")
        command, parameter, duration = commands[pc]
        if command == "frame":
            frames.append(parameter)
            durations.append(int(duration or 1))
            pc += 1
        elif command == "setrepeat":
            repeat_timer = parameter
            pc += 1
        elif command == "dorepeat":
            if repeat_timer == 0:
                pc += 1
                continue
            repeat_timer -= 1
            if repeat_timer:
                if not (0 <= parameter < len(commands)):
                    raise ValueError(f"dorepeat target {parameter} is out of range")
                pc = parameter
            else:
                pc += 1
        elif command == "endanim":
            break
        else:  # pragma: no cover - parser makes this unreachable
            raise AssertionError(command)
    if len(frames) < 3 or len(set(frames)) < 2:
        raise ValueError("source does not contain a meaningful multi-pose animation")
    return frames, durations


def rgb5(value: int) -> int:
    return round(value * 255 / 31)


def bgr555_palette(body: bytes) -> list[tuple[int, int, int]]:
    if len(body) != 8:
        raise ValueError(f"front.gbcpal must contain four colours, got {len(body)} bytes")
    colours = []
    for offset in range(0, 8, 2):
        value = body[offset] | body[offset + 1] << 8
        colours.append(
            (rgb5(value & 31), rgb5((value >> 5) & 31), rgb5((value >> 10) & 31))
        )
    return colours


def shiny_palette(body: str) -> list[tuple[int, int, int]]:
    colours = []
    for line in body.splitlines():
        match = re.search(r"RGB\s+(\d+)\s*,\s*(\d+)\s*,\s*(\d+)", line)
        if match:
            colours.append(tuple(rgb5(int(value)) for value in match.groups()))
    if len(colours) != 2:
        raise ValueError(f"shiny.pal must contain two colours, got {len(colours)}")
    return colours


def apply_text_palette(
    image: Image.Image, colours: list[tuple[int, int, int]]
) -> Image.Image:
    """Colour a Polished Crystal four-shade grayscale sheet exactly once."""
    if len(colours) != 2:
        raise ValueError(f"expected two authored midtones, got {len(colours)}")
    source = image.convert("L")
    if set(source.getdata()) - {0, 85, 170, 255}:
        raise ValueError("Polished Crystal sheet is not exact 2-bit grayscale")
    output = Image.new("RGBA", source.size)
    mapping = {
        0: (0, 0, 0, 255),
        85: (*colours[1], 255),
        170: (*colours[0], 255),
        255: (255, 255, 255, 255),
    }
    output.putdata([mapping[value] for value in source.getdata()])
    return output


def distance(a: tuple[int, int, int], b: tuple[int, int, int]) -> int:
    return sum((x - y) ** 2 for x, y in zip(a, b))


def recolour_shiny(
    image: Image.Image,
    normal_palette: list[tuple[int, int, int]],
    shiny_colours: list[tuple[int, int, int]],
) -> Image.Image:
    image = image.convert("RGBA")
    pixels = image.load()
    # The source sheets are RGB exports of this exact four-colour GBC
    # palette.  Associate their two midtones with gbcpal entries 1/2 by
    # nearest colour so rgbgfx's rounding differences cannot swap them.
    authored_colours = sorted(
        {
            pixel[:3]
            for pixel in image.getdata()
            if pixel[:3] not in {(0, 0, 0), (255, 255, 255)}
        }
    )
    mapping: dict[tuple[int, int, int], tuple[int, int, int]] = {}
    # A handful of Nuuk's rear PNG exports contain a near-black (16,16,16)
    # in addition to literal black.  Classify every source colour against
    # the archive's own four-colour gbcpal: only colours belonging to either
    # midtone are palette-swapped, while black/white variants remain intact.
    for source in authored_colours:
        palette_index = min(
            range(4), key=lambda index: distance(source, normal_palette[index])
        )
        if palette_index == 1:
            mapping[source] = shiny_colours[0]
        elif palette_index == 2:
            mapping[source] = shiny_colours[1]
    for y in range(image.height):
        for x in range(image.width):
            r, g, b, alpha = pixels[x, y]
            replacement = mapping.get((r, g, b))
            if replacement:
                pixels[x, y] = (*replacement, alpha)
    return image


def transparent_border(image: Image.Image) -> Image.Image:
    """Key only the border-connected card colour; preserve white bodies."""
    image = image.convert("RGBA")
    pixels = image.load()
    background = pixels[0, 0][:3]
    queue: deque[tuple[int, int]] = deque()
    seen: set[tuple[int, int]] = set()
    for x in range(image.width):
        queue.append((x, 0))
        queue.append((x, image.height - 1))
    for y in range(image.height):
        queue.append((0, y))
        queue.append((image.width - 1, y))
    while queue:
        x, y = queue.popleft()
        if (x, y) in seen:
            continue
        seen.add((x, y))
        if pixels[x, y][:3] != background:
            continue
        pixels[x, y] = (*background, 0)
        for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
            if 0 <= nx < image.width and 0 <= ny < image.height:
                queue.append((nx, ny))
    return image


def lua_data(rows: dict[int, dict[str, object]]) -> str:
    lines = [
        "-- Generated by tools/install_nuuk_extended_crystal_animations.py.",
        "-- Listed fronts are authored Nuuk/Polished Crystal poses.",
        "-- All supplied Crystal backs contain one pose and remain static.",
        "return {",
        "  normal = {",
    ]
    for dex, row in rows.items():
        durations = ", ".join(str(value) for value in row["durations_ms"])
        lines.append(f'    ["{dex}"] = {{ {durations} }},')
    lines.extend(("  },", "  shiny = {"))
    for dex, row in rows.items():
        durations = ", ".join(str(value) for value in row["durations_ms"])
        lines.append(f'    ["{dex}"] = {{ {durations} }},')
    lines.extend(("  },", "  back = {", "    normal = {"))
    for dex in rows:
        lines.append(f'      ["{dex}"] = {{ 1000 }},')
    lines.extend(("    },", "    shiny = {"))
    for dex in rows:
        lines.append(f'      ["{dex}"] = {{ 1000 }},')
    lines.extend(("    },", "  },", "}", ""))
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-dir", type=Path, default=DEFAULT_SOURCE)
    parser.add_argument(
        "--polished-dir", type=Path, default=DEFAULT_POLISHED_SOURCE,
        help="Polished Crystal checkout pinned to the recorded source commit",
    )
    args = parser.parse_args()
    source_dir = args.source_dir.expanduser().resolve()
    polished_dir = args.polished_dir.expanduser().resolve()
    readme = source_dir / "README.txt"
    if not readme.is_file() or "sprites done by Nuuk" not in readme.read_text(
        encoding="utf-8", errors="replace"
    ):
        raise RuntimeError(f"{source_dir} is not the expected Nuuk Crystal GFX pack")
    try:
        polished_commit = subprocess.check_output(
            ["git", "-C", str(polished_dir), "rev-parse", "HEAD"],
            text=True,
        ).strip()
    except (OSError, subprocess.CalledProcessError) as error:
        raise RuntimeError(
            f"{polished_dir} is not a readable Polished Crystal checkout"
        ) from error
    if polished_commit != POLISHED_SOURCE_COMMIT:
        raise RuntimeError(
            "Polished Crystal source drift: expected "
            f"{POLISHED_SOURCE_COMMIT}, got {polished_commit}"
        )
    polished_credits = (polished_dir / "CREDITS.md").read_bytes()

    rows: dict[int, dict[str, object]] = {}
    manifest_rows = []
    for dex, species, source_dex, slug in SPECIES:
        polished_slug = POLISHED_SLUGS.get(dex)
        if slug is not None:
            provider = "Nuuk Crystal GFX pack"
            archive_path = source_dir / f"{slug}.zip"
            archive_body = archive_path.read_bytes()
            with zipfile.ZipFile(io.BytesIO(archive_body)) as archive:
                # Nuuk's archive filename keeps the underscore while its
                # pokecrystal directory uses the canonical no-punctuation id.
                archive_slug = "porygonz" if slug == "porygon_z" else slug
                prefix = f"{archive_slug}/"
                names = {
                    name: archive.read(prefix + name)
                    for name in (
                        "front.png",
                        "back.png",
                        "front.gbcpal",
                        "shiny.pal",
                        "anim.asm",
                    )
                }
            source_ref = {
                "sourceProvider": provider,
                "sourceZip": archive_path.name,
                "sourceZipSha256": sha256(archive_body),
            }
            normal_palette = bgr555_palette(names["front.gbcpal"])
            shiny_colours = shiny_palette(names["shiny.pal"].decode("utf-8"))
            source_sheet = Image.open(io.BytesIO(names["front.png"])).convert("RGBA")
            normal_sheet = source_sheet
            shiny_sheet = recolour_shiny(
                source_sheet, normal_palette, shiny_colours
            )
            normal_back_source = Image.open(io.BytesIO(names["back.png"])).convert(
                "RGBA"
            )
            shiny_back_source = recolour_shiny(
                normal_back_source, normal_palette, shiny_colours
            )
        elif polished_slug is not None:
            provider = "Pokemon Polished Crystal"
            sprite_dir = polished_dir / "gfx" / "pokemon" / polished_slug
            names = {
                name: (sprite_dir / name).read_bytes()
                for name in (
                    "front.png",
                    "back.png",
                    "normal.pal",
                    "shiny.pal",
                    "anim.asm",
                    "anim_idle.asm",
                )
            }
            source_ref = {
                "sourceProvider": provider,
                "sourceRepository": "https://github.com/Rangi42/polishedcrystal",
                "sourceCommit": polished_commit,
                "sourceArchiveSha256": POLISHED_SOURCE_ARCHIVE_SHA256,
                "sourcePath": f"gfx/pokemon/{polished_slug}",
                "sourceCreditsSha256": sha256(polished_credits),
            }
            normal_colours = shiny_palette(names["normal.pal"].decode("utf-8"))
            shiny_colours = shiny_palette(names["shiny.pal"].decode("utf-8"))
            source_sheet = Image.open(io.BytesIO(names["front.png"]))
            normal_sheet = apply_text_palette(source_sheet, normal_colours)
            shiny_sheet = apply_text_palette(source_sheet, shiny_colours)
            back_source = Image.open(io.BytesIO(names["back.png"]))
            normal_back_source = apply_text_palette(back_source, normal_colours)
            shiny_back_source = apply_text_palette(back_source, shiny_colours)
        else:  # pragma: no cover - catalogue constants make this unreachable
            raise RuntimeError(f"#{dex} {species}: no exact authored source mapping")
        source_label = slug or polished_slug or species.lower()
        if normal_sheet.height % normal_sheet.width:
            raise ValueError(
                f"{source_label}: front.png is not a vertical square-frame sheet"
            )
        if shiny_sheet.size != normal_sheet.size:
            raise ValueError(f"{source_label}: normal/shiny sheet sizes disagree")
        source_frame_count = normal_sheet.height // normal_sheet.width
        frame_indices, ticks = parse_animation(names["anim.asm"].decode("utf-8"))
        if max(frame_indices) >= source_frame_count:
            raise ValueError(
                f"{source_label}: script references frame {max(frame_indices)}, "
                f"but sheet has {source_frame_count} poses"
            )
        durations_ms = [max(20, round(value * TICK_MS)) for value in ticks]

        normal_hashes, shiny_hashes = [], []
        for runtime_index, source_index in enumerate(frame_indices, 1):
            size = normal_sheet.width
            crop_box = (0, source_index * size, size, (source_index + 1) * size)
            normal = transparent_border(normal_sheet.crop(crop_box))
            shiny = transparent_border(shiny_sheet.crop(crop_box))
            for variant, image, hashes in (
                ("normal", normal, normal_hashes),
                ("shiny", shiny, shiny_hashes),
            ):
                body = png_bytes(image)
                hashes.append(sha256(body))
                write_if_changed(
                    DEST / "front" / variant / str(dex) / f"{runtime_index:03d}.png",
                    body,
                )

        back_normal = transparent_border(normal_back_source)
        back_shiny = transparent_border(shiny_back_source)
        back_hashes = {}
        for variant, image in (("normal", back_normal), ("shiny", back_shiny)):
            body = png_bytes(image)
            back_hashes[variant] = sha256(body)
            write_if_changed(
                DEST / "back" / variant / str(dex) / "001.png", body
            )

        # Fail closed on stale output from an earlier sequence.  These exact
        # dex directories are owned by this installer and did not exist in
        # the native #001-251 pack.
        for variant in ("normal", "shiny"):
            target = DEST / "front" / variant / str(dex)
            expected = {f"{index:03d}.png" for index in range(1, len(frame_indices) + 1)}
            for old in target.glob("*.png"):
                if old.name not in expected:
                    old.unlink()

        rows[dex] = {"durations_ms": durations_ms}
        manifest_rows.append(
            source_ref | {
                "internalRuntimeDex": dex,
                "sourceDex": source_dex,
                "species": species,
                "motionStatus": "authored_front_static_back",
                "sourceEntriesSha256": {
                    name: sha256(body) for name, body in sorted(names.items())
                },
                "sourcePoseCount": source_frame_count,
                "runtimeFrontFrameCount": len(frame_indices),
                "authoredSourceFrameIndices": frame_indices,
                "durationsMs": durations_ms,
                "normalFrameSha256": normal_hashes,
                "shinyFrameSha256": shiny_hashes,
                "backMotion": "authored_static_only",
                "backFrameSha256": back_hashes,
            }
        )
        print(
            f"#{dex} {source_label:10} {len(frame_indices):2} authored front steps; "
            f"1 static rear pose ({provider})"
        )

    write_if_changed(DATA, lua_data(rows).encode("utf-8"))
    manifest = {
        "schema": 2,
        "sources": [
            {
                "provider": "Nuuk Crystal GFX pack",
                "sourceReadmeSha256": sha256(readme.read_bytes()),
                "licenseNote": (
                    "Free to use/edit; do not use for profit or claim as your own."
                ),
            },
            {
                "provider": "Pokemon Polished Crystal",
                "repository": "https://github.com/Rangi42/polishedcrystal",
                "commit": polished_commit,
                "sourceArchive": (
                    "https://github.com/Rangi42/polishedcrystal/"
                    "archive/refs/heads/master.tar.gz"
                ),
                "sourceArchiveSha256": POLISHED_SOURCE_ARCHIVE_SHA256,
                "creditsSha256": sha256(polished_credits),
                "creditNotice": (
                    "Artist attribution is retained from the source CREDITS.md; "
                    "no top-level license file was present at the pinned commit."
                ),
            },
        ],
        "internalRuntimeDexRange": [252, 279],
        "identityRule": "species key + sourceDex; never infer National identity from private slot",
        "frontMotion": "authored anim.asm frames; no procedural transforms",
        "backMotion": "not animated: supplied Crystal backs contain one authored pose",
        "rows": manifest_rows,
    }
    write_if_changed(
        MANIFEST,
        (json.dumps(manifest, indent=2, sort_keys=True) + "\n").encode("utf-8"),
    )
    print(
        f"installed {len(rows)} authored normal/shiny front loops; "
        "all supplied Crystal rears remain honest one-pose art"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
