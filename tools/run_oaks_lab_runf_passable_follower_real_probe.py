#!/usr/bin/env python3
"""Fail-closed host runner for the isolated Run-F Oak Lab real-LÖVE probe.

The default mode only prints the post-F checklist.  The mutation-capable mode
is deliberately verbose and deliberately narrow: it becomes available only
after Run F has emitted its formal timeout receipt, reaped its process group,
and left both route.log and the exact fused identity stable across two samples.

The active Run-F identity is a read-only source.  This program has no cleanup,
replacement, rename, chmod, or write operation aimed at that source.  All
created state is confined to one fresh /private/tmp probe root and one fresh,
non-planned fused Application Support identity.  A partial run is retained as
FAIL evidence rather than deleted or silently retried.
"""

from __future__ import annotations

import argparse
import binascii
import hashlib
import json
import os
from pathlib import Path
import pwd
import re
import shutil
import signal
import stat
import struct
import subprocess
import sys
import time
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
DRIVER_SOURCE = ROOT / "tests/oaks_lab_runf_passable_follower_real_probe.lua"
DRIVER_EXPECTED_SHA256 = (
    "ff2b215dd117860b5fcfe7d0fe3b101daef2d6c1a43c25d6de46d10f437881d8"
)

RUN_F_RUNTIME = Path("/private/tmp/ka-final-same-hash.ka650-rc28-20260813-f")
RUN_F_EVIDENCE = Path(
    "/private/tmp/ka-final-same-hash-evidence.ka650-rc28-20260813-f"
)
RUN_F_ENGINE = RUN_F_RUNTIME / "engine.app"
RUN_F_CLOSURE = RUN_F_RUNTIME / "closures/base_deutsch/red"
RUN_F_FAILURE_RECEIPT = RUN_F_EVIDENCE / "failures/L01_BOOT_UPGRADE_RULES.json"
RUN_F_ROUTE_LOG = (
    RUN_F_EVIDENCE / "cells/l01-first-badge-red/route.log"
)
RUN_F_PASS_LOG = (
    RUN_F_EVIDENCE
    / "cells/l01-first-badge-red/pass_logs/000-driver.log"
)
RUN_F_GO_TOKEN = Path(
    "/private/tmp/ka-run-f-formal-stop-go.ka650-rc28-20260813-f.json"
)

ACCOUNT_HOME = Path("/Users/maarten")
APPLICATION_SUPPORT = ACCOUNT_HOME / "Library/Application Support"
RUN_F_IDENTITY_NAME = "ka65-final-first-badge-red"
RUN_F_IDENTITY = APPLICATION_SUPPORT / RUN_F_IDENTITY_NAME
RUN_F_CONVENTIONAL_IDENTITY = (
    APPLICATION_SUPPORT / "LOVE" / RUN_F_IDENTITY_NAME
)
SAVE_RELATIVE = Path("saves/red/slot65firstbadge_red.lua")
SAVE_BACKUP_RELATIVE = Path("saves/red/slot65firstbadge_red.lua.bak")

PROBE_IDENTITY_NAME = "ka65-probe-oak-follower-passable-runf-20260813-01"
PROBE_IDENTITY = APPLICATION_SUPPORT / PROBE_IDENTITY_NAME
PROBE_CONVENTIONAL_IDENTITY = (
    APPLICATION_SUPPORT / "LOVE" / PROBE_IDENTITY_NAME
)
PROBE_ROOT = Path(
    "/private/tmp/ka-oak-follower-passable-runf-probe.ka650-rc28-20260813-01"
)
SNAPSHOT_IDENTITY = PROBE_ROOT / "source_identity_snapshot"
ISOLATED_ENGINE = PROBE_ROOT / "engine.app"
ISOLATED_CLOSURE = PROBE_ROOT / "game"
ISOLATED_DRIVER = PROBE_ROOT / "qa/oaks_lab_runf_passable_follower_real_probe.lua"
OUTPUT_DIR = PROBE_ROOT / "output"
PROCESS_LOG = OUTPUT_DIR / "process.log"
HOST_RECEIPT = PROBE_ROOT / "host_probe_receipt.json"

HOST_SCHEMA = "ka-oaks-lab-passable-follower-host-probe/v1"
DRIVER_SCHEMA = "ka-oaks-lab-passable-follower-real-probe/v1"
GO_SCHEMA = "ka-run-f-formal-stop-go/v1"
STABILITY_SECONDS = 5
PROCESS_TIMEOUT_SECONDS = 120
HEX64 = re.compile(r"^[0-9a-f]{64}$")

PLAN_TEXT = f"""Post-F Oak-Lab-Probe (standardmäßig nur Plan)

1. Nichts starten, solange der formale Run-F-Fehlerbeleg fehlt und der
   koordinierende Parent den separaten atomaren GO-Beleg nach beendetem
   Exec/Session-Wait nicht ausdrücklich erzeugt hat.
   Erwartet: {RUN_F_FAILURE_RECEIPT}
   GO-Token: {RUN_F_GO_TOKEN}
   Der Beleg muss PROCESS_TIMEOUT, l01-first-badge-red sowie einen geleerten
   und abgeholten isolierten Prozessverband ausweisen. Das GO-Token bindet
   SHA-256 von Fehlerbeleg, route.log und 000-driver.log und attestiert den
   beendeten/reapten Orchestrator sowie abwesendes Run-F-LÖVE.
2. GO-Token, route.log, 000-driver.log, Fehlerbeleg und die komplette aktive
   Identität werden zweimal mit
   {STABILITY_SECONDS} Sekunden Abstand gehasht; beide Proben müssen identisch sein.
3. Haupt- und Backup-Spielstand müssen reguläre Dateien mit OAKS_LAB (6,2),
   facing=down sein. In der Quellidentität darf keine *.tmp-Datei liegen.
4. Diese drei Ziele müssen vollständig fehlen; es wird nie aufgeräumt/ersetzt:
   - {PROBE_ROOT}
   - {PROBE_IDENTITY}
   - {PROBE_CONVENTIONAL_IDENTITY}
5. Erst danach exklusiv erzeugen: Read-only-Snapshot der F-Identität,
   isolierte Kopien von engine.app und base/deutsch/red, kopierten QA-Treiber,
   frische Probe-Identität und frisches Output-Verzeichnis. Jede Kopie wird
   gegen den Inhalts-Hash ihrer Quelle geprüft; die F-Quelle wird erneut gehasht.
6. Normaler LÖVE-Start ohne Shell und in eigener Prozesssitzung:
   POKEPORT_IDENTITY={PROBE_IDENTITY_NAME}
   POKEPORT_VERSION=red, POKEPORT_TOUCH=0, POKEPORT_SPEED=8
   POKEPORT_DRIVER={ISOLATED_DRIVER}
   KA_OAK_PROBE_OUTPUT_DIR={OUTPUT_DIR}
   KA_OAK_PROBE_SOURCE_SAVE_SHA256=<gemessener SHA-256>
   KA_OAK_PROBE_CLOSURE_TREE_SHA256=<gemessener Baum-SHA-256>
   {ISOLATED_ENGINE / 'Contents/MacOS/love'} --game {ISOLATED_CLOSURE}
7. Danach fail-closed prüfen: PASS-Beleg, exakt zwei valide/verschiedene PNGs,
   (6,2)->(7,2), follower/passable=true, ambient=false,
   Collision.occupied=nil und echter RIGHT-Queue-Input.
8. Abschließend müssen Ziel-Spielstände und importierter red/-Cache unverändert,
   LOVE/<Probe-ID> weiter abwesend und die komplette aktive F-Identität sowie
   die Run-F-Engine/Closure bitgleich zu den Vorproben sein.

Plan anzeigen (keine Dateisystemprüfung, keine Schreiboperation):
  python3 -B tools/{Path(__file__).name} --plan

Erst NACH formalem F-Stopp ausführen (erzeugt isolierte Probe-Artefakte):
  python3 -B tools/{Path(__file__).name} --execute-after-formal-stop
"""


class ProbeError(RuntimeError):
    """A fail-closed precondition or evidence check failed."""


def fail(message: str) -> None:
    raise ProbeError(message)


def sha256_bytes(payload: bytes) -> str:
    return hashlib.sha256(payload).hexdigest()


def canonical_sha256(value: Any) -> str:
    payload = json.dumps(
        value, ensure_ascii=False, sort_keys=True, separators=(",", ":")
    ).encode("utf-8")
    return sha256_bytes(payload)


def lexists(path: Path) -> bool:
    return os.path.lexists(os.fspath(path))


def is_within(path: Path, root: Path) -> bool:
    try:
        return os.path.commonpath((os.fspath(path), os.fspath(root))) == os.fspath(root)
    except ValueError:
        return False


def require_authorized_write(path: Path) -> None:
    """Permit writes only below the disposable root or exact probe identity."""
    absolute = Path(os.path.abspath(os.fspath(path)))
    allowed = (PROBE_ROOT, PROBE_IDENTITY)
    if not any(absolute == root or is_within(absolute, root) for root in allowed):
        fail(f"write target is outside disposable probe surfaces: {absolute}")
    if absolute == RUN_F_IDENTITY or is_within(absolute, RUN_F_IDENTITY):
        fail("active Run-F identity can never be a write target")
    if absolute == RUN_F_CONVENTIONAL_IDENTITY or is_within(
        absolute, RUN_F_CONVENTIONAL_IDENTITY
    ):
        fail("active Run-F conventional identity can never be a write target")


def require_regular(path: Path, label: str) -> os.stat_result:
    try:
        info = os.lstat(path)
    except OSError as exc:
        fail(f"{label} is unavailable: {exc.__class__.__name__}")
    if not stat.S_ISREG(info.st_mode):
        fail(f"{label} is not one regular, non-symlink file")
    return info


def require_directory(path: Path, label: str) -> os.stat_result:
    try:
        info = os.lstat(path)
    except OSError as exc:
        fail(f"{label} is unavailable: {exc.__class__.__name__}")
    if not stat.S_ISDIR(info.st_mode):
        fail(f"{label} is not one real, non-symlink directory")
    return info


def read_regular_bytes(path: Path, label: str) -> bytes:
    """Open read-only/no-follow and reject an in-flight replacement or rewrite."""
    before = require_regular(path, label)
    flags = os.O_RDONLY
    if hasattr(os, "O_NOFOLLOW"):
        flags |= os.O_NOFOLLOW
    try:
        descriptor = os.open(path, flags)
    except OSError as exc:
        fail(f"{label} cannot be opened read-only: {exc.__class__.__name__}")
    try:
        opened = os.fstat(descriptor)
        if (opened.st_dev, opened.st_ino) != (before.st_dev, before.st_ino):
            fail(f"{label} changed while it was opened")
        chunks: list[bytes] = []
        while True:
            chunk = os.read(descriptor, 1024 * 1024)
            if not chunk:
                break
            chunks.append(chunk)
        after = os.fstat(descriptor)
    finally:
        os.close(descriptor)
    immutable_fields = ("st_dev", "st_ino", "st_size", "st_mtime_ns")
    if any(getattr(opened, field) != getattr(after, field) for field in immutable_fields):
        fail(f"{label} changed while it was read")
    payload = b"".join(chunks)
    if len(payload) != after.st_size:
        fail(f"{label} byte count changed while it was read")
    return payload


def file_fingerprint(path: Path, label: str) -> dict[str, Any]:
    before = require_regular(path, label)
    payload = read_regular_bytes(path, label)
    info = require_regular(path, label)
    if (
        before.st_dev,
        before.st_ino,
        before.st_size,
        before.st_mtime_ns,
    ) != (
        info.st_dev,
        info.st_ino,
        info.st_size,
        info.st_mtime_ns,
    ):
        fail(f"{label} changed across fingerprint read")
    return {
        "bytes": len(payload),
        "mode": stat.S_IMODE(info.st_mode),
        "mtime_ns": info.st_mtime_ns,
        "sha256": sha256_bytes(payload),
    }


def _safe_symlink_target(root: Path, link: Path, target: str, label: str) -> None:
    if os.path.isabs(target):
        fail(f"{label} contains an absolute symlink: {link}")
    try:
        resolved_root = root.resolve(strict=True)
        resolved_target = (link.parent / target).resolve(strict=True)
    except OSError as exc:
        fail(f"{label} contains a broken symlink: {link}: {exc.__class__.__name__}")
    if not is_within(resolved_target, resolved_root):
        fail(f"{label} contains a symlink escaping its root: {link}")


def scan_tree(
    root: Path,
    label: str,
    *,
    allow_safe_symlinks: bool,
    reject_tmp: bool,
) -> dict[str, dict[str, Any]]:
    """Build a race-aware, non-following tree manifest.

    Rows contain content and stability metadata.  ``tree_digest(..., False)``
    intentionally omits mtimes, while ``tree_digest(..., True)`` detects a
    writer that rewrote identical bytes between Run-F stability samples.
    """
    require_directory(root, label)
    rows: dict[str, dict[str, Any]] = {}

    def visit(directory: Path, relative: Path) -> None:
        before = os.lstat(directory)
        if not stat.S_ISDIR(before.st_mode):
            fail(f"{label} directory changed type during scan: {relative}")
        try:
            with os.scandir(directory) as iterator:
                entries = sorted(iterator, key=lambda item: item.name)
        except OSError as exc:
            fail(f"{label} cannot enumerate {relative}: {exc.__class__.__name__}")
        for entry in entries:
            rel = relative / entry.name
            rel_text = rel.as_posix()
            if reject_tmp and any(part.endswith(".tmp") for part in rel.parts):
                fail(f"{label} contains forbidden staged .tmp state: {rel_text}")
            child = Path(entry.path)
            try:
                info = os.lstat(child)
            except OSError as exc:
                fail(f"{label} entry vanished during scan: {rel_text}: {exc.__class__.__name__}")
            common = {
                "mode": stat.S_IMODE(info.st_mode),
                "mtime_ns": info.st_mtime_ns,
            }
            if stat.S_ISDIR(info.st_mode):
                rows[rel_text] = {"kind": "directory", **common}
                visit(child, rel)
            elif stat.S_ISREG(info.st_mode):
                payload = read_regular_bytes(child, f"{label}/{rel_text}")
                after = os.lstat(child)
                if (
                    info.st_dev,
                    info.st_ino,
                    info.st_size,
                    info.st_mtime_ns,
                ) != (
                    after.st_dev,
                    after.st_ino,
                    after.st_size,
                    after.st_mtime_ns,
                ):
                    fail(f"{label} file changed during scan: {rel_text}")
                rows[rel_text] = {
                    "kind": "file",
                    **common,
                    "bytes": len(payload),
                    "sha256": sha256_bytes(payload),
                }
            elif stat.S_ISLNK(info.st_mode):
                if not allow_safe_symlinks:
                    fail(f"{label} contains forbidden symlink: {rel_text}")
                target = os.readlink(child)
                _safe_symlink_target(root, child, target, label)
                rows[rel_text] = {
                    "kind": "symlink",
                    **common,
                    "target": target,
                }
            else:
                fail(f"{label} contains unsupported special entry: {rel_text}")
        after = os.lstat(directory)
        if (
            before.st_dev,
            before.st_ino,
            before.st_mtime_ns,
        ) != (
            after.st_dev,
            after.st_ino,
            after.st_mtime_ns,
        ):
            fail(f"{label} directory changed during scan: {relative}")

    visit(root, Path())
    return rows


def tree_digest(rows: dict[str, dict[str, Any]], include_stability: bool) -> str:
    selected: dict[str, dict[str, Any]] = {}
    for relative, row in rows.items():
        selected[relative] = {
            key: value
            for key, value in row.items()
            if include_stability or key != "mtime_ns"
        }
    return canonical_sha256(selected)


def content_diff(
    before: dict[str, dict[str, Any]], after: dict[str, dict[str, Any]]
) -> list[str]:
    paths = sorted(set(before) | set(after))
    changed: list[str] = []
    for path in paths:
        left = {k: v for k, v in before.get(path, {}).items() if k != "mtime_ns"}
        right = {k: v for k, v in after.get(path, {}).items() if k != "mtime_ns"}
        if left != right:
            changed.append(path)
    return changed


def require_absent(path: Path, label: str) -> None:
    if lexists(path):
        fail(f"{label} must be fresh and absent; refusing cleanup/replacement: {path}")


def require_all_fresh() -> None:
    require_absent(PROBE_ROOT, "probe root")
    require_absent(PROBE_IDENTITY, "probe fused identity")
    require_absent(PROBE_CONVENTIONAL_IDENTITY, "probe conventional LOVE identity")


def assert_static_paths() -> None:
    try:
        actual_home = Path(pwd.getpwuid(os.getuid()).pw_dir).resolve(strict=True)
    except (KeyError, OSError) as exc:
        fail(f"cannot resolve executing account home: {exc.__class__.__name__}")
    if actual_home != ACCOUNT_HOME:
        fail(f"runner is bound to {ACCOUNT_HOME}, not {actual_home}")
    if PROBE_IDENTITY_NAME == RUN_F_IDENTITY_NAME:
        fail("probe identity unexpectedly equals active Run-F identity")
    if any(
        left == right
        for left in (PROBE_ROOT, PROBE_IDENTITY, PROBE_CONVENTIONAL_IDENTITY)
        for right in (
            RUN_F_RUNTIME,
            RUN_F_EVIDENCE,
            RUN_F_IDENTITY,
            RUN_F_CONVENTIONAL_IDENTITY,
        )
    ):
        fail("a disposable target aliases an active Run-F surface")
    require_directory(APPLICATION_SUPPORT, "Application Support parent")
    if APPLICATION_SUPPORT.resolve(strict=True) != APPLICATION_SUPPORT:
        fail("Application Support parent is not the exact non-symlink path")
    love_parent = APPLICATION_SUPPORT / "LOVE"
    if lexists(love_parent):
        require_directory(love_parent, "conventional LOVE parent")
    require_directory(RUN_F_RUNTIME, "Run-F runtime")
    require_directory(RUN_F_EVIDENCE, "Run-F evidence")
    require_directory(RUN_F_IDENTITY, "active Run-F fused identity")
    require_absent(
        RUN_F_CONVENTIONAL_IDENTITY,
        "active Run-F conventional LOVE identity",
    )


def validate_driver_source() -> str:
    digest = sha256_bytes(read_regular_bytes(DRIVER_SOURCE, "probe driver source"))
    if digest != DRIVER_EXPECTED_SHA256:
        fail(
            "probe driver source drifted: "
            f"expected {DRIVER_EXPECTED_SHA256}, got {digest}"
        )
    return digest


def validate_failure_receipt() -> tuple[dict[str, Any], dict[str, Any]]:
    fingerprint = file_fingerprint(RUN_F_FAILURE_RECEIPT, "formal Run-F failure receipt")
    try:
        receipt = json.loads(
            read_regular_bytes(
                RUN_F_FAILURE_RECEIPT, "formal Run-F failure receipt"
            ).decode("utf-8")
        )
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        fail(f"formal Run-F failure receipt is invalid JSON: {exc.__class__.__name__}")
    if not isinstance(receipt, dict):
        fail("formal Run-F failure receipt is not an object")
    exact = {
        "schema": "ka-final-lane-failure/v2",
        "status": "FAIL",
        "defect": "PROCESS_TIMEOUT",
        "lane_id": "L01_BOOT_UPGRADE_RULES",
        "cell_id": "l01-first-badge-red",
        "identity": RUN_F_IDENTITY_NAME,
        "edition": "red",
    }
    for key, expected in exact.items():
        if receipt.get(key) != expected:
            fail(f"formal Run-F failure receipt has wrong {key}: {receipt.get(key)!r}")
    termination = receipt.get("process_group_termination")
    if not isinstance(termination, dict) or any(
        termination.get(key) != expected
        for key, expected in {
            "group_empty_verified": True,
            "leader_reaped": True,
            "process_group": "isolated_session",
        }.items()
    ):
        fail("formal Run-F failure receipt does not prove an empty/reaped process group")
    integrity = receipt.get("post_timeout_integrity")
    if not isinstance(integrity, dict) or any(
        not isinstance(integrity.get(key), dict)
        or integrity[key].get("status") != "PASS"
        for key in ("identity_cache", "immutable_runtime")
    ):
        fail("formal Run-F failure receipt lacks PASS post-timeout integrity")
    if file_fingerprint(
        RUN_F_FAILURE_RECEIPT, "formal Run-F failure receipt coherence"
    ) != fingerprint:
        fail("formal Run-F failure receipt changed while it was validated")
    return receipt, fingerprint


def validate_parent_go_token(
    failure: dict[str, Any],
    route: dict[str, Any],
    pass_log: dict[str, Any],
) -> tuple[dict[str, Any], dict[str, Any]]:
    """Require the coordinator's independent, post-session atomic GO token.

    This token is intentionally not created by this runner.  Its presence is
    the parent/coordinator boundary proving that the yielded Run-F exec cell
    has ended, not merely that a child happened to emit a failure JSON while
    an outer orchestration process was still alive.
    """
    fingerprint = file_fingerprint(RUN_F_GO_TOKEN, "parent formal-stop GO token")
    try:
        token = json.loads(
            read_regular_bytes(
                RUN_F_GO_TOKEN, "parent formal-stop GO token"
            ).decode("utf-8")
        )
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        fail(f"parent formal-stop GO token is invalid JSON: {exc.__class__.__name__}")
    if not isinstance(token, dict):
        fail("parent formal-stop GO token is not an object")
    expected = {
        "schema": GO_SCHEMA,
        "status": "GO",
        "run_id": "ka650-rc28-20260813-f",
        "runtime": str(RUN_F_RUNTIME),
        "evidence": str(RUN_F_EVIDENCE),
        "active_identity": RUN_F_IDENTITY_NAME,
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
    if set(token) != set(expected):
        fail(
            "parent formal-stop GO token has non-exact fields: "
            f"expected {sorted(expected)}, got {sorted(token)}"
        )
    for key, expected_value in expected.items():
        if token.get(key) != expected_value:
            fail(f"parent formal-stop GO token has wrong {key}: {token.get(key)!r}")
    newest_bound_mtime = max(
        failure["mtime_ns"], route["mtime_ns"], pass_log["mtime_ns"]
    )
    if fingerprint["mtime_ns"] < newest_bound_mtime:
        fail("parent formal-stop GO token predates one of its bound Run-F artifacts")
    staged = RUN_F_GO_TOKEN.with_name(f".{RUN_F_GO_TOKEN.name}.new")
    if lexists(staged):
        fail("parent formal-stop GO token still has a staging sibling")
    if file_fingerprint(
        RUN_F_GO_TOKEN, "parent formal-stop GO token coherence"
    ) != fingerprint:
        fail("parent formal-stop GO token changed while it was validated")
    return token, fingerprint


def related_processes() -> list[dict[str, Any]]:
    """Return only Run-F writers, never generic readers/monitoring commands."""
    try:
        completed = subprocess.run(
            ["/bin/ps", "-axww", "-o", "pid=,ppid=,pgid=,command="],
            check=True,
            capture_output=True,
            text=True,
            timeout=10,
            env={
                "PATH": "/usr/bin:/bin:/usr/sbin:/sbin",
                "LANG": "C",
                "LC_ALL": "C",
            },
        )
    except (OSError, subprocess.SubprocessError) as exc:
        fail(f"cannot audit Run-F process table: {exc.__class__.__name__}")
    related: list[dict[str, Any]] = []
    for raw in completed.stdout.splitlines():
        fields = raw.strip().split(None, 3)
        if len(fields) != 4 or not all(part.isdigit() for part in fields[:3]):
            continue
        command = fields[3]
        touches_f = str(RUN_F_RUNTIME) in command or str(RUN_F_EVIDENCE) in command
        is_writer = (
            "Contents/MacOS/love" in command
            or "final_same_hash_orchestrator.py" in command
        )
        if touches_f and is_writer:
            related.append(
                {
                    "pid": int(fields[0]),
                    "ppid": int(fields[1]),
                    "pgid": int(fields[2]),
                    "kind": (
                        "love" if "Contents/MacOS/love" in command else "orchestrator"
                    ),
                }
            )
    return related


def require_run_f_process_quiescent() -> None:
    found = related_processes()
    if found:
        summary = ", ".join(f"{row['kind']} pid={row['pid']}" for row in found)
        fail(f"Run F is still active: {summary}")


def validate_exact_save_state(path: Path, label: str) -> None:
    try:
        source = read_regular_bytes(path, label).decode("utf-8")
    except UnicodeDecodeError:
        fail(f"{label} is not UTF-8 Lua")
    matches = re.findall(r"\n  player = \{\n(.*?)\n  \},", source, re.DOTALL)
    if len(matches) != 1:
        fail(f"{label} does not contain exactly one flat player table")
    player = matches[0]
    required = (
        '    facing = "down",',
        '    map = "OAKS_LAB",',
        "    x = 6,",
        "    y = 2,",
    )
    if any(row not in player for row in required):
        fail(f"{label} is not exact OAKS_LAB (6,2), facing=down")


def identity_sample(sample_name: str) -> dict[str, Any]:
    rows = scan_tree(
        RUN_F_IDENTITY,
        f"active Run-F identity sample {sample_name}",
        allow_safe_symlinks=False,
        reject_tmp=True,
    )
    main = file_fingerprint(RUN_F_IDENTITY / SAVE_RELATIVE, f"main save {sample_name}")
    backup = file_fingerprint(
        RUN_F_IDENTITY / SAVE_BACKUP_RELATIVE, f"backup save {sample_name}"
    )
    validate_exact_save_state(RUN_F_IDENTITY / SAVE_RELATIVE, f"main save {sample_name}")
    validate_exact_save_state(
        RUN_F_IDENTITY / SAVE_BACKUP_RELATIVE, f"backup save {sample_name}"
    )
    main_after_validation = file_fingerprint(
        RUN_F_IDENTITY / SAVE_RELATIVE, f"main save {sample_name} coherence"
    )
    backup_after_validation = file_fingerprint(
        RUN_F_IDENTITY / SAVE_BACKUP_RELATIVE,
        f"backup save {sample_name} coherence",
    )
    if main != main_after_validation or backup != backup_after_validation:
        fail(f"Run-F save changed inside identity sample {sample_name}")
    for relative, fingerprint in (
        (SAVE_RELATIVE.as_posix(), main),
        (SAVE_BACKUP_RELATIVE.as_posix(), backup),
    ):
        row = rows.get(relative)
        if (
            not isinstance(row, dict)
            or row.get("kind") != "file"
            or row.get("sha256") != fingerprint["sha256"]
            or row.get("bytes") != fingerprint["bytes"]
            or row.get("mtime_ns") != fingerprint["mtime_ns"]
        ):
            fail(f"Run-F tree/save sample is incoherent: {relative}")
    return {
        "rows": rows,
        "content_sha256": tree_digest(rows, False),
        "stability_sha256": tree_digest(rows, True),
        "main_save": main,
        "backup_save": backup,
    }


def stable_run_f_sample() -> dict[str, Any]:
    """Require parent GO plus two identical log/save/identity observations."""
    require_run_f_process_quiescent()
    receipt, receipt_one = validate_failure_receipt()
    route_one = file_fingerprint(RUN_F_ROUTE_LOG, "Run-F route.log sample one")
    pass_one = file_fingerprint(RUN_F_PASS_LOG, "Run-F pass log sample one")
    go_token, go_one = validate_parent_go_token(receipt_one, route_one, pass_one)
    identity_one = identity_sample("one")
    time.sleep(STABILITY_SECONDS)
    require_run_f_process_quiescent()
    _, receipt_two = validate_failure_receipt()
    route_two = file_fingerprint(RUN_F_ROUTE_LOG, "Run-F route.log sample two")
    pass_two = file_fingerprint(RUN_F_PASS_LOG, "Run-F pass log sample two")
    _, go_two = validate_parent_go_token(receipt_two, route_two, pass_two)
    identity_two = identity_sample("two")
    if receipt_one != receipt_two:
        fail("formal Run-F failure receipt changed between stability samples")
    if route_one != route_two:
        fail("Run-F route.log changed between stability samples")
    if pass_one != pass_two:
        fail("Run-F pass log changed between stability samples")
    if go_one != go_two:
        fail("parent formal-stop GO token changed between stability samples")
    if identity_one["stability_sha256"] != identity_two["stability_sha256"]:
        fail("active Run-F identity changed between stability samples")
    if identity_one["main_save"] != identity_two["main_save"]:
        fail("Run-F main save changed between stability samples")
    if identity_one["backup_save"] != identity_two["backup_save"]:
        fail("Run-F backup save changed between stability samples")
    return {
        **identity_two,
        "formal_failure": receipt,
        "formal_failure_fingerprint": receipt_two,
        "route_log_fingerprint": route_two,
        "pass_log_fingerprint": pass_two,
        "parent_go_token": go_token,
        "parent_go_token_fingerprint": go_two,
    }


def write_json_atomic(path: Path, value: dict[str, Any]) -> None:
    require_authorized_write(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    stage = path.with_name(f".{path.name}.new")
    if lexists(stage):
        fail(f"receipt staging path unexpectedly exists: {stage}")
    payload = (
        json.dumps(value, ensure_ascii=False, indent=2, sort_keys=True) + "\n"
    ).encode("utf-8")
    descriptor = os.open(stage, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    try:
        offset = 0
        while offset < len(payload):
            written = os.write(descriptor, payload[offset:])
            if written <= 0:
                fail("host receipt staging write made no progress")
            offset += written
        os.fsync(descriptor)
    finally:
        os.close(descriptor)
    os.replace(stage, path)
    if hasattr(os, "O_DIRECTORY"):
        directory = os.open(path.parent, os.O_RDONLY | os.O_DIRECTORY)
        try:
            os.fsync(directory)
        finally:
            os.close(directory)


class HostReceipt:
    def __init__(self) -> None:
        self.value: dict[str, Any] = {
            "schema": HOST_SCHEMA,
            "status": "FAIL",
            "phase": "probe-root-created",
            "fail": 1,
            "probe_identity": PROBE_IDENTITY_NAME,
            "active_run_f_identity": RUN_F_IDENTITY_NAME,
            "active_run_f_identity_write_operations": 0,
            "probe_root": str(PROBE_ROOT),
        }
        write_json_atomic(HOST_RECEIPT, self.value)

    def arm(self, phase: str, **extra: Any) -> None:
        self.value.update(extra)
        self.value.update({"status": "FAIL", "fail": 1, "phase": phase})
        self.value.pop("error", None)
        write_json_atomic(HOST_RECEIPT, self.value)

    def failed(self, phase: str, error: str) -> None:
        self.value.update(
            {
                "status": "FAIL",
                "fail": 1,
                "phase": phase,
                "error": error.replace("\n", " ")[:2000],
            }
        )
        write_json_atomic(HOST_RECEIPT, self.value)

    def passed(self, **extra: Any) -> None:
        self.value.update(extra)
        self.value.update({"status": "PASS", "fail": 0, "phase": "complete"})
        self.value.pop("error", None)
        write_json_atomic(HOST_RECEIPT, self.value)


def copy_tree_exclusive(source: Path, destination: Path, *, symlinks: bool) -> None:
    require_authorized_write(destination)
    require_absent(destination, f"copy destination {destination.name}")
    try:
        shutil.copytree(source, destination, symlinks=symlinks, copy_function=shutil.copy2)
    except OSError as exc:
        fail(f"copy into {destination} failed: {exc.__class__.__name__}: {exc}")


def copy_file_exclusive(source: Path, destination: Path) -> None:
    require_authorized_write(destination)
    require_absent(destination, f"copy destination {destination.name}")
    destination.parent.mkdir(parents=True, exist_ok=True)
    try:
        shutil.copy2(source, destination, follow_symlinks=False)
    except OSError as exc:
        fail(f"copy into {destination} failed: {exc.__class__.__name__}: {exc}")


def require_same_tree(
    expected_rows: dict[str, dict[str, Any]],
    actual_root: Path,
    label: str,
    *,
    allow_safe_symlinks: bool,
    reject_tmp: bool,
) -> dict[str, dict[str, Any]]:
    actual = scan_tree(
        actual_root,
        label,
        allow_safe_symlinks=allow_safe_symlinks,
        reject_tmp=reject_tmp,
    )
    if tree_digest(expected_rows, False) != tree_digest(actual, False):
        changed = content_diff(expected_rows, actual)
        fail(f"{label} differs from source copy: {changed[:8]}")
    return actual


def parse_driver_result(path: Path) -> dict[str, str]:
    try:
        text = read_regular_bytes(path, "driver result").decode("utf-8")
    except UnicodeDecodeError:
        fail("driver result is not UTF-8")
    rows: dict[str, str] = {}
    for number, line in enumerate(text.splitlines(), 1):
        if not line or "=" not in line:
            fail(f"driver result has malformed line {number}")
        key, value = line.split("=", 1)
        if not re.fullmatch(r"[a-z][a-z0-9_]*", key) or key in rows:
            fail(f"driver result has invalid/duplicate key on line {number}")
        rows[key] = value
    expected = {
        "schema": DRIVER_SCHEMA,
        "status": "PASS",
        "fail": "0",
        "phase": "complete",
        "expected_identity": PROBE_IDENTITY_NAME,
        "env_identity": PROBE_IDENTITY_NAME,
        "love_identity": PROBE_IDENTITY_NAME,
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
    for key, expected_value in expected.items():
        if rows.get(key) != expected_value:
            fail(f"driver result has wrong {key}: {rows.get(key)!r}")
    for key in ("source_save_sha256", "closure_tree_sha256"):
        if not HEX64.fullmatch(rows.get(key, "")):
            fail(f"driver result lacks valid {key}")
    return rows


def validate_png(path: Path, label: str) -> dict[str, Any]:
    payload = read_regular_bytes(path, label)
    if len(payload) < 1000 or not payload.startswith(b"\x89PNG\r\n\x1a\n"):
        fail(f"{label} is not a non-empty PNG")
    offset = 8
    chunks: list[bytes] = []
    width = height = 0
    saw_idat = False
    saw_iend = False
    while offset < len(payload):
        if offset + 12 > len(payload):
            fail(f"{label} has a truncated PNG chunk")
        length = struct.unpack(">I", payload[offset : offset + 4])[0]
        kind = payload[offset + 4 : offset + 8]
        end = offset + 12 + length
        if end > len(payload):
            fail(f"{label} has a truncated PNG payload")
        data = payload[offset + 8 : offset + 8 + length]
        expected_crc = struct.unpack(">I", payload[offset + 8 + length : end])[0]
        actual_crc = binascii.crc32(kind + data) & 0xFFFFFFFF
        if actual_crc != expected_crc:
            fail(f"{label} has an invalid PNG CRC")
        chunks.append(kind)
        if len(chunks) == 1:
            if kind != b"IHDR" or length != 13:
                fail(f"{label} does not start with a valid IHDR")
            width, height = struct.unpack(">II", data[:8])
            if not (1 <= width <= 8192 and 1 <= height <= 8192):
                fail(f"{label} has implausible dimensions {width}x{height}")
        if kind == b"IDAT":
            saw_idat = True
        if kind == b"IEND":
            if length != 0:
                fail(f"{label} has malformed IEND")
            saw_iend = True
            offset = end
            break
        offset = end
    if not saw_idat or not saw_iend or offset != len(payload):
        fail(f"{label} lacks complete IDAT/IEND structure")
    return {
        "bytes": len(payload),
        "width": width,
        "height": height,
        "sha256": sha256_bytes(payload),
    }


def run_managed_love(env: dict[str, str]) -> int:
    require_authorized_write(PROCESS_LOG)
    require_absent(PROCESS_LOG, "probe process log")
    command = [
        str(ISOLATED_ENGINE / "Contents/MacOS/love"),
        "--game",
        str(ISOLATED_CLOSURE),
    ]
    with PROCESS_LOG.open("xb") as stream:
        try:
            process = subprocess.Popen(
                command,
                cwd=PROBE_ROOT,
                env=env,
                stdout=stream,
                stderr=subprocess.STDOUT,
                start_new_session=True,
            )
        except OSError as exc:
            fail(f"isolated LÖVE launch failed: {exc.__class__.__name__}: {exc}")
        try:
            returncode = process.wait(timeout=PROCESS_TIMEOUT_SECONDS)
        except subprocess.TimeoutExpired:
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            except OSError as exc:
                try:
                    process.kill()
                    process.wait(timeout=5)
                except (OSError, subprocess.TimeoutExpired):
                    pass
                fail(f"probe process group could not be killed: {exc.__class__.__name__}")
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
                fail("probe process leader resisted SIGKILL")
            fail(f"isolated LÖVE probe exceeded {PROCESS_TIMEOUT_SECONDS} seconds")
    try:
        os.killpg(process.pid, 0)
    except ProcessLookupError:
        pass
    except OSError as exc:
        fail(f"cannot verify probe process group exit: {exc.__class__.__name__}")
    else:
        try:
            os.killpg(process.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
        except OSError as exc:
            fail(
                "probe process group survived leader and could not be killed: "
                f"{exc.__class__.__name__}"
            )
        deadline = time.monotonic() + 5
        while True:
            try:
                os.killpg(process.pid, 0)
            except ProcessLookupError:
                break
            except OSError as exc:
                fail(
                    "cannot verify surviving probe process group cleanup: "
                    f"{exc.__class__.__name__}"
                )
            if time.monotonic() >= deadline:
                fail("surviving probe process group resisted SIGKILL")
            time.sleep(0.05)
        fail("probe process group outlived its leader and was force-reaped")
    return returncode


def probe_processes() -> list[dict[str, Any]]:
    """Detect a detached process still consuming the disposable runtime."""
    try:
        completed = subprocess.run(
            ["/bin/ps", "-axww", "-o", "pid=,ppid=,pgid=,command="],
            check=True,
            capture_output=True,
            text=True,
            timeout=10,
            env={"PATH": "/usr/bin:/bin:/usr/sbin:/sbin", "LANG": "C", "LC_ALL": "C"},
        )
    except (OSError, subprocess.SubprocessError) as exc:
        fail(f"cannot audit probe process table: {exc.__class__.__name__}")
    found: list[dict[str, Any]] = []
    for raw in completed.stdout.splitlines():
        fields = raw.strip().split(None, 3)
        if len(fields) == 4 and fields[0].isdigit() and str(PROBE_ROOT) in fields[3]:
            if "Contents/MacOS/love" in fields[3]:
                found.append({"pid": int(fields[0]), "kind": "love"})
    return found


def build_environment(source_save_sha256: str, closure_tree_sha256: str) -> dict[str, str]:
    return {
        "PATH": "/usr/bin:/bin:/usr/sbin:/sbin",
        "TMPDIR": "/private/tmp",
        "LANG": "en_US.UTF-8",
        "LC_ALL": "en_US.UTF-8",
        "TZ": "UTC",
        "HOME": str(ACCOUNT_HOME),
        "PWD": str(PROBE_ROOT),
        "POKEPORT_IDENTITY": PROBE_IDENTITY_NAME,
        "POKEPORT_VERSION": "red",
        "POKEPORT_TOUCH": "0",
        "POKEPORT_SPEED": "8",
        "POKEPORT_DRIVER": str(ISOLATED_DRIVER),
        "KA_OAK_PROBE_OUTPUT_DIR": str(OUTPUT_DIR),
        "KA_OAK_PROBE_SOURCE_SAVE_SHA256": source_save_sha256,
        "KA_OAK_PROBE_CLOSURE_TREE_SHA256": closure_tree_sha256,
    }


def execute_probe() -> dict[str, Any]:
    """Execute the one-shot probe.  Never call this before formal Run-F stop."""
    assert_static_paths()
    driver_sha256 = validate_driver_source()
    require_all_fresh()
    stable = stable_run_f_sample()
    require_all_fresh()  # close the stability-window freshness race

    require_authorized_write(PROBE_ROOT)
    PROBE_ROOT.mkdir(mode=0o700, parents=False, exist_ok=False)
    host = HostReceipt()
    phase = "formal-stop-bound"
    try:
        host.arm(
            phase,
            formal_failure_receipt_sha256=stable["formal_failure_fingerprint"]["sha256"],
            route_log_sha256=stable["route_log_fingerprint"]["sha256"],
            pass_log_sha256=stable["pass_log_fingerprint"]["sha256"],
            parent_go_token_sha256=stable["parent_go_token_fingerprint"]["sha256"],
            source_identity_content_sha256=stable["content_sha256"],
            source_identity_stability_sha256=stable["stability_sha256"],
            source_save_sha256=stable["main_save"]["sha256"],
            source_save_backup_sha256=stable["backup_save"]["sha256"],
            stable_samples=2,
            stability_seconds=STABILITY_SECONDS,
            probe_driver_sha256=driver_sha256,
        )

        phase = "snapshot-copy"
        host.arm(phase)
        copy_tree_exclusive(RUN_F_IDENTITY, SNAPSHOT_IDENTITY, symlinks=False)
        snapshot_rows = require_same_tree(
            stable["rows"],
            SNAPSHOT_IDENTITY,
            "isolated identity snapshot",
            allow_safe_symlinks=False,
            reject_tmp=True,
        )
        source_after_snapshot = identity_sample("after-snapshot-copy")
        if source_after_snapshot["stability_sha256"] != stable["stability_sha256"]:
            fail("active Run-F identity changed during snapshot copy")
        require_run_f_process_quiescent()

        phase = "runtime-copy"
        host.arm(phase)
        engine_rows = scan_tree(
            RUN_F_ENGINE,
            "Run-F engine source",
            allow_safe_symlinks=True,
            reject_tmp=False,
        )
        closure_rows = scan_tree(
            RUN_F_CLOSURE,
            "Run-F base/deutsch/red closure source",
            allow_safe_symlinks=False,
            reject_tmp=False,
        )
        engine_sha256 = tree_digest(engine_rows, False)
        closure_sha256 = tree_digest(closure_rows, False)
        copy_tree_exclusive(RUN_F_ENGINE, ISOLATED_ENGINE, symlinks=True)
        copy_tree_exclusive(RUN_F_CLOSURE, ISOLATED_CLOSURE, symlinks=False)
        copy_file_exclusive(DRIVER_SOURCE, ISOLATED_DRIVER)
        require_same_tree(
            engine_rows,
            ISOLATED_ENGINE,
            "isolated engine copy",
            allow_safe_symlinks=True,
            reject_tmp=False,
        )
        require_same_tree(
            closure_rows,
            ISOLATED_CLOSURE,
            "isolated closure copy",
            allow_safe_symlinks=False,
            reject_tmp=False,
        )
        if sha256_bytes(read_regular_bytes(ISOLATED_DRIVER, "isolated probe driver")) != driver_sha256:
            fail("isolated probe driver copy drifted")
        love_binary = ISOLATED_ENGINE / "Contents/MacOS/love"
        love_info = require_regular(love_binary, "isolated LÖVE binary")
        if not love_info.st_mode & stat.S_IXUSR:
            fail("isolated LÖVE binary is not executable")

        phase = "probe-identity-copy"
        host.arm(
            phase,
            engine_tree_sha256=engine_sha256,
            closure_tree_sha256=closure_sha256,
        )
        require_absent(PROBE_IDENTITY, "probe fused identity")
        require_absent(PROBE_CONVENTIONAL_IDENTITY, "probe conventional LOVE identity")
        copy_tree_exclusive(SNAPSHOT_IDENTITY, PROBE_IDENTITY, symlinks=False)
        target_before = require_same_tree(
            snapshot_rows,
            PROBE_IDENTITY,
            "fresh probe fused identity",
            allow_safe_symlinks=False,
            reject_tmp=True,
        )
        cache_before = scan_tree(
            PROBE_IDENTITY / "red",
            "probe imported red cache before launch",
            allow_safe_symlinks=False,
            reject_tmp=True,
        )
        saves_before = scan_tree(
            PROBE_IDENTITY / "saves",
            "probe save tree before launch",
            allow_safe_symlinks=False,
            reject_tmp=True,
        )
        require_authorized_write(OUTPUT_DIR)
        OUTPUT_DIR.mkdir(mode=0o700, parents=False, exist_ok=False)

        phase = "prelaunch-revalidation"
        host.arm(phase)
        require_run_f_process_quiescent()
        _, failure_now = validate_failure_receipt()
        route_now = file_fingerprint(RUN_F_ROUTE_LOG, "Run-F route.log before launch")
        pass_now = file_fingerprint(RUN_F_PASS_LOG, "Run-F pass log before launch")
        _, go_now = validate_parent_go_token(failure_now, route_now, pass_now)
        if failure_now != stable["formal_failure_fingerprint"]:
            fail("formal Run-F failure receipt drifted before probe launch")
        if route_now != stable["route_log_fingerprint"]:
            fail("Run-F route.log drifted before probe launch")
        if pass_now != stable["pass_log_fingerprint"]:
            fail("Run-F pass log drifted before probe launch")
        if go_now != stable["parent_go_token_fingerprint"]:
            fail("parent formal-stop GO token drifted before probe launch")
        source_prelaunch = identity_sample("immediately-before-launch")
        if source_prelaunch["stability_sha256"] != stable["stability_sha256"]:
            fail("active Run-F identity drifted before probe launch")
        require_absent(PROBE_CONVENTIONAL_IDENTITY, "probe conventional LOVE identity")

        phase = "love-running"
        env = build_environment(stable["main_save"]["sha256"], closure_sha256)
        host.arm(
            phase,
            effective_environment={key: env[key] for key in sorted(env)},
            process_timeout_seconds=PROCESS_TIMEOUT_SECONDS,
        )
        returncode = run_managed_love(env)
        if returncode != 0:
            fail(f"isolated LÖVE probe returned {returncode}")
        detached = probe_processes()
        if detached:
            fail(f"detached probe process remained: {detached}")

        phase = "driver-evidence-postcheck"
        host.arm(phase, process_returncode=returncode)
        result = parse_driver_result(OUTPUT_DIR / "driver_result.txt")
        if result["source_save_sha256"] != stable["main_save"]["sha256"]:
            fail("driver receipt is not bound to stable Run-F main save")
        if result["closure_tree_sha256"] != closure_sha256:
            fail("driver receipt is not bound to isolated closure")
        before_png = validate_png(
            OUTPUT_DIR / "01_before_right_input.png", "before screenshot"
        )
        after_png = validate_png(
            OUTPUT_DIR / "02_after_right_input.png", "after screenshot"
        )
        if (before_png["width"], before_png["height"]) != (
            after_png["width"],
            after_png["height"],
        ):
            fail("before/after screenshots have different dimensions")
        if before_png["sha256"] == after_png["sha256"]:
            fail("before/after screenshots are byte-identical")
        expected_output = {
            "driver_result.txt",
            "01_before_right_input.png",
            "02_after_right_input.png",
            "process.log",
        }
        actual_output = {path.name for path in OUTPUT_DIR.iterdir()}
        if actual_output != expected_output:
            fail(f"probe output set drifted: {sorted(actual_output)}")

        phase = "cache-and-source-postcheck"
        host.arm(phase)
        target_after = scan_tree(
            PROBE_IDENTITY,
            "probe fused identity after launch",
            allow_safe_symlinks=False,
            reject_tmp=True,
        )
        cache_after = scan_tree(
            PROBE_IDENTITY / "red",
            "probe imported red cache after launch",
            allow_safe_symlinks=False,
            reject_tmp=True,
        )
        saves_after = scan_tree(
            PROBE_IDENTITY / "saves",
            "probe save tree after launch",
            allow_safe_symlinks=False,
            reject_tmp=True,
        )
        if tree_digest(cache_before, False) != tree_digest(cache_after, False):
            fail("probe imported red cache changed during launch")
        if tree_digest(saves_before, False) != tree_digest(saves_after, False):
            fail("probe save tree changed during passability probe")
        require_absent(PROBE_CONVENTIONAL_IDENTITY, "probe conventional LOVE identity")
        require_run_f_process_quiescent()
        source_postlaunch = identity_sample("after-probe-launch")
        if source_postlaunch["stability_sha256"] != stable["stability_sha256"]:
            fail("active Run-F identity changed during isolated probe")
        engine_post = scan_tree(
            RUN_F_ENGINE,
            "Run-F engine source after launch",
            allow_safe_symlinks=True,
            reject_tmp=False,
        )
        closure_post = scan_tree(
            RUN_F_CLOSURE,
            "Run-F closure source after launch",
            allow_safe_symlinks=False,
            reject_tmp=False,
        )
        if tree_digest(engine_post, False) != engine_sha256:
            fail("Run-F engine source changed during isolated probe")
        if tree_digest(closure_post, False) != closure_sha256:
            fail("Run-F closure source changed during isolated probe")
        _, failure_post = validate_failure_receipt()
        route_post = file_fingerprint(RUN_F_ROUTE_LOG, "Run-F route.log after launch")
        pass_post = file_fingerprint(RUN_F_PASS_LOG, "Run-F pass log after launch")
        _, go_post = validate_parent_go_token(failure_post, route_post, pass_post)
        if failure_post != stable["formal_failure_fingerprint"]:
            fail("formal Run-F failure receipt changed during isolated probe")
        if route_post != stable["route_log_fingerprint"]:
            fail("Run-F route.log changed during isolated probe")
        if pass_post != stable["pass_log_fingerprint"]:
            fail("Run-F pass log changed during isolated probe")
        if go_post != stable["parent_go_token_fingerprint"]:
            fail("parent formal-stop GO token changed during isolated probe")

        changed_target_paths = content_diff(target_before, target_after)
        host.passed(
            driver_result_sha256=file_fingerprint(
                OUTPUT_DIR / "driver_result.txt", "final driver result"
            )["sha256"],
            before_png=before_png,
            after_png=after_png,
            process_log_sha256=file_fingerprint(PROCESS_LOG, "final process log")[
                "sha256"
            ],
            artifacts={
                "driver_result": str(OUTPUT_DIR / "driver_result.txt"),
                "before_png": str(OUTPUT_DIR / "01_before_right_input.png"),
                "after_png": str(OUTPUT_DIR / "02_after_right_input.png"),
                "process_log": str(PROCESS_LOG),
                "host_receipt": str(HOST_RECEIPT),
            },
            target_imported_red_cache_sha256=tree_digest(cache_after, False),
            target_save_tree_sha256=tree_digest(saves_after, False),
            target_changed_paths_outside_save_and_imported_cache=changed_target_paths,
            source_identity_post_sha256=source_postlaunch["content_sha256"],
            source_identity_stability_post_sha256=source_postlaunch[
                "stability_sha256"
            ],
            source_identity_unchanged=True,
            source_runtime_unchanged=True,
            probe_conventional_identity_absent=True,
            active_run_f_identity_write_operations=0,
        )
        return host.value
    except Exception as exc:
        try:
            host.failed(phase, f"{exc.__class__.__name__}: {exc}")
        except Exception as receipt_exc:
            print(
                "WARNING: host FAIL receipt update also failed: "
                f"{receipt_exc.__class__.__name__}: {receipt_exc}",
                file=sys.stderr,
            )
        raise


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument(
        "--plan",
        action="store_true",
        help="print the exact post-F checklist; this is the default and performs no checks",
    )
    mode.add_argument(
        "--execute-after-formal-stop",
        action="store_true",
        help="run once, but only after every formal-stop/quiescence precondition passes",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(sys.argv[1:] if argv is None else argv)
    if not args.execute_after_formal_stop:
        print(PLAN_TEXT)
        return 0
    try:
        receipt = execute_probe()
    except Exception as exc:
        print(f"OAK LAB HOST PROBE FAIL: {exc.__class__.__name__}: {exc}", file=sys.stderr)
        return 1
    print(
        "OAK LAB HOST PROBE PASS: "
        f"identity={PROBE_IDENTITY_NAME} "
        f"before={receipt['before_png']['sha256']} "
        f"after={receipt['after_png']['sha256']} "
        "active_run_f_identity_unchanged=1"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
