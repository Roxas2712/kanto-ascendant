-- Voxel Ascendant 2.x may recreate its public OverworldBattle source seam
-- while loading a save. KASC must detect the stale marker, rebind its exact
-- wrapper and keep ordinary trainers on their authored 128px source.

package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local Data = T.fixtures.load()
local Version = require("src.core.Version")
local originalEngineVersion = Version.engine
Version.engine = "0.2.24"
local kascDir = assert(os.getenv("TRAINER_REMATCH_MOD_DIR"),
  "TRAINER_REMATCH_MOD_DIR is required")
local vascDir = assert(os.getenv("VOXEL_ASCENDANT_MOD_DIR"),
  "VOXEL_ASCENDANT_MOD_DIR is required")

local function basename(path)
  return tostring(path):gsub("/+$", ""):match("([^/]+)$")
end

local originalNewImage = love.graphics.newImage
local originalNewCanvas = love.graphics.newCanvas
local mounts = {
  ["mods/" .. basename(kascDir) .. "/"] = kascDir .. "/",
  ["mods/" .. basename(vascDir) .. "/"] = vascDir .. "/",
}
love.graphics.newImage = function(source)
  if type(source) == "string" then
    for mounted, real in pairs(mounts) do
      if source:sub(1, #mounted) == mounted then
        source = real .. source:sub(#mounted + 1)
        break
      end
    end
  end
  local image = originalNewImage(source)
  if type(image) == "table" and type(image.setFilter) ~= "function" then
    image.setFilter = function() end
  end
  return image
end
love.graphics.newCanvas = function(...)
  local canvas = originalNewCanvas(...)
  if type(canvas) == "table" and type(canvas.setFilter) ~= "function" then
    canvas.setFilter = function() end
  end
  return canvas
end

local run = T.sdk.loadMods({ kascDir, vascDir }, { data = Data, root = "/" })
T.eq(#run.errors, 0, "KASC and current VASC load together")
local kasc = assert(run.loader.exports.kanto_ascendant)
local vasc = assert(run.loader.exports.VOXEL_ASCENDANT)
T.check(tostring(vasc.version):match("^2%.") ~= nil,
  "test uses the current VASC 2.x contract")
local Pipelines = require("src.render.Pipelines")
Pipelines.install(Data)
Pipelines.setLevel("voxel", 1)

local overworld = assert(vasc.lib.require("OverworldBattle"))
local firstRelay = assert(overworld.__kantoAscendantApprovedTrainerRelay)
T.eq(overworld.sideTexture, firstRelay.wrapper,
  "initial HD resolver owns the live source seam")

local recreatedBase = function()
  return { trainer = true, recreatedLowResolutionSource = true }
end
overworld.sideTexture = recreatedBase
T.eq(overworld.__ascendantStandingTrainerMirror, true,
  "legacy marker survives renderer source recreation")

local game = {
  data = Data,
  save = { options = { modOptions = { kanto_ascendant = {
    trainer_portrait_style = "crystal_hd",
  } } } },
}
run.loader.events:emit("save.loaded", { game = game, save = game.save })

local rebound = assert(overworld.__kantoAscendantApprovedTrainerRelay)
T.neq(overworld.sideTexture, recreatedBase,
  "save.loaded rebinds a source seam replaced after initial install")
T.eq(overworld.sideTexture, rebound.wrapper,
  "relay records the exact rebound wrapper identity")
T.eq(rebound.original, recreatedBase,
  "rebound wrapper delegates only to the recreated renderer source")

local texture = overworld.sideTexture({
  game = game,
  showEnemyTrainer = true,
  oppClass = "OPP_BIRD_KEEPER",
}, "enemy")
T.eq(texture.ascendantHighResTrainer, true,
  "Bird Keeper remains an authored HD Voxel trainer after rebind")
T.check(texture.ascendantHighResSource:match(
    "/bird_keeper_voxel_front_hd_v2%.png$") ~= nil,
  "Bird Keeper uses only the packaged 128px combat-front source")
T.eq(texture.recreatedLowResolutionSource, nil,
  "renderer base is not allowed to enlarge its low-resolution trainer pic")

love.graphics.newImage = originalNewImage
love.graphics.newCanvas = originalNewCanvas
Version.engine = originalEngineVersion
run.release()
T.finish("VASC 2.x trainer HD source rebind")
