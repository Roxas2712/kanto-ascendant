-- Kanto Ascendant 6.7 Discovery Core: save-compatible family state.
--
-- The five public milestones are monotonic.  Sighting pity is deliberately a
-- separate cadence value: it may reset after a sighting without erasing any
-- discovery.  Every pure operation returns a new root and keeps unknown
-- fields/schema versions so later generations can extend this record safely.

local Module = {
  SAVE_KEY = "discovery_core",
  SCHEMA_VERSION = 1,
  STAGES = { "unseen", "sighted", "trace", "caught", "unlocked" },
}

local RANK = {}
for index, stage in ipairs(Module.STAGES) do RANK[stage] = index end

local function copy(value, seen)
  if type(value) ~= "table" then return value end
  seen = seen or {}
  if seen[value] then return seen[value] end
  local out = {}
  seen[value] = out
  for key, child in pairs(value) do
    out[copy(key, seen)] = copy(child, seen)
  end
  return out
end

local function generationKey(value)
  if type(value) == "number" and value == math.floor(value) and value >= 1 then
    return "gen" .. tostring(value)
  end
  if type(value) ~= "string" or value == "" then return nil end
  local lowered = value:lower()
  local number = lowered:match("^gen(%d+)$") or lowered:match("^(%d+)$")
  if number then return "gen" .. tostring(tonumber(number)) end
  return lowered
end

local function familyKey(value)
  if type(value) ~= "string" or value == "" then return nil end
  return value:upper()
end

local function normalizedVersion(value)
  value = tonumber(value)
  if not value or value ~= math.floor(value) or value < Module.SCHEMA_VERSION then
    return Module.SCHEMA_VERSION
  end
  return value
end

function Module.empty()
  return { version = Module.SCHEMA_VERSION, generations = {} }
end

function Module.normalize(raw)
  if type(raw) ~= "table" then return Module.empty(), true end
  local out = copy(raw)
  local changed = false
  local version = normalizedVersion(out.version)
  if out.version ~= version then
    out.version = version
    changed = true
  end
  if type(out.generations) ~= "table" then
    out.generations = {}
    changed = true
  end
  return out, changed
end

local function recordAt(root, generation, family)
  local generationId = generationKey(generation)
  local familyId = familyKey(family)
  if not generationId or not familyId then return nil end
  local generations = type(root) == "table" and root.generations
  local generationRecord = type(generations) == "table"
    and generations[generationId] or nil
  local families = type(generationRecord) == "table"
    and generationRecord.families or nil
  local record = type(families) == "table" and families[familyId] or nil
  return type(record) == "table" and record or nil,
    generationId, familyId
end

local function ensureRecord(root, generation, family)
  local generationId = generationKey(generation)
  local familyId = familyKey(family)
  if not generationId or not familyId then return nil end
  root.generations[generationId] =
    type(root.generations[generationId]) == "table"
    and root.generations[generationId] or {}
  local generationRecord = root.generations[generationId]
  generationRecord.families = type(generationRecord.families) == "table"
    and generationRecord.families or {}
  generationRecord.families[familyId] =
    type(generationRecord.families[familyId]) == "table"
    and generationRecord.families[familyId] or {}
  return generationRecord.families[familyId], generationId, familyId
end

local function recordRank(record)
  if type(record) ~= "table" then return 1 end
  local rank = RANK[tostring(record.stage or ""):lower()] or 1
  for index = 2, #Module.STAGES do
    if record[Module.STAGES[index]] == true then rank = math.max(rank, index) end
  end
  return rank
end

function Module.status(root, generation, family)
  local record = recordAt(root, generation, family)
  return Module.STAGES[recordRank(record)]
end

function Module.family(root, generation, family)
  local record = recordAt(root, generation, family)
  return record and copy(record) or nil
end

local function materializeMilestones(record, rank)
  local changed = false
  for index = 2, rank do
    local stage = Module.STAGES[index]
    if record[stage] ~= true then
      record[stage] = true
      changed = true
    end
  end
  -- `stage` was used only by unreleased prototypes.  Preserve an unknown
  -- future value, but remove a known redundant value after materializing it.
  if RANK[tostring(record.stage or ""):lower()] then
    record.stage = nil
    changed = true
  end
  return changed
end

function Module.mark(root, generation, family, stage)
  stage = type(stage) == "string" and stage:lower() or nil
  local target = RANK[stage]
  if not target or target == RANK.unseen or target == RANK.unlocked then
    return (Module.normalize(root)), false, "unknown-stage"
  end
  local out, normalized = Module.normalize(root)
  local record = ensureRecord(out, generation, family)
  if not record then return out, false, "invalid-family" end
  local current = recordRank(record)
  local changed = materializeMilestones(record, math.max(current, target))
  return out, normalized or changed
end

function Module.unlock(root, generation, family)
  local out, normalized = Module.normalize(root)
  local record = recordAt(out, generation, family)
  if not record or recordRank(record) < RANK.caught then
    return out, false, "catch-required"
  end
  local changed = materializeMilestones(record, RANK.unlocked)
  return out, normalized or changed
end

function Module.sightingPity(root, generation, family)
  local record = recordAt(root, generation, family)
  local value = record and tonumber(record.sightingPity) or 0
  if not value or value < 0 then return 0 end
  return math.floor(value)
end

function Module.setSightingPity(root, generation, family, value)
  value = tonumber(value)
  if not value or value ~= math.floor(value) or value < 0 then
    return (Module.normalize(root)), false, "invalid-sighting-pity"
  end
  local out, normalized = Module.normalize(root)
  local record = recordAt(out, generation, family)
  if not record and value == 0 then return out, normalized end
  record = record or ensureRecord(out, generation, family)
  if not record then return out, false, "invalid-family" end
  if record.sightingPity == value then return out, normalized end
  record.sightingPity = value
  return out, true
end

function Module.create(mod)
  assert(mod and mod.save, "Discovery Core requires mod.save")
  local S = {
    SAVE_KEY = Module.SAVE_KEY,
    SCHEMA_VERSION = Module.SCHEMA_VERSION,
    registered = false,
  }

  local function read(create)
    local raw = mod.save:get(Module.SAVE_KEY)
    if type(raw) ~= "table" and create == false then return nil end
    local out, changed = Module.normalize(raw)
    if changed then mod.save:set(Module.SAVE_KEY, out) end
    return out
  end

  local function commit(nextRoot)
    local out = Module.normalize(nextRoot)
    mod.save:set(Module.SAVE_KEY, out)
    return out
  end

  function S.root(create)
    return read(create)
  end

  function S.replace(nextRoot)
    return commit(nextRoot)
  end

  function S.status(generation, family)
    return Module.status(read(false), generation, family)
  end

  function S.family(generation, family)
    return Module.family(read(false), generation, family)
  end

  function S.sightingPity(generation, family)
    return Module.sightingPity(read(false), generation, family)
  end

  function S.record(generation, family, stage)
    local nextRoot, changed, reason =
      Module.mark(read(true), generation, family, stage)
    if changed then commit(nextRoot) end
    return changed, nextRoot, reason
  end

  function S.unlock(generation, family)
    local nextRoot, changed, reason =
      Module.unlock(read(true), generation, family)
    if changed then commit(nextRoot) end
    return changed, nextRoot, reason
  end

  function S.setSightingPity(generation, family, value)
    local nextRoot, changed, reason =
      Module.setSightingPity(read(true), generation, family, value)
    if changed then commit(nextRoot) end
    return changed, nextRoot, reason
  end

  function S.install()
    read(true)
    return true
  end

  function S.register()
    if S.registered then return false, "already registered" end
    S.registered = true
    if mod.events and type(mod.events.on) == "function" then
      -- The adapter resolves mod.save on every operation and therefore never
      -- carries a table from Red, Blue, Yellow, another slot, or NEW GAME.
      mod.events:on("save.created", S.install, 1000)
      mod.events:on("save.loaded", S.install, 1000)
      mod.events:on("game.ready", S.install, 1000)
    end
    return true
  end

  S.copy = copy
  S.register()
  return S
end

Module.copy = copy
Module.generationKey = generationKey
Module.familyKey = familyKey
return Module
