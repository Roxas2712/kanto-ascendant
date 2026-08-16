-- Kanto Ascendant rematch AI regression.
-- Run from an engine checkout:
--   KANTO_ASCENDANT_MOD_DIR=/abs/mod luajit /abs/mod/tests/rematch_ai_test.lua

package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local Data = T.fixtures.load()
local TypeChart = require("src.battle.TypeChart")
local TrainerAI = require("src.battle.TrainerAI")

local modPath = os.getenv("KANTO_ASCENDANT_MOD_DIR")
  or os.getenv("TRAINER_REMATCH_MOD_DIR") or "mods/kanto_ascendant"

local function move(id, moveType, power, effect)
  Data.moves[id] = {
    id = id, name = id:gsub("_", " "), type = moveType,
    power = power, accuracy = 100, pp = 20, effect = effect,
  }
end

-- Pidgeot's real mastery pool contains all four of these legal moves.  REST
-- is Psychic-type in Gen I, so vanilla Layer 3 uniquely promotes it against
-- Poison/Fighting even though the move fails at full HP.
move("REST", "PSYCHIC_TYPE", 0, "HEAL_EFFECT")
move("SKY_ATTACK", "FLYING", 140, "FLY_EFFECT")
move("HYPER_BEAM", "NORMAL", 150, "HYPER_BEAM_EFFECT")
move("DOUBLE_EDGE", "NORMAL", 100, "RECOIL_EFFECT")
move("RECOVER", "NORMAL", 0, "HEAL_EFFECT")
move("SOFTBOILED", "NORMAL", 0, "HEAL_EFFECT")
move("THUNDER_WAVE", "ELECTRIC", 0, "PARALYZE_EFFECT")
move("REFLECT", "PSYCHIC_TYPE", 0, "REFLECT_EFFECT")
move("LEECH_SEED", "GRASS", 0, "LEECH_SEED_EFFECT")

Data.type_chart.types = TypeChart.TYPES
Data.type_chart.matchups[#Data.type_chart.matchups + 1] = {
  attacker = "PSYCHIC_TYPE", defender = "POISON", multiplier = 20,
}
TypeChart.load(Data)

local registrations = {}
local fakeMod = {
  content = {
    ai_classes = {
      register = function(_, id, record)
        registrations[id] = record
      end,
    },
  },
}

local factory = assert(loadfile(modPath .. "/rematch_ai.lua"))()
local rematchAI = factory(fakeMod)
local layerId = assert(rematchAI.layerId)
T.neq(registrations[layerId], nil,
  "the KASC-only useful-move scoring layer is registered")
Data.ai_classes = registrations

local function battler(species, moves, hp, maxHp, status)
  local out = {
    mon = { species = species, hp = hp, stats = { hp = maxHp },
      status = status },
    curTypes = species == "PIDGEOT" and { "NORMAL", "FLYING" }
      or { "POISON" },
    curMoves = {}, stages = {},
  }
  for _, id in ipairs(moves) do
    out.curMoves[#out.curMoves + 1] = { id = id, pp = 20 }
  end
  return out
end

local function battleWith(moves, hp, status)
  local enemy = battler("PIDGEOT", moves, hp, 200, status)
  local battle = {
    kind = "trainer", rematch = true, data = Data, enemy = enemy,
    player = battler("ARBOK", { "DOUBLE_EDGE" }, 180, 180),
    enemyAIMods = { 1, 3 },
    ruleset = { enemyUnlimitedPP = true },
  }
  return battle, enemy
end

local function choose(battle, enemy, pick)
  enemy.aiLayer2 = 0
  return TrainerAI.chooseMove(enemy, function(lo, hi)
    return math.max(lo, math.min(hi, pick or lo))
  end, battle).id
end

local pidgeot, enemy = battleWith(
  { "REST", "SKY_ATTACK", "HYPER_BEAM", "DOUBLE_EDGE" }, 200)
T.eq(choose(pidgeot, enemy), "REST",
  "official Expert Layer 3 reproduces the full-HP Pidgeot REST lock")
T.eq(rematchAI.attach(pidgeot), true,
  "the guard attaches to a real KASC rematch")
T.eq(pidgeot.enemyAIMods[#pidgeot.enemyAIMods], layerId,
  "the useful-move layer runs after the selected Expert layers")
for pick = 1, 4 do
  T.neq(choose(pidgeot, enemy, pick), "REST",
    "full-HP Pidgeot cannot select useless REST (tie roll " .. pick .. ")")
end

enemy.mon.hp = 80
T.eq(choose(pidgeot, enemy), "REST",
  "damaged Pidgeot keeps strategic REST instead of losing the move")
enemy.mon.status = "SLP"
T.neq(choose(pidgeot, enemy), "REST",
  "a sleeping Pidgeot cannot select REST again")

local recoverBattle, recoverUser = battleWith(
  { "RECOVER", "DOUBLE_EDGE" }, 200)
rematchAI.attach(recoverBattle)
T.eq(choose(recoverBattle, recoverUser), "DOUBLE_EDGE",
  "RECOVER/SOFTBOILED-class healing is rejected at full HP")
recoverUser.mon.hp = 100
local recoverScore = registrations[layerId].score({
  battle = recoverBattle, user = recoverUser, target = recoverBattle.player,
}, Data.moves.RECOVER, 10)
T.eq(recoverScore, 10,
  "recovery remains normally scoreable when HP is missing")

local allInvalid, allInvalidUser = battleWith(
  { "REST", "RECOVER", "SOFTBOILED" }, 200)
rematchAI.attach(allInvalid)
T.neq(choose(allInvalid, allInvalidUser), nil,
  "an all-invalid recovery set still returns an action instead of deadlocking")

local statusBattle, statusUser = battleWith(
  { "THUNDER_WAVE", "DOUBLE_EDGE" }, 200)
rematchAI.attach(statusBattle)
statusBattle.player.mon.status = "PSN"
T.eq(choose(statusBattle, statusUser), "DOUBLE_EDGE",
  "a major-status move cannot loop against an already statused target")
statusBattle.player.mon.status = nil
T.eq(registrations[layerId].score({ user = statusUser,
    target = statusBattle.player }, Data.moves.THUNDER_WAVE, 10), 10,
  "a useful major-status move retains its ordinary score")

statusUser.reflect = true
T.eq(registrations[layerId].score({ user = statusUser,
    target = statusBattle.player }, Data.moves.REFLECT, 10) > 10, true,
  "an already active defensive screen is noncompetitive")
statusBattle.player.leechSeeded = true
T.eq(registrations[layerId].score({ user = statusUser,
    target = statusBattle.player }, Data.moves.LEECH_SEED, 10) > 10, true,
  "Leech Seed is noncompetitive when the target is already seeded")
statusBattle.player.leechSeeded = nil
statusBattle.player.curTypes = { "GRASS" }
T.eq(registrations[layerId].score({ user = statusUser,
    target = statusBattle.player }, Data.moves.LEECH_SEED, 10) > 10, true,
  "Leech Seed is noncompetitive against a Grass target")

local ordinary = { rematch = false, enemyAIMods = { 1, 3 } }
T.eq(rematchAI.attach(ordinary), false,
  "ordinary trainer battles retain the stock Gen-I AI contract")
T.eq(#ordinary.enemyAIMods, 2,
  "the KASC guard never leaks into non-rematch battles")

-- The reported Pidgeot is a NORMAL-family recruit available to each of the
-- three Viridian Gym Cooltrainers. Reproduce the real progress-5 mastery
-- build rather than assuming the report came from a damage-less set.
local Mastery = assert(loadfile(modPath .. "/rematch_mastery.lua"))().create({})
move("GUST", "NORMAL", 40, "NO_ADDITIONAL_EFFECT")
move("SAND_ATTACK", "NORMAL", 0, "ACCURACY_DOWN1_EFFECT")
move("QUICK_ATTACK", "NORMAL", 40, "NO_ADDITIONAL_EFFECT")
move("WHIRLWIND", "NORMAL", 0, "SWITCH_AND_TELEPORT_EFFECT")
move("WING_ATTACK", "FLYING", 35, "NO_ADDITIONAL_EFFECT")
move("AGILITY", "PSYCHIC_TYPE", 0, "SPEED_UP2_EFFECT")
move("MIRROR_MOVE", "FLYING", 0, "MIRROR_MOVE_EFFECT")
local masteryGame = { data = { moves = Data.moves, pokemon = {
  PIDGEOT = {
    types = { "NORMAL", "FLYING" },
    baseStats = { hp = 83, attack = 80, defense = 75,
      speed = 91, special = 70 },
    level1Moves = { "GUST", "SAND_ATTACK", "QUICK_ATTACK" },
    learnset = {
      { level = 5, move = "SAND_ATTACK" },
      { level = 12, move = "QUICK_ATTACK" },
      { level = 21, move = "WHIRLWIND" },
      { level = 31, move = "WING_ATTACK" },
      { level = 44, move = "AGILITY" },
      { level = 54, move = "MIRROR_MOVE" },
    },
    tmhm = { "DOUBLE_EDGE", "HYPER_BEAM", "REST", "SKY_ATTACK" },
  },
} } }
local masteryMon = {
  species = "PIDGEOT", level = 39,
  dvs = { hp = 8, attack = 9, defense = 8, speed = 8, special = 8 },
  statExp = {}, stats = {}, moves = {},
}
for _, id in ipairs({ "SAND_ATTACK", "QUICK_ATTACK", "WHIRLWIND",
    "WING_ATTACK" }) do
  masteryMon.moves[#masteryMon.moves + 1] = { id = id, pp = Data.moves[id].pp }
end
local masteryBattle = { enemyParty = { masteryMon } }
local Stats = { calc = function()
  return { hp = 120, attack = 100, defense = 95, speed = 110, special = 90 }
end }
Mastery.apply(masteryGame, masteryBattle, {
  Stats = Stats, kind = "field", key = "VIRIDIAN_GYM:COOLTRAINER",
  progress = 5, masteryWins = 0,
})
local ids = {}
for _, slot in ipairs(masteryMon.moves) do ids[#ids + 1] = slot.id end
T.eq(table.concat(ids, "/"),
  "HYPER_BEAM/REST/SKY_ATTACK/DOUBLE_EDGE",
  "the exact Expert Viridian recruit has three attacks; REST alone caused the loop")

T.finish("rematch useful AI")
