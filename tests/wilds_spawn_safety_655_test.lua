-- 6.5.5 P0 regression: Wilds may decorate the world, but never occupy a
-- story-critical cell.  This covers the exact two-Pokémon Oak's Lab report,
-- map topology, load/re-entry repair and the public external-provider seam.

local source = debug.getinfo(1, "S").source
local testDir = source:sub(1, 1) == "@"
  and source:sub(2):match("^(.*)/[^/]+$") or "tests"
local root = testDir:match("^(.*)/tests$") or "."

local assertions = 0
local OAKS_LAB = "OAKS_LAB"
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

local function key(x, y) return tostring(x) .. ":" .. tostring(y) end

local function makeMap(id, rows, def)
  local map = {
    id = id,
    widthCells = #rows[1],
    heightCells = #rows,
    def = def or {},
  }
  function map:inBounds(x, y)
    return x >= 0 and y >= 0 and x < self.widthCells and y < self.heightCells
  end
  function map:isWalkableCell(x, y)
    return self:inBounds(x, y) and rows[y + 1]:sub(x + 1, x + 1) ~= "#"
  end
  function map:isWaterCell(x, y)
    return self:inBounds(x, y) and rows[y + 1]:sub(x + 1, x + 1) == "~"
  end
  function map:isGrassCell(x, y)
    return self:inBounds(x, y) and rows[y + 1]:sub(x + 1, x + 1) == "."
  end
  local warps, doors, warpTiles, warpPads, counters = {}, {}, {}, {}, {}
  for _, row in pairs(map.def.warps or {}) do
    warps[key(row.x, row.y)] = row
  end
  for _, row in pairs(map.def.doors or {}) do doors[key(row.x, row.y)] = true end
  for _, row in pairs(map.def.warpTiles or {}) do
    warpTiles[key(row.x, row.y)] = true
  end
  for _, row in pairs(map.def.warpPads or {}) do
    warpPads[key(row.x, row.y)] = row.kind or "pad"
  end
  for _, row in pairs(map.def.counters or {}) do
    counters[key(row.x, row.y)] = true
  end
  function map:warpAtCell(x, y) return warps[key(x, y)] end
  function map:isDoorTileCell(x, y) return doors[key(x, y)] == true end
  function map:isWarpTileCell(x, y) return warpTiles[key(x, y)] == true end
  function map:warpPadOrHoleAt(x, y) return warpPads[key(x, y)] end
  function map:isCounterCell(x, y) return counters[key(x, y)] == true end
  return map
end

local handlers = {}
local logs = {}
local mod = {
  id = "kanto_ascendant",
  events = {
    on = function(_, name, fn)
      handlers[name] = handlers[name] or {}
      handlers[name][#handlers[name] + 1] = fn
    end,
  },
  log = {
    info = function(_, fmt, ...)
      logs[#logs + 1] = string.format(fmt, ...)
    end,
  },
}
local safety = assert(loadfile(root .. "/wilds_spawn_safety.lua"))()(mod)

-- main.lua publishes the two non-ROM Oak terminal halves as interactables,
-- including their use cells, and the separate fresh-run story landing.
safety.reserveCells(OAKS_LAB, {
  { x = 0, y = 1, approaches = true },
  { x = 1, y = 1, approaches = true },
  { x = 5, y = 5 },
}, "Ascendant Oak's Lab scripted position")

local oakRows = {
  "#########",
  "#.......#",
  "#.......#",
  "#.......#",
  "#.......#",
  "#.......#",
  "####.####",
}
local oakDef = {
  warps = { { x = 4, y = 6, destMap = "PALLET_TOWN" } },
  objects = {
    { x = 3, y = 2, id = "STARTER_BALL_LEFT" },
    { x = 4, y = 2, id = "STARTER_BALL_CENTER" },
    { x = 5, y = 2, id = "STARTER_BALL_RIGHT" },
    { x = 4, y = 1, id = "OAK" },
  },
  signs = { { x = 1, y = 1, text = "LAB_SWITCH" } },
}

local function guardedSave(edition, starter)
  local flagState = { EVENT_GOT_STARTER = starter == true }
  local flags = setmetatable({}, {
    __index = flagState,
    __newindex = function(_, k)
      error("safety attempted to write save flag " .. tostring(k))
    end,
  })
  local state = {
    flags = flags,
    edition = edition,
    randomizer = { seed = 12345, enabled = true },
    nuzlocke = { enabled = true, fainted = {} },
  }
  local save = setmetatable({}, {
    __index = state,
    __newindex = function(_, k)
      error("safety attempted to write save field " .. tostring(k))
    end,
  })
  return save, flagState
end

local function removeFrom(list, target)
  for i = #list, 1, -1 do
    if list[i] == target then table.remove(list, i) end
  end
end

local function makeProvider(owner, game, ow)
  local calls = {
    owner = owner,
    entered = 0,
    stepped = 0,
    spawned = 0,
    ambient = 0,
    reserveSpawn = 0,
    reserveMove = 0,
    clear = 0,
    despawn = 0,
  }
  local occupancy = {}
  function occupancy:reserveSpawn(token, x, y)
    calls.reserveSpawn = calls.reserveSpawn + 1
    return token or "fixture-token", nil
  end
  function occupancy:reserveMove()
    calls.reserveMove = calls.reserveMove + 1
    return true
  end
  function occupancy:releaseEntity() end

  local logic = {
    mod = { world = {
      game = game,
      overworld = function() return ow end,
    } },
    activeMapId = ow.map.id,
    occupancy = occupancy,
    spawns = {}, entities = {}, byMap = { [ow.map.id] = {} },
  }
  function logic:clearAll()
    calls.clear = calls.clear + 1
    for id in pairs(self.spawns) do self:_despawn(id, true) end
  end
  function logic:rebuildOccupancy() return self.occupancy end
  function logic:onMapEntered(ev)
    calls.entered = calls.entered + 1
    self.activeMapId = ev.mapId
    return true
  end
  function logic:onStepped()
    calls.stepped = calls.stepped + 1
    return true
  end
  function logic:onSaveLoaded() return true end
  function logic:onMapReloaded() return true end
  function logic:_despawn(id)
    calls.despawn = calls.despawn + 1
    local entity = self.entities[id]
    local record = self.spawns[id]
    removeFrom(ow.entities, entity)
    removeFrom(ow.npcs, entity)
    self.entities[id], self.spawns[id] = nil, nil
    local list = record and self.byMap[record.mapId]
    if list then
      for i = #list, 1, -1 do if list[i] == id then table.remove(list, i) end end
    end
  end
  function logic:trySpawn(_, opts)
    calls.spawned = calls.spawned + 1
    local id = owner .. "_spawn_" .. tostring(calls.spawned)
    local x, y = opts and opts.x or 3, opts and opts.y or 4
    local entity = {
      id = id, cellX = x, cellY = y, overworldWildSpawn = true,
    }
    local record = { id = id, mapId = ow.map.id, x = x, y = y }
    self.entities[id], self.spawns[id] = entity, record
    self.byMap[ow.map.id] = self.byMap[ow.map.id] or {}
    self.byMap[ow.map.id][#self.byMap[ow.map.id] + 1] = id
    ow.entities[#ow.entities + 1] = entity
    return record, nil, entity
  end
  logic.trySpawnWater = logic.trySpawn

  local ambient = { active = {}, activeMapId = nil }
  function ambient:removeNpc(liveOw, npc)
    removeFrom(liveOw.npcs, npc)
    removeFrom(liveOw.entities, npc)
    self.active[npc] = nil
  end
  function ambient:clearAll(liveOw)
    local pending = {}
    for npc in pairs(self.active) do pending[#pending + 1] = npc end
    for _, npc in ipairs(pending) do self:removeNpc(liveOw, npc) end
  end
  function ambient:findSpawnCell() return 4, 3 end
  function ambient:_makeNpc(_, _, species, x, y)
    return {
      id = owner .. "_ambient_" .. species,
      cellX = x, cellY = y,
      px = x * 16, py = y * 16,
      wildsAmbientPokemon = true,
      update = function(self)
        if self.requestMoveX ~= nil and self.requestMoveY ~= nil then
          self.targetX, self.targetY = self.requestMoveX, self.requestMoveY
          self.moving, self.progress = true, 1
          self.px, self.py = self.px + 1, self.py + 1
        end
      end,
    }
  end
  function ambient:spawnForMap(activeGame, liveOw)
    calls.ambient = calls.ambient + 1
    local x, y = self:findSpawnCell(liveOw, liveOw.map)
    if not x then return 0 end
    local npc = self:_makeNpc(activeGame, liveOw, "PIKACHU", x, y)
    self.active[npc] = true
    liveOw.npcs[#liveOw.npcs + 1] = npc
    liveOw.entities[#liveOw.entities + 1] = npc
    return 1
  end

  local grass = {}
  function grass.validateSpawnTile() return true end
  function grass.validateWalkableTile() return true end
  function grass.validateEligibleTile() return true end
  local provider = {
    version = owner == "internal" and "1.12.2" or "1.99.0",
    logic = logic,
    ambient = ambient,
    lib = {
      require = function(name)
        if name == "grass" then return grass end
      end,
    },
  }
  return provider, calls, grass
end

-- Exact report: on a brand-new Red/Blue/Yellow save two blocking ambient
-- Pokémon are already in Oak's Lab before the player can choose a starter.
for _, edition in ipairs({ "RED", "BLUE", "YELLOW" }) do
  local game = { save = guardedSave(edition, false), data = { maps = {} } }
  local map = makeMap(OAKS_LAB, oakRows, oakDef)
  local ow = { map = map, player = { cellX = 4, cellY = 5 }, entities = {}, npcs = {} }
  local provider, calls = makeProvider("external_" .. edition, game, ow)

  local first = { id = "blocking_one", cellX = 4, cellY = 4,
    wildsAmbientPokemon = true }
  local second = { id = "blocking_two", cellX = 4, cellY = 3,
    wildsAmbientPokemon = true }
  provider.ambient.active[first], provider.ambient.active[second] = true, true
  ow.entities = { first, second }
  ow.npcs = { first, second }

  eq(safety.install(provider, game), true,
    edition .. " installs through the external public owner")
  local count, reason = provider.ambient:spawnForMap(game, ow)
  eq(count, 0, edition .. " has zero Wilds before starter selection")
  eq(reason, safety.STARTER_REASON,
    edition .. " reports the deterministic starter gate")
  eq(calls.ambient, 0,
    edition .. " never invokes Wilds ambient RNG before starter selection")
  eq(#ow.entities, 0, edition .. " removes both persisted blocking bodies")
  eq(#ow.npcs, 0, edition .. " removes both persisted blocking NPC entries")
  eq(next(provider.ambient.active), nil,
    edition .. " clears the ambient owner index without touching the save")
  eq(game.save.randomizer.seed, 12345,
    edition .. " keeps the randomizer seed unchanged")
  eq(game.save.nuzlocke.enabled, true,
    edition .. " keeps Nuzlocke authority unchanged")

  local spawn, spawnReason = provider.logic:trySpawn(game, { x = 4, y = 4 })
  eq(spawn, nil, edition .. " rejects direct battleable Wilds too")
  eq(spawnReason, safety.STARTER_REASON,
    edition .. " shares one gate across ambient and battleable owners")
  eq(calls.spawned, 0,
    edition .. " never reaches encounter/species selection while gated")
end

-- The exact gate lifts on the existing save without requiring a reset.  Static
-- balls, their approach cells, the exit and active story actors stay reserved.
do
  local game = { save = guardedSave("YELLOW", true), data = { maps = {} } }
  local map = makeMap(OAKS_LAB, oakRows, oakDef)
  local oak = { id = "OAK", cellX = 4, cellY = 1 }
  local ow = {
    map = map,
    player = { cellX = 4, cellY = 5 },
    entities = { oak }, npcs = { oak },
  }
  local safe, unsafe
  safe = safety.isSafeCell(game, ow, map, 1, 4)
  check(safe, "an ordinary open post-starter lab cell remains available")
  unsafe = safety.isSafeCell(game, ow, map, 4, 2)
  eq(unsafe, false, "the center starter ball tile is protected")
  unsafe = safety.isSafeCell(game, ow, map, 4, 3)
  eq(unsafe, false, "the center starter ball approach is protected")
  unsafe = safety.isSafeCell(game, ow, map, 4, 6)
  eq(unsafe, false, "the lab exit warp is protected")
  unsafe = safety.isSafeCell(game, ow, map, 4, 5)
  eq(unsafe, false, "the live player/story-spawn cell is protected")
  unsafe = safety.isSafeCell(game, ow, map, 4, 1)
  eq(unsafe, false, "Oak's current and authored NPC cell is protected")
end

-- The KASC terminal is absent from the ROM object table and is operated from
-- row 2.  The real map has walkable cells at both x=0 and x=1 there, so merely
-- reserving the two terminal targets would still allow Wilds to block use.
do
  local game = { save = guardedSave("RED", true), data = { maps = {} } }
  local map = makeMap(OAKS_LAB, {
    "#########", "........#", "........#", "........#",
    "........#", "........#", "####.####",
  }, {})
  local ow = {
    map = map, player = { cellX = 7, cellY = 5 }, entities = {}, npcs = {},
  }
  eq(safety.isSafeCell(game, ow, map, 0, 2), false,
    "left KASC terminal use cell is protected after starter selection")
  eq(safety.isSafeCell(game, ow, map, 1, 2), false,
    "right KASC terminal use cell is protected after starter selection")
  eq(safety.isSafeCell(game, ow, map, 3, 4), true,
    "ordinary post-starter Lab floor remains eligible")
end

-- Map matrix: the policy is not lab-specific after the starter.  All map
-- classes use the same authored/runtime cell rules while ordinary open cells
-- remain valid.
for _, row in ipairs({
  { id = "PALLET_TOWN", type = "town" },
  { id = "REDS_HOUSE_1F", type = "house" },
  { id = "OAKS_LAB", type = "lab" },
  { id = "MT_MOON_1F", type = "cave" },
}) do
  local game = { save = guardedSave("RED", true), data = { maps = {} } }
  local map = makeMap(row.id, {
    "#########", "#.......#", "#.......#", "#.......#",
    "#.......#", "#.......#", "####.####",
  }, {
    warps = { { x = 4, y = 6 } },
    objects = { { x = 1, y = 1, id = "ITEM_BALL" } },
    signs = { { x = 7, y = 1, id = "SWITCH" } },
    doors = { { x = 2, y = 5 } },
    warpTiles = { { x = 6, y = 5 } },
    warpPads = { { x = 4, y = 1, kind = "pad" } },
  })
  local ow = { map = map, player = { cellX = 1, cellY = 5 }, entities = {}, npcs = {} }
  eq(safety.isSafeCell(game, ow, map, 4, 3), true,
    row.type .. " keeps an ordinary open cell")
  eq(safety.isSafeCell(game, ow, map, 1, 1), false,
    row.type .. " protects item/ball cells")
  eq(safety.isSafeCell(game, ow, map, 7, 1), false,
    row.type .. " protects switch/sign cells")
  eq(safety.isSafeCell(game, ow, map, 4, 6), false,
    row.type .. " protects entrances/exits")
  eq(safety.isSafeCell(game, ow, map, 2, 5), false,
    row.type .. " protects native engine door tiles")
  eq(safety.isSafeCell(game, ow, map, 6, 5), false,
    row.type .. " protects native engine warp tiles")
  eq(safety.isSafeCell(game, ow, map, 4, 1), false,
    row.type .. " protects native engine warp pads and holes")
end

-- Discord regression: a visible Wilds body could occupy the inner mouth of
-- Viridian's north connection even though the boundary row itself was
-- protected.  The real entrance is wider than a graph articulation, so the
-- topology-only guard cannot infer that these are player landing/approach
-- cells.  Explicit map connections must retain a short, full-width inward
-- clearance lane and repair an already persisted body there.
do
  local game = { save = guardedSave("RED", true), data = { maps = {} } }
  local map = makeMap("VIRIDIAN_CITY", {
    "###...###",
    "###..####",
    "###...###",
    "###...###",
    "#.......#",
    "#.......#",
    "#########",
  }, {
    connections = { north = { map = "ROUTE_2", offset = 0 } },
  })
  local ow = {
    map = map,
    player = { cellX = 1, cellY = 5 },
    entities = {}, npcs = {},
  }
  eq(safety.isSafeCell(game, ow, map, 3, 2), false,
    "Viridian north landing lane is protected two cells inside the map")
  eq(safety.isSafeCell(game, ow, map, 5, 3), false,
    "Viridian north entrance keeps its full approach width clear")
  eq(safety.isSafeCell(game, ow, map, 7, 4), true,
    "ordinary Viridian town space remains eligible for Wilds")

  local provider = makeProvider("viridian_north_regression", game, ow)
  safety.install(provider, game)
  local blocking = {
    id = "viridian_north_blocker", cellX = 3, cellY = 2,
    overworldWildSpawn = true,
  }
  provider.logic.spawns[blocking.id] = {
    id = blocking.id, mapId = map.id, x = 3, y = 2,
  }
  provider.logic.entities[blocking.id] = blocking
  provider.logic.byMap[map.id] = { blocking.id }
  ow.entities = { blocking }
  eq(safety.repair(provider, game, ow, "Viridian north connection").despawned, 1,
    "load repair removes a Wilds body already blocking the north entrance")
  eq(provider.logic.spawns[blocking.id], nil,
    "persisted Viridian north blocker is removed from provider state")
end

-- Exact graph articulation, not a broad indoor ban: the one-cell bridge is
-- unsafe while both open rooms retain valid population space.
do
  local game = { save = guardedSave("BLUE", true), data = { maps = {} } }
  local map = makeMap("CRITICAL_CORRIDOR_FIXTURE", {
    "#########",
    "#..###..#",
    "#.......#",
    "#..###..#",
    "#########",
  }, {})
  local ow = { map = map, player = nil, entities = {}, npcs = {} }
  eq(safety.isSafeCell(game, ow, map, 4, 2), false,
    "the one-tile critical bridge is protected")
  eq(safety.isSafeCell(game, ow, map, 1, 1), true,
    "the left open room remains a valid spawn area")
  eq(safety.isSafeCell(game, ow, map, 7, 3), true,
    "the right open room remains a valid spawn area")
end

-- Persisted-state repair is deterministic, idempotent and write-free. It
-- removes an unsafe battleable spawn and an orphan ambient body but preserves
-- a valid ordinary spawn. The same fixture exercises the bundled owner name.
do
  local game = { save = guardedSave("RED", true), data = { maps = {} } }
  local map = makeMap("VIRIDIAN_CITY", {
    "#########", "#.......#", "#.......#", "#.......#",
    "#.......#", "#.......#", "####.####",
  }, {
    warps = { { x = 4, y = 6 } },
    objects = { { x = 1, y = 1, id = "NPC_SCRIPT_TARGET" } },
  })
  local ow = { map = map, player = { cellX = 7, cellY = 5 }, entities = {}, npcs = {} }
  local provider, calls = makeProvider("internal", game, ow)
  safety.install(provider, game)

  local bad = { id = "bad", cellX = 1, cellY = 1, overworldWildSpawn = true }
  local good = { id = "good", cellX = 4, cellY = 3, overworldWildSpawn = true }
  local moving = { id = "moving", cellX = 3, cellY = 3,
    targetX = 1, targetY = 1, overworldWildSpawn = true }
  provider.logic.spawns.bad = { id = "bad", mapId = map.id, x = 1, y = 1 }
  provider.logic.spawns.good = { id = "good", mapId = map.id, x = 4, y = 3 }
  provider.logic.spawns.moving = { id = "moving", mapId = map.id,
    x = 3, y = 3, targetX = 1, targetY = 1 }
  provider.logic.entities.bad, provider.logic.entities.good = bad, good
  provider.logic.entities.moving = moving
  provider.logic.byMap[map.id] = { "bad", "good", "moving" }
  local orphan = { id = "orphan", cellX = 4, cellY = 6,
    wildsAmbientPokemon = true }
  local orphanBattleable = { id = "orphan_battleable", cellX = 1, cellY = 1,
    overworldWildSpawn = true }
  ow.entities = { bad, good, moving, orphan, orphanBattleable }
  ow.npcs = { orphan }

  local result = safety.repair(provider, game, ow, "persisted fixture")
  eq(result.despawned, 4,
    "repair removes unsafe current/target logic plus both orphan body types")
  eq(provider.logic.spawns.bad, nil, "unsafe persisted logic record is removed")
  eq(provider.logic.spawns.moving, nil,
    "persisted movement toward a protected target is removed")
  check(provider.logic.spawns.good ~= nil,
    "ordinary valid persisted logic record remains")
  eq(#ow.entities, 1, "only the ordinary valid body remains in world entities")
  eq(ow.entities[1], good, "the preserved body is the known safe spawn")
  eq(#ow.npcs, 0, "orphan unsafe ambient NPC entry is removed")
  eq(game.save.randomizer.seed, 12345, "repair does not rewrite save state")
  eq(safety.repair(provider, game, ow, "repeat").despawned, 0,
    "repair is idempotent on re-entry/save reload")
  eq(calls.despawn, 2, "the provider's own despawn API owns logic cleanup")
end

-- Load/reload repair is write-independent.  Even a failing persistence
-- backend is never called, and the same deterministic cleanup runs through
-- both provider lifecycle seams.
do
  local writeCalls = 0
  local game = {
    save = guardedSave("BLUE", true), data = { maps = {} },
    writeSave = function()
      writeCalls = writeCalls + 1
      return false
    end,
  }
  local map = makeMap("LOAD_REPAIR_FIXTURE", {
    "#####", "#...#", "#...#", "#...#", "#####",
  }, { objects = { { x = 1, y = 1, id = "EVENT_TILE" } } })
  local ow = { map = map, player = { cellX = 3, cellY = 3 }, entities = {}, npcs = {} }
  local provider = makeProvider("load_repair", game, ow)
  safety.install(provider, game)

  local function inject(id)
    local body = { id = id, cellX = 1, cellY = 1,
      overworldWildSpawn = true }
    provider.logic.spawns[id] = { id = id, mapId = map.id, x = 1, y = 1 }
    provider.logic.entities[id] = body
    provider.logic.byMap[map.id][#provider.logic.byMap[map.id] + 1] = id
    ow.entities[#ow.entities + 1] = body
  end
  inject("loaded_bad")
  provider.logic:onSaveLoaded()
  eq(provider.logic.spawns.loaded_bad, nil,
    "save-load lifecycle repairs a persisted unsafe body")
  inject("reloaded_bad")
  provider.logic:onMapReloaded({ mapId = map.id, map = map })
  eq(provider.logic.spawns.reloaded_bad, nil,
    "map-reload lifecycle repairs a persisted unsafe body")
  eq(writeCalls, 0,
    "repair never calls a failing save backend")
end

-- The seam rejects protected reservation/movement before entity creation, but
-- delegates a safe spawn exactly once. Species/level selection and run rules
-- remain provider-owned: the safety layer never invokes a randomizer or edits
-- its seed.
do
  local game = { save = guardedSave("BLUE", true), data = { maps = {} } }
  local map = makeMap("ROUTE_1", {
    "#######", "#.....#", "#.....#", "#.....#", "#.....#",
    "#.....#", "#######",
  }, { objects = { { x = 1, y = 1, id = "ITEM" } } })
  local ow = { map = map, player = { cellX = 5, cellY = 5 }, entities = {}, npcs = {} }
  local provider, calls, grass = makeProvider("external", game, ow)
  safety.install(provider, game)

  local token, why = provider.logic.occupancy:reserveSpawn(nil, 1, 1)
  eq(token, nil, "protected item cell is rejected at atomic reservation")
  check(why:find("protected story cell", 1, true) ~= nil,
    "reservation rejection keeps an explicit diagnostic")
  eq(calls.reserveSpawn, 0, "unsafe reservation never reaches Wilds")
  eq(provider.logic.occupancy:reserveSpawn(nil, 3, 3), "fixture-token",
    "ordinary reservation delegates to Wilds")
  eq(calls.reserveSpawn, 1, "safe reservation delegates exactly once")

  eq(provider.logic.occupancy:reserveMove({ id = "wild" }, 3, 3, 1, 1), false,
    "wandering/chasing Wilds cannot enter a protected story cell")
  eq(calls.reserveMove, 0, "unsafe movement never reaches Wilds")
  eq(provider.logic.occupancy:reserveMove({ id = "wild" }, 3, 3, 3, 2), true,
    "ordinary movement remains provider-owned")
  eq(calls.reserveMove, 1, "safe movement delegates exactly once")

  eq(grass.validateSpawnTile(map, ow.entities, ow.player, 1, 1), false,
    "grass selection filters protected cells before reservation")
  eq(grass.validateSpawnTile(map, ow.entities, ow.player, 3, 3), true,
    "grass selection preserves ordinary valid cells")

  local record = provider.logic:trySpawn(game, { x = 3, y = 3,
    species = "RATTATA", level = 3 })
  check(record ~= nil, "safe external spawn still succeeds")
  eq(calls.spawned, 1, "safe spawn calls the provider exactly once")
  eq(game.save.randomizer.seed, 12345,
    "spawn safety never consumes/reseeds randomizer authority")
  eq(game.save.nuzlocke.enabled, true,
    "spawn safety never changes Nuzlocke authority")

  local wanderer = provider.ambient:_makeNpc(game, ow, "PIKACHU", 3, 3)
  wanderer.requestMoveX, wanderer.requestMoveY = 1, 1
  wanderer:update(map, ow.entities)
  eq(wanderer.targetX, nil,
    "ambient movement into a protected cell is cancelled")
  eq(wanderer.moving, false,
    "cancelled ambient movement cannot resume toward the unsafe target")
  eq(wanderer.px, 48,
    "cancelled ambient movement snaps cleanly to its original cell")
end

-- Legacy providers may return only species/level.  The synchronous post-call
-- world scan still rejects any blocking body they created.  Providers whose
-- cleanup throws fall back to Ascendant's deterministic index/world cleanup.
do
  local game = { save = guardedSave("RED", true), data = { maps = {} } }
  local map = makeMap("OPAQUE_EXTERNAL_FIXTURE", {
    "#######", "#.....#", "#.....#", "#.....#", "#.....#",
    "#.....#", "#######",
  }, { objects = { { x = 1, y = 1, id = "SCRIPT_TARGET" } } })
  local ow = { map = map, player = { cellX = 5, cellY = 5 }, entities = {}, npcs = {} }
  local provider = makeProvider("opaque_1_7_1", game, ow)
  provider.logic.trySpawn = function()
    local body = { id = "opaque_body", cellX = 1, cellY = 1,
      overworldWildSpawn = true }
    ow.entities[#ow.entities + 1] = body
    return { species = "RATTATA", level = 3 }
  end
  safety.install(provider, game)
  local record, why = provider.logic:trySpawn(game, {})
  eq(record, nil, "coordinate-less external spawn is rejected after world scan")
  check(why:find("opaque provider body removed", 1, true) ~= nil,
    "coordinate-less rejection reports the fail-closed path")
  eq(#ow.entities, 0, "opaque external blocking body is removed synchronously")
end

do
  local game = { save = guardedSave("BLUE", true), data = { maps = {} } }
  local map = makeMap("THROWING_DESPAWN_FIXTURE", {
    "#######", "#.....#", "#.....#", "#.....#", "#.....#",
    "#.....#", "#######",
  }, { objects = { { x = 1, y = 1, id = "ITEM" } } })
  local ow = { map = map, player = { cellX = 5, cellY = 5 }, entities = {}, npcs = {} }
  local provider = makeProvider("throwing_cleanup", game, ow)
  provider.logic._despawn = function() error("fixture cleanup failure") end
  safety.install(provider, game)
  local record = provider.logic:trySpawn(game, { x = 1, y = 1 })
  eq(record, nil, "unsafe spawn is rejected when provider cleanup throws")
  eq(provider.logic.spawns.throwing_cleanup_spawn_1, nil,
    "fallback removes the provider record after cleanup failure")
  eq(#ow.entities, 0,
    "fallback removes the blocking world body after cleanup failure")
end

-- Script modules publish non-ROM landing/interaction cells explicitly.  The
-- revision invalidates an already-built map plan. Runtime block mutations do
-- the same for corridor topology, and unknown collision data fails closed.
do
  local game = { save = guardedSave("YELLOW", true), data = { maps = {} } }
  local def = { blocks = { 0 } }
  local map = makeMap("SCRIPT_AND_BLOCK_FIXTURE", {
    "#######", "#.....#", "#.....#", "#.....#", "#.....#",
    "#.....#", "#######",
  }, def)
  local baseWalkable = map.isWalkableCell
  map.isWalkableCell = function(self, x, y)
    if self.def.blocks[1] == 0 then return baseWalkable(self, x, y) end
    if not baseWalkable(self, x, y) then return false end
    return x ~= 3 or y == 3
  end
  local ow = { map = map, player = { cellX = 5, cellY = 5 }, entities = {}, npcs = {} }
  eq(safety.isSafeCell(game, ow, map, 2, 2), true,
    "non-ROM script cell begins as ordinary space")
  safety.reserveCells(map.id, { { x = 2, y = 2 } }, "fixture script landing")
  eq(safety.isSafeCell(game, ow, map, 2, 2), false,
    "published script landing invalidates and protects the cached plan")
  eq(safety.isSafeCell(game, ow, map, 4, 2), true,
    "runtime reservation begins as ordinary space")
  map.wildsReservedCells = { { x = 4, y = 2 } }
  eq(safety.isSafeCell(game, ow, map, 4, 2), false,
    "runtime reserved-cell mutation invalidates the cached plan")
  eq(safety.isSafeCell(game, ow, map, 4, 4), true,
    "authored scripted position begins as ordinary space")
  map.def.scriptedPositions = { { x = 4, y = 4 } }
  eq(safety.isSafeCell(game, ow, map, 4, 4), false,
    "authored scripted-position mutation invalidates the cached plan")

  -- Use a fresh map here: the authored scripted-position fixture above
  -- intentionally reserves approach cells and would alter the graph whose
  -- block-only invalidation this assertion is meant to isolate.
  local blockDef = { blocks = { 0 } }
  local blockMap = makeMap("BLOCK_MUTATION_FIXTURE", {
    "#######", "#.....#", "#.....#", "#.....#", "#.....#",
    "#.....#", "#######",
  }, blockDef)
  local blockBaseWalkable = blockMap.isWalkableCell
  blockMap.isWalkableCell = function(self, x, y)
    if self.def.blocks[1] == 0 then return blockBaseWalkable(self, x, y) end
    if not blockBaseWalkable(self, x, y) then return false end
    return x ~= 3 or y == 3
  end
  local blockOw = {
    map = blockMap,
    player = { cellX = 5, cellY = 5 },
    entities = {}, npcs = {},
  }
  eq(safety.isSafeCell(game, blockOw, blockMap, 3, 3), true,
    "open topology does not invent a corridor")
  blockMap.def.blocks[1] = 1
  eq(safety.isSafeCell(game, blockOw, blockMap, 3, 3), false,
    "block mutation invalidates topology and protects the new bridge")

  local unknown = makeMap("UNKNOWN_COLLISION_FIXTURE", {
    "###", "#.#", "###",
  }, {})
  unknown.isWalkableCell = nil
  unknown.isWaterCell = nil
  eq(safety.isSafeCell(game, { map = unknown, entities = {}, npcs = {} },
    unknown, 1, 1), false,
    "missing collision authority fails closed")
end

-- A pre-starter map-enter remains suppressed across steps, then recovers on
-- the same loaded save as soon as the universal starter flag is set.
do
  local save, flagState = guardedSave("YELLOW", false)
  local game = { save = save, data = { maps = {} } }
  local map = makeMap(OAKS_LAB, oakRows, oakDef)
  local ow = { map = map, player = { cellX = 4, cellY = 5 }, entities = {}, npcs = {} }
  local provider, calls = makeProvider("reentry", game, ow)
  safety.install(provider, game)
  local entered, why = provider.logic:onMapEntered({ mapId = OAKS_LAB, map = map })
  eq(entered, nil, "pre-starter map entry is suppressed")
  eq(why, safety.STARTER_REASON, "map-entry rejection is explicit")
  eq(calls.entered, 0, "provider map initialization does not run early")
  provider.logic:onStepped({ mapId = OAKS_LAB })
  eq(calls.stepped, 0, "pre-starter step cannot late-initialize Wilds")
  provider.logic:onStepped({ mapId = OAKS_LAB })
  eq(calls.clear, 1,
    "repeated gated world ticks do not repeatedly clear an empty provider")
  flagState.EVENT_GOT_STARTER = true
  provider.logic:onStepped({ mapId = OAKS_LAB })
  eq(calls.entered, 1, "same-save starter completion performs one recovery enter")
  eq(calls.stepped, 1, "the recovered step then delegates normally")
end

-- Hot import keeps the already-wrapped public provider but transfers event
-- repair ownership to the newly loaded policy.  This mirrors mod reloads in
-- the client and prevents a stale first-import closure from disabling repair.
do
  local game = { save = guardedSave("RED", true), data = { maps = {} } }
  local map = makeMap("HOT_RELOAD_FIXTURE", {
    "#######", "#.....#", "#.....#", "#.....#", "#.....#",
    "#.....#", "#######",
  }, { objects = { { x = 1, y = 1, id = "STORY_NPC" } } })
  local ow = { map = map, player = { cellX = 5, cellY = 5 }, entities = {}, npcs = {} }
  local provider = makeProvider("hot_reload", game, ow)
  safety.install(provider, game)

  local reloaded = assert(loadfile(root .. "/wilds_spawn_safety.lua"))()(mod)
  eq(reloaded.install(provider, game), true,
    "fresh policy reuses the already wrapped provider")
  eq(reloaded.runtimeStatus().providers, 1,
    "fresh policy registers exactly one retained provider")

  local bad = { id = "hot_bad", cellX = 1, cellY = 1,
    overworldWildSpawn = true }
  provider.logic.spawns.hot_bad = {
    id = "hot_bad", mapId = map.id, x = 1, y = 1,
  }
  provider.logic.entities.hot_bad = bad
  provider.logic.byMap[map.id] = { "hot_bad" }
  ow.entities = { bad }
  eq(reloaded.repairCurrent("hot reload fixture"), 1,
    "fresh policy owns event-style repair after hot reload")
  eq(provider.logic.spawns.hot_bad, nil,
    "hot-reload repair removes the protected persisted body")
end

print(("WILDS SPAWN SAFETY 6.5.5 PASS (%d assertions)"):format(assertions))
