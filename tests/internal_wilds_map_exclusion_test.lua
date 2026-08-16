-- Ascendant-owned Johto Master maps are authored story arenas.  The internal
-- Wilds adapter must reject battleable, classic and ambient populations there
-- even during a hot-reloaded session that is temporarily using external Wilds.

local source = debug.getinfo(1, "S").source
local testDir = source:sub(1, 1) == "@"
  and source:sub(2):match("^(.*)/[^/]+$") or "tests"
local root = testDir:match("^(.*)/tests$") or "."

local function eq(actual, expected, message)
  if actual ~= expected then
    error(("%s\nexpected: %s\nactual:   %s")
      :format(message, tostring(expected), tostring(actual)), 2)
  end
end

local calls = {
  clear = 0, entered = 0, stepped = 0, initialized = 0,
  land = 0, water = 0, suppress = 0, collision = 0, ambient = 0,
}
local currentMap = "ROUTE_1"
local world = {
  overworld = function()
    return { map = { id = currentMap } }
  end,
}
local logic = {
  mod = { world = world },
  activeMapId = "ROUTE_1",
}
function logic:clearAll() calls.clear = calls.clear + 1 end
function logic:onMapEntered()
  calls.entered = calls.entered + 1
  self.activeMapId = currentMap
  return "entered"
end
function logic:onStepped() calls.stepped = calls.stepped + 1 return "stepped" end
function logic:initializeForMap()
  calls.initialized = calls.initialized + 1
  return true
end
function logic:trySpawn()
  calls.land = calls.land + 1
  return { species = "RATTATA" }
end
function logic:trySpawnWater()
  calls.water = calls.water + 1
  return { species = "MAGIKARP" }
end
function logic:shouldSuppressClassicEncounter()
  calls.suppress = calls.suppress + 1
  return false
end
function logic:onCollision(allowed)
  calls.collision = calls.collision + 1
  return not allowed
end

local ambient = { active = {} }
function ambient:clearAll(ow)
  for npc in pairs(self.active) do
    for _, list in ipairs({ ow and ow.npcs, ow and ow.entities }) do
      if type(list) == "table" then
        for index = #list, 1, -1 do
          if list[index] == npc then table.remove(list, index) end
        end
      end
    end
    self.active[npc] = nil
  end
end
function ambient:spawnForMap()
  calls.ambient = calls.ambient + 1
  return 2
end

local externalExports = { logic = logic, ambient = ambient }
local external = { version = "1.12.2", exports = externalExports }
local mod = {
  find = function(id)
    if id == "overworld_wild_spawns" then return external end
  end,
}
local install = assert(loadfile(root .. "/internal_wilds.lua"))()
local result = install(mod)
eq(result.bundled, false, "the fixture exercises the external hot-reload path")
eq(externalExports._kantoAscendantJohtoMapExclusion, true,
  "the Ascendant adapter installs its authored-map policy")

local protected = {
  "KA_JOHTO_GATE_HALL",
  "KA_JOHTO_SILVER_PASSAGE", "KA_JOHTO_SILVER_FINALE",
  "KA_JOHTO_KRIS_PASSAGE", "KA_JOHTO_KRIS_FINALE",
  "KA_JOHTO_GOLD_PASSAGE", "KA_JOHTO_GOLD_FINALE",
}
for _, mapId in ipairs(protected) do
  eq(externalExports.isMapExcluded(mapId), true,
    mapId .. " is covered by the prefix policy")
  currentMap = mapId
  local enteredBefore, steppedBefore = calls.entered, calls.stepped
  local initializedBefore = calls.initialized
  local landBefore, waterBefore = calls.land, calls.water
  local suppressedBefore, collisionBefore = calls.suppress, calls.collision

  local entered, enterReason = logic:onMapEntered({ mapId = mapId })
  eq(entered, nil, mapId .. " never initializes visible Wilds")
  eq(enterReason, "authored Johto map: " .. mapId,
    mapId .. " reports the deterministic exclusion")
  eq(logic.activeMapId, nil,
    mapId .. " cannot be late-initialized on world.stepped")
  eq(calls.entered, enteredBefore,
    mapId .. " bypasses Wilds' ordinary map-enter handler")

  logic:onStepped({ mapId = mapId, x = 1, y = 1 })
  eq(calls.stepped, steppedBefore,
    mapId .. " bypasses visible contact/refill processing")
  local initialized = logic:initializeForMap(mapId, {})
  eq(initialized, nil, mapId .. " rejects direct pipeline initialization")
  eq(calls.initialized, initializedBefore,
    mapId .. " cannot initialize through another Wilds caller")

  local land, landReason = logic:trySpawn({}, {})
  eq(land, nil, mapId .. " rejects a direct visible-land spawn")
  eq(landReason, "authored Johto map: " .. mapId,
    mapId .. " keeps the land rejection explicit")
  local water = logic:trySpawnWater({}, {})
  eq(water, nil, mapId .. " rejects a direct visible-water spawn")
  eq(calls.land, landBefore, mapId .. " never reaches land spawn logic")
  eq(calls.water, waterBefore, mapId .. " never reaches water spawn logic")
  eq(logic:shouldSuppressClassicEncounter({ mapId = mapId }), true,
    mapId .. " suppresses classic encounter.roll as well")
  eq(calls.suppress, suppressedBefore,
    mapId .. " does not defer to the ordinary classic-encounter setting")
  eq(logic:onCollision(true, { mapId = mapId }), true,
    mapId .. " cannot start a stale visible encounter on collision")
  eq(calls.collision, collisionBefore,
    mapId .. " bypasses Wilds collision handling")

  local npc = {}
  local ow = { map = { id = mapId }, npcs = { npc }, entities = { npc } }
  ambient.active[npc] = true
  local count, ambientReason = ambient:spawnForMap({}, ow)
  eq(count, 0, mapId .. " has no ambient population")
  eq(ambientReason, "authored Johto map: " .. mapId,
    mapId .. " keeps the ambient rejection explicit")
  eq(#ow.npcs, 0, mapId .. " removes stale ambient NPCs")
  eq(#ow.entities, 0, mapId .. " removes stale ambient entities")
end

currentMap = "ROUTE_1"
eq(externalExports.isMapExcluded(currentMap), false,
  "the prefix policy does not suppress ordinary Kanto maps")
eq(logic:onMapEntered({ mapId = currentMap }), "entered",
  "ordinary Kanto maps retain the original map-enter path")
eq(logic:trySpawn({}, {}).species, "RATTATA",
  "ordinary Kanto maps retain visible land spawns")
eq(logic:trySpawnWater({}, {}).species, "MAGIKARP",
  "ordinary Kanto maps retain visible water spawns")
eq(logic:shouldSuppressClassicEncounter({ mapId = currentMap }), false,
  "ordinary maps retain their selected classic-encounter policy")
eq(logic:onCollision(true, { mapId = currentMap }), false,
  "ordinary maps retain Wilds collision handling")
eq(ambient:spawnForMap({}, { map = { id = currentMap } }), 2,
  "ordinary safe maps retain ambient populations")

-- Re-installation during a second hot reload is idempotent, not a wrapper
-- stack that invokes or clears the provider multiple times.
install(mod)
local before = calls.entered
logic:onMapEntered({ mapId = currentMap })
eq(calls.entered, before + 1, "adapter re-installation is idempotent")

print("INTERNAL WILDS JOHTO MAP EXCLUSION PASS")
