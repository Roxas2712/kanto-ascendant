#!/usr/bin/env python3
"""Fail closed unless UI-001 is package-only, bilingual and physical-input."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DRIVER = ROOT / "tests/item_select_help_visual_driver.lua"
SETUP = ROOT / "tests/item_select_help_language_setup_driver.lua"
driver = DRIVER.read_text("utf-8")
setup = SETUP.read_text("utf-8")

required = {
    "package gate": 'KA_PACKAGE_GATE") == "1"',
    "pinned util": "KA_TEST_UTIL",
    "language env": "QA_ITEM_HELP_LANGUAGE",
    "keyboard key path": "game:keypressed(key)",
    "keyboard release": "game:keyreleased(key)",
    "controller path": "game:gamepadpressed(nil, button)",
    "controller release": "game:gamepadreleased(nil, button)",
    "keyboard select": 'physicalKey("select", "tab"',
    "controller select": 'physicalPad("select", "back"',
    "keyboard start": 'physicalKey("start", "escape"',
    "controller start": 'physicalPad("start", "start"',
    "bag SELECT mark/place": "Bag keyboard SELECT marks",
    "bag help": "Bag keyboard START reaches",
    "pc help": "PC controller SELECT reaches",
    "shop buy": "BUY keyboard SELECT reaches",
    "shop sell": "SELL controller SELECT reaches",
    "read-only bag": "sameCounts(beforeBag",
    "read-only pc": "sameCounts(beforePc",
    "read-only money": "game.save.money == beforeMoney",
    "screenshots": '"/01_bag_controls_"',
    "matrix receipt": "physicalInputChecks == 9",
}
missing = [name for name, needle in required.items() if needle not in driver]

setup_required = {
    "setup package gate": 'KA_PACKAGE_GATE") == "1"',
    "setup EN only": 'QA_ITEM_HELP_LANGUAGE") == "en"',
    "native launcher": 'require("src.mods.LauncherMods")',
    "native disable": "LauncherMods.setEnabled(languageId, false, edition)",
    "edition scope": "SaveData.modScope(edition)",
    "German before": 'api.language() == "de"',
    "persisted disable": "SaveData.modEnabled(SaveData.loadOptions()",
    "setup receipt": "scope=UI-001-LANGUAGE-SETUP",
}
missing += [name for name, needle in setup_required.items() if needle not in setup]

assert not missing, "ITEM HELP PACKAGE CONTRACT FAIL:\n" + "\n".join(missing)
print(f"ITEM HELP PACKAGE CONTRACT PASS: {len(required) + len(setup_required)} checks")
