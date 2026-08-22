-- Bounded, randomized placement for optional runtime NPCs.
--
-- Authored candidate lists are the location contract. If every vetted cell
-- is busy, the NPC stays absent until the next refresh instead of falling
-- through to a wall, staff-only area, warp or narrow story passage.

return function(mod, opts)
  opts = opts or {}
  local random = opts.random or math.random
  local P = {}

  local function wildsOccupancy()
    local internal = mod and mod.exports and mod.exports.internalWilds
    local exports = internal and internal.exports
    if not (exports and type(exports.occupancy) == "function") then return nil end
    return exports.occupancy()
  end

  local function occupied(ow, occupancy, x, y)
    local player = ow and ow.player
    if player and player.cellX == x and player.cellY == y then return true end
    if ow and type(ow.npcAtCell) == "function" and ow:npcAtCell(x, y) then
      return true
    end
    if occupancy and type(occupancy.isOccupied) == "function"
        and occupancy:isOccupied(x, y) then return true end
    return occupancy and type(occupancy.isReserved) == "function"
      and occupancy:isReserved(x, y) or false
  end

  local function mapCellSafe(map, x, y)
    if not (map and map:inBounds(x, y) and map:isWalkableCell(x, y)) then
      return false
    end
    if type(map.warpAtCell) == "function" and map:warpAtCell(x, y) then
      return false
    end
    if type(map.isWarpTileCell) == "function" and map:isWarpTileCell(x, y) then
      return false
    end
    if type(map.signAtCell) == "function" and map:signAtCell(x, y) then
      return false
    end
    return true
  end

  local function authoredObjectAt(map, x, y)
    for _, object in ipairs(map and map.def and map.def.objects or {}) do
      if object.x == x and object.y == y then return true end
    end
    return false
  end

  local function cellSafe(ow, x, y)
    return mapCellSafe(ow and ow.map, x, y)
      and not authoredObjectAt(ow.map, x, y)
      and not occupied(ow, wildsOccupancy(), x, y)
  end

  -- DOWN-facing hosts reserve a clear 3x2 footprint: the host row and the
  -- approach row below it. The lateral cells guarantee a bypass even when
  -- followers or roaming Town Pokemon are active.
  local function candidateSafe(ow, x, y)
    local occupancy = wildsOccupancy()
    for yy = y, y + 1 do
      for xx = x - 1, x + 1 do
        if not mapCellSafe(ow and ow.map, xx, yy)
            or authoredObjectAt(ow.map, xx, yy)
            or occupied(ow, occupancy, xx, yy) then
          return false
        end
      end
    end
    return true
  end

  local function choose(ow, preferred, predicate, randomized)
    local available = {}
    for _, cell in ipairs(preferred or {}) do
      if predicate(ow, cell[1], cell[2]) then
        available[#available + 1] = cell
      end
    end
    if #available == 0 then return nil end
    local selected = randomized and available[random(#available)] or available[1]
    return selected[1], selected[2]
  end

  function P.find(ow, preferred)
    return choose(ow, preferred, cellSafe, false)
  end

  function P.findWide(ow, preferred)
    return choose(ow, preferred, candidateSafe, false)
  end

  function P.findRandom(ow, preferred)
    return choose(ow, preferred, cellSafe, true)
  end

  function P.findWideRandom(ow, preferred)
    return choose(ow, preferred, candidateSafe, true)
  end

  P.cellSafe = cellSafe
  P.candidateSafe = candidateSafe
  return P
end
