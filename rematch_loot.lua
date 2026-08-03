-- Rare, non-money rewards for completed field-trainer rematches.
-- Rolls use fixed non-overlapping bands out of 10,000, so an ineligible rare
-- item becomes "no drop" instead of silently inflating common-item odds.

local BALANCED = {
  { item = "MASTER_BALL", from = 1, to = 100, gate = "master",
    minLevel = 80 },                                                -- 1%
  { item = "EXP_ALL", from = 101, to = 600, gate = "expAll",
    minLevel = 40 },                                                -- 5%
  { item = "RARE_CANDY", from = 601, to = 1100, minLevel = 20 },   -- 5%
  { item = "PP_UP", from = 1101, to = 2100, minLevel = 35 },       -- 10%
  { item = "MAX_REVIVE", from = 2101, to = 2900, minLevel = 50 },  -- 8%
  { item = "NUGGET", from = 2901, to = 4400 },                     -- 15%
}

local GENEROUS = {
  { item = "MASTER_BALL", from = 1, to = 200, gate = "master",
    minLevel = 80 },                                                -- 2%
  { item = "EXP_ALL", from = 201, to = 700, gate = "expAll",
    minLevel = 40 },                                                -- 5%
  { item = "RARE_CANDY", from = 701, to = 1200, minLevel = 20 },   -- 5%
  { item = "PP_UP", from = 1201, to = 2700, minLevel = 35 },       -- 15%
  { item = "MAX_REVIVE", from = 2701, to = 3900, minLevel = 50 },  -- 12%
  { item = "NUGGET", from = 3901, to = 5400 },                     -- 15%
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
