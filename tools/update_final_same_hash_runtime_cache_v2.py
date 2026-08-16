#!/usr/bin/env python3
"""Switch the final package gate to the complete R/B/Y v10 runtime cache."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
GATE = ROOT / "qa/blitz_real_save_forensic_20260812/package_candidate"
RECEIPT = GATE / "final_same_hash_receipt.json"
ARCHIVE = GATE / "inputs/imported-rby-runtime-cache-v2.zip"
PROVENANCE = GATE / "inputs/imported-rby-runtime-cache-v2.receipt.json"


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> int:
    receipt = json.loads(RECEIPT.read_text("utf-8"))
    provenance = json.loads(PROVENANCE.read_text("utf-8"))
    receipt["imported_data"] = {
        "path": "inputs/imported-rby-runtime-cache-v2.zip",
        "sha256": digest(ARCHIVE),
        "schema": "gen1recomp-imported-rby-cache/v2",
        "editions": ["red", "blue", "yellow"],
        "contains_raw_rom_image": False,
        "contains_rom_derived_content": True,
        "contains_verbatim_rom_fragments": True,
        "distribution": "private_local_gate_input_only",
        "full_runtime_cache": True,
        "cache_format": "rom-cache-v10",
        "engine_payload_sha256": provenance["engine_payload_sha256"],
        "provenance_receipt": "inputs/imported-rby-runtime-cache-v2.receipt.json",
        "provenance_receipt_sha256": digest(PROVENANCE),
    }
    RECEIPT.write_text(json.dumps(receipt, indent=2, sort_keys=True) + "\n", "utf-8")
    print(f"archive_sha256={receipt['imported_data']['sha256']}")
    print(f"provenance_sha256={receipt['imported_data']['provenance_receipt_sha256']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
