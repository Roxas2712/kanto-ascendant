#!/usr/bin/env python3
"""Pixel, provenance and deterministic-build gate for the Yellow trio."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
MASTER = ROOT / "assets/sources/yellow_jessie_james/approved/jessie_james_meowth_battle_master_imagegen_approved_20260820.png"
PROVENANCE = ROOT / "assets/yellow_jessie_james/PROVENANCE.json"
REVIEW = ROOT / "assets/sources/yellow_jessie_james/review/jessie_james_meowth_contact_sheet.png"
EXPECTED = {
    "master": "8d4b4af1515b304cb6b1121bceb00078b142706558e589790d6dca5ce137736a",
    "provenance": "dbb193b6df0bf295b4567f56b90d16922bc85031d140ea96a6ebdcdae66d0892",
    "voxel64": "07fca69290146b89461746bf03777126cb0c65ff151a8a7846972481b0dbd164",
    "voxel128": "8b57885bdb1775bb2a43486af129976583229ca3a462e3c596943d8c55e5eb01",
    "failSafe": "c6c086d954fe828be6f407438e0c6203d19c6d32a427c4fc2773a4ec9d65e46f",
    "review": "ad6410ab71fb1b0d6cc3b2a7d8cb163cae3a4b03be252b09997f75fdc7804c19",
}
checks = 0


def check(value: bool, message: str) -> None:
    global checks
    checks += 1
    if not value:
        raise AssertionError(message)


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


check(MASTER.is_file(), "approved true-alpha master exists")
check(digest(MASTER) == EXPECTED["master"], "approved master SHA-256")
with Image.open(MASTER) as opened:
    master = opened.convert("RGBA")
    check(opened.mode == "RGBA" and opened.size == (1305, 1206),
          "approved master mode and dimensions")
    alpha_values = set(master.getchannel("A").getdata())
    check({0, 255} <= alpha_values and bool(alpha_values - {0, 255}),
          "master has genuine soft alpha, not a baked checkerboard")
    check(master.getchannel("A").getbbox() == (0, 11, 1257, 1206),
          "master silhouette is frozen")

receipt = json.loads(PROVENANCE.read_text(encoding="utf-8"))
check(digest(PROVENANCE) == EXPECTED["provenance"],
      "runtime provenance bytes are frozen")
check(receipt.get("schema") ==
      "kanto-ascendant-yellow-jessie-james-battle/v1",
      "runtime provenance schema")
check(receipt.get("approved") is True and
      receipt.get("visualStatus") == "approved-by-maintainer-2026-08-20",
      "runtime provenance records final visual approval")
approval = receipt.get("maintainerApproval", {})
check(approval == {
    "date": "2026-08-20",
    "decision": "approved",
    "scope": "jessie-james-meowth-voxel64-voxel128",
}, "runtime provenance pins the exact maintainer decision")
identity = receipt.get("identity", {})
check(identity.get("edition") == "yellow" and
      identity.get("class") == "OPP_ROCKET" and
      identity.get("minimumPartyIndex") == 42,
      "runtime provenance pins the Yellow party boundary")
check(identity.get("requires") == {
    "james": True, "jessie": True, "meowth": True,
}, "approved identity visibly requires Jessie, James and Meowth")
check(receipt.get("source", {}).get("sha256") == EXPECTED["master"],
      "both runtime sizes pin the approved master")

surfaces: dict[str, Image.Image] = {}
for role, size, palette_max, opaque in (
    ("voxel64", 64, 32, 1765),
    ("voxel128", 128, 64, 6851),
):
    row = receipt["assets"][role]
    path = ROOT / row["path"]
    check(path.is_file() and digest(path) == EXPECTED[role] == row["sha256"],
          f"{role} exact runtime bytes")
    image = Image.open(path).convert("RGBA")
    surfaces[role] = image
    check(image.size == (size, size), f"{role} exact dimensions")
    alpha = image.getchannel("A")
    check(set(alpha.getdata()) == {0, 255}, f"{role} binary alpha")
    check(all(alpha.getpixel(point) == 0 for point in (
        (0, 0), (size - 1, 0), (0, size - 1), (size - 1, size - 1))),
        f"{role} transparent corners")
    visible = [pixel for pixel in image.getdata() if pixel[3]]
    check(len(visible) == opaque, f"{role} frozen visible pixel count")
    check(len(set(visible)) <= palette_max, f"{role} hard pixel palette")
    check(row.get("sourceSha256") == EXPECTED["master"],
          f"{role} derives directly from the approved master")
    check("master-direct-lanczos" in row.get("transform", ""),
          f"{role} records a direct-master transform")

enlarged = surfaces["voxel64"].resize((128, 128), Image.Resampling.NEAREST)
check(enlarged.tobytes() != surfaces["voxel128"].tobytes(),
      "128 is not a nearest-neighbour enlargement of 64")
check(receipt["assets"]["voxel64"]["transform"] !=
      receipt["assets"]["voxel128"]["transform"],
      "64 and 128 have independent direct transform receipts")

fail_safe = ROOT / receipt["failSafe"]["path"]
check(digest(fail_safe) == EXPECTED["failSafe"] ==
      receipt["failSafe"]["sha256"], "exact bundled duo fail-safe")
check(digest(REVIEW) == EXPECTED["review"], "approved contact sheet is frozen")
with Image.open(REVIEW) as review:
    check(review.size == (2760, 1180), "contact sheet dimensions")

# Rebuild twice in a disposable tree. Both runtime sizes must remain direct,
# byte-identical products of the one copied approved master.
with tempfile.TemporaryDirectory(prefix="ka-jessie-james-rebuild-") as raw:
    rebuilt = Path(raw)
    (rebuilt / "tools").mkdir(parents=True)
    shutil.copy2(ROOT / "tools/build_jessie_james_battle_assets.py",
                 rebuilt / "tools/build_jessie_james_battle_assets.py")
    shutil.copytree(ROOT / "assets/sources/yellow_jessie_james/approved",
                    rebuilt / "assets/sources/yellow_jessie_james/approved")
    for relative in (
        "assets/characters/crystal_chars",
        "assets/characters/frlg_trainers",
        "assets/crystal_v15/trainers/normal",
    ):
        shutil.copytree(ROOT / relative, rebuilt / relative)
    command = [sys.executable,
               str(rebuilt / "tools/build_jessie_james_battle_assets.py")]
    subprocess.run(command, cwd=rebuilt, check=True,
                   capture_output=True, text=True)
    first = {
        role: digest(rebuilt / receipt["assets"][role]["path"])
        for role in ("voxel64", "voxel128")
    }
    first["provenance"] = digest(
        rebuilt / "assets/yellow_jessie_james/PROVENANCE.json")
    first["review"] = digest(
        rebuilt / "assets/sources/yellow_jessie_james/review/jessie_james_meowth_contact_sheet.png")
    subprocess.run(command, cwd=rebuilt, check=True,
                   capture_output=True, text=True)
    second = {
        role: digest(rebuilt / receipt["assets"][role]["path"])
        for role in ("voxel64", "voxel128")
    }
    second["provenance"] = digest(
        rebuilt / "assets/yellow_jessie_james/PROVENANCE.json")
    second["review"] = digest(
        rebuilt / "assets/sources/yellow_jessie_james/review/jessie_james_meowth_contact_sheet.png")
    check(first == second, "two independent rebuild passes are byte-identical")

    # Pillow/zlib may choose different valid PNG compression bytes on Linux
    # and macOS. The checked-in package bytes remain frozen above; a rebuild
    # must reproduce every RGBA pixel and the same semantic receipt, while its
    # receipt honestly records the hashes of the locally encoded PNGs.
    for role in ("voxel64", "voxel128"):
        approved_path = ROOT / receipt["assets"][role]["path"]
        rebuilt_path = rebuilt / receipt["assets"][role]["path"]
        with Image.open(approved_path) as approved_image, \
                Image.open(rebuilt_path) as rebuilt_image:
            approved_rgba = approved_image.convert("RGBA")
            rebuilt_rgba = rebuilt_image.convert("RGBA")
            check(rebuilt_rgba.size == approved_rgba.size and
                  rebuilt_rgba.tobytes() == approved_rgba.tobytes(),
                  f"rebuilt {role} RGBA pixels are frozen")

    rebuilt_receipt = json.loads(
        (rebuilt / "assets/yellow_jessie_james/PROVENANCE.json")
        .read_text(encoding="utf-8"))
    expected_receipt = json.loads(json.dumps(receipt))
    for role in ("voxel64", "voxel128"):
        expected_receipt["assets"][role]["sha256"] = first[role]
    check(rebuilt_receipt == expected_receipt,
          "rebuilt provenance preserves the approved semantic contract")

    with Image.open(REVIEW) as approved_review, Image.open(
            rebuilt / "assets/sources/yellow_jessie_james/review/"
            "jessie_james_meowth_contact_sheet.png") as rebuilt_review:
        approved_rgba = approved_review.convert("RGBA")
        rebuilt_rgba = rebuilt_review.convert("RGBA")
        check(rebuilt_rgba.size == approved_rgba.size and
              rebuilt_rgba.tobytes() == approved_rgba.tobytes(),
              "rebuilt review board RGBA pixels are frozen")

print(f"jessie_james_battle_assets_test: PASS ({checks} checks)")
