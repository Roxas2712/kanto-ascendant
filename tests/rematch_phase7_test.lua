package.path = "./?.lua;./?/init.lua;" .. package.path
local modPath = os.getenv("TRAINER_REMATCH_MOD_DIR") or "."

local assertions = 0
local function ok(value, message)
  assertions = assertions + 1
  assert(value, message)
end
local function eq(actual, expected, message)
  assertions = assertions + 1
  assert(actual == expected, (message or "values differ") .. ": "
    .. tostring(actual) .. " ~= " .. tostring(expected))
end

local Mastery = assert(loadfile(modPath .. "/rematch_mastery.lua"))().create({
  resonanceRules = {
    CLEFAIRY = { SHADOW_BALL = { source = "machine" } },
  },
})

local moves = {
  POUND = { id = "POUND", type = "NORMAL", power = 40, accuracy = 100, pp = 35 },
  BODY_SLAM = { id = "BODY_SLAM", type = "NORMAL", power = 85, accuracy = 100, pp = 15 },
  HYPER_BEAM = { id = "HYPER_BEAM", type = "NORMAL", power = 150, accuracy = 90, pp = 5 },
  THUNDERBOLT = { id = "THUNDERBOLT", type = "ELECTRIC", power = 95, accuracy = 100, pp = 15 },
  ICE_BEAM = { id = "ICE_BEAM", type = "ICE", power = 95, accuracy = 100, pp = 10 },
  PSYCHIC_M = { id = "PSYCHIC_M", type = "PSYCHIC_TYPE", power = 90, accuracy = 100, pp = 10 },
  MINIMIZE = { id = "MINIMIZE", type = "NORMAL", power = 0, accuracy = 100, pp = 20 },
  THUNDER_WAVE = { id = "THUNDER_WAVE", type = "ELECTRIC", power = 0, accuracy = 100, pp = 20 },
  RECOVER = { id = "RECOVER", type = "NORMAL", power = 0, accuracy = 100, pp = 20 },
  SHADOW_BALL = { id = "SHADOW_BALL", type = "GHOST", power = 80, accuracy = 100, pp = 15, category = "physical" },
  CRUNCH = { id = "CRUNCH", type = "DARK", power = 80, accuracy = 100, pp = 15, category = "special" },
  ROCK_SLIDE = { id = "ROCK_SLIDE", type = "ROCK", power = 75, accuracy = 90, pp = 10 },
  EARTHQUAKE = { id = "EARTHQUAKE", type = "GROUND", power = 100, accuracy = 100, pp = 10 },
}

local pokemon = {
  CLEFAIRY = {
    types = { "NORMAL" },
    baseStats = { hp = 70, attack = 45, defense = 48, speed = 35, special = 60 },
    level1Moves = { "POUND", "MINIMIZE" },
    learnset = { { level = 18, move = "THUNDER_WAVE" } },
    tmhm = { "BODY_SLAM", "HYPER_BEAM", "THUNDERBOLT", "ICE_BEAM", "PSYCHIC_M" },
  },
  TYRANITAR = {
    types = { "ROCK", "DARK" },
    baseStats = { hp = 100, attack = 134, defense = 110, speed = 61, special = 95 },
    level1Moves = { "CRUNCH" },
    learnset = {}, tmhm = { "ROCK_SLIDE", "EARTHQUAKE", "HYPER_BEAM" },
  },
  MEWTWO = {
    types = { "PSYCHIC_TYPE" },
    baseStats = { hp = 106, attack = 110, defense = 90, speed = 130, special = 154 },
    level1Moves = { "PSYCHIC_M", "RECOVER" },
    learnset = {}, tmhm = { "THUNDERBOLT", "ICE_BEAM" },
  },
}

local game = { data = { moves = moves, pokemon = pokemon } }
local Stats = {}
function Stats.calc(def, level, dvs, statExp)
  local base = def.baseStats
  local function value(stat)
    return math.floor((base[stat] or base.hp) + level
      + (dvs[stat] or 0) * 2 + math.sqrt(statExp[stat] or 0) / 8)
  end
  return {
    hp = value("hp") + 10, attack = value("attack"),
    defense = value("defense"), speed = value("speed"),
    special = value("special"),
  }
end

local function mon(species, level, moveIds)
  local out = {
    species = species, level = level,
    dvs = { hp = 0, attack = 8, defense = 8, speed = 8, special = 8 },
    statExp = { hp = 0, attack = 0, defense = 0, speed = 0, special = 0 },
    moves = {}, stats = {},
  }
  for _, id in ipairs(moveIds or {}) do
    out.moves[#out.moves + 1] = { id = id, pp = moves[id].pp }
  end
  return out
end

local function apply(species, level, moveIds, context)
  local battle = { enemyParty = { mon(species, level, moveIds) } }
  local merged = { Stats = Stats, key = context.key or "route-test",
    kind = context.kind or "field", progress = context.progress or 0,
    masteryWins = context.masteryWins or 0,
    johtoUnlocked = context.johtoUnlocked == true,
    specialist = context.specialist, champion = context.champion }
  local report = Mastery.apply(game, battle, merged)
  return battle.enemyParty[1], report, battle
end

local early, earlyReport = apply("CLEFAIRY", 20,
  { "POUND", "MINIMIZE" }, { progress = 0 })
local middle, middleReport = apply("CLEFAIRY", 65,
  { "POUND", "MINIMIZE" }, { progress = 10 })
local cap, capReport = apply("CLEFAIRY", 100,
  { "POUND", "MINIMIZE" }, { progress = 40, masteryWins = 0 })
local post, postReport = apply("CLEFAIRY", 100,
  { "POUND", "MINIMIZE" }, { progress = 44, masteryWins = 4 })
local long, longReport, longBattle = apply("CLEFAIRY", 101,
  { "POUND", "MINIMIZE" }, { progress = 60, masteryWins = 12 })

eq(long.level, 100, "level 100 remains the absolute hard cap")
ok(earlyReport.party[1].quality < middleReport.party[1].quality,
  "early to middle stat quality trends upward")
ok(middleReport.party[1].quality < capReport.party[1].quality,
  "middle progression reaches the first level-100 quality band")
ok(capReport.party[1].quality >= .70 and capReport.party[1].quality <= .80,
  "first level-100 team stays in the 70-80 percent band")
ok(postReport.party[1].quality >= .80 and postReport.party[1].quality <= .90,
  "intermediate post-100 team stays in the 80-90 percent band")
ok(longReport.party[1].quality >= .90 and longReport.party[1].quality <= 1,
  "long-term post-100 team reaches the 90-100 percent band")
ok(cap.stats.attack < post.stats.attack and post.stats.attack < long.stats.attack,
  "real calculated stats improve after level 100")
eq(Mastery.inspect(longBattle).party[1].tier, "perfect",
  "debug inspection exposes the mastery tier")

for _, candidate in ipairs({ early, middle, cap, post, long }) do
  for _, stat in ipairs({ "attack", "defense", "speed", "special" }) do
    ok(candidate.dvs[stat] >= 0 and candidate.dvs[stat] <= 15
      and candidate.dvs[stat] == math.floor(candidate.dvs[stat]),
      "DVs stay legal integers")
  end
  for _, stat in ipairs({ "hp", "attack", "defense", "speed", "special" }) do
    ok(candidate.statExp[stat] >= 0 and candidate.statExp[stat] <= 65535
      and candidate.statExp[stat] == math.floor(candidate.statExp[stat]),
      "stat EXP stays legal integers")
    ok(candidate.stats[stat] >= 1
      and candidate.stats[stat] == math.floor(candidate.stats[stat]),
      "calculated stats stay positive integers")
  end
end

local foundMinimize, damagingTypes = false, {}
for _, move in ipairs(long.moves) do
  foundMinimize = foundMinimize or move.id == "MINIMIZE"
  if moves[move.id].power > 0 then damagingTypes[moves[move.id].type] = true end
end
ok(foundMinimize, "Clefairy retains its authored Minimize tactic")
local coverage = 0
for _ in pairs(damagingTypes) do coverage = coverage + 1 end
ok(coverage >= 2, "moveset scoring retains meaningful type coverage")
ok(#long.moves <= 4, "moveset never exceeds four legal moves")

local locked = Mastery.legalMoves(game, mon("CLEFAIRY", 100,
  { "POUND", "MINIMIZE" }), { johtoUnlocked = false })
eq(locked.SHADOW_BALL, nil, "Johto move cannot leak before Driftglass unlock")
local unlocked = Mastery.legalMoves(game, mon("CLEFAIRY", 100,
  { "POUND", "MINIMIZE" }), { johtoUnlocked = true })
eq(unlocked.SHADOW_BALL, true,
  "legal Kanto resonance move appears after Driftglass unlock")
local scrubbed = apply("CLEFAIRY", 100,
  { "SHADOW_BALL", "MINIMIZE" },
  { progress = 50, masteryWins = 10, johtoUnlocked = false })
local leaked = false
for _, move in ipairs(scrubbed.moves) do
  if move.id == "SHADOW_BALL" then leaked = true end
end
eq(leaked, false,
  "an authored Johto move is also scrubbed before the existing unlock")

local elite, eliteReport = apply("TYRANITAR", 100,
  { "CRUNCH", "ROCK_SLIDE", "EARTHQUAKE", "HYPER_BEAM" },
  { key = "OPP_LANCE", kind = "elite", progress = 7,
    masteryWins = 7, specialist = true, johtoUnlocked = true })
local champion, championReport = apply("MEWTWO", 100,
  { "PSYCHIC_M", "RECOVER", "THUNDERBOLT", "ICE_BEAM" },
  { key = "OPP_RIVAL3", kind = "elite", progress = 12,
    masteryWins = 12, specialist = true, champion = true,
    johtoUnlocked = true })
ok(eliteReport.party[1].quality >= .875,
  "Elite Four repeat uses the specialist post-100 band")
ok(championReport.party[1].quality >= .95,
  "Champion repeat can approach perfect stat quality")
eq(elite.level, 100, "Elite Four does not exceed level 100")
eq(champion.level, 100, "Champion does not exceed level 100")

print(("REMATCH PHASE 7 PASS: %d assertions"):format(assertions))
