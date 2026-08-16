-- One-time namespace bridge for the 6.5 identity correction.
--
-- Kanto Ascendant historically shipped as "trainer_rematch", which now
-- belongs to the standalone Trainer Rematch project.  The engine namespaces
-- options, mod save data and exports by manifest id, so changing the id
-- without this bridge would look like a fresh install.  Keep the old bucket
-- as a rollback shadow: RC9 can then read a save written by RC10.

local M = {}

local OLD_ID = "trainer_rematch"
local NEW_ID = "kanto_ascendant"

local LEGACY_OPTION_KEYS = {
  "kanto_151", "ascendant_rules", "johto_time", "legend_art",
  "mega_evolution", "ascendant_qol", "pokemon_sprite_style",
  "character_sprite_style", "trainer_portrait_style",
  "johto_signals_enable", "follower_count", "living_world_enabled",
  "living_world_random_encounters",
}

local LEGACY_SAVE_KEYS = {
  "postgame", "ascendant", "daycare_plus", "johto_research",
  "event_archive", "mega_evolution", "field_tech", "step_clock",
  "trainer_step_clock", "rest_range_version", "extended_characters",
}

local function deepCopy(value, seen)
  if type(value) ~= "table" then return value end
  seen = seen or {}
  if seen[value] then return seen[value] end
  local out = {}
  seen[value] = out
  for key, child in pairs(value) do
    out[deepCopy(key, seen)] = deepCopy(child, seen)
  end
  return out
end

local function mergeMissing(target, source)
  if type(target) ~= "table" or type(source) ~= "table" then return target end
  for key, value in pairs(source) do
    if target[key] == nil then
      target[key] = deepCopy(value)
    elseif type(target[key]) == "table" and type(value) == "table" then
      mergeMissing(target[key], value)
    end
  end
  return target
end

local function hasAny(bucket, keys)
  if type(bucket) ~= "table" then return false end
  for _, key in ipairs(keys) do
    if bucket[key] ~= nil then return true end
  end
  return false
end

local function loaderFrom(fn)
  if type(fn) ~= "function" or not (debug and debug.getupvalue) then return nil end
  local index = 1
  while true do
    local name, value = debug.getupvalue(fn, index)
    if not name then return nil end
    if type(value) == "table" and type(value.modOptions) == "table"
        and type(value.modSave) == "table" then
      return value
    end
    index = index + 1
  end
end

local function removeMeta(meta, id)
  local found
  local mods = type(meta) == "table" and meta.mods
  if type(mods) ~= "table" then return nil end
  for index = #mods, 1, -1 do
    local entry = mods[index]
    if type(entry) == "table" and entry.id == id then
      found = found or entry
      table.remove(mods, index)
    end
  end
  return found
end

local function findMeta(meta, id)
  for _, entry in ipairs(type(meta) == "table" and meta.mods or {}) do
    if type(entry) == "table" and entry.id == id then return entry end
  end
end

local function sortMeta(meta)
  local mods = type(meta) == "table" and meta.mods
  if type(mods) == "table" then
    table.sort(mods, function(left, right)
      return tostring(left.id) < tostring(right.id)
    end)
  end
end

function M.install(mod)
  if mod.id ~= NEW_ID then return false, "unexpected canonical id" end

  -- New sandboxes intentionally omit closure introspection. The public
  -- mod.game service still exposes the live loader during entry, preserving
  -- the one-time legacy option bridge on 0.1.86; older hosts keep the
  -- original guarded upvalue route.  SaveData itself is deliberately not
  -- involved: its sandbox facade exposes only the pure-data newGame helper.
  local game = mod.game or mod.identityMigrationGame
  local loader = type(game) == "table" and game.mods
    or loaderFrom(mod.options and mod.options.get)
  if not (type(loader) == "table" and type(loader.modOptions) == "table"
      and type(loader.modSave) == "table") then
    loader = type(mod.identityMigrationBuckets) == "table"
      and mod.identityMigrationBuckets or nil
  end
  local hasLiveBuckets = type(loader) == "table"
    and type(loader.modOptions) == "table"
    and type(loader.modSave) == "table"
  if type(game) ~= "table" and hasLiveBuckets
      and type(loader.game) == "table" then
    game = loader.game
  end

  -- id_migration consumes the state as it existed before this bridge mutates
  -- the live loader.  Copy only the two owned identities; no foreign mod
  -- bucket crosses the bridge or becomes writable through our exports.
  local bootOptions = { modOptions = {} }
  for _, id in ipairs({ OLD_ID, NEW_ID }) do
    if hasLiveBuckets and type(loader.modOptions[id]) == "table" then
      bootOptions.modOptions[id] = deepCopy(loader.modOptions[id])
    end
  end
  local oldOptions = hasLiveBuckets and loader.modOptions[OLD_ID]
  local legacyOptions = hasAny(oldOptions, LEGACY_OPTION_KEYS)
  if legacyOptions then
    local current = loader.modOptions[NEW_ID]
    if type(current) ~= "table" then
      current = deepCopy(oldOptions)
      loader.modOptions[NEW_ID] = current
    else
      mergeMissing(current, oldOptions)
    end
  end

  local function migrateSave(save)
    if type(save) ~= "table" then return false end
    save.modData = save.modData or {}
    local old = save.modData[OLD_ID]
    if type(old) ~= "table"
        or not (legacyOptions or hasAny(old, LEGACY_SAVE_KEYS)) then
      return false
    end
    local current = save.modData[NEW_ID]
    if type(current) ~= "table" then
      current = deepCopy(old)
      save.modData[NEW_ID] = current
    else
      mergeMissing(current, old)
    end

    save.meta = save.meta or { mods = {} }
    save.meta.mods = save.meta.mods or {}
    local oldMeta = removeMeta(save.meta, OLD_ID)
    if not findMeta(save.meta, NEW_ID) then
      save.meta.mods[#save.meta.mods + 1] = {
        id = NEW_ID,
        version = oldMeta and oldMeta.version or mod.version,
        api = oldMeta and oldMeta.api or mod.manifest.api,
      }
    end
    sortMeta(save.meta)
    return true
  end

  local function shadowSave(save)
    if type(save) ~= "table" then return false end
    save.modData = save.modData or {}
    local current = save.modData[NEW_ID]
    if type(current) ~= "table" then return false end
    save.modData[OLD_ID] = deepCopy(current)

    save.meta = save.meta or { mods = {} }
    save.meta.mods = save.meta.mods or {}
    local canonical = findMeta(save.meta, NEW_ID)
    local oldMeta = findMeta(save.meta, OLD_ID)
    if not oldMeta then
      oldMeta = {}
      save.meta.mods[#save.meta.mods + 1] = oldMeta
    end
    oldMeta.id = OLD_ID
    oldMeta.version = canonical and canonical.version or mod.version
    oldMeta.api = canonical and canonical.api or mod.manifest.api
    sortMeta(save.meta)
    return true
  end

  local function shadowOptions(options)
    local buckets = type(options) == "table" and options.modOptions
    local current = type(buckets) == "table" and buckets[NEW_ID]
    if type(current) ~= "table" then return false end
    buckets[OLD_ID] = deepCopy(current)
    return true
  end

  -- SaveData is intentionally hidden by the 0.1.86 sandbox.  The live Game
  -- owns the supported options write, so wrap that public operation instead
  -- and refresh the rollback bucket immediately before its full snapshot is
  -- persisted.  The per-id handler table keeps the wrapper process-wide and
  -- idempotent without exposing or touching another mod's bucket.
  if type(game) == "table" and type(game.writeOptions) == "function" then
    local handlers = rawget(game, "__identityOptionShadows")
    if not handlers then
      handlers = {}
      local original = game.writeOptions
      game.writeOptions = function(self, ...)
        local options = self and self.save and self.save.options
        for _, handler in pairs(self.__identityOptionShadows or {}) do
          pcall(handler, options)
        end
        return original(self, ...)
      end
      game.__identityOptionShadows = handlers
    end
    handlers[NEW_ID] = shadowOptions
  elseif hasLiveBuckets and mod.log and type(mod.log.warn) == "function" then
    mod.log:warn("identity option rollback shadow unavailable without Game:writeOptions")
  end

  mod.events:on("save.loading", function(event)
    migrateSave(event and event.raw)
  end, 10000)
  -- Run after every feature has snapshotted its canonical state.
  mod.events:on("save.writing", function(event)
    shadowSave(event and event.save)
  end, -10000)

  mod.exports.identityMigration = {
    oldId = OLD_ID,
    newId = NEW_ID,
    migrateSave = migrateSave,
    shadowSave = shadowSave,
    shadowOptions = shadowOptions,
    legacyOptionsDetected = legacyOptions,
    bootOptions = bootOptions,
  }
  return true
end

return M
