-- The optional Classic Voxel camera must restore exactly the renderer-default
-- telephoto rig while leaving the renderer's default untouched otherwise.

package.path = "./?.lua;./?/init.lua;" .. package.path

local S = require("tests.harness").suite("voxel camera compatibility")
local eq = S.eq
local modDir = assert(os.getenv("TRAINER_REMATCH_MOD_DIR"),
  "TRAINER_REMATCH_MOD_DIR is required")

local selected
local handlers = {}
local externalMods = {}
local camera = {
  RIGS = {
    tele = { back = 217.44, height = 56.82, frameH = 34.11 },
  },
}
local mod = {
  id = "trainer_rematch",
  options = { get = function(_, key)
    eq(key, "dramaless_battle_camera", "camera reads only its own option")
    return selected
  end },
  events = { on = function(_, name, callback)
    handlers[name] = callback
  end },
  find = function(id) return externalMods[id] end,
}
externalMods.VOXEL_ASCENDANT = {
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
      if name == "BattleCam" then
        eq(name, "BattleCam", "camera resolves the renderer public camera seam")
        return camera
      end
      return nil
    end },
  },
}
local game = {}

local voxelRenderer = dofile(modDir .. "/voxel_renderer_compat.lua")(mod)
local compat = dofile(modDir .. "/dramaless_camera_compat.lua")(mod, {
  voxelRenderer = voxelRenderer,
})
eq(compat.install(game), true, "compatibility controller installs")
eq(compat.CLASSIC_TELE.frameH, 34.11 * 3,
  "Classic Voxel keeps full-height Crystal trainers inside the frame")
eq(camera.RIGS.tele.back, compat.WIDE_TELE.back,
  "a missing saved choice defaults to the Wide Voxel distance")
eq(camera.RIGS.tele.height, compat.WIDE_TELE.height,
  "a missing saved choice defaults to the Wide Voxel height")
eq(camera.RIGS.tele.frameH, compat.WIDE_TELE.frameH,
  "a missing saved choice defaults to Wide Voxel framing")

selected = "classic"
handlers["mod.options_changed"]({
  mod = "trainer_rematch", key = "dramaless_battle_camera",
})
eq(camera.RIGS.tele.back, compat.CLASSIC_TELE.back,
  "Classic Voxel restores the original battle distance")
eq(camera.RIGS.tele.height, compat.CLASSIC_TELE.height,
  "Classic Voxel restores the original battle height")
eq(camera.RIGS.tele.frameH, compat.CLASSIC_TELE.frameH,
  "Classic Voxel restores the calibrated original-scale battle framing")

handlers["battle.started"]({ battle = { game = game } })
eq(camera.RIGS.tele.back, compat.CLASSIC_TELE.back,
  "the selected classic rig survives the next battle boundary")
eq(camera.RIGS.tele.frameH, compat.CLASSIC_TELE.frameH,
  "the selected calibrated framing survives the next battle boundary")

selected = "wide"
handlers["mod.options_changed"]({
  mod = "trainer_rematch", key = "dramaless_battle_camera",
})
eq(camera.RIGS.tele.back, compat.WIDE_TELE.back,
  "Wide Voxel keeps the original battle distance")
eq(camera.RIGS.tele.height, compat.WIDE_TELE.height,
  "Wide Voxel keeps the original battle height")
eq(camera.RIGS.tele.frameH, compat.WIDE_TELE.frameH,
  "Wide Voxel provides the extra-wide live-reviewed frame")

selected = "fork"
handlers["mod.options_changed"]({
  mod = "trainer_rematch", key = "dramaless_battle_camera",
})
eq(camera.RIGS.tele.back, 217.44,
  "switching back restores the renderer's exact original distance")
eq(camera.RIGS.tele.height, 56.82,
  "switching back restores the renderer's exact original height")
eq(camera.RIGS.tele.frameH, 34.11,
  "switching back restores the renderer's exact original framing")

local noRendererMod = {
  id = "trainer_rematch",
  options = { get = function() return "classic" end },
  events = { on = function() end },
  find = function() return nil end,
}
local noRenderer = dofile(modDir .. "/dramaless_camera_compat.lua")(
  noRendererMod, {
    voxelRenderer = dofile(modDir .. "/voxel_renderer_compat.lua")(
      noRendererMod),
  })
eq(noRenderer.install({}), true,
  "the optional bridge remains inert when the renderer is absent")

-- Exact Battle Art 1.9.0 owns its camera rigs/options. The generic renderer
-- resolver may preflight its public module contract, but this legacy KASC
-- camera adapter must never wrap rigFor or edit RIGS.tele.
local battleCamera = {
  RIGS = { tele = { back = 144.96, height = 37.88, frameH = 34.11 } },
  rigFor = function(self) return self.RIGS.tele end,
}
local originalBattleRigFor = battleCamera.rigFor
local battleModules = {
  AntiAlias = {}, BattleCam = battleCamera, FirstPerson = {}, Mat4 = {},
  OverworldBattle = {}, ShadowMap = {}, SpriteBillboards = {},
  TerrainAtlas = {}, Voxel3D = {}, VoxelScene = {}, VoxelState = {},
}
local battleModuleCalls = 0
local battleLib = {
  mod = { id = "BATTLE_ART_VOXEL_FORK", options = {} },
  path = "/separately-installed/battle-art",
}
battleLib.require = function(name)
  battleModuleCalls = battleModuleCalls + 1
  return battleModules[name]
end
local battleHandlers = {}
local battleOptionReads = 0
local battleMod = {
  id = "kanto_ascendant",
  options = { get = function()
    battleOptionReads = battleOptionReads + 1
    return "classic"
  end },
  events = { on = function(_, name, callback)
    battleHandlers[name] = callback
  end },
  find = function(id)
    if id ~= "BATTLE_ART_VOXEL_FORK" then return nil end
    return {
      id = id, version = "1.9.0",
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
  end,
}
local battleCompat = dofile(modDir .. "/dramaless_camera_compat.lua")(
  battleMod, {
    voxelRenderer = dofile(modDir .. "/voxel_renderer_compat.lua")(
      battleMod),
  })
local battleGame = {}
eq(battleCompat.install(battleGame), true,
  "exact Battle Art remains safely outside the legacy camera adapter")
eq(battleModuleCalls, 11,
  "Battle Art API preflight does not imply camera-option ownership")
eq(battleOptionReads, 0,
  "KASC never reads its legacy camera option for Battle Art")
eq(battleCamera.RIGS.tele.back, 144.96,
  "Battle Art authored camera distance is untouched")
eq(battleCamera.RIGS.tele.height, 37.88,
  "Battle Art authored camera height is untouched")
eq(battleCamera.RIGS.tele.frameH, 34.11,
  "Battle Art authored camera frame is untouched")
eq(battleCamera.rigFor, originalBattleRigFor,
  "Battle Art rigFor remains its own unwrapped function")
eq(battleCamera.__kantoAscendantOakLabLens, nil,
  "KASC does not install its Oak lens into Battle Art")
eq(type(battleHandlers["battle.started"]), "function",
  "the optional bridge retains its harmless battle-boundary listener")
battleHandlers["battle.started"]({ battle = { game = battleGame } })
eq(battleCamera.rigFor, originalBattleRigFor,
  "battle boundary cannot acquire Battle Art camera ownership")
eq(battleCamera.RIGS.tele.back, 144.96,
  "battle boundary preserves Battle Art camera settings")

S.finish()
