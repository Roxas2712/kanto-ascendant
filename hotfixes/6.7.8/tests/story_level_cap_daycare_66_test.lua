local checks = 0
local function eq(actual, expected, label)
  checks = checks + 1
  assert(actual == expected, (label or "values differ") .. ": "
    .. tostring(actual) .. " ~= " .. tostring(expected))
end
local function ok(value, label)
  checks = checks + 1
  assert(value, label)
end

package.preload["src.pokemon.Growth"] = function()
  local G = {}
  function G.expForLevel(_, level) return level * level * level end
  function G.levelForExp(_, exp, cap)
    local level = 1
    while level < (cap or 100) and (level + 1) ^ 3 <= exp do
      level = level + 1
    end
    return level
  end
  return G
end
package.preload["src.pokemon.Pokemon"] = function()
  return { heal = function() end }
end

local stored = { daycare_plus = {
  version = 3, parents = {}, reservedEggs = {}, eggsProduced = 0,
  eggsHatched = 0,
} }
local events = {}
local mod = {
  id = "kanto_ascendant",
  save = {
    get = function(_, key, fallback)
      local value = stored[key]
      return value == nil and fallback or value
    end,
    set = function(_, key, value) stored[key] = value end,
  },
  hooks = { wrap = function() end },
  events = { on = function(_, name, fn)
    events[name] = events[name] or {}
    events[name][#events[name] + 1] = fn
  end },
  options = { get = function() return false end },
  world = { overworld = function() return nil end },
}

local daycare = assert(loadfile("daycare.lua"))()(mod, {})
local activeCap = 10
daycare.setLevelCap({ effective = function()
  return activeCap and { level = activeCap } or nil
end })

local game = {
  data = { pokemon = { BULBASAUR = {
    growthRate = "MEDIUM_FAST", types = { "GRASS" }, evolutions = {},
  } }, moves = {}, maps = {} },
  save = { party = {}, player = { name = "RED", id = 7 } },
}
daycare.install(game)

local function step(count)
  for _ = 1, count or 1 do
    for _, fn in ipairs(events["world.stepped"] or {}) do fn() end
  end
end

local mon = { species = "BULBASAUR", level = 9, exp = 9 ^ 3 }
stored.daycare_plus.parents[1] = { mon = mon, depositLevel = 9, steps = 0 }
step(500)
eq(stored.daycare_plus.parents[1].steps, 10 ^ 3 - 9 ^ 3,
  "Day-Care stores only experience accepted through the cap")
local level, exp = daycare.levelPreview(game, stored.daycare_plus.parents[1])
eq(level, 10, "Day-Care preview reaches the cap")
eq(exp, 10 ^ 3, "Day-Care preview clamps at the cap threshold")
step(100)
eq(stored.daycare_plus.parents[1].steps, 10 ^ 3 - 9 ^ 3,
  "steps walked at the cap are discarded instead of banked")

local imported = { species = "BULBASAUR", level = 12, exp = 12 ^ 3 }
stored.daycare_plus.parents[1] = {
  mon = imported, depositLevel = 12, steps = 0,
}
step(1)
eq(stored.daycare_plus.parents[1].steps, 0,
  "imported over-level parent earns no pending experience")
level, exp = daycare.levelPreview(game, stored.daycare_plus.parents[1])
eq(level, 12, "imported over-level parent is never down-leveled")
eq(exp, 12 ^ 3, "imported over-level experience is never rewritten")

local inconsistent = { species = "BULBASAUR", level = 5, exp = 20 ^ 3 }
stored.daycare_plus.parents[1] = {
  mon = inconsistent, depositLevel = 5, steps = 0,
}
step(1)
level, exp = daycare.levelPreview(game, stored.daycare_plus.parents[1])
eq(stored.daycare_plus.parents[1].steps, 0,
  "inconsistent imported experience cannot accrue a hidden bank")
eq(exp, 20 ^ 3, "inconsistent imported experience never moves backwards")
eq(inconsistent.exp, 20 ^ 3, "preview never mutates the imported record")

activeCap = nil
step(1)
eq(stored.daycare_plus.parents[1].steps, 1,
  "OFF preserves the legacy one-step-one-point path")
ok(level >= 5, "preview remained valid")

print(("story_level_cap_daycare_66_test: PASS checks=%d"):format(checks))
