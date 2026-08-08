-- The Dramaless camera switch belongs in the regular OPTIONS rows, not in
-- Kanto Ascendant's per-mod manager page.  Its writer still needs to drive
-- the normal mod option event so the live camera changes immediately.

package.path = "./?.lua;./?/init.lua;" .. package.path

local S = require("tests.harness").suite("dramaless camera option menu")
local eq = S.eq
local modDir = assert(os.getenv("TRAINER_REMATCH_MOD_DIR"),
  "TRAINER_REMATCH_MOD_DIR is required")

local hook
local stored
local mod = {
  id = "trainer_rematch",
  options = { get = function(_, key)
    eq(key, "dramaless_battle_camera", "main-options row reads its camera key")
    return stored
  end },
  hooks = { wrap = function(_, name, callback, priority)
    eq(name, "ui.options.rows", "camera registers a main-options hook")
    eq(priority, 1000, "camera decorates renderer options after their rows")
    hook = callback
  end },
}

local cameraOption = dofile(modDir .. "/dramaless_camera_option.lua")(mod, {
  camera = "DRAMALESS BATTLE CAMERA",
  fork = "FORK DEFAULT",
  classic = "CLASSIC VOXEL",
})
cameraOption.install()

local emitted = {}
local game = {
  save = { options = {} },
  mods = {
    exports = { DRAMALESS_SHAPE = {} },
    events = { emit = function(_, name, payload)
      if name == "mod.options_changed" then stored = payload.value end
      emitted[#emitted + 1] = { name = name, payload = payload }
    end },
  },
  writeOptions = function() emitted[#emitted + 1] = { name = "persist" } end,
}

local rows = hook(function() return {
  { id = "pipeline:voxel" },
  { id = "DRAMALESS_SHAPE:overworld_battle" },
  { id = "sound" },
} end, game, {})
eq(rows[3].id, "trainer_rematch:dramaless_battle_camera",
  "camera appears immediately after the Dramaless Voxel controls")
eq(rows[3].label, "DRAMALESS BATTLE CAMERA",
  "camera keeps its localized main-options label")
eq(rows[3].value(), "FORK DEFAULT", "camera defaults to the fork view")

rows[3].step(game)
eq(game.save.options.modOptions.trainer_rematch.dramaless_battle_camera,
  "classic", "main-options step persists the classic selection")
eq(game.mods.modOptions.trainer_rematch.dramaless_battle_camera,
  "classic", "main-options step updates the live option store")
eq(rows[3].value(), "CLASSIC VOXEL", "row reflects its new live selection")
eq(emitted[#emitted].name, "mod.options_changed",
  "main-options step notifies the camera compatibility bridge")
eq(emitted[#emitted].payload.mod, "trainer_rematch",
  "camera notification remains namespaced to Kanto Ascendant storage")

local noRenderer = hook(function() return { { id = "pipeline:voxel" } } end,
  { mods = { exports = {} } }, {})
eq(#noRenderer, 1, "camera row stays hidden when Dramaless is unavailable")

S.finish()
