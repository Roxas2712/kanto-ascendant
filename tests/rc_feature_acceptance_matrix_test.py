#!/usr/bin/env python3
"""Every playable 6.5 scope row must have an explicit package gate."""

from __future__ import annotations

import json
import os
from pathlib import Path
import re
import csv


ROOT = Path(__file__).resolve().parents[1]
GATE = ROOT / "qa/rc28_release_gate_20260812"
master = json.loads((ROOT / "docs/RC65_MASTER_SCOPE_MATRIX.json").read_text())
matrix = (GATE / "FEATURE_ACCEPTANCE_MATRIX.md").read_text()

runtime = {
    row["id"]
    for row in master["requirements"]
    if row.get("gate") != "EDITOR"
    and not row.get("id", "").startswith("FUTURE-")
}
listed = set(re.findall(
    r"^\| ((?:RC65|LEGACY|REMATCH|MEW)-[^| ]+) \|",
    matrix,
    flags=re.MULTILINE,
))

missing = sorted(runtime - listed)
unexpected = sorted(listed - runtime)
assert not missing, "runtime scope missing from package matrix: " + ", ".join(missing)
assert not unexpected, "unknown package matrix scope: " + ", ".join(unexpected)
assert len(listed) == len(runtime) == 34, (len(listed), len(runtime))

for scope_id in sorted(runtime):
    line = next(
        row for row in matrix.splitlines()
        if row.startswith(f"| {scope_id} |")
    )
    assert "| OFFEN" in line, f"new RC gate must begin fail-closed: {scope_id}"

print("RC feature acceptance matrix: 34/34 PASS")


# Reverse gate: every shipped top-level product module belongs to exactly one
# acceptance group. This deliberately does not infer coverage only from
# loadSibling() calls: data/provider modules loaded indirectly must be gated too.
group_scopes = {
    "boot_migration_language": {"RC65-RELEASE-BUILD", "RC65-LEGACY-ARCHIVE-INTEGRITY"},
    "ascendant_ui_help": {"RC65-RELEASE-BUILD", "RC65-LEGACY-TITLES"},
    "bag_pc_capture": {"RC65-APRICORN-BALLS", "REMATCH-2-REWARDS"},
    "comfort_features": {"RC65-RELEASE-BUILD"},
    "battle_qol": {"RC65-EARLY-BALANCE", "RC65-RELEASE-BUILD"},
    "character_trainer_art": {"RC65-CRYSTAL-252-279", "RC65-GSC-LATEGAME", "RC65-OAK-FINALE"},
    "breeding_daycare": {"RC65-RELEASE-BUILD"},
    "shiny_mega_runtime": {"RC65-CRYSTAL-252-279", "RC65-HOENN-MEGAS", "RC65-HEVO-DATA"},
    "field_tech_movement": {"RC65-DUNGEON-RED", "RC65-DUNGEON-BLUE", "RC65-DUNGEON-GREEN"},
    "wilds_visibility": {"RC65-WILDS-PURSUIT", "RC65-HEVO-LV70-HABITATS"},
    "follower_runtime": {"RC65-FOLLOWER-MOTION"},
    "postgame_core": {"RC65-OAK-FINALE", "RC65-LEGACY-PARTNER", "RC65-RELEASE-BUILD"},
    "johto_mythic": {"RC65-GSC-LATEGAME", "MEW-PROVENANCE-BATTLE-ART"},
    "world_events_tour": {"LEGACY-WANDERERS-CORE", "RC65-LEGACY-TITLES"},
    "difficulty_run_rules": {"RC65-EARLY-BALANCE", "RC65-RELEASE-BUILD"},
    "compatibility_closure": {"RC65-RELEASE-BUILD", "MEW-PROVENANCE-BATTLE-ART"},
    "hidden_evolution": {
        "RC65-DUNGEON-RED", "RC65-DUNGEON-BLUE", "RC65-DUNGEON-GREEN",
        "RC65-DUNGEON-SHARED", "RC65-DUNGEON-EPILOG", "RC65-HEVO-15",
        "RC65-HEVO-LV70-HABITATS", "RC65-PROFESSOR-HINTS",
    },
    "legacy_ngplus": {
        "RC65-LEGACY-PARTNER", "RC65-LEGACY-PACT-MATRIX",
        "RC65-LEGACY-ARCHIVE-INTEGRITY", "RC65-LEGACY-THREE-JOURNEYS",
        "RC65-LEGACY-STORY", "RC65-LEGACY-WORKSHOP", "RC65-OAK-FINALE",
    },
    "rematch_progression": {"LEGACY-WANDERERS-CORE", "REMATCH-2-POOLS", "REMATCH-2-REWARDS"},
    "ball_systems": {"RC65-APRICORN-BALLS", "RC65-JOURNEYS-BALL-ART"},
}

map_path = GATE / "MODULE_ACCEPTANCE_MAP.tsv"
map_text = map_path.read_text(encoding="utf-8")
assert map_text.endswith("\n"), "module map must end with one newline"
map_lines = map_text.splitlines()
assert map_lines and all(map_lines), "module map contains a blank physical row"
parsed = list(csv.reader(map_lines, delimiter="\t"))
assert parsed[0] == ["module", "acceptance_group"], (
    "module map header drifted", parsed[0],
)
for line_number, (raw, row) in enumerate(zip(map_lines[1:], parsed[1:]), 2):
    assert len(row) == 2, f"module map line {line_number} has {len(row)} columns"
    assert raw == "\t".join(row), (
        f"module map line {line_number} uses quoting or non-canonical TSV"
    )
    assert all(value and value == value.strip() for value in row), (
        f"module map line {line_number} has an empty/padded field"
    )
    assert re.fullmatch(r"[a-z][a-z0-9_]*\.lua", row[0]), (
        f"module map line {line_number} is not one canonical top-level Lua path: "
        f"{row[0]!r}"
    )

rows = [dict(zip(parsed[0], row)) for row in parsed[1:]]

mapped = [row["module"] for row in rows]
duplicates = sorted(module for module in set(mapped) if mapped.count(module) > 1)
assert not duplicates, "module mapped more than once: " + ", ".join(duplicates)

# Mirror the exact-v079 ModKit semantics without building a package. Directory
# rules end in '/', own the complete subtree, and do not use glob syntax.
ignore_lines = (ROOT / ".modkitignore").read_text(encoding="utf-8").splitlines()
ignore_rules: list[str] = []
for line_number, raw in enumerate(ignore_lines, 1):
    line = raw.strip().replace("\\", "/")
    if not line or line.startswith("#"):
        continue
    assert raw == raw.strip() and "\\" not in raw, (
        f".modkitignore line {line_number} is not canonical: {raw!r}"
    )
    assert not line.startswith("/") and ".." not in Path(line).parts, (
        f".modkitignore line {line_number} escapes the package root: {line!r}"
    )
    assert not any(token in line for token in "*?[]"), (
        f".modkitignore line {line_number} uses unsupported glob syntax: {line!r}"
    )
    ignore_rules.append(line)
duplicate_rules = sorted(rule for rule in set(ignore_rules)
                         if ignore_rules.count(rule) > 1)
assert not duplicate_rules, (
    "duplicate .modkitignore rules: " + ", ".join(duplicate_rules)
)
ignored_exact = {rule for rule in ignore_rules if not rule.endswith("/")}
ignored_prefixes = {rule for rule in ignore_rules if rule.endswith("/")}


def package_ignores(relative: str) -> bool:
    return relative in ignored_exact or any(
        relative == prefix[:-1] or relative.startswith(prefix)
        for prefix in ignored_prefixes
    )


required_review_prefixes = {
    "qa/", "tests/", "tools/", "docs/", "art_review/", "artifacts/",
    "assets/sources/",
}
assert required_review_prefixes <= ignored_prefixes, (
    "review/source package prefixes missing from .modkitignore: "
    + ", ".join(sorted(required_review_prefixes - ignored_prefixes))
)
release_only_root_docs = sorted(
    path.name for path in ROOT.iterdir()
    if path.is_file() and re.fullmatch(
        r"(?:RELEASE_NOTES|ROLLBACK|INSTALL)_.+\.md|"
        r"DEMO_.+\.md|TESTKANDIDAT_.+\.md",
        path.name,
    )
)
unignored_release_docs = [name for name in release_only_root_docs
                          if not package_ignores(name)]
assert not unignored_release_docs, (
    "release/QA root documents would leak into the mod package: "
    + ", ".join(unignored_release_docs)
)

actual = sorted(path.name for path in ROOT.glob("*.lua")
                if not package_ignores(path.name))
ignored_top_level_lua = sorted(path.name for path in ROOT.glob("*.lua")
                               if package_ignores(path.name))
assert not ignored_top_level_lua, (
    "top-level Lua cannot be silently removed from the product boundary: "
    + ", ".join(ignored_top_level_lua)
)
assert sorted(mapped) == actual, (
    "shipped top-level product module coverage mismatch",
    sorted(set(actual) - set(mapped)),
    sorted(set(mapped) - set(actual)),
)
assert len(actual) == 148, f"frozen RC product module count drifted: {len(actual)}"

# Root contents are a positive allowlist. This catches arbitrary new reports,
# screenshots, local receipts, scripts, or editor files even when their names
# do not match one of the known release-document patterns above.
public_root_files = {
    ".modkitromallow",
    "CHANGELOG.md",
    "FAQ.md",
    "README.md",
    "THIRD_PARTY_NOTICES.md",
    "manifest.json",
    "mod.card",
}
shipped_root_files = {
    path.name
    for path in ROOT.iterdir()
    if path.is_file()
    and not package_ignores(path.name)
    and path.name != ".modkitignore"
    and (not path.name.startswith(".") or path.name in {".luarc.json", ".modkitromallow"})
}
expected_root_files = set(actual) | public_root_files
assert shipped_root_files == expected_root_files, (
    "top-level package boundary mismatch",
    "unexpected",
    sorted(shipped_root_files - expected_root_files),
    "missing",
    sorted(expected_root_files - shipped_root_files),
)

# Enumerate the complete would-be archive with exact-v079's directory/hidden
# rules. Besides the structural prefixes, no developer-machine absolute path
# may survive in product Lua, public docs, vendored sources, or binary assets.
package_files: list[Path] = []
for base, directories, filenames in os.walk(ROOT):
    base_path = Path(base)
    directories[:] = [
        name for name in directories
        if name not in {".git", ".modkit", "__pycache__", ".vscode"}
        and not name.startswith(".")
        and not package_ignores(
            (base_path / name).relative_to(ROOT).as_posix()
        )
    ]
    for name in filenames:
        if name.startswith(".") and name not in {".luarc.json", ".modkitromallow"}:
            continue
        path = base_path / name
        relative = path.relative_to(ROOT).as_posix()
        if relative == ".modkitignore" or package_ignores(relative):
            continue
        package_files.append(path)

relative_package_files = {
    path.relative_to(ROOT).as_posix() for path in package_files
}
internal_leaks = sorted(
    relative for relative in relative_package_files
    if relative.startswith(tuple(sorted(required_review_prefixes)))
)
assert not internal_leaks, (
    "internal review/source paths survive package enumeration: "
    + ", ".join(internal_leaks)
)
absolute_markers = (
    b"/Users/", b"/home/", b"C:\\Users\\", b"C:/Users/",
    b"/private/var/folders/", b"/tmp/",
)
absolute_path_leaks: list[str] = []
for path in package_files:
    data = path.read_bytes()
    if any(marker in data for marker in absolute_markers):
        absolute_path_leaks.append(path.relative_to(ROOT).as_posix())
assert not absolute_path_leaks, (
    "developer-machine absolute paths would leak into package: "
    + ", ".join(sorted(absolute_path_leaks))
)

used_groups = {row["acceptance_group"] for row in rows}
assert used_groups == set(group_scopes), (
    "acceptance group mismatch",
    sorted(set(group_scopes) - used_groups),
    sorted(used_groups - set(group_scopes)),
)
for group, scopes in group_scopes.items():
    assert scopes <= runtime, f"{group} maps to unknown scope: {sorted(scopes - runtime)}"

# Every shipped module must have an inbound product reference. The sole
# exception is an intentionally retired bridge whose acceptance is negative:
# the authority test proves that neither of its former Gen-II tilesets is
# registered. Any new orphan is a hard source/package-boundary failure.
product_sources = {
    path.name: path.read_text(encoding="utf-8")
    for path in ROOT.glob("*.lua")
}
manifest_text = (ROOT / "manifest.json").read_text(encoding="utf-8")
orphans = set()
for module in actual:
    if module == "main.lua":
        continue
    quoted = (f'"{module}"', f"'{module}'")
    referenced = any(
        source != module and any(token in body for token in quoted)
        for source, body in product_sources.items()
    ) or any(token in manifest_text for token in quoted)
    if not referenced:
        orphans.add(module)

negative_receipts = {
    "hidden_evolution_tilesets.lua": (
        ROOT / "tests/hidden_evolution_campaign_authority_load_test.lua",
        (
            "retired Johto Ice Path tileset is not loaded into the RC",
            "retired Johto Forest tileset is not loaded into the RC",
        ),
    ),
}
assert orphans == set(negative_receipts), (
    "unclassified orphan product modules",
    sorted(orphans - set(negative_receipts)),
    "stale orphan exceptions",
    sorted(set(negative_receipts) - orphans),
)
for module, (receipt_path, markers) in negative_receipts.items():
    assert receipt_path.is_file(), f"negative module receipt missing: {receipt_path}"
    receipt = receipt_path.read_text(encoding="utf-8")
    assert all(marker in receipt for marker in markers), (
        f"negative module receipt drifted: {module}"
    )

print(
    f"RC product module acceptance map: {len(mapped)}/{len(actual)} PASS; "
    f"{len(group_scopes)} groups; {len(negative_receipts)} negative-only module; "
    f"package include {len(package_files)} files/{sum(path.stat().st_size for path in package_files)} bytes; "
    "0 internal/absolute-path leaks"
)
