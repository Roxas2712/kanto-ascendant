-- Focused contract for the mod-owned visibility path used by released 0.1.83.
-- Run from gen1recomp with KA_HIDDEN_EVOLUTION_MOD set to this worktree.

local root = assert(os.getenv("KA_HIDDEN_EVOLUTION_MOD"),
  "KA_HIDDEN_EVOLUTION_MOD is required")
local factory = assert(loadfile(root .. "/hidden_evolution_visibility_compat.lua"))()

local checks = 0
local function check(value, message)
  checks = checks + 1
  assert(value, message)
end
local function eq(actual, expected, message)
  checks = checks + 1
  assert(actual == expected, ("%s (got %s, want %s)"):format(
    message, tostring(actual), tostring(expected)))
end

local function canvas(name, w, h)
  return {
    name = name, w = w, h = h,
    getDimensions = function(self) return self.w, self.h end,
    getWidth = function(self) return self.w end,
    getHeight = function(self) return self.h end,
    getDPIScale = function() return 1 end,
    setFilter = function(self, min, mag) self.filter = min .. "/" .. mag end,
  }
end

local calls, currentCanvas, shaderFailure, canvasFailure = {}, nil, {}, false
local function log(name, ...)
  local row = { name, ... }
  calls[#calls + 1] = row
  return row
end
local Shader = {}
Shader.__index = Shader
function Shader:send(name, value)
  self.uniforms[name] = value
  log("send", self.kind, name, value)
end

_G.love = {
  timer = { getTime = function() return 12.5 end },
  graphics = {
    push = function() log("push") end,
    pop = function() log("pop") end,
    setCanvas = function(target) currentCanvas = target; log("canvas", target) end,
    getCanvas = function() return currentCanvas end,
    clear = function(...) log("clear", ...) end,
    draw = function(...) log("draw", ...) end,
    rectangle = function(...) log("rectangle", ...) end,
    circle = function(...) log("circle", ...) end,
    polygon = function(...) log("polygon", ...) end,
    setColor = function(...) log("color", ...) end,
    setBlendMode = function(...) log("blend", ...) end,
    setShader = function(shader) log("shader", shader) end,
    newShader = function(source)
      local kind = source:find("sightConeSlope", 1, true) and "RED"
        or source:find("sightOuterColor", 1, true) and "GREEN" or "BLUE"
      if shaderFailure[kind] then error("forced " .. kind .. " shader failure") end
      return setmetatable({ kind = kind, uniforms = {} }, Shader)
    end,
    stencil = function(fn, ...) log("stencil", ...); fn() end,
    setStencilTest = function(...) log("stencil-test", ...) end,
    newCanvas = function(w, h)
      if canvasFailure then error("forced canvas allocation failure") end
      local made = canvas("compat-pipeline", w, h)
      log("new-canvas", made)
      return made
    end,
  },
}

local state = { sight = 2 }
local greenSight = 0
local routes = {
  RED = {
    IDS = { upper = "KA_HEVO_RED_UPPER", shrine = "KA_HEVO_RED_SHRINE" },
    run = function() return { sight = 1, completed = false } end,
    sightProfile = function(level)
      return { radius = 2 + level, coreRadius = 0.8, coneSlope = 0.3,
        innerOpacity = 0.25, opacity = 1, featherPx = 2 }
    end,
  },
  BLUE = {
    -- BLUE intentionally exports lowercase `ids`; this guards the production
    -- adapter against silently omitting the whole route.
    ids = { THRESHOLD = "KA_HEVO_BLUE_FROST_THRESHOLD",
      ICE = "KA_HEVO_BLUE_GLACIER_MAZE" },
    state = function() return state end,
    sightProfile = function(level)
      return { radius = 1.5 + level, innerOpacity = 0.6,
        outerOpacity = 1, featherPx = 2 }
    end,
  },
  GREEN = {
    IDS = { grove = "KA_HEVO_GREEN_GROVE" },
    progress = function() return { sight = greenSight } end,
    fogInnerOpacity = function(sight) return 0.7 - sight * 0.1 end,
    FOG_OUTER_COLOR = { 30 / 255, 30 / 255, 30 / 255 },
    FOG_EDGE_SCREEN_PIXELS = 2,
  },
}

local ow = {
  map = { id = "KA_HEVO_RED_UPPER" },
  player = { px = 80, py = 96, facing = "right" },
  camera = { x = 16, y = 32 },
}
local worldCanvas = canvas("world", 220, 180)
local uprightCanvas = canvas("upright", 252, 212)
local renderer = {
  worldCanvas = worldCanvas, uprightCanvas = uprightCanvas,
  uprightActive = false, UPRIGHT_MARGIN = 16,
  worldViewSize = function() return 220, 180 end,
}
local game = { save = {}, renderer = renderer, overworld = ow }
local mod = {
  world = { overworld = function() return ow end },
  log = { warn = function(_, ...) log("warn", ...) end },
}
local pipelineActive, tiltActive = false, false
local Overworld = { drawWorld = function(self) log("base-world", self.map.id) end }
local Pipelines = {
  worldPipeline = function() return pipelineActive and "voxel" or nil end,
  worldPresent = function(input) log("base-present", input); return input end,
}
local Tilt = {
  active = function() return tiltActive end,
  groundPoint = function(x, y) return x * 0.9 + 4, y * 0.7 + 6 end,
}
local voxelProjection = false
local VoxelRenderer = {
  module = function(_, name)
    if name == "Voxel3D" then
      return { project = function(wx, wy, wz)
        if not voxelProjection then return nil end
        return wx * 4, wz * 3
      end }
    elseif name == "VoxelScene" then
      return { groundAt = function() return 2 end }
    elseif name == "AntiAlias" then
      return { factor = function() return 2 end }
    end
  end,
}

local visibility = factory(mod, {
  routes = routes, overworld = Overworld, pipelines = Pipelines, tilt = Tilt,
  voxelRenderer = VoxelRenderer,
})
local installed, mode = visibility.install(game)
check(installed, "compatibility adapter installs")
eq(mode, "legacy-mod-world-mask", "adapter reports its real presentation")
eq(visibility.mapKind.KA_HEVO_RED_UPPER, "RED", "RED maps are owned")
eq(visibility.mapKind.KA_HEVO_BLUE_GLACIER_MAZE, "BLUE",
  "lowercase BLUE ids are owned")
eq(visibility.mapKind.KA_HEVO_GREEN_GROVE, "GREEN", "GREEN maps are owned")

-- Flat RED: base world first, then a keyhole on the world canvas.
Overworld.drawWorld(ow)
eq(ow.kaHevoLegacyVisibilityRuntime.kind, "RED", "flat RED selects RED mask")
eq(ow.kaHevoLegacyVisibilityRuntime.projection, "legacy-flat-world-canvas",
  "flat RED masks the world canvas before UI")
eq(ow.kaHevoLegacyVisibilityRuntime.renderPath, "shader",
  "flat RED uses the analytic shader")
eq(ow.kaHevoLegacyVisibilityRuntime.radius, 3,
  "RED recovers sight stage from authoritative run state")
check(ow.kaHevoLegacyVisibilityRuntime.outerOpaque,
  "RED unexplored space is opaque")
eq(currentCanvas, worldCanvas, "flat wrapper restores the world render target")

-- A foreign map is byte-path transparent: only the original draw executes.
local before = #calls
ow.map.id = "CELADON_CITY"
Overworld.drawWorld(ow)
eq(#calls, before + 1, "foreign map adds no visibility drawing")
eq(calls[#calls][1], "base-world", "foreign map keeps the original draw path")

-- BLUE shader failure must use a real stencil aperture, never expose the map.
ow.map.id = "KA_HEVO_BLUE_GLACIER_MAZE"
ow.kaHevoBlueSight = nil
shaderFailure.BLUE = true
Overworld.drawWorld(ow)
eq(ow.kaHevoLegacyVisibilityRuntime.kind, "BLUE", "BLUE selects BLUE mask")
eq(ow.kaHevoLegacyVisibilityRuntime.renderPath, "stencil",
  "BLUE shader failure falls back to stencil")
check(ow.kaHevoLegacyVisibilityRuntime.outerOpaque,
  "BLUE stencil exterior stays opaque")
eq(ow.kaHevoLegacyVisibilityRuntime.radius, 3.5,
  "BLUE recovers its saved statue stage")

-- GREEN sight expands monotonically and masks the Tilt upright pass last.
ow.map.id = "KA_HEVO_GREEN_GROVE"
greenSight = 4
tiltActive, renderer.uprightActive = true, true
Overworld.drawWorld(ow)
eq(ow.kaHevoLegacyVisibilityRuntime.kind, "GREEN", "Tilt selects GREEN mask")
eq(ow.kaHevoLegacyVisibilityRuntime.projection, "legacy-tilt-upright",
  "Tilt is masked on its final upright canvas")
eq(ow.kaHevoLegacyVisibilityRuntime.radius, 5,
  "GREEN sight stage controls the aperture")
check(ow.kaHevoLegacyVisibilityRuntime.cellPixels > 0,
  "Tilt derives a projected cell scale")
eq(currentCanvas, worldCanvas, "Tilt wrapper restores the ground target")

-- Voxel projection unavailable: worldPresent still returns a valid canvas,
-- but closes it completely instead of leaking the distant maze.
tiltActive, renderer.uprightActive, pipelineActive = false, false, true
ow.map.id = "KA_HEVO_RED_UPPER"
local input = canvas("voxel-input", 640, 576)
local output = Pipelines.worldPresent(input, { state = ow, pipeline = "voxel" })
check(output ~= input, "Voxel worldPresent returns the masked compatibility canvas")
eq(output:getWidth(), 640, "masked Voxel canvas preserves width")
eq(output:getHeight(), 576, "masked Voxel canvas preserves height")
eq(output.filter, "linear/linear", "masked Voxel canvas preserves smooth projection")
eq(ow.kaHevoLegacyVisibilityRuntime.projection, "fail-closed-projection",
  "missing Voxel projection is reported truthfully")
eq(ow.kaHevoLegacyVisibilityRuntime.renderPath, "fail-closed-projection",
  "missing Voxel projection becomes an opaque screen")
check(ow.kaHevoLegacyVisibilityRuntime.outerOpaque,
  "projection failure cannot reveal the map")

-- A working Voxel projector is converted from its supersampled scene into
-- the resolved final-world canvas, with one projected cell defining radius.
voxelProjection = true
output = Pipelines.worldPresent(input, { state = ow, pipeline = "voxel" })
eq(ow.kaHevoLegacyVisibilityRuntime.projection, "legacy-voxel-project",
  "working Voxel projection is used")
eq(ow.kaHevoLegacyVisibilityRuntime.center.x, 176,
  "Voxel X is resolved through the AA factor")
eq(ow.kaHevoLegacyVisibilityRuntime.center.y, 168,
  "Voxel Y is resolved through the AA factor")
check(ow.kaHevoLegacyVisibilityRuntime.cellPixels > 0,
  "Voxel aperture derives a projected cell scale")
check(ow.kaHevoLegacyVisibilityRuntime.renderPath == "shader",
  "working Voxel path draws the analytic mask")
check(ow.kaHevoLegacyVisibilityRuntime.outerOpaque,
  "working Voxel exterior is still opaque")

-- Canvas allocation failure masks the pipeline's own finished target in
-- place.  Returning the unmasked image or throwing would both reveal space.
canvasFailure = true
local pressureInput = canvas("voxel-pressure", 800, 600)
output = Pipelines.worldPresent(pressureInput,
  { state = ow, pipeline = "voxel" })
eq(output, pressureInput,
  "allocation failure returns the safely masked source canvas")
eq(currentCanvas, pressureInput,
  "allocation failure masks the finished world in place")
check(ow.kaHevoLegacyVisibilityRuntime.outerOpaque,
  "allocation failure cannot reveal the map")
canvasFailure = false

-- The process-wide wrapper refreshes to the newest game/route owner instead
-- of retaining a stale save after a loader-level mod reload.
local game2 = { save = {}, renderer = renderer, overworld = ow }
local refreshed = factory(mod, {
  routes = routes, overworld = Overworld, pipelines = Pipelines, tilt = Tilt,
})
local refreshedOk, refreshedWhy = refreshed.install(game2)
check(refreshedOk, "second install refreshes the shared manager")
eq(refreshedWhy, "manager-refreshed", "reload path is explicit")
eq(refreshed.manager.game, game2, "reload replaces the stale game pointer")

print(("HEVO LEGACY VISIBILITY COMPAT PASS: %d assertions"):format(checks))
