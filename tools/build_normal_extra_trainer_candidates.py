#!/usr/bin/env python3
"""Build nine review-only FRLG-authority trainer candidates.

The source renders are keyed ImageGen outputs.  Nothing below this builder is
used by a live resolver: generated sources, 128px review candidates, 64px
derivatives and their provenance all remain below qa/ until explicit approval.
"""

from __future__ import annotations

import csv
import hashlib
import shutil
from pathlib import Path

from PIL import Image, ImageEnhance, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
QA = ROOT / "qa" / "trainer_normal_extra_20260812"
SOURCE = QA / "source"
OUT = QA / "candidates"
KEY = (0, 255, 0)

STYLE_ANCHORS = (
    "qa/trainer_authentic_rework_20260812/candidates/"
    "leader_brock_voxel_front_hd_v2.png; "
    "qa/trainer_authentic_rework_20260812/candidates/"
    "leader_misty_voxel_front_hd_v2.png"
)

REUSED_PROMPT = """Use case: stylized-concept
Asset type: review-only fictional video-game trainer battle sprite
Input images: Image 1 is the binding FRLG character-design authority for identity, pose, age, body, outfit and props. Images 2 and 3 are Rocko/Misty v2 rendering-style references only.
Primary request: Re-render exactly the fictional trainer class from Image 1 as one polished authentic handheld pixel-art battle sprite.
Style/medium: crisp deliberate pixel clusters, compact palette, strong clean dark outline, and the polished detail density of Images 2 and 3.
Composition: one isolated full-body trainer, centered, completely visible, uncropped and generously padded; preserve Image 1's pose and silhouette.
Backdrop: perfectly flat solid #00ff00 chroma-key background.
Constraints: preserve Image 1's age, proportions, hairstyle, facial impression, clothing, colors, pose and visible props; no redesign, chibi exaggeration, adult reinterpretation, bodybuilder anatomy, 3D, text, UI, watermark, shadow, reflection, extra person, Pokemon or extra object; do not use #00ff00 in the character."""

COOL_M_PROMPT = """Use case: stylized-concept
Asset type: review-only fictional video-game trainer battle sprite
Input images: Image 1 is the character-design authority. Images 2 and 3 are pixel-rendering references only.
Primary request: Render the fictional male trainer class shown in Image 1 as a polished 2D pixel-art sprite. Faithfully retain Image 1's lean proportions, purple hairstyle, red-and-black clothing, crossed-arm stance, silhouette, and palette. Use Images 2 and 3 only for their crisp polished pixel rendering, compact palette, clean dark outline, and detail density.
Composition: exactly one full-body character, centered, uncropped, generous padding.
Backdrop: perfectly uniform solid #00ff00 chroma-key green.
Constraints: one fictional character only; preserve Image 1 design and pose; crisp pixel clusters; no redesign; no chibi exaggeration; no bulky anatomy; no photorealism or 3D; no text, logo, UI, Pokemon, extra person, cast shadow, contact shadow, floor, reflection, or additional prop; do not use #00ff00 on the character."""

COOL_F_PROMPT = """Use case: stylized-concept
Asset type: review-only fictional video-game trainer battle sprite
Input images: Image 1 is the binding character-design authority. Images 2 and 3 are pixel-rendering references only.
Primary request: Render the fictional female trainer from Image 1 as polished 2D pixel art. Faithfully retain Image 1's lean proportions, purple side-swept ponytail, red sleeveless zip-front top, black fitted shorts, red boots, and exact confident pose: left hand raised beside her head, right arm lowered outward holding one small red-and-white capture ball exactly as in Image 1. Use Images 2 and 3 only for crisp polished pixel rendering, compact palette, clean dark outline and detail density.
Composition: exactly one full-body character, centered, uncropped, generous padding.
Backdrop: perfectly uniform solid #00ff00 chroma-key green.
Constraints: preserve Image 1 identity, outfit, palette, silhouette, pose and the single small ball; crisp pixel clusters; no redesign, chibi exaggeration, adult reinterpretation, bulky anatomy, photorealism or 3D; no text, logo, UI, creature, extra person, cast/contact shadow, floor, reflection, or any prop besides the one ball from Image 1; do not use #00ff00 on the character."""

GENERATED_ROOT = Path(
    "/Users/maarten/.codex/generated_images/019ff7bd-b1c6-79e3-a7fa-2d3db10789a8"
)
COOL_ROOT = Path(
    "/Users/maarten/.codex/generated_images/019ff7d4-f085-7721-be4a-5d2feb8fb47c"
)

ROWS = (
    ("rocket_grunt_m", GENERATED_ROOT / "exec-23a197bf-c8d2-492d-9be2-f209736117d9.png", REUSED_PROMPT,
     "FRLG cap, uniform, forward fighting stance and lean Rocket silhouette"),
    ("scientist", GENERATED_ROOT / "exec-768e3b60-eb46-4343-93a0-a7c39999f40a.png", REUSED_PROMPT,
     "FRLG glasses, swept lab coat, Pokeball and flask pose"),
    ("gentleman", GENERATED_ROOT / "exec-793a227c-21da-4fa2-bb47-87b69f9d1efe.png", REUSED_PROMPT,
     "FRLG elderly face, formal brown suit, bow tie and cane pose"),
    ("super_nerd", GENERATED_ROOT / "exec-9b580449-9ec4-4b96-ad8b-c34d9b3adb11.png", REUSED_PROMPT,
     "FRLG glasses, white coat, Pokeball and nervous hand-to-head pose"),
    ("pokemaniac", GENERATED_ROOT / "exec-bbe6335d-2104-444e-890d-308ee0a03a39.png", REUSED_PROMPT,
     "FRLG orange monster hood, white top, brown trousers and claw pose"),
    ("cool_trainer_m", COOL_ROOT / "exec-b5b06c0a-773d-4509-840a-b3f1807bfce2.png", COOL_M_PROMPT,
     "FRLG lean male Ace Trainer, purple hair, red suit and crossed-arm pose"),
    ("cool_trainer_f", COOL_ROOT / "exec-11825fc6-9c8e-45f5-855a-365ce0448b1d.png", COOL_F_PROMPT,
     "FRLG lean female Ace Trainer, purple ponytail, hand-to-head pose and lowered Pokeball"),
    ("cue_ball", GENERATED_ROOT / "exec-2bced5ac-9f2e-49e8-a7a7-80d9a58119df.png", REUSED_PROMPT,
     "FRLG bald stocky biker, fur-collar vest, crouch and motorcycle"),
    ("engineer", GENERATED_ROOT / "exec-dc062485-1a48-4e3b-be3e-83b65daf66a0.png", REUSED_PROMPT,
     "FRLG yellow helmet and workwear, glove, tool belt and red toolbox"),
)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def text_sha256(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


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
    result = opaque.convert("RGB").quantize(
        colors=31,
        method=Image.Quantize.MEDIANCUT,
        dither=Image.Dither.NONE,
    ).convert("RGBA")
    result.putalpha(alpha)
    return result


def write_prompts() -> None:
    sections = [
        "# Final ImageGen prompts\n",
        "Review-only source renders. FRLG images are identity authorities; "
        "Rocko/Misty are rendering-style anchors only.\n",
    ]
    seen: set[str] = set()
    for stem, _generated, prompt, _note in ROWS:
        digest = text_sha256(prompt)
        if digest in seen:
            continue
        seen.add(digest)
        users = ", ".join(row[0] for row in ROWS if text_sha256(row[2]) == digest)
        sections.append(f"## {users}\n\nPrompt SHA-256: `{digest}`\n\n```text\n{prompt}\n```\n")
    (QA / "PROMPTS.md").write_text("\n".join(sections), encoding="utf-8")


def main() -> None:
    SOURCE.mkdir(parents=True, exist_ok=True)
    OUT.mkdir(parents=True, exist_ok=True)
    records = []
    for stem, generated, prompt, note in ROWS:
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
        authority = ROOT / "assets" / "characters" / "frlg_trainers" / f"{stem}_front_pic.png"
        records.append({
            "stem": stem,
            "frlg_authority": str(authority.relative_to(ROOT)),
            "authority_sha256": sha256(authority),
            "style_anchors": STYLE_ANCHORS,
            "generated_origin": str(generated),
            "generated_source": str(source.relative_to(ROOT)),
            "source_sha256": sha256(source),
            "prompt_sha256": text_sha256(prompt),
            "chroma_key": "#00ff00",
            "candidate_64": str(low_path.relative_to(ROOT)),
            "candidate_128": str(hd_path.relative_to(ROOT)),
            "status": "REVIEW_ONLY_NOT_INTEGRATED",
            "authority_note": note,
        })
    with (QA / "PROVENANCE.tsv").open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=records[0].keys(), delimiter="\t")
        writer.writeheader()
        writer.writerows(records)
    write_prompts()
    print(f"NORMAL EXTRA TRAINER CANDIDATES: {len(records)} review-only pairs built")


if __name__ == "__main__":
    main()
