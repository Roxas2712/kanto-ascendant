#!/usr/bin/env python3
"""Build the fail-closed 48-identity trainer art approval gallery.

This is a QA-only renderer.  It never writes product assets and never updates a
resolver.  Candidate columns remain visibly empty unless a distinct candidate
file exists in one of the explicitly documented QA candidate locations.
"""

from __future__ import annotations

import csv
import hashlib
import json
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable, Optional

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "qa" / "trainer_final_user_approval_20260812"
FRLG = ROOT / "assets" / "characters" / "frlg_trainers"
CRYSTAL = ROOT / "assets" / "characters" / "crystal_chars"
JOHTO = ROOT / "assets" / "johto_masters" / "battle"
AUTHENTIC_V2 = ROOT / "qa" / "trainer_authentic_rework_20260812" / "candidates"
AUTHORITY_V2 = ROOT / "qa" / "trainer_authentic_authority_20260812" / "candidates"
CHILD_V2 = OUT / "candidates"
ROOT_NORMAL_V2 = ROOT / "qa" / "trainer_full_normal_rework_root_20260812" / "candidates"
FULL_NORMAL_V2 = ROOT / "qa" / "trainer_full_normal_rework_20260812" / "candidates"
EXTRA_NORMAL_V2 = ROOT / "qa" / "trainer_normal_extra_20260812" / "candidates"

PAGE_W = 3600
PAGE_MARGIN = 54
PAGE_HEADER = 164
CARD_GAP = 28
CARD_W = (PAGE_W - PAGE_MARGIN * 2 - CARD_GAP * 2) // 3
CARD_H = 690

BG = (20, 23, 30, 255)
CARD_BG = (33, 38, 49, 255)
PANEL_BG = (19, 22, 29, 255)
LINE = (79, 91, 112, 255)
TEXT = (239, 243, 250, 255)
MUTED = (171, 182, 199, 255)
CURRENT = (89, 170, 255, 255)
NEW = (63, 211, 142, 255)
HOLD = (245, 183, 67, 255)
MISSING = (225, 92, 104, 255)
FIXED_CURRENT_ONLY = {"red", "blue", "green", "silver", "kris", "gold"}
OAK_REJECTED_KEEP_CURRENT = "professor_oak"

DECISION_CURRENT_ONLY = "CURRENT_ONLY"
DECISION_REJECTED_KEEP_CURRENT = "REJECTED_KEEP_CURRENT"
DECISION_APPROVED_NEW_BUILD = "APPROVED_NEW_BUILD"


@dataclass(frozen=True)
class Entry:
    group: str
    stem: str
    german: str
    english: str
    class_id: str
    role: str
    authority: Path
    current_64: Path
    current_128: Path


def fixed_entries() -> list[Entry]:
    data = [
        ("red", "Rot", "Red", "CHAR_RED", "Feste Spielfigur", CRYSTAL / "red_front.png"),
        ("blue", "Blau", "Blue", "CHAR_BLUE", "Feste Spielfigur", CRYSTAL / "blue_front.png"),
        ("green", "Grün", "Green", "CHAR_GREEN", "Feste Spielfigur", CRYSTAL / "green_front.png"),
        ("silver", "Silber", "Silver", "KA_JOHTO_SILVER", "Johto-Meister", JOHTO / "silver_front.png"),
        ("kris", "Kris", "Kris", "KA_JOHTO_KRIS", "Johto-Meisterin", JOHTO / "kris_front.png"),
        ("gold", "Gold", "Gold", "KA_JOHTO_GOLD", "Johto-Meister", JOHTO / "gold_front_color_v1.png"),
    ]
    rows = []
    for stem, de, en, cid, role, front in data:
        base = CRYSTAL if stem in {"red", "blue", "green"} else JOHTO
        rows.append(Entry("fixed", stem, de, en, cid, role, front,
                          base / f"{stem}_voxel_front.png",
                          base / f"{stem}_voxel_front_hd.png"))
    return rows


LEADERS = [
    ("professor_oak", "Professor Eich", "Professor Oak", "OPP_PROF_OAK", "Professor / Legacy-Finale"),
    ("leader_brock", "Rocko", "Brock", "OPP_BROCK", "Arenaleiter Gestein"),
    ("leader_misty", "Misty", "Misty", "OPP_MISTY", "Arenaleiterin Wasser"),
    ("leader_lt_surge", "Major Bob", "Lt. Surge", "OPP_LT_SURGE", "Arenaleiter Elektro"),
    ("leader_erika", "Erika", "Erika", "OPP_ERIKA", "Arenaleiterin Pflanze"),
    ("leader_koga", "Koga", "Koga", "OPP_KOGA", "Arenaleiter Gift"),
    ("leader_sabrina", "Sabrina", "Sabrina", "OPP_SABRINA", "Arenaleiterin Psycho"),
    ("leader_blaine", "Pyro", "Blaine", "OPP_BLAINE", "Arenaleiter Feuer"),
    ("leader_giovanni", "Giovanni", "Giovanni", "OPP_GIOVANNI", "Arenaleiter Boden / Rocket-Boss"),
]

ELITE_FOUR = [
    ("elite_four_lorelei", "Lorelei", "Lorelei", "OPP_LORELEI", "Top Vier Eis"),
    ("elite_four_bruno", "Bruno", "Bruno", "OPP_BRUNO", "Top Vier Kampf"),
    ("elite_four_agatha", "Agatha", "Agatha", "OPP_AGATHA", "Top Vier Geist"),
    ("elite_four_lance", "Siegfried", "Lance", "OPP_LANCE", "Top Vier Drache"),
]

NORMALS = [
    ("beauty", "Schönheit", "Beauty", "OPP_BEAUTY"),
    ("biker", "Biker", "Biker", "OPP_BIKER"),
    ("bird_keeper", "Vogelfänger", "Bird Keeper", "OPP_BIRD_KEEPER"),
    ("black_belt", "Schwarzgurt", "Black Belt", "OPP_BLACKBELT"),
    ("bug_catcher", "Käfersammler", "Bug Catcher", "OPP_BUG_CATCHER"),
    ("burglar", "Dieb", "Burglar", "OPP_BURGLAR"),
    ("channeler", "Exorzistin", "Channeler", "OPP_CHANNELER"),
    ("rocket_grunt_m", "Rocket-Rüpel", "Team Rocket Grunt", "OPP_ROCKET"),
    ("scientist", "Wissenschaftler", "Scientist", "OPP_SCIENTIST"),
    ("gentleman", "Gentleman", "Gentleman", "OPP_GENTLEMAN"),
    ("super_nerd", "Super-Nerd", "Super Nerd", "OPP_SUPER_NERD"),
    ("pokemaniac", "Pokémaniac", "Poké Maniac", "OPP_POKEMANIAC"),
    ("camper", "Camper", "Camper", "OPP_JR_TRAINER_M"),
    ("picnicker", "Picknickerin", "Picnicker", "OPP_JR_TRAINER_F"),
    ("cool_trainer_m", "Ass-Trainer", "Cooltrainer M", "OPP_COOLTRAINER_M"),
    ("cool_trainer_f", "Ass-Trainerin", "Cooltrainer F", "OPP_COOLTRAINER_F"),
    ("cue_ball", "Rowdy", "Cue Ball", "OPP_CUE_BALL"),
    ("engineer", "Ingenieur", "Engineer", "OPP_ENGINEER"),
    ("fisherman", "Angler", "Fisherman", "OPP_FISHER"),
    ("gamer", "Spieler", "Gamer", "OPP_GAMBLER"),
    ("hiker", "Wanderer", "Hiker", "OPP_HIKER"),
    ("juggler", "Jongleur", "Juggler", "OPP_JUGGLER"),
    ("lass", "Göre", "Lass", "OPP_LASS"),
    ("psychic_m", "Psycho", "Psychic", "OPP_PSYCHIC_TR"),
    ("rocker", "Rocker", "Rocker", "OPP_ROCKER"),
    ("sailor", "Matrose", "Sailor", "OPP_SAILOR"),
    ("swimmer_m", "Schwimmer", "Swimmer", "OPP_SWIMMER"),
    ("tamer", "Bändiger", "Tamer", "OPP_TAMER"),
    ("youngster", "Youngster", "Youngster", "OPP_YOUNGSTER"),
]


def frlg_entries(group: str, rows: Iterable[tuple[str, str, str, str, str]]) -> list[Entry]:
    result = []
    for stem, de, en, class_id, role in rows:
        version = "v2" if stem.startswith("elite_four_") else "v1"
        result.append(Entry(group, stem, de, en, class_id, role,
                            FRLG / f"{stem}_front_pic.png",
                            FRLG / f"{stem}_voxel_front_{version}.png",
                            FRLG / f"{stem}_voxel_front_hd_{version}.png"))
    return result


def all_entries() -> list[Entry]:
    leaders = frlg_entries("leaders", LEADERS)
    elites = frlg_entries("elite_four", ELITE_FOUR)
    normals = frlg_entries(
        "normal_trainers",
        [(stem, de, en, cid, "Normale Trainerklasse") for stem, de, en, cid in NORMALS],
    )
    rows = fixed_entries() + leaders + elites + normals
    assert len(rows) == 48, f"gallery inventory drift: {len(rows)} != 48"
    assert len({row.stem for row in rows}) == 48, "duplicate gallery stem"
    return rows


def candidate_paths(stem: str) -> tuple[Optional[Path], Optional[Path]]:
    """Return distinct v2 files only; never fall back to a current asset."""
    pairs = [
        (AUTHENTIC_V2 / f"{stem}_voxel_front_v2.png",
         AUTHENTIC_V2 / f"{stem}_voxel_front_hd_v2.png"),
        (AUTHORITY_V2 / f"{stem}_voxel_front_v2.png",
         AUTHORITY_V2 / f"{stem}_voxel_front_hd_v2.png"),
        (AUTHORITY_V2 / f"{stem}_voxel_front_v3.png",
         AUTHORITY_V2 / f"{stem}_voxel_front_hd_v3.png"),
        (CHILD_V2 / f"{stem}_front_pic_v2_64.png",
         CHILD_V2 / f"{stem}_front_pic_v2_128.png"),
        (ROOT_NORMAL_V2 / f"{stem}_voxel_front_v2.png",
         ROOT_NORMAL_V2 / f"{stem}_voxel_front_hd_v2.png"),
        (FULL_NORMAL_V2 / f"{stem}_voxel_front_v2.png",
         FULL_NORMAL_V2 / f"{stem}_voxel_front_hd_v2.png"),
        (EXTRA_NORMAL_V2 / f"{stem}_voxel_front_v2.png",
         EXTRA_NORMAL_V2 / f"{stem}_voxel_front_hd_v2.png"),
    ]
    for p64, p128 in pairs:
        if p64.exists() or p128.exists():
            return (p64 if p64.exists() else None, p128 if p128.exists() else None)
    return None, None


def font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    # Pillow ships DejaVu through its tests only on some systems.  These macOS
    # fonts are stable in the maintainer environment; load_default is a safe
    # portable fallback for CI.
    names = (["/System/Library/Fonts/Supplemental/Arial Bold.ttf"] if bold else
             ["/System/Library/Fonts/Supplemental/Arial.ttf"])
    names += ["/System/Library/Fonts/SFNS.ttf"]
    for name in names:
        try:
            return ImageFont.truetype(name, size=size)
        except OSError:
            pass
    return ImageFont.load_default(size=size)


F_TITLE = font(42, True)
F_SUBTITLE = font(24)
F_NAME = font(29, True)
F_META = font(18)
F_PANEL = font(14, True)
F_STATUS = font(17, True)


def rel(path: Optional[Path]) -> str:
    if path is None:
        return ""
    return path.resolve().relative_to(ROOT.resolve()).as_posix()


def approval_decision(stem: str) -> str:
    if stem in FIXED_CURRENT_ONLY:
        return DECISION_CURRENT_ONLY
    if stem == OAK_REJECTED_KEEP_CURRENT:
        return DECISION_REJECTED_KEEP_CURRENT
    return DECISION_APPROVED_NEW_BUILD


def image_metadata(path: Path) -> dict[str, object]:
    raw = path.read_bytes()
    with Image.open(path) as im:
        rgba = im.convert("RGBA")
        alpha = rgba.getchannel("A")
        lo, hi = alpha.getextrema()
        return {
            "path": rel(path),
            "width": im.width,
            "height": im.height,
            "mode": im.mode,
            "has_alpha_channel": "A" in im.getbands() or "transparency" in im.info,
            "alpha_min": lo,
            "alpha_max": hi,
            "has_transparent_pixels": lo < 255,
            "sha256": hashlib.sha256(raw).hexdigest(),
        }


def checker(size: tuple[int, int], cell: int = 14) -> Image.Image:
    im = Image.new("RGBA", size, (233, 236, 242, 255))
    draw = ImageDraw.Draw(im)
    alt = (204, 210, 222, 255)
    for y in range(0, size[1], cell):
        for x in range(0, size[0], cell):
            if (x // cell + y // cell) % 2:
                draw.rectangle((x, y, min(x + cell - 1, size[0] - 1),
                                min(y + cell - 1, size[1] - 1)), fill=alt)
    return im


def paste_contained(canvas: Image.Image, path: Path, box: tuple[int, int, int, int]) -> None:
    x0, y0, x1, y1 = box
    pad = 8
    area = checker((x1 - x0, y1 - y0))
    with Image.open(path) as src:
        src = src.convert("RGBA")
        scale = min((area.width - pad * 2) / src.width, (area.height - pad * 2) / src.height)
        w = max(1, int(src.width * scale))
        h = max(1, int(src.height * scale))
        resized = src.resize((w, h), Image.Resampling.NEAREST)
        area.alpha_composite(resized, ((area.width - w) // 2, (area.height - h) // 2))
    canvas.alpha_composite(area, (x0, y0))


def draw_missing(draw: ImageDraw.ImageDraw, box: tuple[int, int, int, int], label: str) -> None:
    x0, y0, x1, y1 = box
    draw.rectangle(box, fill=(42, 31, 35, 255), outline=MISSING, width=3)
    bounds = draw.textbbox((0, 0), label, font=F_STATUS)
    draw.text(((x0 + x1 - (bounds[2] - bounds[0])) / 2,
               (y0 + y1 - (bounds[3] - bounds[1])) / 2), label, fill=MISSING, font=F_STATUS)


def draw_card(canvas: Image.Image, entry: Entry, x: int, y: int) -> dict[str, object]:
    draw = ImageDraw.Draw(canvas)
    draw.rounded_rectangle((x, y, x + CARD_W, y + CARD_H), radius=18,
                           fill=CARD_BG, outline=LINE, width=3)
    candidate_64, candidate_128 = candidate_paths(entry.stem)
    has_candidate = candidate_64 is not None or candidate_128 is not None
    decision = approval_decision(entry.stem)
    fixed_current_only = decision == DECISION_CURRENT_ONLY
    rejected_keep_current = decision == DECISION_REJECTED_KEEP_CURRENT
    if fixed_current_only:
        display_status, status_color = "CURRENT ONLY", HOLD
    elif rejected_keep_current:
        display_status, status_color = "REJECTED · KEEP CURRENT", MISSING
    else:
        display_status, status_color = "APPROVED · NEW BUILD", NEW

    draw.text((x + 24, y + 18), f"{entry.german} / {entry.english}", fill=TEXT, font=F_NAME)
    draw.text((x + 24, y + 58), f"{entry.class_id} · {entry.role}", fill=MUTED, font=F_META)
    sb = draw.textbbox((0, 0), display_status, font=F_STATUS)
    sw = sb[2] - sb[0] + 24
    draw.rounded_rectangle((x + CARD_W - sw - 22, y + 18, x + CARD_W - 22, y + 48),
                           radius=10, fill=status_color)
    draw.text((x + CARD_W - sw - 10, y + 23), display_status,
              fill=(18, 21, 27, 255), font=F_STATUS)

    inner_x = x + 22
    top = y + 100
    panel_h = 528
    widths = [220, 198, 218, 198, 218]
    if fixed_current_only:
        candidate_subhead = ("FIXED IDENTITY", "CURRENT-ONLY")
        candidate_color = MISSING
    elif rejected_keep_current:
        candidate_subhead = ("REJECTED", "KEEP CURRENT")
        candidate_color = MISSING
    else:
        candidate_subhead = ("USER APPROVED", "NEW BUILD")
        candidate_color = NEW
    labels = [("2D AUTHORITY", "", ""), ("64 CURRENT", "", ""),
              ("128 HD CURRENT", "", ""),
              ("64 CANDIDATE", *candidate_subhead),
              ("128 HD CANDIDATE", *candidate_subhead)]
    paths: list[Optional[Path]] = [entry.authority, entry.current_64, entry.current_128,
                                  candidate_64, candidate_128]
    colors = [MUTED, CURRENT, CURRENT,
              candidate_color if candidate_64 else MISSING,
              candidate_color if candidate_128 else MISSING]
    px = inner_x
    for width, label_lines, path, color in zip(widths, labels, paths, colors):
        draw.rectangle((px, top, px + width, top + panel_h), fill=PANEL_BG, outline=LINE, width=2)
        for line_index, line in enumerate(label_lines):
            if line:
                draw.text((px + 10, top + 5 + line_index * 17), line, fill=color, font=F_PANEL)
        image_box = (px + 9, top + 61, px + width - 9, top + panel_h - 10)
        if path is not None and path.exists():
            paste_contained(canvas, path, image_box)
        else:
            draw_missing(draw, image_box,
                         "CURRENT-ONLY" if fixed_current_only else "HOLD / NO V2")
        px += width + 8

    return {
        "group": entry.group,
        "stem": entry.stem,
        "german_name": entry.german,
        "english_name": entry.english,
        "class_id": entry.class_id,
        "role": entry.role,
        "approval_decision": decision,
        "display_status": display_status,
        "selected_build": "CANDIDATE" if decision == DECISION_APPROVED_NEW_BUILD else "CURRENT",
        "selected_64": rel(candidate_64 if decision == DECISION_APPROVED_NEW_BUILD else entry.current_64),
        "selected_128": rel(candidate_128 if decision == DECISION_APPROVED_NEW_BUILD else entry.current_128),
        "authority": rel(entry.authority),
        "current_64": rel(entry.current_64),
        "current_128": rel(entry.current_128),
        "candidate_64": rel(candidate_64),
        "candidate_128": rel(candidate_128),
    }


def render_page(filename: str, title: str, subtitle: str, entries: list[Entry], rows: int) -> tuple[Path, list[dict[str, object]]]:
    height = PAGE_HEADER + PAGE_MARGIN + rows * CARD_H + max(0, rows - 1) * CARD_GAP + PAGE_MARGIN
    canvas = Image.new("RGBA", (PAGE_W, height), BG)
    draw = ImageDraw.Draw(canvas)
    draw.text((PAGE_MARGIN, 38), title, fill=TEXT, font=F_TITLE)
    draw.text((PAGE_MARGIN, 96), subtitle, fill=MUTED, font=F_SUBTITLE)
    records = []
    for i, entry in enumerate(entries):
        col, row = i % 3, i // 3
        x = PAGE_MARGIN + col * (CARD_W + CARD_GAP)
        y = PAGE_HEADER + PAGE_MARGIN + row * (CARD_H + CARD_GAP)
        record = draw_card(canvas, entry, x, y)
        record["page"] = filename
        records.append(record)
    path = OUT / filename
    canvas.convert("RGB").save(path, format="PNG", optimize=False, compress_level=9)
    return path, records


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def validate_sources(entries: list[Entry]) -> None:
    missing = []
    for entry in entries:
        for label, path in (("authority", entry.authority), ("current_64", entry.current_64),
                            ("current_128", entry.current_128)):
            try:
                path.resolve().relative_to(ROOT.resolve())
            except ValueError:
                raise AssertionError(f"path escapes repository: {path}")
            if not path.is_file():
                missing.append(f"{entry.stem}:{label}:{rel(path)}")
    if missing:
        raise FileNotFoundError("missing current authority assets:\n" + "\n".join(missing))


def validate_final_candidate_gate(entries: list[Entry]) -> None:
    """The final approval artifact is valid only with 42 distinct pairs."""
    missing = []
    duplicates = []
    for entry in entries:
        candidate_64, candidate_128 = candidate_paths(entry.stem)
        if entry.stem in FIXED_CURRENT_ONLY:
            if candidate_64 is not None or candidate_128 is not None:
                raise AssertionError(f"fixed identity must remain CURRENT-only: {entry.stem}")
            continue
        if candidate_64 is None or candidate_128 is None:
            missing.append(entry.stem)
            continue
        for candidate, current in ((candidate_64, entry.current_64),
                                   (candidate_128, entry.current_128)):
            if candidate.read_bytes() == current.read_bytes():
                duplicates.append(f"{entry.stem}:{candidate.name}")
    if missing or duplicates:
        details = []
        if missing:
            details.append("missing candidate pairs: " + ", ".join(missing))
        if duplicates:
            details.append("candidate duplicates CURRENT: " + ", ".join(duplicates))
        raise RuntimeError("final trainer approval gate OPEN; " + "; ".join(details))


def write_reports(records: list[dict[str, object]], pages: list[Path]) -> None:
    source_rows: list[dict[str, object]] = []
    seen: set[str] = set()
    for record in records:
        for key in ("authority", "current_64", "current_128", "candidate_64", "candidate_128"):
            value = str(record[key])
            if not value or value in seen:
                continue
            seen.add(value)
            source_rows.append({"slot": key, **image_metadata(ROOT / value)})

    manifest_path = OUT / "MANIFEST.tsv"
    fields = ["group", "stem", "german_name", "english_name", "class_id", "role",
              "approval_decision", "display_status", "selected_build", "selected_64", "selected_128",
              "authority", "current_64", "current_128", "candidate_64", "candidate_128", "page"]
    with manifest_path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields, delimiter="\t")
        writer.writeheader()
        writer.writerows(records)

    receipt_path = OUT / "IMAGE_RECEIPTS.tsv"
    receipt_fields = ["slot", "path", "width", "height", "mode", "has_alpha_channel",
                      "alpha_min", "alpha_max", "has_transparent_pixels", "sha256"]
    with receipt_path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=receipt_fields, delimiter="\t")
        writer.writeheader()
        writer.writerows(source_rows)

    page_rows = []
    for page in pages:
        with Image.open(page) as im:
            page_rows.append({"path": rel(page), "width": im.width, "height": im.height,
                              "mode": im.mode, "sha256": sha256(page)})
    decision_counts = {
        DECISION_CURRENT_ONLY: sum(row["approval_decision"] == DECISION_CURRENT_ONLY for row in records),
        DECISION_REJECTED_KEEP_CURRENT: sum(
            row["approval_decision"] == DECISION_REJECTED_KEEP_CURRENT for row in records),
        DECISION_APPROVED_NEW_BUILD: sum(
            row["approval_decision"] == DECISION_APPROVED_NEW_BUILD for row in records),
    }
    approval_record = {
        "schema": 1,
        "scope": "trainer_sprite_final_user_approval",
        "integration_status": "QA_ONLY_NOT_INTEGRATED",
        "decision_counts": decision_counts,
        "decisions": [
            {
                "stem": row["stem"],
                "decision": row["approval_decision"],
                "selected_build": row["selected_build"],
                "selected_64": row["selected_64"],
                "selected_128": row["selected_128"],
            }
            for row in records
        ],
    }
    approval_path = OUT / "APPROVAL_RECORD.json"
    approval_path.write_text(json.dumps(approval_record, ensure_ascii=False, indent=2) + "\n",
                             encoding="utf-8")

    receipt = {
        "schema": 2,
        "inventory_count": len(records),
        "unique_stems": len({str(row["stem"]) for row in records}),
        "candidate_asset_identity_count": sum(bool(row["candidate_64"] and row["candidate_128"])
                                              for row in records),
        "approval_decision_counts": decision_counts,
        "selected_current_count": sum(row["selected_build"] == "CURRENT" for row in records),
        "selected_candidate_count": sum(row["selected_build"] == "CANDIDATE" for row in records),
        "source_image_count": len(source_rows),
        "all_paths_repository_relative": all(not Path(str(row["path"])).is_absolute() for row in source_rows),
        "pages": page_rows,
        "manifest_sha256": sha256(manifest_path),
        "image_receipts_sha256": sha256(receipt_path),
        "approval_record_sha256": sha256(approval_path),
    }
    expected_decisions = {
        DECISION_CURRENT_ONLY: 6,
        DECISION_REJECTED_KEEP_CURRENT: 1,
        DECISION_APPROVED_NEW_BUILD: 41,
    }
    if (receipt["candidate_asset_identity_count"] != 42 or decision_counts != expected_decisions or
            receipt["selected_current_count"] != 7 or receipt["selected_candidate_count"] != 41):
        raise AssertionError("final receipt must encode 6 CURRENT_ONLY + Oak rejected + 41 approved")
    (OUT / "RECEIPT.json").write_text(json.dumps(receipt, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    index_lines = ["# Trainer-Sprite-Abnahme — Index", "",
                   "Finale Auswahl: 6 CURRENT_ONLY, Professor Eich REJECTED_KEEP_CURRENT, "
                   "41 APPROVED_NEW_BUILD.", ""]
    for page in pages:
        index_lines.append(f"- [{page.stem}]({page.name})")
    index_lines += ["", "Datennachweise:", "", "- [MANIFEST.tsv](MANIFEST.tsv)",
                    "- [APPROVAL_RECORD.json](APPROVAL_RECORD.json)",
                    "- [IMAGE_RECEIPTS.tsv](IMAGE_RECEIPTS.tsv)",
                    "- [RECEIPT.json](RECEIPT.json)", ""]
    (OUT / "INDEX.md").write_text("\n".join(index_lines), encoding="utf-8")

    readme = """# Finale Trainer-Sprite-Abnahme (QA-only)

Diese Galerie zeigt **48 Identitäten**: 6 feste Figuren, Professor Eich, 8
Arenaleiter, 4 Top-Vier-Mitglieder und 29 normale FRLG-Trainerklassen.

- **CURRENT_ONLY** gilt für Rot, Blau, Grün, Silber, Kris und Gold.
- Professor Eichs Kandidat ist **REJECTED_KEEP_CURRENT**; die Vergleichsgrafik
  bleibt nur als Nachweis sichtbar.
- Alle übrigen 41 Identitäten sind **APPROVED_NEW_BUILD**.
- Die maschinenlesbare Auswahl steht in `APPROVAL_RECORD.json` und `MANIFEST.tsv`.
- Es wird niemals heimlich CURRENT als Kandidat dupliziert.
- Die 2D-Spalte ist die jeweilige Authority/FRLG-Referenz, keine generierte
  Ersatzgrafik.

Der Builder schreibt ausschließlich in diesen QA-Ordner. Er ändert keine
Produktassets, Resolver, Produktmanifeste oder Laufzeitlogik. Diese Artefakte
halten die erfolgte Nutzerfreigabe fest; die Live-Integration erfolgt getrennt.

Neu bauen:

```sh
python3 tools/build_trainer_final_approval_gallery.py
```
"""
    (OUT / "README.md").write_text(readme, encoding="utf-8")


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    entries = all_entries()
    validate_sources(entries)
    validate_final_candidate_gate(entries)
    fixed = [e for e in entries if e.group == "fixed"]
    leaders = [e for e in entries if e.group == "leaders"]
    elites = [e for e in entries if e.group == "elite_four"]
    normals = [e for e in entries if e.group == "normal_trainers"]
    specs = [
        ("01_fixed_identities.png", "Feste Identitäten · 6/48",
         "Rot, Blau, Grün, Silber, Kris und Gold — keine Stilumschaltung", fixed, 2),
        ("02_professor_and_gym_leaders.png", "Professor & Arenaleiter · 9/48",
         "2D-Authority, aktueller Voxelstand und strikt getrennte V2-Kandidaten", leaders, 3),
        ("03_elite_four.png", "Top Vier · 4/48",
         "Lorelei, Bruno, Agatha und Siegfried / Lance", elites, 2),
        ("04_normal_trainers_a.png", "Normale Trainerklassen A · 10/29",
         "Teil 1 der vollständigen FRLG-Klassenabnahme", normals[:10], 4),
        ("05_normal_trainers_b.png", "Normale Trainerklassen B · 10/29",
         "Teil 2 der vollständigen FRLG-Klassenabnahme", normals[10:20], 4),
        ("06_normal_trainers_c.png", "Normale Trainerklassen C · 9/29",
         "Teil 3 der vollständigen FRLG-Klassenabnahme", normals[20:], 3),
    ]
    pages: list[Path] = []
    records: list[dict[str, object]] = []
    for filename, title, subtitle, page_entries, rows in specs:
        page, page_records = render_page(filename, title, subtitle, page_entries, rows)
        pages.append(page)
        records.extend(page_records)
    assert len(records) == 48
    write_reports(records, pages)
    print(f"PASS trainer approval gallery: {len(records)}/48 identities, {len(pages)} pages")
    print(f"output: {OUT}")


if __name__ == "__main__":
    main()
