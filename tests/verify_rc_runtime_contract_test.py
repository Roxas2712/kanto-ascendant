#!/usr/bin/env python3
"""Regression for the fail-closed RC/engine delivery gate."""

from __future__ import annotations

import hashlib
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import zipfile


ROOT = Path(__file__).resolve().parents[1]
GATE = ROOT / "tools" / "verify_rc_runtime_contract.py"

spec = importlib.util.spec_from_file_location("rc_gate", GATE)
assert spec and spec.loader
gate = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gate)


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def run(*args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, str(GATE), *args],
        check=False,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
    )


with tempfile.TemporaryDirectory(prefix="ka-rc-contract-") as raw:
    tmp = Path(raw)
    mod = tmp / "mod"
    mod.mkdir()
    payload = b"return { id = 'fixture' }\n"
    (mod / "main.lua").write_bytes(payload)

    map_path = mod / gate.MODULE_ACCEPTANCE_MAP
    map_path.parent.mkdir(parents=True)
    map_payload = "module\tacceptance_group\nmain.lua\tfixture\n"
    map_path.write_text(map_payload, encoding="utf-8")

    files = {"main.lua": payload}
    for name in gate.PUBLIC_ROOT_FILES:
        public = (
            b'{"id":"kanto_ascendant"}\n'
            if name == "manifest.json"
            else ("fixture:" + name + "\n").encode()
        )
        (mod / name).write_bytes(public)
        files[name] = public
    for name in gate.REQUIRED_CHARACTER_ASSETS:
        asset = b"fixture-png:" + name.encode()
        path = mod / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(asset)
        files[name] = asset

    package = tmp / "fixture.zip"
    pack = {
        "id": "kanto_ascendant",
        "files": [
            {"path": name, "bytes": len(data), "sha256": sha(data)}
            for name, data in sorted(files.items())
        ],
    }
    with zipfile.ZipFile(package, "w") as archive:
        for name, data in files.items():
            archive.writestr(name, data)
        archive.writestr(".modkit/pack.json", json.dumps(pack))

    engine = tmp / "engine.love"
    with zipfile.ZipFile(engine, "w") as archive:
        for name, markers in gate.ENGINE_CONTRACT.items():
            archive.writestr(name, b"\n".join(markers) + b"\n")

    common = (
        "--mod-root", str(mod),
        "--mod-archive", str(package),
        "--engine", str(engine),
    )
    passed = run(*common)
    assert passed.returncode == 0, passed.stdout
    assert "RC RUNTIME CONTRACT: PASS" in passed.stdout

    (mod / "main.lua").write_bytes(payload + b"-- newer source\n")
    stale = run(*common)
    assert stale.returncode == 1, stale.stdout
    assert "package is stale against authority: main.lua" in stale.stdout
    (mod / "main.lua").write_bytes(payload)

    # A coherent archive can still omit an authored identity if the packer's
    # include list is wrong. This is a separate hard failure from SHA checks.
    omitted_name = gate.REQUIRED_CHARACTER_ASSETS[-1]
    omitted_pack = tmp / "omitted-character.zip"
    omitted_rows = [row for row in pack["files"] if row["path"] != omitted_name]
    with zipfile.ZipFile(omitted_pack, "w") as archive:
        for name, data in files.items():
            if name != omitted_name:
                archive.writestr(name, data)
        archive.writestr(".modkit/pack.json", json.dumps({
            "id": "kanto_ascendant", "files": omitted_rows,
        }))
    omitted = run(
        "--mod-root", str(mod), "--mod-archive", str(omitted_pack),
        "--engine", str(engine),
    )
    assert omitted.returncode == 1, omitted.stdout
    assert "required six-character assets missing" in omitted.stdout

    # A coherent archive whose pack manifest silently omits a mapped product
    # module must fail independently from per-file hashes.
    helper = b"return { helper = true }\n"
    (mod / "helper.lua").write_bytes(helper)
    map_path.write_text(
        map_payload + "helper.lua\tfixture\n", encoding="utf-8"
    )
    omitted_module = run(*common)
    assert omitted_module.returncode == 1, omitted_module.stdout
    assert "mapped product module package mismatch; missing: helper.lua" in omitted_module.stdout
    (mod / "helper.lua").unlink()
    map_path.write_text(map_payload, encoding="utf-8")

    # Internal review files are forbidden even when archive, source and pack
    # manifest all agree byte-for-byte.
    internal_name = "docs/internal-qa.md"
    internal_data = b"fixture internal QA\n"
    internal_path = mod / internal_name
    internal_path.parent.mkdir(parents=True, exist_ok=True)
    internal_path.write_bytes(internal_data)
    leaked_files = dict(files)
    leaked_files[internal_name] = internal_data
    leaked_pack = tmp / "leaked-internal.zip"
    with zipfile.ZipFile(leaked_pack, "w") as archive:
        leaked_rows = []
        for name, data in leaked_files.items():
            archive.writestr(name, data)
            leaked_rows.append({
                "path": name, "bytes": len(data), "sha256": sha(data),
            })
        archive.writestr(".modkit/pack.json", json.dumps({
            "id": "kanto_ascendant", "files": leaked_rows,
        }))
    leaked = run(
        "--mod-root", str(mod), "--mod-archive", str(leaked_pack),
        "--engine", str(engine),
    )
    assert leaked.returncode == 1, leaked.stdout
    assert "internal QA/source files leaked into package" in leaked.stdout

    local_name = "assets/local-path.txt"
    local_data = b"authority=/Users/example/private/source.png\n"
    local_path = mod / local_name
    local_path.parent.mkdir(parents=True, exist_ok=True)
    local_path.write_bytes(local_data)
    local_files = dict(files)
    local_files[local_name] = local_data
    local_pack = tmp / "leaked-local-path.zip"
    with zipfile.ZipFile(local_pack, "w") as archive:
        local_rows = []
        for name, data in local_files.items():
            archive.writestr(name, data)
            local_rows.append({
                "path": name, "bytes": len(data), "sha256": sha(data),
            })
        archive.writestr(".modkit/pack.json", json.dumps({
            "id": "kanto_ascendant", "files": local_rows,
        }))
    local = run(
        "--mod-root", str(mod), "--mod-archive", str(local_pack),
        "--engine", str(engine),
    )
    assert local.returncode == 1, local.stdout
    assert "developer-machine absolute path leaked" in local.stdout

    with zipfile.ZipFile(engine, "w") as archive:
        for name, markers in gate.ENGINE_CONTRACT.items():
            if name == "src/world/WallDecals.lua":
                continue
            archive.writestr(name, b"\n".join(markers) + b"\n")
    missing = run(*common)
    assert missing.returncode == 1, missing.stdout
    assert "engine capability file missing: src/world/WallDecals.lua" in missing.stdout

print("RC runtime contract gate: PASS")
