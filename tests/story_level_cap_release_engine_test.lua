-- Integration against released 0.2.56 and the earlier LevelCap engine source.
-- Run from a selected Gen1 Recomp root for each official R/B/Y edition.

package.path = "./?.lua;./?/init.lua;" .. package.path
love = love or require("tests.love_stub")

local edition = assert(os.getenv("KA_EXPECT_EDITION"),
  "KA_EXPECT_EDITION is required")
assert(edition == "red" or edition == "blue" or edition == "yellow",
  "official R/B/Y edition required")
local lineage = assert(os.getenv("KA_EXPECT_ENGINE"),
  "KA_EXPECT_ENGINE is required")
assert(lineage == "0.0.0-dev" or lineage == "0.2.56",
  "selected engine lineage required")
assert(require("src.core.Version").engine == lineage,
  "running engine does not match the requested exact lineage")
local root = assert(os.getenv("TRAINER_REMATCH_MOD_DIR"),
  "TRAINER_REMATCH_MOD_DIR is required")

local Events = require("src.mods.Events")
local Hooks = require("src.mods.Hooks")
local Runtime = require("src.mods.Runtime")
local Growth = require("src.pokemon.Growth")
local Stats = require("src.pokemon.Stats")
local LevelCap = { resolve = function(data, mon, source, maxLevel)
  return Runtime.call("pokemon.level_cap", function() return nil end,
    {data=data, mon=mon, source=source, maxLevel=maxLevel})
end }
local Experience = require("src.battle.Experience")
local Evolution = require("src.pokemon.Evolution")
local ItemEffects = require("src.inventory.ItemEffects")
local GameVersion = require("src.core.GameVersion")

local checks = 0
local function eq(actual, expected, label)
  checks = checks + 1
  assert(actual == expected, (label or "values differ") .. ": "
    .. tostring(actual) .. " ~= " .. tostring(expected))
end
local function ok(value, label)
  checks = checks + 1
  assert(value, label)
end

local baseStats = { hp = 45, attack = 49, defense = 49, speed = 45,
  special = 65, specialAttack = 65, specialDefense = 65 }
local mistyTeam = {
  { species = "STARYU", level = 18 },
  { species = "STARMIE", level = 21 },
}
local data = {
  constants = { levelCap = 100 }, growth_rates = {},
  items = { RARE_CANDY = { name = "RARE CANDY" } },
  text = {}, sounds = {}, field = { starterCounterpicks = {} },
  trainers = { OPP_MISTY = { parties = { mistyTeam } } },
  pokemon = {
    BULBASAUR = { name = "BULBASAUR", growthRate = "MEDIUM_FAST",
      baseStats = baseStats, baseExp = 64, learnset = {}, levelMoves = {},
      evolutions = {
        { method = "LEVEL", level = 21, species = "IVYSAUR" },
      } },
    IVYSAUR = { name = "IVYSAUR", growthRate = "MEDIUM_FAST",
      baseStats = baseStats, baseExp = 142, learnset = {}, levelMoves = {},
      evolutions = {} },
    CHANSEY = { name = "CHANSEY", growthRate = "MEDIUM_FAST",
      baseStats = baseStats, baseExp = 1000, learnset = {}, levelMoves = {},
      evolutions = {} },
  },
}

local function mon(level)
  local def = data.pokemon.BULBASAUR
  local dvs = { hp = 8, attack = 8, defense = 8, speed = 8, special = 8 }
  local statExp = { hp = 0, attack = 0, defense = 0, speed = 0, special = 0 }
  local stats = Stats.calc(def, level, dvs, statExp)
  return { species = "BULBASAUR", level = level,
    exp = Growth.expForLevel(def.growthRate, level), dvs = dvs,
    statExp = statExp, stats = stats, hp = stats.hp, moves = {} }
end

local bucket, writes = {}, 0
local events, hooks, errors = Events.new(), Hooks.new(), {}
local mod = {
  id = "kanto_ascendant",
  options = { get = function(_, key)
    return key == "difficulty" and "standard" or nil
  end },
  save = {
    get = function(_, key, fallback)
      local value = bucket[key]
      return value == nil and fallback or value
    end,
    set = function(_, key, value) writes = writes + 1; bucket[key] = value end,
  },
  events = { on = function(_, name, fn, priority)
    return events:on(name, fn, priority, "kanto_ascendant")
  end },
  hooks = { wrap = function(_, name, fn, priority)
    return hooks:wrap(name, fn, priority, "kanto_ascendant")
  end },
}
local savedEvents, savedHooks, savedErrors =
  Runtime.events, Runtime.hooks, Runtime.errors
Runtime.install(events, hooks, errors)
GameVersion.set(edition)

local game = { data = data, save = {
  version = edition, inventory = { BOULDERBADGE = 1 }, flags = {},
  hallOfFame = {}, party = {}, player = { name = "RED", rival = "GARY" },
} }
local adaptive = assert(loadfile(root .. "/adaptive_trainer_levels.lua"))()(mod, {
  difficulty = {},
  growMon = function(_, mon, target) mon.level = target end,
})
-- Explicit +2 avoids changing AUTO/legacy-save defaults.
adaptive.currentSelection = function() return "2" end
local controller = assert(loadfile(root .. "/story_level_cap.lua"))()(mod, {
  gameVersion = GameVersion,
  adaptiveTrainerLevels = adaptive,
  storyGym = { plan = function(_, _, _, party) return party end },
  difficulty = { adjustParty = function(party) return party end },
  postgame = { state = function() return { masterWins = {} } end },
  postgameData = { gyms = {} },
})
events:emit("game.ready", { game = game })

eq(controller.mode(), "off", "missing state is OFF")
eq(LevelCap.resolve(data, mon(20), "battle", 100), nil,
  "OFF is a public-hook no-op")
eq(writes, 0, "legacy OFF causes no migration write")
ok(controller.setMode("story"), "STORY enables outside battle")
eq(controller.summary(game), "CAP: MISTY · LV21",
  "edition resolves the Standard Misty cap")

for _, source in ipairs({ "battle", "exp_share" }) do
  local target = mon(20)
  local levels, gained = Experience.apply(
    data, target, data.pokemon.CHANSEY, 100, true,
    source == "exp_share" and 2 or 1, false)
  eq(target.level, 21, source .. " reaches cap")
  eq(target.exp, Growth.expForLevel("MEDIUM_FAST", 21),
    source .. " discards overflow")
  eq(levels[#levels], 21, source .. " reports cap level-up")
  ok(gained > 0, source .. " reports accepted EXP")
  eq(Evolution.pendingLevelEvo(data, target), "IVYSAUR",
    source .. " retains at-cap evolution")
end

local capped = mon(21)
local cappedExp = capped.exp
local levels, gained = Experience.apply(
  data, capped, data.pokemon.CHANSEY, 100, true, 1, false)
eq(#levels, 0, "at-cap battle cannot add a level")
eq(gained, 0, "at-cap excess is not banked")
eq(capped.exp, cappedExp, "at-cap record stays exact")

local imported = mon(99)
local importedExp = imported.exp
Experience.apply(data, imported, data.pokemon.CHANSEY, 100, true, 1, false)
eq(imported.level, 99, "imported over-level mon is never down-leveled")
eq(imported.exp, importedExp, "imported over-level EXP is untouched")

local candy = mon(20)
local save = game.save
save.player.id = 1; save.party = { candy }
local result = ItemEffects.use(data, save, "RARE_CANDY", candy, nil, nil, nil)
eq(result, "consumed", "Rare Candy can land on cap")
eq(candy.level, 21, "Rare Candy reaches cap")
result = ItemEffects.use(data, save, "RARE_CANDY", candy, nil, nil, nil)
eq(result, "failed", "Rare Candy refuses at cap")

local battle = { kind = "trainer", game = game, oppClass = "OPP_MISTY",
  partyIndex = 1, enemyParty = { { species = "STARMIE", level = 22 } } }
events:emit("battle.started", { battle = battle })
eq(LevelCap.resolve(data, mon(20), "battle", 100), 21,
  "mandatory battle retains progression cap")
eq(controller.setMode("off"), false, "battle blocks mode changes")
events:emit("battle.ended", { battle = battle })

-- Real Events ordering and real adaptive planner: the ceiling must be
-- installed before adaptive changes the mandatory opponent.
for _, playerLevel in ipairs({15, 25, 40, 99}) do
  game.save.party = {mon(playerLevel)}
  events:emit("save.loaded", {game=game})
  eq(controller.currentStage(game).level, 21, "party swap/load leaves cap fixed")
  local team = {{species="BULBASAUR",level=19}, {species="BULBASAUR",level=21}}
  local b = {kind="trainer", game=game, oppClass="OPP_MISTY", partyIndex=1,
    enemyParty=team, ascendantDifficultyContext={difficulty="standard",
      adjustedParty={{species="BULBASAUR",level=19}, {species="BULBASAUR",level=21}}}}
  events:emit("battle.started", {battle=b})
  eq(b.ascendantStoryLevelCeiling, 21, "ceiling reaches adaptive before scaling")
  ok(b.enemyParty[1].level <= 21 and b.enemyParty[2].level <= 21,
    "mandatory opponent cannot exceed story cap")
  eq(controller.effective(game).level, 21, "battle cap stays fixed")
  events:emit("battle.ended", {battle=b})
end
-- Reward multipliers must execute inside the final clamp.
hooks:wrap("exp.gain", function(nextGain, ctx) return math.max(1,nextGain(ctx))*5 end, 200, "reward")
local boosted=mon(20)
Experience.apply(data,boosted,data.pokemon.CHANSEY,100,true,1,false)
eq(boosted.level,21,"5x reward cannot cross cap")
local _,zero=Experience.apply(data,boosted,data.pokemon.CHANSEY,100,true,1,false)
eq(zero,0,"5x reward cannot turn zero into one")
controller.setMode("off")
local uncapped=mon(21)
Experience.apply(data,uncapped,data.pokemon.CHANSEY,100,true,1,false)
ok(uncapped.level>21,"OFF preserves ordinary growth")
controller.setMode("custom")
controller.setOverride("gym:misty",30)
eq(controller.effective(game).level,30,"CUSTOM override remains authoritative")
controller.setMode("story")
eq(controller.effective(game).level,21,"STORY ignores custom override")

bucket[controller.STATE_KEY] = { version = 99, mode = "story", overrides = {} }
local beforeFutureWrites = writes
eq(LevelCap.resolve(data, mon(20), "battle", 100), nil,
  "future state fails closed to OFF")
eq(controller.setMode("story"), false, "future state is read-only")
eq(writes, beforeFutureWrites, "future state is never rewritten")
eq(#errors, 0, "public hook emitted no errors")

Runtime.install(savedEvents, savedHooks, savedErrors)
print(("story_level_cap_release_engine_test: PASS engine=%s edition=%s checks=%d")
  :format(lineage, edition, checks))
