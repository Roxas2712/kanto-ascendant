#!/usr/bin/env python3
"""Static/unit contract for the fail-closed post-F Oak Lab host runner.

This test never calls the runner's execute mode, never reads Run F's active
identity, never creates an Application Support identity, and never launches
LÖVE.  Temporary fixtures exercise only pure parsing/tree helpers.
"""

from __future__ import annotations

import binascii
import importlib.util
import json
from pathlib import Path
import struct
import subprocess
import sys
import tempfile
from types import SimpleNamespace
import zlib


ROOT = Path(__file__).resolve().parents[1]
RUNNER = ROOT / "tools/run_oaks_lab_runf_passable_follower_real_probe.py"
GO_WRITER = ROOT / "tools/write_oaks_lab_runf_formal_stop_go_token.py"
DRIVER = ROOT / "tests/oaks_lab_runf_passable_follower_real_probe.lua"
PLAN = (
    ROOT
    / "qa/blitz_real_save_forensic_20260812/package_candidate"
    / "final_same_hash_plan.json"
)
RECEIPT = (
    ROOT
    / "qa/blitz_real_save_forensic_20260812/package_candidate"
    / "final_same_hash_receipt.json"
)
ORCHESTRATOR = (
    ROOT
    / "qa/blitz_real_save_forensic_20260812/package_candidate"
    / "final_same_hash_orchestrator.py"
)

source = RUNNER.read_text(encoding="utf-8")
go_source = GO_WRITER.read_text(encoding="utf-8")

required = (
    'RUN_F_IDENTITY_NAME = "ka65-final-first-badge-red"',
    'PROBE_IDENTITY_NAME = "ka65-probe-oak-follower-passable-runf-20260813-01"',
    'RUN_F_FAILURE_RECEIPT = RUN_F_EVIDENCE / "failures/L01_BOOT_UPGRADE_RULES.json"',
    'RUN_F_ROUTE_LOG = (',
    '"cells/l01-first-badge-red/route.log"',
    'RUN_F_PASS_LOG = (',
    '"cells/l01-first-badge-red/pass_logs/000-driver.log"',
    '"/private/tmp/ka-run-f-formal-stop-go.ka650-rc28-20260813-f.json"',
    'GO_SCHEMA = "ka-run-f-formal-stop-go/v1"',
    'DRIVER_EXPECTED_SHA256 = (',
    '"ff2b215dd117860b5fcfe7d0fe3b101daef2d6c1a43c25d6de46d10f437881d8"',
    "STABILITY_SECONDS = 5",
    '"--execute-after-formal-stop"',
    '"defect": "PROCESS_TIMEOUT"',
    '"group_empty_verified": True',
    '"leader_reaped": True',
    '"identity_cache", "immutable_runtime"',
    '"run_f_exec_cell_finished": True',
    '"orchestrator_reaped": True',
    '"run_f_love_absent": True',
    '"atomic_promotion_attested": True',
    '"failure_receipt_sha256": failure["sha256"]',
    '"route_log_sha256": route["sha256"]',
    '"pass_log_sha256": pass_log["sha256"]',
    'set(token) != set(expected)',
    "require_run_f_process_quiescent()",
    'time.sleep(STABILITY_SECONDS)',
    'route_one != route_two',
    'pass_one != pass_two',
    'go_one != go_two',
    'identity_one["stability_sha256"] != identity_two["stability_sha256"]',
    'Run-F main save changed between stability samples',
    'Run-F backup save changed between stability samples',
    'part.endswith(".tmp")',
    'require_all_fresh()  # close the stability-window freshness race',
    'copy_tree_exclusive(RUN_F_IDENTITY, SNAPSHOT_IDENTITY, symlinks=False)',
    'copy_tree_exclusive(RUN_F_ENGINE, ISOLATED_ENGINE, symlinks=True)',
    'copy_tree_exclusive(RUN_F_CLOSURE, ISOLATED_CLOSURE, symlinks=False)',
    'copy_tree_exclusive(SNAPSHOT_IDENTITY, PROBE_IDENTITY, symlinks=False)',
    '"POKEPORT_IDENTITY": PROBE_IDENTITY_NAME',
    '"POKEPORT_VERSION": "red"',
    '"POKEPORT_DRIVER": str(ISOLATED_DRIVER)',
    '"KA_OAK_PROBE_OUTPUT_DIR": str(OUTPUT_DIR)',
    '"KA_OAK_PROBE_SOURCE_SAVE_SHA256": source_save_sha256',
    '"KA_OAK_PROBE_CLOSURE_TREE_SHA256": closure_tree_sha256',
    '"--game",',
    'start_new_session=True',
    'os.killpg(process.pid, signal.SIGKILL)',
    'result = parse_driver_result(OUTPUT_DIR / "driver_result.txt")',
    'OUTPUT_DIR / "01_before_right_input.png"',
    'OUTPUT_DIR / "02_after_right_input.png"',
    'tree_digest(cache_before, False) != tree_digest(cache_after, False)',
    'tree_digest(saves_before, False) != tree_digest(saves_after, False)',
    'source_postlaunch["stability_sha256"] != stable["stability_sha256"]',
    'active_run_f_identity_write_operations=0',
)
for needle in required:
    assert needle in source, f"host runner lost safety/evidence contract: {needle}"

# Order is a safety property: formal stop and two stable samples precede the
# first mutation; source is rechecked around copy/launch and after evidence.
execute = source.index("def execute_probe()")
fresh_one = source.index("require_all_fresh()", execute)
stable = source.index("stable = stable_run_f_sample()", fresh_one)
fresh_two = source.index("require_all_fresh()", stable)
create_root = source.index("PROBE_ROOT.mkdir", fresh_two)
snapshot = source.index("copy_tree_exclusive(RUN_F_IDENTITY", create_root)
source_after_copy = source.index('identity_sample("after-snapshot-copy")', snapshot)
runtime_copy = source.index("copy_tree_exclusive(RUN_F_ENGINE", source_after_copy)
target_copy = source.index("copy_tree_exclusive(SNAPSHOT_IDENTITY", runtime_copy)
prelaunch = source.index('identity_sample("immediately-before-launch")', target_copy)
launch = source.index("run_managed_love(env)", prelaunch)
result = source.index("parse_driver_result", launch)
source_after = source.index('identity_sample("after-probe-launch")', result)
passed = source.index("host.passed(", source_after)
assert (
    fresh_one
    < stable
    < fresh_two
    < create_root
    < snapshot
    < source_after_copy
    < runtime_copy
    < target_copy
    < prelaunch
    < launch
    < result
    < source_after
    < passed
)

# No destructive cleanup or source retargeting is available.  os.replace is
# allowed only for the receipt inside the already-exclusive disposable root.
for banned in (
    "shutil.rmtree",
    "os.remove",
    ".unlink(",
    ".rename(",
    "os.rename",
    "chmod(",
    "chown(",
    "shell=True",
):
    assert banned not in source, f"host runner gained destructive/broad primitive: {banned}"
assert "require_authorized_write(path)" in source
assert "active Run-F identity can never be a write target" in source

# Neither the host runner nor the probe is allowed to become part of frozen
# final-same-hash plan/receipt/orchestrator authority.
for authority in (PLAN, RECEIPT, ORCHESTRATOR):
    authority_text = authority.read_text(encoding="utf-8")
    assert RUNNER.name not in authority_text
    assert GO_WRITER.name not in authority_text
    assert DRIVER.name not in authority_text

go_required = (
    'Token: {probe.RUN_F_GO_TOKEN}',
    '"--write-after-parent-wait"',
    '"--attest-run-f-exec-cell-finished"',
    '"--attest-orchestrator-reaped"',
    '"--attest-run-f-love-absent"',
    'probe.require_run_f_process_quiescent()',
    'time.sleep(probe.STABILITY_SECONDS)',
    'os.O_WRONLY | os.O_CREAT | os.O_EXCL',
    'os.link(stage, target, follow_symlinks=False)',
    'probe.validate_parent_go_token(',
)
for needle in go_required:
    assert needle in go_source, f"GO writer lost exclusive/formal-stop contract: {needle}"
for banned in (
    "shutil.rmtree",
    "os.replace",
    "os.rename",
    "shell=True",
    "subprocess.Popen",
):
    assert banned not in go_source, f"GO writer gained forbidden primitive: {banned}"
go_sample = go_source.index("probe.validate_failure_receipt()")
go_wait = go_source.index("time.sleep(probe.STABILITY_SECONDS)", go_sample)
go_sample_two = go_source.index("probe.validate_failure_receipt()", go_wait)
go_publish = go_source.index("exclusive_atomic_publish(value)", go_sample_two)
assert go_sample < go_wait < go_sample_two < go_publish

spec = importlib.util.spec_from_file_location("oak_host_runner", RUNNER)
assert spec is not None and spec.loader is not None
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)

# Central write allowlist is semantic, not merely documentary: every active F
# source/evidence/runtime path is rejected, while the two disposable roots are
# the only accepted namespaces.  This calls no write primitive.
for forbidden in (
    runner.RUN_F_IDENTITY,
    runner.RUN_F_IDENTITY / "saves/red/slot65firstbadge_red.lua",
    runner.RUN_F_CONVENTIONAL_IDENTITY,
    runner.RUN_F_RUNTIME,
    runner.RUN_F_EVIDENCE,
    runner.RUN_F_GO_TOKEN,
):
    try:
        runner.require_authorized_write(forbidden)
    except runner.ProbeError as exc:
        assert "outside disposable probe surfaces" in str(exc) or "never be" in str(exc)
    else:
        raise AssertionError(f"write allowlist accepted active/non-disposable path: {forbidden}")
for allowed in (
    runner.PROBE_ROOT,
    runner.PROBE_ROOT / "output/result.txt",
    runner.PROBE_IDENTITY,
    runner.PROBE_IDENTITY / "options.lua",
):
    runner.require_authorized_write(allowed)

# Process-quiescence parser recognizes only actual F writers, not a harmless
# read-only log monitor.  The real process table is never queried by this test.
real_subprocess_run = runner.subprocess.run
try:
    runner.subprocess.run = lambda *args, **kwargs: SimpleNamespace(
        stdout=(
            f"101 1 101 {runner.RUN_F_ENGINE}/Contents/MacOS/love "
            f"--game {runner.RUN_F_CLOSURE}\n"
            f"102 1 102 python3 final_same_hash_orchestrator.py "
            f"--runtime {runner.RUN_F_RUNTIME} --evidence {runner.RUN_F_EVIDENCE}\n"
            f"103 1 103 tail -f {runner.RUN_F_ROUTE_LOG}\n"
        )
    )
    parsed_processes = runner.related_processes()
    assert [row["kind"] for row in parsed_processes] == ["love", "orchestrator"]
finally:
    runner.subprocess.run = real_subprocess_run

# Default/--plan is demonstrably inert: it prints the formal-stop checklist
# without evaluating active-path preconditions or creating any target.
for arguments in ([], ["--plan"]):
    completed = subprocess.run(
        [sys.executable, "-B", str(RUNNER), *arguments],
        check=True,
        capture_output=True,
        text=True,
    )
    assert "Post-F Oak-Lab-Probe" in completed.stdout
    assert "--execute-after-formal-stop" in completed.stdout
for arguments in ([], ["--plan"]):
    completed = subprocess.run(
        [sys.executable, "-B", str(GO_WRITER), *arguments],
        check=True,
        capture_output=True,
        text=True,
    )
    assert "Run-F formal-stop GO token" in completed.stdout
    assert "--write-after-parent-wait" in completed.stdout


def png_chunk(kind: bytes, payload: bytes) -> bytes:
    return (
        struct.pack(">I", len(payload))
        + kind
        + payload
        + struct.pack(">I", binascii.crc32(kind + payload) & 0xFFFFFFFF)
    )


with tempfile.TemporaryDirectory(prefix="oak-host-contract-") as temporary:
    temp = Path(temporary)
    tree = temp / "tree"
    tree.mkdir()
    (tree / "a.txt").write_bytes(b"stable")
    rows = runner.scan_tree(
        tree,
        "fixture",
        allow_safe_symlinks=False,
        reject_tmp=True,
    )
    assert runner.tree_digest(rows, False) == runner.tree_digest(rows, False)
    (tree / "a.txt").write_bytes(b"changed")
    changed = runner.scan_tree(
        tree,
        "fixture changed",
        allow_safe_symlinks=False,
        reject_tmp=True,
    )
    assert runner.content_diff(rows, changed) == ["a.txt"]

    staged = tree / "save.lua.tmp"
    staged.write_bytes(b"forbidden")
    try:
        runner.scan_tree(
            tree,
            "tmp fixture",
            allow_safe_symlinks=False,
            reject_tmp=True,
        )
    except runner.ProbeError as exc:
        assert "forbidden staged .tmp" in str(exc)
    else:
        raise AssertionError("host runner accepted staged .tmp save state")
    staged.unlink()

    symlink = tree / "link"
    symlink.symlink_to("a.txt")
    try:
        runner.scan_tree(
            tree,
            "symlink fixture",
            allow_safe_symlinks=False,
            reject_tmp=True,
        )
    except runner.ProbeError as exc:
        assert "forbidden symlink" in str(exc)
    else:
        raise AssertionError("host runner accepted a symlinked active identity")

    png = temp / "valid.png"
    raw = b"\x00\x00\x00\xff"
    png.write_bytes(
        b"\x89PNG\r\n\x1a\n"
        + png_chunk(b"IHDR", struct.pack(">IIBBBBB", 1, 1, 8, 6, 0, 0, 0))
        + png_chunk(b"tEXt", b"fixture\x00" + b"x" * 1024)
        + png_chunk(b"IDAT", zlib.compress(raw))
        + png_chunk(b"IEND", b"")
    )
    png_row = runner.validate_png(png, "fixture PNG")
    assert png_row["width"] == 1 and png_row["height"] == 1

    result = temp / "driver_result.txt"
    expected = {
        "schema": runner.DRIVER_SCHEMA,
        "status": "PASS",
        "fail": "0",
        "phase": "complete",
        "expected_identity": runner.PROBE_IDENTITY_NAME,
        "env_identity": runner.PROBE_IDENTITY_NAME,
        "love_identity": runner.PROBE_IDENTITY_NAME,
        "source_save_sha256": "a" * 64,
        "closure_tree_sha256": "b" * 64,
        "edition": "red",
        "map": "OAKS_LAB",
        "before_player": "6,2",
        "right_entity_count": "1",
        "right_entity_pikachu_follower": "1",
        "right_entity_passable": "1",
        "right_entity_ambient": "0",
        "collision_occupied_nil": "1",
        "right_input_via_live_queue": "1",
        "after_player": "7,2",
        "moved_onto_7_2": "1",
        "before_png": "01_before_right_input.png",
        "after_png": "02_after_right_input.png",
    }
    result.write_text(
        "\n".join(f"{key}={value}" for key, value in expected.items()) + "\n",
        encoding="utf-8",
    )
    assert runner.parse_driver_result(result)["status"] == "PASS"

    # GO parser requires an exact field set and SHA binding for all three
    # frozen F artifacts.  Patch only its token path to a temporary fixture.
    failure_file = temp / "failure.json"
    route_file = temp / "route.log"
    pass_file = temp / "pass.log"
    failure_file.write_text("failure\n", encoding="utf-8")
    route_file.write_text("route\n", encoding="utf-8")
    pass_file.write_text("pass\n", encoding="utf-8")
    failure_fp = runner.file_fingerprint(failure_file, "fixture failure")
    route_fp = runner.file_fingerprint(route_file, "fixture route")
    pass_fp = runner.file_fingerprint(pass_file, "fixture pass")
    token_path = temp / "formal-stop-go.json"
    token = {
        "schema": runner.GO_SCHEMA,
        "status": "GO",
        "run_id": "ka650-rc28-20260813-f",
        "runtime": str(runner.RUN_F_RUNTIME),
        "evidence": str(runner.RUN_F_EVIDENCE),
        "active_identity": runner.RUN_F_IDENTITY_NAME,
        "failure_receipt_relative": "failures/L01_BOOT_UPGRADE_RULES.json",
        "failure_receipt_sha256": failure_fp["sha256"],
        "route_log_relative": "cells/l01-first-badge-red/route.log",
        "route_log_sha256": route_fp["sha256"],
        "pass_log_relative": "cells/l01-first-badge-red/pass_logs/000-driver.log",
        "pass_log_sha256": pass_fp["sha256"],
        "run_f_exec_cell_finished": True,
        "orchestrator_reaped": True,
        "run_f_love_absent": True,
        "atomic_promotion_attested": True,
    }
    token_path.write_text(
        json.dumps(token, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    real_token_path = runner.RUN_F_GO_TOKEN
    try:
        runner.RUN_F_GO_TOKEN = token_path
        parsed_token, _ = runner.validate_parent_go_token(
            failure_fp, route_fp, pass_fp
        )
        assert parsed_token == token
        bad_token = dict(token)
        bad_token["route_log_sha256"] = "0" * 64
        token_path.write_text(
            json.dumps(bad_token, indent=2, sort_keys=True) + "\n",
            encoding="utf-8",
        )
        try:
            runner.validate_parent_go_token(failure_fp, route_fp, pass_fp)
        except runner.ProbeError as exc:
            assert "wrong route_log_sha256" in str(exc)
        else:
            raise AssertionError("GO parser accepted a mismatched route.log SHA")
    finally:
        runner.RUN_F_GO_TOKEN = real_token_path

print(
    "oak lab Run-F host-runner contract PASS: formal timeout + process/route "
    "quiescence; two stable save samples; no .tmp; exclusive isolated copies; "
    "live LÖVE; result/PNG/cache/source postchecks; active F identity write count 0"
)
