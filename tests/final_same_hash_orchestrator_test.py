#!/usr/bin/env python3
"""Historical pre-0.1.90 static/dry-run same-hash receipt.

Its Battle Art cells preserve earlier evidence only; they are not part of the
current 6.5.4 renderer-admission or engine-0.1.90 release gate.
"""

from __future__ import annotations

import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import shutil
import stat
import subprocess
import sys
import tempfile
import zipfile


ROOT = Path(__file__).resolve().parents[1]
GATE = ROOT / "qa/blitz_real_save_forensic_20260812/package_candidate"
ORCHESTRATOR = GATE / "final_same_hash_orchestrator.py"
PLAN = GATE / "final_same_hash_plan.json"
RECEIPT = GATE / "final_same_hash_receipt.json"
INPUTS = GATE / "inputs"


def digest(path: Path) -> str:
    value = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            value.update(block)
    return value.hexdigest()


spec = importlib.util.spec_from_file_location("final_same_hash_orchestrator", ORCHESTRATOR)
assert spec and spec.loader
gate = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gate)

plan = gate.read_json(PLAN)
receipt = gate.read_json(RECEIPT)
info = gate.validate_plan(plan)
gate.validate_receipt(receipt, info, require_ready=False)

assert [lane["lane_id"] for lane in info["lanes"]] == [
    "L00_RUNTIME_CLOSURE", "L01_BOOT_UPGRADE_RULES",
    "L02_PRESENTATION_MOTION", "L03_HEVO_MATRIX",
    "L04_NGPLUS_LEGACY", "L05_JOHTO_LEAGUE",
    "L06_WANDERERS_REMATCH", "L07_BALLS_TMS_ITEM_UI",
    "L08_OAK_MEW_ROUTE22", "L09_REVERSE_MODULE_SURFACES",
    "L10_FINAL_SAME_HASH",
]
assert info["cells"] == 192
assert len(info["identities"]) == 190
assert len(info["users"]) == 44
assert len(info["features"]) == 34
assert len(info["blocked"]) == 0
assert len(info["blocked_matrix_rows"]) == 0
assert plan["status"] == "ready_for_package_execution"
assert receipt["status"] == "ready"
assert receipt["orchestrator_sha256"] == digest(ORCHESTRATOR)
assert plan["lane_authority"] == (
    "inputs/authority_snapshot/PACKAGE_ACCEPTANCE_LANES.tsv"
)
assert receipt["authority"]["sha256"] == (
    "0044eb1ddad56fa46b62e2907dfd15723a6441c64dcde5e97a77d0edc0261455"
)
assert receipt["imported_data"]["sha256"] == (
    "307e22e82f995ba4b14ab7d4a05bebfb9dd0a2be426f220bc597d560c0aed917"
)
assert receipt["imported_data"]["provenance_receipt_sha256"] == (
    "750021c00f1907c2837f3bb958001613b590459962337ce01b1111f0d2069886"
)
assert receipt["lane_authority"] == (
    "inputs/authority_snapshot/PACKAGE_ACCEPTANCE_LANES.tsv"
)
assert receipt["user_matrix"] == (
    "inputs/authority_snapshot/USER_CHAT_REGRESSION_GATE.md"
)
assert receipt["feature_matrix"] == (
    "inputs/authority_snapshot/FEATURE_ACCEPTANCE_MATRIX.md"
)
assert "authority/MODULE_ACCEPTANCE_MAP.tsv" in plan["support_files"]
module_map = gate.parse_module_acceptance_map(gate.MODULE_MAP)
assert len(module_map) == 148 and len(set(module_map.values())) == 20
assert receipt["module_acceptance_map_sha256"] == digest(gate.MODULE_MAP)

l00 = next(lane for lane in plan["lanes"] if lane["order"] == 0)
l00_cells = {cell["id"]: cell for cell in l00["cells"]}
assert l00["coverage"]["MOD-002"] == [
    "l00-integrated-hooks-2d", "l00-integrated-hooks-full",
]
for cell_id, closure, renderer in (
    ("l00-integrated-hooks-2d", "base_deutsch", "2d"),
    ("l00-integrated-hooks-full", "dramaless_fp", "full"),
):
    row = l00_cells[cell_id]
    assert row["closure"] == closure
    assert row["env"] == {"QA_RENDER_MODE": renderer}
    assert row["images"] == {"exact_count": 1, "min_bytes": 1000}
    assert {fixture["manifest_id"] for fixture in row["fixture_mods"]} == {
        "overworld_wild_spawns", "FOLLOWERS_EX", "quality_of_life",
        "useful_bag",
    }
allowlist = l00_cells["l00-allowlist-negative-red"]
assert {fixture["manifest_id"] for fixture in allowlist["fixture_mods"]} == {
    "trainer_rematch", "ka65_unknown_probe",
}

l07 = next(lane for lane in plan["lanes"] if lane["order"] == 7)
l07_cells = {cell["id"]: cell for cell in l07["cells"]}
assert l07["coverage"]["UI-001"] == [
    "l07-item-help-red-en", "l07-item-help-red-de",
    "l07-item-help-blue-en", "l07-item-help-blue-de",
    "l07-item-help-yellow-en", "l07-item-help-yellow-de",
]
for edition in gate.EDITIONS:
    for locale in ("en", "de"):
        row = l07_cells[f"l07-item-help-{edition}-{locale}"]
        assert row["edition"] == edition
        assert row["env"] == {"QA_ITEM_HELP_LANGUAGE": locale}
        assert row["images"] == {"exact_count": 6, "min_bytes": 1000}
        if locale == "en":
            assert [phase["driver"] for phase in row["passes"]] == [
                "tests/item_select_help_language_setup_driver.lua",
                "tests/item_select_help_visual_driver.lua",
            ]
        else:
            assert "passes" not in row
assert l07["coverage"]["TECH-001"] == [
    "l07-tech-red", "l07-tech-blue", "l07-tech-yellow",
]
assert {
    l07_cells[cell_id]["edition"]
    for cell_id in ("l07-tech-red", "l07-tech-blue", "l07-tech-yellow")
} == {"red", "blue", "yellow"}
for cell_id in ("l07-tech-red", "l07-tech-blue", "l07-tech-yellow"):
    assert l07_cells[cell_id]["driver"] == (
        "tools/starter_signature_tech_package_driver.lua"
    )
assert l07["coverage"]["RC65-ESPEON-PSYBEAM"] == [
    "l07-espeon-psybeam-red",
    "l07-espeon-psybeam-blue",
    "l07-espeon-psybeam-yellow",
]
assert {
    l07_cells[cell_id]["edition"]
    for cell_id in l07["coverage"]["RC65-ESPEON-PSYBEAM"]
} == {"red", "blue", "yellow"}
apricorn_cells = [
    f"l07-apricorn-{edition}-{mode}"
    for edition in gate.EDITIONS for mode in ("2d", "full")
]
for coverage_id in (
    "BALL-001", "RC65-APRICORN-BALLS", "RC65-JOURNEYS-BALL-ART",
):
    assert l07["coverage"][coverage_id] == apricorn_cells
for cell_id in apricorn_cells:
    row = l07_cells[cell_id]
    edition, mode = cell_id.rsplit("-", 2)[1:]
    assert row["edition"] == edition
    assert row["closure"] == (
        "base_deutsch" if mode == "2d" else "dramaless_fp"
    )
    assert row["env"] == {"QA_RENDER_MODE": mode}
    assert [phase["name"] for phase in row["passes"]] == [
        "acquire", "visual", "reload",
    ]
    assert row["images"] == {"exact_count": 52, "min_bytes": 1000}
assert "l07-blocked-ball-matrix" not in l07_cells
espeon_driver = (ROOT / "tools/espeon_psybeam_love_qa_driver.lua").read_text("utf-8")
for token in (
    'game:writeSave()', 'SaveData.load()', 'game:restoreSave(loaded, false)',
    'native reload retains the taught Espeon PSYBEAM',
    'os.getenv("KA_IMPORTED_POKEMON")', 'loadfile(importedPokemon)',
):
    assert token in espeon_driver, token
assert 'dofile("data/generated/pokemon.lua")' not in espeon_driver

assert tuple(plan["closures"]) == gate.CLOSURES
assert plan["closures"]["base_deutsch"]["packages"] == [
    "authority", "language:{edition}",
]
assert plan["closures"]["dramaless_fp"]["packages"] == [
    "authority", "language:{edition}", "DRAMALESS_SHAPE", "ds_fp_ceiling",
]
assert plan["closures"]["battle_art"]["packages"] == [
    "authority", "language:{edition}", "BATTLE_ART_VOXEL_FORK",
]
assert "BATTLE_ART_VOXEL_FORK" in plan["closures"]["dramaless_fp"]["forbidden"]
assert {"DRAMALESS_SHAPE", "ds_fp_ceiling"}.issubset(
    plan["closures"]["battle_art"]["forbidden"]
)

expected_engine = {
    "app_archive_sha256": "b28029fd61341fd0fbe2cf0bdc5d9265130ff3815f930f585eaaed3b29f1ea3b",
    "game_love_sha256": "8d73505cc343c0adb8832069bf0cf6954e99cda0b993229307cc8d462511151c",
    "love_binary_sha256": "79e8b524f2acbc58d7b0bd56086d1e4031b683c901833c5e78e37379a6b3e221",
    "build_info_sha256": "6943e1827356c362a6628de5f02faa2e7f6054e6cabc19ded9b0318c81a0cdad",
    "sha256sums_sha256": "7935304062f6035de841dd9e98be6863e001e4d64aaa13650b05acb103c767ef",
}
for key, value in expected_engine.items():
    assert receipt["engine"][key] == value
assert "361a" not in RECEIPT.read_text("utf-8")
assert receipt["engine"]["app_bundle_relpath"] == "gen1recomp-0.1.79-d229a454-macos.app"
assert receipt["engine"]["build_info"] == "inputs/build-info.json"
engine_archive = GATE / receipt["engine"]["app_archive"]
build_info = GATE / receipt["engine"]["build_info"]
assert engine_archive.stat().st_size == 17_622_369
assert digest(engine_archive) == expected_engine["app_archive_sha256"]
assert digest(build_info) == expected_engine["build_info_sha256"]
gate.verify_engine_archive(engine_archive, receipt["engine"], build_info)
with zipfile.ZipFile(engine_archive) as archive:
    names = archive.namelist()
assert not any(name.endswith("BuildInfo.json") or name.endswith("build-info.json") for name in names)

expected_languages = {
    "red": ("deutsch", "2.1.6", "bb33db0449b85cb85ec37fae9d75350aa15afd60f84f928aa8f19492696effc8"),
    "blue": ("deutsch-blau", "1.0.2", "22cb108d7ea75f431da383517ceda4e7cf265f5e6a1306241ccd2cb30df11840"),
    "yellow": ("deutsch-gelb", "1.0.5", "2fede157029190b9dae86b1d6a365f88115ad5a17c9017f6c7d3b32d41f3a673"),
}
for edition, (manifest_id, version, sha) in expected_languages.items():
    row = receipt["languages"][edition]
    assert (row["manifest_id"], row["version"], row["sha256"]) == (
        manifest_id, version, sha,
    )
    package = GATE / row["path"]
    assert package.is_file() and not package.is_symlink() and digest(package) == sha
assert gate.language_set_hash(receipt) == (
    "624fb00cacdfe85d53292339a8bee9e5cfd928d7048ac1cdbb31836d94200e0b"
)

for key, expected in {
    "DRAMALESS_SHAPE": "8b073fe0a97db8eeb10cfa0a3b9f7d52767217780bd251f885326745c838cfb9",
    "ds_fp_ceiling": "28ce02e4bf57143677a9664146ad45814818f213f5e3b53ceb4546a8cf3a80b8",
    "BATTLE_ART_VOXEL_FORK": "10d7e80a58d9046b41ec446900f2f15aa6021335a1547d9209117f3a22a0604e",
}.items():
    row = receipt["renderers"][key]
    package = GATE / row["path"]
    assert package.is_file() and not package.is_symlink() and digest(package) == expected

snapshot = INPUTS / "harness_snapshot"
assert digest(snapshot / "source_snapshot/slot7_original_readonly.lua") == (
    "f0d8c1925c09ad8ba825240f6218b81fd1f7dbd6c30348f6304fb006dcf2f8a0"
)
assert digest(snapshot / "source_snapshot/options_original_readonly.lua") == (
    "2f5ca783613d1ecefd12b3942ef7b12f0c78180e9b6a3820ba2637f21b91e540"
)
assert digest(snapshot / "driver_util.lua") == (
    "2ab81a7d14c816b71e819c8421e2f761dbd5f89015a59cc084499df71c3da8d2"
)
assert "tests/drivers/util.lua" not in plan["support_files"]
for relative in info["harness"]:
    frozen = snapshot / relative
    assert frozen.is_file() and not frozen.is_symlink(), relative
for relative, expected in {
    "tools/mod_allowlist_runtime_qa.lua": "549755e01a832d78dc29f67fd59a972e107b52107676021923c270fa32522839",
    "tests/integrated_hooks_package_driver.lua": "7bc5d812751fc0657ee1205bcf2d3ca54ceedf70f787b01c2dc535ad43672821",
    "tests/legacy_oak_finale_visual_driver.lua": "324f6c32a237600f5c4231ff0c62ec08d597baa6cce4e31cc2960f874b741712",
    "tests/legacy_oak_finale_language_setup_driver.lua": "eec572842c0a31c6b7a10935e74fe10bdf4a50c630395eef7b6ac91df8c1dcb7",
    "tools/route22_rematch_qa_setup.lua": "5d99a81a5ceeaed38d5e5ae679506e2e4b1000f6a9610f496f7aafa30103ffda",
    "tools/route22_rematch_package_driver.lua": "6bee993a8495e0287fe95aca27e01f1e44fe1fae7cc9b0ee525f9d0dc4d76c0c",
    "tests/item_select_help_visual_driver.lua": "5a095fc3b2ffb33bd6bf71505ea428c8e65751cb5bf9fa243276f42fbe68453e",
    "tests/item_select_help_language_setup_driver.lua": "7e3ce372f545f5b4b7629073367adb30bc97ed323a628a9132deaf5717a003bb",
    "tests/apricorn_balls_package_driver.lua": "39401fb501e02c993f90ec832adbc8af996259e87bc57e43a1a641a91921014c",
    "tests/journeys_ball_skins_visual_driver.lua": "3d0611b71e35c65d7893e5a5d9391abbd2c689f973bc2fa134fe65e633a8e9e4",
}.items():
    # This is an immutable pre-0.1.90 receipt. Current source drivers evolve
    # with later releases; only the captured harness snapshot is authoritative
    # for reproducing the historical same-hash run.
    assert digest(snapshot / relative) == expected, relative
assert set(path.name for path in (INPUTS / "authority_snapshot").iterdir()) == {
    "PACKAGE_ACCEPTANCE_LANES.tsv",
    "USER_CHAT_REGRESSION_GATE.md",
    "FEATURE_ACCEPTANCE_MATRIX.md",
}

dry = gate.dry_run(info, receipt)
encoded = json.dumps(dry, sort_keys=True)
assert dry["lane_order"][-2:] == ["L09_REVERSE_MODULE_SURFACES", "L10_FINAL_SAME_HASH"]
assert dry["cell_count"] == 192 and dry["blocked_driver_count"] == 0
assert dry["blocked_matrix_row_count"] == 0
assert dry["user_gate_count"] == 44 and dry["feature_count"] == 34
assert dry["love_started"] is False and dry["stop_on_first_defect"] is True
assert dry["closures_physically_separate"] is True
dry_cells = {cell["id"]: cell for cell in dry["cells"]}
assert dry_cells["l00-allowlist-negative-red"]["runtime"] == (
    "<RUNTIME_ROOT>/cell_closures/l00-allowlist-negative-red"
)
assert dry_cells["l00-integrated-hooks-full"]["runtime"] == (
    "<RUNTIME_ROOT>/cell_closures/l00-integrated-hooks-full"
)
assert all(
    dry_cells[f"l01-upgrade-{source}-{edition}"]["runtime"].endswith(
        f"/base_deutsch/{edition}"
    )
    for source in ("6-0-11", "rc25", "rc26", "rc27")
    for edition in gate.EDITIONS
)
alt_setup = (ROOT / "tools/hevo_alt_full_path_qa_setup.lua").read_text("utf-8")
assert ':format(character:lower(), renderer:lower())' in alt_setup
assert dry_cells["l10-aggregate"]["runtime"] == "<INTERNAL_RECEIPT_OPERATION>"
assert not any(marker in encoded for marker in ("/Users/", ".worktrees", "/Documents/Recompile/"))

source = ORCHESTRATOR.read_text("utf-8")
run_cell_source = source[source.index("def run_cell"):source.index("def run_all")]
assert ".extractall(" not in source
assert "ROOT / relative" not in source
assert 'shutil.copy2(HARNESS_SNAPSHOT / relative' in source
assert 'tree_sha256(runtime / "imported_data")' in source
assert "with zipfile.ZipFile(imported_archive) as imported:" in source
assert "imported_files = zip_tree_manifest(imported, skip_macos=True)" in source
assert 'runtime mod tree drifted' in source
assert 'materialized engine binary drifted' in source
assert 'cwd=runtime / "qa_harness"' in source
assert "env = process_environment(runtime)" in source
assert "phase_env = dict(env)" in source
assert "os.environ.items()" not in source
assert '"PATH": "/usr/bin:/bin:/usr/sbin:/sbin"' in source
assert '"PWD": str(harness)' in source
assert '"POKEPORT_DATA_DIR"' not in run_cell_source
assert "identity_cache = seed_identity_cache(runtime, cell[\"identity\"], cell[\"edition\"])" in source
assert run_cell_source.count("verify_identity_cache(") == 2
first_identity_check = run_cell_source.index("verify_identity_cache(")
process_call = run_cell_source.index("run_managed_process(")
finally_clause = run_cell_source.index("finally:", process_call)
second_identity_check = run_cell_source.index(
    "verify_identity_cache(", first_identity_check + 1,
)
assert first_identity_check < process_call < finally_clause < second_identity_check
assert '[str(runtime / "engine.app/Contents/MacOS/love"),' in run_cell_source
assert '"--game", str(closure)]' in run_cell_source
assert "conventional.exists() or conventional.is_symlink()" in source
assert '"KA_IMPORTED_POKEMON": str(' in source
assert 'runtime / "imported_data" / cell["edition"] / "data/generated/pokemon.lua"' in source
assert '"KA_SOURCE_SAVE": str(' in source
assert 'runtime / "qa_harness/immutable_inputs/source_snapshot/slot7_original_readonly.lua"' in source
assert '"KA_SOURCE_OPTIONS": str(' in source
assert 'runtime / "qa_harness/immutable_inputs/source_snapshot/options_original_readonly.lua"' in source
assert '"KA_PRESENTATION_COMPOSITE": str(' in source
assert '"KA_CHARACTER_MATRIX", "KA_PRESENTATION_COMPOSITE"' in source
assert "validate_pass_environment(" in source
assert "before_images = image_snapshot(output)" in source
assert "write_pass_image_manifest(" in source
assert "subprocess.Popen(" in source
assert "start_new_session=True" in source
assert "os.killpg(process.pid, signal.SIGKILL)" in source
assert "os.killpg(process.pid, 0)" in source
assert '"group_empty_verified": True' in source
assert '"detached_descendants_attested": False' in source
assert "signal.SIGTERM" not in gate.run_managed_process.__code__.co_names
assert "subprocess.run(" not in run_cell_source
assert "if args.mode == \"run\":" in source
assert '"schema": "ka-package-image-receipt/v1"' in source

process_env = gate.process_environment(Path("/private/tmp/ka-final-same-hash.contract"))
assert set(process_env) == {"PATH", "TMPDIR", "LANG", "LC_ALL", "TZ", "HOME", "PWD"}
assert process_env["PWD"] == "/private/tmp/ka-final-same-hash.contract/qa_harness"
assert process_env["PATH"] == "/usr/bin:/bin:/usr/sbin:/sbin"
assert not any(marker in json.dumps(process_env) for marker in (".worktrees", "/Documents/Recompile/"))
assert gate.safe_runtime("/private/tmp/ka-final-same-hash.contract") == Path(
    "/private/tmp/ka-final-same-hash.contract"
)
assert gate.safe_evidence(
    "/private/tmp/ka-final-same-hash-evidence.contract"
) == Path("/private/tmp/ka-final-same-hash-evidence.contract")
for unsafe, validator in (
    ("/private/tmp/child/../ka-final-same-hash.contract", gate.safe_runtime),
    ("/private/tmp/child/../ka-final-same-hash-evidence.contract", gate.safe_evidence),
    (str(ROOT / "ka-final-same-hash-evidence.contract"), gate.safe_evidence),
):
    try:
        validator(unsafe)
    except gate.GateError:
        pass
    else:
        raise AssertionError(f"unsafe output path passed: {unsafe}")

l01 = next(lane for lane in plan["lanes"] if lane["order"] == 1)
l01_cells = {cell["id"]: cell for cell in l01["cells"]}
assert l01["coverage"]["RC65-EARLY-BALANCE"][-3:] == [
    "l01-first-badge-red", "l01-first-badge-blue", "l01-first-badge-yellow",
]
for edition in gate.EDITIONS:
    row = l01_cells[f"l01-first-badge-{edition}"]
    assert row["edition"] == edition and row["images"] == {"exact_count": 0}
    assert row["driver"] == "tools/first_badge_connected_package_driver.lua"

upgrade_cells = [
    f"l01-upgrade-{source}-{edition}"
    for source in ("6-0-11", "rc25", "rc26", "rc27")
    for edition in gate.EDITIONS
]
assert all(cell_id in l01["coverage"]["RULE-001"] for cell_id in upgrade_cells)
assert "l01-blocked-upgrade-matrix" not in l01_cells
for cell_id in upgrade_cells:
    row = l01_cells[cell_id]
    assert [phase["name"] for phase in row["passes"]] == [
        "stage", "migrate", "disabled", "reenabled",
    ]
    assert row["images"] == {"exact_count": 0}

l02 = next(lane for lane in plan["lanes"] if lane["order"] == 2)
l02_cells = {cell["id"]: cell for cell in l02["cells"]}
presentation_cells = [
    f"l02-presentation-{edition}-{renderer}"
    for edition in gate.EDITIONS
    for renderer in ("2d", "battle-art-full")
] + [
    "l02-presentation-blitz-red-2d",
    "l02-presentation-blitz-red-battle-art-full",
]
assert "l02-blocked-complete-presentation" not in l02_cells
assert all(cell_id in l02_cells for cell_id in presentation_cells)
assert all(
    l02_cells[cell_id]["closure"] == "battle_art"
    for cell_id in presentation_cells
)
assert {
    cell_id: [phase["images"]["exact_count"]
              for phase in l02_cells[cell_id]["passes"]]
    for cell_id in presentation_cells
} == {
    "l02-presentation-red-2d": [45, 5, 8, 0, 0],
    "l02-presentation-red-battle-art-full": [15, 5, 8, 0, 0],
    "l02-presentation-blue-2d": [45, 5, 8, 0, 0],
    "l02-presentation-blue-battle-art-full": [15, 5, 8, 0, 0],
    "l02-presentation-yellow-2d": [45, 5, 8, 0, 0],
    "l02-presentation-yellow-battle-art-full": [15, 5, 8, 0, 0],
    "l02-presentation-blitz-red-2d": [6, 0, 0],
    "l02-presentation-blitz-red-battle-art-full": [6, 0, 0],
}
assert all(
    [phase["name"] for phase in l02_cells[cell_id]["passes"]]
    == (["characters", "crystal_title_gorochu", "follower_wilds",
         "reload_verify", "aggregate"]
        if l02_cells[cell_id]["env"]["QA_PRESENTATION_SOURCE"] == "FRESH"
        else ["blitz_restore", "reload_verify", "aggregate"])
    for cell_id in presentation_cells
)
assert {
    cell_id: l02_cells[cell_id]["images"]["exact_count"]
    for cell_id in presentation_cells
} == {
    "l02-presentation-red-2d": 58,
    "l02-presentation-red-battle-art-full": 28,
    "l02-presentation-blue-2d": 58,
    "l02-presentation-blue-battle-art-full": 28,
    "l02-presentation-yellow-2d": 58,
    "l02-presentation-yellow-battle-art-full": 28,
    "l02-presentation-blitz-red-2d": 6,
    "l02-presentation-blitz-red-battle-art-full": 6,
}
for gate_id in (*l02["user_gates"], *l02["feature_ids"]):
    assert all(cell_id in l02["coverage"][gate_id]
               for cell_id in presentation_cells)

l03 = next(lane for lane in plan["lanes"] if lane["order"] == 3)
l03_cells = {cell["id"]: cell for cell in l03["cells"]}
assert not any(cell_id.startswith("l03-blocked-") for cell_id in l03_cells)
assert len([cell_id for cell_id in l03_cells if cell_id.startswith("l03-path-")]) == 12
assert all(
    l03_cells[f"l03-path-{character}-alt-{renderer}"]["identity"]
        == f"ka65-final-hevo-{character}-alt-{renderer}"
    for character in ("red", "blue", "green")
    for renderer in ("2d", "full")
)
assert len([cell_id for cell_id in l03_cells if cell_id.startswith("l03-encounter-")]) == 12
assert all(
    l03_cells[cell_id]["env"].get("HEVO_ENCOUNTER_NATURAL_ONLY") == "1"
    and "HEVO NATURAL DUNGEON ENCOUNTER PASS"
        in l03_cells[cell_id]["result"]["contains"]
    for cell_id in l03_cells if cell_id.startswith("l03-encounter-")
)
assert len([cell_id for cell_id in l03_cells if cell_id.startswith("l03-professor-")]) == 12
assert len([cell_id for cell_id in l03_cells if cell_id.startswith("l03-mega-")]) == 24
assert {l03_cells[cell_id]["edition"] for cell_id in l03["coverage"]["RC65-PROFESSOR-HINTS"]} == {
    "red", "blue", "yellow",
}
assert all(
    l03_cells[cell_id]["result"]["path"] == "driver_result.txt"
    for cell_id in l03["coverage"]["RC65-HOENN-MEGAS"]
    if cell_id.startswith("l03-mega-")
)

l04 = next(lane for lane in plan["lanes"] if lane["order"] == 4)
l04_cells = {cell["id"]: cell for cell in l04["cells"]}
assert "l04-blocked-connected-legacy" not in l04_cells
assert len([cell_id for cell_id in l04_cells if cell_id.startswith("l04-connected-")]) == 6
assert all(
    [phase["name"] for phase in l04_cells[cell_id]["passes"]] == [
        "language-setup", "connected-story-partner",
    ]
    for cell_id in l04_cells if cell_id.startswith("l04-connected-")
)
assert l04_cells["l04-workshop-full"]["closure"] == "dramaless_fp"
assert l04_cells["l04-archive-transaction"]["images"] == {"exact_count": 0}

l05 = next(lane for lane in plan["lanes"] if lane["order"] == 5)
l05_cells = {cell["id"]: cell for cell in l05["cells"]}
assert set(cell_id for cell_id in l05_cells if cell_id.startswith("l05-johto-")) == {
    "l05-johto-blitz-2d", "l05-johto-blitz-full",
    "l05-johto-fresh-2d", "l05-johto-fresh-full",
}
for cell_id in l05["coverage"]["RC65-GSC-LATEGAME"]:
    assert l05_cells[cell_id]["images"] == {"exact_count": 44, "min_bytes": 1000}

l06 = next(lane for lane in plan["lanes"] if lane["order"] == 6)
l06_cells = {cell["id"]: cell for cell in l06["cells"]}
wanderer_cells = l06["coverage"]["LEGACY-WANDERERS-CORE"]
assert len(wanderer_cells) == 6
assert {(l06_cells[cell_id]["edition"], l06_cells[cell_id]["env"]["QA_RENDER_MODE"])
        for cell_id in wanderer_cells} == {
    (edition, renderer) for edition in gate.EDITIONS for renderer in ("2d", "full")
}
for cell_id in wanderer_cells:
    assert l06_cells[cell_id]["images"] == {"exact_count": 8, "min_bytes": 1000}

l08 = next(lane for lane in plan["lanes"] if lane["order"] == 8)
l08_cells = {cell["id"]: cell for cell in l08["cells"]}
assert all(
    [phase["driver"] for phase in l08_cells[cell_id]["passes"]] == [
        "tests/legacy_oak_finale_language_setup_driver.lua",
        "tests/mew_provenance_rby_visual_driver.lua",
    ]
    for cell_id in l08["coverage"]["MEW-001"]
)
assert len(l08["coverage"]["OAK-001"]) == 12
assert l08["coverage"]["OAK-001"] == l08["coverage"]["RC65-OAK-FINALE"]
assert {
    (l08_cells[cell_id]["edition"], l08_cells[cell_id]["env"]["QA_LANGUAGE"],
     l08_cells[cell_id]["env"]["QA_RENDERER"])
    for cell_id in l08["coverage"]["OAK-001"]
} == {
    (edition, locale, renderer)
    for edition in gate.EDITIONS
    for locale in ("en", "de")
    for renderer in ("2D", "BATTLE_ART_FULL")
}
route22 = l08["coverage"]["RC65-ROUTE22-REMATCH"]
assert route22 == [
    "l08-route22-red-fresh", "l08-route22-red-alt",
    "l08-route22-blue-fresh", "l08-route22-blue-alt",
    "l08-route22-yellow-fresh", "l08-route22-yellow-alt",
]
for cell_id in route22:
    row = l08_cells[cell_id]
    assert row["setup"] == "tools/route22_rematch_qa_setup.lua"
    assert row["driver"] == "tools/route22_rematch_package_driver.lua"
    assert row["images"] == {"exact_count": 5, "min_bytes": 1000}

assert all(
    cell.get("images") is not None or cell.get("status") == "BLOCKED_DRIVER" or cell.get("kind")
    for lane in plan["lanes"] for cell in lane["cells"]
)

for mutation, expected_error in (
    ((lambda value: value["lanes"][0].pop("coverage")), "execution coverage mismatch"),
    ((lambda value: value["lanes"][10].update(cells=[])), "L10 must contain"),
    ((lambda value: value["closures"]["battle_art"].update(packages=["authority"])), "package composition drifted"),
    ((lambda value: value["lanes"][0]["cells"][1].update(identity=value["lanes"][0]["cells"][0]["identity"])), "identity is missing or reused"),
    ((lambda value: value.update(lane_authority="qa/source.tsv")), "immutable lane-authority snapshot"),
    ((lambda value: value["lanes"][0]["cells"][-1]["fixture_mods"][0].update(source="tests/fixtures/outside")), "fixture source is outside"),
    ((lambda value: value["support_files"].append("../source.lua")), "support_files entry is not a canonical relative path"),
    ((lambda value: value["lanes"][0]["cells"][0].update(driver="tests/../source.lua")), "driver is not a canonical relative path"),
    ((lambda value: value["lanes"][0]["cells"][0].update(identity="../../shared")), "identity is missing or reused"),
    ((lambda value: value["lanes"][0]["cells"][0]["result"].update(path="../receipt.txt")), "result path is not a canonical relative path"),
    ((lambda value: value["lanes"][0]["cells"][0]["result"].update(contains="PASS")), "has no fail-closed result contract"),
    ((lambda value: value["lanes"][2]["cells"][-1]["passes"][0]["env"].update(QA_RENDERER="2D")), "overrides cell environment"),
):
    broken = copy.deepcopy(plan)
    mutation(broken)
    try:
        gate.validate_plan(broken)
    except gate.GateError as exc:
        assert expected_error in str(exc), (expected_error, str(exc))
    else:
        raise AssertionError(f"negative plan mutation passed: {expected_error}")

bad_receipt = copy.deepcopy(receipt)
bad_receipt["orchestrator_sha256"] = "0" * 64
try:
    gate.validate_receipt(bad_receipt, info, require_ready=False)
except gate.GateError as exc:
    assert "orchestrator_sha256 drifted" in str(exc)
else:
    raise AssertionError("receipt accepted a different orchestrator")

schema = subprocess.run(
    [sys.executable, "-B", str(ORCHESTRATOR), "schema"],
    cwd=ROOT, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False,
)
assert schema.returncode == 0, schema.stderr
assert "lanes=11 cells=192 users=44 features=34 blocked=0 blocked_rows=0" in schema.stdout
preflight = subprocess.run(
    [sys.executable, "-B", str(ORCHESTRATOR), "preflight"],
    cwd=ROOT, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False,
)
assert preflight.returncode == 0, preflight.stderr
assert "PASS immutable same-hash preflight" in preflight.stdout

with tempfile.TemporaryDirectory(
    prefix="ka-final-orchestrator-contract.", dir="/private/tmp",
) as temp_text:
    temp = Path(temp_text)
    duplicate_json = temp / "duplicate.json"
    duplicate_json.write_text('{"status":"pending","status":"ready"}\n', "utf-8")
    try:
        gate.read_json(duplicate_json)
    except gate.GateError as exc:
        assert "duplicate object key" in str(exc)
    else:
        raise AssertionError("duplicate JSON key passed")
    safe_archive = temp / "safe.zip"
    with zipfile.ZipFile(safe_archive, "w") as archive:
        archive.writestr("red/cache.marker", "red\n")
    safe_target = temp / "safe"
    gate.extract_regular_archive(safe_archive, safe_target)
    assert (safe_target / "red/cache.marker").read_text("utf-8") == "red\n"

    unsafe_archive = temp / "unsafe.zip"
    with zipfile.ZipFile(unsafe_archive, "w") as archive:
        archive.writestr("../source-leak", "forbidden\n")
    try:
        gate.extract_regular_archive(unsafe_archive, temp / "unsafe")
    except gate.GateError as exc:
        assert "unsafe archive member" in str(exc)
    else:
        raise AssertionError("path-traversing archive passed")

    imported_archive = temp / "imported.zip"
    pokemon_shas = {}
    with zipfile.ZipFile(imported_archive, "w") as archive:
        for edition in gate.EDITIONS:
            for name in (
                "constants", "maps", "tilesets", "text", "text_pointers",
                "trainer_headers", "font", "sprites", "pokemon", "moves", "items",
                "type_chart", "trainers", "encounters", "field", "battle_anims",
            ):
                relative = f"{edition}/data/generated/{name}.lua"
                payload = f"return {{ edition = '{edition}', module = '{name}' }}\n".encode()
                archive.writestr(relative, payload)
                if name == "pokemon":
                    pokemon_shas[edition] = hashlib.sha256(payload).hexdigest()
            archive.writestr(
                f"{edition}/rom-cache.complete",
                f"rom-cache-v10:{gate.RBY_ROM_SHA1[edition]}",
            )
            for asset in (
                "assets/generated/title/pokemon_logo.png",
                "assets/generated/fonts/font.png",
                "assets/generated/battle/front/pikachu.png",
                "assets/generated/battle/anims/move_anim_0.png",
                "assets/generated/battle/anims/move_anim_1.png",
                "assets/generated/audio/programs.bin",
                "assets/generated/trade/game_boy.png",
            ):
                archive.writestr(f"{edition}/{asset}", b"fixture")
            if edition == "yellow":
                for asset in (
                    "assets/generated/battle/trainers/jessie_james.png",
                    "assets/generated/battle/profoakb.png",
                    "assets/generated/pikachu/pikapic_1.png",
                ):
                    archive.writestr(f"yellow/{asset}", b"fixture")
    with zipfile.ZipFile(imported_archive) as archive:
        imported_files = gate.zip_tree_manifest(archive, skip_macos=True)
    imported_row = {
        "schema": "gen1recomp-imported-rby-cache/v2",
        "sha256": digest(imported_archive),
        "engine_payload_sha256": "a" * 64,
    }
    imported_provenance = temp / "imported.receipt.json"
    imported_provenance.write_text(json.dumps({
        "schema": imported_row["schema"],
        "archive_sha256": imported_row["sha256"],
        "tree_sha256": gate.manifest_sha256(imported_files),
        "editions": list(gate.EDITIONS),
        "contains_raw_rom_image": False,
        "contains_rom_derived_content": True,
        "contains_verbatim_rom_fragments": True,
        "distribution": "private_local_gate_input_only",
        "full_runtime_cache": True,
        "cache_format": "rom-cache-v10",
        "engine_payload_sha256": imported_row["engine_payload_sha256"],
        "runtime_cache": {
            edition: {
                "marker": f"rom-cache-v10:{gate.RBY_ROM_SHA1[edition]}",
                "marker_sha256": imported_files[f"{edition}/rom-cache.complete"],
                "regular_file_count": sum(path.startswith(f"{edition}/") for path in imported_files),
                "data_module_count": sum(path.startswith(f"{edition}/data/generated/") for path in imported_files),
                "asset_file_count": sum(path.startswith(f"{edition}/assets/generated/") for path in imported_files),
                "pokemon_sha256": pokemon_shas[edition],
            } for edition in gate.EDITIONS
        },
        "generated_pokemon": {
            edition: {
                "path": f"{edition}/data/generated/pokemon.lua",
                "sha256": pokemon_shas[edition],
            } for edition in gate.EDITIONS
        },
    }) + "\n", "utf-8")
    gate.validate_imported_cache(imported_archive, imported_provenance, imported_row)

    bad_provenance = json.loads(imported_provenance.read_text("utf-8"))
    bad_provenance["generated_pokemon"].pop("yellow")
    imported_provenance.write_text(json.dumps(bad_provenance) + "\n", "utf-8")
    try:
        gate.validate_imported_cache(imported_archive, imported_provenance, imported_row)
    except gate.GateError as exc:
        assert "exact R/B/Y generated Pokemon rows" in str(exc)
    else:
        raise AssertionError("incomplete imported-cache provenance passed")

    rom_archive = temp / "rom.zip"
    with zipfile.ZipFile(rom_archive, "w") as archive:
        archive.writestr("red/data/generated/pokemon.lua", "return {}\n")
        archive.writestr("red/source.gbc", b"forbidden")
    try:
        gate.validate_imported_cache(rom_archive, imported_provenance, {
            **imported_row, "sha256": digest(rom_archive),
        })
    except gate.GateError as exc:
        assert "forbidden ROM-shaped file" in str(exc)
    else:
        raise AssertionError("ROM-shaped imported-cache file passed")

    image_output = temp / "images"
    image_output.mkdir()
    gate.write_image_manifest(image_output, {"exact_count": 0})
    image_receipt = json.loads((image_output / "image_receipt.json").read_text("utf-8"))
    assert image_receipt["actual_count"] == 0
    assert image_receipt["manifest_sha256"] == digest(image_output / "image_sha256.tsv")
    (image_output / "bad.png").write_bytes(b"not-png")
    try:
        gate.write_image_manifest(image_output, {"exact_count": 1})
    except gate.GateError as exc:
        assert "non-PNG payload" in str(exc)
    else:
        raise AssertionError("non-PNG evidence passed")
    (image_output / "bad.png").unlink()
    before = gate.image_snapshot(image_output)
    png = image_output / "phase.png"
    png.write_bytes(b"\x89PNG\r\n\x1a\n" + b"x" * 16)
    gate.write_pass_image_manifest(
        image_output, "phase", before,
        {"exact_count": 1, "min_bytes": 8},
    )
    try:
        gate.write_pass_image_manifest(
            image_output, "empty-phase", gate.image_snapshot(image_output),
            {"exact_count": 1, "min_bytes": 8},
        )
    except gate.GateError as exc:
        assert "image delta failed" in str(exc)
    else:
        raise AssertionError("missing pass-local PNG evidence passed")

    # The packaged macOS binary stays fused when ``--game`` selects a closure.
    # Mount the complete cache only into that identity and reject the
    # conventional LOVE/<identity> fallback before and after every process.
    identity_runtime = temp / "identity-runtime"
    identity_source = identity_runtime / "imported_data/red"
    identity_source_file = identity_source / "data/generated/pokemon.lua"
    identity_asset = identity_source / "assets/generated/fonts/font.png"
    identity_source_file.parent.mkdir(parents=True)
    identity_source_file.write_text("return { edition = 'red' }\n", "utf-8")
    identity_asset.parent.mkdir(parents=True)
    identity_asset.write_bytes(b"font-fixture\n")
    identity_fused = temp / "identity-home/Library/Application Support/identity"
    identity_conventional = (
        temp / "identity-home/Library/Application Support/LOVE/identity"
    )
    original_identity_paths = gate.identity_paths
    gate.identity_paths = lambda identity: (
        identity_fused, identity_conventional,
    )
    try:
        mounted = gate.seed_identity_cache(identity_runtime, "identity", "red")
        assert mounted == identity_fused / "red"
        assert not identity_conventional.exists()
        expected_identity_sha256 = gate.tree_sha256(identity_source)
        gate.verify_identity_cache(
            identity_runtime, "identity", "red", mounted,
            expected_identity_sha256,
        )

        mounted_file = mounted / "data/generated/pokemon.lua"
        mounted_file.write_text("return { drift = true }\n", "utf-8")
        try:
            gate.verify_identity_cache(
                identity_runtime, "identity", "red", mounted,
                expected_identity_sha256,
            )
        except gate.GateError as exc:
            assert "mounted identity cache drifted" in str(exc)
        else:
            raise AssertionError("mutated mounted identity cache passed")
        mounted_file.write_bytes(identity_source_file.read_bytes())

        original_source = identity_source_file.read_bytes()
        identity_source_file.write_bytes(original_source + b"drift\n")
        try:
            gate.verify_identity_cache(
                identity_runtime, "identity", "red", mounted,
                expected_identity_sha256,
            )
        except gate.GateError as exc:
            assert "identity cache source drifted" in str(exc)
        else:
            raise AssertionError("mutated identity cache source passed")
        identity_source_file.write_bytes(original_source)

        identity_conventional.mkdir(parents=True)
        try:
            gate.verify_identity_cache(
                identity_runtime, "identity", "red", mounted,
                expected_identity_sha256,
            )
        except gate.GateError as exc:
            assert "conventional LOVE identity fallback is present" in str(exc)
        else:
            raise AssertionError("conventional LOVE identity fallback passed")
    finally:
        gate.identity_paths = original_identity_paths

    # A materialization receipt is not trusted on its own: every mutable
    # runtime input is rehashed immediately before any LÖVE process starts.
    runtime = temp / "runtime"
    binary = runtime / "engine.app/Contents/MacOS/love"
    binary.parent.mkdir(parents=True)
    binary.write_bytes(b"immutable-engine-binary\n")
    framework = runtime / "engine.app/Contents/Frameworks/love.framework/Versions/A/love"
    framework.parent.mkdir(parents=True)
    framework.write_bytes(b"immutable-love-framework\n")
    harness_file = runtime / "qa_harness/tests/driver.lua"
    harness_file.parent.mkdir(parents=True)
    harness_file.write_text("return true\n", "utf-8")
    runtime_module_map = runtime / "qa_harness/authority/MODULE_ACCEPTANCE_MAP.tsv"
    runtime_module_map.parent.mkdir(parents=True)
    shutil.copy2(gate.MODULE_MAP, runtime_module_map)
    closure_hashes = {}
    mod_hashes = {}
    receipt_sha = "d" * 64
    core = {key: "a" * 64 for key in gate.core_hashes(receipt)}
    for closure in gate.CLOSURES:
        for edition in gate.EDITIONS:
            closure_root = runtime / "closures" / closure / edition
            mod = closure_root / "mods/0000_kanto_ascendant"
            mod.mkdir(parents=True)
            (closure_root / "main.lua").write_text("return true\n", "utf-8")
            (mod / "manifest.json").write_text(
                '{"id":"kanto_ascendant","version":"1"}\n', "utf-8",
            )
            for module_name in module_map:
                (mod / module_name).write_text("return true\n", "utf-8")
            key = f"{closure}/{edition}"
            mod_hashes[key] = {"0000_kanto_ascendant": gate.tree_sha256(mod)}
            closure_hashes[key] = gate.tree_sha256(closure_root)
            (closure_root / ".ka_final_runtime.json").write_text(
                json.dumps({"receipt_sha256": receipt_sha}) + "\n", "utf-8",
            )
    fixture_cell = runtime / "cell_closures/fixture-cell"
    fixture_mod_hashes = {}
    for dirname, manifest_id in (
        ("0000_kanto_ascendant", "kanto_ascendant"),
        ("negative_probe", "negative_probe"),
    ):
        fixture_mod = fixture_cell / "mods" / dirname
        fixture_mod.mkdir(parents=True)
        (fixture_mod / "manifest.json").write_text(json.dumps({
            "id": manifest_id, "version": "1",
        }) + "\n", "utf-8")
        if dirname == "0000_kanto_ascendant":
            for module_name in module_map:
                (fixture_mod / module_name).write_text("return true\n", "utf-8")
        fixture_mod_hashes[dirname] = gate.tree_sha256(fixture_mod)
    (fixture_cell / "main.lua").write_text("return true\n", "utf-8")
    fixture_cell_hash = gate.tree_sha256(fixture_cell)
    (fixture_cell / ".ka_final_runtime.json").write_text(json.dumps({
        "schema": "ka-final-fixture-runtime/v1",
        "cell_id": "fixture-cell",
        "receipt_sha256": receipt_sha,
        "core": core,
        "mod_tree_sha256": fixture_mod_hashes,
    }) + "\n", "utf-8")
    imported = runtime / "imported_data"
    for edition in gate.EDITIONS:
        marker = imported / edition / "data/generated/pokemon.lua"
        marker.parent.mkdir(parents=True)
        marker.write_text("return {}\n", "utf-8")
    runtime_hashes = {
        "engine_app_tree_sha256": gate.manifest_sha256(
            gate.app_tree_manifest(runtime / "engine.app")
        ),
        "harness_tree_sha256": gate.tree_sha256(runtime / "qa_harness"),
        "closure_tree_sha256": closure_hashes,
        "mod_tree_sha256": mod_hashes,
        "cell_closure_tree_sha256": {"fixture-cell": fixture_cell_hash},
        "cell_mod_tree_sha256": {"fixture-cell": fixture_mod_hashes},
        "imported_tree_sha256": gate.tree_sha256(imported),
    }
    runtime_receipt = copy.deepcopy(receipt)
    runtime_receipt["engine"]["love_binary_sha256"] = digest(binary)
    runtime_ctx = {
        "receipt": runtime_receipt,
        "receipt_sha256": receipt_sha,
        "core": core,
        "runtime_hashes": runtime_hashes,
        "plan_info": {"module_map": module_map},
    }
    (runtime / ".ka_final_materialization.json").write_text(json.dumps({
        "receipt_sha256": receipt_sha,
        "plan_sha256": digest(PLAN),
        "core": core,
        "engine_binary_sha256": digest(binary),
        **runtime_hashes,
    }) + "\n", "utf-8")
    gate.verify_runtime(runtime_ctx, runtime)

    def mutation_fails(path: Path, expected_error: str) -> None:
        original = path.read_bytes()
        path.write_bytes(original + b"drift\n")
        try:
            gate.verify_runtime(runtime_ctx, runtime)
        except gate.GateError as exc:
            assert expected_error in str(exc), (expected_error, str(exc))
        else:
            raise AssertionError(f"runtime mutation passed: {path}")
        finally:
            path.write_bytes(original)

    mutation_fails(binary, "engine binary drifted")
    mutation_fails(framework, "engine app tree drifted")
    mutation_fails(harness_file, "QA harness drifted")
    mutation_fails(runtime_module_map, "QA harness drifted")
    mutation_fails(
        runtime / "closures/base_deutsch/red/mods/0000_kanto_ascendant/manifest.json",
        "mod tree drifted",
    )
    mutation_fails(
        runtime / "closures/base_deutsch/red/main.lua",
        "closure tree drifted",
    )
    mutation_fails(
        fixture_cell / "mods/negative_probe/manifest.json",
        "fixture-cell mod tree drifted",
    )
    mutation_fails(
        imported / "red/data/generated/pokemon.lua",
        "imported cache drifted",
    )

    framework_payload = framework.read_bytes()
    framework_mode = stat.S_IMODE(framework.stat().st_mode)
    framework.unlink()
    try:
        gate.verify_runtime(runtime_ctx, runtime)
    except gate.GateError as exc:
        assert "engine app tree drifted" in str(exc)
    else:
        raise AssertionError("runtime accepted a missing engine framework")
    finally:
        framework.write_bytes(framework_payload)
        framework.chmod(framework_mode)

    extra_framework = framework.parent / "unbound-framework-payload"
    extra_framework.write_bytes(b"unbound\n")
    try:
        gate.verify_runtime(runtime_ctx, runtime)
    except gate.GateError as exc:
        assert "engine app tree drifted" in str(exc)
    else:
        raise AssertionError("runtime accepted an extra engine framework file")
    finally:
        extra_framework.unlink()

    framework.chmod(framework_mode ^ stat.S_IXUSR)
    try:
        gate.verify_runtime(runtime_ctx, runtime)
    except gate.GateError as exc:
        assert "engine app tree drifted" in str(exc)
    else:
        raise AssertionError("runtime accepted engine framework mode drift")
    finally:
        framework.chmod(framework_mode)
    gate.verify_runtime(runtime_ctx, runtime)

    # L10 accepts only a complete canonical Cell -> Lane -> Run hash chain.
    # Keep this fixture deliberately small (one cell per real lane ID): the
    # evidence validator, not a mocked aggregate, creates every receipt.
    synthetic_lanes = []
    for lane_order, real_lane in enumerate(info["lanes"][:10]):
        cell = {
            "id": (
                "l09-reverse-modules"
                if lane_order == 9 else f"synthetic-evidence-{lane_order:02d}"
            ),
            "identity": f"ka-final-synthetic-evidence-{lane_order:02d}",
            "edition": "red",
            "closure": "base_deutsch",
            "driver": "tests/driver.lua",
            "timeout_seconds": 30,
            "env": {},
            "result": {
                "path": "driver_result.txt",
                "contains": ["status=PASS", f"lane={real_lane['lane_id']}"],
            },
            "images": {"exact_count": 1, "min_bytes": 8},
            "passes": [{
                "name": "driver",
                "driver": "tests/driver.lua",
                "env": {},
                "images": {"exact_count": 1, "min_bytes": 8},
            }],
        }
        if lane_order == 9:
            cell["lane_evidence"] = True
        synthetic_lanes.append({
            "order": lane_order,
            "lane_id": real_lane["lane_id"],
            "source_references": [],
            "cells": [cell],
            "user_gates": [],
            "feature_ids": [],
            "coverage": {},
        })

    aggregate_ctx = {
        **runtime_ctx,
        "plan_info": {"lanes": synthetic_lanes, "module_map": module_map},
    }
    evidence_seed = temp / "evidence-seed"
    evidence_seed.mkdir()
    evidence_store = gate.evidence_gate.EvidenceStore(
        evidence_seed,
        bindings=gate.evidence_bindings(aggregate_ctx),
        receipt_contract=gate.CONTRACT,
    )
    sealed_lanes = []
    artifact_files = {}
    for lane_order, lane in enumerate(synthetic_lanes):
        cell = lane["cells"][0]
        compatibility_claims = None
        if lane_order == 9:
            compatibility_claims = gate.retain_l09_compatibility_inputs(
                aggregate_ctx, evidence_seed, sealed_lanes,
            )
        artifact_root, manifest_relative, receipt_relative = (
            gate.cell_artifact_paths(evidence_seed, lane, cell)
        )
        output = evidence_seed / artifact_root
        output.mkdir(parents=True, exist_ok=True)
        result_payload = (
            "status=PASS\n"
            f"lane={lane['lane_id']}\n"
        ).encode("utf-8")
        result = output / "driver_result.txt"
        result.write_bytes(result_payload)
        process_log = output / "process.log"
        process_log.write_bytes(b"synthetic process PASS\n")
        pass_log = output / "pass_logs/000-driver.log"
        pass_log.parent.mkdir()
        pass_log.write_bytes(process_log.read_bytes())
        png = output / "visual.png"
        png.write_bytes(b"\x89PNG\r\n\x1a\n" + bytes([lane_order]) * 32)
        image_row = (
            "path\tsha256\tbytes\n"
            f"visual.png\t{digest(png)}\t{png.stat().st_size}\n"
        )
        pass_manifest = output / "driver_image_sha256.tsv"
        pass_manifest.write_text(image_row, "utf-8")
        image_manifest = output / "image_sha256.tsv"
        image_manifest.write_text(image_row, "utf-8")
        image_receipt = output / "image_receipt.json"
        image_receipt.write_text(json.dumps({
            "actual_count": 1,
            "exact_count": 1,
            "manifest_sha256": digest(image_manifest),
            "minimum_bytes": 8,
            "minimum_count": 0,
            "schema": "ka-package-image-receipt/v1",
        }, indent=2, sort_keys=True) + "\n", "utf-8")
        phase_env = gate.cell_base_environment(
            aggregate_ctx, runtime, evidence_seed, lane, cell,
        )
        phase_env["POKEPORT_DRIVER"] = str(
            runtime / "qa_harness" / cell["driver"]
        )
        pass_records = [{
            "driver": cell["driver"],
            "driver_sha256": digest(runtime / "qa_harness" / cell["driver"]),
            "effective_env_sha256": gate.normalized_environment_sha256(
                phase_env, runtime, evidence_seed,
            ),
            "image_manifest": pass_manifest.name,
            "image_manifest_sha256": digest(pass_manifest),
            "log_bytes": process_log.stat().st_size,
            "log_offset": 0,
            "log_path": pass_log.relative_to(output).as_posix(),
            "log_sha256": digest(process_log),
            "name": "driver",
            "returncode": 0,
            "timeout_seconds": cell["timeout_seconds"],
        }]
        claims = gate.cell_claims(
            cell, pass_records, result.name, digest(result), result.stat().st_size,
        )
        if compatibility_claims is not None:
            claims["compatibility_receipts"] = compatibility_claims
        cell_evidence = evidence_store.write_cell_evidence(
            lane_id=lane["lane_id"],
            lane_order=lane_order,
            cell_id=cell["id"],
            cell_order=0,
            cell_spec=cell,
            artifact_root=artifact_root,
            artifact_manifest=manifest_relative,
            receipt_path=receipt_relative,
            claims=claims,
        )
        lane_evidence = evidence_store.write_lane_evidence(
            lane_id=lane["lane_id"],
            lane_order=lane_order,
            lane_spec=lane,
            cells=[cell_evidence],
        )
        sealed_lanes.append(lane_evidence)
        if lane_order < 9:
            gate.lane_receipt(
                gate.compatibility_receipt_path(
                    evidence_seed, lane["lane_id"],
                ),
                lane["lane_id"], "PASS", aggregate_ctx,
                {
                    "cells": "1",
                    "lane_evidence_sha256": lane_evidence.receipt_sha256,
                },
            )
        artifact_files[cell["id"]] = {
            "root": artifact_root,
            "manifest": manifest_relative,
            "receipt": receipt_relative,
            "result": f"{artifact_root}/{result.name}",
            "log": f"{artifact_root}/{process_log.name}",
            "pass_log": f"{artifact_root}/{pass_log.relative_to(output).as_posix()}",
            "png": f"{artifact_root}/{png.name}",
            "pass_manifest": f"{artifact_root}/{pass_manifest.name}",
            "image_manifest": f"{artifact_root}/{image_manifest.name}",
            "image_receipt": f"{artifact_root}/{image_receipt.name}",
        }
    gate.remove_compatibility_views(
        aggregate_ctx, evidence_seed, sealed_lanes[:9],
    )
    evidence_store.write_run_seal(
        plan_spec=synthetic_lanes,
        lanes=sealed_lanes,
    )

    positive_evidence = temp / "evidence-positive"
    shutil.copytree(evidence_seed, positive_evidence)
    gate.aggregate(aggregate_ctx, runtime, positive_evidence)
    final_path = positive_evidence / "lane_receipts/L10_FINAL_SAME_HASH.json"
    final = json.loads(final_path.read_text("utf-8"))
    assert final == {
        "aggregate": "PASS",
        "doc_hold": "PASS",
        "engine_app_tree_sha256": runtime_hashes["engine_app_tree_sha256"],
        "package_gate_receipt_sha256": receipt_sha,
        "prior_lane_receipts": 10,
        "public_docs_published": False,
        "receipt_contract": gate.CONTRACT,
        "release_phase": "rc_candidate",
        "run_seal_sha256": digest(positive_evidence / "run_seal.json"),
        "schema": "ka-final-same-hash-aggregate/v2",
        "status": "PASS",
    }

    first_lane = synthetic_lanes[0]
    first_cell = first_lane["cells"][0]
    first_files = artifact_files[first_cell["id"]]
    l09_cell = synthetic_lanes[9]["cells"][0]
    l09_files = artifact_files[l09_cell["id"]]
    l09_compat = (
        f"{l09_files['root']}/compat_inputs/"
        f"{synthetic_lanes[0]['lane_id']}.receipt"
    )

    def canonical_json_mutation(path: Path, field: str, value: object) -> None:
        payload = json.loads(path.read_text("utf-8"))
        payload[field] = value
        path.write_bytes(gate.evidence_gate.canonical_json_bytes(payload))

    def evidence_mutation_fails(label: str, mutate, expected: str) -> None:
        evidence = temp / f"evidence-negative-{label}"
        shutil.copytree(evidence_seed, evidence)
        mutate(evidence)
        try:
            gate.aggregate(aggregate_ctx, runtime, evidence)
        except gate.GateError as exc:
            assert expected in str(exc), (label, expected, str(exc))
        else:
            raise AssertionError(f"L10 accepted mutated evidence: {label}")
        assert not (evidence / "lane_receipts/L10_FINAL_SAME_HASH.json").exists()

    evidence_mutation_fails(
        "missing-lane-receipt",
        lambda root: (root / f"lane_receipts/{first_lane['lane_id']}.json").unlink(),
        "lane receipt file is missing",
    )
    evidence_mutation_fails(
        "mutated-lane-receipt",
        lambda root: canonical_json_mutation(
            root / f"lane_receipts/{first_lane['lane_id']}.json",
            "status", "FAIL",
        ),
        "lane receipt field drifted",
    )
    evidence_mutation_fails(
        "extra-lane-receipt",
        lambda root: (root / "lane_receipts/unbound.json").write_text(
            "{}\n", "utf-8",
        ),
        "sealed evidence contains an extra file",
    )
    evidence_mutation_fails(
        "legacy-text-lane-receipt",
        lambda root: (root / f"lane_receipts/{first_lane['lane_id']}.receipt").write_text(
            "receipt_contract=BLITZ_PACKAGE_RECEIPT_V1\nstatus=PASS\n", "utf-8",
        ),
        "sealed evidence contains an extra file",
    )
    evidence_mutation_fails(
        "missing-cell-receipt",
        lambda root: (root / first_files["receipt"]).unlink(),
        "canonical evidence JSON is unreadable",
    )
    evidence_mutation_fails(
        "mutated-cell-receipt",
        lambda root: canonical_json_mutation(
            root / first_files["receipt"], "status", "FAIL",
        ),
        "cell receipt field drifted",
    )
    evidence_mutation_fails(
        "mutated-cell-result-claim",
        lambda root: canonical_json_mutation(
            root / first_files["receipt"], "claims", {
                **json.loads((root / first_files["receipt"]).read_text("utf-8"))["claims"],
                "result_sha256": "0" * 64,
            },
        ),
        "cell receipt field drifted: claims",
    )
    evidence_mutation_fails(
        "extra-cell-receipt",
        lambda root: (root / "cell_receipts/unbound.json").write_text(
            "{}\n", "utf-8",
        ),
        "sealed evidence contains an extra file",
    )
    evidence_mutation_fails(
        "missing-artifact-manifest",
        lambda root: (root / first_files["manifest"]).unlink(),
        "artifact manifest file is missing",
    )
    evidence_mutation_fails(
        "mutated-artifact-manifest",
        lambda root: (root / first_files["manifest"]).write_bytes(
            (root / first_files["manifest"]).read_bytes() + b"drift"
        ),
        "artifact manifest",
    )
    evidence_mutation_fails(
        "extra-artifact-manifest",
        lambda root: (root / "cell_manifests/unbound.tsv").write_text(
            "path\tsha256\tbytes\n", "utf-8",
        ),
        "sealed evidence contains an extra file",
    )
    evidence_mutation_fails(
        "missing-artifact-tree",
        lambda root: shutil.rmtree(root / first_files["root"]),
        "cell artifact output is missing/symlinked",
    )

    def append_drift(relative: str):
        def mutate(root: Path) -> None:
            path = root / relative
            path.write_bytes(path.read_bytes() + b"drift")
        return mutate

    for label, relative, expected in (
        ("mutated-result", first_files["result"], "artifact manifest does not match"),
        ("mutated-process-log", first_files["log"], "cell pass logs do not cover process.log"),
        ("mutated-pass-log", first_files["pass_log"], "cell pass log partition drifted"),
        ("mutated-png", first_files["png"], "image bytes drifted"),
        ("mutated-pass-image-manifest", first_files["pass_manifest"], "image manifest row is malformed"),
        ("mutated-image-manifest", first_files["image_manifest"], "image manifest row is malformed"),
        ("mutated-image-receipt", first_files["image_receipt"], "JSON unreadable"),
    ):
        evidence_mutation_fails(
            label, append_drift(relative), expected,
        )
    for label, relative, expected in (
        ("missing-result", first_files["result"], "cell result is missing/non-regular"),
        ("missing-process-log", first_files["log"], "cell process log is missing/non-regular"),
        ("missing-pass-log", first_files["pass_log"], "cell pass log is missing/non-regular"),
        ("missing-png", first_files["png"], "image is missing/non-regular"),
        ("missing-pass-image-manifest", first_files["pass_manifest"], "image manifest is unreadable"),
        ("missing-image-manifest", first_files["image_manifest"], "image manifest is unreadable"),
        ("missing-image-receipt", first_files["image_receipt"], "JSON unreadable"),
    ):
        evidence_mutation_fails(
            label, lambda root, relative=relative: (root / relative).unlink(),
            expected,
        )
    evidence_mutation_fails(
        "extra-artifact",
        lambda root: (root / first_files["root"] / "unbound.txt").write_text(
            "unbound\n", "utf-8",
        ),
        "artifact manifest does not match the complete artifact tree",
    )
    evidence_mutation_fails(
        "symlink-artifact",
        lambda root: (root / first_files["root"] / "unbound-link").symlink_to(
            "driver_result.txt",
        ),
        "artifact tree contains a symlink",
    )
    evidence_mutation_fails(
        "extra-png",
        lambda root: (root / first_files["root"] / "unbound.png").write_bytes(
            b"\x89PNG\r\n\x1a\nextra"
        ),
        "cell final image manifest is not exhaustive",
    )
    evidence_mutation_fails(
        "extra-cell-artifact-directory",
        lambda root: (
            (root / "cells/unbound").mkdir(),
            (root / "cells/unbound/result.txt").write_text("PASS\n", "utf-8"),
        ),
        "sealed evidence contains an extra directory",
    )
    evidence_mutation_fails(
        "missing-run-seal",
        lambda root: (root / "run_seal.json").unlink(),
        "run seal file is missing",
    )
    evidence_mutation_fails(
        "mutated-run-seal",
        lambda root: canonical_json_mutation(
            root / "run_seal.json", "status", "FAIL",
        ),
        "run seal field drifted",
    )
    evidence_mutation_fails(
        "extra-root",
        lambda root: (root / "unbound").mkdir(),
        "sealed evidence contains an extra directory",
    )

    def mutate_l09_compatibility_claim(root: Path) -> None:
        receipt_path = root / l09_files["receipt"]
        payload = json.loads(receipt_path.read_text("utf-8"))
        payload["claims"]["compatibility_receipts"]["count"] = 8
        receipt_path.write_bytes(
            gate.evidence_gate.canonical_json_bytes(payload)
        )

    evidence_mutation_fails(
        "missing-l09-compatibility-input",
        lambda root: (root / l09_compat).unlink(),
        "L09 retained compatibility evidence drifted",
    )
    evidence_mutation_fails(
        "mutated-l09-compatibility-input",
        append_drift(l09_compat),
        "L09 retained compatibility evidence drifted",
    )
    evidence_mutation_fails(
        "extra-l09-compatibility-input",
        lambda root: (
            root / l09_files["root"] / "compat_inputs/unbound.receipt"
        ).write_text("status=PASS\n", "utf-8"),
        "artifact manifest does not match the complete artifact tree",
    )
    evidence_mutation_fails(
        "mutated-l09-compatibility-claim",
        mutate_l09_compatibility_claim,
        "L09 compatibility receipt claims drifted",
    )

    # Aggregate mode rechecks the package-only runtime before trusting the
    # otherwise-valid evidence chain, including app payload topology and mode.
    def aggregate_runtime_mutation_fails(
        label: str, mutate, restore, expected: str = "engine app tree drifted",
    ) -> None:
        evidence = temp / f"evidence-runtime-negative-{label}"
        shutil.copytree(evidence_seed, evidence)
        mutate()
        try:
            gate.aggregate(aggregate_ctx, runtime, evidence)
        except gate.GateError as exc:
            assert expected in str(exc), (label, expected, str(exc))
        else:
            raise AssertionError(f"L10 accepted runtime mutation: {label}")
        finally:
            restore()
        assert not (evidence / "lane_receipts/L10_FINAL_SAME_HASH.json").exists()
        gate.verify_runtime(runtime_ctx, runtime)

    def restore_framework() -> None:
        framework.write_bytes(framework_payload)
        framework.chmod(framework_mode)

    aggregate_runtime_mutation_fails(
        "mutated-framework",
        lambda: framework.write_bytes(framework_payload + b"drift\n"),
        restore_framework,
    )
    aggregate_runtime_mutation_fails(
        "missing-framework",
        framework.unlink,
        restore_framework,
    )
    aggregate_runtime_mutation_fails(
        "extra-framework",
        lambda: extra_framework.write_bytes(b"unbound\n"),
        lambda: extra_framework.unlink(),
    )
    aggregate_runtime_mutation_fails(
        "framework-mode",
        lambda: framework.chmod(framework_mode ^ stat.S_IXUSR),
        lambda: framework.chmod(framework_mode),
    )

    # The superseded key=value receipt format can never form an aggregate,
    # even if all ten legacy rows claim PASS and use the current core hashes.
    legacy_evidence = temp / "evidence-legacy-only"
    for lane in synthetic_lanes:
        gate.lane_receipt(
            legacy_evidence / "lane_receipts" / f"{lane['lane_id']}.receipt",
            lane["lane_id"], "PASS", aggregate_ctx, {"cells": "1"},
        )
    try:
        gate.aggregate(aggregate_ctx, runtime, legacy_evidence)
    except gate.GateError as exc:
        assert "canonical evidence JSON is unreadable" in str(exc)
    else:
        raise AssertionError("L10 accepted synthetic legacy text receipts")
    assert not (legacy_evidence / "lane_receipts/L10_FINAL_SAME_HASH.json").exists()

print(
    "final same-hash orchestrator: schema/dry-run PASS; "
    "11 lanes, 192 cells, 44 users, 34 features, 0 explicit blockers, "
    "0 blocked matrix rows; no LÖVE started"
)
