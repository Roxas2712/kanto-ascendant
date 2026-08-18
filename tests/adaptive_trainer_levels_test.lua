package.path = "./?.lua;./?/init.lua;" .. package.path

local root = os.getenv("TRAINER_REMATCH_MOD_DIR") or "."
local checks = 0
local function eq(actual, expected, message)
  checks = checks + 1
  assert(actual == expected, (message or "values differ") .. ": "
    .. tostring(actual) .. " ~= " .. tostring(expected))
end
local function ok(value, message)
  checks = checks + 1
  assert(value, message)
end

local bucket, optionValues, listeners = {}, {
  difficulty = "standard",
  adaptive_trainer_levels = "auto",
}, {}
local mod = {
  options = { get = function(_, key) return optionValues[key] end },
  save = {
    get = function(_, key, default)
      local value = bucket[key]
      return value == nil and default or value
    end,
    set = function(_, key, value) bucket[key] = value end,
  },
  events = { on = function(_, name, fn, priority)
    listeners[name] = { fn = fn, priority = priority }
  end },
}
local difficulty = {
  progressionBonus = function(_, badges, name)
    local base = ({ standard = 0, high = 1, hard = 2,
      very_hard = 3, extreme = 4 })[name] or 0
    return base + (badges == 8 and 1 or 0)
  end,
}
local adaptive = assert(loadfile(root .. "/adaptive_trainer_levels.lua"))()(mod, {
  difficulty = difficulty,
  growMon = function(_, mon, target)
    mon.level = target
    mon.exp = target * 100
    mon.stats = { hp = target * 2, attack = target }
    mon.hp = mon.stats.hp
  end,
})

-- AUTO is deliberately independent from the fixed authored Difficulty floor.
eq(adaptive.effectiveGap("auto", "standard"), nil,
  "AUTO is classic on Standard")
eq(adaptive.effectiveGap("auto", "high"), 1, "AUTO High gap")
eq(adaptive.effectiveGap("auto", "hard"), 2, "AUTO Hard gap")
eq(adaptive.effectiveGap("auto", "very_hard"), 3,
  "AUTO Very Hard gap")
eq(adaptive.effectiveGap("auto", "extreme"), 4,
  "AUTO Extreme gap")
eq(adaptive.effectiveGap("-2", "extreme"), -2,
  "manual gap never follows Difficulty")
eq(adaptive.effectiveGap("0", "extreme"), 0, "MATCH is an active gap")
eq(adaptive.effectiveGap("off", "extreme"), nil, "OFF is classic")

-- Eggs do not represent a usable battler; fainted team members still do.
local reference, detail = adaptive.playerReference({
  { species = "A", level = 50, hp = 0 },
  { species = "B", level = 10, hp = 10 },
  { species = "C", level = 10, hp = 10 },
  { species = "EGG", level = 100, isEgg = true },
  { level = 100 },
})
eq(reference, 23, "player reference is the rounded arithmetic team mean")
eq(detail.mean, 23, "party arithmetic mean rounds to nearest level")
eq(detail.highest, 50, "highest usable party member is recorded")
eq(detail.count, 3, "fainted members count and eggs do not")
local registryReference, registryDetail = adaptive.playerReference({
  { species = "A", level = 20 },
  { species = "MISSING", level = 100 },
}, { A = {} })
eq(registryReference, 20, "unregistered party species do not enter the mean")
eq(registryDetail.count, 1, "registry validation reports only usable battlers")

local raw = {
  { species = "A", level = 10 },
  { species = "B", level = 14 },
  { species = "C", level = 18, recruited = true },
}
local party = {
  { species = "A", level = 30 },
  { species = "B", level = 30 },
  { species = "C", level = 30 },
}

-- Classic/OFF is the exact current constructor path: original slots receive
-- authored + Difficulty + B, while appended recruits retain the historical
-- authored + B behavior. Adaptive fixes that asymmetry only while enabled.
local classic, classicReport = adaptive.planRematch(raw, party, {
  selection = "off", difficultyName = "hard", badges = 0, classicBoost = 8,
  originalCount = 2,
})
eq(classic[1].level, 20, "classic original gets D+B")
eq(classic[3].level, 26, "classic recruit keeps exact legacy B-only level")
eq(classicReport.mode, "classic", "OFF report is explicit")

-- Adaptive uses the authored + Difficulty team as a floor, discards numeric
-- B only, preserves internal level spacing, and freezes one shared preview /
-- battle plan. Here the D-adjusted mean is 16 and P+2 is 32, so shift=16.
local planned, report = adaptive.planRematch(raw, party, {
  selection = "2", difficultyName = "hard", badges = 0, classicBoost = 80,
  originalCount = 2,
})
eq(planned[1].level, 28, "adaptive floor receives one shared shift")
eq(planned[2].level, 32, "authored internal spacing is preserved")
eq(planned[3].level, 36, "recruits use the same frozen target plan")
eq(report.playerReference, 30, "report exposes player reference")
eq(report.targetMean, 32, "report exposes requested target mean")
eq(report.shift, 16, "report exposes shared non-negative shift")
eq(report.classicBoostSuppressed, 80,
  "numeric rematch B is explicitly suppressed only in adaptive mode")

-- An authored floor may be stronger than the adaptive target; it is never
-- reduced. This protects bosses and authored difficulty expectations.
local floorPlan, floorReport = adaptive.planRematch({
  { species = "A", level = 44 }, { species = "B", level = 48 },
}, { { species = "A", level = 30 } }, {
  selection = "-2", difficultyName = "standard", badges = 0,
  classicBoost = 99, originalCount = 2,
})
eq(floorPlan[1].level, 44, "adaptive never lowers authored floor")
eq(floorReport.shift, 0, "strong authored team needs no shift")

local cappedPlan, cappedReport = adaptive.planAdjusted({
  { species = "A", level = 20 }, { species = "B", level = 24 },
}, { { species = "A", level = 80 } }, {
  selection = "8", difficultyName = "extreme", maxLevel = 25,
})
eq(cappedPlan[1].level, 25, "optional story ceiling caps adaptive growth")
eq(cappedPlan[2].level, 25, "ceiling applies to every raised Gym slot")
eq(cappedReport.levelCeiling, 25, "planner reports the story ceiling")

-- Invalid active contexts return no plan at all. Callers can therefore run
-- the untouched classic path without any partial adaptive mutation.
local invalid, why = adaptive.planRematch(raw, {}, {
  selection = "4", difficultyName = "hard", badges = 0, classicBoost = 8,
  originalCount = 2,
})
eq(invalid, nil, "empty player party fails closed")
eq(why.reason, "invalid_player_party", "fallback reason is inspectable")
eq(adaptive.planRematch({ { species = "A", level = "bad" } }, party, {
  selection = "off", difficultyName = "hard", badges = 0, classicBoost = 8,
  originalCount = 1,
}), nil, "invalid authored rows fail closed even while OFF")

-- Applying targets is transactional. An adapter error restores every mon,
-- including the one already grown before the error.
local battle = { kind = "trainer", enemyParty = {
  { species = "A", level = 10, exp = 10, hp = 10, stats = { hp = 10 } },
  { species = "B", level = 12, exp = 12, hp = 12, stats = { hp = 12 } },
} }
ok(adaptive.applyBattleTargets({}, battle, {
  { species = "A", level = 20 }, { species = "B", level = 22 },
}), "valid frozen targets apply")
eq(battle.enemyParty[1].level, 20, "first exact target applied")
eq(battle.enemyParty[2].level, 22, "second exact target applied")
local remapped = { enemyParty = {
  { species = "RANDOMIZED_A", level = 10, stats = { hp = 10 }, hp = 10 },
  { species = "RANDOMIZED_B", level = 12, stats = { hp = 12 }, hp = 12 },
} }
eq(adaptive.applyBattleTargets({}, remapped, {
  { species = "A", level = 20 }, { species = "B", level = 22 },
}), false, "species remaps fail closed unless the caller owns that seam")
ok(adaptive.applyBattleTargets({}, remapped, {
  { species = "A", level = 20 }, { species = "B", level = 22 },
}, { allowSpeciesRemap = true }),
  "explicit slot ownership composes with a species-only Randomizer")
eq(remapped.enemyParty[1].species, "RANDOMIZED_A",
  "adaptive slot targets never replace Randomizer species")
eq(remapped.enemyParty[1].level, 20,
  "Randomizer composition receives the exact frozen preview level")

-- Regression: Gen-I Day Care learning can shift the only damaging move out
-- when a trainer is raised across several status-move levels (Butterfree is
-- the real report). A scaled trainer must keep one legal damaging move from
-- its pre-growth/level/TM pool; an unscaled authored set is never rewritten.
do
  local Data = require("tests.modkit").fixtures.load()
  for index = 1, 4 do
    local id = "FIX_STATUS_" .. index
    Data.moves[id] = { id = id, index = 200 + index, name = id,
      type = "NORMAL", power = 0, accuracy = 100, pp = 20,
      effect = "NO_ADDITIONAL_EFFECT" }
  end
  local species = Data.pokemon.FIXMON_A
  species.learnset = {
    { level = 6, move = "FIX_STATUS_1" },
    { level = 7, move = "FIX_STATUS_2" },
    { level = 8, move = "FIX_STATUS_3" },
    { level = 9, move = "FIX_STATUS_4" },
  }
  local Pokemon = require("src.pokemon.Pokemon")
  local scaled = Pokemon.new(Data, "FIXMON_A", 5, function() return 8 end)
  local unchanged = Pokemon.new(Data, "FIXMON_A", 5, function() return 8 end)
  local realGrowth = assert(loadfile(root .. "/adaptive_trainer_levels.lua"))()({
    options = mod.options, save = mod.save,
    events = { on = function() end },
  }, { difficulty = difficulty })
  ok(realGrowth.applyBattleTargets({ data = Data }, {
    enemyParty = { scaled },
  }, { { species = "FIXMON_A", level = 9 } }),
    "real adaptive growth reaches the status-move regression level")
  local damaging = false
  for _, move in ipairs(scaled.moves) do
    if tonumber(Data.moves[move.id] and Data.moves[move.id].power) > 0 then
      damaging = true
    end
  end
  eq(damaging, true,
    "scaled trainer retains at least one legal damaging move")
  ok(realGrowth.applyBattleTargets({ data = Data }, {
    enemyParty = { unchanged },
  }, { { species = "FIXMON_A", level = 5 } }),
    "an unchanged authored target is accepted")
  eq(unchanged.moves[1].id, "FIX_TACKLE",
    "unscaled authored moves are byte-for-byte untouched")
  local fixedCases = {
    SONICBOOM = "SPECIAL_DAMAGE_EFFECT",
    DRAGON_RAGE = "SPECIAL_DAMAGE_EFFECT",
    SEISMIC_TOSS = "SPECIAL_DAMAGE_EFFECT",
    NIGHT_SHADE = "SPECIAL_DAMAGE_EFFECT",
    SUPER_FANG = "SUPER_FANG_EFFECT",
    FISSURE = "OHKO_EFFECT",
  }
  for id, effect in pairs(fixedCases) do
    Data.moves[id] = { id = id, index = 299,
      name = id, type = "NORMAL", power = 0, accuracy = 100,
      pp = 20, effect = effect }
    local fixedOnly = { moves = { { id = id, pp = 20 } } }
    eq(realGrowth.hasDamagingMove(Data, fixedOnly.moves), true,
      id .. " counts as a legal damaging move through " .. effect)
    ok(realGrowth.ensureDamagingMove(
      Data, fixedOnly, species, fixedOnly.moves, 9),
      id .. "-only set needs no fallback")
    eq(#fixedOnly.moves, 1,
      id .. "-only set does not receive an unnecessary TM move")
    eq(fixedOnly.moves[1].id, id,
      id .. "-only authored move remains unchanged")
  end
end

local failingMod = {
  options = mod.options, save = mod.save,
  events = { on = function() end },
}
local failing = assert(loadfile(root .. "/adaptive_trainer_levels.lua"))()(failingMod, {
  difficulty = difficulty,
  growMon = function(_, mon, target)
    if mon.species == "B" then error("synthetic growth failure") end
    mon.level = target
  end,
})
battle.enemyParty[1].level, battle.enemyParty[2].level = 20, 22
local applied = failing.applyBattleTargets({}, battle, {
  { species = "A", level = 30 }, { species = "B", level = 32 },
})
eq(applied, false, "growth exception fails closed")
eq(battle.enemyParty[1].level, 20, "transaction rolls first mon back")
eq(battle.enemyParty[2].level, 22, "transaction keeps second mon unchanged")

-- Save lifecycle: new saves get AUTO. Existing slots without a marker are
-- held on classic until the player explicitly chooses Adaptive or reselects
-- Difficulty. A later Difficulty change never overwrites a manual gap.
ok(listeners["save.created"] and listeners["save.loaded"]
  and listeners["mod.options_changed"], "lifecycle handlers are installed")
bucket = {}
listeners["save.created"].fn({ save = {} })
eq(bucket[adaptive.STATE_KEY].legacyHold, false,
  "fresh save is not held on classic")
bucket = {}
listeners["save.loaded"].fn({ save = {} })
eq(bucket[adaptive.STATE_KEY].legacyHold, true,
  "existing unmarked slot is held on classic")
eq(adaptive.currentGap(), nil, "legacy hold makes visible AUTO effective OFF")
local legacyBucket = bucket
bucket = {}
listeners["save.created"].fn({ save = {} })
eq(bucket[adaptive.STATE_KEY].legacyHold, false,
  "a new slot after Continue never inherits the old slot's hold")
bucket = legacyBucket
optionValues.difficulty = "hard"
listeners["mod.options_changed"].fn({ key = "difficulty", value = "hard" })
eq(bucket[adaptive.STATE_KEY].legacyHold, false,
  "reselecting Difficulty releases an untouched legacy AUTO hold")
eq(adaptive.currentGap(), 2, "released AUTO follows current Difficulty")
optionValues.adaptive_trainer_levels = "6"
listeners["mod.options_changed"].fn({ key = "adaptive_trainer_levels",
  value = "6" })
optionValues.difficulty = "extreme"
listeners["mod.options_changed"].fn({ key = "difficulty", value = "extreme" })
eq(adaptive.currentGap(), 6,
  "Difficulty change never overwrites a manual adaptive gap")

-- Story application waits until lower-priority postgame marker handlers have
-- run, requires a matching frozen difficulty context, and excludes every
-- fixed/facility/Legacy lane fail-closed.
eq(listeners["battle.started"].priority, -100,
  "story adaptation runs after priority-zero exclusion markers")
optionValues.adaptive_trainer_levels = "4"
local story = { kind = "trainer", game = { save = { party = {
  { species = "A", level = 20 }, { species = "B", level = 20 },
} } }, enemyParty = {
  { species = "A", level = 8, exp = 8, hp = 8, stats = { hp = 8 } },
  { species = "B", level = 12, exp = 12, hp = 12, stats = { hp = 12 } },
}, ascendantDifficultyContext = { adjustedParty = {
  { species = "A", level = 8 }, { species = "B", level = 12 },
}, difficulty = "standard" } }
listeners["battle.started"].fn({ battle = story })
eq(story.enemyParty[1].level, 22, "story uses authored+D floor plus shift")
eq(story.enemyParty[2].level, 26, "story preserves authored spacing")
eq(story.ascendantAdaptiveTrainerLevels.mode, "adaptive",
  "story battle records its frozen adaptive report")

local excluded = { kind = "trainer", ascendantForcedBattle = true,
  game = story.game, enemyParty = {
    { species = "A", level = 8, stats = { hp = 8 }, hp = 8 },
  }, ascendantDifficultyContext = { adjustedParty = {
    { species = "A", level = 8 },
  }, difficulty = "standard" } }
listeners["battle.started"].fn({ battle = excluded })
eq(excluded.enemyParty[1].level, 8, "fixed postgame battle is excluded")
eq(excluded.ascendantAdaptiveTrainerLevels, nil,
  "excluded lane receives no adaptive claim")

local gymListeners, preserved = {}, false
local gymMod = {
  id = "kanto_ascendant", options = mod.options, save = mod.save,
  events = { on = function(_, name, fn) gymListeners[name] = fn end },
}
local gymAdaptive = assert(loadfile(root .. "/adaptive_trainer_levels.lua"))()(
  gymMod, { difficulty = difficulty,
    growMon = function(_, mon, target, context)
      preserved = context and context.preserveAuthoredMoves == true
      mon.level = target
      if not preserved then mon.moves = { { id = "LEVEL_MOVE" } } end
    end,
  })
local gym = { kind = "trainer", ascendantStoryGymDifficulty = {},
  ascendantStoryLevelCeiling = 25,
  game = { save = { party = { { species = "A", level = 40 } } } },
  enemyParty = { { species = "A", level = 20,
    moves = { { id = "CURATED_MOVE" } }, stats = { hp = 20 }, hp = 20 } },
  ascendantDifficultyContext = { difficulty = "standard",
    adjustedParty = { { species = "A", level = 20 } } },
}
local gymApplied = gymAdaptive.applyStoryBattle(gym)
eq(gymApplied, true, "explicit story Gym lane composes with adaptive API")
eq(preserved, true, "story Gym requests authored moveset preservation")
eq(gym.enemyParty[1].moves[1].id, "CURATED_MOVE",
  "adaptive Gym growth does not replace curated moves")
eq(gym.enemyParty[1].level, 25,
  "story Gym adaptive target honors the authored ceiling")

print(("adaptive_trainer_levels_test: PASS (%d checks)"):format(checks))
