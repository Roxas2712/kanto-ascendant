package.path = "./?.lua;./?/init.lua;" .. package.path

local S = require("tests.harness").suite("Crystal enemy native-2D layout")
local check, eq = S.check, S.eq
local modDir = assert(os.getenv("TRAINER_REMATCH_MOD_DIR"),
  "TRAINER_REMATCH_MOD_DIR is required")

local values = {
  pokemon_sprite_style = "crystal",
  sprite_style_battle = true,
  crystal_animation = true,
  kanto_crystal_art = true,
}
local function readable(relative)
  local file = io.open(modDir .. "/" .. relative, "rb")
  if not file then return nil end
  local body = file:read("*a")
  file:close()
  return body
end
local fakeMod = {
  path = modDir,
  read = function(_, relative) return readable(relative) end,
  options = { get = function(_, key) return values[key] end },
  events = { on = function() end },
  content = { battle_sprite_scales = { register = function() end } },
}
local data = { pokemon = {
  BULBASAUR = { id = "BULBASAUR", dex = 1 },
  CHARIZARD = { id = "CHARIZARD", dex = 6 },
} }
local timing = {
  normal = { ["1"] = { 120, 120 } },
  shiny = { ["1"] = { 120, 120 } },
  grayscale = { ["1"] = { 120, 120 } },
  back = { normal = {}, shiny = {}, grayscale = {} },
}
local megaEvolution = {
  usesCrystalBattleFront = function(mon)
    return mon and mon._fixtureCrystalMega == true
  end,
}
local controller = assert(dofile(modDir .. "/crystal_animation.lua")(
  fakeMod, {
    animationData = timing,
    shinySystem = { isShiny = function(mon) return mon and mon.shiny end },
    megaEvolution = megaEvolution,
  }))

local calls = {}
local BattleState = {
  update = function() end,
  drawPicsLayer = function(_, slide, sx, sy, onlySide, skipMenuClip)
    calls[#calls + 1] = {
      slide = slide, sx = sx, sy = sy,
      onlySide = onlySide, skipMenuClip = skipMenuClip,
    }
    return "drawn"
  end,
}
controller.install({ data = data }, { battleState = BattleState })

local function resetCalls()
  calls = {}
end
local function selectFront(mon, external)
  return controller.select({
    species = mon.species, mon = mon, kind = "battle", data = data,
  }, "front", external == true)
end
local function battleFor(mon, edition)
  return setmetatable({
    edition = edition,
    enemy = { mon = mon, sprite = {} },
    player = { mon = { species = "CHARIZARD" }, sprite = {} },
    showEnemyTrainer = false,
  }, { __index = BattleState })
end

local normal = { species = "BULBASAUR" }
check(selectFront(normal) ~= nil,
  "normal authored Crystal front resolves before layout")
for _, edition in ipairs({ "red", "blue", "yellow" }) do
  resetCalls()
  local battle = battleFor(normal, edition)
  eq(BattleState.drawPicsLayer(battle, 3, 2, 4, nil, true), "drawn",
    edition .. " draw preserves the engine return contract")
  eq(#calls, 2, edition .. " splits the native two-side composition")
  eq(calls[1].onlySide, "enemy", edition .. " draws enemy first")
  eq(calls[1].sx, -6, edition .. " moves Crystal enemy one tile left")
  eq(calls[1].sy, -4, edition .. " moves Crystal enemy one tile up")
  eq(calls[1].slide, 3, edition .. " preserves intro slide")
  eq(calls[1].skipMenuClip, true, edition .. " preserves clip mode")
  eq(calls[2].onlySide, "player", edition .. " draws player second")
  eq(calls[2].sx, 2, edition .. " never moves the player back")
  eq(calls[2].sy, 4, edition .. "never moves the player back vertically")
end

resetCalls()
BattleState.drawPicsLayer(battleFor(normal, "red"), 0, 5, 6, "enemy", false)
eq(#calls, 1, "wide/native enemy-only composition remains one draw")
eq(calls[1].sx, -3, "enemy-only composition receives the same x offset")
eq(calls[1].sy, -2, "enemy-only composition receives the same y offset")

resetCalls()
BattleState.drawPicsLayer(battleFor(normal, "red"), 0, 5, 6, "player", false)
eq(#calls, 1, "player-only composition is not split")
eq(calls[1].sx, 5, "player-only x remains exact")
eq(calls[1].sy, 6, "player-only y remains exact")

values.crystal_animation = false
local still = { species = "BULBASAUR" }
check(selectFront(still) ~= nil,
  "static Crystal front resolves with animation disabled")
eq(controller.selected[still], nil,
  "animation-off front has no motion state")
eq(select(1, controller.enemyFrontOffset(battleFor(still, "yellow"))), -8,
  "animation-off front still receives layout clearance")
values.crystal_animation = true

local shiny = { species = "BULBASAUR", shiny = true }
local shinyPath = assert(selectFront(shiny))
check(shinyPath:find("/front/shiny/1/001.png", 1, true) ~= nil,
  "shiny Crystal front resolves its own authored family")
local shinyDx, shinyDy = controller.enemyFrontOffset(
  battleFor(shiny, "blue"))
eq(shinyDx, -8, "shiny front receives the same one-tile x clearance")
eq(shinyDy, -8, "shiny front receives the same one-tile y clearance")

local yielded = { species = "BULBASAUR" }
eq(selectFront(yielded, true), nil, "external sprite provider wins")
local yieldedDx, yieldedDy = controller.enemyFrontOffset(
  battleFor(yielded, "red"))
eq(yieldedDx, 0, "external front is never repositioned")
eq(yieldedDy, 0, "external front keeps its exact vertical placement")

values.pokemon_sprite_style = "legacy"
values.kanto_crystal_art = false
local native = { species = "BULBASAUR" }
eq(selectFront(native), nil, "legacy/native Gen1 front remains selected")
local nativeDx, nativeDy = controller.enemyFrontOffset(
  battleFor(native, "red"))
eq(nativeDx, 0, "native Gen1 front is never moved")
eq(nativeDy, 0, "native Gen1 front keeps its engine baseline")
values.pokemon_sprite_style = "crystal"
values.kanto_crystal_art = true

local trainerBattle = battleFor(normal, "blue")
trainerBattle.showEnemyTrainer = true
local trainerDx, trainerDy = controller.enemyFrontOffset(trainerBattle)
eq(trainerDx, 0, "enemy trainer picture is never moved")
eq(trainerDy, 0, "enemy trainer picture keeps its engine baseline")

local megaCrystal = { species = "CHARIZARD", _fixtureCrystalMega = true }
local megaDx, megaDy = controller.enemyFrontOffset(
  battleFor(megaCrystal, "yellow"))
eq(megaDx, -8, "Crystal Mega front shares the native-2D clearance seam")
eq(megaDy, -8, "Crystal Mega front moves one tile up")
local megaGen1 = { species = "CHARIZARD", _fixtureCrystalMega = false }
local megaGen1Dx, megaGen1Dy = controller.enemyFrontOffset(
  battleFor(megaGen1, "yellow"))
eq(megaGen1Dx, 0, "Gen1-style Mega front is not moved")
eq(megaGen1Dy, 0, "Gen1-style Mega front keeps its baseline")

local Pipelines = require("src.render.Pipelines")
local originalLevel = Pipelines.level
Pipelines.level = function(id)
  if id == "voxel" then return 1 end
  return originalLevel(id)
end
local voxelDx, voxelDy = controller.enemyFrontOffset(
  battleFor(normal, "red"))
eq(voxelDx, 0, "Voxel/Battle Art pipeline is never repositioned")
eq(voxelDy, 0, "Voxel/Battle Art pipeline keeps renderer-owned placement")
Pipelines.level = originalLevel

-- Pixel-bound proof for the exact 0.1.96/0.1.98 enemyPicXY contract:
-- placement caps at seven tiles, while the complete image is still drawn.
local HUD_NAME_Y = 56
local function bottomAfterOffset(height)
  local tileHeight = math.max(1, math.min(7, math.floor(height / 8)))
  local top = 8 * (7 - tileHeight)
  return top - 8 + height
end
eq(bottomAfterOffset(56), 48,
  "56px Crystal card gains one full tile before the name HUD")
eq(HUD_NAME_Y - bottomAfterOffset(56), 8,
  "normal Crystal card has an exact 8px HUD gap")
eq(bottomAfterOffset(60), 52,
  "60px Mega card no longer crosses the name HUD")
eq(bottomAfterOffset(64), 56,
  "64px Gorochu card ends exactly before the name HUD")
check(bottomAfterOffset(64) <= HUD_NAME_Y,
  "largest shipped Crystal front cannot overlap the player name")

S.finish()
