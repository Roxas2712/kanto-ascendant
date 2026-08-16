#!/usr/bin/env python3
"""Mechanically replace the finished L01/L03 blockers with package cells.

This script owns no acceptance result.  It only makes the reviewed matrix
explicit in the canonical same-hash plan; the orchestrator still refuses to
run until a newly packed Authority artifact and every immutable receipt match.
"""

from __future__ import annotations

import copy
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
PLAN = ROOT / "qa/blitz_real_save_forensic_20260812/package_candidate/final_same_hash_plan.json"


def cell(cell_id, identity, edition, closure, driver, *, env=None,
         setup=None, passes=None, result=None, images=None, timeout=1800):
    row = {
        "id": cell_id,
        "identity": identity,
        "edition": edition,
        "closure": closure,
        "driver": driver,
        "timeout_seconds": timeout,
        "env": env or {},
        "result": result,
        "images": images or {"exact_count": 0},
    }
    if setup:
        row["setup"] = setup
    if passes:
        row["passes"] = passes
    return row


def update_l01(lane, plan):
    matrix_path = ROOT / "tools/upgrade_package_matrix_manifest.lua"
    text = matrix_path.read_text("utf-8")
    sources = [
        ("v6_0_11", "6-0-11", "72779b0a9923e2e3908573552858718aa09bc6eae25222d1268bf3f1e41b62e7", "unlocked"),
        ("rc25", "rc25", "9d340d9badf940adc7bd1a36b43d66a4d02b84229a63df8c5caa85939fdab9a5", "unlocked"),
        ("rc26", "rc26", "0b0fcd765a1dd6d64584d2dd5c116bbabf9a8218c77314e7d5de5937d63e2418", "locked"),
        ("rc27", "rc27", "fb870c51b22ac87be7a3c79ec98e6fe798196946c96abec439e5915d99af5912", "locked"),
    ]
    assert all(value in text for row in sources for value in row), "upgrade manifest drifted"
    frozen = [
        "immutable_inputs/upgrade_sources/upgrade_matrix_package_driver.lua",
        "immutable_inputs/upgrade_sources/upgrade_package_sources.lua",
        "immutable_inputs/upgrade_sources/upgrade_package_matrix_manifest.lua",
        "immutable_inputs/upgrade_sources/immutable_input_receipt.json",
        "immutable_inputs/upgrade_sources/kanto-ascendant-6.0.11.modpkg",
        "immutable_inputs/upgrade_sources/kanto-ascendant-6.5.0-rc25-test.zip",
        "immutable_inputs/upgrade_sources/kanto-ascendant-6.5.0-rc26-test.zip",
        "immutable_inputs/upgrade_sources/kanto-ascendant-6.5.0-rc27-test.zip",
    ]
    plan["support_files"] = sorted(set(plan["support_files"] + frozen))
    old = [row for row in lane["cells"]
           if row["id"] != "l01-blocked-upgrade-matrix"
           and not row["id"].startswith("l01-upgrade-")]
    upgrades = []
    for source, slug, archive_sha, initial in sources:
        for edition in ("red", "blue", "yellow"):
            passes = [{
                "name": phase,
                "driver": "tests/upgrade_matrix_package_driver.lua",
                "timeout_seconds": 1800,
                "env": {"QA_UPGRADE_PHASE": phase, "QA_UPGRADE_SOURCE": source},
            } for phase in ("stage", "migrate", "disabled", "reenabled")]
            contains = [
                "status=PASS", "scope=UPGRADE-MATRIX-PACKAGE",
                "provenance=schema-derived-sanitized", "published_save=false",
                "archive_verified=1/1", "migration=1/1",
                "rules_select_or_preserve=1/1", "final_rule_lock=1/1",
                "native_save_reload=1/1", "failed_write_rollback=1/1",
                "backup_rollback=1/1", "rollback_shadow=1/1",
                "disable_quarantine=2/2", "reenable_restore=2/2",
                "data_equality=1/1", "fail=0", f"edition={edition}",
                f"source={source}", f"archive_sha256={archive_sha}",
                f"initial_rules={initial}",
            ]
            upgrades.append(cell(
                f"l01-upgrade-{slug}-{edition}",
                f"ka65-upgrade-matrix-{source}-{edition}", edition,
                "base_deutsch", "tests/upgrade_matrix_package_driver.lua",
                passes=passes,
                result={"path": "driver_result.txt", "contains": contains},
            ))
    lane["cells"] = old + upgrades
    lane["source_references"] = sorted(set(lane["source_references"] + [
        "tools/upgrade_package_matrix_manifest.lua",
        "tests/upgrade_matrix_package_driver.lua",
        "tests/upgrade_matrix_package_driver_contract_test.py",
    ]))
    lane["coverage"]["RULE-001"] = [
        "l01-red", "l01-blue", "l01-yellow",
        *[row["id"] for row in upgrades],
    ]


def full_path_cells():
    specs = {
        "red": {
            "edition": "red", "fresh_setup": "tools/hidden_evolution_red_input_qa_setup.lua",
            "driver": "tools/hidden_evolution_red_input_e2e.lua",
            "render_env": "RED_QA_RENDER", "character": "RED", "stone": "BLAZIKENITE",
        },
        "blue": {
            "edition": "blue", "fresh_setup": "tools/hidden_evolution_blue_pure_qa_setup.lua",
            "driver": "tools/hidden_evolution_blue_pure_input_qa.lua",
            "render_env": "BLUE_QA_RENDER", "character": "BLUE", "stone": "SWAMPERTITE",
        },
        "green": {
            "edition": "yellow", "fresh_setup": "tools/hidden_evolution_green_input_qa_setup.lua",
            "driver": "tools/hidden_evolution_green_input_e2e.lua",
            "render_env": "GREEN_QA_RENDER", "character": "GREEN", "stone": "SCEPTILITE",
        },
    }
    rows = []
    for key, spec in specs.items():
        for variant in ("fresh", "alt"):
            for renderer in ("2d", "full"):
                voxel = renderer == "full"
                setup = spec["fresh_setup"] if variant == "fresh" else "tools/hevo_alt_full_path_qa_setup.lua"
                env = {
                    "HEVO_QA_VARIANT": variant.upper(),
                    "QA_RENDERER": renderer.upper(),
                    spec["render_env"]: "voxel" if voxel else "2d",
                }
                rows.append(cell(
                    f"l03-path-{key}-{variant}-{renderer}",
                    f"ka65-final-hevo-{key}-{variant}-{renderer}",
                    spec["edition"], "dramaless_fp" if voxel else "base_deutsch",
                    spec["driver"], env=env, setup=setup, timeout=7200,
                    result={"path": "driver_result.txt", "contains": [
                        "status=PASS", "scope=HEVO-FULL-PATH",
                        f"character={spec['character']}", f"edition={spec['edition']}",
                        f"renderer={'voxel' if voxel else '2d'}",
                        f"variant={variant.upper()}", f"stone={spec['stone']}",
                        "native_save_reload=1/1", "reentry=1/1", "fail=0",
                    ]},
                    images={"min_count": {"red": 20, "blue": 35, "green": 20}[key], "min_bytes": 1000},
                ))
    return rows


def encounter_cells():
    editions = {"red": "red", "blue": "blue", "green": "yellow"}
    rows = []
    for character, edition in editions.items():
        for renderer in ("2d", "full"):
            for cycle in (1, 7):
                expected = 70 if cycle == 1 else 100
                rows.append(cell(
                    f"l03-encounter-{character}-{renderer}-cycle{cycle}",
                    f"ka65-final-hevo-encounter-demo-{character}-{renderer}-cycle{cycle}",
                    edition, "dramaless_fp" if renderer == "full" else "base_deutsch",
                    "tools/hevo_dungeon_encounter_demo_capture.lua",
                    setup="tools/hevo_dungeon_encounter_demo_qa_setup.lua",
                    timeout=3600,
                    env={
                        "HEVO_ENCOUNTER_DEMO_CHARACTER": character.upper(),
                        "HEVO_ENCOUNTER_DEMO_CYCLE": str(cycle),
                        "HEVO_ENCOUNTER_RENDERER": "voxel" if renderer == "full" else "2d",
                        "HEVO_ENCOUNTER_NATURAL_ONLY": "1",
                    },
                    result={"path": "runtime_assertions.txt", "contains": [
                        "HEVO NATURAL DUNGEON ENCOUNTER PASS",
                        f"character={character.upper()}", f"journey_cycle={cycle}",
                        f"level={expected}", "origin=automatic_initial_map_enter_wave",
                        "driver_trySpawn_calls_before_receipt=0",
                        "visible_spawn=reachable,no_fallback,six_frame_sheet",
                        "contact_battle=real_start_battle_script,command_menu",
                    ]},
                    images={"exact_count": 2, "min_bytes": 1000},
                ))
    return rows


def professor_cells():
    editions = {"red": "red", "blue": "blue", "green": "yellow"}
    rows = []
    for character, edition in editions.items():
        for locale in ("en", "de"):
            for renderer in ("2d", "full"):
                runtime_renderer = "voxel" if renderer == "full" else "2d"
                rows.append(cell(
                    f"l03-professor-{character}-{locale}-{renderer}",
                    f"ka65-final-hevo-professor-{character}-{locale}-{renderer}",
                    edition, "dramaless_fp" if renderer == "full" else "base_deutsch",
                    "tests/hidden_evolution_professor_hints_visual_driver.lua",
                    timeout=5400,
                    env={"QA_ONLY": character.upper(), "QA_LANGUAGE": locale,
                         "QA_RENDERER": runtime_renderer},
                    result={"path": "driver_result.txt", "contains": [
                        "PASS", f"locale={locale}", f"renderer={runtime_renderer}", "fail=0",
                    ]},
                    images={"exact_count": 12, "min_bytes": 1000},
                ))
    return rows


def mega_cells():
    specs = {
        "blaziken": ("red", "mega-blaziken"),
        "swampert": ("blue", "mega-swampert"),
        "sceptile": ("yellow", "mega-sceptile"),
    }
    rows = []
    for name, (edition, form) in specs.items():
        for renderer in ("2d", "full"):
            for side in ("player", "enemy"):
                for shiny in (0, 1):
                    layout = "voxel" if renderer == "full" else "2d"
                    rows.append(cell(
                        f"l03-mega-{name}-{renderer}-{side}-shiny{shiny}",
                        f"ka65-final-hevo-mega-{name}-{renderer}-{side}-shiny{shiny}",
                        edition, "dramaless_fp" if renderer == "full" else "base_deutsch",
                        "tools/mega_crystal_qa_driver.lua", timeout=2400,
                        env={
                            "MEGA_QA_FORM": form, "MEGA_QA_LAYOUT": layout,
                            "MEGA_QA_SIDE": side, "MEGA_QA_SHINY": str(shiny),
                            "MEGA_QA_BACK_SPRITES": "1" if side == "player" else "0",
                            "MEGA_QA_CRYSTAL": "1", "MEGA_QA_VERSION": edition,
                        },
                        result={"path": "driver_result.txt", "contains": [
                            "status=PASS", "scope=HOENN-MEGA-PRESENTATION",
                            f"edition={edition}", f"form={form}", f"layout={layout}",
                            f"side={side}", f"shiny={shiny}", "crystal=1",
                            "animation=1/1", "sprite_ownership=1/1", "fail=0",
                        ]},
                        images={"exact_count": 1, "min_bytes": 1000},
                    ))
    return rows


def update_l03(lane, plan):
    plan["support_files"] = sorted(set(plan["support_files"] + [
        "tools/hevo_dungeon_encounter_demo_manifest.lua",
    ]))
    contract = next(row for row in lane["cells"] if row["id"] == "l03-hevo-contract")
    paths = full_path_cells()
    encounters = encounter_cells()
    fissures = [cell(
        f"l03-fissure-{renderer}", f"ka65-final-hevo-fissure-red-{renderer}",
        "red", "dramaless_fp" if renderer == "full" else "base_deutsch",
        "tests/hidden_evolution_fissure_visual_driver.lua",
        env={"QA_RENDERER": "voxel" if renderer == "full" else "2d"},
        result={"path": "driver_result.txt", "contains": [
            "status=PASS", "scope=HEVO-FISSURE-RENDERERS",
            f"renderer={'voxel' if renderer == 'full' else '2d'}",
            "sites=RED,BLUE,GREEN", "wall_decals=3/3",
            "interaction_anchors=3/3", "fail=0",
        ]}, images={"exact_count": 3, "min_bytes": 1000},
    ) for renderer in ("2d", "full")]
    hevo15 = cell(
        "l03-hevo15-grants-altars", "ka-hevo15-grants-altars-package",
        "red", "base_deutsch", "tests/hevo_15_grants_altars_visual_driver.lua",
        timeout=5400,
        result={"path": "hevo15_grants_altars_receipt.txt", "contains": [
            "HEVO-15 GRANTS + FIELD ALTARS PASS",
            "grant_boundary=REAL_LEGACY_DUNGEON_ADAPTER_FINALIZE",
            "manual_package_flag_writes=false", "packages=15/15 targets=17/17 first_grants=8/8",
            "physical_altars=3/3", "altar_results=MAGNEZONE,GLACEON,LEAFEON",
            "altar_reload=3/3",
        ]}, images={"exact_count": 7, "min_bytes": 1000},
    )
    epilogues = [cell(
        f"l03-epilogue-{renderer}", f"ka65-final-hevo-epilogue-red-{renderer}",
        "red", "dramaless_fp" if renderer == "full" else "base_deutsch",
        "tools/hevo_epilogue_stone_case_qa_driver.lua", timeout=7200,
        env={"QA_RENDERER": renderer.upper()},
        result={"path": "runtime_assertions.txt", "contains": [
            "HEVO EPILOGUE / STONE CASE / HOENN GATE PASS",
            f"renderer={renderer.upper()}", "final_cycle=3", "final_avatar=GREEN",
            "stones=BLAZIKENITE,SWAMPERTITE,SCEPTILITE",
            "oak_left_ball=TORCHIC->MUDKIP->TREECKO; display-only; no grants",
        ]}, images={"exact_count": 9, "min_bytes": 1000},
    ) for renderer in ("2d", "full")]
    professors = professor_cells()
    nonmap = [cell(
        f"l03-nonmap-{locale}", f"ka65-final-hevo-nonmap-red-{locale}",
        "red", "base_deutsch", "tests/hevo_nonmap_surfaces_visual_driver.lua",
        timeout=7200, env={"QA_LANGUAGE": locale},
        result={"path": "driver_result.txt", "contains": [
            f"locale={locale}", "fail=0", "itemTargets=9", "knowledgeTargets=5",
            "scope=non-map; field altars and dungeon first grants excluded",
        ]}, images={"exact_count": 50, "min_bytes": 1000},
    ) for locale in ("en", "de")]
    megas = mega_cells()
    lane["cells"] = [contract, *paths, *encounters, *fissures, hevo15,
                     *epilogues, *professors, *nonmap, *megas]
    lane["source_references"] = sorted(set(lane["source_references"] + [
        "tools/hevo_alt_full_path_qa_setup.lua",
        "tests/hidden_evolution_fissure_visual_driver.lua",
        "tests/hevo_15_grants_altars_visual_driver.lua",
        "tests/hidden_evolution_professor_hints_visual_driver.lua",
        "tests/hevo_nonmap_surfaces_visual_driver.lua",
        "tools/mega_crystal_qa_driver.lua",
    ]))

    path_ids = [row["id"] for row in paths]
    red_paths = [value for value in path_ids if "-red-" in value]
    blue_paths = [value for value in path_ids if "-blue-" in value]
    green_paths = [value for value in path_ids if "-green-" in value]
    alt_paths = [value for value in path_ids if "-alt-" in value]
    encounter_ids = [row["id"] for row in encounters]
    fissure_ids = [row["id"] for row in fissures]
    epilogue_ids = [row["id"] for row in epilogues]
    professor_ids = [row["id"] for row in professors]
    nonmap_ids = [row["id"] for row in nonmap]
    mega_ids = [row["id"] for row in megas]
    def unique(values):
        return list(dict.fromkeys(values))

    coverage = {
        "HEVO-001": ["l03-hevo-contract", *path_ids, *fissure_ids],
        "HEVO-002": ["l03-hevo-contract", *path_ids],
        "HEVO-003": red_paths,
        "HEVO-004": ["l03-hevo-contract", *path_ids],
        "HEVO-005": encounter_ids,
        "HEVO-006": ["l03-hevo-contract", *path_ids],
        "HEVO-007": path_ids,
        "HEVO-008": unique([*path_ids, *alt_paths, *epilogue_ids]),
        "HEVO-009": [*mega_ids, *epilogue_ids],
        "NGP-001": [*professor_ids, *alt_paths],
        "RC65-DUNGEON-RED": [*red_paths, *fissure_ids],
        "RC65-DUNGEON-BLUE": [*blue_paths, *fissure_ids],
        "RC65-DUNGEON-GREEN": [*green_paths, *fissure_ids],
        "RC65-DUNGEON-SHARED": ["l03-hevo-contract", *path_ids],
        "RC65-DUNGEON-STATUE-BANKS": ["l03-hevo-contract", *path_ids],
        "RC65-DUNGEON-EPILOG": [*path_ids, *epilogue_ids],
        "RC65-HEVO-15": [hevo15["id"], *nonmap_ids],
        "RC65-HEVO-LV70-HABITATS": encounter_ids,
        "RC65-HOENN-MEGAS": [*mega_ids, *epilogue_ids],
        "RC65-HEVO-DATA": ["l03-hevo-contract", hevo15["id"], *nonmap_ids],
        "RC65-PROFESSOR-HINTS": professor_ids,
    }
    lane["coverage"] = coverage


def update_l04(lane):
    """Replace the connected-Legacy placeholder with its reviewed 11 cells."""
    manifest_path = ROOT / "tools/legacy_connected_package_matrix_manifest.lua"
    assert manifest_path.is_file(), "connected Legacy manifest is missing"
    rows = []
    for edition in ("red", "blue", "yellow"):
        for locale in ("en", "de"):
            yellow_path = "pikachu" if edition == "yellow" and locale == "de" else "catalog"
            rows.append(cell(
                f"l04-connected-{edition}-{locale}",
                f"ka65-final-legacy-connected-{edition}-{locale}",
                edition, "base_deutsch",
                "tests/legacy_story_partner_fresh_e2e_driver.lua",
                timeout=3600,
                env={"QA_LANGUAGE": locale, "QA_YELLOW_PATH": yellow_path},
                passes=[
                    {"name": "language-setup",
                     "driver": "tests/legacy_connected_language_setup_driver.lua",
                     "timeout_seconds": 300},
                    {"name": "connected-story-partner",
                     "driver": "tests/legacy_story_partner_fresh_e2e_driver.lua",
                     "timeout_seconds": 3600},
                ],
                result={"path": "driver_result.txt", "contains": [
                    "status=PASS", "scope=LEGACY-CONNECTED-FRESH-LAB",
                    f"edition={edition}", f"locale={locale}", f"path={yellow_path}",
                    "physical_lab_pc=PASS", "fresh_confirm_default_no=2/2",
                    "partner_confirm_default_no=2/2", "rival_ball_boundary=1/1",
                    "mid_phase_native_reload=1/1", "physical_lab_exit_lock=1/1",
                    "partner_rival_durable=1/1", "native_save_reload=midphase+partner",
                    "archive_transaction=1/1", "fail=0",
                ]},
                images={"min_count": 20, "min_bytes": 1000},
            ))
    rows.extend([
        cell(
            "l04-archive-transaction", "ka65-final-legacy-archive-transaction",
            "red", "base_deutsch", "tools/legacy_archive_transaction_package_driver.lua",
            result={"path": "driver_result.txt", "contains": [
                "status=PASS", "scope=LEGACY-ARCHIVE-TRANSACTION",
                "installed_archive_factory=1/1", "failed_witness_rollback=1/1",
                "source_save_unchanged=2/2", "committed_witness_recovery=1/1",
                "same_source_retry_exact_once=1/1", "v1_to_v7_migration=1/1",
                "migration_persist_exact_once=1/1", "fail=0",
            ]},
        ),
        cell(
            "l04-archive-daycare-de", "ka65-final-legacy-daycare-de",
            "red", "base_deutsch", "tests/legacy_archive_daycare_visual_driver.lua",
            timeout=1800, env={"QA_LANGUAGE": "de"},
            result={"path": "driver_result.txt", "contains": [
                "status=PASS", "scope=LEGACY-ARCHIVE-DAYCARE", "edition=red",
                "locale=de", "vanilla_daycare_block=1/1", "daycare_plus_block=1/1",
                "blocked_retry_side_effect_free=1/1", "fresh_handoff=1/1",
                "native_save_reload=1/1", "fail=0",
            ]}, images={"exact_count": 6, "min_bytes": 1000},
        ),
        cell(
            "l04-workshop-full", "ka65-final-legacy-workshop-product-full",
            "red", "dramaless_fp", "tools/ngplus_legacy_workshop_e2e_driver.lua",
            timeout=2400,
            result={"path": "driver_result.txt", "contains": [
                "status=PASS", "scope=LEGACY-WORKSHOP-PRODUCT", "edition=red",
                "renderer=2D+DRAMALESS_FULL", "curator_entry=1/1",
                "seal_states=0/1/2/3", "native_save_reload=4/4",
                "unsolved_resonance_gate=3/3", "ledger_purchase=1/1",
                "physical_gallery_return=1/1", "fail=0",
            ]}, images={"exact_count": 12, "min_bytes": 1000},
        ),
        cell(
            "l04-workshop-resonance-2d", "ka65-final-legacy-workshop-resonance-2d",
            "red", "base_deutsch", "tools/ngplus_legacy_workshop_resonance_e2e_driver.lua",
            timeout=3000,
            result={"path": "driver_result.txt", "contains": [
                "status=PASS", "scope=LEGACY-WORKSHOP-RESONANCE", "edition=red",
                "renderer=2D", "characters=RED,BLUE,GREEN", "unsolved_gate=3/3",
                "ready_default_no=3/3", "native_save_reload=10/10",
                "walkable_resonance_destination=3/3", "physical_return=3/3",
                "return_token_exact_once=3/3", "fail=0",
            ]}, images={"exact_count": 12, "min_bytes": 1000},
        ),
        cell(
            "l04-title-archive-card-de", "ka65-final-legacy-title-card-de",
            "red", "base_deutsch", "tests/legacy_wanderer_title_visual_driver.lua",
            timeout=1800,
            result={"path": "driver_result.txt", "contains": [
                "status=PASS", "scope=LEGACY-TITLE-ARCHIVE-CARD", "edition=red",
                "locale=de", "archive_title_handoff=1/1", "native_save_reload=1/1",
                "trainer_card_title=FABRIK-ARCHITEKT", "trainer_card_pact=PAKT:VERM.",
                "wanderer_title_reaction=1/1", "committed_partner_reaction=1/1",
                "fail=0",
            ]}, images={"exact_count": 4, "min_bytes": 1000},
        ),
    ])
    assert len(rows) == 11
    base = [row for row in lane["cells"]
            if row["id"] != "l04-blocked-connected-legacy"
            and not row["id"].startswith(("l04-connected-", "l04-archive-", "l04-workshop-", "l04-title-"))]
    lane["cells"] = base + rows
    lane["source_references"] = sorted(set(lane["source_references"] + [
        "tools/legacy_connected_package_matrix_manifest.lua",
        "tests/legacy_connected_package_contract_test.py",
    ]))
    connected = [row["id"] for row in rows if row["id"].startswith("l04-connected-")]
    archive = ["l04-archive-transaction", "l04-archive-daycare-de"]
    workshops = ["l04-workshop-full", "l04-workshop-resonance-2d"]
    title = ["l04-title-archive-card-de"]
    pacts = ["l04-pact-red", "l04-pact-blue", "l04-pact-yellow"]
    journeys = ["l04-three-journeys"]
    lane["coverage"] = {
        "NGP-002": connected + archive,
        "NGP-003": connected + archive + title,
        "NGP-004": connected + workshops,
        "NGP-005": connected + workshops + title,
        "NGP-006": pacts + connected,
        "RC65-LEGACY-PARTNER": connected,
        "RC65-LEGACY-PACT-MATRIX": pacts + connected,
        "RC65-LEGACY-TITLES": title + connected,
        "RC65-LEGACY-ARCHIVE-INTEGRITY": journeys + archive + connected,
        "RC65-LEGACY-THREE-JOURNEYS": journeys,
        "RC65-LEGACY-STORY": connected + archive,
        "RC65-LEGACY-WORKSHOP": workshops,
    }


def main():
    plan = json.loads(PLAN.read_text("utf-8"))
    lanes = {lane["lane_id"]: lane for lane in plan["lanes"]}
    update_l01(lanes["L01_BOOT_UPGRADE_RULES"], plan)
    update_l03(lanes["L03_HEVO_MATRIX"], plan)
    update_l04(lanes["L04_NGPLUS_LEGACY"])
    PLAN.write_text(json.dumps(plan, indent=2, ensure_ascii=False) + "\n", "utf-8")
    print("updated L01 and L03 package cells")


if __name__ == "__main__":
    main()
