#!/usr/bin/env python3
"""Parent-only atomic GO token for the post-Run-F Oak Lab probe.

The coordinator invokes the write mode only after its yielded Run-F exec cell
has returned and the outer orchestrator has been reaped.  This tool does not
launch LÖVE, copy a save, or touch either Application Support identity.  It
only binds the already-formal failure receipt and two stable log samples into
one exclusive /private/tmp token consumed by the separate host runner.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import time

import run_oaks_lab_runf_passable_follower_real_probe as probe


TOKEN_PLAN = f"""Run-F formal-stop GO token (parent/coordinator only)

Do not invoke write mode until the yielded Run-F exec cell has returned.
The command refuses an existing token or staging sibling and never replaces it.

Token: {probe.RUN_F_GO_TOKEN}

After the parent has observed formal session end, invoke exactly:
  python3 -B tools/{os.path.basename(__file__)} \\
    --write-after-parent-wait \\
    --attest-run-f-exec-cell-finished \\
    --attest-orchestrator-reaped \\
    --attest-run-f-love-absent
"""


def payload_for(
    failure: dict[str, object],
    route: dict[str, object],
    pass_log: dict[str, object],
) -> dict[str, object]:
    return {
        "schema": probe.GO_SCHEMA,
        "status": "GO",
        "run_id": "ka650-rc28-20260813-f",
        "runtime": str(probe.RUN_F_RUNTIME),
        "evidence": str(probe.RUN_F_EVIDENCE),
        "active_identity": probe.RUN_F_IDENTITY_NAME,
        "failure_receipt_relative": "failures/L01_BOOT_UPGRADE_RULES.json",
        "failure_receipt_sha256": failure["sha256"],
        "route_log_relative": "cells/l01-first-badge-red/route.log",
        "route_log_sha256": route["sha256"],
        "pass_log_relative": "cells/l01-first-badge-red/pass_logs/000-driver.log",
        "pass_log_sha256": pass_log["sha256"],
        "run_f_exec_cell_finished": True,
        "orchestrator_reaped": True,
        "run_f_love_absent": True,
        "atomic_promotion_attested": True,
    }


def write_all(descriptor: int, payload: bytes) -> None:
    offset = 0
    while offset < len(payload):
        written = os.write(descriptor, payload[offset:])
        if written <= 0:
            probe.fail("GO token staging write made no progress")
        offset += written


def exclusive_atomic_publish(value: dict[str, object]) -> None:
    target = probe.RUN_F_GO_TOKEN
    stage = target.with_name(f".{target.name}.new")
    probe.require_absent(target, "parent formal-stop GO token")
    probe.require_absent(stage, "parent formal-stop GO staging path")
    payload = (
        json.dumps(value, ensure_ascii=False, indent=2, sort_keys=True) + "\n"
    ).encode("utf-8")
    descriptor = os.open(stage, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    try:
        write_all(descriptor, payload)
        os.fsync(descriptor)
    finally:
        os.close(descriptor)
    try:
        # A hard-link publish on the same /private/tmp filesystem is atomic
        # and, unlike rename/replace, fails if the final token already exists.
        os.link(stage, target, follow_symlinks=False)
    except OSError as exc:
        probe.fail(f"exclusive GO token publish failed: {exc.__class__.__name__}: {exc}")
    os.unlink(stage)
    if hasattr(os, "O_DIRECTORY"):
        directory = os.open(target.parent, os.O_RDONLY | os.O_DIRECTORY)
        try:
            os.fsync(directory)
        finally:
            os.close(directory)


def write_after_parent_wait() -> dict[str, object]:
    probe.require_absent(probe.RUN_F_GO_TOKEN, "parent formal-stop GO token")
    probe.require_run_f_process_quiescent()
    _, failure_one = probe.validate_failure_receipt()
    route_one = probe.file_fingerprint(probe.RUN_F_ROUTE_LOG, "route.log GO sample one")
    pass_one = probe.file_fingerprint(probe.RUN_F_PASS_LOG, "pass log GO sample one")
    time.sleep(probe.STABILITY_SECONDS)
    probe.require_run_f_process_quiescent()
    _, failure_two = probe.validate_failure_receipt()
    route_two = probe.file_fingerprint(probe.RUN_F_ROUTE_LOG, "route.log GO sample two")
    pass_two = probe.file_fingerprint(probe.RUN_F_PASS_LOG, "pass log GO sample two")
    if failure_one != failure_two:
        probe.fail("formal failure receipt changed during parent GO sampling")
    if route_one != route_two:
        probe.fail("route.log changed during parent GO sampling")
    if pass_one != pass_two:
        probe.fail("pass log changed during parent GO sampling")
    value = payload_for(failure_two, route_two, pass_two)
    exclusive_atomic_publish(value)
    parsed, fingerprint = probe.validate_parent_go_token(
        failure_two, route_two, pass_two
    )
    if parsed != value:
        probe.fail("published parent GO token changed during verification")
    return fingerprint


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--plan", action="store_true")
    parser.add_argument("--write-after-parent-wait", action="store_true")
    parser.add_argument("--attest-run-f-exec-cell-finished", action="store_true")
    parser.add_argument("--attest-orchestrator-reaped", action="store_true")
    parser.add_argument("--attest-run-f-love-absent", action="store_true")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(sys.argv[1:] if argv is None else argv)
    attestations = (
        args.attest_run_f_exec_cell_finished,
        args.attest_orchestrator_reaped,
        args.attest_run_f_love_absent,
    )
    if not args.write_after_parent_wait:
        if any(attestations):
            print("attestations require --write-after-parent-wait", file=sys.stderr)
            return 2
        print(TOKEN_PLAN)
        return 0
    if args.plan or not all(attestations):
        print(
            "write mode requires all three explicit post-parent-wait attestations",
            file=sys.stderr,
        )
        return 2
    try:
        fingerprint = write_after_parent_wait()
    except Exception as exc:
        print(f"RUN-F FORMAL-STOP GO REFUSED: {exc.__class__.__name__}: {exc}", file=sys.stderr)
        return 1
    print(
        "RUN-F FORMAL-STOP GO WRITTEN: "
        f"path={probe.RUN_F_GO_TOKEN} sha256={fingerprint['sha256']}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
