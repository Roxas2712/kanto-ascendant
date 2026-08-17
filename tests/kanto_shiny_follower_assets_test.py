#!/usr/bin/env python3
"""Exact Crystal-index contract for all Kanto shiny follower walkers."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path
import re
import struct
import zlib


ROOT = Path(__file__).resolve().parents[1]
NORMAL = ROOT / "assets" / "followers_kanto"
SHINY = NORMAL / "shiny"
CONTRACT = SHINY / "palette_contract.json"


def png_rgba(path: Path) -> tuple[int, int, list[tuple[int, int, int, int]]]:
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
        distances = (abs(estimate - left), abs(estimate - above),
                     abs(estimate - upper_left))
        return (left, above, upper_left)[distances.index(min(distances))]

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
    assert packed_offset == len(packed), f"unexpected PNG payload: {path}"
    return width, height, [
        tuple(row[index : index + 4])
        for row in rows for index in range(0, stride, 4)
    ]


def colour(value: str) -> tuple[int, int, int]:
    assert re.fullmatch(r"#[0-9A-F]{6}", value), value
    return tuple(int(value[index : index + 2], 16) for index in (1, 3, 5))


def tree_hash(relative: str) -> str:
    digest = hashlib.sha256()
    for path in sorted((ROOT / relative).rglob("*")):
        if path.is_file():
            digest.update(path.relative_to(ROOT).as_posix().encode() + b"\0")
            digest.update(path.read_bytes())
    return digest.hexdigest()


assert tree_hash("assets/followers_runtime/normal") == (
    "1ee34abd14114013414784ca075394d2f8a7d7f4932a52b4794b162596430956"
), "Johto/extended/Gorochu normal walkers changed"
assert tree_hash("assets/followers_runtime/shiny") == (
    "957bf4714c5679b05004aa855ed6dbb58b59427736912dc7fc80bd55fc9e3c14"
), "Johto/extended/Gorochu shiny walkers changed"
assert tree_hash("assets/followers") == (
    "59cb29e5a453852e7fcfe9b48848d9d966ff3ec2e7cee725c060e6abc92ab010"
), "bundled Johto source walkers changed"

contract = json.loads(CONTRACT.read_text(encoding="utf-8"))
assert contract["schema"] == 1
assert contract["source"]["commit"] == "7a7881d0d62e0ddbd82dcf10e7116807487ac651"
assert contract["source"]["expansion"] == "5-bit channel << 3"
assert contract["source"]["auditAliases"] == {
    "nidoranf": "nidoran_f",
    "nidoranm": "nidoran_m",
    "farfetchd": "farfetch_d",
    "mr.mime": "mr__mime",
}
entries = contract["entries"]
assert len(entries) == 151

transform = (ROOT / "shiny_transforms.lua").read_text(encoding="utf-8")
packed = re.search(r'local COLORS = "([0-9a-f]+)"', transform).group(1)
assert len(packed) == 151 * 12

normal_hashes: set[str] = set()
shiny_hashes: set[str] = set()
for dex, entry in enumerate(entries, 1):
    assert entry["dex"] == dex
    normal_path = NORMAL / f"follower_{dex:03d}.png"
    shiny_path = SHINY / f"follower_{dex:03d}.png"
    assert hashlib.sha256(normal_path.read_bytes()).hexdigest() == entry["normalSha256"]
    assert hashlib.sha256(shiny_path.read_bytes()).hexdigest() == entry["shinySha256"]
    normal_hashes.add(entry["normalSha256"])
    shiny_hashes.add(entry["shinySha256"])

    width, height, normal_pixels = png_rgba(normal_path)
    shiny_width, shiny_height, shiny_pixels = png_rgba(shiny_path)
    assert (width, height) == (16, 96) == (shiny_width, shiny_height)
    assert len(normal_pixels) == len(shiny_pixels) == 16 * 96

    follower_colours = [colour(value) for value in entry["normalFollowerColours"]]
    crystal_normal = [colour(value) for value in entry["crystalNormal"]]
    crystal_shiny = [colour(value) for value in entry["crystalShiny"]]
    mapping = entry["crystalIndexByFollowerColour"]
    assert sorted(mapping) == sorted(entry["normalFollowerColours"])
    assert sorted(mapping.values()) == [1, 2]

    def distance(a: tuple[int, int, int], b: tuple[int, int, int]) -> int:
        return sum((left - right) ** 2 for left, right in zip(a, b))

    expected_indices = []
    for follower_colour in follower_colours:
        costs = [distance(follower_colour, role) for role in crystal_normal]
        assert costs[0] != costs[1], (
            f"ambiguous palette-index assignment at #{dex:03d}"
        )
        expected_indices.append(1 if costs[0] < costs[1] else 2)
    assert sorted(expected_indices) == [1, 2], (
        f"non-bijective palette-index assignment at #{dex:03d}"
    )
    assert [mapping[value] for value in entry["normalFollowerColours"]] == expected_indices

    offset = (dex - 1) * 12
    expected_shiny = [
        tuple(int(packed[offset + base : offset + base + 2], 16)
              for base in (0, 2, 4)),
        tuple(int(packed[offset + base : offset + base + 2], 16)
              for base in (6, 8, 10)),
    ]
    assert crystal_shiny == expected_shiny

    for normal_pixel, shiny_pixel in zip(normal_pixels, shiny_pixels):
        assert normal_pixel[3] == shiny_pixel[3], f"alpha changed at #{dex:03d}"
        if normal_pixel[3] == 0 or normal_pixel[:3] == (0, 0, 0):
            assert normal_pixel == shiny_pixel, f"geometry/black changed at #{dex:03d}"
            continue
        key = "#%02X%02X%02X" % normal_pixel[:3]
        assert key in mapping, f"unexpected normal colour {key} at #{dex:03d}"
        expected = crystal_shiny[mapping[key] - 1] + (normal_pixel[3],)
        assert shiny_pixel == expected, f"wrong Crystal index at #{dex:03d}"

assert entries[24]["crystalShiny"] == ["#F88800", "#A01058"]
assert len(normal_hashes) == 151
assert len(shiny_hashes) >= 145, "suspiciously duplicated shiny catalogue"

print("PASS Kanto shiny followers: 151 exact Crystal-index walkers; protected families byte-stable")
