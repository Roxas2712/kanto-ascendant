local engine = assert(os.getenv("GEN1RECOMP_DIR"),
  "GEN1RECOMP_DIR is required")
package.path = engine .. "/?.lua;" .. engine .. "/?/init.lua;" .. package.path

local assertions = 0
local function ok(value, message)
  assertions = assertions + 1
  assert(value, message)
end
local function eq(actual, expected, message)
  assertions = assertions + 1
  assert(actual == expected, message .. ": " .. tostring(actual)
    .. " ~= " .. tostring(expected))
end

local saved, hooks, events = {}, {}, {}
local mod = {
  id = "kanto_ascendant",
  save = {
    get = function(_, key) return saved[key] end,
    set = function(_, key, value) saved[key] = value end,
  },
  options = { get = function() return nil end },
  hooks = { wrap = function(_, name, fn) hooks[name] = fn end },
  events = { on = function(_, name, fn) events[name] = fn end },
  world = { spawnNpc = function() end, removeNpc = function() end,
    npc = function() end },
}

local legacy = { cycle = 1, runId = "progression", pact = "trainer",
  wanderersEnabled = true }
local journey = {
  state = function() return legacy end,
  profile = function() return { completedPaths = {} } end,
  wanderersEnabled = function() return true end,
}
local clock = 0
local recruitment = assert(loadfile("trainer_recruits.lua"))()
recruitment.configureJohto({}, function() return false end)
recruitment.configureEvolutionAvailability(function() return false end)

local pokemon = {
  RATTATA = { dex = 19, types = { "NORMAL" },
    baseStats = { hp = 30, attack = 56, defense = 35, speed = 72, special = 25 },
    evolutions = { { method = "LEVEL", level = 20, species = "RATICATE" } } },
  RATICATE = { dex = 20, types = { "NORMAL" },
    baseStats = { hp = 55, attack = 81, defense = 60, speed = 97, special = 50 },
    level1Moves = { "TACKLE", "QUICK_ATTACK" },
    learnset = { { level = 20, move = "HYPER_FANG" },
      { level = 40, move = "SUPER_FANG" } },
    tmhm = { "BODY_SLAM", "BLIZZARD", "THUNDER" } },
  PIDGEY = { dex = 16, types = { "NORMAL", "FLYING" },
    baseStats = { hp = 40, attack = 45, defense = 40, speed = 56, special = 35 },
    evolutions = { { method = "LEVEL", level = 18, species = "PIDGEOTTO" } } },
  PIDGEOTTO = { dex = 17, types = { "NORMAL", "FLYING" },
    baseStats = { hp = 63, attack = 60, defense = 55, speed = 71, special = 50 },
    evolutions = { { method = "LEVEL", level = 36, species = "PIDGEOT" } } },
  PIDGEOT = { dex = 18, types = { "NORMAL", "FLYING" },
    baseStats = { hp = 83, attack = 80, defense = 75, speed = 91, special = 70 },
    level1Moves = { "TACKLE", "QUICK_ATTACK" },
    learnset = { { level = 20, move = "WING_ATTACK" },
      { level = 40, move = "AGILITY" } },
    tmhm = { "BODY_SLAM", "BLIZZARD", "THUNDER" } },
}
local moves = {
  TACKLE = { type = "NORMAL", power = 35, accuracy = 95, pp = 35 },
  QUICK_ATTACK = { type = "NORMAL", power = 40, accuracy = 100, pp = 30 },
  HYPER_FANG = { type = "NORMAL", power = 80, accuracy = 90, pp = 15 },
  SUPER_FANG = { type = "NORMAL", power = 1, accuracy = 90, pp = 10 },
  BODY_SLAM = { type = "NORMAL", power = 85, accuracy = 100, pp = 15 },
  BLIZZARD = { type = "ICE", power = 120, accuracy = 90, pp = 5 },
  THUNDER = { type = "ELECTRIC", power = 120, accuracy = 70, pp = 10 },
  WING_ATTACK = { type = "FLYING", power = 60, accuracy = 100, pp = 35 },
  AGILITY = { type = "PSYCHIC_TYPE", power = 0, accuracy = 100, pp = 30 },
}
local game = {
  save = { inventory = {}, party = {
    { species = "RATTATA", level = 10 },
    { species = "PIDGEY", level = 10 },
  } },
  data = {
    pokemon = pokemon, moves = moves, items = {}, balls = {},
    trainers = { OPP_YOUNGSTER = { name = "YOUNGSTER", parties = {
      { { species = "RATTATA", level = 5 },
        { species = "PIDGEY", level = 6 } },
    } } },
    sprites = { SPRITE_YOUNGSTER = {} },
    constants = { badges = {} },
  },
}

local makeWanderers = assert(loadfile("legacy_wanderers.lua"))()
local wanderers = makeWanderers(mod, {
  journey = journey, recruitment = recruitment,
  clock = function() return clock end,
  random = function(lo, hi, purpose)
    if purpose == "master" then return hi end
    if purpose == "recruitment" then return hi end
    return lo
  end,
})
local archetype = wanderers.liveTrainerPool(game)[1]

local earlyState = { wins = 0, rotation = {} }
local _, early, earlyTier = wanderers.teamFor(
  game, archetype, earlyState, 3, true)
eq(early[1].species, "RATTATA", "early Wanderer keeps the base family stage")
eq(early[2].species, "PIDGEY", "early second slot remains unevolved")
ok(not earlyTier.perfectMastery, "early Wanderer has no perfect mastery")

legacy.cycle, clock = 2, 3600
game.save.party[1].level, game.save.party[2].level = 30, 30
local middleState = { wins = 3, rotation = {} }
local _, middle, middleTier = wanderers.teamFor(
  game, archetype, middleState, 3, true)
eq(middle[1].species, "RATICATE",
  "mid-game Wanderer reuses rematch evolution for the first family")
eq(middle[2].species, "PIDGEOTTO",
  "fair mid-game edge keeps the second family at its legal middle stage")
ok(middleTier.growthProgress > earlyTier.growthProgress,
  "Legacy cycle, wins and trainer clock increase roster progression")
ok(middleState.recruitment.OPP_YOUNGSTER.rematchProgressionVersion >= 2,
  "Wanderer commits through the existing recruitment state seam")

legacy.cycle, legacy.pact, clock = 3, "ascendant", 14400
game.save.party[1].level, game.save.party[2].level = 100, 100
local lateState = { wins = 10, rotation = {} }
local _, late, lateTier = wanderers.teamFor(
  game, archetype, lateState, 3, true)
eq(late[1].level, 100, "late Wanderer reaches the legal level-100 cap")
eq(late[2].level, 100, "every level-100 baseline slot remains capped")
ok(lateTier.perfectMastery,
  "level 100 plus sufficient cycle/wins enters the explicit perfect tier")
eq(lateTier.pact, "ascendant", "battle economy retains the Legacy pact")

local relievedState = { wins = 10, rotation = {}, lossRelief = 1 }
local _, relieved, relievedTier = wanderers.teamFor(
  game, archetype, relievedState, 3, false)
ok(not relievedTier.perfectMastery,
  "one persisted loss suspends perfect mastery even at level 100")
eq(relievedTier.aiLayers, 2,
  "one persisted loss removes one extra AI pressure layer")
local relievedBattle = {
  trainer = { id = "OPP_YOUNGSTER", name = "YOUNGSTER", baseMoney = 100 },
  enemyParty = relieved,
}
wanderers.configureBattle(game, relievedBattle, {
  token = "relieved-battle", expBonusPercent = 18,
  tier = relievedTier,
})
eq(#relievedBattle.enemyAIMods, 2,
  "relieved level-100 retry applies only two AI layers")
eq(relievedBattle.ascendantLegacyHealItemCap, 0,
  "relieved retry removes the opponent healing item")

local mastery = assert(loadfile("rematch_mastery.lua"))().create({
  johtoUnlocked = function() return true end,
})
local function mon(species, level)
  return { species = species, level = level, moves = {
    { id = "TACKLE", pp = 35 },
  } }
end
local mixedBattle = { enemyParty = { mon("RATICATE", 100), mon("PIDGEOT", 90) } }
local report = mastery.apply(game, mixedBattle, {
  kind = "legacy_wanderer", key = "perfect-mixed", progress = 20,
  masteryWins = 10, perfect = true,
  Stats = { calc = function(_, level)
    return { hp = level + 100, attack = level + 80,
      defense = level + 70, speed = level + 90, special = level + 60 }
  end },
})
for _, stat in ipairs({ "attack", "defense", "speed", "special", "hp" }) do
  eq(mixedBattle.enemyParty[1].dvs[stat], 15,
    "actual Lv100 perfect tier has maximum " .. stat .. " DV")
end
for _, stat in ipairs({ "hp", "attack", "defense", "speed", "special" }) do
  eq(mixedBattle.enemyParty[1].statExp[stat], 65535,
    "actual Lv100 perfect tier has maximum " .. stat .. " StatExp")
end
eq(#mixedBattle.enemyParty[1].moves, 4,
  "actual Lv100 perfect tier receives four selected legal moves")
local legal = mastery.legalMoves(game, mixedBattle.enemyParty[1], {
  johtoUnlocked = true,
})
for _, move in ipairs(mixedBattle.enemyParty[1].moves) do
  ok(legal[move.id], "perfect set contains only registry-legal moves")
end
ok(mixedBattle.enemyParty[2].dvs.attack < 15,
  "mixed-party sub-100 slot does not inherit perfect DVs")
ok(mixedBattle.enemyParty[2].statExp.attack < 65535,
  "mixed-party sub-100 slot does not inherit perfect StatExp")
ok(not report.perfect,
  "mixed-level report does not overclaim an all-party perfect end tier")

local masteryCalls = 0
wanderers.setMasteryProvider({ apply = function(_, battle, context)
  masteryCalls = masteryCalls + 1
  ok(context.perfect, "late battle forwards the explicit perfect context")
  battle.aiUses = battle:aiUsesFor()
  return { perfect = true }
end })
local battle = {
  trainer = { id = "OPP_YOUNGSTER", name = "YOUNGSTER", baseMoney = 100 },
  enemyParty = late,
  aiUses = 1,
  aiUsesFor = function() return 1 end,
}
wanderers.configureBattle(game, battle, {
  token = "late-battle", expBonusPercent = 18,
  tier = lateTier,
})
eq(masteryCalls, 1, "Wanderer battle invokes the configured mastery provider")
eq(#battle.enemyAIMods, 3, "late Wanderer enables all three legal AI layers")
eq(battle.enemyAIMods[1], 1, "AI layer one is enabled")
eq(battle.enemyAIMods[2], 2, "AI layer two is enabled")
eq(battle.enemyAIMods[3], 3, "AI layer three is enabled")
eq(battle.trainer.aiClass, "OPP_SABRINA",
  "late Wanderer uses the registered limited-healing TrainerAI class")
eq(battle.ascendantLegacyHealItemCap, 1,
  "late Wanderer healing cap is one item for the whole battle")
eq(battle.trainer.baseMoney, 300,
  "Ascendant pact retains its authored three-times money multiplier")

local enemyAction = hooks["battle.enemy_action"]
local function engineAction(b)
  if (b.aiUses or 0) > 0 then
    return { special = "aiItem", item = "HYPER_POTION" }
  end
  return { move = "TACKLE" }
end
local first = enemyAction(engineAction, battle)
eq(first.special, "aiItem", "registered TrainerAI may use its one heal")
eq(battle.ascendantLegacyHealItemUses, 1,
  "first legal healing item consumes the battle-wide allowance")
battle.aiUses = 1 -- engine normally resets this on the next enemy monster
local second = enemyAction(engineAction, battle)
eq(second.move, "TACKLE",
  "a per-mon AI reset cannot create healing spam after the cap")
eq(battle.ascendantLegacyHealItemUses, 1,
  "battle-wide healing usage stays capped at exactly one")

print(("legacy wanderers progression: %d assertions"):format(assertions))
