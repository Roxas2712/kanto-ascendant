local modPath = os.getenv("TRAINER_REMATCH_MOD_DIR") or "."
local P = assert(loadfile(modPath .. "/rematch_break_profiles.lua"))()

local assertions = 0
local function eq(actual, expected, message)
  assertions = assertions + 1
  assert(actual == expected, (message or "values differ") .. ": "
    .. tostring(actual) .. " ~= " .. tostring(expected))
end

local expected = {
  very_short = { 151, 302 },
  short = { 303, 604 },
  normal = { 605, 1255 },
  long = { 1256, 1882 },
  very_long = { 1883, 2510 },
}

for id, range in pairs(expected) do
  eq(P.PROFILES[id].min, range[1], id .. " minimum")
  eq(P.PROFILES[id].max, range[2], id .. " maximum")
  eq(P.profileForRange(range[1], range[2]), id,
    id .. " is recognized only by its exact pair")
  local lo, hi = P.range(id, 151, 2510)
  eq(lo, range[1], id .. " ignores the stored custom minimum")
  eq(hi, range[2], id .. " ignores the stored custom maximum")
end

eq(P.DEFAULT, "normal", "fresh saves default to NORMAL")
eq(P.profileForRange(151, 2510), "custom",
  "the historical full range migrates to CUSTOM")
eq(P.profileForRange(700, 900), "custom",
  "an arbitrary existing pair migrates to CUSTOM")
eq(P.profileForRange(1255, 605), "custom",
  "a reversed pair is not mislabeled as a preset")
eq(P.profileForRange(128, 256), "custom",
  "the oldest exact pair is preserved as CUSTOM")

local lo, hi = P.range("custom", 700, 900)
eq(lo, 700, "CUSTOM keeps an existing minimum")
eq(hi, 900, "CUSTOM keeps an existing maximum")
lo, hi = P.range("custom", 900, 700)
eq(lo, 700, "CUSTOM normalizes only the range used for a future roll")
eq(hi, 900, "CUSTOM does not require rewriting the stored pair")
lo, hi = P.range("custom", 128, 256)
eq(lo, 128, "legacy custom values remain numerically exact")
eq(hi, 256, "legacy custom values are not silently rerolled")

local old = { rest_min = 151, rest_max = 2510 }
local changed, profile = P.migrateBucket(old, false)
eq(changed, true, "an existing profile receives a stable profile id")
eq(profile, "custom", "the old default becomes CUSTOM")
eq(old.rest_min, 151, "migration never rewrites the existing minimum")
eq(old.rest_max, 2510, "migration never rewrites the existing maximum")

local exact = { rest_min = 303, rest_max = 604 }
changed, profile = P.migrateBucket(exact, false)
eq(changed, true, "an exact preset pair is migrated")
eq(profile, "short", "an exact preset pair gets its named profile")

local fresh = {}
changed, profile = P.migrateBucket(fresh, true)
eq(changed, true, "a fresh save records its profile explicitly")
eq(profile, "normal", "a fresh save starts on NORMAL")

local explicit = {
  rest_profile = "long", rest_min = 700, rest_max = 900,
}
changed, profile = P.migrateBucket(explicit, false)
eq(changed, false, "an explicit profile is never overwritten")
eq(profile, "long", "the explicit named profile remains selected")
eq(explicit.rest_min, 700, "switching away preserves the custom minimum")
eq(explicit.rest_max, 900, "switching away preserves the custom maximum")

local handlers = {}
local mod = {
  id = "kanto_ascendant",
  events = { on = function(_, name, fn, priority)
    handlers[name] = handlers[name] or {}
    handlers[name][#handlers[name] + 1] = {
      fn = fn, priority = tonumber(priority) or 0,
    }
    table.sort(handlers[name], function(a, b) return a.priority > b.priority end)
  end },
}
local function emit(name, payload)
  for _, row in ipairs(handlers[name] or {}) do row.fn(payload or {}) end
end
eq(P.install(mod), true, "profile migration installs real lifecycle handlers")
eq(handlers["save.loaded"][1].priority, 5000,
  "CONTINUE migration runs before rematch timer seeding")
eq(handlers["save.created"][1].priority, 5000,
  "New Game migration runs on the adopted fresh slot")

local bootstrapSave = { options = { modOptions = { kanto_ascendant = {
  rest_profile = "very_long", rest_min = 1883, rest_max = 2510,
} } } }
emit("save.created", { save = bootstrapSave })
eq(bootstrapSave.options.modOptions.kanto_ascendant.rest_profile, "very_long",
  "the pre-game boot skeleton cannot reset persisted CONTINUE options")

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
      trainers = { ROUTE_1_obj_1 = {
        readyAt = 1234, nextTrainingAt = 2345,
        lastRest = 151, lastTraining = 302,
      } },
      postgame = { bossRest = { ["master:brock"] = 3456 } },
      legacy_journey = { wanderer = {
        steps = 777, maps = 3, due = true, encore = 1,
      } },
    } },
  },
  writeOptions = function() writes = writes + 1 end,
}
P.bindGame(game)
emit("save.loaded")
local saved = game.save.options.modOptions.kanto_ascendant
eq(saved.rest_profile, "custom",
  "save.loaded maps historical 151-2510 to CUSTOM")
eq(saved.rest_min, 151, "save.loaded preserves the stored minimum")
eq(saved.rest_max, 2510, "save.loaded preserves the stored maximum")
eq(game.mods.modOptions.kanto_ascendant.rest_profile, "custom",
  "save.loaded synchronizes the active option bucket")
eq(writes, 1, "a migrated existing slot persists its profile exactly once")
local timers = game.save.modData.kanto_ascendant
eq(timers.trainers.ROUTE_1_obj_1.readyAt, 1234,
  "save.loaded never changes readyAt")
eq(timers.trainers.ROUTE_1_obj_1.nextTrainingAt, 2345,
  "save.loaded never changes nextTrainingAt")
eq(timers.postgame.bossRest["master:brock"], 3456,
  "save.loaded never changes bossRest")
eq(timers.legacy_journey.wanderer.steps, 777,
  "profile migration never changes Legacy Wanderer steps")
eq(timers.legacy_journey.wanderer.maps, 3,
  "profile migration never changes Legacy Wanderer map cadence")
eq(timers.legacy_journey.wanderer.due, true,
  "profile migration never changes a reserved Wanderer")

game.mods.modOptions.kanto_ascendant.rest_min = 999
game.mods.modOptions.kanto_ascendant.rest_max = 1000
game.save = {
  options = { modOptions = { kanto_ascendant = {
    rest_profile = "custom", rest_min = 700, rest_max = 900,
  } } },
  modData = { kanto_ascendant = {} },
}
emit("save.loaded", { save = game.save })
eq(game.mods.modOptions.kanto_ascendant.rest_profile, "custom",
  "an explicit save-local profile remains authoritative")
eq(game.mods.modOptions.kanto_ascendant.rest_min, 700,
  "save.loaded replaces a previous slot's live minimum")
eq(game.mods.modOptions.kanto_ascendant.rest_max, 900,
  "save.loaded replaces a previous slot's live maximum")
eq(writes, 1, "an already explicit profile needs no migration write")

game.save = {
  options = { modOptions = { kanto_ascendant = {
    rest_min = 303, rest_max = 604,
  } } },
  modData = { kanto_ascendant = {} },
}
emit("save.loaded", { save = game.save })
eq(game.save.options.modOptions.kanto_ascendant.rest_profile, "short",
  "a second slot derives its own exact preset independently")
eq(game.mods.modOptions.kanto_ascendant.rest_profile, "short",
  "the active bucket follows the newly loaded slot")
eq(writes, 2, "the second slot persists one independent migration")

game.save = {
  options = { modOptions = { kanto_ascendant = {
    rest_min = 151, rest_max = 2510,
  } } },
  modData = { kanto_ascendant = {} },
}
emit("save.created", { save = game.save })
eq(game.save.options.modOptions.kanto_ascendant.rest_profile, "normal",
  "save.created starts NORMAL despite the previously loaded slot")
eq(game.save.options.modOptions.kanto_ascendant.rest_min, 151,
  "fresh initialization leaves the saved custom minimum available")
eq(game.save.options.modOptions.kanto_ascendant.rest_max, 2510,
  "fresh initialization leaves the saved custom maximum available")
eq(game.mods.modOptions.kanto_ascendant.rest_profile, "normal",
  "fresh initialization replaces the prior slot's live profile only")
eq(game.mods.modOptions.kanto_ascendant.rest_min, 151,
  "fresh initialization cannot inherit a prior slot's live minimum")
eq(game.mods.modOptions.kanto_ascendant.rest_max, 2510,
  "fresh initialization cannot inherit a prior slot's live maximum")
eq(writes, 3, "fresh initialization is persisted exactly once")

print(("rematch break profiles: %d assertions passed"):format(assertions))
