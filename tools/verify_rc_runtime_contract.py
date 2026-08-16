#!/usr/bin/env python3
"""Fail closed when a Kanto Ascendant RC and its real engine drift apart.

This gate deliberately validates the *shipped* archive and the *shipped*
``.love`` payload.  A green source checkout is not enough: RC27 proved that a
mod can be packed correctly while depending on engine APIs which never reach
the player's application.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
from pathlib import Path, PurePosixPath
import sys
import zipfile


ENGINE_CONTRACT = {
    "src/world/WallDecals.lua": (
        b"function WallDecals.draw",
        b"decal.cellX",
    ),
    "src/world/OverworldController.lua": (
        b'require("src.world.WallDecals")',
        b"WallDecals.draw",
    ),
    "src/render/Renderer.lua": (
        b"function Renderer:queueWorldPostOverlay",
        b"worldPostOverlays",
    ),
    "src/render/SpriteRenderer.lua": (
        b"__alphaSafeTrueColorWorld = true",
    ),
    "src/mods/Schemas.lua": (
        b"wallDecals",
        b"battleTheme",
        b'callStyle = f.opt(f.enum{ "context", "legacyArgs" })',
        b"mapAtmospheres",
        b"throwFrames",
        b"lootExcluded",
    ),
    "src/core/Music.lua": (
        b"function Music.playBattle(data, kind, trainerId, song)",
        b"song or b[kind] or b.wild",
    ),
    "src/mods/Manifest.lua": (
        b"function Manifest.exclusiveAllows",
        b"function Manifest.exclusiveBlock",
        b"function Manifest.replacement",
    ),
    "src/mods/Loader.lua": (
        b"function Loader:_enforceReplacements",
    ),
    "src/mods/ManagerState.lua": (
        b"Manifest.exclusiveBlock",
    ),
    "src/mods/LauncherMods.lua": (
        b"Manifest.exclusiveBlock",
        b"Manifest.replacement",
    ),
    "src/inventory/ItemEffects.lua": (
        b'effectDef.callStyle == "legacyArgs"',
        b"Runtime.reportError",
    ),
    "src/battle/BattleState.lua": (
        b'Runtime.wantsHook("battle.wild")',
        b"validTrainerPartyDef",
        b"YELLOW_OAK_PIKACHU_ENCOUNTER",
        b"imageBattleThrow",
        b"trainer.battleTheme",
        b"function BattleState:playBattleTheme()",
    ),
    "src/pokemon/Stats.lua": (
        b'Runtime.wantsHook("pokemon.stats.def")',
    ),
    "src/ui/PlayerPC.lua": (
        b'Runtime.wantsHook("ui.player_pc.items")',
        b'kind = "pc_item_withdraw"',
        b'kind = "pc_item_deposit"',
        b'kind = "pc_item_toss"',
    ),
    "src/ui/ListMenu.lua": (
        b"self.onStartKey = opts.onStartKey",
        b"self.controlHint = opts.controlHint",
        b'input:wasPressed("start")',
    ),
    "src/ui/ShopMenu.lua": (
        b'kind = "shop_buy"',
        b'kind = "shop_sell"',
    ),
    "src/world/Map.lua": (
        b"def.waterTiles or tilesetDef.waterTiles",
        b"self.grassTiles",
    ),
    "src/world/NPC.lua": (
        b"objDef.passable == true",
    ),
    "src/world/Player.lua": (
        b"self.fishingSprite or self.sprite",
    ),
    "data/scripts/story2.lua": (
        b"BattleState.YELLOW_OAK_PIKACHU_ENCOUNTER",
        b"randomizerProtected = true",
    ),
}


# These identities are not optional presentation samples. Red/Blue/Green are
# the frozen playable/rival family; Silver/Kris/Gold are the three Johto
# Masters. Missing one source from an otherwise valid pack must reject the RC.
REQUIRED_CHARACTER_ASSETS = tuple(
    [
        f"assets/characters/crystal_chars/{character}_{state}.png"
        for character in ("red", "blue", "green")
        for state in (
            "walk", "bike", "fish", "front", "back",
            "voxel_front", "voxel_front_hd",
        )
    ]
    + [
        f"assets/characters/crystal_chars/{character}_back_throw_{frame}.png"
        for character in ("red", "blue", "green")
        for frame in range(1, 6)
    ]
    + [
        f"assets/johto_masters/field/{character}_walk.png"
        for character in ("silver", "kris", "gold")
    ]
    + [
        f"assets/johto_masters/battle/{character}_{state}.png"
        for character in ("silver", "kris", "gold")
        for state in ("front", "voxel_front", "voxel_front_hd")
    ]
    + [
        "assets/johto_masters/battle/gold_front_color_v1.png",
        "assets/johto_masters/battle/gold_back.png",
        "assets/johto_masters/battle/kris_back.png",
    ]
)

MODULE_ACCEPTANCE_MAP = Path(
    "qa/rc28_release_gate_20260812/MODULE_ACCEPTANCE_MAP.tsv"
)
PUBLIC_ROOT_FILES = {
    ".modkitromallow",
    "CHANGELOG.md",
    "FAQ.md",
    "README.md",
    "THIRD_PARTY_NOTICES.md",
    "manifest.json",
    "mod.card",
}
FORBIDDEN_PACKAGE_PREFIXES = (
    "art_review/",
    "artifacts/",
    "assets/sources/",
    "docs/",
    "qa/",
    "tests/",
    "tools/",
)
ABSOLUTE_LOCAL_PATH_MARKERS = (
    b"/Users/",
    b"/home/",
    b"C:\\Users\\",
    b"C:/Users/",
    b"/private/var/folders/",
    b"/tmp/",
)


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


class Source:
    def __init__(self, path: Path):
        self.path = path
        self.archive: zipfile.ZipFile | None = None
        if path.is_file():
            self.archive = zipfile.ZipFile(path)

    def read(self, name: str) -> bytes:
        if self.archive is not None:
            return self.archive.read(name)
        return (self.path / name).read_bytes()

    def names(self) -> set[str]:
        if self.archive is not None:
            return {
                info.filename
                for info in self.archive.infolist()
                if not info.is_dir()
            }
        return {
            item.relative_to(self.path).as_posix()
            for item in self.path.rglob("*")
            if item.is_file()
        }

    def close(self) -> None:
        if self.archive is not None:
            self.archive.close()


def safe_pack_path(raw: str) -> str:
    path = PurePosixPath(raw)
    if path.is_absolute() or ".." in path.parts or raw != path.as_posix():
        raise ValueError(f"unsafe/non-canonical pack path: {raw!r}")
    return raw


def product_modules(mod_root: Path, errors: list[str]) -> set[str]:
    """Read the frozen reverse map without accepting permissive TSV shapes."""
    path = mod_root / MODULE_ACCEPTANCE_MAP
    try:
        text = path.read_text(encoding="utf-8")
    except OSError as exc:
        errors.append(f"module acceptance map missing/unreadable: {exc}")
        return set()
    if not text.endswith("\n"):
        errors.append("module acceptance map has no final newline")
    lines = text.splitlines()
    if not lines or any(not line for line in lines):
        errors.append("module acceptance map is empty or has a blank row")
        return set()
    rows = list(csv.reader(lines, delimiter="\t"))
    if rows[0] != ["module", "acceptance_group"]:
        errors.append(f"module acceptance map header drifted: {rows[0]!r}")
        return set()
    modules: list[str] = []
    for line_number, (raw, row) in enumerate(zip(lines[1:], rows[1:]), 2):
        if len(row) != 2 or raw != "\t".join(row):
            errors.append(
                f"module acceptance map line {line_number} is not canonical TSV"
            )
            continue
        module, group = row
        if (not module or not group or module != module.strip()
                or group != group.strip()
                or "/" in module or not module.endswith(".lua")):
            errors.append(
                f"module acceptance map line {line_number} has invalid fields"
            )
            continue
        modules.append(module)
    duplicates = sorted(name for name in set(modules) if modules.count(name) > 1)
    if duplicates:
        errors.append(
            "duplicate module acceptance paths: " + ", ".join(duplicates)
        )
    return set(modules)


def validate_engine(engine: Source, errors: list[str], facts: list[str]) -> None:
    error_count = len(errors)
    names = engine.names()
    for name, markers in ENGINE_CONTRACT.items():
        if name not in names:
            errors.append(f"engine capability file missing: {name}")
            continue
        data = engine.read(name)
        missing = [marker.decode("ascii") for marker in markers if marker not in data]
        if missing:
            errors.append(f"engine capability missing in {name}: {', '.join(missing)}")
    if len(errors) == error_count:
        facts.append(f"engine contract: {len(ENGINE_CONTRACT)}/{len(ENGINE_CONTRACT)} files")


def validate_package(
    archive: Source,
    mod_root: Path,
    errors: list[str],
    facts: list[str],
) -> None:
    if archive.archive is None:
        errors.append("mod archive must be a .zip/.modpkg file")
        return
    names = archive.names()
    manifest_name = ".modkit/pack.json"
    if manifest_name not in names:
        errors.append("mod archive is missing .modkit/pack.json")
        return
    try:
        pack = json.loads(archive.read(manifest_name))
    except (json.JSONDecodeError, UnicodeDecodeError) as exc:
        errors.append(f"invalid .modkit/pack.json: {exc}")
        return
    if pack.get("id") != "kanto_ascendant":
        errors.append(f"unexpected package id: {pack.get('id')!r}")
    rows = pack.get("files")
    if not isinstance(rows, list) or not rows:
        errors.append("pack manifest contains no files")
        return

    expected: set[str] = set()
    for index, row in enumerate(rows):
        if not isinstance(row, dict):
            errors.append(f"pack row {index} is not an object")
            continue
        try:
            name = safe_pack_path(row["path"])
        except (KeyError, TypeError, ValueError) as exc:
            errors.append(f"pack row {index}: {exc}")
            continue
        if name in expected:
            errors.append(f"duplicate pack path: {name}")
            continue
        expected.add(name)
        if name not in names:
            errors.append(f"archive file missing: {name}")
            continue
        packaged = archive.read(name)
        local_markers = [
            marker.decode("ascii")
            for marker in ABSOLUTE_LOCAL_PATH_MARKERS
            if marker in packaged
        ]
        if local_markers:
            errors.append(
                f"developer-machine absolute path leaked in {name}: "
                + ", ".join(local_markers)
            )
        if row.get("bytes") != len(packaged):
            errors.append(f"archive byte count mismatch: {name}")
        if row.get("sha256") != digest(packaged):
            errors.append(f"archive SHA-256 mismatch: {name}")

        source_path = mod_root / name
        if not source_path.is_file():
            errors.append(f"current authority file missing: {name}")
            continue
        current = source_path.read_bytes()
        if current != packaged:
            errors.append(
                "package is stale against authority: "
                f"{name} (zip {digest(packaged)[:12]}, source {digest(current)[:12]})"
            )

    unexpected = sorted(names - expected - {manifest_name})
    if unexpected:
        preview = ", ".join(unexpected[:5])
        suffix = " ..." if len(unexpected) > 5 else ""
        errors.append(f"unexpected archive files ({len(unexpected)}): {preview}{suffix}")

    mapped_modules = product_modules(mod_root, errors)
    packaged_modules = {
        name for name in expected
        if "/" not in name and name.endswith(".lua")
    }
    missing_modules = sorted(mapped_modules - packaged_modules)
    unexpected_modules = sorted(packaged_modules - mapped_modules)
    if missing_modules or unexpected_modules:
        errors.append(
            "mapped product module package mismatch; missing: "
            + (", ".join(missing_modules) or "NONE")
            + "; unexpected: "
            + (", ".join(unexpected_modules) or "NONE")
        )

    packaged_root = {name for name in expected if "/" not in name}
    expected_root = mapped_modules | PUBLIC_ROOT_FILES
    missing_root = sorted(expected_root - packaged_root)
    unexpected_root = sorted(packaged_root - expected_root)
    if missing_root or unexpected_root:
        errors.append(
            "top-level package boundary mismatch; missing: "
            + (", ".join(missing_root) or "NONE")
            + "; unexpected: "
            + (", ".join(unexpected_root) or "NONE")
        )

    leaked = sorted(
        name for name in expected
        if name.startswith(FORBIDDEN_PACKAGE_PREFIXES)
    )
    if leaked:
        preview = ", ".join(leaked[:5])
        suffix = " ..." if len(leaked) > 5 else ""
        errors.append(
            f"internal QA/source files leaked into package ({len(leaked)}): "
            f"{preview}{suffix}"
        )

    missing_character_assets = sorted(set(REQUIRED_CHARACTER_ASSETS) - expected)
    if missing_character_assets:
        errors.append(
            "required six-character assets missing from pack manifest: "
            + ", ".join(missing_character_assets)
        )
    facts.append(f"package manifest rows: {len(expected)}")
    if mapped_modules and not missing_modules and not unexpected_modules:
        facts.append(
            f"mapped top-level product modules: "
            f"{len(mapped_modules)}/{len(mapped_modules)}"
        )
    if not missing_character_assets:
        facts.append(
            "fixed Red/Blue/Green/Silver/Kris/Gold assets: "
            f"{len(REQUIRED_CHARACTER_ASSETS)}/{len(REQUIRED_CHARACTER_ASSETS)}"
        )


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--mod-root", required=True, type=Path)
    parser.add_argument("--mod-archive", required=True, type=Path)
    parser.add_argument(
        "--engine",
        required=True,
        type=Path,
        help="the exact shipped .love payload, or an unpacked engine root",
    )
    parser.add_argument("--report", type=Path)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    errors: list[str] = []
    facts: list[str] = []
    sources: list[Source] = []
    try:
        for label, path in (
            ("mod root", args.mod_root),
            ("mod archive", args.mod_archive),
            ("engine", args.engine),
        ):
            if not path.exists():
                errors.append(f"{label} does not exist: {path}")
        if not errors:
            archive = Source(args.mod_archive)
            engine = Source(args.engine)
            sources.extend((archive, engine))
            validate_package(archive, args.mod_root, errors, facts)
            validate_engine(engine, errors, facts)
            facts.append(
                "engine archive SHA-256: "
                + (digest(args.engine.read_bytes()) if args.engine.is_file() else "directory")
            )
    except (OSError, KeyError, zipfile.BadZipFile) as exc:
        errors.append(str(exc))
    finally:
        for source in sources:
            source.close()

    lines = ["RC RUNTIME CONTRACT: " + ("FAIL" if errors else "PASS")]
    lines.extend(f"INFO: {fact}" for fact in facts)
    lines.extend(f"ERROR: {error}" for error in errors)
    output = "\n".join(lines) + "\n"
    sys.stdout.write(output)
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(output, encoding="utf-8")
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
