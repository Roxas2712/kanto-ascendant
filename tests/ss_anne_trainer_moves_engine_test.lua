-- Exact-engine/data regression for the report that every S.S. Anne trainer
-- falls back to Struggle. Run this in a clean process for each official
-- R/B/Y data cache, engine 0.1.96/0.1.98 and requested scenario.

package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local Version = require("src.core.Version")
local GameVersion = require("src.core.GameVersion")
local Data = require("src.core.Data")
local SaveData = require("src.core.SaveData")
local Pokemon = require("src.pokemon.Pokemon")
local BattleState = require("src.battle.BattleState")
local TrainerAI = require("src.battle.TrainerAI")

local modRoot = assert(os.getenv("TRAINER_REMATCH_MOD_DIR"),
  "TRAINER_REMATCH_MOD_DIR is required")
local expectedEngine = assert(os.getenv("KA_EXPECT_ENGINE"),
  "KA_EXPECT_ENGINE is required")
local edition = assert(os.getenv("KA_EXPECT_EDITION"),
  "KA_EXPECT_EDITION is required")
local scenario = os.getenv("KA_SS_ANNE_SCENARIO") or "normal"

T.eq(Version.engine, expectedEngine, "exact engine version")
T.check(edition == "red" or edition == "blue" or edition == "yellow",
  "official edition fixture")
GameVersion.set(edition)
Data:load()

local run = T.sdk.loadMod(modRoot, { data = Data, root = "/" })
T.eq(#run.errors, 0, "Kanto Ascendant loads without registry failures")
local exports = assert(run.loader.exports.kanto_ascendant)
local runRules = assert(exports.runRules)

local save = SaveData.newGame({
  version = edition, playerName = "SSANNE", rivalName = "RIVAL",
})
save.party[1] = Pokemon.new(Data, "PIKACHU", 30,
  function(lo, hi) return math.floor((lo + hi) / 2) end)
local pushed = {}
local game = {
  data = Data,
  save = save,
  overworld = {
    map = { id = "SS_ANNE_1F_ROOMS", def = Data.maps.SS_ANNE_1F_ROOMS },
  },
  stack = {
    push = function(_, value) pushed[#pushed + 1] = value end,
    pop = function() end,
  },
  writeSave = function() return true end,
}

run.loader.modSave = save.modData
run.loader.modOptions.kanto_ascendant =
  run.loader.modOptions.kanto_ascendant or {}
local options = run.loader.modOptions.kanto_ascendant
options.difficulty = "standard"
options.wild_level_scaling = false

-- game.ready is the production binding point for both the difficulty hook
-- and the per-save Randomizer/Nuzlocke controller.
run.loader.events:emit("game.ready", { game = game })
local rules = assert(runRules.state(save))
if scenario == "very_hard" or scenario == "extreme" then
  options.difficulty = scenario
elseif scenario == "nuzlocke" then
  rules.nuzlocke.mode = "standard"
  assert(runRules.lock(game, "explicit_start"))
  runRules.buildPool(game)
elseif scenario == "randomizer_balanced"
    or scenario == "randomizer_chaos" then
  rules.randomizer.enabled = true
  rules.randomizer.trainers = true
  rules.randomizer.balanced = scenario == "randomizer_balanced"
  rules.randomizer.consistent = true
  assert(runRules.lock(game, "explicit_start"))
  runRules.buildPool(game)
else
  T.check(scenario == "normal" or scenario == "rematch",
    "known S.S. Anne scenario")
end

local specs, seen = {}, {}
for mapId, map in pairs(Data.maps) do
  if tostring(mapId):find("SS_ANNE", 1, true) then
    for _, object in ipairs(map.objects or {}) do
      if object.trainerClass and object.trainerParty then
        local key = object.trainerClass .. "#" .. object.trainerParty
        if not seen[key] then
          seen[key] = true
          specs[#specs + 1] = {
            mapId = mapId,
            class = object.trainerClass,
            party = object.trainerParty,
            index = object.index,
            text = object.text,
          }
        end
      end
    end
  end
end
table.sort(specs, function(a, b)
  if a.class == b.class then return a.party < b.party end
  return a.class < b.class
end)
T.eq(#specs, 17, edition .. " S.S. Anne trainer object contracts")

local checkedMons, checkedMoves = 0, 0
local function rng(lo) return lo end
for _, spec in ipairs(specs) do
  local source = assert(Data.trainers[spec.class]).parties[spec.party]
  T.check(type(source) == "table" and #source > 0,
    spec.class .. "#" .. spec.party .. " source party exists")
  local sourceSignature = {}
  for index, slot in ipairs(source) do
    sourceSignature[index] = tostring(slot.species) .. "@" .. tostring(slot.level)
  end

  local battle = BattleState.newTrainer(game, spec.class, spec.party)
  T.check(not battle.dead, spec.class .. "#" .. spec.party .. " constructs")
  T.eq(#battle.enemyParty, #source,
    spec.class .. "#" .. spec.party .. " keeps party size")
  for index, mon in ipairs(battle.enemyParty) do
    checkedMons = checkedMons + 1
    T.check(type(mon.moves) == "table" and #mon.moves > 0,
      ("%s#%d slot %d has a legal learned moveset"):format(
        spec.class, spec.party, index))
    for _, move in ipairs(mon.moves or {}) do
      checkedMoves = checkedMoves + 1
      T.check(Data.moves[move.id] ~= nil,
        spec.class .. " materialized unknown move " .. tostring(move.id))
      T.check((tonumber(move.pp) or 0) > 0,
        spec.class .. " materialized zero-PP move " .. tostring(move.id))
    end

    -- Use the real battler and class AI layers. The engine can return
    -- Struggle only if this finalized opponent has no usable move.
    local battler = BattleState.makeBattler(Data, mon, false)
    battle.enemy = battler
    battler.aiLayer2 = 0
    local selected = TrainerAI.chooseMove(battler, rng, battle)
    T.check(selected and selected.id ~= "STRUGGLE" and not selected.struggle,
      ("%s#%d slot %d selected Struggle in %s"):format(
        spec.class, spec.party, index, scenario))
  end

  for index, slot in ipairs(source) do
    T.eq(tostring(slot.species) .. "@" .. tostring(slot.level),
      sourceSignature[index], spec.class .. " source party remains immutable")
  end
end

if scenario == "rematch" then
  local Overworld = require("src.world.OverworldController")
  local rematches = 0
  for serial, spec in ipairs(specs) do
    -- The ship rival is an authored on-step story encounter, deliberately
    -- excluded from the generic field-trainer rematch controller.
    if spec.class ~= "OPP_RIVAL1" then
      local key = ("SSANNE_QA_%s_%d_%d"):format(
        spec.class, spec.party, serial)
      exports.trainerStates()[key] = {
        rematches = 0, trainingCycles = 0, masteryWins = 0,
        readyAt = 0, recruitFamilies = {},
      }
      local npc = {
        id = key,
        def = {
          trainerClass = spec.class, trainerParty = spec.party,
          index = spec.index, text = spec.text,
        },
        frozen = false,
        facePlayer = function() end,
      }
      local captured
      local overworld = {
        map = { id = spec.mapId, def = Data.maps[spec.mapId] },
        player = {},
        trainerDefeated = function() return true end,
        afterBattle = function() end,
        pushBattle = function(_, battle) captured = battle end,
      }
      pushed = {}
      Overworld.talkTo(overworld, npc)
      local prompt = pushed[#pushed]
      T.check(prompt and type(prompt.choice) == "function",
        spec.class .. "#" .. spec.party .. " exposes its real rematch prompt")
      prompt.choice(true)
      -- An unexpectedly large gap adds a second confirmation; the level-30
      -- fixture normally avoids it, but driving it keeps this regression
      -- robust to an authored team retune.
      if not captured and pushed[#pushed] ~= prompt
          and type(pushed[#pushed].choice) == "function" then
        pushed[#pushed].choice(true)
      end
      T.check(captured and captured.rematch == true,
        spec.class .. "#" .. spec.party .. " constructs a real KASC rematch")
      for index, mon in ipairs(captured.enemyParty or {}) do
        T.check(type(mon.moves) == "table" and #mon.moves > 0,
          ("%s#%d rematch slot %d has moves"):format(
            spec.class, spec.party, index))
        local battler = BattleState.makeBattler(Data, mon, false)
        captured.enemy = battler
        battler.aiLayer2 = 0
        local selected = TrainerAI.chooseMove(battler, rng, captured)
        T.check(selected and selected.id ~= "STRUGGLE"
            and not selected.struggle,
          ("%s#%d rematch slot %d selected Struggle"):format(
            spec.class, spec.party, index))
      end
      rematches = rematches + 1
    end
  end
  T.eq(rematches, 16, edition .. " generic S.S. Anne rematches audited")
end

T.check(checkedMons >= 30, "all S.S. Anne party members audited")
T.check(checkedMoves >= checkedMons, "every audited opponent has usable PP")
print(("SS ANNE MOVE INTEGRITY PASS: engine=%s edition=%s scenario=%s "
  .. "trainers=%d mons=%d moves=%d"):format(
    expectedEngine, edition, scenario, #specs, checkedMons, checkedMoves))
