-- Focused regression coverage for Espeon's canonical Crystal learnset and
-- Kanto Ascendant's real Route 5 Move Reminder eligibility seam.
--
-- Run from the Gen1 Recomp checkout:
--   ./.tools/luajit-src/src/luajit \
--     ../.worktrees/ka-6.5-rc11-integration/tests/espeon_psybeam_regression_test.lua

local source = debug.getinfo(1, "S").source
local testDir = source:sub(1, 1) == "@"
  and source:sub(2):match("^(.*)/[^/]+$") or "tests"
local root = testDir:match("^(.*)/tests$") or "."

local canonical = assert(loadfile(root .. "/crystal_learnsets.lua"))()
local compat = assert(loadfile(root .. "/crystal_learnset_compat.lua"))()
local johto = assert(loadfile(root .. "/johto_data.lua"))()

local assertions = 0
local function equal(actual, expected, message)
  assertions = assertions + 1
  assert(actual == expected, (message or "values differ") .. ": "
    .. tostring(actual) .. " ~= " .. tostring(expected))
end

local knownMoves = {}
for species, rows in pairs(canonical) do
  if species ~= "_meta" then
    for _, row in ipairs(rows) do knownMoves[row.move] = true end
  end
end
local function hasMove(id) return knownMoves[id] == true end

-- Reproduce the faulty pre-fix schedule: PSYBEAM is absent and PSYCHIC is
-- incorrectly placed at level 30. The compatibility boundary must replace
-- canonical-owned rows rather than retain the bad level as an extension.
local schedule = compat.compile({
  level1Moves = { "TACKLE", "TAIL_WHIP", "SAND_ATTACK" },
  learnset = {
    { level = 8, move = "CONFUSION" },
    { level = 16, move = "QUICK_ATTACK" },
    { level = 23, move = "SWIFT" },
    { level = 30, move = "PSYCHIC_M" },
  },
}, canonical.ESPEON, hasMove)

local function countRow(rows, level, move)
  local count = 0
  for _, row in ipairs(rows or {}) do
    if row.level == level and row.move == move then count = count + 1 end
  end
  return count
end

-- Pin the authored Johto source as well as the later compatibility overlay.
-- This keeps the fix present even when the optional full Crystal audit layer
-- is not part of a minimal package.
local authored = assert(johto.species.ESPEON, "missing authored Espeon data")
equal(countRow(authored.learnset, 36, "PSYBEAM"), 1,
  "the authored Johto data must contain level-36 PSYBEAM")
equal(countRow(authored.learnset, 30, "PSYCHIC_M"), 0,
  "the authored Johto data must remove level-30 PSYCHIC")
equal(countRow(authored.learnset, 47, "PSYCHIC_M"), 1,
  "the authored Johto data must restore level-47 PSYCHIC")
equal(authored.level1[1], "TACKLE",
  "Espeon's first authored level-one move must remain TACKLE")
equal(authored.level1[2], "TAIL_WHIP",
  "Espeon's second authored level-one move must remain TAIL_WHIP")
equal(authored.level1[3], nil,
  "SAND_ATTACK must not remain an authored level-one move")
equal(countRow(authored.learnset, 8, "SAND_ATTACK"), 1,
  "the authored Johto data must restore level-8 SAND_ATTACK")

equal(countRow(schedule.learnset, 36, "PSYBEAM"), 1,
  "Espeon must have exactly one level-36 PSYBEAM row")
equal(countRow(schedule.learnset, 30, "PSYCHIC_M"), 0,
  "the obsolete level-30 PSYCHIC row must not survive")
equal(countRow(schedule.learnset, 47, "PSYCHIC_M"), 1,
  "Espeon's canonical Crystal PSYCHIC level must be restored")

-- Exercise the engine's exact-level lookup, not only the table shape.
local Experience = require("src.battle.Experience")
local at36 = Experience.movesLearnedAt(schedule, 36)
equal(#at36, 1,
  "the level-up runtime must offer exactly one move at Espeon level 36")
equal(at36[1], "PSYBEAM",
  "the level-up runtime must offer PSYBEAM at Espeon level 36")
equal(#Experience.movesLearnedAt(schedule, 35), 0,
  "the level-up runtime must not offer PSYBEAM below level 36")

-- Instantiate the production Move Reminder module with minimal registries.
-- This avoids a duplicate test implementation of reminder eligibility.
local saveState = {}
local function registry()
  return {
    rows = {},
    register = function(self, id, value) self.rows[id] = value end,
  }
end
local moves, items = registry(), registry()
local fieldTech = assert(loadfile(root .. "/field_tech.lua"))()({
  save = {
    get = function(_, id) return saveState[id] end,
    set = function(_, id, value) saveState[id] = value end,
  },
  hooks = { wrap = function() end },
  content = {
    moves = moves,
    items = items,
    pokemon = {
      get = function() return nil end,
      patch = function() error("unexpected starter patch") end,
    },
  },
  ui = {},
}, {})

local game = {
  data = {
    pokemon = {
      ESPEON = schedule,
      SCYTHER = {
        id = "SCYTHER", name = "SCYTHER", dex = 123,
        level1Moves = { "FIX_TACKLE" }, learnset = {},
      },
    },
    moves = {
      PSYBEAM = { id = "PSYBEAM", name = "PSYBEAM", pp = 20 },
      FALSE_SWIPE = {
        id = "FALSE_SWIPE", name = "FALSE SWIPE", pp = 40,
      },
      FIX_TACKLE = { id = "FIX_TACKLE", name = "TACKLE", pp = 35 },
    },
  },
  save = { inventory = {}, party = {} },
}
local scizorSchedule = compat.compile({
  level1Moves = johto.species.SCIZOR.level1,
  learnset = johto.species.SCIZOR.learnset,
}, canonical.SCIZOR, hasMove)
game.data.pokemon.SCIZOR = scizorSchedule
local function espeon(level)
  return {
    species = "ESPEON", level = level,
    moves = { { id = "FIX_TACKLE", pp = 35 } },
  }
end
local function reminderSource(mon, move)
  for _, row in ipairs(fieldTech.reminderMoves(game, mon)) do
    if row.id == move then return row.source end
  end
end

local exact = espeon(36)
equal(reminderSource(exact, "PSYBEAM"), "level",
  "the Move Reminder must offer PSYBEAM to a level-36 Espeon")
local learned, reason = fieldTech.rememberMove(game, exact, "PSYBEAM")
equal(learned, true,
  "a level-36 Espeon must be able to relearn PSYBEAM")
equal(exact.moves[#exact.moves].id, "PSYBEAM",
  "the Move Reminder must add PSYBEAM to the selected Espeon")

local higher = espeon(73)
equal(reminderSource(higher, "PSYBEAM"), "level",
  "an existing Espeon above level 36 must be offered PSYBEAM")
learned, reason = fieldTech.rememberMove(game, higher, "PSYBEAM")
equal(learned, true,
  "an existing Espeon above level 36 must be able to relearn PSYBEAM")
equal(higher.moves[#higher.moves].id, "PSYBEAM",
  "the Move Reminder must teach PSYBEAM to the higher-level Espeon")

local lower = espeon(35)
equal(reminderSource(lower, "PSYBEAM"), nil,
  "an Espeon below level 36 must not be offered PSYBEAM")
learned, reason = fieldTech.rememberMove(game, lower, "PSYBEAM")
equal(learned, false,
  "an Espeon below level 36 must not relearn PSYBEAM")
equal(reason, "illegal",
  "the below-level rejection must use the normal legality gate")

local function scizor(level)
  return {
    species = "SCIZOR", level = level,
    moves = { { id = "FIX_TACKLE", pp = 35 } },
  }
end
local youngScizor = scizor(17)
equal(reminderSource(youngScizor, "FALSE_SWIPE"), nil,
  "a level-17 Scizor must not receive its level-18 Crystal move")
local readyScizor = scizor(18)
equal(reminderSource(readyScizor, "FALSE_SWIPE"), "level",
  "Scizor receives FALSE SWIPE through its regular Johto learnset")
learned, reason = fieldTech.rememberMove(
  game, readyScizor, "FALSE_SWIPE")
equal(learned, true,
  "a level-18 Scizor can relearn FALSE SWIPE without Resonance")

-- The Crystal overlay is deliberately scoped to the 100 Johto species.
-- Sentinels for all 151 Kanto species prove that no RBY learnset is patched
-- as collateral.
local speciesData, kantoBefore, johtoSet = {}, {}, {}
local patched = {}
for _, species in ipairs(johto.order) do
  johtoSet[species] = true
  speciesData[species] = {
    level1Moves = {}, learnset = {},
  }
end
for species in pairs(canonical) do
  if species ~= "_meta" and not johtoSet[species] then
    speciesData[species] = {
      level1Moves = { "RBY_SENTINEL" },
      learnset = { { level = 7, move = "RBY_SENTINEL" } },
    }
    kantoBefore[species] = speciesData[species]
  end
end
compat.apply({
  exports = {},
  content = {
    moves = { get = function(_, id)
      return hasMove(id) and { id = id } or nil
    end },
    pokemon = {
      get = function(_, id) return speciesData[id] end,
      patch = function(_, id, value)
        patched[id], speciesData[id] = value, value
      end,
    },
  },
}, canonical, johto.order)
equal(#johto.order, 100,
  "the production overlay scope must remain Johto #152-251")
local kantoCount = 0
for species, before in pairs(kantoBefore) do
  kantoCount = kantoCount + 1
  equal(patched[species], nil,
    "the Espeon fix must not patch RBY species " .. species)
  equal(speciesData[species], before,
    "the RBY learnset object must remain untouched for " .. species)
end
equal(kantoCount, 151,
  "the no-collateral-change gate must cover all original 151 species")

-- Psybeam belongs to Espeon's regular Gen-II schedule. It must not leak into
-- the optional Kanto-only Johto Move Resonance catalog as a blanket fix.
local signalState = {
  earlyJohto = { receiverRepaired = false },
  prismGrotto = {}, resonance = {},
}
local prism = assert(loadfile(root .. "/driftglass_prisms.lua"))().create({
  content = {}, ui = {},
}, {
  state = {
    section = function(name)
      signalState[name] = signalState[name] or {}
      return signalState[name]
    end,
  },
  content = { mapSupported = false },
  fieldTech = fieldTech,
})
equal(prism.resonanceRules.ESPEON, nil,
  "Espeon must not be routed through Kanto Johto Move Resonance")
for species, rules in pairs(prism.resonanceRules) do
  equal(rules.PSYBEAM, nil,
    "PSYBEAM must not be added to Johto Move Resonance for " .. species)
end

local function scyther(level)
  return {
    species = "SCYTHER", level = level,
    moves = { { id = "FIX_TACKLE", pp = 35 } },
  }
end

local lockedScyther = scyther(18)
equal(reminderSource(lockedScyther, "FALSE_SWIPE"), nil,
  "Route 5 must not bypass the optional Johto Resonance unlock")
signalState.earlyJohto.receiverRepaired = true

local earlyScyther = scyther(17)
equal(reminderSource(earlyScyther, "FALSE_SWIPE"), nil,
  "a level-17 Scyther must not be offered level-18 FALSE SWIPE")
learned, reason = fieldTech.rememberMove(
  game, earlyScyther, "FALSE_SWIPE")
equal(learned, false,
  "a level-17 Scyther must not learn FALSE SWIPE from Route 5")
equal(reason, "illegal",
  "under-levelled Resonance moves use the normal legality gate")

local readyScyther = scyther(18)
equal(reminderSource(readyScyther, "FALSE_SWIPE"), "resonance",
  "an unlocked level-18 Scyther sees its species-specific Johto move")
learned, reason = fieldTech.rememberMove(
  game, readyScyther, "FALSE_SWIPE")
equal(learned, true,
  "an unlocked level-18 Scyther can learn FALSE SWIPE at Route 5")
equal(readyScyther.moves[#readyScyther.moves].id, "FALSE_SWIPE",
  "Route 5 teaches FALSE SWIPE to the selected Scyther")

local unrelated = {
  species = "ESPEON", level = 80,
  moves = { { id = "FIX_TACKLE", pp = 35 } },
}
equal(reminderSource(unrelated, "FALSE_SWIPE"), nil,
  "the Resonance provider never exposes a global Johto move pool")

print(("espeon_psybeam_regression_test: ok (%d assertions)")
  :format(assertions))
