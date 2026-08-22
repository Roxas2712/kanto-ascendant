-- Save/reward authority for the separate Silver, Kris and Gold passages.
-- Each Master owns a physical route and finale arena in
-- johto_masters_passages.lua, while this controller keeps their rotating
-- level-100 rosters and Gold's exact-once permanent shiny reward.

return function(mod, opts)
  opts = opts or {}
  local data = assert(opts.data, "Johto Masters data missing")
  local postgame = assert(opts.postgame, "postgame controller missing")
  local ascendant = opts.ascendant
  local shinySystem = assert(opts.shinySystem, "shiny controller missing")
  local i18n = opts.i18n
  local journey = opts.journey
  local beyondKanto = opts.beyondKanto or opts.johtoBoundary
  local placement = assert(opts.placement, "runtime NPC placement missing")
  local J = { game = nil }

  local function tr(en, de)
    return i18n and i18n.text(en, de) or en
  end

  local function localized(row)
    return type(row) == "table" and tr(row.en, row.de) or row
  end

  local function state(create)
    local s = mod.save:get("johto_masters")
    if type(s) ~= "table" and create ~= false then
      s = {
        version = 1, attempts = 0, clears = 0, gifts = 0,
        title = false,
      }
      mod.save:set("johto_masters", s)
    end
    if type(s) == "table" then
      -- v3 keeps the old direct-gauntlet clear/gift/title fields byte-for-byte
      -- while separating them from the connected Hall -> Silver -> Kris ->
      -- Gold cadence.  Old direct-gauntlet wins must not make the new arena
      -- host disappear on migrated/BLITZ saves.
      local priorCadenceVersion = math.max(0,
        math.floor(tonumber(s.cadenceVersion) or 0))
      s.version = 3
      s.attempts = math.max(0, math.floor(tonumber(s.attempts) or 0))
      s.clears = math.max(0, math.floor(tonumber(s.clears) or 0))
      s.gifts = math.max(0, math.floor(tonumber(s.gifts) or 0))
      s.title = s.title == true
      if type(s.pendingGift) ~= "table" then s.pendingGift = nil end
      s.passages = type(s.passages) == "table" and s.passages or {}
      for _, key in ipairs({ "silver", "kris", "gold" }) do
        local passage = s.passages[key]
        if type(passage) ~= "table" then passage = {}; s.passages[key] = passage end
        local legacyStatus = passage.status
        local normalizedStatus = legacyStatus == "rewarded"
          and "cleared" or legacyStatus
        passage.status = ({ locked=true, unlocked=true, entered=true,
          cleared=true })[normalizedStatus] and normalizedStatus or "locked"
        passage.rewarded = passage.rewarded == true
          or legacyStatus == "rewarded"
        passage.attempts = math.max(0, math.floor(tonumber(passage.attempts) or 0))
        passage.puzzle = passage.puzzle == true
        passage.clue = passage.clue == true
        passage.step = math.max(0, math.min(3,
          math.floor(tonumber(passage.step) or 0)))
        passage.resets = math.max(0,
          math.floor(tonumber(passage.resets) or 0))
      end
      local gold = s.passages.gold
      local connectedLegacyClear = gold.status == "cleared"
        and gold.rewarded == true
      if priorCadenceVersion < 1 then
        -- Only the authored passage receipt can migrate as a connected clear.
        -- `clears`/`gifts` alone came from the removed direct lobby gauntlet.
        s.connectedClears = connectedLegacyClear and 1 or 0
        s.journeyClears = connectedLegacyClear and 1 or 0
        local partial = not connectedLegacyClear and (
          s.passages.silver.status == "entered"
          or s.passages.silver.status == "cleared"
          or s.passages.kris.status == "unlocked"
          or s.passages.kris.status == "entered"
          or s.passages.kris.status == "cleared"
          or s.passages.gold.status == "unlocked"
          or s.passages.gold.status == "entered")
        s.activeRun = partial and true or false
        -- A migrated authored passage can be mid-run even though its old
        -- bucket had no run serial.  Reserve the next serial now; otherwise
        -- Gold would compare 0 >= 0 at the finale and reject the resumed
        -- run as an already-recorded reward.
        s.runSerial = math.max(s.connectedClears, 0) + (partial and 1 or 0)
        s.rewardedRunSerial = math.max(s.connectedClears, 0)
        s.cadenceOwner = nil
        s.lastHallTicket = nil
        s.runTicket = nil
        s.cadenceSerial = math.max(0,
          math.floor(tonumber(s.cadenceSerial) or 0))
      else
        s.connectedClears = math.max(0,
          math.floor(tonumber(s.connectedClears) or 0))
        s.journeyClears = math.max(0,
          math.floor(tonumber(s.journeyClears) or 0))
        s.activeRun = s.activeRun == true
        s.runSerial = math.max(s.connectedClears,
          math.floor(tonumber(s.runSerial) or 0))
        s.rewardedRunSerial = math.max(0, math.min(s.runSerial,
          math.floor(tonumber(s.rewardedRunSerial) or 0)))
        s.cadenceOwner = type(s.cadenceOwner) == "string"
          and s.cadenceOwner or nil
        s.lastHallTicket = tonumber(s.lastHallTicket)
          and math.max(0, math.floor(s.lastHallTicket)) or nil
        s.runTicket = tonumber(s.runTicket)
          and math.max(0, math.floor(s.runTicket)) or nil
        s.cadenceSerial = math.max(0,
          math.floor(tonumber(s.cadenceSerial) or 0))
      end
      s.cadenceVersion = 1
    end
    return s
  end

  local function persist(s, game)
    if not s then return false, "state" end
    s.cadenceSerial = math.max(0,
      math.floor(tonumber(s.cadenceSerial) or 0)) + 1
    mod.save:set("johto_masters", s)
    local live = game or J.game
    local save = live and live.save
    local sync = journey and journey.syncJohtoMastersPersistent
    if not (save and type(sync) == "function") then return true end
    local called, synced, err = pcall(sync, save)
    if not called or synced == false then
      local reason = not called and synced or err or "archive"
      if mod.log and mod.log.warn then
        mod.log:warn("Johto Masters archive will retry: %s", tostring(reason))
      end
      return false, reason
    end
    return true
  end

  local function eligible(game)
    -- The Indigo host is post-Elite-Four content.  Requiring the later CROWN
    -- championship silently removed him from legitimate migrated Hall of
    -- Fame saves that had never challenged Silver/Kris/Gold.
    if beyondKanto and type(beyondKanto.isActive) == "function"
        and not beyondKanto.isActive(game or J.game) then
      return false, "beyond-kanto-sealed"
    end
    if not postgame.hasHallOfFame(game and game.save) then
      return false, "hall"
    end
    return true
  end

  local function hallCount(game)
    local hall = game and game.save and game.save.hallOfFame
    return type(hall) == "table" and #hall or 0
  end

  local function cadenceOwner(game)
    local save = game and game.save or {}
    local player = type(save.player) == "table" and save.player or {}
    local bucket = type(save.modData) == "table"
      and type(save.modData[mod.id]) == "table" and save.modData[mod.id] or {}
    local journeyState = type(bucket.legacy_journey) == "table"
      and bucket.legacy_journey or {}
    return table.concat({
      tostring(save.version or "unknown"),
      tostring(player.id or "no-player-id"),
      tostring(journeyState.runId or "original"),
    }, ":")
  end

  local function resetPassages(s)
    for _, key in ipairs({ "silver", "kris", "gold" }) do
      local passage = s.passages[key]
      passage.status = key == "silver" and "unlocked" or "locked"
      passage.rewarded = false
      passage.puzzle = false
      passage.clue = false
      passage.step = 0
      -- Attempts and wrong-route resets are lifetime diagnostics.  They do
      -- not unlock a gate, so retaining them across farm runs is harmless.
    end
  end

  local function syncCadence(game)
    local s = state()
    local owner = cadenceOwner(game)
    local count = hallCount(game)
    local changed = false
    if not s.cadenceOwner then
      -- First v3 observation is an in-place migration, not a new journey.
      s.cadenceOwner = owner
      s.lastHallTicket = s.journeyClears > 0 and count or 0
      if s.activeRun then s.runTicket = count end
      changed = true
    elseif s.cadenceOwner ~= owner then
      -- A Legacy New Game+ has its own Elite-Four clock.  Persistent titles,
      -- total clears and gifts remain, while this journey gets a fresh first
      -- connected run after its own Hall of Fame.
      s.cadenceOwner = owner
      s.journeyClears = 0
      s.lastHallTicket = 0
      s.activeRun = false
      s.runTicket = nil
      resetPassages(s)
      changed = true
    end
    if s.lastHallTicket == nil then
      s.lastHallTicket = s.journeyClears > 0 and count or 0
      changed = true
    end
    if s.activeRun and s.runTicket == nil then
      s.runTicket = s.journeyClears == 0 and count
        or math.min(count, s.lastHallTicket + 1)
      changed = true
    end
    if changed then persist(s, game) end
    return s
  end

  local function challengeAvailable(game)
    if not eligible(game) then return false end
    local s = syncCadence(game)
    if s.pendingGift then return false end
    return s.activeRun or s.journeyClears == 0
      or hallCount(game) > s.lastHallTicket
  end

  local function hostAvailable(game)
    if not eligible(game) then return false end
    local s = syncCadence(game)
    return s.pendingGift ~= nil or s.activeRun or s.journeyClears == 0
      or hallCount(game) > s.lastHallTicket
  end

  local function beginRun(game)
    local allowed, reason = eligible(game)
    if not allowed then return false, reason end
    local s = syncCadence(game)
    if s.pendingGift then return false, "gift" end
    if s.activeRun then return true, "resume" end
    local count = hallCount(game)
    if s.journeyClears > 0 and count <= s.lastHallTicket then
      return false, "elite-four"
    end
    s.runSerial = math.max(s.runSerial, s.connectedClears) + 1
    s.runTicket = s.journeyClears == 0 and count
      or math.min(count, s.lastHallTicket + 1)
    s.activeRun = true
    resetPassages(s)
    persist(s, game)
    return true, "new"
  end

  local function copySlot(slot)
    return {
      species = slot.species, level = 100,
      mega = slot.mega,
      moves = slot.moves and {
        slot.moves[1], slot.moves[2], slot.moves[3], slot.moves[4],
      } or nil,
    }
  end

  local SIGNATURE_STARTER = {
    silver = "FERALIGATR", kris = "MEGANIUM", gold = "TYPHLOSION",
  }

  local function trainerFor(key)
    for _, trainer in ipairs(data.trainers) do
      if trainer.key == key then return trainer end
    end
  end

  local function teamFor(key, attempt)
    local trainer = assert(trainerFor(key), "unknown Johto Master " .. tostring(key))
    local pool, out, seen = trainer.pool, {}, {}
    local signature = assert(SIGNATURE_STARTER[key],
      "Johto Master signature starter missing for " .. tostring(key))
    for _, slot in ipairs(pool) do
      if slot.species == signature then
        out[#out + 1] = copySlot(slot)
        seen[signature] = true
        break
      end
    end
    assert(#out == 1, "Johto Master pool lacks signature starter " .. signature)
    local offset = key == "silver" and 0 or (key == "kris" and 4 or 8)
    local start = (math.max(1, math.floor(tonumber(attempt) or 1))
      + offset - 1) % #pool
    -- Five is coprime with the twelve-slot pools. Keep the signature starter
    -- fixed, then rotate five other unique partners per attempt.
    for index = 0, #pool - 1 do
      local slot = pool[((start + index * 5) % #pool) + 1]
      if not seen[slot.species] then
        out[#out + 1] = copySlot(slot)
        seen[slot.species] = true
        if #out == 6 then break end
      end
    end
    assert(#out == 6, "Johto Master team could not select six unique species")
    return out
  end

  local function megaTargetFor(key)
    return SIGNATURE_STARTER[key]
  end

  local function secretFormFor(key)
    return key == "gold" and "TYPHLOSION_ASCENDANT" or nil
  end

  local function fullRoster(game)
    local byDex = {}
    for id, def in pairs(game and game.data and game.data.pokemon or {}) do
      local dex = tonumber(def.dex)
      if dex and dex >= 1 and dex <= 251 and not byDex[dex] then
        byDex[dex] = id
      end
    end
    local out = {}
    for dex = 1, 251 do
      if byDex[dex] then out[#out + 1] = byDex[dex] end
    end
    return out
  end

  local function randomInt(lo, hi)
    if love and love.math and love.math.random then
      return love.math.random(lo, hi)
    end
    return math.random(lo, hi)
  end

  local function randomSpecies(game, rng)
    local roster = fullRoster(game)
    if #roster == 0 then return nil end
    local index = (rng or randomInt)(1, #roster)
    index = math.max(1, math.min(#roster, math.floor(tonumber(index) or 1)))
    return roster[index]
  end

  local function markOwned(game, species)
    game.save.pokedex = game.save.pokedex or { seen = {}, owned = {} }
    game.save.pokedex.seen = game.save.pokedex.seen or {}
    game.save.pokedex.owned = game.save.pokedex.owned or {}
    game.save.pokedex.seen[species] = true
    game.save.pokedex.owned[species] = true
  end

  local function buildGift(game, row)
    local Pokemon = require("src.pokemon.Pokemon")
    local mon = Pokemon.new(game.data, row.species, row.level or 50)
    shinySystem.forceMon(mon, game.data.pokemon[row.species])
    require("src.battle.BattleState").stampOT(game.save, mon)
    mon.johtoMasterGift = {
      trainer = "GOLD", clear = row.clear, title = "KANTO ASCENDANT",
    }
    return mon
  end

  local function deliverGift(game, s)
    local row = s.pendingGift
    if not row then return nil, true end
    local mon = buildGift(game, row)
    local destination, box
    if require("src.pokemon.Party").add(game.save.party, mon) then
      destination = "party"
    else
      box = require("src.pokemon.Boxes").deposit(game.save, mon)
      if box then destination = "box" end
    end
    if not destination then
      return tr(
        "Your PARTY and every\nBOX are full.\fGOLD will protect the\nshiny until you return.",
        "TEAM und alle BOXEN\nsind voll.\fGOLD bewahrt das Shiny\nbis zu deiner Rückkehr."), false
    end
    markOwned(game, row.species)
    shinySystem.markCaught(mon)
    s.pendingGift = nil
    s.gifts = s.gifts + 1
    persist(s, game)
    local name = game.data.pokemon[row.species].name
    if destination == "box" then
      return tr(
        ("GOLD: A golden victory\ndeserves something rare!\f%s received a shiny\n%s!\fIt was sent to BOX %d.")
          :format(game.save.player.name, name, box or 1),
        ("GOLD: Ein goldener Sieg\nverdient etwas Seltenes!\f%s erhält ein Shiny\n%s!\fEs ist nun in BOX %d.")
          :format(game.save.player.name, name, box or 1)), true
    end
    return tr(
      ("GOLD: A golden victory\ndeserves something rare!\f%s received a shiny\n%s!")
        :format(game.save.player.name, name),
      ("GOLD: Ein goldener Sieg\nverdient etwas Seltenes!\f%s erhält ein Shiny\n%s!")
        :format(game.save.player.name, name)), true
  end

  local function healParty(game)
    local Pokemon = require("src.pokemon.Pokemon")
    for _, mon in ipairs(game.save.party or {}) do Pokemon.heal(mon) end
  end

  local function awardTitle(s)
    if s.title then return false end
    s.title = true
    if ascendant and ascendant.state then
      local a = ascendant.state()
      a.achievements.johto_master = true
      a.latestAchievement = "johto_master"
      mod.save:set("ascendant", a)
    end
    return true
  end

  local function completeRun(game)
    local s = syncCadence(game)
    if not s.activeRun or s.rewardedRunSerial >= s.runSerial then
      return tr(
        "GOLD: This run is already recorded. Defeat the Elite Four again for another shiny run.",
        "GOLD: Dieser Lauf ist bereits verbucht. Besiege die Top Vier erneut für einen weiteren Shiny-Lauf."), false
    end
    s.clears = s.clears + 1
    s.connectedClears = s.connectedClears + 1
    s.journeyClears = s.journeyClears + 1
    s.rewardedRunSerial = s.runSerial
    s.lastHallTicket = math.max(s.lastHallTicket or 0,
      s.runTicket or hallCount(game))
    s.runTicket = nil
    s.activeRun = false
    local first = awardTitle(s)
    local reward, delivered
    -- One connected run consumes one Elite-Four ticket and creates exactly
    -- one shiny.  Pending delivery is recovered by the host before another
    -- run may begin, so a farm result can never be overwritten or duplicated.
    if not s.pendingGift then
      s.pendingGift = {
        species = randomSpecies(game), level = 50, clear = s.clears,
        connectedClear = s.connectedClears, run = s.runSerial,
      }
      persist(s, game)
      reward, delivered = deliverGift(game, s)
    else
      persist(s, game)
      reward, delivered = tr(
        "GOLD is still protecting your pending shiny. Make room, then speak to the host.",
        "GOLD bewahrt dein ausstehendes Shiny. Schaffe Platz und sprich mit dem Gastgeber."), false
    end
    if ascendant and ascendant.evaluateAchievements then
      ascendant.evaluateAchievements(game)
    end
    local title = first and tr(
      "TITLE EARNED:\nKANTO ASCENDANT\fA golden star now\nmarks your TRAINER CARD.",
      "TITEL ERHALTEN:\nKANTO ASCENDANT\fEin goldener Stern ziert\nnun deinen TRAINERPASS.")
      or tr(
        ("JOHTO MASTERS CLEAR %d"):format(s.clears),
        ("JOHTO-MEISTER SIEG %d"):format(s.clears))
    local cadence = delivered and tr(
      "To challenge them again,\ndefeat the ELITE FOUR\nand CHAMPION once more.",
      "Für eine neue Herausforderung\nbesiege TOP VIER und\nCHAMPION erneut.") or nil
    return title .. (reward and "\f" .. reward or "")
      .. (cadence and "\f" .. cadence or ""), delivered
  end

  local function startTrial(ow, npc, game)
    local TextBox = require("src.render.TextBox")
    local s = state()
    s.attempts = s.attempts + 1
    persist(s, game)
    local attempt, index = s.attempts, 0
    healParty(game)

    local function finish(result)
      npc.frozen = false
      if result ~= "win" then return end
      local message = completeRun(game)
      game.stack:push(TextBox.new(game, message))
    end

    local function nextBattle()
      index = index + 1
      local trainer = data.trainers[index]
      healParty(game)
      local battle = postgame.newForcedBattle(
        game, trainer.class, teamFor(trainer.key, attempt), "johto_master")
      battle.rematch = true
      battle.johtoMaster = trainer.key
      battle.ascendantNoItems = true
      battle.enemyAIMods = { 1, 2, 3 }
      battle.trainer = setmetatable({ name = localized(trainer.name) },
        { __index = battle.trainer })
      battle.introText = localized(trainer.intro)
      battle.endBattleText = localized(trainer.win)
      battle.onFinish = function(result)
        ow:afterBattle(result, battle)
        if result ~= "win" then finish(result); return end
        if index >= #data.trainers then finish("win"); return end
        game.stack:push(TextBox.new(game, tr(
          ("%s was defeated!\fYour team is restored.\fThe next Johto Master\nsteps forward.")
            :format(localized(trainer.name)),
          ("%s wurde besiegt!\fDein Team wird geheilt.\fDer nächste Johto-\nMeister tritt vor.")
            :format(localized(trainer.name))), nextBattle))
      end
      ow:pushBattle(battle)
    end
    nextBattle()
  end

  local function handleTalk(game, ow, npc)
    if J.passages then
      if J.passages.contentEnabled and J.passages.hostTalk then
        return J.passages.hostTalk(game, ow, npc)
      end
      -- The old single-lobby Rival-2/3 gauntlet is not a safe fallback: it
      -- aliases the selected Kanto rival and bypasses all passage saves.
      -- A fixture build without the authored maps therefore fails closed.
      game.stack:push(require("src.render.TextBox").new(game, tr(
        "The Johto arenas are unavailable in this content build.",
        "Die Johto-Arenen sind in diesem Inhaltspaket nicht verfügbar.")))
      return true
    end
    if not eligible(game) then
      game.stack:push(require("src.render.TextBox").new(game, tr(
        "The Johto Masters will\ncome after Kanto's\nElite Four falls.",
        "Die Johto-Meister\nkommen nach Kantos\nTop Vier.")))
      return
    end
    local s = state()
    npc.frozen = true
    npc:facePlayer(ow.player)
    if s.pendingGift then
      local message, delivered = deliverGift(game, s)
      game.stack:push(require("src.render.TextBox").new(game, message,
        function() npc.frozen = false end))
      if not delivered then return end
      return
    end
    local message = tr(
      "JOHTO MASTERS TRIAL\fSILVER, KRIS and GOLD\nfight in sequence.\fAll teams are LEVEL 100.\nYour team is healed\nbetween rounds.\fThe BAG is sealed.\fChallenge them?",
      "JOHTO-MEISTERPRÜFUNG\fSILVER, KRIS und GOLD\nkämpfen nacheinander.\fAlle Teams sind LEVEL 100.\nDein Team wird zwischen\nden Runden geheilt.\fDer BEUTEL ist gesperrt.\fHerausfordern?")
    game.stack:push(require("src.render.TextBox").new(game, message, nil, {
      choice = function(yes)
        if yes then startTrial(ow, npc, game)
        else npc.frozen = false end
      end,
    }))
  end

  local function runtimeObjectIds(game)
    local out = {}
    local map = game and game.data and game.data.maps
      and game.data.maps[data.map]
    for _, obj in ipairs(map and map.objects or {}) do
      if obj.runtime and obj.owner == mod.id and obj.name == data.name then
        out[#out + 1] = data.map .. "_obj_" .. tostring(obj.index)
      end
    end
    return out
  end

  local function liveRuntimeHost(ow, ids)
    local expected = {}
    for _, id in ipairs(ids) do expected[id] = true end
    local count, only
    count = 0
    for _, npc in ipairs(ow and ow.npcs or {}) do
      if expected[npc.id] then count, only = count + 1, npc end
    end
    return count, only
  end

  local function refresh(game, mapId)
    if not (mod.world and game) then return end
    local ids = runtimeObjectIds(game)
    local should = mapId == data.map and hostAvailable(game)
    if not should then
      for _, id in ipairs(ids) do mod.world:removeNpc(id) end
      return
    end
    local ow = mod.world:overworld()
    if not (ow and ow.map and ow.map.id == data.map) then return end
    local liveCount = liveRuntimeHost(ow, ids)
    if #ids == 1 and liveCount == 1 then return end
    -- A map reload can leave a runtime definition without a live pooled NPC;
    -- duplicate definitions are equally unsafe.  Reconcile to exactly one.
    for _, id in ipairs(ids) do mod.world:removeNpc(id) end
    local toggles = game.save and game.save.objectToggles
      and game.save.objectToggles[data.map]
    if toggles then toggles[data.name] = nil end
    local x, y = placement.findWideRandom(ow, data.preferred)
    if not x then
      if mod.log and mod.log.warn then
        mod.log:warn("Johto Masters host has no free public Indigo cell")
      end
      return
    end
    mod.world:spawnNpc(data.map, {
      name = data.name, sprite = data.sprite, movement = "STAY", range = "DOWN",
      -- This is a map-script host, not a battle trainer.  In particular it
      -- must never fall through to the old Rival-2 gauntlet when a talk
      -- callback is unavailable for a frame during a map transition.
      text = data.textId, x = x, y = y,
    })
  end

  if mod.content and mod.content.map_scripts then
    mod.content.map_scripts:register(data.map, {
      priority = 2300,
      talk = {
        [data.textId] = function(game, ow, npc)
          handleTalk(game, ow, npc)
        end,
      },
    })
  end

  mod.events:on("map.entered", function(ev)
    local game = ev and ev.game or J.game
    local mapId = ev and (ev.mapId or ev.map and ev.map.id)
    if game then refresh(game, mapId) end
  end)

  mod.events:on("map.reloaded", function(ev)
    local mapId = ev and ev.mapId
    if J.game then refresh(J.game, mapId) end
  end)

  mod.events:on("save.loaded", function()
    state()
    local ow = mod.world and mod.world:overworld()
    if J.game then refresh(J.game, ow and ow.map and ow.map.id) end
  end)

  function J.install(game)
    J.game = game
    state()
    if J.passages and J.passages.install then J.passages.install(game) end
    local ow = mod.world and mod.world:overworld()
    refresh(game, ow and ow.map and ow.map.id)

    local ok, TrainerCard = pcall(require, "src.ui.TrainerCard")
    if ok and TrainerCard and not TrainerCard._johtoMasterTitleWrapped then
      TrainerCard._johtoMasterTitleWrapped = true
      local draw = TrainerCard.draw
      TrainerCard.draw = function(card)
        draw(card)
        if not J.hasTitle() or not (love and love.graphics) then return end
        local g = love.graphics
        g.setColor(0.82, 0.57, 0.06, 1)
        g.rectangle("line", 1.5, 1.5, 157, 141)
        g.rectangle("fill", 8, 130, 6, 2)
        g.rectangle("fill", 10, 128, 2, 6)
        g.setColor(1, 1, 1, 1)
        g.rectangle("fill", 36, 68, 88, 15)
        g.setColor(0, 0, 0, 1)
        require("src.render.Font").draw("ASCENDANT", 44, 71)
        g.setColor(1, 1, 1, 1)
      end
    end
  end

  function J.hasTitle()
    local s = state(false)
    return s and s.title == true or false
  end

  function J.statusText()
    local s = syncCadence(J.game)
    return tr("JOHTO MASTERS", "JOHTO-MEISTER")
      .. ("\n%s: %d\n%s: %d"):format(
        tr("CLEARS", "SIEGE"), s.clears,
        tr("GOLD SHINIES", "GOLD-SHINYS"), s.gifts)
      .. ("\n%s: %d"):format(
        tr("ARENA RUNS", "ARENENLÄUFE"), s.connectedClears)
      .. ("\f%s: %s"):format(
        tr("TITLE", "TITEL"),
        s.title and "KANTO ASCENDANT" or tr("LOCKED", "GESPERRT"))
  end

  J.state = state
  J.persist = persist
  J.eligible = eligible
  J.hallCount = hallCount
  J.syncCadence = syncCadence
  J.challengeAvailable = challengeAvailable
  J.hostAvailable = hostAvailable
  J.beginRun = beginRun
  J.trainerFor = trainerFor
  J.localized = localized
  J.teamFor = teamFor
  J.megaTargetFor = megaTargetFor
  J.secretFormFor = secretFormFor
  J.fullRoster = fullRoster
  J.randomSpecies = randomSpecies
  J.completeRun = completeRun
  J.deliverGift = deliverGift
  J.refresh = refresh
  return J
end
