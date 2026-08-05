-- Deterministic unit/regression coverage for Kanto Ascendant 6.0's optional
-- early Johto current.
--
-- Run from the mod directory:
--   ../gen1recomp/.tools/luajit-src/src/luajit tests/johto_signals_test.lua

local modulePath = os.getenv("KANTO_SIGNALS_MOD_DIR") or "."
local createSignals = assert(loadfile(modulePath .. "/johto_signals.lua"))()

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

local function contains(text, fragment, message)
  check(type(text) == "string" and text:find(fragment, 1, true) ~= nil,
    message .. "\nmissing fragment: " .. tostring(fragment)
      .. "\ntext: " .. tostring(text))
end

local function notContains(text, fragment, message)
  check(type(text) == "string" and text:find(fragment, 1, true) == nil,
    message .. "\nunexpected fragment: " .. tostring(fragment)
      .. "\ntext: " .. tostring(text))
end

local function sequence(values, fallback)
  local index = 0
  return function(a, b)
    index = index + 1
    local value = values[index]
    if value == nil then
      if fallback == "min" then return a end
      if type(fallback) == "number" then return fallback end
      return b
    end
    if value < a then return a end
    if value > b then return b end
    return value
  end
end

local HABITATS = {
  CHIKORITA = {
    map = "ROUTE_24", terrain = "grass", level = 18,
  },
  TOTODILE = {
    map = "SEAFOAM_ISLANDS_B2F", terrain = "indoor", level = 22,
  },
  CYNDAQUIL = {
    map = "POKEMON_MANSION_B1F", terrain = "indoor", level = 22,
  },
  LARVITAR = {
    map = "VICTORY_ROAD_3F", terrain = "indoor", level = 45,
  },
  SENTRET = {
    map = "ROUTE_1", terrain = "grass", level = 12,
  },
  HOOTHOOT = {
    map = "ROUTE_2", terrain = "grass", level = 14,
  },
  HOPPIP = {
    map = "ROUTE_5", terrain = "grass", level = 16,
  },
  SLUGMA = {
    map = "POKEMON_MANSION_B1F", terrain = "indoor", level = 30,
  },
  BAYLEEF = {
    map = "TEST_ROUTE", terrain = "grass", level = 25,
  },
  TYRANITAR = {
    map = "TEST_ROUTE", terrain = "grass", level = 70,
  },
  RAIKOU = {
    map = "TEST_ROUTE", terrain = "grass", level = 70,
  },
  CELEBI = {
    map = "TEST_ROUTE", terrain = "grass", level = 70,
  },
}

local function gameFixture(withDex)
  return {
    data = {
      pokemon = {
        CHIKORITA = { name = "CHIKORITA" },
        TOTODILE = { name = "TOTODILE" },
        CYNDAQUIL = { name = "CYNDAQUIL" },
        LARVITAR = { name = "LARVITAR" },
      },
    },
    save = {
      flags = withDex and { EVENT_GOT_POKEDEX = true } or {},
      inventory = {},
      party = { { species = "BULBASAUR", level = 5 } },
      pokedex = { seen = {}, owned = {} },
    },
    overworld = { map = { id = "PALLET_TOWN" } },
  }
end

local function newHarness(config)
  config = config or {}
  local root = { earlyJohto = config.state or {} }
  local backend = { persistCount = 0, sectionCount = 0 }
  function backend.section(name)
    backend.sectionCount = backend.sectionCount + 1
    eq(name, "earlyJohto", "the module requests only its public save section")
    return root.earlyJohto
  end
  function backend.persist()
    backend.persistCount = backend.persistCount + 1
  end

  local hooks = {}
  local handlers = {}
  local options = { values = config.options or {} }
  function options:get(key) return self.values[key] end

  local mod = {
    options = options,
    hooks = {},
    events = {},
  }
  function mod.hooks:wrap(name, fn, priority)
    hooks[name] = { fn = fn, priority = priority }
  end
  function mod.events:on(name, fn, priority)
    handlers[name] = handlers[name] or {}
    handlers[name][#handlers[name] + 1] = {
      fn = fn, priority = priority,
    }
  end

  local language = config.language or "en"
  local i18n = {}
  function i18n.text(en, de) return language == "de" and de or en end

  local callbacks = {
    oak = 0,
    onboarding = 0,
    repaired = 0,
  }
  local api = createSignals(mod, {
    state = backend,
    content = {
      johtoData = {
        habitats = config.habitats or HABITATS,
        germanNames = {
          CHIKORITA = "ENDIVIE",
          TOTODILE = "KARNIMANI",
          CYNDAQUIL = "FEURIGEL",
          LARVITAR = "LARVITAR",
        },
      },
    },
    i18n = i18n,
    startPolicy = config.startPolicy,
    random = config.random or sequence({}, "max"),
    onOakCall = function(game, text, done)
      callbacks.oak = callbacks.oak + 1
      callbacks.oakGame = game
      callbacks.oakText = text
      callbacks.finishOakCall = done
    end,
    onOnboardingRequired = function(game, policy, text, done)
      callbacks.onboarding = callbacks.onboarding + 1
      callbacks.onboardingGame = game
      callbacks.onboardingPolicy = policy
      callbacks.onboardingText = text
      callbacks.configure = done
    end,
    onReceiverRepaired = function(_, source)
      callbacks.repaired = callbacks.repaired + 1
      callbacks.repairSource = source
    end,
  })

  local function emit(name, event)
    for _, row in ipairs(handlers[name] or {}) do row.fn(event or {}) end
  end

  return {
    api = api,
    root = root,
    state = root.earlyJohto,
    backend = backend,
    hooks = hooks,
    handlers = handlers,
    callbacks = callbacks,
    emit = emit,
    setLanguage = function(value) language = value end,
  }
end

-- ------------------------------------------------------ discovery cadence

do
  local completed = newHarness({
    state = {
      version = 1,
      capsuleFound = true,
      questStarted = true,
      receiverRepaired = false,
    },
  })
  completed.api.state()
  eq(completed.state.version, 2,
    "public 6.0 Signals saves migrate to the staged capsule schema")
  eq(completed.state.capsuleTaken, true,
    "a completed 6.0 shore interaction preserves capsule ownership")
  eq(completed.state.capsuleOpened, true,
    "a completed 6.0 shore interaction preserves its opened capsule")
  eq(completed.state.boatmanBriefed, true,
    "a completed 6.0 field quest never loses Driftglass travel")

  local waiting = newHarness({
    state = {
      version = 1,
      capsuleTarget = 768,
      pokedexSteps = 300,
      capsuleAvailable = false,
    },
  })
  local game = gameFixture(true)
  waiting.api.install(game)
  eq(waiting.state.capsuleTarget, 200,
    "an oversized public 6.0 discovery target is clamped to 200")
  waiting.api.onStep(game, { game = game, mapId = "ROUTE_1" })
  eq(waiting.callbacks.oak, 1,
    "an upgraded save already beyond 200 steps receives Oak's call")
  eq(waiting.state.capsuleAvailable, true,
    "Oak's upgrade call places the physical capsule on the coast")
end

do
  local h = newHarness({ random = sequence({ 200 }, "max") })
  local game = gameFixture(false)
  h.api.install(game)

  for _ = 1, 250 do
    h.api.onStep(game, { game = game, mapId = "ROUTE_1" })
  end
  eq(h.state.capsuleTarget, nil,
    "steps before the Pokédex do not start Oak's hidden timer")
  eq(h.callbacks.oak, 0,
    "Oak never calls before starter plus Pokédex")

  game.save.flags.EVENT_GOT_POKEDEX = true
  for step = 1, 199 do
    h.api.onStep(game, { game = game, mapId = "ROUTE_1" })
    eq(h.api.capsuleReady(), false,
      "the exact 200-step maximum remains hidden through step 199")
  end
  eq(h.callbacks.oak, 0, "Oak has not called before the target")
  h.api.onStep(game, { game = game, mapId = "ROUTE_1" })
  eq(h.state.pokedexSteps, 200,
    "the initial discovery counter reaches its maximum at 200")
  eq(h.api.capsuleReady(), true,
    "the capsule becomes physically available by step 200")
  eq(h.callbacks.oak, 1, "the first Oak call occurs at the target")
  contains(h.callbacks.oakText, "help you complete\nthe POKéDEX",
    "Oak explains how the shore find may help the Pokédex")
  h.callbacks.finishOakCall()
  eq(h.state.oakCallShown, true, "the first call persists")
  eq(h.state.capsuleAvailable, true, "the shore object is now visible")

  for _ = 1, 399 do
    h.api.onStep(game, { game = game, mapId = "ROUTE_2" })
  end
  eq(h.callbacks.oak, 1, "the reminder waits through step 399")
  h.api.onStep(game, { game = game, mapId = "ROUTE_2" })
  eq(h.callbacks.oak, 2, "exactly one reminder occurs at step 400")
  contains(h.callbacks.oakText, "checked\nPALLET coast",
    "the one reminder points back to Pallet's coast")
  for _ = 1, 800 do
    h.api.onStep(game, { game = game, mapId = "ROUTE_3" })
  end
  eq(h.callbacks.oak, 2, "no third Oak call is ever scheduled")
end

do
  local h = newHarness({ random = sequence({ 1 }, "min") })
  local game = gameFixture(true)
  h.api.install(game)
  h.api.onStep(game, { game = game, mapId = "ROUTE_1" })
  eq(h.state.pokedexSteps, 1,
    "the configured minimum can call Oak after the first eligible step")
  eq(h.api.capsuleReady(), true,
    "the one-step target makes the physical capsule available")
  eq(h.callbacks.oak, 1, "the minimum target emits Oak's first call")
  notContains(h.api.objective(game), "1",
    "the hidden target is never exposed by the quest objective")
end

do
  local h = newHarness()
  local game = gameFixture(true)
  h.api.install(game)
  h.state.capsuleAvailable = true
  h.state.oakCallShown = true
  local ok, reason, declineText = h.api.inspectCapsule(false, game)
  eq(ok, false, "declining the capsule remains a non-completion")
  eq(reason, "declined", "declining reports its authored reason")
  contains(declineText, "remains in the\ndriftwood",
    "declining explains that the physical object remains")
  eq(h.api.capsuleVisible(), true,
    "declining leaves the capsule visible on the coast")

  local accepted, acceptedReason, takenText =
    h.api.inspectCapsule(true, game)
  eq(accepted, true,
    "accepting after an earlier decline takes the capsule")
  eq(acceptedReason, "taken",
    "the physical pickup reaches the sealed-item stage")
  contains(takenText, "DARK CAPSULE",
    "pickup grants the authored quest item")
  eq(h.state.capsuleTaken, true, "capsule pickup persists")
  eq(h.state.capsuleFound, false,
    "taking the capsule does not silently open it")
  eq(h.api.capsuleVisible(), false,
    "taking the capsule removes its physical object")
  eq(h.state.oakReminderShown, true,
    "taking the capsule cancels the one pending reminder")

  local postponed, postponedReason, postponedText =
    h.api.openCapsule(false, game)
  eq(postponed, false, "opening can be postponed")
  eq(postponedReason, "postponed", "postpone stage is explicit")
  contains(postponedText, "JOHTO SIGNALS",
    "postponing points to the menu action")
  eq(h.state.capsuleOpened, false, "postponing preserves the sealed item")

  local opened, openedReason, openedText =
    h.api.openCapsule(true, game)
  eq(opened, true, "the quest item can be opened later")
  eq(openedReason, "opened", "opening has its own state")
  contains(openedText, "Coordinates are",
    "opening reveals the boatman's coordinate clue")
  eq(h.state.capsuleFound, true,
    "legacy capsuleFound is written only after opening")
  eq(h.state.questStarted, true,
    "opening starts the field quest")

  local briefed, briefReason, briefText =
    h.api.onBoatmanCoordinates(game)
  eq(briefed, true, "the opened capsule can brief the boatman")
  eq(briefReason, "briefed", "boatman briefing has an explicit stage")
  contains(briefText, "DRIFTGLASS POST",
    "the boatman identifies the destination")
  eq(h.state.boatmanBriefed, true,
    "travel permission persists only after showing coordinates")

  local savePriority
  for _, row in ipairs(h.handlers["save.loaded"] or {}) do
    savePriority = math.max(savePriority or row.priority, row.priority)
  end
  eq(savePriority, 300,
    "Early resets its slot cache before content refreshes Pallet travel")
end

-- ------------------------------------------------------- receiver and UX

do
  local h = newHarness()
  local game = gameFixture(true)
  h.api.install(game)

  local ok, reason = h.api.setMode(game, "WANDERWAVES")
  eq(ok, false, "mode changes are blocked before receiver repair")
  eq(reason, "receiver-locked", "locked mode changes explain their gate")
  ok, reason = h.api.scanTrace(game, "VIRIDIAN_FOREST")
  eq(ok, false, "trace scans are blocked before receiver repair")
  eq(reason, "receiver-locked", "locked scans explain their gate")
  ok, reason = h.api.onResearcherRepair(game)
  eq(ok, false, "a researcher cannot repair an unseen capsule")
  eq(reason, "capsule-missing", "repair reports the missing source capsule")

  h.state.capsuleAvailable = true
  h.api.inspectCapsule(true, game)
  h.api.openCapsule(true, game)
  h.api.onBoatmanCoordinates(game)
  ok, reason, text = h.api.onResearcherRepair(game)
  eq(ok, true, "the discovered capsule enables researcher repair")
  eq(reason, "repaired", "repair reports its story stage")
  eq(h.state.mode, "KANTO_FIRST",
    "repair defaults to Kanto First rather than silently enabling Johto")
  eq(h.state.modeChosen, false,
    "repair still requires a conscious current choice")
  contains(text, "Foreign pollen",
    "the researcher identifies the foreign residue")
  contains(text, "How far should",
    "repair leads naturally into the current choice")
  notContains(text, "%",
    "the story dialogue leaves exact rates to the details page")

  ok, reason = h.api.setMode(game, "WANDERWAVES")
  eq(ok, true, "the repaired receiver accepts Wanderwaves")
  eq(reason, "mode-set", "a successful mode choice is explicit")
  eq(h.state.modeChosen, true, "the conscious receiver choice persists")
  eq(h.state.mode, "WANDERWAVES", "the public mode ID is stable")
  check(h.state.waveIndex >= 1,
    "the first Wanderwave is initialized only after the conscious choice")
end

do
  local h = newHarness({
    startPolicy = "unleashed",
    state = {},
  })
  local game = gameFixture(false)
  h.api.install(game)
  eq(h.state.receiverRepaired, false,
    "a launcher policy never silently repairs the receiver")
  eq(h.state.capsuleFound, false,
    "a launcher policy never silently skips the story")
  eq(h.callbacks.onboarding, 1,
    "the launcher policy produces exactly one authored onboarding request")
  eq(h.callbacks.onboardingPolicy, "UNLEASHED",
    "the authored onboarding names the requested policy")

  local ok, reason = h.api.completeOnboarding(true, "UNLEASHED", game)
  eq(ok, true, "explicit onboarding acceptance may initialize from start")
  eq(reason, "configured", "accepted onboarding reports configuration")
  eq(h.state.receiverRepaired, true,
    "only accepted onboarding repairs the from-start receiver")
  eq(h.state.mode, "UNLEASHED",
    "accepted onboarding applies the requested public mode")
  eq(h.state.onboardingComplete, true,
    "the from-start onboarding is persistently one-time")
  eq(h.callbacks.repairSource, "onboarding",
    "content receives the authored onboarding repair source")
  ok, reason = h.api.completeOnboarding(true, "WANDERWAVES", game)
  eq(ok, false, "the one-time onboarding cannot be replayed")
  eq(reason, "already-complete", "a replay reports its stable reason")
end

do
  local h = newHarness({ startPolicy = "waves" })
  local game = gameFixture(false)
  h.api.install(game)
  local ok, reason = h.api.completeOnboarding(false, "WANDERWAVES", game)
  eq(ok, true, "declining the authored onboarding is a valid choice")
  eq(reason, "field-quest", "decline returns to the ordinary field quest")
  eq(h.state.receiverRepaired, false,
    "declining onboarding cannot activate encounters")
  eq(h.state.startPolicy, "quest",
    "declining onboarding preserves the discoverable field quest")
end

-- ------------------------------------------------------- primal trace UX

do
  local h = newHarness()
  local game = gameFixture(true)
  h.api.install(game)
  h.state.capsuleAvailable = true
  h.api.inspectCapsule(true, game)
  h.api.openCapsule(true, game)
  h.api.onBoatmanCoordinates(game)
  h.api.onResearcherRepair(game)
  h.api.setMode(game, "UNLEASHED")

  local ok, reason, text = h.api.scanTrace(game, "ROUTE_1")
  eq(ok, false, "an unrelated habitat cannot unlock a primal trace")
  eq(reason, "weak-echo", "an unrelated scan yields only a regional clue")
  contains(text, "deep Viridian\nForest",
    "the locked trace clue names a region, not a species")
  notContains(text, "CHIKORITA",
    "a locked trace never spoils the species name")

  local species
  ok, reason, text, species =
    h.api.scanTrace(game, "VIRIDIAN_FOREST")
  eq(ok, true, "the forest trace unlocks independently")
  eq(reason, "trace-recorded", "the forest trace reports its new state")
  eq(species, "CHIKORITA", "the controller receives the unlocked base ID")
  eq(h.state.traces.forest, true, "the forest trace persists")
  eq(game.save.pokedex.seen.CHIKORITA, nil,
    "scanning a trace does not mark its species seen")
  contains(text, "???",
    "the trace result keeps the species hidden before a real sighting")
  notContains(text, "CHIKORITA",
    "the English species name stays hidden before a real sighting")
  contains(h.api.status(game), "???",
    "the status page follows the real Dex rather than trace state")

  game.save.pokedex.seen.CHIKORITA = true
  contains(h.api.status(game), "CHIKORITA",
    "a real Dex sighting reveals the English trace signature")
  h.setLanguage("de")
  contains(h.api.status(game), "ENDIVIE",
    "a real Dex sighting reveals the localized German name")
  contains(h.api.status(game), "10 PROZ",
    "German status uses the requested PROZ notation")
  notContains(h.api.status(game), "%",
    "German status never uses a percent glyph")
end

-- -------------------------------------------------- exact encounter odds

local function activeWaveHarness(strong)
  local h = newHarness({
    state = {
      capsuleFound = true,
      receiverRepaired = true,
      modeChosen = true,
      mode = "WANDERWAVES",
      waveIndex = 1,
      waveSteps = 500,
      strongSignal = strong == true,
      traces = {},
      rarePity = {},
    },
  })
  local game = gameFixture(true)
  h.api.install(game)
  return h, game
end

do
  local h, game = activeWaveHarness(false)
  local native = { species = "RATTATA", level = 3, nativeTag = "kept" }
  local hit = h.api.rollReplacement(native, {
    mapId = "ROUTE_1", terrain = "grass",
    rng = sequence({ 2, 1 }, "max"),
  })
  eq(hit.species, "SENTRET",
    "normal Wanderwaves include a roll of exactly 2 in 100")
  eq(hit.level, 12, "the replacement uses its authored habitat level")
  eq(hit.nativeTag, "kept",
    "replacement preserves unrelated native encounter metadata")
  eq(hit.kaProtected, true,
    "an actual Early Johto replacement is protected from outer mythic hooks")
  eq(hit.kaEncounterSource, "johto_signals",
    "an actual replacement identifies its encounter source")

  local miss = h.api.rollReplacement(native, {
    mapId = "ROUTE_1", terrain = "grass",
    rng = sequence({ 3 }, "max"),
  })
  eq(miss, native,
    "normal Wanderwaves exclude a roll of 3 in 100")
  eq(miss.kaProtected, nil,
    "an unchanged native roll never receives a Johto protection marker")
end

do
  local h = activeWaveHarness(true)
  local native = { species = "RATTATA", level = 3 }
  local hit = h.api.rollReplacement(native, {
    mapId = "ROUTE_1", terrain = "grass",
    rng = sequence({ 4, 1 }, "max"),
  })
  eq(hit.species, "SENTRET",
    "a strong Wanderwave includes a roll of exactly 4 in 100")
  local miss = h.api.rollReplacement(native, {
    mapId = "ROUTE_1", terrain = "grass",
    rng = sequence({ 5 }, "max"),
  })
  eq(miss, native,
    "a strong Wanderwave excludes a roll of 5 in 100")
end

do
  local h = newHarness({
    state = {
      capsuleFound = true,
      receiverRepaired = true,
      modeChosen = true,
      mode = "UNLEASHED",
      traces = {},
      rarePity = {},
    },
  })
  local game = gameFixture(true)
  h.api.install(game)
  local native = { species = "RATTATA", level = 3 }
  local hit = h.api.rollReplacement(native, {
    mapId = "ROUTE_1", terrain = "grass",
    rng = sequence({ 10, 1 }, "max"),
  })
  eq(hit.species, "SENTRET",
    "Unleashed includes a roll of exactly 10 in 100")
  local miss = h.api.rollReplacement(native, {
    mapId = "ROUTE_1", terrain = "grass",
    rng = sequence({ 11 }, "max"),
  })
  eq(miss, native, "Unleashed excludes a roll of 11 in 100")
end

-- ----------------------------------------- transactional rare-species pity

do
  local h, game = activeWaveHarness(false)
  h.state.traces.forest = true
  h.state.rarePity.CHIKORITA = 0
  local native = { species = "ODDISH", level = 14 }
  local context = {
    mapId = "ROUTE_24", terrain = "grass",
    rng = sequence({}, "max"),
  }

  for attempt = 1, 511 do
    local out = h.api.rollReplacement(native, context)
    eq(out, native,
      "Wanderwave rare pity does not fire before attempt " .. 512)
    eq(h.state.rarePity.CHIKORITA, attempt - 1,
      "a roll alone never advances Wanderwave rare pity")
    local committed = h.api.commitCandidate(out)
    eq(committed, true,
      "the matching native battle commits eligible rare attempt " .. attempt)
    eq(h.state.rarePity.CHIKORITA, attempt,
      "matching battle.started advances Wanderwave rare pity")
  end

  local guaranteed = h.api.rollReplacement(native, context)
  eq(guaranteed.species, "CHIKORITA",
    "the 512th eligible Wanderwave encounter is guaranteed")
  eq(guaranteed.level, 18,
    "the guaranteed Chikorita uses its habitat level")
  eq(h.state.rarePity.CHIKORITA, 511,
    "the guaranteed roll does not reset pity before battle.started")
  h.api.commitCandidate(guaranteed)
  eq(h.state.rarePity.CHIKORITA, 0,
    "the matching guaranteed battle resets pity")
  eq(game.save.pokedex.seen.CHIKORITA, nil,
    "candidate commit still leaves Dex sighting to the real battle engine")
end

do
  local h = newHarness({
    state = {
      capsuleFound = true,
      receiverRepaired = true,
      modeChosen = true,
      mode = "UNLEASHED",
      traces = { ember = true },
      rarePity = { CYNDAQUIL = 255 },
    },
  })
  local game = gameFixture(true)
  h.api.install(game)
  local native = { species = "KOFFING", level = 30 }
  local out = h.api.rollReplacement(native, {
    mapId = "POKEMON_MANSION_B1F", terrain = "indoor",
    rng = sequence({}, "max"),
  })
  eq(out.species, "CYNDAQUIL",
    "the 256th eligible Unleashed encounter is guaranteed")
  eq(h.state.rarePity.CYNDAQUIL, 255,
    "the 256 guarantee is transactional before battle.started")
  h.emit("battle.started", {
    kind = "wild",
    species = "CYNDAQUIL",
    battle = {
      kind = "wild",
      enemy = { mon = { species = "CYNDAQUIL", level = out.level } },
    },
  })
  eq(h.state.rarePity.CYNDAQUIL, 0,
    "the real matching wild battle commits the 256 guarantee")
end

do
  local h = activeWaveHarness(false)
  h.state.traces.forest = true
  h.state.rarePity.CHIKORITA = 23
  local native = { species = "ODDISH", level = 14 }
  local context = {
    mapId = "ROUTE_24", terrain = "grass",
    rng = sequence({}, "max"),
  }
  h.api.rollReplacement(native, context)
  eq(h.state.rarePity.CHIKORITA, 23,
    "a pending miss has not yet changed pity")
  h.emit("battle.started", {
    kind = "wild",
    species = "MEWTWO",
    battle = { kind = "wild", enemy = { mon = { species = "MEWTWO" } } },
  })
  eq(h.state.rarePity.CHIKORITA, 23,
    "a higher-priority encounter override cancels without advancing pity")
  eq(h.api.pendingCandidate(), nil,
    "the mismatching battle clears the stale pending candidate")

  h.api.rollReplacement(native, context)
  check(h.api.pendingCandidate() ~= nil,
    "an eligible encounter creates a runtime-only transaction")
  h.api.onStep(gameFixture(true), {
    mapId = "ROUTE_24",
  })
  eq(h.state.rarePity.CHIKORITA, 23,
    "a Repel-suppressed encounter is cancelled on the next field step")
  eq(h.api.pendingCandidate(), nil,
    "the next field step clears a Repel-suppressed candidate")
end

do
  local h = activeWaveHarness(false)
  h.state.traces.forest = true
  h.state.rarePity.CHIKORITA = 31
  h.api.rollReplacement({ species = "ODDISH", level = 14 }, {
    mapId = "ROUTE_24", terrain = "grass",
    rng = sequence({}, "max"),
  })
  h.emit("battle.started", {
    kind = "wild",
    species = "ODDISH",
    level = 15,
    battle = {
      kind = "wild",
      enemy = { mon = { species = "ODDISH", level = 15 } },
    },
  })
  eq(h.state.rarePity.CHIKORITA, 31,
    "same-species outer replacements at another level do not consume pity")
  eq(h.api.pendingCandidate(), nil,
    "a level mismatch closes the stale Early Johto transaction")
end

do
  local h = activeWaveHarness(false)
  h.state.traces.forest = true
  h.state.rarePity.CHIKORITA = 300
  local game = gameFixture(true)
  local ok = h.api.setMode(game, "KANTO_FIRST")
  eq(ok, true, "the receiver can return to Kanto First")
  eq(h.state.rarePity.CHIKORITA, 300,
    "Kanto First preserves the rare-species counter")
  h.api.setMode(game, "UNLEASHED")
  eq(h.state.rarePity.CHIKORITA, 300,
    "switching to Unleashed preserves the accumulated counter")
  local out = h.api.rollReplacement({ species = "ODDISH", level = 14 }, {
    mapId = "ROUTE_24", terrain = "grass",
    rng = sequence({}, "max"),
  })
  eq(out.species, "CHIKORITA",
    "a preserved counter above 256 guarantees the next Unleashed encounter")
end

-- ------------------------------------------- exclusions and hook ordering

do
  local habitats = {}
  for key, value in pairs(HABITATS) do habitats[key] = value end
  habitats.SENTRET = {
    map = "TEST_ROUTE", terrain = "grass", level = 12,
  }
  local h = newHarness({
    habitats = habitats,
    state = {
      capsuleFound = true,
      receiverRepaired = true,
      modeChosen = true,
      mode = "UNLEASHED",
      traces = {},
      rarePity = {},
    },
  })
  h.api.install(gameFixture(true))
  local candidates = h.api.ordinaryCandidates({
    mapId = "TEST_ROUTE", terrain = "grass",
  }, h.api.state())
  eq(#candidates, 1,
    "Unleashed rejects injected evolutions, legendary and mythical species")
  eq(candidates[1], "SENTRET",
    "only the authored ordinary base species remains eligible")
  eq(h.api.excluded.BAYLEEF, true, "starter evolutions are explicitly excluded")
  eq(h.api.excluded.TYRANITAR, true, "Larvitar evolutions are excluded")
  eq(h.api.excluded.RAIKOU, true, "legendary species are excluded")
  eq(h.api.excluded.CELEBI, true, "mythical species are excluded")
end

do
  local h = newHarness({
    state = {
      capsuleFound = true,
      receiverRepaired = true,
      modeChosen = true,
      mode = "KANTO_FIRST",
      traces = {},
      rarePity = {},
    },
  })
  h.api.install(gameFixture(true))
  local native = { species = "RATTATA", level = 3, identity = {} }
  local rngCalls = 0
  local persistBefore = h.backend.persistCount
  local readsBefore = h.backend.sectionCount
  local out = h.api.rollReplacement(native, {
    mapId = "ROUTE_1", terrain = "grass",
    rng = function()
      rngCalls = rngCalls + 1
      return 1
    end,
  })
  eq(out, native, "Kanto First returns the exact native encounter table")
  eq(out.identity, native.identity,
    "Kanto First is bit-identical even for nested native metadata")
  eq(rngCalls, 0, "Kanto First consumes zero encounter RNG draws")
  eq(h.backend.persistCount, persistBefore,
    "Kanto First performs no encounter-time save write")
  eq(h.backend.sectionCount, readsBefore,
    "Kanto First performs no encounter-time save re-read")
  eq(h.api.pendingCandidate(), nil,
    "Kanto First creates no pending Johto transaction")

  local hook = h.hooks["encounter.roll"]
  check(hook ~= nil, "the module registers the encounter hook")
  eq(hook.priority, -30,
    "Early Johto sits below authored events and existing special encounters")
  local nextCalls = 0
  local hooked = hook.fn(function()
    nextCalls = nextCalls + 1
    return native
  end, {}, {
    mapId = "ROUTE_1", terrain = "grass",
    rng = function() error("Kanto First must not roll") end,
  })
  eq(nextCalls, 1, "the low-priority wrapper calls native encounter logic once")
  eq(hooked, native, "the registered Kanto First hook is bit-identical")
end

do
  local h = activeWaveHarness(false)
  h.state.traces.forest = true
  h.state.rarePity.CHIKORITA = 7
  local native = { species = "ODDISH", level = 14 }
  local hook = h.hooks["encounter.roll"].fn
  local early = hook(function() return native end, {}, {
    mapId = "ROUTE_24", terrain = "grass",
    rng = sequence({}, "max"),
  })
  eq(early, native, "the pending rare miss keeps the native encounter")
  local outerAuthoredEvent = { species = "MOLTRES", level = 50 }
  h.emit("battle.started", {
    kind = "wild",
    species = outerAuthoredEvent.species,
    battle = {
      kind = "wild",
      enemy = { mon = { species = outerAuthoredEvent.species } },
    },
  })
  eq(h.state.rarePity.CHIKORITA, 7,
    "an outer authored special encounter outranks Early Johto cleanly")
end

do
  local h = activeWaveHarness(false)
  local native = { species = "RATTATA", level = 3 }
  local early = h.api.rollReplacement(native, {
    mapId = "ROUTE_1", terrain = "grass",
    rng = sequence({ 1, 1 }, "max"),
  })
  eq(early.species, "SENTRET", "the Early Johto candidate is produced")
  local mythicLikeOuter = early.kaProtected and early
    or { species = "MEW", level = 60, kaEncounterSource = "mythic_signals" }
  eq(mythicLikeOuter, early,
    "a mythic-style outer hook preserves the protected Early Johto result")
  eq(mythicLikeOuter.species, "SENTRET",
    "the protected ordinary wave cannot be swallowed by a mythic roll")
end

do
  local h = activeWaveHarness(false)
  h.state.traces.forest = true
  h.state.rarePity.CHIKORITA = 511
  local native = { species = "ODDISH", level = 14 }
  local spawn, transaction = h.api.rollWildsReplacement(native, {
    mapId = "ROUTE_24", terrain = "grass",
    rng = sequence({}, "max"),
  })
  eq(spawn.species, "CHIKORITA",
    "Wilds compatibility receives the same 512th trace guarantee")
  check(transaction ~= nil and transaction.wilds == true,
    "Wilds compatibility receives an independent transaction")
  eq(h.api.pendingCandidate(), nil,
    "a visible Wilds spawn never occupies the single battle-roll slot")
  eq(h.state.rarePity.CHIKORITA, 511,
    "preparing a visible Wilds spawn does not reset pity")
  local committed = h.api.commitWildsSpawn(transaction, spawn)
  eq(committed, true,
    "Wilds compatibility commits only after the visible spawn succeeds")
  eq(h.state.rarePity.CHIKORITA, 0,
    "a successful matching Wilds spawn commits the guarantee")
  committed = h.api.commitWildsSpawn(transaction, spawn)
  eq(committed, false,
    "the same visible Wilds transaction cannot be committed twice")

  h.state.rarePity.CHIKORITA = 44
  local _, cancelled = h.api.rollWildsReplacement(native, {
    mapId = "ROUTE_24", terrain = "grass",
    rng = sequence({}, "max"),
  })
  eq(h.api.cancelWildsSpawn(cancelled, "despawned"), true,
    "a visible spawn can be explicitly cancelled when it despawns")
  eq(h.state.rarePity.CHIKORITA, 44,
    "despawning a visible Wilds candidate leaves pity untouched")
end

-- ---------------------------------------------- pure resolver and no UI

do
  local h = activeWaveHarness(false)
  local persistBefore = h.backend.persistCount
  local native = { species = "RATTATA", level = 3 }
  local resolved, transaction = h.api.resolveCandidate(native, {
    mapId = "ROUTE_1", terrain = "grass",
    rng = sequence({ 2, 1 }, "max"),
  }, h.api.state())
  eq(resolved.species, "SENTRET",
    "the exported pure resolver is usable by Wilds compatibility")
  eq(transaction.expectedSpecies, "SENTRET",
    "the pure resolver returns its commit contract")
  eq(h.api.pendingCandidate(), nil,
    "the pure resolver never touches module runtime")
  eq(h.backend.persistCount, persistBefore,
    "the pure resolver never writes save state")
  eq(h.hooks["ui.start_menu.items"], nil,
    "the gameplay module adds no direct start-menu travel or UI")
end

do
  local h = newHarness({
    options = {
      johto_signals_enable = false,
      johto_signals_current = "unleashed",
    },
    state = {
      capsuleFound = true,
      receiverRepaired = true,
      modeChosen = true,
      mode = "UNLEASHED",
      traces = {},
      rarePity = {},
    },
  })
  h.api.install(gameFixture(true))
  eq(h.api.requestedStartPolicy(), "UNLEASHED",
    "the public johto_signals_current option is recognized")
  local native = { species = "RATTATA", level = 3 }
  local rngCalls = 0
  local out = h.api.rollReplacement(native, {
    mapId = "ROUTE_1", terrain = "grass",
    rng = function()
      rngCalls = rngCalls + 1
      return 1
    end,
  })
  eq(out, native,
    "disabling Johto Signals returns the exact native encounter")
  eq(rngCalls, 0,
    "the disabled public option consumes no encounter RNG")
  eq(h.api.pendingCandidate(), nil,
    "the disabled public option creates no transaction")
end

do
  local h = newHarness({
    options = {
      johto_signals_enable = false,
      mythic_signals = true,
    },
    random = sequence({ 128 }, "max"),
  })
  local game = gameFixture(true)
  h.api.install(game)
  for _ = 1, 128 do
    h.api.onStep(game, { game = game, mapId = "ROUTE_1" })
  end
  eq(h.state.capsuleAvailable, true,
    "mythic-only play still unlocks the shared receiver field quest")
  local native = { species = "RATTATA", level = 3 }
  local out = h.api.rollReplacement(native, {
    mapId = "ROUTE_1", terrain = "grass",
    rng = sequence({ 1, 1 }, "min"),
  })
  eq(out, native,
    "the shared mythic quest never enables an Early Johto encounter")

  local fullyOff = newHarness({
    options = {
      johto_signals_enable = false,
      mythic_signals = false,
    },
    random = sequence({ 128 }, "max"),
  })
  fullyOff.api.install(gameFixture(true))
  for _ = 1, 128 do
    fullyOff.api.onStep(gameFixture(true), {
      game = gameFixture(true), mapId = "ROUTE_1",
    })
  end
  eq(fullyOff.state.capsuleTarget, nil,
    "disabling both systems leaves the hidden field quest dormant")
end

print(("JOHTO SIGNALS TEST PASS: %d assertions"):format(assertions))
