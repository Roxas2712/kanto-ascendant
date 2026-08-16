#!/usr/bin/env python3
"""Build six review-only trainer candidates from accepted keyed sources."""

from __future__ import annotations

import csv
import shutil
from pathlib import Path

from PIL import Image, ImageEnhance, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
QA = ROOT / "qa" / "trainer_full_normal_rework_root_20260812"
SOURCE = QA / "source"
OUT = QA / "candidates"
KEY = (0, 255, 0)

ROWS = (
    ("beauty", "exec-de5e5f49-4f8e-4470-8b45-e32b6067dc98.png", "FRLG blonde hair, blue-white top, red skirt, empty hand pose"),
    ("biker", "exec-fd02b2df-601c-4611-8dec-1718571174c4.png", "FRLG stocky biker and motorcycle silhouette"),
    ("bird_keeper", "exec-4c23efae-f0a3-4296-9650-24ff7978cd70.png", "FRLG youthful keeper, empty cage and falconry glove"),
    ("black_belt", "exec-804349e1-efa6-4e1b-a32f-1c7acc99e842.png", "FRLG lean martial artist, white gi and red headband"),
    ("burglar", "exec-8438020a-76c2-4ac6-857e-83fc41624f5f.png", "FRLG masked thief with sack and sneaking pose"),
    ("channeler", "exec-c51642bf-eb9f-427f-a87a-de583721f2c7.png", "FRLG ritual pose, white robe and paper talisman"),
)

GENERATED = Path("/Users/maarten/.codex/generated_images/019fee1d-ec0a-76f0-97fd-b081274777f6")


def remove_key(image: Image.Image) -> Image.Image:
    image = image.convert("RGBA")
    pixels = []
    for red, green, blue, _alpha in image.getdata():
        distance = max(abs(red - KEY[0]), abs(green - KEY[1]), abs(blue - KEY[2]))
        pixels.append((red, green, blue, 0 if distance <= 54 else 255))
    image.putdata(pixels)
    return image


def frame(image: Image.Image) -> Image.Image:
    bbox = image.getchannel("A").getbbox()
    if bbox is None:
        raise RuntimeError("empty keyed subject")
    subject = image.crop(bbox)
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
    result = opaque.convert("RGB").quantize(colors=47, method=Image.Quantize.MEDIANCUT,
                                             dither=Image.Dither.NONE).convert("RGBA")
    result.putalpha(alpha)
    return result


def main() -> None:
    SOURCE.mkdir(parents=True, exist_ok=True)
    OUT.mkdir(parents=True, exist_ok=True)
    records = []
    for stem, generated_name, note in ROWS:
        generated = GENERATED / generated_name
        if not generated.is_file():
            raise FileNotFoundError(generated)
        source = SOURCE / f"{stem}_v2_chroma.png"
        shutil.copyfile(generated, source)
        hd = frame(remove_key(Image.open(source)))
        low = hd.resize((64, 64), Image.Resampling.NEAREST)
        low.putalpha(low.getchannel("A").point(lambda value: 255 if value else 0))
        hd_path = OUT / f"{stem}_voxel_front_hd_v2.png"
        low_path = OUT / f"{stem}_voxel_front_v2.png"
        hd.save(hd_path, optimize=True)
        low.save(low_path, optimize=True)
        records.append({
            "stem": stem,
            "frlg_authority": f"assets/characters/frlg_trainers/{stem}_front_pic.png",
            "generated_source": generated_name,
            "candidate_64": str(low_path.relative_to(ROOT)),
            "candidate_128": str(hd_path.relative_to(ROOT)),
            "status": "REVIEW_ONLY_NOT_INTEGRATED",
            "authority_note": note,
        })
    with (QA / "PROVENANCE.tsv").open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=records[0].keys(), delimiter="\t")
        writer.writeheader()
        writer.writerows(records)
    print(f"ROOT NORMAL TRAINER CANDIDATES: {len(records)} review-only pairs built")


if __name__ == "__main__":
    main()
