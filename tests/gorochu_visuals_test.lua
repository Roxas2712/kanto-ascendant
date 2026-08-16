-- Gorochu's high-detail Voxel source and six-pose field walker must remain
-- independent from its intentional 56 px Crystal battle cards.

package.path = "./?.lua;./?/init.lua;" .. package.path

local S = require("tests.harness").suite("gorochu visuals")
local check, eq = S.check, S.eq
local modDir = assert(os.getenv("TRAINER_REMATCH_MOD_DIR"),
  "TRAINER_REMATCH_MOD_DIR is required")

local function pngDimensions(relative)
  local handle = assert(io.open(modDir .. "/" .. relative, "rb"), relative)
  local header = handle:read(24)
  handle:close()
  check(header and #header == 24 and header:sub(1, 8) == "\137PNG\r\n\26\n",
    relative .. " is a PNG")
  local function integer(offset)
    local a, b, c, d = header:byte(offset, offset + 3)
    return a * 16777216 + b * 65536 + c * 256 + d
  end
  return integer(17), integer(21)
end

local files = {}
for _, side in ipairs({ "front", "back" }) do
  for _, shiny in ipairs({ false, true }) do
    local suffix = shiny and "_shiny" or ""
    files[("assets/voxel/gorochu/gorochu_%s%s.png")
      :format(side, suffix)] = { 96, 96 }
  end
end
for _, variant in ipairs({ "normal", "shiny" }) do
  for frame = 1, 6 do
    files[("assets/voxel/gorochu/animation/%s/%03d.png")
      :format(variant, frame)] = { 96, 96 }
    files[("assets/voxel/gorochu/crystal/%s/%03d.png")
      :format(variant, frame)] = { 56, 56 }
  end
end
files["assets/followers/gorochu.png"] = { 96, 16 }
files["assets/followers/shiny/gorochu.png"] = { 96, 16 }
files["assets/followers_runtime/normal/follower_GOROCHU.png"] = { 16, 96 }
files["assets/followers_runtime/shiny/follower_GOROCHU.png"] = { 16, 96 }
files["assets/voxel/gorochu/gorochu_dex.png"] = { 56, 56 }
files["assets/voxel/gorochu/gorochu_dex_shiny.png"] = { 56, 56 }
files["assets/voxel/gorochu/gorochu_catalogue_placeholder.png"] = { 56, 56 }

for relative, size in pairs(files) do
  local width, height = pngDimensions(relative)
  eq(width, size[1], relative .. " has the expected width")
  eq(height, size[2], relative .. " has the expected height")
end

local readable = {}
for relative in pairs(files) do readable[relative] = true end
local externalMods = {}
local fakeMod = {
  path = "/fake/kanto-ascendant",
  exports = {},
  read = function(_, relative)
    return readable[relative] and "png" or nil
  end,
  find = function(id) return externalMods[id] end,
}
local voxelRenderer = assert(
  dofile(modDir .. "/voxel_renderer_compat.lua")(fakeMod))
local shinySystem = {
  isShiny = function(mon) return mon and mon.shiny == true end,
}
local visuals = assert(
  dofile(modDir .. "/gorochu_visuals.lua")(fakeMod, {
    species = "GOROCHU",
    shinySystem = shinySystem,
    voxelRenderer = voxelRenderer,
  }))

eq(visuals.relativePath({ species = "GOROCHU" }, "front"),
  "assets/voxel/gorochu/gorochu_front.png",
  "normal Voxel front resolves from the dedicated master")
eq(visuals.relativePath({ species = "GOROCHU", shiny = true }, "front"),
  "assets/voxel/gorochu/gorochu_front_shiny.png",
  "shiny Voxel front resolves independently")
eq(visuals.relativePath({ species = "GOROCHU" }, "back"),
  "assets/voxel/gorochu/gorochu_back.png",
  "BACK SPRITES mode owns a high-detail rear master")
eq(visuals.cataloguePath({ species = "GOROCHU" }),
  "assets/voxel/gorochu/gorochu_dex.png",
  "Dex and status views receive the fitted high-resolution normal card")
eq(visuals.cataloguePath({ species = "GOROCHU", shiny = true }),
  "assets/voxel/gorochu/gorochu_dex_shiny.png",
  "Dex and status views receive the fitted high-resolution shiny card")
eq(visuals.relativePath({ species = "GOROCHU" }, "front", 4),
  "assets/voxel/gorochu/animation/normal/004.png",
  "normal Voxel front resolves the authored live frame")
eq(visuals.relativePath({ species = "GOROCHU", shiny = true }, "front", 5),
  "assets/voxel/gorochu/animation/shiny/005.png",
  "shiny Voxel front resolves its matching authored live frame")
check(not visuals.relativePath(
  { species = "GOROCHU" }, "front"):find("crystal", 1, true),
  "legacy static callers retain the illustrated Voxel card")

local pngSignature = "\137PNG\r\n\26\n"
local primaryMod = {
  path = "/fake/kanto-ascendant",
  read = function(_, relative)
    if relative:find("assets/voxel/gorochu/crystal/", 1, true) then
      return pngSignature .. "primary"
    end
    return readable[relative] and "png" or nil
  end,
}
local primaryVisuals = assert(
  dofile(modDir .. "/gorochu_visuals.lua")(primaryMod, {
    species = "GOROCHU",
    shinySystem = shinySystem,
  }))
eq(primaryVisuals.primaryReady(), true,
  "complete twelve-frame Crystal family is selected atomically")
local primaryNormal, primaryNormalLane = primaryVisuals.relativePath(
  { species = "GOROCHU" }, "front", 4)
eq(primaryNormal, "assets/voxel/gorochu/crystal/normal/004.png",
  "normal Voxel front prefers the native Crystal frame")
eq(primaryNormalLane, "crystal-primary",
  "normal Voxel front records the Crystal-primary lane")
local primaryShiny, primaryShinyLane = primaryVisuals.relativePath(
  { species = "GOROCHU", shiny = true }, "front", 11)
eq(primaryShiny, "assets/voxel/gorochu/crystal/shiny/005.png",
  "animation indices wrap within the six-frame Crystal family")
eq(primaryShinyLane, "crystal-primary",
  "shiny Voxel front uses the same atomic primary family")
eq(primaryVisuals.relativePath(
  { species = "GOROCHU" }, "back", 4),
  "assets/voxel/gorochu/gorochu_back.png",
  "BACK SPRITES remains on the separately approved rear fallback")

local incompleteMod = {
  path = "/fake/kanto-ascendant",
  read = function(_, relative)
    if relative == "assets/voxel/gorochu/crystal/shiny/006.png" then
      return nil
    end
    if relative:find("assets/voxel/gorochu/crystal/", 1, true) then
      return pngSignature .. "primary"
    end
    return readable[relative] and "png" or nil
  end,
}
local incompleteVisuals = assert(
  dofile(modDir .. "/gorochu_visuals.lua")(incompleteMod, {
    species = "GOROCHU",
    shinySystem = shinySystem,
    voxelRenderer = voxelRenderer,
  }))
eq(incompleteVisuals.primaryReady(), false,
  "one missing primary frame rejects the whole primary family")
local incompletePath, incompleteLane = incompleteVisuals.relativePath(
  { species = "GOROCHU" }, "front", 4)
eq(incompletePath, "assets/voxel/gorochu/animation/normal/004.png",
  "incomplete family falls back without mixing normal frames")
eq(incompleteLane, "illustrated-fallback",
  "incomplete family records the illustrated fallback lane")

local front = true
local playerTexture
local overworldBattle = {
  sideTexture = function(_, side)
    if side == "player" and playerTexture then return playerTexture end
    return { side = side, ax = 80, ay = 96 }
  end,
  wantsFront = function() return front end,
}
externalMods.DRAMALESS_SHAPE = {
  id = "DRAMALESS_SHAPE",
  version = "1.6.2-ST.190.1",
  exports = {
    version = "1.6.2-ST.190.1",
    lib = {
      require = function(name)
        if name == "OverworldBattle" then
          eq(name, "OverworldBattle",
            "Gorochu installs through the renderer's public module")
          return overworldBattle
        end
        return nil
      end,
    },
  },
}
local game = {}

local oldLove = _G.love
local currentCanvas
local drawCalls = {}
local imageFilters = {}
local canvasFilters = {}
_G.love = {
  graphics = {
    newImage = function(path)
      if _G.__failGorochuPrimaryDecode
          and path:find("/assets/voxel/gorochu/crystal/", 1, true) then
        error("intentional primary decode failure")
      end
      local crystal = path:find("/assets/voxel/gorochu/crystal/", 1, true)
      return {
        path = path,
        setFilter = function(_, min, mag)
          imageFilters[path] = { min, mag }
        end,
        getDimensions = function()
          return crystal and 56 or 96, crystal and 56 or 96
        end,
      }
    end,
    newCanvas = function(width, height)
      return {
        width = width,
        height = height,
        setFilter = function(_, min, mag)
          canvasFilters[#canvasFilters + 1] = { min, mag }
        end,
      }
    end,
    getCanvas = function() return currentCanvas end,
    setCanvas = function(value) currentCanvas = value end,
    getBlendMode = function() return "alpha", "alphamultiply" end,
    setBlendMode = function() end,
    getColor = function() return 1, 1, 1, 1 end,
    setColor = function() end,
    clear = function() end,
    draw = function(...)
      drawCalls[#drawCalls + 1] = { ... }
    end,
  },
}

eq(visuals.install(game), true,
  "the dedicated Voxel side-texture hook installs")
local battle = {
  player = {
    mon = { species = "GOROCHU" },
    __ascendantCrystalAnimation = { frame = 4 },
  },
  enemy = { mon = { species = "GOROCHU", shiny = true } },
}

-- Both battlers already exist during a trainer battle's opening tableau, but
-- a later selected-character wrapper can deliberately clear `trainer` to
-- mirror its standing-front card correctly. BattleState.showPlayerBack must
-- still keep Gorochu out until the real send-out.
playerTexture = { side = "player", ax = 80, ay = 96, trainer = false,
  canvas = { width = 160, height = 144 } }
battle.showPlayerBack = true
local trainerIntro = overworldBattle.sideTexture(battle, "player")
eq(trainerIntro.trainer, false,
  "Gorochu preserves the renderer's player-trainer intro card")
check(trainerIntro.kantoAscendantGorochuSupersampled == nil,
  "Gorochu is not rendered before its real send-out")
playerTexture = nil
battle.showPlayerBack = false

-- Preserve the renderer's own marker even on a compatibility path where the
-- BattleState flags are temporarily unavailable.
playerTexture = { side = "player", ax = 80, ay = 96, trainer = true,
  canvas = { width = 160, height = 144 } }
local markedTrainer = overworldBattle.sideTexture(battle, "player")
eq(markedTrainer.trainer, true,
  "Gorochu preserves a natively marked trainer texture")
check(markedTrainer.kantoAscendantGorochuSupersampled == nil,
  "native trainer markers suppress the early Gorochu card")
playerTexture = nil

-- The enemy's eventual battler is also allocated while its trainer portrait
-- is still visible. It must follow the same no-early-Pokemon contract.
battle.showEnemyTrainer = true
local enemyTrainer = overworldBattle.sideTexture(battle, "enemy")
check(enemyTrainer.kantoAscendantGorochuSupersampled == nil,
  "enemy Gorochu is not rendered over its trainer introduction")
battle.showEnemyTrainer = false

local player = overworldBattle.sideTexture(battle, "player")
eq(player.kantoAscendantGorochuSupersampled, true,
  "player Gorochu receives a supersampled Voxel texture")
eq(player.kantoAscendantGorochuSource,
  "assets/voxel/gorochu/animation/normal/004.png",
  "camera-facing player uses the approved normal live frame")
eq(player.canvas.width, 160,
  "Gorochu card retains the renderer's native canvas width")
eq(player.canvas.height, 144,
  "Gorochu card retains the renderer's native canvas height")
eq(player.ax, 80,
  "Gorochu card retains the renderer's horizontal anchor")
eq(player.ay, 96,
  "Gorochu card retains the renderer's vertical anchor")
eq(player.kantoAscendantGorochuAnimationFrame, 4,
  "Voxel master follows the live Crystal animation clock")

local enemy = overworldBattle.sideTexture(battle, "enemy")
eq(enemy.kantoAscendantGorochuSource,
  "assets/voxel/gorochu/animation/shiny/001.png",
  "camera-facing enemy selects the shiny live frame")

front = false
local back = overworldBattle.sideTexture(battle, "player")
eq(back.kantoAscendantGorochuSource,
  "assets/voxel/gorochu/gorochu_back.png",
  "BACK SPRITES mode selects the approved rear master")
eq(back.kantoAscendantGorochuSide, "back",
  "the side-texture marker records the pinned rear view")
eq(visuals.install(game), true, "the Voxel hook is idempotent")

-- A complete Crystal family wins in a real sideTexture wrapper, stays at its
-- native 1x scale and forces nearest filtering. The illustrated cycle remains
-- bytefixed and is only used if the primary family is incomplete or cannot be
-- decoded.
local primaryOverworld = {
  sideTexture = function(_, side)
    return { side = side, ax = 80, ay = 96,
      canvas = { width = 160, height = 144 } }
  end,
  wantsFront = function() return true end,
}
local primaryResolver = {
  module = function(_, name)
    eq(name, "OverworldBattle",
      "primary Voxel hook asks for the shared sideTexture module")
    return primaryOverworld
  end,
}
primaryVisuals = assert(
  dofile(modDir .. "/gorochu_visuals.lua")(primaryMod, {
    species = "GOROCHU",
    shinySystem = shinySystem,
    voxelRenderer = primaryResolver,
  }))
eq(primaryVisuals.install({}), true,
  "complete Crystal primary installs through the shared renderer")
drawCalls = {}
local primaryTexture = primaryOverworld.sideTexture({
  player = {
    mon = { species = "GOROCHU" },
    __ascendantCrystalAnimation = { frame = 4 },
  },
}, "player")
eq(primaryTexture.kantoAscendantGorochuSource,
  "assets/voxel/gorochu/crystal/normal/004.png",
  "live Voxel texture uses the selected Crystal-primary frame")
eq(primaryTexture.kantoAscendantGorochuAssetLane, "crystal-primary",
  "live Voxel receipt records the Crystal-primary lane")
eq(primaryTexture.kantoAscendantGorochuFallbackReason, nil,
  "healthy primary texture has no fallback reason")
local primaryImagePath = primaryMod.path .. "/"
  .. "assets/voxel/gorochu/crystal/normal/004.png"
eq(imageFilters[primaryImagePath][1], "nearest",
  "Crystal-primary image uses nearest filtering")
eq(imageFilters[primaryImagePath][2], "nearest",
  "Crystal-primary magnification uses nearest filtering")
eq(drawCalls[#drawCalls][5], 1,
  "Crystal-primary is drawn at native one-times scale")
eq(drawCalls[#drawCalls][6], 1,
  "Crystal-primary keeps equal one-times axes")

local decodeOverworld = {
  sideTexture = primaryOverworld.sideTexture,
  wantsFront = primaryOverworld.wantsFront,
}
local decodeVisuals = assert(
  dofile(modDir .. "/gorochu_visuals.lua")(primaryMod, {
    species = "GOROCHU",
    shinySystem = shinySystem,
    voxelRenderer = { module = function() return decodeOverworld end },
  }))
eq(decodeVisuals.install({}), true,
  "decode-fallback hook installs before image resolution")
_G.__failGorochuPrimaryDecode = true
local decodedFallback = decodeOverworld.sideTexture({
  player = {
    mon = { species = "GOROCHU" },
    __ascendantCrystalAnimation = { frame = 3 },
  },
}, "player")
_G.__failGorochuPrimaryDecode = nil
eq(decodedFallback.kantoAscendantGorochuSource,
  "assets/voxel/gorochu/animation/normal/003.png",
  "primary decode failure retries the exact illustrated fallback frame")
eq(decodedFallback.kantoAscendantGorochuAssetLane, "illustrated-fallback",
  "decode failure records the illustrated fallback lane")
eq(decodedFallback.kantoAscendantGorochuFallbackReason,
  "primary-decode-failed",
  "decode failure is explicit in the texture receipt")
local afterFailure, afterFailureLane = decodeVisuals.relativePath(
  { species = "GOROCHU", shiny = true }, "front", 5)
eq(afterFailure, "assets/voxel/gorochu/animation/shiny/005.png",
  "decode failure disables primary for later shiny frames too")
eq(afterFailureLane, "illustrated-fallback",
  "run-wide decode fallback prevents style mixing")

-- Dex/status use the approved 96px frame in the final screen-space pass.
-- This preserves more source pixels than the native 56px UI canvas can hold.
local hudWrap
local dexStyle = "original"
local overlayMod = {
  path = "/fake/kanto-ascendant",
  read = fakeMod.read,
  options = { get = function(_, key)
    if key == "dex_sprite_style" then return dexStyle end
  end },
  hooks = { wrap = function(_, name, callback, priority)
    eq(name, "render.hud", "catalogue overlay uses the screen-space hook")
    eq(priority, 900, "catalogue overlay has deterministic HUD priority")
    hudWrap = callback
  end },
}
local overlay = assert(dofile(
  modDir .. "/gorochu_catalogue_overlay.lua"))(overlayMod, {
    species = "GOROCHU",
    shinySystem = shinySystem,
  })
eq(overlay.placeholderPath({ species = "GOROCHU", kind = "dex" }),
  "assets/voxel/gorochu/gorochu_catalogue_placeholder.png",
  "Voxel Dex route receives a transparent layout placeholder")
dexStyle = "crystal"
eq(overlay.placeholderPath({ species = "GOROCHU", kind = "dex" }), nil,
  "Crystal Dex route never receives the Voxel placeholder")
dexStyle = "original"
eq(overlay.register(), true, "catalogue overlay hook registers")
check(type(hudWrap) == "function", "catalogue overlay installed render.hud")

drawCalls = {}
local chained = 0
local dexState = { screenId = "DexEntryMenu", def = { id = "GOROCHU" } }
local hudGame = { stack = { top = function() return dexState end } }
local viewport = {
  gameX = 20, gameY = 30, gameWidth = 800, gameHeight = 720,
}
hudWrap(function() chained = chained + 1 end, hudGame, viewport)
eq(chained, 1, "catalogue HUD preserves lower-priority overlays")
eq(#drawCalls, 1, "Gorochu Dex receives one high-density redraw")
eq(drawCalls[1][2], 60,
  "Dex high-density redraw keeps the native x=8 slot")
eq(drawCalls[1][3], 50,
  "Dex high-density redraw keeps the native y=4 slot")
check(math.abs(drawCalls[1][5] - (56 * 5 / 96)) < 0.0001,
  "Dex high-density redraw maps 96 source pixels into 56 logical units")

drawCalls = {}
local summaryState = {
  screenId = "SummaryMenu",
  mon = { species = "GOROCHU", shiny = true },
}
hudGame.stack.top = function() return summaryState end
hudWrap(function() end, hudGame, viewport)
eq(#drawCalls, 1, "shiny Gorochu status receives one high-density redraw")
check(drawCalls[1][1].path:find("animation/shiny/001.png", 1, true) ~= nil,
  "status overlay selects the approved shiny frame")
check(drawCalls[1][5] < 0,
  "status overlay preserves the Gen-I mirrored-front presentation")

drawCalls = {}
dexStyle = "crystal"
hudWrap(function() end, hudGame, viewport)
eq(#drawCalls, 0, "Crystal status mode suppresses the Voxel HUD redraw")

_G.love = oldLove

S.finish()
