#!/usr/bin/env python3
"""Fail-closed identity/asset contract for private slots #252-279."""

from __future__ import annotations

import hashlib
import json
import re
import sys
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "assets" / "crystal_animated"
MANIFEST = ASSETS / "extended_252_279_motion_sources.json"
DATA = ROOT / "extended_crystal_animation_data.lua"

EXPECTED = {
    252: ("TREECKO", 252), 253: ("GROVYLE", 253),
    254: ("SCEPTILE", 254), 255: ("TORCHIC", 255),
    256: ("COMBUSKEN", 256), 257: ("BLAZIKEN", 257),
    258: ("MUDKIP", 258), 259: ("MARSHTOMP", 259),
    260: ("SWAMPERT", 260), 261: ("AMBIPOM", 424),
    262: ("MISMAGIUS", 429), 263: ("HONCHKROW", 430),
    264: ("WEAVILE", 461), 265: ("MAGNEZONE", 462),
    266: ("LICKILICKY", 463), 267: ("RHYPERIOR", 464),
    268: ("TANGROWTH", 465), 269: ("ELECTIVIRE", 466),
    270: ("MAGMORTAR", 467), 271: ("TOGEKISS", 468),
    272: ("YANMEGA", 469), 273: ("LEAFEON", 470),
    274: ("GLACEON", 471), 275: ("GLISCOR", 472),
    276: ("MAMOSWINE", 473), 277: ("PORYGON_Z", 474),
    278: ("AZURILL", 298), 279: ("WYNAUT", 360),
}
ANIMATED = set(EXPECTED)
POLISHED = {261, 262, 266, 267, 268, 272, 279}


def fail(message: str) -> None:
    raise AssertionError(message)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def parse_lua_section(body: str, section: str) -> dict[int, list[int]]:
    marker = f"  {section} = {{"
    start = body.find(marker)
    if start < 0:
        fail(f"missing Lua section {section}")
    start += len(marker)
    end = body.find("\n  },", start)
    if end < 0:
        fail(f"unterminated Lua section {section}")
    rows = {}
    for dex, values in re.findall(r'\["(\d+)"\]\s*=\s*\{([^}]*)\}', body[start:end]):
        rows[int(dex)] = [int(value) for value in re.findall(r"\d+", values)]
    return rows


def image_contract(path: Path, label: str) -> bytes:
    image = Image.open(path).convert("RGBA")
    if image.width != image.height or image.width not in (40, 48, 56, 64, 96):
        fail(f"{label}: invalid card canvas {image.size}")
    alpha = image.getchannel("A")
    if alpha.getextrema() != (0, 255):
        fail(f"{label}: background is not alpha-keyed")
    return alpha.tobytes()


def main() -> int:
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    if manifest.get("schema") != 2:
        fail("manifest schema does not record both authored source providers")
    providers = {
        row.get("provider"): row for row in (manifest.get("sources") or [])
    }
    if set(providers) != {"Nuuk Crystal GFX pack", "Pokemon Polished Crystal"}:
        fail("manifest source-provider set is incomplete")
    if providers["Pokemon Polished Crystal"].get("commit") != (
        "4a440ffdecd821ae1b724d6df88280a3f89f158d"
    ):
        fail("manifest Polished Crystal commit drift")
    if providers["Pokemon Polished Crystal"].get("sourceArchiveSha256") != (
        "184ac0ef4eb50db3dea78e2a4dad03807e7dc4b696e9a3248aa0b7bb84a9deb5"
    ):
        fail("manifest Polished Crystal source archive hash drift")
    if manifest.get("internalRuntimeDexRange") != [252, 279]:
        fail("manifest does not own exactly private slots #252-279")
    rows = manifest.get("rows") or []
    if [row.get("internalRuntimeDex") for row in rows] != list(range(252, 280)):
        fail("manifest rows are not contiguous private slots #252-279")

    timing_body = DATA.read_text(encoding="utf-8")
    normal = parse_lua_section(timing_body, "normal")
    shiny = parse_lua_section(timing_body, "shiny")
    if set(normal) != ANIMATED or normal != shiny:
        fail("timing data must name all 28 identity-correct authored fronts")

    total_front = 0
    for row in rows:
        dex = row["internalRuntimeDex"]
        if (row.get("species"), row.get("sourceDex")) != EXPECTED[dex]:
            fail(f"#{dex}: private slot was confused with National-Dex identity")

        if row.get("motionStatus") != "authored_front_static_back":
            fail(f"#{dex}: authored source status missing")
        expected_provider = (
            "Pokemon Polished Crystal" if dex in POLISHED
            else "Nuuk Crystal GFX pack"
        )
        if row.get("sourceProvider") != expected_provider:
            fail(f"#{dex}: wrong authored provider identity")
        if dex in POLISHED:
            if row.get("sourceCommit") != (
                "4a440ffdecd821ae1b724d6df88280a3f89f158d"
            ):
                fail(f"#{dex}: Polished Crystal source commit drift")
            if row.get("sourceArchiveSha256") != (
                "184ac0ef4eb50db3dea78e2a4dad03807e7dc4b696e9a3248aa0b7bb84a9deb5"
            ):
                fail(f"#{dex}: Polished Crystal source archive hash drift")
            if not str(row.get("sourcePath", "")).endswith(
                "/" + row["species"].lower()
            ):
                fail(f"#{dex}: Polished Crystal source path drift")
        elif not row.get("sourceZip"):
            fail(f"#{dex}: Nuuk source archive provenance missing")
        count = row["runtimeFrontFrameCount"]
        indices = row["authoredSourceFrameIndices"]
        durations = row["durationsMs"]
        if not (count == len(indices) == len(durations) == len(normal[dex])):
            fail(f"#{dex}: manifest/timing/frame counts disagree")
        if count < 3 or len(set(indices)) < 2:
            fail(f"#{dex}: source is not meaningful multi-pose motion")
        for variant in ("normal", "shiny"):
            directory = ASSETS / "front" / variant / str(dex)
            files = sorted(directory.glob("*.png"))
            expected_names = [f"{index:03d}.png" for index in range(1, count + 1)]
            if [path.name for path in files] != expected_names:
                fail(f"#{dex} {variant}: missing or stale front frames")
            hashes = [sha256(path) for path in files]
            if hashes != row[f"{variant}FrameSha256"] or len(set(hashes)) < 2:
                fail(f"#{dex} {variant}: frame hash/unique-pose contract failed")
            for path in files:
                image_contract(path, f"#{dex} {variant}/{path.name}")
        if row["normalFrameSha256"] == row["shinyFrameSha256"]:
            fail(f"#{dex}: shiny authored sequence is not distinct")
        for variant in ("normal", "shiny"):
            directory = ASSETS / "back" / variant / str(dex)
            files = sorted(directory.glob("*.png"))
            if [path.name for path in files] != ["001.png"]:
                fail(f"#{dex} {variant}: supplied Crystal rear must remain one pose")
            if sha256(files[0]) != row["backFrameSha256"][variant]:
                fail(f"#{dex} {variant}: rear hash drift")
            image_contract(files[0], f"#{dex} back/{variant}")
        total_front += count * 2

    notices = (ROOT / "THIRD_PARTY_NOTICES.md").read_text(encoding="utf-8")
    if "Nuuk" not in notices or "Polished Crystal" not in notices:
        fail("identity-correct Nuuk/Polished Crystal attribution is missing")
    print(
        f"PASS: 28 authored species / {total_front} normal+shiny front PNGs; "
        "all 28 rears honestly static"
    )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except AssertionError as error:
        print(f"FAIL: {error}", file=sys.stderr)
        raise SystemExit(1)
