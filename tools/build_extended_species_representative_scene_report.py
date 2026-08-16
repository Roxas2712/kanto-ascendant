#!/usr/bin/env python3
"""Build durable, labelled scene evidence for the #252-279 P1 sample."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1] / "qa" / "rc65_crystal_252_279"
OUT = ROOT / "representative_scene_report.json"

SPECIES = [
    ("TREECKO", 252, 252, "Hoenn public"),
    ("AMBIPOM", 261, 424, "HEVO private internal ID"),
    ("AZURILL", 278, 298, "Azurill private internal ID"),
    ("WYNAUT", 279, 360, "Wynaut private internal ID"),
]

FONT = ImageFont.load_default()


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def card_label(path: Path) -> str:
    return path.parent.name + "/" + path.stem


def contact(name: str, paths: list[Path], columns: int = 2) -> dict:
    paths = sorted(paths)
    if not paths:
        raise SystemExit(f"no frames for {name}")
    images = [Image.open(p).convert("RGBA") for p in paths]
    frame_w, frame_h = images[0].size
    if any(im.size != (frame_w, frame_h) for im in images):
        raise SystemExit(f"mixed dimensions in {name}")
    pad, label_h = 12, 18
    rows = (len(paths) + columns - 1) // columns
    sheet = Image.new("RGBA", (
        columns * (frame_w + pad) + pad,
        rows * (frame_h + label_h + pad) + pad,
    ), (25, 25, 25, 255))
    draw = ImageDraw.Draw(sheet)
    for index, (path, image) in enumerate(zip(paths, images)):
        col, row = index % columns, index // columns
        x = pad + col * (frame_w + pad)
        y = pad + row * (frame_h + label_h + pad)
        sheet.alpha_composite(image, (x, y))
        draw.text((x, y + frame_h + 3), card_label(path), fill=(255, 255, 255), font=FONT)
    output = ROOT / f"representative_{name}_contact.png"
    sheet.convert("RGB").save(output)
    return {"path": str(output.relative_to(ROOT.parent.parent)), "sha256": sha(output),
            "frames": len(paths), "frameDimensions": [frame_w, frame_h]}


def require(directory: str, expected: int) -> list[Path]:
    paths = sorted((ROOT / directory).rglob("*.png"))
    if len(paths) != expected:
        raise SystemExit(f"{directory}: expected {expected} PNGs, got {len(paths)}")
    return paths


def main() -> None:
    ui = require("representative_ui", 16)
    battle = require("representative_battle", 8)
    field = require("representative_world_2d", 8)
    voxel = require("representative_world_voxel", 8)
    contacts = {
        "ui": contact("ui", ui),
        "battle": contact("battle", battle),
        "field2d": contact("field_2d", field),
        "voxel": contact("voxel", voxel),
    }
    manifests = [
        ROOT / "representative_ui/ui_capture_manifest.json",
        ROOT / "representative_battle/battle_capture_manifest.json",
        ROOT / "representative_world_2d/world_capture_manifest.json",
        ROOT / "representative_world_voxel/world_capture_manifest.json",
    ]
    if not all(path.is_file() for path in manifests):
        raise SystemExit("one or more live-capture manifests missing")
    report = {
        "id": "RC65-CRYSTAL-252-279",
        "status": "partial",
        "gate": "P1",
        "evidence": "native Authority-main/LÖVE scene stack; no raw walker sheets accepted",
        "representativeSpecies": [
            {"species": species, "internalDex": internal, "sourceDex": source, "role": role}
            for species, internal, source, role in SPECIES
        ],
        "coverage": {
            "PartyMenu": "4 species normal+shiny in native UI",
            "SummaryMenu": "4 species normal+shiny in native UI",
            "DexEntryMenu": "4 species normal in native UI",
            "BoxMenuModernWithdrawGrid": "4 species normal+shiny after real WITHDRAW action",
            "battle": "4 species: normal player/shiny enemy and shiny player/normal enemy at command menu",
            "singleFollowerMovement": "4 species in real Route 22 movement scene",
            "visibleWilds": "4 forced, attached real Wilds entities in Route 22",
            "DRAMALESSVoxel": "same 4 follower and Wilds scenes with active Voxel camera and registered target Wild",
        },
        "notAcceptedAsEvidence": ["raw 16x96 walker sheets", "16x16 billboard exports", "resolver/file-existence probes"],
        "runtimeNotes": [
            "The target Wild of each capture was asserted attached; Voxel targets were additionally asserted registered with the DRAMALESS renderer.",
            "The DRAMALESS identity emitted separate pose warnings for ambient Route 22 Wilds; those entities are outside this four-target sample and are not accepted as coverage.",
        ],
        "open": ["24 of 28 species still require equivalent real scene acceptance"],
        "captureManifests": [str(path.relative_to(ROOT.parent.parent)) for path in manifests],
        "contacts": contacts,
    }
    OUT.write_text(json.dumps(report, indent=2) + "\n")
    print(f"PARTIAL P1: 40 real scene captures; {OUT}")


if __name__ == "__main__":
    main()
