#!/usr/bin/env python3
"""Static release-boundary audit for the integrated Phase-10 candidate."""

from __future__ import annotations

import json
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
checks = 0


def require(condition: bool, message: str) -> None:
    global checks
    checks += 1
    if not condition:
        raise AssertionError(message)


manifest = json.loads((ROOT / "manifest.json").read_text(encoding="utf-8"))
require(manifest["id"] == "kanto_ascendant", "released save/mod id drifted")
require(manifest["name"] == "Kanto Ascendant", "public name drifted")
require(manifest["version"] == "6.5.15", "6.5 integration version drifted")
require(manifest.get("dependencies") == [], "an external runtime became required")
require(manifest.get("entry") == "main.lua", "unexpected runtime entry point")

package_ignore = (ROOT / ".modkitignore").read_text(encoding="utf-8")
ignored = set()
ignored_prefixes = []
for raw_line in package_ignore.splitlines():
    line = raw_line.strip().replace("\\", "/")
    if not line or line.startswith("#"):
        continue
    if line.endswith("/"):
        ignored_prefixes.append(line)
    else:
        ignored.add(line)
missing_ignores = []
for prefix in (
    "qa", "art_review", "tests", "tools", "docs", "artifacts", "assets/sources",
):
    base = ROOT / prefix
    if base.is_dir():
        for path in base.rglob("*"):
            if not path.is_file():
                continue
            relative = path.relative_to(ROOT).as_posix()
            if relative not in ignored and not any(
                    relative.startswith(item) for item in ignored_prefixes):
                missing_ignores.append(relative)
require(not missing_ignores,
        "release package would include QA/source files: " + ", ".join(missing_ignores))

runtime = "\n".join(
    path.read_text(encoding="utf-8")
    for path in sorted(ROOT.glob("*.lua"))
)
require(not re.search(r"(?<![.:])\b(?:print|io\.write)\s*\(", runtime),
        "debug global console output remains in runtime Lua")
require("★" not in runtime, "unsupported decorative star remains in Gen-I UI text")
require("EXP_DOUBLER" not in runtime.upper(),
        "obsolete EXP Doubler identifier remains in runtime")
require("os.execute" not in runtime and "io.popen" not in runtime,
        "runtime shells out to an external process")

followers = (ROOT / "single_follower.lua").read_text(encoding="utf-8")
require('setmetatable({}, { __mode = "k" })' in followers,
        "follower runtime ownership is not weak-keyed")
require("MAX_FOLLOWERS, MAX_TRAIL = 6, 64" in followers,
        "follower count/trail bounds changed")
require("never serialized" in followers,
        "runtime-only follower object boundary is undocumented")

config = (ROOT / "follower_config.lua").read_text(encoding="utf-8")
require("local VERSION = 1" in config and "s.version = VERSION" in config,
        "follower save state is not versioned/normalized")
require("math.min(MAX_FOLLOWERS" in config,
        "follower save count is not capped through the shared limit")

difficulty = (ROOT / "difficulty.lua").read_text(encoding="utf-8")
require("if #pending >= 8 then table.remove(pending, 1) end" in difficulty,
        "difficulty preview queue is unbounded")

visions = (ROOT / "vision_encounters.lua").read_text(encoding="utf-8")
require("STATE_VERSION = 2" in visions and "state.version = V.STATE_VERSION" in visions,
        "vision once-flags are not versioned/normalized")

rewards = (ROOT / "rematch_rewards.lua").read_text(encoding="utf-8")
require("local function reservePending" in rewards,
        "reward overflow has no shared reservation path")
require("s.pendingItems = compact" in rewards,
        "legacy duplicate reward reservations are not compacted")
require("math.min(9999" in rewards, "pending reward quantities are not capped")

notices = (ROOT / "THIRD_PARTY_NOTICES.md").read_text(encoding="utf-8")
for label in (
    "PokeWilds follower sprites",
    "Crystal Clear Kanto follower sprites",
    "Follower EX was evaluated",
    "Pokémon Channel Raichu voice clips",
    "All Pokémon Catchable 151 Mod",
):
    require(label in notices, f"missing provenance notice: {label}")

phase_modules = {
    "followers": ("single_follower.lua", "follower_config.lua", "follower_sprites.lua"),
    "rematch": ("rematch_mastery.lua", "rematch_rewards.lua", "rematch_loot.lua"),
    "core": ("difficulty.lua", "item_protection.lua", "vision_encounters.lua"),
}
for group, paths in phase_modules.items():
    require(all((ROOT / path).is_file() for path in paths),
            f"integrated {group} module set is incomplete")

print(f"PHASE 10 STATIC AUDIT PASS: {checks} checks")
