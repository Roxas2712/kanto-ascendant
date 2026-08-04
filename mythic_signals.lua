-- Production Mythic Signals controller.
--
-- Mew and Celebi first appear as uncatchable echoes.  Three witnessed
-- echoes let Driftglass' researcher create the Resonance Seal once the
-- Johto sender is repaired and the player owns four badges.  Afterwards a
-- true manifestation can appear.  A failed true encounter becomes a
-- short-pity persistent roamer instead of asking for another 1/8192 roll.
--
-- The encounter proposal API is deliberately transactional:
-- rollReplacement() is side-effect free, commit() applies its state delta,
-- and cancel() discards it.  The installed encounter.roll adapter waits for
-- the exact battle.started event; visible-wild pipelines receive the same
-- explicit transaction contract.

return function(mod, opts)
  opts = opts or {}
  local signalsState = assert(opts.state, "Mythic Signals state missing")
  local content = opts.content or {}
  local johtoSignals = opts.johtoSignals
  local i18n = opts.i18n

  local M = {
    game = nil,
    deps = nil,
    priority = -10,
  }

  local POOL = { "MEW", "CELEBI" }
  local OPTION_KEYS = {
    MEW = "legend_mew",
    CELEBI = "legend_celebi",
  }
  local BADGES = {
    "BOULDERBADGE", "CASCADEBADGE", "THUNDERBADGE", "RAINBOWBADGE",
    "SOULBADGE", "MARSHBADGE", "VOLCANOBADGE", "EARTHBADGE",
  }
  local ECHO_FIRST_DENOMINATOR = 512
  local ECHO_LATER_DENOMINATOR = 2048
  local TRUE_DENOMINATOR = 8192
  local RETRY_DENOMINATOR = 16
  local RETRY_GUARANTEE = 32
  local STATE_VERSION = 2

  local pendingTransaction

  local function tr(english, german)
    return i18n and i18n.text(english, german) or english
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

  local function sameState(left, right, seen)
    if type(left) ~= type(right) then return false end
    if type(left) ~= "table" then return left == right end
    seen = seen or {}
    if seen[left] == right then return true end
    seen[left] = right
    for key, value in pairs(left) do
      if not sameState(value, right[key], seen) then return false end
    end
    for key in pairs(right) do
      if left[key] == nil then return false end
    end
    return true
  end

  local function integer(value, minimum, maximum)
    value = math.floor(tonumber(value) or 0)
    if minimum ~= nil then value = math.max(minimum, value) end
    if maximum ~= nil then value = math.min(maximum, value) end
    return value
  end

  local function normalizeBound(bound)
    if type(bound) ~= "table" or not OPTION_KEYS[bound.species] then
      return nil
    end
    bound.species = tostring(bound.species)
    bound.level = integer(bound.level, 1, 100)
    bound.retryRolls = integer(bound.retryRolls, 0, RETRY_GUARANTEE)
    bound.dvs = type(bound.dvs) == "table" and bound.dvs or nil
    if bound.dvs then
      for _, key in ipairs({ "attack", "defense", "speed", "special", "hp" }) do
        bound.dvs[key] = integer(bound.dvs[key], 0, 15)
      end
    end
    bound.hp = bound.hp and integer(bound.hp, 1) or nil
    bound.status = type(bound.status) == "string" and bound.status or nil
    bound.toxicCounter = bound.toxicCounter
      and integer(bound.toxicCounter, 1) or nil
    bound.leechSeeded = bound.leechSeeded == true or nil
    return bound
  end

  local function normalize(s)
    s.version = STATE_VERSION
    if s.echoRolls == nil and s.rolls ~= nil then
      s.echoRolls = s.rolls
    end
    s.echoes = integer(s.echoes, 0, 3)
    s.echoRolls = integer(s.echoRolls, 0, ECHO_LATER_DENOMINATOR)
    s.trueRolls = integer(s.trueRolls, 0, TRUE_DENOMINATOR)
    s.sealed = s.sealed == true
    s.completed = type(s.completed) == "table" and s.completed or {}
    for species, value in pairs(s.completed) do
      if not OPTION_KEYS[species] or value ~= true then
        s.completed[species] = nil
      end
    end
    s.bound = normalizeBound(s.bound)
    -- Obsolete Lab-only counters must not drive the production controller.
    s.rolls, s.pity, s.nextAt, s.speciesSeen = nil, nil, nil, nil
    return s
  end

  local function state()
    return normalize(signalsState.section("resonance"))
  end

  local function persist()
    return signalsState.persist()
  end

  local function replaceTable(target, source)
    for key in pairs(target) do target[key] = nil end
    for key, value in pairs(source) do target[key] = copy(value) end
    return normalize(target)
  end

  local function optionValue(key)
    if not (mod.options and mod.options.get) then return nil end
    return mod.options:get(key)
  end

  local function optionEnabled()
    local value = optionValue("mythic_signals")
    if value == nil then value = optionValue("mythic_resonance") end
    return value ~= false and value ~= "off"
  end

  local function speciesEnabled(species)
    local value = optionValue(OPTION_KEYS[species])
    return value ~= false and value ~= "off"
  end

  local function owns(game, species)
    local save = game and game.save
    local owned = save and save.pokedex and save.pokedex.owned
    if owned and owned[species] then return true end
    local fn = content.isCaught or content.isOwned
    if type(fn) == "function" then
      local ok, result = pcall(fn, species, game)
      if ok and result then return true end
    end
    return false
  end

  local function markCanonicalCaught(species, game)
    local fn = content.markCanonicalCaught or content.markCaught
    if type(fn) == "function" then
      local ok, result = pcall(fn, species, game)
      if ok then return result ~= false end
    end

    -- Default bridge for Kanto Ascendant's existing canonical controllers.
    -- Their pokemon.caught listeners perform the same writes for new catches;
    -- this path additionally repairs older saves which already own the species.
    if not (mod.save and mod.save.get and mod.save.set) then return false end
    if species == "MEW" then
      local ascendant = mod.save:get("ascendant")
      ascendant = type(ascendant) == "table" and ascendant or {}
      ascendant.mewCaught = true
      ascendant.mewStage = math.max(4,
        integer(ascendant.mewStage, 0))
      mod.save:set("ascendant", ascendant)
      return true
    elseif species == "CELEBI" then
      local postgame = mod.save:get("postgame")
      postgame = type(postgame) == "table" and postgame or {}
      postgame.catches = type(postgame.catches) == "table"
        and postgame.catches or {}
      postgame.roamers = type(postgame.roamers) == "table"
        and postgame.roamers or {}
      postgame.catches.CELEBI = true
      postgame.roamers.CELEBI = nil
      mod.save:set("postgame", postgame)
      return true
    end
    return false
  end

  local function syncOwned(game)
    local s = state()
    local changed = false
    for _, species in ipairs(POOL) do
      if owns(game, species) then
        if not s.completed[species] then
          s.completed[species] = true
          changed = true
        end
        if s.bound and s.bound.species == species then
          s.bound = nil
          changed = true
        end
        markCanonicalCaught(species, game)
      end
    end
    if changed then persist() end
    return s
  end

  local function activePool(snapshot, game)
    local pool = {}
    for _, species in ipairs(POOL) do
      if speciesEnabled(species)
          and not snapshot.completed[species]
          and not owns(game, species) then
        pool[#pool + 1] = species
      end
    end
    return pool
  end

  local function hasPokedex(game)
    return game and game.save and game.save.flags
      and game.save.flags.EVENT_GOT_POKEDEX == true
  end

  local function badgeCount(game)
    local fn = content.badgeCount
    if type(fn) == "function" then
      local ok, result = pcall(fn, game)
      if ok and tonumber(result) then
        return integer(result, 0, #BADGES)
      end
    end
    local inventory = game and game.save and game.save.inventory or {}
    local count = 0
    for _, badge in ipairs(BADGES) do
      if inventory[badge] then count = count + 1 end
    end
    return count
  end

  local function senderRepaired(game)
    if not johtoSignals then return false end
    for _, key in ipairs({
      "isSenderRepaired", "isReceiverRepaired",
      "senderRepaired", "receiverRepaired", "isRepaired",
    }) do
      local fn = johtoSignals[key]
      if type(fn) == "function" then
        local ok, result = pcall(fn, game)
        if ok then return result == true end
      end
    end
    local fn = johtoSignals.state
    if type(fn) == "function" then
      local ok, result = pcall(fn)
      if ok and type(result) == "table" then
        return result.repaired == true
          or result.senderRepaired == true
          or result.receiverRepaired == true
      end
    end
    return johtoSignals.repaired == true
      or johtoSignals.senderRepaired == true
      or johtoSignals.receiverRepaired == true
  end

  local function partyPeak(game)
    local peak = 1
    for _, mon in ipairs(game and game.save and game.save.party or {}) do
      peak = math.max(peak, integer(mon.level, 1, 100))
    end
    return peak
  end

  local function echoLevel(game)
    return math.min(100, math.max(60, partyPeak(game) + 20))
  end

  local function trueLevel(game)
    -- The quest can finish at badge four; 50 there and +5 per later badge
    -- keeps a true manifestation threatening without jumping straight to 100.
    return math.min(70, math.max(50, 30 + badgeCount(game) * 5))
  end

  local function randomDVs(rng)
    local dvs = {
      attack = rng(0, 15),
      defense = rng(0, 15),
      speed = rng(0, 15),
      special = rng(0, 15),
    }
    dvs.hp = (dvs.attack % 2) * 8 + (dvs.defense % 2) * 4
      + (dvs.speed % 2) * 2 + (dvs.special % 2)
    return dvs
  end

  local function nativeKantoGrass(out, encDef, ctx)
    if type(out) ~= "table" or type(ctx) ~= "table"
        or ctx.terrain ~= "grass" then return false end
    if out.kaProtected or out.kaEncounterSource
        or ctx.kaProtected or ctx.kaEncounterSource then return false end
    -- Safari battles mutate the native wild battle into a separate capture
    -- ruleset after this hook.  Keep Mythic Signals on ordinary Kanto grass
    -- where no BALL/item contract is silently replaced by Safari mechanics.
    local mapId = tostring(ctx.mapId or "")
    if mapId:find("SAFARI_ZONE", 1, true) then return false end
    local grass = type(encDef) == "table" and encDef.grass
    local slots = type(grass) == "table" and grass.slots
    if type(slots) ~= "table" or (tonumber(grass.rate) or 0) <= 0 then
      return false
    end
    for _, slot in ipairs(slots) do
      if slot.species == out.species
          and tonumber(slot.level) == tonumber(out.level) then
        local isKanto = content.isKantoMap
        if type(isKanto) == "function" then
          local ok, result = pcall(isKanto, ctx.mapId, encDef, ctx)
          if ok and result == false then return false end
        end
        return true
      end
    end
    return false
  end

  local function protectedOutput(species, level, kind)
    return {
      species = species,
      level = level,
      kaEncounterSource = "mythic_signals",
      kaProtected = true,
      kaMythicKind = kind,
    }
  end

  local function echoDenominator(snapshot, rolls)
    if snapshot.echoes == 0 then return ECHO_FIRST_DENOMINATOR end
    rolls = integer(rolls == nil and snapshot.echoRolls or rolls,
      0, ECHO_LATER_DENOMINATOR)
    if rolls <= 1024 then return ECHO_LATER_DENOMINATOR end
    -- Pressure rises continuously through the second half of the hunt:
    -- 1/2048 at roll 1024, 1/1024 at 1536, 1/512 at 1792 and
    -- 1/2 on roll 2047, followed by the hard guarantee on 2048.
    return math.max(2,
      ECHO_LATER_DENOMINATOR - (rolls - 1024) * 2)
  end

  local function makeTransaction(before, after, output, ticket, kind)
    return {
      before = before,
      after = after,
      output = output,
      pending = ticket,
      expected = output and {
        species = output.species,
        level = output.level,
      } or nil,
      kind = kind,
      committed = false,
      cancelled = false,
    }
  end

  -- Pure encounter proposal.  It reads the supplied or current snapshot but
  -- never mutates persistent state and never installs runtime pending data.
  function M.rollReplacement(out, encDef, ctx, game, snapshot)
    game = game or M.game
    if not optionEnabled() or not hasPokedex(game)
        or not nativeKantoGrass(out, encDef, ctx)
        or type(ctx.rng) ~= "function" then
      return out, nil
    end

    local before = normalize(copy(snapshot or state()))
    local after = normalize(copy(before))
    local pool = activePool(after, game)
    if #pool == 0 then return out, nil end

    if not after.sealed then
      if after.echoes >= 3 then return out, nil end
      after.echoRolls = after.echoRolls + 1
      local denominator = echoDenominator(after, after.echoRolls)
      local guaranteeAt = after.echoes == 0
        and ECHO_FIRST_DENOMINATOR or ECHO_LATER_DENOMINATOR
      local guaranteed = after.echoRolls >= guaranteeAt
      if not guaranteed and ctx.rng(1, denominator) ~= 1 then
        return out, makeTransaction(before, after, out, nil, "echo_roll")
      end
      local species = pool[ctx.rng(1, #pool)]
      local ticket = {
        kind = "echo",
        species = species,
        fleeAt = ctx.rng(1, 3),
      }
      after.echoRolls = 0
      local replacement = protectedOutput(
        species, echoLevel(game), "echo")
      return replacement,
        makeTransaction(before, after, replacement, ticket, "echo")
    end

    local bound = normalizeBound(after.bound)
    if bound then
      if not speciesEnabled(bound.species)
          or after.completed[bound.species]
          or owns(game, bound.species) then
        after.bound = nil
        return out,
          makeTransaction(before, after, out, nil, "bound_retired")
      end
      bound.retryRolls = bound.retryRolls + 1
      local guaranteed = bound.retryRolls >= RETRY_GUARANTEE
      if not guaranteed and ctx.rng(1, RETRY_DENOMINATOR) ~= 1 then
        return out, makeTransaction(before, after, out, nil, "retry_roll")
      end
      bound.retryRolls = 0
      local ticket = { kind = "true", species = bound.species, retry = true }
      local replacement = protectedOutput(
        bound.species, bound.level, "true")
      return replacement,
        makeTransaction(before, after, replacement, ticket, "retry")
    end

    after.trueRolls = after.trueRolls + 1
    local guaranteed = after.trueRolls >= TRUE_DENOMINATOR
    if not guaranteed and ctx.rng(1, TRUE_DENOMINATOR) ~= 1 then
      return out, makeTransaction(before, after, out, nil, "true_roll")
    end

    local species = pool[ctx.rng(1, #pool)]
    after.trueRolls = 0
    after.bound = normalizeBound({
      species = species,
      level = trueLevel(game),
      dvs = randomDVs(ctx.rng),
      retryRolls = 0,
    })
    local ticket = { kind = "true", species = species, retry = false }
    local replacement = protectedOutput(
      species, after.bound.level, "true")
    return replacement,
      makeTransaction(before, after, replacement, ticket, "true")
  end

  function M.commit(transaction)
    if type(transaction) ~= "table"
        or transaction.cancelled or transaction.committed then
      return false, "inactive transaction"
    end
    local live = state()
    if not sameState(live, transaction.before) then
      transaction.cancelled = true
      return false, "stale transaction"
    end
    replaceTable(live, transaction.after)
    persist()
    transaction.committed = true
    return transaction.output, transaction.kind,
      transaction.pending and copy(transaction.pending) or nil
  end

  function M.cancel(transaction)
    if type(transaction) ~= "table"
        or transaction.committed or transaction.cancelled then
      return false
    end
    transaction.cancelled = true
    return true
  end

  function M.cancelPending()
    local transaction = pendingTransaction
    pendingTransaction = nil
    if not transaction then return false end
    return M.cancel(transaction)
  end

  -- Commit only when the proposal became the exact immediately-started wild
  -- battle.  This is the integration seam for Repel and outer authored
  -- encounter systems: a different species/level cancels every state delta.
  function M.commitWildsSpawn(transaction, species, level)
    if type(transaction) ~= "table"
        or transaction.committed or transaction.cancelled then
      return false, "inactive transaction"
    end
    local expected = transaction.expected
    if type(expected) ~= "table"
        or expected.species ~= species
        or tonumber(expected.level) ~= tonumber(level) then
      M.cancel(transaction)
      return false, "spawn mismatch"
    end
    local committed, kind, ticket = M.commit(transaction)
    if committed == false then return false, kind end
    return true, ticket, kind
  end

  mod.hooks:wrap("encounter.roll", function(nextRoll, encDef, ctx)
    -- If the previous proposal never reached battle.started, Repel or an
    -- outer system consumed it.  The next roll is the definitive cancel.
    M.cancelPending()
    local out = nextRoll(encDef, ctx)
    local replacement, transaction =
      M.rollReplacement(out, encDef, ctx, M.game)
    pendingTransaction = transaction
    return replacement
  end, M.priority)

  mod.hooks:wrap("battle.damage", function(nextDamage, ctx)
    local damage, info = nextDamage(ctx)
    local battle = ctx and ctx.battle
    if not (battle and battle.kaMythicEcho and ctx.target) then
      return damage, info
    end
    local target = ctx.target
    local mon = target.mon or target
    local enemy = battle.enemy
    if target ~= enemy and mon ~= (enemy and enemy.mon) then
      return damage, info
    end
    return math.min(tonumber(damage) or 0,
      math.max(0, (tonumber(mon.hp) or 1) - 1)), info
  end, 900)

  local function applyBoundToBattle(battle, bound)
    if not (battle and battle.enemy and battle.enemy.mon and bound) then
      return
    end
    local battler, mon = battle.enemy, battle.enemy.mon
    if bound.dvs then
      mon.dvs = copy(bound.dvs)
      local stats = M.deps and M.deps.stats
      if not stats then
        local ok, module = pcall(require, "src.pokemon.Stats")
        if ok then stats = module end
      end
      local def = battle.data and battle.data.pokemon
        and battle.data.pokemon[mon.species]
      if stats and stats.calc and def then
        mon.stats = stats.calc(def, mon.level, mon.dvs, mon.statExp)
        battler.curStats = mon.stats
        if not bound.hp then mon.hp = mon.stats.hp end
      end
    end
    if bound.hp then
      mon.hp = math.max(1, math.min(mon.stats and mon.stats.hp
        or bound.hp, bound.hp))
    end
    mon.status = bound.status
    battler.toxicCounter = bound.toxicCounter
    battler.leechSeeded = bound.leechSeeded
    battler.shownHP = mon.hp
    battler.shownStatus = mon.status
  end

  function M.applyBattleTicket(battle, ticket)
    local mon = battle and battle.enemy and battle.enemy.mon
    if type(ticket) ~= "table"
        or not (battle and battle.kind == "wild" and mon)
        or mon.species ~= ticket.species then
      return false, "battle mismatch"
    end
    battle.kaMythicSignal = ticket.species
    battle.kaMythicKind = ticket.kind
    if ticket.kind == "echo" then
      battle.kaMythicEcho = ticket.species
      battle.noCatch = true
      battle.kaMythicFleeAt = integer(ticket.fleeAt, 1, 3)
    elseif ticket.kind == "true" then
      battle.kaMythicTrue = ticket.species
      battle.kaMythicRetry = ticket.retry == true
      applyBoundToBattle(battle, state().bound)
    else
      return false, "unknown ticket"
    end
    return true
  end

  -- The proposal is deliberately consumed before validation.  A different
  -- next battle cancels it and can never inherit a stale Mythic ticket.
  mod.events:on("battle.started", function(ev)
    local transaction = pendingTransaction
    pendingTransaction = nil
    if not transaction then return end
    local battle = ev and ev.battle
    local mon = battle and battle.enemy and battle.enemy.mon
    if not (battle and battle.kind == "wild" and mon) then
      M.cancel(transaction)
      return
    end
    local committed, ticket =
      M.commitWildsSpawn(transaction, mon.species, mon.level)
    if not committed or not ticket then return end
    M.applyBattleTicket(battle, ticket)
  end, 500)

  mod.events:on("world.stepped", function()
    -- Repel and visible-wild suppression can discard an encounter.roll
    -- result without ever creating a battle.  Its proposal expires on the
    -- next field step and must not accidentally match a later battle.
    M.cancelPending()
  end, 500)

  mod.events:on("save.loaded", function(ev)
    -- Runtime proposals and owned-species conclusions belong to one save
    -- slot only.  Reinstalling here also keeps the BattleState wrappers
    -- idempotent while switching between versioned upgrade fixtures.
    M.install(ev and ev.game, M.deps)
  end, 290)

  mod.events:on("battle.turn_ended", function(ev)
    local battle = ev and ev.battle
    if not (battle and battle.kaMythicEcho and not battle.result) then
      return
    end
    battle.kaMythicTurns = integer(battle.kaMythicTurns, 0) + 1
    if battle.kaMythicTurns < battle.kaMythicFleeAt then return end
    battle.result = "run"
    battle.phase = "messages"
    battle.afterQueue = "finish"
    if battle.sayNext then
      battle:sayNext(tr(
        "The bright outline\nbursts into stars!",
        "Der helle Umriss\nwird zu Sternen!"))
    end
  end, 500)

  local function completeSpecies(species, game)
    local s = state()
    local changed = not s.completed[species]
    s.completed[species] = true
    if s.bound and s.bound.species == species then
      s.bound = nil
      changed = true
    end
    if changed then persist() end
    markCanonicalCaught(species, game)
    return changed
  end

  mod.events:on("battle.ended", function(ev)
    local battle = ev and ev.battle
    if not battle then return end
    if battle.kaMythicEcho and not battle.kaMythicEchoCounted then
      battle.kaMythicEchoCounted = true
      local s = state()
      s.echoes = math.min(3, s.echoes + 1)
      persist()
      return
    end
    if not battle.kaMythicTrue then return end
    local species = battle.kaMythicTrue
    if ev.result == "caught" or owns(battle.game or M.game, species) then
      completeSpecies(species, battle.game or M.game)
      return
    end
    local mon = battle.enemy and battle.enemy.mon
    if not mon then return end
    local s = state()
    local bound = s.bound
    if not bound or bound.species ~= species then
      bound = { species = species, level = mon.level, retryRolls = 0 }
      s.bound = bound
    end
    -- The manifestation's badge-tier level is part of its persistent
    -- identity.  Never let a malformed/reconstructed battle silently
    -- reroll that tier on teardown.
    bound.level = integer(bound.level or mon.level, 1, 100)
    bound.dvs = copy(mon.dvs or bound.dvs)
    bound.hp = math.max(1, integer(mon.hp, 0))
    bound.status = mon.status
    bound.toxicCounter = battle.enemy.toxicCounter
    bound.leechSeeded = battle.enemy.leechSeeded == true or nil
    bound.retryRolls = 0
    normalizeBound(bound)
    persist()
  end, 500)

  mod.events:on("pokemon.caught", function(ev)
    if ev and OPTION_KEYS[ev.species] then
      completeSpecies(ev.species, ev.game or M.game)
    end
  end, 500)

  local function appendOrder(save, item)
    save.bagOrder = type(save.bagOrder) == "table" and save.bagOrder or {}
    for _, existing in ipairs(save.bagOrder) do
      if existing == item then return end
    end
    save.bagOrder[#save.bagOrder + 1] = item
  end

  local function resonanceItem()
    return content.ITEMS and content.ITEMS.RESONANCE_SEAL
      or content.RESONANCE_SEAL or "RESONANCE_SEAL"
  end

  local function grantWithoutCapacity(save, item)
    save.inventory = type(save.inventory) == "table" and save.inventory or {}
    if save.inventory[item] then return false end
    save.inventory[item] = 1
    appendOrder(save, item)
    return true
  end

  function M.researcherCanSeal(game)
    game = game or M.game
    local s = syncOwned(game)
    if s.sealed then
      return false, "sealed", tr(
        "The seal is\nalready stable.",
        "Das Siegel ist\nschon stabil.")
    end
    if not optionEnabled() then
      return false, "disabled", tr(
        "Receiver is quiet.\nMYTHIC: OFF",
        "Empfänger schweigt\nMYTHOS: AUS")
    end
    if s.echoes < 3 then
      return false, "echoes", tr(
        ("Only %d/3 echoes\nanswer the seal.")
          :format(s.echoes),
        ("Erst %d/3 Echos\nantworten.")
          :format(s.echoes))
    end
    if not senderRepaired(game) then
      return false, "sender", tr(
        "Repair the JOHTO\nsender first.",
        "Repariere zuerst\nden JOHTO-Sender.")
    end
    local badges = badgeCount(game)
    if badges < 4 then
      return false, "badges", tr(
        ("Need four BADGES.\nYou have %d.")
          :format(badges),
        ("Vier ORDEN nötig.\nDu hast %d.")
          :format(badges))
    end
    return true, "ready", tr(
      "All three echoes\nagree. Seal ready.",
      "Alle drei Echos\nstimmen ein.\nSiegel bereit.")
  end

  function M.researcherSeal(game)
    game = game or M.game
    local canSeal, reason, message = M.researcherCanSeal(game)
    if not canSeal then return false, reason, message end
    if not (game and game.save) then
      return false, "no_save", tr(
        "No save loaded.", "Kein Spielstand.")
    end

    local s = state()
    local item = resonanceItem()
    local save = game.save
    save.inventory = type(save.inventory) == "table" and save.inventory or {}
    local previousItem = save.inventory[item]
    local previousOrder = copy(save.bagOrder)
    local previousSealed = s.sealed
    local added = grantWithoutCapacity(save, item)
    s.sealed = true
    s.trueRolls = 0

    local ok, err = pcall(persist)
    if not ok then
      s.sealed = previousSealed
      save.inventory[item] = previousItem
      save.bagOrder = previousOrder
      return false, "save", tostring(err)
    end
    return true, added and "sealed" or "repaired", tr(
      "The RESONANCE SEAL\nholds steady.\fTrue mythic\nsignals take form.",
      "Das RESONANZ-\nSIEGEL hält.\fEchte Mythosspuren\nnehmen Form an.")
  end

  function M.publicSpeciesName(species, game)
    game = game or M.game
    local seen = game and game.save and game.save.pokedex
      and game.save.pokedex.seen
    if not (seen and seen[species]) then return "???" end
    local def = game and game.data and game.data.pokemon
      and game.data.pokemon[species]
    return def and def.name or species
  end

  function M.statusData(game)
    game = game or M.game
    local s = syncOwned(game)
    local pool = activePool(s, game)
    local guaranteeAt = s.echoes == 0
      and ECHO_FIRST_DENOMINATOR or ECHO_LATER_DENOMINATOR
    local denominator = echoDenominator(s, s.echoRolls + 1)
    return {
      enabled = optionEnabled(),
      hasPokedex = hasPokedex(game),
      senderRepaired = senderRepaired(game),
      badges = badgeCount(game),
      echoes = s.echoes,
      echoRolls = s.echoRolls,
      echoOdds = denominator,
      echoGuaranteeIn = math.max(0, guaranteeAt - s.echoRolls),
      sealed = s.sealed,
      trueRolls = s.trueRolls,
      trueOdds = TRUE_DENOMINATOR,
      trueGuaranteeIn = math.max(0, TRUE_DENOMINATOR - s.trueRolls),
      retryOdds = RETRY_DENOMINATOR,
      retryGuarantee = RETRY_GUARANTEE,
      active = copy(pool),
      complete = #pool == 0,
      bound = s.bound and {
        species = M.publicSpeciesName(s.bound.species, game),
        retryRolls = s.bound.retryRolls,
        guaranteeIn = math.max(0,
          RETRY_GUARANTEE - s.bound.retryRolls),
      } or nil,
    }
  end

  function M.status(game)
    local d = M.statusData(game)
    if not d.enabled then
      return tr(
        "MYTHIC SIGNALS\nSystem: OFF",
        "MYTHOS-SIGNALE\nSystem: AUS")
    end
    if d.complete then
      return tr(
        "MYTHIC SIGNALS\nAll enabled traces\nare complete.",
        "MYTHOS-SIGNALE\nAlle Mythos-Spuren\nsind vollständig.")
    end
    if d.bound then
      return tr(
        ("BOUND SIGNAL\nTrace:\n%s\fRetry: 1/%d\nGuaranteed in:\n%d")
          :format(d.bound.species, d.retryOdds, d.bound.guaranteeIn),
        ("GEBUNDENES SIGNAL\nSpur:\n%s\fChance: 1/%d\nGarantiert in:\n%d")
          :format(d.bound.species, d.retryOdds, d.bound.guaranteeIn))
    end
    if d.sealed then
      return tr(
        ("RESONANCE SEALED\nTrue trace:\n1/%d\fGuaranteed in:\n%d")
          :format(d.trueOdds, d.trueGuaranteeIn),
        ("RESONANZ-SIEGEL\nEchte Spur:\n1/%d\fGarantiert in:\n%d")
          :format(d.trueOdds, d.trueGuaranteeIn))
    end
    return tr(
      ("MYTHIC SIGNALS\nEchoes: %d/3\fPressure: 1/%d\nGuaranteed in:\n%d")
        :format(d.echoes, d.echoOdds, d.echoGuaranteeIn),
      ("MYTHOS-SIGNALE\nEchos: %d/3\fDruck: 1/%d\nGarantiert in:\n%d")
        :format(d.echoes, d.echoOdds, d.echoGuaranteeIn))
  end

  function M.objective(game)
    game = game or M.game
    local d = M.statusData(game)
    if not d.enabled then
      return tr(
        "MYTHIC: OFF",
        "MYTHOS: AUS")
    end
    if d.complete then
      return tr(
        "All mythic signals\nare complete.",
        "Alle Mythosspuren\nsind vollständig.")
    end
    if not d.hasPokedex then
      return tr(
        "Get the POKEDEX\nfrom PROF.OAK.",
        "Hol den POKEDEX\nbei PROF.EICH.")
    end
    if d.echoes < 3 then
      return tr(
        ("Witness echo %d/3\nin Kanto grass.")
          :format(d.echoes + 1),
        ("Finde Echo %d/3\nin Kantos Gras.")
          :format(d.echoes + 1))
    end
    if not d.sealed then
      if not d.senderRepaired then
        return tr(
          "Repair the sender\nat DRIFTGLASS.",
          "Sender reparieren\nauf DRIFTGLAS.")
      end
      if d.badges < 4 then
        return tr(
          "Earn four BADGES.\nSteady the echo.",
          "Vier ORDEN holen.\nEcho festigen.")
      end
      return tr(
        "Ask the researcher\nat DRIFTGLASS.",
        "Bitte den Forscher\nauf DRIFTGLAS\num das Siegel.")
    end
    if d.bound then
      return tr(
        ("Track:\n%s\fKanto grass.\nIt will return.")
          :format(d.bound.species),
        ("Verfolge:\n%s\fKantos Gras.\nEs kehrt zurück.")
          :format(d.bound.species))
    end
    return tr(
      "Search Kanto grass\nfor a true signal.",
      "Suche in Kantos\nGras nach echter\nErscheinung.")
  end

  function M.researcherDialogue(game)
    game = game or M.game
    local d = M.statusData(game)
    if not d.enabled then
      return tr(
        "RESEARCHER:\nReceiver is quiet.\fEnable MYTHIC\nSIGNALS for study.",
        "FORSCHER:\nEmpfänger schweigt\fAktiviere MYTHOS-\nSIGNALE zur Suche.")
    end
    if d.complete then
      return tr(
        "RESEARCHER:\nBoth signals\nare recorded.\fKanto remembers\nyour discovery.",
        "FORSCHER:\nBeide Signale sind\nerfasst.\fKanto bewahrt\ndeinen Fund.")
    end
    if d.echoes < 3 then
      return tr(
        ("RESEARCHER:\nSeal holds %d/3.\fSearch Kanto\ngrass.\fNo BALL can hold\nan echo.")
          :format(d.echoes),
        ("FORSCHER:\nEchos: %d/3.\fSuche in Kantos\nGras.\fKein BALL hält\nein Echo.")
          :format(d.echoes))
    end
    local canSeal, _, message = M.researcherCanSeal(game)
    if not d.sealed then
      if canSeal then
        return message .. "\f" .. tr(
          "Ask me to finish\nthe RESONANCE\nSEAL.",
          "Bitte mich, das\nRESONANZ-SIEGEL\nzu vollenden.")
      end
      return tr("RESEARCHER:\n", "FORSCHER:\n") .. message
    end
    if d.bound then
      return tr(
        ("RESEARCHER:\nBound trace:\n%s\fIt recalls wounds\nand returns soon.")
          :format(d.bound.species),
        ("FORSCHER:\nGebundene Spur:\n%s\fSie merkt Wunden\nund kehrt zurück.")
          :format(d.bound.species))
    end
    return tr(
      "RESEARCHER:\nSeal is listening.\fA true signal is\nrare, but pressure\npersists.",
      "FORSCHER:\nSiegel lauscht.\fEin echtes Signal\nist selten. Der\nDruck bleibt.")
  end

  function M.install(game, deps)
    M.game = game or M.game
    M.deps = deps or M.deps or {}
    -- Loading/reinstalling can switch save slots without reconstructing the
    -- module table.  Runtime-only proposals must never cross that boundary.
    M.cancelPending()
    if signalsState.install then signalsState.install(M.game) end
    syncOwned(M.game)

    local BattleState = M.deps.battleState
    if not BattleState then
      local ok, module = pcall(require, "src.battle.BattleState")
      if ok then BattleState = module end
    end
    if not BattleState then return false, "battle state unavailable" end

    if not BattleState._kaMythicSignalsBallWrapped
        and type(BattleState.throwBall) == "function" then
      BattleState._kaMythicSignalsBallWrapped = true
      local vanillaThrowBall = BattleState.throwBall
      BattleState.throwBall = function(battle, ball, ...)
        if battle and battle.kaMythicEcho and ball == "MASTER_BALL"
            and battle.game and battle.game.save then
          -- BagMenu has already consumed the selected ball at this point.
          -- Put exactly that ball back before the uncatchable vanilla branch.
          local save = battle.game.save
          save.inventory = type(save.inventory) == "table"
            and save.inventory or {}
          save.inventory[ball] = (save.inventory[ball] or 0) + 1
          appendOrder(save, ball)
          battle.kaMythicMasterBallReturned = true
        end
        return vanillaThrowBall(battle, ball, ...)
      end
    end

    if not BattleState._kaMythicSignalsResidualWrapped
        and type(BattleState.endOfTurn) == "function" then
      BattleState._kaMythicSignalsResidualWrapped = true
      local vanillaEndOfTurn = BattleState.endOfTurn
      BattleState.endOfTurn = function(battle, ...)
        if battle and battle.kaMythicEcho
            and battle.enemy and battle.enemy.mon then
          -- Status.residual directly subtracts Poison/Burn/Leech Seed HP;
          -- it does not pass through battle.damage.  Clear all three sources
          -- immediately before vanilla's residual sweep.
          battle.enemy.mon.status = nil
          battle.enemy.mon.toxicCounter = nil
          battle.enemy.toxicCounter = nil
          battle.enemy.leechSeeded = nil
          battle.enemy.shownStatus = nil
        end
        return vanillaEndOfTurn(battle, ...)
      end
    end

    if not BattleState._kaMythicSignalsApplyDamageWrapped
        and type(BattleState.applyDamage) == "function" then
      BattleState._kaMythicSignalsApplyDamageWrapped = true
      local vanillaApplyDamage = BattleState.applyDamage
      BattleState.applyDamage = function(battle, target, damage, ...)
        if battle and battle.kaMythicEcho
            and target == battle.enemy and target and target.mon
            and not target.substituteHP then
          damage = math.min(tonumber(damage) or 0,
            math.max(0, (tonumber(target.mon.hp) or 1) - 1))
        end
        return vanillaApplyDamage(battle, target, damage, ...)
      end
    end
    return true
  end

  M.state = state
  M.syncOwned = syncOwned
  M.activePool = function(game)
    game = game or M.game
    return activePool(syncOwned(game), game)
  end
  M.nativeKantoGrass = nativeKantoGrass
  M.echoLevel = echoLevel
  M.trueLevel = trueLevel
  M.badgeCount = badgeCount
  M.senderRepaired = senderRepaired
  M.constants = {
    ECHO_FIRST_DENOMINATOR = ECHO_FIRST_DENOMINATOR,
    ECHO_LATER_DENOMINATOR = ECHO_LATER_DENOMINATOR,
    TRUE_DENOMINATOR = TRUE_DENOMINATOR,
    RETRY_DENOMINATOR = RETRY_DENOMINATOR,
    RETRY_GUARANTEE = RETRY_GUARANTEE,
  }
  M.mythicals = copy(POOL)
  M.pending = function()
    if not pendingTransaction then return nil end
    return {
      kind = pendingTransaction.kind,
      expected = copy(pendingTransaction.expected),
      ticket = pendingTransaction.pending
        and copy(pendingTransaction.pending) or nil,
    }
  end
  return M
end
