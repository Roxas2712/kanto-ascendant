#!/usr/bin/env python3
"""Pixel-level quality gate for Gorochu's Raichu-derived walking cycle."""
from __future__ import annotations

import struct
import zlib
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
checks = 0


def require(value: bool, message: str) -> None:
    global checks
    checks += 1
    if not value:
        raise AssertionError(message)


def rgba(path: Path) -> tuple[int, int, list[tuple[int, int, int, int]]]:
    data = path.read_bytes()
    require(data[:8] == b"\x89PNG\r\n\x1a\n", f"{path}: invalid PNG")
    pos, chunks = 8, []
    width = height = color_type = bit_depth = None
    while pos < len(data):
        size = struct.unpack(">I", data[pos:pos + 4])[0]
        kind = data[pos + 4:pos + 8]
        body = data[pos + 8:pos + 8 + size]
        pos += 12 + size
        if kind == b"IHDR":
            width, height, bit_depth, color_type = struct.unpack(">IIBB", body[:10])
        elif kind == b"IDAT":
            chunks.append(body)
        elif kind == b"IEND":
            break
    require(bit_depth == 8 and color_type == 6,
            f"{path}: quality decoder requires 8-bit RGBA")
    raw = zlib.decompress(b"".join(chunks))
    stride, bpp, rows, offset = width * 4, 4, [], 0
    previous = bytearray(stride)
    for _ in range(height):
        filter_type, offset = raw[offset], offset + 1
        scan = bytearray(raw[offset:offset + stride])
        offset += stride
        for i in range(stride):
            left = scan[i - bpp] if i >= bpp else 0
            up = previous[i]
            upper_left = previous[i - bpp] if i >= bpp else 0
            if filter_type == 1:
                scan[i] = (scan[i] + left) & 255
            elif filter_type == 2:
                scan[i] = (scan[i] + up) & 255
            elif filter_type == 3:
                scan[i] = (scan[i] + ((left + up) // 2)) & 255
            elif filter_type == 4:
                p = left + up - upper_left
                pa, pb, pc = abs(p - left), abs(p - up), abs(p - upper_left)
                predictor = left if pa <= pb and pa <= pc else up if pb <= pc else upper_left
                scan[i] = (scan[i] + predictor) & 255
            elif filter_type != 0:
                raise AssertionError(f"{path}: unsupported PNG filter {filter_type}")
        rows.append(scan)
        previous = scan
    pixels = [tuple(row[i:i + 4]) for row in rows for i in range(0, stride, 4)]
    return width, height, pixels


def frames(pixels: list[tuple[int, int, int, int]]) -> list[list[tuple[int, ...]]]:
    return [pixels[index * 256:(index + 1) * 256] for index in range(6)]


def mask(frame: list[tuple[int, ...]]) -> set[int]:
    return {index for index, pixel in enumerate(frame) if pixel[3] != 0}


def components(points: set[int]) -> int:
    pending, count = set(points), 0
    while pending:
        count += 1
        todo = [pending.pop()]
        while todo:
            value = todo.pop()
            x, y = value % 16, value // 16
            for dx, dy in (
                (-1, -1), (0, -1), (1, -1), (-1, 0),
                (1, 0), (-1, 1), (0, 1), (1, 1),
            ):
                nx, ny = x + dx, y + dy
                candidate = ny * 16 + nx
                if 0 <= nx < 16 and 0 <= ny < 16 and candidate in pending:
                    pending.remove(candidate)
                    todo.append(candidate)
    return count


raichu_path = ROOT / "assets/followers_kanto/follower_026.png"
normal_path = ROOT / "assets/followers_runtime/normal/follower_GOROCHU.png"
shiny_path = ROOT / "assets/followers_runtime/shiny/follower_GOROCHU.png"
source_normal_path = ROOT / "assets/followers/gorochu.png"
source_shiny_path = ROOT / "assets/followers/shiny/gorochu.png"

rw, rh, raichu = rgba(raichu_path)
nw, nh, normal = rgba(normal_path)
sw, sh, shiny = rgba(shiny_path)
require((rw, rh) == (16, 96), "Raichu quality base changed geometry")
require((nw, nh) == (16, 96) and (sw, sh) == (16, 96),
        "Gorochu runtime sheets must contain six 16x16 frames")

raichu_frames, normal_frames, shiny_frames = frames(raichu), frames(normal), frames(shiny)
require([mask(frame) for frame in normal_frames] == [mask(frame) for frame in shiny_frames],
        "normal and shiny walkers must share one exact silhouette")
require(len({tuple(frame) for frame in normal_frames}) == 6,
        "all six normal direction/gait frames must be distinct")
require(len({tuple(frame) for frame in shiny_frames}) == 6,
        "all six shiny direction/gait frames must be distinct")

for index, (base, current) in enumerate(zip(raichu_frames, normal_frames)):
    base_mask, current_mask = mask(base), mask(current)
    require(base_mask <= current_mask,
            f"frame {index}: Gorochu lost part of Raichu's stable silhouette")
    added = len(current_mask - base_mask)
    require(3 <= added <= 8,
            f"frame {index}: expected only a light horn modification, added {added} pixels")
    require(126 <= len(current_mask) <= 150,
            f"frame {index}: body occupancy is outside follower-family bounds")
    require(max(point // 16 for point in current_mask) == 15,
            f"frame {index}: walker is not grounded on the bottom pixel row")
    require(components(current_mask) == 1,
            f"frame {index}: horn/tail contains a disconnected pixel island")
    similarity = len(base_mask & current_mask) / len(base_mask | current_mask)
    require(similarity >= 0.94,
            f"frame {index}: silhouette no longer reads as the Raichu family")

for first, second in ((0, 3), (1, 4), (2, 5)):
    a, b = mask(normal_frames[first]), mask(normal_frames[second])
    overlap = len(a & b) / len(a | b)
    require(0.70 <= overlap < 0.90,
            f"gait pair {first}/{second}: incoherent or visually static ({overlap:.3f})")

normal_colors = {pixel for pixel in normal if pixel[3]}
shiny_colors = {pixel for pixel in shiny if pixel[3]}
require(len(normal_colors) == 4, "normal Gorochu must use four deliberate colors")
require(len(shiny_colors) == 4, "shiny Gorochu must use four deliberate colors")
require(normal_colors != shiny_colors, "shiny Gorochu must have a distinct palette")

# Prove the checked horizontal source sheets reproduce the runtime frames via
# the release builder's historic order, preventing source/runtime drift.
for source_path, expected in ((source_normal_path, normal_frames),
                              (source_shiny_path, shiny_frames)):
    width, height, source_pixels = rgba(source_path)
    require((width, height) == (96, 16), f"{source_path}: expected 96x16")
    source_frames = []
    for source_index in range(6):
        source_frames.append([
            source_pixels[y * 96 + source_index * 16 + x]
            for y in range(16) for x in range(16)
        ])
    rebuilt = [source_frames[index] for index in (4, 2, 0, 5, 3, 1)]
    require(rebuilt == expected, f"{source_path}: source/runtime order drift")

print(f"GOROCHU FOLLOWER QUALITY PASS: {checks} checks")
