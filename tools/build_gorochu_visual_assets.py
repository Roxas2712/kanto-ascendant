#!/usr/bin/env python3
"""Build independent Gorochu Voxel masters and follower sheets.

The 56 px Crystal battle cards are intentionally *not* inputs here. Voxel
needs the approved high-detail source, while the overworld follower needs six
authored directional poses. Keeping the pipelines separate prevents a later
Crystal rebuild from silently degrading either presentation.
"""

from __future__ import annotations

from collections import deque
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
MASTER = ROOT / "assets/sources/gorochu/gorochu_sprite_reference.png"
VOXEL_MASTER = (
    ROOT / "assets/sources/gorochu/gorochu_voxel_user_reference.png"
)
FOLLOWER_REFERENCE = (
    ROOT / "assets/sources/gorochu/gorochu_follower_pose_reference.png"
)
VOXEL_TARGET = ROOT / "assets/voxel/gorochu"
FOLLOWER_TARGET = ROOT / "assets/followers"
FOLLOWER_RUNTIME_TARGET = ROOT / "assets/followers_runtime"
QA_TARGET = ROOT.parent / "qa/gorochu-visual-quality"

VOXEL_CANVAS = (96, 96)
FOLLOWER_CANVAS = (16, 16)

# The source master is a 2x2 sheet:
# normal front/back, followed by shiny front/back.
MASTER_VIEWS = {
    ("front", "normal"): (0, 0),
    ("back", "normal"): (1, 0),
    ("front", "shiny"): (0, 1),
    ("back", "shiny"): (1, 1),
}

# The pose reference is a 3x2 sheet already in Gen1 Recomp runtime order:
# stand down/up/left, then walk down/up/left.
FOLLOWER_POSES = (
    "stand_down",
    "stand_up",
    "stand_left",
    "walk_down",
    "walk_up",
    "walk_left",
)

# Deliberate five-colour Crystal-era palettes. The same nearest-colour index
# is used for normal and shiny, guaranteeing identical silhouettes.
NORMAL_PALETTE = (
    (41, 26, 26, 255),
    (77, 46, 43, 255),
    (230, 69, 36, 255),
    (255, 171, 41, 255),
    (255, 230, 184, 255),
)
SHINY_PALETTE = (
    (20, 28, 38, 255),
    (41, 51, 66, 255),
    (99, 112, 128, 255),
    (245, 156, 33, 255),
    (255, 224, 173, 255),
)

# Source order expected by the existing PokeWilds-compatible converter:
# side still/walk, up still/walk, down still/walk.
POKEWILDS_FROM_RUNTIME = (2, 5, 1, 4, 0, 3)


def alpha_box(image: Image.Image) -> tuple[int, int, int, int]:
    box = image.getchannel("A").getbbox()
    if not box:
        raise ValueError("source contains no visible pixels")
    return box


def clear_connected_sheet_background(image: Image.Image) -> Image.Image:
    """Remove the user's magenta review matte without touching highlights."""
    rgba = image.convert("RGBA")
    pixels = rgba.load()
    width, height = rgba.size
    visited: set[tuple[int, int]] = set()
    queue: deque[tuple[int, int]] = deque()

    def outside(pixel: tuple[int, int, int, int]) -> bool:
        red, green, blue, alpha = pixel
        magenta = red >= 175 and blue >= 175 and green <= 115
        review_white = red >= 235 and green >= 235 and blue >= 235
        return alpha < 96 or magenta or review_white

    for x in range(width):
        queue.append((x, 0))
        queue.append((x, height - 1))
    for y in range(height):
        queue.append((0, y))
        queue.append((width - 1, y))

    while queue:
        x, y = queue.popleft()
        if (x, y) in visited or not outside(pixels[x, y]):
            continue
        visited.add((x, y))
        pixels[x, y] = (0, 0, 0, 0)
        if x > 0:
            queue.append((x - 1, y))
        if x + 1 < width:
            queue.append((x + 1, y))
        if y > 0:
            queue.append((x, y - 1))
        if y + 1 < height:
            queue.append((x, y + 1))
    # Tail loops enclose a few islands of the same review matte, so they are
    # not reachable from the border flood. Gorochu's authored reds/pinks have
    # far less blue; remove only saturated magenta remnants globally.
    for y in range(height):
        for x in range(width):
            red, green, blue, alpha = pixels[x, y]
            if alpha and red >= 160 and blue >= 160 and green <= 135:
                pixels[x, y] = (0, 0, 0, 0)
    # The review export contains two isolated antialias pixels above the
    # normal rear view. Keep the body and intentionally detached lightning
    # bolt, but discard microscopic matte debris before measuring geometry.
    visited.clear()
    for y in range(height):
        for x in range(width):
            if pixels[x, y][3] == 0 or (x, y) in visited:
                continue
            component: list[tuple[int, int]] = []
            queue = deque([(x, y)])
            visited.add((x, y))
            while queue:
                current_x, current_y = queue.popleft()
                component.append((current_x, current_y))
                for neighbor in (
                    (current_x - 1, current_y),
                    (current_x + 1, current_y),
                    (current_x, current_y - 1),
                    (current_x, current_y + 1),
                ):
                    if (
                        0 <= neighbor[0] < width
                        and 0 <= neighbor[1] < height
                        and neighbor not in visited
                        and pixels[neighbor[0], neighbor[1]][3] > 0
                    ):
                        visited.add(neighbor)
                        queue.append(neighbor)
            if len(component) < 64:
                for component_x, component_y in component:
                    pixels[component_x, component_y] = (0, 0, 0, 0)
    return rgba


def hard_alpha(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    pixels = rgba.load()
    for y in range(rgba.height):
        for x in range(rgba.width):
            red, green, blue, alpha = pixels[x, y]
            pixels[x, y] = (
                (red, green, blue, 255)
                if alpha >= 96
                else (0, 0, 0, 0)
            )
    return rgba


def resize_palette_locked(
    image: Image.Image,
    size: tuple[int, int],
    source_palette: tuple[tuple[int, int, int, int], ...] | None = None,
    target_palette: tuple[tuple[int, int, int, int], ...] | None = None,
) -> Image.Image:
    """Reduce pixel art cleanly, then snap every visible pixel to its palette."""
    reduced = image.resize(size, Image.Resampling.LANCZOS).convert("RGBA")
    if not (source_palette and target_palette):
        return hard_alpha(reduced)
    output = Image.new("RGBA", size, (0, 0, 0, 0))
    source = reduced.load()
    target = output.load()
    for y in range(size[1]):
        for x in range(size[0]):
            pixel = source[x, y]
            if pixel[3] < 96:
                continue
            index = min(
                range(len(source_palette)),
                key=lambda candidate: sum(
                    (source_palette[candidate][channel] - pixel[channel]) ** 2
                    for channel in range(3)
                ),
            )
            target[x, y] = target_palette[index]
    return output


def fit(
    source: Image.Image,
    canvas: tuple[int, int],
    *,
    max_content: tuple[int, int],
    bottom_margin: int = 1,
    source_palette: tuple[tuple[int, int, int, int], ...] | None = None,
    target_palette: tuple[tuple[int, int, int, int], ...] | None = None,
) -> Image.Image:
    cropped = source.crop(alpha_box(source))
    scale = min(
        max_content[0] / cropped.width,
        max_content[1] / cropped.height,
    )
    width = max(1, round(cropped.width * scale))
    height = max(1, round(cropped.height * scale))
    reduced = resize_palette_locked(
        cropped,
        (width, height),
        source_palette,
        target_palette,
    )
    reduced_box = alpha_box(reduced)
    frame = Image.new("RGBA", canvas, (0, 0, 0, 0))
    visible_width = reduced_box[2] - reduced_box[0]
    x = (canvas[0] - visible_width) // 2 - reduced_box[0]
    y = canvas[1] - bottom_margin - reduced_box[3]
    frame.alpha_composite(reduced, (x, y))
    return frame


def build_voxel() -> dict[tuple[str, str], Image.Image]:
    with Image.open(VOXEL_MASTER) as opened:
        sheet = clear_connected_sheet_background(opened)
    half_width, half_height = sheet.width // 2, sheet.height // 2
    result: dict[tuple[str, str], Image.Image] = {}
    VOXEL_TARGET.mkdir(parents=True, exist_ok=True)
    for (side, variant), (column, row) in MASTER_VIEWS.items():
        quadrant = sheet.crop((
            column * half_width,
            row * half_height,
            (column + 1) * half_width,
            (row + 1) * half_height,
        ))
        frame = fit(
            quadrant,
            VOXEL_CANVAS,
            max_content=(92, 94),
            bottom_margin=1,
        )
        suffix = "_shiny" if variant == "shiny" else ""
        target = VOXEL_TARGET / f"gorochu_{side}{suffix}.png"
        frame.save(target, "PNG", optimize=False)
        result[(side, variant)] = frame
    return result


def follower_cells() -> list[Image.Image]:
    with Image.open(FOLLOWER_REFERENCE) as opened:
        sheet = opened.convert("RGBA")
    cell_width, cell_height = sheet.width // 3, sheet.height // 2
    cells: list[Image.Image] = []
    for index in range(6):
        column, row = index % 3, index // 3
        cells.append(sheet.crop((
            column * cell_width,
            row * cell_height,
            (column + 1) * cell_width,
            (row + 1) * cell_height,
        )))
    return cells


def build_follower_variant(
    cells: list[Image.Image],
    variant: str,
) -> tuple[Image.Image, Image.Image]:
    palette = SHINY_PALETTE if variant == "shiny" else NORMAL_PALETTE
    runtime_frames = [
        fit(
            cell,
            FOLLOWER_CANVAS,
            # Long lightning tails need the full width. One transparent top
            # row protects the tallest horn; feet remain on the baseline.
            max_content=(16, 15),
            bottom_margin=0,
            source_palette=NORMAL_PALETTE,
            target_palette=palette,
        )
        for cell in cells
    ]

    runtime = Image.new("RGBA", (16, 96), (0, 0, 0, 0))
    for index, frame in enumerate(runtime_frames):
        runtime.alpha_composite(frame, (0, index * 16))

    horizontal = Image.new("RGBA", (96, 16), (0, 0, 0, 0))
    for target_index, runtime_index in enumerate(POKEWILDS_FROM_RUNTIME):
        horizontal.alpha_composite(
            runtime_frames[runtime_index],
            (target_index * 16, 0),
        )

    source_dir = FOLLOWER_TARGET / ("shiny" if variant == "shiny" else "")
    runtime_dir = FOLLOWER_RUNTIME_TARGET / variant
    source_dir.mkdir(parents=True, exist_ok=True)
    runtime_dir.mkdir(parents=True, exist_ok=True)
    horizontal.save(source_dir / "gorochu.png", "PNG", optimize=False)
    runtime.save(
        runtime_dir / "follower_GOROCHU.png",
        "PNG",
        optimize=False,
    )
    return horizontal, runtime


def nearest_preview(image: Image.Image, scale: int) -> Image.Image:
    return image.resize(
        (image.width * scale, image.height * scale),
        Image.Resampling.NEAREST,
    )


def build_review(
    voxel: dict[tuple[str, str], Image.Image],
    follower_runtime: dict[str, Image.Image],
) -> None:
    QA_TARGET.mkdir(parents=True, exist_ok=True)
    paper = (224, 232, 210, 255)

    voxel_review = Image.new("RGBA", (384, 384), paper)
    order = (
        ("front", "normal"),
        ("back", "normal"),
        ("front", "shiny"),
        ("back", "shiny"),
    )
    for index, key in enumerate(order):
        voxel_review.alpha_composite(
            nearest_preview(voxel[key], 2),
            ((index % 2) * 192, (index // 2) * 192),
        )
    voxel_review.save(QA_TARGET / "gorochu_voxel_masters_2x.png", "PNG")

    follower_review = Image.new("RGBA", (384, 192), paper)
    for variant_index, variant in enumerate(("normal", "shiny")):
        runtime = follower_runtime[variant]
        for frame_index, _ in enumerate(FOLLOWER_POSES):
            frame = runtime.crop((
                0,
                frame_index * 16,
                16,
                frame_index * 16 + 16,
            ))
            follower_review.alpha_composite(
                nearest_preview(frame, 4),
                (
                    frame_index * 64,
                    variant_index * 96 + 16,
                ),
            )
    follower_review.save(QA_TARGET / "gorochu_follower_poses_4x.png", "PNG")


def validate(
    voxel: dict[tuple[str, str], Image.Image],
    follower_runtime: dict[str, Image.Image],
) -> None:
    lines: list[str] = []
    for key, image in voxel.items():
        if image.size != VOXEL_CANVAS:
            raise ValueError(f"Voxel {key} is {image.size}, expected 96x96")
        box = alpha_box(image)
        if box[2] - box[0] <= 56 or box[3] - box[1] <= 56:
            raise ValueError(f"Voxel {key} was reduced to Crystal-card detail")
        for _, color in image.getcolors(maxcolors=1_000_000) or []:
            red, green, blue, alpha = color
            if alpha and red >= 160 and blue >= 160 and green <= 135:
                raise ValueError(f"Voxel {key} still contains magenta matte")
        lines.append(f"PASS voxel {key[1]} {key[0]}: 96x96, alpha box {box}")

    normal = follower_runtime["normal"]
    shiny = follower_runtime["shiny"]
    if normal.size != (16, 96) or shiny.size != (16, 96):
        raise ValueError("Follower runtime sheets must be 16x96")
    if normal.getchannel("A").tobytes() != shiny.getchannel("A").tobytes():
        raise ValueError("Normal/shiny follower silhouettes diverged")
    for variant, sheet in follower_runtime.items():
        frames = [
            sheet.crop((0, index * 16, 16, (index + 1) * 16))
            for index in range(6)
        ]
        if len({frame.tobytes() for frame in frames}) != 6:
            raise ValueError(f"{variant} follower has duplicate pose frames")
        if len({
            frame.getchannel("A").tobytes()
            for frame in frames
        }) != 6:
            raise ValueError(f"{variant} follower lacks six distinct gaits")
        for index, frame in enumerate(frames):
            box = alpha_box(frame)
            if box[3] != 16:
                raise ValueError(
                    f"{variant} {FOLLOWER_POSES[index]} is not grounded: {box}"
                )
            if box[0] == 0 and box[2] == 16 and index != 4:
                raise ValueError(
                    f"{variant} {FOLLOWER_POSES[index]} clips both edges"
                )
        lines.append(
            f"PASS follower {variant}: 16x96, six unique grounded poses"
        )

    QA_TARGET.mkdir(parents=True, exist_ok=True)
    (QA_TARGET / "ASSET_AUDIT.txt").write_text(
        "\n".join(lines) + "\n",
        encoding="utf-8",
    )


def main() -> int:
    for required in (MASTER, VOXEL_MASTER, FOLLOWER_REFERENCE):
        if not required.is_file():
            raise FileNotFoundError(required)
    voxel = build_voxel()
    cells = follower_cells()
    follower_runtime: dict[str, Image.Image] = {}
    for variant in ("normal", "shiny"):
        _, runtime = build_follower_variant(cells, variant)
        follower_runtime[variant] = runtime
    validate(voxel, follower_runtime)
    build_review(voxel, follower_runtime)
    print(
        "Built 4 dedicated 96px Voxel masters, 2 six-pose follower "
        "sources/runtime sheets, and QA previews."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
