#!/usr/bin/env python3
"""Build nine non-integrated normal-trainer approval candidates."""

from __future__ import annotations

import csv
import os
from pathlib import Path

from PIL import Image, ImageEnhance, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
QA = ROOT / "qa" / "trainer_full_normal_rework_20260812"
SOURCE = QA / "source"
OUT = QA / "candidates"

GENERATED_ROOT = Path(os.environ.get("KASC_NORMAL_TRAINER_IMAGE_ROOT", "generated_input"))
ROWS = (
    ("fisherman", "exec-218777b4-a102-4ec9-93ea-3e6f0c0df553.png",
     "FRLG seated fisherman, cap/vest/tackle box/rod/line/float"),
    ("gamer", "exec-2df92a42-b607-4ee8-b6fc-554042538782.png",
     "FRLG elderly bald bearded seated player, blue robe and tan bag"),
    ("hiker", "exec-f2f561ce-c275-45f5-bb20-dce97055c51d.png",
     "FRLG mountain hiker, hat, huge backpack and staff"),
    ("juggler", "exec-3fc4d55e-46fe-4ce8-a79c-269f7aa8b792.png",
     "FRLG stage juggler, purple cap/cape/trousers and juggling balls"),
    ("psychic_m", "exec-966fb66f-252a-46f8-9162-6f524feaf5d0.png",
     "FRLG lavender hair, teal-gold outfit and pink psychic orbs"),
    ("rocker", "exec-a8a1050f-d884-4379-a172-825c43ece2de.png",
     "FRLG spiky hair, orange jacket, cable and electrical spark"),
    ("sailor", "exec-dc63e746-bc87-4e79-99b2-a3ac848f3b42.png",
     "FRLG white-blue sailor uniform and salute"),
    ("swimmer_m", "exec-85d3d960-cba8-44cc-aaa3-f25a0cc277f3.png",
     "FRLG male swimmer, blue cap/trunks and forward running pose"),
    ("tamer", "exec-a6282f3e-ba0f-4c9d-84ae-b5a1ed12411e.png",
     "FRLG grey tamer outfit, ring and arcing whip"),
)


def remove_green(image: Image.Image) -> Image.Image:
    image = image.convert("RGBA")
    pixels = []
    for red, green, blue, _alpha in image.getdata():
        # Generated sources are deliberately pure-green dominant.  The
        # component rule tolerates minor edge compression without eating teal
        # clothes or blue effects.
        keyed = green >= 175 and green >= red * 1.48 and green >= blue * 1.42
        pixels.append((red, green, blue, 0 if keyed else 255))
    image.putdata(pixels)
    return image


def frame(image: Image.Image) -> Image.Image:
    box = image.getchannel("A").getbbox()
    if box is None:
        raise RuntimeError("empty keyed subject")
    subject = image.crop(box)
    available = 116
    scale = min(available / subject.width, available / subject.height)
    size = (max(1, round(subject.width * scale)), max(1, round(subject.height * scale)))
    subject = subject.resize(size, Image.Resampling.LANCZOS)
    subject = ImageEnhance.Contrast(subject).enhance(1.08)
    subject = subject.filter(ImageFilter.UnsharpMask(radius=0.7, percent=90, threshold=3))
    canvas = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    canvas.alpha_composite(subject, ((128 - size[0]) // 2, 122 - size[1]))
    alpha = canvas.getchannel("A").point(lambda value: 255 if value >= 112 else 0)
    opaque = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    opaque.paste(canvas.convert("RGB"), mask=alpha)
    palette = opaque.convert("RGB").quantize(colors=47, method=Image.Quantize.MEDIANCUT,
                                              dither=Image.Dither.NONE).convert("RGBA")
    palette.putalpha(alpha)
    return palette


def main() -> None:
    SOURCE.mkdir(parents=True, exist_ok=True)
    OUT.mkdir(parents=True, exist_ok=True)
    provenance = []
    for stem, generated_name, note in ROWS:
        generated = GENERATED_ROOT / generated_name
        if not generated.is_file():
            raise FileNotFoundError(generated)
        source = SOURCE / f"{stem}_v2_chroma.png"
        source.write_bytes(generated.read_bytes())
        hd = frame(remove_green(Image.open(source)))
        low = hd.resize((64, 64), Image.Resampling.NEAREST)
        low.putalpha(low.getchannel("A").point(lambda value: 255 if value else 0))
        hd_path = OUT / f"{stem}_voxel_front_hd_v2.png"
        low_path = OUT / f"{stem}_voxel_front_v2.png"
        hd.save(hd_path, optimize=True)
        low.save(low_path, optimize=True)
        provenance.append({
            "stem": stem,
            "frlg_authority": f"assets/characters/frlg_trainers/{stem}_front_pic.png",
            "selected_imagegen_source": generated_name,
            "chroma_key": "#00ff00",
            "candidate_64": low_path.relative_to(ROOT).as_posix(),
            "candidate_128": hd_path.relative_to(ROOT).as_posix(),
            "status": "REVIEW_ONLY_NOT_INTEGRATED",
            "authority_note": note,
        })
    with (QA / "PROVENANCE.tsv").open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=provenance[0].keys(), delimiter="\t")
        writer.writeheader()
        writer.writerows(provenance)
    print(f"FULL NORMAL TRAINER CANDIDATES: {len(provenance)} review-only pairs built")


if __name__ == "__main__":
    main()
