-- Full-mod / real-engine lifecycle coverage for selective wanderer title
-- reactions. Run from Gen1 Recomp:
--   TRAINER_REMATCH_MOD_DIR=mods/0000_ka_rc11_integration \
--     ./.tools/luajit-src/src/luajit \
--     /path/to/tests/legacy_wanderer_title_engine_test.lua

package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local stubRead = love.filesystem.read
love.filesystem.read = function(path)
  local body, err = stubRead(path)
  if body ~= nil then return body, err end
  local handle = io.open(path, "rb")
  if not handle then return nil, err end
  body = handle:read("*a")
  handle:close()
  return body
end

local Data = require("src.core.Data")
if not (Data.pokemon and Data.pokemon.BULBASAUR) then Data:load() end
local SaveData = require("src.core.SaveData")

local assertions = 0
local function check(value, message)
  assertions = assertions + 1
  assert(value, message)
end
local function eq(actual, expected, message)
  check(actual == expected, (message or "values differ") .. " (got "
    .. tostring(actual) .. ", expected " .. tostring(expected) .. ")")
end
local function contains(text, fragment, message)
  check(type(text) == "string" and text:find(fragment, 1, true) ~= nil,
    message .. " (text: " .. tostring(text) .. ")")
end

local modPath = os.getenv("TRAINER_REMATCH_MOD_DIR")
  or "mods/kanto_ascendant"
local run = T.sdk.loadMod(modPath, { data = Data })
eq(#(run.errors or {}), 0, "the complete mod graph loads in the real engine")
local exports = assert(run.loader.exports.kanto_ascendant)
local hall = assert(exports.legacyHall)
local wanderers = assert(exports.legacyWanderers)
local ascendant = assert(exports.ascendant)

local function makeGame(save)
  return {
    data = Data,
    save = save,
    mods = run.loader,
    stack = { push = function() end },
    input = {},
  }
end

run.loader.modSave = {}
local save = SaveData.newGame()
run.loader.modSave = save.modData
local game = makeGame(save)
exports.install(game, {})

local scientist = {
  game = game,
  archetype = { class = "OPP_SCIENTIST" },
  team = { { species = "MAGNEMITE", level = 30 } },
}
local ace = {
  game = game,
  archetype = { class = "OPP_COOLTRAINER_M" },
  team = { { species = "PIDGEOTTO", level = 30 } },
}

local titleId, titleName = hall.currentTitle()
eq(titleId, nil, "a fresh real save has no selected title")
eq(titleName, "CHAMPION", "the hall exposes its neutral English fallback")
eq(wanderers.reactionContext(scientist).kind, "fallback",
  "the late-bound real Hall provider preserves no-title fallback")
contains(wanderers.challengeText(scientist), "not titles",
  "the real no-title field dialogue stays neutral")

check(ascendant.unlockAchievement("factory_architect"),
  "the real achievement API unlocks Factory Architect")
check(hall.selectTitle("factory_architect"),
  "the real Hall API selects the unlocked title")
titleId, titleName = hall.currentTitle()
eq(titleId, "factory_architect", "the selected title is active immediately")
eq(titleName, "FACTORY ARCHITECT", "the selected title resolves its real name")
eq(wanderers.reactionContext(scientist).kind, "title_factory",
  "the real Scientist recognizes the active title")
eq(wanderers.reactionContext(ace).kind, "fallback",
  "the real unrelated ace keeps the neutral fallback")
contains(wanderers.challengeText(scientist), "No rental team",
  "the selected title reaches the authored real field dialogue")
eq(save.modData.kanto_ascendant.legacy_hall.selectedTitle,
  "factory_architect", "Hall selection is stored in mod save data")
eq(save.modData.kanto_ascendant.ascendant.selectedTitle,
  "factory_architect", "Ascendant's compatibility title mirrors the choice")

local encoded = SaveData.encode(save)
local reloadedSave, decodeError = SaveData.decode(encoded)
check(reloadedSave ~= nil,
  "real save serialization reloads title state: " .. tostring(decodeError))
run.loader.modSave = reloadedSave.modData
local reloadedGame = makeGame(reloadedSave)
run.loader.events:emit("save.loaded", {
  save = reloadedSave, game = reloadedGame,
})
scientist.game = reloadedGame
titleId, titleName = hall.currentTitle()
eq(titleId, "factory_architect",
  "the selected title survives real encode/decode and save.loaded")
eq(titleName, "FACTORY ARCHITECT",
  "the persisted title keeps its localized display name")
eq(wanderers.reactionContext(scientist).kind, "title_factory",
  "the matching reaction survives reload with the selected title")
contains(wanderers.challengeText(scientist), "FACTORY\nARCHITECT?",
  "the reloaded real dialogue still names the achievement")

-- Partner recognition reads only the committed active-run fields. Merely
-- browsing a selector cannot create this reaction.
reloadedSave.modData.kanto_ascendant.legacy_journey = {
  version = 1, partnerChosen = false, partnerSpecies = "PIKACHU",
}
run.loader.modSave = reloadedSave.modData
local partnerActive = {
  game = reloadedGame,
  archetype = { class = "OPP_SUPER_NERD" },
  team = { { species = "PIKACHU", level = 30 } },
}
-- Clear only the selection for this independent partner branch while keeping
-- the unlocked achievement intact.
reloadedSave.modData.kanto_ascendant.legacy_hall.selectedTitle = nil
reloadedSave.modData.kanto_ascendant.ascendant.selectedTitle = nil
reloadedSave.modData.kanto_ascendant.ascendant.latestAchievement = nil
eq(wanderers.reactionContext(partnerActive).kind, "fallback",
  "an unresolved partner choice cannot affect real dialogue")
reloadedSave.modData.kanto_ascendant.legacy_journey.partnerChosen = true
eq(wanderers.reactionContext(partnerActive).kind, "partner_match",
  "the same roster recognizes the partner only after commitment")
contains(wanderers.challengeText(partnerActive), "PIKACHU knows",
  "the real committed-partner dialogue names the species")

-- A separate New Game save must not inherit the previous save's active title.
run.loader.modSave = {}
local freshSave = SaveData.newGame()
run.loader.modSave = freshSave.modData
local freshGame = makeGame(freshSave)
run.loader.events:emit("save.loaded", { save = freshSave, game = freshGame })
scientist.game = freshGame
titleId, titleName = hall.currentTitle()
eq(titleId, nil, "a fresh save cannot inherit another save's title")
eq(titleName, "CHAMPION", "fresh-save fallback remains available")
eq(wanderers.reactionContext(scientist).kind, "fallback",
  "fresh-save real dialogue returns to the no-title fallback")

run.release()
print(("legacy wanderer title engine: %d assertions"):format(assertions))
