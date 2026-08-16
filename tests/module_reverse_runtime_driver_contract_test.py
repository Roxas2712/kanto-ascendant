#!/usr/bin/env python3
"""Fail-closed source contract for the package-only L09 runtime driver."""

from __future__ import annotations

import csv
import hashlib
from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[1]
DRIVER = ROOT / "tests/module_reverse_runtime_visual_driver.lua"
MAPPING = ROOT / "qa/rc28_release_gate_20260812/MODULE_ACCEPTANCE_MAP.tsv"
source = DRIVER.read_text(encoding="utf-8")

EXPECTED_MAPPING_SHA256 = "2da4dd4c952acbbe6ac5cc785c57124b8dc8d5dccd2b8b2e174200383961929b"
mapping_bytes = MAPPING.read_bytes()
assert hashlib.sha256(mapping_bytes).hexdigest() == EXPECTED_MAPPING_SHA256
assert mapping_bytes.endswith(b"\n") and b"\r" not in mapping_bytes
assert mapping_bytes.splitlines()[0] == b"module\tacceptance_group"

with MAPPING.open(newline="", encoding="utf-8") as handle:
    rows = list(csv.DictReader(handle, delimiter="\t"))
assert all(set(row) == {"module", "acceptance_group"} for row in rows)
modules = [row["module"] for row in rows]
groups = {row["acceptance_group"] for row in rows}
assert len(rows) == len(set(modules)) == 148
assert all(re.fullmatch(r"[A-Za-z0-9_]+\.lua", module) for module in modules)
assert len(groups) == 20 and all(groups)

# Every mapped group is named in the executable driver.  This is intentionally
# stronger than a module require inventory: 17 groups bind to completed lanes,
# while the three residual groups must expose concrete runtime interactions.
for group in groups:
    assert re.search(rf"\b{re.escape(group)}\b", source), group

lanes = [
    "L00_RUNTIME_CLOSURE",
    "L01_BOOT_UPGRADE_RULES",
    "L02_PRESENTATION_MOTION",
    "L03_HEVO_MATRIX",
    "L04_NGPLUS_LEGACY",
    "L05_JOHTO_LEAGUE",
    "L06_WANDERERS_REMATCH",
    "L07_BALLS_TMS_ITEM_UI",
    "L08_OAK_MEW_ROUTE22",
]
for lane in lanes:
    assert source.count(f'"{lane}"') >= 1, lane

for token in (
    'os.getenv("KA_PACKAGE_GATE") == "1"',
    'sha("KA_ENGINE_PAYLOAD_SHA256")',
    'sha("KA_AUTHORITY_PACKAGE_SHA256")',
    'sha("KA_DEUTSCH_PACKAGE_SHA256")',
    'sha("KA_PACKAGE_GATE_RECEIPT_SHA256")',
    'receipt.receipt_contract == "BLITZ_PACKAGE_RECEIPT_V1"',
    'receipt.status == "PASS"',
    'receipt.lane_evidence_sha256',
    'receipt[key] == expected',
    'dir == evidenceRoot .. "/L09_REVERSE_MODULE_SURFACES"',
    'receiptRoot .. "/" .. lane .. ".receipt"',
    'local receiptRoot = evidenceRoot .. "/compat_receipts"',
    'daycare.compatible(game, female, male)',
    'daycare.babyFor(game, "PIKACHU")',
    'hub.openJohto(game)',
    'hub.openMythic(game)',
    'hub.openWorld(game)',
    'worldEvents.statusText(game)',
    'grandTour.statusText()',
    'eventArchive.details(game',
):
    assert token in source, f"missing fail-closed/runtime seam: {token}"

# The map is an authenticated runtime input, not a repository-relative lookup
# or an operator-supplied count.  Its exact bytes are hashed with LÖVE's native
# data API before the same in-memory body is parsed.
for token in (
    'local moduleMapPath = assert(os.getenv("KA_MODULE_ACCEPTANCE_MAP")',
    'local moduleMapSha = sha("KA_MODULE_ACCEPTANCE_MAP_SHA256")',
    'local moduleMapBody = readFile(moduleMapPath)',
    'local digest = love.data.hash("sha256", body)',
    'love.data.encode("string", "hex", digest):lower()',
    'assert(bodySha256(moduleMapBody) == moduleMapSha',
    'assert(not moduleMapBody:find("\\r", 1, true)',
    'and moduleMapBody:sub(-1) == "\\n"',
    'assert(mapHeader == "module\\tacceptance_group"',
    'for line in moduleMapBody:gmatch("([^\\n]+)\\n") do',
    'and not mappedModules[module]',
    'mappedModules[module] = true',
    'mappedGroups[group] = true',
    'for _ in pairs(mappedModules) do mappedModuleCount = mappedModuleCount + 1 end',
    'for _ in pairs(mappedGroups) do mappedGroupCount = mappedGroupCount + 1 end',
    'assert(mappedModuleCount == 148 and mappedGroupCount == 20',
):
    assert token in source, f"missing authenticated module-map seam: {token}"
assert source.count('os.getenv("KA_MODULE_ACCEPTANCE_MAP")') == 1
assert source.count('sha("KA_MODULE_ACCEPTANCE_MAP_SHA256")') == 1
assert "qa/rc28_release_gate_20260812/MODULE_ACCEPTANCE_MAP.tsv" not in source

# Enumerate the actual installed package directory, then prove set equality in
# both directions.  Merely counting map rows or loaded Lua modules is not proof.
for token in (
    'local authorityPath = tostring(loaded.path or "")',
    'local packageModules = {}',
    'local packageItems = assert(love.filesystem.getDirectoryItems(authorityPath)',
    'for _, name in ipairs(packageItems) do',
    'local info = assert(love.filesystem.getInfo(authorityPath .. "/" .. name)',
    'assert(info.type == "file" and name:match("^[A-Za-z0-9_]+%.lua$")',
    'packageModules[name] = true',
    'for module in pairs(packageModules) do',
    'assert(mappedModules[module], "unmapped installed Authority module: " .. module)',
    'for module in pairs(mappedModules) do',
    'assert(packageModules[module], "mapped Authority module absent from package: " .. module)',
    'assert(packageModuleCount == mappedModuleCount',
):
    assert token in source, f"missing installed-module set proof: {token}"

# L09 must remain hermetic inside the already-running package process.  Shell
# enumeration/hash helpers could observe a different path or executable.
for forbidden in (
    "io.popen",
    "/usr/bin/find",
    "/usr/bin/shasum",
    "os.execute",
    "shellQuote",
):
    assert forbidden not in source, f"forbidden shell seam: {forbidden}"

# Published counts must be derived from the parsed map and observed group set.
# A hard-coded result line was the original false-positive seam.
for token in (
    'local expectedGroups = mappedGroupCount',
    'groupCount == expectedGroups',
    '"mapped_modules=" .. tostring(mappedModuleCount)',
    '"acceptance_groups=" .. tostring(groupCount)',
):
    assert token in source, f"missing dynamically derived result: {token}"
for forbidden in (
    "mapped_modules=148",
    "acceptance_groups=20",
):
    assert forbidden not in source, f"literal result claim is forbidden: {forbidden}"
assert not re.search(r"\bmappedModuleCount\s*=\s*148\b", source)
assert not re.search(r"\bmappedGroupCount\s*=\s*20\b", source)
assert not re.search(r"\bexpectedGroups\s*=\s*20\b", source)

# Individual receipt paths may not be injected.  The driver derives nine
# canonical siblings from the one package evidence root and rejects source.
assert not re.search(r'os\.getenv\("KA_L0[0-8]_RECEIPT', source)
assert not re.search(r'os\.getenv\("KA_[A-Z_]*RECEIPT_PATH', source)
for forbidden in (
    "/Users/", "package.path", "package.loaded", "loadfile(",
    'require("kanto_ascendant',
):
    assert forbidden not in source, f"driver contains forbidden source seam: {forbidden}"
assert 'not path:find(".worktrees", 1, true)' in source
assert 'not path:find("/Documents/Recompile/", 1, true)' in source

# No direct feature-state receipt or shortcut: the residual proofs call the
# installed exports and real UI, then capture their live stack surfaces.
for forbidden in (
    "game.save.modData.kanto_ascendant =",
    "packageReceipt =",
    "injectedReceipt",
    "fakeReceipt",
):
    assert forbidden not in source, forbidden
assert source.count("U.shot(game") == 3
assert 'love.filesystem.getSource()' in source
assert 'game.mods.mods.kanto_ascendant' in source

print("L09 module reverse runtime driver contract PASS: 148 modules / 20 groups")
