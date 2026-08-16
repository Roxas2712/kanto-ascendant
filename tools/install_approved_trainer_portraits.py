#!/usr/bin/env python3
"""Install the user-approved trainer redraws as versioned live assets.

The approval gallery is the single source of truth.  Red, Blue, Green,
Silver, Kris, Gold and Professor Oak deliberately keep their CURRENT files.
Every other identity is copied to a new versioned filename; no existing
product PNG is overwritten.
"""

from __future__ import annotations

import csv
import hashlib
import shutil
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
GALLERY = ROOT / "qa/trainer_final_user_approval_20260812/MANIFEST.tsv"
LIVE = ROOT / "assets/characters/frlg_trainers"
OUT = ROOT / "qa/trainer_approved_live_integration_20260812"
PROTECTED_STEMS = {"red", "blue", "green", "silver", "kris", "gold", "professor_oak"}


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def live_pair(stem: str) -> tuple[Path, Path]:
    version = "v3" if stem.startswith("elite_four_") else "v2"
    return (
        LIVE / f"{stem}_voxel_front_{version}.png",
        LIVE / f"{stem}_voxel_front_hd_{version}.png",
    )


def safe_copy(source: Path, target: Path) -> None:
    if target.exists():
        if sha256(source) != sha256(target):
            raise RuntimeError(f"refusing to overwrite different live asset: {target}")
        return
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(source, target)


def main() -> None:
    with GALLERY.open(encoding="utf-8", newline="") as handle:
        rows = list(csv.DictReader(handle, delimiter="\t"))
    approved = [
        row for row in rows
        if row["group"] != "fixed" and row["stem"] != "professor_oak"
    ]
    if len(approved) != 41:
        raise RuntimeError(f"approval scope changed: expected 41, got {len(approved)}")

    receipts: list[dict[str, str]] = []
    for row in approved:
        stem = row["stem"]
        if stem in PROTECTED_STEMS:
            raise RuntimeError(f"protected identity entered approval set: {stem}")
        sources = (ROOT / row["candidate_64"], ROOT / row["candidate_128"])
        targets = live_pair(stem)
        for size, source, target in zip(("64", "128"), sources, targets):
            if not source.is_file():
                raise FileNotFoundError(source)
            safe_copy(source, target)
            receipts.append({
                "stem": stem,
                "class_id": row["class_id"],
                "size": size,
                "source": source.relative_to(ROOT).as_posix(),
                "source_sha256": sha256(source),
                "live": target.relative_to(ROOT).as_posix(),
                "live_sha256": sha256(target),
                "authority": row["authority"],
                "authority_sha256": sha256(ROOT / row["authority"]),
                "install_policy": "VERSIONED_COPY_NO_OVERWRITE",
            })

    OUT.mkdir(parents=True, exist_ok=True)
    manifest = OUT / "LIVE_ASSET_MANIFEST.tsv"
    fields = list(receipts[0])
    with manifest.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, delimiter="\t", fieldnames=fields,
                                lineterminator="\n")
        writer.writeheader()
        writer.writerows(receipts)

    approval: list[dict[str, str]] = []
    receipt_by_stem = {row["stem"]: row for row in receipts if row["size"] == "64"}
    receipt_hd_by_stem = {row["stem"]: row for row in receipts if row["size"] == "128"}
    for row in rows:
        stem = row["stem"]
        if stem in PROTECTED_STEMS:
            chosen_64, chosen_128 = row["current_64"], row["current_128"]
            decision = "KEEP_CURRENT"
        else:
            chosen_64 = receipt_by_stem[stem]["live"]
            chosen_128 = receipt_hd_by_stem[stem]["live"]
            decision = "PROMOTE_NEW_CANDIDATE"
        approval.append({
            "stem": stem,
            "class_id": row["class_id"],
            "decision": decision,
            "chosen_64": chosen_64,
            "chosen_64_sha256": sha256(ROOT / chosen_64),
            "chosen_128": chosen_128,
            "chosen_128_sha256": sha256(ROOT / chosen_128),
            "rollback_64": row["current_64"],
            "rollback_64_sha256": sha256(ROOT / row["current_64"]),
            "rollback_128": row["current_128"],
            "rollback_128_sha256": sha256(ROOT / row["current_128"]),
            "frlg_authority": row["authority"],
            "frlg_authority_sha256": sha256(ROOT / row["authority"]),
        })
    approval_path = OUT / "APPROVAL_RECORD.tsv"
    approval_fields = list(approval[0])
    with approval_path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, delimiter="\t",
                                fieldnames=approval_fields,
                                lineterminator="\n")
        writer.writeheader()
        writer.writerows(approval)

    print(f"INSTALLED {len(approved)} APPROVED IDENTITIES / {len(receipts)} FILES; "
          f"RECORDED {len(approval)} DECISIONS")


if __name__ == "__main__":
    main()
