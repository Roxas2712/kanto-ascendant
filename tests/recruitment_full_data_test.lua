-- Imported-data coverage for deterministic Johto field-trainer recruitment.
package.path = "./?.lua;./?/init.lua;" .. package.path
love = love or require("tests.love_stub")

local Data = require("src.core.Data")
if not (Data.pokemon and Data.pokemon.RATTATA) then Data:load() end
local T = require("tests.modkit")
local modPath = os.getenv("TRAINER_REMATCH_MOD_DIR") or "../trainer_rematch"
local run = T.sdk.loadMod(modPath, { data = Data })
assert(#run.errors == 0, table.concat(run.errors, "\n"))
local api = assert(run.loader.exports.trainer_rematch)
local recruitment = assert(api.recruitment)
local checks = 0

local function check(value, message)
  checks = checks + 1
  assert(value, message)
end

local legendary = {
  ARTICUNO = true, ZAPDOS = true, MOLTRES = true, MEWTWO = true, MEW = true,
  RAIKOU = true, ENTEI = true, SUICUNE = true, LUGIA = true, HO_OH = true,
  CELEBI = true,
}

recruitment.configureJohto(api.johtoData.order, function() return false end)
check(#recruitment.eligibleJohtoFamilies(
  Data, { { species = "RATTATA", level = 50 } }, "OPP_YOUNGSTER") == 0,
  "pre-research recruitment must be Kanto-only")

recruitment.configureJohto(api.johtoData.order, function() return true end)
local classCount = 0
for class, pool in pairs(api.recruitPools) do
  classCount = classCount + 1
  local team = { { species = pool[1], level = 60 } }
  local candidates = recruitment.eligibleJohtoFamilies(Data, team, class)
  check(#candidates > 0,
    class .. " has no class-appropriate Johto recruitment candidate")
  for _, species in ipairs(candidates) do
    check(not legendary[species],
      class .. " exposed legendary recruitment candidate " .. species)
    local def = assert(Data.pokemon[species], "unknown candidate " .. species)
    check(def.dex > 151 and def.dex <= 251,
      class .. " exposed a non-Johto candidate " .. species)
  end
end
check(classCount == 47, "expected all 47 authored trainer classes")

local generic = recruitment.eligibleJohtoFamilies(
  Data, { { species = "RATTATA", level = 60 } }, "OPP_MODDED_CLASS")
check(#generic > 0,
  "a generic modded trainer cannot access eligible Johto families")

local fullTeam = {}
for i = 1, 6 do
  fullTeam[i] = { species = i % 2 == 0 and "RATTATA" or "SPEAROW",
    level = 20 + i }
end
check(recruitment.expand(Data, fullTeam, "OPP_BUG_CATCHER",
  "VIRIDIAN_BUG_CATCHER", 99, 99, true) == fullTeam,
  "an already-full Viridian Bug Catcher team must remain unchanged")

recruitment.configureJohto(api.johtoData.order, function(species)
  return species == "LEDYBA"
end)
local selections = {}
local trainerSeed, first
for seed = 1, 100 do
  local trialSelections = {}
  local trial = recruitment.expand(Data,
    { { species = "CATERPIE", level = 30 } }, "OPP_BUG_CATCHER",
    "VIRIDIAN_BUG_CATCHER_SAVE_" .. seed, 1, 30, true,
    { selections = trialSelections })
  if trial[2] and Data.pokemon[trial[2].species].dex > 151 then
    trainerSeed, first, selections =
      "VIRIDIAN_BUG_CATCHER_SAVE_" .. seed, trial, trialSelections
    break
  end
end
check(first and first[2] and Data.pokemon[first[2].species].dex > 151,
  "the researched Bug family was not recruited")
local rememberedFamily = selections[2]

recruitment.configureJohto(api.johtoData.order, function() return true end)
local loaded = recruitment.expand(Data,
  { { species = "CATERPIE", level = 30 } }, "OPP_BUG_CATCHER",
  trainerSeed, 1, 30, true,
  { selections = selections })
check(selections[2] == rememberedFamily and loaded[2].species == first[2].species,
  "save/load or a larger unlock pool rerolled the existing recruit")

local Pokemon = require("src.pokemon.Pokemon")
local recruitedMon = Pokemon.new(Data, loaded[2].species, 60,
  function() return 8 end)
check(#recruitedMon.moves > 0 and #recruitedMon.moves <= 4,
  "the evolved Johto recruit does not construct with a legal move list")

-- Elite Apex/Crown battles enter through the base story constructor rather
-- than postgame.newForcedBattle, so cover that independent path as well.
local SaveData = require("src.core.SaveData")
local BattleState = require("src.battle.BattleState")
local Runtime = require("src.mods.Runtime")
local eliteGame = {
  data = Data,
  save = SaveData.newGame(),
  stack = { push = function() end },
}
eliteGame.save.party = {
  Pokemon.new(Data, "RATTATA", 100, function() return 8 end),
}
eliteGame.save.hallOfFame = { {} }
eliteGame.save.flags.EVENT_BEAT_CHAMPION_RIVAL = true
local postgameState = api.postgame.state()
for _, gym in ipairs(api.postgameData.gyms) do
  postgameState.masterWins[gym.key] = true
end
api.postgame.game = eliteGame
local eliteClass = "OPP_LORELEI"
local apexTeam = api.postgameData.apex[eliteClass]
local eliteInput
local removeEliteRandomizer = Runtime.hooks:wrap("trainer.party",
  function(nextParty, class, partyIndex, party)
    eliteInput = party
    local downstream = nextParty(class, partyIndex, party)
    local out = {}
    for i = 1, #downstream do
      out[i] = { species = "RATTATA", level = 5 }
    end
    return out
  end, -100, "full-data-elite-randomizer")
local apexBattle = BattleState.newTrainer(eliteGame, eliteClass, 1)
Runtime.emit("battle.started", { battle = apexBattle })
removeEliteRandomizer()
check(#eliteInput == #apexTeam,
  "the Elite Randomizer did not receive the authored Apex roster")
check(apexBattle.ascendantForcedSource == "elite"
    and apexBattle.ascendantForcedRandomized,
  "the Apex Elite battle lost forced/randomized QA metadata")
for i, mon in ipairs(apexBattle.enemyParty) do
  check(mon.species == "RATTATA",
    "the Elite finalizer discarded a valid randomized species")
  check(mon.level == apexTeam[i].level,
    "the Elite finalizer lost the authored slot-level pattern")
end

local vanillaElite = Data.trainers[eliteClass].parties[1]
local removeEliteSwallow = Runtime.hooks:wrap("trainer.party",
  function() return vanillaElite end, 2000, "full-data-elite-swallow")
local fallbackElite = BattleState.newTrainer(eliteGame, eliteClass, 1)
Runtime.emit("battle.started", { battle = fallbackElite })
removeEliteSwallow()
check(fallbackElite.ascendantForcedFallback,
  "a swallowed vanilla Elite roster was not repaired")
check(#fallbackElite.enemyParty == #apexTeam,
  "the repaired Elite roster has the wrong team size")
for i, mon in ipairs(fallbackElite.enemyParty) do
  check(mon.species == apexTeam[i].species
      and mon.level == apexTeam[i].level,
    "the repaired Elite roster differs from its authored Apex team")
end

print(("%d imported-data recruitment checks passed"):format(checks))
