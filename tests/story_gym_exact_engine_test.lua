-- Exact-engine constructor proof for the first-story Gym difficulty package.
-- Run once per engine 0.1.96/0.1.98 and official Red/Blue/Yellow cache.

package.path = "./?.lua;./?/init.lua;" .. package.path

love = love or {}
love.math = love.math or {}
love.math.random = love.math.random or function(lo, hi)
  if hi == nil then hi, lo = lo, 1 end
  return math.floor((lo + hi) / 2)
end
love.graphics = love.graphics or {}
love.graphics.newImage = love.graphics.newImage or function(path)
  return { path = path, getDimensions = function() return 8, 8 end }
end

local Version = require("src.core.Version")
local GameVersion = require("src.core.GameVersion")
local Data = require("src.core.Data")
local Pokemon = require("src.pokemon.Pokemon")
local BattleState = require("src.battle.BattleState")
local TrainerAI = require("src.battle.TrainerAI")
local Hooks = require("src.mods.Hooks")
local Events = require("src.mods.Events")
local Runtime = require("src.mods.Runtime")

local root = assert(os.getenv("TRAINER_REMATCH_MOD_DIR"),
  "TRAINER_REMATCH_MOD_DIR is required")
local expectedEngine = assert(os.getenv("KA_EXPECT_ENGINE"),
  "KA_EXPECT_ENGINE is required")
local edition = assert(os.getenv("KA_EXPECT_EDITION"),
  "KA_EXPECT_EDITION is required")
assert(Version.engine == expectedEngine,
  "wrong exact engine: " .. tostring(Version.engine))
assert(edition == "red" or edition == "blue" or edition == "yellow",
  "official edition required")

GameVersion.set(edition)
Data:load()

local hooks, events = Hooks.new(), Events.new()
Runtime.install(events, hooks, {})
local selectedTier = "standard"
local mod = {
  options = { get = function(_, key)
    if key == "difficulty" then return selectedTier end
  end },
  hooks = { wrap = function(_, name, fn, priority)
    return hooks:wrap(name, fn, priority, "story_gym_exact_engine_test")
  end },
  events = { on = function(_, name, fn, priority)
    return events:on(name, fn, priority, "story_gym_exact_engine_test")
  end },
}
local yellow = assert(loadfile(root .. "/yellow_gym_move_fidelity.lua"))()
local story = assert(loadfile(root .. "/story_gym_difficulty.lua"))()(mod, {
  gameVersion = GameVersion,
  yellowFidelity = yellow,
  usefulLayerId = "KA_REMATCH_USEFUL_MOVE",
  johtoUnlocked = function() return false end,
})
local randomizerSeen
hooks:wrap("trainer.party", function(nextParty, class, partyIndex, party)
  randomizerSeen = { class = class, party = partyIndex, rows = party }
  return nextParty(class, partyIndex, party)
end, 70, "randomizer-order-proof")
local difficulty = assert(loadfile(root .. "/difficulty.lua"))()(mod, {
  i18n = { text = function(en) return en end },
})
local trainerChain = assert(hooks.chains["trainer.party"])
assert(#trainerChain == 3 and trainerChain[1].priority == 150
    and trainerChain[2].priority == 110 and trainerChain[3].priority == 70,
  "trainer.party order must be Difficulty(150) > Gym(110) > Randomizer(70)")

local leaders = {
  { "OPP_BROCK", "PEWTER_GYM", 1 },
  { "OPP_MISTY", "CERULEAN_GYM", 1 },
  { "OPP_LT_SURGE", "VERMILION_GYM", 1 },
  { "OPP_ERIKA", "CELADON_GYM", 1 },
  { "OPP_KOGA", "FUCHSIA_GYM", 1 },
  { "OPP_SABRINA", "SAFFRON_GYM", 1 },
  { "OPP_BLAINE", "CINNABAR_GYM", 1 },
  { "OPP_GIOVANNI", "VIRIDIAN_GYM", 3 },
}
local tiers = { "standard", "high", "hard", "very_hard", "extreme" }

local save = {
  version = edition,
  player = { name = "GYMTEST", rival = "RIVAL", id = 1 },
  party = {}, inventory = {}, flags = {}, hallOfFame = {}, options = {},
  pokedex = { seen = {}, owned = {} }, money = 3000,
}
save.party[1] = Pokemon.new(Data, "PIKACHU", 30,
  function(lo, hi) return math.floor((lo + hi) / 2) end)
local game = {
  data = Data,
  save = save,
  overworld = { map = { id = "PEWTER_GYM" } },
  stack = { push = function() end, pop = function() end },
}
events:emit("game.ready", { game = game })

local constructed, materializedMoves = 0, 0
for _, tier in ipairs(tiers) do
  selectedTier = tier
  for _, spec in ipairs(leaders) do
    local class, map, partyIndex = spec[1], spec[2], spec[3]
    game.overworld.map = { id = map, def = Data.maps[map] }
    local source = assert(Data.trainers[class]).parties[partyIndex]
    local sourceSpecies, sourceLevels = {}, {}
    for index, row in ipairs(source) do
      sourceSpecies[index], sourceLevels[index] = row.species, row.level
    end

    local battle = BattleState.newTrainer(game, class, partyIndex)
    assert(not battle.dead, edition .. "/" .. class .. "/" .. tier
      .. " did not construct")
    assert(battle.kind == "trainer" and battle.oppClass == class
        and battle.partyIndex == partyIndex,
      "real BattleState identity fields do not match pending transaction")
    assert(#battle.enemyParty >= 1 and #battle.enemyParty <= 6,
      "real BattleState materialized invalid team size")
    assert(randomizerSeen and randomizerSeen.class == class
        and randomizerSeen.party == partyIndex
        and #randomizerSeen.rows == #battle.enemyParty,
      "Randomizer seam did not receive every authored Gym slot")
    for _, mon in ipairs(battle.enemyParty) do
      assert(type(mon.moves) == "table" and #mon.moves >= 1 and #mon.moves <= 4,
        edition .. "/" .. class .. "/" .. tier .. " empty moveset")
      for _, move in ipairs(mon.moves) do
        assert(Data.moves[move.id], "real constructor accepted unknown move "
          .. tostring(move.id))
        assert((tonumber(move.pp) or 0) > 0,
          "real constructor materialized zero-PP move " .. tostring(move.id))
        materializedMoves = materializedMoves + 1
      end
    end

    -- The engine emits this exact object at enter(). Emitting here avoids
    -- graphics/audio state while proving the real BattleState fields match
    -- the roster transaction stored by trainer.party.
    events:emit("battle.started", { battle = battle, kind = "trainer" })
    if tier == "standard" and edition ~= "yellow" then
      assert(battle.ascendantStoryGym == nil,
        "STANDARD Red/Blue must fully bypass the story Gym module")
      assert(#battle.enemyParty == #source,
        "STANDARD Red/Blue changed party size")
      for index, mon in ipairs(battle.enemyParty) do
        assert(mon.species == sourceSpecies[index]
            and mon.level == sourceLevels[index],
          "STANDARD Red/Blue changed authored species or level")
      end
    else
      assert(battle.ascendantStoryGym == true,
        "real battle did not match its pending story Gym transaction")
      assert(battle.ascendantStoryGymClass == class,
        "pending transaction matched the wrong leader")
      assert(battle.ascendantStoryGymDifficulty == tier,
        "pending transaction matched the wrong tier")
      assert(battle.ascendantStoryLevelCeiling == story.authored[class].ceiling,
        "adaptive ceiling missing from real BattleState")
      assert(battle.ascendantStoryPreserveAuthoredMoves == true,
        "adaptive move-preservation marker missing from real BattleState")
      assert(battle.ascendantStoryGymAdjustedParty == battle.enemyParty,
        "resolved party seam is not the real BattleState party")
      local expectedBonus = difficulty.progressionBonus("trainer", 0, tier)
      for index, mon in ipairs(battle.enemyParty) do
        local resolved = battle.ascendantStoryGymResolvedParty[index]
        assert(mon.level == resolved.level + expectedBonus,
          "Difficulty did not post-process every authored Gym slot")
      end
      if tier == "hard" and class == "OPP_MISTY" then
        -- Even if the native class budget is non-zero, the wrapper owns the
        -- whole first-story Gym item contract. Above threshold it must fall
        -- through to a move, never a vanilla Potion/X-item.
        battle.enemy.mon.hp = battle.enemy.mon.stats.hp
        battle.aiUses = 99
        local healthyAction = battle:enemyAction()
        assert(healthyAction and healthyAction.special ~= "aiItem"
            and battle.aiUses == 0,
          "above-threshold Gym turn leaked a native class item")

        battle.enemy.mon.hp = 1
        battle.aiUses = 99
        local action = battle:enemyAction()
        assert(action and action.special == "aiItem"
            and action.item == "SUPER_POTION",
          "real battle.enemy_action did not select the HARD Gym heal")
        assert(battle.ascendantStoryGymHealUses == 1,
          "HARD Gym did not debit its one battle-wide heal")
        local before = battle.enemy.mon.hp
        local messages = TrainerAI.useItem(battle, action.item)
        assert(type(messages) == "table" and #messages > 0
            and battle.enemy.mon.hp > before,
          "real TrainerAI aiItem path did not apply the Gym heal")

        -- Enemy send-out normally resets wAICount/aiUses. Simulate that
        -- transition with a real materialized backup battler: the wrapper
        -- must still suppress native class actions after the battle cap.
        battle.enemyIndex = 2
        battle.enemy = BattleState.makeBattler(Data, battle.enemyParty[2], false)
        battle.enemy.mon.hp = 1
        battle.aiUses = 99
        local afterSwitch = battle:enemyAction()
        assert(afterSwitch and afterSwitch.special ~= "aiItem"
            and battle.ascendantStoryGymHealUses == 1 and battle.aiUses == 0,
          "new enemy reset bypassed the battle-wide Gym heal cap")
      end
    end
    constructed = constructed + 1
  end
end

if edition == "yellow" then
  selectedTier = "standard"
  game.overworld.map = { id = "VERMILION_GYM", def = Data.maps.VERMILION_GYM }
  local surge = BattleState.newTrainer(game, "OPP_LT_SURGE", 1)
  local ids = {}
  for index, move in ipairs(surge.enemyParty[1].moves) do ids[index] = move.id end
  assert(table.concat(ids, ",") == "THUNDERBOLT,MEGA_PUNCH,MEGA_KICK,GROWL",
    "explicit Yellow STANDARD moves did not override legacy R/B boss table")
end

print(("story_gym_exact_engine_test: PASS engine=%s edition=%s battles=%d moves=%d")
  :format(expectedEngine, edition, constructed, materializedMoves))
