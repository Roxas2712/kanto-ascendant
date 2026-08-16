-- Phase-7 Crystal breeding compatibility and inheritance contract.

package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local Data = T.fixtures.load()
local modPath = os.getenv("TRAINER_REMATCH_MOD_DIR") or "mods/kanto_ascendant"
local run = T.sdk.loadMod(modPath, { data = Data })
T.eq(#run.errors, 0, "Kanto Ascendant loads with Crystal breeding data")
local daycare = assert(run.loader.exports.kanto_ascendant.daycare)
local hatchAnimation = assert(run.loader.exports.kanto_ascendant.eggHatchAnimation)
T.eq(hatchAnimation.optionalCrystalEggPath,
  "crystal_251/generated/egg/front.png",
  "Hatch movie can consume Crystal-251's user-extracted Egg art in place")
T.eq(hatchAnimation.phase(0), "settle", "Egg hatch movie starts with a quiet reveal beat")
T.eq(hatchAnimation.phase(24), "wobble", "Egg hatch movie enters its wobble sequence")
T.eq(hatchAnimation.phase(112), "crack", "Egg hatch movie exposes progressive cracks")
T.eq(hatchAnimation.phase(154), "reveal", "Egg hatch movie reveals the newborn Pokemon")
T.eq(hatchAnimation.phase(210), "message", "Egg hatch movie ends at its result text")
T.eq(hatchAnimation.fragmentsVisible(153), false,
  "Shell fragments do not precede the reveal")
T.eq(hatchAnimation.fragmentsVisible(154), true,
  "Shell fragments begin with the reveal burst")
T.eq(hatchAnimation.fragmentsVisible(188), true,
  "Shell fragments complete their short travel before cleanup")
T.eq(hatchAnimation.fragmentsVisible(189), false,
  "Shell fragments are removed before the settled newborn")
T.eq(hatchAnimation.fragmentsVisible(210), false,
  "No shell fragment can remain under the result message")

local function def(dex, level1, learnset, tmhm)
  return { dex = dex, name = "TEST", growthRate = "MEDIUM_FAST",
    baseStats = { hp = 45, attack = 49, defense = 49, speed = 45, special = 65 },
    level1Moves = level1 or {}, learnset = learnset or {}, tmhm = tmhm or {},
    evolutions = {}, types = { "NORMAL" }, catchRate = 45 }
end
local game = { data = { pokemon = {
  PARENT = def(1, { "BASE_A", "BASE_B", "BASE_C" },
    { { level = 12, move = "LEVEL_MOVE" } }, { "TM_MOVE" }),
  DITTO = def(132), MAGNEMITE = def(81), NIDOQUEEN = def(31),
  NIDORAN_F = def(29), NIDORAN_M = def(32),
}, moves = {
  BASE_A = { pp = 35 }, BASE_B = { pp = 35 }, BASE_C = { pp = 35 },
  LIGHT_SCREEN = { pp = 30 }, LEVEL_MOVE = { pp = 20 }, TM_MOVE = { pp = 10 },
} } }
local function mon(species, attack, otId, moves, defense, special)
  return { species = species, otId = otId, moves = moves or {},
    dvs = { attack = attack, defense = defense or 1, speed = 7, special = special or 1 } }
end

local female = mon("PARENT", 0, 1, { { id = "LEVEL_MOVE" } }, 1, 1)
local male = mon("PARENT", 2, 2,
  { { id = "LIGHT_SCREEN" }, { id = "LEVEL_MOVE" }, { id = "TM_MOVE" } }, 2, 2)
local ok, score = daycare.compatible(game, female, male)
T.eq(ok, true, "opposite-gender parents in one Egg Group are compatible")
T.eq(score, 255, "same-species parents with different OTs use Crystal byte 255")
male.otId = 1
T.eq(select(2, daycare.compatible(game, female, male)), 254,
  "same-species parents with one OT use Crystal byte 254")
male.otId = 2
male.species = "MAGNEMITE"
T.eq(daycare.compatible(game, female, male), false,
  "different Egg Groups are incompatible")
male.species, male.dvs.attack = "PARENT", 0
T.eq(daycare.compatible(game, female, male), false,
  "same-gender parents are incompatible")
male.dvs.attack = 2

local ditto = mon("DITTO", 0, 2, {}, 2, 2)
T.eq(select(2, daycare.compatible(game, female, ditto)), 128,
  "Ditto follows the different-species/different-OT compatibility byte")
T.eq(daycare.compatible(game, ditto, mon("DITTO", 0, 3)), false,
  "two Ditto cannot breed")
T.eq(daycare.compatible(game, female, mon("NIDOQUEEN", 0, 3)), false,
  "No-Egg group stays incompatible")
T.eq(daycare.compatible(game, female, mon("PARENT", 2, 4, {}, 1, 1)), false,
  "matching Defense and lower Special DV bits retain Crystal's restriction")
T.eq(daycare.productionThreshold(255), 80, "best Crystal pair uses 80/256 hatch roll")
T.eq(daycare.productionThreshold(128), 30, "different-OT species pair uses 30/256 hatch roll")
T.eq(daycare.productionThreshold(51), 10, "same-OT different-species pair uses 10/256 hatch roll")
local egg = { isEgg = true, moves = { { id = "CUT" } } }
T.eq(run.loader.hooks:call("fieldmove.eligibility", function() return egg end,
  "CUT", { save = { party = { egg } }, data = game.data }), nil,
  "Eggs are excluded from field-move eligibility")
local eggItems = run.loader.hooks:call("ui.party.submenu", function(_, items)
  return items
end, game, {
  { action = "stats" }, { action = "switch" }, { action = "cut" },
  { action = "surf" }, { action = "cancel" },
}, egg, { battle = false })
T.eq(#eggItems, 3, "Egg party submenu omits field-move actions")
T.eq(eggItems[2].action, "switch", "Eggs may still be reordered outside battle")
local battleEggItems = run.loader.hooks:call("ui.party.submenu", function(_, items)
  return items
end, game, {
  { action = "battle_switch" }, { action = "stats" }, { action = "cancel" },
}, egg, { battle = true })
T.eq(#battleEggItems, 2, "Egg party submenu omits battle switch")
T.eq(battleEggItems[1].action, "stats", "Egg battle submenu keeps inspection")

local inherited = daycare.inheritedMoves(game, "PARENT", female, male)
T.eq(#inherited, 4, "Crystal move inheritance retains the four-move cap")
T.eq(inherited[2], "LIGHT_SCREEN", "father passes listed Crystal Egg Moves")
T.eq(inherited[3], "LEVEL_MOVE", "both-parent level-up move inheritance is retained")
T.eq(inherited[4], "TM_MOVE", "father passes compatible Gen-II TM/HM moves")
local femaleDittoMoves = daycare.inheritedMoves(game, "PARENT", female, ditto)
T.eq(femaleDittoMoves[1], "BASE_A", "female with Ditto does not become a Gen-II egg-move donor")

local nidoranFemale = mon("NIDORAN_F", 0, 1)
local nidoranMale = mon("NIDORAN_M", 2, 2)
T.eq(daycare.eggSpecies(game, nidoranFemale, nidoranMale,
  function() return 0 end), "NIDORAN_F", "low Crystal Nidoran roll produces Nidoran♀")
T.eq(daycare.eggSpecies(game, nidoranFemale, nidoranMale,
  function() return 255 end), "NIDORAN_M", "high Crystal Nidoran roll produces Nidoran♂")

T.finish("breeding_phase7_test")
