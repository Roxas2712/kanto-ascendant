-- Real SDK/full-main registry contract for the Legacy Oak team builder.
-- Run from Gen1 Recomp:
--   TRAINER_REMATCH_MOD_DIR=/path/to/kanto-ascendant \
--     ./.tools/luajit-src/src/luajit \
--     /path/to/kanto-ascendant/tests/legacy_oak_finale_engine_test.lua

package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.modkit")
local Data = require("src.core.Data")
if not (Data.pokemon and Data.pokemon.BULBASAUR) then Data:load() end

local assertions = 0
local function check(value, message)
  assertions = assertions + 1
  if not value then error("FAIL: " .. message, 2) end
end
local function eq(actual, expected, message)
  check(actual == expected, message .. " (got " .. tostring(actual)
    .. ", expected " .. tostring(expected) .. ")")
end

local modPath = os.getenv("TRAINER_REMATCH_MOD_DIR")
  or "mods/ka_rc11_integration"
local run = T.sdk.loadMod(modPath, { data = Data })
check(run.mod ~= nil, "Authority mod loads through the real SDK")
eq(#(run.errors or {}), 0, "Authority main merge is clean")
local exports = assert(run.loader.exports.kanto_ascendant)
local oak = assert(exports.legacyOakFinale)
check(oak.validateBoss(Data), "merged registry validates Oak's fixed legal six")

local function firstMoves(def, level)
  local rows, seen = {}, {}
  local function add(id)
    if id and Data.moves[id] and not seen[id] and #rows < 4 then
      seen[id] = true
      rows[#rows + 1] = { id = id, pp = Data.moves[id].pp }
    end
  end
  for _, id in ipairs(def.level1Moves or {}) do add(id) end
  for _, row in ipairs(def.learnset or {}) do
    if (tonumber(row.level) or 101) <= level then add(row.move) end
  end
  for _, id in ipairs(def.tmhm or {}) do add(id) end
  return rows
end

for _, species in ipairs({ "BLAZIKEN", "SCEPTILE", "SWAMPERT",
    "MAGNEZONE", "MISMAGIUS", "TOGEKISS", "AZURILL", "WYNAUT" }) do
  local def = assert(Data.pokemon[species], species .. " is merged")
  local mon = { species = species, level = 70, moves = firstMoves(def, 70) }
  local normal, err = oak.normaliseMon(Data, mon)
  check(normal ~= nil, species .. " is a legal current/archive source: "
    .. tostring(err))
  check(normal.hp == normal.stats.hp and #normal.moves >= 1,
    species .. " becomes a healed bounded trial copy")
end

local raichu = { species = "RAICHU", level = 50,
  moves = { { id = "QUICK_ATTACK", pp = Data.moves.QUICK_ATTACK.pp } } }
check(oak.normaliseMon(Data, raichu),
  "real merged evolution graph permits a retained Pikachu move")

local eventPikachu = { species = "PIKACHU", level = 50,
  moves = { { id = "SPLASH", pp = Data.moves.SPLASH.pp } },
  eventDistribution = { originalMoves = { "SPLASH" } } }
check(oak.normaliseMon(Data, eventPikachu),
  "event-distribution provenance permits its authored move")
eventPikachu.eventDistribution = nil
local _, eventErr = oak.normaliseMon(Data, eventPikachu)
eq(eventErr, "invalid_move_state",
  "same species/move pair without provenance is rejected")

local authoredEggMoves = assert(loadfile(modPath .. "/egg_moves.lua"))()
local eggSpecies, eggMove
for species, def in pairs(Data.pokemon) do
  for _, move in ipairs(authoredEggMoves[tonumber(def.dex)] or {}) do
    if Data.moves[move] then eggSpecies, eggMove = species, move break end
  end
  if eggSpecies then break end
end
check(eggSpecies ~= nil, "real Crystal egg-move registry resolves in merged data")
check(oak.normaliseMon(Data, { species = eggSpecies, level = 70,
  moves = { { id = eggMove, pp = Data.moves[eggMove].pp } },
}), "real Crystal egg-move source is accepted by the finale validator")

local resonanceRules = assert(exports.driftglassPrisms.resonanceRules)
local resonanceSpecies, resonanceMove, resonanceLevel
for species, rules in pairs(resonanceRules) do
  for move, rule in pairs(rules) do
    if Data.pokemon[species] and Data.moves[move] then
      resonanceSpecies, resonanceMove = species, move
      resonanceLevel = math.max(1, tonumber(rule.level) or 1)
      break
    end
  end
  if resonanceSpecies then break end
end
check(resonanceSpecies ~= nil, "merged Resonance registry has a legal row")
check(oak.normaliseMon(Data, { species = resonanceSpecies,
  level = resonanceLevel,
  moves = { { id = resonanceMove, pp = Data.moves[resonanceMove].pp } },
}), "real Resonance rule is accepted without a hard-coded species list")

run.release()
print(("legacy Oak full-main registry: %d assertions"):format(assertions))
