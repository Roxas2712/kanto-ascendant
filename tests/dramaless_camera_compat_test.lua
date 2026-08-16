-- The optional Classic Voxel camera must restore exactly the renderer-default
-- telephoto rig while leaving the renderer's default untouched otherwise.

package.path = "./?.lua;./?/init.lua;" .. package.path

local S = require("tests.harness").suite("voxel camera compatibility")
local eq = S.eq
local function close(actual, expected, message)
  return S.check(math.abs(actual - expected) < 0.000000001,
    ("%s (got %.14g, want %.14g)"):format(message, actual, expected))
end
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

-- Exact upstream DRAMALESS 2.0.2 keeps its world/cards/HUD native-owned but
-- exposes one reviewed fixed BattleCam capability. KASC writes the literal
-- historical raw 3x tele rig; the renderer retains its 1.3 resting zoom,
-- steering and canonical/fixed behavior without any KASC wrapper.
local selected202 = "classic"
local handlers202 = {}
local moduleNames202 = {}
local camera202 = {
  RIGS = {
    tele = {
      side = 78.79, back = 144.96, height = 37.88,
      lookX = -0.26, lookY = 0.34, frameH = 34.11,
    },
    wide = {
      side = 41.98, back = 41.16, height = 28.48,
      lookX = -3.24, lookY = -1.35, frameH = 55.62,
    },
  },
  DEFAULT_RIG = "tele", DEFAULT_ZOOM = 1.3,
  ZOOM_MIN = 0.45, ZOOM_MAX = 2.0,
  zoom = 1.3, zoomGoal = 1.3,
  still = false, steerable = true,
}
camera202.rigFor = function(arena)
  return camera202.RIGS[arena and arena.cam] or camera202.RIGS.tele
end
camera202.frameH = function(arena)
  local base = camera202.rigFor(arena).frameH
  if camera202.still or not camera202.steerable then return base end
  return base * camera202.zoom
end
camera202.rig = function(arena, _, canonical)
  local rig = camera202.rigFor(arena)
  return { frameH = canonical and rig.frameH or camera202.frameH(arena) }
end
local exported202 = {
  version = "2.0.2",
  voxelArenaProvider = {}, voxelCardProvider = {}, voxel2DBattleHost = {},
  lib = {
    mod = { id = "DRAMALESS_SHAPE" },
    path = "/separately-installed/dramaless-2.0.2",
    require = function(name)
      moduleNames202[#moduleNames202 + 1] = name
      if name == "BattleCam" then return camera202 end
      error("unexpected DRAMALESS owner-loader request: " .. tostring(name))
    end,
  },
}
local mod202 = {
  id = "kanto_ascendant",
  options = { get = function(_, key)
    eq(key, "dramaless_battle_camera",
      "2.0.2 camera reads only its own KASC option")
    return selected202
  end },
  events = { on = function(_, name, callback)
    handlers202[name] = callback
  end },
  find = function(id)
    if id ~= "DRAMALESS_SHAPE" then return nil end
    return {
      id = id, version = "2.0.2", exports = exported202,
    }
  end,
}
local resolver202 = dofile(modDir .. "/voxel_renderer_compat.lua")(mod202)
local compat202 = dofile(modDir .. "/dramaless_camera_compat.lua")(mod202, {
  voxelRenderer = resolver202,
})
eq(compat202.install({}), true,
  "exact DRAMALESS 2.0.2 installs the fixed camera adapter")
eq(#moduleNames202, 1,
  "2.0.2 adapter makes one exact owner-loader request")
eq(moduleNames202[1], "BattleCam",
  "2.0.2 adapter requests only the literal reviewed BattleCam module")
close(camera202.RIGS.tele.frameH, compat202.CLASSIC_TELE.frameH,
  "2.0.2 stores the literal historical factor-3 raw tele rig")
close(camera202.frameH({}), 34.11 * 3 * 1.3,
  "2.0.2 applies its renderer-owned resting zoom above the raw 3x rig")

camera202.zoom = 1.6
close(camera202.frameH({}), (34.11 * 3) * 1.6,
  "2.0.2 preserves the player's zoom semantics above the raw 3x rig")
camera202.zoom = 1.3
camera202.still = true
close(camera202.frameH({}), 34.11 * 3,
  "2.0.2 fixed-seat path reads the same literal factor-3 raw rig")
close(camera202.rig({}, 0, true).frameH, 34.11 * 3,
  "2.0.2 canonical path remains renderer-owned and reads raw factor 3")
camera202.still = false
selected202 = "fork"
handlers202["mod.options_changed"]({
  mod = "kanto_ascendant", key = "dramaless_battle_camera",
})
eq(camera202.RIGS.tele.frameH, 34.11,
  "2.0.2 fork mode restores the exact upstream rig base")
close(camera202.frameH({}), 34.11 * 1.3,
  "2.0.2 fork mode restores the upstream neutral rendered frame")

selected202 = "wide"
handlers202["mod.options_changed"]({
  mod = "kanto_ascendant", key = "dramaless_battle_camera",
})
close(camera202.frameH({}), 34.11 * 3 * 1.3,
  "2.0.2 Wide mode keeps the literal raw 3x plus renderer resting zoom")
eq(#moduleNames202, 1,
  "camera changes use the cached capability without further owner access")

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
