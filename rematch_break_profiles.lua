-- Stable, save-safe recovery profiles shared by ordinary field rematches,
-- their silent training clock and post-game Gym rematches. Legacy Wanderers
-- intentionally own a separate cadence and never call this module.

local P = {
  DEFAULT = "normal",
  CUSTOM = "custom",
  CUSTOM_MIN = 151,
  CUSTOM_MAX = 2510,
  ORDER = { "very_short", "short", "normal", "long", "very_long", "custom" },
  PROFILES = {
    very_short = { min = 151, max = 302 },
    short = { min = 303, max = 604 },
    normal = { min = 605, max = 1255 },
    long = { min = 1256, max = 1882 },
    very_long = { min = 1883, max = 2510 },
    custom = { min = 151, max = 2510 },
  },
}

local function integer(value)
  value = tonumber(value)
  if not value or value ~= math.floor(value) then return nil end
  return value
end

function P.valid(profile)
  return type(profile) == "string" and P.PROFILES[profile] ~= nil
end

-- Only a literal named pair earns that label. In particular, the historical
-- 151-2510 default and every hand-tuned range become CUSTOM without either
-- number being rewritten.
function P.profileForRange(minimum, maximum)
  minimum, maximum = integer(minimum), integer(maximum)
  for _, id in ipairs(P.ORDER) do
    if id ~= P.CUSTOM then
      local row = P.PROFILES[id]
      if minimum == row.min and maximum == row.max then return id end
    end
  end
  return P.CUSTOM
end

-- Resolving a range is deliberately pure. Named profiles ignore the stored
-- custom pair, so switching away and back cannot erase a player's values.
-- Very old 128-256 values remain usable until the player edits them; the UI's
-- supported custom input range remains 151-2510.
function P.range(profile, customMinimum, customMaximum)
  if P.valid(profile) and profile ~= P.CUSTOM then
    local row = P.PROFILES[profile]
    return row.min, row.max
  end
  local minimum = integer(customMinimum) or P.CUSTOM_MIN
  local maximum = integer(customMaximum) or P.CUSTOM_MAX
  minimum = math.max(1, math.min(P.CUSTOM_MAX, minimum))
  maximum = math.max(1, math.min(P.CUSTOM_MAX, maximum))
  if minimum > maximum then minimum, maximum = maximum, minimum end
  return minimum, maximum
end

function P.migrateBucket(bucket, fresh)
  if type(bucket) ~= "table" then return false, nil end
  if P.valid(bucket.rest_profile) then
    return false, bucket.rest_profile
  end
  local profile = fresh and P.DEFAULT
    or P.profileForRange(bucket.rest_min, bucket.rest_max)
  bucket.rest_profile = profile
  return true, profile
end

function P.migrateGameOptions(modId, game, fresh)
  if type(modId) ~= "string" or type(game) ~= "table" then
    return false, nil
  end
  game.mods = game.mods or {}
  game.mods.modOptions = game.mods.modOptions or {}
  local live = game.mods.modOptions[modId]
  if type(live) ~= "table" then
    live = {}
    game.mods.modOptions[modId] = live
  end
  game.save = game.save or {}
  game.save.options = game.save.options or {}
  game.save.options.modOptions = game.save.options.modOptions or {}
  local saved = game.save.options.modOptions[modId]
  if type(saved) ~= "table" then
    saved = {}
    game.save.options.modOptions[modId] = saved
  end

  -- The save-local bucket is authoritative. Never infer a slot from the
  -- process-global live bucket: it may still contain the previously loaded
  -- slot while save.loaded/save.created is being dispatched.
  local savedMinimum = saved.rest_min ~= nil
    and saved.rest_min or P.CUSTOM_MIN
  local savedMaximum = saved.rest_max ~= nil
    and saved.rest_max or P.CUSTOM_MAX
  local function syncLiveRange()
    live.rest_min = savedMinimum
    live.rest_max = savedMaximum
  end

  if fresh == true then
    local changed = saved.rest_profile ~= P.DEFAULT
    saved.rest_profile = P.DEFAULT
    live.rest_profile = P.DEFAULT
    syncLiveRange()
    if changed and type(game.writeOptions) == "function" then
      game:writeOptions()
    end
    return changed, P.DEFAULT
  end
  if P.valid(saved.rest_profile) then
    live.rest_profile = saved.rest_profile
    syncLiveRange()
    return false, saved.rest_profile
  end

  local candidate = {
    rest_min = savedMinimum,
    rest_max = savedMaximum,
  }
  local _, profile = P.migrateBucket(candidate, false)
  saved.rest_profile = profile
  live.rest_profile = profile
  syncLiveRange()
  if type(game.writeOptions) == "function" then game:writeOptions() end
  return true, profile
end

function P.bindGame(game)
  P.game = game
  return game
end

function P.install(mod)
  if P.installed then return false end
  assert(mod and type(mod.id) == "string" and mod.events,
    "rematch break profiles require a mod event facade")
  local function migrate(ev, fresh)
    local game = ev and ev.game or P.game
    return P.migrateGameOptions(mod.id, game, fresh)
  end
  -- Run before rematch seeding on CONTINUE. New Game has already adopted its
  -- slot by save.created, so the same handler is save-local on both engines.
  mod.events:on("save.loaded", function(ev) migrate(ev, false) end, 5000)
  mod.events:on("save.created", function(ev) migrate(ev, true) end, 5000)
  P.installed = true
  return true
end

return P
