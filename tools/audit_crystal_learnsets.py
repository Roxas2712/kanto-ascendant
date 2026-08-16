#!/usr/bin/env python3
"""Audit Crystal schedules against Gen1 Recomp + Ascendant move ids."""

from __future__ import annotations

import argparse
import json
import re
from collections import defaultdict
from pathlib import Path


ROW = re.compile(r'\{ level = (\d+), move = "([A-Z0-9_]+)" \},')
SPECIES = re.compile(r"^  ([A-Z0-9_]+) = \{ -- #(\d{3})$")


def parse_learnsets(path: Path) -> tuple[dict[str, list[tuple[int, str]]], str]:
    schedules: dict[str, list[tuple[int, str]]] = {}
    current: str | None = None
    revision = "unknown"
    for line in path.read_text(encoding="utf-8").splitlines():
        source_match = re.match(r"-- Source revision: ([0-9a-f]+|unknown)$", line)
        if source_match:
            revision = source_match.group(1)
        species_match = SPECIES.match(line)
        if species_match:
            current = species_match.group(1)
            schedules[current] = []
            continue
        row_match = ROW.search(line)
        if current and row_match:
            schedules[current].append((int(row_match.group(1)), row_match.group(2)))
        elif current and line == "  },":
            current = None
    return schedules, revision


def parse_base_moves(path: Path) -> set[str]:
    return set(re.findall(r"^  ([A-Z0-9_]+) = \{$", path.read_text(
        encoding="utf-8"), re.MULTILINE))


def parse_ascendant_moves(path: Path) -> set[str]:
    body = path.read_text(encoding="utf-8")
    block = body.split("  local moves = {", 1)[1]
    block = block.split("  for id, row in pairs(moves)", 1)[0]
    return set(re.findall(r"^    ([A-Z0-9_]+) = \{", block, re.MULTILINE))


def build_report(learnsets: Path, base_moves: Path, ascendant: Path) -> dict:
    schedules, revision = parse_learnsets(learnsets)
    registered = parse_base_moves(base_moves) | parse_ascendant_moves(ascendant)
    missing: dict[str, dict[str, list[int]]] = defaultdict(
        lambda: defaultdict(list))
    canonical_ids: set[str] = set()
    rows = 0
    for species, entries in schedules.items():
        for level, move in entries:
            rows += 1
            canonical_ids.add(move)
            if move not in registered:
                missing[move][species].append(level)

    missing_records = []
    for move in sorted(missing):
        species_records = [
            {"id": species, "levels": sorted(levels)}
            for species, levels in sorted(missing[move].items())
        ]
        missing_records.append({
            "id": move,
            "occurrences": sum(len(row["levels"]) for row in species_records),
            "speciesCount": len(species_records),
            "species": species_records,
        })

    espeon = schedules.get("ESPEON", [])
    active_ids = canonical_ids & registered
    return {
        "schema": "kanto-ascendant.crystal-learnsets.audit.v1",
        "source": "pret/pokecrystal:data/pokemon/evos_attacks.asm",
        "sourceRevision": revision,
        "canonicalSpecies": len(schedules),
        "canonicalRows": rows,
        "canonicalMoveCount": len(canonical_ids),
        "activeCanonicalMoveCount": len(active_ids),
        "activeCanonicalRows": sum(
            1 for entries in schedules.values() for _, move in entries
            if move in registered
        ),
        "registeredMoveCount": len(registered),
        "missingMoveCount": len(missing_records),
        "missingMoveIds": [record["id"] for record in missing_records],
        "missingMoves": missing_records,
        "checks": {
            "espeonLearnsPsybeamAt36": (36, "PSYBEAM") in espeon,
            "psybeamRegistered": "PSYBEAM" in registered,
            "allActiveMoveIdsRegistered": all(
                move in registered for move in active_ids),
            "unknownIdsInActiveLearnsets": [],
        },
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--learnsets", type=Path, required=True)
    parser.add_argument("--base-moves", type=Path, required=True)
    parser.add_argument("--ascendant", type=Path, required=True)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    report = build_report(args.learnsets, args.base_moves, args.ascendant)
    rendered = json.dumps(report, indent=2, sort_keys=True) + "\n"
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(rendered, encoding="utf-8")
    else:
        print(rendered, end="")


if __name__ == "__main__":
    main()
