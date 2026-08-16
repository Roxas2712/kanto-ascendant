#!/usr/bin/env python3
"""Refresh the immutable final-package harness while the receipt is pending.

This helper never packs Authority, marks a receipt ready, materializes a
runtime, or starts LÖVE.  It builds and validates the complete proposed
harness/plan/receipt in an isolated staging tree before changing any frozen
byte.  The engine-owned route runner must be supplied from the one exact
engine worktree and match its reviewed SHA-256; an old snapshot is never used
as an implicit fallback.
"""

from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path, PurePosixPath
import shutil
import stat
import tempfile


ROOT = Path(__file__).resolve().parents[1]
QA = ROOT / "qa/blitz_real_save_forensic_20260812/package_candidate"
PLAN = QA / "final_same_hash_plan.json"
RECEIPT = QA / "final_same_hash_receipt.json"
SNAPSHOT = QA / "inputs/harness_snapshot"
ORCHESTRATOR = QA / "final_same_hash_orchestrator.py"
EVIDENCE_MODULE = QA / "final_same_hash_evidence.py"
IMPORT_ARCHIVE = QA / "inputs/imported-rby-runtime-cache-v2.zip"
IMPORT_RECEIPT = QA / "inputs/imported-rby-runtime-cache-v2.receipt.json"
MODULE_MAP = ROOT / "qa/rc28_release_gate_20260812/MODULE_ACCEPTANCE_MAP.tsv"
MODULE_MAP_SNAPSHOT = SNAPSHOT / "authority/MODULE_ACCEPTANCE_MAP.tsv"
AUTHORITY_SNAPSHOT = QA / "inputs/authority_snapshot"
LANE_AUTHORITY = AUTHORITY_SNAPSHOT / "PACKAGE_ACCEPTANCE_LANES.tsv"
USER_MATRIX = AUTHORITY_SNAPSHOT / "USER_CHAT_REGRESSION_GATE.md"
FEATURE_MATRIX = AUTHORITY_SNAPSHOT / "FEATURE_ACCEPTANCE_MATRIX.md"

EXTERNAL_ROUTE_RUNNER = "tests/drivers/route.lua"
EXPECTED_ENGINE_ROOT = ROOT.parent / "gen1recomp-ka65-engine-rc27-v079"
EXPECTED_EXTERNAL_ROUTE = EXPECTED_ENGINE_ROOT / EXTERNAL_ROUTE_RUNNER
EXPECTED_EXTERNAL_ROUTE_SHA256 = (
    "8cad0bc24ba92f01bae136f6f1aec4c029256c44f8db9570cc23493d26ad0842"
)
FROZEN_ONLY_INPUTS = frozenset({
    "immutable_inputs/upgrade_sources/immutable_input_receipt.json",
    "immutable_inputs/upgrade_sources/kanto-ascendant-6.0.11.modpkg",
    "immutable_inputs/upgrade_sources/kanto-ascendant-6.5.0-rc25-test.zip",
    "immutable_inputs/upgrade_sources/kanto-ascendant-6.5.0-rc26-test.zip",
    "immutable_inputs/upgrade_sources/kanto-ascendant-6.5.0-rc27-test.zip",
    "immutable_inputs/upgrade_sources/upgrade_matrix_package_driver.lua",
    "immutable_inputs/upgrade_sources/upgrade_package_matrix_manifest.lua",
    "immutable_inputs/upgrade_sources/upgrade_package_sources.lua",
})
HARNESS_EXTRAS = (
    "source_snapshot/options_original_readonly.lua",
    "source_snapshot/slot7_original_readonly.lua",
    "driver_util.lua",
)


def sha256(path):
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def read_json_unique(path):
    def unique(pairs):
        value = {}
        for key, row in pairs:
            if key in value:
                raise SystemExit(f"duplicate JSON key in {path}: {key}")
            value[key] = row
        return value

    try:
        return json.loads(path.read_text("utf-8"), object_pairs_hook=unique)
    except (OSError, UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise SystemExit(f"cannot read canonical JSON {path}: {exc}") from exc


def require_regular_file(path, label, *, single_link=True):
    path = Path(path)
    try:
        row = path.lstat()
        resolved = path.resolve(strict=True)
    except OSError as exc:
        raise SystemExit(f"{label} missing/unresolvable: {exc}") from exc
    if not stat.S_ISREG(row.st_mode) or path.is_symlink():
        raise SystemExit(f"{label} is not a regular non-symlink file")
    if path.absolute() != resolved:
        raise SystemExit(f"{label} has a symlinked/noncanonical path")
    if single_link and row.st_nlink != 1:
        raise SystemExit(f"{label} is hardlinked")
    return row


def require_real_directory(path, label):
    path = Path(path)
    try:
        row = path.lstat()
        resolved = path.resolve(strict=True)
    except OSError as exc:
        raise SystemExit(f"{label} missing/unresolvable: {exc}") from exc
    if not stat.S_ISDIR(row.st_mode) or path.is_symlink():
        raise SystemExit(f"{label} is not a real non-symlink directory")
    if path.absolute() != resolved:
        raise SystemExit(f"{label} has a symlinked/noncanonical path")
    return row


def require_safe_destination(path, label):
    """Reject linked/special snapshot destinations before the first write."""
    path = Path(path)
    try:
        path.relative_to(SNAPSHOT)
    except ValueError as exc:
        raise SystemExit(f"{label} escapes the harness snapshot") from exc
    require_real_directory(SNAPSHOT, "harness snapshot root")
    current = SNAPSHOT
    try:
        relative_parent = path.parent.relative_to(SNAPSHOT)
    except ValueError as exc:
        raise SystemExit(f"{label} parent escapes the harness snapshot") from exc
    for part in relative_parent.parts:
        current = current / part
        try:
            row = current.lstat()
        except OSError as exc:
            raise SystemExit(f"{label} parent is missing: {current}") from exc
        if not stat.S_ISDIR(row.st_mode) or current.is_symlink():
            raise SystemExit(f"{label} has a linked/non-directory parent: {current}")
    try:
        row = path.lstat()
    except FileNotFoundError:
        return None
    except OSError as exc:
        raise SystemExit(f"{label} cannot be inspected: {exc}") from exc
    if not stat.S_ISREG(row.st_mode) or path.is_symlink():
        raise SystemExit(f"{label} is linked or not a regular file")
    if row.st_nlink != 1:
        raise SystemExit(f"{label} is hardlinked")
    if path.absolute() != path.resolve(strict=True):
        raise SystemExit(f"{label} has a symlinked/noncanonical path")
    return row


def validate_pending_receipt(receipt):
    if receipt.get("status") != "pending":
        raise SystemExit("receipt must be explicitly pending before harness refresh")
    if receipt.get("harness_tree_sha256") not in (None, ""):
        raise SystemExit(
            "pending receipt must clear harness_tree_sha256 before refresh"
        )


def add_tree(paths, relative):
    source = ROOT / relative
    if not source.is_dir() or source.is_symlink():
        raise SystemExit(f"fixture tree missing/symlinked: {relative}")
    for path in sorted(source.rglob("*")):
        if path.is_file() and not path.is_symlink():
            paths.add(
                (PurePosixPath(relative) / path.relative_to(source).as_posix())
                .as_posix()
            )


def plan_paths(plan):
    paths = set(plan.get("support_files") or [])
    for lane in plan["lanes"]:
        for cell in lane["cells"]:
            if cell.get("status") == "BLOCKED_DRIVER" or cell.get("kind"):
                continue
            for key in ("driver", "setup"):
                if cell.get(key):
                    paths.add(cell[key])
            for phase in cell.get("passes") or []:
                paths.add(phase["driver"])
            for fixture in cell.get("fixture_mods") or []:
                add_tree(paths, fixture["source"])
    return sorted(paths)


def exact_external_route(external_route_runner):
    if external_route_runner is None:
        raise SystemExit(
            "planned engine route runner requires --external-route-runner; "
            "refusing stale snapshot reuse"
        )
    route = Path(external_route_runner)
    if not route.is_absolute():
        raise SystemExit("external route runner must be an absolute path")
    if route != EXPECTED_EXTERNAL_ROUTE:
        raise SystemExit(
            "external route runner is not the exact reviewed engine-worktree path"
        )
    require_regular_file(route, "external route runner")
    got = sha256(route)
    if got != EXPECTED_EXTERNAL_ROUTE_SHA256:
        raise SystemExit(
            f"external route runner SHA drifted: expected "
            f"{EXPECTED_EXTERNAL_ROUTE_SHA256}, got {got}"
        )
    return route


def harness_sources(paths, external_route_runner):
    """Resolve the exact payload for every plan-bound snapshot member."""
    route_source = exact_external_route(external_route_runner)
    sources = {}
    for relative in paths:
        destination = SNAPSHOT / relative
        require_safe_destination(destination, f"snapshot destination {relative}")
        if relative in FROZEN_ONLY_INPUTS:
            require_regular_file(destination, f"pinned immutable input {relative}")
            sources[relative] = None
        elif relative.startswith("immutable_inputs/"):
            raise SystemExit(f"unapproved frozen-only input: {relative}")
        elif relative == EXTERNAL_ROUTE_RUNNER:
            sources[relative] = route_source
        elif relative == "authority/MODULE_ACCEPTANCE_MAP.tsv":
            sources[relative] = MODULE_MAP
        else:
            source = ROOT / relative
            require_regular_file(source, f"planned harness source {relative}")
            sources[relative] = source
    if set(FROZEN_ONLY_INPUTS) - set(paths):
        missing = sorted(set(FROZEN_ONLY_INPUTS) - set(paths))
        raise SystemExit(f"pinned immutable inputs left the plan: {missing}")
    return sources


def canonical_json(value):
    return (json.dumps(value, indent=2, ensure_ascii=False) + "\n").encode()


def stage_harness(stage, paths, sources):
    for relative in paths:
        source = sources[relative] or (SNAPSHOT / relative)
        destination = stage / relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, destination, follow_symlinks=False)
    for relative in HARNESS_EXTRAS:
        source = SNAPSHOT / relative
        require_regular_file(source, f"harness extra {relative}")
        destination = stage / relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, destination, follow_symlinks=False)


def import_orchestrator():
    spec = importlib.util.spec_from_file_location("final_gate", ORCHESTRATOR)
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


def build_proposal(external_route_runner):
    """Read and validate every late input; perform no frozen-surface write."""
    for path, label in (
        (PLAN, "execution plan"),
        (RECEIPT, "input receipt"),
        (ORCHESTRATOR, "orchestrator"),
        (EVIDENCE_MODULE, "evidence helper"),
        (IMPORT_ARCHIVE, "import cache"),
        (IMPORT_RECEIPT, "import provenance receipt"),
        (MODULE_MAP, "module acceptance map"),
        (LANE_AUTHORITY, "lane authority snapshot"),
        (USER_MATRIX, "user matrix snapshot"),
        (FEATURE_MATRIX, "feature matrix snapshot"),
    ):
        require_regular_file(path, label)
    receipt = read_json_unique(RECEIPT)
    validate_pending_receipt(receipt)
    orchestrator_text = ORCHESTRATOR.read_text("utf-8")
    expected_helper_row = (
        'EXPECTED_EVIDENCE_MODULE_SHA256 = (\n'
        f'    "{sha256(EVIDENCE_MODULE)}"\n'
        ')'
    )
    if expected_helper_row not in orchestrator_text:
        raise SystemExit(
            "orchestrator does not authenticate the exact evidence helper before import"
        )

    plan = read_json_unique(PLAN)
    support_files = set(plan.get("support_files") or [])
    support_files.add("authority/MODULE_ACCEPTANCE_MAP.tsv")
    plan["support_files"] = sorted(support_files)
    plan_bytes = canonical_json(plan)
    paths = plan_paths(plan)
    sources = harness_sources(paths, external_route_runner)

    # All destination metadata is captured before staging so a linked target
    # is rejected without changing its referent.  Plan/receipt are also
    # required to remain single-link regular files.
    require_regular_file(PLAN, "execution plan destination")
    require_regular_file(RECEIPT, "input receipt destination")
    before = {
        PLAN: sha256(PLAN),
        RECEIPT: sha256(RECEIPT),
    }
    read_guards = {
        ORCHESTRATOR: sha256(ORCHESTRATOR),
        EVIDENCE_MODULE: sha256(EVIDENCE_MODULE),
        IMPORT_ARCHIVE: sha256(IMPORT_ARCHIVE),
        IMPORT_RECEIPT: sha256(IMPORT_RECEIPT),
        MODULE_MAP: sha256(MODULE_MAP),
        LANE_AUTHORITY: sha256(LANE_AUTHORITY),
        USER_MATRIX: sha256(USER_MATRIX),
        FEATURE_MATRIX: sha256(FEATURE_MATRIX),
    }
    for relative, source in sources.items():
        destination = SNAPSHOT / relative
        before[destination] = sha256(destination) if destination.exists() else None
        if source is not None:
            read_guards[source] = sha256(source)
    for relative in HARNESS_EXTRAS:
        source = SNAPSHOT / relative
        require_regular_file(source, f"harness extra {relative}")
        read_guards[source] = sha256(source)

    # Staging provides the exact globals used by validate_plan,
    # harness_tree_hash, and validate_receipt.  All archive/provenance hashes
    # are read before the proposal is returned, so a late missing input cannot
    # leave a partially refreshed snapshot.
    with tempfile.TemporaryDirectory(
        prefix="ka-final-harness-preflight.", dir="/private/tmp"
    ) as temp:
        temp_root = Path(temp)
        staged_snapshot = temp_root / "harness_snapshot"
        stage_harness(staged_snapshot, paths, sources)
        staged_plan = temp_root / PLAN.name
        staged_plan.write_bytes(plan_bytes)

        module = import_orchestrator()
        if (module.LANES_PATH != LANE_AUTHORITY
                or module.USER_MATRIX != USER_MATRIX
                or module.FEATURE_MATRIX != FEATURE_MATRIX):
            raise SystemExit(
                "orchestrator authority-snapshot paths drifted from freeze guards"
            )
        module.HARNESS_SNAPSHOT = staged_snapshot
        module.MODULE_MAP = staged_snapshot / "authority/MODULE_ACCEPTANCE_MAP.tsv"
        module.PLAN_PATH = staged_plan
        info = module.validate_plan(plan)
        if sorted(info["harness"]) != paths:
            raise SystemExit("staged validator changed the exact harness path set")

        receipt["orchestrator_sha256"] = sha256(ORCHESTRATOR)
        receipt["evidence_module_sha256"] = sha256(EVIDENCE_MODULE)
        receipt["execution_plan_sha256"] = hashlib.sha256(plan_bytes).hexdigest()
        receipt["harness_tree_sha256"] = module.harness_tree_hash(info["harness"])
        receipt["module_acceptance_map_sha256"] = sha256(module.MODULE_MAP)
        receipt["imported_data"]["sha256"] = sha256(IMPORT_ARCHIVE)
        receipt["imported_data"]["provenance_receipt_sha256"] = sha256(
            IMPORT_RECEIPT
        )
        module.validate_receipt(receipt, info, require_ready=False)

    receipt_bytes = canonical_json(receipt)
    writes = []
    for relative, source in sources.items():
        if source is None:
            continue
        target = SNAPSHOT / relative
        payload = source.read_bytes()
        if before[target] != hashlib.sha256(payload).hexdigest():
            writes.append((target, payload, stat.S_IMODE(source.stat().st_mode)))
    if before[PLAN] != hashlib.sha256(plan_bytes).hexdigest():
        writes.append((PLAN, plan_bytes, stat.S_IMODE(PLAN.stat().st_mode)))
    writes.append((RECEIPT, receipt_bytes, stat.S_IMODE(RECEIPT.stat().st_mode)))
    return {
        "before": before,
        "read_guards": read_guards,
        "harness_count": len(paths),
        "harness_sha256": receipt["harness_tree_sha256"],
        "import_sha256": receipt["imported_data"]["sha256"],
        "plan_sha256": receipt["execution_plan_sha256"],
        "writes": writes,
    }


def atomic_write(path, payload, mode):
    temporary = path.with_name(f".{path.name}.freeze-{os.getpid()}.tmp")
    if temporary.exists() or temporary.is_symlink():
        raise SystemExit(f"freeze staging file already exists: {temporary}")
    try:
        descriptor = os.open(temporary, os.O_WRONLY | os.O_CREAT | os.O_EXCL, mode)
        with os.fdopen(descriptor, "wb") as stream:
            stream.write(payload)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, path)
        directory = os.open(path.parent, os.O_RDONLY)
        try:
            os.fsync(directory)
        finally:
            os.close(directory)
    finally:
        if temporary.exists() and not temporary.is_symlink():
            temporary.unlink()


def apply_proposal(proposal):
    """Recheck every target, then atomically replace proposal members."""
    for path, expected in proposal["read_guards"].items():
        require_regular_file(path, f"freeze input {path}")
        if sha256(path) != expected:
            raise SystemExit(f"freeze input drifted after preflight: {path}")
    for path, expected in proposal["before"].items():
        if expected is None:
            if path.exists() or path.is_symlink():
                raise SystemExit(f"freeze destination appeared after preflight: {path}")
            continue
        require_regular_file(path, f"freeze destination {path}")
        if sha256(path) != expected:
            raise SystemExit(f"freeze destination drifted after preflight: {path}")
    for path, payload, mode in proposal["writes"]:
        atomic_write(path, payload, mode)


def parser():
    result = argparse.ArgumentParser(
        description="Refresh the immutable final same-hash harness",
    )
    result.add_argument(
        "--external-route-runner",
        help=(
            "exact absolute reviewed engine-worktree tests/drivers/route.lua; "
            "required whenever that runner is plan-bound"
        ),
    )
    return result


def main(argv=None):
    args = parser().parse_args(argv)
    proposal = build_proposal(args.external_route_runner)
    apply_proposal(proposal)
    print("PASS frozen harness", proposal["harness_count"], "files")
    print("plan", proposal["plan_sha256"])
    print("harness", proposal["harness_sha256"])
    print("import", proposal["import_sha256"])


if __name__ == "__main__":
    main()
