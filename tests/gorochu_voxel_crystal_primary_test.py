#!/usr/bin/env python3
"""Release gate for Gorochu's native Crystal-style Voxel front lane."""

from __future__ import annotations

import hashlib
import subprocess
import tempfile
from collections import deque
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
PRIMARY = ROOT / "assets/voxel/gorochu/crystal"
FALLBACK = ROOT / "assets/voxel/gorochu/animation"
BUILDER = ROOT / "tools/build_gorochu_voxel_crystal_primary.py"
EXPECTED_PRIMARY_DIGEST = (
    "204bc36b47ae72f7f3ae7f00e6a3eff28204701f4737878a082b1c22e0e74500"
)
EXPECTED_FALLBACK_DIGEST = (
    "61a1f068e03ad632f60e20e6176a78d88f9ba8c3acf771844133220b8fdac439"
)
NORMAL = {
    (0, 0, 0, 255),
    (75, 35, 27, 255),
    (217, 84, 46, 255),
    (248, 184, 0, 255),
    (248, 232, 208, 255),
}
SHINY = {
    (20, 28, 38, 255),
    (40, 51, 66, 255),
    (99, 112, 127, 255),
    (244, 155, 33, 255),
    (255, 224, 173, 255),
}
checks = 0


def require(value: bool, message: str) -> None:
    global checks
    checks += 1
    if not value:
        raise AssertionError(message)


def digest(paths: list[Path]) -> str:
    hashes = "".join(hashlib.sha256(path.read_bytes()).hexdigest() for path in paths)
    return hashlib.sha256(hashes.encode()).hexdigest()


def components(alpha: Image.Image) -> list[set[tuple[int, int]]]:
    visible = {
        (x, y)
        for y in range(alpha.height)
        for x in range(alpha.width)
        if alpha.getpixel((x, y)) == 255
    }
    groups: list[set[tuple[int, int]]] = []
    while visible:
        seed = visible.pop()
        group = {seed}
        queue = deque([seed])
        while queue:
            x, y = queue.popleft()
            for nx, ny in (
                (x - 1, y - 1), (x, y - 1), (x + 1, y - 1),
                (x - 1, y),                 (x + 1, y),
                (x - 1, y + 1), (x, y + 1), (x + 1, y + 1),
            ):
                point = (nx, ny)
                if point in visible:
                    visible.remove(point)
                    group.add(point)
                    queue.append(point)
        groups.append(group)
    return sorted(groups, key=len, reverse=True)


def load_family(root: Path) -> dict[str, list[Image.Image]]:
    family: dict[str, list[Image.Image]] = {}
    for variant in ("normal", "shiny"):
        paths = sorted((root / variant).glob("*.png"))
        require(len(paths) == 6, f"{variant}: expected exactly six primary frames")
        family[variant] = [Image.open(path).convert("RGBA") for path in paths]
    return family


primary_paths = sorted(PRIMARY.glob("*/*.png"))
fallback_paths = sorted(FALLBACK.glob("*/*.png"))
require(len(primary_paths) == 12, "primary family contains exactly twelve files")
require(len(fallback_paths) == 12, "illustrated fallback contains exactly twelve files")
require(digest(primary_paths) == EXPECTED_PRIMARY_DIGEST,
        "primary matrix digest changed without review")
require(digest(fallback_paths) == EXPECTED_FALLBACK_DIGEST,
        "approved illustrated fallback bytes changed")

family = load_family(PRIMARY)
for variant, expected_palette in (("normal", NORMAL), ("shiny", SHINY)):
    frames = family[variant]
    require(len({frame.tobytes() for frame in frames}) == 6,
            f"{variant}: all six animation states must be distinct")
    for index, frame in enumerate(frames, 1):
        require(frame.size == (56, 56), f"{variant} {index}: native size is 56 px")
        alpha = frame.getchannel("A")
        require(set(alpha.getdata()) <= {0, 255},
                f"{variant} {index}: alpha is binary")
        require(all(pixel[:3] == (0, 0, 0) for pixel in frame.getdata() if pixel[3] == 0),
                f"{variant} {index}: transparent RGB is zero")
        colours = {pixel for pixel in frame.getdata() if pixel[3]}
        require(colours == expected_palette,
                f"{variant} {index}: exact five-colour palette is preserved")
        box = alpha.getbbox()
        require(box is not None and box[0] > 0 and box[1] > 0
                and box[2] < 56 and box[3] <= 56,
                f"{variant} {index}: artwork has a safe top/side canvas margin")
        groups = components(alpha)
        require(groups and len(groups[0]) >= sum(map(len, groups)) * 0.98,
                f"{variant} {index}: body and complete tail remain connected")
        require(all(len(group) <= 4 for group in groups[1:]),
                f"{variant} {index}: detached pixels are charge sparks only")

for index, (normal, shiny) in enumerate(zip(family["normal"], family["shiny"]), 1):
    require(normal.getchannel("A").tobytes() == shiny.getchannel("A").tobytes(),
            f"frame {index}: normal/shiny silhouette is identical")

# The two authored body poses must animate substantially, without turning into
# the huge silhouette jump seen in the rejected early candidate.
mask_a = set(components(family["normal"][0].getchannel("A"))[0])
mask_b = set(components(family["normal"][2].getchannel("A"))[0])
union = mask_a | mask_b
xor_ratio = len(mask_a ^ mask_b) / len(union)
require(0.12 <= xor_ratio <= 0.35,
        f"authored pose change must stay readable and stable (got {xor_ratio:.3f})")

with tempfile.TemporaryDirectory(prefix="ka-gorochu-primary-test-") as temp:
    output = Path(temp)
    subprocess.run(
        ["python3", str(BUILDER), "--output-root", str(output)],
        cwd=ROOT,
        check=True,
        capture_output=True,
        text=True,
    )
    rebuilt = sorted((output / "assets/voxel/gorochu/crystal").glob("*/*.png"))
    require(len(rebuilt) == 12, "deterministic rebuild emitted all twelve frames")
    for current, fresh in zip(primary_paths, rebuilt):
        require(current.relative_to(ROOT) == fresh.relative_to(output),
                "deterministic rebuild preserves relative paths")
        require(current.read_bytes() == fresh.read_bytes(),
                f"deterministic rebuild matches {current.relative_to(ROOT)}")

print(f"GOROCHU VOXEL CRYSTAL PRIMARY PASS: {checks} checks")
