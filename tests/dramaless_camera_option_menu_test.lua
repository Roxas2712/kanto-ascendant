-- The Voxel camera switch belongs in the regular OPTIONS rows, not in
-- Kanto Ascendant's per-mod manager page.  Its writer still needs to drive
-- the normal mod option event so the live camera changes immediately.

package.path = "./?.lua;./?/init.lua;" .. package.path

local S = require("tests.harness").suite("voxel camera option menu")
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
  camera = "VOXEL BATTLE CAMERA",
  fork = "VOXEL DEFAULT",
  classic = "CLASSIC VOXEL",
  wide = "WIDE VOXEL",
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
  "camera appears immediately after the compatible Voxel controls")
eq(rows[3].label, "VOXEL BATTLE CAMERA",
  "camera keeps its localized main-options label")
eq(rows[3].value(), "VOXEL DEFAULT", "camera defaults to the standard view")

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

rows[3].step(game)
eq(game.save.options.modOptions.trainer_rematch.dramaless_battle_camera,
  "wide", "second main-options step selects the extra-wide view")
eq(rows[3].value(), "WIDE VOXEL", "row labels the extra-wide selection")
rows[3].step(game)
eq(game.save.options.modOptions.trainer_rematch.dramaless_battle_camera,
  "fork", "third main-options step returns to the fork view")

local noRenderer = hook(function() return { { id = "pipeline:voxel" } } end,
  { mods = { exports = {} } }, {})
eq(#noRenderer, 1, "camera row stays hidden when the renderer is unavailable")

S.finish()
