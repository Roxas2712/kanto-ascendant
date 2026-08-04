-- Contract tests for the Wilds of Kanto 0.4.2 Johto Signals adapter.
--
-- Run from the mod directory:
--   ../gen1recomp/.tools/luajit-src/src/luajit \
--     tests/johto_signals_wilds_test.lua

local modulePath = os.getenv("KANTO_SIGNALS_MOD_DIR") or "."
local createAdapter =
  assert(loadfile(modulePath .. "/johto_signals_wilds.lua"))()

local assertions = 0
local function check(value, message)
  assertions = assertions + 1
  if not value then error("FAIL: " .. message, 2) end
end

local function eq(actual, expected, message)
  assertions = assertions + 1
  if actual ~= expected then
    error(("FAIL: %s\nexpected: %s\nactual:   %s")
      :format(message, tostring(expected), tostring(actual)), 2)
  end
end

local function eventsFixture()
  local handlers = {}
  local events = {}
  function events:on(name, fn, priority)
    handlers[name] = handlers[name] or {}
    handlers[name][#handlers[name] + 1] = {
      fn = fn,
      priority = priority or 0,
    }
  end
  local function emit(name, payload)
    local rows = {}
    for _, row in ipairs(handlers[name] or {}) do rows[#rows + 1] = row end
    table.sort(rows, function(a, b) return a.priority > b.priority end)
    local results = {}
    for _, row in ipairs(rows) do
      results[#results + 1] = { row.fn(payload), row.priority }
    end
    return results
  end
  return events, handlers, emit
end

local function gameFixture()
  return {
    data = {
      encounters = {
        ROUTE_1 = {
          grass = {
            rate = 25,
            slots = {
              { species = "PIDGEY", level = 3 },
              { species = "RATTATA", level = 4 },
            },
          },
        },
      },
    },
    save = {
      flags = { EVENT_GOT_POKEDEX = true },
      inventory = {},
      party = { { species = "BULBASAUR", level = 12 } },
      pokedex = { seen = {}, owned = {} },
      repelSteps = 0,
    },
  }
end

local function newHarness(config)
  config = config or {}
  local events, handlers, emit = eventsFixture()
  local logs = {}
  local mod = {
    events = events,
    log = {
      info = function(_, fmt, ...)
        logs[#logs + 1] = string.format(fmt, ...)
      end,
    },
  }

  local picker = { calls = 0 }
  function picker.pick(encDef, rng, kind)
    picker.calls = picker.calls + 1
    picker.lastDef = encDef
    picker.lastRng = rng
    picker.lastKind = kind
    if config.pickNil then return nil end
    local tableDef = encDef and encDef[kind or "grass"]
    local slot = tableDef and tableDef.slots and tableDef.slots[1]
    if not slot then return nil end
    return {
      species = slot.species,
      level = slot.level,
      kind = kind,
    }
  end

  local early = {
    rolls = 0,
    commits = 0,
    cancels = 0,
    mode = config.earlyMode or "native",
  }
  function early.rollWildsReplacement(native, ctx)
    early.rolls = early.rolls + 1
    early.lastNative = native
    early.lastCtx = ctx
    local output = native
    if early.mode == "special" or early.mode == "rare" then
      output = {
        species = "CHIKORITA",
        level = 18,
        kaProtected = true,
        kaEncounterSource = "johto_signals",
      }
    elseif early.mode == "none" then
      return native, nil
    end
    local transaction = {
      expectedSpecies = output.species,
      expectedLevel = output.level,
    }
    if early.mode == "rare" then
      transaction.rareHit = true
      transaction.rareSpecies = "CHIKORITA"
    end
    early.lastTransaction = transaction
    return output, transaction
  end
  function early.commitWildsSpawn(transaction, value)
    early.commits = early.commits + 1
    early.lastCommitValue = value
    if transaction.cancelled then return false, "cancelled" end
    if transaction.expectedSpecies ~= value.species
        or transaction.expectedLevel ~= value.level then
      transaction.cancelled = true
      return false, "mismatch"
    end
    transaction.committed = true
    early.stateChanges = (early.stateChanges or 0) + 1
    return true, transaction
  end
  function early.cancelWildsSpawn(transaction, reason)
    if not transaction or transaction.cancelled or transaction.committed then
      return false
    end
    early.cancels = early.cancels + 1
    transaction.cancelled = true
    transaction.cancelReason = reason
    return true
  end

  local mythic = {
    rolls = 0,
    commits = 0,
    cancels = 0,
    pendingCancels = 0,
    applies = 0,
    mode = config.mythicMode or "native",
  }
  function mythic.cancelPending()
    mythic.pendingCancels = mythic.pendingCancels + 1
    return true
  end
  function mythic.rollReplacement(out, encDef, ctx, game)
    mythic.rolls = mythic.rolls + 1
    mythic.lastInput = out
    mythic.lastDef = encDef
    mythic.lastCtx = ctx
    mythic.lastGame = game
    if out.kaProtected or out.kaEncounterSource
        or mythic.mode == "none" then
      return out, nil
    end
    local output = out
    local ticket
    if mythic.mode == "echo" then
      output = {
        species = "MEW",
        level = 60,
        kaProtected = true,
        kaEncounterSource = "mythic_signals",
        kaMythicKind = "echo",
      }
      ticket = {
        kind = "echo",
        species = "MEW",
        fleeAt = 2,
      }
    end
    local transaction = {
      expected = {
        species = output.species,
        level = output.level,
      },
      ticket = ticket,
      afterBound = ticket and ticket.species or nil,
    }
    mythic.lastTransaction = transaction
    return output, transaction
  end
  function mythic.commitWildsSpawn(transaction, species, level)
    mythic.commits = mythic.commits + 1
    if transaction.cancelled then return false, nil, "cancelled" end
    if transaction.expected.species ~= species
        or transaction.expected.level ~= level then
      transaction.cancelled = true
      return false, nil, "mismatch"
    end
    transaction.committed = true
    mythic.stateChanges = (mythic.stateChanges or 0) + 1
    -- Model Mythic Signals' replaceTable(after) semantics: an old no-hit
    -- transaction would erase a newer bound form if serialization failed.
    mythic.bound = transaction.afterBound
    return true, transaction.ticket,
      transaction.ticket and transaction.ticket.kind or "roll"
  end
  function mythic.cancel(transaction)
    if not transaction or transaction.cancelled or transaction.committed then
      return false
    end
    mythic.cancels = mythic.cancels + 1
    transaction.cancelled = true
    return true
  end
  function mythic.applyBattleTicket(battle, ticket)
    mythic.applies = mythic.applies + 1
    mythic.lastTicket = ticket
    battle.appliedTicket = ticket
    return true
  end

  local lind = config.withLind and {
    rolls = 0,
  } or nil
  if lind then
    function lind.rollHabitat(mapId, terrain, rng, fallbackLevel)
      lind.rolls = lind.rolls + 1
      lind.last = {
        mapId = mapId,
        terrain = terrain,
        rng = rng,
        fallbackLevel = fallbackLevel,
      }
      if config.lindSpecies then
        return { species = config.lindSpecies, level = 18 }
      end
      return nil
    end
  end

  local ow = {
    map = { id = "ROUTE_1" },
    player = { cellX = 1, cellY = 1 },
  }
  local logic = {
    activeMapId = "ROUTE_1",
    surfaceInfo = {
      surface = config.surface or "GRASS",
      encounterKind = config.encounterKind or "grass",
    },
    spawns = {},
    entities = {},
    nextId = 1,
  }
  logic.render = {
    invalidateAssetCache = function(_, species)
      logic.invalidated = species
    end,
  }
  logic.mod = {
    world = {
      overworld = function() return ow end,
    },
  }
  function logic:_encDef(mapId, game)
    self.encDefCalls = (self.encDefCalls or 0) + 1
    return game and game.data and game.data.encounters[mapId]
  end
  function logic:trySpawn(game, incoming)
    self.originalTryCalls = (self.originalTryCalls or 0) + 1
    self.lastIncoming = incoming
    if incoming.failSpawn then return nil, "no eligible tiles" end
    local species, level = incoming.species, incoming.level
    if not species then
      local native = picker.pick(
        self:_encDef(self.activeMapId, game),
        config.random or function(lo) return lo end,
        self.surfaceInfo.encounterKind)
      if not native then return nil, "rejected: no encounter data" end
      species, level = native.species, native.level
    end
    local id = "visible_" .. tostring(self.nextId)
    self.nextId = self.nextId + 1
    local record = {
      id = id,
      species = species,
      level = level,
      state = "AVAILABLE",
    }
    local entity = { id = id, species = species }
    self.spawns[id] = record
    self.entities[id] = entity
    return record, nil, entity
  end
  function logic:_despawn(id)
    local record = self.spawns[id]
    if record then record.state = "REMOVED" end
    self.spawns[id] = nil
    self.entities[id] = nil
    return true
  end
  function logic:_startBattle(record)
    self.originalStartCalls = (self.originalStartCalls or 0) + 1
    if self.startMode == "busy" then return false end
    record.state = "ENCOUNTER_STARTING"
    self:_despawn(record.id)
    if self.startMode == "queue-fail" then return false end
    self.queued = {
      species = record.species,
      level = record.level,
    }
    return true
  end

  local wilds = {
    version = "0.4.2",
    logic = logic,
    lib = {},
  }
  function wilds.lib.require(name)
    eq(name, "encounter_pick",
      "the adapter requests Wilds' exact public encounter_pick module")
    return picker
  end

  local game = gameFixture()
  game.mods = {
    exports = {
      overworld_wild_spawns = wilds,
    },
  }

  local rng = config.random or function(lo) return lo end
  local adapter = createAdapter(mod, {
    johtoSignals = early,
    mythicSignals = mythic,
    johtoResearch = lind,
    random = rng,
  })

  return {
    adapter = adapter,
    game = game,
    logic = logic,
    picker = picker,
    early = early,
    mythic = mythic,
    lind = lind,
    wilds = wilds,
    mod = mod,
    handlers = handlers,
    emit = emit,
    logs = logs,
  }
end

local function wildBattle(species, level)
  return {
    kind = "wild",
    enemy = {
      mon = {
        species = species,
        level = level,
      },
    },
  }
end

-- --------------------------------------------------------- hot-reload bind

do
  local first = newHarness({
    earlyMode = "special",
    mythicMode = "native",
  })
  first.adapter.install(first.game)
  local visibleBeforeReload =
    assert(first.logic:trySpawn(first.game, {}))
  eq(visibleBeforeReload.species, "CHIKORITA",
    "the first adapter owns the pre-reload visible proposal")
  local wrappedTry = first.logic.trySpawn
  local wrappedStart = first.logic._startBattle
  local wrappedDespawn = first.logic._despawn

  local reloaded = newHarness({
    earlyMode = "none",
    mythicMode = "echo",
  })
  local rebound, reason = reloaded.adapter.install(reloaded.game, {
    wilds = first.wilds,
  })
  eq(rebound, true,
    "a fresh adapter instance rebinds an already wrapped Wilds runtime")
  eq(reason, "rebound",
    "the hot-reload path reports its runtime rebind")
  eq(first.logic.trySpawn, wrappedTry,
    "hot reload preserves the stable trySpawn wrapper")
  eq(first.logic._startBattle, wrappedStart,
    "hot reload preserves the stable battle-start wrapper")
  eq(first.logic._despawn, wrappedDespawn,
    "hot reload preserves the stable despawn wrapper")
  eq(first.logic._kantoAscendantSignalsWildsAdapter.api,
    reloaded.adapter,
    "the stable marker points at the fresh adapter instance")
  eq(first.adapter.installed, false,
    "the superseded adapter is explicitly deactivated")
  eq(first.early.cancels, 1,
    "hot reload cancels the old visible Early-Johto transaction")
  eq(visibleBeforeReload._kaSignalsWilds, nil,
    "hot reload removes stale runtime bundles from visible entities")

  local afterReload =
    assert(first.logic:trySpawn(reloaded.game, {}))
  eq(afterReload.species, "MEW",
    "the stable wrapper dispatches through the fresh Mythic controller")
  eq(first.early.rolls, 1,
    "the superseded Early-Johto controller receives no post-reload roll")
  eq(reloaded.early.rolls, 1,
    "the fresh Early-Johto controller receives the post-reload roll")
  eq(first.mythic.rolls, 1,
    "the superseded Mythic controller receives no post-reload roll")
  eq(reloaded.mythic.rolls, 1,
    "the fresh Mythic controller owns the post-reload proposal")

  eq(first.logic:_startBattle(afterReload), true,
    "the rebound adapter queues the fresh visible proposal")
  reloaded.emit("battle.started", {
    battle = wildBattle("MEW", 60),
  })
  eq(reloaded.mythic.commits, 1,
    "the fresh battle.started handler commits the rebound transaction")
  eq(reloaded.mythic.applies, 1,
    "the fresh handler applies the rebound Mythic battle ticket")
  eq(first.mythic.commits, 0,
    "the superseded runtime cannot commit the post-reload battle")
end

-- ----------------------------------------------------------- API contract

do
  local h = newHarness()
  local missingGame = gameFixture()
  local ok, reason = h.adapter.install(missingGame)
  eq(ok, false, "install is harmless when Wilds is not active")
  eq(reason, "Wilds of Kanto 0.4.2 API is not active",
    "missing Wilds reports its exact required contract")
  eq(h.adapter.installed, false,
    "a rejected install never advertises active compatibility")
end

do
  local h = newHarness()
  h.wilds.lib.require = nil
  local ok, reason = h.adapter.install(h.game)
  eq(ok, false, "install rejects an export without lib.require")
  eq(reason, "Wilds of Kanto 0.4.2 API is not active",
    "the missing public library reports a stable reason")
end

do
  local h = newHarness()
  h.wilds.lib.require = function() return {} end
  local ok, reason = h.adapter.install(h.game)
  eq(ok, false, "install rejects an encounter_pick without pick()")
  eq(reason, "Wilds encounter_pick export is unavailable",
    "the missing picker reports a stable reason")
end

-- ---------------------------------------------------- one native slot pick

do
  local h = newHarness({ earlyMode = "special", withLind = true,
    lindSpecies = "NATU", mythicMode = "echo" })
  eq(h.adapter.install(h.game), true,
    "the real Wilds 0.4.2-shaped export installs")
  eq(h.adapter.wildsVersion, "0.4.2",
    "the active Wilds version remains inspectable")
  eq(h.adapter.EVENT_PRIORITY, 900,
    "the visible battle bridge precedes Mythic's generic priority 500")
  eq(h.handlers["battle.started"][1].priority, 900,
    "battle.started is registered at the public bridge priority")

  local wrappedTry = h.logic.trySpawn
  local wrappedStart = h.logic._startBattle
  eq(h.adapter.install(h.game), true,
    "installing the adapter twice is idempotent")
  eq(h.logic.trySpawn, wrappedTry,
    "a second install never nests trySpawn wrappers")
  eq(h.logic._startBattle, wrappedStart,
    "a second install never nests _startBattle wrappers")
  eq(h.adapter.runtimeStatus().installs, 1,
    "only the first install changes the Wilds instance")

  local record, spawnErr, entity = h.logic:trySpawn(h.game, {})
  check(record ~= nil, "a protected Early-Johto proposal materializes")
  eq(spawnErr, nil, "the three-value Wilds success contract is preserved")
  check(entity ~= nil, "the real third entity return is preserved")
  eq(h.picker.calls, 1,
    "an eligible visible spawn performs exactly one native encounter pick")
  eq(h.logic.originalTryCalls, 1,
    "the original Wilds trySpawn runs exactly once")
  eq(h.logic.lastIncoming.species, "CHIKORITA",
    "the final proposal reaches Wilds as an explicit species")
  eq(h.logic.lastIncoming.level, 18,
    "the final proposal keeps its authored level")
  eq(record.species, "CHIKORITA",
    "the visible entity uses the Early-Johto result")
  eq(record.kaEncounterSource, "johto_signals",
    "the visible record retains encounter ownership metadata")
  eq(entity.kaEncounterSource, "johto_signals",
    "the visible renderer entity retains encounter ownership metadata")
  eq(h.logic.invalidated, "CHIKORITA",
    "Wilds refreshes a late species asset before materializing it")
  eq(h.early.rolls, 1,
    "Early Johto receives the one native pick")
  eq(h.early.lastCtx.mapId, "ROUTE_1",
    "the adapter forwards the live Wilds map")
  eq(h.early.lastCtx.terrain, "grass",
    "the adapter translates Wilds' GRASS surface")
  eq(h.picker.lastKind, "grass",
    "the native pick uses Wilds' resolved encounter kind")
  eq(h.lind.rolls, 0,
    "Lind never double-replaces a protected Early-Johto output")
  eq(h.mythic.rolls, 1,
    "Mythic receives the protected result and can reject it safely")
  eq(h.mythic.lastInput.kaEncounterSource, "johto_signals",
    "Mythic sees the Early encounter-owner guard")
  eq(h.early.commits, 0,
    "merely rendering a visible species never advances Early state")
  eq(h.mythic.commits, 0,
    "merely rendering a visible species never advances Mythic state")

  h.logic:_despawn(record.id, true)
  eq(h.early.cancels, 1,
    "despawning an untouched visible species cancels its Early proposal")
  eq(h.early.stateChanges or 0, 0,
    "despawn never consumes Early pity")
  eq(h.mythic.stateChanges or 0, 0,
    "despawn never consumes Mythic pressure")
end

-- ---------------------------------------------------- exact battle commit

do
  local h = newHarness({ earlyMode = "native", mythicMode = "native" })
  eq(h.adapter.install(h.game), true, "native transaction harness installs")
  local record = assert(h.logic:trySpawn(h.game, {}))
  eq(record.species, "PIDGEY", "the native Wilds result stays native")
  eq(h.picker.calls, 1, "the native path still picks exactly once")
  eq(h.early.commits, 0, "no Early commit happens at spawn time")
  eq(h.mythic.commits, 0, "no Mythic commit happens at spawn time")

  eq(h.logic:_startBattle(record), true,
    "Wilds reports a successfully queued battle")
  eq(h.early.cancels, 0,
    "_startBattle's internal despawn does not cancel the queued proposal")
  eq(h.mythic.cancels, 0,
    "_startBattle's internal despawn preserves the Mythic proposal")
  local pending = h.adapter.runtimeStatus().pendingBattle
  eq(pending.species, "PIDGEY",
    "the exact queued species is held only in runtime")
  eq(pending.level, 3,
    "the exact queued level is held only in runtime")
  eq(h.early.commits, 0,
    "successful _startBattle alone is still not a save commit")

  local battle = wildBattle("PIDGEY", 3)
  h.emit("battle.started", { battle = battle })
  eq(h.early.commits, 1,
    "the exact battle.started calls Early.commitWildsSpawn once")
  eq(h.mythic.commits, 1,
    "the exact battle.started calls Mythic.commitWildsSpawn once")
  eq(h.early.stateChanges, 1,
    "the exact native battle advances Early pity once")
  eq(h.mythic.stateChanges, 1,
    "the exact native battle advances Mythic pressure once")
  eq(h.mythic.applies, 0,
    "a no-hit Mythic transaction has no battle ticket to apply")
  eq(h.adapter.runtimeStatus().pendingBattle, nil,
    "the pending bridge is consumed before event validation")
  check(h.mythic.pendingCancels >= 2,
    "global Mythic proposals are cleared at spawn and battle start")

  h.emit("battle.started", { battle = battle })
  eq(h.early.commits, 1,
    "a duplicate battle.started cannot commit Early twice")
  eq(h.mythic.commits, 1,
    "a duplicate battle.started cannot commit Mythic twice")
end

do
  local h = newHarness({ earlyMode = "native", mythicMode = "echo" })
  h.adapter.install(h.game)
  local record = assert(h.logic:trySpawn(h.game, {}))
  eq(record.species, "MEW", "a Mythic echo becomes the visible species")
  eq(record.level, 60, "the visible echo keeps its transactional level")
  eq(record.kaMythicKind, "echo",
    "the visible record carries only non-save Mythic metadata")
  eq(h.logic:_startBattle(record), true, "the echo battle queues")
  local battle = wildBattle("MEW", 60)
  h.emit("battle.started", { battle = battle })
  eq(h.early.commits, 1,
    "the bridge still calls Early.commitWildsSpawn for exact dispatch")
  eq(h.early.stateChanges or 0, 0,
    "a Mythic replacement does not consume the superseded Early pity roll")
  eq(h.mythic.stateChanges, 1,
    "the exact echo commits its Mythic transaction")
  eq(h.mythic.applies, 1,
    "the exact echo applies its battle ticket")
  eq(battle.appliedTicket.kind, "echo",
    "applyBattleTicket receives the authored echo ticket")
  eq(battle.appliedTicket.fleeAt, 2,
    "the echo's flee timing survives the visible-spawn bridge")
end

do
  local h = newHarness({ earlyMode = "native", mythicMode = "native" })
  h.adapter.install(h.game)
  local record = assert(h.logic:trySpawn(h.game, {}))
  h.logic:_startBattle(record)
  h.emit("battle.started", { battle = wildBattle("RATTATA", 3) })
  eq(h.early.commits, 0,
    "a different species never reaches Early.commitWildsSpawn")
  eq(h.mythic.commits, 0,
    "a different species never reaches Mythic.commitWildsSpawn")
  eq(h.early.cancels, 1,
    "a mismatching battle cancels the Early proposal")
  eq(h.mythic.cancels, 1,
    "a mismatching battle cancels the Mythic proposal")
  eq(h.early.stateChanges or 0, 0,
    "a species mismatch consumes no Early state")
  eq(h.mythic.stateChanges or 0, 0,
    "a species mismatch consumes no Mythic state")
end

-- Wilds 0.4.2 keeps several records in logic.spawns simultaneously.  A
-- saved 511/255 pity therefore needs one outstanding rare claim, not one
-- guaranteed rare result per visible entity.
do
  local h = newHarness({ earlyMode = "rare", mythicMode = "none" })
  h.adapter.install(h.game)

  local first = assert(h.logic:trySpawn(h.game, {}))
  eq(first.species, "CHIKORITA",
    "the first outstanding record reserves the guaranteed trace")
  eq(#h.adapter.runtimeStatus().rareClaims, 1,
    "one guaranteed species owns one visible claim")
  eq(h.adapter.runtimeStatus().rareClaims[1], "CHIKORITA",
    "the claim is keyed by the guaranteed species")

  local second = assert(h.logic:trySpawn(h.game, {}))
  eq(second.species, "PIDGEY",
    "a concurrent record cannot duplicate the reserved guarantee")
  eq(h.picker.calls, 2,
    "two outstanding records each use exactly one native pick")
  eq(h.early.rolls, 2,
    "both records may inspect the same live pity snapshot")
  eq(h.early.cancels, 1,
    "the duplicate guarantee transaction is cancelled immediately")
  eq(#h.adapter.runtimeStatus().rareClaims, 1,
    "the duplicate attempt cannot create a second claim")

  h.logic:_startBattle(second)
  h.emit("battle.started", { battle = wildBattle("PIDGEY", 3) })
  eq(h.early.commits, 0,
    "the unclaimed concurrent native battle cannot commit that pity")
  eq(h.early.stateChanges or 0, 0,
    "the unclaimed record consumes no saved rare state")
  eq(#h.adapter.runtimeStatus().rareClaims, 1,
    "the original visible guarantee remains reserved")

  h.logic:_despawn(first.id, true)
  eq(#h.adapter.runtimeStatus().rareClaims, 0,
    "despawning the guaranteed record releases its claim")
  eq(h.early.cancels, 2,
    "despawn cancels the original guaranteed transaction")

  local third = assert(h.logic:trySpawn(h.game, {}))
  eq(third.species, "CHIKORITA",
    "a released guarantee can be represented by a later record")
  eq(#h.adapter.runtimeStatus().rareClaims, 1,
    "the later record owns the only replacement claim")
  h.logic:_startBattle(third)
  h.emit("battle.started", { battle = wildBattle("CHIKORITA", 18) })
  eq(h.early.commits, 1,
    "only the one exact guaranteed battle reaches Early's commit seam")
  eq(h.early.stateChanges, 1,
    "the saved 511/255 pity is consumed exactly once")
  eq(#h.adapter.runtimeStatus().rareClaims, 0,
    "the committed guarantee releases its runtime claim")
end

-- Mythic transactions replace their whole saved snapshot on commit.  Unlike
-- Early pity increments, two concurrent snapshots cannot be merged safely:
-- serialize the entire visible Mythic proposal stream.
do
  local h = newHarness({ earlyMode = "none", mythicMode = "native" })
  h.adapter.install(h.game)

  local first = assert(h.logic:trySpawn(h.game, {}))
  local oldTransaction = first._kaSignalsWilds
    and first._kaSignalsWilds.mythic
  check(oldTransaction ~= nil,
    "the first visible record owns the one Mythic transaction")
  check(h.adapter.runtimeStatus().mythicClaim ~= nil,
    "the first Mythic snapshot is globally reserved")
  eq(h.mythic.rolls, 1,
    "the first visible record performs one Mythic roll")

  local second = assert(h.logic:trySpawn(h.game, {}))
  eq(second.species, "PIDGEY",
    "a second visible record remains on its native result")
  eq(h.mythic.rolls, 1,
    "no second Mythic roll occurs while a snapshot is outstanding")
  eq(second._kaSignalsWilds, nil,
    "the concurrent native record owns no stale Mythic snapshot")
  h.logic:_startBattle(second)
  h.emit("battle.started", { battle = wildBattle("PIDGEY", 3) })
  eq(h.mythic.commits, 0,
    "the unclaimed concurrent battle cannot advance Mythic pressure")
  eq(h.mythic.stateChanges or 0, 0,
    "the unclaimed concurrent battle changes no Mythic state")

  h.logic:_despawn(first.id, true)
  eq(oldTransaction.cancelled, true,
    "despawning the owner permanently cancels its old snapshot")
  eq(h.adapter.runtimeStatus().mythicClaim, nil,
    "despawn releases the global Mythic claim")

  h.mythic.mode = "echo"
  local third = assert(h.logic:trySpawn(h.game, {}))
  eq(third.species, "MEW",
    "a later record may roll a new Mythic result after release")
  eq(h.mythic.rolls, 2,
    "the released claim permits exactly one fresh Mythic roll")
  h.logic:_startBattle(third)
  h.emit("battle.started", { battle = wildBattle("MEW", 60) })
  eq(h.mythic.stateChanges, 1,
    "the fresh exact Mythic result commits once")
  eq(h.mythic.bound, "MEW",
    "the newer true/echo-shaped snapshot owns the modeled bound state")
  eq(h.adapter.runtimeStatus().mythicClaim, nil,
    "the exact commit releases the Mythic claim")

  local staleCommitted =
    h.mythic.commitWildsSpawn(oldTransaction, "PIDGEY", 3)
  eq(staleCommitted, false,
    "the cancelled old no-hit transaction can never commit later")
  eq(h.mythic.bound, "MEW",
    "an old no-hit snapshot cannot erase the newer bound state")
  eq(h.mythic.stateChanges, 1,
    "the stale commit attempt cannot change Mythic counters")
end

do
  local h = newHarness({ earlyMode = "native", mythicMode = "native" })
  h.adapter.install(h.game)
  local record = assert(h.logic:trySpawn(h.game, {}))
  h.logic:_startBattle(record)
  h.emit("battle.started", { battle = wildBattle("PIDGEY", 4) })
  eq(h.early.commits, 0,
    "the same species at the wrong level never commits Early state")
  eq(h.mythic.commits, 0,
    "the same species at the wrong level never commits Mythic state")
  eq(h.early.cancels, 1, "a level mismatch cancels Early")
  eq(h.mythic.cancels, 1, "a level mismatch cancels Mythic")
end

-- ------------------------------------------------------- aborted spawns

do
  local h = newHarness({ earlyMode = "native", mythicMode = "native" })
  h.adapter.install(h.game)
  local record, reason = h.logic:trySpawn(h.game, { failSpawn = true })
  eq(record, nil, "a rejected visible spawn stays rejected")
  eq(reason, "no eligible tiles", "the original rejection reason survives")
  eq(h.picker.calls, 1,
    "a rejected eligible attempt still makes only its one native pick")
  eq(h.early.cancels, 1,
    "a rejected materialization cancels Early's proposal")
  eq(h.mythic.cancels, 1,
    "a rejected materialization cancels Mythic's proposal")
  eq(h.early.commits, 0, "a rejected spawn never commits Early state")
  eq(h.mythic.commits, 0, "a rejected spawn never commits Mythic state")
end

do
  local h = newHarness({ earlyMode = "native", mythicMode = "native" })
  h.adapter.install(h.game)
  local record = assert(h.logic:trySpawn(h.game, {}))
  h.logic.startMode = "busy"
  eq(h.logic:_startBattle(record), false,
    "a busy Wilds runner rejects the first battle start")
  eq(h.logic.spawns[record.id], record,
    "a temporary start rejection leaves the entity available")
  eq(h.early.cancels, 0,
    "a retryable start rejection preserves Early's proposal")
  eq(h.mythic.cancels, 0,
    "a retryable start rejection preserves Mythic's proposal")
  eq(h.adapter.runtimeStatus().pendingBattle, nil,
    "a failed _startBattle never arms battle.started")

  h.logic.startMode = nil
  eq(h.logic:_startBattle(record), true,
    "the same visible entity can queue on a later retry")
  h.emit("battle.started", { battle = wildBattle("PIDGEY", 3) })
  eq(h.early.stateChanges, 1,
    "the later exact battle commits Early exactly once")
  eq(h.mythic.stateChanges, 1,
    "the later exact battle commits Mythic exactly once")
end

do
  local h = newHarness({ earlyMode = "native", mythicMode = "native" })
  h.adapter.install(h.game)
  local record = assert(h.logic:trySpawn(h.game, {}))
  h.logic.startMode = "queue-fail"
  eq(h.logic:_startBattle(record), false,
    "Wilds exposes a terminal queue failure")
  eq(h.logic.spawns[record.id], nil,
    "the queue-failed entity was removed by Wilds")
  eq(h.early.cancels, 1,
    "a terminal queue failure cancels Early")
  eq(h.mythic.cancels, 1,
    "a terminal queue failure cancels Mythic")
  eq(h.adapter.runtimeStatus().pendingBattle, nil,
    "a queue failure never arms battle.started")
end

-- ---------------------------------------- Repel/readiness/test/explicit

do
  local cases = {
    {
      name = "Repel",
      options = {},
      setup = function(game) game.save.repelSteps = 20 end,
      expectedPicks = 1,
    },
    {
      name = "readiness probe",
      options = { readinessProbe = true },
      expectedPicks = 1,
    },
    {
      name = "forced diagnostic",
      options = { force = true },
      expectedPicks = 1,
    },
    {
      name = "test spawn",
      options = { testSpawn = true, species = "RATTATA", level = 9 },
      expectedPicks = 0,
      expectedSpecies = "RATTATA",
    },
    {
      name = "explicit species",
      options = { species = "RATTATA", level = 7 },
      expectedPicks = 0,
      expectedSpecies = "RATTATA",
    },
  }

  for _, row in ipairs(cases) do
    local h = newHarness({ earlyMode = "special", mythicMode = "echo",
      withLind = true, lindSpecies = "NATU" })
    h.adapter.install(h.game)
    if row.setup then row.setup(h.game) end
    local record = assert(h.logic:trySpawn(h.game, row.options))
    eq(h.picker.calls, row.expectedPicks,
      row.name .. " uses only the original native pick when needed")
    eq(h.early.rolls, 0,
      row.name .. " creates no Early transaction")
    eq(h.mythic.rolls, 0,
      row.name .. " creates no Mythic transaction")
    eq(h.lind.rolls, 0,
      row.name .. " creates no Lind replacement")
    eq(h.early.commits, 0,
      row.name .. " consumes no Early pity")
    eq(h.mythic.commits, 0,
      row.name .. " consumes no Mythic pressure")
    if row.expectedSpecies then
      eq(record.species, row.expectedSpecies,
        row.name .. " preserves the caller's species")
    end
  end
end

-- ------------------------------------------- Lind protection / one pass

do
  local h = newHarness({ earlyMode = "native", mythicMode = "echo",
    withLind = true, lindSpecies = "NATU" })
  h.adapter.install(h.game)
  local record = assert(h.logic:trySpawn(h.game, {}))
  eq(h.picker.calls, 1,
    "the Lind path still starts with exactly one native pick")
  eq(h.lind.rolls, 1,
    "Lind receives exactly one chance after an unchanged Early result")
  eq(record.species, "NATU",
    "Lind's researched habitat becomes the visible species")
  eq(record.level, 18,
    "Lind's authored habitat level reaches Wilds")
  eq(record.kaEncounterSource, "johto_research",
    "the Lind result is protected from a second replacement")
  eq(h.logic.lastIncoming.species, "NATU",
    "the original Wilds call receives Lind's result explicitly")
  eq(h.mythic.rolls, 1,
    "Mythic receives the protected Lind output once")
  eq(h.mythic.lastInput.kaProtected, true,
    "Mythic can identify and preserve Lind's encounter")

  h.logic:_startBattle(record)
  h.emit("battle.started", { battle = wildBattle("NATU", 18) })
  eq(h.early.commits, 1,
    "the exact dispatcher calls Early's transactional seam")
  eq(h.early.stateChanges or 0, 0,
    "Lind superseding the native result consumes no Early pity")
  eq(h.mythic.commits, 0,
    "a protected Lind result owns no Mythic transaction")
end

-- ------------------------------------------------ map/terrain and reset

do
  local h = newHarness({ surface = "CAVE", encounterKind = "grass" })
  h.adapter.install(h.game)
  h.logic:trySpawn(h.game, {})
  eq(h.early.lastCtx.terrain, "indoor",
    "Wilds' CAVE surface maps to Early Johto's indoor terrain")
  eq(h.early.lastCtx.encounterKind, "grass",
    "caves keep Wilds' grass-table encounter kind")
  eq(h.adapter.terrainForSurface("WATER"), "water",
    "the public terrain helper maps Wilds water")
  eq(h.adapter.terrainForSurface("INTERIOR"), "indoor",
    "the public terrain helper maps Wilds interiors")
end

do
  local h = newHarness({ earlyMode = "native", mythicMode = "native" })
  h.adapter.install(h.game)
  local record = assert(h.logic:trySpawn(h.game, {}))
  h.logic:_startBattle(record)
  check(h.adapter.runtimeStatus().pendingBattle ~= nil,
    "the save-reset test begins with a runtime-only proposal")
  h.emit("save.loaded", {})
  eq(h.adapter.runtimeStatus().pendingBattle, nil,
    "loading a save clears the runtime-only visible proposal")
  eq(h.early.cancels, 1,
    "loading a save cancels Early's pending proposal")
  eq(h.mythic.cancels, 1,
    "loading a save cancels Mythic's pending proposal")
  eq(h.early.stateChanges or 0, 0,
    "loading a save never consumes Early state")
  eq(h.mythic.stateChanges or 0, 0,
    "loading a save never consumes Mythic state")
end

do
  local h = newHarness({ pickNil = true })
  h.adapter.install(h.game)
  local record, reason = h.logic:trySpawn(h.game, {})
  eq(record, nil, "an empty real encounter table yields no visible spawn")
  eq(reason, "rejected: no encounter data",
    "an empty native pick preserves Wilds' public rejection wording")
  eq(h.picker.calls, 1,
    "even an empty eligible attempt calls encounter_pick only once")
  eq(h.logic.originalTryCalls or 0, 0,
    "the adapter never asks original trySpawn to pick a second time")
  eq(h.early.rolls, 0,
    "an empty native pick creates no Early proposal")
  eq(h.mythic.rolls, 0,
    "an empty native pick creates no Mythic proposal")
end

print(("JOHTO SIGNALS WILDS PASS: %d/%d assertions")
  :format(assertions, assertions))
