-- Regression for the 6.5.3 fresh-campaign Johto Signals deadlock.
--
-- Run from the mod directory:
--   ../gen1recomp/.tools/luajit-src/src/luajit \
--     tests/normal_johto_signals_boundary_test.lua

local modulePath = os.getenv("KANTO_ASCENDANT_MOD_DIR") or "."
local makeBoundary = assert(loadfile(modulePath .. "/johto_unleashed.lua"))()
local stateModule =
  assert(loadfile(modulePath .. "/johto_signals_state.lua"))()
local makeSignals = assert(loadfile(modulePath .. "/johto_signals.lua"))()

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
local function contains(text, fragment, label)
  check(type(text) == "string" and text:find(fragment, 1, true) ~= nil,
    label .. " (missing " .. tostring(fragment) .. ")")
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

local function same(actual, expected, path)
  path = path or "value"
  if type(actual) ~= type(expected) then
    error("FAIL: " .. path .. " changed type", 2)
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
      error("FAIL: " .. path .. " gained " .. tostring(key), 2)
    end
  end
end

local function runRules()
  return {
    version = 4, locked = true, seed = 251151,
    randomizer = { enabled = true, wilds = true, trainers = true,
      items = true, similarStrength = true },
    nuzlocke = { mode = "standard", dupes = true, blackout = "end" },
    mappings = { species = { RATTATA = "SENTRET" } },
    areas = { ROUTE_1 = { encountered = true, species = "RATTATA" } },
  }
end

local function completedReceiver(mode, chosen)
  return {
    version = 2, questStarted = true,
    capsuleFound = true, capsuleAvailable = true,
    capsuleTaken = true, capsuleOpened = true, boatmanBriefed = true,
    oakCallShown = true, oakReminderShown = true,
    receiverRepaired = true, mode = mode or "KANTO_FIRST",
    modeChosen = chosen == true,
    pokedexSteps = 149, capsuleTarget = 200,
    traces = { forest = true, coast = false, ember = false, stone = false },
    rarePity = { CHIKORITA = 41, TOTODILE = 7,
      CYNDAQUIL = 0, LARVITAR = 2 },
  }
end

local function newHarness(config)
  config = config or {}
  local handlers, hooks = {}, {}
  local language = config.language or "en"
  local save = {
    version = config.edition or "red",
    player = { id = 25, name = language == "de" and "BLAU" or "RED" },
    flags = { EVENT_GOT_POKEDEX = true }, inventory = {},
    party = { { species = "BULBASAUR", level = 5 } }, boxes = {},
    pokedex = { seen = {}, owned = {} },
    modData = { kanto_ascendant = copy(config.owner or {
      beyond_kanto = { version = 1, active = false,
        decision = "fresh_gen1" },
      run_rules = runRules(), unrelated = { keep = "exact" },
    }) },
  }
  local function owner()
    return save.modData.kanto_ascendant
  end

  local events = {}
  function events:on(name, fn, priority)
    handlers[name] = handlers[name] or {}
    handlers[name][#handlers[name] + 1] = {
      fn = fn, priority = tonumber(priority) or 0,
    }
  end
  function events:emit(name, payload)
    local rows = {}
    for _, row in ipairs(handlers[name] or {}) do rows[#rows + 1] = row end
    table.sort(rows, function(a, b) return a.priority > b.priority end)
    for _, row in ipairs(rows) do row.fn(payload or {}) end
  end

  local mod = {
    id = "kanto_ascendant", exports = {}, events = events,
    hooks = { wrap = function(_, name, fn) hooks[name] = fn end },
    options = { get = function(_, key)
      if key == "johto_signals_enable" or key == "mythic_signals" then
        return true
      end
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

  local writes, successfulWrites = 0, 0
  local behavior = copy(config.writeBehavior or { "ok" })
  local disk = copy(save)
  local game = {
    save = save,
    data = {
      pokemon = {
        MAGNEMITE = { dex = 81, types = { "ELECTRIC" } },
        MAGNETON = { dex = 82, types = { "ELECTRIC" } },
        SENTRET = { dex = 161, types = { "NORMAL" } },
      },
      moves = {
        BITE = { type = "NORMAL", category = "physical" },
        GUST = { type = "NORMAL", category = "physical" },
        SAND_ATTACK = { type = "NORMAL", category = "status" },
        KARATE_CHOP = { type = "NORMAL", category = "physical" },
      },
    },
    overworld = { map = { id = "ROUTE_1" } },
  }
  if not config.noWriter then
    function game:writeSave()
      writes = writes + 1
      local action = table.remove(behavior, 1) or "ok"
      if action == "throw" then error("fixture write exception") end
      if action == "false" then return false end
      successfulWrites = successfulWrites + 1
      disk = copy(self.save)
      return true
    end
  end

  local i18n = { text = function(en, de)
    return language == "de" and de or en
  end }
  local boundary = makeBoundary(mod, { i18n = i18n, johtoData = {
    species = { SENTRET = { dex = 161 } },
  } })
  mod.exports.beyondKanto = boundary
  local signalsState = stateModule.create(mod)
  local oakCalls, oakText = 0, nil
  local signals = makeSignals(mod, {
    state = signalsState, johtoBoundary = boundary, i18n = i18n,
    johtoData = { habitats = {
      SENTRET = { map = "ROUTE_1", terrain = "grass", level = 5 },
    } },
    activationOptions = false, startPolicyOptions = false,
    random = function(lo) return lo end,
    encounterLevels = {
      routeAverage = function() return 4 end,
      ordinaryLevelFromAverage = function() return 6 end,
    },
    onOakCall = function(_, text, done)
      oakCalls, oakText = oakCalls + 1, text
      if done then done() end
    end,
  })
  boundary.sync(game, save, "fixture")
  signals.install(game, false)
  boundary.bindControllers({ signals = signals })

  local H = { game = game, save = save, mod = mod,
    boundary = boundary, signals = signals }
  function H.owner() return owner() end
  function H.state() return signals.state() end
  function H.writes() return writes end
  function H.successfulWrites() return successfulWrites end
  function H.disk() return copy(disk) end
  function H.oakCalls() return oakCalls end
  function H.oakText() return oakText end
  function H.allowWrites() behavior = { "ok", "ok", "ok" } end
  function H.emit(name)
    events:emit(name, { game = game, save = game.save })
  end
  return H
end

-- Fresh normal Red/Blue/Yellow campaigns run the entire physical discovery
-- while the generation boundary remains sealed. Both languages use the same
-- save-safe transaction once a Johto current is consciously selected.
for _, edition in ipairs({ "red", "blue", "yellow" }) do
  for _, language in ipairs({ "en", "de" }) do
    local h = newHarness({ edition = edition, language = language })
    local beforeRules = copy(h.owner().run_rules)
    check(h.signals.questEnabled(), edition .. "/" .. language
      .. " sealed save keeps field infrastructure enabled")
    check(not h.signals.enabled(), edition .. "/" .. language
      .. " sealed save cannot inject Johto encounters")
    h.signals.onStep(h.game, { game = h.game, mapId = "ROUTE_1" })
    eq(h.oakCalls(), 1, edition .. "/" .. language
      .. " first eligible step can schedule Oak")
    contains(h.oakText(), language == "de" and "PROF. EICH" or "PROF. OAK",
      edition .. "/" .. language .. " Oak call is localized")
    check(h.signals.capsuleVisible(), edition .. "/" .. language
      .. " Oak call exposes Pallet capsule")

    check(h.signals.inspectCapsule(true, h.game),
      edition .. "/" .. language .. " capsule can be taken")
    check(h.signals.openCapsule(true, h.game),
      edition .. "/" .. language .. " capsule can be opened")
    check(h.signals.onBoatmanCoordinates(h.game),
      edition .. "/" .. language .. " coordinates unlock boatman")
    check(h.signals.onResearcherRepair(h.game),
      edition .. "/" .. language .. " researcher repairs receiver")
    check(not h.boundary.isActive(h.save), edition .. "/" .. language
      .. " physical story alone stays sealed")

    check(h.signals.setMode(h.game, "KANTO_FIRST"), edition .. "/"
      .. language .. " Kanto First remains a valid conscious choice")
    check(not h.boundary.isActive(h.save), edition .. "/" .. language
      .. " Kanto First does not open boundary")
    eq(h.writes(), 0, edition .. "/" .. language
      .. " Kanto First does not spend irreversible writer")

    check(h.signals.setMode(h.game, "WANDERWAVES"), edition .. "/"
      .. language .. " Johto current activates atomically")
    check(h.boundary.isActive(h.save), edition .. "/" .. language
      .. " Johto current opens boundary")
    eq(h.state().mode, "WANDERWAVES", edition .. "/" .. language
      .. " selected current survives boundary synchronization")
    eq(h.writes(), 1, edition .. "/" .. language
      .. " boundary and current use one durable write")
    same(h.owner().run_rules, beforeRules,
      edition .. "." .. language .. ".run_rules")
    eq(h.owner().unrelated.keep, "exact", edition .. "/" .. language
      .. " unrelated mod state is untouched")

    local reloadedOwner = h.disk().modData.kanto_ascendant
    local reloaded = newHarness({ edition = edition, language = language,
      owner = reloadedOwner })
    check(reloaded.boundary.isActive(reloaded.save), edition .. "/"
      .. language .. " durable boundary survives reload")
    eq(reloaded.state().mode, "WANDERWAVES", edition .. "/" .. language
      .. " durable receiver current survives reload")
  end
end

-- Failed and throwing writers roll back the boundary and Signals together;
-- a later retry succeeds without losing run rules or quest progress.
for _, failure in ipairs({ "false", "throw" }) do
  local owner = {
    beyond_kanto = { version = 1, active = false,
      decision = "fresh_gen1" },
    johto_signals = { version = 2,
      earlyJohto = completedReceiver("KANTO_FIRST", false),
      resonance = { wins = 3 }, prismGrotto = { visits = 1 } },
    run_rules = runRules(), unrelated = { keep = "exact" },
  }
  local h = newHarness({ owner = owner, writeBehavior = { failure } })
  local before = copy(h.owner())
  local changed, reason = h.signals.setMode(h.game, "WANDERWAVES")
  check(not changed and reason == "save_failed",
    failure .. " writer fails the conscious activation closed")
  check(not h.boundary.isActive(h.save), failure
    .. " writer leaves boundary sealed")
  same(h.owner(), before, failure .. ".rollback")
  local failedReload = newHarness({ owner =
    h.disk().modData.kanto_ascendant })
  check(not failedReload.boundary.isActive(failedReload.save), failure
    .. " writer leaves the durable reload sealed")
  same(failedReload.owner(), before, failure .. ".durable_rollback")
  check(failedReload.signals.setMode(
      failedReload.game, "WANDERWAVES"), failure
    .. " durable reload can retry the conscious choice")
  check(failedReload.boundary.isActive(failedReload.save), failure
    .. " durable reload retry opens boundary")
  h.allowWrites()
  check(h.signals.setMode(h.game, "WANDERWAVES"), failure
    .. " writer can retry")
  check(h.boundary.isActive(h.save), failure
    .. " retry opens boundary")
  eq(h.state().mode, "WANDERWAVES", failure
    .. " retry preserves chosen current")
end

do
  local h = newHarness({ owner = {
    beyond_kanto = { version = 1, active = false,
      decision = "fresh_gen1" },
    johto_signals = { version = 2,
      earlyJohto = completedReceiver("KANTO_FIRST", false) },
    run_rules = runRules(), unrelated = { keep = "exact" },
  }, noWriter = true })
  local changed, reason = h.signals.setMode(h.game, "UNLEASHED")
  check(not changed and reason == "save_failed",
    "missing writer cannot fake a durable receiver activation")
  check(not h.boundary.isActive(h.save),
    "missing writer leaves boundary sealed")
end

-- A complete 6.5.3 current is repaired on load. Failed repairs preserve every
-- counter and retry; partial/copied/malformed shapes are never authoritative.
for _, failure in ipairs({ "false", "throw" }) do
  local early = completedReceiver("WANDERWAVES", true)
  local owner = {
    beyond_kanto = { version = 1, active = false,
      decision = "fresh_gen1" },
    johto_signals = { version = 2, earlyJohto = early,
      resonance = { wins = 8 }, prismGrotto = { visits = 2 } },
    run_rules = runRules(), unrelated = { keep = "exact" },
  }
  local h = newHarness({ owner = owner, writeBehavior = { failure } })
  local before = copy(h.owner())
  h.emit("save.loaded")
  check(not h.boundary.isActive(h.save), failure
    .. " old-save repair failure remains sealed")
  same(h.owner(), before, failure .. ".old_save_rollback")
  local failedReload = newHarness({ owner =
    h.disk().modData.kanto_ascendant })
  failedReload.emit("save.loaded")
  check(failedReload.boundary.isActive(failedReload.save), failure
    .. " old-save repair retries safely after reload")
  eq(failedReload.state().mode, "WANDERWAVES", failure
    .. " old-save reload repair retains exact current")
  same(failedReload.owner().run_rules, before.run_rules,
    failure .. ".old_save_reload_run_rules")
  h.allowWrites()
  h.emit("save.loaded")
  check(h.boundary.isActive(h.save), failure
    .. " old-save repair retries on next load")
  eq(h.state().mode, "WANDERWAVES", failure
    .. " old-save repair retains exact current")
  eq(h.state().rarePity.CHIKORITA, 41, failure
    .. " old-save repair retains pity")
  same(h.owner().run_rules, before.run_rules,
    failure .. ".old_save_run_rules")
end

-- Already-repaired 6.5.3/6.5.4 saves that have a real Driftglass boundary
-- receipt keep their selected current and all longitudinal progress. Loading
-- them is idempotent and never spends another durable write.
do
  local early = completedReceiver("WANDERWAVES", true)
  local owner = {
    beyond_kanto = { version = 1, active = true, irreversible = true,
      decision = "driftglass_receiver" },
    johto_signals = { version = 2, earlyJohto = early,
      resonance = { wins = 12 }, prismGrotto = { visits = 4 } },
    run_rules = runRules(), unrelated = { keep = "exact" },
  }
  local h = newHarness({ owner = owner })
  local before = copy(h.owner())
  h.emit("save.loaded")
  check(h.boundary.isActive(h.save),
    "existing Driftglass boundary stays active after load")
  eq(h.state().mode, "WANDERWAVES",
    "existing Driftglass boundary keeps its chosen current")
  eq(h.state().rarePity.CHIKORITA, 41,
    "existing Driftglass boundary keeps encounter pity")
  same(h.owner().run_rules, before.run_rules,
    "existing_active.run_rules")
  eq(h.writes(), 0,
    "existing Driftglass boundary load is idempotent")
end

for index, mutate in ipairs({
  function(s) s.receiverRepaired = false end,
  function(s) s.questStarted = false end,
  function(s) s.modeChosen = false end,
  function(s) s.mode = "KANTO_FIRST" end,
  function(s) s.mode = "CELEBI_NOW" end,
}) do
  local early = completedReceiver("WANDERWAVES", true)
  mutate(early)
  local h = newHarness({ owner = {
    johto_signals = { version = 2, earlyJohto = early },
    run_rules = runRules(), unrelated = { keep = "exact" },
  } })
  h.emit("save.loaded")
  check(not h.boundary.isActive(h.save),
    "malformed Signals shape " .. index .. " stays fail-closed")
  eq(h.writes(), 0,
    "malformed Signals shape " .. index .. " performs no durable write")
end

-- A blocked 6.5.3 fresh save starts its hidden cadence on the next eligible
-- step without resetting already-counted progress.
do
  local h = newHarness({ owner = {
    beyond_kanto = { version = 1, active = false,
      decision = "fresh_gen1" },
    johto_signals = { version = 2, earlyJohto = {
      version = 2, pokedexSteps = 37, traces = {}, rarePity = {},
    } },
    run_rules = runRules(), unrelated = { keep = "exact" },
  } })
  h.signals.onStep(h.game, { game = h.game, mapId = "ROUTE_1" })
  eq(h.state().pokedexSteps, 38,
    "6.5.3 blocked save resumes rather than resets its cadence")
  eq(h.state().capsuleTarget, 1,
    "6.5.3 blocked save initializes its missing target once")
  eq(h.oakCalls(), 1,
    "6.5.3 blocked save immediately receives an already-due Oak call")
  check(not h.boundary.isActive(h.save),
    "cadence repair cannot open Beyond Kanto")
end

print(("normal_johto_signals_boundary_test: %d assertions passed")
  :format(assertions))
