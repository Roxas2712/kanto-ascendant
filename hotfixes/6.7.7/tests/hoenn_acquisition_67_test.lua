package.path = "./?.lua;./?/init.lua;" .. package.path

local acquisition = require("hoenn_acquisition_67_data")
local runtime = require("hoenn_species_67_runtime_data")
local State = require("discovery_state")
local Overlay = require("encounter_overlay")
local Discovery = require("hoenn_discovery").create(State, Overlay, acquisition)

local assertions = 0
local function check(value, message)
  assertions = assertions + 1
  assert(value, message)
end
local function eq(actual, expected, message)
  check(actual == expected, (message or "values differ") .. " (got "
    .. tostring(actual) .. ", expected " .. tostring(expected) .. ")")
end

local bySpecies, incoming = {}, {}
for runtimeDex, row in pairs(runtime.breeding) do
  bySpecies[row.species] = {
    runtimeDex = runtimeDex,
    sourceDex = row.sourceDex,
  }
end
for parent, branches in pairs(runtime.evolutions) do
  for _, branch in ipairs(branches) do
    if bySpecies[branch.species] and branch.authority ~= "hevo_package" then
      incoming[branch.species] = parent
    end
  end
end

local roots = {}
for species in pairs(bySpecies) do
  if not incoming[species] then roots[species] = true end
end

local classes, coveredRoots, directSpecies = {
  trace = acquisition.traceFamilies,
  starter = acquisition.starterFamilies,
  research = acquisition.researchRewards,
  existing = acquisition.existingSpecials,
  sanctum = acquisition.sanctumLegends,
  evolution = acquisition.evolutionOnly,
}, {}, {}

for class, rows in pairs(classes) do
  for _, row in ipairs(rows) do
    check(type(row.id) == "string" and roots[row.id],
      class .. " acquisition row must own a real Hoenn family root")
    check(not coveredRoots[row.id], row.id .. " has two acquisition owners")
    coveredRoots[row.id] = class
    directSpecies[row.id] = true
    if class == "trace" or class == "starter" then
      check(type(row.members) == "table" and row.members[1] == row.id,
        row.id .. " trace must start with its family root")
      check(type(row.habitat) == "table"
          and type(row.habitat.map) == "string"
          and ({ grass=true, indoor=true, cave=true })[row.habitat.terrain],
        row.id .. " needs an authored random-encounter habitat")
      check(tonumber(row.habitat.level) and row.habitat.level >= 2
          and row.habitat.level <= 55,
        row.id .. " needs a bounded encounter level")
    elseif class == "research" then
      check(type(row.milestone) == "number" and row.milestone > 0,
        row.id .. " needs a deterministic research milestone")
    elseif class == "existing" or class == "sanctum" then
      check(type(row.owner) == "string" and row.owner ~= "",
        row.id .. " needs a named static/roamer owner")
    elseif class == "evolution" then
      check(type(row.from) == "string" and bySpecies[row.from],
        row.id .. " needs a registered evolution source")
    end
  end
end

eq(#acquisition.traceFamilies, 62,
  "all ordinary Hoenn roots have authored trace habitats")
eq(#acquisition.starterFamilies, 3,
  "the Hoenn starter roots have separate Legacy NG+ habitats")
eq(#acquisition.researchRewards, 0,
  "no ordinary Hoenn lineage bypasses the wild discovery contract")
eq(#acquisition.existingSpecials, 6,
  "the two roamers and four existing quest legends keep their owners")
eq(#acquisition.sanctumLegends, 4,
  "the Regi trio and Deoxys own dedicated sanctum encounters")
eq(#acquisition.evolutionOnly, 1,
  "Shedinja remains evolution-only")

local packed = {}
for _, character in ipairs({ "RED", "GREEN", "BLUE" }) do
  local rows = acquisition.characterPacks[character]
  local expected = ({ RED=21, GREEN=21, BLUE=20 })[character]
  eq(#rows, expected,
    character .. " owns its fixed third of ordinary Hoenn families")
  for _, family in ipairs(rows) do
    check(coveredRoots[family] == "trace",
      family .. " pack entry must be an ordinary trace family")
    check(not packed[family], family .. " appears in two character packs")
    packed[family] = character
    eq(acquisition.familyCharacter[family], character,
      family .. " reverse pack authority is stable")
  end
end
for _, row in ipairs(acquisition.traceFamilies) do
  check(packed[row.id] ~= nil, row.id .. " is missing its character pack")
end
eq((function() local n=0 for _ in pairs(packed) do n=n+1 end return n end)(),
  62, "the fixed character packs partition every ordinary family exactly once")

local rootCount = 0
for species in pairs(roots) do
  rootCount = rootCount + 1
  check(coveredRoots[species], species .. " has no playable acquisition owner")
end
eq(rootCount, 76, "Hoenn runtime root count remains stable")
eq((function() local n=0 for _ in pairs(coveredRoots) do n=n+1 end return n end)(),
  rootCount, "every Hoenn root is owned exactly once")

local reachable = {}
local function visit(species)
  if reachable[species] then return end
  reachable[species] = true
  for _, branch in ipairs(runtime.evolutions[species] or {}) do
    if bySpecies[branch.species] and branch.authority ~= "hevo_package" then
      visit(branch.species)
    end
  end
end
for species in pairs(directSpecies) do visit(species) end
for _, row in ipairs(acquisition.evolutionOnly) do reachable[row.id] = true end

local reachableCount = 0
for sourceDex = 252, 386 do
  local species
  for candidate, row in pairs(bySpecies) do
    if row.sourceDex == sourceDex then species = candidate break end
  end
  check(species ~= nil, "source Dex #" .. sourceDex .. " is registered")
  check(reachable[species], species .. " (#" .. sourceDex
    .. ") is not reachable from its acquisition owner")
  reachableCount = reachableCount + 1
end
eq(reachableCount, 135, "all Hoenn National-Dex identities are reachable")

local forbiddenTrace = {
  REGIROCK=true, REGICE=true, REGISTEEL=true, LATIAS=true, LATIOS=true,
  KYOGRE=true, GROUDON=true, RAYQUAZA=true, JIRACHI=true, DEOXYS=true,
}
for _, row in ipairs(acquisition.traceFamilies) do
  check(not forbiddenTrace[row.id], row.id .. " leaked into ordinary traces")
end

eq(#Discovery.order, 65,
  "the live discovery catalogue consumes all ordinary acquisition rows")
eq(#Discovery.ordinaryOrder, 62,
  "the ordinary Hoenn pool excludes all three starters")
eq(#Discovery.starterOrder, 3,
  "the starter pool contains exactly the three Hoenn starters")
eq(Discovery.primaryHabitat("TREECKO").map, "ROUTE_2",
  "Treecko uses its separate Legacy NG+ Route 2 habitat")
check(#Discovery.familiesForMap("SEAFOAM_ISLANDS_B2F") >= 6,
  "the Seafoam research cluster is discoverable without visible Wilds")

local introducedRoot, introduced = Discovery.planIntroduction(State.empty(), {
  mapId = "ROUTE_1", eligible = true, registeredFamilies = {"POOCHYENA"},
  chanceRoll = 1, familyRoll = 1, token = "authored-habitat",
})
eq(introduced.sourceMapId, "ROUTE_1",
  "the Wanderer battle keeps its actual source map")
eq(introduced.mapId, "ROUTE_1",
  "the clue points to the authored habitat rather than the trainer's tile")
eq(Discovery.traceMap(introducedRoot, "POOCHYENA"), "ROUTE_1",
  "the durable trace records the authored habitat")

local ngRoot, ngIntroduction = Discovery.planIntroduction(State.empty(), {
  mapId = "ROUTE_24", traceMap = "ROUTE_24", eligible = true,
  registeredFamilies = {"POOCHYENA"}, chanceRoll = 1, familyRoll = 1,
  token = "legacy-alternate-habitat",
})
eq(ngIntroduction.introduced, false,
  "new distant clues cannot relocate Poochyena to Route 24")
eq(Discovery.traceMap(ngRoot, "POOCHYENA"), nil,
  "a rejected distant clue leaves no fake habitat")

local inherited, inheritedChanged = Discovery.hydrateLineage(State.empty(), {
  POOCHYENA = { caught=true, unlocked=true, traceMap="ROUTE_24" },
  REGIROCK = { caught=true, unlocked=true, traceMap="ROUTE_10" },
})
check(inheritedChanged,
  "a prior ordinary Hoenn catch hydrates into the next Legacy journey")
eq(State.status(inherited, "hoenn", "POOCHYENA"), "unlocked",
  "the inherited ordinary family remains a durable captured unlock")
eq(Discovery.traceMap(inherited, "POOCHYENA"), "ROUTE_24",
  "the inherited family keeps its NG+ habitat receipt")
eq(State.status(inherited, "hoenn", "REGIROCK"), "unseen",
  "legendary quest species never enter the ordinary character-pack ledger")

print(("HOENN ACQUISITION 6.7 PASS: %d assertions; "
  .. "62 wild traces + 3 Legacy starters + 10 legends + 1 evolution root")
  :format(assertions))
