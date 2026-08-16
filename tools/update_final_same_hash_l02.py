#!/usr/bin/env python3
"""Replace the final L02 blocker with the reviewed eight-cell package matrix.

This only updates the fail-closed execution plan.  It does not mark the input
receipt ready, materialize a runtime, launch LÖVE, or claim package acceptance.
"""

from __future__ import annotations

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
PLAN = ROOT / "qa/blitz_real_save_forensic_20260812/package_candidate/final_same_hash_plan.json"
MANIFEST = ROOT / "tools/presentation_motion_package_matrix_manifest.lua"

BATTLE_ART_SHA256 = (
    "10d7e80a58d9046b41ec446900f2f15aa6021335a1547d9209117f3a22a0604e"
)
BLITZ_SAVE_SHA256 = (
    "f0d8c1925c09ad8ba825240f6218b81fd1f7dbd6c30348f6304fb006dcf2f8a0"
)
BLITZ_OPTIONS_SHA256 = (
    "2f5ca783613d1ecefd12b3942ef7b12f0c78180e9b6a3820ba2637f21b91e540"
)


def phases(source: str, renderer: str) -> list[dict]:
    if source == "FRESH":
        rows = (
            ("characters", 1800),
            ("crystal_title_gorochu", 1200),
            ("follower_wilds", 1500),
            ("reload_verify", 600),
            ("aggregate", 120),
        )
    else:
        rows = (
            ("blitz_restore", 1200),
            ("reload_verify", 600),
            ("aggregate", 120),
        )
    counts = (
        {"characters": 45 if renderer == "2D" else 15,
         "crystal_title_gorochu": 5, "follower_wilds": 8,
         "reload_verify": 0,
         "aggregate": 0}
        if source == "FRESH" else {
            "blitz_restore": 6,
            "reload_verify": 0,
            "aggregate": 0,
        }
    )
    return [{
        "name": name,
        "driver": "tests/presentation_motion_package_driver.lua",
        "timeout_seconds": timeout,
        "env": {
            "QA_PRESENTATION_PHASE": name,
            "QA_PRESENTATION_SOURCE": source,
            "QA_RENDERER": renderer,
        },
        "images": {
            "exact_count": counts[name],
            "min_bytes": 1000 if counts[name] else 1,
        },
    } for name, timeout in rows]


def result_tokens(edition: str, renderer: str, source: str) -> list[str]:
    common = [
        "status=PASS",
        "scope=PRESENTATION-MOTION-PACKAGE",
    ]
    if source == "FRESH":
        common.extend([
            "fixed_identities=6/6",
            "ordinary_modes=3/3",
            "ordinary_classes=42/42",
            "title_rhythm=GREEN>POKEMON>BLUE>POKEMON>RED>POKEMON>GREEN",
            "crystal_species=28/28",
            "crystal_surfaces=9/9",
            "crystal_variants=2/2",
            "follower_exactly_one=1/1",
            "follower_map=1/1",
            "follower_door=1/1",
            "follower_surf=1/1",
            "follower_evolution=1/1",
            "follower_reload=1/1",
            "wilds_spawnfx=1/1",
            "wilds_randomizer_once=1/1",
            "wilds_johto_protection=1/1",
            "wilds_contact=1/1",
            "gorochu_intro_absent=1/1",
            "gorochu_sendout_present=1/1",
            "gorochu_hof=1/1",
        ])
    else:
        common.extend([
            f"blitz_source_sha256={BLITZ_SAVE_SHA256}",
            f"blitz_options_sha256={BLITZ_OPTIONS_SHA256}",
            "blitz_natural_restore=1/1",
            "blitz_load_report_dismissed=1/1",
            "follower_exactly_one=1/1",
            "follower_map=1/1",
            "follower_door=1/1",
            "follower_surf=1/1",
            "follower_reload=1/1",
        ])
    common.extend([
        "native_save_write=1/1",
        "native_options_write=1/1",
        "native_process_boot_without_progress_marker=1/1",
        "native_save_load=1/1",
        "native_save_recovery=main",
        "native_save_restore=1/1",
        "renderer_contract_persisted=1/1",
        "renderer_contract_reloaded=1/1",
        "durable_follower_exactly_one=1/1",
        "durable_follower_option=1/1",
    ])
    if source == "BLITZ":
        common.extend([
            "native_active_slot=slot7",
            "immutable_blitz_snapshot_unchanged=1/1",
        ])
    durable_species = (
        "ALAKAZAM" if source == "BLITZ" else {
            "red": "IVYSAUR",
            "blue": "WARTORTLE",
            "yellow": "RAICHU",
        }[edition]
    )
    common.append(f"durable_follower_species={durable_species}")
    common.extend([
        "engine_payload_sha256=",
        "authority_package_sha256=",
        "deutsch_package_sha256=",
        f"battle_art_package_sha256={BATTLE_ART_SHA256}",
        "package_gate_receipt_sha256=",
        f"edition={edition}",
        f"renderer={renderer}",
        f"source={source}",
        "fail=0",
    ])
    return common


def make_cell(cell_id: str, identity: str, edition: str, renderer: str,
              source: str, images: int) -> dict:
    return {
        "id": cell_id,
        "identity": identity,
        "edition": edition,
        "closure": "battle_art",
        "driver": "tests/presentation_motion_package_driver.lua",
        "timeout_seconds": 1800,
        "env": {
            "QA_PRESENTATION_SOURCE": source,
            "QA_RENDERER": renderer,
        },
        "passes": phases(source, renderer),
        "result": {
            "path": "driver_result.txt",
            "contains": result_tokens(edition, renderer, source),
        },
        "images": {"exact_count": images, "min_bytes": 1000},
    }


def main() -> None:
    manifest = MANIFEST.read_text("utf-8")
    for token in (
        'schema = "ka-l02-presentation-motion-package-matrix/v1"',
        'replacementCell = "l02-blocked-complete-presentation"',
        BATTLE_ART_SHA256,
        BLITZ_SAVE_SHA256,
        BLITZ_OPTIONS_SHA256,
        "assert(#cells == 8",
    ):
        assert token in manifest, f"presentation manifest drifted: {token}"

    specs = [
        ("l02-presentation-red-2d", "ka65-presentation-motion-red-2d", "red", "2D", "FRESH", 58),
        ("l02-presentation-red-battle-art-full", "ka65-presentation-motion-red-battle-art-full", "red", "BATTLE_ART_FULL", "FRESH", 28),
        ("l02-presentation-blue-2d", "ka65-presentation-motion-blue-2d", "blue", "2D", "FRESH", 58),
        ("l02-presentation-blue-battle-art-full", "ka65-presentation-motion-blue-battle-art-full", "blue", "BATTLE_ART_FULL", "FRESH", 28),
        ("l02-presentation-yellow-2d", "ka65-presentation-motion-yellow-2d", "yellow", "2D", "FRESH", 58),
        ("l02-presentation-yellow-battle-art-full", "ka65-presentation-motion-yellow-battle-art-full", "yellow", "BATTLE_ART_FULL", "FRESH", 28),
        ("l02-presentation-blitz-red-2d", "ka65-presentation-motion-blitz-red-2d", "red", "2D", "BLITZ", 6),
        ("l02-presentation-blitz-red-battle-art-full", "ka65-presentation-motion-blitz-red-battle-art-full", "red", "BATTLE_ART_FULL", "BLITZ", 6),
    ]
    cells = [make_cell(*row) for row in specs]
    cell_ids = [row[0] for row in specs]

    plan = json.loads(PLAN.read_text("utf-8"))
    lane = next(row for row in plan["lanes"]
                if row["lane_id"] == "L02_PRESENTATION_MOTION")
    old = lane["cells"]
    blocker_count = sum(
        row.get("id") == "l02-blocked-complete-presentation" for row in old
    )
    existing = {row.get("id") for row in old} & set(cell_ids)
    assert (blocker_count == 1 and not existing) or (
        blocker_count == 0 and existing == set(cell_ids)
    ), "L02 is neither the blocked nor the integrated reviewed matrix"
    lane["cells"] = [
        row for row in old
        if row.get("id") != "l02-blocked-complete-presentation"
        and row.get("id") not in set(cell_ids)
    ] + cells
    lane["source_references"] = sorted(set(lane["source_references"] + [
        "tools/presentation_motion_package_matrix_manifest.lua",
        "tests/presentation_motion_package_driver_contract_test.py",
    ]))
    plan["support_files"] = sorted(set(plan["support_files"] + [
        "tools/presentation_motion_package_composite.lua",
    ]))
    for gate, references in lane["coverage"].items():
        lane["coverage"][gate] = list(dict.fromkeys(
            [value for value in references
             if value != "l02-blocked-complete-presentation"] + cell_ids
        ))

    PLAN.write_text(json.dumps(plan, indent=2, ensure_ascii=False) + "\n", "utf-8")
    print("PASS integrated L02 presentation cells: 8; blocker removed")


if __name__ == "__main__":
    main()
