#!/usr/bin/env python3
"""Read and validate the canonical playable-QA test-point manifest."""

from __future__ import annotations

import argparse
import json
import re
import shlex
import sys
from pathlib import Path


VALID_STATUSES = {"ready", "pending"}
ID_RE = re.compile(r"^[a-z0-9][a-z0-9-]*$")
ENV_RE = re.compile(r"^[A-Z][A-Z0-9_]*$")


def load_manifest(path: Path) -> dict:
    with path.open("r", encoding="utf-8") as handle:
        data = json.load(handle)
    if data.get("schemaVersion") != 1:
        raise ValueError("unsupported manifest schemaVersion")
    if not isinstance(data.get("testPoints"), list):
        raise ValueError("testPoints must be an array")
    return data


def validate(data: dict, root: Path | None = None) -> list[str]:
    errors: list[str] = []
    seen_ids: set[str] = set()
    identity_owners: dict[str, str | None] = {}
    seen_orders: set[int] = set()
    prefix = data.get("safety", {}).get("identityPrefix", "")
    normal_identity = data.get("safety", {}).get("normalIdentity")

    for index, point in enumerate(data["testPoints"], 1):
        tag = point.get("id") or f"row-{index}"
        point_id = point.get("id")
        if not isinstance(point_id, str) or not ID_RE.fullmatch(point_id):
            errors.append(f"{tag}: invalid id")
        elif point_id in seen_ids:
            errors.append(f"{tag}: duplicate id")
        else:
            seen_ids.add(point_id)

        status = point.get("status")
        if status not in VALID_STATUSES:
            errors.append(f"{tag}: invalid status {status!r}")
        order = point.get("order")
        if not isinstance(order, int) or order < 1:
            errors.append(f"{tag}: order must be a positive integer")
        elif order in seen_orders:
            errors.append(f"{tag}: duplicate order {order}")
        else:
            seen_orders.add(order)

        for key in ("label", "edition", "identity", "slot", "setupDriver", "start"):
            if not isinstance(point.get(key), str) or not point[key]:
                errors.append(f"{tag}: missing {key}")
        if point.get("edition") not in {"red", "blue", "yellow"}:
            errors.append(f"{tag}: invalid edition")
        identity = point.get("identity")
        if identity == normal_identity:
            errors.append(f"{tag}: normal player identity is forbidden")
        if isinstance(identity, str):
            group = point.get("sharedIdentityGroup")
            prior_group = identity_owners.get(identity)
            if identity in identity_owners and (not group or group != prior_group):
                errors.append(f"{tag}: duplicate identity outside one declared sharedIdentityGroup")
            identity_owners[identity] = group
            if status == "ready" and not identity.startswith(prefix):
                errors.append(f"{tag}: ready identity lacks QA prefix {prefix!r}")

        setup_env = point.get("setupEnv")
        if not isinstance(setup_env, dict):
            errors.append(f"{tag}: setupEnv must be an object")
        else:
            for key, value in setup_env.items():
                if not ENV_RE.fullmatch(key):
                    errors.append(f"{tag}: invalid setup env key {key!r}")
                if not isinstance(value, str):
                    errors.append(f"{tag}: setup env {key} must be a string")

        checks = point.get("checks")
        evidence = point.get("evidence")
        if not isinstance(checks, list) or not all(isinstance(v, str) for v in checks):
            errors.append(f"{tag}: checks must be a string array")
        if not isinstance(evidence, list) or not all(isinstance(v, str) for v in evidence):
            errors.append(f"{tag}: evidence must be a string array")
        if status == "ready" and not (3 <= len(checks or []) <= 6):
            errors.append(f"{tag}: ready point needs 3-6 manual checks")
        if status == "pending" and not point.get("pendingReason"):
            errors.append(f"{tag}: pendingReason is required")

        if root is not None and status == "ready":
            driver = root / point.get("setupDriver", "")
            if not driver.is_file():
                errors.append(f"{tag}: setup driver missing: {driver}")
            for relative in evidence or []:
                if not (root / relative).exists():
                    errors.append(f"{tag}: evidence missing: {relative}")
    return errors


def point_by_id(data: dict, point_id: str) -> dict:
    for point in data["testPoints"]:
        if point.get("id") == point_id:
            return point
    raise KeyError(point_id)


def shell_assignment(name: str, value: object) -> str:
    return f"{name}={shlex.quote(str(value))}"


def emit_shell(point: dict) -> None:
    rows = {
        "TP_ID": point["id"],
        "TP_ORDER": point["order"],
        "TP_STATUS": point["status"],
        "TP_LABEL": point["label"],
        "TP_EDITION": point["edition"],
        "TP_IDENTITY": point["identity"],
        "TP_SLOT": point["slot"],
        "TP_SETUP_DRIVER": point["setupDriver"],
        "TP_START": point["start"],
        "TP_PENDING_REASON": point.get("pendingReason", ""),
    }
    for key, value in rows.items():
        print(shell_assignment(key, value))
    env_values = [f"{key}={value}" for key, value in sorted(point["setupEnv"].items())]
    print("TP_SETUP_ENV=(" + " ".join(shlex.quote(value) for value in env_values) + ")")


def emit_list(data: dict, machine: bool = False) -> None:
    points = sorted(data["testPoints"], key=lambda row: row["order"])
    if machine:
        for point in points:
            print("\t".join((str(point["order"]), point["status"], point["id"], point["label"])))
        return
    print("Kanto Ascendant 6.5 – isolierte spielbare Testpunkte")
    for point in points:
        marker = "BEREIT" if point["status"] == "ready" else "AUSSTEHEND"
        print(f"{point['order']:>2}. [{marker:<10}] {point['label']}  ({point['id']})")
        print(f"    Start: {point['start']}")
        if point["status"] == "pending":
            print(f"    Grund: {point['pendingReason']}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", type=Path, required=True)
    sub = parser.add_subparsers(dest="command", required=True)
    validate_parser = sub.add_parser("validate")
    validate_parser.add_argument("--root", type=Path)
    list_parser = sub.add_parser("list")
    list_parser.add_argument("--machine", action="store_true")
    shell_parser = sub.add_parser("shell")
    shell_parser.add_argument("id")
    args = parser.parse_args()

    try:
        data = load_manifest(args.manifest)
        errors = validate(data, getattr(args, "root", None))
        if errors:
            for error in errors:
                print(f"FEHLER: {error}", file=sys.stderr)
            return 1
        if args.command == "validate":
            print(f"PASS: {len(data['testPoints'])} Testpunkte, Manifest schemaVersion=1")
        elif args.command == "list":
            emit_list(data, args.machine)
        elif args.command == "shell":
            emit_shell(point_by_id(data, args.id))
        return 0
    except (OSError, ValueError, json.JSONDecodeError, KeyError) as exc:
        print(f"FEHLER: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
