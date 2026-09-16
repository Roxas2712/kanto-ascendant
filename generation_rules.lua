-- KASC 6.7 selectable battle-generation controller.
--
-- This is the single authority for selectedMode, unlockedEpoch, activeEpoch
-- and immutable battle receipts.  Content progress is monotonic; an active
-- profile may safely be lower.  Unsupported exact generations never become
-- active merely because their species or artwork exists.

return function(mod, opts)
  opts = opts or {}
  local evidence = assert(opts.evidence, "generation evidence missing")
  local migration = assert(opts.migration, "generation migration missing")
  local memory = assert(opts.moveMemory, "generation move memory missing")
  local projection = assert(opts.typeProjection, "generation type projection missing")
  local receipts = assert(opts.receipts, "generation receipt service missing")
  local moveCatalog = opts.moveCatalog

  local G = {
    CARD_ID = "KASC-67-BATTLE-GENERATION-PROFILES",
    OWNER = "kasc.rules.battle-generation-profiles/v1",
    OPTION_KEY = "battle_generation_mode",
    SAVE_KEY = migration.SAVE_KEY,
    MODE_AUTO = "auto",
    MODE_OFF = "off",
    MODE_GEN1 = "gen1", MODE_GEN2 = "gen2", MODE_GEN3 = "gen3",
    MODE_GEN4 = "gen4", MODE_GEN5 = "gen5", MODE_GEN6 = "gen6",
    MODE_GEN7 = "gen7",
  }

  local profiles = {
    auto = { auto = true, versionGroup = "automatic" },
    off = { epoch = 1, projection = "native-rby-only",
      versionGroup = "running-rby-rom", strictQuirks = true },
    gen1 = { epoch = 1, projection = "generation-pool-1",
      versionGroup = "kasc-generation-1" },
    gen2 = { epoch = 2, projection = "generation-pool-2",
      versionGroup = "kasc-generation-2" },
    gen3 = { epoch = 3, projection = "generation-pool-3",
      versionGroup = "kasc-generation-3" },
    gen4 = { epoch = 4, projection = "generation-pool-4",
      versionGroup = "kasc-generation-4" },
    gen5 = { epoch = 5, projection = "generation-pool-5",
      versionGroup = "kasc-generation-5" },
    gen6 = { epoch = 6, projection = "generation-pool-6",
      versionGroup = "kasc-generation-6" },
    gen7 = { epoch = 7, projection = "generation-pool-7",
      versionGroup = "kasc-generation-7" },
  }

  local function cardEnabled()
    if mod.options and type(mod.options.get) == "function" then
      local ok, value = pcall(mod.options.get, mod.options, G.OPTION_KEY)
      return not ok or value ~= G.MODE_OFF
    end
    return true
  end

  if opts.supportLog and type(opts.supportLog.registerSegment) == "function" then
    opts.supportLog.registerSegment({
      segmentId = G.CARD_ID, cardId = G.CARD_ID, version = "1.0.0",
      schema = "kasc.optional-feature-card/v1", owner = G.OWNER,
      active = cardEnabled(), dependencyStatus = "local-reviewed",
      providerStatus = cardEnabled() and "runtime-loaded"
        or "native-rby-fallback",
      buildReceiptId = "docs/BATTLE_GENERATION_PROFILES_67.md",
      rollbackReceiptId = "select-battle-generation-off",
    })
  end

  local capabilities = {
    generation1 = true, generation2 = true, generation3 = true,
    generation4 = true, generation5 = true, generation6 = true,
    -- The profile/save boundary can be exercised independently, but a
    -- registered profile is not full effect support. Enable only after the
    -- Gen-VII battle owners have been integrated and tested together.
    generation7 = false,
  }
  for key, value in pairs(type(opts.capabilities) == "table"
      and opts.capabilities or {}) do capabilities[key] = value == true end

  local activeGame, installed, battleActive = nil, false, false
  local checkpointBattle
  local currentDataProvider
  local liveLearnsetProvider
  local liveMoveProvider
  local ownedGiftBattleCompatibilityProvider
  local ownedGiftMoveCompatibilityProvider
  local baselineByData = setmetatable({}, { __mode = "k" })

  local function copy(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local out = {}
    seen[value] = out
    for key, child in pairs(value) do out[copy(key, seen)] = copy(child, seen) end
    return out
  end

  local function restoreTable(target, snapshot)
    for key in pairs(target) do target[key] = nil end
    for key, value in pairs(snapshot) do target[copy(key)] = copy(value) end
    return target
  end

  local function saveOf(gameOrSave)
    if type(gameOrSave) == "table" and type(gameOrSave.save) == "table" then
      return gameOrSave.save
    end
    return type(gameOrSave) == "table" and gameOrSave
      or activeGame and activeGame.save or nil
  end

  local function supportedEpoch()
    for epoch = 7, 1, -1 do
      if capabilities["generation" .. tostring(epoch)] then return epoch end
    end
    return 1
  end

  local function available(profile, state)
    if not profile then return false, "unknown_mode" end
    if profile.auto then return true end
    if profile.epoch and capabilities["generation" .. profile.epoch] ~= true then
      return false, "capability_locked"
    end
    if profile.epoch and profile.epoch > (state.unlockedEpoch or 1) then
      return false, "content_locked"
    end
    return true
  end

  local function autoProfile(state)
    local target = math.min(state.unlockedEpoch or 1, supportedEpoch())
    return "gen" .. tostring(math.max(1, target))
  end

  local function optionMode(game, state)
    local save = saveOf(game)
    local options = migration.optionBucket(save, false)
    local selected = options and options.battle_generation_mode
    if type(selected) ~= "string" and game and game.mods
        and type(game.mods.modOptions) == "table" then
      local live = game.mods.modOptions[mod.id]
      selected = type(live) == "table" and live.battle_generation_mode or nil
    end
    local aliases = { kasc_67_current="auto", vanilla_rby="off",
      gen1_clean="gen1", gen2_compat_crystal="gen2" }
    selected = aliases[selected] or selected
    local fallback = aliases[state.selectedMode] or state.selectedMode
    return profiles[selected] and selected or fallback
  end

  local function updateEvidence(game, state)
    local report = evidence.collect(game, saveOf(game))
    if report.epoch > state.unlockedEpoch then state.unlockedEpoch = report.epoch end
    state.supportedEpoch = supportedEpoch()
    state.evidence = type(state.evidence) == "table" and state.evidence or {}
    for _, witness in ipairs(report.witnesses) do state.evidence[witness] = true end
    state.contentEvidence = type(state.contentEvidence) == "table"
      and state.contentEvidence or {}
    for key, value in pairs(type(report.content) == "table"
        and report.content or {}) do
      if value == true then state.contentEvidence[key] = true end
    end
    return report
  end

  function G.state(gameOrSave, create, fresh)
    local save = saveOf(gameOrSave)
    local state = migration.state(save, create ~= false, fresh == true)
    if state then updateEvidence(type(gameOrSave) == "table"
      and gameOrSave.save and gameOrSave or activeGame, state) end
    return state
  end

  local function resolveState(game, state, requestedOverride)
    if checkpointBattle and checkpointBattle.game==game and not checkpointBattle.result then
      local frozen=copy(checkpointBattle.kascGenerationRulesReceipt)
      frozen.extensionsEnabled=frozen.mode~=G.MODE_OFF
      frozen.requestedMode=requestedOverride or optionMode(game,state) or G.MODE_AUTO
      return frozen,state
    end
    local requested = requestedOverride or optionMode(game, state) or G.MODE_AUTO
    state.selectedMode = requested
    local mode = requested == G.MODE_AUTO and autoProfile(state) or requested
    local profile = profiles[mode]
    local ok, reason = available(profile, state)
    if not ok then mode, profile = autoProfile(state), profiles[autoProfile(state)] end

    local epoch = profile.epoch or 1
    state.activeMode, state.activeEpoch = mode, epoch
    state.lastResolution = reason or "supported"
    return {
      requestedMode = requested,
      mode = mode,
      activeEpoch = epoch,
      unlockedEpoch = state.unlockedEpoch,
      supportedEpoch = state.supportedEpoch,
      strictQuirks = profile.strictQuirks == true,
      extensionsEnabled = mode ~= G.MODE_OFF,
      versionGroup = profile.versionGroup,
      projection = profile.projection,
      capabilities = copy(capabilities),
      resolverVersions = {
        rules = 2, evidence = 2, migration = migration.MIGRATION_VERSION,
        moves = 1, types = 1,
      },
      fallbackReason = reason,
    }, state
  end

  function G.resolve(gameOrSave)
    local game = type(gameOrSave) == "table" and gameOrSave.save
      and gameOrSave or activeGame
    local state = G.state(gameOrSave, true, false)
    if not state then return nil, "save" end
    return resolveState(game,state)
  end

  -- Observations/tooltips must not migrate a save or advance evidence just
  -- by reading it. Use the same resolver on a detached migration proposal.
  function G.peek(gameOrSave)
    local game=type(gameOrSave)=='table' and gameOrSave.save and gameOrSave or activeGame
    local save=saveOf(gameOrSave)
    local state=migration.state(save,false)
    local requestedOverride
    if state then
      -- resolve() does not normalize an existing state on every read.
      state=copy(state)
    else
      local transaction,why=migration.stage(save,false)
      if not transaction then return nil,why end
      state=transaction.staged
      local options=migration.optionBucket(save,false)
      -- Mirror the option that commit() would install without touching the
      -- save. In particular first migration deliberately starts in AUTO.
      if transaction.first or not options or type(options.battle_generation_mode)~='string' then
        requestedOverride=state.selectedMode
      end
    end
    updateEvidence(game,state)
    return resolveState(game,state,requestedOverride)
  end

  function G.peekShouldUseEpoch(game,epoch,currentFallback)
    local resolved=G.peek(game)
    if not resolved then return currentFallback==true end
    return resolved.activeEpoch>=(tonumber(epoch) or 1)
  end

  local function baseline(data)
    if type(data) ~= "table" then return nil end
    local existing = baselineByData[data]
    if existing then return existing end
    existing = { pokemon = {}, moves = {} }
    for species, record in pairs(type(data.pokemon) == "table"
        and data.pokemon or {}) do
      if type(record) == "table" then
        existing.pokemon[species] = {
          types = copy(record.types), level1Moves = copy(record.level1Moves),
          learnset = copy(record.learnset), tmhm = copy(record.tmhm),
        }
      end
    end
    -- Every registered move can be projected. Keeping only the handful of
    -- historic Gen-I type changes here made a Gen-VI FAIRY move stay NORMAL
    -- after Gen VI -> OFF -> Gen VI. Snapshot the complete merged move table
    -- before the first projection so every later upshift is exact.
    for id, record in pairs(type(data.moves) == "table" and data.moves or {}) do
      if type(record) == "table" then
        existing.moves[id] = {
          typePresent = record.type ~= nil,
          type = record.type, category = record.category,
          categoryPresent = record.category ~= nil,
          powerPresent = record.power ~= nil,
          power = record.power, accuracy = record.accuracy, pp = record.pp,
          accuracyPresent = record.accuracy ~= nil,
          ppPresent = record.pp ~= nil,
          priorityOwned = record.kascFirstAction67 ~= nil,
          priorityPresent = record.priority ~= nil, priority = record.priority,
        }
      end
    end
    baselineByData[data] = existing
    return existing
  end

  local function restoreBaseline(data)
    local base = baseline(data)
    if not base then return false end
    for species, snapshot in pairs(base.pokemon) do
      local record = data.pokemon and data.pokemon[species]
      if type(record) == "table" then
        record.types = copy(snapshot.types)
        record.level1Moves = copy(snapshot.level1Moves)
        record.learnset = copy(snapshot.learnset)
        record.tmhm = copy(snapshot.tmhm)
      end
    end
    for id, values in pairs(base.moves) do
      local record = data.moves and data.moves[id]
      if type(record) == "table" then
        record.type = values.typePresent and values.type or nil
        record.category = values.categoryPresent and values.category or nil
        record.power = values.powerPresent and values.power or nil
        record.accuracy = values.accuracyPresent and values.accuracy or nil
        record.pp = values.ppPresent and values.pp or nil
        if values.priorityOwned then record.priority = values.priorityPresent and values.priority or nil end
      end
    end
    return true
  end

  function G.syncData(game, frozenProfile)
    game = type(game) == "table" and game or activeGame
    if not (game and game.data) then return false, "data" end
    baseline(game.data)
    restoreBaseline(game.data)
    local resolved = frozenProfile or G.resolve(game)
    if not resolved then return false, "resolution" end
    if type(currentDataProvider) == "function" then
      currentDataProvider(game, resolved.activeEpoch, resolved.extensionsEnabled)
    end
    for species, record in pairs(type(game.data.pokemon) == "table"
        and game.data.pokemon or {}) do
      if type(record) == "table" then
        record.types = projection.projectSpecies(species, record.types,
          resolved.activeEpoch)
        local function allowed(id)
          return G.moveAvailable(id, resolved.activeEpoch, game.data)
        end
        local level1 = {}
        for _, value in ipairs(record.level1Moves or {}) do
          local id = type(value)=="table" and (value.move or value.id) or value
          if allowed(id) then level1[#level1+1]=value end
        end
        local learnset = {}
        for _, value in ipairs(record.learnset or {}) do
          local id = type(value)=="table" and (value.move or value.id) or value
          if allowed(id) then learnset[#learnset+1]=value end
        end
        local tmhm = {}
        for _, value in ipairs(record.tmhm or {}) do
          local id = type(value)=="table" and (value.move or value.id) or value
          if allowed(id) then tmhm[#tmhm+1]=value end
        end
        record.level1Moves, record.learnset, record.tmhm = level1, learnset, tmhm
      end
    end
    for id, record in pairs(type(game.data.moves) == "table"
        and game.data.moves or {}) do
      if type(record) == "table" then
        record.type = projection.moveType(id, record.type, resolved.activeEpoch)
        record.category = projection.moveCategory(id, record.type,
          record.category, resolved.activeEpoch)
      end
    end
    if liveMoveProvider and resolved.extensionsEnabled then
      local ok,why=liveMoveProvider(game,resolved.activeEpoch)
      if ok==false then return false,why end
    end
    if liveLearnsetProvider and resolved.extensionsEnabled then
      local ok,why=liveLearnsetProvider(game,resolved.activeEpoch)
      if ok==false then return false,why end
    end
    if opts.typeMatchups then
      opts.typeMatchups.apply(game.data,resolved.extensionsEnabled and resolved.activeEpoch or 1)
    end
    -- Modern genetics belong only to explicitly bound new Day-Care eggs.
    -- Profile transitions already snapshot all owned surfaces atomically.
    -- Legacy/unbound IVs are untouched; larger maxima never heal a Pokemon.
    local genetics=mod.exports and mod.exports.daycare and mod.exports.daycare.breedingIVs
    if genetics then
      local seen={};local epoch=resolved.extensionsEnabled and resolved.activeEpoch or 1
      for _,row in ipairs(evidence.ownedSurfaces(game.save,game))do
        local mon=row.mon
        if type(mon)=='table'and not seen[mon]then
          seen[mon]=true
          local bonds=mod.exports and mod.exports.pokemonBondForms67
          local base=checkpointBattle and checkpointBattle.game==game and bonds
            and bonds.savedBase(checkpointBattle,mon)
          genetics.apply(game,mon,epoch,base)
        end
      end
    end
    return true, resolved
  end

  function G.shouldUseEpoch(game, epoch, currentFallback)
    local resolved = G.resolve(game)
    if not resolved then return currentFallback == true end
    return resolved.activeEpoch >= (tonumber(epoch) or 1)
  end

  local MOVE_EPOCH_FALLBACK = {
    CRUNCH=2, METAL_CLAW=2, FALSE_SWIPE=2, IRON_TAIL=2,
    SHADOW_BALL=2, FLAME_WHEEL=2, GIGA_DRAIN=2, CHARM=2,
    MUD_SLAP=2, SNORE=2, SUNNY_DAY=2, SYNTHESIS=2,
    RAIN_DANCE=2, WHIRLPOOL=2, SLUDGE_BOMB=2, SPARK=2,
    POWDER_SNOW=2, SACRED_FIRE=2, AEROBLAST=2, BONE_RUSH=2,
    CROSS_CHOP=2, EXTREMESPEED=2, FAINT_ATTACK=2, MACH_PUNCH=2,
    MEGAHORN=2, MILK_DRINK=2, SWEET_KISS=2, VITAL_THROW=2,
    THUNDERPUNCH=1, ROLLOUT=2, ANCIENTPOWER=2,
    LEAF_BLADE=3, DOUBLE_HIT=4,
  }

  function G.moveEpoch(id, data)
    local row = data and data.moves and data.moves[id]
    local epoch = tonumber(row and (row.originEpoch or row.originGeneration))
      or type(moveCatalog) == "table" and type(moveCatalog.byId) == "table"
        and moveCatalog.byId[id] and moveCatalog.byId[id].generation
      or MOVE_EPOCH_FALLBACK[id]
    return math.max(1, math.min(9, math.floor(epoch or 1)))
  end

  function G.moveAvailable(id, epoch, data)
    if type(id) ~= "string" then return false end
    if not (data and data.moves and data.moves[id]) then return false end
    return G.moveEpoch(id, data) <= math.max(1, tonumber(epoch) or 1)
  end

  -- Later gifts keep their own legal learning era across AUTO/manual changes.
  -- No global move/species unlock: validate ownership, archive receipt and
  -- the precise identity's learning source before allowing the exception.
  function G.monMoveAvailable(game,mon,id,epoch,extensionsEnabled)
    if G.moveAvailable(id,epoch,game and game.data) then return true end
    if extensionsEnabled==false then return false end
    if type(ownedGiftMoveCompatibilityProvider)=='function'
        and G.ownedGiftBattleCompatible(game,mon,game and game.data and game.data.pokemon
          and game.data.pokemon[type(mon)=='table'and mon.species])then
      local ok,allowed=pcall(ownedGiftMoveCompatibilityProvider,game,mon,id,epoch)
      if ok and allowed==true then return true end
    end
    -- Borrowing exists only inside this owner's genuine synchronous
    -- native child. Ordinary tutor/party/save reads gain no permission.
    local called=mod.exports and mod.exports.pokemonCalledMoves67
    if called and called.permission(game,mon,id,epoch,extensionsEnabled)==true then return true end
    local redirect=mod.exports and mod.exports.pokemonMoveRedirection67
    return redirect and redirect.permission(game,mon,id,epoch,extensionsEnabled)==true or false
  end

  function G.speciesEpoch(species, record)
    return evidence.speciesEpoch(species, record) or 1
  end

  local function speciesInProfile(resolved, species, record)
    if not resolved or not resolved.extensionsEnabled then
      return G.speciesEpoch(species, record) == 1
    end
    if G.speciesEpoch(species, record) > resolved.activeEpoch then return false end
    local original = type(record)=="table" and record.types or {}
    if #original > 0 then
      local any = false
      for _, typeId in ipairs(original) do
        if projection.typeAvailable(typeId, resolved.activeEpoch) then any=true break end
      end
      if not any then return false end
    end
    return true
  end

  function G.speciesAvailable(game,species,record)
    return speciesInProfile(G.resolve(game),species,record)
  end

  function G.peekSpeciesAvailable(game,species,record)
    return speciesInProfile(G.peek(game),species,record)
  end

  function G.monAvailable(game, mon)
    if type(mon)=='table' and (mon.isEgg or mon.egg or mon.eggSpecies
        or mon.species=='EGG') then return false end
    local species = type(mon)=="table" and (mon.species or mon.eggSpecies) or mon
    local record = game and game.data and game.data.pokemon
      and game.data.pokemon[species]
    if G.ownedGiftBattleCompatible(game, mon, record) then return true end
    return G.speciesAvailable(game, species, record)
  end

  -- Owned event gifts are an explicit per-Pokemon exception, never a species
  -- availability exception.  The event archive validates its durable receipt;
  -- encounter, AI and prize builders continue to call speciesAvailable and
  -- therefore cannot leak a later species into their candidate pools.
  function G.ownedGiftBattleCompatible(game, mon, record)
    if type(mon) ~= "table"
        or type(ownedGiftBattleCompatibilityProvider) ~= "function" then
      return false, "not_event_gift"
    end
    local ok, compatible, reason = pcall(
      ownedGiftBattleCompatibilityProvider, game, mon, record)
    if not ok then return false, "provider_error" end
    if compatible ~= true then return false, reason end
    local liveGame = type(game) == "table" and game.save and game or activeGame
    local save = saveOf(liveGame or game)
    if type(save) ~= "table" then return false, "not_owned" end
    for _, surface in ipairs(evidence.ownedSurfaces(save, liveGame)) do
      if surface.mon == mon then return true, reason end
    end
    return false, "not_owned"
  end

  function G.filterSpecies(game, values, resolver)
    local out = {}
    for _, value in ipairs(type(values)=="table" and values or {}) do
      local species = type(resolver)=="function" and resolver(value)
        or type(value)=="table" and value.species or value
      local record = game and game.data and game.data.pokemon
        and game.data.pokemon[species]
      if G.speciesAvailable(game, species, record) then out[#out+1]=value end
    end
    return out
  end

  function G.safeBoundary(game)
    if battleActive or game and (game.battle or game.tradeSession
        or game.evolutionSession or game.storageTransaction) then
      return false, "transaction_active"
    end
    if game and (game.linkSession or type(game.linkNet) == "table"
        and game.linkNet.closed ~= true) then return false, "link_active" end
    if type(opts.safeBoundary) == "function" then return opts.safeBoundary(game) end
    return true
  end

  local function moveId(value)
    return type(value) == "table" and (value.move or value.id) or value
  end

  local function replacementMove(game, mon, epoch, replacedIndex)
    local species = type(mon) == "table" and (mon.species or mon.eggSpecies)
    local def = game and game.data and game.data.pokemon
      and game.data.pokemon[species]
    if type(def) ~= "table" then return nil end
    local used = {}
    for index, value in ipairs(type(mon.moves) == "table" and mon.moves or {}) do
      if index ~= replacedIndex then used[moveId(value)] = true end
    end
    local candidates = {}
    local function add(value, level)
      local id = moveId(value)
      if type(id) == "string" and not used[id]
          and (level == nil or level <= (tonumber(mon.level) or 1))
          and G.monMoveAvailable(game, mon, id, epoch,
            G.resolve(game).extensionsEnabled) then
        candidates[#candidates + 1] = id
      end
    end
    for _, value in ipairs(def.level1Moves or {}) do add(value) end
    for _, value in ipairs(def.learnset or {}) do
      add(value, type(value) == "table" and tonumber(value.level) or nil)
    end
    -- Prefer the most recent level-legal source while retaining deterministic
    -- source order. Repeated replacements cannot duplicate an active move.
    return candidates[#candidates]
  end

  function G.switchMode(game, requested)
    game = type(game) == "table" and game or activeGame
    if not profiles[requested] then return false, "unknown_mode" end
    local state = G.state(game, true, false)
    local candidate = requested == G.MODE_AUTO and autoProfile(state) or requested
    local ok, why = available(profiles[candidate], state)
    if not ok then return false, why end
    local safe, boundaryWhy = G.safeBoundary(game)
    if not safe then
      state.pendingMode = requested
      return false, boundaryWhy
    end

    local before = copy(state)
    local beforeOption = migration.optionBucket(game.save, true)
      .battle_generation_mode
    local ownedBefore, ownedSeen = {}, {}
    -- A profile switch is a save transaction.  Preserve every live owned
    -- Pokémon before touching its moveset memory so a later resolver or data
    -- failure cannot leave only the first half of Party/Boxes/Day-Care moved.
    for _, row in ipairs(evidence.ownedSurfaces(game.save, game)) do
      local mon = row.mon
      if type(mon) == "table" and not ownedSeen[mon] then
        ownedSeen[mon] = true
        ownedBefore[#ownedBefore + 1] = { mon = mon, snapshot = copy(mon) }
      end
    end
    local oldResolved = G.resolve(game)
    local success, err = pcall(function()
      migration.syncOption(game.save, requested)
      local nextResolved = G.resolve(game)
      memory.walkOwned(evidence, game.save, function(mon)
        local moved, moveWhy = memory.transitionMon(mon,
          oldResolved.mode, nextResolved.mode, game.data, {
            moveLegal = function(target, id)
              return G.monMoveAvailable(game, target, id, nextResolved.activeEpoch,
                nextResolved.extensionsEnabled)
            end,
            replacement = function(target, _, index)
              return replacementMove(game, target,
                nextResolved.activeEpoch, index)
            end,
            requireMove = function(target)
              return G.monAvailable(game, target)
            end,
          })
        assert(moved, moveWhy)
      end, game)
      state.switchRevision = (state.switchRevision or 0) + 1
      state.pendingMode = nil
      assert(G.syncData(game))
    end)
    if not success then
      for _, row in ipairs(ownedBefore) do
        restoreTable(row.mon, row.snapshot)
      end
      migration.bucket(game.save, true)[G.SAVE_KEY] = before
      migration.optionBucket(game.save, true).battle_generation_mode = beforeOption
      G.syncData(game)
      return false, tostring(err)
    end
    return true, G.resolve(game)
  end

  function G.rulesReceipt(game)
    return receipts.create(assert(G.resolve(game)))
  end

  function G.attachBattle(battle, game)
    return receipts.attachBattle(battle, assert(G.resolve(game or activeGame)))
  end

  function G.resumeBattle(battle)
    local receipt,why=receipts.restoreBattle(battle)
    if not receipt and why=='legacy_checkpoint_without_receipt' then
      receipt=G.attachBattle(battle,battle.game)
    end
    if receipt then
      if capabilities["generation" .. tostring(receipt.activeEpoch)] ~= true then
        return nil, 'unsupported_checkpoint_generation'
      end
      local profile=copy(receipt);profile.extensionsEnabled=profile.mode~=G.MODE_OFF
      checkpointBattle=battle
      local ok,synced,problem=pcall(G.syncData,battle.game,profile)
      if not ok or not synced then
        checkpointBattle=nil
        pcall(G.syncData,battle.game)
        return nil,ok and problem or synced
      end
      battleActive=true
    end
    return receipt,why
  end

  function G.setCurrentDataProvider(provider)
    assert(type(provider) == "function", "current generation data provider missing")
    currentDataProvider = provider
    return true
  end

  function G.setLiveLearnsetProvider(provider)
    assert(type(provider)=='function','live learnset provider missing')
    liveLearnsetProvider=provider
  end
  function G.setLiveMoveProvider(provider)
    assert(type(provider)=='function','live move provider must be a function')
    liveMoveProvider=provider
  end

  function G.setOwnedGiftBattleCompatibilityProvider(provider)
    assert(type(provider) == "function",
      "owned Gift-Code/event compatibility provider missing")
    ownedGiftBattleCompatibilityProvider = provider
    return true
  end

  function G.setOwnedGiftMoveCompatibilityProvider(provider)
    assert(type(provider)=='function','owned gift move compatibility provider missing')
    ownedGiftMoveCompatibilityProvider=provider
  end

  function G.setCapability(key, enabled)
    if capabilities[key] == nil then return false, "unknown_capability" end
    capabilities[key] = enabled == true
    if activeGame then G.syncData(activeGame) end
    return true
  end

  function G.install(game)
    activeGame = game or activeGame
    if activeGame and activeGame.data then
      -- Capture the merged registry before any generation provider projects
      -- later data into it. Otherwise the first active profile accidentally
      -- becomes the rollback baseline and a later downgrade cannot be exact.
      baseline(activeGame.data)
    end
    if installed then return G.syncData(activeGame) end
    installed = true
    G.syncData(activeGame)
    return true
  end

  if mod.events and type(mod.events.on) == "function" then
    mod.events:on("save.loading", function(ev)
      migration.apply(ev and ev.raw, false)
    end, 9200)
    mod.events:on("save.created", function(ev)
      local game, save = ev and ev.game, ev and ev.save
      migration.apply(save or game and game.save, true)
      if game then G.syncData(game) end
    end, 9200)
    mod.events:on("save.loaded", function(ev)
      local game, save = ev and ev.game or activeGame, ev and ev.save
      migration.apply(save or game and game.save, false)
      if game then G.syncData(game) end
    end, -9200)
    mod.events:on("game.ready", function(ev)
      local game = ev and ev.game or activeGame
      if game then G.install(game) end
    end, -9200)
    mod.events:on("battle.started", function(ev)
      battleActive = true
      local battle = ev and (ev.battle or ev.state)
      if type(battle) == "table" then
        G.attachBattle(battle, ev and ev.game or activeGame)
      end
    end, 9900)
    mod.events:on("battle.ended", function(ev)
      local resumed=checkpointBattle and (not ev or not ev.battle or ev.battle==checkpointBattle)
        and checkpointBattle
      if resumed then checkpointBattle=nil end
      battleActive = false
      local state = G.state(activeGame, false)
      if state and state.pendingMode then G.switchMode(activeGame, state.pendingMode) end
      if resumed then G.syncData(resumed.game) end
    end, -9900)
  end

  G.profiles = profiles
  G.capabilities = capabilities
  G.supportedEpoch = supportedEpoch
  G.copy = copy
  G.receipts = receipts
  G.evidence = evidence
  G.migration = migration
  G.moveMemory = memory
  G.typeProjection = projection
  return G
end
