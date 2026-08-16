#!/usr/bin/env python3
"""Fail closed if the complete character/Pokemon presentation contract drifts."""

from __future__ import annotations

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
contract = json.loads((
    ROOT / "qa/rc28_release_gate_20260812/CHARACTER_PRESENTATION_CONTRACT.json"
).read_text())
characters = contract["fixed_identities"]
by_id = {row["id"]: row for row in characters}

assert set(by_id) == {"RED", "BLUE", "GREEN", "SILVER", "KRIS", "GOLD"}
assert len(characters) == len(by_id) == 6

playable_surfaces = {
    "selector_hd", "walk", "bike", "fish", "battle_front", "battle_back",
    "throw_1_5", "trainer_card", "hall_of_fame", "credits", "voxel_64",
    "voxel_128",
}
master_surfaces = {"field_walker", "arena_front_2d", "voxel_64", "voxel_128"}
for identity in ("RED", "BLUE", "GREEN"):
    row = by_id[identity]
    assert row["role"] == "playable_and_rival"
    assert set(row["surfaces"]) == playable_surfaces
    assert len(row["assets"]) == 12
for identity in ("SILVER", "KRIS"):
    row = by_id[identity]
    assert row["role"] == "johto_master_enemy_only"
    assert row["player_back_required"] is False
    assert set(row["surfaces"]) == master_surfaces
for identity in ("GOLD",):
    row = by_id[identity]
    assert row["role"] == "johto_master_enemy_only"
    assert row["player_back_required"] is False
    assert set(row["surfaces"]) == (
        master_surfaces - {"arena_front_2d"} | {"arena_front_2d_coloured"}
    )

assets = [asset for row in characters for asset in row["assets"]]
assert len(assets) == len(set(assets)) == 48
for asset in assets:
    if asset == "assets/characters/crystal_chars/red_front.png":
        assert not (ROOT / asset).exists()
    else:
        assert (ROOT / asset).is_file(), f"missing authored identity asset: {asset}"

ordinary = contract["ordinary_trainers"]
assert ordinary["mapped_classes"] == 42
assert set(ordinary["modes"]) == {"crystal_hd", "frlg", "original"}, (
    "historical receipt itself drifted"
)
assert ordinary["fixed_identity_negative_control"] == [
    "RED", "BLUE", "GREEN", "SILVER", "KRIS", "GOLD",
]

pokemon = contract["crystal_pokemon"]
assert set(pokemon["required_surfaces"]) == {
    "title", "battle_front", "battle_back", "pokedex", "summary", "box",
    "hall_of_fame", "follower", "visible_wild",
}
assert set(pokemon["required_variants"]) == {"normal", "shiny"}
assert pokemon["must_animate_when_enabled"] is True

source = (ROOT / "extended_characters.lua").read_text()
main = (ROOT / "main.lua").read_text()
for identity in ("RED", "BLUE", "GREEN"):
    assert f'SPRITE_KA_CRYSTAL_" .. id .. "_WALK' in source
    assert f'{identity}' in source
for master in ("SILVER", "KRIS", "GOLD"):
    assert f"KA_JOHTO_{master}" in source
    assert f"{master.lower()}_voxel_front_hd.png" in source
assert 'trainer_portrait_style' in main
for mode in ("CRYSTAL HD", "ORIGINAL"):
    assert mode in main
assert 'menuLabel("FRLG", "FRBG")' not in main
assert 'M.modes = { "crystal_hd", "original" }' in (
    ROOT / "frlg_trainer_pack.lua"
).read_text()

print("character presentation contract: 6/6 fixed identities, 2/2 public trainer modes PASS")
