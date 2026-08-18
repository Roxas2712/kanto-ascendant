-- Exact 0.1.96/0.1.98 lifecycle proof for save-local rematch profiles.

local engineRoot = assert(os.getenv("KA_ENGINE_ROOT"),
  "KA_ENGINE_ROOT is required")
local expected = assert(os.getenv("KA_EXPECT_ENGINE"),
  "KA_EXPECT_ENGINE is required")
local modRoot = assert(os.getenv("TRAINER_REMATCH_MOD_DIR"),
  "TRAINER_REMATCH_MOD_DIR is required")

package.path = engineRoot .. "/?.lua;" .. engineRoot .. "/?/init.lua;"
  .. package.path
local Version = assert(loadfile(engineRoot .. "/src/core/Version.lua"))()
assert(Version.engine == expected,
  "wrong exact engine: " .. tostring(Version.engine))
local Events = assert(loadfile(engineRoot .. "/src/mods/Events.lua"))()
local bus = Events.new()
local P = assert(loadfile(modRoot .. "/rematch_break_profiles.lua"))()

local mod = {
  id = "kanto_ascendant",
  events = { on = function(_, name, fn, priority)
    return bus:on(name, fn, priority, "kanto_ascendant")
  end },
}
assert(P.install(mod) == true, "lifecycle handlers were not installed")
assert(bus.listeners["save.loaded"][1].priority == 5000,
  "CONTINUE migration priority changed")
assert(bus.listeners["save.created"][1].priority == 5000,
  "New Game migration priority changed")

local writes = 0
local game = {
  mods = { modOptions = { kanto_ascendant = {
    rest_min = 999, rest_max = 1000,
  } } },
  save = {
    options = { modOptions = { kanto_ascendant = {
      rest_min = 151, rest_max = 2510,
    } } },
    modData = { kanto_ascendant = {
      trainers = { A = { readyAt = 321, nextTrainingAt = 654 } },
      postgame = { bossRest = { ["master:misty"] = 987 } },
    } },
  },
  writeOptions = function() writes = writes + 1 end,
}
P.bindGame(game)
bus:emit("save.loaded", { save = game.save })
local saved = game.save.options.modOptions.kanto_ascendant
assert(saved.rest_profile == "custom",
  "existing 151-2510 did not become CUSTOM")
assert(saved.rest_min == 151 and saved.rest_max == 2510,
  "existing numeric pair was rewritten")
assert(game.mods.modOptions.kanto_ascendant.rest_min == 151
    and game.mods.modOptions.kanto_ascendant.rest_max == 2510,
  "live options inherited a different slot's numeric range")
assert(game.save.modData.kanto_ascendant.trainers.A.readyAt == 321,
  "readyAt changed during exact-engine event dispatch")
assert(game.save.modData.kanto_ascendant.trainers.A.nextTrainingAt == 654,
  "nextTrainingAt changed during exact-engine event dispatch")
assert(game.save.modData.kanto_ascendant.postgame
  .bossRest["master:misty"] == 987,
  "bossRest changed during exact-engine event dispatch")

game.save = {
  options = { modOptions = { kanto_ascendant = {
    rest_min = 151, rest_max = 2510,
  } } },
  modData = { kanto_ascendant = {} },
}
bus:emit("save.created", { save = game.save })
assert(game.save.options.modOptions.kanto_ascendant.rest_profile == "normal",
  "fresh save inherited the previous slot instead of NORMAL")
assert(game.mods.modOptions.kanto_ascendant.rest_profile == "normal",
  "live options did not follow the adopted fresh save")
assert(game.mods.modOptions.kanto_ascendant.rest_min == 151
    and game.mods.modOptions.kanto_ascendant.rest_max == 2510,
  "fresh slot inherited a previous slot's custom range")
assert(writes == 2, "each changed slot must persist exactly once")

print(("REMATCH BREAK PROFILE ENGINE PASS: engine=%s"):format(expected))
