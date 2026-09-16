-- Slot-local, idempotent generation-rules migration.
--
-- Existing saves are pinned to KASC 6.7's previous behaviour.  Fresh saves
-- start in AUTO.  The transaction builds a detached state first and assigns
-- it only after validation, so an error leaves the original tree untouched.

return function(mod, opts)
  opts = opts or {}
  local M = {
    SAVE_KEY = "generation_rules",
    STATE_VERSION = 3,
    MIGRATION_VERSION = 3,
    CURRENT_MODE = "auto",
    AUTO_MODE = "auto",
  }

  local function copy(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local out = {}
    seen[value] = out
    for key, child in pairs(value) do out[copy(key, seen)] = copy(child, seen) end
    return out
  end

  local function hash(text)
    local value = 5381
    for index = 1, #text do value = (value * 33 + text:byte(index)) % 4294967296 end
    return ("%08x"):format(value)
  end

  local function bucket(save, create)
    if type(save) ~= "table" then return nil end
    if type(save.modData) ~= "table" then
      if not create then return nil end
      save.modData = {}
    end
    local out = save.modData[mod.id]
    if type(out) ~= "table" then
      if not create then return nil end
      out = {}
      save.modData[mod.id] = out
    end
    return out
  end

  local function optionBucket(save, create)
    if type(save) ~= "table" then return nil end
    if type(save.options) ~= "table" then
      if not create then return nil end
      save.options = {}
    end
    if type(save.options.modOptions) ~= "table" then
      if not create then return nil end
      save.options.modOptions = {}
    end
    local out = save.options.modOptions[mod.id]
    if type(out) ~= "table" then
      if not create then return nil end
      out = {}
      save.options.modOptions[mod.id] = out
    end
    return out
  end

  local function seedFor(save)
    local player = type(save.player) == "table" and save.player or {}
    local parts = {
      "kasc-generation-mechanics-v1",
      tostring(save.version or opts.edition or "unknown"),
      tostring(player.id or player.trainerId or 0),
      tostring(player.name or "PLAYER"),
    }
    return hash(table.concat(parts, ":"))
  end

  local function normalize(raw, save, fresh)
    local state = type(raw) == "table" and copy(raw) or {}
    local previousMigration = tonumber(state.migrationVersion) or 0
    local firstMigration = previousMigration == 0
    state.version = M.STATE_VERSION
    state.migrationVersion = M.MIGRATION_VERSION
    state.mechanicsSeed = type(state.mechanicsSeed) == "string"
      and state.mechanicsSeed ~= "" and state.mechanicsSeed or seedFor(save)
    state.unlockedEpoch = math.max(1,
      math.min(7, math.floor(tonumber(state.unlockedEpoch) or 1)))
    state.supportedEpoch = math.max(1,
      math.min(7, math.floor(tonumber(state.supportedEpoch) or 1)))
    state.switchRevision = math.max(0,
      math.floor(tonumber(state.switchRevision) or 0))
    state.movesetEditRevision = math.max(0,
      math.floor(tonumber(state.movesetEditRevision) or 0))
    state.profileSnapshots = type(state.profileSnapshots) == "table"
      and state.profileSnapshots or {}
    state.dormantMoves = type(state.dormantMoves) == "table"
      and state.dormantMoves or {}
    state.evidence = type(state.evidence) == "table" and state.evidence or {}
    state.contentEvidence = type(state.contentEvidence) == "table"
      and state.contentEvidence or {}
    local aliases = {
      kasc_67_current = "auto", vanilla_rby = "off",
      gen1_clean = "gen1", gen2_compat_crystal = "gen2",
    }
    state.selectedMode = aliases[state.selectedMode] or state.selectedMode
    if firstMigration or type(state.selectedMode) ~= "string" then
      -- AUTO is the product default for fresh and upgraded saves. Progress
      -- evidence remains fail-closed, so an old slot begins at Gen I until
      -- durable receipts prove a later era.
      state.selectedMode = M.AUTO_MODE
      state.migratedFromExisting = fresh ~= true
    end
    return state, firstMigration
  end

  local function validate(state)
    return type(state) == "table" and state.version == M.STATE_VERSION
      and type(state.mechanicsSeed) == "string"
      and state.unlockedEpoch >= 1 and state.unlockedEpoch <= 7
      and type(state.selectedMode) == "string"
  end

  function M.stage(save, fresh)
    if type(save) ~= "table" then return nil, "save" end
    local owner = bucket(save, false)
    local previous = owner and copy(owner[M.SAVE_KEY]) or nil
    local ok, staged, first = pcall(normalize,
      owner and owner[M.SAVE_KEY], save, fresh == true)
    if not ok or not validate(staged) then return nil, "invalid_state" end
    return {
      previous = previous,
      staged = staged,
      first = first == true,
      fresh = fresh == true,
    }
  end

  function M.commit(save, transaction)
    if type(transaction) ~= "table" or not validate(transaction.staged) then
      return false, "transaction"
    end
    local owner = bucket(save, true)
    owner[M.SAVE_KEY] = copy(transaction.staged)
    local options = optionBucket(save, true)
    if transaction.first then
      options.battle_generation_mode = transaction.staged.selectedMode
    elseif type(options.battle_generation_mode) ~= "string" then
      options.battle_generation_mode = transaction.staged.selectedMode
    end
    return true, owner[M.SAVE_KEY]
  end

  function M.rollback(save, transaction)
    if type(save) ~= "table" or type(transaction) ~= "table" then return false end
    local owner = bucket(save, true)
    owner[M.SAVE_KEY] = copy(transaction.previous)
    return true
  end

  function M.apply(save, fresh)
    local transaction, why = M.stage(save, fresh)
    if not transaction then return false, why end
    local ok, state = M.commit(save, transaction)
    if not ok then M.rollback(save, transaction) end
    return ok, state, transaction.first
  end

  function M.state(save, create, fresh)
    local owner = bucket(save, false)
    local state = owner and owner[M.SAVE_KEY]
    if type(state) == "table" then return state end
    if create == false then return nil end
    local ok, created = M.apply(save, fresh == true)
    return ok and created or nil
  end

  function M.syncOption(save, mode)
    local state = M.state(save, true, false)
    if not state or type(mode) ~= "string" then return false end
    optionBucket(save, true).battle_generation_mode = mode
    state.selectedMode = mode
    return true
  end

  M.copy = copy
  M.hash = hash
  M.bucket = bucket
  M.optionBucket = optionBucket
  M.seedFor = seedFor
  return M
end
