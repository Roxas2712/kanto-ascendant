-- Shared level policy for ordinary Johto species that replace a native
-- Kanto encounter.  Story/primal encounters do not use this module and keep
-- their explicitly authored levels.

local L = {}

-- Gen I's cumulative encounter-slot thresholds out of 256. Encounter tables
-- may override these with their own `buckets`, matching Encounter.roll.
local DEFAULT_BUCKETS = {
  51, 102, 141, 166, 191, 216, 229, 242, 253, 256,
}

local function encounterTable(encDef, encounterKind)
  if type(encDef) ~= "table" then return nil end
  if type(encDef.slots) == "table" then return encDef end

  -- The regular engine normalizes surfing tables to { grass = waterDef }
  -- before encounter.roll, while Wilds supplies the complete map table.
  local requested = encounterKind == "water" and encDef.water
    or encounterKind == "grass" and encDef.grass
  return requested or encDef.grass or encDef.water
end

function L.routeAverage(encDef, encounterKind)
  local tableDef = encounterTable(encDef, encounterKind)
  local slots = tableDef and tableDef.slots
  if type(slots) ~= "table" or #slots == 0 then return nil end

  local buckets = type(tableDef.buckets) == "table"
    and tableDef.buckets or DEFAULT_BUCKETS
  local weightedTotal, totalWeight, previous = 0, 0, 0
  for index, slot in ipairs(slots) do
    local level = tonumber(slot and slot.level)
    local threshold = tonumber(buckets[index])
    local weight
    if threshold then
      weight = math.max(0, threshold - previous)
      previous = math.max(previous, threshold)
    else
      -- A custom table without a matching bucket still contributes once
      -- instead of disappearing from its own route average.
      weight = 1
    end
    if level and weight > 0 then
      weightedTotal = weightedTotal + level * weight
      totalWeight = totalWeight + weight
    end
  end
  if totalWeight == 0 then return nil end

  -- Pokémon levels are integral. Use the nearest whole route average so the
  -- promised +2..+5 band is itself exact and easy to explain to players.
  return math.max(1, math.floor(weightedTotal / totalWeight + 0.5))
end

function L.ordinaryLevelFromAverage(averageLevel, rng, fallbackLevel)
  local base = tonumber(averageLevel) or tonumber(fallbackLevel) or 1
  base = math.max(1, math.floor(base + 0.5))
  rng = type(rng) == "function" and rng or math.random
  local bonus = math.floor(tonumber(rng(2, 5)) or 2)
  bonus = math.max(2, math.min(5, bonus))
  return math.min(100, base + bonus)
end

function L.ordinaryLevel(encDef, encounterKind, rng, fallbackLevel)
  return L.ordinaryLevelFromAverage(
    L.routeAverage(encDef, encounterKind), rng, fallbackLevel)
end

L.DEFAULT_BUCKETS = DEFAULT_BUCKETS
L.encounterTable = encounterTable

return L
