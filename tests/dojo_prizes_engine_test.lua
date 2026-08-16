-- Exact 0.1.96/0.1.98 Fighting Dojo prize integration test.
--
-- Required environment:
--   KA_ENGINE_ROOT=/unpacked/official/love
--   KA_EXPECT_ENGINE=0.1.96
--   KA_ENGINE_CACHE_ROOT=/path/to/pokemon-love2d
--   GEN1RECOMP_TEST_ROOT=/path/to/gen1recomp
--   TRAINER_REMATCH_MOD_DIR=/path/to/kanto-ascendant

local engineRoot = assert(os.getenv("KA_ENGINE_ROOT"),
  "KA_ENGINE_ROOT is required")
local expectedEngine = assert(os.getenv("KA_EXPECT_ENGINE"),
  "KA_EXPECT_ENGINE is required")
local cacheRoot = assert(os.getenv("KA_ENGINE_CACHE_ROOT"),
  "KA_ENGINE_CACHE_ROOT is required")
local harnessRoot = assert(os.getenv("GEN1RECOMP_TEST_ROOT"),
  "GEN1RECOMP_TEST_ROOT is required")
local modRoot = assert(os.getenv("TRAINER_REMATCH_MOD_DIR"),
  "TRAINER_REMATCH_MOD_DIR is required")

package.path = engineRoot .. "/?.lua;" .. engineRoot .. "/?/init.lua;"
  .. harnessRoot .. "/?.lua;" .. harnessRoot .. "/?/init.lua;"
  .. package.path
love = love or require("tests.love_stub")

local Version = require("src.core.Version")
assert(Version.engine == expectedEngine,
  "wrong exact engine (expected " .. expectedEngine .. ", got "
    .. tostring(Version.engine) .. ")")

local checks = 0
local function ok(value, message)
  checks = checks + 1
  if not value then error("FAIL: " .. message, 2) end
end
local function eq(actual, expected, message)
  ok(actual == expected, message .. " (expected " .. tostring(expected)
    .. ", got " .. tostring(actual) .. ")")
end

local function read(path)
  local handle = assert(io.open(path, "rb"), path)
  local body = handle:read("*a")
  handle:close()
  return body
end

local function loadData(edition)
  local root = cacheRoot .. "/" .. edition .. "/data/generated"
  return {
    pokemon = assert(loadfile(root .. "/pokemon.lua"))(),
    moves = assert(loadfile(root .. "/moves.lua"))(),
    text = assert(loadfile(root .. "/text.lua"))(),
    maps = assert(loadfile(root .. "/maps.lua"))(),
    items = assert(loadfile(root .. "/items.lua"))(),
    sprites = assert(loadfile(root .. "/sprites.lua"))(),
    audio = assert(loadfile(root .. "/audio.lua"))(),
    constants = assert(loadfile(root .. "/constants.lua"))(),
  }
end

local function clone(value, seen)
  if type(value) ~= "table" then return value end
  seen = seen or {}
  if seen[value] then return seen[value] end
  local out = {}
  seen[value] = out
  for key, child in pairs(value) do out[clone(key, seen)] = clone(child, seen) end
  return out
end

local function deepEqual(left, right, seen)
  if type(left) ~= type(right) then return false end
  if type(left) ~= "table" then return left == right end
  seen = seen or {}
  if seen[left] == right then return true end
  seen[left] = right
  for key, value in pairs(left) do
    if not deepEqual(value, right[key], seen) then return false end
  end
  for key in pairs(right) do
    if left[key] == nil then return false end
  end
  return true
end

local function makeStack()
  return {
    states = {},
    push = function(self, value) self.states[#self.states + 1] = value end,
    pop = function(self) return table.remove(self.states) end,
    top = function(self) return self.states[#self.states] end,
  }
end

local function makeEvents()
  local handlers = {}
  local bus = {}
  function bus:on(name, fn, priority)
    handlers[name] = handlers[name] or {}
    handlers[name][#handlers[name] + 1] = {
      fn = fn, priority = tonumber(priority) or 0,
    }
    table.sort(handlers[name], function(a, b) return a.priority > b.priority end)
  end
  function bus:emit(name, payload)
    for _, row in ipairs(handlers[name] or {}) do row.fn(payload) end
  end
  return bus
end

local function fullBoxes(full)
  local out = {}
  for box = 1, 12 do
    out[box] = {}
    if full then
      for slot = 1, 20 do
        out[box][slot] = { species = "RATTATA", level = 2,
          serial = box * 100 + slot }
      end
    end
  end
  return out
end

local function lockedRules(randomizer)
  local random = {
    enabled = randomizer, wild = true, trainers = true, starters = true,
    gifts = randomizer, static = true, items = false, legendary = false,
    balanced = true, consistent = true,
  }
  local nuzlocke = {
    mode = "off", dupes = true, blackout = "end", shinyOdds = 4096,
  }
  return {
    version = 3, configured = true, locked = true,
    lockReason = "player_pc", legacyProgress = false,
    preset = "custom", seed = 6504, failed = false, poolDexMax = 151,
    randomizer = clone(random), nuzlocke = clone(nuzlocke),
    mappings = { species = {}, items = {} },
    finalRules = {
      preset = "custom", seed = 6504, poolDexMax = 151,
      randomizer = clone(random), nuzlocke = clone(nuzlocke),
      mappings = { species = {}, items = {} },
    },
    areas = {}, deaths = {}, encounterSerial = 0,
  }
end

local function fixture(edition, randomizer, storage, writeMode)
  local data = loadData(edition)
  local events = makeEvents()
  local mod = {
    id = "kanto_ascendant",
    events = events,
    hooks = { wrap = function() end },
    ui = {},
    log = { warn = function() end },
  }
  local boundary = { isActive = function() return false end,
    onChanged = function() end }
  local runRules = assert(loadfile(modRoot .. "/run_rules.lua"))()(mod, {
    i18n = { text = function(en) return en end },
    beyondKanto = boundary,
  })
  local dojo = assert(loadfile(modRoot .. "/dojo_prizes.lua"))()(mod, {
    i18n = { text = function(en) return en end },
  })

  local party = {}
  if storage ~= "party" then
    for slot = 1, 6 do party[slot] = { species = "RATTATA", level = 2 } end
  end
  local save = {
    version = edition,
    player = { name = edition:upper(), id = 6504 },
    flags = { EVENT_BEAT_KARATE_MASTER = true },
    party = party, boxes = fullBoxes(storage == "full"), currentBox = 1,
    inventory = {}, bagOrder = {}, defeatedTrainers = {},
    pokedex = { seen = {}, owned = {} }, objectToggles = {},
    modData = { kanto_ascendant = { run_rules = lockedRules(randomizer) } },
  }
  local game = {
    save = save, data = data, stack = makeStack(),
    mods = { events = events }, writes = 0,
    overworld = nil,
  }
  game.input = {
    pressed = nil,
    wasPressed = function(self, key)
      if self.pressed ~= key then return false end
      self.pressed = nil
      return true
    end,
  }
  function game:writeSave()
    self.writes = self.writes + 1
    if writeMode == "false" and self.writes == 1 then return false end
    if writeMode == "throw" and self.writes == 1 then error("fault injection") end
    return true
  end
  local dojoMap = assert(data.maps.FIGHTING_DOJO,
    edition .. " generated Fighting Dojo map")
  local ow = {
    map = { id = "FIGHTING_DOJO", def = dojoMap },
    player = {}, npcs = {}, entities = {}, npcPool = {},
  }
  game.overworld = ow
  runRules.install(game)
  return dojo, runRules, game, ow
end

-- Confirm the public incident's two exact upstream seams on every engine:
-- the continuation exists, while the native gift flags precede delivery and
-- never inspect lastCheck.  This is evidence, not a reason to patch upstream.
do
  local story = read(engineRoot .. "/data/scripts/story4.lua")
  local dex = assert(story:find("DexEntryMenu.new(game, species, function()", 1, true))
  local flag = assert(story:find('flags["EVENT_GOT_" .. species] = true', dex, true))
  local give = assert(story:find("Commands.give_pokemon(ctx, species, 30)", flag, true))
  local hide = assert(story:find("Commands.hide_object(ctx", give, true))
  ok(flag < give and give < hide,
    expectedEngine .. " native Dojo still commits flags before delivery")
  eq(story:find("lastCheck", flag, true), nil,
    expectedEngine .. " native Dojo does not validate delivery")
end

-- Crystal-v1.5's production wrapper must preserve DexEntryMenu's public
-- third argument.  Patch only the exact engine constructor to a sentinel so
-- no graphics/audio are needed; then install the real KASC wrapper.
do
  local DexEntryMenu = require("src.ui.DexEntryMenu")
  local originalNew = DexEntryMenu.new
  DexEntryMenu.new = function(game, species, onDone)
    return { game = game, species = species, onDone = onDone }
  end
  DexEntryMenu._ascendantCrystalV15Wrapped = nil
  local mod = {
    path = modRoot,
    options = { get = function(_, key)
      return key == "pokemon_sprite_style" and "crystal" or true
    end },
    hooks = { wrap = function() end },
    events = { on = function() end },
    content = { battle_sprite_scales = { register = function() end } },
    read = function() return nil end,
  }
  local v15 = assert(loadfile(modRoot .. "/crystal_v15_features.lua"))()(mod, {})
  v15.install({ data = { pokemon = {} } }, {
    battleState = { newTrainer = function() return {} end },
  })
  local callback = function() end
  local screen = DexEntryMenu.new({ data = { pokemon = {} } }, "HITMONLEE", callback)
  eq(screen.onDone, callback,
    expectedEngine .. " Crystal Dex wrapper forwards Dojo continuation")
  -- Reinstall around the real exact-engine constructor for the interactive
  -- A/B flow below; the first install intentionally captured the sentinel.
  DexEntryMenu.new = originalNew
  DexEntryMenu._ascendantCrystalV15Wrapped = nil
  v15.install({ data = { pokemon = {} } }, {
    battleState = { newTrainer = function() return {} end },
  })
end

-- Drive the real exact-engine DexEntryMenu -> TextBox -> ChoiceBox chain.
-- A accepts and B cancels only after the engine's normal 15-frame answer
-- hold; this catches both the swallowed continuation and menu-order bugs.
for _, answer in ipairs({ "b", "a" }) do
  local dojo, _, game, ow = fixture("red", false, "party", "ok")
  local npc = {
    def = {
      name = "FIGHTINGDOJO_HITMONLEE_POKE_BALL",
      text = "TEXT_FIGHTINGDOJO_HITMONLEE_POKE_BALL",
    },
    frozen = false,
    facePlayer = function(self) self.faced = true end,
  }
  ok(dojo.handleTalk(ow, npc, game),
    expectedEngine .. "/" .. answer .. " real ball talk handled")
  local dex = game.stack:top()
  eq(type(dex.onDone), "function",
    expectedEngine .. "/" .. answer .. " real Dex continuation survives")
  game.input.pressed = "a"
  dex:update(0)
  local prompt = game.stack:top()
  prompt.done = true
  prompt:update(0)
  local choice = game.stack:top()
  game.input.pressed = answer
  choice:update(0)
  for _ = 1, 20 do choice:update(0) end
  if answer == "b" then
    eq(game.save.flags.EVENT_GOT_HITMONLEE, nil,
      expectedEngine .. " real ChoiceBox B cancels")
    eq(#game.save.party, 0,
      expectedEngine .. " real ChoiceBox B leaves PARTY unchanged")
    eq(npc.frozen, false,
      expectedEngine .. " real ChoiceBox B unfreezes object")
  else
    eq(game.save.flags.EVENT_GOT_HITMONLEE, true,
      expectedEngine .. " real ChoiceBox A commits prize")
    eq(#game.save.party, 1,
      expectedEngine .. " real ChoiceBox A delivers prize")
    eq(game.writes, 1,
      expectedEngine .. " real ChoiceBox A persists once")
  end
end

local cases = {
  { storage = "party", write = "ok", succeeds = true },
  { storage = "box", write = "ok", succeeds = true },
  { storage = "full", write = "ok", succeeds = false, reason = "storage_full" },
  { storage = "box", write = "false", succeeds = false, reason = "save_failed" },
  { storage = "box", write = "throw", succeeds = false, reason = "save_failed" },
}

for _, edition in ipairs({ "red", "blue", "yellow" }) do
  for _, randomizer in ipairs({ false, true }) do
    for _, case in ipairs(cases) do
      local label = table.concat({ expectedEngine, edition,
        "rnd=" .. tostring(randomizer), case.storage, case.write }, "/")
      local dojo, _, game, ow = fixture(
        edition, randomizer, case.storage, case.write)
      local row = dojo.BALLS.TEXT_FIGHTINGDOJO_HITMONLEE_POKE_BALL
      local before = clone(game.save)
      local claimed, reason, actualName = dojo.claim(game, ow, row)
      eq(claimed, case.succeeds, label .. " transaction result")
      if not case.succeeds then
        eq(reason, case.reason, label .. " failure reason")
        ok(deepEqual(game.save, before), label .. " restores exact save graph")
        eq(game.save.objectToggles.FIGHTING_DOJO, nil,
          label .. " restores absent object-toggle map")
        eq(game.save.flags.EVENT_GOT_HITMONLEE, nil,
          label .. " never burns chosen-prize flag")
        local rules = game.save.modData.kanto_ascendant.run_rules
        eq(next(rules.mappings.species), nil,
          label .. " rolls back live Randomizer mapping")
        eq(next(rules.finalRules.mappings.species), nil,
          label .. " rolls back immutable Randomizer receipt")
        if case.write ~= "ok" then
          claimed = dojo.claim(game, ow, row)
          eq(claimed, true, label .. " retry succeeds")
          eq(game.writes, 2, label .. " retry writes once more")
        else
          eq(game.writes, 0, label .. " storage-full never writes")
        end
      else
        eq(game.save.flags.EVENT_GOT_HITMONLEE, true,
          label .. " commits chosen flag")
        eq(game.save.flags.EVENT_DEFEATED_FIGHTING_DOJO, true,
          label .. " commits Dojo completion")
        eq(game.save.objectToggles.FIGHTING_DOJO[row.object], false,
          label .. " hides chosen ball")
        eq(game.writes, 1, label .. " persists once")
        local rules = game.save.modData.kanto_ascendant.run_rules
        if randomizer then
          local mapped = rules.mappings.species.HITMONLEE
          ok(type(mapped) == "string" and game.data.pokemon[mapped] ~= nil,
            label .. " commits an in-pool Randomizer gift mapping")
          eq(rules.finalRules.mappings.species.HITMONLEE, mapped,
            label .. " final Randomizer receipt matches live mapping")
          eq(actualName, game.data.pokemon[mapped].name,
            label .. " confirmation names the actual mapped gift")
        else
          eq(next(rules.mappings.species), nil,
            label .. " Randomizer OFF keeps mappings empty")
          eq(actualName, game.data.pokemon.HITMONLEE.name,
            label .. " confirmation names HITMONLEE")
        end
      end
    end
  end
end

print(("DOJO PRIZES ENGINE PASS: engine=%s checks=%d R/B/Y randomizer OFF/ON")
  :format(expectedEngine, checks))
