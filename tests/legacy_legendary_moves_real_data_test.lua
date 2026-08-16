-- Production-data proof for the three-path Legacy capstone partners.
--
-- This deliberately loads Kanto Ascendant through the real 0.1.95 mod
-- loader over the generated Kanto registries.  Johto species/moves are then
-- the same merged definitions the shipped mod exposes in play; no synthetic
-- legality fixture is allowed to make an authored four-move plan pass.

local engine = assert(os.getenv("GEN1RECOMP_DIR"),
  "GEN1RECOMP_DIR is required")
local root = assert(os.getenv("KANTO_SIGNALS_MOD_DIR"),
  "KANTO_SIGNALS_MOD_DIR is required")
package.path = engine .. "/?.lua;" .. engine .. "/?/init.lua;"
  .. package.path

local assertions = 0
local function check(value, message)
  assertions = assertions + 1
  if not value then error("FAIL: " .. message, 2) end
end
local function eq(actual, expected, message)
  check(actual == expected, message .. " (got " .. tostring(actual)
    .. ", expected " .. tostring(expected) .. ")")
end

local Data = require("src.core.Data")
Data:load()
local Version = require("src.core.Version")
local previousVersion = Version.engine
Version.engine = "0.1.95"
local T = require("tests.modkit")
local run = T.sdk.loadMod(root, { data = Data, root = "/" })
Version.engine = previousVersion
check(run.mod ~= nil,
  "Kanto Ascendant loads through the production 0.1.95 registry merge")
eq(#(run.errors or {}), 0,
  "production 0.1.95 merge reports no loader errors")

local ex = assert(run.loader.exports.kanto_ascendant,
  "Kanto Ascendant exports unavailable after production merge")
local starters = assert(ex.legacyStarters,
  "Legacy partner controller is exported")
local expected = {
  "ARTICUNO", "ZAPDOS", "MOLTRES", "MEWTWO", "MEW",
  "RAIKOU", "ENTEI", "SUICUNE", "LUGIA", "HO_OH", "CELEBI",
}
eq(#starters.legendaryOrder, #expected,
  "the capstone catalogue contains exactly eleven identities")

local function normalizedType(value)
  return tostring(value or ""):upper():gsub("_TYPE$", "")
end

for index, species in ipairs(expected) do
  eq(starters.legendaryOrder[index], species,
    "capstone identity order is stable at row " .. tostring(index))
  eq(starters.legendaryIds[species], true,
    species .. " is in the closed capstone identity set")
  local def = Data.pokemon[species]
  check(type(def) == "table",
    species .. " exists in the real merged species registry")
  check(math.floor(tonumber(def.dex) or 0) >= 1,
    species .. " retains a real merged Pokédex identity")

  local plan = starters.legendaryMoveSets[species]
  eq(type(plan), "table", species .. " has an authored move plan")
  eq(#plan, 4, species .. " has exactly four start moves")
  local slots, moveErr = starters.legendaryMoveSlots({ data = Data }, species)
  check(type(slots) == "table",
    species .. " passes the real merged legality gate: "
      .. tostring(moveErr))
  eq(#slots, 4, species .. " produces four real move slots")
  local seen = {}
  for moveIndex, move in ipairs(plan) do
    check(not seen[move], species .. " has no duplicate move " .. move)
    seen[move] = true
    local source = starters.legalMoveSource(def, move)
    check(source == "level" or source == "machine" or source == "tutor",
      species .. " / " .. move
        .. " is legal in real level/TM/HM/tutor data")
    eq(slots[moveIndex].id, move,
      species .. " keeps deterministic move order in production")
    local moveDef = Data.moves[move]
    check(type(moveDef) == "table" and (tonumber(moveDef.pp) or 0) > 0,
      species .. " / " .. move .. " exists with usable PP")
    eq(slots[moveIndex].pp, moveDef.pp,
      species .. " / " .. move .. " uses merged base PP")
  end

  local stab = starters.legendaryEarlyStab[species]
  local stabDef = Data.moves[stab]
  check(type(stabDef) == "table" and (tonumber(stabDef.power) or 0) > 0,
    species .. " has an immediately damaging authored STAB")
  local stabType = normalizedType(stabDef.type)
  local matchingType = false
  for _, speciesType in ipairs(def.types or {}) do
    if normalizedType(speciesType) == stabType then matchingType = true end
  end
  check(matchingType,
    species .. " damaging opener matches a real merged species type")

  local preview, trueColor, source = starters.crystalSpritePath({
    data = Data, save = {},
  }, species)
  check(type(preview) == "string" and preview ~= "",
    species .. " resolves a real Crystal preview path")
  eq(trueColor, true,
    species .. " Crystal preview stays true-colour")
  eq(source, "crystal",
    species .. " preview does not fall back to generic Kanto art")
end

run.release()
print(("LEGACY LEGENDARY REAL-DATA PASS: %d assertions")
  :format(assertions))
