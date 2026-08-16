-- Canonical Crystal level-up compatibility for Gen1 Recomp.
--
-- The canonical table deliberately contains every Crystal move id.  This
-- adapter is the safety boundary: unavailable ids are audited, never written
-- into a registered species, while Ascendant-only additions are retained.

local M = {}

local function copyRows(rows)
  local result = {}
  for index, row in ipairs(rows or {}) do
    result[index] = { level = row.level, move = row.move }
  end
  return result
end

local function sortedSpecies(canonical)
  local result = {}
  for species, rows in pairs(canonical or {}) do
    if species ~= "_meta" and type(rows) == "table" then
      result[#result + 1] = species
    end
  end
  table.sort(result)
  return result
end

-- Build one species schedule.  A move which occurs anywhere in Crystal's
-- schedule is canonical-owned, so an old approximate level cannot survive as
-- an "extension" at a second, incorrect level.  Moves absent from Crystal's
-- schedule remain KA extensions and retain their original level.
function M.compile(current, canonicalRows, hasMove)
  current = current or {}
  canonicalRows = canonicalRows or {}
  assert(type(hasMove) == "function", "hasMove callback required")

  local canonicalIds = {}
  for _, row in ipairs(canonicalRows) do
    assert(type(row.level) == "number" and type(row.move) == "string",
      "invalid canonical Crystal learnset row")
    canonicalIds[row.move] = true
  end

  local level1, scheduled = {}, {}
  local level1Seen = {}
  local audit = {
    canonicalRows = #canonicalRows,
    activeCanonicalRows = 0,
    preservedExtensions = 0,
    skippedUnknownExtensions = 0,
    missingRows = {},
  }

  local function available(move)
    return hasMove(move) and true or false
  end

  for order, row in ipairs(canonicalRows) do
    if available(row.move) then
      audit.activeCanonicalRows = audit.activeCanonicalRows + 1
      if row.level == 1 then
        if not level1Seen[row.move] then
          level1[#level1 + 1] = row.move
          level1Seen[row.move] = true
        end
      else
        scheduled[#scheduled + 1] = {
          level = row.level, move = row.move, _order = order,
        }
      end
    else
      audit.missingRows[#audit.missingRows + 1] = {
        level = row.level, move = row.move,
      }
    end
  end

  for _, move in ipairs(current.level1Moves or {}) do
    if not canonicalIds[move] then
      if available(move) then
        if not level1Seen[move] then
          level1[#level1 + 1] = move
          level1Seen[move] = true
          audit.preservedExtensions = audit.preservedExtensions + 1
        end
      else
        audit.skippedUnknownExtensions = audit.skippedUnknownExtensions + 1
      end
    end
  end

  local extensionOrder = #canonicalRows
  for _, row in ipairs(current.learnset or {}) do
    if not canonicalIds[row.move] then
      if available(row.move) then
        extensionOrder = extensionOrder + 1
        scheduled[#scheduled + 1] = {
          level = row.level, move = row.move, _order = extensionOrder,
        }
        audit.preservedExtensions = audit.preservedExtensions + 1
      else
        audit.skippedUnknownExtensions = audit.skippedUnknownExtensions + 1
      end
    end
  end

  table.sort(scheduled, function(left, right)
    if left.level ~= right.level then return left.level < right.level end
    return left._order < right._order
  end)
  local learnset = {}
  for index, row in ipairs(scheduled) do
    learnset[index] = { level = row.level, move = row.move }
  end

  return { level1Moves = level1, learnset = learnset }, audit
end

local function finalizeMissing(missing)
  local result = {}
  for move, entry in pairs(missing) do
    local species = {}
    for id, levels in pairs(entry.bySpecies) do
      table.sort(levels)
      species[#species + 1] = { id = id, levels = levels }
    end
    table.sort(species, function(left, right) return left.id < right.id end)
    result[#result + 1] = {
      id = move,
      occurrences = entry.occurrences,
      speciesCount = #species,
      species = species,
    }
  end
  table.sort(result, function(left, right) return left.id < right.id end)
  return result
end

function M.apply(mod, canonical, speciesScope)
  assert(mod and mod.content and mod.content.moves and mod.content.pokemon,
    "Crystal learnset compatibility requires move and species registries")
  canonical = canonical or {}

  local report = {
    schema = "kanto-ascendant.crystal-learnsets.audit.v1",
    source = canonical._meta and canonical._meta.source or "unknown",
    sourceRevision = canonical._meta and canonical._meta.revision or "unknown",
    sourceSpecies = canonical._meta and canonical._meta.speciesCount or 0,
    canonicalSpecies = 0,
    patchedSpecies = 0,
    canonicalRows = 0,
    activeCanonicalRows = 0,
    preservedExtensions = 0,
    skippedUnknownExtensions = 0,
    unregisteredSpecies = {},
  }
  local missing = {}
  local known = {}
  local function hasMove(move)
    if known[move] == nil then
      known[move] = mod.content.moves:get(move) and true or false
    end
    return known[move]
  end

  local scope = speciesScope or sortedSpecies(canonical)
  report.scopeSpecies = {}
  for index, species in ipairs(scope) do report.scopeSpecies[index] = species end
  for _, species in ipairs(scope) do
    assert(type(canonical[species]) == "table",
      "missing canonical Crystal rows for " .. tostring(species))
    report.canonicalSpecies = report.canonicalSpecies + 1
    local current = mod.content.pokemon:get(species)
    if not current then
      report.unregisteredSpecies[#report.unregisteredSpecies + 1] = species
    else
      local schedule, audit = M.compile(current, canonical[species], hasMove)
      mod.content.pokemon:patch(species, schedule)
      report.patchedSpecies = report.patchedSpecies + 1
      report.canonicalRows = report.canonicalRows + audit.canonicalRows
      report.activeCanonicalRows = report.activeCanonicalRows
        + audit.activeCanonicalRows
      report.preservedExtensions = report.preservedExtensions
        + audit.preservedExtensions
      report.skippedUnknownExtensions = report.skippedUnknownExtensions
        + audit.skippedUnknownExtensions
      for _, row in ipairs(audit.missingRows) do
        local entry = missing[row.move]
        if not entry then
          entry = { occurrences = 0, bySpecies = {} }
          missing[row.move] = entry
        end
        entry.occurrences = entry.occurrences + 1
        local levels = entry.bySpecies[species]
        if not levels then
          levels = {}
          entry.bySpecies[species] = levels
        end
        levels[#levels + 1] = row.level
      end
    end
  end

  report.missingMoves = finalizeMissing(missing)
  report.missingMoveIds = {}
  for index, entry in ipairs(report.missingMoves) do
    report.missingMoveIds[index] = entry.id
  end
  report.missingMoveCount = #report.missingMoves

  if mod.exports then mod.exports.crystalLearnsetAudit = report end
  if mod.log and mod.log.info then
    mod.log:info(
      "Crystal learnsets: %d/%d canonical rows active; %d move ids unavailable; %d KA extensions retained",
      report.activeCanonicalRows, report.canonicalRows,
      report.missingMoveCount, report.preservedExtensions)
  end
  return report
end

M.copyRows = copyRows

return M
