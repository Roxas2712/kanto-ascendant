-- Save-local, irreversible Beyond-Kanto boundary.
--
-- Extended species stay registered globally so old saves and the Legacy archive
-- remain readable.  A fresh save nevertheless plays with the exact Gen-I
-- Magnemite/Move records until the player explicitly authorizes Johto.  The
-- six live data overlays are restored before every slot transition so a
-- process that visits an unleashed slot can never leak those rules into a
-- different save.

return function(mod, opts)
  opts = opts or {}
  local i18n = opts.i18n
  local johto = opts.johtoData or {}
  local B = {
    SAVE_KEY = "beyond_kanto",
    SCHEMA_VERSION = 1,
    LEGACY_WILDS_VERSION = 1,
    game = nil,
  }

  local listeners = {}
  local controllers = {}
  local DATA_MARKER = "_kantoAscendantBeyondKantoBaseline"
  local SPECIES_OVERLAY = {
    MAGNEMITE = { "ELECTRIC", "STEEL" },
    MAGNETON = { "ELECTRIC", "STEEL" },
  }
  local MOVE_OVERLAY = {
    BITE = { type = "DARK", category = "special" },
    GUST = { type = "FLYING", category = "physical" },
    SAND_ATTACK = { type = "GROUND", category = "status" },
    KARATE_CHOP = { type = "FIGHTING", category = "physical" },
  }

  local function tr(en, de)
    return i18n and i18n.text(en, de) or en
  end

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

  local function saveOf(value)
    if type(value) == "table" and type(value.save) == "table" then
      return value.save
    end
    if type(value) == "table" then return value end
    return B.game and B.game.save or nil
  end

  local function bucket(save, create)
    save = saveOf(save)
    if type(save) ~= "table" then return nil end
    if type(save.modData) ~= "table" then
      if not create then return nil end
      save.modData = {}
    end
    local value = save.modData[mod.id]
    if type(value) ~= "table" then
      if not create then return nil end
      value = {}
      save.modData[mod.id] = value
    end
    return value
  end

  local function rawState(save)
    local owner = bucket(save, false)
    local state = owner and owner[B.SAVE_KEY]
    return type(state) == "table" and state or nil
  end

  local function setState(save, state)
    bucket(save, true)[B.SAVE_KEY] = state
    return state
  end

  local function anyTrue(values)
    for _, value in pairs(type(values) == "table" and values or {}) do
      if value == true or type(value) == "number" and value > 0 then
        return true
      end
    end
    return false
  end

  local function anyRows(values)
    return type(values) == "table" and next(values) ~= nil
  end

  local function speciesDex(game, species)
    local def = game and game.data and game.data.pokemon
      and game.data.pokemon[species]
      or johto.species and johto.species[species]
    local dex = def and tonumber(def.dex)
    return dex and math.floor(dex) or nil
  end

  local function isBeyondKanto(game, species)
    local dex = speciesDex(game, species)
    return dex and dex > 151 or false
  end

  local function monWitness(game, save)
    local function scan(list, label)
      for _, mon in ipairs(type(list) == "table" and list or {}) do
        local species = type(mon) == "table"
          and (mon.eggSpecies or mon.species) or nil
        if isBeyondKanto(game, species) then
          return label .. ":" .. tostring(species)
        end
      end
    end
    local found = scan(save.party, "party") or scan(save.box, "legacy_box")
    if found then return found end
    for index, box in ipairs(type(save.boxes) == "table" and save.boxes or {}) do
      found = scan(box, "box" .. tostring(index))
      if found then return found end
    end
    local vanilla = type(save.daycare) == "table" and save.daycare or nil
    if vanilla and type(vanilla.mon) == "table"
        and isBeyondKanto(game, vanilla.mon.species) then
      return "daycare:" .. tostring(vanilla.mon.species)
    end
    local owner = bucket(save, false)
    local daycare = owner and owner.daycare_plus
    for index, row in ipairs(type(daycare) == "table"
        and type(daycare.parents) == "table" and daycare.parents or {}) do
      local mon = type(row) == "table" and (row.mon or row) or nil
      if type(mon) == "table" and isBeyondKanto(game, mon.species) then
        return "daycare_parent" .. tostring(index) .. ":" .. mon.species
      end
    end
    for _, row in ipairs(type(daycare) == "table"
        and type(daycare.reservedEggs) == "table" and daycare.reservedEggs or {}) do
      if type(row) == "table" and isBeyondKanto(game, row.species) then
        return "reserved_egg:" .. tostring(row.species)
      end
    end
  end

  local function dexWitness(game, save)
    local dex = type(save.pokedex) == "table" and save.pokedex or {}
    for _, section in ipairs({ "owned", "seen" }) do
      for species, value in pairs(type(dex[section]) == "table"
          and dex[section] or {}) do
        if value == true and isBeyondKanto(game, species) then
          return "pokedex_" .. section .. ":" .. tostring(species)
        end
      end
    end
  end

  local function researchWitness(owner)
    local state = owner and owner.johto_research
    if type(state) ~= "table" then return nil end
    if state.finalReward == true then return "research_finale" end
    for _, key in ipairs({
      "starters", "rewards", "trackWins", "eggsQueued", "eggsHatched",
      "itemsClaimed", "partnersClaimed", "compensations",
    }) do
      if anyTrue(state[key]) then return "research_" .. key end
    end
    for _, key in ipairs({ "eggQueue", "pendingMons" }) do
      if anyRows(state[key]) then return "research_" .. key end
    end
    if type(state.activeEgg) == "table" then return "research_active_egg" end
  end

  local function signalsWitness(owner)
    -- Since 6.5.3 the physical capsule, boat and repaired receiver are all
    -- allowed to exist while this save is still deliberately Gen-I sealed.
    -- Even a complete old current is not inferred here: after sync creates a
    -- sealed receipt, johto_signals.repairBoundaryChoice validates the whole
    -- reachable quest shape and performs the required durable transaction.
    -- This keeps all Signals-only migrations rollback-safe and fail-closed.
    return nil
  end

  local function expectedCadenceOwner(save, owner)
    local player = type(save.player) == "table" and save.player or {}
    local run = type(owner and owner.legacy_journey) == "table"
      and owner.legacy_journey or {}
    return table.concat({
      tostring(save.version or "unknown"),
      tostring(player.id or "no-player-id"),
      tostring(run.runId or "original"),
    }, ":")
  end

  local function mastersWitness(save, owner)
    local state = owner and owner.johto_masters
    if type(state) ~= "table" then return nil end
    -- A Legacy handoff copies edition history into the next run.  It is not
    -- proof that this new save has opened Johto.  In particular, old archive
    -- snapshots predate cadenceOwner, so nil is only local evidence on a
    -- non-Legacy save.  A stamped owner must match this exact run.
    if state.cadenceOwner == nil
        and type(owner and owner.legacy_journey) == "table" then
      return nil
    end
    if type(state.cadenceOwner) == "string"
        and state.cadenceOwner ~= expectedCadenceOwner(save, owner) then
      return nil
    end
    for _, key in ipairs({
      "attempts", "clears", "gifts", "connectedClears", "journeyClears",
    }) do
      if (tonumber(state[key]) or 0) > 0 then return "masters_" .. key end
    end
    if state.title == true or state.activeRun == true
        or type(state.pendingGift) == "table" then
      return "masters_progress"
    end
    for key, passage in pairs(type(state.passages) == "table"
        and state.passages or {}) do
      if type(passage) == "table" and (passage.status == "unlocked"
          or passage.status == "entered" or passage.status == "cleared"
          or passage.rewarded == true or (tonumber(passage.attempts) or 0) > 0)
          then
        return "masters_passage:" .. tostring(key)
      end
    end
  end

  local function hevoStoryWitness(save, owner)
    local flags = type(save.flags) == "table" and save.flags or {}
    for _, character in ipairs({ "RED", "BLUE", "GREEN" }) do
      if flags["KA_HEVO_CHARACTER_TUNNEL_ENTERED_" .. character] == true then
        return "hevo_tunnel:" .. character
      end
    end

    local campaign = owner and owner.hidden_evolution_story_campaign
    if type(campaign) == "table" then
      if type(campaign.handoff) == "table" and campaign.handoff.seal == true then
        return "hevo_handoff"
      end
      if anyTrue(campaign.discovery) or anyTrue(campaign.hints)
          or anyTrue(campaign.doorVisits) then
        return "hevo_story"
      end
      for _, retry in pairs(type(campaign.researcherRetry) == "table"
          and campaign.researcherRetry or {}) do
        if retry == true or type(retry) == "table"
            and (retry.failed == true or (tonumber(retry.attempts) or 0) > 0)
            then
          return "hevo_researcher"
        end
      end
    end

    local run = owner and owner.hevo_run
    if type(run) ~= "table" then return nil end
    local dungeon = run.dungeonLegacy
    if type(dungeon) == "table"
        and (anyTrue(dungeon.seals) or anyTrue(dungeon.reentered)) then
      return "hevo_seal"
    end
    local red = run.red
    if type(red) == "table" and ((tonumber(red.sight) or 0) > 0
        or anyTrue(red.boulders) or red.completed == true) then
      return "hevo_red"
    end
    local blue = run.hidden_evolution_blue
    if type(blue) == "table" and ((tonumber(blue.sight) or 0) > 0
        or (tonumber(blue.cycle) or 1) > 1 or anyRows(blue.asked)
        or anyTrue(blue.solved) or anyTrue(blue.switches)) then
      return "hevo_blue"
    end
    local nested = run.hidden_evolution_story_campaign
    local green = type(nested) == "table" and nested.green or nil
    if type(green) == "table" and ((tonumber(green.sight) or 0) > 0
        or (tonumber(green.checkpointRank) or 1) > 1
        or green.rootgate == true or green.canopy == true
        or green.completed == true or anyRows(green.asked)) then
      return "hevo_green"
    end
  end

  local function hevoPersistentWitness(owner)
    -- Legacy Journey deliberately carries permanent HEVO history into its next
    -- fresh save.  That archive inheritance is not evidence that this save has
    -- crossed the boundary; its fresh explicit OFF record remains authoritative.
    if type(owner and owner.legacy_journey) == "table" then return nil end
    local persistent = owner and owner.hevo_persistent
    if type(persistent) ~= "table" then return nil end
    for _, key in ipairs({ "packageUnlocks", "evolutionUnlocks",
        "permanentItems", "firstGrants", "questionIds", "dex",
        "secretUnlocks" }) do
      if anyTrue(persistent[key]) then return "hevo_persistent:" .. key end
    end
    if anyRows(persistent.pendingItems) then return "hevo_pending_items" end
  end

  function B.migrationWitness(game, save)
    save = saveOf(save or game)
    if type(save) ~= "table" then return nil end
    game = type(game) == "table" and game.data and game or B.game
    local owner = bucket(save, false)
    return monWitness(game, save)
      or dexWitness(game, save)
      or researchWitness(owner)
      or signalsWitness(owner)
      or mastersWitness(save, owner)
      or hevoStoryWitness(save, owner)
      or hevoPersistentWitness(owner)
      or (type(owner and owner.dex_progress) == "table"
        and owner.dex_progress.nationalDexUnlocked == true
        and "national_dex" or nil)
  end

  local function normalizeState(state)
    if type(state) ~= "table" then return nil end
    state.version = B.SCHEMA_VERSION
    -- Once written, the irreversible receipt is authoritative even if an old
    -- UI or a hand-edited table tries to flip only the display boolean back.
    state.active = state.active == true or state.irreversible == true
    state.irreversible = state.active and true or nil
    return state
  end

  -- This exact receipt is written only by Oak's irreversible Legacy/New
  -- Game+ Johto YES transaction. Old-save witnesses, imported Pokémon,
  -- Pokédex rows and a later Driftglass activation intentionally fail it.
  function B.hasLegacyJohtoAuthority(value)
    local state = rawState(saveOf(value))
    return type(state) == "table"
      and state.active == true and state.irreversible == true
      and state.decision == "legacy_partner_catalog"
  end

  function B.hasLegacyJohtoWildsAuthority(value)
    local state = rawState(saveOf(value))
    local receipt = type(state) == "table" and state.ordinaryWilds or nil
    return B.hasLegacyJohtoAuthority(value)
      and type(receipt) == "table"
      and receipt.version == B.LEGACY_WILDS_VERSION
      and receipt.authority == "legacy_partner_catalog"
      and receipt.applied == true
  end

  function B.state(value, create)
    local save = saveOf(value)
    local state = normalizeState(rawState(save))
    if not state and create ~= false then
      state = setState(save, {
        version = B.SCHEMA_VERSION,
        active = false,
        decision = "sealed",
      })
    end
    return state
  end

  function B.isActive(value)
    local state = B.state(value, false)
    return state and state.active == true or false
  end

  function B.sealFresh(value, forceFresh)
    local save = saveOf(value)
    if type(save) ~= "table" then return false end
    if not forceFresh and B.isActive(save) then
      return false, "irreversible"
    end
    setState(save, {
      version = B.SCHEMA_VERSION,
      active = false,
      decision = "fresh_gen1",
    })
    return true
  end

  local function ensureBaseline(data)
    if type(data) ~= "table" then return nil end
    local baseline = rawget(data, DATA_MARKER)
    if type(baseline) == "table" then return baseline end
    baseline = { pokemon = {}, moves = {} }
    for species in pairs(SPECIES_OVERLAY) do
      local record = data.pokemon and data.pokemon[species]
      if type(record) == "table" then
        baseline.pokemon[species] = { types = copy(record.types or {}) }
      end
    end
    for move in pairs(MOVE_OVERLAY) do
      local record = data.moves and data.moves[move]
      if type(record) == "table" then
        baseline.moves[move] = {
          type = record.type,
          category = record.category,
          categoryPresent = record.category ~= nil,
        }
      end
    end
    rawset(data, DATA_MARKER, baseline)
    return baseline
  end

  local function restoreData(data)
    local baseline = ensureBaseline(data)
    if not baseline then return false end
    for species, saved in pairs(baseline.pokemon) do
      local record = data.pokemon and data.pokemon[species]
      if type(record) == "table" then record.types = copy(saved.types) end
    end
    for move, saved in pairs(baseline.moves) do
      local record = data.moves and data.moves[move]
      if type(record) == "table" then
        record.type = saved.type
        record.category = saved.categoryPresent and saved.category or nil
      end
    end
    return true
  end

  local function applyData(data)
    for species, types in pairs(SPECIES_OVERLAY) do
      local record = data.pokemon and data.pokemon[species]
      if type(record) == "table" then record.types = copy(types) end
    end
    for move, overlay in pairs(MOVE_OVERLAY) do
      local record = data.moves and data.moves[move]
      if type(record) == "table" then
        record.type, record.category = overlay.type, overlay.category
      end
    end
  end

  local function notify(active, game, reason, activation)
    for _, listener in ipairs(listeners) do
      local ok, err = pcall(listener, active == true, game, reason)
      if not ok and mod.log and mod.log.error then
        mod.log:error("Beyond-Kanto boundary listener failed: " .. tostring(err))
      end
    end
    local signals = controllers.signals
    if signals and type(signals.forceUnleashed) == "function" then
      local state = rawState(saveOf(game))
      signals.forceUnleashed(game, active == true, {
        reason = reason,
        decision = state and state.decision,
        signalMode = type(activation) == "table"
          and activation.signalMode or nil,
      })
    end
    local dex = controllers.dex
    if active and dex and type(dex.unlockNationalDex) == "function" then
      dex.unlockNationalDex(game)
    end
    local research = controllers.research
    if research and type(research.refresh) == "function" and game then
      local map = game.overworld and game.overworld.map
      research.refresh(game, map and map.id)
    end
  end

  function B.sync(game, save, reason)
    game = type(game) == "table" and game or B.game
    save = saveOf(save or game)
    if game then B.game = game end
    if type(save) ~= "table" then return false, "save" end
    local state = normalizeState(rawState(save))
    local migrated = false
    if not state then
      local witness = B.migrationWitness(game, save)
      state = setState(save, {
        version = B.SCHEMA_VERSION,
        active = witness ~= nil,
        irreversible = witness and true or nil,
        decision = witness and "migrated_active" or "sealed",
        migrationWitness = witness,
      })
      migrated = witness ~= nil
    end
    if game and game.data then
      restoreData(game.data)
      if state.active then applyData(game.data) end
    end
    return state.active == true, migrated, state.migrationWitness, reason
  end

  function B.onChanged(listener)
    assert(type(listener) == "function", "Beyond-Kanto boundary listener missing")
    listeners[#listeners + 1] = listener
    return listener
  end

  function B.bindControllers(values)
    for key, value in pairs(type(values) == "table" and values or {}) do
      controllers[key] = value
    end
    local game = B.game
    if game and game.save then
      notify(B.isActive(game.save), game, "controllers-bound")
    end
    return B
  end

  local function legacyWildsReceiptReady(state)
    local receipt = type(state) == "table" and state.ordinaryWilds or nil
    return type(receipt) == "table"
      and receipt.version == B.LEGACY_WILDS_VERSION
      and receipt.authority == "legacy_partner_catalog"
      and receipt.applied == true
  end

  local function legacyWildsControllerReady(signals, game)
    if not (signals and type(signals.legacyWildsReady) == "function") then
      return false
    end
    local ok, ready = pcall(signals.legacyWildsReady, game)
    return ok and ready == true
  end

  local function stageLegacyWilds(game, state)
    local signals = controllers.signals
    if not (signals
        and type(signals.stageLegacyWildsRepair) == "function"
        and type(signals.rollbackLegacyWildsRepair) == "function"
        and type(signals.commitLegacyWildsRepair) == "function") then
      return nil, "legacy-wilds-controller"
    end
    local called, signalsReceipt, reason =
      pcall(signals.stageLegacyWildsRepair, game)
    if not called then return nil, "legacy-wilds-stage" end
    if type(signalsReceipt) ~= "table" then
      return nil, reason or "legacy-wilds-authority"
    end
    local staged = {
      signals = signals,
      signalsReceipt = signalsReceipt,
      previousReceipt = copy(state.ordinaryWilds),
    }
    state.ordinaryWilds = {
      version = B.LEGACY_WILDS_VERSION,
      authority = "legacy_partner_catalog",
      applied = true,
    }
    return staged
  end

  local function rollbackLegacyWilds(state, staged)
    if type(state) == "table" and type(staged) == "table" then
      state.ordinaryWilds = copy(staged.previousReceipt)
    end
    if not (type(staged) == "table" and staged.signals
        and type(staged.signals.rollbackLegacyWildsRepair) == "function") then
      return false
    end
    local ok, restored = pcall(staged.signals.rollbackLegacyWildsRepair,
      staged.signalsReceipt)
    return ok and restored == true
  end

  local function commitLegacyWilds(staged)
    if not (type(staged) == "table" and staged.signals
        and type(staged.signals.commitLegacyWildsRepair) == "function") then
      return false
    end
    local ok, committed = pcall(staged.signals.commitLegacyWildsRepair,
      staged.signalsReceipt)
    return ok and committed == true
  end

  -- Backward-compatible 6.5.3 repair. It mutates only the versioned boundary
  -- receipt and the narrow Johto Signals ordinary-wild authority. A failed
  -- durable write restores both in memory, leaves canonical YES intact, and
  -- therefore makes the next lifecycle pass a safe retry.
  function B.repairLegacyWilds(game, reason)
    game = type(game) == "table" and game or B.game
    local save = saveOf(game)
    if type(save) ~= "table" then return false, "save" end
    if not B.hasLegacyJohtoAuthority(save) then
      return false, "not-legacy-johto"
    end
    local state = rawState(save)
    local signals = controllers.signals
    if legacyWildsReceiptReady(state)
        and legacyWildsControllerReady(signals, game) then
      return false, "already-repaired"
    end

    local staged, stageReason = stageLegacyWilds(game, state)
    if not staged then return false, stageReason end
    local wrote = false
    if type(game.writeSave) == "function" then
      local called, result = pcall(game.writeSave, game)
      wrote = called and result ~= false
    end
    if not wrote then
      local restored = rollbackLegacyWilds(state, staged)
      return false, restored and "save_failed" or "rollback_failed"
    end
    commitLegacyWilds(staged)
    return true, "repaired", reason
  end

  function B.activate(game, activation)
    game = type(game) == "table" and game or B.game
    activation = type(activation) == "table" and activation or {}
    local save = game and game.save
    if type(save) ~= "table" then return false, "save" end
    if B.isActive(save) then
      B.sync(game, save, "already-active")
      return false, "already-active", tr(
        "BEYOND KANTO is\nalready permanent in\nthis save.",
        "JENSEITS VON KANTO\nist in diesem Spielstand\nbereits dauerhaft.")
    end

    local owner = bucket(save, true)
    local rollback = {
      boundary = copy(owner[B.SAVE_KEY]),
      signals = copy(owner.johto_signals),
      dex = copy(owner.dex_progress),
      runRules = copy(owner.run_rules),
    }
    owner[B.SAVE_KEY] = {
      version = B.SCHEMA_VERSION,
      active = true,
      irreversible = true,
      decision = type(activation.decision) == "string"
          and activation.decision ~= "" and activation.decision
        or "player_confirmed",
      activatedAt = os.time(),
    }
    B.sync(game, save, "activated")
    notify(true, game, "activated", activation)

    local legacyWildsStage
    if B.hasLegacyJohtoAuthority(save) then
      local stageReason
      legacyWildsStage, stageReason = stageLegacyWilds(game, owner[B.SAVE_KEY])
      if not legacyWildsStage then
        owner[B.SAVE_KEY] = rollback.boundary
        owner.johto_signals = rollback.signals
        owner.dex_progress = rollback.dex
        owner.run_rules = rollback.runRules
        local signals = controllers.signals
        if signals and type(signals.install) == "function" then
          pcall(signals.install, game, false)
        end
        B.sync(game, save, "activation-rollback")
        notify(false, game, "activation-rollback")
        return false, stageReason or "legacy-wilds-stage", tr(
          "The save remains sealed.\nJohto wilds could not\nbe prepared safely.",
          "Der Spielstand bleibt\nversiegelt. Johto-Wildnis\nkonnte nicht sicher\nvorbereitet werden.")
      end
    end

    -- The canonical Legacy YES is allowed to become visible only together
    -- with a durable ordinary-wild receipt. Other historical activation
    -- callers retain the pre-existing no-writer behavior.
    local wrote = activation.requireDurable ~= true
      and legacyWildsStage == nil
    if type(game.writeSave) == "function" then
      local called, result = pcall(game.writeSave, game)
      wrote = called and result ~= false
    end
    if not wrote then
      if legacyWildsStage then
        rollbackLegacyWilds(owner[B.SAVE_KEY], legacyWildsStage)
      end
      owner[B.SAVE_KEY] = rollback.boundary
      owner.johto_signals = rollback.signals
      owner.dex_progress = rollback.dex
      owner.run_rules = rollback.runRules
      local signals = controllers.signals
      if signals and type(signals.install) == "function" then
        pcall(signals.install, game, false)
      end
      B.sync(game, save, "activation-rollback")
      notify(false, game, "activation-rollback")
      return false, "save_failed", tr(
        "The save failed.\nBEYOND KANTO remains\nsealed; nothing changed.",
        "Speichern fehlgeschlagen.\nJENSEITS VON KANTO bleibt\nversiegelt; nichts änderte sich.")
    end
    if legacyWildsStage then commitLegacyWilds(legacyWildsStage) end
    return true, "activated", tr(
      "BEYOND KANTO!\fDark and Steel rules\nnow apply.\fAll extended encounters,\nrewards and Legacy Bank\nwithdrawals are open.\fThis save can never\nreturn to pure Gen I.",
      "JENSEITS VON KANTO!\fUnlicht- und Stahlregeln\ngelten ab jetzt.\fAlle erweiterten Kämpfe,\nBelohnungen und Bank-\nEntnahmen sind offen.\fDieser Spielstand kehrt\nnie zu reinem Gen I\nzurück.")
  end

  function B.canWithdrawMon(save, mon, game)
    if B.isActive(save) then return true end
    local species = type(mon) == "table" and mon.species or nil
    local dex = speciesDex(game or B.game, species)
    if dex and dex >= 1 and dex <= 151 then return true end
    return false, tr(
      "BEYOND KANTO:\nSEALED.\fThe POKéMON remains safe\nin the Legacy Bank.",
      "JENSEITS VON KANTO:\nVERSIEGELT.\fDas POKéMON bleibt sicher\nin der Vermächtnis-Bank.")
  end

  function B.status(value)
    local state = B.state(value, false)
    return {
      active = state and state.active == true or false,
      irreversible = state and state.irreversible == true or false,
      decision = state and state.decision or "unseen",
      migrationWitness = state and state.migrationWitness or nil,
    }
  end

  if mod.hooks and type(mod.hooks.wrap) == "function" then
    -- Species remain registered so archives and old slots are readable, but
    -- no live evolution may cross #151 while this save is sealed.  This one
    -- engine dispatch covers friendship, level, item, trade and every custom
    -- HEVO method without deleting Kanto's original evolution branches.
    mod.hooks:wrap("evolution.check", function(nextCheck, game, mon, evo,
        trigger)
      if not B.isActive(game)
          and isBeyondKanto(game, type(evo) == "table" and evo.species) then
        return false
      end
      return nextCheck(game, mon, evo, trigger)
    end, 9500)
    mod.hooks:wrap("save.new_game", function(nextNewGame, save)
      local fresh = nextNewGame(save)
      B.sealFresh(fresh, true)
      return fresh
    end, 9500)
  end

  if mod.events and type(mod.events.on) == "function" then
    mod.events:on("save.created", function(ev)
      local game = ev and ev.game or B.game
      local save = ev and ev.save or game and game.save
      B.sealFresh(save, true)
      B.sync(game, save, "save.created")
    end, 9500)
    mod.events:on("save.loaded", function(ev)
      B.sync(ev and ev.game or B.game, ev and ev.save, "save.loaded")
    end, 9500)
    mod.events:on("game.ready", function(ev)
      B.sync(ev and ev.game or B.game, ev and ev.game and ev.game.save,
        "game.ready")
    end, 9500)
    -- Signals resets its slot cache at priority 300.  Notify composed
    -- controllers only afterwards so a selected save can never mutate the
    -- previously active bucket through a stale cached section.
    local function notifyCurrent(ev, reason)
      local game = ev and ev.game or B.game
      if game then
        notify(B.isActive(game.save), game, reason)
        -- game.ready still exposes CONTINUE's provisional/title save. The
        -- selected slot is authoritative only at save.loaded; fresh YES is
        -- handled atomically inside activate() and needs no lifecycle repair.
        if reason == "save.loaded" then
          local _, repairReason = B.repairLegacyWilds(game, reason)
          if (repairReason == "save_failed"
              or repairReason == "rollback_failed")
              and mod.log and mod.log.error then
            mod.log:error("Legacy Johto wild repair deferred: "
              .. tostring(repairReason))
          end
        end
      end
    end
    mod.events:on("save.created", function(ev)
      notifyCurrent(ev, "save.created")
    end, 50)
    mod.events:on("save.loaded", function(ev)
      notifyCurrent(ev, "save.loaded")
    end, 50)
    mod.events:on("game.ready", function(ev)
      notifyCurrent(ev, "game.ready")
    end, 50)
  end

  B.copy = copy
  B.speciesDex = speciesDex
  B.isBeyondKantoSpecies = isBeyondKanto
  B.overlays = { species = SPECIES_OVERLAY, moves = MOVE_OVERLAY }
  return B
end
