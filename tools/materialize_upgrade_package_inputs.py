#!/usr/bin/env python3
"""Materialize L01's immutable historical package inputs, fail closed.

The command accepts product archives only.  It never reads a save directory,
slot, user profile or arbitrary glob.  The sole save-shaped input used by the
runtime is the reviewed schema-derived fixture shipped in Authority source.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import stat
import tempfile
import zipfile


HERE = Path(__file__).resolve().parent
AUTHORITY = HERE.parent
FIXTURE = AUTHORITY / "tests/fixtures/upgrade_package_sources.lua"
MANIFEST = AUTHORITY / "tools/upgrade_package_matrix_manifest.lua"
DRIVER = AUTHORITY / "tests/upgrade_matrix_package_driver.lua"

SOURCES = (
    {
        "key": "v6_0_11",
        "relative": "qa/kanto-ascendant-6.0.11.modpkg",
        "archive": "kanto-ascendant-6.0.11.modpkg",
        "bytes": 16662061,
        "sha256": "72779b0a9923e2e3908573552858718aa09bc6eae25222d1268bf3f1e41b62e7",
    },
    {
        "key": "rc25",
        "relative": "kanto-ascendant-6.5.0-rc25-test.zip",
        "archive": "kanto-ascendant-6.5.0-rc25-test.zip",
        "bytes": 37749193,
        "sha256": "9d340d9badf940adc7bd1a36b43d66a4d02b84229a63df8c5caa85939fdab9a5",
    },
    {
        "key": "rc26",
        "relative": "kanto-ascendant-6.5.0-rc26-test.zip",
        "archive": "kanto-ascendant-6.5.0-rc26-test.zip",
        "bytes": 37794577,
        "sha256": "0b0fcd765a1dd6d64584d2dd5c116bbabf9a8218c77314e7d5de5937d63e2418",
    },
    {
        "key": "rc27",
        "relative": "kanto-ascendant-6.5.0-rc27-test.zip",
        "archive": "kanto-ascendant-6.5.0-rc27-test.zip",
        "bytes": 37983841,
        "sha256": "fb870c51b22ac87be7a3c79ec98e6fe798196946c96abec439e5915d99af5912",
    },
)

SAVE_SHAPED = re.compile(
    r"(?:^|/)(?:save(?:_[a-z0-9_-]+)?|slot[0-9]+)\.(?:lua|sav|json|dat)$",
    re.IGNORECASE,
)


class MaterializeError(RuntimeError):
    pass


def fail(message: str) -> None:
    raise MaterializeError(message)


def sha256(path: Path) -> str:
    value = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            value.update(block)
    return value.hexdigest()


def regular_file(path: Path, label: str) -> None:
    if not path.is_file() or path.is_symlink():
        fail(f"{label} is missing, not regular, or a symlink: {path}")


def inspect_archive(path: Path, expected: dict[str, object]) -> dict[str, object]:
    regular_file(path, str(expected["key"]))
    if path.stat().st_size != expected["bytes"] or sha256(path) != expected["sha256"]:
        fail(f"{expected['key']} immutable size/SHA-256 mismatch")
    try:
        with zipfile.ZipFile(path) as archive:
            names: list[str] = []
            for info in archive.infolist():
                relative = PurePosixPath(info.filename)
                if relative.is_absolute() or ".." in relative.parts:
                    fail(f"{expected['key']} contains an unsafe archive path")
                if stat.S_ISLNK(info.external_attr >> 16):
                    fail(f"{expected['key']} contains a symlink")
                if not info.is_dir():
                    names.append(relative.as_posix())
            if "manifest.json" not in names:
                fail(f"{expected['key']} lacks manifest.json")
            save_rows = sorted(name for name in names if SAVE_SHAPED.search(name))
            if save_rows:
                fail(f"{expected['key']} unexpectedly contains save-shaped data")
    except (OSError, zipfile.BadZipFile) as exc:
        fail(f"{expected['key']} is not a readable product archive: {exc}")
    return {
        "key": expected["key"],
        "archive": expected["archive"],
        "bytes": expected["bytes"],
        "sha256": expected["sha256"],
        "save_shaped_members": 0,
    }


def verify(source_root: Path) -> list[tuple[Path, dict[str, object]]]:
    if not source_root.is_dir() or source_root.is_symlink():
        fail("historical product-archive root is missing or a symlink")
    regular_file(FIXTURE, "schema-derived fixture")
    regular_file(MANIFEST, "L01 matrix manifest")
    regular_file(DRIVER, "L01 package driver")
    fixture = FIXTURE.read_text("utf-8")
    for marker in (
        'kind = "schema-derived-sanitized"',
        "publishedSave = false",
        "containsPlayerPII = false",
        "no published player save",
    ):
        if marker not in fixture:
            fail(f"schema-derived fixture lacks provenance marker {marker!r}")
    rows = []
    for expected in SOURCES:
        path = source_root.joinpath(*PurePosixPath(str(expected["relative"])).parts)
        rows.append((path, inspect_archive(path, expected)))
    return rows


def materialize(source_root: Path, target: Path) -> dict[str, object]:
    rows = verify(source_root)
    if target.exists() or target.is_symlink():
        fail("immutable target already exists; refusing to merge or overwrite")
    if target.name != "upgrade_sources" or target.parent.name != "immutable_inputs":
        fail("target must end in immutable_inputs/upgrade_sources")
    target.parent.mkdir(parents=True, exist_ok=True)
    staging = Path(tempfile.mkdtemp(prefix=".upgrade_sources.", dir=target.parent))
    try:
        for source, row in rows:
            shutil.copyfile(source, staging / str(row["archive"]), follow_symlinks=False)
        shutil.copyfile(FIXTURE, staging / "upgrade_package_sources.lua", follow_symlinks=False)
        shutil.copyfile(MANIFEST, staging / "upgrade_package_matrix_manifest.lua", follow_symlinks=False)
        shutil.copyfile(DRIVER, staging / "upgrade_matrix_package_driver.lua", follow_symlinks=False)
        receipt = {
            "schema": "ka-l01-upgrade-immutable-inputs/v1",
            "provenance": "schema-derived-sanitized",
            "published_player_save": False,
            "contains_player_pii": False,
            "source_count": 4,
            "edition_count": 3,
            "cell_count": 12,
            "processes_per_cell": 4,
            "archives": [row for _, row in rows],
            "fixture": {
                "path": "upgrade_package_sources.lua",
                "sha256": sha256(staging / "upgrade_package_sources.lua"),
            },
            "matrix": {
                "path": "upgrade_package_matrix_manifest.lua",
                "sha256": sha256(staging / "upgrade_package_matrix_manifest.lua"),
            },
            "driver": {
                "path": "upgrade_matrix_package_driver.lua",
                "sha256": sha256(staging / "upgrade_matrix_package_driver.lua"),
            },
        }
        receipt_path = staging / "immutable_input_receipt.json"
        receipt_path.write_text(json.dumps(receipt, indent=2, sort_keys=True) + "\n", "utf-8")
        for source, row in rows:
            copied = staging / str(row["archive"])
            if copied.stat().st_size != row["bytes"] or sha256(copied) != row["sha256"]:
                fail(f"materialized {row['key']} drifted")
        os.replace(staging, target)
        return receipt
    except Exception:
        shutil.rmtree(staging, ignore_errors=True)
        raise


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source-root", type=Path, required=True)
    parser.add_argument("--target", type=Path)
    parser.add_argument("--verify-only", action="store_true")
    args = parser.parse_args()
    if args.verify_only == (args.target is not None):
        parser.error("choose exactly one of --verify-only or --target")
    if args.verify_only:
        rows = verify(args.source_root.resolve(strict=True))
        print(f"PASS immutable L01 inputs verified: archives={len(rows)} saves=0 pii=0")
    else:
        receipt = materialize(args.source_root.resolve(strict=True), args.target.absolute())
        print(
            "PASS immutable L01 inputs materialized: "
            f"cells={receipt['cell_count']} passes={receipt['processes_per_cell']} saves=0 pii=0"
        )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except MaterializeError as exc:
        raise SystemExit(f"FAIL CLOSED: {exc}")
