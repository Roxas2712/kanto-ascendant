#!/usr/bin/env python3
"""Build review-only FRLG-authority Oak/Leader/Elite candidates.

No output of this script is written below ``assets/``.  The 64px variant is a
deterministic nearest-neighbour reduction of the visually reviewed 128px file.
"""

from __future__ import annotations

import csv
import os
from pathlib import Path

from PIL import Image, ImageEnhance, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
QA = ROOT / "qa" / "trainer_authentic_authority_20260812"
SOURCE = QA / "source"
OUT = QA / "candidates"
GEN = Path(os.environ.get("KASC_AUTHORITY_IMAGE_ROOT", "generated_input"))

# stem, live generation suffix, chroma, selected raw, authority note
ROWS = (
    ("professor_oak", "v2", "#00ff00", "exec-bf3c9d0d-476b-42c9-af69-e9f0edf4c461.png",
     "FRLG clean-shaven mature professor; hair, coat, clothes and presenting pose"),
    ("leader_lt_surge", "v2", "#00ff00", "exec-8dab5f07-8eb3-4cd4-8628-9c94ae57b246.png",
     "FRLG adult military build, outfit, boots and ball-in-hand stance"),
    ("leader_erika", "v2", "#00ff00", "exec-c0064d65-fde4-47ca-a5a5-d1ad09283eac.png",
     "FRLG youthful kimono design and both-hands-together calm stance"),
    ("leader_koga", "v2", "#00ff00", "exec-874726c4-0ce0-4020-a95f-f93917b92129.png",
     "FRLG ninja identity, scarf, clothing and crouched silhouette"),
    ("leader_sabrina", "v2", "#00ff00", "exec-fadf81ad-3d83-4029-b99f-c83677fad661.png",
     "FRLG age, hair, red-blue outfit and ball-holding stance"),
    ("leader_blaine", "v2", "#ff00ff", "exec-73519ce7-cba7-4cfc-b9ee-e3269af42afd.png",
     "FRLG elderly bald head, moustache, glasses, lab coat and raised-ball pose"),
    ("leader_giovanni", "v2", "#00ff00", "exec-f16ba005-b7fc-4ca9-9ce4-da4bfd98dcbe.png",
     "FRLG middle-aged formal identity, suit and ball directly held in hand"),
    ("elite_four_lorelei", "v3", "#00ff00", "exec-03592ccf-c247-4685-a1fa-02562a2a31f0.png",
     "FRLG adult identity, red hair, black-purple outfit and command pose"),
    ("elite_four_bruno", "v3", "#00ff00", "exec-46074cf3-6610-4dc4-8aa1-ac7da693ccb9.png",
     "FRLG martial-artist anatomy, trousers and exact crouched fighting pose"),
    ("elite_four_agatha", "v3", "#00ff00", "exec-f55e167a-5857-4b23-b453-2858b799809e.png",
     "FRLG elderly identity, dress, apron, cane and stooped stance"),
    ("elite_four_lance", "v3", "#00ff00", "exec-c64f97a9-2ade-4587-8cce-e9cb29e1aaa2.png",
     "FRLG red hair, dark uniform, cape and extended-arm silhouette"),
)


def key_rgb(value: str) -> tuple[int, int, int]:
    value = value.removeprefix("#")
    return tuple(int(value[index:index + 2], 16) for index in (0, 2, 4))


def remove_key(image: Image.Image, key: tuple[int, int, int]) -> Image.Image:
    image = image.convert("RGBA")
    pixels = []
    for red, green, blue, _alpha in image.getdata():
        distance = max(abs(red - key[0]), abs(green - key[1]), abs(blue - key[2]))
        pixels.append((red, green, blue, 0 if distance <= 54 else 255))
    image.putdata(pixels)
    return image


def frame(image: Image.Image, size: int = 128, margin: int = 6) -> Image.Image:
    bbox = image.getchannel("A").getbbox()
    if bbox is None:
        raise RuntimeError("empty keyed subject")
    subject = image.crop(bbox)
    available = size - 2 * margin
    scale = min(available / subject.width, available / subject.height)
    dims = (max(1, round(subject.width * scale)), max(1, round(subject.height * scale)))
    subject = subject.resize(dims, Image.Resampling.LANCZOS)
    subject = ImageEnhance.Contrast(subject).enhance(1.08)
    subject = subject.filter(ImageFilter.UnsharpMask(radius=0.7, percent=90, threshold=3))
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    canvas.alpha_composite(subject, ((size - dims[0]) // 2, size - margin - dims[1]))
    alpha = canvas.getchannel("A").point(lambda value: 255 if value >= 112 else 0)
    opaque = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    opaque.paste(canvas.convert("RGB"), mask=alpha)
    quantized = opaque.convert("RGB").quantize(
        colors=31, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE,
    ).convert("RGBA")
    quantized.putalpha(alpha)
    return quantized


def main() -> None:
    SOURCE.mkdir(parents=True, exist_ok=True)
    OUT.mkdir(parents=True, exist_ok=True)
    provenance = []
    for stem, version, chroma, filename, note in ROWS:
        generated = GEN / filename
        if not generated.is_file():
            raise FileNotFoundError(generated)
        source = SOURCE / f"{stem}_{version}_chroma.png"
        source.write_bytes(generated.read_bytes())
        hd = frame(remove_key(Image.open(source), key_rgb(chroma)))
        low = hd.resize((64, 64), Image.Resampling.NEAREST)
        low.putalpha(low.getchannel("A").point(lambda value: 255 if value else 0))
        low_path = OUT / f"{stem}_voxel_front_{version}.png"
        hd_path = OUT / f"{stem}_voxel_front_hd_{version}.png"
        low.save(low_path, optimize=True)
        hd.save(hd_path, optimize=True)
        provenance.append({
            "stem": stem,
            "frlg_authority": f"assets/characters/frlg_trainers/{stem}_front_pic.png",
            "selected_imagegen_source": filename,
            "chroma_key": chroma,
            "candidate_64": str(low_path.relative_to(ROOT)),
            "candidate_128": str(hd_path.relative_to(ROOT)),
            "status": "REVIEW_ONLY_NOT_INTEGRATED",
            "authority_note": note,
        })
    with (QA / "PROVENANCE.tsv").open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=provenance[0].keys(), delimiter="\t")
        writer.writeheader()
        writer.writerows(provenance)
    print(f"AUTHENTIC AUTHORITY CANDIDATES: {len(ROWS)} review-only pairs built")


if __name__ == "__main__":
    main()
