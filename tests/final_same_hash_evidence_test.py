#!/usr/bin/env python3
"""Unit coverage for the isolated same-hash evidence chain."""

from __future__ import annotations

import copy
import importlib.util
from pathlib import Path
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
MODULE = (
    ROOT
    / "qa/blitz_real_save_forensic_20260812/package_candidate"
    / "final_same_hash_evidence.py"
)
SPEC = importlib.util.spec_from_file_location("final_same_hash_evidence", MODULE)
assert SPEC is not None and SPEC.loader is not None
evidence = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = evidence
SPEC.loader.exec_module(evidence)


def write_canonical(root: Path, relative: str, payload: dict) -> None:
    path = root / relative
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(evidence.canonical_json_bytes(payload))


class EvidenceChainTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory(prefix="ka-final-evidence-test.")
        self.root = Path(self.temporary.name).resolve(strict=True)
        self.artifact_root = "cells/cell-a"
        output = self.root / self.artifact_root
        output.mkdir(parents=True)
        (output / "process.log").write_text("phase=driver status=PASS\n", "utf-8")
        (output / "driver_result.txt").write_text(
            "status=PASS\nscope=UNIT\nfail=0\n", "utf-8",
        )
        (output / "frame.png").write_bytes(b"\x89PNG\r\n\x1a\nunit-image")

        self.manifest_path = "cell_manifests/cell-a.tsv"
        manifest = self.root / self.manifest_path
        manifest.parent.mkdir(parents=True)
        manifest.write_bytes(evidence.build_artifact_manifest(output))
        self.artifact = evidence.validate_artifact_manifest(
            self.root,
            artifact_root=self.artifact_root,
            manifest_path=self.manifest_path,
        )

        self.bindings = {
            "engine_app_tree_sha256": "1" * 64,
            "execution_plan_sha256": "2" * 64,
            "package_gate_receipt_sha256": "3" * 64,
            "runtime_manifest_sha256": "4" * 64,
        }
        self.cell_spec = {
            "id": "cell-a",
            "identity": "ka65-unit-cell-a",
            "edition": "red",
            "closure": "base_deutsch",
            "result": {"path": "driver_result.txt", "contains": ["status=PASS", "fail=0"]},
            "images": {"exact_count": 1, "min_bytes": 8},
        }
        self.claims = {
            "image_count": 1,
            "process_log_sha256": evidence.file_sha256(output / "process.log"),
            "result_sha256": evidence.file_sha256(output / "driver_result.txt"),
        }
        self.cell_receipt_path = "cell_receipts/cell-a.json"
        cell_payload = evidence.cell_receipt_payload(
            lane_id="L00_UNIT",
            lane_order=0,
            cell_id="cell-a",
            cell_order=0,
            cell_spec=self.cell_spec,
            artifact=self.artifact,
            bindings=self.bindings,
            claims=self.claims,
        )
        write_canonical(self.root, self.cell_receipt_path, cell_payload)
        self.cell = self.validate_cell()

        self.lane_spec = {"lane_id": "L00_UNIT", "order": 0, "cells": [self.cell_spec]}
        self.lane_receipt_path = "lane_receipts/L00_UNIT.json"
        lane_payload = evidence.lane_receipt_payload(
            lane_id="L00_UNIT",
            lane_order=0,
            lane_spec=self.lane_spec,
            cells=[self.cell],
            bindings=self.bindings,
        )
        write_canonical(self.root, self.lane_receipt_path, lane_payload)
        self.lane = self.validate_lane()

        self.plan_spec = {"schema": "unit-plan/v1", "lanes": [self.lane_spec]}
        self.seal_path = "run_seal.json"
        seal_payload = evidence.run_seal_payload(
            plan_spec=self.plan_spec,
            lanes=[self.lane],
            bindings=self.bindings,
        )
        write_canonical(self.root, self.seal_path, seal_payload)

    def tearDown(self) -> None:
        self.temporary.cleanup()

    def validate_cell(self):
        return evidence.validate_cell_receipt(
            self.root,
            receipt_path=self.cell_receipt_path,
            lane_id="L00_UNIT",
            lane_order=0,
            cell_id="cell-a",
            cell_order=0,
            cell_spec=self.cell_spec,
            artifact_root=self.artifact_root,
            artifact_manifest=self.manifest_path,
            bindings=self.bindings,
            claims=self.claims,
        )

    def validate_lane(self):
        return evidence.validate_lane_receipt(
            self.root,
            receipt_path=self.lane_receipt_path,
            lane_id="L00_UNIT",
            lane_order=0,
            lane_spec=self.lane_spec,
            cells=[self.cell],
            bindings=self.bindings,
        )

    def validate_seal(self):
        return evidence.validate_run_seal(
            self.root,
            seal_path=self.seal_path,
            plan_spec=self.plan_spec,
            lanes=[self.lane],
            bindings=self.bindings,
        )

    def test_complete_chain_passes(self) -> None:
        seal = self.validate_seal()
        self.assertEqual(seal.cell_count, 1)
        self.assertEqual(seal.plan_spec_sha256, evidence.canonical_spec_sha256(self.plan_spec))
        self.assertRegex(seal.seal_sha256, r"^[0-9a-f]{64}$")

    def test_artifact_mutation_rejected_recursively(self) -> None:
        path = self.root / self.artifact_root / "driver_result.txt"
        path.write_text("status=PASS\nscope=UNIT\nfail=1\n", "utf-8")
        with self.assertRaisesRegex(evidence.EvidenceError, "complete artifact tree"):
            self.validate_seal()

    def test_added_artifact_rejected(self) -> None:
        (self.root / self.artifact_root / "unbound.txt").write_text("extra\n", "utf-8")
        with self.assertRaisesRegex(evidence.EvidenceError, "complete artifact tree"):
            self.validate_cell()

    def test_cell_spec_or_claim_drift_rejected(self) -> None:
        changed_spec = copy.deepcopy(self.cell_spec)
        changed_spec["edition"] = "blue"
        with self.assertRaisesRegex(evidence.EvidenceError, "cell_spec_sha256"):
            evidence.validate_cell_receipt(
                self.root,
                receipt_path=self.cell_receipt_path,
                lane_id="L00_UNIT",
                lane_order=0,
                cell_id="cell-a",
                cell_order=0,
                cell_spec=changed_spec,
                artifact_root=self.artifact_root,
                artifact_manifest=self.manifest_path,
                bindings=self.bindings,
                claims=self.claims,
            )
        changed_claims = dict(self.claims, image_count=2)
        with self.assertRaisesRegex(evidence.EvidenceError, "claims"):
            evidence.validate_cell_receipt(
                self.root,
                receipt_path=self.cell_receipt_path,
                lane_id="L00_UNIT",
                lane_order=0,
                cell_id="cell-a",
                cell_order=0,
                cell_spec=self.cell_spec,
                artifact_root=self.artifact_root,
                artifact_manifest=self.manifest_path,
                bindings=self.bindings,
                claims=changed_claims,
            )

    def test_noncanonical_or_expanded_receipt_rejected(self) -> None:
        path = self.root / self.cell_receipt_path
        original = path.read_bytes()
        path.write_bytes(b"  " + original)
        with self.assertRaisesRegex(evidence.EvidenceError, "not canonical JSON"):
            self.validate_cell()
        path.write_bytes(original)
        payload = evidence.cell_receipt_payload(
            lane_id="L00_UNIT",
            lane_order=0,
            cell_id="cell-a",
            cell_order=0,
            cell_spec=self.cell_spec,
            artifact=self.artifact,
            bindings=self.bindings,
            claims=self.claims,
        )
        payload["unreviewed"] = True
        write_canonical(self.root, self.cell_receipt_path, payload)
        with self.assertRaisesRegex(evidence.EvidenceError, "extra=.*unreviewed"):
            self.validate_cell()

    def test_lane_cell_omission_rejected(self) -> None:
        payload = evidence.lane_receipt_payload(
            lane_id="L00_UNIT",
            lane_order=0,
            lane_spec=self.lane_spec,
            cells=[self.cell],
            bindings=self.bindings,
        )
        payload["cells"] = []
        payload["cell_count"] = 0
        write_canonical(self.root, self.lane_receipt_path, payload)
        with self.assertRaisesRegex(evidence.EvidenceError, "field drifted"):
            self.validate_lane()

    def test_run_seal_order_and_stale_lane_rejected(self) -> None:
        stale_lane = self.lane
        lane_path = self.root / self.lane_receipt_path
        payload = evidence.lane_receipt_payload(
            lane_id="L00_UNIT",
            lane_order=0,
            lane_spec=self.lane_spec,
            cells=[self.cell],
            bindings=self.bindings,
        )
        payload["status"] = "FAIL"
        write_canonical(self.root, self.lane_receipt_path, payload)
        with self.assertRaisesRegex(evidence.EvidenceError, "bound lane receipt drifted"):
            evidence.validate_run_seal(
                self.root,
                seal_path=self.seal_path,
                plan_spec=self.plan_spec,
                lanes=[stale_lane],
                bindings=self.bindings,
            )

    def test_unsafe_paths_and_symlinks_rejected(self) -> None:
        with self.assertRaisesRegex(evidence.EvidenceError, "canonical relative path"):
            evidence.validate_artifact_manifest(
                self.root,
                artifact_root="../escape",
                manifest_path=self.manifest_path,
            )
        target = self.root / self.artifact_root / "process.log"
        link = self.root / self.artifact_root / "linked.log"
        try:
            link.symlink_to(target)
        except (OSError, NotImplementedError):
            self.skipTest("symlinks unavailable")
        with self.assertRaisesRegex(evidence.EvidenceError, "contains a symlink"):
            evidence.validate_artifact_manifest(
                self.root,
                artifact_root=self.artifact_root,
                manifest_path=self.manifest_path,
            )

    def test_duplicate_manifest_row_rejected(self) -> None:
        manifest = self.root / self.manifest_path
        rows = manifest.read_bytes().splitlines(keepends=True)
        manifest.write_bytes(b"".join(rows + rows[1:2]))
        with self.assertRaisesRegex(evidence.EvidenceError, "duplicate or not strictly sorted"):
            evidence.validate_artifact_manifest(
                self.root,
                artifact_root=self.artifact_root,
                manifest_path=self.manifest_path,
            )


class EvidenceStoreTest(unittest.TestCase):
    def test_write_once_store_and_recursive_aggregate(self) -> None:
        with tempfile.TemporaryDirectory(prefix="ka-final-evidence-store.") as temporary:
            root = Path(temporary).resolve(strict=True)
            output = root / "cells/cell-a"
            output.mkdir(parents=True)
            (output / "driver_result.txt").write_text(
                "status=PASS\nfail=0\n", "utf-8",
            )
            bindings = {
                "engine_app_tree_sha256": "1" * 64,
                "execution_plan_sha256": "2" * 64,
            }
            cell_spec = {"id": "cell-a", "edition": "red"}
            lane_spec = {"lane_id": "L00_UNIT", "order": 0, "cells": [cell_spec]}
            plan_spec = {"schema": "unit/v1", "lanes": [lane_spec]}
            store = evidence.EvidenceStore(root, bindings=bindings)
            cell = store.write_cell_evidence(
                lane_id="L00_UNIT",
                lane_order=0,
                cell_id="cell-a",
                cell_order=0,
                cell_spec=cell_spec,
                artifact_root="cells/cell-a",
                claims={"result_sha256": evidence.file_sha256(output / "driver_result.txt")},
            )
            lane = store.write_lane_evidence(
                lane_id="L00_UNIT",
                lane_order=0,
                lane_spec=lane_spec,
                cells=[cell],
            )
            seal = store.write_run_seal(plan_spec=plan_spec, lanes=[lane])
            self.assertEqual(
                store.verify_and_aggregate(
                    seal_path=seal.seal_path,
                    plan_spec=plan_spec,
                    lanes=[lane],
                ).seal_sha256,
                seal.seal_sha256,
            )
            (root / "unbound.txt").write_text("not sealed\n", "utf-8")
            with self.assertRaisesRegex(evidence.EvidenceError, "extra file"):
                store.verify_and_aggregate(
                    seal_path=seal.seal_path,
                    plan_spec=plan_spec,
                    lanes=[lane],
                )
            (root / "unbound.txt").unlink()
            with self.assertRaisesRegex(evidence.EvidenceError, "already exists"):
                evidence.EvidenceStore(root, bindings=bindings).write_cell_evidence(
                    lane_id="L00_UNIT",
                    lane_order=0,
                    cell_id="cell-a",
                    cell_order=0,
                    cell_spec=cell_spec,
                    artifact_root="cells/cell-a",
                    claims={"result_sha256": "3" * 64},
                )
            (output / "driver_result.txt").write_text("status=FAIL\n", "utf-8")
            with self.assertRaisesRegex(evidence.EvidenceError, "complete artifact tree"):
                store.verify_and_aggregate(
                    seal_path=seal.seal_path,
                    plan_spec=plan_spec,
                    lanes=[lane],
                )


if __name__ == "__main__":
    unittest.main(verbosity=2)
