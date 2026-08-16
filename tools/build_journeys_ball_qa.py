#!/usr/bin/env python3
"""Archive the renderer-backed Journeys ball matrix and build review sheets.

The LÖVE driver emits one native 160x144 viewport per state.  This tool is a
handoff tool: it copies those source PNGs into the Authority QA tree without
resampling them, validates the exact file matrix, and makes contact sheets that
show each complete viewport with external padding and two unclipped labels.
It deliberately does not claim visual approval; that remains a human review.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import shutil
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFont, PngImagePlugin

BALLS = ["POKE_BALL", "GREAT_BALL", "ULTRA_BALL", "MASTER_BALL", "SAFARI_BALL",
         "FAST_BALL", "LEVEL_BALL", "LURE_BALL", "HEAVY_BALL", "LOVE_BALL",
         "FRIEND_BALL", "MOON_BALL"]
PHASES = ["toss", "roll_shake", "breakout", "success_shake", "success_full_box", "no_catch", "block"]
RUNS = {
    "red_modern": "/tmp/ka-journeys-v2-red-modern",
    "red_original": "/tmp/ka-journeys-v2-red-original2",
    "blue_modern": "/tmp/ka-journeys-v2-blue-modern2",
    "blue_original": "/tmp/ka-journeys-v2-blue-original3",
    "yellow_modern": "/tmp/ka-journeys-v2-yellow-modern2",
    "yellow_original": "/tmp/ka-journeys-v2-yellow-original2",
}
FRAME_SIZE = (160, 144)  # Native Game Boy viewport, stored 1:1 in QA.
CONTACT_SCALE = 2        # Nearest-neighbour review cells; native frames stay separate.
OUT = Path(__file__).resolve().parents[1] / "qa" / "journeys_ball_matrix"
FRAMES = OUT / "frames"


def expected_names() -> list[str]:
    return [f"{ball}_{phase}.png" for ball in BALLS for phase in PHASES]


def font() -> ImageFont.ImageFont:
    # A bundled Pillow bitmap font is the deterministic fallback.  DejaVu is
    # present on the authoring host and keeps the labels readable in the sheet.
    try:
        return ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial.ttf", 18)
    except OSError:
        return ImageFont.load_default()


def label(draw: ImageDraw.ImageDraw, xy: tuple[int, int], text: str,
          width: int, face: ImageFont.ImageFont) -> None:
    box = draw.textbbox((0, 0), text, font=face)
    draw.text((xy[0] + (width - (box[2] - box[0])) // 2, xy[1]), text,
              fill="black", font=face)


def make_contacts(run: str, archive: Path) -> list[Path]:
    # Seven columns by one ball per page.  Keeping each review strip shallow
    # avoids large-image preview corruption while still comparing every state
    # side by side at a readable 2x nearest-neighbour scale.
    # remains 160x144; the review sheet uses a 2x nearest-neighbour copy so the
    # app's large-image preview cannot alias/cut the 1-bit Original palette.
    margin, label_gap, line_height = 8, 6, 22
    shown_w = FRAME_SIZE[0] * CONTACT_SCALE
    shown_h = FRAME_SIZE[1] * CONTACT_SCALE
    cell_w = shown_w + margin * 2
    cell_h = shown_h + margin * 2 + label_gap + line_height * 2
    contacts: list[Path] = []
    for page, first in enumerate(range(len(BALLS)), 1):
        page_balls = BALLS[first:first + 1]
        sheet = Image.new("RGB", (7 * cell_w, len(page_balls) * cell_h), "white")
        draw, face = ImageDraw.Draw(sheet), font()
        for ball_index, ball in enumerate(page_balls):
            for phase_index, phase in enumerate(PHASES):
                x, y = phase_index * cell_w, ball_index * cell_h
                with Image.open(archive / f"{ball}_{phase}.png") as source:
                    shown = source.convert("RGB").resize(
                        (shown_w, shown_h), Image.Resampling.NEAREST)
                    sheet.paste(shown, (x + margin, y + margin))
                label(draw, (x, y + margin * 2 + shown_h + label_gap),
                      ball.replace("_BALL", ""), cell_w, face)
                label(draw, (x, y + margin * 2 + shown_h + label_gap + line_height),
                      phase.replace("_", " "), cell_w, face)
        contact = OUT / f"{run}_contact_{page:02d}.png"
        pending = contact.with_name(contact.stem + ".pending.png")
        metadata = PngImagePlugin.PngInfo()
        metadata.add_text("KantoAscendantQAGrid",
                          "160x144-native-2x-nearest-review-v4-1-ball")
        sheet.save(pending, pnginfo=metadata)
        pending.replace(contact)
        # The Codex/app preview path can corrupt large high-frequency PNG
        # previews even though their decoded pixels verify.  Keep the exact
        # PNG as machine evidence and a high-quality JPEG as the human sheet.
        sheet.save(contact.with_suffix(".review.jpg"), "JPEG", quality=95,
                   subsampling=0, optimize=True)
        contacts.append(contact)
    return contacts


def make_ball_identity(run: str, archive: Path) -> Path:
    """Compact 12-ball overview using the real roll/shake capture."""
    margin, label_gap, line_height = 8, 6, 22
    shown_w = FRAME_SIZE[0] * CONTACT_SCALE
    shown_h = FRAME_SIZE[1] * CONTACT_SCALE
    cell_w = shown_w + margin * 2
    cell_h = shown_h + margin * 2 + label_gap + line_height
    sheet = Image.new("RGB", (4 * cell_w, 3 * cell_h), "white")
    draw, face = ImageDraw.Draw(sheet), font()
    for index, ball in enumerate(BALLS):
        x, y = (index % 4) * cell_w, (index // 4) * cell_h
        with Image.open(archive / f"{ball}_roll_shake.png") as source:
            shown = source.convert("RGB").resize(
                (shown_w, shown_h), Image.Resampling.NEAREST)
            sheet.paste(shown, (x + margin, y + margin))
        label(draw, (x, y + margin * 2 + shown_h + label_gap),
              ball.replace("_BALL", ""), cell_w, face)
    target = OUT / f"{run}_ball_identity.png"
    pending = target.with_name(target.stem + ".pending.png")
    sheet.save(pending)
    pending.replace(target)
    sheet.save(target.with_suffix(".review.jpg"), "JPEG", quality=95,
               subsampling=0, optimize=True)
    return target


def verify_ball_identity(target: Path, archive: Path) -> bool:
    margin = 8
    shown_w, shown_h = FRAME_SIZE[0] * CONTACT_SCALE, FRAME_SIZE[1] * CONTACT_SCALE
    cell_w = shown_w + margin * 2
    cell_h = shown_h + margin * 2 + 6 + 22
    with Image.open(target) as sheet:
        if sheet.size != (4 * cell_w, 3 * cell_h):
            return False
        sheet = sheet.convert("RGB")
        for index, ball in enumerate(BALLS):
            x = (index % 4) * cell_w + margin
            y = (index // 4) * cell_h + margin
            with Image.open(archive / f"{ball}_roll_shake.png") as frame:
                expected = frame.convert("RGB").resize(
                    (shown_w, shown_h), Image.Resampling.NEAREST)
            if ImageChops.difference(
                    sheet.crop((x, y, x + shown_w, y + shown_h)),
                    expected).getbbox() is not None:
                return False
    return True


def verify_contact(contact: Path, archive: Path, page: int) -> bool:
    """Prove every contact cell is the complete, unshifted logical frame."""
    margin = 8
    shown_w, shown_h = FRAME_SIZE[0] * CONTACT_SCALE, FRAME_SIZE[1] * CONTACT_SCALE
    cell_w = shown_w + margin * 2
    cell_h = shown_h + margin * 2 + 6 + 22 * 2
    with Image.open(contact) as sheet:
        first = page
        page_balls = BALLS[first:first + 1]
        if sheet.size != (7 * cell_w, len(page_balls) * cell_h):
            return False
        sheet = sheet.convert("RGB")
        for ball_index, ball in enumerate(page_balls):
            for phase_index, phase in enumerate(PHASES):
                x, y = phase_index * cell_w + margin, ball_index * cell_h + margin
                with Image.open(archive / f"{ball}_{phase}.png") as frame:
                    frame = frame.convert("RGB")
                    if frame.size != FRAME_SIZE:
                        return False
                    expected = frame.resize((shown_w, shown_h), Image.Resampling.NEAREST)
                    if ImageChops.difference(
                            sheet.crop((x, y, x + shown_w, y + shown_h)),
                            expected).getbbox() is not None:
                        return False
    return True


def archive_run(name: str, source: Path) -> dict[str, object]:
    expected = expected_names()
    expected_set = set(expected)
    actual = {path.name for path in source.glob("*.png")}
    missing, unexpected = sorted(expected_set - actual), sorted(actual - expected_set)
    target = FRAMES / name
    raw_target = target / "raw"
    target.mkdir(parents=True, exist_ok=True)
    raw_target.mkdir(parents=True, exist_ok=True)
    invalid_captures: list[str] = []
    capture_sizes: set[tuple[int, int]] = set()
    extraction: dict[str, int] | None = None
    for filename in expected:
        src = source / filename
        if not src.is_file():
            continue
        with Image.open(src) as image:
            capture_sizes.add(image.size)
            width, height = image.size
            scale = min(width // FRAME_SIZE[0], height // FRAME_SIZE[1])
            viewport_w, viewport_h = FRAME_SIZE[0] * scale, FRAME_SIZE[1] * scale
            x, y = (width - viewport_w) // 2, (height - viewport_h) // 2
            if scale < 1 or x < 0 or y < 0 or x + viewport_w > width or y + viewport_h > height:
                invalid_captures.append(f"{filename}: cannot extract GB viewport from {width}x{height}")
                continue
            current = {"x": x, "y": y, "width": viewport_w,
                       "height": viewport_h, "scale": scale}
            if extraction and current != extraction:
                invalid_captures.append(f"{filename}: capture viewport differs")
                continue
            extraction = current
            # Keep original full-window LÖVE evidence too.  The outward-facing
            # 160x144 frame is a nearest-neighbour crop of the centred GB
            # viewport, never an authored or interpolated replacement.
            shutil.copy2(src, raw_target / filename)
            frame = image.convert("RGB").crop((x, y, x + viewport_w, y + viewport_h))
            frame = frame.resize(FRAME_SIZE, Image.Resampling.NEAREST)
            frame.save(target / filename)
    archived = {path.name for path in target.glob("*.png")}
    raw_archived = {path.name for path in raw_target.glob("*.png")}
    stale = sorted(archived - expected_set)
    if stale:
        raise RuntimeError(f"{name}: unexpected archived files: {stale}")
    archived_missing = sorted(expected_set - archived)
    raw_missing = sorted(expected_set - raw_archived)
    wrong_dimensions: list[str] = []
    for filename in sorted(archived):
        with Image.open(target / filename) as image:
            if image.size != FRAME_SIZE:
                wrong_dimensions.append(f"{filename}: {image.size[0]}x{image.size[1]}")
    file_matrix_pass = not (missing or unexpected or invalid_captures
                            or wrong_dimensions or archived_missing or raw_missing)
    return {
        "expected": len(expected),
        "captured": len(actual),
        "archived": len(archived),
        "archive": f"frames/{name}",
        "rawArchive": f"frames/{name}/raw",
        "captureSizes": [
            {"width": width, "height": height}
            for width, height in sorted(capture_sizes)
        ],
        "viewportExtraction": extraction,
        "viewportRule": "independent centered integer-scale 160x144 extraction",
        "frameSize": {"width": FRAME_SIZE[0], "height": FRAME_SIZE[1]},
        "missing": missing,
        "unexpected": unexpected,
        "invalidCaptures": invalid_captures,
        "wrongDimensions": wrong_dimensions,
        "archiveMissing": archived_missing,
        "rawArchiveMissing": raw_missing,
        "fileMatrixPass": file_matrix_pass,
        "visualStatus": "pending",
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--contact-only", choices=sorted(RUNS),
                        help="regenerate and verify one archived contact sheet only")
    parser.add_argument("--approve-visual", metavar="REVIEWER",
                        help="record a manual approval for the current contact-sheet hashes")
    args = parser.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    report_path = OUT / "matrix_report.json"
    if args.approve_visual:
        report = json.loads(report_path.read_text())
        if not report.get("fileMatrixPass"):
            raise SystemExit("cannot approve: file matrix is not green")
        hashes: dict[str, str] = {}
        for name, run in report["runs"].items():
            if not (run.get("fileMatrixPass") and run.get("contactGridPass")):
                raise SystemExit(f"cannot approve: {name} did not pass grid verification")
            for contact_name in run["contactSheets"]:
                contact = OUT / contact_name
                hashes[contact_name] = hashlib.sha256(contact.read_bytes()).hexdigest()
            for review_name in run["reviewSheets"]:
                review = OUT / review_name
                hashes[review_name] = hashlib.sha256(review.read_bytes()).hexdigest()
            identity_name = run["ballIdentitySheet"]
            hashes[identity_name] = hashlib.sha256((OUT / identity_name).read_bytes()).hexdigest()
            review_identity = run["ballIdentityReview"]
            hashes[review_identity] = hashlib.sha256((OUT / review_identity).read_bytes()).hexdigest()
            run["visualStatus"] = "pass"
        report["visualStatus"] = "pass"
        report["pass"] = True
        report["manualReview"] = {
            "status": "pass",
            "reviewer": args.approve_visual,
            "date": "2026-08-11",
            "scope": (
                "R/B/Y × Modern/Original; all 12 ball identities plus "
                "Toss/Roll-Shake/Breakout/Success/Full-PC/No-Catch/Block; "
                "72 exact contact strips, their readable review derivatives "
                "and six 12-ball identity sheets"
            ),
            "contactSheetSha256": hashes,
        }
        report_path.write_text(json.dumps(report, indent=2) + "\n")
        print(f"journeys matrix visual approval: PASS ({args.approve_visual})")
        return
    if args.contact_only:
        report = json.loads(report_path.read_text())
        run = report["runs"][args.contact_only]
        archive = OUT / run["archive"]
        contacts = make_contacts(args.contact_only, archive)
        identity = make_ball_identity(args.contact_only, archive)
        run["contactSheets"] = [contact.name for contact in contacts]
        run["reviewSheets"] = [contact.with_suffix(".review.jpg").name for contact in contacts]
        run["ballIdentitySheet"] = identity.name
        run["ballIdentityReview"] = identity.with_suffix(".review.jpg").name
        run.pop("contactSheet", None)
        run["contactGridPass"] = all(
            verify_contact(contact, archive, page)
            for page, contact in enumerate(contacts)) and verify_ball_identity(identity, archive)
        if not run["contactGridPass"]:
            raise SystemExit(f"{args.contact_only}: contact cell verification failed")
        # Any regenerated review artifact invalidates an earlier human signoff.
        run["visualStatus"] = "pending"
        report["visualStatus"] = "pending"
        report["pass"] = False
        report.pop("manualReview", None)
        report["contactGridPass"] = all(
            candidate.get("contactGridPass") for candidate in report["runs"].values())
        report_path.write_text(json.dumps(report, indent=2) + "\n")
        print(f"journeys matrix contact: PASS ({args.contact_only}, 84 full native cells); visualStatus=pending")
        return
    report: dict[str, object] = {
        "format": 4,
        "balls": BALLS,
        "phases": PHASES,
        "fileMatrixPass": False,
        "contactGridPass": False,
        "visualStatus": "pending",
        "pass": False,
        "runtimeAnimation": {
            "sourceFramesPerBall": 8,
            "sourceFramesDistinct": True,
            "timingSource": "journeys_ball_skins.lua FRAME_TICKS driven by AnimPlayer elapsed",
            "captureDriver": "tests/journeys_ball_skins_visual_driver.lua",
        },
        "stateRationale": {
            "success_full_box": {
                "capturePoint": "real lockedBall success state after all party and PC slots are filled",
                "expectedVisual": "The text box is intentionally blank at this frozen handoff; the storage-full destination message is queued after this success beat.",
            },
            "block": {
                "capturePoint": "real trainer-battle BLOCKBALL_ANIM",
                "expectedVisual": "The frozen frame is the engine's trainer-catch prohibition effect; it is not a successful capture or a full-box message frame.",
            },
        },
        "runs": {},
    }
    runs: dict[str, dict[str, object]] = report["runs"]  # type: ignore[assignment]
    for name, raw in RUNS.items():
        source = Path(raw)
        if not source.is_dir():
            raise RuntimeError(f"{name}: unavailable capture source {source}")
        result = archive_run(name, source)
        contacts = make_contacts(name, OUT / str(result["archive"]))
        identity = make_ball_identity(name, OUT / str(result["archive"]))
        result["contactSheets"] = [contact.name for contact in contacts]
        result["reviewSheets"] = [contact.with_suffix(".review.jpg").name for contact in contacts]
        result["ballIdentitySheet"] = identity.name
        result["ballIdentityReview"] = identity.with_suffix(".review.jpg").name
        result["contactGridPass"] = all(
            verify_contact(contact, OUT / str(result["archive"]), page)
            for page, contact in enumerate(contacts)) and verify_ball_identity(
                identity, OUT / str(result["archive"]))
        if not result["contactGridPass"]:
            raise RuntimeError(f"{name}: contact cell verification failed")
        runs[name] = result
    report["fileMatrixPass"] = all(
        run["fileMatrixPass"] for run in runs.values()
    )
    report["contactGridPass"] = all(
        run["contactGridPass"] for run in runs.values()
    )
    (OUT / "matrix_report.json").write_text(json.dumps(report, indent=2) + "\n")
    if not report["fileMatrixPass"]:
        raise SystemExit(json.dumps(report, indent=2))
    print("journeys matrix file handoff: PASS (6 runs x 84 native frames); visualStatus=pending")


if __name__ == "__main__":
    main()
