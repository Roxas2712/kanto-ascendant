-- Rare, non-money rewards for completed field-trainer rematches.
-- Rolls use fixed non-overlapping bands out of 10,000, so an ineligible rare
-- item becomes "no drop" instead of silently inflating common-item odds.

local BALANCED = {
  { item = "MASTER_BALL", from = 1, to = 100, gate = "master",
    minLevel = 80 },                                                -- 1%
  { item = "EXP_ALL", from = 101, to = 2100, gate = "expAll",
    minLevel = 40 },                                                -- 20%
  { item = "RARE_CANDY", from = 2101, to = 3600, minLevel = 20 },  -- 15%
  { item = "PP_UP", from = 3601, to = 4600, minLevel = 35 },       -- 10%
  { item = "MAX_REVIVE", from = 4601, to = 5400, minLevel = 50 },  -- 8%
  { item = "NUGGET", from = 5401, to = 7400 },                     -- 20%
}

local GENEROUS = {
  { item = "MASTER_BALL", from = 1, to = 200, gate = "master",
    minLevel = 80 },                                                -- 2%
  { item = "EXP_ALL", from = 201, to = 2700, gate = "expAll",
    minLevel = 40 },                                                -- 25%
  { item = "RARE_CANDY", from = 2701, to = 4700, minLevel = 20 },  -- 20%
  { item = "PP_UP", from = 4701, to = 6200, minLevel = 35 },       -- 15%
  { item = "MAX_REVIVE", from = 6201, to = 7400, minLevel = 50 },  -- 12%
  { item = "NUGGET", from = 7401, to = 10000 },                    -- 26%
}

local L = { bands = { balanced = BALANCED, generous = GENEROUS } }

function L.averageLevel(team)
  local total, count = 0, 0
  for _, mon in ipairs(team or {}) do
    if tonumber(mon.level) then
      total = total + mon.level
      count = count + 1
    end
  end
  return count > 0 and total / count or 0
end

function L.select(roll, mode, ctx)
  if mode == "off" then return nil end
  roll = math.max(1, math.min(10000, math.floor(tonumber(roll) or 10000)))
  ctx = ctx or {}
  local level = tonumber(ctx.averageLevel) or 0
  local bands = mode == "generous" and GENEROUS or BALANCED
  for _, row in ipairs(bands) do
    if roll >= row.from and roll <= row.to then
      if row.gate == "master" and not ctx.masterUnlocked then return nil end
      if row.gate == "expAll" and not ctx.expAllAvailable then return nil end
      if row.minLevel and level < row.minLevel then return nil end
      return row.item
    end
  end
  return nil
end

return L
