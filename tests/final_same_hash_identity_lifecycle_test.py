#!/usr/bin/env python3
"""Isolated tests for guarded final-gate identity audit/archive lifecycle.

Every mutable identity in this test lives below a fresh /private/tmp fixture.
The account's real Application Support directory is never inspected or changed.
"""

from __future__ import annotations

import importlib.util
import json
import os
from pathlib import Path
import sys
import tempfile


ROOT = Path(__file__).resolve().parents[1]
HELPER = (
    ROOT / "qa/blitz_real_save_forensic_20260812/package_candidate"
    / "final_same_hash_identity_lifecycle.py"
)
PLAN = HELPER.parent / "final_same_hash_plan.json"
spec = importlib.util.spec_from_file_location(
    "final_same_hash_identity_lifecycle", HELPER,
)
assert spec and spec.loader
lifecycle = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = lifecycle
spec.loader.exec_module(lifecycle)


def rejected(fragment: str, operation) -> None:
    try:
        operation()
    except lifecycle.IdentityLifecycleError as exc:
        assert fragment in str(exc), (fragment, str(exc))
    else:
        raise AssertionError(f"identity lifecycle accepted: {fragment}")


def fixture_roots(base: Path) -> lifecycle.IdentityRoots:
    support = base / "home/Library/Application Support"
    conventional = support / "LOVE"
    conventional.mkdir(parents=True)
    return lifecycle.IdentityRoots(
        primary=support,
        conventional=conventional,
    )


def identity_tree(roots: lifecycle.IdentityRoots,
                  spec: lifecycle.IdentitySpec,
                  surface: str = "primary") -> Path:
    root = roots.primary if surface == "primary" else roots.conventional
    identity = root / spec.identity
    cache = identity / "red/data/generated"
    cache.mkdir(parents=True)
    (cache / "pokemon.lua").write_text("return { edition = 'red' }\n", "utf-8")
    (identity / "save_red.lua").write_text("return { map = 'pallet' }\n", "utf-8")
    (identity / "options.lua").write_text("return { language = 'en' }\n", "utf-8")
    return identity


plan = json.loads(PLAN.read_text("utf-8"))
plan_specs = lifecycle.identity_specs_from_plan(plan)
assert len(plan_specs) == 190
assert len({row.cell_id for row in plan_specs}) == 190
assert len({row.identity.casefold() for row in plan_specs}) == 190
assert all(row.identity.startswith(("ka-", "ka65-")) for row in plan_specs)

# Default semantics reflect the real fused launcher: Application Support/<id>
# is primary; Application Support/LOVE/<id> is the forbidden conventional root.
original_pwd = lifecycle.pwd.getpwuid
lifecycle.pwd.getpwuid = lambda uid: type("Pw", (), {"pw_dir": "/private/tmp/fake-home"})()
try:
    default_roots = lifecycle.default_identity_roots()
finally:
    lifecycle.pwd.getpwuid = original_pwd
assert default_roots.primary == Path("/private/tmp/fake-home/Library/Application Support")
assert default_roots.conventional == default_roots.primary / "LOVE"

with tempfile.TemporaryDirectory(
        prefix="ka-final-identity-lifecycle.", dir="/private/tmp") as raw:
    base = Path(raw)
    roots = fixture_roots(base)
    one = lifecycle.IdentitySpec("L00_RUNTIME_CLOSURE", "cell-one", "ka65-cell-one")
    two = lifecycle.IdentitySpec("L01_BOOT_UPGRADE_RULES", "cell-two", "ka65-cell-two")

    lifecycle.audit_fresh_identities((one, two), roots)
    primary = identity_tree(roots, one)
    conventional = identity_tree(roots, two, "conventional")
    rejected("cell-one:ka65-cell-one:primary:directory", lambda: (
        lifecycle.audit_fresh_identities((one, two), roots)
    ))
    rejected("cell-two:ka65-cell-two:conventional:directory", lambda: (
        lifecycle.audit_fresh_identities((one, two), roots)
    ))
    assert primary.is_dir() and conventional.is_dir()

    # Audit reports a symlink/file/special as occupied; it never follows or
    # mutates that unexpected node.
    link_spec = lifecycle.IdentitySpec("L02_PRESENTATION_MOTION", "cell-link", "ka65-cell-link")
    target = base / "foreign-target"
    target.mkdir()
    (roots.primary / link_spec.identity).symlink_to(target, target_is_directory=True)
    rejected("cell-link:ka65-cell-link:primary:symlink", lambda: (
        lifecycle.audit_fresh_identities((link_spec,), roots)
    ))
    assert target.is_dir()

    # Ancestor symlinks and colliding surface roots are categorically unsafe.
    real_support = base / "real-support"
    real_support.mkdir()
    linked_support = base / "linked-support"
    linked_support.symlink_to(real_support, target_is_directory=True)
    rejected("traverses a symlink", lambda: lifecycle.validate_roots(
        lifecycle.IdentityRoots(linked_support, real_support / "LOVE")
    ))
    rejected("roots collide", lambda: lifecycle.validate_roots(
        lifecycle.IdentityRoots(real_support, real_support)
    ))

with tempfile.TemporaryDirectory(
        prefix="ka-final-identity-snapshot.", dir="/private/tmp") as raw:
    base = Path(raw)
    roots = fixture_roots(base)
    spec_one = lifecycle.IdentitySpec("L04_NGPLUS_LEGACY", "cell-save", "ka65-cell-save")
    identity = identity_tree(roots, spec_one)
    snapshot = lifecycle.observe_success_identity(spec_one, roots)
    assert snapshot.surface == "primary"
    assert snapshot.file_count == 3
    assert snapshot.total_bytes == sum(
        path.stat().st_size for path in identity.rglob("*") if path.is_file()
    )
    assert snapshot.manifest.startswith(lifecycle.MANIFEST_HEADER)
    lifecycle.verify_sealed_success_identity(spec_one, roots, snapshot)

    (identity / "options.lua").write_text("return { language = 'de' }\n", "utf-8")
    rejected("drifted during cell sealing", lambda: (
        lifecycle.verify_sealed_success_identity(spec_one, roots, snapshot)
    ))
    # Failure inspection is non-mutating and retains root siblings such as
    # save/options in addition to the edition cache.
    failures = lifecycle.preserved_failure_snapshots(spec_one, roots)
    assert len(failures) == 1 and failures[0].file_count == 3
    assert (identity / "save_red.lua").is_file()

    # A conventional fallback invalidates a successful-cell observation.
    identity_tree(roots, spec_one, "conventional")
    rejected("conventional fallback identity", lambda: (
        lifecycle.observe_success_identity(spec_one, roots)
    ))

with tempfile.TemporaryDirectory(
        prefix="ka-final-identity-hostile.", dir="/private/tmp") as raw:
    base = Path(raw)
    roots = fixture_roots(base)
    hostile = lifecycle.IdentitySpec("L03_HEVO_MATRIX", "cell-hostile", "ka65-cell-hostile")
    identity = identity_tree(roots, hostile)
    first = identity / "save_red.lua"
    second = identity / "hardlink.lua"
    os.link(first, second)
    rejected("hardlink", lambda: lifecycle.snapshot_identity(
        hostile, roots, "primary",
    ))
    assert first.is_file() and second.is_file()

with tempfile.TemporaryDirectory(
        prefix="ka-final-identity-archive-test.", dir="/private/tmp") as raw:
    base = Path(raw)
    roots = fixture_roots(base)
    archive_base = base / "archives"
    archive_base.mkdir()
    owned = lifecycle.IdentitySpec(
        "L06_WANDERERS_REMATCH", "cell-archive", "ka65-cell-archive",
    )
    specs = (owned,)
    source = identity_tree(roots, owned)
    source_payload = {
        path.relative_to(source).as_posix(): path.read_bytes()
        for path in source.rglob("*") if path.is_file()
    }
    inspection = lifecycle.inspect_archive_retry(
        specs, cell_id=owned.cell_id, identity=owned.identity,
        surface="primary", roots=roots,
    )

    # Every failed guard leaves the complete identity at its original path.
    rejected("does not belong", lambda: lifecycle.archive_retry(
        specs, cell_id=owned.cell_id, identity="ka65-wrong-identity",
        surface="primary", expected_tree_sha256=inspection.snapshot.manifest_sha256,
        confirmation=inspection.confirmation, archive_id="wrong-identity",
        roots=roots, archive_base=archive_base,
    ))
    rejected("tree SHA256 changed", lambda: lifecycle.archive_retry(
        specs, cell_id=owned.cell_id, identity=owned.identity,
        surface="primary", expected_tree_sha256="0" * 64,
        confirmation=inspection.confirmation, archive_id="wrong-hash",
        roots=roots, archive_base=archive_base,
    ))
    rejected("confirmation token", lambda: lifecycle.archive_retry(
        specs, cell_id=owned.cell_id, identity=owned.identity,
        surface="primary", expected_tree_sha256=inspection.snapshot.manifest_sha256,
        confirmation="ARCHIVE-RETRY:wrong", archive_id="wrong-confirm",
        roots=roots, archive_base=archive_base,
    ))
    assert source.is_dir()
    assert not any(archive_base.iterdir())

    collision = archive_base / (
        lifecycle.ARCHIVE_PREFIX + "existing-destination"
    )
    collision.mkdir()
    rejected("destination already exists", lambda: lifecycle.archive_retry(
        specs, cell_id=owned.cell_id, identity=owned.identity,
        surface="primary", expected_tree_sha256=inspection.snapshot.manifest_sha256,
        confirmation=inspection.confirmation, archive_id="existing-destination",
        roots=roots, archive_base=archive_base,
    ))
    assert source.is_dir() and collision.is_dir()

    result = lifecycle.archive_retry(
        specs, cell_id=owned.cell_id, identity=owned.identity,
        surface="primary", expected_tree_sha256=inspection.snapshot.manifest_sha256,
        confirmation=inspection.confirmation, archive_id="successful-retry",
        roots=roots, archive_base=archive_base,
    )
    assert not source.exists()
    archived_identity = result.archive_path / owned.identity
    assert archived_identity.is_dir()
    assert {
        path.relative_to(archived_identity).as_posix(): path.read_bytes()
        for path in archived_identity.rglob("*") if path.is_file()
    } == source_payload
    assert (result.archive_path / "identity_hash_manifest.tsv").read_bytes() \
        == inspection.snapshot.manifest
    receipt_path = result.archive_path / "archive_receipt.json"
    receipt_payload = receipt_path.read_bytes()
    receipt = json.loads(receipt_payload)
    assert receipt_payload == lifecycle._canonical_json_bytes(receipt)
    assert receipt == {
        "archive_id": "successful-retry",
        "archive_name": result.archive_path.name,
        "cell_id": owned.cell_id,
        "file_count": 3,
        "identity": owned.identity,
        "identity_manifest": "identity_hash_manifest.tsv",
        "identity_manifest_sha256": inspection.snapshot.manifest_sha256,
        "identity_tree": owned.identity,
        "lane_id": owned.lane_id,
        "schema": lifecycle.ARCHIVE_SCHEMA,
        "status": "ARCHIVED_FOR_EXPLICIT_RETRY",
        "surface": "primary",
        "total_bytes": inspection.snapshot.total_bytes,
    }
    lifecycle.audit_fresh_identities(specs, roots)

    # A second archive cannot silently reuse the same archive name.
    replacement = identity_tree(roots, owned)
    replacement_inspection = lifecycle.inspect_archive_retry(
        specs, cell_id=owned.cell_id, identity=owned.identity,
        surface="primary", roots=roots,
    )
    rejected("destination already exists", lambda: lifecycle.archive_retry(
        specs, cell_id=owned.cell_id, identity=owned.identity,
        surface="primary",
        expected_tree_sha256=replacement_inspection.snapshot.manifest_sha256,
        confirmation=replacement_inspection.confirmation,
        archive_id="successful-retry", roots=roots, archive_base=archive_base,
    ))
    assert replacement.is_dir()

    # Archive destinations are constrained beneath /private/tmp even through
    # the programmatic API used by tests/integration.
    rejected("outside /private/tmp", lambda: lifecycle.archive_retry(
        specs, cell_id=owned.cell_id, identity=owned.identity,
        surface="primary",
        expected_tree_sha256=replacement_inspection.snapshot.manifest_sha256,
        confirmation=replacement_inspection.confirmation,
        archive_id="outside", roots=roots,
        archive_base=Path("/usr"),
    ))

source_text = HELPER.read_text("utf-8")
assert "os.rename(source, target)" in source_text
assert "shutil" not in source_text
assert ".unlink(" not in source_text and ".rmdir(" not in source_text
assert 'conventional=support / "LOVE"' in source_text
assert 'SURFACES = ("primary", "conventional")' in source_text

print(
    "final same-hash identity lifecycle PASS: 190 planned identities; "
    "fused-primary/conventional audit; guarded atomic archive; no real identity"
)
