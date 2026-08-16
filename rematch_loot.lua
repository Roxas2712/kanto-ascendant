-- Rematch 2.0 normal reward tables.
--
-- Special one-time EXP unlocks live in rematch_rewards.lua.  This module is
-- deliberately pure: it maps fixed integer rolls to either one supported
-- item stack or its exact money fallback. MASTER_BALL is resolved by the
-- reward controller as a separate post-Hall-of-Fame roll; SAFARI_BALL is
-- never eligible ordinary loot.

local L = {}

L.ROLL_MAX = 100000
L.SPECIAL = {
  expShare = { denominator = 10000, hits = 225 }, -- 2.25 percent
  multiplier2 = { denominator = 300, hits = 1 },
  multiplier3 = { denominator = 250, hits = 1 },
  multiplier5 = { denominator = 250, hits = 1 },
  rematchMaster = { denominator = 50, hits = 1 }, -- post-HOF: exactly 2%
}

local ITEM_CHANCE = {
  balanced = { normal = 0.65, level100 = 0.72 },
  generous = { normal = 0.80, level100 = 0.87 },
}

-- A stack is one weighted result.  Repeated ids are intentional: their
-- quantities have independent rarity, especially the required Ball tiers.
local BASE_POOL = {
  { item = "POKE_BALL", qty = 3, weight = 8, category = "ball" },
  { item = "POKE_BALL", qty = 5, weight = 5, category = "ball" },
  { item = "POKE_BALL", qty = 10, weight = 1, category = "ball" },
  { item = "GREAT_BALL", qty = 2, weight = 7, category = "ball" },
  { item = "GREAT_BALL", qty = 3, weight = 4, category = "ball" },
  { item = "GREAT_BALL", qty = 5, weight = 1, category = "ball" },
  { item = "ULTRA_BALL", qty = 1, weight = 5, category = "ball",
    premium = true },
  { item = "ULTRA_BALL", qty = 2, weight = 3, category = "ball",
    premium = true },
  { item = "ULTRA_BALL", qty = 3, weight = 1, category = "ball",
    premium = true },

  { item = "POTION", qty = 2, weight = 6, category = "healing" },
  { item = "SUPER_POTION", qty = 2, weight = 6, category = "healing" },
  { item = "HYPER_POTION", qty = 1, weight = 5, category = "healing" },
  { item = "MAX_POTION", qty = 1, weight = 2, category = "healing",
    premium = true },
  { item = "FULL_HEAL", qty = 2, weight = 5, category = "healing" },
  { item = "REVIVE", qty = 1, weight = 4, category = "healing" },
  { item = "MAX_REVIVE", qty = 1, weight = 1, category = "healing",
    premium = true },

  { item = "ETHER", qty = 1, weight = 5, category = "pp" },
  { item = "MAX_ETHER", qty = 1, weight = 2, category = "pp",
    premium = true },
  { item = "ELIXER", qty = 1, weight = 3, category = "pp",
    premium = true },
  { item = "MAX_ELIXER", qty = 1, weight = 1, category = "pp",
    premium = true },

  { item = "PP_UP", qty = 1, weight = 2, category = "progress",
    premium = true },
  { item = "RARE_CANDY", qty = 1, weight = 2, category = "progress",
    premium = true },
  { item = "HP_UP", qty = 1, weight = 2, category = "progress",
    premium = true },
  { item = "PROTEIN", qty = 1, weight = 2, category = "progress",
    premium = true },
  { item = "IRON", qty = 1, weight = 2, category = "progress",
    premium = true },
  { item = "CALCIUM", qty = 1, weight = 2, category = "progress",
    premium = true },
  { item = "CARBOS", qty = 1, weight = 2, category = "progress",
    premium = true },

  { item = "FIRE_STONE", qty = 1, weight = 2, category = "evolution" },
  { item = "WATER_STONE", qty = 1, weight = 2, category = "evolution" },
  { item = "THUNDER_STONE", qty = 1, weight = 2, category = "evolution" },
  { item = "LEAF_STONE", qty = 1, weight = 2, category = "evolution" },
  { item = "MOON_STONE", qty = 1, weight = 2, category = "evolution" },
}

local MONEY_NORMAL = {
  { amount = 0, weight = 500 }, { amount = 100, weight = 2000 },
  { amount = 250, weight = 2000 }, { amount = 500, weight = 2000 },
  { amount = 750, weight = 1200 }, { amount = 1000, weight = 1000 },
  { amount = 1250, weight = 600 }, { amount = 1500, weight = 400 },
  { amount = 1750, weight = 200 }, { amount = 2000, weight = 100 },
}

local MONEY_LEVEL100 = {
  { amount = 1000, weight = 2500 }, { amount = 1500, weight = 2000 },
  { amount = 2000, weight = 1800 }, { amount = 2500, weight = 1200 },
  { amount = 3000, weight = 1000 }, { amount = 4000, weight = 600 },
  { amount = 5000, weight = 400 }, { amount = 6000, weight = 250 },
  { amount = 7000, weight = 150 }, { amount = 8000, weight = 100 },
}

local function clampRoll(roll, maximum)
  return math.max(1, math.min(maximum,
    math.floor(tonumber(roll) or maximum)))
end

local function copy(row)
  local out = {}
  for key, value in pairs(row) do out[key] = value end
  return out
end

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

local function supported(data, id)
  return data and data.items and data.items[id] ~= nil
end

-- HEVO relics are progression capabilities, not ordinary consumables. Their
-- item-shaped records exist for bag/evolution compatibility only and must
-- never enter generic loot. The explicit metadata flags keep this contract
-- useful for future research rewards too.
local function genericEvolutionLootAllowed(data, id)
  local def = data and data.items and data.items[id]
  if not def or tostring(id):match("^HEVO_") then return false end
  return def.lootExcluded ~= true and def.progressionItem ~= true
end

local function evolutionItems(data)
  local ids = {}
  for _, def in pairs((data and data.pokemon) or {}) do
    for _, evolution in ipairs(def.evolutions or {}) do
      if evolution.method == "ITEM"
          and genericEvolutionLootAllowed(data, evolution.item) then
        ids[evolution.item] = true
      end
    end
  end
  return ids
end

local function supportedBallIds(data)
  local ids = {
    POKE_BALL = true, GREAT_BALL = true, ULTRA_BALL = true,
  }
  local ok, effects = pcall(require, "src.inventory.ItemEffects")
  for id in pairs((data and data.items) or {}) do
    local registered = data and data.balls and data.balls[id]
    local implemented = ok and effects and effects.isBall
      and effects.isBall(id)
    if (registered or implemented) and id ~= "MASTER_BALL"
        and id ~= "SAFARI_BALL" then ids[id] = true end
  end
  return ids
end

function L.pool(data, ctx)
  ctx = ctx or {}
  local rows, seenEvolution = {}, {}
  local balls = supportedBallIds(data)
  for _, source in ipairs(BASE_POOL) do
    if supported(data, source.item)
        and (source.category ~= "ball" or balls[source.item]) then
      local row = copy(source)
      rows[#rows + 1] = row
      if row.category == "evolution" then seenEvolution[row.item] = true end
    end
  end

  -- Ascendant's Gen-II evolution registry is authoritative.  Any supported
  -- item evolution absent from the native five stones joins automatically;
  -- unsupported placeholders never do.
  for id in pairs(evolutionItems(data)) do
    if not seenEvolution[id] then
      rows[#rows + 1] = {
        item = id, qty = 1, weight = 1.5, category = "evolution",
      }
      seenEvolution[id] = true
    end
  end

  -- Future ordinary Ball registrations join without changing this file.
  for id in pairs(balls) do
    local known = id == "POKE_BALL" or id == "GREAT_BALL"
      or id == "ULTRA_BALL"
    if not known and supported(data, id) then
      rows[#rows + 1] = {
        item = id, qty = 1, weight = 2, category = "ball",
      }
    end
  end

  local level100 = ctx.level100 == true
    or (tonumber(ctx.averageLevel) or 0) >= 100
  local mastery = math.max(0, math.floor(tonumber(ctx.masteryWins) or 0))
  local masteryPremium = math.min(0.25, mastery * 0.025)
  for _, row in ipairs(rows) do
    row.effectiveWeight = row.weight
    if row.premium and level100 then row.effectiveWeight = row.effectiveWeight * 1.6 end
    if row.premium then row.effectiveWeight = row.effectiveWeight * (1 + masteryPremium) end
  end
  return rows
end

function L.itemChance(mode, ctx)
  if mode == "off" then return 0 end
  local table_ = ITEM_CHANCE[mode] or ITEM_CHANCE.balanced
  ctx = ctx or {}
  local level100 = ctx.level100 == true
    or (tonumber(ctx.averageLevel) or 0) >= 100
  local chance = level100 and table_.level100 or table_.normal
  if level100 then
    local wins = math.max(0, math.floor(tonumber(ctx.masteryWins) or 0))
    chance = chance + math.min(0.03, wins * 0.0025)
  end
  return math.min(0.90, chance)
end

function L.select(roll, mode, ctx, data)
  if mode == "off" then return nil end
  ctx = ctx or {}
  roll = clampRoll(roll, L.ROLL_MAX)
  local threshold = math.floor(L.itemChance(mode, ctx) * L.ROLL_MAX)
  if roll > threshold then return nil end
  local pool = L.pool(data, ctx)
  local total = 0
  for _, row in ipairs(pool) do total = total + row.effectiveWeight end
  if total <= 0 then return nil end
  local point = ((roll - 1) / math.max(1, threshold)) * total
  local cursor = 0
  for _, row in ipairs(pool) do
    cursor = cursor + row.effectiveWeight
    if point < cursor then return copy(row) end
  end
  return copy(pool[#pool])
end

local function selectWeighted(roll, rows)
  roll = clampRoll(roll, 10000)
  local cursor = 0
  for _, row in ipairs(rows) do
    cursor = cursor + row.weight
    if roll <= cursor then return row.amount end
  end
  return rows[#rows].amount
end

function L.money(roll, level100)
  return selectWeighted(roll, level100 and MONEY_LEVEL100 or MONEY_NORMAL)
end

function L.specialHit(kind, roll)
  local spec = assert(L.SPECIAL[kind], "unknown special reward " .. tostring(kind))
  return clampRoll(roll, spec.denominator) <= spec.hits
end

function L.catalog(data, mode, ctx)
  local rows = L.pool(data, ctx)
  local total = 0
  for _, row in ipairs(rows) do total = total + row.effectiveWeight end
  local itemChance = L.itemChance(mode, ctx)
  local out = {}
  for _, row in ipairs(rows) do
    local copy_ = copy(row)
    copy_.chance = total > 0 and itemChance * row.effectiveWeight / total or 0
    out[#out + 1] = copy_
  end
  return out, 1 - itemChance
end

L.moneyBands = { normal = MONEY_NORMAL, level100 = MONEY_LEVEL100 }
L.basePool = BASE_POOL
-- Kept as a compatibility export for older Atlas consumers. New code uses
-- catalog(), because supported registry items make the final rows dynamic.
L.bands = { balanced = BASE_POOL, generous = BASE_POOL }

return L
