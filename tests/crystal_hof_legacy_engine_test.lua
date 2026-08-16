-- The downloadable RC is a mod package and may run on an app whose
-- HallOfFame predates the engine-side true-colour receipt.  Verify that the
-- mod's compatibility wrapper marks animated Crystal pictures itself without
-- requiring an engine replacement.

package.path = "./?.lua;./?/init.lua;" .. package.path

local modDir = assert(os.getenv("TRAINER_REMATCH_MOD_DIR"),
  "TRAINER_REMATCH_MOD_DIR is required")
love = love or require("tests.love_stub")

local marks = {}
local PaletteFX = require("src.render.PaletteFX")
local originalMark = PaletteFX.markTrueColor
PaletteFX.markTrueColor = function(x, y, w, h)
  marks[#marks + 1] = { x, y, w, h }
end

local pokemonImage = {
  getDimensions = function() return 56, 56 end,
}
local playerImage = {
  getDimensions = function() return 64, 64 end,
}

local LegacyHall = {}
LegacyHall.__index = LegacyHall
function LegacyHall.new(game)
  return setmetatable({
    game = game,
    index = 1,
    playerPic = playerImage,
    scrollX = 73,
  }, LegacyHall)
end
function LegacyHall:spriteFor() return nil end
function LegacyHall:update() end
function LegacyHall:drawPic(image)
  self.lastDrawn = image
end

package.loaded["src.ui.HallOfFame"] = LegacyHall
for _, name in ipairs({
  "SummaryMenu", "DexEntryMenu", "EvolutionState", "TrainerCard",
  "TitleState", "OakSpeech",
}) do
  package.loaded["src.ui." .. name] = false
end

local hooks = {}
local mod = {
  path = modDir,
  options = { get = function(_, key)
    if key == "pokemon_sprite_style" then return "crystal" end
    return true
  end },
  read = function() return nil end,
  hooks = { wrap = function(_, name, fn) hooks[name] = fn end },
  events = { on = function() end },
  content = { battle_sprite_scales = { register = function() end } },
}
local crystal = {
  externalKantoActive = function() return false end,
  advancedColor = function() return true end,
  presentationAnimation = function()
    return { image = pokemonImage, trueColor = true, frame = 1 }
  end,
  advancePresentation = function(state)
    return state.image
  end,
}
local factory = assert(loadfile(modDir .. "/crystal_v15_features.lua"))
local controller = factory()(mod, { crystalAnimation = crystal })
local battleState = {
  newTrainer = function() return {} end,
}
local game = {
  data = { pokemon = { BULBASAUR = {} } },
  save = { party = { { species = "BULBASAUR" } } },
}
controller.install(game, { battleState = battleState })

local screen = LegacyHall.new(game)
assert(screen.__ascendantHallNativeTrueColor == false,
  "legacy Hall was mistaken for a native true-colour engine")
local image = LegacyHall.spriteFor(screen, "BULBASAUR")
assert(image == pokemonImage, "Crystal Hall picture was not selected")
LegacyHall.drawPic(screen, image)
assert(screen.lastDrawn == pokemonImage, "legacy Hall draw was not preserved")
assert(#marks == 1 and marks[1][1] == 73 and marks[1][2] == 40
    and marks[1][3] == 56 and marks[1][4] == 56,
  "legacy Hall did not receive the alpha-sized true-colour late pass")

PaletteFX.markTrueColor = originalMark
print("crystal_hof_legacy_engine_test: PASS")
