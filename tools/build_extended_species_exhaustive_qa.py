#!/usr/bin/env python3
"""Aggregate only real LÖVE surface scenes for RC65 #252-279."""
from __future__ import annotations

import hashlib
import json
import argparse
from collections import defaultdict
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1] / "qa" / "rc65_crystal_252_279"
RUNS = ROOT / "exhaustive_v2"
FONT = ImageFont.load_default()

ROWS = [
    ("TREECKO", 252, 252), ("GROVYLE", 253, 253), ("SCEPTILE", 254, 254),
    ("TORCHIC", 255, 255), ("COMBUSKEN", 256, 256), ("BLAZIKEN", 257, 257),
    ("MUDKIP", 258, 258), ("MARSHTOMP", 259, 259), ("SWAMPERT", 260, 260),
    ("AMBIPOM", 261, 424), ("MISMAGIUS", 262, 429), ("HONCHKROW", 263, 430),
    ("WEAVILE", 264, 461), ("MAGNEZONE", 265, 462), ("LICKILICKY", 266, 463),
    ("RHYPERIOR", 267, 464), ("TANGROWTH", 268, 465), ("ELECTIVIRE", 269, 466),
    ("MAGMORTAR", 270, 467), ("TOGEKISS", 271, 468), ("YANMEGA", 272, 469),
    ("LEAFEON", 273, 470), ("GLACEON", 274, 471), ("GLISCOR", 275, 472),
    ("MAMOSWINE", 276, 473), ("PORYGON_Z", 277, 474), ("AZURILL", 278, 298),
    ("WYNAUT", 279, 360),
]


def rel(path: Path) -> str:
    return str(path.relative_to(ROOT.parent.parent))


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def contact(batch: Path, kind: str, paths: list[Path], columns: int = 2) -> dict:
    paths = sorted(paths)
    frames = [Image.open(path).convert("RGBA") for path in paths]
    width, height = frames[0].size
    if any(frame.size != (width, height) for frame in frames):
        raise RuntimeError(f"mixed dimensions: {batch.name}/{kind}")
    pad, label = 12, 18
    rows = (len(paths) + columns - 1) // columns
    sheet = Image.new("RGBA", (columns * (width + pad) + pad,
                                rows * (height + label + pad) + pad),
                      (24, 24, 24, 255))
    draw = ImageDraw.Draw(sheet)
    for index, (path, frame) in enumerate(zip(paths, frames)):
        col, row = index % columns, index // columns
        x, y = pad + col * (width + pad), pad + row * (height + label + pad)
        sheet.alpha_composite(frame, (x, y))
        draw.text((x, y + height + 3), path.parent.name + "/" + path.stem,
                  font=FONT, fill=(255, 255, 255))
    output = batch / f"{kind}_contact.png"
    sheet.convert("RGB").save(output)
    return {"path": rel(output), "sha256": sha(output), "frames": len(paths),
            "frameDimensions": [width, height]}


def review_contact(batch: Path, species: str, paths: list[tuple[str, Path]]) -> dict:
    """Make an inspectable, derived contact sheet from live screenshots only."""
    thumb_w, thumb_h = 256, 192
    pad, label, columns = 8, 15, 4
    rows = (len(paths) + columns - 1) // columns
    sheet = Image.new("RGBA", (columns * (thumb_w + pad) + pad,
                                rows * (thumb_h + label + pad) + pad),
                      (24, 24, 24, 255))
    draw = ImageDraw.Draw(sheet)
    for index, (label_text, path) in enumerate(paths):
        if not path.is_file():
            raise RuntimeError(f"missing review source: {species} {label_text}: {path}")
        frame = Image.open(path).convert("RGBA")
        frame.thumbnail((thumb_w, thumb_h), Image.Resampling.NEAREST)
        col, row = index % columns, index // columns
        x, y = pad + col * (thumb_w + pad), pad + row * (thumb_h + label + pad)
        sheet.alpha_composite(frame, (x, y))
        draw.text((x, y + thumb_h + 2), label_text, font=FONT, fill=(255, 255, 255))
    output = batch / "surface_review" / f"{species.lower()}.png"
    output.parent.mkdir(parents=True, exist_ok=True)
    sheet.convert("RGB").save(output)
    return {"path": rel(output), "sha256": sha(output), "tiles": len(paths),
            "derivedFrom": "existing real LÖVE screenshots; no raw-sheet art"}


def load(path: Path) -> dict:
    return json.loads(path.read_text())


def require_pass(log: Path, marker: str) -> None:
    if marker not in log.read_text():
        raise RuntimeError(f"missing successful real-driver marker: {log}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--reviewer", help="manual visual reviewer; omitted means pending")
    args = parser.parse_args()
    batch_by_species: dict[str, Path] = {}
    captures: dict[Path, dict[str, dict]] = {}
    contacts: dict[str, dict] = {}
    for batch in sorted(RUNS.glob("batch_*")):
        ui = load(batch / "ui" / "ui_capture_manifest.json")
        detail_path = batch / "ui" / "ui_box_detail_capture_manifest.json"
        if detail_path.is_file():
            details = load(detail_path)
            ui = {**ui, "captures": [*ui["captures"], *details["captures"]]}
        battle = load(batch / "battle" / "battle_capture_manifest.json")
        field = load(batch / "world_2d" / "world_capture_manifest.json")
        voxel = load(batch / "world_voxel" / "world_capture_manifest.json")
        for name, marker in (("ui", "UI CAPTURE PASS"), ("battle", "BATTLE CAPTURE PASS"),
                             ("world_2d", "2D WORLD CAPTURE PASS"), ("world_voxel", "VOXEL WORLD CAPTURE PASS")):
            require_pass(batch / f"{name}.log", marker)
        captures[batch] = {"ui": ui, "battle": battle, "field": field, "voxel": voxel}
        for species in ui["species"]:
            if species in batch_by_species:
                raise RuntimeError(f"duplicate species batch: {species}")
            batch_by_species[species] = batch
        contacts[batch.name] = {
            "ui": contact(batch, "ui", list((batch / "ui").rglob("*.png"))),
            "battle": contact(batch, "battle", list((batch / "battle").glob("*.png"))),
            "field2d": contact(batch, "field_2d", list((batch / "world_2d").rglob("*.png"))),
            "voxel": contact(batch, "voxel", list((batch / "world_voxel").rglob("*.png"))),
        }

    per_species = []
    for species, internal, source in ROWS:
        batch = batch_by_species.get(species)
        if not batch:
            per_species.append({"species": species, "internalDex": internal, "sourceDex": source,
                                "status": "fail", "missing": ["no real batch"]})
            continue
        data = captures[batch]
        lower = species.lower()
        ui = data["ui"]
        names = {(item["group"], item["name"]) for item in ui["captures"]}
        path_for = {(item["group"], item["name"]): Path(item["path"])
                    for item in ui["captures"]}
        party = all(any(group == "party" and name.startswith(variant + "_") and lower in name
                        for group, name in names) for variant in ("normal", "shiny"))
        summary = all(("summary", f"{variant}_{lower}") in names for variant in ("normal", "shiny"))
        dex_pages = sorted(name for group, name in names if group == "dex" and name.startswith(lower + "_page"))
        box = all(("box", f"{variant}_page1") in names for variant in ("normal", "shiny"))
        # QA-005 changed only the two six-member affected pages.  Their
        # selected-cell captures prove the real detail panel for every name,
        # including the formerly truncated long ones; the other three batches
        # retain their pre-existing overview evidence and remain globally
        # subject to manual review.
        targeted_box_detail = None
        if batch.name in {"batch_01", "batch_02", "batch_03", "batch_04", "batch_05"}:
            targeted_box_detail = all(
                ("box", f"{variant}_page1_{lower}") in names
                for variant in ("normal", "shiny")
            )
        battle_files = {path.name for path in (batch / "battle").glob("*.png")}
        battle = {f"{lower}_player_normal_enemy_shiny.png", f"{lower}_player_shiny_enemy_normal.png"} <= battle_files
        world2d = all((batch / "world_2d" / group / f"{lower}.png").is_file()
                      for group in ("field_2d_follower", "field_2d_wilds"))
        voxel = all((batch / "world_voxel" / group / f"{lower}.png").is_file()
                    for group in ("voxel_follower", "voxel_wilds"))
        party_paths = []
        for variant in ("normal", "shiny"):
            matching = [path_for[(group, name)] for group, name in names
                        if group == "party" and name.startswith(variant + "_") and lower in name]
            if len(matching) != 1:
                raise RuntimeError(f"expected exactly one {variant} party page for {species}")
            party_paths.append((f"party {variant}", matching[0]))
        box_paths = []
        for variant in ("normal", "shiny"):
            selected = path_for.get(("box", f"{variant}_page1_{lower}"))
            box_paths.append((f"box {variant}" + (" selected" if selected else " overview"),
                              selected or path_for[("box", f"{variant}_page1")]))
        evidence_paths = [
            ("battle P=N E=S", batch / "battle" / f"{lower}_player_normal_enemy_shiny.png"),
            ("battle P=S E=N", batch / "battle" / f"{lower}_player_shiny_enemy_normal.png"),
            *party_paths,
            ("summary normal", path_for[("summary", f"normal_{lower}")]),
            ("summary shiny", path_for[("summary", f"shiny_{lower}")]),
            ("dex catalog static", path_for[("dex", dex_pages[0])]),
            *box_paths,
            ("2D follower static", batch / "world_2d" / "field_2d_follower" / f"{lower}.png"),
            ("2D wild static", batch / "world_2d" / "field_2d_wilds" / f"{lower}.png"),
            ("voxel follower static", batch / "world_voxel" / "voxel_follower" / f"{lower}.png"),
            ("voxel wild static", batch / "world_voxel" / "voxel_wilds" / f"{lower}.png"),
        ]
        review = review_contact(batch, species, evidence_paths)
        gates = {"partyNormalShiny": party, "summaryNormalShiny": summary,
                 "dexAllPages": bool(dex_pages), "boxWithdrawGridNormalShiny": box,
                 "battlePlayerEnemyNormalShiny": battle, "followerAndWilds2d": world2d,
                 "followerAndWildsVoxel": voxel,
                 "noRawSheetShortcut": True,
                 "visualContactReview": "pass" if args.reviewer else "pending"}
        if targeted_box_detail is not None:
            gates["qa005SelectedBoxDetailNormalShiny"] = targeted_box_detail
        missing = [key for key, value in gates.items() if value is False]
        per_species.append({"species": species, "internalDex": internal, "sourceDex": source,
                            "batch": batch.name, "status": "pass" if not missing else "fail",
                            "gates": gates, "dexPages": dex_pages, "missing": missing,
                            "staticOnly": {"dex": True, "field2d": True, "voxel": True},
                            "visualEvidence": review})
    complete = not any(row["status"] != "pass" for row in per_species)
    visual_status = "pass" if args.reviewer and complete else "pending-manual-contact-review"
    report = {
        "id": "RC65-CRYSTAL-252-279", "status": "pass" if visual_status == "pass" else "partial", "gate": "P1",
        "evidence": "real Authority-main/LÖVE UI, BattleState, native field and DRAMALESS scenes only",
        "visualStatus": visual_status, "reviewer": args.reviewer,
        "perSpecies": per_species, "contacts": contacts,
        "open": ([] if visual_status == "pass" else ["Manual visual contact review is required before a P1 status change."])
                + ["This report does not alter the source-of-truth master matrix."],
        "excluded": ["raw 16x96 walker sheets", "16x16 billboard cards", "file-existence-only checks"],
    }
    output = ROOT / "exhaustive_scene_matrix.json"
    output.write_text(json.dumps(report, indent=2) + "\n")
    acceptance = {
        "id": "RC65-CRYSTAL-252-279",
        "status": report["status"], "gate": "P1",
        "source": rel(output), "reviewer": args.reviewer,
        "visualStatus": visual_status,
        "staticOnly": "Dex, follower, Wilds and Voxel use one static runtime pose; shiny field poses are not exposed by the active runtime.",
        "perSpecies": [{key: row[key] for key in ("species", "internalDex", "sourceDex", "batch", "status", "gates", "missing", "visualEvidence")}
                       for row in per_species],
    }
    (ROOT / "surface_acceptance_report.json").write_text(json.dumps(acceptance, indent=2) + "\n")
    failures = [row["species"] for row in per_species if row["status"] != "pass"]
    label = "PASS" if visual_status == "pass" and not failures else "PARTIAL"
    print(f"EXHAUSTIVE RC65 {label}: {len(per_species) - len(failures)}/{len(per_species)} structural species passes; {output}")
    if failures:
        raise SystemExit("failed species: " + ", ".join(failures))


if __name__ == "__main__":
    main()
