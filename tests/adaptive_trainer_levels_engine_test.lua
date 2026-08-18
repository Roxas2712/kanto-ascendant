-- Exact 0.1.96/0.1.98 lifecycle contract for Adaptive Trainer Levels.
-- Run from the selected engine root with KA_EXPECT_ENGINE set.

package.path = "./?.lua;./?/init.lua;" .. package.path

local engine = assert(os.getenv("KA_EXPECT_ENGINE"),
  "KA_EXPECT_ENGINE is required")
assert(engine == "0.1.96" or engine == "0.1.98" or engine == "broad",
  "unexpected engine contract " .. tostring(engine))
local modRoot = assert(os.getenv("TRAINER_REMATCH_MOD_DIR"),
  "TRAINER_REMATCH_MOD_DIR is required")

local function source(path)
  local file = assert(io.open(path, "rb"))
  local text = assert(file:read("*a"))
  file:close()
  return text
end

-- Both shipped engine lines adopt the fresh/save slot before they announce
-- its lifecycle event. This is what makes mod.save point at the correct
-- bucket and prevents title-screen skeleton, Continue and New Game leakage.
local gameSource = source("src/core/Game.lua")
local bootAdopt = assert(gameSource:find(
  "self:adoptSave(self.save, true)", 1, true))
local bootCreated = assert(gameSource:find(
  'ModRuntime.emit("save.created"', bootAdopt, true))
assert(bootAdopt < bootCreated, "boot skeleton emits before adopting save")
local newAdopt = assert(gameSource:find(
  "self:adoptSave(self.save)", bootCreated + 1, true))
local newCreated = assert(gameSource:find(
  'ModRuntime.emit("save.created"', newAdopt, true))
assert(newAdopt < newCreated, "New Game emits before adopting fresh save")
local loadedAdopt = assert(gameSource:find(
  "self:adoptSave(loaded)", newCreated + 1, true))
local loadedEvent = assert(gameSource:find(
  'ModRuntime.emit("save.loaded"', loadedAdopt, true))
assert(loadedAdopt < loadedEvent, "Continue emits before adopting loaded slot")

local Events = require("src.mods.Events")
local bus = Events.new()
local activeBucket = {}
local values = { difficulty = "hard", adaptive_trainer_levels = "auto" }
local mod = {
  id = "kanto_ascendant",
  options = { get = function(_, key) return values[key] end },
  save = {
    get = function(_, key, default)
      local value = activeBucket[key]
      return value == nil and default or value
    end,
    set = function(_, key, value) activeBucket[key] = value end,
  },
  events = { on = function(_, name, fn, priority)
    return bus:on(name, fn, priority, "kanto_ascendant")
  end },
}
local adaptive = assert(loadfile(modRoot .. "/adaptive_trainer_levels.lua"))()(
  mod, { difficulty = {
    progressionBonus = function() return 2 end,
  } })

local function state()
  return activeBucket[adaptive.STATE_KEY]
end

-- Exact EventBus priority ordering and real lifecycle names used by .96/.98.
assert(bus.listeners["save.created"][1].priority == 120)
assert(bus.listeners["save.loaded"][1].priority == 120)
assert(bus.listeners["battle.started"][1].priority == -100)

activeBucket = {}
bus:emit("save.created", { save = { modData = {
  kanto_ascendant = activeBucket,
} } })
assert(state() and state().legacyHold == false,
  "fresh New Game must start AUTO without a legacy hold")
local freshBucket = activeBucket

activeBucket = {}
bus:emit("save.loaded", { save = { modData = {
  kanto_ascendant = activeBucket,
} } })
assert(state() and state().legacyHold == true,
  "unmarked existing slot must stay classic")
assert(adaptive.currentSelection() == "off" and adaptive.currentGap() == nil,
  "legacy hold must be effective OFF despite raw AUTO")
local legacyBucket = activeBucket

activeBucket = {}
bus:emit("save.created", { save = { modData = {
  kanto_ascendant = activeBucket,
} } })
assert(state().legacyHold == false,
  "New Game after Continue must not inherit legacy state")
assert(activeBucket ~= freshBucket and activeBucket ~= legacyBucket,
  "slot buckets remain independent")

activeBucket = legacyBucket
bus:emit("mod.options_changed", { mod = "kanto_ascendant",
  key = "difficulty", value = "hard" })
assert(state().legacyHold == false and adaptive.currentGap() == 2,
  "reselecting Difficulty deliberately activates held AUTO")
values.adaptive_trainer_levels = "6"
bus:emit("mod.options_changed", { mod = "kanto_ascendant",
  key = "adaptive_trainer_levels", value = "6" })
values.difficulty = "extreme"
bus:emit("mod.options_changed", { mod = "kanto_ascendant",
  key = "difficulty", value = "extreme" })
assert(adaptive.currentGap() == 6,
  "Difficulty changes never overwrite a manual target gap")

print("adaptive_trainer_levels_engine_test: PASS engine=" .. engine)
