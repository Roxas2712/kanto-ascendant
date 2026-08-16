-- Regression: importing/reloading Ascendant while already standing on an
-- authored HEVO floor must initialize visible Wilds without waiting for a
-- second map.entered/save.loaded event.  A later ordinary step may self-heal
-- missing state, but only when its map id is the real live Overworld map.

local source = debug.getinfo(1, "S").source
local testDir = source:sub(1, 1) == "@"
  and source:sub(2):match("^(.*)/[^/]+$") or "tests"
local root = testDir:match("^(.*)/tests$") or "."

local assertions = 0
local function check(value, message)
  assertions = assertions + 1
  if not value then error("FAIL: " .. message, 2) end
end
local function eq(actual, expected, message)
  assertions = assertions + 1
  if actual ~= expected then
    error(("FAIL: %s\nexpected: %s\nactual:   %s")
      :format(message, tostring(expected), tostring(actual)), 2)
  end
end

local RED_UPPER = "KA_HEVO_RED_UPPER"
local currentMapId = RED_UPPER
local overworld = {
  map = { id = currentMapId },
  player = { cellX = 5, cellY = 5 },
  entities = {}, npcs = {},
}
local world = {
  overworld = function()
    overworld.map.id = currentMapId
    return overworld
  end,
}

local game = {
  data = {
    sprites = {}, pokemon = {},
    encounters = {
      [RED_UPPER] = {
        kaEncounterSource = "hevo_dungeon",
        kaMaxVisible = 3,
        grass = {
          rate = 25,
          slots = {
            { species = "RHYDON", level = 70 },
            { species = "PILOSWINE", level = 70 },
            { species = "MAGMAR", level = 70 },
            { species = "LICKITUNG", level = 70 },
          },
        },
      },
      ROUTE_1 = {
        kaMaxVisible = 2,
        grass = {
          rate = 25,
          slots = {
            { species = "PIDGEY", level = 3 },
            { species = "RATTATA", level = 3 },
          },
        },
      },
    },
  },
  save = { options = {} },
  mods = { exports = {} },
}
world.game = game

local logic = {
  mod = { world = world },
  activeMapId = nil,
  state = nil,
  spawns = {},
  byMap = {},
  enterCalls = 0,
  stepCalls = 0,
}
function logic:clearAll()
  self.spawns = {}
  self.byMap = {}
end
function logic:trySpawn(spawnGame, opts)
  local mapId = self.activeMapId
  local def = spawnGame.data.encounters[mapId]
  local cap = def and def.kaMaxVisible or 0
  local rows = self.byMap[mapId] or {}
  self.byMap[mapId] = rows
  if #rows >= cap then return nil end
  local id = "fixture_wild_" .. tostring(#rows + 1)
  local record = {
    id = id, mapId = mapId,
    species = opts.species,
    level = opts.level,
  }
  rows[#rows + 1] = id
  self.spawns[id] = record
  return record
end
function logic:onMapEntered(ev)
  self.enterCalls = self.enterCalls + 1
  self.activeMapId = ev.mapId
  self.state = { mapId = ev.mapId, initialized = true }
  self.spawns = {}
  self.byMap[ev.mapId] = {}
  local def = game.data.encounters[ev.mapId]
  local slots = def and def.grass and def.grass.slots or {}
  local cap = def and def.kaMaxVisible or 0
  for index = 1, math.min(cap, #slots) do
    local slot = slots[index]
    self:trySpawn(game, { species = slot.species, level = slot.level })
  end
end
function logic:onStepped(ev)
  self.stepCalls = self.stepCalls + 1
  if self.activeMapId ~= (ev and ev.mapId) then return nil end
  return true
end
function logic:onSaveLoaded()
  self:clearAll()
  self.activeMapId = nil
  self.state = nil
  self:onMapEntered({ mapId = currentMapId, map = overworld.map })
end
function logic:initializeForMap(mapId)
  self.state = { mapId = mapId, initialized = true }
  return true
end

local external = {
  version = "1.12.2",
  logic = logic,
}
game.mods.exports.overworld_wild_spawns = external

local handlers = {}
local mod = {
  id = "kanto_ascendant",
  exports = {},
  options = {
    get = function(_, key)
      if key == "johto_wilds_integration" then return false end
      return nil
    end,
  },
  events = {
    on = function(_, name, fn)
      handlers[name] = handlers[name] or {}
      handlers[name][#handlers[name] + 1] = fn
    end,
  },
  log = {
    info = function() end,
    warn = function() end,
  },
  find = function(id)
    if id == "overworld_wild_spawns" then
      return { version = external.version, exports = external }
    end
  end,
}

local installInternal = assert(loadfile(root .. "/internal_wilds.lua"))()
local internal = installInternal(mod)
eq(internal.bundled, false,
  "fixture exercises the already-running external/hot-import surface")

local createCompat = assert(loadfile(root .. "/wilds_compat.lua"))()
local function newCompat()
  return createCompat(mod, {
    johtoResearch = {
      rollHabitat = function() return nil end,
      encounterLevels = { routeAverage = function() return nil end },
    },
    johtoSignals = { allowedSpeciesPool = function() return {} end },
    data = {},
    contentEnabled = false,
  })
end

-- No map.entered/save.loaded event is emitted after this point.  Installing
-- compatibility on the already-open HEVO floor must still initialize it.
local compat = newCompat()
eq(compat.install(game), true, "first hot import installs compatibility")
eq(logic.enterCalls, 1,
  "hot import initializes the already-open HEVO map exactly once")
eq(logic.activeMapId, RED_UPPER,
  "hot import adopts the real current HEVO map")
eq(logic.state.mapId, RED_UPPER,
  "hot import creates map-coherent Wilds state")
local redRows = logic.byMap[RED_UPPER]
check(#redRows > 0 and #redRows <= 3,
  "hot import permits visible HEVO spawns within kaMaxVisible")
for _, id in ipairs(redRows) do
  eq(logic.spawns[id].level, 70,
    "every first-cycle visible HEVO spawn keeps level 70")
end

-- A newly constructed compatibility adapter models a second full dev reload:
-- the provider is already wrapped, so W.install takes its early-return path.
local beforeIds = table.concat(redRows, ",")
local compatReloaded = newCompat()
eq(compatReloaded.install(game), true,
  "second hot reload reuses the existing compatibility wrapper")
eq(logic.enterCalls, 1,
  "second hot reload does not replay coherent map initialization")
eq(table.concat(logic.byMap[RED_UPPER], ","), beforeIds,
  "second hot reload neither clears nor duplicates visible spawns")

-- Simulate the precise broken state from the report.  The first ordinary
-- step on the exact live map repairs it before delegating to Wilds' original
-- step handler.
logic.activeMapId = nil
logic.state = nil
logic.spawns = {}
logic.byMap = {}
local entersBeforeHeal = logic.enterCalls
eq(logic:onStepped({ mapId = RED_UPPER, x = 6, y = 5 }), true,
  "an ordinary live-map step continues after recovery")
eq(logic.enterCalls, entersBeforeHeal + 1,
  "the first exact live-map step performs one recovery initialization")
eq(#logic.byMap[RED_UPPER], 3,
  "step recovery restores the capped visible HEVO population")
for _, id in ipairs(logic.byMap[RED_UPPER]) do
  eq(logic.spawns[id].level, 70,
    "step recovery preserves first-cycle level 70")
end

local entersAfterHeal = logic.enterCalls
logic:onStepped({ mapId = RED_UPPER, x = 7, y = 5 })
eq(logic.enterCalls, entersAfterHeal,
  "later steps do not repeat coherent recovery")

-- A delayed event from another map is never allowed to clear or initialize
-- the live floor.
logic:onStepped({ mapId = "ROUTE_1", x = 1, y = 1 })
eq(logic.enterCalls, entersAfterHeal,
  "a stale foreign-map step cannot trigger recovery")
eq(logic.activeMapId, RED_UPPER,
  "a stale foreign-map step cannot replace the active map")

-- Ordinary map entry/switch remains the sole owner when the engine actually
-- changes maps, and coherent steps on the new map stay no-ops for recovery.
currentMapId = "ROUTE_1"
logic:onMapEntered({ mapId = "ROUTE_1", map = overworld.map })
local afterSwitch = logic.enterCalls
eq(logic.activeMapId, "ROUTE_1", "ordinary map switch still works")
eq(#logic.byMap.ROUTE_1, 2,
  "ordinary map switch keeps its normal visible-spawn cap")
logic:onStepped({ mapId = "ROUTE_1", x = 2, y = 2 })
eq(logic.enterCalls, afterSwitch,
  "ordinary coherent map steps remain unchanged")

local beforeSaveLoad = logic.enterCalls
logic:onSaveLoaded()
eq(logic.enterCalls, beforeSaveLoad + 1,
  "ordinary save-loaded initialization remains exactly once")
eq(#logic.byMap.ROUTE_1, 2,
  "ordinary save-loaded initialization keeps one capped population")
local afterSaveLoad = logic.enterCalls
logic:onStepped({ mapId = "ROUTE_1", x = 3, y = 2 })
eq(logic.enterCalls, afterSaveLoad,
  "the next step does not duplicate save-loaded initialization")

print(("INTERNAL WILDS HOT IMPORT PASS: %d assertions"):format(assertions))
