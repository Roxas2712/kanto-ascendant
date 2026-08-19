-- Ascendant-owned safety boundary for visible/ambient Wilds populations.
--
-- This module deliberately sits above both the bundled Wilds 1.12.2 runtime
-- and an installed `overworld_wild_spawns` provider.  Wilds keeps ownership of
-- species choice, encounter levels, randomizer/Nuzlocke policy, rendering and
-- battles; Ascendant owns only the question "may a blocking body occupy this
-- story cell?".

return function(mod)
  local S = {
    activeGame = nil,
    providers = {},
    installed = false,
    repairs = 0,
    despawned = 0,
    rejected = 0,
    storyReservations = {},
    storyReservationRevision = 0,
  }

  local OAKS_LAB = "OAKS_LAB"
  local BLOCK_REASON = "rejected: protected story cell"
  local STARTER_REASON = "rejected: starter selection pending"
  local CONNECTION_CLEARANCE_DEPTH = 3
  local CONNECTION_CLEARANCE_LATERAL = 1
  local DIRS = {
    { 0, -1 }, { 1, 0 }, { 0, 1 }, { -1, 0 },
  }

  local staticCache = setmetatable({}, { __mode = "k" })

  local function mapIdOf(value)
    if type(value) == "string" then return value end
    if type(value) ~= "table" then return nil end
    return value.mapId or value.id
      or (type(value.map) == "table" and value.map.id)
  end

  local function upper(value)
    return tostring(value or ""):upper()
  end

  local function cellKey(x, y)
    if x == nil or y == nil then return nil end
    return tostring(x) .. ":" .. tostring(y)
  end

  local function xyOf(row)
    if type(row) ~= "table" then return nil, nil end
    local pos = type(row.position) == "table" and row.position or nil
    local x = row.x
      or row.cellX
      or row.tileX
      or (pos and (pos.x or pos.cellX))
      or row[1]
    local y = row.y
      or row.cellY
      or row.tileY
      or (pos and (pos.y or pos.cellY))
      or row[2]
    x, y = tonumber(x), tonumber(y)
    if x == nil or y == nil then return nil, nil end
    return math.floor(x), math.floor(y)
  end

  local function eachRow(value, fn)
    if type(value) ~= "table" then return end
    for _, row in pairs(value) do
      if type(row) == "table" then fn(row) end
    end
  end

  local function safeMethod(object, name, ...)
    local fn = object and object[name]
    if type(fn) ~= "function" then return nil end
    local ok, result = pcall(fn, object, ...)
    if ok then return result end
    return nil
  end

  local function currentGame(runtime, logic)
    local world = logic and logic.mod and logic.mod.world
    return runtime and runtime.game
      or world and world.game
      or S.activeGame
      or mod.world and mod.world.game
  end

  local function currentOverworld(logic)
    local world = logic and logic.mod and logic.mod.world or mod.world
    if not (world and type(world.overworld) == "function") then return nil end
    local ok, ow = pcall(world.overworld, world)
    return ok and ow or nil
  end

  local function currentContext(runtime, logic)
    local game = currentGame(runtime, logic)
    local ow = currentOverworld(logic)
    return game, ow, ow and ow.map
  end

  local function policyOf(runtime)
    return runtime and runtime.policy or S
  end

  function S.starterComplete(game)
    local save = game and game.save
    local flags = save and save.flags
    return type(flags) == "table" and flags.EVENT_GOT_STARTER == true
  end

  function S.mapAllowed(game, value)
    local mapId = upper(mapIdOf(value))
    if mapId == OAKS_LAB and not S.starterComplete(game) then
      return false, STARTER_REASON
    end
    return true
  end

  -- Story modules can publish landing/interaction cells that do not exist in
  -- the ROM object table (for example Ascendant's scripted Lab terminal).
  -- Keeping this explicit avoids guessing coordinates from opaque onStep
  -- functions and gives future content one stable safety seam.
  function S.reserveCells(mapId, cells, reason)
    mapId = upper(mapId)
    if mapId == "" or type(cells) ~= "table" then return false end
    local bucket = S.storyReservations[mapId]
    if not bucket then
      bucket = {}
      S.storyReservations[mapId] = bucket
    end
    local changed = false
    for _, row in ipairs(cells) do
      local x, y = xyOf(row)
      local key = cellKey(x, y)
      if key and not bucket[key] then
        bucket[key] = {
          x = x, y = y,
          reason = reason or row.reason or "scripted position",
          approaches = row.approaches == true,
        }
        changed = true
      end
    end
    if changed then
      S.storyReservationRevision = S.storyReservationRevision + 1
    end
    return true
  end

  local function defFor(game, map)
    if type(map) ~= "table" then return nil end
    if type(map.def) == "table" then return map.def end
    local maps = game and game.data and game.data.maps
    return type(maps) == "table" and maps[map.id] or nil
  end

  local function staticSignature(game, map)
    local def = defFor(game, map) or {}
    local parts = {
      tostring(map.widthCells or def.widthCells or def.width or 0),
      "x",
      tostring(map.heightCells or def.heightCells or def.height or 0),
      "@",
      tostring(def),
      "#",
      tostring(S.storyReservationRevision),
    }
    local function append(label, rows)
      parts[#parts + 1] = "|" .. label
      eachRow(rows, function(row)
        local x, y = xyOf(row)
        if x ~= nil then
          parts[#parts + 1] = ";" .. tostring(x) .. "," .. tostring(y)
        end
      end)
    end
    append("w", def.warps)
    append("o", def.objects)
    append("s", def.signs)
    append("sp", def.scriptedPositions)
    append("st", def.storyPositions)
    append("kr", def.kaWildsReservedCells)
    append("wr", def.wildsReservedCells)
    append("mkr", map.kaWildsReservedCells)
    append("mwr", map.wildsReservedCells)
    parts[#parts + 1] = "|b"
    for index, block in ipairs(def.blocks or {}) do
      parts[#parts + 1] = ";" .. tostring(index) .. "=" .. tostring(block)
    end
    return table.concat(parts)
  end

  local function buildStaticPlan(game, map)
    local signature = staticSignature(game, map)
    local cached = staticCache[map]
    if cached and cached.signature == signature then return cached end

    local def = defFor(game, map) or {}
    local width = tonumber(map.widthCells or def.widthCells or def.width) or 0
    local height = tonumber(map.heightCells or def.heightCells or def.height) or 0
    local reserved = {}

    local function inBounds(x, y)
      if x == nil or y == nil or x < 0 or y < 0
          or x >= width or y >= height then return false end
      local explicit = safeMethod(map, "inBounds", x, y)
      return explicit ~= false
    end

    local function reserve(x, y, reason)
      if inBounds(x, y) then
        local key = cellKey(x, y)
        if not reserved[key] then reserved[key] = reason end
      end
    end

    local function reserveApproach(x, y, reason)
      reserve(x, y, reason)
      for _, d in ipairs(DIRS) do
        reserve(x + d[1], y + d[2], reason .. " approach")
      end
    end

    local function reserveRows(rows, reason, approaches)
      eachRow(rows, function(row)
        local x, y = xyOf(row)
        if x ~= nil then
          if approaches then reserveApproach(x, y, reason)
          else reserve(x, y, reason) end
        end
      end)
    end

    -- Map-authored locations cover future NPCs/items/balls/switches even when
    -- their object is currently hidden by a story flag.
    reserveRows(def.warps, "warp", true)
    reserveRows(def.objects, "object/interactable", true)
    reserveRows(def.signs, "sign/interactable", true)
    reserveRows(def.scriptedPositions, "scripted position", true)
    reserveRows(def.storyPositions, "story position", true)
    reserveRows(def.kaWildsReservedCells, "authored reserved cell", false)
    reserveRows(def.wildsReservedCells, "authored reserved cell", false)
    reserveRows(map.kaWildsReservedCells, "runtime reserved cell", false)
    reserveRows(map.wildsReservedCells, "runtime reserved cell", false)
    local published = S.storyReservations[upper(map.id)]
    if published then
      for _, row in pairs(published) do
        if row.approaches then reserveApproach(row.x, row.y, row.reason)
        else reserve(row.x, row.y, row.reason) end
      end
    end

    -- Runtime methods also catch engine-generated exits, doors, counters and
    -- interactions that are absent from the public map definition.
    for y = 0, height - 1 do
      for x = 0, width - 1 do
        if safeMethod(map, "warpAtCell", x, y)
            or safeMethod(map, "isWarpTileCell", x, y)
            or safeMethod(map, "warpPadOrHoleAt", x, y) then
          reserveApproach(x, y, "warp")
        elseif safeMethod(map, "isDoorTileCell", x, y)
            or safeMethod(map, "isDoorCell", x, y) then
          reserveApproach(x, y, "door")
        end
        if safeMethod(map, "isCounterCell", x, y) then
          reserveApproach(x, y, "counter/interactable")
        end
        for _, method in ipairs({
          "objectAtCell", "signAtCell", "interactionAtCell", "switchAtCell",
        }) do
          if safeMethod(map, method, x, y) then
            reserveApproach(x, y, "runtime interactable")
            break
          end
        end

        -- Gen-I connections can leave the map without an explicit warp row.
        -- A walkable boundary cell and its inward neighbour are therefore an
        -- entrance/exit lane, never a blocking-spawn slot.
        if x == 0 or y == 0 or x == width - 1 or y == height - 1 then
          local walkable = safeMethod(map, "isWalkableCell", x, y)
          if walkable == true then reserveApproach(x, y, "map connection") end
        end
      end
    end

    -- A connection is not just its outermost cell.  Gen-I drops the player
    -- onto a short lane inside the destination map, and multi-cell mouths are
    -- intentionally not graph articulations.  Reserving only the boundary
    -- and one neighbour therefore allowed two Wilds bodies to seal Viridian's
    -- north entrance.  Protect a small inward funnel for authored connection
    -- sides while leaving unrelated map-edge art and the rest of town free.
    local function reserveConnectionSide(side, startX, startY,
        scanX, scanY, count, inwardX, inwardY, lateralX, lateralY)
      local connections = def.connections
      if type(connections) ~= "table" or connections[side] == nil then return end
      for index = 0, count - 1 do
        local seedX = startX + scanX * index
        local seedY = startY + scanY * index
        local walkable = safeMethod(map, "isWalkableCell", seedX, seedY)
        local water = safeMethod(map, "isWaterCell", seedX, seedY)
        if walkable == true or water == true then
          for depth = 0, CONNECTION_CLEARANCE_DEPTH do
            local baseX = seedX + inwardX * depth
            local baseY = seedY + inwardY * depth
            for lateral = -CONNECTION_CLEARANCE_LATERAL,
                CONNECTION_CLEARANCE_LATERAL do
              local x = baseX + lateralX * lateral
              local y = baseY + lateralY * lateral
              if inBounds(x, y) then
                local laneWalkable = safeMethod(map, "isWalkableCell", x, y)
                local laneWater = safeMethod(map, "isWaterCell", x, y)
                if laneWalkable == true or laneWater == true then
                  reserve(x, y, "map connection clearance")
                end
              end
            end
          end
        end
      end
    end
    reserveConnectionSide("north", 0, 0, 1, 0, width,
      0, 1, 1, 0)
    reserveConnectionSide("south", 0, height - 1, 1, 0, width,
      0, -1, 1, 0)
    reserveConnectionSide("west", 0, 0, 0, 1, height,
      1, 0, 0, 1)
    reserveConnectionSide("east", width - 1, 0, 0, 1, height,
      -1, 0, 0, 1)

    local function graphPassable(x, y)
      if not inBounds(x, y) or reserved[cellKey(x, y)] then return false end
      if safeMethod(map, "isWaterCell", x, y) == true then return false end
      return safeMethod(map, "isWalkableCell", x, y) == true
    end

    -- Articulation cells are the exact graph definition of a critical
    -- one-tile corridor: occupying one disconnects traversable map space.
    -- Computing this once per immutable map signature is cheap on Gen-I maps
    -- and avoids treating ordinary open grass as a corridor.
    local nodes = {}
    local nodeCount = 0
    for y = 0, height - 1 do
      for x = 0, width - 1 do
        if graphPassable(x, y) then
          nodes[cellKey(x, y)] = { x = x, y = y }
          nodeCount = nodeCount + 1
        end
      end
    end
    if nodeCount <= 8192 then
      local serial, discovered, low, parent, articulation = 0, {}, {}, {}, {}
      local function visit(key)
        serial = serial + 1
        discovered[key], low[key] = serial, serial
        local children = 0
        local node = nodes[key]
        for _, d in ipairs(DIRS) do
          local nextKey = cellKey(node.x + d[1], node.y + d[2])
          if nodes[nextKey] then
            if not discovered[nextKey] then
              parent[nextKey] = key
              children = children + 1
              visit(nextKey)
              low[key] = math.min(low[key], low[nextKey])
              if not parent[key] and children > 1 then
                articulation[key] = true
              elseif parent[key] and low[nextKey] >= discovered[key] then
                articulation[key] = true
              end
            elseif nextKey ~= parent[key] then
              low[key] = math.min(low[key], discovered[nextKey])
            end
          end
        end
      end
      for key in pairs(nodes) do
        if not discovered[key] then visit(key) end
      end
      for key in pairs(articulation) do
        if not reserved[key] then reserved[key] = "critical one-tile corridor" end
      end
    end

    cached = {
      signature = signature,
      width = width,
      height = height,
      reserved = reserved,
    }
    staticCache[map] = cached
    return cached
  end

  local function isWildsEntity(entity)
    return type(entity) == "table" and (
      entity.overworldWildSpawn == true
      or entity.wildsAmbientPokemon == true
      or entity._kantoAscendantWildsSafetyNpc == true)
  end

  local function dynamicOccupantAt(ow, x, y, ignore)
    local player = ow and ow.player
    if player and player ~= ignore then
      if player.cellX == x and player.cellY == y then return "player position" end
      if player.targetX == x and player.targetY == y then return "player target" end
    end
    for _, name in ipairs({ "npcs", "entities" }) do
      local list = ow and ow[name]
      if type(list) == "table" then
        for _, entity in pairs(list) do
          if entity and entity ~= ignore and not isWildsEntity(entity) then
            if entity.cellX == x and entity.cellY == y then
              return "NPC/story position"
            end
            if entity.targetX == x and entity.targetY == y then
              return "NPC/story target"
            end
          end
        end
      end
    end
    return nil
  end

  local function wildsOccupantAt(ow, x, y, ignore)
    for _, name in ipairs({ "npcs", "entities" }) do
      local list = ow and ow[name]
      if type(list) == "table" then
        for _, entity in pairs(list) do
          if entity and entity ~= ignore and isWildsEntity(entity) then
            if entity.cellX == x and entity.cellY == y then return true end
            if entity.targetX == x and entity.targetY == y then return true end
          end
        end
      end
    end
    return false
  end

  function S.isSafeCell(game, ow, map, x, y, opts)
    opts = opts or {}
    local allowed, reason = S.mapAllowed(game, map)
    if not allowed then return false, reason end
    if type(map) ~= "table" then return false, BLOCK_REASON .. " (no map)" end
    x, y = tonumber(x), tonumber(y)
    if x == nil or y == nil then return false, BLOCK_REASON .. " (no cell)" end
    x, y = math.floor(x), math.floor(y)
    local plan = buildStaticPlan(game, map)
    if x < 0 or y < 0 or x >= plan.width or y >= plan.height
        or safeMethod(map, "inBounds", x, y) == false then
      return false, BLOCK_REASON .. " (outside map)"
    end
    local walkable = safeMethod(map, "isWalkableCell", x, y)
    local water = safeMethod(map, "isWaterCell", x, y)
    if walkable ~= true and water ~= true then
      return false, BLOCK_REASON .. " (blocked map cell)"
    end
    local staticReason = plan.reserved[cellKey(x, y)]
    if staticReason then
      return false, BLOCK_REASON .. " (" .. staticReason .. ")"
    end
    local occupantReason = dynamicOccupantAt(ow, x, y, opts.ignore)
    if occupantReason then
      return false, BLOCK_REASON .. " (" .. occupantReason .. ")"
    end
    return true
  end

  function S.filterCells(game, ow, map, cells)
    local safe = {}
    for _, cell in ipairs(cells or {}) do
      local ok = S.isSafeCell(game, ow, map, cell.x, cell.y)
      if ok then safe[#safe + 1] = cell end
    end
    return safe
  end

  local function bodyIsSafe(policy, game, ow, map, x, y, entity,
      fallbackTargetX, fallbackTargetY)
    local ok, why = policy.isSafeCell(game, ow, map, x, y, {
      ignore = entity,
    })
    if not ok then return false, why end
    local targetX = entity and entity.targetX or fallbackTargetX
    local targetY = entity and entity.targetY or fallbackTargetY
    if targetX ~= nil and targetY ~= nil
        and (targetX ~= x or targetY ~= y) then
      return policy.isSafeCell(game, ow, map,
        targetX, targetY, { ignore = entity })
    end
    return true
  end

  local function removeFromArray(list, target)
    if type(list) ~= "table" then return false end
    local removed = false
    for index = #list, 1, -1 do
      if list[index] == target then
        table.remove(list, index)
        removed = true
      end
    end
    return removed
  end

  local function removeByMapList(logic, mapId, id)
    local list = logic and logic.byMap and logic.byMap[mapId]
    if type(list) ~= "table" then return end
    for index = #list, 1, -1 do
      if list[index] == id then table.remove(list, index) end
    end
  end

  local function fallbackRemoveLogic(logic, ow, id, record, entity)
    removeFromArray(ow and ow.entities, entity)
    removeFromArray(ow and ow.npcs, entity)
    if logic.occupancy and type(logic.occupancy.releaseEntity) == "function" then
      pcall(logic.occupancy.releaseEntity, logic.occupancy, entity or id)
    end
    if id ~= nil then
      if logic.entities then logic.entities[id] = nil end
      if logic.spawns then logic.spawns[id] = nil end
      removeByMapList(logic, record and record.mapId, id)
    end
    if entity then
      if logic.voxel and type(logic.voxel.unregister) == "function" then
        pcall(logic.voxel.unregister, logic.voxel, entity)
      end
      entity.removed = true
      entity.registeredInWorld = false
    end
  end

  local function sortedLogicRows(logic, mapId)
    local rows = {}
    for id, record in pairs(logic and logic.spawns or {}) do
      if type(record) == "table" and (not record.mapId or record.mapId == mapId) then
        local entity = logic.entities and logic.entities[id]
        rows[#rows + 1] = {
          id = id,
          record = record,
          entity = entity,
          x = entity and entity.cellX or record.x,
          y = entity and entity.cellY or record.y,
          targetX = entity and entity.targetX or record.targetX,
          targetY = entity and entity.targetY or record.targetY,
        }
      end
    end
    table.sort(rows, function(a, b)
      if (a.y or -1) ~= (b.y or -1) then return (a.y or -1) < (b.y or -1) end
      if (a.x or -1) ~= (b.x or -1) then return (a.x or -1) < (b.x or -1) end
      return tostring(a.id) < tostring(b.id)
    end)
    return rows
  end

  local function markNpcSafe(npc, runtime)
    if type(npc) ~= "table" or npc._kantoAscendantWildsSafetyNpc then return end
    npc._kantoAscendantWildsSafetyNpc = true
    if type(npc.update) ~= "function" then return end
    local original = npc.update
    npc.update = function(selfNpc, map, entities, ...)
      local oldX, oldY = selfNpc.cellX, selfNpc.cellY
      local result = { original(selfNpc, map, entities, ...) }
      local game, ow = currentContext(runtime, runtime.logic)
      local policy = policyOf(runtime)
      map = map or ow and ow.map
      local tx, ty = selfNpc.targetX, selfNpc.targetY
      if tx ~= nil and ty ~= nil then
        local ok = policy.isSafeCell(game, ow, map, tx, ty, { ignore = selfNpc })
        if not ok then
          selfNpc.cellX, selfNpc.cellY = oldX, oldY
          selfNpc.targetX, selfNpc.targetY = nil, nil
          selfNpc.px, selfNpc.py = oldX * 16, oldY * 16
          selfNpc.moving = false
          selfNpc.progress = 0
        end
      end
      return unpack(result)
    end
  end

  function S.repair(provider, game, ow, reason)
    if type(provider) ~= "table" then return { despawned = 0 } end
    local runtime = provider._kantoAscendantSpawnSafety
    local logic = type(provider.logic) == "table" and provider.logic or {}
    game = game or currentGame(runtime, logic)
    ow = ow or currentOverworld(logic)
    local map = ow and ow.map
    if not map then return { despawned = 0, reason = "no overworld" } end
    local mapId = map.id
    local removed, removedEntities = 0, {}

    for _, row in ipairs(sortedLogicRows(logic, mapId)) do
      local ok = bodyIsSafe(S, game, ow, map,
        row.x, row.y, row.entity, row.targetX, row.targetY)
      if not ok then
        local cleaned = false
        if type(logic._despawn) == "function" then
          cleaned = pcall(logic._despawn, logic, row.id, true)
          if cleaned and type(logic.spawns) == "table"
              and logic.spawns[row.id] ~= nil then cleaned = false end
          if cleaned and type(logic.entities) == "table"
              and logic.entities[row.id] ~= nil then cleaned = false end
        end
        if not cleaned then
          fallbackRemoveLogic(logic, ow, row.id, row.record, row.entity)
        end
        if row.entity then removedEntities[row.entity] = true end
        removed = removed + 1
      end
    end

    local ambient = provider.ambient
    local wildRows, seen = {}, {}
    local function appendWild(npc)
      if isWildsEntity(npc)
          and not seen[npc] and not removedEntities[npc] then
        seen[npc] = true
        wildRows[#wildRows + 1] = npc
      end
    end
    if type(ambient) == "table" and type(ambient.active) == "table" then
      for npc in pairs(ambient.active) do appendWild(npc) end
    end
    for _, list in ipairs({ ow.npcs, ow.entities }) do
      if type(list) == "table" then
        for _, npc in pairs(list) do appendWild(npc) end
      end
    end
    table.sort(wildRows, function(a, b)
      if (a.cellY or -1) ~= (b.cellY or -1) then
        return (a.cellY or -1) < (b.cellY or -1)
      end
      if (a.cellX or -1) ~= (b.cellX or -1) then
        return (a.cellX or -1) < (b.cellX or -1)
      end
      return tostring(a.id or a.index or a) < tostring(b.id or b.index or b)
    end)
    for _, npc in ipairs(wildRows) do
      local ok = bodyIsSafe(S, game, ow, map,
        npc.cellX, npc.cellY, npc)
      if not ok then
        if npc.wildsAmbientPokemon == true
            and ambient and type(ambient.removeNpc) == "function" then
          pcall(ambient.removeNpc, ambient, ow, npc)
        end
        -- Provider removal is allowed to own additional cleanup, but the
        -- fail-closed boundary always verifies/removes its world indexes too.
        fallbackRemoveLogic(logic, ow, npc.id, nil, npc)
        if ambient and ambient.active then ambient.active[npc] = nil end
        npc.removed = true
        removed = removed + 1
      else
        markNpcSafe(npc, runtime)
      end
    end

    if removed > 0 and type(logic.rebuildOccupancy) == "function" then
      pcall(logic.rebuildOccupancy, logic, ow)
    end

    S.repairs = S.repairs + 1
    S.despawned = S.despawned + removed
    if removed > 0 and mod.log and type(mod.log.info) == "function" then
      mod.log:info("Wilds story-cell repair removed %d unsafe entities on %s (%s)",
        removed, tostring(mapId), tostring(reason or "runtime"))
    end
    return { despawned = removed, mapId = mapId, reason = reason }
  end

  local function guardOccupancy(runtime, occupancy)
    if type(occupancy) ~= "table" then return false end
    local existing = occupancy._kantoAscendantSpawnSafety
    if type(existing) == "table" then
      existing.runtime = runtime
      return true
    end
    local state = { runtime = runtime }
    occupancy._kantoAscendantSpawnSafety = state

    if type(occupancy.reserveSpawn) == "function" then
      local original = occupancy.reserveSpawn
      occupancy.reserveSpawn = function(self, token, x, y)
        local live = self._kantoAscendantSpawnSafety.runtime
        local policy = policyOf(live)
        local game, ow, map = currentContext(live, live.logic)
        local ok, why = policy.isSafeCell(game, ow, map, x, y)
        if not ok then
          policy.rejected = policy.rejected + 1
          return nil, why
        end
        return original(self, token, x, y)
      end
      state.originalReserveSpawn = original
    end
    if type(occupancy.reserveMove) == "function" then
      local original = occupancy.reserveMove
      occupancy.reserveMove = function(self, entity, fromX, fromY, toX, toY, opts)
        local live = self._kantoAscendantSpawnSafety.runtime
        local policy = policyOf(live)
        local game, ow, map = currentContext(live, live.logic)
        local ok, why = policy.isSafeCell(game, ow, map, toX, toY, {
          ignore = entity,
        })
        if not ok then
          policy.rejected = policy.rejected + 1
          return false, why
        end
        return original(self, entity, fromX, fromY, toX, toY, opts)
      end
      state.originalReserveMove = original
    end
    return true
  end

  local function guardGrass(runtime, provider)
    local lib = provider and provider.lib
    if not (lib and type(lib.require) == "function") then return false end
    local ok, grass = pcall(lib.require, "grass")
    if not (ok and type(grass) == "table") then return false end
    local existing = grass._kantoAscendantSpawnSafety
    if type(existing) == "table" then
      existing.runtime = runtime
      return true
    end
    local state = { runtime = runtime }
    grass._kantoAscendantSpawnSafety = state
    for _, method in ipairs({
      "validateSpawnTile", "validateWalkableTile", "validateEligibleTile",
    }) do
      if type(grass[method]) == "function" then
        local original = grass[method]
        grass[method] = function(map, entities, player, x, y, ...)
          local allowed, reason = original(map, entities, player, x, y, ...)
          if not allowed then return allowed, reason end
          local live = grass._kantoAscendantSpawnSafety.runtime
          local policy = policyOf(live)
          local game, ow = currentContext(live, live.logic)
          local safe, why = policy.isSafeCell(game, ow, map, x, y)
          if not safe then
            policy.rejected = policy.rejected + 1
            return false, why
          end
          return allowed, reason
        end
        state["original_" .. method] = original
      end
    end
    return true
  end

  local function suppressLogic(runtime, mapId, reason)
    local logic = runtime.logic
    if runtime.suppressedMapId ~= mapId
        and type(logic.clearAll) == "function" then
      pcall(logic.clearAll, logic)
    end
    logic.activeMapId = nil
    runtime.suppressedMapId = mapId
    return nil, reason
  end

  local function guardLogic(runtime)
    local logic = runtime.logic
    if type(logic) ~= "table" then return false end
    local existing = logic._kantoAscendantSpawnSafety
    if type(existing) == "table" then
      existing.runtime = runtime
      guardOccupancy(runtime, logic.occupancy)
      return true
    end
    local state = { runtime = runtime }
    logic._kantoAscendantSpawnSafety = state

    if type(logic.rebuildOccupancy) == "function" then
      local original = logic.rebuildOccupancy
      logic.rebuildOccupancy = function(self, ow)
        local occupancy = original(self, ow)
        guardOccupancy(self._kantoAscendantSpawnSafety.runtime, occupancy)
        return occupancy
      end
      state.originalRebuildOccupancy = original
    end
    guardOccupancy(runtime, logic.occupancy)

    local function guardSpawn(method)
      if type(logic[method]) ~= "function" then return end
      local original = logic[method]
      logic[method] = function(self, game, opts)
        local live = self._kantoAscendantSpawnSafety.runtime
        local policy = policyOf(live)
        live.game = game or live.game
        local activeGame, ow, map = currentContext(live, self)
        local allowed, why = policy.mapAllowed(activeGame, map or self.activeMapId)
        if not allowed then return nil, why end
        local record, err, entity = original(self, game, opts)
        if record then
          local x = entity and entity.cellX or record.x
          local y = entity and entity.cellY or record.y
          local safe, unsafeReason = true, nil
          if x ~= nil and y ~= nil then
            safe, unsafeReason = bodyIsSafe(policy, activeGame, ow, map,
              x, y, entity, record.targetX, record.targetY)
          else
            -- Legacy public providers may return only species/level.  Their
            -- blocking body, when one exists, is still discoverable through
            -- the world/provider indexes and is validated synchronously here.
            local repaired = policy.repair(live.provider, activeGame, ow,
              "coordinate-less " .. tostring(method))
            if (repaired.despawned or 0) > 0 then
              safe, unsafeReason = false,
                BLOCK_REASON .. " (opaque provider body removed)"
            end
          end
          if not safe then
            local cleaned = false
            if record.id and type(self._despawn) == "function" then
              cleaned = pcall(self._despawn, self, record.id, true)
              if cleaned and type(self.spawns) == "table"
                  and self.spawns[record.id] ~= nil then cleaned = false end
              if cleaned and type(self.entities) == "table"
                  and self.entities[record.id] ~= nil then cleaned = false end
            end
            if not cleaned and (record.id ~= nil or entity ~= nil) then
              fallbackRemoveLogic(self, ow, record.id, record, entity)
            end
            policy.rejected = policy.rejected + 1
            return nil, unsafeReason
          end
        end
        return record, err, entity
      end
      state["original_" .. method] = original
    end
    guardSpawn("trySpawn")
    guardSpawn("trySpawnWater")

    if type(logic.onMapEntered) == "function" then
      local original = logic.onMapEntered
      logic.onMapEntered = function(self, ev)
        local live = self._kantoAscendantSpawnSafety.runtime
        local policy = policyOf(live)
        local game, ow = currentContext(live, self)
        local map = ev and ev.map or ow and ow.map
        local mapId = mapIdOf(ev) or mapIdOf(map)
        local allowed, why = policy.mapAllowed(game, map or mapId)
        if not allowed then return suppressLogic(live, mapId, why) end
        live.suppressedMapId = nil
        local result, err = original(self, ev)
        policy.repair(live.provider, game, ow, "map.entered")
        return result, err
      end
      state.originalOnMapEntered = original
    end

    if type(logic.onSaveLoaded) == "function" then
      local original = logic.onSaveLoaded
      logic.onSaveLoaded = function(self, ...)
        local result = { original(self, ...) }
        local live = self._kantoAscendantSpawnSafety.runtime
        local policy = policyOf(live)
        local game, ow = currentContext(live, self)
        policy.repair(live.provider, game, ow, "save.loaded")
        return unpack(result)
      end
      state.originalOnSaveLoaded = original
    end

    if type(logic.onMapReloaded) == "function" then
      local original = logic.onMapReloaded
      logic.onMapReloaded = function(self, ...)
        local result = { original(self, ...) }
        local live = self._kantoAscendantSpawnSafety.runtime
        local policy = policyOf(live)
        local game, ow = currentContext(live, self)
        policy.repair(live.provider, game, ow, "map.reloaded")
        return unpack(result)
      end
      state.originalOnMapReloaded = original
    end

    if type(logic.onStepped) == "function" then
      local original = logic.onStepped
      logic.onStepped = function(self, ev)
        local live = self._kantoAscendantSpawnSafety.runtime
        local policy = policyOf(live)
        local game, ow, map = currentContext(live, self)
        local mapId = mapIdOf(ev) or mapIdOf(map)
        local allowed, why = policy.mapAllowed(game, map or mapId)
        if not allowed then return suppressLogic(live, mapId, why) end
        if live.suppressedMapId == mapId then
          live.suppressedMapId = nil
          local enter = self._kantoAscendantSpawnSafety.originalOnMapEntered
          if type(enter) == "function" then
            pcall(enter, self, { mapId = mapId, map = map,
              starterSafetyRecovery = true })
          end
        end
        local result = { original(self, ev) }
        return unpack(result)
      end
      state.originalOnStepped = original
    end
    return true
  end

  local function guardAmbient(runtime)
    local ambient = runtime.provider and runtime.provider.ambient
    if type(ambient) ~= "table" then return false end
    runtime.ambient = ambient
    local existing = ambient._kantoAscendantSpawnSafety
    if type(existing) == "table" then
      existing.runtime = runtime
      return true
    end
    local state = { runtime = runtime }
    ambient._kantoAscendantSpawnSafety = state

    if type(ambient.findSpawnCell) == "function" then
      local original = ambient.findSpawnCell
      ambient.findSpawnCell = function(self, ow, map)
        local live = self._kantoAscendantSpawnSafety.runtime
        local policy = policyOf(live)
        local game = currentGame(live, live.logic)
        local allowed = policy.mapAllowed(game, map)
        if not allowed then return nil, nil end
        local x, y = original(self, ow, map)
        if x ~= nil and policy.isSafeCell(game, ow, map, x, y) then return x, y end

        -- Preserve Wilds' random choice whenever it is valid.  Only its unsafe
        -- result falls back to a stable scan, which makes recovery reproducible
        -- and avoids burning additional encounter RNG.
        local player = ow and ow.player
        local px, py = player and player.cellX or 5, player and player.cellY or 5
        for cy = 0, (map.heightCells or 0) - 1 do
          for cx = 0, (map.widthCells or 0) - 1 do
            local distance = math.abs(cx - px) + math.abs(cy - py)
            if distance >= 2 and distance <= 10
                and safeMethod(map, "isWalkableCell", cx, cy) ~= false
                and safeMethod(map, "isWaterCell", cx, cy) ~= true
                and not wildsOccupantAt(ow, cx, cy)
                and policy.isSafeCell(game, ow, map, cx, cy) then
              return cx, cy
            end
          end
        end
        return nil, nil
      end
      state.originalFindSpawnCell = original
    end

    if type(ambient._makeNpc) == "function" then
      local original = ambient._makeNpc
      ambient._makeNpc = function(self, ...)
        local npc = original(self, ...)
        if npc then markNpcSafe(npc, self._kantoAscendantSpawnSafety.runtime) end
        return npc
      end
      state.originalMakeNpc = original
    end

    if type(ambient.spawnForMap) == "function" then
      local original = ambient.spawnForMap
      ambient.spawnForMap = function(self, game, ow)
        local live = self._kantoAscendantSpawnSafety.runtime
        local policy = policyOf(live)
        live.game = game or live.game
        local map = ow and ow.map
        local mapId = mapIdOf(map)
        local allowed, why = policy.mapAllowed(game, map)
        if not allowed then
          if type(self.clearAll) == "function" then pcall(self.clearAll, self, ow) end
          self.activeMapId = mapId
          live.suppressedAmbientMapId = mapId
          return 0, why
        end
        live.suppressedAmbientMapId = nil
        local count, err = original(self, game, ow)
        policy.repair(live.provider, game, ow, "ambient spawn")
        return count, err
      end
      state.originalSpawnForMap = original
    end
    return true
  end

  function S.install(provider, game)
    if type(provider) ~= "table" then return false, "Wilds provider unavailable" end
    S.activeGame = game or S.activeGame
    local runtime = provider._kantoAscendantSpawnSafety
    if type(runtime) ~= "table" or runtime.provider ~= provider then
      runtime = {
        policy = S,
        provider = provider,
        logic = provider.logic,
        game = game,
      }
      provider._kantoAscendantSpawnSafety = runtime
    else
      runtime.policy = S
      runtime.logic = provider.logic
      runtime.game = game or runtime.game
    end
    -- A Lua hot reload creates a fresh policy table while intentionally
    -- retaining the provider-owned runtime and wrappers.  Register that
    -- provider with the fresh policy too, otherwise event-driven repair would
    -- silently disappear until the next cold boot.
    local registered = false
    for _, known in ipairs(S.providers) do
      if known == provider then registered = true break end
    end
    if not registered then S.providers[#S.providers + 1] = provider end
    guardLogic(runtime)
    guardGrass(runtime, provider)
    guardAmbient(runtime)
    S.installed = true
    return true
  end

  function S.repairCurrent(reason)
    local total = 0
    for _, provider in ipairs(S.providers) do
      local runtime = provider._kantoAscendantSpawnSafety
      if runtime and runtime.policy == S then
        local game, ow = currentContext(runtime, provider.logic)
        local mapId = ow and ow.map and ow.map.id
        local allowed = S.mapAllowed(game, ow and ow.map)
        if allowed and runtime.suppressedAmbientMapId == mapId then
          runtime.suppressedAmbientMapId = nil
          local ambient = provider.ambient
          local original = ambient and ambient._kantoAscendantSpawnSafety
            and ambient._kantoAscendantSpawnSafety.originalSpawnForMap
          if type(original) == "function" then
            ambient.activeMapId = nil
            pcall(original, ambient, game, ow)
          end
        end
        total = total + (S.repair(provider, game, ow, reason).despawned or 0)
      end
    end
    return total
  end

  function S.runtimeStatus()
    return {
      installed = S.installed,
      providers = #S.providers,
      repairs = S.repairs,
      despawned = S.despawned,
      rejected = S.rejected,
    }
  end

  if mod.events and type(mod.events.on) == "function" then
    for _, event in ipairs({
      "map.entered", "map.reloaded", "save.loaded", "world.stepped",
    }) do
      mod.events:on(event, function()
        S.repairCurrent(event)
      end, -10000)
    end
  end

  S.BLOCK_REASON = BLOCK_REASON
  S.STARTER_REASON = STARTER_REASON
  return S
end
