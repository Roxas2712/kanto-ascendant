package.path = "./?.lua;./?/init.lua;" .. package.path

local State = require("discovery_state")
local Overlay = require("encounter_overlay")
local Acquisition = require("hoenn_acquisition_67_data")
local Hoenn = require("hoenn_discovery").create(State, Overlay, Acquisition)

local checks = 0
local function check(value, message)
  checks = checks + 1
  assert(value, message)
end
local function eq(actual, expected, message)
  check(actual == expected, (message or "values differ") .. " (got "
    .. tostring(actual) .. ", expected " .. tostring(expected) .. ")")
end

local dexReady, starterReady, legacy = false, false, false
local discoveryRoot = State.empty()
local mod = { exports = {
  discoveryCore = {
    Hoenn = Hoenn,
    state = { root = function() return discoveryRoot end },
  },
  hoennFieldAccess = {
    hasDex = function() return dexReady end,
    isLegacy = function() return legacy end,
    ordinaryAllowed = function(_, family) return family == "POOCHYENA" end,
    starterUnlocked = function(_, family)
      return starterReady and family == "TREECKO"
    end,
  },
} }
local provider = assert(loadfile("pokedex_area_habitats.lua"))()(mod)
local game = { save={ pokedex={ seen={}, owned={} } } }

eq(#provider(game, "POOCHYENA"), 0,
  "an unseen Hoenn species never leaks a location")
game.save.pokedex.seen.POOCHYENA = true
eq(#provider(game, "POOCHYENA"), 0,
  "a seen species still needs the Hoenn Dex for AREA")
dexReady = true
local rows = provider(game, "POOCHYENA")
eq(#rows, 1, "the Hoenn Dex projects one authored ordinary habitat")
eq(rows[1].map, "ROUTE_1", "Poochyena AREA points to Route 1")
eq(rows[1].chance, 1, "ordinary AREA metadata retains the one-percent rate")

legacy = true
eq(#provider(game, "POOCHYENA"), 0,
  "NG+ never leaks the unavailable standard-game Route 1 habitat")
-- Saved pre-hotfix traces stay valid; new clues no longer relocate species.
discoveryRoot = State.mark(discoveryRoot, "hoenn", "POOCHYENA", "trace")
discoveryRoot.generations.hoenn.families.POOCHYENA.traceMap = "ROUTE_24"

rows = provider(game, "POOCHYENA")
eq(#rows, 1, "an NG+ Wanderer trace exposes exactly one new habitat")
eq(rows[1].map, "ROUTE_24",
  "NG+ AREA data points to the Wanderer habitat instead of Route 1")
eq(rows[1].source, "hoenn_legacy_trace_67",
  "NG+ AREA data names the Legacy trace authority")
eq(rows[1].chance, 1.5, "NG+ trace metadata retains its stronger clue rate")

discoveryRoot = select(1, Hoenn.hydrateLineage(State.empty(), {
  POOCHYENA = {
    caught=true, unlocked=true, traceMap="ROUTE_24", character="RED",
  },
}))
rows = provider(game, "POOCHYENA")
eq(#rows, 1,
  "a caught family from an earlier character keeps one NG+ AREA habitat")
eq(rows[1].map, "ROUTE_24",
  "a durable lineage receipt keeps the NG+ habitat and never Route 1")
legacy = false

game.save.pokedex.seen.TREECKO = true
eq(#provider(game, "TREECKO"), 0,
  "a locked Hoenn starter location stays hidden as unknown")
starterReady = true
rows = provider(game, "TREECKO")
eq(#rows, 1, "the matching Legacy path reveals the starter route")
eq(rows[1].map, "ROUTE_2", "Treecko AREA points to its distinct route")
eq(rows[1].chance, 0.5, "starter AREA metadata retains the half-percent rate")

game.save.pokedex.seen.MIGHTYENA = true
rows = provider(game, "MIGHTYENA")
eq(rows[1].map, "ROUTE_1",
  "an evolved member resolves to its family's authored habitat")

print(("POKEDEX AREA HOENN 6.7 PASS: %d assertions"):format(checks))
