-- Focused, ROM-free verification of the canonical Crystal overlay.
-- Run: ../gen1recomp/.tools/luajit-src/src/luajit \
--   tests/crystal_learnset_compat_test.lua

local source = debug.getinfo(1, "S").source
local testDir = source:sub(1, 1) == "@"
  and source:sub(2):match("^(.*)/[^/]+$") or "tests"
local root = testDir:match("^(.*)/tests$") or "."

local canonical = assert(loadfile(root .. "/crystal_learnsets.lua"))()
local compat = assert(loadfile(root .. "/crystal_learnset_compat.lua"))()
local johto = assert(loadfile(root .. "/johto_data.lua"))()

local missingIds = {
  "ANCIENTPOWER", "BATON_PASS", "BEAT_UP", "BELLY_DRUM", "CONVERSION2",
  "COTTON_SPORE", "CURSE", "DESTINY_BOND", "DETECT", "ENCORE",
  "ENDURE", "FLAIL", "FORESIGHT", "FUTURE_SIGHT",
  "HEAL_BELL", "HIDDEN_POWER", "LOCK_ON", "MAGNITUDE", "MEAN_LOOK",
  "MIND_READER", "MIRROR_COAT", "MOONLIGHT", "MORNING_SUN",
  "OCTAZOOKA", "OUTRAGE", "PAIN_SPLIT", "PERISH_SONG", "PRESENT",
  "PROTECT", "PSYCH_UP", "PURSUIT", "RAPID_SPIN", "REVERSAL",
  "ROLLOUT", "SAFEGUARD", "SANDSTORM", "SCARY_FACE", "SKETCH",
  "SPIDER_WEB", "SPIKES", "SPITE", "STEEL_WING", "SWAGGER",
  "SWEET_SCENT", "TRIPLE_KICK", "TWISTER", "ZAP_CANNON",
}
local missing = {}
for _, id in ipairs(missingIds) do missing[id] = true end

local canonicalMoves = {}
for species, rows in pairs(canonical) do
  if species ~= "_meta" then
    for _, row in ipairs(rows) do canonicalMoves[row.move] = true end
  end
end
local available = {}
for id in pairs(canonicalMoves) do
  if not missing[id] then available[id] = true end
end
available.KA_SIGNATURE = true

-- A pre-overlay approximation deliberately puts several canonical moves at
-- the wrong level and includes both a KA extension and an unknown id.
local schedule, one = compat.compile({
  level1Moves = {
    "TACKLE", "TAIL_WHIP", "SAND_ATTACK", "KA_SIGNATURE", "UNKNOWN_ID",
  },
  learnset = {
    { level = 23, move = "SWIFT" },
    { level = 30, move = "PSYCHIC_M" },
    { level = 60, move = "KA_SIGNATURE" },
    { level = 99, move = "UNKNOWN_ID" },
  },
}, canonical.ESPEON, function(id) return available[id] end)

local function atLevel(rows, level, move)
  for _, row in ipairs(rows) do
    if row.level == level and row.move == move then return true end
  end
  return false
end

assert(atLevel(schedule.learnset, 36, "PSYBEAM"),
  "Psiana/Espeon must learn PSYBEAM exactly at level 36")
assert(atLevel(schedule.learnset, 47, "PSYCHIC_M"),
  "Crystal's level-47 PSYCHIC must replace the approximate level-30 row")
assert(not atLevel(schedule.learnset, 30, "PSYCHIC_M"),
  "approximate canonical levels must not survive as KA extensions")
assert(atLevel(schedule.learnset, 60, "KA_SIGNATURE"),
  "KA-only learnset additions must survive the Crystal overlay")
assert(schedule.level1Moves[#schedule.level1Moves] == "KA_SIGNATURE",
  "KA-only level-one additions must survive the Crystal overlay")
assert(one.skippedUnknownExtensions == 2,
  "unknown existing ids must be removed rather than re-registered")

-- Verify the actual Gen1 Recomp level-up seam, not only the generated row.
local engineCandidates = {
  root .. "/../gen1recomp",
  root .. "/../../gen1recomp",
}
if os.getenv("GEN1RECOMP_ROOT") then
  table.insert(engineCandidates, 1, os.getenv("GEN1RECOMP_ROOT"))
end
local engine
for _, candidate in ipairs(engineCandidates) do
  if candidate then
    local probe = io.open(candidate .. "/src/battle/Experience.lua", "rb")
    if probe then probe:close(); engine = candidate; break end
  end
end
assert(engine, "set GEN1RECOMP_ROOT to test the runtime level-up seam")
package.path = engine .. "/?.lua;" .. engine .. "/?/init.lua;" .. package.path
local Experience = require("src.battle.Experience")
local learned = Experience.movesLearnedAt({ learnset = schedule.learnset }, 36)
assert(#learned == 1 and learned[1] == "PSYBEAM",
  "Gen1 Recomp's exact-level runtime must offer Psiana PSYBEAM at 36")
assert(#Experience.movesLearnedAt({ learnset = schedule.learnset }, 35) == 0,
  "PSYBEAM must not be offered one level early")

-- Exercise the production patch boundary for the 100 Johto species.  Any
-- unknown canonical id must appear only in the audit, never in a learnset.
local speciesData, patched = {}, {}
for species in pairs(canonical) do
  if species ~= "_meta" then
    speciesData[species] = { level1Moves = {}, learnset = {} }
  end
end
local mod = {
  exports = {},
  log = { info = function() end },
  content = {
    moves = { get = function(_, id) return available[id] and { id = id } end },
    pokemon = {
      get = function(_, id) return speciesData[id] end,
      patch = function(_, id, value)
        patched[id] = value
        speciesData[id] = value
      end,
    },
  },
}
local kantoBefore = speciesData.BULBASAUR
local report = compat.apply(mod, canonical, johto.order)
assert(#johto.order == 100, "production Crystal scope must be the 100 Johto species")
assert(report.sourceSpecies == 251,
  "the full source table must remain available for audit/future opt-in")
assert(report.canonicalSpecies == 100 and report.patchedSpecies == 100,
  "production must patch exactly Johto #152-251")
assert(patched.BULBASAUR == nil and speciesData.BULBASAUR == kantoBefore,
  "the production overlay must not change Kanto learnsets")
for species, data in pairs(patched) do
  for _, move in ipairs(data.level1Moves) do
    assert(available[move], species .. " received unknown level-one move " .. move)
  end
  for _, row in ipairs(data.learnset) do
    assert(available[row.move], species .. " received unknown move " .. row.move)
  end
end
assert(atLevel(patched.ESPEON.learnset, 36, "PSYBEAM"),
  "runtime aggregate patch lost Espeon's level-36 PSYBEAM")
assert(atLevel(patched.SCIZOR.learnset, 18, "FALSE_SWIPE"),
  "runtime aggregate patch lost Scizor's implemented level-18 False Swipe")
assert(mod.exports.crystalLearnsetAudit == report,
  "machine-readable runtime audit must be exported")

print("crystal_learnset_compat_test: ok")
