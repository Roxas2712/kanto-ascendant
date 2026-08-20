#!/usr/bin/env python3
"""Build the approved Yellow Jessie/James/Meowth staged battle pair.

Both runtime sizes are direct reductions of one exact maintainer-approved
RGBA ImageGen master.  The 128px surface is never enlarged from the 64px
surface.  This tool does not download, regenerate or redesign the source.
"""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
SOURCE_ROOT = ROOT / "assets" / "sources" / "yellow_jessie_james" / "approved"
REVIEW_ROOT = ROOT / "assets" / "sources" / "yellow_jessie_james" / "review"
RUNTIME_ROOT = ROOT / "assets" / "yellow_jessie_james"
REFERENCE_ROOT = ROOT / "assets" / "characters" / "crystal_chars"
TRAINER_ROOT = ROOT / "assets" / "characters" / "frlg_trainers"

MASTER = SOURCE_ROOT / (
    "jessie_james_meowth_battle_master_imagegen_approved_20260820.png"
)
MASTER_SHA256 = "8d4b4af1515b304cb6b1121bceb00078b142706558e589790d6dca5ce137736a"
MASTER_SIZE = (1305, 1206)
MASTER_BBOX = (0, 11, 1257, 1206)

OUTPUTS = {
    "voxel64": {
        "path": RUNTIME_ROOT / "battle" / "jessie_james_meowth_voxel_front.png",
        "size": 64,
        "max": (62, 62),
        "bottom": 1,
        "colors": 32,
        "transform": "approved-rgba-master-direct-lanczos64-hard-alpha-32color-v1",
    },
    "voxel128": {
        "path": RUNTIME_ROOT / "battle" / "jessie_james_meowth_voxel_front_hd.png",
        "size": 128,
        "max": (124, 124),
        "bottom": 2,
        "colors": 64,
        "transform": "approved-rgba-master-direct-lanczos128-hard-alpha-64color-v1",
    },
}


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load_master() -> Image.Image:
    if sha256(MASTER) != MASTER_SHA256:
        raise RuntimeError("approved Jessie/James/Meowth master hash changed")
    opened = Image.open(MASTER)
    if opened.mode != "RGBA" or opened.size != MASTER_SIZE:
        raise RuntimeError(
            f"unexpected approved master: mode={opened.mode} size={opened.size}"
        )
    alpha = opened.getchannel("A")
    if alpha.getbbox() != MASTER_BBOX:
        raise RuntimeError(f"approved master alpha bbox changed: {alpha.getbbox()}")
    alpha_values = set(alpha.getdata())
    if not ({0, 255} <= alpha_values and alpha_values - {0, 255}):
        raise RuntimeError("approved master no longer carries genuine soft alpha")
    return opened


def quantize_visible(source: Image.Image, colors: int,
                     alpha_threshold: int = 80) -> Image.Image:
    rgba = source.convert("RGBA")
    alpha = rgba.getchannel("A").point(
        lambda value: 255 if value >= alpha_threshold else 0
    )
    visible = [
        pixel[:3]
        for pixel, mask in zip(rgba.getdata(), alpha.getdata())
        if mask
    ]
    if not visible:
        raise RuntimeError("empty sprite after hard-alpha projection")
    samples = Image.new("RGB", (len(visible), 1))
    samples.putdata(visible)
    palette = samples.quantize(
        colors=colors, method=Image.Quantize.MEDIANCUT,
        dither=Image.Dither.NONE,
    )
    mapped = rgba.convert("RGB").quantize(
        palette=palette, dither=Image.Dither.NONE
    ).convert("RGBA")
    mapped.putalpha(alpha)
    return mapped


def direct_surface(master: Image.Image, spec: dict) -> Image.Image:
    crop = master.crop(MASTER_BBOX)
    max_width, max_height = spec["max"]
    scale = min(max_width / crop.width, max_height / crop.height)
    size = (
        max(1, round(crop.width * scale)),
        max(1, round(crop.height * scale)),
    )
    reduced = crop.resize(size, Image.Resampling.LANCZOS)
    sprite = quantize_visible(reduced, spec["colors"])
    canvas_size = spec["size"]
    output = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    output.alpha_composite(
        sprite,
        ((canvas_size - size[0]) // 2,
         canvas_size - size[1] - spec["bottom"]),
    )
    return output


def write_png(image: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, format="PNG", optimize=False, compress_level=9)


def verify_surface(path: Path, spec: dict) -> dict:
    image = Image.open(path).convert("RGBA")
    expected = (spec["size"], spec["size"])
    if image.size != expected:
        raise RuntimeError(f"{path}: expected {expected}, got {image.size}")
    alpha = set(image.getchannel("A").getdata())
    if alpha != {0, 255}:
        raise RuntimeError(f"{path}: alpha is not binary: {sorted(alpha)}")
    corners = ((0, 0), (expected[0] - 1, 0),
               (0, expected[1] - 1), (expected[0] - 1, expected[1] - 1))
    if any(image.getpixel(point)[3] for point in corners):
        raise RuntimeError(f"{path}: transparent-corner contract failed")
    opaque = [pixel for pixel in image.getdata() if pixel[3]]
    palette = len(set(opaque))
    if palette > spec["colors"]:
        raise RuntimeError(f"{path}: palette {palette} > {spec['colors']}")
    return {
        "size": list(expected),
        "binaryAlpha": True,
        "transparentCorners": True,
        "opaquePixels": len(opaque),
        "opaquePalette": palette,
        "sha256": sha256(path),
    }


def checker(size: tuple[int, int], cell: int = 8) -> Image.Image:
    image = Image.new("RGBA", size, (43, 47, 57, 255))
    draw = ImageDraw.Draw(image)
    colors = ((75, 81, 94, 255), (55, 60, 71, 255))
    for y in range(0, size[1], cell):
        for x in range(0, size[0], cell):
            draw.rectangle(
                (x, y, min(x + cell - 1, size[0] - 1),
                 min(y + cell - 1, size[1] - 1)),
                fill=colors[(x // cell + y // cell) % 2],
            )
    return image


def label(canvas: Image.Image, text: str, x: int, y: int,
          color=(238, 241, 247, 255)) -> None:
    font = ImageFont.load_default()
    scratch = Image.new("RGBA", (max(1, len(text) * 8 + 8), 18),
                        (0, 0, 0, 0))
    ImageDraw.Draw(scratch).text((2, 2), text, font=font, fill=color)
    scratch = scratch.resize((scratch.width * 2, scratch.height * 2),
                             Image.Resampling.NEAREST)
    canvas.alpha_composite(scratch, (x, y))


def preview(canvas: Image.Image, image: Image.Image, x: int, y: int,
            scale: int) -> None:
    scaled = image.resize((image.width * scale, image.height * scale),
                          Image.Resampling.NEAREST)
    background = checker(scaled.size)
    background.alpha_composite(scaled)
    canvas.alpha_composite(background, (x, y))


def build_review(generated: dict[str, Image.Image]) -> None:
    canvas = Image.new("RGBA", (2760, 1180), (24, 27, 34, 255))
    label(canvas,
          "KANTO ASCENDANT - YELLOW JESSIE / JAMES / MEOWTH - APPROVED 2026-08-20",
          34, 22)
    label(canvas,
          "HD128 nearest comparison against exact Red / Blue / Green and generic Rocket",
          34, 70, (174, 183, 202, 255))
    comparisons = [
        ("RED", REFERENCE_ROOT / "red_voxel_front_hd.png"),
        ("BLUE", REFERENCE_ROOT / "blue_voxel_front_hd.png"),
        ("GREEN", REFERENCE_ROOT / "green_voxel_front_hd.png"),
        ("GENERIC ROCKET", TRAINER_ROOT / "rocket_grunt_m_voxel_front_hd_v2.png"),
    ]
    for index, (name, path) in enumerate(comparisons):
        x = 34 + index * 540
        label(canvas, name, x, 118)
        preview(canvas, Image.open(path).convert("RGBA"), x, 160, 3)
    label(canvas, "JESSIE / JAMES / MEOWTH", 2194, 118)
    preview(canvas, generated["voxel128"], 2194, 160, 3)

    label(canvas,
          "Runtime pair: independent direct reductions from the same approved RGBA master",
          34, 600, (174, 183, 202, 255))
    label(canvas, "64x64 @ 6x", 34, 650)
    preview(canvas, generated["voxel64"], 34, 692, 6)
    label(canvas, "128x128 @ 3x", 500, 650)
    preview(canvas, generated["voxel128"], 500, 692, 3)
    fallback = Image.open(
        ROOT / "assets" / "crystal_v15" / "trainers" / "normal"
        / "jessie_james.png"
    ).convert("RGBA")
    label(canvas, "EXACT 56px DUO FAIL-SAFE @ 6x", 966, 650)
    preview(canvas, fallback, 966, 692, 6)
    label(canvas,
          "Identity gate: Yellow OPP_ROCKET partyIndex >= 42 only. Ordinary Rockets unchanged.",
          34, 1128, (174, 183, 202, 255))
    REVIEW_ROOT.mkdir(parents=True, exist_ok=True)
    write_png(canvas, REVIEW_ROOT / "jessie_james_meowth_contact_sheet.png")


def main() -> None:
    master = load_master()
    generated = {
        name: direct_surface(master, spec) for name, spec in OUTPUTS.items()
    }
    for name, image in generated.items():
        write_png(image, OUTPUTS[name]["path"])
    validation = {
        name: verify_surface(spec["path"], spec)
        for name, spec in OUTPUTS.items()
    }

    source_receipt = {
        "path": str(MASTER.relative_to(ROOT)),
        "sha256": MASTER_SHA256,
        "size": list(MASTER_SIZE),
        "mode": "RGBA",
        "alphaBbox": list(MASTER_BBOX),
        "artifact": "exec-37308b82-3890-4a98-beea-d7279431bfa7",
        "credit": (
            "OpenAI ImageGen output; exact Jessie/James/Meowth design selected "
            "and approved by the Kanto Ascendant maintainer on 2026-08-20"
        ),
        "permission": (
            "imagegen-derived-pokemon-fan-art-maintainer-approved-"
            "no-broader-rights-claimed"
        ),
        "policy": (
            "project visual approval only; underlying Pokemon character "
            "rights remain with their respective owners"
        ),
    }
    assets = {}
    for name, spec in OUTPUTS.items():
        assets[name] = {
            "path": str(spec["path"].relative_to(ROOT)),
            "sha256": validation[name]["sha256"],
            "sourceSha256": MASTER_SHA256,
            "transform": spec["transform"],
            "approved": True,
            "visualStatus": "approved-by-maintainer-2026-08-20",
            **{key: value for key, value in validation[name].items()
               if key != "sha256"},
        }
    receipt = {
        "schema": "kanto-ascendant-yellow-jessie-james-battle/v1",
        "approved": True,
        "visualStatus": "approved-by-maintainer-2026-08-20",
        "maintainerApproval": {
            "decision": "approved",
            "date": "2026-08-20",
            "scope": "jessie-james-meowth-voxel64-voxel128",
        },
        "identity": {
            "edition": "yellow",
            "class": "OPP_ROCKET",
            "minimumPartyIndex": 42,
            "requires": {"jessie": True, "james": True, "meowth": True},
        },
        "ownership": "imagegen-fan-art-maintainer-approved",
        "source": source_receipt,
        "assets": assets,
        "failSafe": {
            "path": "assets/crystal_v15/trainers/normal/jessie_james.png",
            "sha256": "c6c086d954fe828be6f407438e0c6203d19c6d32a427c4fc2773a4ec9d65e46f",
            "role": "exact-bundled-yellow-duo",
        },
    }
    SOURCE_ROOT.mkdir(parents=True, exist_ok=True)
    RUNTIME_ROOT.mkdir(parents=True, exist_ok=True)
    text = json.dumps(receipt, indent=2, sort_keys=True) + "\n"
    (SOURCE_ROOT / "manifest.json").write_text(text, encoding="utf-8")
    (RUNTIME_ROOT / "PROVENANCE.json").write_text(text, encoding="utf-8")
    build_review(generated)


if __name__ == "__main__":
    main()
