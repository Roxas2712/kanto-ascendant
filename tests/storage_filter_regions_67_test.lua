-- Box region filters are canonical regional views, not a broad split at 151.
-- Later discovery species remain available under ALL without leaking into
-- either the Kanto or Johto filter.

local root = assert(os.getenv("TRAINER_REMATCH_MOD_DIR"),
  "TRAINER_REMATCH_MOD_DIR is required")

local function eq(actual, expected, message)
  if actual ~= expected then
    error((message or "values differ") .. ": expected " .. tostring(expected)
      .. ", got " .. tostring(actual), 2)
  end
end

local PokedexMenu = { new = function() return { items = {}, index = 1 } end }
local ListMenu = {}
function ListMenu.new(game, title, items)
  return { game = game, title = title, items = items, index = 1 }
end
package.loaded["src.ui.PokedexMenu"] = PokedexMenu
package.loaded["src.ui.ListMenu"] = ListMenu

local boxMode = "all"
local mod = {
  options = {
    get = function(_, key)
      if key == "box_filter" then return boxMode end
      if key == "pokedex_filter" then return "all" end
      return nil
    end,
  },
}
assert(loadfile(root .. "/storage_filters.lua"))()(mod)

local game = {
  data = { pokemon = {
    BULBASAUR = { dex = 1 },
    CHIKORITA = { dex = 152 },
    CELEBI = { dex = 251 },
    JIRACHI = { dex = 385 },
    TURTWIG = { dex = 387 },
  } },
  save = {
    currentBox = 1,
    boxes = { {
      { species = "BULBASAUR" },
      { species = "CHIKORITA" },
      { species = "CELEBI" },
      { species = "JIRACHI" },
      { species = "TURTWIG" },
      { species = "MISSING_SPECIES" },
    } },
  },
}
local items = {}
for index = 1, 6 do items[index] = { label = tostring(index), value = index } end

local function values(mode)
  boxMode = mode
  local menu = ListMenu.new(game, "WITHDRAW", items)
  local out = {}
  for _, item in ipairs(menu.items) do out[#out + 1] = item.value end
  return table.concat(out, ",")
end

eq(values("all"), "1,2,3,4,5,6",
  "ALL remains a non-destructive view of every box row")
eq(values("kanto"), "1",
  "KANTO means only canonical Dex numbers 1 through 151")
eq(values("johto"), "2,3",
  "JOHTO means only canonical Dex numbers 152 through 251")

print("STORAGE FILTER REGIONS 6.7 PASS")
