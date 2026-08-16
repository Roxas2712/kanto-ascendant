-- Durable result boundary for the three character-bound Hidden Evolution
-- dungeons. Maps/puzzles own their local state; this adapter is the only
-- production path that turns a completed seal into permanent packages.
return function(opts)
  opts = opts or {}
  local archive = assert(opts.archive,
    "legacy dungeon adapter requires legacy archive")
  local packages = assert(opts.packages,
    "legacy dungeon adapter requires HEVO packages")
  local mega = opts.megaEvolution
  local beyondKanto = opts.beyondKanto or opts.johtoBoundary
  local i18n = opts.i18n
  local A = {}
  A.contract = {
    RED = { seal = "red", stone = "BLAZIKENITE", starter = "TORCHIC",
      secret = "KA_RED_BLAZIKENITE_SECRET", title = "legacy_path_red" },
    BLUE = { seal = "blue", stone = "SWAMPERTITE", starter = "MUDKIP",
      secret = "KA_HEVO_BLUE_SWAMPERTITE_CACHE", title = "legacy_path_blue" },
    GREEN = { seal = "green", stone = "SCEPTILITE", starter = "TREECKO",
      secret = "KA_GREEN_SCEPTILITE_SECRET", title = "legacy_path_green" },
  }

  local function beyondActive(save)
    return not beyondKanto or type(beyondKanto.isActive) ~= "function"
      or beyondKanto.isActive(save or A.game)
  end

  local function tr(en, de)
    return i18n and i18n.text(en, de) or en
  end

  function A.failureText(reason)
    if reason ~= "beyond-kanto-sealed" then return nil end
    return tr(
      "BEYOND KANTO still\nseals this non-Gen-I\nreward.\fActivate it with ELM'S\nAIDE, then return.",
      "JENSEITS VON KANTO\nversiegelt diese Nicht-\nGen-I-Belohnung noch.\fAktiviere es bei LIND\nund kehre dann zurück.")
  end

  local function copy(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}; if seen[value] then return seen[value] end
    local out = {}; seen[value] = out
    for key, child in pairs(value) do out[copy(key, seen)] = copy(child, seen) end
    return out
  end

  local function bucket(save, create)
    if type(save.modData) ~= "table" then
      if not create then return nil end
      save.modData = {}
    end
    local id = opts.modId or "kanto_ascendant"
    local b = save.modData[id]
    if type(b) ~= "table" and create then b = {}; save.modData[id] = b end
    return b
  end

  local function localState(save, create)
    local b = bucket(save, create); if not b then return nil end
    if type(b.hevo_run) ~= "table" then
      if not create then return nil end
      b.hevo_run = {}
    end
    if type(b.hevo_run.dungeonLegacy) ~= "table" then
      if not create then return nil end
      b.hevo_run.dungeonLegacy = { seals = {}, reentered = {} }
    end
    local state = b.hevo_run.dungeonLegacy
    state.seals = type(state.seals) == "table" and state.seals or {}
    state.reentered = type(state.reentered) == "table" and state.reentered or {}
    return state
  end

  function A.character(save)
    local function resolved(value)
      if value == nil then return nil, false end
      value = type(value) == "string" and value:upper() or nil
      return value and A.contract[value] and value or nil, true
    end
    -- Read the unnormalized slot record before extendedCharacters.getState().
    -- That public presentation surface maps every unknown value to RED; a
    -- present FUTURE/YELLOW record must instead close all reward authority.
    local b = bucket(save, false)
    local state = b and b.extended_characters or nil
    if state ~= nil then
      if type(state) ~= "table" then return nil end
      local character, authoritative = resolved(state.player_character)
      if authoritative then return character end
      return nil
    end
    local character, authoritative
    if opts.journey and type(opts.journey.activeCharacter) == "function" then
      character, authoritative = resolved(opts.journey.activeCharacter(save))
      if authoritative then return character end
    end
    if type(archive.activeCharacter) == "function" then
      character, authoritative = resolved(archive.activeCharacter(save))
      if authoritative then return character end
    end
    if opts.characters and type(opts.characters.getState) == "function" then
      local public = opts.characters.getState()
      character, authoritative = resolved(public and public.player_character)
      if authoritative then return character end
    end
    -- Exact absence is the only legacy migration case: pre-6.5 Kanto saves
    -- had no character bucket because Red was the sole playable identity.
    return type(save) == "table" and "RED" or nil
  end

  function A.hasHall(save)
    return type(save.hallOfFame) == "table" and #save.hallOfFame > 0
  end

  function A.canFinalize(save, character)
    if not beyondActive(save) then return false, "beyond-kanto-sealed" end
    character = tostring(character or ""):upper()
    if A.character(save) ~= character then return false, "character" end
    local run = localState(save, false)
    if run and run.seals[character] then return false, "claimed" end
    return true
  end

  local function snapshot(save)
    local b = bucket(save, true)
    return { bucket = b, run = copy(b.hevo_run),
      persistent = copy(b.hevo_persistent), mega = copy(b.mega_evolution),
      flags = copy(save.flags), inventory = copy(save.inventory),
      bagOrder = copy(save.bagOrder) }
  end

  local function restore(save, before)
    before.bucket.hevo_run = copy(before.run)
    before.bucket.hevo_persistent = copy(before.persistent)
    before.bucket.mega_evolution = copy(before.mega)
    save.flags = copy(before.flags)
    save.inventory = copy(before.inventory) or {}
    save.bagOrder = copy(before.bagOrder)
  end

  function A.finalize(game, result)
    local save = assert(game and game.save, "game save required")
    result = type(result) == "table" and result or {}
    -- Production results cannot smuggle a subset or a foreign package.
    if result.evolutionUnlocks ~= nil or result.packageUnlocks ~= nil then
      return false, "result-packages-forbidden"
    end
    local character = A.character(save)
    local contract = A.contract[character]
    if not contract then return false, "character" end
    local allowed, why = A.canFinalize(save, character)
    if not allowed then return false, why end
    if result.character
        and tostring(result.character):upper() ~= character then
      return false, "character"
    end

    local before = snapshot(save)
    local run = localState(save, true)
    run.seals[character], run.reentered[character] = true, true
    run.rivalWitness = type(run.rivalWitness) == "table"
      and run.rivalWitness or {}
    run.rivalWitness[character] = result.rivalWitness == true

    local persistent = packages.persistent(save, true)
    persistent.meta[character] = true
    persistent.permanentItems["LEGACY_STARTER_" .. contract.starter] = true
    persistent.dex[contract.starter] = true
    for _, id in ipairs(result.questionIds or {}) do
      persistent.questionIds[id] = true
    end
    save.flags = type(save.flags) == "table" and save.flags or {}
    save.flags["HEVO_META_" .. character] = true

    local packageTx, packageErr = packages.stageCharacter(save, character)
    if not packageTx then restore(save, before); return false, packageErr end

    local function rollback(reason)
      restore(save, before)
      local restored = not game.writeSave or game:writeSave() ~= false
      return false, restored and reason or "rollback-save"
    end
    if game.writeSave and game:writeSave() == false then
      return rollback("save")
    end
    -- advancePath merges the live HEVO bucket into the archive in the same
    -- archive write that seals this character path.
    local completePath = opts.journey and opts.journey.completeHevoPath
      or archive.completeHevoPath
    local ok, err
    if completePath then ok, err = completePath(save, character)
    else
      local advance = opts.journey and opts.journey.advancePath
        or archive.advancePath
      ok, err = advance(save, 5, true)
    end
    if not ok then return rollback(err or "archive") end
    local targetCount = 0
    for _, package in ipairs(packages.byCharacter[character]) do
      targetCount = targetCount + #package.targets
    end
    return true, {
      character = character, contract = contract,
      packages = packages.byCharacter[character], targetCount = targetCount,
    }
  end

  -- Explicitly named migration/recovery seam. Normal dungeon payloads never
  -- reach it and the package registry still validates the character whitelist.
  function A.recoverPackages(game, character, packageIds)
    if not beyondActive(game and game.save) then
      return false, "beyond-kanto-sealed"
    end
    local tx, err = packages.stageRecovery(game.save,
      tostring(character or ""):upper(), packageIds, false)
    if not tx then return false, err end
    return packages.commit(game, tx)
  end

  function A.archiveReady(save)
    if not beyondActive(save) then return false end
    local p = packages.persistent(save, false)
    return p and p.meta.RED and p.meta.BLUE and p.meta.GREEN
      and ((opts.journey and opts.journey.hevoDoorQuestReady
          and opts.journey.hevoDoorQuestReady(save))
        or (archive.hevoDoorQuestReady and archive.hevoDoorQuestReady(save)))
      or false
  end

  function A.consumeDoorArchive(save)
    if not A.archiveReady(save) then return false, "seals" end
    local consume = opts.journey and opts.journey.consumeHevoDoorQuest
      or archive.consumeHevoDoorQuest
    return consume(save) and true or false, "consumed"
  end

  function A.reenter(save, character)
    character = tostring(character or A.character(save) or ""):upper()
    if A.character(save) ~= character then return false, "character" end
    local p = packages.persistent(save, false)
    if not (p and p.meta[character]) then return false, "seal" end
    local run = localState(save, true); run.reentered[character] = true
    return true
  end

  local function syncPersistent(save)
    local sync = opts.journey and opts.journey.syncHevoPersistent
      or archive.syncHevoPersistent
    if not sync then return true end
    return sync(save)
  end

  local function cleanLegacyStoneFlags(persistent)
    -- RC23 briefly treated path completion as a Mega-stone grant.  There is
    -- no reliable way to distinguish that preview flag from its unfinished
    -- secret interaction, so only the explicit secret ledger is authoritative.
    -- A player who reached the old cache can simply interact with it once;
    -- the cache remains available through character-bound re-entry.
    -- Fresh/migrated saves can have an otherwise valid persistent bucket
    -- before the optional secret ledger was introduced.  Normalize locally
    -- before reconciling rather than making the unrelated game-ready hook
    -- abort (and consequently skipping later map-spawn listeners).
    persistent.secretUnlocks=type(persistent.secretUnlocks)=="table" and persistent.secretUnlocks or {}
    persistent.permanentItems=type(persistent.permanentItems)=="table" and persistent.permanentItems or {}
    for character, contract in pairs(A.contract) do
      if persistent.secretUnlocks[character] ~= true then
        persistent.permanentItems[contract.stone] = nil
      end
    end
  end

  function A.hasSecret(save, character)
    character = tostring(character or ""):upper()
    local persistent = packages.persistent(save, false)
    return A.contract[character] ~= nil and persistent ~= nil
      and persistent.secretUnlocks[character] == true
  end

  function A.reconcileSecrets(game)
    game = game or A.game
    local save = game and game.save
    if not save then return false, "save" end
    if not beyondActive(save) then
      return true, { granted = {}, pending = {}, sealed = true }
    end
    local persistent = packages.persistent(save, true)
    cleanLegacyStoneFlags(persistent)
    local granted, pending = {}, {}
    for _, character in ipairs({ "RED", "BLUE", "GREEN" }) do
      local contract = A.contract[character]
      if persistent.secretUnlocks[character] == true then
        persistent.permanentItems[contract.stone] = true
        if not mega then
          pending[#pending + 1] = contract.stone
        else
          local owned = type(mega.hasStone) == "function"
            and mega.hasStone(contract.stone, game) == true
          if not owned and type(mega.grantStone) == "function" then
            mega.grantStone(contract.stone, game)
            owned = type(mega.hasStone) == "function"
              and mega.hasStone(contract.stone, game) == true
          end
          if owned then granted[#granted + 1] = contract.stone
          else return false, "mega-grant:" .. contract.stone end
        end
      end
    end
    return true, { granted = granted, pending = pending }
  end

  function A.claimSecret(game, request)
    local save = game and game.save
    if not save then return false, "save" end
    if not beyondActive(save) then return false, "beyond-kanto-sealed" end
    request = type(request) == "table" and request or {}
    local character = tostring(request.character or ""):upper()
    local contract = A.contract[character]
    if not contract or A.character(save) ~= character then
      return false, "character"
    end
    -- Map packages submit the complete immutable identity. This closes the
    -- API to foreign stones and to another character's secret object.
    if request.stone ~= contract.stone or request.secret ~= contract.secret then
      return false, "secret"
    end
    local persistent = packages.persistent(save, true)
    cleanLegacyStoneFlags(persistent)
    if persistent.secretUnlocks[character] == true then
      local reconciled, why = A.reconcileSecrets(game)
      return false, reconciled and "claimed" or why
    end

    local before = snapshot(save)
    persistent.secretUnlocks[character] = true
    persistent.permanentItems[contract.stone] = true
    local reconciled, reconcileResult = A.reconcileSecrets(game)
    if not reconciled then restore(save, before); return false, reconcileResult end

    local function rollback(reason)
      restore(save, before)
      local restored = not game.writeSave or game:writeSave() ~= false
      return false, restored and reason or "rollback-save"
    end
    if not game.writeSave or game:writeSave() == false then
      return rollback("save")
    end
    local synced, syncErr = syncPersistent(save)
    if synced == false then return rollback(syncErr or "archive") end
    return true, {
      character = character, stone = contract.stone,
      secret = contract.secret,
      pending = #reconcileResult.pending > 0,
    }
  end

  function A.install(game)
    A.game = game
    if not A._saveHook and opts.events and opts.events.on then
      A._saveHook = true
      opts.events:on("save.loaded", function()
        local ok, why = A.reconcileSecrets(A.game)
        if not ok and opts.log and opts.log.warn then
          opts.log:warn("HEVO Mega secret reconcile failed: " .. tostring(why))
        end
      end, 1400)
    end
    return A.reconcileSecrets(game)
  end

  A.persistent = packages.persistent
  A.run = localState
  A.beyondActive = beyondActive
  return A
end
