#!/usr/bin/env python3
"""Real-archive, no-save contract for the L01 immutable-input materializer."""

from __future__ import annotations

import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "tools/materialize_upgrade_package_inputs.py"


def workspace_root() -> Path:
    if ROOT.parent.name == ".worktrees":
        return ROOT.parent.parent
    return ROOT.parent


def digest(path: Path) -> str:
    value = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            value.update(block)
    return value.hexdigest()


spec = importlib.util.spec_from_file_location("upgrade_materializer", SCRIPT)
assert spec and spec.loader
materializer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(materializer)

source_root = workspace_root()
verified = materializer.verify(source_root)
assert len(verified) == 4
assert {row[1]["key"] for row in verified} == {"v6_0_11", "rc25", "rc26", "rc27"}
assert all(row[1]["save_shaped_members"] == 0 for row in verified)

with tempfile.TemporaryDirectory(prefix="ka-l01-materializer-") as temporary:
    target = Path(temporary) / "immutable_inputs/upgrade_sources"
    receipt = materializer.materialize(source_root, target)
    assert receipt["schema"] == "ka-l01-upgrade-immutable-inputs/v1"
    assert receipt["provenance"] == "schema-derived-sanitized"
    assert receipt["published_player_save"] is False
    assert receipt["contains_player_pii"] is False
    assert (receipt["source_count"], receipt["edition_count"]) == (4, 3)
    assert (receipt["cell_count"], receipt["processes_per_cell"]) == (12, 4)
    assert len(receipt["archives"]) == 4
    frozen = json.loads((target / "immutable_input_receipt.json").read_text("utf-8"))
    assert frozen == receipt
    assert {path.name for path in target.iterdir()} == {
        "upgrade_package_sources.lua",
        "upgrade_package_matrix_manifest.lua",
        "upgrade_matrix_package_driver.lua",
        "immutable_input_receipt.json",
        "kanto-ascendant-6.0.11.modpkg",
        "kanto-ascendant-6.5.0-rc25-test.zip",
        "kanto-ascendant-6.5.0-rc26-test.zip",
        "kanto-ascendant-6.5.0-rc27-test.zip",
    }
    assert digest(target / "upgrade_package_sources.lua") == receipt["fixture"]["sha256"]
    assert digest(target / "upgrade_package_matrix_manifest.lua") == receipt["matrix"]["sha256"]
    assert digest(target / "upgrade_matrix_package_driver.lua") == receipt["driver"]["sha256"]
    for row in receipt["archives"]:
        archive = target / row["archive"]
        assert archive.is_file() and not archive.is_symlink()
        assert archive.stat().st_size == row["bytes"]
        assert digest(archive) == row["sha256"]
    try:
        materializer.materialize(source_root, target)
    except materializer.MaterializeError as exc:
        assert "refusing to merge or overwrite" in str(exc)
    else:
        raise AssertionError("existing immutable target was overwritten")

source = SCRIPT.read_text("utf-8")
for forbidden in ("--save", "Path.home(", "expanduser(", "glob(", "rglob(", "/Users/"):
    assert forbidden not in source
for required in (
    "schema-derived-sanitized", "published_player_save", "contains_player_pii",
    "SAVE_SHAPED", "source_count", "cell_count", "processes_per_cell", "DRIVER",
):
    assert required in source

print("Upgrade immutable-input materializer PASS: 4 archives, 12 cells, saves=0, pii=0")
