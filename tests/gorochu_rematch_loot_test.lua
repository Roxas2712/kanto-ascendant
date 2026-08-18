local modPath = os.getenv("TRAINER_REMATCH_MOD_DIR") or "."

local checks = 0
local function check(value, message)
  checks = checks + 1
  assert(value, message)
end

local function eq(actual, expected, message)
  checks = checks + 1
  assert(actual == expected, (message or "values differ") .. ": "
    .. tostring(actual) .. " ~= " .. tostring(expected))
end

local loot = assert(loadfile(modPath .. "/rematch_loot.lua"))()
local data = { items = {}, pokemon = {}, balls = {} }

for _, row in ipairs(loot.basePool) do
  data.items[row.item] = { id = row.item, name = row.item, price = 100 }
end

local evolutionItems = {
  "SUN_STONE", "KINGS_ROCK", "METAL_COAT", "DRAGON_SCALE", "UPGRADE",
}
for index, itemId in ipairs(evolutionItems) do
  data.items[itemId] = { id = itemId, name = itemId, price = 100 }
  data.pokemon["EVOLUTION_SOURCE_" .. index] = {
    evolutions = {
      { method = "ITEM", item = itemId, species = "EVOLUTION_TARGET_" .. index },
    },
  }
end

for _, itemId in ipairs({
  "FAST_BALL", "FRIEND_BALL", "HEAVY_BALL", "LEVEL_BALL", "LOVE_BALL",
  "LURE_BALL", "MOON_BALL",
}) do
  data.items[itemId] = { id = itemId, name = itemId, price = 100 }
  data.balls[itemId] = { id = itemId }
end

data.pokemon.RAICHU = {
  id = "RAICHU",
  icon = "QUADRUPED",
  growthRate = "MEDIUM_FAST",
  tmhm = {},
  evolutions = {},
}

local bucket = {}
local mod = {
  id = "kanto_ascendant",
  path = modPath,
  manifest = { id = "kanto_ascendant" },
  save = {
    get = function(_, key) return bucket[key] end,
    set = function(_, key, value) bucket[key] = value end,
  },
  content = {
    items = {
      register = function(_, id, def) data.items[id] = def end,
    },
    pokemon = {
      get = function(_, id) return data.pokemon[id] end,
      register = function(_, id, def) data.pokemon[id] = def end,
      patch = function(_, id, patch)
        for key, value in pairs(patch) do data.pokemon[id][key] = value end
      end,
    },
    icons = { register = function() end },
  },
  hooks = { wrap = function() end },
  events = { on = function() end },
  ui = { insertBefore = function(rows) return rows end },
}

local registerGorochu = assert(loadfile(modPath .. "/gorochu.lua"))()
local gorochu = registerGorochu(mod)
eq(gorochu.tearItemId, "ASCENDANT_THUNDER_TEAR",
  "the test loaded the canonical Gorochu item definition")

local tear = assert(data.items[gorochu.tearItemId],
  "Gorochu did not register its Thunder Tear")
eq(tear.lootExcluded, true,
  "Thunder Tear must be explicitly excluded from generic reward pools")
eq(tear.progressionItem, true,
  "Thunder Tear must carry progression-item metadata")

local total, sawTear = 0, false
for _, row in ipairs(loot.pool(data, {})) do
  total = total + row.weight
  if row.item == gorochu.tearItemId then sawTear = true end
end
check(not sawTear,
  "the one-time Gorochu Thunder Tear entered ordinary rematch loot")
check(math.abs(total - 120.5) < 0.000001,
  "the audited ordinary pool must stay at 120.5 weight, got " .. total)

print("PASS gorochu rematch loot: " .. checks .. " checks")
