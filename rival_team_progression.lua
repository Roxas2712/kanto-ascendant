-- kasc.rival-team-progression/v1
--
-- Canonical, forward-only species progression for generated rival teams.
-- The installed Pokemon registry is the sole graph authority. Only an
-- unambiguous LEVEL edge whose threshold has been reached is automatic;
-- item, trade, friendship, time, move and ambiguous branches remain authored
-- choices instead of being guessed here.

return function(opts)
  opts = opts or {}
  local P = {
    OWNER = "kasc.rival-team-progression/v1",
    SCHEMA = "kasc.rival-team-progression-receipt/v1",
    MAX_DEPTH = 8,
  }

  local supportLog = opts.supportLog

  local function copy(value)
    if type(value) ~= "table" then return value end
    local out = {}
    for key, child in pairs(value) do out[key] = copy(child) end
    return out
  end

  local function integer(value)
    value = tonumber(value)
    return value and math.floor(value) or nil
  end

  local function edge(row)
    if type(row) ~= "table" then return nil end
    local method = tostring(row.method or row[1] or ""):upper()
    local target = row.species or row[2]
    local level = integer(row.level or row[3])
    if type(target) ~= "string" or target == "" then target = nil end
    return method, target, level
  end

  local function emit(fields)
    if not (supportLog and type(supportLog.write) == "function") then
      return false
    end
    local ok, written = pcall(supportLog.write,
      "kasc.rival.team-progression", fields)
    return ok and written ~= false
  end

  local function allowed(context, target, from, row)
    local callback = context and context.speciesAllowed
    if type(callback) ~= "function" then return true end
    local ok, result = pcall(callback, target, from, row)
    return ok and result == true
  end

  local function receipt(from, target, level, status, reason, context)
    local row = {
      schema = P.SCHEMA,
      owner = P.OWNER,
      speciesId = from,
      target = target or from,
      level = level,
      status = status,
      reason = reason,
      source = "installed-canonical-pokemon-registry",
      phase = context and context.storyTier or "unknown",
      targetKind = context and context.actor or "unknown",
    }
    if context and context.actor then row.actor = context.actor end
    emit(row)
    return row
  end

  function P.resolveSpecies(game, species, level, context)
    local registry = game and game.data and game.data.pokemon
    level = integer(level)
    if type(registry) ~= "table" or type(species) ~= "string"
        or type(registry[species]) ~= "table" or not level then
      return species, { receipt(species, species, level or 0, "unchanged",
        "INVALID_SOURCE", context) }
    end

    local current, receipts, seen = species, {}, {}
    for _ = 1, P.MAX_DEPTH do
      if seen[current] then
        receipts[#receipts + 1] = receipt(current, current, level,
          "unchanged", "CYCLE_GUARD", context)
        break
      end
      seen[current] = true
      local def = registry[current]
      local eligible, unavailable = {}, false
      for _, row in ipairs(type(def.evolutions) == "table"
          and def.evolutions or {}) do
        local method, target, threshold = edge(row)
        if method == "LEVEL" and target and threshold
            and level >= threshold then
          if type(registry[target]) == "table"
              and allowed(context, target, current, row) then
            eligible[#eligible + 1] = {
              target = target, threshold = threshold, row = row,
            }
          else
            unavailable = true
          end
        end
      end

      if #eligible == 1 then
        local selected = eligible[1]
        receipts[#receipts + 1] = receipt(current, selected.target, level,
          "evolved", "LEVEL_" .. tostring(selected.threshold), context)
        current = selected.target
      elseif #eligible > 1 then
        receipts[#receipts + 1] = receipt(current, current, level,
          "unchanged", "AMBIGUOUS_LEVEL_BRANCH", context)
        break
      else
        receipts[#receipts + 1] = receipt(current, current, level,
          "unchanged", unavailable and "TARGET_UNAVAILABLE"
            or "NO_UNAMBIGUOUS_LEVEL_EDGE", context)
        break
      end
    end
    return current, receipts
  end

  function P.resolveTeam(game, team, context)
    if type(team) ~= "table" then return nil, {} end
    local out, receipts = {}, {}
    for index, source in ipairs(team) do
      if type(source) ~= "table" or type(source.species) ~= "string" then
        return nil, receipts
      end
      local row = copy(source)
      local species, slotReceipts = P.resolveSpecies(game, row.species,
        row.level, {
          actor = context and context.actor,
          speciesAllowed = context and context.speciesAllowed,
          slot = index,
          storyTier = context and context.storyTier,
        })
      row.species = species
      out[index] = row
      for _, current in ipairs(slotReceipts) do
        current.slot = index
        receipts[#receipts + 1] = current
      end
    end
    return out, receipts
  end

  return P
end
