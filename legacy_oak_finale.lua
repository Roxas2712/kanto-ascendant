-- KA-INTERNAL: LEGACY-OAK-FINALE-001
--
-- The final Legacy trial borrows a validated party only for the battle.  It
-- never leases, deposits, saves, or otherwise mutates a bank row while the
-- builder is open: the live party is replaced by copies and restored before
-- any overworld continuation.  This makes cancellation, loss, reload, and a
-- failed UI path a strict rollback to the pre-trial save state.

return function(mod, opts)
  opts = opts or {}
  local journey = assert(opts.journey, "Oak finale needs Legacy Journey")
  local paths = assert(opts.paths, "Oak finale needs Legacy Paths")
  local i18n = opts.i18n
  local newTrainer = opts.newTrainer or function(game, class, index)
    return require("src.battle.BattleState").newTrainer(game, class, index)
  end
  local F = { CLASS = "KA_OAK_BETA", PARTY_INDEX = 1 }
  local sourceOwners = setmetatable({}, { __mode = "k" })

  -- Egg moves are a real legality source in this build, but the finale is
  -- created before Day-Care during main.lua's load order.  Read the same
  -- authored registry through the public mod filesystem instead of copying
  -- a second list into this module.  Unit fixtures may inject it directly.
  local eggMoves = opts.eggMoves
  if type(eggMoves) ~= "table" and mod and type(mod.read) == "function" then
    local body = mod:read("egg_moves.lua")
    local chunk = body and loadstring(body, "@" .. tostring(mod.path)
      .. "/egg_moves.lua")
    if chunk then
      local ok, rows = pcall(chunk)
      if ok and type(rows) == "table" then eggMoves = rows end
    end
  end
  eggMoves = type(eggMoves) == "table" and eggMoves or {}

  local BOSS = {
    { species = "TAUROS", level = 88,
      moves = { "BODY_SLAM", "EARTHQUAKE", "BLIZZARD", "HYPER_BEAM" } },
    { species = "ALAKAZAM", level = 86,
      moves = { "PSYCHIC_M", "RECOVER", "REFLECT", "THUNDER_WAVE" } },
    { species = "EXEGGUTOR", level = 86,
      moves = { "PSYCHIC_M", "MEGA_DRAIN", "SOLARBEAM", "EXPLOSION" } },
    { species = "GYARADOS", level = 87,
      moves = { "SURF", "BLIZZARD", "THUNDERBOLT", "HYPER_BEAM" } },
    { species = "ARCANINE", level = 87,
      moves = { "FIRE_BLAST", "BODY_SLAM", "DIG", "HYPER_BEAM" } },
    { species = "SNORLAX", level = 89,
      moves = { "BODY_SLAM", "EARTHQUAKE", "BLIZZARD", "REST" } },
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
    for key, child in pairs(value) do out[copy(key, seen)] = copy(child, seen) end
    return out
  end

  local function allComplete()
    local profile = paths.profile and paths.profile() or {}
    local done = profile.completedPaths or {}
    return done.red == true and done.blue == true and done.green == true, profile
  end

  local function moveId(row)
    return type(row) == "table" and row.id or row
  end

  local function isInteger(value)
    return type(value) == "number" and value == math.floor(value)
  end

  local function containsMove(rows, id)
    for _, row in ipairs(rows or {}) do
      if (type(row) == "table" and (row.move or row.id) or row) == id then
        return true
      end
    end
    return false
  end

  local function directMoveLegal(def, id, level)
    for _, id2 in ipairs(def.level1Moves or {}) do
      if id2 == id then return true end
    end
    for _, row in ipairs(def.learnset or {}) do
      if row.move == id and (tonumber(row.level) or 101) <= level then
        return true
      end
    end
    for _, id2 in ipairs(def.tmhm or {}) do
      if id2 == id then return true end
    end
    if containsMove(eggMoves[tonumber(def.dex)], id) then return true end
    return false
  end

  -- A lawful evolved Pokemon may retain a pre-evolution or egg move which
  -- is absent from its final form's compact learnset.  Event distributions
  -- and authored Reminder/Resonance choices carry their own provenance too.
  -- Walk the merged evolution registry rather than hard-coding families.
  local function legalMove(data, def, id, mon, seen)
    local level = math.max(1, math.floor(tonumber(mon and mon.level) or 1))
    if directMoveLegal(def, id, level) then return true end
    if containsMove(mon and mon.eventDistribution
        and mon.eventDistribution.originalMoves, id) then return true end
    local remembered = mon and mon.rememberedMoves
    if type(remembered) == "table"
        and (remembered[id] == true or containsMove(remembered, id)) then
      return true
    end
    local resonance = mod.exports and mod.exports.driftglassPrisms
      and mod.exports.driftglassPrisms.resonanceRules
    local rule = resonance and resonance[mon and mon.species]
      and resonance[mon.species][id]
    if rule and (not rule.level or level >= rule.level) then return true end

    seen = seen or {}
    if seen[def.id or def.dex] then return false end
    seen[def.id or def.dex] = true
    for parentId, parent in pairs(data and data.pokemon or {}) do
      for _, evolution in ipairs(parent.evolutions or {}) do
        if evolution.species == (mon and mon.species or def.id)
            and not seen[parentId] then
          local ancestor = { species = parentId, level = level }
          if legalMove(data, parent, id, ancestor, seen) then return true end
        end
      end
    end
    return false
  end

  -- Normalise old string-form move saves into the engine's current move
  -- records, but reject unknown, duplicate, empty, ghost, or held-item data.
  -- Gen I has no held-item runtime, so any such field is a foreign/unsafe
  -- state rather than a harmless thing to silently carry into this battle.
  function F.normaliseMon(data, mon)
    if type(mon) ~= "table" then
      return nil, "ghost_or_missing_mon"
    end
    if mon.isEgg == true then return nil, "egg_mon" end
    if mon.ghost == true or mon.species == "GHOST" then
      return nil, "ghost_or_missing_mon"
    end
    local def = data and data.pokemon and data.pokemon[mon.species]
    if not def then return nil, "unknown_species" end
    if not isInteger(mon.level) or mon.level < 1 or mon.level > 100 then
      return nil, "invalid_level"
    end
    if mon.item ~= nil or mon.heldItem ~= nil or mon.held_item ~= nil then
      return nil, "invalid_held_item_state"
    end
    if type(mon.moves) ~= "table" or #mon.moves < 1 or #mon.moves > 4 then
      return nil, "invalid_move_count"
    end
    local result, seen = copy(mon), {}
    result.moves = {}
    for index, row in ipairs(mon.moves) do
      local id = moveId(row)
      if type(id) ~= "string" or not (data.moves and data.moves[id]) or seen[id]
          or not legalMove(data, def, id, mon) then
        return nil, "invalid_move_state"
      end
      seen[id] = true
      local pp = type(row) == "table" and tonumber(row.pp) or nil
      local ppUps = type(row) == "table" and tonumber(row.ppUps) or 0
      if not isInteger(ppUps) or ppUps < 0 or ppUps > 3 then
        return nil, "invalid_move_pp"
      end
      local base = tonumber(data.moves[id].pp) or 1
      local max = base + ppUps * math.floor(base / 5)
      if pp and (pp < 0 or pp > max or pp ~= math.floor(pp)) then
        return nil, "invalid_move_pp"
      end
      result.moves[index] = { id = id, pp = pp or max, ppUps = ppUps }
    end
    -- Archive rows may have originated as box_struct records and therefore
    -- legitimately lack cached party stats.  Recalculate every trial copy
    -- from bounded DVs/stat-exp: this accepts old saves but cannot import
    -- impossible/tampered combat stats into Oak's supposedly fair battle.
    local stats = require("src.pokemon.Stats")
    local keys = { "attack", "defense", "speed", "special" }
    local dvs = {}
    for _, key in ipairs(keys) do
      local value = mon.dvs and tonumber(mon.dvs[key]) or 0
      if not isInteger(value) or value < 0 or value > 15 then
        return nil, "invalid_dv_state"
      end
      dvs[key] = value
    end
    dvs.hp = (dvs.attack % 2) * 8 + (dvs.defense % 2) * 4
      + (dvs.speed % 2) * 2 + (dvs.special % 2)
    local statExp = {}
    for _, key in ipairs({ "hp", "attack", "defense", "speed", "special" }) do
      local value = mon.statExp and tonumber(mon.statExp[key]) or 0
      if not isInteger(value) or value < 0 or value > 65535 then
        return nil, "invalid_stat_exp"
      end
      statExp[key] = value
    end
    result.dvs, result.statExp = dvs, statExp
    result.stats = stats.calc(def, result.level, dvs, statExp, result)
    result.hp = result.stats.hp
    result.status = nil
    for _, move in ipairs(result.moves) do
      local base = tonumber(data.moves[move.id].pp) or 1
      move.pp = base + move.ppUps * math.floor(base / 5)
    end
    return result
  end

  local function sourceLabel(game, mon)
    local def = game.data.pokemon[mon.species]
    return mon.nickname or (def and def.name) or mon.species
  end

  -- `availableMons` reconciles leases first, so an archive entry already in
  -- a party is never offered a second time.  The stable identity still guards
  -- a corrupted/stale source list and a duplicate Lua table in the party.
  function F.sources(game)
    local rows, seen = {}, {}
    local function add(kind, id, mon, label)
      local identity = mon.__kaLegacyId and ("mon:" .. mon.__kaLegacyId)
        or (kind == "archive" and ("mon:" .. id) or ("live:" .. tostring(mon)))
      if seen[identity] then return end
      seen[identity] = true
      local normal, err = F.normaliseMon(game.data, mon)
      rows[#rows + 1] = {
        id = kind .. ":" .. tostring(id), identity = identity, kind = kind,
        mon = normal, invalid = err, label = label or sourceLabel(game, mon),
      }
      sourceOwners[rows[#rows]] = game
    end
    for index, mon in ipairs(game.save.party or {}) do
      add("party", index, mon)
    end
    local archive = journey.archive
    if archive and archive.availableMons then
      local available, archiveErr = archive.availableMons(game.save)
      if archiveErr then return rows, archiveErr end
      for _, row in ipairs(available or {}) do
        if type(row) == "table" and row.id and type(row.mon) == "table" then
          add("archive", row.id, row.mon, sourceLabel(game, row.mon))
        end
      end
    end
    return rows
  end

  function F.buildTeam(game, selected)
    if type(selected) ~= "table" or #selected ~= 6 then
      return nil, "exactly_six_required"
    end
    local team, identities = {}, {}
    for _, source in ipairs(selected) do
      if type(source) ~= "table" or sourceOwners[source] ~= game then
        return nil, "untrusted_source"
      end
      if type(source.identity) ~= "string" or identities[source.identity] then
        return nil, "duplicate_source"
      end
      identities[source.identity] = true
      if source.invalid then return nil, source.invalid end
      local mon, err = F.normaliseMon(game.data, source.mon)
      if not mon then return nil, err end
      team[#team + 1] = mon
    end
    return team
  end

  function F.validateBoss(data)
    local seen = {}
    for _, slot in ipairs(BOSS) do
      local def = data and data.pokemon and data.pokemon[slot.species]
      if not def or seen[slot.species] or not isInteger(slot.level)
          or slot.level < 1 or slot.level > 100 or #slot.moves ~= 4 then
        return false
      end
      seen[slot.species] = true
      for _, id in ipairs(slot.moves) do
        if not (data.moves and data.moves[id])
            or not legalMove(data, def, id, slot) then
          return false
        end
      end
    end
    return #BOSS == 6
  end

  local pendingBoss
  mod.hooks:wrap("trainer.party", function(nextParty, class, index, party)
    if class == F.CLASS and index == F.PARTY_INDEX and pendingBoss then
      return copy(pendingBoss)
    end
    return nextParty(class, index, party)
  end, 5400)

  -- The Loader's deliberately tiny full-fixture data set does not contain
  -- every Kanto species or Oak's optional vanilla portrait.  Registering a
  -- schema record at load time would therefore make a valid live battle look
  -- like a merge error.  Define this isolated trainer only after the real
  -- battle data has loaded; it remains a unique class and never patches an
  -- Elite/Champion or vanilla Oak record.
  function F.ensureTrainer(game)
    local trainers = game and game.data and game.data.trainers
    if type(trainers) ~= "table" then return nil, "missing_trainer_data" end
    local existing = trainers[F.CLASS]
    if existing then
      if existing.__kaLegacyOakBeta ~= true or existing.baseMoney ~= 0 then
        return nil, "trainer_class_conflict"
      end
      return existing
    end
    local oak = trainers.OPP_PROF_OAK or {}
    local parties = {}
    for index, slot in ipairs(BOSS) do
      parties[index] = { species = slot.species, level = slot.level }
    end
    local record = {
      id = F.CLASS, name = oak.name or "PROF.OAK", pic = oak.pic,
      trueColor = oak.trueColor, paletteSource = oak.paletteSource,
      -- The engine calculates a prize from baseMoney.  Zero is intentional:
      -- this is a research trial, never an Elite/Champion money source.
      baseMoney = 0, parties = { parties }, __kaLegacyOakBeta = true,
    }
    trainers[F.CLASS] = record
    return record
  end

  local function pushText(game, text, done, config)
    local TextBox = opts.TextBox or require("src.render.TextBox")
    game.stack:push(TextBox.new(game, text, done, config))
  end

  local function reportError(message)
    if mod.log and type(mod.log.error) == "function" then
      mod.log:error(tostring(message))
    end
  end

  local function finishBattle(game, ow, npc, originalParty, battle, result)
    -- This restoration happens before any overworld logic.  Since no save
    -- call occurred while copies were active, there is no partial party write
    -- to reconcile after a cancelled or lost trial.
    game.save.party = originalParty
    npc.frozen = false
    if result ~= "win" then
      pushText(game, tr(
        "OAK: Team restored\fStudy the result.\nThen ask to retry.",
        "EICH: Team zurück.\fLerne aus Fehlern.\nBitte dann erneut."))
      return
    end
    if ow and ow.afterBattle then ow:afterBattle("win", battle) end
    local _, profile = allComplete()
    if not profile.legacyPass then
      local called, saved, err = pcall(journey.completeFinale, game.save)
      if not called then err, saved = saved, false end
      if not saved then
        reportError("Legacy Oak reward write failed: " .. tostring(err))
        pushText(game, tr(
          "OAK: The archive did\nnot answer.\fYour team is safe.\nNo reward saved.\fSave, then retry.",
          "EICH: Das Archiv\nantwortet nicht.\fTeam bleibt sicher.\nNichts vergeben.\fSpeichere zuerst.\nVersuche es erneut."))
        return
      end
      pushText(game, tr(
        "OAK: Your LEGACY\nPASS is recorded.\fLEGACY KEEPER!\nReward: one time.",
        "EICH: DEIN PASS\nIST VERMERKT.\fVERMÄCHTNIS-\nHÜTER! EINMALIG."))
    else
      pushText(game, tr("OAK: Fair rematch.\fNo prize today.\nOnly a new lesson.",
        "EICH: Gutes Duell.\fHeute kein Preis.\nNur neue Erkenntnis."))
    end
  end

  function F.startBattle(game, ow, npc, selected)
    local complete = allComplete()
    if not complete then return false, "paths_incomplete" end
    local team, err = F.buildTeam(game, selected)
    if not team then return false, err end
    if not F.validateBoss(game.data) then return false, "invalid_boss_data" end
    local trainer, trainerErr = F.ensureTrainer(game)
    if not trainer then return false, trainerErr end
    local originalParty = game.save.party
    game.save.party = team
    pendingBoss = BOSS
    local ok, battle = pcall(newTrainer, game, F.CLASS, F.PARTY_INDEX)
    pendingBoss = nil
    if not ok or not battle then
      game.save.party = originalParty
      return false, "battle_creation_failed"
    end
    battle.ascendantOakBeta = true
    battle.ascendantDedicatedContext = "legacy_oak_beta"
    battle.noPrizeMoney = true
    battle.introText = tr("PROF.OAK tests\nYOUR LEGACY TEAM!",
      "PROF.EICH prüft\nDEIN VERMÄCHTNIS!")
    local finished = false
    battle.onFinish = function(result)
      if finished then return end
      finished = true
      finishBattle(game, ow, npc, originalParty, battle, result)
    end
    if not (ow and ow.pushBattle) then
      game.save.party = originalParty
      return false, "missing_battle_presenter"
    end
    local pushed = pcall(ow.pushBattle, ow, battle)
    if not pushed then
      game.save.party = originalParty
      npc.frozen = false
      return false, "battle_presentation_failed"
    end
    return true, battle
  end

  local function beginConfirmed(game, ow, npc, selected)
    local team, err = F.buildTeam(game, selected)
    if not team then
      pushText(game, tr("OAK: That team is\nnot legal here.",
        "EICH: Dieses Team\nist unzulässig.")
        .. "\f" .. tostring(err))
      return
    end
    -- Two explicit opt-in prompts: team lock, then battle start.  The first
    -- irreversible action is still only the normal battle launch; no save is
    -- written by either confirmation.
    pushText(game, tr(
      "OAK: Lock all six\nfor my last trial?",
      "EICH: Diese sechs\nfür Eichs Prüfung?"), nil, {
      defaultNo = true,
      choice = function(locked)
        if not locked then return end
        pushText(game, tr("Begin the BETA\ntrial now?",
          "BETA-Prüfung jetzt\nbeginnen?"), nil, {
          defaultNo = true,
          choice = function(begin)
            if begin then F.startBattle(game, ow, npc, selected) end
          end,
        })
      end,
    })
  end

  function F.openBuilder(game, ow, npc)
    local complete = allComplete()
    if not complete then return false, "paths_incomplete" end
    local sources, sourceErr = F.sources(game)
    if sourceErr then return false, sourceErr end
    local selected, legalCount = {}, 0
    for _, source in ipairs(sources) do
      if not source.invalid then legalCount = legalCount + 1 end
    end
    if legalCount < 6 then return false, "not_enough_valid_sources" end
    local ListMenu = (mod.ui and (mod.ui.KantoListMenu or mod.ui.ListMenu))
    if not ListMenu then return false, "missing_list_menu" end
    local function picker()
      local rows, selectedIds = {}, {}
      for _, source in ipairs(selected) do selectedIds[source.identity] = true end
      for _, source in ipairs(sources) do
        if not selectedIds[source.identity] and not source.invalid then
          local origin = source.kind == "archive" and "A" or tr("P", "T")
          rows[#rows + 1] = { label = source.label,
            -- Compact origin + level keeps every legal 10-character Gen-I
            -- name visible. The intro already explains PARTY + ARCHIVE;
            -- P/T and A distinguish the source without a clipped suffix.
            right = origin .. " L" .. tostring(source.mon.level), value = source }
        end
      end
      if #selected > 0 then
        rows[#rows + 1] = { label = tr("REMOVE LAST", "LETZTE ENTFERNEN"),
          value = "remove" }
      end
      if #selected == 6 then
        rows[#rows + 1] = { label = tr("REVIEW SIX", "SECHS PRÜFEN"),
          value = "review" }
      end
      local list
      list = ListMenu.new(game, tr("OAK TEAM %d/6", "EICH-TEAM %d/6")
        :format(#selected), rows, {
        -- This is a full-screen team builder, not a dialogue-choice overlay.
        -- Let Ascendant's opaque layout own the whole frame; the stock
        -- messageBox variant could inherit a stale/black German backbuffer.
        pageJump = true,
        onCancel = function()
          npc.frozen = false
        end,
        onChoose = function(item)
          if not item then return end
          if item.value == "remove" then
            list:close()
            table.remove(selected)
            picker()
            return
          end
          if item.value == "review" then
            list:close()
            beginConfirmed(game, ow, npc, selected)
            return
          end
          list:close()
          selected[#selected + 1] = item.value
          picker()
        end,
      })
      game.stack:push(list)
    end
    picker()
    return true
  end

  function F.start(game, ow, npc)
    local complete, profile = allComplete()
    if not complete then return false, "paths_incomplete" end
    npc.frozen = true
    npc:facePlayer(ow.player)
    local rematch = profile.legacyPass == true
    pushText(game, rematch and tr(
      "OAK: Paths remain.\fBuild a legal six.\fNo-prize rematch.",
      "EICH: Pfade aktiv.\fBaue ein Team aus\nsechs POKéMON.\fOhne Preis.") or tr(
      "OAK: Three seals.\fBuild a legal six.\fParty + archive.",
      "EICH: Drei Siegel.\fBaue ein Team aus\nsechs POKéMON.\fTeam und Archiv."), function()
        local ok, err = F.openBuilder(game, ow, npc)
        if not ok then
          npc.frozen = false
          reportError("Legacy Oak builder refused: " .. tostring(err))
          pushText(game, tr(
            "OAK: Six valid\nPOKéMON required.\fCheck party +\narchive.",
            "EICH: Sechs\ngültige POKéMON.\fPrüfe Team und\nArchiv."))
        end
      end)
    return true
  end

  F.boss = copy(BOSS)
  F.allComplete = allComplete
  return F
end
