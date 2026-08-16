#!/usr/bin/env python3
"""Fail-closed L05 League plan/driver receipt contract."""

from __future__ import annotations

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
PLAN = (
    ROOT
    / "qa/blitz_real_save_forensic_20260812/package_candidate"
    / "final_same_hash_plan.json"
)
DRIVER = ROOT / "tests/postgame_league_megas_visual_driver.lua"

plan = json.loads(PLAN.read_text(encoding="utf-8"))
source = DRIVER.read_text(encoding="utf-8")
cells = {
    cell["id"]: cell
    for lane in plan["lanes"]
    for cell in lane["cells"]
    if cell["id"].startswith("l05-league-")
}
assert set(cells) == {
    "l05-league-2d",
    "l05-league-dramaless",
    "l05-league-battle-art",
}

common = {
    "edition=red",
    "scope=RC65-LEAGUE-UNIQUE-MEGAS",
    "authority=Authority-main/LÖVE/package",
    "progression_setup=STAGED_POSTGAME_SAVE_STATE",
    "battle_construction=REAL_BATTLESTATE_TRAINER",
    "staged_switch=BattleState.makeBattler+battle.battler_switched",
    "manual_mega_activation=false",
    "league_legend_options=CANONICAL_DEFAULTS_STAGED",
    "OPP_LORELEI_roster=DEWGONG,CLOYSTER,SLOWBRO,JYNX,VAPOREON,ARTICUNO",
    "OPP_BRUNO_roster=HITMONLEE,HITMONCHAN,POLIWRATH,PRIMEAPE,AERODACTYL,MACHAMP",
    "OPP_AGATHA_roster=GENGAR,ARBOK,WEEZING,GOLBAT,HAUNTER,MISMAGIUS",
    "OPP_LANCE_roster=GYARADOS,TYRANITAR,CHARIZARD,DRAGONAIR,KINGDRA,DRAGONITE",
    "OPP_RIVAL3_roster=MEWTWO,RAIKOU,ENTEI,TAUROS,LUGIA,HO_OH",
    "OPP_RIVAL3_apex_roster=TAUROS,TYRANITAR,RHYDON,EXEGGUTOR,ARCANINE,GYARADOS",
    "OPP_LORELEI_mega_entry=STAGED_SWITCH_AFTER_REAL_ROSTER_ASSERTION",
    "OPP_BRUNO_mega_entry=STAGED_SWITCH_AFTER_REAL_ROSTER_ASSERTION",
    "OPP_AGATHA_mega_entry=NATURAL_LEAD",
    "OPP_LANCE_mega_entry=STAGED_SWITCH_AFTER_REAL_ROSTER_ASSERTION",
    "OPP_RIVAL3_mega_entry=NATURAL_LEAD",
    "OPP_RIVAL3_apex_mega_entry=STAGED_SWITCH_AFTER_REAL_ROSTER_ASSERTION",
    "pass=77",
    "fail=0",
}
for cell_id, cell in cells.items():
    tokens = set(cell["result"]["contains"])
    assert common <= tokens, (cell_id, sorted(common - tokens))
    assert all("wanderer_matrix=" not in token for token in tokens), cell_id
    renderer_tokens = (
        {"renderer=2d", "renderer_id=classic-2d"}
        if cell_id.endswith("-2d")
        else {
            "renderer=full",
            "renderer_id=" + (
                "DRAMALESS_SHAPE"
                if cell_id.endswith("-dramaless")
                else "BATTLE_ART_VOXEL_FORK"
            ),
        }
    )
    assert common | renderer_tokens == tokens, (
        cell_id,
        sorted((common | renderer_tokens) ^ tokens),
    )
    assert cell["result"]["path"] == "driver_result.txt"
    assert cell["images"] == {"exact_count": 11, "min_bytes": 1000}

for token in (
    'local GameVersion = require("src.core.GameVersion")',
    'local expectedEdition = assert(os.getenv("POKEPORT_VERSION")',
    "local edition = GameVersion.get()",
    "assert(edition == expectedEdition",
    '"edition=" .. edition',
    '"scope=RC65-LEAGUE-UNIQUE-MEGAS"',
    '"battle_construction=REAL_BATTLESTATE_TRAINER"',
    '"manual_mega_activation=false"',
    'report[#report + 1] = "pass=" .. pass',
    'report[#report + 1] = "fail=" .. fail',
):
    assert token in source, token

assert "wanderer_matrix=" not in source
print("L05 League plan/result contract PASS: 3 cells; truthful League-only receipt")
