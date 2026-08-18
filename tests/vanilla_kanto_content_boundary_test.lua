-- Product boundary: Johto content may add ids and append evolution branches,
-- but it must not rewrite existing Generation-I species or moves.
-- Run from the engine checkout with TRAINER_REMATCH_MOD_DIR set.

package.path = "./?.lua;./?/init.lua;" .. package.path

local Merge = require("src.mods.Merge")
local TypeChart = require("src.battle.TypeChart")

local root = assert(os.getenv("TRAINER_REMATCH_MOD_DIR"),
  "TRAINER_REMATCH_MOD_DIR is required")

local function loadRoot(filename)
  local chunk, err = loadfile(root .. "/" .. filename)
  assert(chunk, err)
  return chunk()
end

local function readRoot(filename)
  local file = io.open(root .. "/" .. filename, "rb")
  if not file then return nil end
  local body = file:read("*a")
  file:close()
  return body
end

local function deepEqual(left, right, path)
  path = path or "$"
  if type(left) ~= type(right) then
    return false, path .. " type " .. type(left) .. " != " .. type(right)
  end
  if type(left) ~= "table" then
    if left ~= right then
      return false, path .. " " .. tostring(left) .. " != " .. tostring(right)
    end
    return true
  end
  for key, value in pairs(left) do
    local ok, err = deepEqual(value, right[key],
      path .. "[" .. tostring(key) .. "]")
    if not ok then return false, err end
  end
  for key in pairs(right) do
    if left[key] == nil then
      return false, path .. " gained field " .. tostring(key)
    end
  end
  return true
end

local function records(name, initial, semantics)
  local values = Merge.deepCopy(initial or {})
  local api = {}
  function api:get(id) return values[id] end
  function api:register(id, value)
    assert(values[id] == nil, name .. " already registered: " .. tostring(id))
    values[id] = Merge.deepCopy(value)
    return value
  end
  function api:override(id, value)
    values[id] = Merge.deepCopy(value)
    return value
  end
  function api:patch(id, partial)
    values[id] = Merge.deepMerge(
      Merge.deepCopy(values[id] == nil and {} or values[id]),
      partial, semantics or "record")
    return partial
  end
  api.values = values
  return api
end

local basePokemon = require("data.generated.pokemon")
local baseMoves = require("data.generated.moves")
local baseItems = require("data.generated.items")
local generatedChart = require("data.generated.type_chart")

local chartRecords = {}
for id, value in pairs(TypeChart.TYPES) do
  chartRecords[id] = Merge.deepCopy(value)
end
for _, row in ipairs(generatedChart.matchups) do
  chartRecords[row.attacker .. ">" .. row.defender] = {
    multiplier = row.multiplier,
  }
end

local content = {
  pokemon = records("pokemon", basePokemon),
  moves = records("moves", baseMoves),
  items = records("items", baseItems),
  type_chart = records("type_chart", chartRecords),
  move_effects = records("move_effects"),
  evolution_methods = records("evolution_methods"),
  icons = records("icons"),
  text = records("text"),
  constants = records("constants", { dexSize = 151, dexDigits = 3 }, "deep"),
}

local mod = {
  id = "kanto_ascendant",
  path = root,
  manifest = { id = "kanto_ascendant", version = "6.5.0" },
  content = content,
  exports = {},
  options = { get = function() return "auto" end },
  hooks = { wrap = function() return true end },
  log = {
    info = function() end,
    warn = function() end,
    error = function() end,
  },
}
function mod:read(filename)
  if filename == "crystal_learnsets.lua"
      or filename == "crystal_learnset_compat.lua" then
    return readRoot(filename)
  end
  -- Asset presence is irrelevant to this data-boundary test. Returning nil
  -- deliberately takes the module's documented built-in fallback path.
  return nil
end

local beforePokemon, kantoIds = {}, {}
for id, record in pairs(basePokemon) do
  if tonumber(record.dex) and record.dex >= 1 and record.dex <= 151 then
    beforePokemon[id] = Merge.deepCopy(record)
    kantoIds[id] = true
  end
end
local beforeMoves = Merge.deepCopy(baseMoves)
local beforeChart = Merge.deepCopy(chartRecords)

local install = loadRoot("postgame_species.lua")
local installed = install(mod, loadRoot("postgame_data.lua"),
  loadRoot("johto_data.lua"), { isGerman = function() return false end })
assert(installed == true, "Johto content did not install")

-- Existing move records are an absolute boundary: no field, category,
-- effect, animation or value may change. New move ids remain allowed.
for id, expected in pairs(beforeMoves) do
  local actual = assert(content.moves:get(id), "removed Gen-I move " .. id)
  local ok, err = deepEqual(expected, actual, "moves." .. id)
  assert(ok, "mutated Gen-I move: " .. tostring(err))
end

-- Existing species records retain every original field. Johto evolution
-- branches are the one intentional additive seam: the original list must be
-- an identical prefix and every appended target must itself be a new id.
for id, expected in pairs(beforePokemon) do
  local actual = assert(content.pokemon:get(id), "removed Kanto species " .. id)
  for key, value in pairs(expected) do
    if key ~= "evolutions" then
      local ok, err = deepEqual(value, actual[key],
        "pokemon." .. id .. "." .. tostring(key))
      assert(ok, "mutated Kanto species: " .. tostring(err))
    end
  end
  for key in pairs(actual) do
    assert(expected[key] ~= nil or key == "evolutions",
      "Kanto species gained non-additive field: " .. id .. "." .. tostring(key))
  end
  local original = expected.evolutions or {}
  local current = actual.evolutions or {}
  assert(#current >= #original, "Kanto evolution list shrank: " .. id)
  for index, row in ipairs(original) do
    local ok, err = deepEqual(row, current[index],
      "pokemon." .. id .. ".evolutions[" .. index .. "]")
    assert(ok, "mutated Kanto evolution: " .. tostring(err))
  end
  for index = #original + 1, #current do
    local target = current[index] and current[index].species
    assert(type(target) == "string" and not kantoIds[target],
      "non-additive Kanto evolution target: " .. id .. " -> " .. tostring(target))
  end
end

-- Original type ids and chart rows remain exact; Dark/Steel rows are new
-- records, not patches to vanilla rows.
for id, expected in pairs(beforeChart) do
  local actual = assert(content.type_chart:get(id), "removed vanilla chart id " .. id)
  local ok, err = deepEqual(expected, actual, "type_chart." .. id)
  assert(ok, "mutated vanilla type chart: " .. tostring(err))
end

assert(content.type_chart:get("DARK") and content.type_chart:get("STEEL"),
  "additive Dark/Steel types missing")
assert(content.pokemon:get("CHIKORITA") and content.pokemon:get("CELEBI"),
  "additive Johto species missing")
assert(content.moves:get("CRUNCH") and content.moves:get("METAL_CLAW"),
  "additive Johto moves missing")
local gigaDrain = assert(content.moves:get("GIGA_DRAIN"),
  "additive Giga Drain move missing")
assert(gigaDrain.power == 60 and gigaDrain.effect == "DRAIN_HP_EFFECT",
  "Giga Drain must keep its Gen-II 60 BP half-damage recovery effect")

for _, id in ipairs({ "MAGNEMITE", "MAGNETON" }) do
  local ok, err = deepEqual(beforePokemon[id].types,
    content.pokemon:get(id).types, "pokemon." .. id .. ".types")
  assert(ok, "Kanto type regression: " .. tostring(err))
end
for _, id in ipairs({ "BITE", "GUST", "SAND_ATTACK", "KARATE_CHOP" }) do
  local ok, err = deepEqual(beforeMoves[id], content.moves:get(id), "moves." .. id)
  assert(ok, "Kanto move regression: " .. tostring(err))
end

print("vanilla Kanto content boundary tests passed")
