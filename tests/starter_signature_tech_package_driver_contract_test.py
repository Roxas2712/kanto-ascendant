#!/usr/bin/env python3
"""Fail-closed source contract for the TECH-001 package-only driver."""

from __future__ import annotations

from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[1]
DRIVER = ROOT / "tools/starter_signature_tech_package_driver.lua"
FIELD_TECH = ROOT / "field_tech.lua"
source = DRIVER.read_text(encoding="utf-8")
field_tech = FIELD_TECH.read_text(encoding="utf-8")

expected = {
    "FRENZY_PLANT": [
        "BULBASAUR", "IVYSAUR", "VENUSAUR",
        "CHIKORITA", "BAYLEEF", "MEGANIUM",
        "TREECKO", "GROVYLE", "SCEPTILE",
    ],
    "BLAST_BURN": [
        "CHARMANDER", "CHARMELEON", "CHARIZARD",
        "CYNDAQUIL", "QUILAVA", "TYPHLOSION",
        "TORCHIC", "COMBUSKEN", "BLAZIKEN",
    ],
    "HYDRO_CANNON": [
        "SQUIRTLE", "WARTORTLE", "BLASTOISE",
        "TOTODILE", "CROCONAW", "FERALIGATR",
        "MUDKIP", "MARSHTOMP", "SWAMPERT",
    ],
}

# Parse the executable expectation table, not comments or a documentation
# inventory. Every move must retain exactly nine ordered stages.
expectation_block = source.split("local expected = {", 1)[1].split(
    "local external = {", 1
)[0]
for move_id, species in expected.items():
    match = re.search(
        rf"\b{re.escape(move_id)}\s*=\s*\{{(.*?)\n\s*\}},",
        expectation_block,
        re.DOTALL,
    )
    assert match, move_id
    actual = re.findall(r'"([A-Z][A-Z0-9_]*)"', match.group(1))
    assert actual == species, (move_id, actual)
assert len({mon for family in expected.values() for mon in family}) == 27

external_expected = {
    move_id: [f"TECH_EXT_{species}" for species in species[6:]]
    for move_id, species in expected.items()
}
external_block = source.split("local external = {", 1)[1].split(
    "local machines = {", 1
)[0]
for move_id, species in external_expected.items():
    match = re.search(
        rf"\b{re.escape(move_id)}\s*=\s*\{{(.*?)\n\s*\}},",
        external_block,
        re.DOTALL,
    )
    assert match, f"external/{move_id}"
    actual = re.findall(r'"([A-Z][A-Z0-9_]*)"', match.group(1))
    assert actual == species, (f"external/{move_id}", actual)
assert len({mon for family in external_expected.values() for mon in family}) == 9

for token in (
    'os.getenv("KA_PACKAGE_GATE") == "1"',
    'requiredSha("KA_ENGINE_PAYLOAD_SHA256")',
    'requiredSha("KA_AUTHORITY_PACKAGE_SHA256")',
    'requiredSha("KA_DEUTSCH_PACKAGE_SHA256")',
    '"KA_PACKAGE_GATE_RECEIPT_SHA256"',
    'dofile(utilPath)',
    'require("src.core.SaveData")',
    'require("src.core.GameVersion")',
    'require("src.pokemon.Pokemon")',
    'os.getenv("POKEPORT_VERSION")',
    'os.getenv("POKEPORT_IDENTITY")',
    'SaveData.setActiveSlot(edition, slot)',
    'SaveData.newGame(game:bootConfig())',
    'game:restoreSave(fresh, false)',
    'game:writeSave()',
    'SaveData.load(edition)',
    'game:restoreSave(reloaded, recovered)',
    'love.filesystem.getSource()',
    'loaded.kanto_ascendant',
    'api.fieldTech',
    'tech.registerStarterFamilyProvider(',
    '"qa_external_hoenn_252_260"',
    'not tech.syncStarterFamilies(game.data)',
    'tech.syncStarterFamilies(game.data)',
    'partial external Hoenn provider did not fail closed',
    'external provider did not reactivate after its stage returned',
    'restored canonical provider did not shadow the optional provider',
    'tech.afterBossWin(game, machine.gym, "crown")',
    'tech.rememberMove(game, mon, moveId)',
    'row.id == moveId and row.source == "crown"',
    'transactionState.signatureUnlocked[machine.item] == true',
    'transactionState.signatureAwarded[machine.item] == true',
    'savedState.signatureUnlocked[machine.item] == true',
    'savedState.signatureAwarded[machine.item] == true',
    'status=PASS',
    'scope=TECH-001-STARTER-SIGNATURES',
    'edition=',
    'external_provider=qa_external_hoenn_252_260',
    'external_partial_fail_closed=18/18',
    'external_complete=27/27',
    'external_reactivation=27/27',
    'canonical_restored=27/27',
    'cardinality=9/9/9',
    'stages=27/27',
    'unique_stages=27/27',
    'tm_compatibility=27/27',
    'reminder=',
    'tm_transactions=',
    'reminder_transactions=',
    'native_save_reload=1/1',
    'persisted_tm_inventory=',
    'persisted_reminder_moves=',
    'persisted_reminder_access=',
    'fail=0',
    'love.event.quit(0)',
):
    assert token in source, token

# The installed driver may register one disposable external provider and
# alias installed Hoenn definitions to prove alternate internal ids. It may
# not load source fixtures, replace the controller's family tables, or skip
# the product award/reminder/save APIs by writing protected save state.
for forbidden in (
    "loadfile(", "package.path", "tests/fixtures", "U.teleport",
    "/Users/",
):
    assert forbidden not in source, forbidden
for pattern in (
    r"tech\.starterFamilies\s*=(?!=)",
    r"tech\.starterFamilies\[[^]]+\]\s*=(?!=)",
    r"status\.totalStages\s*=(?!=)",
    r"signatureUnlocked\[[^]]+\]\s*=\s*true",
    r"signatureAwarded\[[^]]+\]\s*=\s*true",
    r"game\.save\.inventory\[[^]]+\]\s*=",
):
    assert not re.search(pattern, source), pattern

# Keep the product seam and its late installed-registry resolution in the same
# contract as the package proof so a decorative 27-row driver cannot outlive
# the actual provider implementation.
for token in (
    'registerStarterFamilyProvider',
    'syncStarterFamilies',
    'starterFamilyStatus',
    'registered_hoenn_252_260',
    'partial #252-260 registrations completely ineligible',
    'F.syncStarterFamilies(game.data)',
    'starter-family cardinality drifted',
):
    assert token in field_tech, token

print("TECH-001 package driver contract PASS: 3 x 9 = 27 exact stages")
