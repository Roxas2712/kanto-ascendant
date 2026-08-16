#!/usr/bin/env python3
"""Fail-closed source/archive contract for DRV-UPGRADE-MATRIX-PACKAGE."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path
import re
import zipfile


ROOT = Path(__file__).resolve().parents[1]
DRIVER = ROOT / "tests/upgrade_matrix_package_driver.lua"
FIXTURE = ROOT / "tests/fixtures/upgrade_package_sources.lua"


def workspace_root() -> Path:
    # Normal integration worktrees live at <workspace>/.worktrees/<name>.
    # A direct checkout keeps the historical artifacts one directory above
    # the Authority repository.  No user-specific absolute path is trusted.
    if ROOT.parent.name == ".worktrees":
        return ROOT.parent.parent
    return ROOT.parent


WORKSPACE = workspace_root()


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


SOURCES = {
    "v6_0_11": {
        "path": WORKSPACE / "qa/kanto-ascendant-6.0.11.modpkg",
        "name": "kanto-ascendant-6.0.11.modpkg",
        "bytes": 16662061,
        "sha": "72779b0a9923e2e3908573552858718aa09bc6eae25222d1268bf3f1e41b62e7",
        "manifest_id": "trainer_rematch",
        "manifest_version": "6.0.11",
        "entry": "main.lua",
        "entry_bytes": 75829,
        "entry_sha": "3c66e844c67ed10f63e8f5a9789496f31c350700cd7b3a8c6acd1d3e1f8d0bfe",
        "run_rules": False,
        "initial": "unlocked",
    },
    "rc25": {
        "path": WORKSPACE / "kanto-ascendant-6.5.0-rc25-test.zip",
        "name": "kanto-ascendant-6.5.0-rc25-test.zip",
        "bytes": 37749193,
        "sha": "9d340d9badf940adc7bd1a36b43d66a4d02b84229a63df8c5caa85939fdab9a5",
        "manifest_id": "kanto_ascendant",
        "manifest_version": "6.5.0",
        "entry": "run_rules.lua",
        "entry_bytes": 25216,
        "entry_sha": "f8dd2040b7aaf793ba6fd0203e09aaa6e1aa07b2cc46994572fa1898d043f884",
        "run_rules": True,
        "initial": "unlocked",
    },
    "rc26": {
        "path": WORKSPACE / "kanto-ascendant-6.5.0-rc26-test.zip",
        "name": "kanto-ascendant-6.5.0-rc26-test.zip",
        "bytes": 37794577,
        "sha": "0b0fcd765a1dd6d64584d2dd5c116bbabf9a8218c77314e7d5de5937d63e2418",
        "manifest_id": "kanto_ascendant",
        "manifest_version": "6.5.0",
        "entry": "run_rules.lua",
        "entry_bytes": 26416,
        "entry_sha": "00cd36afb48aeea5ddaac83a4cb6295f5df3c89d66971d71ee9435775e7b8ecc",
        "run_rules": True,
        "initial": "locked",
    },
    "rc27": {
        "path": WORKSPACE / "kanto-ascendant-6.5.0-rc27-test.zip",
        "name": "kanto-ascendant-6.5.0-rc27-test.zip",
        "bytes": 37983841,
        "sha": "fb870c51b22ac87be7a3c79ec98e6fe798196946c96abec439e5915d99af5912",
        "manifest_id": "kanto_ascendant",
        "manifest_version": "6.5.0",
        "entry": "run_rules.lua",
        "entry_bytes": 26416,
        "entry_sha": "00cd36afb48aeea5ddaac83a4cb6295f5df3c89d66971d71ee9435775e7b8ecc",
        "run_rules": True,
        "initial": "locked",
    },
}


driver = DRIVER.read_text(encoding="utf-8")
fixture = FIXTURE.read_text(encoding="utf-8")

assert "schema-derived fixtures" in fixture
assert "no published player save" in fixture
assert 'kind = "schema-derived-sanitized"' in fixture
assert "publishedSave = false" in fixture
assert "containsPlayerPII = false" in fixture

# The full, actual artifacts are part of the source contract.  Their archives
# contain product files only; no slot/save payload is being relabelled as a
# player fixture.
save_payload = re.compile(
    r"(?:^|/)(?:save(?:_blue|_yellow)?|slot[0-9]+)\.lua$", re.IGNORECASE
)
for key, expected in SOURCES.items():
    path = expected["path"]
    assert path.is_file(), f"missing actual historical archive: {key}: {path}"
    assert path.stat().st_size == expected["bytes"], key
    assert sha256(path) == expected["sha"], key
    with zipfile.ZipFile(path) as archive:
        names = archive.namelist()
        assert not any(save_payload.search(name) for name in names), (
            key,
            "archive unexpectedly contains a player-save-shaped payload",
        )
        manifest = json.loads(archive.read("manifest.json"))
        assert manifest["id"] == expected["manifest_id"], key
        assert manifest["version"] == expected["manifest_version"], key
        entry = archive.read(expected["entry"])
        assert len(entry) == expected["entry_bytes"], key
        assert hashlib.sha256(entry).hexdigest() == expected["entry_sha"], key
        assert ("run_rules.lua" in names) is expected["run_rules"], key

    start = fixture.index(f"  {key} = {{")
    tail = fixture[start:]
    end = tail.index("\n  },")
    block = tail[: end + 5]
    for token in (
        f'key = "{key}"',
        f'archiveName = "{expected["name"]}"',
        f'archiveBytes = {expected["bytes"]}',
        f'archiveSha256 = "{expected["sha"]}"',
        f'manifestId = "{expected["manifest_id"]}"',
        f'manifestVersion = "{expected["manifest_version"]}"',
        f'schemaEntry = "{expected["entry"]}"',
        f'schemaEntryBytes = {expected["entry_bytes"]}',
        f'schemaEntrySha256 = "{expected["entry_sha"]}"',
        f'expectedInitialRuleState = "{expected["initial"]}"',
        "provenance = provenance",
    ):
        assert token in block, (key, token)

# Every cell must use only immutable package inputs/receipts and the installed
# package APIs.  The four phases are explicit so an orchestrator cannot replace
# disable/save/re-enable with one in-process table round-trip.
for token in (
    'os.getenv("KA_PACKAGE_GATE") == "1"',
    'os.getenv("KA_CLOSURE_PROFILE") == "base_deutsch"',
    'os.getenv("QA_UPGRADE_PHASE")',
    'phase == "stage"',
    'phase == "migrate"',
    'phase == "disabled"',
    'phase == "reenabled"',
    'os.getenv("QA_UPGRADE_SOURCE")',
    'os.getenv("GEN1RECOMP_DIR")',
    '"/immutable_inputs/upgrade_sources/"',
    'local fixturePath = immutableRoot .. "upgrade_package_sources.lua"',
    'local archivePath = immutableRoot .. source.archiveName',
    'requiredSha("KA_ENGINE_PAYLOAD_SHA256")',
    'requiredSha("KA_AUTHORITY_PACKAGE_SHA256")',
    'requiredSha("KA_DEUTSCH_PACKAGE_SHA256")',
    'requiredSha("KA_PACKAGE_GATE_RECEIPT_SHA256")',
    'love.filesystem.newFileData(bytes',
    'love.filesystem.mount(fd, mount)',
    'love.filesystem.unmount(fd)',
    'Json.decode(rawManifest)',
    'SaveData.setActiveSlot(edition, slot)',
    'SaveData.writeSlot(edition, slot, raw)',
    'save.player.surfing = false',
    'SaveData.load(edition)',
    'game:restoreSave(loaded, recovered)',
    'rules.open(game)',
    'menu.onChoose(menu.items[2], menu)',
    'menu.onChoose(menu.items[3], menu)',
    'confirmation.choice(true)',
    'SaveData.saveFilename(edition) .. ".tmp"',
    'game:writeSave()',
    'recovered == "bak"',
    'LauncherMods.setEnabled("kanto_ascendant", false, edition)',
    'LauncherMods.setEnabled("kanto_ascendant", true, edition)',
    '#report.lostMons == 1 and #report.lostItems == 1',
    '#report.restoredMons == 1 and #report.restoredItems == 1',
    'protectedSnapshot(game.save) == receipt.protectedBaseline',
    'SaveData.encode(game.save.modData.trainer_rematch)',
    'status=PASS',
    'scope=UPGRADE-MATRIX-PACKAGE',
    'provenance=schema-derived-sanitized',
    'published_save=false',
    'failed_write_rollback=1/1',
    'backup_rollback=1/1',
    'rollback_shadow=1/1',
    'disable_quarantine=2/2',
    'reenable_restore=2/2',
    'data_equality=1/1',
    'fail=0',
):
    assert token in driver, token

for key in SOURCES:
    assert key in fixture, key
assert driver.count('love.event.quit(0)') == 4
assert driver.index("injectFailedSave()", driver.index('if phase == "migrate"')) \
    < driver.index("receipt.receipts.optionMigration = true") \
    < driver.index("local rules = exerciseRules()")

# RC27's follower controller is slot-local: its game.ready/save.loaded sync
# overwrites the live option bucket from sourceBucket.follower_config.  A
# source fixture that claims option Count=4 must therefore carry Count=4 in
# the historical save bucket as well.  Pin the complete v1 normalized shape
# so future fixture edits cannot recreate an options/save contradiction.
rc27_start = fixture.index("  rc27 = {")
rc27_block = fixture[rc27_start:]
rc27_end = rc27_block.index("\n  },")
rc27_block = rc27_block[: rc27_end + 5]
for token in (
    'options = { kanto_151 = "ascendant", follower_count = 4 }',
    "follower_config = {",
    'version = 1, count = 4, mode = "party"',
    'presentation = "ascendant_box", custom = {}, nextId = 0',
):
    assert token in rc27_block, token

historical_follower = SOURCES["rc27"]["path"]
with zipfile.ZipFile(historical_follower) as archive:
    follower_source = archive.read("follower_config.lua")
assert hashlib.sha256(follower_source).hexdigest() == (
    "cc3953edc4958dc1c1fae6a532dd768e81d11887637552633873a4519508bb63"
)
for token in (
    b"local VERSION = 1",
    b"s.count = clampCount(s.count ~= nil and s.count or 1)",
    b's.mode = normalizeMode(s.mode ~= nil and s.mode or "party")',
    b's.presentation ~= nil and s.presentation or "ascendant_box"',
    b"s.custom = type(s.custom) == \"table\" and s.custom or {}",
    b"s.nextId = math.max(0, math.floor(tonumber(s.nextId) or 0))",
    b'syncOneOption("follower_count", s.count)',
):
    assert token in follower_source, token

# The driver may construct only its clearly-labelled sanitized source save.
# Current migration/rule/quarantine results must come from installed product
# APIs and native IO, not direct writes to protected current state.
for forbidden in (
    "/Users/",
    ".worktrees/",
    "loadfile(",
    "SaveData.runMigrations(",
    "identityMigration.migrateSave(",
    "idMigration.migrateSave(",
    "game.save.modData.kanto_ascendant =",
    "game.save.inventory.MEGA_RING =",
):
    assert forbidden not in driver, forbidden
assert driver.count('not harnessRoot:find("/Documents/Recompile/", 1, true)') == 1
assert driver.count('not path:find("/Documents/Recompile/", 1, true)') == 1
for pattern in (
    r"\bstate\.(?:locked|configured|lockReason)\s*=(?!=)",
    r"\bfinalRules\.(?:locked|configured|lockReason)\s*=(?!=)",
    r"game\.save\.pokedex\.(?:seen|owned)\[[^]]+\]\s*=(?!=)",
    r"game\.save\.orphaned\s*=(?!=)",
):
    assert not re.search(pattern, driver), pattern

assert driver.count("SaveData.validate(save, game.data)") == 1
assert "schema-derived-fixture" in driver
assert "source.provenance.publishedSave == false" in driver

print(
    "Upgrade package driver contract PASS: "
    "4 actual archives x 3 editions = 12 four-process cells"
)
