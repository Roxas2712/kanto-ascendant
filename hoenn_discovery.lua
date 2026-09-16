-- Kanto Ascendant 6.7 Hoenn Discovery, Phase 2.
--
-- Surprise wins may open a trace, but never expose a trainer-owned Pokemon
-- as a catch target.  Standard encounters use a runtime-only proposal.  No
-- save delta, sighting, pity increment or pending catch is committed until
-- the exact proposed species and level reach an actual wild battle.started.

local Module = {
  INTRODUCTION_ROLL_MAX = 10000,
  INTRODUCTION_HIT_MAX = 2000,
  HARD_INTRODUCTION_WIN = 8,
  HARD_OVERLAY_ENCOUNTER = 50,
  NORMAL_HIT_MIN = 9901,       -- 1.00%
  TRACE_HIT_MIN = 9851,        -- 1.50%
  STARTER_HIT_MIN = 9851,      -- 0.50% directly below the normal 1% bucket
  STARTER_WITH_TRACE_HIT_MIN = 9801,
  ENCOUNTER_PRIORITY = -25,
  EVENT_PRIORITY = 4000,
}

local DEFAULT_CATALOG = {
  { id = "TREECKO", members = { "TREECKO", "GROVYLE", "SCEPTILE" } },
  { id = "TORCHIC", members = { "TORCHIC", "COMBUSKEN", "BLAZIKEN" } },
  { id = "MUDKIP", members = { "MUDKIP", "MARSHTOMP", "SWAMPERT" } },
}

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

local function key(value)
  return type(value) == "string" and value ~= "" and value:upper() or nil
end

local function nonNegativeInteger(value)
  value = tonumber(value)
  if not value or value ~= math.floor(value) or value < 0 then return 0 end
  return value
end

local function validRoll(value, maximum)
  return type(value) == "number" and value == math.floor(value)
    and value >= 1 and value <= maximum
end

local function mapKey(value)
  return type(value) == "string" and value ~= "" and value or nil
end

function Module.create(State, Overlay, Acquisition)
  assert(State and type(State.normalize) == "function"
      and type(State.mark) == "function"
      and type(State.unlock) == "function",
    "Hoenn Discovery requires Discovery State")
  assert(Overlay and type(Overlay.plan) == "function",
    "Hoenn Discovery requires the shared encounter overlay")

  local H = {
    INTRODUCTION_ROLL_MAX = Module.INTRODUCTION_ROLL_MAX,
    INTRODUCTION_HIT_MAX = Module.INTRODUCTION_HIT_MAX,
    HARD_INTRODUCTION_WIN = Module.HARD_INTRODUCTION_WIN,
    HARD_OVERLAY_ENCOUNTER = Module.HARD_OVERLAY_ENCOUNTER,
    NORMAL_HIT_MIN = Module.NORMAL_HIT_MIN,
    TRACE_HIT_MIN = Module.TRACE_HIT_MIN,
    STARTER_HIT_MIN = Module.STARTER_HIT_MIN,
    STARTER_WITH_TRACE_HIT_MIN = Module.STARTER_WITH_TRACE_HIT_MIN,
    ENCOUNTER_PRIORITY = Module.ENCOUNTER_PRIORITY,
    EVENT_PRIORITY = Module.EVENT_PRIORITY,
    order = {},
    ordinaryOrder = {},
    starterOrder = {},
    families = {},
    familyClass = {},
    speciesFamily = {},
    maps = {},
    acquisition = Acquisition,
    legacyCompatibility = type(Acquisition) ~= "table",
  }

  local catalog = type(Acquisition) == "table"
      and type(Acquisition.traceFamilies) == "table"
      and Acquisition.traceFamilies or DEFAULT_CATALOG
  local starterCatalog = type(Acquisition) == "table"
      and type(Acquisition.starterFamilies) == "table"
      and Acquisition.starterFamilies or {}
  local function registerFamily(source, class)
    local def = copy(source)
    H.order[#H.order + 1] = def.id
    local classOrder = class == "starter" and H.starterOrder
      or H.ordinaryOrder
    classOrder[#classOrder + 1] = def.id
    H.families[def.id] = def
    H.familyClass[def.id] = class
    for _, species in ipairs(def.members or {}) do
      H.speciesFamily[species] = def.id
    end
    local habitat = type(def.habitat) == "table" and def.habitat or nil
    if habitat and mapKey(habitat.map) then
      H.maps[habitat.map] = H.maps[habitat.map] or {}
      H.maps[habitat.map][#H.maps[habitat.map] + 1] = def.id
    end
  end
  for _, source in ipairs(catalog) do registerFamily(source, "ordinary") end
  for _, source in ipairs(starterCatalog) do
    registerFamily(source, "starter")
  end

  function H.primaryHabitat(family)
    local def = H.families[key(family)]
    return def and type(def.habitat) == "table" and copy(def.habitat) or nil
  end

  function H.familyForSpecies(species)
    local family = H.speciesFamily[key(species)]
    return family, family and H.familyClass[family] or nil
  end

  function H.familiesForMap(mapId, class)
    local out = {}
    for _, family in ipairs(H.maps[mapKey(mapId)] or {}) do
      if class == nil or H.familyClass[family] == class then
        out[#out + 1] = family
      end
    end
    return copy(out)
  end

  local function normalized(root)
    local out = State.normalize(root)
    return out
  end

  local function generation(root, create)
    local generations = type(root) == "table" and root.generations or nil
    local record = type(generations) == "table" and generations.hoenn or nil
    if type(record) == "table" or not create then return record end
    root.generations.hoenn = { families = {} }
    return root.generations.hoenn
  end

  local function familyRecord(root, family, create)
    local familyId = key(family)
    if not familyId or not H.families[familyId] then return nil end
    local generationRecord = generation(root, create)
    if not generationRecord then return nil end
    if type(generationRecord.families) ~= "table" then
      if not create then return nil end
      generationRecord.families = {}
    end
    local record = generationRecord.families[familyId]
    if type(record) == "table" or not create then return record end
    generationRecord.families[familyId] = {}
    return generationRecord.families[familyId]
  end

  local function registeredOrder(value, class)
    local enabled = {}
    if type(value) == "table" then
      for _, family in ipairs(value) do
        family = key(family)
        if family then enabled[family] = true end
      end
      for family, present in pairs(value) do
        if type(family) == "string" and present == true then
          enabled[family:upper()] = true
        end
      end
    end
    local out = {}
    for _, family in ipairs(H.order) do
      if enabled[family]
          and (class == nil or H.familyClass[family] == class) then
        out[#out + 1] = family
      end
    end
    return out
  end

  function H.introductionPity(root)
    local record = generation(root, false)
    return nonNegativeInteger(record and record.introductionPity)
  end

  function H.lastSurpriseToken(root)
    local record = generation(root, false)
    return record and type(record.lastSurpriseToken) == "string"
      and record.lastSurpriseToken or nil
  end

  function H.traceMap(root, family)
    local record = familyRecord(root, family, false)
    return record and mapKey(record.traceMap) or nil
  end

  function H.pendingCatch(root, family)
    local record = familyRecord(root, family, false)
    local pending = record and record.pendingCatch
    return type(pending) == "table" and copy(pending) or nil
  end

  function H.hydrateLineage(root, receipts)
    local out, changed = normalized(root), false
    for family, receipt in pairs(type(receipts) == "table" and receipts or {}) do
      family = key(family)
      if family and H.familyClass[family] == "ordinary"
          and type(receipt) == "table" and receipt.caught == true
          and receipt.unlocked == true then
        local before = State.status(out, "hoenn", family)
        out = select(1, State.mark(out, "hoenn", family, "caught"))
        out = select(1, State.unlock(out, "hoenn", family))
        local record = familyRecord(out, family, true)
        if not mapKey(record.traceMap) and mapKey(receipt.traceMap) then
          record.traceMap = receipt.traceMap
        end
        if before ~= "unlocked" then changed = true end
      end
    end
    return out, changed
  end

  local function localFamilies(root, registered, mapId)
    local families = registeredOrder(registered, "ordinary")
    if H.legacyCompatibility or not mapId then return families end
    local nearby = { [mapId] = true }
    for _, district in ipairs(Acquisition.traceDistricts or {}) do
      local contains = false
      for _, place in ipairs(district) do if place == mapId then contains = true end end
      if contains then for _, place in ipairs(district) do nearby[place] = true end end
    end
    local here, around = {}, {}
    for _, family in ipairs(families) do
      local habitat = H.primaryHabitat(family)
      -- Old saves retain their actual encounter location, even when it was
      -- assigned by a Wanderer rather than by the authored habitat table.
      local target = H.traceMap(root, family) or habitat and habitat.map
      local status = State.status(root, "hoenn", family)
      if status ~= "caught" and status ~= "unlocked" then
        if target == mapId then here[#here + 1] = family
        elseif nearby[target] then around[#around + 1] = family end
      end
    end
    if #here > 0 then return here end
    return around
  end

  local function introductionPool(root, registered, mapId)
    local unseen, unresolved, caught = {}, {}, {}
    for _, family in ipairs(localFamilies(root, registered, mapId)) do
      local status = State.status(root, "hoenn", family)
      if status == "unseen" then
        unseen[#unseen + 1] = family
      elseif status == "sighted" or status == "trace" then
        unresolved[#unresolved + 1] = family
      else
        caught[#caught + 1] = family
      end
    end
    if #unseen > 0 then return unseen, "unseen" end
    if #unresolved > 0 then return unresolved, "unresolved" end
    return {}, "caught"
  end

  H.introductionPool = introductionPool

  function H.planIntroduction(root, args)
    args = type(args) == "table" and args or {}
    local out = normalized(root)
    local mapId = mapKey(args.mapId)
    if args.eligible ~= true or not mapId then
      return out, {
        eligible = false, introduced = false, rollsUsed = 0,
        reason = "ineligible-surprise-win",
      }
    end
    local token = type(args.token) == "string" and args.token ~= ""
      and args.token or nil
    if not token then
      return out, {
        eligible = false, introduced = false, rollsUsed = 0,
        reason = "missing-surprise-token",
      }
    end

    local pool, tier = introductionPool(out, args.registeredFamilies, mapId)
    if #pool == 0 then
      return out, {
        eligible = false, introduced = false, rollsUsed = 0,
        reason = "no-registered-family",
      }
    end

    if H.lastSurpriseToken(out) == token then
      return out, {
        eligible = true, introduced = false, rollsUsed = 0,
        reason = "duplicate-surprise-win",
      }
    end
    if not validRoll(args.chanceRoll, H.INTRODUCTION_ROLL_MAX) then
      return out, {
        eligible = true, introduced = false, rollsUsed = 0,
        reason = "chance-roll-out-of-range",
      }
    end

    local before = H.introductionPity(out)
    local eligibleWin = before + 1
    local natural = args.chanceRoll <= H.INTRODUCTION_HIT_MAX
    local guaranteed = not natural
      and eligibleWin >= H.HARD_INTRODUCTION_WIN
    local introduced = natural or guaranteed
    if introduced and not validRoll(args.familyRoll, #pool) then
      return out, {
        eligible = true, introduced = false, natural = natural,
        guaranteed = guaranteed, rollsUsed = 1,
        reason = "family-roll-out-of-range",
      }
    end

    local generationRecord = generation(out, true)
    generationRecord.lastSurpriseToken = token
    if not introduced then
      generationRecord.introductionPity = eligibleWin
      return out, {
        changed = true,
        eligible = true,
        eligibleWin = eligibleWin,
        chanceRoll = args.chanceRoll,
        introduced = false,
        natural = false,
        guaranteed = false,
        rollsUsed = 1,
      }
    end

    local family = pool[args.familyRoll]
    local habitat = H.primaryHabitat(family)
    local traceMap = H.legacyCompatibility and mapKey(args.traceMap)
      or habitat and mapKey(habitat.map) or mapId
    local status = State.status(out, "hoenn", family)
    if status == "unseen" or status == "sighted" then
      out = State.mark(out, "hoenn", family, "trace")
      local record = familyRecord(out, family, true)
      if not mapKey(record.traceMap) then record.traceMap = traceMap end
    elseif status == "trace" then
      -- A repeated introduction may reinforce an unresolved clue, but its
      -- authored map binding is immutable until the family is caught.
      local record = familyRecord(out, family, true)
      if not mapKey(record.traceMap) then record.traceMap = traceMap end
    end
    generationRecord = generation(out, true)
    generationRecord.introductionPity = 0
    generationRecord.lastSurpriseToken = token
    return out, {
      changed = true,
      eligible = true,
      eligibleWin = eligibleWin,
      chanceRoll = args.chanceRoll,
      familyRoll = args.familyRoll,
      family = family,
      mapId = H.traceMap(out, family) or traceMap,
      sourceMapId = mapId,
      habitat = habitat,
      selectionTier = tier,
      introduced = true,
      natural = natural,
      guaranteed = guaranteed,
      rollsUsed = 2,
    }
  end

  function H.activeTraces(root, mapId, registered)
    mapId = mapKey(mapId)
    if not mapId then return {} end
    local out = {}
    for _, family in ipairs(registeredOrder(registered, "ordinary")) do
      local status = State.status(root, "hoenn", family)
      if (status == "sighted" or status == "trace")
          and H.traceMap(root, family) == mapId then
        out[#out + 1] = {
          family = family,
          species = H.families[family].members[1],
          pity = State.sightingPity(root, "hoenn", family),
        }
      end
    end
    return out
  end

  -- Caught ordinary families are durable lineage habitats in NG+.  Keep them
  -- separate from unresolved traces so they cannot accrue/reset pity or
  -- reopen Wanderer discovery rewards.  Their only route authority is the
  -- traceMap persisted by the journey in which they were actually found.
  function H.legacyHabitats(root, mapId, registered)
    mapId = mapKey(mapId)
    if not mapId then return {} end
    local out = {}
    for _, family in ipairs(registeredOrder(registered, "ordinary")) do
      if State.status(root, "hoenn", family) == "unlocked"
          and H.traceMap(root, family) == mapId then
        out[#out + 1] = {
          family = family,
          species = H.families[family].members[1],
          durable = true,
        }
      end
    end
    return out
  end

  local function registeredSet(registered)
    local out = {}
    for _, family in ipairs(registeredOrder(registered)) do out[family] = true end
    return out
  end

  local function familyRowsForMap(mapId, class, registered)
    local allowed, out = registeredSet(registered), {}
    for _, family in ipairs(H.familiesForMap(mapId, class)) do
      if allowed[family] then out[#out + 1] = family end
    end
    return out
  end

  local function partyAverage(game)
    local total, count = 0, 0
    for _, mon in ipairs(game and game.save and game.save.party or {}) do
      if type(mon) == "table" and mon.isEgg ~= true and mon.egg ~= true
          and tonumber(mon.level) then
        total = total + math.max(1, math.floor(tonumber(mon.level)))
        count = count + 1
      end
    end
    return count > 0 and math.floor(total / count + 0.5) or nil
  end

  local function encounterLevel(game, family, native, mode, badgeCount)
    local habitat = family and family.habitat or {}
    local routeLevel = math.max(1, math.floor(math.max(
      tonumber(native and native.level) or 1,
      tonumber(habitat.level) or 1)))
    if mode == "badges" then
      return math.min(100, math.max(routeLevel,
        4 + math.max(0, math.floor(tonumber(badgeCount) or 0)) * 6))
    elseif mode == "party" then
      return math.min(100, math.max(routeLevel, partyAverage(game) or 1))
    end
    return routeLevel
  end

  local function evolutionFloors(game, family)
    local members, floors, depths = {}, {}, {}
    for _, species in ipairs(family.members or {}) do members[species] = true end
    local root = family.members and family.members[1]
    if not root then return floors end
    floors[root], depths[root] = 1, 1
    local queue, index = { root }, 1
    local pokemon = game and game.data and game.data.pokemon or {}
    while queue[index] do
      local parent = queue[index]
      index = index + 1
      for _, branch in ipairs(pokemon[parent]
          and pokemon[parent].evolutions or {}) do
        local species = key(branch.species)
        if species and members[species] then
          local depth = (depths[parent] or 1) + 1
          local fallback = depth >= 3 and 36 or 20
          local minimum = math.max(floors[parent] or 1,
            math.floor(tonumber(branch.level) or fallback))
          if floors[species] == nil or minimum < floors[species] then
            floors[species], depths[species] = minimum, depth
            queue[#queue + 1] = species
          end
        end
      end
    end
    return floors
  end

  local function selectSpecies(game, family, roll, level, evolvedAllowed)
    local root = family.members[1]
    if not evolvedAllowed or (roll - 1) % 5 ~= 0 then return root, level end
    local floors, evolved = evolutionFloors(game, family), {}
    for index = 2, #family.members do
      local species = family.members[index]
      local minimum = floors[species]
      if minimum and minimum <= level then
        evolved[#evolved + 1] = { species = species, minimum = minimum }
      end
    end
    if #evolved == 0 then return root, level end
    local selected = evolved[(math.floor((roll - 1) / 5) % #evolved) + 1]
    return selected.species, math.max(level, selected.minimum)
  end

  local function selectedFamily(pool, roll, lower)
    if #pool == 0 then return nil end
    return pool[((roll - lower) % #pool) + 1]
  end

  -- Reserve enough remaining encounters for simultaneous clues. Waiting
  -- until all reach 49 misses would make every clue but one exceed 50.
  local function dueTrace(traces)
    local ordered = copy(traces)
    table.sort(ordered, function(a, b)
      if a.pity ~= b.pity then return a.pity > b.pity end
      return a.family < b.family
    end)
    for index, row in ipairs(ordered) do
      if row.pity + index >= H.HARD_OVERLAY_ENCOUNTER then return ordered[1] end
    end
  end

  function H.planFieldOverlay(root, args)
    args = type(args) == "table" and args or {}
    local native, mapId, roll = args.native, mapKey(args.mapId), args.roll
    if type(native) ~= "table" or type(native.species) ~= "string"
        or not mapId or not validRoll(roll, Overlay.ROLL_MAX or 10000) then
      return native, nil, "invalid-overlay-input"
    end
    local traces = H.activeTraces(root, mapId, args.registeredFamilies)
    local tracePool, traceFamilies = {}, {}
    local forced = dueTrace(traces)
    for _, row in ipairs(traces) do
      tracePool[#tracePool + 1] = row.family
      traceFamilies[row.family] = true
    end
    if args.legacyEnabled == true then
      for _, row in ipairs(H.legacyHabitats(
          root, mapId, args.registeredFamilies)) do
        if not traceFamilies[row.family] then
          tracePool[#tracePool + 1] = row.family
        end
      end
    end
    local normalPool = {}
    if args.normalEnabled == true then
      for _, family in ipairs(familyRowsForMap(
          mapId, "ordinary", args.registeredFamilies)) do
        if type(args.ordinaryAllowed) ~= "table"
            or args.ordinaryAllowed[family] == true then
          normalPool[#normalPool + 1] = family
        end
      end
    end
    local starterPool = {}
    for _, family in ipairs(familyRowsForMap(
        mapId, "starter", args.registeredFamilies)) do
      if type(args.starterUnlocked) == "table"
          and args.starterUnlocked[family] == true then
        starterPool[#starterPool + 1] = family
      end
    end

    local family, mode, natural, guaranteed, lower
    if forced then
      family, mode, guaranteed = forced.family, "trace", true
      natural = false
    elseif #tracePool > 0 and roll >= H.TRACE_HIT_MIN then
      family = selectedFamily(tracePool, roll, H.TRACE_HIT_MIN)
      mode = traceFamilies[family] and "trace" or "legacy"
      natural, lower = true, H.TRACE_HIT_MIN
    else
      local starterMinimum = #tracePool > 0
        and H.STARTER_WITH_TRACE_HIT_MIN or H.STARTER_HIT_MIN
      local starterMaximum = #tracePool > 0
        and H.TRACE_HIT_MIN - 1 or H.NORMAL_HIT_MIN - 1
      if #starterPool > 0 and roll >= starterMinimum
          and roll <= starterMaximum then
        family = selectedFamily(starterPool, roll, starterMinimum)
        mode, natural, lower = "starter", true, starterMinimum
      elseif #tracePool == 0 and #normalPool > 0
          and roll >= H.NORMAL_HIT_MIN then
        family = selectedFamily(normalPool, roll, H.NORMAL_HIT_MIN)
        mode, natural, lower = "normal", true, H.NORMAL_HIT_MIN
      end
    end

    local output = copy(native)
    if family then
      local def = H.families[family]
      local level = encounterLevel(args.game, def, native,
        args.levelMode, args.badgeCount)
      local species
      species, level = selectSpecies(args.game, def, roll, level,
        mode ~= "starter" and mode ~= "trace")
      output.species, output.level = species, level
      output.kaEncounterSource = "hoenn_discovery"
      output.kaProtected = true
      output.kaHoennFamily = family
      output.kaHoennMode = mode
    elseif #traces == 0 then
      return native, nil, "native"
    end

    local transaction = {
      serial = nonNegativeInteger(args.serial),
      mapId = mapId,
      roll = roll,
      expectedSpecies = output.species,
      expectedLevel = output.level,
      family = family,
      mode = mode,
      natural = family ~= nil and natural or false,
      guaranteed = family ~= nil and guaranteed or false,
      traces = copy(traces),
      committed = false,
      cancelled = false,
    }
    return output, transaction, family and mode or "trace-miss"
  end

  function H.planOverlay(root, args)
    if not H.legacyCompatibility and args and args.expanded == true then
      return H.planFieldOverlay(root, args)
    end
    args = type(args) == "table" and args or {}
    local native = args.native
    local mapId = mapKey(args.mapId)
    if type(native) ~= "table" or type(native.species) ~= "string"
        or not mapId or not validRoll(args.roll, Overlay.ROLL_MAX or 10000) then
      return native, nil, "invalid-overlay-input"
    end
    local traces = H.activeTraces(root, mapId, args.registeredFamilies)
    if #traces == 0 then return native, nil, "no-map-trace" end

    local traceSet, pool = {}, {}
    local forced = dueTrace(traces)
    for _, row in ipairs(traces) do
      traceSet[row.family] = true
      pool[#pool + 1] = {
        species = row.species,
        family = row.family,
        level = native.level,
        habitats = { mapId },
      }
    end

    local planned, reason = Overlay.plan({
      roll = args.roll,
      nativePool = { native },
      johtoPool = {},
      hoennPool = pool,
      johtoUnlocked = {},
      hoennTraces = traceSet,
      habitat = mapId,
    })
    if not planned then return native, nil, reason end

    local natural = planned.source == "hoenn"
    local selected = natural and key(planned.encounter.family) or nil
    local guaranteed = false
    if forced then
      selected = forced.family
      guaranteed = true
      natural = false
    end

    local output = copy(native)
    if selected then
      output.species = H.families[selected].members[1]
      output.kaEncounterSource = "hoenn_discovery"
      output.kaProtected = true
      output.kaHoennFamily = selected
    end

    local transaction = {
      serial = nonNegativeInteger(args.serial),
      mapId = mapId,
      roll = args.roll,
      expectedSpecies = output.species,
      expectedLevel = output.level,
      family = selected,
      natural = selected ~= nil and natural or false,
      guaranteed = selected ~= nil and guaranteed or false,
      traces = copy(traces),
      committed = false,
      cancelled = false,
    }
    return output, transaction
  end

  local function startedMap(value)
    if type(value) ~= "table" then return nil end
    if mapKey(value.mapId) then return value.mapId end
    local battle = value.battle or value
    local game = battle and battle.game
    return game and game.overworld and game.overworld.map
      and game.overworld.map.id or nil
  end

  function H.commitStarted(root, transaction, value)
    local out = normalized(root)
    if type(transaction) ~= "table"
        or transaction.committed or transaction.cancelled then
      return out, false, "inactive-transaction"
    end
    value = type(value) == "table" and value or {}
    local battle = value.battle or value
    local kind = value.kind or battle.kind
    local encounterSource = value.encounterSource or battle.encounterSource
    -- Engine 0.2.57 identifies ordinary grass/cave/surf battles through
    -- checkpointOrigin, without setting encounterSource. Accept that exact
    -- field origin only; missing provenance or explicit non-wild sources
    -- must not count. The pending proposal and all guards below still apply.
    local origin = battle.checkpointOrigin
    if encounterSource == nil and type(origin) == "table"
        and origin.kind == "wild_encounter"
        and origin.map == transaction.mapId then
      encounterSource = "wild"
    end
    local species = value.species
    local level = value.level
    if battle.enemy and battle.enemy.mon then
      species = species or battle.enemy.mon.species
      level = level or battle.enemy.mon.level
    end
    if kind ~= "wild" or encounterSource ~= "wild"
        or battle.noCatch == true or battle.scriptedEncounter
        or battle.demo or battle.safari or battle.ghost or battle.dead
        or battle.ascendantMythicProtected then
      transaction.cancelled = true
      return out, false, "protected-catch-surface"
    end
    if species ~= transaction.expectedSpecies
        or tonumber(level) ~= tonumber(transaction.expectedLevel)
        or startedMap(value) ~= transaction.mapId then
      transaction.cancelled = true
      return out, false, "battle-mismatch"
    end

    for _, row in ipairs(transaction.traces or {}) do
      local status = State.status(out, "hoenn", row.family)
      if H.traceMap(out, row.family) ~= transaction.mapId
          or (status ~= "sighted" and status ~= "trace")
          or State.sightingPity(out, "hoenn", row.family) ~= row.pity then
        transaction.cancelled = true
        return out, false, "stale-transaction"
      end
    end

    for _, row in ipairs(transaction.traces or {}) do
      if transaction.family == row.family then
        out = State.mark(out, "hoenn", row.family, "sighted")
        out = State.setSightingPity(out, "hoenn", row.family, 0)
      else
        out = State.setSightingPity(out, "hoenn", row.family,
          math.min(H.HARD_OVERLAY_ENCOUNTER, row.pity + 1))
      end
    end

    if transaction.family then
      local record = familyRecord(out, transaction.family, true)
      record.pendingCatch = {
        version = 1,
        serial = transaction.serial,
        family = transaction.family,
        species = transaction.expectedSpecies,
        mapId = transaction.mapId,
      }
    end
    transaction.committed = true
    return out, true, {
      serial = transaction.serial,
      family = transaction.family,
      species = transaction.expectedSpecies,
      mapId = transaction.mapId,
      mode = transaction.mode,
      sighted = transaction.family ~= nil,
      natural = transaction.natural,
      guaranteed = transaction.guaranteed,
    }
  end

  local function pendingMatches(pending, args)
    if type(pending) ~= "table" or type(args) ~= "table" then return false end
    return pending.family == key(args.family)
      and pending.species == key(args.species)
      and pending.mapId == mapKey(args.mapId)
      and nonNegativeInteger(pending.serial) == nonNegativeInteger(args.serial)
  end

  function H.completeCatch(root, args)
    local out = normalized(root)
    local family = key(args and args.family)
    local pending = family and H.pendingCatch(out, family) or nil
    if not pendingMatches(pending, args) then
      return out, false, "pending-catch-mismatch"
    end
    local record = familyRecord(out, family, true)
    record.pendingCatch = nil
    out = State.mark(out, "hoenn", family, "caught")
    local unlocked
    out, unlocked = State.unlock(out, "hoenn", family)
    return out, {
      family = family,
      species = pending.species,
      caught = true,
      unlocked = unlocked == true
        or State.status(out, "hoenn", family) == "unlocked",
    }
  end

  function H.closePending(root, args)
    local out = normalized(root)
    local family = key(args and args.family)
    local pending = family and H.pendingCatch(out, family) or nil
    if not pendingMatches(pending, args) then
      return out, false, "pending-catch-mismatch"
    end
    familyRecord(out, family, true).pendingCatch = nil
    return out, true
  end

  function H.clearPending(root)
    local out = normalized(root)
    local changed = false
    for _, family in ipairs(H.order) do
      local record = familyRecord(out, family, false)
      if record and record.pendingCatch ~= nil then
        record.pendingCatch = nil
        changed = true
      end
    end
    return out, changed
  end

  local function listedByLegacy(legacy, species, dex)
    if type(legacy) ~= "table" or type(legacy.order) ~= "table"
        or type(legacy.species) ~= "table" then return false end
    local listed = false
    for _, value in ipairs(legacy.order) do
      if value == species then listed = true break end
    end
    local row = legacy.species[species]
    return listed and type(row) == "table" and tonumber(row.dex) == dex
  end

  local function completeDefinition(game, deps, species)
    local data = game and game.data
    local def = data and data.pokemon and data.pokemon[species]
    local dex = def and tonumber(def.dex)
    if type(def) ~= "table" or def.id ~= species
        or type(def.name) ~= "string" or not dex
        or type(def.types) ~= "table" or #def.types == 0
        or type(def.baseStats) ~= "table"
        or tonumber(def.catchRate) == nil
        or type(def.growthRate) ~= "string"
        or type(def.level1Moves) ~= "table"
        or type(def.learnset) ~= "table"
        or type(def.evolutions) ~= "table"
        or type(def.tmhm) ~= "table"
        or type(def.cry) ~= "string"
        or type(def.spriteFront) ~= "string" or def.spriteFront == ""
        or type(def.spriteBack) ~= "string" or def.spriteBack == ""
        or def.icon == nil or type(def.dexEntry) ~= "table" then
      return false
    end
    local cries = data.audio and data.audio.cries
    if type(cries) ~= "table" or cries[def.cry] == nil then return false end
    local authority = type(deps.hoennSpecies67) == "table"
      and type(deps.hoennSpecies67.bySpecies) == "table"
      and deps.hoennSpecies67.bySpecies[species] or nil
    if authority then
      return tonumber(authority.runtimeDex) == dex
        and tonumber(authority.sourceDex) == tonumber(def.sourceDex or dex)
    end

    -- Compatibility for the isolated Phase-2 fixtures and old downstream
    -- callers that intentionally provide only the original three families.
    if not listedByLegacy(deps.legacyHoenn, species, dex) then return false end
    local runtime = deps.extendedSpeciesRuntime
    if type(runtime) ~= "table" or type(runtime.identity) ~= "function" then
      return false
    end
    local ok, identity = pcall(runtime.identity, species, data)
    return ok and type(identity) == "table"
      and identity.family == "legacy_hoenn"
      and tonumber(identity.internalRuntimeDex) == dex
      and tonumber(identity.sourceDex) == dex
  end

  local function completeFamilyGraph(game, family)
    local pokemon = game and game.data and game.data.pokemon or {}
    local members, reached = {}, {}
    for _, species in ipairs(family.members or {}) do members[species] = true end
    local root = family.members and family.members[1]
    if not root then return false end
    local function visit(species)
      if reached[species] then return end
      reached[species] = true
      for _, branch in ipairs(pokemon[species].evolutions or {}) do
        if members[branch.species] then visit(branch.species) end
      end
    end
    visit(root)
    for species in pairs(members) do
      if not reached[species] then return false end
    end
    return true
  end

  function H.registeredFamilies(game, deps)
    deps = type(deps) == "table" and deps or {}
    local out = {}
    for _, familyId in ipairs(H.order) do
      local family = H.families[familyId]
      local complete = true
      for _, species in ipairs(family.members) do
        if not completeDefinition(game, deps, species) then
          complete = false
          break
        end
      end
      if complete and not completeFamilyGraph(game, family) then complete = false end
      if complete then out[#out + 1] = familyId end
    end
    return out
  end

  local function surface(encDef, terrain)
    if type(encDef) ~= "table" or type(terrain) ~= "string" then return nil end
    local row = encDef[terrain]
    return type(row) == "table" and row or nil
  end

  local function usableSurface(row)
    return type(row) == "table" and (tonumber(row.rate) or 0) > 0
      and type(row.slots) == "table" and #row.slots > 0
  end

  local function encounterSurface(encDef, terrain)
    if terrain == "grass" then return surface(encDef, "grass") end
    if terrain == "indoor" or terrain == "cave" then
      -- The engine labels cave/tower/mansion rolls as `indoor`, while the
      -- canonical encounter payload still lives in its `grass` surface.
      return surface(encDef, "cave") or surface(encDef, "grass")
    end
    return nil
  end

  function H.mapHasEligibleWild(game, mapId)
    local enc = game and game.data and game.data.encounters
      and game.data.encounters[mapId]
    return usableSurface(surface(enc, "grass"))
      or usableSurface(surface(enc, "cave"))
  end

  local function nativeSlotMatches(slot, encounter)
    if type(slot) ~= "table" or slot.species ~= encounter.species then
      return false
    end
    if tonumber(slot.level) ~= nil then
      return tonumber(slot.level) == tonumber(encounter.level)
    end
    local minimum = tonumber(slot.minLevel or slot.levelMin)
    local maximum = tonumber(slot.maxLevel or slot.levelMax)
    local level = tonumber(encounter.level)
    return minimum and maximum and level and level >= minimum and level <= maximum
      or false
  end

  function H.isEligibleNative(game, native, encDef, ctx)
    if type(native) ~= "table" or type(native.species) ~= "string"
        or type(ctx) ~= "table" or type(ctx.rng) ~= "function"
        or ctx.kaProtected or ctx.kaEncounterSource
        or native.kaProtected or native.kaEncounterSource then return false end
    local mapId = mapKey(ctx.mapId)
    if not mapId or mapId:find("SAFARI_ZONE", 1, true) then return false end
    if ctx.terrain ~= "grass" and ctx.terrain ~= "indoor"
        and ctx.terrain ~= "cave" then return false end
    if ctx.source == "fishing" or ctx.source == "wilds"
        or ctx.visibleWilds == true or ctx.kaVisibleWild == true then return false end
    local opts = ctx.opts
    if type(opts) == "table" and (opts.hooked == true
        or opts.scriptedEncounter == true or opts.randomizerProtected == true) then
      return false
    end
    local row = encounterSurface(encDef, ctx.terrain)
    if not usableSurface(row) then return false end
    local matches = false
    for _, slot in ipairs(row.slots) do
      if nativeSlotMatches(slot, native) then matches = true break end
    end
    if not matches then return false end
    local def = game and game.data and game.data.pokemon
      and game.data.pokemon[native.species]
    local sourceDex = type(def) == "table"
      and tonumber(def.sourceDex or def.nationalDex or def.dex) or nil
    -- Hoenn traces are a low-probability replacement layer over the released
    -- Kanto/Johto field pool. Never recurse over a Hoenn or later-generation
    -- native encounter, even when it uses a compact runtime slot.
    return sourceDex ~= nil and sourceDex >= 1 and sourceDex <= 251
  end

  local function runRulesBlocked(runRules, game)
    if type(runRules) ~= "table" or type(runRules.state) ~= "function" then
      return false
    end
    local ok, state = pcall(runRules.state, game and game.save)
    if not ok or type(state) ~= "table" or state.locked ~= true then
      return false
    end
    local randomizer = state.randomizer
    local nuzlocke = state.nuzlocke
    return type(randomizer) == "table" and randomizer.enabled == true
        and randomizer.wild == true
      or state.failed ~= true and type(nuzlocke) == "table"
        and nuzlocke.mode ~= nil and nuzlocke.mode ~= "off"
      or false
  end

  function H.attach(mod, deps)
    deps = type(deps) == "table" and deps or {}
    local manager = assert(deps.state,
      "Hoenn Discovery runtime requires the save adapter")
    assert(type(manager.root) == "function"
        and type(manager.replace) == "function",
      "Hoenn Discovery save adapter is invalid")
    local C = {
      game = nil,
      serial = 0,
      encounterPriority = H.ENCOUNTER_PRIORITY,
      eventPriority = H.EVENT_PRIORITY,
    }
    local pendingProposal

    local function profileSpeciesAllowed(game, species)
      local rules = deps.generationRules
      if not (rules and type(rules.speciesAvailable) == "function") then
        return true
      end
      local def = game and game.data and game.data.pokemon
        and game.data.pokemon[species]
      if type(def) ~= "table" then return false end
      local ok, allowed = pcall(rules.speciesAvailable, game, species, def)
      return ok and allowed == true
    end

    local function random(low, high, purpose)
      local source = deps.random
      local value
      if type(source) == "function" then
        value = source(low, high, purpose)
      elseif love and love.math and type(love.math.random) == "function" then
        value = love.math.random(low, high)
      else
        value = math.random(low, high)
      end
      value = math.floor(tonumber(value) or high)
      return math.max(low, math.min(high, value))
    end

    local function gameOf(value)
      if type(value) == "table" and value.game then return value.game end
      return C.game
    end

    local function mapOf(value, game)
      if type(value) == "table" and mapKey(value.mapId) then return value.mapId end
      local battle = type(value) == "table" and (value.battle or value) or nil
      game = game or battle and battle.game or C.game
      return game and game.overworld and game.overworld.map
        and game.overworld.map.id or nil
    end

    local function registered(game)
      return H.registeredFamilies(game, deps)
    end

    local function fieldPolicy(game)
      local access = deps.fieldAccess
      local normal, legacy, levelMode, badges = false, false, "route", 0
      local starters = {}
      local ordinaryAllowed = {}
      if type(access) == "table" then
        if type(access.normalEnabled) == "function" then
          local ok, value = pcall(access.normalEnabled, game)
          normal = ok and value == true
        end
        if type(access.isLegacy) == "function" then
          local ok, value = pcall(access.isLegacy, game)
          legacy = ok and value == true
        end
        if type(access.levelMode) == "function" then
          local ok, value = pcall(access.levelMode, game)
          if ok and ({ route=true, badges=true, party=true })[value] then
            levelMode = value
          end
        end
        if type(access.badgeCount) == "function" then
          local ok, value = pcall(access.badgeCount, game)
          badges = ok and math.max(0, math.floor(tonumber(value) or 0)) or 0
        end
        if type(access.starterUnlocked) == "function" then
          for _, family in ipairs(H.starterOrder) do
            local ok, value = pcall(access.starterUnlocked, game, family)
            starters[family] = ok and value == true
          end
        end
        if type(access.characterFamilies) == "function" then
          local ok, rows = pcall(access.characterFamilies, game)
          if ok and type(rows) == "table" then
            for _, family in ipairs(rows) do ordinaryAllowed[family] = true end
          end
        end
      end
      return normal, legacy, levelMode, badges, starters, ordinaryAllowed
    end

    function C.cancelPending(reason)
      local transaction = pendingProposal
      pendingProposal = nil
      if not transaction then return false end
      transaction.cancelled = true
      transaction.cancelReason = reason or "cancelled"
      return true
    end

    function C.pending()
      return pendingProposal and copy(pendingProposal) or nil
    end

    function C.handleSurpriseWin(battle)
      local game = gameOf(battle)
      local mapId = mapOf(battle, game)
      local token = battle and battle.ascendantLegacyToken
      local access = deps.fieldAccess
      if type(access) == "table"
          and type(access.encountersEnabled) == "function" then
        local ok, enabled = pcall(access.encountersEnabled, game)
        if not ok or enabled ~= true then
          return false, "encounters-disabled"
        end
      end
      if not (battle and battle.ascendantLegacyWanderer == true)
          or type(token) ~= "string" or token == ""
          or not H.mapHasEligibleWild(game, mapId)
          or runRulesBlocked(deps.runRules, game) then
        return false, "ineligible-surprise-win"
      end
      local families = registered(game)
      if type(access) ~= "table"
          or type(access.introductionFamilies) ~= "function" then
        return false, "missing-character-pack-authority"
      end
      local ok, filtered = pcall(access.introductionFamilies, game, families)
      families = ok and type(filtered) == "table" and filtered or {}
      if #families == 0 then return false, "no-registered-family" end
      local root = manager.root(true)
      if type(token) == "string" and H.lastSurpriseToken(root) == token then
        return false, "duplicate-surprise-win"
      end
      local pool = introductionPool(root, families, mapId)
      if #pool == 0 then return false, "no-local-family" end
      local chanceRoll = random(1, H.INTRODUCTION_ROLL_MAX,
        "hoenn-introduction")
      local willIntroduce = chanceRoll <= H.INTRODUCTION_HIT_MAX
        or H.introductionPity(root) + 1 >= H.HARD_INTRODUCTION_WIN
      local familyRoll = willIntroduce and random(1, #pool, "hoenn-family")
        or nil
      local nextRoot, result = H.planIntroduction(root, {
        mapId = mapId,
        eligible = true,
        registeredFamilies = families,
        chanceRoll = chanceRoll,
        familyRoll = familyRoll,
        token = token,
      })
      if result.changed then manager.replace(nextRoot) end
      battle.kaHoennIntroductionCounted = result.changed == true
      -- Presentation is a separate optional Card. Publish only this transient
      -- result; the durable trace remains wholly owned by Discovery.
      battle.kaHoennIntroductionResult = result.changed == true
        and copy(result) or nil
      return result.changed == true, result
    end

    function C.propose(native, encDef, ctx)
      C.cancelPending("superseded-roll")
      local game = gameOf(ctx)
      C.game = game or C.game
      local access = deps.fieldAccess
      if type(access) == "table"
          and type(access.encountersEnabled) == "function" then
        local ok, enabled = pcall(access.encountersEnabled, game)
        if not ok or enabled ~= true then return native end
      end
      if runRulesBlocked(deps.runRules, game)
          or not H.isEligibleNative(game, native, encDef, ctx) then
        return native
      end
      local families = registered(game)
      local normal, legacy, levelMode, badges, starters, ordinaryAllowed =
        fieldPolicy(game)
      local normalOnMap = normal
        and #H.familiesForMap(ctx.mapId, "ordinary") > 0
      local hasStarter = false
      for family, value in pairs(starters) do
        local habitat = value and H.primaryHabitat(family) or nil
        if habitat and habitat.map == ctx.mapId then
          hasStarter = true break
        end
      end
      if #H.activeTraces(manager.root(false), ctx.mapId, families) == 0
          and (not legacy or #H.legacyHabitats(
            manager.root(false), ctx.mapId, families) == 0)
          and not normalOnMap and not hasStarter then
        return native
      end
      C.serial = C.serial + 1
      local roll = ctx.rng(1, Overlay.ROLL_MAX or 10000)
      local output, transaction = H.planOverlay(manager.root(true), {
        native = native,
        mapId = ctx.mapId,
        registeredFamilies = families,
        roll = roll,
        serial = C.serial,
        expanded = not H.legacyCompatibility,
        game = game,
        normalEnabled = normalOnMap,
        legacyEnabled = legacy,
        levelMode = levelMode,
        badgeCount = badges,
        starterUnlocked = starters,
        ordinaryAllowed = ordinaryAllowed,
      })
      if output ~= native and type(output) == "table"
          and not profileSpeciesAllowed(game, output.species) then
        return native
      end
      pendingProposal = transaction
      return output
    end

    function C.commitStarted(ev)
      local transaction = pendingProposal
      pendingProposal = nil
      if not transaction then return false, "none" end
      local battle = ev and ev.battle or ev
      local mon = battle and battle.enemy and battle.enemy.mon
      local nextRoot, committed, result = H.commitStarted(
        manager.root(true), transaction, {
          battle = battle,
          kind = ev and ev.kind or battle and battle.kind,
          species = mon and mon.species,
          level = mon and mon.level,
          mapId = mapOf(ev, battle and battle.game),
        })
      if not committed then return false, result end
      manager.replace(nextRoot)
      if result.family and battle then
        battle.kaHoennDiscoveryFamily = result.family
        battle.kaHoennDiscoverySpecies = result.species
        battle.kaHoennDiscoveryMap = result.mapId
        battle.kaHoennDiscoverySerial = result.serial
        battle.kaHoennDiscoveryMode = result.mode
      end
      return true, result
    end

    local function battleReceipt(battle, species)
      if not (battle and battle.kaHoennDiscoveryFamily) then return nil end
      return {
        family = battle.kaHoennDiscoveryFamily,
        species = species or battle.kaHoennDiscoverySpecies,
        mapId = battle.kaHoennDiscoveryMap,
        serial = battle.kaHoennDiscoverySerial,
      }
    end

    function C.completeCatch(ev)
      local battle = ev and ev.battle
      local species = ev and (ev.species or ev.mon and ev.mon.species)
      local receipt = battleReceipt(battle, species)
      if not receipt then return false, "not-discovery-catch" end
      local nextRoot, result, reason = H.completeCatch(
        manager.root(true), receipt)
      if not result then return false, reason end
      manager.replace(nextRoot)
      battle.kaHoennDiscoveryCaught = true
      local journey = deps.legacyJourney
      if journey and type(journey.syncHevoPersistent) == "function"
          and battle.game and battle.game.save then
        pcall(journey.syncHevoPersistent, battle.game.save)
      end
      return true, result
    end

    function C.finishBattle(ev)
      local battle = ev and ev.battle
      local receipt = battleReceipt(battle)
      if not receipt then return false, "not-discovery-battle" end
      if ev.result == "caught" and not battle.kaHoennDiscoveryCaught then
        local completed = C.completeCatch({
          battle = battle,
          species = receipt.species,
          game = battle.game,
        })
        if completed then return true, "caught" end
      end
      local nextRoot, closed, reason = H.closePending(
        manager.root(true), receipt)
      if closed then manager.replace(nextRoot) end
      return closed, reason
    end

    local function resetRuntime(ev)
      C.game = ev and ev.game or C.game
      C.cancelPending("save-boundary")
      local root = manager.root(true)
      local cleaned, changed = H.clearPending(root)
      local journey = deps.legacyJourney
      if journey and type(journey.profile) == "function" then
        local ok, profile = pcall(journey.profile)
        if ok and type(profile) == "table" then
          local hydrated, hydrationChanged = H.hydrateLineage(cleaned,
            profile.hoennDiscoveryUnlocks)
          cleaned, changed = hydrated, changed or hydrationChanged
        end
      end
      if changed then manager.replace(cleaned) end
    end

    if mod.hooks and type(mod.hooks.wrap) == "function" then
      mod.hooks:wrap("encounter.roll", function(nextRoll, encDef, ctx)
        local native = nextRoll(encDef, ctx)
        if not native then C.cancelPending("no-native-encounter"); return native end
        return C.propose(native, encDef, ctx)
      end, H.ENCOUNTER_PRIORITY)
    end

    if mod.events and type(mod.events.on) == "function" then
      mod.events:on("battle.started", C.commitStarted, H.EVENT_PRIORITY)
      mod.events:on("world.stepped", function()
        C.cancelPending("next-world-step")
      end, H.EVENT_PRIORITY)
      mod.events:on("pokemon.caught", C.completeCatch, H.EVENT_PRIORITY)
      mod.events:on("battle.ended", function(ev)
        local battle = ev and ev.battle
        if battle and battle.kaHoennDiscoveryFamily then C.finishBattle(ev) end
        if ev and ev.result == "win" and battle
            and battle.ascendantLegacyWanderer == true
            and not battle.kaHoennIntroductionCounted then
          C.handleSurpriseWin(battle)
        end
      end, H.EVENT_PRIORITY)
      mod.events:on("save.created", resetRuntime, 900)
      mod.events:on("save.loaded", resetRuntime, 900)
      mod.events:on("game.ready", resetRuntime, 900)
    end

    return C
  end

  H.copy = copy
  return H
end

Module.catalog = function(acquisition)
  return copy(type(acquisition) == "table"
    and acquisition.traceFamilies or DEFAULT_CATALOG)
end
return Module
