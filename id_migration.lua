-- One-way runtime migration from Kanto Ascendant's historical, conflicting
-- `trainer_rematch` namespace to its own permanent `kanto_ascendant` id.
-- The old buckets are deliberately retained as rollback snapshots: current
-- code writes only the new namespace, while an accepted older build can still
-- read the state it last owned.

local M = {}

M.LEGACY_ID = "trainer_rematch"
M.CURRENT_ID = "kanto_ascendant"

local OPTION_SIGNATURES = {
  "kanto_151", "johto_signals_enable", "follower_count",
  "ascendant_rules", "mega_evolution", "living_world_enabled",
  "living_world_random_encounters", "johto_time", "legend_art",
  "ascendant_qol", "pokemon_sprite_style", "character_sprite_style",
  "trainer_portrait_style",
}

local SAVE_SIGNATURES = {
  "ascendant", "johto_research", "kanto_completion", "legacy_hall",
  "mega_evolution", "postgame", "world_events",
}

local function copy(value, seen)
  if type(value) ~= "table" then return value end
  seen = seen or {}
  if seen[value] then return seen[value] end
  local out = {}
  seen[value] = out
  for key, item in pairs(value) do
    out[copy(key, seen)] = copy(item, seen)
  end
  return out
end

local function hasAny(bucket, keys)
  if type(bucket) ~= "table" then return false end
  for _, key in ipairs(keys) do
    if bucket[key] ~= nil then return true end
  end
  return false
end

local function legacyMetaVersion(raw)
  for _, row in ipairs(type(raw) == "table" and raw.meta
      and raw.meta.mods or {}) do
    if type(row) == "table" and row.id == M.LEGACY_ID then
      return tostring(row.version or "")
    end
  end
  return nil
end

local function looksLikeAscendant(raw, legacyOptions)
  local legacySave = type(raw) == "table" and raw.modData
    and raw.modData[M.LEGACY_ID]
  if hasAny(legacyOptions, OPTION_SIGNATURES)
      or hasAny(legacySave, SAVE_SIGNATURES) then
    return true
  end
  -- The migration targets the accepted 6.x line. This also covers players
  -- who never changed an option and whose save has not initialized a later
  -- subsystem yet, without claiming the unrelated trainer-rematch mod's 1.x
  -- namespace.
  local version = legacyMetaVersion(raw)
  return version ~= nil and version:match("^6%.") ~= nil
end

local function mergeMissing(target, source)
  target = type(target) == "table" and target or {}
  if type(source) ~= "table" then return target end
  for key, value in pairs(source) do
    if target[key] == nil then target[key] = copy(value) end
  end
  return target
end

function M.loadOptions(mod)
  -- identity_migration runs first and exports a data-only snapshot of the two
  -- identities before it merges the old bucket into the live loader.  This
  -- replaces the former raw SaveData.loadOptions escape, which is correctly
  -- absent from the 0.1.86 sandbox facade.
  local bridge = mod and mod.exports and mod.exports.identityMigration
  if type(bridge) ~= "table" or bridge.legacyOptionsDetected ~= true then
    return nil
  end
  local options = type(bridge) == "table" and bridge.bootOptions
  if type(options) ~= "table" then return nil end
  return copy(options)
end

function M.legacyOptionBucket(options)
  local all = type(options) == "table" and options.modOptions
  local legacy = type(all) == "table" and all[M.LEGACY_ID]
  return type(legacy) == "table" and legacy or nil
end

function M.applyOptionDefaults(schema, options)
  local buckets = type(options) == "table" and options.modOptions
  local current = type(buckets) == "table" and buckets[M.CURRENT_ID]
  local legacy = M.legacyOptionBucket(options)
  if type(legacy) ~= "table" or not hasAny(legacy, OPTION_SIGNATURES) then
    return false
  end
  local changed = false
  for _, row in ipairs(schema or {}) do
    if type(row) == "table"
        and (type(current) ~= "table" or current[row.key] == nil)
        and legacy[row.key] ~= nil then
      row.default = copy(legacy[row.key])
      changed = true
    end
  end
  return changed
end

function M.migrateSave(raw, fallbackOptions)
  if type(raw) ~= "table" then return false end
  raw.modData = raw.modData or {}
  local legacy = raw.modData[M.LEGACY_ID]
  local rawOptions = raw.options or fallbackOptions
  local legacyOptions = M.legacyOptionBucket(rawOptions)
  if type(legacy) ~= "table"
      or not looksLikeAscendant(raw, legacyOptions) then
    return false
  end

  raw.modData[M.CURRENT_ID] = mergeMissing(
    raw.modData[M.CURRENT_ID], legacy)

  -- Rewrite the metadata identity before the engine computes the active-mod
  -- diff and runs the current namespace's migrations. Keep every other mod.
  raw.meta = raw.meta or { mods = {} }
  raw.meta.mods = raw.meta.mods or {}
  local foundCurrent = false
  for i = #raw.meta.mods, 1, -1 do
    local row = raw.meta.mods[i]
    if type(row) == "table" and row.id == M.CURRENT_ID then
      foundCurrent = true
    elseif type(row) == "table" and row.id == M.LEGACY_ID then
      if not foundCurrent then
        row.id = M.CURRENT_ID
        foundCurrent = true
      else
        table.remove(raw.meta.mods, i)
      end
    end
  end
  return true
end

function M.persistOptions(game, schema, bootOptions)
  if type(game) ~= "table" or type(game.mods) ~= "table" then return false end
  local old = M.legacyOptionBucket(bootOptions)
  if type(old) ~= "table" or not hasAny(old, OPTION_SIGNATURES) then return false end

  local current = game.mods.modOptions and game.mods.modOptions[M.CURRENT_ID]
  local migrated = copy(type(current) == "table" and current or {})
  -- The canonical bucket is authoritative; fill only its gaps from the
  -- signature-proven historical KA bucket.  Keep every historical KA option,
  -- including keys an older rollback build understands but the current
  -- schema no longer displays.
  mergeMissing(migrated, old)
  local savedOptions = game.save and game.save.options
  local savedBuckets = type(savedOptions) == "table" and savedOptions.modOptions
  local saved = type(savedBuckets) == "table" and savedBuckets[M.CURRENT_ID]
  saved = type(saved) == "table" and saved or {}
  for key, value in pairs(saved) do migrated[key] = copy(value) end
  local changed = false
  for key, value in pairs(migrated) do
    if saved[key] == nil then
      saved[key] = copy(value)
      changed = true
    end
  end
  if not changed then return false end

  game.mods.modOptions = game.mods.modOptions or {}
  game.mods.modOptions[M.CURRENT_ID] = migrated
  if type(game.save) ~= "table" or type(game.writeOptions) ~= "function" then
    return false
  end
  game.save.options = game.save.options or {}
  game.save.options.modOptions = game.save.options.modOptions or {}
  game.save.options.modOptions[M.CURRENT_ID] = saved
  game:writeOptions()
  return true
end

function M.new(mod)
  assert(mod and mod.id == M.CURRENT_ID,
    "Kanto Ascendant id migration loaded under an unexpected manifest id")
  local bootOptions = M.loadOptions(mod)
  local api = { bootOptions = bootOptions }
  function api.applyOptionDefaults(schema)
    return M.applyOptionDefaults(schema, bootOptions)
  end
  function api.migrateSave(raw)
    return M.migrateSave(raw, bootOptions)
  end
  function api.persistOptions(game, schema)
    return M.persistOptions(game, schema, bootOptions)
  end
  return api
end

return M
