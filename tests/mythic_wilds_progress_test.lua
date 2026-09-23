-- Contract tests for the Wilds of Kanto 1.7.1 Johto Signals adapter.
--
-- Run from the mod directory:
--   ../gen1recomp/.tools/luajit-src/src/luajit \
--     tests/johto_signals_wilds_test.lua

local modulePath = os.getenv("KANTO_SIGNALS_MOD_DIR") or "."
local createAdapter =
  assert(loadfile(modulePath .. "/johto_signals_wilds.lua"))()
local encounterLevels =
  assert(loadfile(modulePath .. "/johto_encounter_levels.lua"))()

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
  local habitatMapId = config.starterHabitat
    and (config.starterMapId or "KA_HABITAT_TURTWIG_PROTOTYPE")
    or "ROUTE_1"
  local habitatFamily = config.starterFamily or "TURTWIG"
  local events, handlers, emit = eventsFixture()
  local logs = {}
  local mod = {
    events = events,
    options = {
      get = function(_, key)
        if key == "johto_wilds_integration" then
          return config.integrationEnabled ~= false
        end
      end,
    },
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
    function lind.rollHabitat(
        mapId, terrain, rng, fallbackLevel, _, routeAverageLevel)
      lind.rolls = lind.rolls + 1
      lind.last = {
        mapId = mapId,
        terrain = terrain,
        rng = rng,
        fallbackLevel = fallbackLevel,
        routeAverageLevel = routeAverageLevel,
      }
      if config.lindSpecies then
        return {
          species = config.lindSpecies,
          level = (routeAverageLevel or fallbackLevel) + 2,
        }
      end
      return nil
    end
  end

  local ow = {
    map = { id = habitatMapId },
    player = { cellX = 1, cellY = 1 },
  }
  local logic = {
    activeMapId = habitatMapId,
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
  local waterSpawn = { ROD_TIER = { SURF = 0 } }
  function waterSpawn.pickForZone(_, zone)
    local native = picker.pick(
      logic:_encDef(logic.activeMapId, logic.activeGame),
      config.random or function(lo) return lo end, "water")
    if not native then return nil end
    return {
      species = native.species,
      speciesId = native.species,
      level = native.level,
      levelMin = native.level,
      levelMax = native.level,
      zone = zone,
    }
  end
  function logic:trySpawnWater(game, incoming)
    self.originalWaterCalls = (self.originalWaterCalls or 0) + 1
    self.lastWaterIncoming = incoming
    self.activeGame = game
    local selected = waterSpawn.pickForZone(game, { id = "pond" })
    self.activeGame = nil
    if not selected then return nil, "rejected: no water encounter data" end
    local id = "water_" .. tostring(self.nextId)
    self.nextId = self.nextId + 1
    local record = {
      id = id,
      species = selected.species or selected.speciesId,
      level = selected.level or selected.levelMin,
      state = "AVAILABLE",
    }
    local entity = { id = id, species = record.species }
    self.spawns[id], self.entities[id] = record, entity
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
    version = config.wildsVersion or "1.7.1",
    logic = logic,
    lib = {},
  }
  function wilds.lib.require(name)
    if name == "encounter_pick" then return picker end
    if name == "water_spawn" then return waterSpawn end
    error("unexpected Wilds library request: " .. tostring(name))
  end

  local game = gameFixture()
  if config.starterHabitat then
    game.data.encounters[habitatMapId] = {
      grass = {
        rate = 25,
        slots = { { species = "PIDGEY", level = 30 } },
      },
      water = {
        rate = 25,
        slots = { { species = "PSYDUCK", level = 31 } },
      },
    }
  end
  mod.find = function(id)
    if id == "overworld_wild_spawns" then
      return { id = id, version = wilds.version, exports = wilds }
    end
  end

  local rng = config.random or function(lo) return lo end
  local starterHabitats
  if config.starterHabitat then
    starterHabitats = {
      SOURCE = "starter_habitat_67",
      maps = { [habitatMapId] = { family = habitatFamily } },
      wilds = {},
      plans = 0,
      commits = 0,
      cancels = 0,
    }
    function starterHabitats.wilds.plan(native, _, ctx)
      starterHabitats.plans = starterHabitats.plans + 1
      starterHabitats.lastContext = ctx
      if config.starterInactive then
        return nil, nil, "habitat-inactive"
      end
      if config.starterUnavailable then
        return native, nil, "starter-family-unavailable"
      end
      local output = {
        species = config.starterSpecies or habitatFamily,
        level = native.level,
      }
      local transaction = {
        mapId = habitatMapId,
        outputSpecies = output.species,
        expectedLevel = output.level,
      }
      return output, transaction
    end
    function starterHabitats.wilds.commitStarted(transaction, ev)
      starterHabitats.commits = starterHabitats.commits + 1
      starterHabitats.lastCommit = { transaction = transaction, event = ev }
      local battle = ev and ev.battle
      local mon = battle and battle.enemy and battle.enemy.mon
      if ev.mapId ~= transaction.mapId or not mon
          or mon.species ~= transaction.outputSpecies
          or tonumber(mon.level) ~= tonumber(transaction.expectedLevel) then
        return false, "battle-mismatch"
      end
      transaction.committed = true
      battle.kaStarterHabitatFamily = habitatFamily
      return true, { sighted = true }
    end
    function starterHabitats.wilds.cancel(transaction, reason)
      if not transaction or transaction.committed or transaction.cancelled then
        return false
      end
      starterHabitats.cancels = starterHabitats.cancels + 1
      transaction.cancelled = true
      transaction.cancelReason = reason
      return true
    end
  end
  local visibleRules
  if config.visibleRuleSpecies then
    visibleRules = { maps = 0, remembers = 0, cancels = 0 }
    function visibleRules.mapVisibleWild(encounter, ctx)
      visibleRules.maps = visibleRules.maps + 1
      visibleRules.lastMapContext = ctx
      local out = {}
      for key, value in pairs(encounter) do out[key] = value end
      if not (ctx and (ctx.kaProtected or ctx.kaEncounterSource)) then
        out.species = config.visibleRuleSpecies
      end
      return out
    end
    function visibleRules.rememberVisibleWild(encounter, ctx)
      visibleRules.remembers = visibleRules.remembers + 1
      visibleRules.lastRememberContext = ctx
      local ticket = { species = encounter.species, active = true }
      visibleRules.lastTicket = ticket
      return encounter, ticket
    end
    function visibleRules.cancelVisibleWild(ticket)
      if not (ticket and ticket.active) then return false end
      visibleRules.cancels = visibleRules.cancels + 1
      ticket.active = false
      return true
    end
  end
  local worldEvents
  if config.worldEventSpecies then
    worldEvents={proposals=0}
    function worldEvents.proposeVisible(native,ctx,rng)
      worldEvents.proposals=worldEvents.proposals+1
      worldEvents.lastContext=ctx
      if rng(1,5)~=1 then return native end
      local out={}
      for key,value in pairs(native) do out[key]=value end
      out.species=config.worldEventSpecies
      out.kaProtected=true
      out.kaEncounterSource="world_event:johto_migration"
      out.kaWorldEventId="johto_migration"
      return out,{id="johto_migration",map=ctx.mapId,
        species=out.species,terrain=ctx.terrain}
    end
  end
  local adapter = createAdapter(mod, {
    johtoSignals = early,
    mythicSignals = mythic,
    johtoResearch = lind,
    encounterLevels = encounterLevels,
    random = rng,
    runRules = visibleRules,
    starterHabitats = not config.lateStarterBinding and starterHabitats or nil,
    worldEvents = worldEvents,
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
    visibleRules = visibleRules,
    starterHabitats = starterHabitats,
    worldEvents = worldEvents,
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


local function realHarness()
 local h=newHarness{earlyMode='native',random=function(_,max)return max end}
 h.mod.hooks={wrap=function()end};h.mod.save={get=function()end,set=function()end}
 local saved={echoRolls=80};local writes=0
 local M=assert(loadfile(modulePath..'/mythic_signals.lua'))()(h.mod,{state={section=function()return saved end,persist=function()writes=writes+1 end}})
 M.game=h.game
 for k in pairs(h.mythic)do h.mythic[k]=nil end
 for k,v in pairs(M)do h.mythic[k]=v end
 h.M=M;h.saved=saved;h.writes=function()return writes end
 assert(h.adapter.install(h.game))
 function h.fight(record)
  assert(h.logic:_startBattle(record))
  local battle=wildBattle(record.species,record.level)
  h.emit('battle.started',{battle=battle})
  return battle
 end
 return h
end
local h=realHarness()
local ignored=assert(h.logic:trySpawn(h.game,{}))
local rows={};for i=1,15 do rows[i]=assert(h.logic:trySpawn(h.game,{}))end
assert(h.saved.echoRolls==80 and h.writes()==0,'spawns must not count')
for i=15,1,-1 do h.fight(rows[i]) end
assert(h.saved.echoRolls==95,'15 actual wild battles must count while first entity remains unfought: '..h.saved.echoRolls)
assert(h.M.statusData(h.game).echoGuaranteeIn==417)
assert(h.writes()==15)
h.emit('battle.started',{battle=wildBattle(rows[1].species,rows[1].level)})
assert(h.writes()==15,'duplicate event counted')
h.logic:_despawn(ignored.id,true);assert(h.saved.echoRolls==95,'despawn counted')
print('MYTHIC_432_TO_417_PASS')
-- Concurrent bound/true hunts also count without replacing newer progress.
for _,phase in ipairs{'true','retry'}do
 local x=realHarness();x.saved.sealed=true;x.saved.echoes=3
 if phase=='retry'then x.saved.bound={species='MEW',level=60,retryRolls=0}end
 local a=assert(x.logic:trySpawn(x.game,{}));local b=assert(x.logic:trySpawn(x.game,{}))
 x.fight(b);x.fight(a)
 assert((phase=='retry'and x.saved.bound.retryRolls or x.saved.trueRolls)==2)
end
-- Guaranteed visible signal survives intervening ordinary battle progress,
-- and cannot be rendered twice concurrently.
local x=realHarness();x.saved.echoRolls=510
local ordinary=assert(x.logic:trySpawn(x.game,{}));x.fight(ordinary)
local hit=assert(x.logic:trySpawn(x.game,{}));assert(hit.species=='CELEBI' or hit.species=='MEW')
local deferred=assert(x.logic:trySpawn(x.game,{}));assert(deferred.species=='PIDGEY')
x.fight(deferred);local battle=x.fight(hit);assert(battle.kaMythicEcho)
assert(x.saved.echoRolls==0)
print('MYTHIC_CONCURRENT_PHASES_GUARANTEE_AND_EXACT_ONCE_PASS')
-- A progression change invalidates stale proposals rather than rewinding.
local z=realHarness();local stale=assert(z.logic:trySpawn(z.game,{}));z.saved.sealed=true;z.saved.echoes=3
z.fight(stale);assert(z.saved.sealed and z.saved.echoes==3 and z.writes()==0)
print('MYTHIC_STALE_PROGRESSION_PASS')
