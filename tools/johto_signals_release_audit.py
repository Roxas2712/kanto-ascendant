#!/usr/bin/env python3
"""Fail closed when a Johto Signals package leaks frozen Lab content.

The component branch intentionally still lives beside the frozen Starfall
prototype.  This audit is therefore aimed at either:

* a final Kanto Ascendant 6.x source/package directory (default), or
* only the extracted Signals components (``--component``).

It uses only Python's standard library so the same command can run locally
and in GitHub CI against a directory, ``.zip`` or ``.modpkg``.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path, PurePosixPath
import sys
import zipfile


RELEASE_VERSION = "6.5.15"
CURRENT_RELEASE_NOTES = "RELEASE_NOTES_6.5.15.md"

REQUIRED_COMPONENTS = {
    "driftglass_prisms.lua",
    "johto_encounter_levels.lua",
    "johto_signals.lua",
    "johto_signals_content.lua",
    "johto_signals_hub.lua",
    "johto_signals_state.lua",
    "johto_signals_wilds.lua",
    "mythic_signals.lua",
}

REQUIRED_PACKAGE_FILES = {
    "README.md",
    "manifest.json",
    "mod.card",
}

REQUIRED_SOURCE_FILES = REQUIRED_PACKAGE_FILES | {
    CURRENT_RELEASE_NOTES,
}

PUBLIC_RELEASE_TEXTS = {
    "README.md",
    CURRENT_RELEASE_NOTES,
    "mod.card",
}

FORBIDDEN_PATH_PARTS = {
    "assets/guests/",
    "assets/orange_trainers/",
    "fairy_research.lua",
    "orange_archipelago.lua",
    "orange_puzzles.lua",
    "starfall_content.lua",
    "starfall_debug.lua",
    "starfall_orange_maps.lua",
    "starfall_state.lua",
    "tools/starfall_",
}

FORBIDDEN_PRODUCTION_TOKENS = {
    "FAIRY_TYPE",
    "JIRACHI",
    "ORANGE_PASS",
    "STARFALL_",
    "SYLVEON",
    "WISH_CORE",
}

TEXT_SUFFIXES = {".lua", ".json"}

# Vendored upstream data can legitimately contain species that Kanto
# Ascendant never registers.  Token-scanning it would confuse an asset name
# with a production unlock.  The package boundary is still checked above;
# only the semantic production-token scan skips these non-runtime sources.
TOKEN_SCAN_EXCLUDED_PREFIXES = (
    "qa/",
    "tests/",
    "tools/",
    "vendor/",
)


class PackageReader:
    def __init__(self, source: Path):
        self.source = source
        self._zip: zipfile.ZipFile | None = None
        if source.is_file():
            self._zip = zipfile.ZipFile(source)
            self.names = sorted(
                self._normalise(name)
                for name in self._zip.namelist()
                if not name.endswith("/")
            )
            self._prefix = self._common_prefix(self.names)
        else:
            self.names = sorted(
                path.relative_to(source).as_posix()
                for path in source.rglob("*")
                if path.is_file() and ".git" not in path.parts
            )
            self._prefix = ""

    @staticmethod
    def _normalise(name: str) -> str:
        path = PurePosixPath(name)
        if path.is_absolute() or ".." in path.parts:
            raise ValueError(f"unsafe archive entry: {name}")
        normalised = path.as_posix()
        while normalised.startswith("./"):
            normalised = normalised[2:]
        return normalised

    @staticmethod
    def _common_prefix(names: list[str]) -> str:
        if not names:
            return ""
        first = names[0].split("/", 1)
        if len(first) != 2:
            return ""
        root = first[0] + "/"
        return root if all(name.startswith(root) for name in names) else ""

    def relative_names(self) -> list[str]:
        if not self._prefix:
            return self.names
        return [name[len(self._prefix) :] for name in self.names]

    def read(self, relative_name: str) -> bytes:
        if self._zip is not None:
            return self._zip.read(self._prefix + relative_name)
        return (self.source / relative_name).read_bytes()

    def close(self) -> None:
        if self._zip is not None:
            self._zip.close()


def audit(source: Path, component_only: bool) -> list[str]:
    errors: list[str] = []
    reader = PackageReader(source)
    try:
        names = reader.relative_names()
        present = set(names)

        missing = sorted(REQUIRED_COMPONENTS - present)
        if missing:
            errors.append("missing required components: " + ", ".join(missing))

        selected_names = (
            sorted(REQUIRED_COMPONENTS & present) if component_only else names
        )
        if not component_only:
            required_files = (
                REQUIRED_PACKAGE_FILES if source.is_file()
                else REQUIRED_SOURCE_FILES
            )
            missing_release = sorted(required_files - present)
            if missing_release:
                errors.append(
                    "missing release files: " + ", ".join(missing_release)
                )
            lowered = {name.lower(): name for name in names}
            for fragment in sorted(FORBIDDEN_PATH_PARTS):
                for lower_name, original in lowered.items():
                    if fragment.lower() in lower_name:
                        errors.append(
                            f"frozen Lab path leaked into package: {original}"
                        )

            if "manifest.json" in present:
                try:
                    manifest = json.loads(reader.read("manifest.json"))
                except (UnicodeDecodeError, json.JSONDecodeError) as exc:
                    errors.append(f"manifest.json is invalid: {exc}")
                else:
                    if manifest.get("id") != "kanto_ascendant":
                        errors.append(
                            "manifest id must be kanto_ascendant"
                        )
                    if str(manifest.get("version", "")) != RELEASE_VERSION:
                        errors.append(
                            "manifest version must be exactly " + RELEASE_VERSION
                        )
                    if manifest.get("experimental") is True:
                        errors.append("release manifest must not be experimental")

        for name in selected_names:
            if not component_only and name.startswith(TOKEN_SCAN_EXCLUDED_PREFIXES):
                continue
            if (
                PurePosixPath(name).suffix.lower() not in TEXT_SUFFIXES
                and name not in PUBLIC_RELEASE_TEXTS
            ):
                continue
            try:
                text = reader.read(name).decode("utf-8")
            except UnicodeDecodeError:
                errors.append(f"text file is not UTF-8: {name}")
                continue
            for token in sorted(FORBIDDEN_PRODUCTION_TOKENS):
                if token in text:
                    errors.append(f"forbidden token {token} in {name}")

        return errors
    finally:
        reader.close()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument(
        "--component",
        action="store_true",
        help="audit only the extracted Signals modules",
    )
    args = parser.parse_args()

    if not args.source.exists():
        parser.error(f"source does not exist: {args.source}")

    try:
        errors = audit(args.source.resolve(), args.component)
    except (OSError, ValueError, zipfile.BadZipFile) as exc:
        print(f"JOHTO SIGNALS SCOPE AUDIT FAIL: {exc}", file=sys.stderr)
        return 2

    if errors:
        print("JOHTO SIGNALS SCOPE AUDIT FAIL", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1

    mode = "components" if args.component else "release package"
    print(f"JOHTO SIGNALS SCOPE AUDIT PASS: {mode}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
