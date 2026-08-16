-- Regression for rare early Kanto-starter habitats in an active Legacy run.

local modulePath = os.getenv("KANTO_ASCENDANT_MOD_DIR") or "."
local makeCompletion = assert(loadfile(modulePath .. "/kanto_completion.lua"))()

local assertions = 0
local function eq(actual, expected, label)
  assertions = assertions + 1
  if actual ~= expected then
    error(("FAIL: %s\nexpected: %s\nactual:   %s")
      :format(label, tostring(expected), tostring(actual)), 2)
  end
end

local function newHarness(edition)
  local hooks, saved = {}, {}
  local active = false
  local mod = {
    id = "kanto_ascendant",
    options = { get = function(_, key)
      if key == "kanto_151" then return "off" end
    end },
    save = {
      get = function(_, key) return saved[key] end,
      set = function(_, key, value) saved[key] = value end,
    },
    hooks = { wrap = function(_, name, fn, priority)
      hooks[name] = hooks[name] or {}
      hooks[name][#hooks[name] + 1] = { fn = fn, priority = priority }
    end },
    events = { on = function() end },
    log = { info = function() end, warn = function() end },
    content = {},
  }
  local journey = {
    isActive = function(save)
      return active and save and save.version == edition
    end,
  }
  local completion = makeCompletion(mod, {
    contentEnabled = true, legacyJourney = journey,
  })
  local game = { save = { version = edition } }
  completion.install(game)
  return {
    completion = completion,
    game = game,
    hooks = hooks,
    saved = saved,
    setActive = function(value) active = value == true end,
  }
end

local habitats = {
  { map = "VIRIDIAN_FOREST", species = "BULBASAUR", level = 5 },
  { map = "ROUTE_4", species = "CHARMANDER", level = 7 },
  { map = "ROUTE_24", species = "SQUIRTLE", level = 9 },
}

for _, edition in ipairs({ "red", "blue", "yellow" }) do
  local h = newHarness(edition)
  local roll
  for _, row in ipairs(h.hooks["encounter.roll"] or {}) do
    if row.priority == -15 then roll = row end
  end
  eq(type(roll and roll.fn), "function",
    edition .. " installs the ordinary encounter wrapper")
  eq(roll.priority, -15,
    edition .. " keeps authored high-priority encounters outside the habitat")

  local native = { species = "PIDGEY", level = 4 }
  local function call(mapId, draw, output, terrain)
    return roll.fn(function() return output or native end, {}, {
      mapId = mapId, terrain = terrain or "grass",
      rng = function(low, high)
        eq(low, 1, edition .. " chance lower bound")
        eq(high, 100, edition .. " chance upper bound")
        return draw
      end,
    })
  end

  local inactive = call("VIRIDIAN_FOREST", 1)
  eq(inactive.species, "PIDGEY",
    edition .. " ordinary saves never receive Legacy starter habitats")
  eq(h.saved.legacy_early_starters, nil,
    edition .. " inactive rolls do not create migration state")
  local inactiveCharmander = call("ROUTE_4", 1)
  eq(inactiveCharmander.species, "PIDGEY",
    edition .. " standard Route 4 stays native outside Legacy")
  eq(h.saved.legacy_early_starters, nil,
    edition .. " inactive Route 4 creates no Legacy state")

  h.setActive(true)
  for _, row in ipairs(habitats) do
    local rare = call(row.map, 2)
    eq(rare.species, row.species,
      edition .. " exposes " .. row.species .. " in its early habitat")
    eq(rare.level, row.level,
      edition .. " uses the authored early level for " .. row.species)
    eq(rare.kaProtected, nil,
      edition .. " leaves " .. row.species .. " visible to Randomizer/Nuzlocke")
  end

  local wrongTerrain = call("ROUTE_24", 1, native, "water")
  eq(wrongTerrain.species, "PIDGEY",
    edition .. " Squirtle habitat does not replace fishing or surfing")
  local wrongMap = call("ROUTE_1", 1)
  eq(wrongMap.species, "PIDGEY",
    edition .. " unrelated early routes remain native")
  local oldCharmanderMap = call("ROUTE_3", 1)
  eq(oldCharmanderMap.species, "PIDGEY",
    edition .. " Route 3 no longer exposes early Charmander")

  local protected = call("ROUTE_4", 1, {
    species = "MEW", level = 5, kaProtected = true,
  })
  eq(protected.species, "MEW",
    edition .. " never replaces an authored protected encounter")

  -- Each habitat has an independent 50-encounter ceiling. A reload retains
  -- the in-save counter because the state lives in modData, not module globals.
  h.saved.legacy_early_starters.pity.VIRIDIAN_FOREST = 48
  local fortyNine = call("VIRIDIAN_FOREST", 100)
  eq(fortyNine.species, "PIDGEY",
    edition .. " pity cannot trigger before encounter fifty")
  local fifty = call("VIRIDIAN_FOREST", 100)
  eq(fifty.species, "BULBASAUR",
    edition .. " encounter fifty ends an unlucky Bulbasaur streak")
  eq(h.saved.legacy_early_starters.pity.VIRIDIAN_FOREST, 0,
    edition .. " successful habitat roll resets only its pity")

  h.saved.legacy_early_starters.pity.ROUTE_4 = 48
  h.saved.legacy_early_starters.pity.ROUTE_24 = 17
  local charmFortyNine = call("ROUTE_4", 100)
  eq(charmFortyNine.species, "PIDGEY",
    edition .. " Charmander pity cannot trigger before encounter fifty")
  eq(h.saved.legacy_early_starters.pity.ROUTE_4, 49,
    edition .. " Route 4 retains its own Charmander pity")
  eq(h.saved.legacy_early_starters.pity.ROUTE_24, 17,
    edition .. " Charmander rolls do not change Squirtle pity")
  local charmFifty = call("ROUTE_4", 100)
  eq(charmFifty.species, "CHARMANDER",
    edition .. " Route 4 encounter fifty ends an unlucky Charmander streak")
  eq(h.saved.legacy_early_starters.pity.ROUTE_4, 0,
    edition .. " successful Charmander roll resets only Route 4 pity")
  eq(h.saved.legacy_early_starters.pity.ROUTE_24, 17,
    edition .. " successful Charmander roll preserves Squirtle pity")

  -- The result remains an ordinary encounter record. Integrated Randomizer
  -- and Nuzlocke processors therefore see it through their normal downstream
  -- hooks instead of treating it as an authored/protected encounter.
  local passthrough = call("ROUTE_4", 1)
  eq(passthrough.species, "CHARMANDER",
    edition .. " produces the ordinary Charmander proposal")
  eq(passthrough.kaProtected, nil,
    edition .. " Charmander stays visible to Randomizer")
  eq(passthrough.kaEncounterSource, nil,
    edition .. " Charmander stays visible to Nuzlocke encounter rules")

  eq(h.completion.wildEncounters.SAFARI_ZONE_EAST[10].species,
    "BULBASAUR", edition .. " keeps guaranteed late Bulbasaur")
  eq(h.completion.wildEncounters.SEAFOAM_ISLANDS_B2F[10].species,
    "SQUIRTLE", edition .. " keeps guaranteed late Squirtle")
  eq(h.completion.wildEncounters.VICTORY_ROAD_3F[10].species,
    "CHARMANDER", edition .. " keeps guaranteed late Charmander")
end

print(("PASS Legacy early starters: %d assertions"):format(assertions))
