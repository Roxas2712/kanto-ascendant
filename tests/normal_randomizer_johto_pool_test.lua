-- Save-compatibility regression for normal-run Randomizer pool expansion.
--
-- The exact Driftglass receiver YES expands only ordinary explicit runs from
-- #001-151 to #001-251. Legacy Journey remains fixed. Boundary, Signals,
-- National-Dex and run_rules still share B.activate's single durable write.

local modulePath = os.getenv("KANTO_ASCENDANT_MOD_DIR") or "."
local engineRoot = os.getenv("GEN1RECOMP_ROOT")
if engineRoot then
  package.path = engineRoot .. "/?.lua;" .. engineRoot .. "/?/init.lua;"
    .. package.path
end

local makeBoundary = assert(loadfile(modulePath .. "/johto_unleashed.lua"))()
local makeRules = assert(loadfile(modulePath .. "/run_rules.lua"))()

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

local function species(id, dex, value)
  return {
    id = id, name = id, dex = dex, types = { "NORMAL" },
    baseStats = { hp = value, attack = value, defense = value,
      speed = value, special = value },
    evolutions = {}, level1Moves = {}, learnset = {},
  }
end

local function randomizer()
  return {
    enabled = true, wild = true, trainers = true, starters = true,
    gifts = true, static = true, items = true, legendary = false,
    balanced = true, consistent = true,
  }
end

local function nuzlocke()
  return {
    mode = "standard", dupes = true, blackout = "end",
    shinyOdds = 4096,
  }
end

local function runRules(version, reason, pool)
  version = version or 4
  reason = reason or "explicit_start"
  pool = pool or 151
  local mappings = {
    species = { RATTATA = "BULBASAUR" },
    items = { POTION = "ANTIDOTE" },
  }
  local policy = reason == "explicit_start" or reason == "player_pc"
    and "expand_on_beyond_kanto" or "fixed"
  local state = {
    version = version, configured = true, locked = true,
    lockReason = reason, legacyProgress = false,
    preset = "ascendant", seed = 654251, failed = false,
    poolDexMax = pool,
    randomizer = randomizer(), nuzlocke = nuzlocke(),
    mappings = copy(mappings),
    areas = { ROUTE_1 = { encountered = true, species = "RATTATA" } },
    deaths = { { species = "PIDGEY", level = 4, area = "ROUTE_1" } },
    encounterSerial = 17,
  }
  state.finalRules = {
    preset = state.preset, seed = state.seed, poolDexMax = pool,
    randomizer = copy(state.randomizer), nuzlocke = copy(state.nuzlocke),
    mappings = copy(mappings),
  }
  if version >= 4 then
    state.poolPolicy = policy
    state.finalRules.poolPolicy = policy
  end
  return state
end

local function newHarness(config)
  config = config or {}
  local handlers, hooks = {}, {}
  local owner = copy(config.owner or {
    beyond_kanto = { version = 1, active = false,
      decision = "fresh_gen1" },
    run_rules = runRules(config.rulesVersion, config.lockReason,
      config.poolDexMax),
    unrelated = { exact = "keep" },
  })
  local save = {
    version = config.edition or "red",
    player = { id = 42, name = string.upper(config.edition or "red") },
    party = {}, boxes = {}, inventory = {},
    pokedex = { seen = {}, owned = {} },
    modData = { kanto_ascendant = owner },
  }
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
    id = "kanto_ascendant", events = events,
    hooks = { wrap = function(_, name, fn) hooks[name] = fn end },
    log = { info = function() end, warn = function() end,
      error = function() end },
  }
  local actions = copy(config.writeBehavior or { "ok" })
  local writes, successfulWrites = 0, 0
  local disk = copy(save)
  local game = {
    save = save,
    data = {
      pokemon = {
        BULBASAUR = species("BULBASAUR", 1, 45),
        RATTATA = species("RATTATA", 19, 42),
        PIKACHU = species("PIKACHU", 25, 50),
        MAGNEMITE = species("MAGNEMITE", 81, 40),
        MAGNETON = species("MAGNETON", 82, 60),
        MEW = species("MEW", 151, 100),
        CHIKORITA = species("CHIKORITA", 152, 52),
        SENTRET = species("SENTRET", 161, 43),
        CELEBI = species("CELEBI", 251, 100),
      },
      moves = {
        BITE = { type = "NORMAL", category = "physical" },
        GUST = { type = "NORMAL", category = "physical" },
        SAND_ATTACK = { type = "NORMAL", category = "status" },
        KARATE_CHOP = { type = "NORMAL", category = "physical" },
      },
      items = {
        POTION = { name = "POTION" },
        ANTIDOTE = { name = "ANTIDOTE" },
      },
    },
    overworld = { map = { def = { id = "ROUTE_1" }, id = "ROUTE_1" } },
  }
  local function installWriter()
    function game:writeSave()
      writes = writes + 1
      local action = table.remove(actions, 1) or "ok"
      if action == "throw" then error("fixture writer threw") end
      if action == "false" then return false end
      successfulWrites = successfulWrites + 1
      disk = copy(self.save)
      return true
    end
  end
  if not config.noWriter then installWriter() end

  local boundary = makeBoundary(mod, { johtoData = {
    species = { CHIKORITA = { dex = 152 }, SENTRET = { dex = 161 },
      CELEBI = { dex = 251 } },
  } })
  local rules = makeRules(mod, { beyondKanto = boundary })
  boundary.sync(game, save, "fixture")
  rules.install(game)

  local H = { game = game, save = save, boundary = boundary,
    rules = rules, events = events }
  function H.owner() return save.modData.kanto_ascendant end
  function H.writes() return writes end
  function H.successfulWrites() return successfulWrites end
  function H.disk() return copy(disk) end
  function H.setActions(values)
    actions = copy(values)
    if type(game.writeSave) ~= "function" then installWriter() end
  end
  function H.emit(name)
    events:emit(name, { game = game, save = save })
  end
  return H
end

local function stableRunProjection(state)
  return {
    seed = state.seed, randomizer = copy(state.randomizer),
    nuzlocke = copy(state.nuzlocke), mappings = copy(state.mappings),
    areas = copy(state.areas), deaths = copy(state.deaths),
    encounterSerial = state.encounterSerial, failed = state.failed,
    unrelated = state.unrelated,
  }
end

-- Red, Blue and Yellow ordinary starts receive the same one-write contract.
for _, edition in ipairs({ "red", "blue", "yellow" }) do
  for _, reason in ipairs({ "explicit_start", "player_pc" }) do
    local h = newHarness({ edition = edition, lockReason = reason })
    local before = stableRunProjection(h.owner().run_rules)
    local changed, why = h.boundary.activate(h.game, {
      decision = "driftglass_receiver", signalMode = "WANDERWAVES",
      requireDurable = true,
    })
    check(changed and why == "activated",
      edition .. "/" .. reason .. " activates Driftglass authority")
    eq(h.writes(), 1, edition .. "/" .. reason
      .. " uses the boundary's single durable write")
    eq(h.owner().run_rules.poolDexMax, 251,
      edition .. "/" .. reason .. " expands live pool")
    eq(h.owner().run_rules.finalRules.poolDexMax, 251,
      edition .. "/" .. reason .. " expands final pool receipt")
    eq(h.owner().run_rules.poolPolicy, "expand_on_beyond_kanto",
      edition .. "/" .. reason .. " records normal-run policy")
    same(stableRunProjection(h.owner().run_rules), before,
      edition .. "." .. reason .. ".stable")
    eq(h.rules.randomSpecies(h.owner().run_rules, "RATTATA", "wild"),
      "BULBASAUR", edition .. "/" .. reason
        .. " keeps the already-resolved encounter mapping")
    check(h.rules.byId.CHIKORITA ~= nil and h.rules.byId.CELEBI ~= nil,
      edition .. "/" .. reason .. " live pool includes #152-251")
  end
end

-- False, throwing and missing writers restore both save table and live pool;
-- the same in-memory save can retry without a reload.
for _, failure in ipairs({ "false", "throw", "missing" }) do
  local h = newHarness(failure == "missing"
    and { noWriter = true } or { writeBehavior = { failure } })
  local before = copy(h.owner())
  local changed, why = h.boundary.activate(h.game, {
    decision = "driftglass_receiver", signalMode = "UNLEASHED",
    requireDurable = true,
  })
  check(not changed and why == "save_failed",
    failure .. " writer fails activation closed")
  same(h.owner(), before, failure .. ".complete_rollback")
  eq(h.rules.poolMaxDex(h.game), 151,
    failure .. " rollback restores live #001-151 pool")
  eq(h.rules.byId.CHIKORITA, nil,
    failure .. " rollback removes Johto rows from live Randomizer pool")
  h.setActions({ "ok" })
  check(h.boundary.activate(h.game, {
    decision = "driftglass_receiver", signalMode = "UNLEASHED",
    requireDurable = true,
  }), failure .. " writer can retry without reconfiguring the run")
  eq(h.owner().run_rules.poolDexMax, 251,
    failure .. " retry expands the pool")
  same(stableRunProjection(h.owner().run_rules),
    stableRunProjection(before.run_rules), failure .. ".retry_stable")
end

-- Legacy Journey has a player-confirmed fixed pool, even if Johto is opened
-- later through Driftglass in that save.
do
  local h = newHarness({ lockReason = "legacy_start" })
  check(h.boundary.activate(h.game, {
    decision = "driftglass_receiver", requireDurable = true,
  }), "Legacy save can open Beyond Kanto")
  eq(h.owner().run_rules.poolPolicy, "fixed",
    "Legacy save keeps fixed policy")
  eq(h.owner().run_rules.poolDexMax, 151,
    "Legacy save keeps its explicit #001-151 choice")
  eq(h.owner().run_rules.finalRules.poolDexMax, 151,
    "Legacy final receipt remains fixed")
end

-- Other historical boundary decisions are not Driftglass authority.
do
  local h = newHarness()
  check(h.boundary.activate(h.game, {
    decision = "player_confirmed", requireDurable = true,
  }), "non-Driftglass boundary can still activate")
  eq(h.owner().run_rules.poolDexMax, 151,
    "non-Driftglass activation cannot expand a locked pool")
end

-- Existing 6.5.3 saves repair once at authoritative save.loaded. A failed
-- migration restores the exact v3 table and retries on the next load.
for _, failure in ipairs({ "false", "throw", "missing" }) do
  local h = newHarness(failure == "missing"
    and { noWriter = true } or { writeBehavior = { failure } })
  h.owner().beyond_kanto = {
    version = 1, active = true, irreversible = true,
    decision = "driftglass_receiver",
  }
  h.owner().run_rules = runRules(3, "explicit_start", 151)
  local before = copy(h.owner().run_rules)
  h.emit("save.loaded")
  same(h.owner().run_rules, before,
    failure .. ".reload_exact_v3_rollback")
  eq(h.rules.poolMaxDex(h.game), 151,
    failure .. " reload failure restores #001-151")
  h.setActions({ "ok" })
  h.emit("save.loaded")
  eq(h.owner().run_rules.version, h.rules.runRulesVersion,
    failure .. " reload retry migrates schema")
  eq(h.owner().run_rules.poolPolicy, "expand_on_beyond_kanto",
    failure .. " reload retry infers normal policy")
  eq(h.owner().run_rules.poolDexMax, 251,
    failure .. " reload retry expands pool")
  same(stableRunProjection(h.owner().run_rules),
    stableRunProjection(before), failure .. ".reload_stable")
end

-- A completed migration is idempotent and performs no load-time write.
do
  local h = newHarness({ owner = {
    beyond_kanto = { version = 1, active = true, irreversible = true,
      decision = "driftglass_receiver" },
    run_rules = runRules(4, "explicit_start", 251),
    unrelated = { exact = "keep" },
  } })
  local before = copy(h.owner().run_rules)
  h.emit("save.loaded")
  same(h.owner().run_rules, before, "completed_migration.idempotent")
  eq(h.writes(), 0, "completed migration spends no reload write")
end

print(("normal_randomizer_johto_pool_test: %d assertions passed")
  :format(assertions))
