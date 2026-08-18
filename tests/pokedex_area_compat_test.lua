local checks = 0

local function check(value, message)
  checks = checks + 1
  assert(value, message or ("check " .. checks .. " failed"))
end

local function equal(actual, expected, message)
  checks = checks + 1
  assert(actual == expected, (message or "values differ")
    .. (" (expected %s, got %s)"):format(tostring(expected), tostring(actual)))
end

local function unsafeTownMap()
  local TownMap = { calls = 0 }
  function TownMap.new(game, opts)
    TownMap.calls = TownMap.calls + 1
    if not (opts and opts.nestSpecies) then
      return { plain = true, encounters = game.data.encounters }
    end
    local nests = {}
    for mapId, encounter in pairs(game.data.encounters or {}) do
      for _, group in pairs(encounter) do
        for _, slot in ipairs(group.slots or {}) do
          if slot.species == opts.nestSpecies then
            nests[#nests + 1] = mapId
            break
          end
        end
      end
    end
    return { species = opts.nestSpecies, nests = nests,
      scanned = game.data.encounters }
  end
  return TownMap
end

local function fixture()
  return {
    ROUTE_1 = {
      grass = { rate = 25, slots = {
        { species = "RATTATA", level = 3 },
        { species = "PIKACHU", level = 4 },
      } },
      water = { rate = 0, slots = {} },
    },
    KA_HEVO_BLUE_TIDAL_DEPTHS = {
      grass = { rate = 15, slots = {
        { species = "CHINCHOU", level = 28 },
        false, -- malformed third-party row must not take down AREA
      } },
      water = { rate = 15, slots = {
        { species = "CHINCHOU", level = 29 },
      } },
      kaProtected = true,
      kaEncounterSource = "hevo_dungeon",
      hevoCharacter = "BLUE",
      kaMaxVisible = 3,
    },
    MALFORMED_MAP = "not an encounter table",
    FOREIGN_METADATA = {
      grass = { rate = 10, slots = "not a slot list" },
      annotations = { owner = "foreign mod" },
      enabled = true,
    },
  }
end

local install = assert(loadfile("pokedex_area_compat.lua"))()
local TownMap = unsafeTownMap()
local encounters = fixture()
local game = { data = { encounters = encounters } }

-- Direct proof of the public 0.1.96 reader contract: Ascendant's scalar HEVO
-- metadata causes `.slots` indexing to raise before any map can be shown.
local reproGame = { data = { encounters = {
  KA_HEVO_RED_UPPER = {
    grass = { slots = { { species = "MAGMAR", level = 30 } } },
    kaProtected = true,
    kaEncounterSource = "hevo_dungeon",
    hevoCharacter = "RED",
    kaMaxVisible = 3,
  },
} } }
local okBefore, errBefore = pcall(TownMap.new, reproGame,
  { nestSpecies = "PIKACHU" })
check(not okBefore, "unpatched 0.1.96-style AREA reader should reproduce crash")
check(tostring(errBefore):find("index", 1, true) ~= nil,
  "reproduction should be the scalar-group indexing failure")

local providerCalls = 0
local installed, why = install({
  townMap = TownMap,
  habitatsFor = function(_, species)
    providerCalls = providerCalls + 1
    return species == "CHIKORITA" and { { map = "ROUTE_24", level = 18 } }
      or {}
  end,
})
check(installed, why)
local installedAgain, againWhy = install({ townMap = TownMap })
check(installedAgain and againWhy == "already installed",
  "installation must be idempotent")

-- Red, Blue and Yellow share this engine screen.  Exercise an ordinary Kanto
-- species and an extended Johto species for every edition identity.
for _, edition in ipairs({ "red", "blue", "yellow" }) do
  game.edition = edition
  local kanto = TownMap.new(game, { nestSpecies = "PIKACHU" })
  equal(kanto.species, "PIKACHU", edition .. " Kanto species")
  equal(#kanto.nests, 1, edition .. " Kanto nest count")
  equal(kanto.nests[1], "ROUTE_1", edition .. " Kanto nest")

  local johto = TownMap.new(game, { nestSpecies = "CHINCHOU" })
  equal(johto.species, "CHINCHOU", edition .. " Johto species")
  equal(#johto.nests, 2, edition .. " Johto grass/water groups remain readable")
  check(johto.scanned ~= encounters,
    edition .. " AREA scan must receive a temporary projection")
  check(game.data.encounters == encounters,
    edition .. " canonical encounter registry must be restored")
end

local projected = TownMap.new(game, { nestSpecies = "CHIKORITA" })
equal(#projected.nests, 1,
  "runtime-only authored habitat should appear in AREA")
equal(projected.nests[1], "ROUTE_24",
  "runtime-only authored habitat uses its real map")
check(providerCalls > 0, "AREA did not consult the habitat provider")
check(game.data.encounters == encounters,
  "runtime habitat projection must restore canonical encounter data")

local unknown = TownMap.new(game, { nestSpecies = "CELEBI" })
equal(#unknown.nests, 0, "species without native slots should show unknown area")
check(game.data.encounters == encounters,
  "unknown-area scan must restore canonical registry")

-- Town Map/Fly and all other callers stay on the engine's original path.
local plain = TownMap.new(game, {})
check(plain.plain, "ordinary Town Map remains available")
check(plain.encounters == encounters,
  "ordinary Town Map receives the exact canonical registry")
local explicitPlain = TownMap.new(game, { nestSpecies = false })
check(explicitPlain.plain and explicitPlain.encounters == encounters,
  "false nest option must stay on the exact ordinary Town Map path")

-- Restoration is transactional even if the downstream engine constructor
-- fails for an unrelated reason.
local failing = {
  new = function(failingGame, opts)
    if opts and opts.nestSpecies then error("synthetic render failure") end
    return failingGame
  end,
}
assert(install({ townMap = failing }))
local failGame = { data = { encounters = encounters } }
local okAfter, errAfter = pcall(failing.new, failGame,
  { nestSpecies = "PIKACHU" })
check(not okAfter and tostring(errAfter):find("synthetic render failure", 1, true),
  "downstream failures must propagate")
check(failGame.data.encounters == encounters,
  "downstream failure must still restore canonical registry")

print(("POKEDEX AREA COMPAT PASS: %d checks"):format(checks))
