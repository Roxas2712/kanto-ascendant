#!/usr/bin/env python3
"""Fail-closed package contract for default-deny/replacement probes."""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DRIVER = ROOT / "tools" / "mod_allowlist_runtime_qa.lua"
FIXTURES = ROOT / "tests" / "fixtures" / "final_allowlist"
text = DRIVER.read_text(encoding="utf-8")

required = {
    "package gate": 'KA_PACKAGE_GATE") == "1"',
    "live status": "game.mods:status()",
    "Ascendant loaded": 'ascendant.state == "loaded"',
    "replacement state": 'replaced.state == "replaced"',
    "replacement owner": 'replaced.replacedBy == "kanto_ascendant"',
    "unknown state": 'unknown.state == "not_approved"',
    "unknown owner": 'unknown.replacedBy == "kanto_ascendant"',
    "loaded replacement negative": "replacement fixture leaked into loaded mod registry",
    "loaded unknown negative": "unknown fixture leaked into loaded mod registry",
    "export replacement negative": "replacement fixture leaked an export",
    "export unknown negative": "unknown fixture leaked an export",
    "runtime result": "scope=MOD-ALLOWLIST-NEGATIVE-PACKAGE",
}
missing = [name for name, needle in required.items() if needle not in text]

expected = {
    "trainer_rematch": "replaced",
    "ka65_unknown_probe": "not_approved",
}
for mod_id, policy in expected.items():
    root = FIXTURES / mod_id
    manifest = json.loads((root / "manifest.json").read_text("utf-8"))
    entry = (root / manifest["entry"]).read_text("utf-8")
    if manifest["id"] != mod_id or manifest["api"] != 2:
        missing.append(f"invalid fixture manifest: {mod_id}")
    if "error(" not in entry or policy not in entry:
        missing.append(f"fixture does not fail if loaded: {mod_id}")

assert not missing, "MOD ALLOWLIST PACKAGE CONTRACT FAIL:\n" + "\n".join(missing)
print(f"MOD ALLOWLIST PACKAGE CONTRACT PASS: {len(required) + 2} checks")
