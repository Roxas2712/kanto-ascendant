#!/usr/bin/env python3
"""Build non-integrated 64/128 review candidates from keyed ImageGen sources.

These files live only below qa/ until the maintainer explicitly accepts them.
The native FRLG 64px fronts remain the visual authority; this script performs
only deterministic background removal, framing, downsampling and quantizing.
"""

from __future__ import annotations

import csv
import os
from pathlib import Path

from PIL import Image, ImageEnhance, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
QA = ROOT / "qa" / "trainer_authentic_rework_20260812"
SOURCE = QA / "source"
OUT = QA / "candidates"
GENERATED_ROOT = Path(os.environ.get("KASC_TRAINER_IMAGE_ROOT", "generated_input"))

ROWS = (
    ("leader_misty", "leader_misty_front_pic.png", "#00ff00",
     "exec-e37a1d09-d60d-4f34-b685-0c285467e76b.png",
     GENERATED_ROOT / "exec-e37a1d09-d60d-4f34-b685-0c285467e76b.png",
     "FRLG age/proportions/outfit/pose; less adult"),
    ("leader_brock", "leader_brock_front_pic.png", "#00ff00",
     "exec-ac90ce35-dabc-4f29-bb7f-a87afbe561e8.png",
     GENERATED_ROOT / "exec-ac90ce35-dabc-4f29-bb7f-a87afbe561e8.png",
     "FRLG lean proportions/outfit/pose; no bodybuilder anatomy"),
    ("lass", "lass_front_pic.png", "#00ff00",
     "exec-2b9974ab-3774-4798-ab1f-4e949e4e458e.png",
     GENERATED_ROOT / "exec-2b9974ab-3774-4798-ab1f-4e949e4e458e.png",
     "FRLG youthful proportions/outfit/pose; no adult reinterpretation"),
    ("youngster", "youngster_front_pic.png", "#00ff00",
     "exec-324f931d-be90-4220-8da5-46b7cbefd56d.png",
     GENERATED_ROOT / "exec-324f931d-be90-4220-8da5-46b7cbefd56d.png",
     "FRLG bald head/youthful proportions/outfit/pose; no cap"),
)


def rgb(hex_colour: str) -> tuple[int, int, int]:
    value = hex_colour.removeprefix("#")
    return tuple(int(value[i:i + 2], 16) for i in (0, 2, 4))


def remove_key(image: Image.Image, key: tuple[int, int, int]) -> Image.Image:
    image = image.convert("RGBA")
    pixels = []
    for red, green, blue, _alpha in image.getdata():
        distance = max(abs(red - key[0]), abs(green - key[1]), abs(blue - key[2]))
        # The generated art uses deliberately hard pixel borders. A hard alpha
        # decision avoids grey/fringed pixels in the in-game renderer.
        alpha = 0 if distance <= 54 else 255
        pixels.append((red, green, blue, alpha))
    image.putdata(pixels)
    return image


def frame(image: Image.Image, size: int, margin: int) -> Image.Image:
    bbox = image.getchannel("A").getbbox()
    if bbox is None:
        raise RuntimeError("empty keyed subject")
    subject = image.crop(bbox)
    available = size - 2 * margin
    scale = min(available / subject.width, available / subject.height)
    width = max(1, round(subject.width * scale))
    height = max(1, round(subject.height * scale))
    subject = subject.resize((width, height), Image.Resampling.LANCZOS)
    subject = ImageEnhance.Contrast(subject).enhance(1.08)
    subject = subject.filter(ImageFilter.UnsharpMask(radius=0.7, percent=90, threshold=3))
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    canvas.alpha_composite(subject, ((size - width) // 2, size - margin - height))
    alpha = canvas.getchannel("A").point(lambda value: 255 if value >= 112 else 0)
    opaque = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    opaque.paste(canvas.convert("RGB"), mask=alpha)
    # Palette excludes the alpha slot: 31 colours at 128px, 23 at 64px.
    colours = 31 if size == 128 else 23
    palette = opaque.convert("RGB").quantize(
        colors=colours, method=Image.Quantize.MEDIANCUT,
        dither=Image.Dither.NONE,
    ).convert("RGBA")
    palette.putalpha(alpha)
    return palette


def main() -> None:
    SOURCE.mkdir(parents=True, exist_ok=True)
    OUT.mkdir(parents=True, exist_ok=True)
    provenance = []
    for stem, authority_name, key_hex, generated_name, generated, note in ROWS:
        if not generated.is_file():
            raise FileNotFoundError(generated)
        source = SOURCE / f"{stem}_v2_chroma.png"
        source.write_bytes(generated.read_bytes())
        keyed = remove_key(Image.open(source), rgb(key_hex))
        hd = frame(keyed, 128, 6)
        low = hd.resize((64, 64), Image.Resampling.NEAREST)
        # Retain the exact binary alpha contract after 2x reduction.
        low.putalpha(low.getchannel("A").point(lambda value: 255 if value else 0))
        hd_path = OUT / f"{stem}_voxel_front_hd_v2.png"
        low_path = OUT / f"{stem}_voxel_front_v2.png"
        hd.save(hd_path, optimize=True)
        low.save(low_path, optimize=True)
        provenance.append({
            "stem": stem,
            "frlg_authority": f"assets/characters/frlg_trainers/{authority_name}",
            "generated_source": generated_name,
            "chroma_key": key_hex,
            "candidate_64": str(low_path.relative_to(ROOT)),
            "candidate_128": str(hd_path.relative_to(ROOT)),
            "status": "REVIEW_ONLY_NOT_INTEGRATED",
            "authority_note": note,
        })
    path = QA / "PROVENANCE.tsv"
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=provenance[0].keys(), delimiter="\t")
        writer.writeheader()
        writer.writerows(provenance)
    print(f"AUTHENTIC TRAINER CANDIDATES: {len(ROWS)} review-only pairs built")


if __name__ == "__main__":
    main()
