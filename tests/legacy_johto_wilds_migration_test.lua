-- Regression for the 6.5.3 Legacy/New Game+ Johto-YES wild-distribution gap.
--
-- Run from the mod directory with the repository's pinned LuaJIT:
--   ../gen1recomp/.tools/luajit-src/src/luajit \
--     tests/legacy_johto_wilds_migration_test.lua

local modulePath = os.getenv("KANTO_ASCENDANT_MOD_DIR") or "."
local makeBoundary = assert(loadfile(modulePath .. "/johto_unleashed.lua"))()
local signalsStateModule =
  assert(loadfile(modulePath .. "/johto_signals_state.lua"))()
local makeSignals = assert(loadfile(modulePath .. "/johto_signals.lua"))()
local makeSignalsWilds =
  assert(loadfile(modulePath .. "/johto_signals_wilds.lua"))()

local assertions = 0
local function check(value, label)
  assertions = assertions + 1
  if not value then error("FAIL: " .. label, 2) end
end
local function eq(actual, expected, label)
  assertions = assertions + 1
  if actual ~= expected then
    error(("FAIL: %s\nexpected: %s\nactual:   %s")
      :format(label, tostring(expected), tostring(actual)), 2)
  end
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

local function same(actual, expected, path)
  path = path or "value"
  if type(actual) ~= type(expected) then
    error(("FAIL: %s type changed (%s ~= %s)")
      :format(path, type(actual), type(expected)), 2)
  end
  if type(actual) ~= "table" then
    if actual ~= expected then
      error(("FAIL: %s changed (%s ~= %s)")
        :format(path, tostring(actual), tostring(expected)), 2)
    end
    return
  end
  for key, value in pairs(expected) do
    same(actual[key], value, path .. "." .. tostring(key))
  end
  for key in pairs(actual) do
    if expected[key] == nil then
      error("FAIL: " .. path .. " gained key " .. tostring(key), 2)
    end
  end
end

local function canonicalBoundary()
  return {
    version = 1,
    active = true,
    irreversible = true,
    decision = "legacy_partner_catalog",
    activatedAt = 1723800000,
  }
end

local function runRulesFixture()
  return {
    version = 4,
    locked = true,
    poolDexMax = 251,
    seed = 251251,
    randomizer = { enabled = true, wilds = true, trainers = true,
      items = true, similarStrength = true },
    nuzlocke = { mode = "standard", dupes = true, blackout = "end",
      shinyOdds = 1024 },
    mappings = {
      species = { RATTATA = "SENTRET", PIDGEY = "HOOTHOOT" },
      items = { POTION = "SUPER_POTION" },
    },
    areas = {
      ROUTE_1 = { encountered = true, caught = true, species = "RATTATA" },
    },
    deaths = { { species = "PIDGEY", map = "ROUTE_1" } },
    encounterSerial = 19,
    finalRules = {
      poolDexMax = 251,
      seed = 251251,
      randomizer = { enabled = true, wilds = true, trainers = true,
        items = true, similarStrength = true },
      nuzlocke = { mode = "standard", dupes = true, blackout = "end",
        shinyOdds = 1024 },
      mappings = {
        species = { RATTATA = "SENTRET", PIDGEY = "HOOTHOOT" },
        items = { POTION = "SUPER_POTION" },
      },
    },
  }
end

local function signalsProgressFixture()
  return { version = 2, earlyJohto = {
    version = 2, mode = "KANTO_FIRST", modeChosen = false,
    receiverRepaired = false,
    questStarted = true, capsuleFound = false, capsuleTaken = true,
    capsuleOpened = true, boatmanBriefed = true,
    oakCallShown = true, oakReminderShown = true, oakReminderSteps = 211,
    pokedexSteps = 149, palletVisits = 3, capsuleTarget = 200,
    traces = { forest = true, coast = false, ember = true, stone = false },
    rarePity = { CHIKORITA = 255, TOTODILE = 17,
      CYNDAQUIL = 8, LARVITAR = 129 },
  }, resonance = { wins = 4, lastSpecies = "PIKACHU" },
    prismGrotto = { opened = true, visits = 2 } }
end

local function signalsProgress(owner)
  local root = copy(owner and owner.johto_signals or {})
  local early = type(root.earlyJohto) == "table" and root.earlyJohto or {}
  early.mode, early.modeChosen, early.legacyWildsAuthorized = nil, nil, nil
  return root
end

local function newHarness(config)
  config = config or {}
  local handlers, hooks = {}, {}
  local migrationEvents = 0
  local save = {
    version = config.edition or "red",
    player = { id = config.playerId or 25, name = "PLAYER" },
    flags = {}, inventory = {}, party = copy(config.party or {}), boxes = {},
    pokedex = copy(config.pokedex or { seen = {}, owned = {} }),
    modData = { kanto_ascendant = copy(config.owner or {}) },
  }
  local activeSave = save
  local function owner()
    activeSave.modData = type(activeSave.modData) == "table"
      and activeSave.modData or {}
    activeSave.modData.kanto_ascendant =
      type(activeSave.modData.kanto_ascendant) == "table"
      and activeSave.modData.kanto_ascendant or {}
    return activeSave.modData.kanto_ascendant
  end

  local events = {}
  function events:on(name, fn, priority)
    handlers[name] = handlers[name] or {}
    handlers[name][#handlers[name] + 1] = {
      fn = fn, priority = tonumber(priority) or 0,
    }
  end
  function events:emit(name, payload)
    if name == "mod.kanto_ascendant.johto_migration_changed" then
      migrationEvents = migrationEvents + 1
    end
    local rows = {}
    for _, row in ipairs(handlers[name] or {}) do rows[#rows + 1] = row end
    table.sort(rows, function(a, b) return a.priority > b.priority end)
    for _, row in ipairs(rows) do row.fn(payload) end
  end

  local mod = {
    id = "kanto_ascendant",
    exports = {},
    events = events,
    hooks = { wrap = function(_, name, fn) hooks[name] = fn end },
    options = { get = function(_, key)
      if key == "johto_wilds_integration" then return true end
      if key == "johto_signals_enable" then return true end
      return nil
    end },
    log = { info = function() end, warn = function() end,
      error = function() end },
  }
  mod.save = {
    get = function(_, key, fallback)
      local value = owner()[key]
      return value == nil and fallback or value
    end,
    set = function(_, key, value) owner()[key] = value end,
  }

  local writeAttempts = 0
  local successfulWrites = 0
  local writeReadyObservations = {}
  local failWrites = tonumber(config.failWrites) or 0
  local throwWrites = tonumber(config.throwWrites) or 0
  local disk = copy(save)
  local boundary, signals
  local game = {
    save = save,
    data = {
      pokemon = {
        MAGNEMITE = { dex = 81, types = { "ELECTRIC" } },
        MAGNETON = { dex = 82, types = { "ELECTRIC" } },
        HOUNDOUR = { dex = 228, types = { "DARK", "FIRE" } },
        SENTRET = { dex = 161, types = { "NORMAL" } },
      },
      moves = {
        BITE = { type = "NORMAL", category = "physical" },
        GUST = { type = "NORMAL", category = "physical" },
        SAND_ATTACK = { type = "NORMAL", category = "status" },
        KARATE_CHOP = { type = "NORMAL", category = "physical" },
      },
      encounters = {
        ROUTE_1 = { grass = { rate = 25, slots = {
          { species = "RATTATA", level = 4 },
        } } },
      },
    },
    overworld = { map = { id = "ROUTE_1" } },
  }
  if not config.noWriter then
    function game:writeSave()
      writeAttempts = writeAttempts + 1
      writeReadyObservations[#writeReadyObservations + 1] =
        signals and signals.legacyWildsReady(self) == true or false
      if throwWrites > 0 then
        throwWrites = throwWrites - 1
        error("fixture write exception")
      end
      if failWrites > 0 then
        failWrites = failWrites - 1
        return false
      end
      successfulWrites = successfulWrites + 1
      disk = copy(self.save)
      return true
    end
  end

  boundary = makeBoundary(mod, { johtoData = {
    species = { HOUNDOUR = { dex = 228 }, SENTRET = { dex = 161 } },
  } })
  mod.exports.beyondKanto = boundary
  local signalsState = signalsStateModule.create(mod)
  signals = makeSignals(mod, {
    state = signalsState,
    johtoBoundary = boundary,
    johtoData = { habitats = {
      SENTRET = { map = "ROUTE_1", terrain = "grass", level = 5 },
    } },
    activationOptions = false,
    startPolicyOptions = false,
    random = function(lo) return lo end,
    encounterLevels = {
      routeAverage = function() return 4 end,
      ordinaryLevelFromAverage = function() return 6 end,
    },
  })
  boundary.bindControllers({ signals = signals })

  local H = {
    mod = mod, game = game, boundary = boundary, signals = signals,
    signalsState = signalsState, save = save, hooks = hooks,
  }
  function H.owner() return owner() end
  function H.emit(name)
    events:emit(name, { game = game, save = game.save })
  end
  function H.roll()
    return signals.rollReplacement({ species = "RATTATA", level = 4 }, {
      mapId = "ROUTE_1", terrain = "grass", routeAverageLevel = 4,
      rng = function(lo) return lo end,
    })
  end
  function H.writeAttempts() return writeAttempts end
  function H.successfulWrites() return successfulWrites end
  function H.writeReadyObservations() return copy(writeReadyObservations) end
  function H.migrationEvents() return migrationEvents end
  function H.disk() return copy(disk) end
  function H.allowWrites()
    failWrites, throwWrites = 0, 0
  end
  return H
end

local function compatibleWilds(h, ownerName)
  local overworld = { map = { id = "ROUTE_1" }, player = { cellX = 1, cellY = 1 } }
  local logic = {
    ownerName = ownerName,
    activeMapId = "ROUTE_1",
    surfaceInfo = { surface = "GRASS", encounterKind = "grass" },
    spawns = {}, entities = {}, nextId = 1, originalTryCalls = 0,
  }
  logic.mod = { world = { overworld = function() return overworld end } }
  function logic:_encDef(mapId, game)
    return game and game.data and game.data.encounters[mapId]
  end
  function logic:trySpawn(game, incoming)
    self.originalTryCalls = self.originalTryCalls + 1
    local species, level = incoming.species, incoming.level
    if not species then
      local slot = game.data.encounters.ROUTE_1.grass.slots[1]
      species, level = slot.species, slot.level
    end
    local id = ownerName .. ":" .. tostring(self.nextId)
    self.nextId = self.nextId + 1
    local record = { id = id, species = species, level = level,
      state = "AVAILABLE" }
    local entity = { id = id, species = species }
    self.spawns[id], self.entities[id] = record, entity
    return record, nil, entity
  end
  function logic:_startBattle(record)
    record.state = "ENCOUNTER_STARTING"
    return true
  end
  function logic:_despawn(id)
    self.spawns[id], self.entities[id] = nil, nil
    return true
  end
  local wilds = {
    version = "1.12.2",
    logic = logic,
    lib = { require = function(name)
      if name ~= "encounter_pick" then error("unexpected fixture library") end
      return { pick = function(encDef, _, kind)
        local slot = encDef and encDef[kind or "grass"]
          and encDef[kind or "grass"].slots[1]
        return slot and { species = slot.species, level = slot.level,
          kind = kind or "grass" } or nil
      end }
    end },
  }
  return wilds, logic
end

local function installVisibleAdapter(h)
  local mythic = {
    cancelPending = function() return true end,
    rollReplacement = function(native) return native, nil end,
    cancel = function() return true end,
    commitWildsSpawn = function() return true end,
    applyBattleTicket = function() return true end,
  }
  local adapter = makeSignalsWilds(h.mod, {
    johtoSignals = h.signals,
    mythicSignals = mythic,
    encounterLevels = {
      routeAverage = function() return 4 end,
    },
    random = function(lo) return lo end,
  })
  return adapter, adapter.install(h.game, {
    random = function(lo) return lo end,
  })
end

-- Fresh Legacy/New Game+ YES must include the ordinary-wild authority in the
-- same durable write as the irreversible boundary and 251-species run rules.
for _, edition in ipairs({ "red", "blue", "yellow" }) do
  local owner = {
    beyond_kanto = { version = 1, active = false, decision = "fresh_gen1" },
    legacy_journey = { runId = edition .. ":2", partnerDexMax = 251 },
    run_rules = runRulesFixture(),
  }
  local h = newHarness({ edition = edition, owner = owner })
  h.boundary.sync(h.game, h.save, "fresh-legacy")
  h.signals.install(h.game, false)
  local beforeRules = copy(h.owner().run_rules)
  local changed, reason = h.boundary.activate(h.game, {
    decision = "legacy_partner_catalog",
  })
  check(changed and reason == "activated",
    edition .. " fresh Johto YES activates atomically")
  check(h.boundary.hasLegacyJohtoAuthority(h.save),
    edition .. " fresh YES exposes only the canonical durable authority")
  check(h.signals.legacyWildsReady(h.game),
    edition .. " fresh YES opens the ordinary Johto distribution")
  eq(h.signals.state().receiverRepaired, false,
    edition .. " fresh YES does not counterfeit Driftglass quest completion")
  eq(h.roll().species, "SENTRET",
    edition .. " fresh YES can replace a normal Route 1 encounter")
  eq(h.writeAttempts(), 1,
    edition .. " fresh YES needs only its existing atomic write")
  eq(h.writeReadyObservations()[1], false,
    edition .. " fresh YES stays encounter-closed while its writer runs")
  same(h.owner().run_rules, beforeRules,
    edition .. ".fresh.run_rules")
end

-- A persisted 6.5.3 YES receipt receives one idempotent 6.5.4 repair on load.
for _, edition in ipairs({ "red", "blue", "yellow" }) do
  local rules = runRulesFixture()
  local h = newHarness({ edition = edition, owner = {
    beyond_kanto = canonicalBoundary(),
    legacy_journey = { runId = edition .. ":3", partnerDexMax = 251 },
    run_rules = rules,
    johto_signals = signalsProgressFixture(),
  } })
  local beforeRules = copy(h.owner().run_rules)
  h.signals.install(h.game, false)
  local beforeSignalsProgress = signalsProgress(h.owner())
  check(h.boundary.hasLegacyJohtoAuthority(h.save),
    edition .. " 6.5.3 YES retains the canonical repair trigger")
  check(not h.boundary.hasLegacyJohtoWildsAuthority(h.save)
      and not h.signals.legacyWildsReady(h.game),
    edition .. " 6.5.3 YES stays closed before a durable repair receipt")
  eq(h.roll().species, "RATTATA",
    edition .. " pre-repair state cannot leak a Johto encounter")
  h.emit("game.ready")
  eq(h.writeAttempts(), 0,
    edition .. " provisional game.ready never migrates a save slot")
  check(not h.signals.legacyWildsReady(h.game),
    edition .. " provisional game.ready keeps ordinary Johto wilds closed")
  h.emit("save.loaded")
  check(h.signals.legacyWildsReady(h.game),
    edition .. " 6.5.3 YES is repaired during reload")
  eq(h.signals.state().receiverRepaired, false,
    edition .. " migration leaves receiver quest progress unchanged")
  eq(h.roll().species, "SENTRET",
    edition .. " migrated YES reaches the classic encounter path")
  eq(h.writeAttempts(), 1,
    edition .. " migrated YES persists exactly one repair")
  eq(h.writeReadyObservations()[1], false,
    edition .. " migrated YES stays encounter-closed while its writer runs")
  same(h.owner().run_rules, beforeRules,
    edition .. ".migrated.run_rules")
  same(signalsProgress(h.owner()), beforeSignalsProgress,
    edition .. ".migrated.signals_progress")
  local migration = h.owner().beyond_kanto.ordinaryWilds
  check(type(migration) == "table" and migration.version == 1
      and migration.authority == "legacy_partner_catalog",
    edition .. " repair records its narrow authority and schema")
  local eventCount = h.migrationEvents()
  h.emit("save.loaded")
  eq(h.writeAttempts(), 1,
    edition .. " repaired reload is write-idempotent")
  eq(h.migrationEvents(), eventCount,
    edition .. " repaired reload emits no duplicate invalidation")
  same(h.owner().run_rules, beforeRules,
    edition .. ".idempotent.run_rules")

  local persisted = h.disk()
  local reload = newHarness({ edition = persisted.version,
    owner = persisted.modData.kanto_ascendant })
  reload.emit("save.loaded")
  check(reload.signals.legacyWildsReady(reload.game),
    edition .. " durable repair survives a new controller/save reload")
  eq(reload.writeAttempts(), 0,
    edition .. " durable reload needs no migration rewrite")
  eq(reload.roll().species, "SENTRET",
    edition .. " durable reload retains the ordinary Johto distribution")
  same(reload.owner().run_rules, beforeRules,
    edition .. ".durable_reload.run_rules")
  same(signalsProgress(reload.owner()), beforeSignalsProgress,
    edition .. ".durable_reload.signals_progress")
end

-- Either half of an interrupted older attempt stays fail-closed until both
-- the boundary receipt and Signals flag are committed in the same retry.
for _, half in ipairs({ "signals-only", "receipt-only" }) do
  local boundary = canonicalBoundary()
  local signalsRoot = signalsProgressFixture()
  if half == "signals-only" then
    local early = signalsRoot.earlyJohto
    early.mode, early.modeChosen, early.legacyWildsAuthorized =
      "UNLEASHED", true, true
  else
    boundary.ordinaryWilds = { version = 1,
      authority = "legacy_partner_catalog", applied = true }
  end
  local h = newHarness({ edition = "blue", owner = {
    beyond_kanto = boundary,
    legacy_journey = { runId = "blue:" .. half, partnerDexMax = 251 },
    run_rules = runRulesFixture(), johto_signals = signalsRoot,
  } })
  h.signals.install(h.game, false)
  check(not h.signals.legacyWildsReady(h.game),
    half .. " interrupted state cannot expose ordinary Johto wilds")
  eq(h.roll().species, "RATTATA",
    half .. " interrupted state keeps the encounter distribution closed")
  local beforeEvents = h.migrationEvents()
  h.emit("save.loaded")
  check(h.signals.legacyWildsReady(h.game),
    half .. " interrupted state is completed transactionally on reload")
  eq(h.writeAttempts(), 1,
    half .. " interrupted state performs exactly one repair write")
  eq(h.migrationEvents(), beforeEvents + 1,
    half .. " completed authority invalidates live Wilds exactly once")
end

-- A write failure rolls back only the staged authority and receipt. The exact
-- canonical YES remains, so a later lifecycle pass retries without touching
-- Nuzlocke areas, deterministic mappings, the locked pool, or progress.
for _, failure in ipairs({ "return", "throw" }) do
  local h = newHarness({ edition = "yellow",
    failWrites = failure == "return" and 1 or 0,
    throwWrites = failure == "throw" and 1 or 0,
    owner = {
      beyond_kanto = canonicalBoundary(),
      legacy_journey = { runId = "yellow:4", partnerDexMax = 251 },
      run_rules = runRulesFixture(),
      johto_signals = signalsProgressFixture(),
    },
  })
  local beforeRules = copy(h.owner().run_rules)
  h.signals.install(h.game, false)
  local beforeSignalsProgress = signalsProgress(h.owner())
  h.emit("save.loaded")
  check(not h.signals.legacyWildsReady(h.game),
    failure .. " failure keeps the newly staged wild authority closed")
  eq(h.owner().beyond_kanto.ordinaryWilds, nil,
    failure .. " failure rolls back the migration receipt")
  eq(h.roll().species, "RATTATA",
    failure .. " failure cannot expose a non-durable Johto encounter")
  same(h.owner().run_rules, beforeRules,
    failure .. ".failed.run_rules")
  same(signalsProgress(h.owner()), beforeSignalsProgress,
    failure .. ".failed.signals_progress")
  local failedDisk = h.disk()
  eq(failedDisk.modData.kanto_ascendant.beyond_kanto.ordinaryWilds, nil,
    failure .. " failure writes no durable repair receipt")
  h.allowWrites()
  h.emit("save.loaded")
  check(h.signals.legacyWildsReady(h.game),
    failure .. " failure retries from canonical YES authority")
  eq(h.roll().species, "SENTRET",
    failure .. " retry opens the intended ordinary distribution")
  eq(h.writeAttempts(), 2,
    failure .. " retry performs one failed and one successful write")
  same(h.owner().run_rules, beforeRules,
    failure .. ".retried.run_rules")
  same(signalsProgress(h.owner()), beforeSignalsProgress,
    failure .. ".retried.signals_progress")

  local reload = newHarness({ edition = failedDisk.version,
    owner = failedDisk.modData.kanto_ascendant })
  reload.emit("save.loaded")
  check(reload.signals.legacyWildsReady(reload.game),
    failure .. " failed disk image repairs cleanly after a real reload")
  eq(reload.writeAttempts(), 1,
    failure .. " failed disk image retries exactly one migration write")
  same(reload.owner().run_rules, beforeRules,
    failure .. ".disk_reload.run_rules")
  same(signalsProgress(reload.owner()), beforeSignalsProgress,
    failure .. ".disk_reload.signals_progress")
end

-- The initial fresh YES write uses the same rollback/retry boundary as the
-- partner pool. A rejected write must expose neither general Johto nor its
-- ordinary distribution, and retry must retain every preselected run rule.
do
  local h = newHarness({ edition = "blue", failWrites = 1, owner = {
    beyond_kanto = { version = 1, active = false, decision = "fresh_gen1" },
    legacy_journey = { runId = "blue:FRESH-RETRY", partnerDexMax = 251 },
    run_rules = runRulesFixture(),
  } })
  h.boundary.sync(h.game, h.save, "fresh-write-failure")
  h.signals.install(h.game, false)
  local beforeRules = copy(h.owner().run_rules)
  local changed, reason = h.boundary.activate(h.game, {
    decision = "legacy_partner_catalog",
  })
  check(not changed and reason == "save_failed",
    "fresh Johto YES fails closed when its durable write is rejected")
  check(not h.boundary.isActive(h.save),
    "failed fresh YES restores the sealed generation boundary")
  check(not h.signals.legacyWildsReady(h.game),
    "failed fresh YES restores the closed ordinary-wild state")
  eq(h.owner().beyond_kanto.ordinaryWilds, nil,
    "failed fresh YES leaves no repair receipt")
  same(h.owner().run_rules, beforeRules, "fresh-failure.run_rules")
  h.allowWrites()
  changed, reason = h.boundary.activate(h.game, {
    decision = "legacy_partner_catalog",
  })
  check(changed and reason == "activated",
    "fresh Johto YES can retry after the rejected write")
  check(h.signals.legacyWildsReady(h.game),
    "successful fresh retry opens ordinary Johto wilds")
  same(h.owner().run_rules, beforeRules, "fresh-retry.run_rules")
end

-- The canonical path cannot report success without a persistence surface.
-- Legacy Starters owns the outer disk rollback; the boundary must still fail
-- closed so that caller can restore its already-staged run-rule transaction.
do
  local h = newHarness({ edition = "red", noWriter = true, owner = {
    beyond_kanto = { version = 1, active = false, decision = "fresh_gen1" },
    legacy_journey = { runId = "red:NO-WRITER", partnerDexMax = 251 },
    run_rules = runRulesFixture(),
  } })
  h.boundary.sync(h.game, h.save, "fresh-no-writer")
  h.signals.install(h.game, false)
  local beforeRules = copy(h.owner().run_rules)
  local changed, reason = h.boundary.activate(h.game, {
    decision = "legacy_partner_catalog",
  })
  check(not changed and reason == "save_failed",
    "fresh canonical YES requires an actual durable save writer")
  check(not h.boundary.isActive(h.save)
      and not h.signals.legacyWildsReady(h.game),
    "missing writer restores both boundary and ordinary wild authority")
  eq(h.writeAttempts(), 0, "missing writer performs no phantom save attempt")
  same(h.owner().run_rules, beforeRules, "missing-writer.run_rules")
end

-- Internal Wilds and a compatible external Wilds consume the same repaired
-- Signals pool. A missing or conflicting provider neither blocks persistence
-- nor gets replaced/mutated by the save migration; classic encounters retain
-- their own working path.
for _, ownerKind in ipairs({
  "no-provider", "internal", "compatible-external", "conflicting-external",
}) do
  local h = newHarness({ edition = "red", owner = {
    beyond_kanto = canonicalBoundary(),
    legacy_journey = { runId = "red:" .. ownerKind, partnerDexMax = 251 },
    run_rules = runRulesFixture(),
    johto_signals = signalsProgressFixture(),
  } })
  local internalWilds, internalLogic = compatibleWilds(h, "internal")
  local externalWilds, externalLogic = compatibleWilds(h, "external")
  local conflict = { version = "9.9-conflict", logic = {
    owner = "conflicting-overworld-mod",
  } }
  if ownerKind == "internal" then
    h.mod.exports.internalWilds = {
      source = "bundled", bundled = true, exports = internalWilds,
    }
    h.mod.find = function() return nil end
  elseif ownerKind == "compatible-external" then
    h.mod.exports.internalWilds = {
      source = "bundled", bundled = true, exports = internalWilds,
    }
    h.mod.find = function(id)
      if id == "overworld_wild_spawns" then
        return { id = id, version = "1.12.2", exports = externalWilds }
      end
    end
  elseif ownerKind == "conflicting-external" then
    h.mod.exports.internalWilds = {
      source = "external", bundled = false, exports = conflict,
    }
    h.mod.find = function(id)
      if id == "overworld_wild_spawns" then
        return { id = id, version = conflict.version, exports = conflict }
      end
    end
  else
    h.mod.find = function() return nil end
  end
  local conflictBefore = copy(conflict)
  -- Production binds the Wilds wrapper during game.ready, before CONTINUE
  -- adopts the selected save and emits save.loaded. Keep that exact order so
  -- this proves an already-live internal/external owner sees the migration.
  local adapter, installed, installReason = installVisibleAdapter(h)
  h.emit("save.loaded")
  check(h.signals.legacyWildsReady(h.game),
    ownerKind .. " owner matrix persists canonical repair")
  eq(h.writeAttempts(), 1,
    ownerKind .. " owner matrix uses one migration write")
  if ownerKind == "internal" then
    check(installed, "bundled internal Wilds accepts the repaired pool")
    local record = assert(internalLogic:trySpawn(h.game, {}))
    eq(record.species, "SENTRET",
      "bundled internal Wilds renders a repaired Johto proposal")
    eq(externalLogic.originalTryCalls, 0,
      "bundled ownership never touches an absent external provider")
  elseif ownerKind == "compatible-external" then
    check(installed, "compatible external Wilds accepts the repaired pool")
    local record = assert(externalLogic:trySpawn(h.game, {}))
    eq(record.species, "SENTRET",
      "compatible external Wilds renders a repaired Johto proposal")
    eq(internalLogic.originalTryCalls, 0,
      "compatible external ownership remains ahead of the bundled fallback")
  else
    check(not installed
        and installReason == "Compatible Wilds of Kanto API is not active",
      ownerKind .. " leaves the visible adapter safely inactive")
    eq(h.roll().species, "SENTRET",
      ownerKind .. " retains the repaired classic encounter path")
  end
  if ownerKind == "conflicting-external" then
    same(conflict, conflictBefore, "conflicting-owner")
    eq(h.mod.exports.internalWilds.source, "external",
      "migration never steals ownership from a conflicting external mod")
  end
  check(type(adapter.runtimeStatus()) == "table",
    ownerKind .. " adapter remains inspectable after owner resolution")
end

-- NO, later Driftglass activation, and heuristic old-save witnesses are not
-- Oak's durable Legacy YES and therefore may never receive this repair.
do
  local no = newHarness({ edition = "red", party = {
    { species = "HOUNDOUR", level = 20 },
  }, pokedex = { seen = { HOUNDOUR = true }, owned = { HOUNDOUR = true } },
    owner = {
      beyond_kanto = { version = 1, active = false,
        decision = "fresh_gen1" },
      legacy_journey = { runId = "red:NO", partnerDexMax = 151 },
      run_rules = runRulesFixture(),
    },
  })
  no.emit("save.loaded")
  check(not no.boundary.hasLegacyJohtoAuthority(no.save),
    "explicit NO remains authoritative despite imported Johto data")
  check(not no.signals.legacyWildsReady(no.game),
    "explicit NO receives no ordinary-wild repair")
  eq(no.writeAttempts(), 0, "explicit NO performs no migration write")
end

do
  local driftglass = newHarness({ edition = "blue", owner = {
    beyond_kanto = { version = 1, active = true, irreversible = true,
      decision = "driftglass_later" },
    legacy_journey = { runId = "blue:DRIFT", partnerDexMax = 151 },
    run_rules = runRulesFixture(),
  } })
  driftglass.emit("save.loaded")
  check(not driftglass.boundary.hasLegacyJohtoAuthority(driftglass.save),
    "later Driftglass activation is not reclassified as Legacy YES")
  check(not driftglass.signals.legacyWildsReady(driftglass.game),
    "later Driftglass activation keeps its receiver progression contract")
  eq(driftglass.writeAttempts(), 0,
    "later Driftglass activation performs no Legacy repair write")
end

do
  local inferred = newHarness({ edition = "yellow", party = {
    { species = "HOUNDOUR", level = 20 },
  }, pokedex = { seen = { HOUNDOUR = true }, owned = { HOUNDOUR = true } },
    owner = { run_rules = runRulesFixture() },
  })
  inferred.emit("save.loaded")
  check(inferred.boundary.isActive(inferred.save),
    "old-save compatibility may still open the general Johto boundary")
  eq(inferred.owner().beyond_kanto.decision, "migrated_active",
    "heuristic witness remains explicitly classified as an old-save migration")
  check(not inferred.boundary.hasLegacyJohtoAuthority(inferred.save),
    "imported mon and Pokédex rows are never canonical Legacy YES")
  check(not inferred.signals.legacyWildsReady(inferred.game),
    "heuristic old-save witness receives no Legacy ordinary-wild repair")
  eq(inferred.writeAttempts(), 0,
    "heuristic old-save witness performs no Legacy repair write")
end

print(("legacy_johto_wilds_migration_test: %d assertions passed")
  :format(assertions))
