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

local game = {
  save = { party = { { species="PIKACHU", level=30 } } },
  data = { pokemon = {
    POOCHYENA = { evolutions = { { species="MIGHTYENA", level=18 } } },
    MIGHTYENA = { evolutions = {} },
    TREECKO = { evolutions = { { species="GROVYLE", level=16 } } },
    GROVYLE = { evolutions = { { species="SCEPTILE", level=36 } } },
    SCEPTILE = { evolutions = {} },
  } },
}
local registered = { "POOCHYENA", "TREECKO" }
local native = { species="RATTATA", level=4, marker="native" }

local function plan(root, mapId, roll, extra)
  extra = extra or {}
  return Hoenn.planFieldOverlay(root or State.empty(), {
    native = native,
    mapId = mapId,
    roll = roll,
    serial = roll,
    registeredFamilies = extra.registeredFamilies or registered,
    normalEnabled = extra.normalEnabled == true,
    legacyEnabled = extra.legacyEnabled == true,
    ordinaryAllowed = extra.ordinaryAllowed,
    starterUnlocked = extra.starterUnlocked or {},
    levelMode = extra.levelMode or "route",
    badgeCount = extra.badgeCount or 0,
    game = game,
  })
end

-- The normal field layer is exactly 1%, only after its separate access gate.
local output, tx, reason = plan(nil, "ROUTE_1", 9900,
  { normalEnabled=true })
eq(output.species, "RATTATA", "roll 9900 stays native")
eq(tx, nil, "a normal-pool miss creates no transaction")
eq(reason, "native", "a normal-pool miss is explicitly native")

output, tx, reason = plan(nil, "ROUTE_1", 9901,
  { normalEnabled=true })
eq(output.species, "POOCHYENA", "roll 9901 starts the exact 1% window")
eq(output.kaHoennMode, "normal", "normal encounters retain their source mode")
eq(output.level, 4, "route mode uses the authored/native route floor")
eq(reason, "normal", "the planner reports a normal Hoenn hit")

output = plan(nil, "ROUTE_1", 10000, { normalEnabled=false })
eq(output.species, "RATTATA", "Honey/Dex-disabled normal play stays native")

local normalHits = 0
for roll = 1, 10000 do
  local candidate = plan(nil, "ROUTE_1", roll, { normalEnabled=true })
  if candidate.kaHoennMode == "normal" then normalHits = normalHits + 1 end
end
eq(normalHits, 100, "the normal field layer is exactly 100/10000")

output = plan(nil, "ROUTE_1", 9901, {
  normalEnabled=true, ordinaryAllowed={ ZIGZAGOON=true },
})
eq(output.species, "RATTATA",
  "a family outside the active character third cannot use its normal habitat")

-- Hoenn starters are a disjoint 0.5% Legacy-only bucket.
output = plan(nil, "ROUTE_2", 9851, {
  normalEnabled=true, starterUnlocked={ TREECKO=false },
})
eq(output.species, "RATTATA", "a locked Hoenn starter never leaks")

output = plan(nil, "ROUTE_2", 9850, {
  normalEnabled=true, starterUnlocked={ TREECKO=true },
})
eq(output.species, "RATTATA", "roll 9850 stays below the starter bucket")
output, tx, reason = plan(nil, "ROUTE_2", 9851, {
  normalEnabled=true, starterUnlocked={ TREECKO=true },
})
eq(output.species, "TREECKO", "roll 9851 starts the 0.5% starter bucket")
eq(output.kaHoennMode, "starter", "starter encounters retain their source mode")
eq(output.level, 5, "starter habitat level remains authoritative")

local starterHits = 0
for roll = 1, 10000 do
  local candidate = plan(nil, "ROUTE_2", roll, {
    normalEnabled=true, starterUnlocked={ TREECKO=true },
  })
  if candidate.kaHoennMode == "starter" then starterHits = starterHits + 1 end
end
eq(starterHits, 50, "the Legacy starter layer is exactly 50/10000")

-- An active Wanderer trace replaces the ordinary bucket with a 1.5% clue.
local traced = select(1, Hoenn.planIntroduction(State.empty(), {
  mapId="ROUTE_1", eligible=true, registeredFamilies={"POOCHYENA"},
  chanceRoll=1, familyRoll=1, token="overlay-contract",
}))
output, tx, reason = plan(traced, "ROUTE_1", 9850,
  { normalEnabled=true })
eq(output.species, "RATTATA", "roll 9850 stays below a trace")
check(type(tx) == "table" and reason == "trace-miss",
  "a trace miss carries the exact pity transaction")
output, tx, reason = plan(traced, "ROUTE_1", 9851,
  { normalEnabled=true })
eq(output.species, "POOCHYENA", "roll 9851 starts the exact trace window")
eq(output.kaHoennMode, "trace", "the active clue wins the map overlay")

local traceHits = 0
for roll = 1, 10000 do
  local candidate = plan(traced, "ROUTE_1", roll,
    { normalEnabled=true })
  if candidate.kaHoennMode == "trace" then traceHits = traceHits + 1 end
end
eq(traceHits, 150, "an active trace is exactly 150/10000")

-- A family caught in an earlier character journey remains available only on
-- its durable NG+ trace habitat.  It must not resurrect the standard Honey
-- route, and it must not participate in unresolved-trace pity bookkeeping.
local inherited = select(1, Hoenn.hydrateLineage(State.empty(), {
  POOCHYENA = {
    caught=true, unlocked=true, traceMap="ROUTE_24", character="RED",
  },
}))
output = plan(inherited, "ROUTE_1", 10000, {
  normalEnabled=false, legacyEnabled=true,
})
eq(output.species, "RATTATA",
  "an inherited family never restores its standard-game habitat in NG+")
output, tx, reason = plan(inherited, "ROUTE_24", 9851, {
  normalEnabled=false, legacyEnabled=true,
})
eq(output.species, "POOCHYENA",
  "an inherited family remains catchable on its saved NG+ trace habitat")
eq(output.kaHoennMode, "legacy",
  "a durable lineage habitat is distinct from an unresolved trace")
eq(#tx.traces, 0,
  "a durable lineage encounter cannot invent trace-pity bookkeeping")
output = plan(inherited, "ROUTE_24", 9851, {
  normalEnabled=false, legacyEnabled=false,
})
eq(output.species, "RATTATA",
  "durable trace habitats never leak outside an active NG+ journey")

-- Evolved ordinary forms are occasional, but never below their evolution floor.
output = plan(nil, "ROUTE_1", 9901, {
  normalEnabled=true, levelMode="route",
})
eq(output.species, "POOCHYENA",
  "an evolved form cannot appear below its real evolution floor")
output = plan(nil, "ROUTE_1", 9901, {
  normalEnabled=true, levelMode="badges", badgeCount=4,
})
eq(output.species, "MIGHTYENA",
  "the occasional evolved slot may appear once its floor is satisfied")
eq(output.level, 28, "badge scaling remains deterministic and bounded")

-- Starters always stay at their root even when the shared roll is an evolved slot.
output = plan(nil, "ROUTE_2", 9851, {
  normalEnabled=true, levelMode="party",
  starterUnlocked={ TREECKO=true },
})
eq(output.species, "TREECKO", "starter habitat encounters never skip stages")
eq(output.level, 30, "party level mode uses the active non-egg party average")

print(("HOENN FIELD OVERLAY 6.7 PASS: %d assertions"):format(checks))
