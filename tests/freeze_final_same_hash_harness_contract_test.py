#!/usr/bin/env python3
"""Fail-closed contract for external route-runner harness refreshes."""

import importlib.util
import json
import os
from pathlib import Path
import tempfile


ROOT = Path(__file__).resolve().parents[1]
HELPER = ROOT / "tools/freeze_final_same_hash_harness.py"

spec = importlib.util.spec_from_file_location("freeze_harness", HELPER)
module = importlib.util.module_from_spec(spec)
assert spec.loader is not None
spec.loader.exec_module(module)

plan = module.read_json_unique(module.PLAN)
paths = module.plan_paths(plan)
assert module.EXTERNAL_ROUTE_RUNNER in paths
assert module.sha256(module.EXPECTED_EXTERNAL_ROUTE) == (
    module.EXPECTED_EXTERNAL_ROUTE_SHA256
)

for invalid, text in (
    (None, "refusing stale snapshot reuse"),
    ("tests/drivers/route.lua", "absolute path"),
):
    try:
        module.harness_sources(paths, invalid)
    except SystemExit as exc:
        assert text in str(exc)
    else:
        raise AssertionError(f"invalid external runner accepted: {invalid}")

with tempfile.TemporaryDirectory(dir="/private/tmp") as temp:
    temp_root = Path(temp)
    fake = temp_root / "route.lua"
    fake.write_text("return function() end\n", "utf-8")
    try:
        module.harness_sources(paths, str(fake))
    except SystemExit as exc:
        assert "exact reviewed engine-worktree path" in str(exc)
    else:
        raise AssertionError("arbitrary absolute route runner was accepted")

    old_snapshot = module.SNAPSHOT
    try:
        snapshot = temp_root / "snapshot"
        snapshot.mkdir()
        module.SNAPSHOT = snapshot
        outside = temp_root / "outside.txt"
        outside.write_text("outside remains unchanged\n", "utf-8")
        linked = snapshot / "linked.lua"
        linked.symlink_to(outside)
        try:
            module.require_safe_destination(linked, "linked destination")
        except SystemExit as exc:
            assert "linked or not a regular file" in str(exc)
        else:
            raise AssertionError("symlink snapshot destination was accepted")
        assert outside.read_text("utf-8") == "outside remains unchanged\n"

        original = snapshot / "original.lua"
        hardlink = snapshot / "hardlink.lua"
        original.write_text("payload\n", "utf-8")
        os.link(original, hardlink)
        try:
            module.require_safe_destination(hardlink, "hardlink destination")
        except SystemExit as exc:
            assert "hardlinked" in str(exc)
        else:
            raise AssertionError("hardlinked snapshot destination was accepted")
    finally:
        module.SNAPSHOT = old_snapshot

for receipt, expected in (
    ({"status": "ready", "harness_tree_sha256": ""}, "explicitly pending"),
    ({"status": "pending", "harness_tree_sha256": "a" * 64}, "must clear"),
):
    try:
        module.validate_pending_receipt(receipt)
    except SystemExit as exc:
        assert expected in str(exc)
    else:
        raise AssertionError("unsafe receipt state was accepted")

# The real ready checkpoint must stop before proposal application and leave all
# four mutable surfaces byte-identical.  This is a no-write invocation.
critical = (
    module.MODULE_MAP_SNAPSHOT,
    module.PLAN,
    module.SNAPSHOT / module.EXTERNAL_ROUTE_RUNNER,
    module.RECEIPT,
)
before = {path: module.sha256(path) for path in critical}
try:
    module.main([
        "--external-route-runner", str(module.EXPECTED_EXTERNAL_ROUTE),
    ])
except SystemExit as exc:
    assert "explicitly pending" in str(exc)
else:
    raise AssertionError("ready receipt allowed a freeze mutation")
assert before == {path: module.sha256(path) for path in critical}

# A valid pending proposal guards every authority input consumed by the staged
# plan/receipt validators.  The receipt clone is disposable; no frozen byte is
# changed by proposal construction.
with tempfile.TemporaryDirectory(dir="/private/tmp") as temp:
    pending_path = Path(temp) / "pending-receipt.json"
    pending = module.read_json_unique(module.RECEIPT)
    pending["status"] = "pending"
    pending["harness_tree_sha256"] = ""
    pending_path.write_text(
        json.dumps(pending, indent=2, ensure_ascii=False) + "\n", "utf-8"
    )
    old_receipt = module.RECEIPT
    try:
        module.RECEIPT = pending_path
        proposal = module.build_proposal(str(module.EXPECTED_EXTERNAL_ROUTE))
    finally:
        module.RECEIPT = old_receipt
    assert {
        module.LANE_AUTHORITY,
        module.USER_MATRIX,
        module.FEATURE_MATRIX,
    }.issubset(proposal["read_guards"])
assert before == {path: module.sha256(path) for path in critical}

# A missing late provenance input is rejected before any map/plan/snapshot or
# receipt byte changes.  Use an isolated pending receipt input; the immutable
# frozen destinations remain the real checkpoint and are only hashed here.
with tempfile.TemporaryDirectory(dir="/private/tmp") as temp:
    temp_root = Path(temp)
    pending_path = temp_root / "pending-receipt.json"
    pending = module.read_json_unique(module.RECEIPT)
    pending["status"] = "pending"
    pending["harness_tree_sha256"] = ""
    pending_path.write_text(
        json.dumps(pending, indent=2, ensure_ascii=False) + "\n", "utf-8"
    )
    old_receipt = module.RECEIPT
    old_import_receipt = module.IMPORT_RECEIPT
    try:
        module.RECEIPT = pending_path
        module.IMPORT_RECEIPT = temp_root / "missing-import-provenance.json"
        try:
            module.build_proposal(str(module.EXPECTED_EXTERNAL_ROUTE))
        except SystemExit as exc:
            assert "import provenance receipt missing/unresolvable" in str(exc)
        else:
            raise AssertionError("missing late import provenance was accepted")
    finally:
        module.RECEIPT = old_receipt
        module.IMPORT_RECEIPT = old_import_receipt
assert before == {path: module.sha256(path) for path in critical}

# Authority drift after preflight is rejected before the first proposed write.
# Both the guarded input and destination are disposable, so this also proves
# zero-write behavior without mutating the real frozen authority or snapshot.
with tempfile.TemporaryDirectory(dir="/private/tmp") as temp:
    temp_root = Path(temp)
    authority = temp_root / "authority.tsv"
    destination = temp_root / "destination.json"
    authority.write_text("before\n", "utf-8")
    destination.write_text("frozen\n", "utf-8")
    proposal = {
        "read_guards": {authority: module.sha256(authority)},
        "before": {destination: module.sha256(destination)},
        "writes": [(destination, b"refreshed\n", 0o600)],
    }
    authority.write_text("drifted\n", "utf-8")
    try:
        module.apply_proposal(proposal)
    except SystemExit as exc:
        assert "freeze input drifted after preflight" in str(exc)
    else:
        raise AssertionError("authority drift allowed a frozen write")
    assert destination.read_bytes() == b"frozen\n"

source = HELPER.read_text("utf-8")
build = source.index("proposal = build_proposal(")
apply = source.index("apply_proposal(proposal)", build)
assert build < apply
for needle in (
    "EXPECTED_EXTERNAL_ROUTE_SHA256",
    "FROZEN_ONLY_INPUTS",
    "require_safe_destination",
    "require_real_directory(SNAPSHOT",
    "module.validate_plan(plan)",
    "module.validate_receipt(receipt, info, require_ready=False)",
    "IMPORT_ARCHIVE: sha256(IMPORT_ARCHIVE)",
    "IMPORT_RECEIPT: sha256(IMPORT_RECEIPT)",
    "LANE_AUTHORITY: sha256(LANE_AUTHORITY)",
    "USER_MATRIX: sha256(USER_MATRIX)",
    "FEATURE_MATRIX: sha256(FEATURE_MATRIX)",
    "freeze input drifted after preflight",
    "freeze destination drifted after preflight",
):
    assert needle in source, needle

print(
    "freeze harness transaction contract PASS: exact engine path+SHA; "
    "explicit frozen-only inputs; symlink/hardlink rejection; complete staged "
    "plan+receipt validation; ready checkpoint no-write"
)
