-- Shared ordinary-Johto encounter-level policy.

local modulePath = os.getenv("KANTO_SIGNALS_MOD_DIR") or "."
local levels =
  assert(loadfile(modulePath .. "/johto_encounter_levels.lua"))()

local assertions = 0
local function eq(actual, expected, message)
  assertions = assertions + 1
  if actual ~= expected then
    error(("FAIL: %s\nexpected: %s\nactual:   %s")
      :format(message, tostring(expected), tostring(actual)), 2)
  end
end

local routeOne = {
  grass = {
    slots = {
      { level = 3 }, { level = 3 }, { level = 3 }, { level = 2 },
      { level = 2 }, { level = 3 }, { level = 3 }, { level = 4 },
      { level = 4 }, { level = 5 },
    },
  },
}

eq(levels.routeAverage(routeOne, "grass"), 3,
  "Route 1's Gen-I-weighted average rounds to level 3")
levels.setBonusRange(2, 5)
eq(levels.ordinaryLevel(routeOne, "grass",
    function(lo) return lo end, 99), 5,
  "an ordinary Johto replacement can be exactly average plus two")
eq(levels.ordinaryLevel(routeOne, "grass",
    function(_, hi) return hi end, 99), 8,
  "the legacy 2..5 compatibility band can still be selected")

levels.setBonusRange(2, 8)
eq(levels.ordinaryLevel(routeOne, "grass",
    function(_, hi) return hi end, 99), 11,
  "the 6.5 ordinary Johto replacement reaches average plus eight")

local customBuckets = {
  water = {
    buckets = { 10, 256 },
    slots = {
      { level = 2 },
      { level = 10 },
    },
  },
}
eq(levels.routeAverage(customBuckets, "water"), 10,
  "custom encounter buckets control the weighted route average")

local normalizedWater = {
  grass = {
    slots = {
      { level = 20 },
      { level = 22 },
    },
  },
}
eq(levels.routeAverage(normalizedWater, "water"), 21,
  "the regular engine's normalized surfing table remains supported")
eq(levels.ordinaryLevelFromAverage(nil,
    function(lo) return lo end, 7), 9,
  "a direct compatibility call falls back to native level plus two")
eq(levels.ordinaryLevelFromAverage(99,
    function(_, hi) return hi end, 1), 100,
  "the ordinary Johto band respects the level-100 ceiling")

print(("JOHTO ENCOUNTER LEVELS PASS: %d assertions"):format(assertions))
