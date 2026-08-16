#!/usr/bin/env python3
"""Negative contract for timeout containment and forensic evidence."""

from __future__ import annotations

import contextlib
import importlib.util
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time


ROOT = Path(__file__).resolve().parents[1]
ORCHESTRATOR = (
    ROOT
    / "qa/blitz_real_save_forensic_20260812/package_candidate"
    / "final_same_hash_orchestrator.py"
)

spec = importlib.util.spec_from_file_location(
    "final_same_hash_timeout_forensics_orchestrator", ORCHESTRATOR,
)
assert spec and spec.loader
gate = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gate)


with tempfile.TemporaryDirectory(
    prefix="ka-final-timeout-forensics.", dir="/private/tmp",
) as temp_text:
    temp = Path(temp_text)

    # A real parent creates a real descendant.  The helper must isolate their
    # session, kill the complete group, reap its direct child, and return a
    # deterministic typed timeout instead of subprocess.TimeoutExpired.
    process_log = temp / "process-group.log"
    program = "\n".join((
        "import os, subprocess, sys, time",
        "escape = 'import os, signal, time; signal.signal(signal.SIGTERM, lambda *_: os.setsid()); time.sleep(60)'",
        "child = subprocess.Popen([sys.executable, '-c', escape])",
        "print(f'{os.getpid()} {child.pid}', flush=True)",
        "time.sleep(60)",
    ))
    with process_log.open("xb") as stream:
        try:
            gate.run_managed_process(
                [sys.executable, "-B", "-c", program],
                env=dict(os.environ), stdout=stream, cwd=temp,
                timeout_seconds=1,
            )
        except gate.ProcessGroupTimeout as exc:
            assert exc.timeout_seconds == 1
            assert exc.termination == {
                "detached_descendants_attested": False,
                "group_empty_verified": True,
                "leader_reaped": True,
                "process_group": "isolated_session",
                "signals": ["SIGKILL"],
            }
        else:
            raise AssertionError("managed parent/descendant did not time out")
    leader_pid, descendant_pid = map(
        int, process_log.read_text("utf-8").strip().split(),
    )
    deadline = time.monotonic() + 5
    while True:
        try:
            os.killpg(leader_pid, 0)
        except ProcessLookupError:
            break
        if time.monotonic() >= deadline:
            raise AssertionError(
                f"timed-out process group survived: {leader_pid}/{descendant_pid}"
            )
        time.sleep(0.05)

    # Every final integrity check runs even if the first one fails.
    calls: list[str] = []

    def broken(label: str):
        def check() -> None:
            calls.append(label)
            raise gate.GateError(label)
        return check

    integrity, errors = gate.final_integrity_results([
        ("identity_cache", broken("identity_cache")),
        ("immutable_runtime", broken("immutable_runtime")),
    ])
    assert calls == ["identity_cache", "immutable_runtime"]
    assert len(errors) == 2
    assert integrity == {
        "identity_cache": {"failure_class": "GateError", "status": "FAIL"},
        "immutable_runtime": {"failure_class": "GateError", "status": "FAIL"},
    }

    output = temp / "evidence/cells/cell-timeout"
    pass_log = output / "pass_logs/000-driver.log"
    pass_log.parent.mkdir(parents=True)
    pass_log.write_bytes(b"partial log bytes\n")
    partial_png = output / "partial.png"
    partial_png.write_bytes(b"\x89PNG\r\n\x1a\npartial")
    core = {
        "authority_package_sha256": "1" * 64,
        "engine_payload_sha256": "2" * 64,
        "orchestrator_sha256": "3" * 64,
    }
    ctx = {
        "core": core,
        "receipt_sha256": "4" * 64,
        "runtime_hashes": {
            "engine_app_tree_sha256": "5" * 64,
            "imported_tree_sha256": "6" * 64,
        },
    }
    lane = {"lane_id": "L00_TEST", "order": 0}
    cell = {
        "id": "cell-timeout", "edition": "red", "identity": "identity-test",
        "closure": "base_deutsch", "driver": "tests/driver.lua",
    }
    pass_row = {"name": "driver", "driver": "tests/driver.lua"}
    termination = {
        "detached_descendants_attested": False,
        "group_empty_verified": True,
        "leader_reaped": True,
        "process_group": "isolated_session",
        "signals": ["SIGKILL"],
    }
    timeout = gate.ProcessGroupTimeout(17, termination)
    failure = gate.timeout_failure_receipt(
        ctx, lane, cell, 0, 2, pass_row, 3, timeout,
        output, pass_log, {"identity_cache": {"status": "PASS"}},
    )
    assert failure["schema"] == "ka-final-lane-failure/v2"
    assert failure["defect"] == "PROCESS_TIMEOUT"
    assert failure["lane_id"] == "L00_TEST" and failure["lane_order"] == 0
    assert failure["cell_id"] == "cell-timeout" and failure["cell_order"] == 2
    assert failure["pass_name"] == "driver" and failure["pass_index"] == 3
    assert failure["timeout_seconds"] == 17
    assert failure["bindings"] == gate.evidence_bindings(ctx)
    assert failure["process_group_termination"] == termination
    assert failure["partial_log"] == {
        "bytes": len(b"partial log bytes\n"),
        "path": "pass_logs/000-driver.log",
        "sha256": gate.hashlib.sha256(b"partial log bytes\n").hexdigest(),
    }
    partial_rows = {row["path"]: row for row in failure["partial_artifacts"]}
    assert set(partial_rows) == {"partial.png", "pass_logs/000-driver.log"}
    assert all(len(row["sha256"]) == 64 for row in partial_rows.values())
    assert failure == gate.timeout_failure_receipt(
        ctx, lane, cell, 0, 2, pass_row, 3, timeout,
        output, pass_log, {"identity_cache": {"status": "PASS"}},
    )
    encoded = gate.evidence_gate.canonical_json_bytes(failure)
    assert b"/Users/" not in encoded and b"/private/tmp/" not in encoded

    # run_all persists exactly that frozen failure record and rethrows a
    # GateError caught by main as rc2, never as a traceback-producing timeout.
    evidence = temp / "evidence-run"
    run_ctx = {
        **ctx,
        "plan_info": {"lanes": [{"lane_id": "L00_TEST", "cells": [cell]}]},
    }
    original_run_cell = gate.run_cell
    gate.run_cell = lambda *args, **kwargs: (_ for _ in ()).throw(
        gate.PassTimeoutError(failure)
    )
    try:
        try:
            gate.run_all(run_ctx, temp / "runtime", evidence)
        except gate.PassTimeoutError as exc:
            assert exc.failure_receipt == failure
        else:
            raise AssertionError("run_all swallowed the typed timeout")
    finally:
        gate.run_cell = original_run_cell
    stored = evidence / "failures/L00_TEST.json"
    assert stored.is_file()
    assert json.loads(stored.read_text("utf-8")) == failure

    original_read_json = gate.read_json
    original_validate_plan = gate.validate_plan
    original_validate_receipt = gate.validate_receipt
    original_safe_runtime = gate.safe_runtime
    original_verify_runtime = gate.verify_runtime
    original_safe_evidence = gate.safe_evidence
    original_run_all = gate.run_all
    gate.read_json = lambda path: {}
    gate.validate_plan = lambda value: {"blocked": []}
    gate.validate_receipt = lambda receipt, info, require_ready: run_ctx
    gate.safe_runtime = lambda value: temp / "runtime"
    gate.verify_runtime = lambda ctx, runtime: None
    gate.safe_evidence = lambda value: temp / "main-evidence"
    gate.run_all = lambda ctx, runtime, evidence: (_ for _ in ()).throw(
        gate.PassTimeoutError(failure)
    )
    stderr = io.StringIO()
    try:
        with contextlib.redirect_stderr(stderr):
            returncode = gate.main([
                "run", "--runtime", str(temp / "runtime"),
                "--evidence", str(temp / "main-evidence"),
            ])
    finally:
        gate.read_json = original_read_json
        gate.validate_plan = original_validate_plan
        gate.validate_receipt = original_validate_receipt
        gate.safe_runtime = original_safe_runtime
        gate.verify_runtime = original_verify_runtime
        gate.safe_evidence = original_safe_evidence
        gate.run_all = original_run_all
    assert returncode == 2
    assert stderr.getvalue().startswith("FAIL CLOSED: process timed out:")
    assert "Traceback" not in stderr.getvalue()


print("PASS timeout process-group containment and forensic failure receipt")
