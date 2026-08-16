#!/usr/bin/env python3
"""Pin the exact optional graphics closures used for final package QA."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path
import zipfile


ROOT = Path(__file__).resolve().parents[1]
deps = ROOT / "qa/rc652_renderer_choice_20260815/dependencies"
lock = json.loads((deps / "LOCK.json").read_text())
manifest = json.loads((ROOT / "manifest.json").read_text())
allowed = manifest["exclusive"]["allow_packages"]

assert set(lock) == {"VOXEL_ASCENDANT", "DRAMALESS_SHAPE"}

for mod_id, row in lock.items():
    archive_path = deps / row["archive"]
    assert archive_path.is_file(), f"missing pinned dependency: {archive_path}"
    assert hashlib.sha256(archive_path.read_bytes()).hexdigest() == row["sha256"], (
        f"dependency digest drift: {mod_id}"
    )
    with zipfile.ZipFile(archive_path) as archive:
        assert archive.testzip() is None, f"corrupt dependency: {mod_id}"
        packaged = json.loads(archive.read("manifest.json"))
    assert packaged["id"] == row["manifest_id"] == mod_id
    assert packaged["version"] == row["version"]
    assert packaged["github"] == row["manifest_github"]
    assert packaged["game_version"] == row["engine_range"]

voxel = [entry for entry in allowed
         if "Roxas2712/voxel-ascendant" in entry.get("repositories", [])]
assert voxel == [
    {
        "repositories": ["Roxas2712/voxel-ascendant"],
        "version": "=0.1.0-rc.1",
    },
    {
        "repositories": ["Roxas2712/voxel-ascendant"],
        "version": "=0.1.1",
    },
], "Voxel Ascendant transition pins drifted"

dramaless = [entry for entry in allowed
             if "artyrambles/DRAMALESS_SHAPE"
             in entry.get("repositories", [])]
assert dramaless == [{
    "repositories": ["artyrambles/DRAMALESS_SHAPE"],
    "version": "=1.6.2-ST.190.1",
}], "hardened DRAMALESS ST.190.1 pin drifted"

battle_art = [entry for entry in allowed
              if "absol89/DramaticShapeVoxelMod"
              in entry.get("repositories", [])]
assert battle_art == [{
    "repositories": ["absol89/DramaticShapeVoxelMod"],
    "version": "=1.9.0",
}], "separately installed Battle Art 1.9.0 pin drifted"
assert "BATTLE_ART_VOXEL_FORK@<1.9.0 || >1.9.0" in manifest["conflicts"], (
    "Battle Art exact-version conflict fence drifted"
)
assert len(allowed) == 4, "unreviewed Voxel packages remain allowlisted"

print("RC optional dependency lock: Voxel Ascendant 0.1.0-rc.1/0.1.1 + "
      "hardened DRAMALESS ST.190.1 + separate Battle Art 1.9.0 PASS")
