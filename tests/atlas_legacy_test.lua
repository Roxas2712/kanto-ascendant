-- Focused Kanto Ascendant 5.0 Atlas, wallet and Legacy Gallery regression.
--
-- Run from the Gen1 Recomp checkout:
--   TRAINER_REMATCH_MOD_DIR=../trainer_rematch \
--   POKEPORT_DATA_DIR=tests/fixture_data \
--   ./.tools/luajit-src/src/luajit \
--   ../trainer_rematch/tests/atlas_legacy_test.lua

package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.modkit")
local Data = T.fixtures.load()
local modPath = os.getenv("TRAINER_REMATCH_MOD_DIR")
  or "mods/trainer_rematch"
local run = T.sdk.loadMod(modPath, { data = Data })
T.eq(#run.errors, 0, "Kanto Ascendant loads for Atlas/Legacy tests")
T.eq(run.mod.manifest.version, "5.0.2",
  "the release manifest identifies the bundled-sprite 5.0 feature set")

local ex = assert(run.loader.exports.trainer_rematch)
local atlas = assert(ex.researchAtlas)
local legacy = assert(ex.legacyHall)
local ascendant = assert(ex.ascendant)
T.neq(ex.grandTour, nil, "the Legacy Gallery receives Grand Tour records")
T.neq(ex.frontierExchange, nil,
  "the Atlas-era economy controller is available")

local game = {
  data = Data,
  save = {
    player = { name = "RED", id = 151 },
    flags = { EVENT_BEAT_CHAMPION_RIVAL = true },
    hallOfFame = { {} },
    party = {}, boxes = {}, inventory = {}, bagOrder = {},
    pokedex = { seen = {}, owned = {} },
  },
}

local rewardById = {}
for _, row in ipairs(atlas.rewardRows(game)) do
  if row.value and row.value.item then
    rewardById[row.value.item] = row
  elseif row.value and row.value.noDrop then
    rewardById.NO_DROP = row
  end
end
T.eq(rewardById.MASTER_BALL.right, "1 PCT",
  "the Atlas publishes the exact balanced Master Ball band")
T.eq(rewardById.EXP_ALL.right, "5 PCT",
  "the Atlas publishes EXP.ALL's exact unique band")
T.eq(rewardById.RARE_CANDY.right, "5 PCT",
  "the Atlas publishes Rare Candy's exact band")
T.eq(rewardById.NUGGET.right, "15 PCT",
  "the Atlas publishes Nugget's exact band")
T.eq(rewardById.NO_DROP.right, "56 PCT",
  "the Atlas exposes the true base no-drop probability")

game.save.pokedex.seen.FIXMON_A = true
local habitats = atlas.habitatRows(game)
T.eq(#habitats, 1,
  "known habitats contain only species already revealed by this save")
T.eq(habitats[1].value, "FIXMON_A",
  "the Atlas never inserts an unseen Pokédex species")
game.save.pokedex.owned.FIXMON_A = true
habitats = atlas.habitatRows(game)
T.eq(habitats[1].right, "OWN",
  "a captured species receives the owned marker")

-- Dynamic habitat wording distinguishes outdoor grass, water, caves and
-- buildings. Percentages are explicitly the pre-hook base chances: world
-- events and Eevee replacement can still alter the encounter that follows.
do
  local language = "en"
  local i18n = {
    text = function(en, de) return language == "de" and de or en end,
    isGerman = function() return language == "de" end,
  }
  local habitatRowsBySpecies = {
    CYNDAQUIL = {
      map = "POKEMON_MANSION_B1F", terrain = "indoor", chance = 2,
    },
    TOTODILE = {
      map = "SEAFOAM_ISLANDS_B2F", terrain = "indoor", chance = 2,
    },
    CHINCHOU = {
      map = "ROUTE_20", terrain = "water", chance = 2,
    },
  }
  local research = {
    habitatFor = function(species) return habitatRowsBySpecies[species] end,
    isSpeciesResearched = function() return true end,
    habitatCandidates = function()
      return { { chance = 2 }, { chance = 2 } }
    end,
  }
  local isolatedMod = {
    save = {
      get = function(_, _, fallback) return fallback end,
    },
    options = { get = function() return "balanced" end },
    hooks = { wrap = function() end },
    content = {},
  }
  local isolatedAtlas =
    assert(loadfile(modPath .. "/research_atlas.lua"))()(isolatedMod, {
      i18n = i18n, johtoResearch = research,
      kantoCompletion = {
        postgameEevee = { map = "ROUTE_7", chance = 2 },
      },
    })
  local habitatGame = {
    data = {
      maps = {
        POKEMON_MANSION_B1F = { name = "POKEMON MANSION B1F" },
        SEAFOAM_ISLANDS_B2F = { name = "SEAFOAM ISLANDS B2F" },
        ROUTE_20 = { name = "ROUTE 20" },
        ROUTE_7 = { name = "ROUTE 7" },
      },
      encounters = {},
      pokemon = {
        CYNDAQUIL = {
          dex = 155, name = "CYNDAQUIL",
          evolutions = {
            { method = "LEVEL", level = 14, species = "QUILAVA" },
          },
        },
        QUILAVA = { dex = 156, name = "QUILAVA", evolutions = {} },
        TOTODILE = { dex = 158, name = "TOTODILE", evolutions = {} },
        CHINCHOU = { dex = 170, name = "CHINCHOU", evolutions = {} },
        EEVEE = { dex = 133, name = "EEVEE", evolutions = {} },
      },
    },
    save = { pokedex = { seen = {}, owned = {} } },
  }
  local building = isolatedAtlas.habitatDetails(habitatGame, "CYNDAQUIL")
  T.eq(building:find("\fbuilding\f", 1, true) ~= nil, true,
    "an indoor Pokémon Mansion habitat is labeled as a building")
  T.eq(building:find("grass", 1, true), nil,
    "an indoor building habitat is never mislabeled as grass")
  T.eq(building:find("POOL BASE: 2 PCT", 1, true) ~= nil, true,
    "the Atlas identifies the habitat-pool percentage as a base chance")
  T.eq(building:find("SPECIES BASE: 1 PCT", 1, true) ~= nil, true,
    "the existing per-species split is also identified as a base chance")
  T.eq(building:find("LEVEL 14 -> ???", 1, true) ~= nil, true,
    "known Pokémon show evolution conditions without spoiling unseen targets")
  habitatGame.save.pokedex.seen.QUILAVA = true
  building = isolatedAtlas.habitatDetails(habitatGame, "CYNDAQUIL")
  T.eq(building:find("LEVEL 14 -> QUILAVA", 1, true) ~= nil, true,
    "the Atlas reveals an evolution target after it has been seen")

  local cave = isolatedAtlas.habitatDetails(habitatGame, "TOTODILE")
  T.eq(cave:find("\fcave\f", 1, true) ~= nil, true,
    "a Seafoam indoor habitat is labeled as a cave")
  local water = isolatedAtlas.habitatDetails(habitatGame, "CHINCHOU")
  T.eq(water:find("\fwater\f", 1, true) ~= nil, true,
    "a water habitat retains its accurate terrain label")
  local eevee = isolatedAtlas.habitatDetails(habitatGame, "EEVEE")
  T.eq(eevee:find("BASE CHANCE: 2 PCT", 1, true) ~= nil, true,
    "Eevee's post-League percentage is identified as a base chance")

  language = "de"
  T.eq(isolatedAtlas.cleanMapName(
    habitatGame, "POKEMON_MANSION_B1F"), "POKéMON-HAUS UG1",
    "Atlas locations use their authored German map names")
  local germanBuilding =
    isolatedAtlas.habitatDetails(habitatGame, "CYNDAQUIL")
  T.eq(germanBuilding:find("\fGebäude\f", 1, true) ~= nil, true,
    "the building terrain label is localized in German")
  T.eq(germanBuilding:find("POOL BASIS: 2 PROZ", 1, true) ~= nil,
    true, "German habitat odds are explicitly labeled as base chances")
end

local trainerStates = ex.trainerStates()
trainerStates.ROUTE_1_obj_1 = {
  trainerName = "SCOUT", trainerClass = "OPP_YOUNGSTER",
  mapId = "ROUTE_1", rematches = 2, trainingCycles = 3, readyAt = 500,
}
run.loader.modSave.trainer_rematch.trainer_step_clock = 100
local trainers = atlas.trainerRows(game)
T.eq(trainers[1].label, "SCOUT",
  "the Trainer Log uses the recorded trainer identity")
T.eq(trainers[1].right, "400",
  "the Trainer Log reports an exact remaining-step count")

T.eq(ascendant.frontierBalance(), 0,
  "a new Ascendant wallet starts with no Frontier Points")
T.eq(ascendant.addFrontierPoints(12), 12,
  "facility rewards enter the shared Frontier wallet")
local spent, balance = ascendant.spendFrontierPoints(3)
T.eq(spent, true, "the wallet accepts an affordable atomic debit")
T.eq(balance, 9, "the wallet returns the exact post-purchase balance")
local rejected, unchanged = ascendant.spendFrontierPoints(10)
T.eq(rejected, false, "the wallet rejects an unaffordable debit")
T.eq(unchanged, 9, "a rejected debit leaves points unchanged")

local covered = {}
for _, row in ipairs(legacy.trophyRows(game)) do covered[row.id] = row end
T.eq(covered.crown.label, "???",
  "an unknown trophy does not reveal its name before completion")
T.eq(covered.crown.right, "???",
  "an unknown trophy does not reveal its completion condition")
T.eq(legacy.selectTitle("factory_architect"), false,
  "a locked achievement cannot be selected as a title")
T.eq(ascendant.unlockAchievement("factory_architect"), true,
  "the Factory title can be unlocked through the public achievement API")
T.eq(legacy.selectTitle("factory_architect"), true,
  "an unlocked title can be selected explicitly")
local titleId, titleName = legacy.currentTitle()
T.eq(titleId, "factory_architect",
  "the selected title remains active instead of following the newest title")
T.eq(titleName, "FACTORY ARCHITECT",
  "the active title uses its authored localized name")
T.eq(ascendant.unlockAchievement("sea_champion"), true,
  "the cruise title can unlock independently")
T.eq(legacy.currentTitle(), "factory_architect",
  "unlocking a newer achievement does not replace the selected title")

local tourState = ex.grandTour.state()
tourState.factory.wins = 1
tourState.cruise.clears = 1
local trophies = {}
for _, row in ipairs(legacy.trophyRows(game)) do trophies[row.id] = row end
T.eq(trophies.factory.done, true,
  "a Factory clear appears in the Legacy Gallery")
T.eq(trophies.cruise.done, true,
  "an S.S. Anne clear appears in the Legacy Gallery")

run.release()
T.finish("atlas_legacy")
