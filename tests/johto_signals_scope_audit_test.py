#!/usr/bin/env python3
"""Self-test for the fail-closed Johto Signals package audit."""

from __future__ import annotations

import importlib.util
import json
from pathlib import Path
import tempfile
import zipfile


ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location(
    "signals_audit", ROOT / "tools" / "johto_signals_release_audit.py"
)
assert SPEC and SPEC.loader
AUDIT = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(AUDIT)


def write_clean_package(root: Path) -> None:
    (root / ".luarc.json").write_text("{}\n", encoding="utf-8")
    (root / "README.md").write_text("# Kanto Ascendant\n", encoding="utf-8")
    (root / "RELEASE_NOTES_6.0.1.md").write_text(
        "# Kanto Ascendant 6.0.1\n", encoding="utf-8"
    )
    (root / "mod.card").write_text("return {}\n", encoding="utf-8")
    (root / "manifest.json").write_text(
        json.dumps(
            {
                "id": "trainer_rematch",
                "version": "6.0.1",
                "experimental": False,
            }
        ),
        encoding="utf-8",
    )
    for name in AUDIT.REQUIRED_COMPONENTS:
        (root / name).write_text("return {}\n", encoding="utf-8")


with tempfile.TemporaryDirectory(prefix="signals-audit-") as raw:
    temp = Path(raw)
    clean = temp / "clean"
    clean.mkdir()
    write_clean_package(clean)
    assert AUDIT.audit(clean, False) == []

    readme = clean / "README.md"
    readme.unlink()
    incomplete = AUDIT.audit(clean, False)
    assert any("missing release files" in error for error in incomplete)
    readme.write_text("# Kanto Ascendant\n", encoding="utf-8")

    (clean / "orange_archipelago.lua").write_text("return {}\n", encoding="utf-8")
    leaked = AUDIT.audit(clean, False)
    assert any("frozen Lab path" in error for error in leaked)
    (clean / "orange_archipelago.lua").unlink()

    mythic = clean / "mythic_signals.lua"
    mythic.write_text('return { species = "JIRACHI" }\n', encoding="utf-8")
    leaked = AUDIT.audit(clean, False)
    assert any("JIRACHI" in error for error in leaked)
    mythic.write_text("return {}\n", encoding="utf-8")

    notes = clean / "RELEASE_NOTES_6.0.1.md"
    notes.write_text("JIRACHI is included.\n", encoding="utf-8")
    leaked = AUDIT.audit(clean, False)
    assert any("JIRACHI" in error for error in leaked)
    notes.write_text("# Kanto Ascendant 6.0.1\n", encoding="utf-8")

    archive = temp / "clean.modpkg"
    with zipfile.ZipFile(archive, "w") as zf:
        for path in clean.iterdir():
            if path.name == "RELEASE_NOTES_6.0.1.md":
                continue
            zf.write(path, "kanto-ascendant/" + path.name)
    assert AUDIT.audit(archive, False) == []

    manifest = json.loads((clean / "manifest.json").read_text(encoding="utf-8"))
    manifest["version"] = "5.3.0"
    (clean / "manifest.json").write_text(json.dumps(manifest), encoding="utf-8")
    wrong_version = AUDIT.audit(clean, False)
    assert any("exactly 6.0.1" in error for error in wrong_version)

print("JOHTO SIGNALS SCOPE AUDIT TEST PASS")
