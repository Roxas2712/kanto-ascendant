-- Focused Rematch 2.0 Phase-6 progression matrix.
local modPath = os.getenv("TRAINER_REMATCH_MOD_DIR") or "mods/kanto_ascendant"
local R = assert(loadfile(modPath .. "/trainer_recruits.lua"))()
local checks = 0

local function check(value, message)
  checks = checks + 1
  assert(value, message)
end

local function same(actual, expected, message)
  checks = checks + 1
  assert(#actual == #expected, message .. " (length)")
  for i = 1, #expected do
    assert(actual[i] == expected[i],
      message .. " (index " .. i .. ": " .. tostring(actual[i])
        .. " ~= " .. tostring(expected[i]) .. ")")
  end
end

local function mon(id, dex, types, evolutions)
  return { id = id, name = id, dex = dex, index = dex, types = types,
    evolutions = evolutions or {} }
end

local function level(species, at)
  return { method = "LEVEL", species = species, level = at }
end

local function item(species, id)
  return { method = "ITEM", species = species, item = id }
end

local data = { pokemon = {
  RATTATA = mon("RATTATA", 19, { "NORMAL" }, { level("RATICATE", 20) }),
  RATICATE = mon("RATICATE", 20, { "NORMAL" }),
  CATERPIE = mon("CATERPIE", 10, { "BUG" }, { level("METAPOD", 7) }),
  METAPOD = mon("METAPOD", 11, { "BUG" }, { level("BUTTERFREE", 10) }),
  BUTTERFREE = mon("BUTTERFREE", 12, { "BUG", "FLYING" }),
  WEEDLE = mon("WEEDLE", 13, { "BUG", "POISON" }, { level("KAKUNA", 7) }),
  KAKUNA = mon("KAKUNA", 14, { "BUG", "POISON" }, { level("BEEDRILL", 10) }),
  BEEDRILL = mon("BEEDRILL", 15, { "BUG", "POISON" }),
  POLIWHIRL = mon("POLIWHIRL", 61, { "WATER" }, {
    item("POLIWRATH", "WATER_STONE"), item("POLITOED", "KINGS_ROCK"),
  }),
  POLIWRATH = mon("POLIWRATH", 62, { "WATER", "FIGHTING" }),
  POLITOED = mon("POLITOED", 186, { "WATER" }),
  RAICHU = mon("RAICHU", 26, { "ELECTRIC" }, {
    item("GOROCHU", "THUNDER_TEAR"),
  }),
  GOROCHU = mon("GOROCHU", 1026, { "ELECTRIC", "FIRE" }),
  GEODUDE = mon("GEODUDE", 74, { "ROCK", "GROUND" }),
  GOLDEEN = mon("GOLDEEN", 118, { "WATER" }),
  ABRA = mon("ABRA", 63, { "PSYCHIC_TYPE" }),
  SPINARAK = mon("SPINARAK", 167, { "BUG", "POISON" }, {
    level("ARIADOS", 22),
  }),
  ARIADOS = mon("ARIADOS", 168, { "BUG", "POISON" }),
  CHINCHOU = mon("CHINCHOU", 170, { "WATER", "ELECTRIC" }),
  NATU = mon("NATU", 177, { "PSYCHIC_TYPE", "FLYING" }),
  MAREEP = mon("MAREEP", 179, { "ELECTRIC" }),
  PHANPY = mon("PHANPY", 231, { "GROUND" }),
  REMORAID = mon("REMORAID", 223, { "WATER" }),
} }

-- Exact target tables.
same(R.stageWeights(1, 1), { 50, 50 }, "two-stage rematch 1")
same(R.stageWeights(2, 1), { 40, 60 }, "two-stage rematch 2")
same(R.stageWeights(3, 1), { 30, 70 }, "two-stage rematch 3")
same(R.stageWeights(4, 1), { 20, 80 }, "two-stage rematch 4")
same(R.stageWeights(99, 1), { 10, 90 }, "two-stage rematch 5+")
local three = {
  { 50, 30, 20 }, { 40, 30, 30 }, { 30, 30, 40 },
  { 20, 30, 50 }, { 10, 25, 65 }, { 5, 20, 75 }, { 5, 10, 85 },
}
for rematch, expected in ipairs(three) do
  same(R.stageWeights(rematch, 2), expected,
    "three-stage rematch " .. rematch)
end
same(R.stageWeights(99, 2), { 5, 10, 85 }, "three-stage rematch 7+")

local unlocked = {}
local function isUnlocked(species) return unlocked[species] == true end
R.configureJohto({}, isUnlocked)
R.configureEvolutionAvailability(function(target)
  return unlocked[target] == true
end)

local function sequence(...)
  local values, index = { ... }, 0
  return function(lo, hi)
    index = index + 1
    local value = values[index] or values[#values] or lo
    return math.max(lo, math.min(hi, value))
  end
end

local function evolve(species, levelValue, rematch, roll, state)
  state = state or {}
  local team, update = R.expand(data, {
    { species = species, level = levelValue },
  }, "OPP_TEST", "TRAINER_A", rematch - 1, 0, false, {
    rematchNumber = rematch, random = sequence(roll, 1),
    originalStages = state.originalStages,
    originalBranches = state.originalBranches,
  })
  return team[1].species, update
end

-- Level gates override a high evolution roll.
check(evolve("RATTATA", 5, 1, 100) == "RATTATA",
  "level gate allowed an absurd early Raticate")
check(evolve("RATTATA", 20, 1, 50) == "RATTATA",
  "two-stage 50% base boundary changed")
check(evolve("RATTATA", 20, 1, 51) == "RATICATE",
  "two-stage final half did not evolve")

check(evolve("WEEDLE", 20, 1, 50) == "WEEDLE",
  "three-stage base boundary changed")
check(evolve("WEEDLE", 20, 1, 51) == "KAKUNA",
  "three-stage middle bucket failed")
check(evolve("WEEDLE", 20, 1, 81) == "BEEDRILL",
  "three-stage final bucket failed")
check(evolve("WEEDLE", 20, 7, 5) == "WEEDLE",
  "rematch-7 base boundary changed")
check(evolve("WEEDLE", 20, 7, 6) == "KAKUNA",
  "rematch-7 middle bucket failed")
check(evolve("WEEDLE", 20, 7, 16) == "BEEDRILL",
  "rematch-7 final bucket failed")

-- Exhaust every integer roll, proving the implemented outcome counts match
-- the design rather than merely checking a few boundaries.
for rematch = 1, 5 do
  local counts = { RATTATA = 0, RATICATE = 0 }
  for roll = 1, 100 do
    local species = evolve("RATTATA", 60, rematch, roll)
    counts[species] = counts[species] + 1
  end
  local expected = R.stageWeights(rematch, 1)
  check(counts.RATTATA == expected[1] and counts.RATICATE == expected[2],
    "two-stage exhaustive distribution differs at rematch " .. rematch)
end
for rematch = 1, 7 do
  local counts = { WEEDLE = 0, KAKUNA = 0, BEEDRILL = 0 }
  for roll = 1, 100 do
    local species = evolve("WEEDLE", 60, rematch, roll)
    counts[species] = counts[species] + 1
  end
  local expected = R.stageWeights(rematch, 2)
  check(counts.WEEDLE == expected[1] and counts.KAKUNA == expected[2]
      and counts.BEEDRILL == expected[3],
    "three-stage exhaustive distribution differs at rematch " .. rematch)
end

-- Won evolution progress is monotonic across reloads.
local persistent = {}
local finalSpecies, finalUpdate = evolve("WEEDLE", 20, 1, 100, persistent)
check(finalSpecies == "BEEDRILL", "fixture did not reach final stage")
R.commit(persistent, finalUpdate, true)
local afterReload = evolve("WEEDLE", 20, 2, 1, persistent)
check(afterReload == "BEEDRILL", "persisted trainer de-evolved after reload")

-- Generic branch selection can reach both registered final branches.
unlocked.POLITOED = true
local branchA = R.expand(data, { { species = "POLIWHIRL", level = 60 } },
  "OPP_SWIMMER", "BRANCH_A", 0, 0, false, {
    rematchNumber = 1, random = sequence(100, 1),
  })
local branchB = R.expand(data, { { species = "POLIWHIRL", level = 60 } },
  "OPP_SWIMMER", "BRANCH_B", 0, 0, false, {
    rematchNumber = 1, random = sequence(100, 2),
  })
check(branchA[1].species ~= branchB[1].species,
  "registered branched evolution produced only one outcome")
check((branchA[1].species == "POLITOED" or branchA[1].species == "POLIWRATH")
    and (branchB[1].species == "POLITOED" or branchB[1].species == "POLIWRATH"),
  "branched evolution left the registered family")

-- Custom branches use the same registry path but remain gated.
unlocked.GOROCHU = nil
check(evolve("RAICHU", 60, 5, 100) == "RAICHU",
  "Gorochu leaked before its Ascendant unlock")
unlocked.GOROCHU = true
check(evolve("RAICHU", 60, 5, 100) == "GOROCHU",
  "unlocked custom branch did not use the generic evolution graph")

-- Johto class pools are absent before release and appear after release.
unlocked.SPINARAK, unlocked.ARIADOS = nil, nil
local lockedTeam = R.expand(data, { { species = "WEEDLE", level = 30 } },
  "OPP_BUG_CATCHER", "BUG_LOCKED", 1, 20, true, {
    rematchNumber = 2, random = sequence(100, 100, 100), recentHistory = {},
  })
for _, slot in ipairs(lockedTeam) do
  check((data.pokemon[slot.species].dex or 0) <= 151,
    "Johto species leaked into a locked Bug Catcher pool")
end
unlocked.SPINARAK, unlocked.ARIADOS = true, true
local openTeam = R.expand(data, { { species = "WEEDLE", level = 30 } },
  "OPP_BUG_CATCHER", "BUG_OPEN", 1, 20, true, {
    rematchNumber = 2, random = sequence(100, 200), recentHistory = {},
  })
local foundJohtoBug = false
for _, slot in ipairs(openTeam) do
  if slot.species == "SPINARAK" or slot.species == "ARIADOS" then
    foundJohtoBug = true
  end
end
local openIds = {}
for _, slot in ipairs(openTeam) do openIds[#openIds + 1] = slot.species end
check(foundJohtoBug, "released Johto Bug family did not enter Bug Catcher pool: "
  .. table.concat(openIds, ","))

-- The required archetypes discover registry families from types, not a
-- species-by-species class list.
for _, species in ipairs({ "CHINCHOU", "NATU", "PHANPY", "REMORAID" }) do
  unlocked[species] = true
end
local archetypes = {
  { "OPP_SWIMMER", "CHINCHOU", "GOLDEEN" },
  { "OPP_FISHER", "REMORAID", "GOLDEEN" },
  { "OPP_HIKER", "PHANPY", "GEODUDE" },
  { "OPP_PSYCHIC_TR", "NATU", "ABRA" },
}
for _, row in ipairs(archetypes) do
  local candidates = R.eligibleJohtoFamilies(data,
    { { species = row[3], level = 50 } }, row[1])
  local found = false
  for _, species in ipairs(candidates) do
    if species == row[2] then found = true break end
  end
  check(found, row[1] .. " did not discover thematic " .. row[2])
end

-- Previous use is strongly reduced; two consecutive uses are excluded. A
-- one-family exhausted pool still relaxes safely instead of looping.
check(R.recentPenalty("ARIADOS", { { "ARIADOS" } }) == 10,
  "previous-rematch species was not strongly reduced")
check(R.recentPenalty("ARIADOS", { { "ARIADOS" }, { "ARIADOS" } }) == 0,
  "twice-consecutive species was not excluded")
local antiRepeat = R.expand(data, { { species = "WEEDLE", level = 30 } },
  "OPP_BUG_CATCHER", "BUG_HISTORY", 1, 20, true, {
    rematchNumber = 2, random = sequence(100, 100, 100),
    recentHistory = { { "ARIADOS" }, { "ARIADOS" } },
  })
check(antiRepeat[2] and antiRepeat[2].species ~= "ARIADOS",
  "anti-repeat reused a twice-consecutive additional species")

local tiny = { pokemon = {
  RATTATA = data.pokemon.RATTATA, RATICATE = data.pokemon.RATICATE,
  CATERPIE = data.pokemon.CATERPIE, METAPOD = data.pokemon.METAPOD,
  BUTTERFREE = data.pokemon.BUTTERFREE,
} }
R.configureJohto({}, function() return false end)
local exhausted = R.expand(tiny, { { species = "RATTATA", level = 40 } },
  "OPP_BUG_CATCHER", "TINY_POOL", 1, 20, true, {
    rematchNumber = 2, random = sequence(100, 100),
    recentHistory = { { "BUTTERFREE" }, { "BUTTERFREE" } },
  })
check(exhausted[2] and exhausted[2].species == "BUTTERFREE",
  "pool exhaustion did not relax to the only legal family")

print(("%d Rematch Phase-6 progression checks passed"):format(checks))
