#!/usr/bin/env python3
"""Exercise Kanto Ascendant with the exact installed 0.1.86 Sandbox.

This is intentionally not a mocked reimplementation of the allow-list: the
test extracts the installed engine archive, imports its Sandbox.lua, compiles
the real mod entry in that environment, then calls main.lua's actual
mod:read/loadstring sibling loader against a directory install.
"""

from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
import textwrap
import zipfile


ROOT = Path(os.environ.get("TRAINER_REMATCH_MOD_DIR", Path(__file__).parents[1]))
ARCHIVE = Path(os.environ.get(
    "GEN1RECOMP_0186_LOVE",
    "/Users/maarten/Library/Application Support/pokemon-love2d/updates/"
    "gen1recomp-0.1.86.love",
))
LUAJIT = Path(os.environ.get(
    "KA_LUAJIT",
    "/Users/maarten/Documents/Recompile/gen1recomp/.tools/"
    "luajit-src/src/luajit",
))

EXPECTED_ARCHIVE = "51a446fc20b5d5b92143436aa5ed108353250909b89fe1ad9b19969144dbeaec"
EXPECTED_SANDBOX = "4fdecc9726022e78bd8b6e0de9fffbf8ed60a14b28128c3df3f5c7cf3e37efce"


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


assert ARCHIVE.is_file(), f"exact 0.1.86 archive missing: {ARCHIVE}"
assert LUAJIT.is_file(), f"LuaJIT missing: {LUAJIT}"
assert digest(ARCHIVE) == EXPECTED_ARCHIVE, "installed 0.1.86 archive hash changed"

with tempfile.TemporaryDirectory(prefix="ka-sandbox-0186-") as temp_name:
    temp = Path(temp_name)
    engine = temp / "engine"
    engine.mkdir()
    with zipfile.ZipFile(ARCHIVE) as bundle:
        bundle.extractall(engine)
    sandbox = engine / "src/mods/Sandbox.lua"
    assert digest(sandbox) == EXPECTED_SANDBOX, "exact Sandbox.lua hash changed"

    harness = temp / "exact_loader.lua"
    harness.write_text(textwrap.dedent(r'''
        local engine = assert(os.getenv("KA_EXACT_ENGINE"))
        local root = assert(os.getenv("TRAINER_REMATCH_MOD_DIR"))
        package.path = engine .. "/?.lua;" .. engine .. "/?/init.lua;"
          .. package.path

        -- Engine modules own the real LÖVE table. The mod only sees the
        -- exact Sandbox facade produced below.
        love = {
          filesystem = { getInfo = function(path)
            if path == "mods/external/assets/sprites/follower_PIKACHU.png" then
              return { type = "file" }
            end
          end },
        }

        local Sandbox = require("src.mods.Sandbox")
        local env = Sandbox.envFor({ modId = "kanto_ascendant", permissions = {} })
        assert(env._G == env and env._G ~= _G,
          "sandbox did not provide a private per-mod _G")
        env._G.__kaPrivateProbe = true
        assert(rawget(_G, "__kaPrivateProbe") == nil,
          "private mod global escaped into the host")
        for _, name in ipairs({
          "debug", "loadfile", "dofile", "getfenv", "setfenv", "io", "package",
        }) do
          assert(env[name] == nil, name .. " unexpectedly available")
        end
        for _, key in ipairs({ "filesystem", "system", "thread", "event" }) do
          local ok, message = pcall(function() return env.love[key] end)
          assert(not ok and tostring(message):find("not available to mods", 1, true),
            "love." .. key .. " did not use exact denied proxy")
        end
        local okDebug = pcall(env.require, "debug")
        assert(not okDebug, "sandbox require unexpectedly exposed debug")

        for _, path in ipairs({
          "../main.lua", "/main.lua", "C:/main.lua", "C:main.lua",
          "folder\\main.lua", "folder/../../main.lua",
        }) do
          assert(Sandbox.safePath(path) == nil,
            "SafePath accepted forbidden mod path " .. path)
        end
        assert(Sandbox.safePath("./sub/../main.lua") == nil,
          "SafePath normalized a traversal segment")
        assert(Sandbox.safePath("./main.lua") == "main.lua",
          "SafePath rejected a safe relative source path")
        local bytecode = string.dump(function() return true end)
        local binary, binaryErr = Sandbox.compile(bytecode, "@entry.lua", env)
        assert(binary == nil and tostring(binaryErr):find("source, not bytecode", 1, true),
          "entry bytecode was not rejected")
        local loadedBinary, loadBinaryErr = env.load(bytecode, "@sibling.lua")
        assert(loadedBinary == nil
            and tostring(loadBinaryErr):find("source, not bytecode", 1, true),
          "sandboxed sibling load accepted bytecode")

        -- Engine internals remain callable through the sanctioned require
        -- gate and can resolve cross-mod/save paths without handing the mod
        -- love.filesystem itself (the same bridge internal_wilds.V.exists uses).
        local Assets = env.require("src.render.Assets")
        assert(Assets.exists(
          "mods/external/assets/sprites/follower_PIKACHU.png") == true,
          "engine Assets.exists did not resolve an external follower path")

        local function read(path)
          local handle = assert(io.open(path, "rb"))
          local body = handle:read("*a")
          handle:close()
          return body
        end
        local main = read(root .. "/main.lua")
        local chunk = assert(Sandbox.compile(main, "@" .. root .. "/main.lua", env))
        local factory = assert(chunk())
        assert(type(factory) == "function", "main.lua did not return its factory")

        -- Call main.lua's own closure rather than a test copy of its loader.
        local loadSibling
        for index = 1, 200 do
          local name, value = debug.getupvalue(factory, index)
          if not name then break end
          if name == "loadSibling" then loadSibling = value; break end
        end
        assert(type(loadSibling) == "function", "main loadSibling upvalue missing")
        local mod = { path = root }
        function mod:read(relative)
          local handle = io.open(root .. "/" .. relative, "rb")
          if not handle then return nil, "missing " .. relative end
          local body = handle:read("*a")
          handle:close()
          return body
        end
        local expected = {
          ["driftglass_prisms.lua"] = "table",
          ["identity_migration.lua"] = "table",
        }
        for _, file in ipairs({
          "postgame_species.lua", "driftglass_prisms.lua", "mega_evolution.lua",
          "gorochu_visuals.lua", "dramaless_camera_compat.lua",
          "dramaless_wall_decals_compat.lua", "dramaless_camera_option.lua",
          "postgame.lua", "truecolor_world_compat.lua", "sprite_assets.lua",
          "shiny_system.lua", "legacy_archive.lua", "single_follower.lua",
          "identity_migration.lua", "frlg_trainer_pack.lua", "internal_wilds.lua",
          "title_intro.lua",
        }) do
          local value = loadSibling(mod, file)
          assert(type(value) == (expected[file] or "function"),
            file .. " did not execute in exact sandbox")
        end

        -- This source-level bridge is deliberately verified alongside the
        -- exact engine Assets call above: own-root reads win; foreign paths
        -- delegate to the engine facade and never touch env.love.filesystem.
        local wilds = read(root .. "/internal_wilds.lua")
        assert(wilds:find('pcall(require, "src.render.Assets")', 1, true)
            and wilds:find("pcall(Assets.exists, path)", 1, true),
          "internal Wilds lost its sanctioned external asset bridge")

        print("PASS exact 0.1.86 Sandbox: private _G, denied proxy, SafePath, source-only entry/siblings, Assets.exists")
    '''), encoding="utf-8")

    env = os.environ.copy()
    env["KA_EXACT_ENGINE"] = str(engine)
    env["TRAINER_REMATCH_MOD_DIR"] = str(ROOT)
    result = subprocess.run(
        [str(LUAJIT), str(harness)],
        env=env,
        cwd=ROOT,
        text=True,
        capture_output=True,
        check=False,
    )
    if result.returncode:
        raise AssertionError(
            "exact Sandbox loader failed\nSTDOUT:\n"
            + result.stdout + "\nSTDERR:\n" + result.stderr
        )
    print(result.stdout.strip())

manifest = json.loads((ROOT / "manifest.json").read_text(encoding="utf-8"))
for field in ("entry", "options_schema"):
    value = manifest.get(field)
    if value is None:
        continue
    assert isinstance(value, str) and value
    assert not value.startswith(("/", "\\"))
    assert not re.match(r"^[A-Za-z]:", value)
    assert "\\" not in value and ".." not in value.split("/")
    assert not (ROOT / value).read_bytes().startswith(b"\x1b"), (
        field + " must be Lua source"
    )

main_source = (ROOT / "main.lua").read_text(encoding="utf-8")
siblings = re.findall(
    r"loadSibling\s*\(\s*mod\s*,\s*[\r\n ]*\"([^\"]+)\"",
    main_source,
)
assert siblings, "main.lua sibling inventory is empty"
for relative in siblings:
    assert not relative.startswith(("/", "\\"))
    assert not re.match(r"^[A-Za-z]:", relative)
    assert "\\" not in relative and ".." not in relative.split("/")
    target = ROOT / relative
    assert target.is_file(), "missing packaged sibling " + relative
    assert not target.read_bytes().startswith(b"\x1b"), (
        relative + " must be Lua source"
    )

# Foreign mod discovery is capability-based only. The engine-owned Game/Loader
# tables are not a communication channel and no compatibility module may add a
# global alias on another package's behalf.
foreign_patterns = (
    "game.mods.exports", "mods.exports", "loader.exports", "loader.mods",
    "currentGame.mods.exports",
)
for source_path in ROOT.rglob("*.lua"):
    relative = source_path.relative_to(ROOT)
    if relative.parts[0] in {"tests", "tools", "qa"}:
        continue
    body = source_path.read_text(encoding="utf-8")
    for pattern in foreign_patterns:
        assert pattern not in body, f"foreign global channel {pattern}: {relative}"

for relative in (
    "extended_species_runtime.lua", "follower_compat.lua", "yellow_partner.lua",
    "single_follower.lua", "johto_signals_hub.lua", "johto_signals_wilds.lua",
    "crystal_animation.lua", "shiny_system.lua", "wilds_compat.lua",
    "voxel_renderer_compat.lua",
):
    assert "mod.find" in (ROOT / relative).read_text(encoding="utf-8"), (
        relative + " lost its official foreign-export discovery seam"
    )

print("PASS exact archive hashes: gen1recomp 0.1.86 + Sandbox.lua")
