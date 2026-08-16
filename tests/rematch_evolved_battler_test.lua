-- Regression for rematch lead evolution after BattleState.newTrainer.
-- Run from the engine checkout:
--   TRAINER_REMATCH_MOD_DIR=/path/to/kanto_ascendant \
--     luajit /path/to/kanto_ascendant/tests/rematch_evolved_battler_test.lua
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local Data = T.fixtures.load()

local function species(id, dex, name)
  return {
    id = id, index = dex, dex = dex, name = name,
    types = { "FIGHTING" },
    baseStats = { hp = 50, attack = 60, defense = 50,
      speed = 50, special = 40 },
    catchRate = 45, baseExp = 100, level1Moves = { "FIX_TACKLE" },
    growthRate = "MEDIUM_FAST", tmhm = {}, learnset = {}, evolutions = {},
    spriteFront = "tests/fixture_data/assets/fixmon_a_front.png",
    spriteBack = "tests/fixture_data/assets/fixmon_a_back.png",
    frontSize = 6,
  }
end

Data.pokemon.MANKEY = species("MANKEY", 56, "Localized Mankey")
Data.pokemon.PRIMEAPE = species("PRIMEAPE", 57, "Localized Primeape")
Data.pokemon.MACHOP = species("MACHOP", 66, "Localized Machop")
Data.pokemon.MACHAMP = species("MACHAMP", 68, "Localized Machamp")

local modPath = os.getenv("TRAINER_REMATCH_MOD_DIR")
  or "mods/kanto_ascendant"
local sdkOpts = { data = Data }
if modPath:sub(1, 1) == "/" then sdkOpts.root = "/" end
local Version = require("src.core.Version")
local oldEngine = Version.engine
Version.engine = "0.1.98"
local run = T.sdk.loadMod(modPath, sdkOpts)
Version.engine = oldEngine
T.eq(#run.errors, 0, "Kanto Ascendant loads for evolved-rematch regression")
local ex = assert(run.loader.exports.kanto_ascendant)
T.eq(type(ex.syncRematchLead), "function",
  "the rematch lead identity synchronizer is exported")

local Runtime = require("src.mods.Runtime")
local rebuilt = 0
local BattleState = {
  makeBattler = function(data, mon)
    rebuilt = rebuilt + 1
    local def = data.pokemon[mon.species]
    local ctx = {
      species = mon.species, side = "front", kind = "battle",
      mon = mon, data = data, trueColor = false,
    }
    local path = Runtime.call("pokemon.sprite",
      function(fallback) return fallback end, def.spriteFront, ctx)
    local animation = ex.crystalAnimation.selected[mon]
    return {
      mon = mon, def = def, name = mon.nickname or def.name,
      curStats = mon.stats, curTypes = def.types, curMoves = mon.moves,
      shownHP = mon.hp, sprite = path, spritePath = path,
      animationDex = animation and animation.dex or nil,
      animationFrames = animation and #animation.durations or 0,
    }
  end,
}

local function mon(id)
  return {
    species = id, hp = 50, stats = { hp = 50 }, moves = {},
    dvs = { attack = 9, defense = 8, speed = 8, special = 8, hp = 8 },
  }
end

for _, case in ipairs({
  { base = "MANKEY", evolved = "PRIMEAPE", dex = 57, frames = 22 },
  { base = "MACHOP", evolved = "MACHAMP", dex = 68, frames = 20 },
}) do
  local oldLead, evolvedLead = mon(case.base), mon(case.evolved)
  local battle = {
    data = Data, enemyIndex = 1, enemyParty = { evolvedLead },
    enemy = BattleState.makeBattler(Data, oldLead),
    aiUsesFor = function(self)
      self.aiRefreshes = (self.aiRefreshes or 0) + 1
      return { species = self.enemy.mon.species }
    end,
  }
  local game = { data = Data, save = { pokedex = { seen = {} } } }
  T.eq(ex.syncRematchLead(game, battle, BattleState), true,
    case.evolved .. " replaces the stale active rematch battler")
  T.eq(battle.enemy.mon, evolvedLead,
    case.evolved .. " active battler owns the evolved party object")
  T.eq(battle.enemy.def, Data.pokemon[case.evolved],
    case.evolved .. " active battler owns the evolved species definition")
  T.eq(battle.enemy.name, Data.pokemon[case.evolved].name,
    case.evolved .. " HUD uses the evolved localized species name")
  T.eq(battle.enemy.spritePath:find((
      "assets/crystal_animated/front/normal/%d/001.png"):format(case.dex),
      1, true) ~= nil, true,
    case.evolved .. " uses the evolved front-sprite asset")
  T.eq(battle.enemy.animationDex, case.dex,
    case.evolved .. " animation state uses the evolved Pokédex id")
  T.eq(battle.enemy.animationFrames, case.frames,
    case.evolved .. " owns its complete authored animation sequence")
  local selected = assert(ex.crystalAnimation.selected[evolvedLead])
  ex.crystalAnimation.updateBattle(battle,
    ((selected.durations[1] or 100) + 1) / 1000)
  T.eq(battle.enemy.__ascendantCrystalAnimation.species, case.evolved,
    case.evolved .. " live animation state keeps the evolved identity")
  T.eq(battle.enemy.__ascendantCrystalAnimation.frame, 2,
    case.evolved .. " visibly advances beyond its first frame")
  T.eq(game.save.pokedex.seen[case.evolved], true,
    case.evolved .. " is marked seen when it becomes the visible lead")
  T.eq(battle.aiUses.species, case.evolved,
    case.evolved .. " refreshes trainer AI from the synchronized lead")
  local beforeNoop = rebuilt
  T.eq(ex.syncRematchLead(game, battle, BattleState), false,
    case.evolved .. " synchronized identity is idempotent")
  T.eq(rebuilt, beforeNoop,
    case.evolved .. " synchronized identity is not rebuilt twice")
end

-- Exercise the public engine constructor too; the path-aware fake above
-- exposes the selected asset for assertions, while this case proves the
-- production seam creates and animates a real BattleState battler.
do
  local EngineBattleState = require("src.battle.BattleState")
  local oldLead, evolvedLead = mon("MACHOP"), mon("MACHAMP")
  local battle = {
    data = Data, enemyIndex = 1, enemyParty = { evolvedLead },
    enemy = EngineBattleState.makeBattler(Data, oldLead, false),
    aiUsesFor = function() return { real = true } end,
  }
  local game = { data = Data, save = { pokedex = { seen = {} } } }
  T.eq(ex.syncRematchLead(game, battle, EngineBattleState), true,
    "the real engine BattleState rebuilds an evolved rematch lead")
  T.eq(battle.enemy.mon, evolvedLead,
    "the real engine battler owns Machamp rather than stale Machop")
  T.eq(battle.enemy.def, Data.pokemon.MACHAMP,
    "the real engine battler resolves Machamp's definition")
  T.eq(battle.enemy.name, "Localized Machamp",
    "the real engine HUD name resolves Machamp's localized definition")
  T.eq(ex.crystalAnimation.selected[evolvedLead].dex, 68,
    "the real engine sprite resolver selects Machamp's Crystal animation")
  local first = ex.crystalAnimation.selected[evolvedLead].durations[1]
  ex.crystalAnimation.updateBattle(battle, (first + 1) / 1000)
  T.eq(battle.enemy.__ascendantCrystalAnimation.frame, 2,
    "the real engine Machamp front sprite advances to frame two")
end

T.finish("rematch_evolved_battler_test")
