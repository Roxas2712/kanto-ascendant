#!/usr/bin/env python3
"""Fail-closed gate for the approved 41-trainer live portrait set."""

from __future__ import annotations

import csv
import hashlib
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
LIVE = ROOT / "assets/characters/frlg_trainers"
GALLERY = ROOT / "qa/trainer_final_user_approval_20260812/MANIFEST.tsv"
RECEIPT = ROOT / "qa/trainer_approved_live_integration_20260812/LIVE_ASSET_MANIFEST.tsv"
APPROVAL = ROOT / "qa/trainer_approved_live_integration_20260812/APPROVAL_RECORD.tsv"
GALLERY_RECEIPTS = ROOT / "qa/trainer_final_user_approval_20260812/IMAGE_RECEIPTS.tsv"

# These are the exact CURRENT 64/128 files approved by the user.  A gallery
# rebuild or a resolver change must never silently mutate them.
PROTECTED = {
    "assets/characters/crystal_chars/red_voxel_front.png": "88d92e67d3168b4bdca3261f15d42788496bfbd127b103a49528681c650f851c",
    "assets/characters/crystal_chars/red_voxel_front_hd.png": "9bba6856d9e67608864bb83a5960073f984cbaed3f691544cbb6c20564d8bf66",
    "assets/characters/crystal_chars/blue_voxel_front.png": "8780eb313c2803ffa3c0ad40eef85cd51f6c3042834b274afa5718897c077ee5",
    "assets/characters/crystal_chars/blue_voxel_front_hd.png": "4fc8ecf0dfe081f3e1289d36c161cbe46c8b1d0cc28433c8716c3f8a4af4ae0b",
    "assets/characters/crystal_chars/green_voxel_front.png": "3da2769795bbb98f28d8d250ec968472b4c067fafc548a5636b36437020e20f8",
    "assets/characters/crystal_chars/green_voxel_front_hd.png": "ef4b0706f3e0684cedc624c4d490715c375d20b49cca8d1773e3d7436402c1cb",
    "assets/johto_masters/battle/silver_voxel_front.png": "bb036e76cf834ace1423516725cb77c03ae96fd44b389574397f37b9113a8766",
    "assets/johto_masters/battle/silver_voxel_front_hd.png": "2d1aaf4e0c85b10abebfcf07df1e75b67fed4225bdbeb381b0bea2ff456165f9",
    "assets/johto_masters/battle/kris_voxel_front.png": "ccc40bbdabd75d6ac16234ee87fd55e2de37e22a69c226302331571f4bb3c0fa",
    "assets/johto_masters/battle/kris_voxel_front_hd.png": "66cd4faa904aa4594d1e7ccdade4a0b2e8e33c9dd75afae53b08ef1274c7260e",
    "assets/johto_masters/battle/gold_voxel_front.png": "c70e7fddfa03583d47c274ab1f7a6f25ebc8bca91de9d141bc23f1040f3d901e",
    "assets/johto_masters/battle/gold_voxel_front_hd.png": "223ad39fe93ed13c58a5da3067ba9c514afa6842e96db1e64397e530f8861176",
    "assets/characters/frlg_trainers/professor_oak_voxel_front_v1.png": "a7999c98d9e4c98f087f113b9d5a6a6b2583b09acacf8626003fb2e7e40238a5",
    "assets/characters/frlg_trainers/professor_oak_voxel_front_hd_v1.png": "16c4ab75a3ea37a6e876726f85baa4e568d5ac14ffdb2e7e52cac7298858e209",
}


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


for relative, expected in PROTECTED.items():
    path = ROOT / relative
    assert path.is_file(), path
    assert sha256(path) == expected, (relative, sha256(path), expected)
johto_protected = [path for path in PROTECTED if path.startswith(
    "assets/johto_masters/battle/")]
assert len(johto_protected) == 6
assert {Path(path).name.split("_", 1)[0] for path in johto_protected} == {
    "silver", "kris", "gold"
}

with GALLERY.open(encoding="utf-8", newline="") as handle:
    gallery = list(csv.DictReader(handle, delimiter="\t"))
approved = [row for row in gallery if row["group"] != "fixed"
            and row["stem"] != "professor_oak"]
assert len(approved) == 41

with RECEIPT.open(encoding="utf-8", newline="") as handle:
    receipts = list(csv.DictReader(handle, delimiter="\t"))
assert len(receipts) == 82
assert {(row["stem"], row["size"]) for row in receipts} == {
    (row["stem"], size) for row in approved for size in ("64", "128")
}

with APPROVAL.open(encoding="utf-8", newline="") as handle:
    decisions = list(csv.DictReader(handle, delimiter="\t"))
with GALLERY_RECEIPTS.open(encoding="utf-8", newline="") as handle:
    historical_rows = list(csv.DictReader(handle, delimiter="\t"))
historical = {(row["slot"], row["path"]): row["sha256"]
              for row in historical_rows}
fixed = {"red", "blue", "green", "silver", "kris", "gold"}
assert len(decisions) == 48
assert sum(row["decision"] == "KEEP_CURRENT" for row in decisions) == 7
assert sum(row["decision"] == "PROMOTE_NEW_CANDIDATE" for row in decisions) == 41
for row in decisions:
    for path_key, hash_key in (("chosen_64", "chosen_64_sha256"),
                               ("chosen_128", "chosen_128_sha256"),
                               ("rollback_64", "rollback_64_sha256"),
                               ("rollback_128", "rollback_128_sha256")):
        assert sha256(ROOT / row[path_key]) == row[hash_key], (row["stem"], path_key)
    # Historical FRLG authority hashes remain in the private approval receipt,
    # but the copyrighted authority PNGs are deliberately absent from public
    # source and package trees.
    if row["stem"] not in fixed or row["stem"] == "red":
        assert not (ROOT / row["frlg_authority"]).exists()
    assert historical[("current_64", row["rollback_64"])] == row["rollback_64_sha256"]
    assert historical[("current_128", row["rollback_128"])] == row["rollback_128_sha256"]

# Full public 48x2 acceptance matrix. The six identity portraits remain fixed;
# ordinary trainers select the authored HD pair or their engine-owned Gen-I
# original. The removed FRLG mode survives only as a migration alias.
matrix = []
for row in decisions:
    for mode in ("crystal_hd", "original"):
        if row["stem"] in fixed:
            resolution = row["chosen_64_sha256"] + ":" + row["chosen_128_sha256"]
        elif mode == "crystal_hd":
            resolution = row["chosen_64_sha256"] + ":" + row["chosen_128_sha256"]
        else:
            resolution = "ENGINE_ORIGINAL:" + row["class_id"]
        matrix.append((row["stem"], mode, resolution))
assert len(matrix) == 96
assert len({(stem, mode) for stem, mode, _ in matrix}) == 96
assert all(resolution for _, _, resolution in matrix)

for receipt in receipts:
    source = ROOT / receipt["source"]
    live = ROOT / receipt["live"]
    assert receipt["install_policy"] == "VERSIONED_COPY_NO_OVERWRITE"
    assert source.is_file() and live.is_file()
    assert not (ROOT / receipt["authority"]).exists()
    assert sha256(source) == receipt["source_sha256"]
    assert sha256(live) == receipt["live_sha256"] == receipt["source_sha256"]
    assert live.name.endswith(("_v2.png", "_v3.png"))
    image = Image.open(live).convert("RGBA")
    size = int(receipt["size"])
    assert image.size == (size, size), (live, image.size)
    alpha = set(image.getchannel("A").getdata())
    assert alpha == {0, 255}, (live, alpha)
    assert image.getpixel((0, 0))[3] == 0
    assert image.getpixel((size - 1, size - 1))[3] == 0
    opaque = [pixel for pixel in image.getdata() if pixel[3]]
    # Every 64px release sibling is an exact nearest-neighbour reduction of
    # its approved 128px source; it may retain the source's complete 48-colour
    # palette without creating interpolation colours.
    assert len(set(opaque)) <= 48, live
    assert sum(max(pixel[:3]) <= 64 for pixel in opaque) / len(opaque) >= 0.04, live
    assert max(max(pixel[:3]) - min(pixel[:3]) for pixel in opaque) >= 80, live

print("APPROVED TRAINER PORTRAITS LIVE PASS: 41 identities / 82 authored files; "
      "native FRLG authorities absent; 48x2 public selected-hash matrix")
