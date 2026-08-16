#!/usr/bin/env python3
"""Release-boundary audit for the shared Kanto Ascendant menu skin."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
checks = 0


def require(value: bool, message: str) -> None:
    global checks
    checks += 1
    if not value:
        raise AssertionError(message)


theme = (ROOT / "ascendant_ui.lua").read_text(encoding="utf-8")
main = (ROOT / "main.lua").read_text(encoding="utf-8")
require("__kantoAscendantLayout" in theme, "layout marker missing")
require("trueColorZone(0, 0, 19, 17)" in theme, "true-color UI zone missing")
for token in ("blue3", "orange", "gold", "cream"):
    require(token in theme, f"FireRed palette token {token} missing")
require('loadSibling(mod, "ascendant_ui.lua")' in main,
        "main does not load the shared UI before feature modules")
require("mod.ui.KantoListMenu = ascendantUi.ListMenu" in main,
        "Kanto list facade is not installed")

raw_users = []
styled_users = []
for path in sorted(ROOT.glob("*.lua")):
    body = path.read_text(encoding="utf-8")
    if path.name != "ascendant_ui.lua" and "mod.ui.ListMenu.new" in body:
        raw_users.append(path.name)
    if "mod.ui.KantoListMenu or mod.ui.ListMenu" in body:
        styled_users.append(path.name)
require(not raw_users,
        "mod-owned lists bypass the shared layout: " + ", ".join(raw_users))
require(len(styled_users) >= 17,
        f"expected broad feature coverage, found only {len(styled_users)} modules")
for essential in (
    "ascendant_menu.lua", "rematch_rewards.lua", "follower_config.lua",
    "johto_signals_hub.lua", "field_tech.lua", "daycare.lua",
    "mega_evolution.lua", "research_atlas.lua", "grand_tour.lua",
):
    require(essential in styled_users, f"essential screen family unthemed: {essential}")

print(f"ASCENDANT UI AUDIT PASS: {checks} checks, "
      f"{len(styled_users)} themed modules")
