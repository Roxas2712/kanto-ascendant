-- Kanto Ascendant 6.x compatibility for Wilds of Kanto.
--
-- Wilds creates visible encounters directly from its map table and therefore
-- never reaches encounter.roll.  This adapter uses Wilds' exported
-- encounter_pick module exactly once, turns the result into transactional
-- Early-Johto/Mythic proposals, and passes the final species explicitly to
-- logic:trySpawn().  No save delta is committed while an entity is merely
-- visible.  The exact species and level must reach battle.started after
-- logic:_startBattle() succeeded.

return function(mod, opts)
  opts = opts or {}

  local early = assert(opts.johtoSignals or opts.earlyJohto,
    "Johto Signals Wilds adapter needs Early Johto")
  local mythic = assert(opts.mythicSignals,
    "Johto Signals Wilds adapter needs Mythic Signals")
  local lind = opts.johtoResearch
  local runRules = opts.runRules
  local starterHabitats = opts.starterHabitats
  local worldEvents = opts.worldEvents
  local encounterLevels = opts.encounterLevels or early.encounterLevels or {
    routeAverage = function() return nil end,
  }

  local W = {
    game = nil,
    logic = nil,
    installed = false,
    wildsVersion = nil,
    encounterPick = nil,
    waterSpawn = nil,
    waterWrapped = false,
    EVENT_PRIORITY = 900,
  }

  local runtime = {
    pendingBattle = nil,
    serial = 0,
    random = opts.random,
    installs = 0,
    rareClaims = {},
    mythicClaim = nil,
    habitatClaim = nil,
  }

  local TERRAIN_FOR_SURFACE = {
    GRASS = "grass",
    CAVE = "indoor",
    INTERIOR = "indoor",
    WATER = "water",
  }

  local function randomSource(override)
    return override
      or runtime.random
      or (love and love.math and love.math.random)
      or math.random
  end

  local function integrationEnabled()
    if mod.options and type(mod.options.get) == "function" then
      return mod.options:get("johto_wilds_integration") ~= false
    end
    return true
  end

  local function copyTable(source)
    local out = {}
    for key, value in pairs(source or {}) do out[key] = value end
    return out
  end

  local function protectedCopy(source, replacement, owner)
    local out = copyTable(source)
    for key, value in pairs(replacement or {}) do out[key] = value end
    out.kaProtected = true
    out.kaEncounterSource = owner
    return out
  end

  local function terrainForSurface(surface, encounterKind)
    local terrain = TERRAIN_FOR_SURFACE[tostring(surface or ""):upper()]
    if terrain then return terrain end
    if encounterKind == "water" then return "water" end
    if encounterKind == "grass" then return "grass" end
    return nil
  end

  local function overworldFor(logic)
    local world = logic and logic.mod and logic.mod.world
    if not (world and type(world.overworld) == "function") then
      world = mod.world
    end
    return world and type(world.overworld) == "function"
      and world:overworld() or nil
  end

  local function wildsExport(game, deps)
    if deps and type(deps.wilds) == "table" then return deps.wilds end
    local ok, handle = false, nil
    if mod and type(mod.find) == "function" then
      ok, handle = pcall(function() return mod.find("overworld_wild_spawns") end)
    end
    local public = ok and type(handle) == "table" and handle.exports or nil
    if public then return public end
    local internal = mod.exports and mod.exports.internalWilds
    return type(internal) == "table" and internal.exports or nil
  end

  local function cancelEarly(transaction, reason)
    if transaction and type(early.cancelWildsSpawn) == "function" then
      return early.cancelWildsSpawn(transaction, reason)
    end
    return false
  end

  local function cancelMythic(transaction)
    if transaction and type(mythic.cancel) == "function" then
      return mythic.cancel(transaction)
    end
    return false
  end

  local function cancelHabitat(transaction, reason)
    local wilds = starterHabitats and starterHabitats.wilds
    if transaction and wilds and type(wilds.cancel) == "function" then
      return wilds.cancel(transaction, reason)
    end
    return false
  end

  local function cancelBundle(bundle, reason)
    if type(bundle) ~= "table"
        or bundle.cancelled or bundle.committed then return false end
    bundle.cancelled = true
    bundle.cancelReason = reason or "cancelled"
    if bundle.randomizerTicket and runRules
        and type(runRules.cancelVisibleWild) == "function" then
      runRules.cancelVisibleWild(bundle.randomizerTicket)
    end
    cancelEarly(bundle.early, bundle.cancelReason)
    cancelMythic(bundle.mythic)
    cancelHabitat(bundle.habitat, bundle.cancelReason)
    if bundle.rareClaim
        and runtime.rareClaims[bundle.rareClaim] == bundle then
      runtime.rareClaims[bundle.rareClaim] = nil
    end
    if runtime.mythicClaim == bundle then
      runtime.mythicClaim = nil
    end
    if runtime.habitatClaim == bundle then
      runtime.habitatClaim = nil
    end
    return true
  end

  local function cancelPending(reason)
    local pending = runtime.pendingBattle
    runtime.pendingBattle = nil
    if not pending then return false end
    return cancelBundle(pending.bundle, reason or "pending-cancelled")
  end

  local function skipSignals(game, incoming)
    incoming = incoming or {}
    if incoming.species ~= nil or incoming.level ~= nil
        or incoming.testSpawn or incoming.readinessProbe
        or incoming.force or incoming.explicit
        or incoming.preview or incoming.debug then
      return true, "explicit-or-diagnostic"
    end
    local repelSteps = game and game.save
      and tonumber(game.save.repelSteps) or 0
    if repelSteps > 0 then return true, "repel" end
    return false
  end

  local function contextFor(logic, game, rng, forcedEncounterKind)
    local ow = overworldFor(logic)
    local mapId = ow and ow.map and ow.map.id or logic.activeMapId
    if not mapId then return nil, nil, nil end
    local encDef = type(logic._encDef) == "function"
      and logic:_encDef(mapId, game) or nil
    if type(encDef) ~= "table" then return nil, nil, nil end
    local surfaceInfo = logic.surfaceInfo or {}
    local encounterKind = forcedEncounterKind or surfaceInfo.encounterKind
      or (surfaceInfo.surface == "WATER" and "water") or "grass"
    local terrain = forcedEncounterKind == "water" and "water"
      or terrainForSurface(surfaceInfo.surface, encounterKind)
    if not terrain then return nil, nil, nil end
    return encDef, encounterKind, {
      mapId = mapId,
      terrain = terrain,
      encounterKind = encounterKind,
      kaProtected = encDef.kaProtected == true or nil,
      kaEncounterSource = encDef.kaEncounterSource,
      routeAverageLevel =
        encounterLevels.routeAverage(encDef, encounterKind),
      rng = rng,
      game = game,
      kaVisibleWild = true,
    }
  end

  local function starterHabitatFor(mapId)
    return type(starterHabitats) == "table"
      and type(starterHabitats.maps) == "table"
      and starterHabitats.maps[mapId] or nil
  end

  -- main.lua constructs this adapter before the content registry reaches the
  -- Access V3.1/habitat block. Bind the controller later, but still before
  -- install(game), without closing over a permanently nil placeholder.
  function W.bindStarterHabitats(habitats)
    local wilds = type(habitats) == "table" and habitats.wilds
    if type(habitats) ~= "table" or type(habitats.maps) ~= "table"
        or type(habitats.SOURCE) ~= "string"
        or type(wilds) ~= "table" or type(wilds.plan) ~= "function"
        or type(wilds.commitStarted) ~= "function"
        or type(wilds.cancel) ~= "function" then
      return false, "invalid-starter-habitat-controller"
    end
    if starterHabitats == habitats then return true, "already-bound" end

    if runtime.habitatClaim then
      cancelBundle(runtime.habitatClaim, "habitat-controller-rebound")
    end
    if W.logic and type(W.logic.spawns) == "table" then
      for _, record in pairs(W.logic.spawns) do
        local bundle = type(record) == "table" and record._kaSignalsWilds
        if bundle and bundle.habitat then
          cancelBundle(bundle, "habitat-controller-rebound")
          record._kaSignalsWilds = nil
          record._kaSignalsStarting = nil
        end
      end
    end
    runtime.habitatClaim = nil
    starterHabitats = habitats
    return true
  end

  -- main.lua creates World Events after the Signals hub. Bind that late
  -- controller into the already-constructed adapter without rebuilding or
  -- nesting the live Wilds wrappers.
  function W.bindWorldEvents(controller)
    if type(controller) ~= "table"
        or type(controller.proposeVisible) ~= "function"
        or type(controller.currentMigration) ~= "function" then
      return false, "invalid-world-events-controller"
    end
    worldEvents = controller
    return true, "bound"
  end

  local function rollLind(out, ctx, rng)
    if type(out) ~= "table" or out.kaProtected or out.kaEncounterSource
        or not (lind and type(lind.rollHabitat) == "function") then
      return out
    end
    local selected = lind.rollHabitat(
      ctx.mapId, ctx.terrain, rng, out.level, nil,
      ctx.routeAverageLevel)
    if type(selected) ~= "table" or not selected.species then return out end
    return protectedCopy(out, selected, "johto_research")
  end

  local function prepareProposal(
      logic, game, incoming, rng, forcedEncounterKind)
    local encDef, encounterKind, ctx =
      contextFor(logic, game, rng, forcedEncounterKind)
    if not encDef then return nil, nil, "unsupported-map" end

    local picker = W.encounterPick
    local pick = picker and picker.pick
    if type(pick) ~= "function" then
      return nil, nil, "encounter-pick-unavailable"
    end
    local sourceNative = pick(encDef, rng, encounterKind)
    if type(sourceNative) ~= "table" or not sourceNative.species then
      return nil, nil, "rejected: no encounter data"
    end

    -- Compact starter habitats are their own progression authority. Their
    -- Gen-I-III residents must remain authored even while the later starter
    -- family is unavailable, and no Randomizer/Johto/Mythic layer may replace
    -- them. The habitat planner itself rejects first-playthrough/inactive
    -- access and refuses a starter until every species/asset row is complete.
    if starterHabitatFor(ctx.mapId) then
      if type(mythic.cancelPending) == "function" then
        mythic.cancelPending()
      end
      local selected, habitatTransaction, habitatReason
      if runtime.habitatClaim then
        selected = sourceNative
        habitatReason = "habitat-claim-already-visible"
      else
        local wilds = starterHabitats and starterHabitats.wilds
        if not (wilds and type(wilds.plan) == "function") then
          return nil, nil, "starter-habitat-adapter-unavailable"
        end
        selected, habitatTransaction, habitatReason =
          wilds.plan(sourceNative, encDef, ctx)
      end
      if type(selected) ~= "table" or not selected.species then
        cancelHabitat(habitatTransaction,
          habitatReason or "invalid-habitat-proposal")
        return nil, nil, habitatReason or "habitat-inactive"
      end
      selected = protectedCopy(selected, nil,
        starterHabitats.SOURCE or "starter_habitat_67")

      local bundle
      if habitatTransaction then
        runtime.serial = runtime.serial + 1
        bundle = {
          serial = runtime.serial,
          sourceNative = sourceNative,
          native = sourceNative,
          output = selected,
          habitat = habitatTransaction,
          habitatReason = habitatReason,
          expectedSpecies = selected.species,
          expectedLevel = tonumber(selected.level),
          committed = false,
          cancelled = false,
        }
        runtime.habitatClaim = bundle
      end
      return selected, bundle, nil
    end

    local native = sourceNative
    if runRules and type(runRules.mapVisibleWild) == "function" then
      native = runRules.mapVisibleWild(sourceNative, ctx)
      if type(native) ~= "table" or not native.species then
        return nil, nil, "rejected: invalid Randomizer result"
      end
    end


    -- World Events are temporary postgame replacements, not Johto Signals
    -- pity and not a Legacy Journey. Resolve their pure proposal after native
    -- Randomizer mapping, then protect the exact rendered species from every
    -- later replacement layer. Merely rendering/despawning never writes save
    -- state or consumes event duration.
    local worldSelected, worldEvent
    if worldEvents and type(worldEvents.proposeVisible) == "function" then
      local ok, selectedEvent, event = pcall(
        worldEvents.proposeVisible, native, ctx, rng)
      if ok and type(selectedEvent) == "table" and selectedEvent.species then
        worldSelected = selectedEvent
        if type(event) == "table"
            and selectedEvent.kaProtected == true
            and selectedEvent.kaEncounterSource
              == "world_event:johto_migration" then
          worldEvent = event
        end
      end
    end

    -- encounter.roll can leave a proposal pending when Repel or another
    -- outer system suppresses its battle.  A visible spawn must never inherit
    -- that transaction.
    if type(mythic.cancelPending) == "function" then
      mythic.cancelPending()
    end

    runtime.serial = runtime.serial + 1
    local serial = runtime.serial

    local selected, earlyTransaction
    if worldEvent then
      selected = worldSelected
    elseif not integrationEnabled() then
      selected = native
    elseif ctx.kaProtected or ctx.kaEncounterSource then
      selected = protectedCopy(native, nil,
        ctx.kaEncounterSource or "protected_encounter")
    else
      selected, earlyTransaction = early.rollWildsReplacement(native, ctx)
    end
    if type(selected) ~= "table" or not selected.species then
      selected = native
      cancelEarly(earlyTransaction, "invalid-early-proposal")
      earlyTransaction = nil
    end

    -- A hard 256th/512th trace guarantee is a claim on the live save pity,
    -- not a property every concurrently rendered entity may duplicate.
    -- Wilds can hold several records at once, so reserve at most one hit per
    -- species until that record starts its exact battle or is despawned.
    local rareClaim
    if earlyTransaction and earlyTransaction.rareHit
        and earlyTransaction.rareSpecies then
      rareClaim = earlyTransaction.rareSpecies
      if runtime.rareClaims[rareClaim] then
        cancelEarly(earlyTransaction, "rare-claim-already-visible")
        earlyTransaction = nil
        selected = native
        rareClaim = nil
      end
    end

    if integrationEnabled() then
      selected = rollLind(selected, ctx, rng)
    end

    local mythicTransaction
    if integrationEnabled() and not worldEvent and not runtime.mythicClaim then
      local mythicSelected
      mythicSelected, mythicTransaction =
        mythic.rollReplacement(selected, encDef, ctx, game)
      if type(mythicSelected) == "table" and mythicSelected.species then
        selected = mythicSelected
      else
        cancelMythic(mythicTransaction)
        mythicTransaction = nil
      end
    end

    local randomizerTicket
    if runRules and type(runRules.rememberVisibleWild) == "function" then
      local finalCtx = copyTable(ctx)
      finalCtx.kaProtected = selected.kaProtected == true or nil
      finalCtx.kaEncounterSource = selected.kaEncounterSource
      selected, randomizerTicket =
        runRules.rememberVisibleWild(selected, finalCtx)
      if type(selected) ~= "table" or not selected.species then
        cancelEarly(earlyTransaction, "invalid-randomizer-ticket")
        cancelMythic(mythicTransaction)
        return nil, nil, "rejected: invalid Randomizer ticket"
      end
    end

    local bundle = {
      serial = serial,
      sourceNative = sourceNative,
      native = native,
      output = selected,
      early = earlyTransaction,
      mythic = mythicTransaction,
      worldEvent = worldEvent,
      expectedSpecies = selected.species,
      expectedLevel = tonumber(selected.level),
      committed = false,
      cancelled = false,
      rareClaim = rareClaim,
      randomizerTicket = randomizerTicket,
    }
    if rareClaim then runtime.rareClaims[rareClaim] = bundle end
    if mythicTransaction then runtime.mythicClaim = bundle end
    return selected, bundle, nil
  end

  local function attachBundle(record, entity, selected, bundle)
    if type(record) ~= "table" then return false end
    if record.species ~= selected.species
        or tonumber(record.level) ~= tonumber(selected.level) then
      cancelBundle(bundle, "spawn-result-mismatch")
      return false
    end
    if bundle and (bundle.early or bundle.mythic or bundle.habitat
        or bundle.worldEvent
        or bundle.randomizerTicket) then
      record._kaSignalsWilds = bundle
    end
    record.kaProtected = selected.kaProtected == true or nil
    record.kaEncounterSource = selected.kaEncounterSource
    record.kaMythicKind = selected.kaMythicKind
    if type(entity) == "table" then
      entity.kaEncounterSource = selected.kaEncounterSource
      entity.kaMythicKind = selected.kaMythicKind
    end
    return true
  end

  local function battleMon(ev)
    local battle = ev and ev.battle
    local mon = battle and battle.enemy and battle.enemy.mon
    return battle, mon
  end

  local function commitPending(ev)
    local pending = runtime.pendingBattle
    runtime.pendingBattle = nil
    if not pending then return false, "none" end

    -- This handler runs before Mythic Signals' generic priority-500 handler.
    -- Clear an encounter.roll proposal only when this really is one of our
    -- visible-Wilds battles. Doing it for every ordinary battle erased the
    -- exact S16 echo ticket before Mythic Signals could apply noCatch.
    if type(mythic.cancelPending) == "function" then
      mythic.cancelPending()
    end

    local battle, mon = battleMon(ev)
    local kind = battle and battle.kind or ev and ev.kind
    if kind ~= "wild" or not mon
        or mon.species ~= pending.expectedSpecies
        or tonumber(mon.level) ~= tonumber(pending.expectedLevel) then
      cancelBundle(pending.bundle, "battle-start-mismatch")
      return false, "mismatch"
    end

    local bundle = pending.bundle
    local earlyCommitted, earlyReason
    if bundle.early and type(early.commitWildsSpawn) == "function" then
      earlyCommitted, earlyReason = early.commitWildsSpawn(bundle.early, {
        species = mon.species,
        level = mon.level,
        battle = battle,
      })
    end

    local mythicCommitted, ticket, mythicKind
    if bundle.mythic and type(mythic.commitWildsSpawn) == "function" then
      mythicCommitted, ticket, mythicKind =
        mythic.commitWildsSpawn(bundle.mythic, mon.species, mon.level)
      if mythicCommitted and ticket
          and type(mythic.applyBattleTicket) == "function" then
        mythic.applyBattleTicket(battle, ticket)
      end
    end

    local habitatCommitted, habitatResult
    if bundle.habitat then
      local habitatWilds = starterHabitats and starterHabitats.wilds
      local activeWorld = overworldFor(W.logic)
      local habitatMapId = ev and ev.mapId
        or activeWorld and activeWorld.map and activeWorld.map.id
      if habitatMapId ~= bundle.habitat.mapId then
        habitatResult = "habitat-map-mismatch"
      elseif habitatWilds
          and type(habitatWilds.commitStarted) == "function" then
        habitatCommitted, habitatResult = habitatWilds.commitStarted(
          bundle.habitat, {
            battle = battle,
            kind = kind,
            mapId = habitatMapId,
          })
      end
      if habitatCommitted ~= true then
        local reason = type(habitatResult) == "string"
          and habitatResult or "habitat-commit-rejected"
        cancelBundle(bundle, reason)
        W.lastCommit = {
          serial = bundle.serial,
          species = mon.species,
          level = mon.level,
          habitat = false,
          habitatReason = reason,
        }
        return false, reason
      end
    end

    bundle.committed = true
    if bundle.rareClaim
        and runtime.rareClaims[bundle.rareClaim] == bundle then
      runtime.rareClaims[bundle.rareClaim] = nil
    end
    if runtime.mythicClaim == bundle then
      runtime.mythicClaim = nil
    end
    if runtime.habitatClaim == bundle then
      runtime.habitatClaim = nil
    end
    W.lastCommit = {
      serial = bundle.serial,
      species = mon.species,
      level = mon.level,
      early = earlyCommitted == true,
      earlyReason = earlyReason,
      mythic = mythicCommitted == true,
      mythicKind = mythicKind,
      ticket = ticket,
      habitat = habitatCommitted == true,
      habitatResult = habitatResult,
      worldEvent = bundle.worldEvent ~= nil,
      worldEventId = bundle.worldEvent and bundle.worldEvent.id or nil,
    }
    return true, W.lastCommit
  end

  -- These entry points deliberately receive Wilds' original methods.
  -- The engine-facing wrappers below close only over a stable marker and
  -- resolve marker.api for every call. A dev hot reload can therefore bind a
  -- fresh adapter/runtime without nesting wrappers or leaving battle.started
  -- attached to transactions owned by the previous chunk.
  function W.dispatchTrySpawn(originalTrySpawn, logic, spawnGame, spawnOpts)
    local incoming = spawnOpts or {}
    local activeGame = spawnGame or W.game
    local skipped = skipSignals(activeGame, incoming)
    if skipped then
      if type(mythic.cancelPending) == "function" then
        mythic.cancelPending()
      end
      return originalTrySpawn(logic, spawnGame, incoming)
    end

    local rng = randomSource()
    local selected, bundle, prepareErr =
      prepareProposal(logic, activeGame, incoming, rng)
    if not selected then
      if prepareErr == "unsupported-map" then
        return originalTrySpawn(logic, spawnGame, incoming)
      end
      return nil, prepareErr
    end

    local augmented = copyTable(incoming)
    augmented.species = selected.species
    augmented.level = selected.level
    if logic.render
        and type(logic.render.invalidateAssetCache) == "function"
        and selected.species then
      pcall(logic.render.invalidateAssetCache,
        logic.render, selected.species)
    end

    local ok, record, spawnErr, entity =
      pcall(originalTrySpawn, logic, spawnGame, augmented)
    if not ok then
      cancelBundle(bundle, "spawn-error")
      error(record, 0)
    end
    if not record then
      cancelBundle(bundle, "spawn-rejected")
      return nil, spawnErr, entity
    end
    attachBundle(record, entity, selected, bundle)
    return record, spawnErr, entity
  end

  function W.dispatchTrySpawnWater(
      originalTrySpawnWater, logic, spawnGame, spawnOpts)
    local incoming = spawnOpts or {}
    local activeGame = spawnGame or W.game
    local skipped = skipSignals(activeGame, incoming)
    if skipped then
      if type(mythic.cancelPending) == "function" then
        mythic.cancelPending()
      end
      return originalTrySpawnWater(logic, spawnGame, incoming)
    end

    local rng = randomSource()
    local selected, bundle, prepareErr =
      prepareProposal(logic, activeGame, incoming, rng, "water")
    if not selected then
      if prepareErr == "unsupported-map" then
        return originalTrySpawnWater(logic, spawnGame, incoming)
      end
      return nil, prepareErr
    end

    local augmented = copyTable(incoming)
    augmented.species = selected.species
    augmented.level = selected.level
    -- wilds_compat recognizes this private marker and accepts any complete,
    -- live game.data species rather than limiting the synchronous water path
    -- to its older Gen-II compatibility table.
    augmented._kaSignalsWaterOverride = true
    if logic.render
        and type(logic.render.invalidateAssetCache) == "function"
        and selected.species then
      pcall(logic.render.invalidateAssetCache,
        logic.render, selected.species)
    end

    -- Newer Wilds releases choose surf bodies through water_spawn instead of
    -- honoring trySpawnWater options. Hold its picker only for this synchronous
    -- call and restore it even when the original throws. This also makes the
    -- adapter work without wilds_compat's optional water bridge.
    local waterSpawn = W.waterSpawn
    local originalPick = waterSpawn and waterSpawn.pickForZone
    if type(originalPick) == "function" then
      waterSpawn.pickForZone = function(_, zone)
        return {
          species = selected.species,
          speciesId = selected.species,
          level = selected.level,
          levelMin = selected.level,
          levelMax = selected.level,
          source = starterHabitats and starterHabitats.SOURCE
            or selected.kaEncounterSource or "ascendant_signals",
          rodTier = waterSpawn.ROD_TIER
            and waterSpawn.ROD_TIER.SURF or 0,
          zone = zone,
          spawnRule = "ANY_WEIGHTED",
          encounterSource = "ASCENDANT_SIGNALS",
        }
      end
    end
    local ok, record, spawnErr, entity =
      pcall(originalTrySpawnWater, logic, spawnGame, augmented)
    if type(originalPick) == "function" then
      waterSpawn.pickForZone = originalPick
    end
    if not ok then
      cancelBundle(bundle, "water-spawn-error")
      error(record, 0)
    end
    if not record then
      cancelBundle(bundle, "water-spawn-rejected")
      return nil, spawnErr, entity
    end
    attachBundle(record, entity, selected, bundle)
    return record, spawnErr, entity
  end

  function W.dispatchDespawn(originalDespawn, logic, id, removeEntity, ...)
    local record = logic.spawns and logic.spawns[id]
    if record and record._kaSignalsWilds
        and not record._kaSignalsStarting then
      cancelBundle(record._kaSignalsWilds, "visible-despawn")
      record._kaSignalsWilds = nil
    end
    return originalDespawn(logic, id, removeEntity, ...)
  end

  function W.dispatchStartBattle(originalStartBattle, logic, record, ...)
    local bundle = record and record._kaSignalsWilds
    if record then record._kaSignalsStarting = true end
    local ok, started = pcall(originalStartBattle, logic, record, ...)
    if record then record._kaSignalsStarting = nil end
    if not ok then
      if not (record and logic.spawns
          and logic.spawns[record.id] == record) then
        cancelBundle(bundle, "battle-start-error")
      end
      error(started, 0)
    end
    if not started then
      -- A busy runner leaves the visible entity intact for a later retry.
      -- A queue failure removes it; only that terminal failure cancels.
      if not (record and logic.spawns
          and logic.spawns[record.id] == record) then
        cancelBundle(bundle, "battle-start-rejected")
      end
      return started
    end

    if runtime.pendingBattle then
      cancelPending("superseded-visible-battle")
    end
    if bundle and (bundle.early or bundle.mythic or bundle.habitat
        or bundle.worldEvent
        or bundle.randomizerTicket) then
      runtime.pendingBattle = {
        bundle = bundle,
        expectedSpecies = record.species,
        expectedLevel = tonumber(record.level),
      }
    end
    return started
  end

  function W.deactivate(reason)
    reason = reason or "adapter-deactivated"
    cancelPending(reason)

    local claimed = {}
    if runtime.mythicClaim then
      claimed[#claimed + 1] = runtime.mythicClaim
    end
    if runtime.habitatClaim then
      claimed[#claimed + 1] = runtime.habitatClaim
    end
    for _, bundle in pairs(runtime.rareClaims) do
      claimed[#claimed + 1] = bundle
    end
    for _, bundle in ipairs(claimed) do
      cancelBundle(bundle, reason)
    end

    if W.logic and type(W.logic.spawns) == "table" then
      for _, record in pairs(W.logic.spawns) do
        if type(record) == "table" and record._kaSignalsWilds then
          cancelBundle(record._kaSignalsWilds, reason)
          record._kaSignalsWilds = nil
          record._kaSignalsStarting = nil
        end
      end
    end

    runtime.rareClaims = {}
    runtime.mythicClaim = nil
    runtime.habitatClaim = nil
    if type(mythic.cancelPending) == "function" then
      mythic.cancelPending()
    end
    W.installed = false
    return true
  end

  function W.install(game, deps)
    deps = deps or {}
    W.game = game or W.game
    runtime.random = deps.random or runtime.random
    cancelPending("install")
    if type(mythic.cancelPending) == "function" then
      mythic.cancelPending()
    end

    local wilds = wildsExport(W.game, deps)
    local logic = type(wilds) == "table" and wilds.logic or nil
    local library = type(wilds) == "table" and wilds.lib or nil
    if type(logic) ~= "table"
        or type(logic.trySpawn) ~= "function"
        or type(logic._startBattle) ~= "function"
        or type(logic._despawn) ~= "function"
        or type(logic._encDef) ~= "function"
        or type(library) ~= "table"
        or type(library.require) ~= "function" then
      W.installed = false
      return false, "Compatible Wilds of Kanto API is not active"
    end

    local okPick, encounterPick =
      pcall(library.require, "encounter_pick")
    if not okPick or type(encounterPick) ~= "table"
        or type(encounterPick.pick) ~= "function" then
      W.installed = false
      return false, "Wilds encounter_pick export is unavailable"
    end

    W.logic = logic
    W.encounterPick = encounterPick
    local okWater, waterSpawn = pcall(library.require, "water_spawn")
    W.waterSpawn = okWater and type(waterSpawn) == "table"
      and type(waterSpawn.pickForZone) == "function" and waterSpawn or nil
    W.wildsVersion = wilds.version

    local marker = logic._kantoAscendantSignalsWildsAdapter
    local alreadyBound = marker and marker.api == W
    local rebound = marker and marker.api ~= W
    if not marker then
      marker = {
        api = W,
        version = "6.0.2",
        originalTrySpawn = logic.trySpawn,
        originalTrySpawnWater = type(logic.trySpawnWater) == "function"
          and logic.trySpawnWater or nil,
        originalStartBattle = logic._startBattle,
        originalDespawn = logic._despawn,
      }
      logic._kantoAscendantSignalsWildsAdapter = marker
    elseif rebound then
      local previous = marker.api
      if previous and type(previous.deactivate) == "function" then
        pcall(previous.deactivate, "hot-reload")
      elseif previous and type(previous.cancelPending) == "function" then
        pcall(previous.cancelPending, "hot-reload")
      end
      -- Legacy 6.0 development wrappers did not expose their visible-claim
      -- canceller. Clearing those runtime-only bundles is still safe: no save
      -- delta was committed while the entity was merely rendered.
      for _, record in pairs(logic.spawns or {}) do
        if type(record) == "table" then
          record._kaSignalsWilds = nil
          record._kaSignalsStarting = nil
        end
      end
      marker.api = W
      marker.version = "6.0.2"
    end

    if marker.originalTrySpawnWater == nil
        and type(logic.trySpawnWater) == "function"
        and (marker.dispatchVersion or 0) < 2 then
      marker.originalTrySpawnWater = logic.trySpawnWater
    end

    -- dispatchVersion also upgrades an already-live pre-fix development
    -- wrapper by rebuilding it from the originals stored in its marker.
    if marker.dispatchVersion ~= 2 then
      logic.trySpawn = function(...)
        local api = marker.api
        if api and type(api.dispatchTrySpawn) == "function" then
          return api.dispatchTrySpawn(marker.originalTrySpawn, ...)
        end
        return marker.originalTrySpawn(...)
      end
      if type(marker.originalTrySpawnWater) == "function" then
        logic.trySpawnWater = function(...)
          local api = marker.api
          if api and type(api.dispatchTrySpawnWater) == "function" then
            return api.dispatchTrySpawnWater(
              marker.originalTrySpawnWater, ...)
          end
          return marker.originalTrySpawnWater(...)
        end
      end
      logic._despawn = function(...)
        local api = marker.api
        if api and type(api.dispatchDespawn) == "function" then
          return api.dispatchDespawn(marker.originalDespawn, ...)
        end
        return marker.originalDespawn(...)
      end
      logic._startBattle = function(...)
        local api = marker.api
        if api and type(api.dispatchStartBattle) == "function" then
          return api.dispatchStartBattle(marker.originalStartBattle, ...)
        end
        return marker.originalStartBattle(...)
      end
      marker.dispatchVersion = 2
    end

    W.installed = true
    W.waterWrapped = type(marker.originalTrySpawnWater) == "function"
    W.sharedAdapter = marker
    if runtime.installs == 0 then
      runtime.installs = 1
    end
    if mod.log and type(mod.log.info) == "function" then
      mod.log:info(
        "Johto Signals: Wilds of Kanto %s transactional adapter active",
        tostring(W.wildsVersion or "unknown"))
    end
    return true, rebound and "rebound"
      or (alreadyBound and "already installed" or nil)
  end

  local function resetSlotClaims(reason)
    cancelPending(reason)
    if runtime.mythicClaim then
      cancelBundle(runtime.mythicClaim, reason)
    end
    if runtime.habitatClaim then
      cancelBundle(runtime.habitatClaim, reason)
    end
    local claimed = {}
    for _, bundle in pairs(runtime.rareClaims) do
      claimed[#claimed + 1] = bundle
    end
    for _, bundle in ipairs(claimed) do
      cancelBundle(bundle, reason)
    end
    if type(mythic.cancelPending) == "function" then
      mythic.cancelPending()
    end
  end

  if mod.events and type(mod.events.on) == "function" then
    mod.events:on("battle.started", commitPending, W.EVENT_PRIORITY)
    mod.events:on("save.created", function()
      resetSlotClaims("save-created")
    end, W.EVENT_PRIORITY)
    mod.events:on("save.loaded", function()
      resetSlotClaims("save-loaded")
    end, W.EVENT_PRIORITY)
    mod.events:on("battle.ended", function()
      cancelPending("battle-ended-without-start")
    end, W.EVENT_PRIORITY)
  end

  W.cancelPending = cancelPending
  W.commitPending = commitPending
  W.terrainForSurface = terrainForSurface
  W.skipSignals = skipSignals
  W.runtimeStatus = function()
    local claims = {}
    for species in pairs(runtime.rareClaims) do
      claims[#claims + 1] = species
    end
    table.sort(claims)
    return {
      installed = W.installed,
      enabled = integrationEnabled(),
      starterHabitatsBound = starterHabitats ~= nil,
      worldEventsBound = worldEvents ~= nil,
      wildsVersion = W.wildsVersion,
      waterWrapped = W.waterWrapped,
      serial = runtime.serial,
      installs = runtime.installs,
      rareClaims = claims,
      mythicClaim = runtime.mythicClaim and {
        serial = runtime.mythicClaim.serial,
        species = runtime.mythicClaim.expectedSpecies,
        level = runtime.mythicClaim.expectedLevel,
      } or nil,
      habitatClaim = runtime.habitatClaim and {
        serial = runtime.habitatClaim.serial,
        species = runtime.habitatClaim.expectedSpecies,
        level = runtime.habitatClaim.expectedLevel,
        mapId = runtime.habitatClaim.habitat
          and runtime.habitatClaim.habitat.mapId,
      } or nil,
      pendingBattle = runtime.pendingBattle and {
        species = runtime.pendingBattle.expectedSpecies,
        level = runtime.pendingBattle.expectedLevel,
        serial = runtime.pendingBattle.bundle
          and runtime.pendingBattle.bundle.serial,
      } or nil,
    }
  end

  return W
end
