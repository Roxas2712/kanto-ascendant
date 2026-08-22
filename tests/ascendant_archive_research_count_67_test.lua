-- The Crown Archive must count only research assignments that are active for
-- the current option set. Completed rows disabled by configuration remain in
-- old saves, but must not inflate the visible numerator above the denominator.

local source = debug.getinfo(1, "S").source:sub(2)
local root = os.getenv("TRAINER_REMATCH_MOD_DIR")
  or source:match("^(.*)/tests/") or "."

local saved = {
  ascendant = {
    research = { completed = {
      field = true,
      legend_signals = true,
      tournament = true,
      rocket = true,
    } },
    gymQuests = {}, achievements = {}, metrics = {}, bossBattles = {},
    tournament = { runs = 0, wins = 0, best = 0 },
    frontierPoints = 0, typeMastery = {}, rocketStage = 0,
    mewStage = 0, cycle = 0,
  },
}

local mod = {
  save = {
    get = function(_, key) return saved[key] end,
    set = function(_, key, value) saved[key] = value end,
  },
  -- Disable the three conditional research rows in this fixture.
  options = { get = function() return false end },
  hooks = { wrap = function() end },
  events = { on = function() end },
  ui = { insertBefore = function(items) return items end },
}

local data = {
  ranks = { { threshold = 0 } },
  research = {
    { id = "field" },
    { id = "legend_signals" },
    { id = "tournament" },
    { id = "rocket" },
  },
  achievements = {},
  gymQuests = {},
  rocket = { {} },
  tournament = { name = "TOURNAMENT_HOST", rules = {}, opponents = {} },
  newGamePlus = { name = "NGPLUS_HOST" },
  mew = { name = "MEW_HOST", clues = {} },
  world = {}, worldMoments = {},
}

local makeAscendant = assert(loadfile(root .. "/ascendant.lua"))()
local ascendant = makeAscendant(mod, {
  gyms = {}, legendOrder = {},
}, { data = data, placement = {} })

local archive = ascendant.archiveText({ save = {} })
assert(archive:find("RESEARCH: 1/1", 1, true),
  "Crown Archive did not report only enabled research (got "
    .. tostring(archive) .. ")")
assert(not archive:find("RESEARCH: 4/1", 1, true),
  "disabled completed research inflated the Crown Archive numerator")

print("ascendant archive research count 6.7 test passed")
