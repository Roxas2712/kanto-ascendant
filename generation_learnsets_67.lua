-- KASC-67-GENERATION-LEARNSETS
--
-- Projects the pinned Gen-II--VI learn-source authority onto the currently
-- merged species registry.  The projection is cumulative and reversible:
-- generation_rules restores its clean species baseline before calling us,
-- while this module owns the equivalent baseline for the shared egg table.

return function(mod, opts)
  opts = opts or {}
  local data = assert(opts.data, "generation learnset data missing")
  local rules = assert(opts.generationRules, "generation rules missing")
  local eggMoves = assert(opts.eggMoves, "egg move registry missing")
  local fieldTech = opts.fieldTech
  assert(data._meta and data._meta.speciesCount == 721
      and data._meta.rowCount == 58781,
    "generation learnset authority cardinality drift")

  local L = {
    data = data,
    audit = { activeEpoch = 1, species = 0, level = 0,
      egg = 0, tutor = 0, machine = 0, missing = 0 },
  }
  local eggBaseline
  local backendProvider

  function L.setBackendProvider(provider)
    assert(provider and type(provider.rowsFor)=='function' and type(provider.owns)=='function')
    backendProvider=provider
  end

  local function copyArray(values)
    local out = {}
    for index, value in ipairs(type(values) == "table" and values or {}) do
      out[index] = value
    end
    return out
  end

  local function snapshotEggs()
    if eggBaseline then return eggBaseline end
    eggBaseline = {}
    for dex, values in pairs(eggMoves) do
      if type(values) == "table" then eggBaseline[dex] = copyArray(values) end
    end
    return eggBaseline
  end

  local function restoreEggs()
    local baseline = snapshotEggs()
    for dex in pairs(eggMoves) do eggMoves[dex] = nil end
    for dex, values in pairs(baseline) do eggMoves[dex] = copyArray(values) end
  end

  local function dexOf(def)
    local value = tonumber(def and (def.sourceDex or def.nationalDex or def.dex))
    if not value then return nil end
    value = math.floor(value)
    if value < 1 or value > 721 then return nil end
    return value
  end

  local function moveId(value)
    return type(value) == "table" and (value.move or value.id) or value
  end

  local function appendUnique(target, value)
    local id = moveId(value)
    if type(id) ~= "string" then return false end
    for _, existing in ipairs(target) do
      if moveId(existing) == id then return false end
    end
    target[#target + 1] = value
    return true
  end

  local function activeRows(game, def, epoch, method)
    local rows, dex = {}, dexOf(def)
    local source = dex and data.byDex[dex] or nil
    for _, row in ipairs(type(source) == "table" and source or {}) do
      local generation, kind, level, id = row[1], row[2], row[3], row[4]
      if generation <= epoch and (not method or kind == method)
          and game.data.moves and game.data.moves[id]
          and rules.moveAvailable(id, epoch, game.data) then
        rows[#rows + 1] = {
          generation = generation, method = kind,
          level = level, id = id, dex = dex,
        }
      end
    end
    return rows
  end

  function L.rowsFor(game, monOrSpecies, method, forcedEpoch)
    if not (game and game.data and game.data.pokemon) then return {} end
    if backendProvider then
      local rows=backendProvider.rowsFor(game,monOrSpecies,method,forcedEpoch)
      if rows~=nil then return rows end
    end
    local species = type(monOrSpecies) == "table"
      and (monOrSpecies.species or monOrSpecies.eggSpecies) or monOrSpecies
    local def = game.data.pokemon[species]
    if not def then return {} end
    local resolved = rules.resolve(game)
    local epoch = math.max(1, math.min(6, math.floor(tonumber(forcedEpoch)
      or resolved and resolved.activeEpoch or 1)))
    return activeRows(game, def, epoch, method)
  end

  function L.apply(game, forcedEpoch)
    if not (game and game.data and game.data.pokemon and game.data.moves) then
      return false, "game data"
    end
    local resolved = rules.resolve(game)
    local epoch = math.max(1, math.min(6, math.floor(tonumber(forcedEpoch)
      or resolved and resolved.activeEpoch or 1)))
    restoreEggs()
    local audit = { activeEpoch = epoch, species = 0, level = 0,
      egg = 0, tutor = 0, machine = 0, missing = 0 }

    for speciesId, def in pairs(game.data.pokemon) do
      local dex = dexOf(def)
      local source = dex and data.byDex[dex] or nil
      if type(def) == "table" and type(source) == "table"
          and not (backendProvider and backendProvider.owns(speciesId)) then
        audit.species = audit.species + 1
        def.level1Moves = type(def.level1Moves) == "table"
          and def.level1Moves or {}
        def.learnset = type(def.learnset) == "table" and def.learnset or {}
        def.tmhm = type(def.tmhm) == "table" and def.tmhm or {}
        for _, row in ipairs(source) do
          local generation, method, level, id = row[1], row[2], row[3], row[4]
          if generation <= epoch then
            if not game.data.moves[id]
                or not rules.moveAvailable(id, epoch, game.data) then
              audit.missing = audit.missing + 1
            elseif method == "L" then
              local added
              if (tonumber(level) or 0) <= 1 then
                added = appendUnique(def.level1Moves, id)
              else
                added = appendUnique(def.learnset,
                  { level = tonumber(level), move = id })
              end
              if added then audit.level = audit.level + 1 end
            elseif method == "E" then
              eggMoves[dex] = eggMoves[dex] or {}
              if appendUnique(eggMoves[dex], id) then
                audit.egg = audit.egg + 1
              end
            elseif method == "T" then
              -- Tutor rows are served by the existing Reminder provider
              -- below. Count them here without pretending they are TMs.
              audit.tutor = audit.tutor + 1
            elseif method == "M" then
              if appendUnique(def.tmhm, id) then
                audit.machine = audit.machine + 1
              end
            end
          end
        end
      end
    end
    L.audit = audit
    return true, audit
  end

  if fieldTech and type(fieldTech.registerReminderProvider) == "function" then
    local ok, why = fieldTech.registerReminderProvider(
      "generation_learnsets_67", function(game, mon)
        local out = {}
        for _, row in ipairs(L.rowsFor(game, mon, "T")) do
          out[#out + 1] = { id = row.id, source = "tutor" }
        end
        local resolved=rules.resolve(game)
        if resolved.extensionsEnabled~=false and backendProvider
            and type(backendProvider.giftReminderRows)=='function'
            and rules.ownedGiftBattleCompatible(game,mon,game.data.pokemon[mon.species]) then
          for _,row in ipairs(backendProvider.giftReminderRows(game,mon,resolved.activeEpoch))do
            out[#out+1]=row
          end
        end
        return out
      end)
    assert(ok or why == "already registered", why)
  end

  L.restoreEggs = restoreEggs
  L.dexOf = dexOf
  return L
end
