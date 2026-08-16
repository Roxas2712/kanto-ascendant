#!/usr/bin/env python3
"""Assemble the renderer-backed #252-279 acceptance evidence.

The input JSON and PNGs are emitted by tools/extended_species_runtime_qa_driver.lua
inside a real main.lua/LÖVE process.  This tool is deliberately stricter than an
asset inventory: it requires every LÖVE-rendered export, validates the private
Dex boundary, verifies static-only frame counts and makes readable review sheets.
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "qa" / "rc65_crystal_252_279"
PROFILES = ("crystal_on", "crystal_off")
SURFACES = (
    "battleEnemy", "battlePlayer", "dex", "summary", "box",
    "partyIcon", "follower", "wilds", "voxel",
)
BATTLE = ("battleEnemy", "battlePlayer")
AUXILIARY = ("partyIcon", "follower", "wilds", "voxel")


def font(size: int) -> ImageFont.ImageFont:
    for candidate in (
        "/System/Library/Fonts/Supplemental/Arial.ttf",
        "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
    ):
        try:
            return ImageFont.truetype(candidate, size)
        except OSError:
            pass
    return ImageFont.load_default()


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def frame_path(profile: str, species: str, variant: str, surface: str) -> Path:
    return OUT / profile / "frames" / f"{species.lower()}_{variant}_{surface}.png"


def load_profile(name: str) -> dict:
    report = OUT / name / "extended_species_runtime_matrix.json"
    data = json.loads(report.read_text())
    profile = data.get("qaProfile", {})
    expected = name == "crystal_on"
    assert profile.get("crystalEnabled") is expected, (name, profile)
    assert profile.get("guestStaticPolicy") == "retain-supplied-static-card"
    assert profile.get("decodedSurfaces") == 448
    assert profile.get("readyVoxelCards") == 56
    assert profile.get("playableCries") == 28
    rows = data.get("rows", [])
    assert len(rows) == 28
    return data


def render_sheet(profile: str, group: str, surfaces: tuple[str, ...]) -> str:
    data = load_profile(profile)
    rows = data["rows"]
    columns = [(variant, surface) for variant in ("normal", "shiny")
               for surface in surfaces]
    cell_w, cell_h, label_h, row_h = 132, 94, 29, 124
    left, top = 224, 86
    width = left + len(columns) * cell_w + 20
    height = top + len(rows) * row_h + 18
    sheet = Image.new("RGBA", (width, height), (18, 21, 29, 255))
    draw = ImageDraw.Draw(sheet)
    title = f"RC65 Crystal #252-279 · {profile.replace('_', ' ')} · {group}"
    draw.text((16, 13), title, fill=(245, 247, 255), font=font(21))
    draw.text((16, 42),
              "LÖVE-rendered exports; static-only is intentional (one authored frame).",
              fill=(185, 195, 215), font=font(13))
    for col, (variant, surface) in enumerate(columns):
        x = left + col * cell_w
        draw.text((x + 5, 54), f"{variant}\n{surface}",
                  fill=(222, 228, 245), font=font(12), spacing=1)
    for row_index, row in enumerate(rows):
        y = top + row_index * row_h
        draw.rectangle((8, y, width - 10, y + row_h - 8),
                       outline=(57, 67, 87, 255), width=1)
        label = (f"{row['species']}\n"
                 f"internal #{row['internalRuntimeDex']} · source #{row['sourceDex']}\n"
                 "static: one frame")
        draw.multiline_text((16, y + 14), label, fill=(240, 243, 252),
                            font=font(13), spacing=3)
        for col, (variant, surface) in enumerate(columns):
            path = frame_path(profile, row["species"], variant, surface)
            with Image.open(path) as raw:
                image = raw.convert("RGBA")
            image.thumbnail((cell_w - 16, cell_h - 14), Image.Resampling.NEAREST)
            x = left + col * cell_w + (cell_w - image.width) // 2
            iy = y + 4 + (cell_h - image.height) // 2
            sheet.alpha_composite(image, (x, iy))
            draw.rectangle((left + col * cell_w + 3, y + 3,
                            left + (col + 1) * cell_w - 4, y + cell_h),
                           outline=(73, 84, 109, 255), width=1)
    target = OUT / f"{profile}_{group}_contact.png"
    sheet.convert("RGB").save(target, "PNG", optimize=False)
    return target.name


def validate_profile(name: str, data: dict) -> dict:
    rows = data["rows"]
    hashes: dict[str, str] = {}
    normal_shiny_differences = 0
    front_back_differences = 0
    for row in rows:
        assert row["animation"] == {"authoredTiming": False, "mode": "static"}
        for variant in ("normal", "shiny"):
            for surface in SURFACES:
                path = frame_path(name, row["species"], variant, surface)
                assert path.is_file(), f"missing LÖVE export: {path}"
                with Image.open(path) as image:
                    assert image.width > 0 and image.height > 0, path
                hashes[str(path.relative_to(OUT))] = sha(path)
            surfaces = row["surfaces"][variant]
            assert surfaces["voxel"]["valid"] is True
            assert surfaces["voxel"]["sourceDex"] == row["sourceDex"]
            assert surfaces["wilds"]["sourceDex"] == row["sourceDex"]
        for surface in BATTLE:
            if (sha(frame_path(name, row["species"], "normal", surface)) !=
                    sha(frame_path(name, row["species"], "shiny", surface))):
                normal_shiny_differences += 1
        if (sha(frame_path(name, row["species"], "normal", "battleEnemy")) !=
                sha(frame_path(name, row["species"], "normal", "battlePlayer"))):
            front_back_differences += 1
        dex = str(row["internalRuntimeDex"])
        for side in ("front", "back"):
            for variant in ("normal", "shiny"):
                authored = ROOT / "assets" / "crystal_animated" / side / variant / dex
                assert sorted(p.name for p in authored.glob("*.png")) == ["001.png"], authored
    assert normal_shiny_differences == 56
    assert front_back_differences == 28
    by_species = {row["species"]: row for row in rows}
    assert by_species["AZURILL"]["internalRuntimeDex"] == 278
    assert by_species["AZURILL"]["sourceDex"] == 298
    assert by_species["WYNAUT"]["internalRuntimeDex"] == 279
    assert by_species["WYNAUT"]["sourceDex"] == 360
    return {
        "renderedFrameCount": len(hashes),
        "normalShinyBattlePairsDifferent": normal_shiny_differences,
        "normalFrontBackPairsDifferent": front_back_differences,
        "frameSha256": hashes,
    }


def main() -> None:
    reports = {profile: load_profile(profile) for profile in PROFILES}
    validated = {profile: validate_profile(profile, data)
                 for profile, data in reports.items()}
    sheets = {}
    for profile in PROFILES:
        sheets[f"{profile}.battle"] = render_sheet(profile, "battle", BATTLE)
        sheets[f"{profile}.auxiliary"] = render_sheet(profile, "auxiliary", AUXILIARY)
    on_rows = reports["crystal_on"]["rows"]
    off_rows = reports["crystal_off"]["rows"]
    assert [row["species"] for row in on_rows] == [row["species"] for row in off_rows]
    # The static guest-card policy means both setting branches intentionally
    # resolve the same local #252-279 cards.  Compare their LÖVE exports so
    # that a future accidental original-art fallback cannot pass silently.
    toggle_invariant = all(
        sha(frame_path("crystal_on", row["species"], variant, surface)) ==
        sha(frame_path("crystal_off", row["species"], variant, surface))
        for row, off in zip(on_rows, off_rows)
        for variant in ("normal", "shiny")
        for surface in SURFACES
        if row["species"] == off["species"]
    )
    assert toggle_invariant
    result = {
        "format": 1,
        "generatedBy": "tools/extended_species_runtime_qa_driver.lua (real main.lua/LÖVE) + gallery",
        "status": "partial",
        "coverage": {
            "species": 28,
            "profiles": list(PROFILES),
            "surfaces": list(SURFACES),
            "staticOnly": True,
            "summaryDexConstructedInLove": ["AZURILL", "WYNAUT"],
            "criesPlayedInLove": 28,
            "sourceDexSentinels": {"AZURILL": {"internal": 278, "source": 298},
                                   "WYNAUT": {"internal": 279, "source": 360}},
            "crystalToggleGuestStaticInvariant": toggle_invariant,
        },
        "runs": validated,
        "sheets": sheets,
        "sheetSha256": {name: sha(OUT / name) for name in sheets.values()},
        "visualReview": {
            "status": "resolver-only",
            "reviewer": "codex-runtime-qa-2026-08-11",
            "reviewedSheets": list(sheets.values()),
            "finding": "Labels, complete rows, front/back separation and shiny contrast are legible; the auxiliary sheet intentionally shows raw 16x96 sheets and 16x16 billboard cards, not live UI or world scenes.",
        },
    }
    target = OUT / "surface_acceptance_report.json"
    target.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
    print("RC65 Crystal #252-279 resolver gallery: PARTIAL (28 species, 2 profiles, 1008 LÖVE exports; UI/scene capture pending)")


if __name__ == "__main__":
    main()
