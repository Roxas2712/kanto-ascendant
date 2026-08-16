#!/usr/bin/env python3
"""Fail-closed contract and evidence verifier for PotatoVoxel 1.7.2 QA.

The default, ROM-free mode protects the reviewed artifact hashes, engine
commits, 12-cell matrix, four visual states, and the real-LÖVE driver's source
contract.  A release operator can additionally set all three artifact
variables and ``KA_PV172_EVIDENCE_ROOT`` to verify the exact packages and a
completed matrix without network access.
"""

from __future__ import annotations

import hashlib
import itertools
import json
import os
from pathlib import Path
import re
import struct
import zipfile


ROOT = Path(__file__).resolve().parents[1]
DRIVER = ROOT / "tests/potato_voxel_172_visual_driver.lua"
MATRIX = ROOT / "tests/potato_voxel_172_visual_matrix.json"

EXPECTED_DRIVER_SHA256 = (
    "5109753024bf02e69c187c3fff9cb5ea5c41c7b0855b6e2ac3fa6a5196688b75"
)
EXPECTED_MATRIX_SHA256 = (
    "6f97b12e78dc6872869b049d1e24327bfe55f578071c1929a5333918f5a6d2a6"
)
EXPECTED_PACKAGE = {
    "filename": "potato_voxel-1.7.2.zip",
    "id": "potato_voxel",
    "repository": "ShaneMcGovernIE/potato_voxel",
    "version": "1.7.2",
    "sha256": "200153d7623db14e08925d1b51f99f8ccbfa5e32db134922f51c8179bd64fd33",
}
EXPECTED_ENGINES = {
    "0.1.96": {
        "tag": "0196",
        "filename": "gen1recomp-0.1.96.love",
        "commit": "73fbaaa25093338585923b8b9809f2fea7fc59dc",
        "sha256": "eea83b7f73300994429d70fa4b1003dd9a1c1e524d70842380ef595bcc1a8249",
    },
    "0.1.98": {
        "tag": "0198",
        "filename": "gen1recomp-0.1.98.love",
        "commit": "0e40a7a1f4cd956b37fd74ad50193c259161aac5",
        "sha256": "a28b914f5265a52132cb743ba632e1c7bb81f5eb989829816c571adde798db55",
    },
}
EXPECTED_EDITIONS = ("red", "blue", "yellow")
EXPECTED_LANGUAGES = ("en", "de")
EXPECTED_LANGUAGE_PACKAGES = {
    "red": {"id": "deutsch", "version": "2.1.6"},
    "blue": {"id": "deutsch-blau", "version": "1.0.2"},
    "yellow": {"id": "deutsch-gelb", "version": "1.0.5"},
}
EXPECTED_LABELS = {
    "red": {
        "en": {"command": "FIGHT", "move": "GROWL"},
        "de": {"command": "KMPF", "move": "HEULER"},
    },
    "blue": {
        "en": {"command": "FIGHT", "move": "GROWL"},
        "de": {"command": "KMPF", "move": "HEULER"},
    },
    "yellow": {
        "en": {"command": "FIGHT", "move": "QUICK ATTACK"},
        "de": {"command": "KMPF", "move": "RUCKZUCKHIEB"},
    },
}
EXPECTED_CAPTURES = (
    ("3d_on_landscape_textbox", True, "landscape", 960, 540),
    ("3d_on_landscape_command", True, "landscape", 960, 540),
    ("3d_on_portrait_move", True, "portrait", 540, 900),
    ("3d_off_landscape_command", False, "landscape", 960, 540),
)
ARTIFACT_ENV = {
    "package": "KA_PV172_PACKAGE_ZIP",
    "0.1.96": "KA_PV172_ENGINE_0196",
    "0.1.98": "KA_PV172_ENGINE_0198",
}


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def require(value: bool, message: str) -> None:
    if not value:
        raise AssertionError(message)


def load_receipt(path: Path) -> dict[str, str]:
    receipt: dict[str, str] = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        require("=" in line, f"malformed receipt line in {path}: {line!r}")
        key, value = line.split("=", 1)
        require(key not in receipt, f"duplicate receipt key in {path}: {key}")
        receipt[key] = value
    return receipt


def png_dimensions(path: Path) -> tuple[int, int]:
    data = path.read_bytes()
    require(data.startswith(b"\x89PNG\r\n\x1a\n"), f"not a PNG: {path}")
    require(len(data) > 24 and data[12:16] == b"IHDR", f"bad IHDR: {path}")
    return struct.unpack(">II", data[16:24])


def zip_member(archive: zipfile.ZipFile, basename: str) -> str:
    matches = [name for name in archive.namelist() if Path(name).name == basename]
    require(len(matches) == 1, f"expected one {basename} in {archive.filename}")
    return matches[0]


matrix_bytes = MATRIX.read_bytes()
matrix = json.loads(matrix_bytes)
source = DRIVER.read_text(encoding="utf-8")
code = "\n".join(line.split("--", 1)[0] for line in source.splitlines())

require(digest(DRIVER) == EXPECTED_DRIVER_SHA256, "visual driver source drift")
require(digest(MATRIX) == EXPECTED_MATRIX_SHA256, "visual matrix source drift")
require(matrix["schema"] == "ka-potato-voxel-1.7.2-visual-matrix/v1",
        "matrix schema drift")
require(matrix["love_runtime"] == "11.5", "LÖVE runtime pin drift")
require(matrix["package"] == EXPECTED_PACKAGE, "package pin drift")
require(matrix["engines"] == EXPECTED_ENGINES, "engine pin drift")
require(tuple(matrix["editions"]) == EXPECTED_EDITIONS, "edition matrix drift")
require(tuple(matrix["languages"]) == EXPECTED_LANGUAGES,
        "language matrix drift")
require(matrix["language_packages"] == EXPECTED_LANGUAGE_PACKAGES,
        "German package matrix drift")
require(matrix["labels"] == EXPECTED_LABELS, "localized label matrix drift")

captures = tuple(
    (item["id"], item["battle_3d"], item["viewport"],
     item["width"], item["height"])
    for item in matrix["captures"]
)
require(captures == EXPECTED_CAPTURES, "capture matrix drift")
cells = set(itertools.product(EXPECTED_ENGINES, EXPECTED_EDITIONS,
                              EXPECTED_LANGUAGES))
require(len(cells) == 12, "visual matrix is not exactly 12 cells")
require(len(cells) * len(captures) == 48,
        "visual matrix is not exactly 48 captures")

for value in (
    EXPECTED_PACKAGE["sha256"],
    *(engine["sha256"] for engine in EXPECTED_ENGINES.values()),
):
    require(re.fullmatch(r"[0-9a-f]{64}", value) is not None,
            f"invalid SHA-256 pin: {value}")

for token in (
    'assert(os.getenv("EXPECT_ENGINE_SHA256")',
    'assert(expectedEngineSha == engineContract.sha256',
    'assert(buildCommit == engineContract.commit',
    'assert(caseId == engineContract.tag .. "_" .. edition .. "_" .. language',
    'local expectedIdentity = "ka-potato-172-" .. engineContract.tag',
    'identity ~= "pokemon-love2d" and identity == expectedIdentity',
    'assert(os.getenv("POKEPORT_TOUCH") == "1"',
    'assert(#(game.modStatus and game.modStatus.errors or {}) == 0',
    'assert(rendererCount == 1',
    'handles.DRAMALESS_SHAPE == nil',
    'handles.BATTLE_ART_VOXEL_FORK == nil',
    'handles.VOXEL_ASCENDANT == nil',
    'receipt.provenance == "potato-voxel-1.7.2-reviewed-api-contract"',
    'receipt.export == "kasc-local-allowlist/v1"',
    'resolved.lib.require("__KA_PRIVATE_PROBE__") == nil',
    'resolver.module(game, "BattleCam")',
    'resolver.module(game, "MeshCache")',
    'ownerCamera.RIGS.tele.frameH, 34.11',
    'local nativeCameraZoom = ownerCamera.zoom',
    'close(nativeCameraZoom, 1',
    'ownerCamera.DEFAULT_ZOOM == nil',
    'kasc.dramalessCameraCompat.apply(game) == false',
    'ownerBattle.snapHUDs == nil',
    'hudInspect.profile == "RENDERER_NATIVE"',
    'hudInspect.snapCount == 0 and hudInspect.nativeSnapCount == 0',
    'rawget(ownerBattle, rendererHud.snapHookKey) == nil',
    'rawget(BattleState, "__kascWideBattleHudState") == nil',
    'row.id == "potato_voxel:settings"',
    'row.id == "kanto_ascendant:dramaless_battle_camera"',
    'ownerSettingsRows == 1',
    'cameraRows == 0',
    'ownerMeshCache.GEOMETRY_VERSION == 18',
    'ownerMeshCache.identity():match("^PVMC1|18|"',
    'debugOverlay.sendingAllowed() == false',
    'game.stack:push(Overworld, "ROUTE_1", 5, 5, "down")',
    'game.save.party = { makeMon("PIKACHU", 30, 15, "PAR") }',
    'BattleState.newWild(game, "PIDGEY", 20)',
    'assert(call.text == "♀")',
    'assert(call.text == "♂")',
    'call.text == "PAR"',
    'wait(4 * logicSpeed)',
    'enemyGender >= 1',
    'enemyGender > 0 and 1 or 0',
    'touch:visible()',
    'touch.orientation == kind',
    'ownerBattle.shot() ~= nil',
    'ownerBattle.shot() == nil and flatBattle.dramaticShapeShot == nil',
    'command.commandLabel == labels.command',
    'move.moveLabel == labels.move',
    'flat.commandLabel == labels.command',
    'record("engine_artifact_sha256", expectedEngineSha)',
    'record("package_sha256", expectedPackageSha)',
    'record("screenshots", table.concat(shotNames, ","))',
    'record("screenshot_count", #shotNames)',
    'love.event.quit(0)',
):
    require(token in source, f"driver lost fail-closed contract: {token}")

for version, contract in EXPECTED_ENGINES.items():
    for value in (version, contract["commit"], contract["sha256"]):
        require(value in source, f"driver lost engine pin: {value}")
require(EXPECTED_PACKAGE["sha256"] in source, "driver lost package hash pin")
for package in EXPECTED_LANGUAGE_PACKAGES.values():
    require(package["id"] in source and package["version"] in source,
            f"driver lost language package pin: {package}")
for capture_id, *_ in EXPECTED_CAPTURES:
    require(source.count(f'"{capture_id}"') == 1,
            f"capture missing or duplicated in driver: {capture_id}")

capture_order = [source.index(f'"{capture_id}"')
                 for capture_id, *_ in EXPECTED_CAPTURES]
require(capture_order == sorted(capture_order), "capture order drift")
require(source.index('record("status", "PASS")') > capture_order[-1],
        "driver promotes PASS before all captures")
for forbidden in (
    "game:writeSave(",
    "game.writeSave(",
    "SaveData.save(",
    "SaveData.writeSlot(",
    "pokemon-love2d/save",
    "/Users/",
    "https://",
    "http://",
):
    require(forbidden not in code, f"driver crosses isolated QA boundary: {forbidden}")

artifact_paths = {key: os.getenv(name) for key, name in ARTIFACT_ENV.items()}
provided = {key for key, value in artifact_paths.items() if value}
if provided:
    require(provided == set(ARTIFACT_ENV),
            "artifact verification is all-or-none: set all KA_PV172 paths")
    package_path = Path(artifact_paths["package"] or "")
    require(package_path.is_file(), f"package missing: {package_path}")
    require(digest(package_path) == EXPECTED_PACKAGE["sha256"],
            "PotatoVoxel package hash mismatch")
    with zipfile.ZipFile(package_path) as archive:
        manifest = json.loads(archive.read(zip_member(archive, "manifest.json")))
    require(manifest["id"] == EXPECTED_PACKAGE["id"], "package id drift")
    require(manifest["version"] == EXPECTED_PACKAGE["version"],
            "package version drift")
    require(manifest["github"] == EXPECTED_PACKAGE["repository"],
            "package repository drift")
    for version, expected in EXPECTED_ENGINES.items():
        engine_path = Path(artifact_paths[version] or "")
        require(engine_path.is_file(), f"engine missing: {engine_path}")
        require(digest(engine_path) == expected["sha256"],
                f"engine {version} hash mismatch")
        with zipfile.ZipFile(engine_path) as archive:
            build = json.loads(archive.read(zip_member(archive, "build-info.json")))
        require(build["version"] == version, f"engine {version} version drift")
        require(build["gitCommitFull"] == expected["commit"],
                f"engine {version} commit drift")

evidence_value = os.getenv("KA_PV172_EVIDENCE_ROOT")
if evidence_value:
    require(provided == set(ARTIFACT_ENV),
            "evidence verification also requires all exact artifact paths")
    evidence = Path(evidence_value)
    results_dir = evidence / "results"
    shots_dir = evidence / "shots"
    logs_dir = evidence / "logs"
    expected_results: set[Path] = set()
    expected_shots: set[Path] = set()
    expected_logs: set[Path] = set()
    required_receipt = matrix["required_receipt"]
    for version, edition, language in sorted(cells):
        engine = EXPECTED_ENGINES[version]
        case_id = f"{engine['tag']}_{edition}_{language}"
        receipt_path = results_dir / f"{case_id}.txt"
        log_path = logs_dir / f"{case_id}.log"
        expected_results.add(receipt_path)
        expected_logs.add(log_path)
        require(receipt_path.is_file(), f"missing receipt: {receipt_path}")
        require(log_path.is_file(), f"missing log: {log_path}")
        log = log_path.read_text(encoding="utf-8", errors="replace")
        require("driver error:" not in log and "stack traceback" not in log,
                f"runtime error in {log_path}")
        receipt = load_receipt(receipt_path)
        for key, value in required_receipt.items():
            require(receipt.get(key) == value,
                    f"{case_id} receipt drift: {key}={receipt.get(key)!r}")
        require(receipt.get("engine") == version, f"{case_id} engine drift")
        require(receipt.get("engine_commit") == engine["commit"],
                f"{case_id} engine commit drift")
        require(receipt.get("engine_artifact_sha256") == engine["sha256"],
                f"{case_id} engine hash drift")
        require(receipt.get("package_sha256") == EXPECTED_PACKAGE["sha256"],
                f"{case_id} package hash drift")
        require(receipt.get("edition") == edition, f"{case_id} edition drift")
        require(receipt.get("language") == language,
                f"{case_id} language drift")
        require(receipt.get("identity") ==
                f"ka-potato-172-{engine['tag']}-{edition}-{language}",
                f"{case_id} identity drift")
        labels = EXPECTED_LABELS[edition][language]
        require(receipt.get("command_label") == labels["command"],
                f"{case_id} command localization drift")
        require(receipt.get("flat_command_label") == labels["command"],
                f"{case_id} flat command localization drift")
        require(receipt.get("move_label") == labels["move"],
                f"{case_id} move localization drift")
        if language == "de":
            package = EXPECTED_LANGUAGE_PACKAGES[edition]
            require(receipt.get("language_package") == package["id"],
                    f"{case_id} German package id drift")
            require(receipt.get("language_package_version") == package["version"],
                    f"{case_id} German package version drift")
        else:
            require(receipt.get("language_package") == "none",
                    f"{case_id} unexpected language package")
            require(receipt.get("language_package_version") == "none",
                    f"{case_id} unexpected language package version")
        require(re.fullmatch(rf"PVMC1\|18\|{edition}\|[^\n]+",
                             receipt.get("cache_identity", "")) is not None,
                f"{case_id} cache identity drift")
        filenames = [f"{case_id}_{capture_id}.png"
                     for capture_id, *_ in EXPECTED_CAPTURES]
        require(receipt.get("screenshots") == ",".join(filenames),
                f"{case_id} screenshot receipt drift")
        for filename, capture in zip(filenames, EXPECTED_CAPTURES):
            shot_path = shots_dir / engine["tag"] / filename
            expected_shots.add(shot_path)
            require(shot_path.is_file(), f"missing screenshot: {shot_path}")
            require(shot_path.stat().st_size > 1000,
                    f"empty screenshot: {shot_path}")
            require(png_dimensions(shot_path) == capture[3:5],
                    f"screenshot dimensions drift: {shot_path}")

    actual_results = set(results_dir.glob("*.txt"))
    actual_logs = set(logs_dir.glob("*.log"))
    actual_shots = set(shots_dir.glob("*/*.png"))
    require(actual_results == expected_results, "result file matrix drift")
    require(actual_logs == expected_logs, "log file matrix drift")
    require(actual_shots == expected_shots, "screenshot file matrix drift")

mode = "static"
if provided:
    mode += "+artifacts"
if evidence_value:
    mode += "+evidence"
print(f"PASS PotatoVoxel 1.7.2 visual contract: {mode}; 12 cells; 48 captures")
