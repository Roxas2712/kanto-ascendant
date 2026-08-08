-- The optional Classic Voxel camera must restore exactly the pre-Dramaless
-- telephoto rig while leaving the renderer's default untouched otherwise.

package.path = "./?.lua;./?/init.lua;" .. package.path

local S = require("tests.harness").suite("dramaless camera compatibility")
local eq = S.eq
local modDir = assert(os.getenv("TRAINER_REMATCH_MOD_DIR"),
  "TRAINER_REMATCH_MOD_DIR is required")

local selected = "fork"
local handlers = {}
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
}
local game = {
  mods = { exports = { DRAMALESS_SHAPE = { lib = { require = function(name)
    eq(name, "BattleCam", "camera resolves the Dramaless public camera seam")
    return camera
  end } } } },
}

local compat = dofile(modDir .. "/dramaless_camera_compat.lua")(mod)
eq(compat.install(game), true, "compatibility controller installs")
eq(camera.RIGS.tele.back, 217.44,
  "the Dramaless default remains untouched until Classic Voxel is selected")
eq(camera.RIGS.tele.height, 56.82,
  "the Dramaless default height remains untouched until selected")

selected = "classic"
handlers["mod.options_changed"]({
  mod = "trainer_rematch", key = "dramaless_battle_camera",
})
eq(camera.RIGS.tele.back, compat.CLASSIC_TELE.back,
  "Classic Voxel restores the original battle distance")
eq(camera.RIGS.tele.height, compat.CLASSIC_TELE.height,
  "Classic Voxel restores the original battle height")
eq(camera.RIGS.tele.frameH, compat.CLASSIC_TELE.frameH,
  "Classic Voxel restores the original visible battle framing")

handlers["battle.started"]({ battle = { game = game } })
eq(camera.RIGS.tele.back, compat.CLASSIC_TELE.back,
  "the selected classic rig survives the next battle boundary")
eq(camera.RIGS.tele.frameH, compat.CLASSIC_TELE.frameH,
  "the selected classic framing survives the next battle boundary")

selected = "fork"
handlers["mod.options_changed"]({
  mod = "trainer_rematch", key = "dramaless_battle_camera",
})
eq(camera.RIGS.tele.back, 217.44,
  "switching back restores Dramaless's exact original distance")
eq(camera.RIGS.tele.height, 56.82,
  "switching back restores Dramaless's exact original height")
eq(camera.RIGS.tele.frameH, 34.11,
  "switching back restores Dramaless's exact original framing")

local noRenderer = dofile(modDir .. "/dramaless_camera_compat.lua")({
  id = "trainer_rematch",
  options = { get = function() return "classic" end },
  events = { on = function() end },
})
eq(noRenderer.install({ mods = { exports = {} } }), true,
  "the optional bridge remains inert when Dramaless is absent")

S.finish()
