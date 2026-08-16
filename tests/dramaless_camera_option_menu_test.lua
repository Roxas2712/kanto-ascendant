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
local handles = {}
local mod = {
  id = "kanto_ascendant",
  exports = {},
  find = function(id) return handles[id] end,
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
local voxelRenderer = assert(
  dofile(modDir .. "/voxel_renderer_compat.lua")(mod))

local cameraOption = dofile(modDir .. "/dramaless_camera_option.lua")(mod, {
  camera = "VOXEL BATTLE CAMERA",
  fork = "VOXEL DEFAULT",
  classic = "CLASSIC VOXEL",
  wide = "WIDE VOXEL",
  voxelRenderer = voxelRenderer,
})
cameraOption.install()

local emitted = {}
handles.DRAMALESS_SHAPE = {
  id = "DRAMALESS_SHAPE",
  version = "1.6.2-ST.190.1",
  exports = {
    version = "1.6.2-ST.190.1",
    lib = { require = function(name)
      if name == "BattleCam" then return {} end
      return nil
    end },
  },
}
local game = {
  save = { options = {} },
  mods = {
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
eq(rows[3].id, "kanto_ascendant:dramaless_battle_camera",
  "camera appears immediately after the compatible Voxel controls")
eq(rows[3].label, "VOXEL BATTLE CAMERA",
  "camera keeps its localized main-options label")
eq(rows[3].value(), "WIDE VOXEL", "camera defaults to the wide view")

rows[3].step(game)
eq(game.save.options.modOptions.kanto_ascendant.dramaless_battle_camera,
  "fork", "main-options step persists the renderer-default selection")
eq(game.mods.modOptions.kanto_ascendant.dramaless_battle_camera,
  "fork", "main-options step updates the live option store")
eq(rows[3].value(), "VOXEL DEFAULT", "row reflects its new live selection")
eq(emitted[#emitted].name, "mod.options_changed",
  "main-options step notifies the camera compatibility bridge")
eq(emitted[#emitted].payload.mod, "kanto_ascendant",
  "camera notification remains namespaced to Kanto Ascendant storage")

rows[3].step(game)
eq(game.save.options.modOptions.kanto_ascendant.dramaless_battle_camera,
  "classic", "second main-options step selects the classic view")
eq(rows[3].value(), "CLASSIC VOXEL", "row labels the classic selection")
rows[3].step(game)
eq(game.save.options.modOptions.kanto_ascendant.dramaless_battle_camera,
  "wide", "third main-options step returns to the wide default")

handles.DRAMALESS_SHAPE = nil
handles.VOXEL_ASCENDANT = {
  id = "VOXEL_ASCENDANT", version = "0.1.1",
  exports = {
    version = "0.1.1", apiVersion = 1,
    renderer = {
      id = "VOXEL_ASCENDANT", version = "0.1.1",
      pipeline = "voxel", cameraProfile = "orbit-only",
    },
    capabilities = {
      voxelWorld = true, battleCards = { "MAP", "DISCS" },
      wallDecals = 1, diskCache = false, stadium = false, vr = false,
    },
    lib = { require = function(name)
      if name == "BattleCam" then return {} end
      return nil
    end },
  },
}
local voxelRows = hook(function() return {
  { id = "pipeline:voxel" },
  { id = "VOXEL_ASCENDANT:battles" },
} end, game, {})
eq(#voxelRows, 2,
  "KASC hides its Dramaless camera row from Voxel Ascendant")
eq(voxelRows[2].id, "VOXEL_ASCENDANT:battles",
  "Voxel Ascendant keeps ownership of its own battle controls")

handles.VOXEL_ASCENDANT = nil
local noRenderer = hook(function() return { { id = "pipeline:voxel" } } end,
  { mods = {} }, {})
eq(#noRenderer, 1, "camera row stays hidden when the renderer is unavailable")

local battleModules = {
  AntiAlias = {}, BattleCam = {}, FirstPerson = {}, Mat4 = {},
  OverworldBattle = {}, ShadowMap = {}, SpriteBillboards = {},
  TerrainAtlas = {}, Voxel3D = {}, VoxelScene = {}, VoxelState = {},
}
local battleLib = {
  mod = { id = "BATTLE_ART_VOXEL_FORK", options = {} },
  require = function(name) return battleModules[name] end,
}
handles.BATTLE_ART_VOXEL_FORK = {
  id = "BATTLE_ART_VOXEL_FORK", version = "1.9.0",
  exports = {
    version = "1.9.0", lib = battleLib,
    battleStage = {
      apiVersion = 1, sourceModId = "BATTLE_ART_VOXEL_FORK",
      ownership = { hud = true, animationProjection = true },
      state = function() return { staged = true } end,
    },
    battlePresentation = {
      apiVersion = 1, sourceModId = "BATTLE_ART_VOXEL_FORK",
      suppressHook = "battle.presentation.suppress_native.v1",
    },
  },
}
local battleRows = hook(function() return {
  { id = "BATTLE_ART_VOXEL_FORK:battle_art" },
  { id = "BATTLE_ART_VOXEL_FORK:camera" },
  { id = "sound" },
} end, game, {})
eq(#battleRows, 3,
  "Battle Art keeps only its own camera/options rows")
eq(battleRows[1].id, "BATTLE_ART_VOXEL_FORK:battle_art",
  "KASC does not displace Battle Art option ordering")
eq(battleLib.mod.options ~= nil, true,
  "Battle Art remains owner of its separately installed options")

S.finish()
