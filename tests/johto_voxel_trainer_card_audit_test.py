#!/usr/bin/env python3
"""Static Johto/DRAMALESS authored Voxel-trainer asset gate."""

from __future__ import annotations

import hashlib
import os
from pathlib import Path
import struct
import zlib


ROOT = Path(__file__).resolve().parents[1]
ENGINE = Path(os.environ.get("GEN1RECOMP_DIR", ROOT.parents[1] / "gen1recomp"))
DRAMALESS = Path(os.environ.get(
    "DRAMALESS_DIR", ENGINE / "mods" / "DRAMALESS_SHAPE"
))


def png_size(path: Path) -> tuple[int, int]:
    raw = path.read_bytes()[:24]
    assert raw[:8] == b"\x89PNG\r\n\x1a\n", f"not PNG: {path}"
    assert raw[12:16] == b"IHDR", f"missing IHDR: {path}"
    return struct.unpack(">II", raw[16:24])


def png_rgba(path: Path) -> tuple[int, int, list[tuple[int, int, int, int]]]:
    """Decode the checked-in 8-bit RGBA PNGs without a Pillow dependency."""
    raw = path.read_bytes()
    assert raw[:8] == b"\x89PNG\r\n\x1a\n", f"not PNG: {path}"
    offset = 8
    header = None
    compressed: list[bytes] = []
    while offset < len(raw):
        length = struct.unpack(">I", raw[offset : offset + 4])[0]
        chunk_type = raw[offset + 4 : offset + 8]
        payload = raw[offset + 8 : offset + 8 + length]
        offset += 12 + length
        if chunk_type == b"IHDR":
            header = struct.unpack(">IIBBBBB", payload)
        elif chunk_type == b"IDAT":
            compressed.append(payload)
        elif chunk_type == b"IEND":
            break

    assert header, f"missing IHDR: {path}"
    width, height, depth, color_type, compression, filtering, interlace = header
    assert (depth, color_type, compression, filtering, interlace) == (8, 6, 0, 0, 0), (
        f"{path.name} must remain non-interlaced 8-bit RGBA"
    )
    packed = zlib.decompress(b"".join(compressed))
    stride = width * 4
    previous = bytearray(stride)
    rows: list[bytes] = []
    packed_offset = 0

    def paeth(left: int, above: int, upper_left: int) -> int:
        estimate = left + above - upper_left
        left_distance = abs(estimate - left)
        above_distance = abs(estimate - above)
        upper_left_distance = abs(estimate - upper_left)
        if left_distance <= above_distance and left_distance <= upper_left_distance:
            return left
        return above if above_distance <= upper_left_distance else upper_left

    for _ in range(height):
        filter_type = packed[packed_offset]
        packed_offset += 1
        row = bytearray(packed[packed_offset : packed_offset + stride])
        packed_offset += stride
        for index in range(stride):
            left = row[index - 4] if index >= 4 else 0
            above = previous[index]
            upper_left = previous[index - 4] if index >= 4 else 0
            if filter_type == 1:
                row[index] = (row[index] + left) & 0xFF
            elif filter_type == 2:
                row[index] = (row[index] + above) & 0xFF
            elif filter_type == 3:
                row[index] = (row[index] + ((left + above) // 2)) & 0xFF
            elif filter_type == 4:
                row[index] = (row[index] + paeth(left, above, upper_left)) & 0xFF
            else:
                assert filter_type == 0, f"unsupported PNG filter {filter_type}: {path}"
        rows.append(bytes(row))
        previous = row

    assert packed_offset == len(packed), f"unexpected PNG scanline payload: {path}"
    pixels = [
        tuple(row[index : index + 4])
        for row in rows
        for index in range(0, stride, 4)
    ]
    return width, height, pixels


compat = (ROOT / "extended_characters.lua").read_text()
passages = (ROOT / "johto_masters_passages.lua").read_text()
data = (ROOT / "johto_masters_data.lua").read_text()
dramaless = (DRAMALESS / "lib/OverworldBattle.lua").read_text()

assert "RIVAL_CLASS_SET[battle.oppClass]" in compat
assert "M.voxelStandingTrainerCharacter(battle, side)" in compat
assert "M.voxelStandingTrainerSpec(battle, side)" in compat
assert "local JOHTO_VOXEL_BY_CLASS" in compat
assert "local texture = originalSideTexture(battle, side)" in compat
for master in ("SILVER", "KRIS", "GOLD"):
    assert f'class = "KA_JOHTO_{master}"' in data
for forbidden in ("OPP_RIVAL2", "OPP_RIVAL3", "OPP_COOLTRAINER_F"):
    assert forbidden not in data, f"Johto data still aliases {forbidden}"

assert 'key=="gold" and "gold_front_color_v1.png"' in passages
assert "trueColor=true" in passages
assert "battle.showEnemyTrainer and battle.trainerPic" in dramaless
assert "innerPics(battle, 0, 0, 0)" in dramaless

baseline_front_hashes = {
    "silver": "53eb4c82d954f9b03059d47bd8a4823656489915ff2636ab2a9b31b6a06abea8",
    "kris": "6120bbb8b33437a2f90a821659d7da00209039f31ab41e996d656fa4882d07f4",
    "gold": "bb777eb354484e04fc719ae9e8b6494fdbee4e7da37b554c5bd46ce19eb1af5c",
}
protected_voxel_hashes = {
    "assets/characters/crystal_chars/red_voxel_front.png":
        "88d92e67d3168b4bdca3261f15d42788496bfbd127b103a49528681c650f851c",
    "assets/characters/crystal_chars/red_voxel_front_hd.png":
        "9bba6856d9e67608864bb83a5960073f984cbaed3f691544cbb6c20564d8bf66",
    "assets/characters/crystal_chars/blue_voxel_front.png":
        "8780eb313c2803ffa3c0ad40eef85cd51f6c3042834b274afa5718897c077ee5",
    "assets/characters/crystal_chars/blue_voxel_front_hd.png":
        "4fc8ecf0dfe081f3e1289d36c161cbe46c8b1d0cc28433c8716c3f8a4af4ae0b",
    "assets/characters/crystal_chars/green_voxel_front.png":
        "3da2769795bbb98f28d8d250ec968472b4c067fafc548a5636b36437020e20f8",
    "assets/characters/crystal_chars/green_voxel_front_hd.png":
        "ef4b0706f3e0684cedc624c4d490715c375d20b49cca8d1773e3d7436402c1cb",
    "assets/johto_masters/battle/silver_voxel_front.png":
        "bb036e76cf834ace1423516725cb77c03ae96fd44b389574397f37b9113a8766",
    "assets/johto_masters/battle/silver_voxel_front_hd.png":
        "2d1aaf4e0c85b10abebfcf07df1e75b67fed4225bdbeb381b0bea2ff456165f9",
    "assets/johto_masters/battle/kris_voxel_front.png":
        "ccc40bbdabd75d6ac16234ee87fd55e2de37e22a69c226302331571f4bb3c0fa",
    "assets/johto_masters/battle/kris_voxel_front_hd.png":
        "66cd4faa904aa4594d1e7ccdade4a0b2e8e33c9dd75afae53b08ef1274c7260e",
    "assets/johto_masters/battle/gold_voxel_front.png":
        "c70e7fddfa03583d47c274ab1f7a6f25ebc8bca91de9d141bc23f1040f3d901e",
    "assets/johto_masters/battle/gold_voxel_front_hd.png":
        "223ad39fe93ed13c58a5da3067ba9c514afa6842e96db1e64397e530f8861176",
}
for relative_path, expected_hash in protected_voxel_hashes.items():
    asset = ROOT / relative_path
    assert hashlib.sha256(asset.read_bytes()).hexdigest() == expected_hash, (
        f"protected Voxel trainer asset changed unexpectedly: {relative_path}"
    )

voxel_hashes: set[str] = set()
for key in ("silver", "kris", "gold"):
    front = ROOT / f"assets/johto_masters/battle/{key}_front.png"
    assert png_size(front) == (64, 64), f"{key} front is not 64x64"
    assert hashlib.sha256(front.read_bytes()).hexdigest() == baseline_front_hashes[key], (
        f"existing {key} 2D front was overwritten"
    )
    for suffix, size, max_colours, min_height, max_bottom in (
        ("_voxel_front.png", 64, 24, 54, 61),
        ("_voxel_front_hd.png", 128, 48, 108, 122),
    ):
        path = ROOT / f"assets/johto_masters/battle/{key}{suffix}"
        width, height, pixels = png_rgba(path)
        assert (width, height) == (size, size), f"{path.name} has wrong dimensions"
        assert {pixel[3] for pixel in pixels} <= {0, 255}, (
            f"{path.name} has a soft alpha halo"
        )
        assert all(pixels[y * width + x][3] == 0 for x, y in (
            (0, 0), (size - 1, 0), (0, size - 1), (size - 1, size - 1)
        )), f"{path.name} has opaque corners"
        opaque = [
            (index % width, index // width)
            for index, pixel in enumerate(pixels)
            if pixel[3]
        ]
        assert opaque, f"{path.name} is blank"
        top = min(y for _, y in opaque)
        bottom = max(y for _, y in opaque)
        assert bottom - top + 1 >= min_height, (
            f"{path.name} standing figure is too short"
        )
        assert bottom <= max_bottom, f"{path.name} lacks bottom padding"
        colours = len(set(pixels))
        assert colours <= max_colours + 1, f"{path.name} exceeds palette budget"
        voxel_hashes.add(hashlib.sha256(path.read_bytes()).hexdigest())

assert len(voxel_hashes) == 6, "each Johto Master needs unique 64/128 Voxel art"
gold_colour = ROOT / "assets/johto_masters/battle/gold_front_color_v1.png"
assert gold_colour.read_bytes() == (
    ROOT / "assets/johto_masters/battle/gold_voxel_front.png"
).read_bytes(), "Gold's coloured 2D front must use the approved new card"

print("johto_voxel_trainer_card_audit_test: PASS")
