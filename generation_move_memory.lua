-- Lossless moveset memory for generation profile transitions.
--
-- Canonical Pokémon data is never rewritten.  Profile snapshots live in the
-- portable KASC extra namespace on the Pokémon itself so party, Boxes,
-- Day-Care and Legacy transfer paths keep the same ordered four slots.

return function(mod, opts)
  opts = opts or {}
  local M = {}

  local function copy(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local out = {}
    seen[value] = out
    for key, child in pairs(value) do out[copy(key, seen)] = copy(child, seen) end
    return out
  end

  local function namespace(mon, create)
    if type(mon) ~= "table" then return nil end
    if type(mon.extra) ~= "table" then
      if not create then return nil end
      mon.extra = {}
    end
    local root = mon.extra[mod.id]
    if type(root) ~= "table" then
      if not create then return nil end
      root = {}
      mon.extra[mod.id] = root
    end
    local memory = root.generationMoves
    if type(memory) ~= "table" then
      if not create then return nil end
      memory = { version = 1, editRevision = 0, profiles = {}, dormant = {} }
      root.generationMoves = memory
    end
    memory.version = 1
    memory.editRevision = math.max(0,
      math.floor(tonumber(memory.editRevision) or 0))
    memory.profiles = type(memory.profiles) == "table" and memory.profiles or {}
    memory.dormant = type(memory.dormant) == "table" and memory.dormant or {}
    return memory
  end

  local function moveId(row)
    return type(row) == "table" and row.id or type(row) == "string" and row
      or nil
  end

  local function maxPP(row, data)
    local id = moveId(row)
    local def = data and data.moves and data.moves[id]
    local base = tonumber(def and def.pp) or tonumber(row and row.maxPP)
      or tonumber(row and row.pp) or 0
    local ups = math.max(0, math.min(3,
      math.floor(tonumber(type(row) == "table" and row.ppUps) or 0)))
    return math.max(0, math.floor(base + ups * math.floor(base / 5)))
  end

  local function acquisition(mon, row, index)
    if type(row) == "table" and type(row.acquisition) == "table" then
      return copy(row.acquisition)
    end
    local provenance = type(mon.moveProvenance) == "table"
      and mon.moveProvenance[moveId(row)] or nil
    if type(provenance) == "table" then return copy(provenance) end
    return { kind = "legacyImported", slot = index }
  end

  function M.snapshot(mon, profile, data)
    if type(mon) ~= "table" or type(profile) ~= "string" then
      return nil, "arguments"
    end
    local memory = namespace(mon, true)
    local out = {
      version = 1,
      profile = profile,
      editRevision = memory.editRevision,
      moves = {},
    }
    for index, row in ipairs(type(mon.moves) == "table" and mon.moves or {}) do
      local id = moveId(row)
      if id then
        out.moves[index] = {
          id = id,
          pp = math.max(0, math.floor(tonumber(type(row) == "table"
            and row.pp) or 0)),
          maxPP = maxPP(row, data),
          ppUps = math.max(0, math.min(3, math.floor(tonumber(
            type(row) == "table" and row.ppUps) or 0))),
          acquisition = acquisition(mon, row, index),
        }
      end
    end
    memory.profiles[profile] = copy(out)
    return out
  end

  function M.markEdited(mon, reason)
    local memory = namespace(mon, true)
    memory.editRevision = memory.editRevision + 1
    memory.lastEditReason = tostring(reason or "moveset_changed")
    return memory.editRevision
  end

  local function materialize(snapshot, data)
    local out = {}
    for index, row in ipairs(type(snapshot) == "table" and snapshot.moves or {}) do
      local limit = maxPP(row, data)
      out[index] = {
        id = row.id,
        pp = math.min(limit, math.max(0, math.floor(tonumber(row.pp) or limit))),
        ppUps = math.max(0, math.min(3,
          math.floor(tonumber(row.ppUps) or 0))),
      }
    end
    return out
  end

  function M.canRestore(mon, profile)
    local memory = namespace(mon, false)
    local snapshot = memory and memory.profiles[profile]
    if type(snapshot) ~= "table" then return false, "missing" end
    if tonumber(snapshot.editRevision) ~= tonumber(memory.editRevision) then
      return false, "edited", copy(snapshot)
    end
    return true, snapshot
  end

  function M.restore(mon, profile, data, confirmed)
    local can, snapshotOrWhy, preview = M.canRestore(mon, profile)
    if not can then
      if snapshotOrWhy ~= "edited" or confirmed ~= true then
        return false, snapshotOrWhy, preview
      end
      snapshotOrWhy = preview
    end
    mon.moves = materialize(snapshotOrWhy, data)
    return true, copy(mon.moves)
  end

  local function dormantKey(profile, index, id)
    return table.concat({ profile, tostring(index), tostring(id) }, ":")
  end

  function M.transitionMon(mon, fromProfile, toProfile, data, policy)
    policy = policy or {}
    M.snapshot(mon, fromProfile, data)
    local restored, why, preview = M.restore(mon, toProfile, data, false)
    if restored then return true, "restored" end
    if why == "edited" then return false, "confirmation_required", preview end

    local memory = namespace(mon, true)
    local changed = false
    mon.moves = type(mon.moves) == "table" and mon.moves or {}
    -- Walk backwards because removing an illegal slot must not skip the move
    -- that followed it.  Slot order is otherwise preserved exactly.
    for index = #(type(mon.moves) == "table" and mon.moves or {}), 1, -1 do
      local row = mon.moves[index]
      local id = moveId(row)
      local legal = type(policy.moveLegal) ~= "function"
        or policy.moveLegal(mon, id, toProfile, index) == true
      if not legal then
        local key = dormantKey(toProfile, index, id)
        memory.dormant[key] = {
          profile = toProfile, slot = index, move = copy(row),
          acquisition = acquisition(mon, row, index),
          editRevision = memory.editRevision,
        }
        mon.rememberedMoves = type(mon.rememberedMoves) == "table"
          and mon.rememberedMoves or {}
        mon.rememberedMoves[id] = true
        local replacement = type(policy.replacement) == "function"
          and policy.replacement(mon, toProfile, index, id) or nil
        if type(replacement) == "string" and data and data.moves
            and data.moves[replacement] then
          mon.moves[index] = {
            id = replacement, pp = tonumber(data.moves[replacement].pp) or 0,
          }
        else
          table.remove(mon.moves, index)
        end
        changed = true
      else
        row.pp = math.min(maxPP(row, data),
          math.max(0, math.floor(tonumber(row.pp) or 0)))
      end
    end
    -- A currently eligible Pokémon must never leave a successful transaction
    -- with zero usable moves. Later-generation Pokémon that are themselves
    -- inactive may safely keep only their dormant snapshot until re-enabled.
    if #mon.moves == 0 and type(policy.requireMove) == "function"
        and policy.requireMove(mon, toProfile) == true then
      local replacement = type(policy.replacement) == "function"
        and policy.replacement(mon, toProfile, 1, nil) or nil
      if type(replacement) ~= "string" or not (data and data.moves
          and data.moves[replacement]) then
        return false, "no_legal_replacement"
      end
      mon.moves[1] = {
        id=replacement, pp=tonumber(data.moves[replacement].pp) or 0,
      }
      changed = true
    end
    M.snapshot(mon, toProfile, data)
    return true, changed and "projected" or "unchanged"
  end

  function M.walkOwned(evidence, save, callback, game)
    local seen, count = {}, 0
    for _, row in ipairs(evidence.ownedSurfaces(save, game)) do
      local mon = row.mon
      if type(mon) == "table" and not seen[mon] then
        seen[mon], count = true, count + 1
        callback(mon, row.label)
      end
    end
    return count
  end

  M.copy = copy
  M.namespace = namespace
  M.maxPP = maxPP
  return M
end
