-- Fresh-campaign balance authority for 6.5.
--
-- This loads the complete production mod against the engine's generated Red
-- data and resolves real BattleState trainer parties.  Identity-specific
-- rivals may change species, but a standard fresh run must keep the authored
-- Gen-I level, healing and item economy.  Fresh/missing Living World settings
-- enable both visible Wilds and classic step encounters; a stored explicit
-- false must continue to select visible-only play.

package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local Data = require("src.core.Data")
local SaveData = require("src.core.SaveData")
local Pokemon = require("src.pokemon.Pokemon")
local BattleState = require("src.battle.BattleState")

Data:load()
local root = assert(os.getenv("KA_FRESH_BALANCE_MOD"),
  "KA_FRESH_BALANCE_MOD is required")
local run = T.sdk.loadMod(root, { data = Data, root = "/" })
T.eq(#run.errors, 0, "complete 6.5 mod loads for fresh-balance audit")

local exports = assert(run.loader.exports.kanto_ascendant)
local characters = assert(exports.extendedCharacters)
local difficulty = assert(exports.difficulty)
local legacy = assert(exports.legacyJourney)
local postgame = assert(exports.postgame)
local runRules = assert(exports.runRules)
local signals = assert(exports.johtoSignals)
local internalWilds = assert(exports.internalWilds)

local function schemaRow(key)
  for _, row in ipairs(run.loader.optionSchemas.kanto_ascendant or {}) do
    if row.key == key then return row end
  end
end

local function schemaDefault(key)
  local row = schemaRow(key)
  if row then return row.default end
  error("missing option schema row " .. tostring(key), 2)
end

local function partySignature(party)
  local out = {}
  for _, mon in ipairs(party or {}) do
    out[#out + 1] = tostring(mon.species) .. "@" .. tostring(mon.level)
  end
  return table.concat(out, ",")
end

local function levelSignature(party)
  local out = {}
  for _, mon in ipairs(party or {}) do out[#out + 1] = tostring(mon.level) end
  return table.concat(out, ",")
end

local function freshGame(character)
  local save = SaveData.newGame({
    version = "red", playerName = character, rivalName = "RIVAL",
  })
  local game = {
    data = Data,
    save = save,
    overworld = { map = { id = "REDS_HOUSE_2F",
      def = Data.maps.REDS_HOUSE_2F } },
    stack = { push = function() end },
    writes = 0,
  }
  function game:writeSave() self.writes = self.writes + 1 return true end
  runRules.install(game)
  signals.install(game, false)
  characters.select(character)
  save.party[1] = Pokemon.new(Data, "BULBASAUR", 5)
  return game
end

T.eq(schemaDefault("difficulty"), "standard",
  "fresh profile selects standard difficulty")
T.eq(schemaDefault("wild_level_scaling"), false,
  "fresh or migrated profile keeps Wild level scaling disabled")
T.eq(difficulty.adjustLevel(9, "trainer"), 9,
  "standard difficulty leaves trainer levels unchanged")
T.eq(difficulty.adjustLevel(5, "wild"), 5,
  "standard difficulty leaves wild levels unchanged")
T.eq(schemaRow("johto_signals_enable"), nil,
  "the generic options screen cannot activate Early Johto before Driftglass")
T.eq(schemaRow("johto_signals_start"), nil,
  "the generic options screen exposes no direct-start quest bypass")

run.loader.modOptions.kanto_ascendant =
  run.loader.modOptions.kanto_ascendant or {}
run.loader.modOptions.kanto_ascendant.johto_signals_enable = true
run.loader.modOptions.kanto_ascendant.johto_signals_start = "unleashed"
T.eq(signals.requestedStartPolicy(), "quest",
  "stale launcher direct-start values are ignored by the production runtime")

for _, edition in ipairs({ "red", "blue", "yellow" }) do
  local fresh = SaveData.newGame({ version = edition })
  T.eq(fresh.version, edition, edition .. " fresh save keeps its edition")
  T.eq(fresh.money, 3000, edition .. " fresh save keeps 3000 starting money")
  T.eq(#fresh.party, 0, edition .. " fresh save starts before starter choice")
  T.eq(fresh.inventory.POTION, nil,
    edition .. " fresh bag receives no extra healing item")
  T.eq(fresh.pcItems.POTION, 1,
    edition .. " fresh bedroom PC contains the one vanilla Potion")
  T.eq(fresh.lastHeal.map, "PALLET_TOWN",
    edition .. " fresh blackout anchor remains Pallet Town")
  T.check(not legacy.isActive(fresh),
    edition .. " fresh save is not a Legacy/NG+ journey")
  T.check(not postgame.hasHallOfFame(fresh),
    edition .. " fresh save has no Hall-of-Fame state")
  T.eq(postgame.phaseFor({}, fresh), "story",
    edition .. " fresh save remains in story phase")
  T.eq(postgame.eliteTier({}, fresh), nil,
    edition .. " fresh save has no postgame trainer tier")
end

-- Exact manual-RC repro: BLITZ (UNLEASHED) is replaced with a new GREEN game
-- in the same process and slot.  Game:adoptSave swaps the mod bucket, then
-- emits save.created; no save.loaded or second game.ready follows.
local blitz = SaveData.newGame({
  version = "red", playerName = "BLITZ", rivalName = "WRATH",
})
blitz.modData.kanto_ascendant = {
  johto_signals = {
    version = 2,
    earlyJohto = {
      version = 2,
      receiverRepaired = true,
      modeChosen = true,
      mode = "UNLEASHED",
      capsuleOpened = true,
      boatmanBriefed = true,
      traces = {},
      rarePity = {},
    },
    resonance = {}, prismGrotto = {},
  },
}
run.loader.modSave = blitz.modData
local switchedGame = {
  data = Data,
  save = blitz,
  overworld = { map = { id = "ROUTE_1", def = Data.maps.ROUTE_1 } },
  stack = { push = function() end },
}
signals.install(switchedGame, false)
T.eq(signals.migrationOpen(), true,
  "the source BLITZ fixture begins with UNLEASHED migration")

local green = SaveData.newGame({
  version = "red", playerName = "GREEN", rivalName = "RED",
})
run.loader.modSave = green.modData
switchedGame.save = green
run.loader.events:emit("save.created", { save = green })
local switchedState = signals.state()
T.eq(switchedState.receiverRepaired, false,
  "fresh GREEN cannot inherit BLITZ's repaired receiver")
T.eq(switchedState.modeChosen, false,
  "fresh GREEN cannot inherit BLITZ's migration choice")
T.eq(switchedState.boatmanBriefed, false,
  "fresh GREEN cannot inherit BLITZ's boatman permission")
T.eq(signals.migrationOpen(switchedState), false,
  "fresh GREEN stays Kanto-only after an in-process New Game")
T.eq(#signals.allowedSpeciesPool(switchedState, true), 0,
  "fresh GREEN exposes no catchable Johto species pool")

local expectedRival = {
  RED = "PIDGEY@9,SQUIRTLE@8",
  BLUE = "JIGGLYPUFF@9,SQUIRTLE@8",
  GREEN = "PIKACHU@9,SQUIRTLE@8",
}
for _, character in ipairs({ "RED", "BLUE", "GREEN" }) do
  local game = freshGame(character)
  local rules = runRules.state(game.save)
  T.eq(rules.preset, "standard", character .. " starts with standard run rules")
  T.eq(rules.randomizer.enabled, false,
    character .. " starts with randomizer disabled")
  T.eq(rules.nuzlocke.mode, "off",
    character .. " starts with Nuzlocke disabled")

  local signalState = signals.state()
  T.eq(signalState.receiverRepaired, false,
    character .. " fresh start has no repaired Johto receiver")
  T.eq(signalState.modeChosen, false,
    character .. " fresh start has no Johto migration mode")
  T.eq(signals.migrationOpen(signalState), false,
    character .. " cannot receive early Johto replacements yet")

  local lab = BattleState.newTrainer(game, "OPP_RIVAL1", 1)
  T.eq(partySignature(lab.enemyParty), "SQUIRTLE@5",
    character .. " Oak-lab rival remains one level-5 starter")

  local route22 = BattleState.newTrainer(game, "OPP_RIVAL1", 4)
  T.eq(partySignature(route22.enemyParty), expectedRival[character],
    character .. " Route 22 identity roster keeps authored L9/L8 band")

  local junior = BattleState.newTrainer(game, "OPP_JR_TRAINER_M", 1)
  T.eq(partySignature(junior.enemyParty), "DIGLETT@11,SANDSHREW@11",
    character .. " Pewter junior remains vanilla L11/L11")
  local brock = BattleState.newTrainer(game, "OPP_BROCK", 1)
  T.eq(partySignature(brock.enemyParty), "GEODUDE@12,ONIX@14",
    character .. " Brock remains vanilla L12/L14")
end

local expectedWilds = {
  ROUTE_22 = "3,3,4,4,2,2,3,5,3,4",
  ROUTE_2 = "3,3,4,4,5,3,2,5,4,5",
  VIRIDIAN_FOREST = "4,3,3,4,4,5,4,3,3,5",
}
local wildGame = freshGame("RED")
for mapId, expected in pairs(expectedWilds) do
  local slots = assert(Data.encounters[mapId].grass.slots)
  T.eq(levelSignature(slots), expected,
    mapId .. " registered encounter levels match the Gen-I source")
  local resolved = {}
  for _, slot in ipairs(slots) do
    resolved[#resolved + 1] = run.loader.hooks:call("encounter.species",
      function(row) return row end,
      { species = slot.species, level = slot.level },
      { mapId = mapId, terrain = "grass" })
  end
  T.eq(levelSignature(resolved), expected,
    mapId .. " live standard hook adds no wild level offset")
end

T.eq(schemaDefault("living_world_enabled"), true,
  "visible Wilds remains enabled for a fresh 6.5 profile")
T.eq(schemaDefault("living_world_chase"), true,
  "occasional visible-wild pursuit remains enabled")
T.eq(schemaDefault("living_world_random_encounters"), true,
  "classic step encounters default on alongside visible Wilds")
T.eq(internalWilds.exports.logic:canSuppressVanilla(), false,
  "a missing setting keeps both encounter pipelines on by default")

local johtoMasterMaps = {
  "KA_JOHTO_GATE_HALL",
  "KA_JOHTO_SILVER_PASSAGE", "KA_JOHTO_SILVER_FINALE",
  "KA_JOHTO_KRIS_PASSAGE", "KA_JOHTO_KRIS_FINALE",
  "KA_JOHTO_GOLD_PASSAGE", "KA_JOHTO_GOLD_FINALE",
}
for _, mapId in ipairs(johtoMasterMaps) do
  T.eq(internalWilds.exports.isMapExcluded(mapId), true,
    mapId .. " is an authored no-Wilds arena")
  local visible, visibleReason = internalWilds.exports.logic:trySpawn(
    wildGame, { mapId = mapId })
  T.eq(visible, nil, mapId .. " rejects direct visible spawns")
  T.eq(visibleReason, "authored Johto map: " .. mapId,
    mapId .. " reports the adapter-owned visible exclusion")
  local ambientCount = internalWilds.exports.ambient:spawnForMap(wildGame, {
    map = { id = mapId }, npcs = {}, entities = {},
  })
  T.eq(ambientCount, 0, mapId .. " rejects peaceful ambient Pokemon")
  local nativeCalls = 0
  local native = run.loader.hooks:call("encounter.roll", function()
    nativeCalls = nativeCalls + 1
    return { species = "RATTATA", level = 3 }
  end, {}, { mapId = mapId })
  T.eq(native, nil, mapId .. " suppresses classic encounters")
  T.eq(nativeCalls, 0,
    mapId .. " never reaches the native encounter picker")
end

-- Stored booleans remain authoritative. Explicit OFF selects visible-only;
-- explicit ON restores both paths. Removing the key returns to the new
-- both-enabled schema default instead of inventing a saved choice.
run.loader.modOptions.kanto_ascendant =
  run.loader.modOptions.kanto_ascendant or {}
run.loader.modOptions.kanto_ascendant.living_world_enabled = true
run.loader.modOptions.kanto_ascendant.living_world_random_encounters = false
T.eq(internalWilds.exports.logic:canSuppressVanilla(), true,
  "an explicit Random Battles OFF choice remains visible-only")
run.loader.modOptions.kanto_ascendant.living_world_random_encounters = true
T.eq(internalWilds.exports.logic:canSuppressVanilla(), false,
  "explicit Random Battles ON keeps visible and classic encounters")
run.loader.modOptions.kanto_ascendant.living_world_random_encounters = nil
T.eq(internalWilds.exports.logic:canSuppressVanilla(), false,
  "removing the setting restores the both-enabled default")
run.loader.modOptions.kanto_ascendant.living_world_enabled = nil

run.release()
T.finish("fresh_campaign_balance_regression_test")
