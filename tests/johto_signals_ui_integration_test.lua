-- Deterministic WORLD, Journal and Research Atlas integration tests.
--
-- Run from the mod directory:
--   ../gen1recomp/.tools/luajit-src/src/luajit \
--     tests/johto_signals_ui_integration_test.lua

local source = debug.getinfo(1, "S").source
local testDir = source:sub(1, 1) == "@"
  and source:sub(2):match("^(.*)/[^/]+$") or "tests"
local rootDir = testDir:match("^(.*)/tests$") or "."

local assertions = 0
local function equal(actual, expected, message)
  assertions = assertions + 1
  if actual ~= expected then
    error(("FAIL: %s\nexpected: %s\nactual:   %s")
      :format(message, tostring(expected), tostring(actual)), 2)
  end
end

local function contains(text, fragment, message)
  assertions = assertions + 1
  if type(text) ~= "string" or not text:find(fragment, 1, true) then
    error(("FAIL: %s\nmissing: %s\ntext: %s")
      :format(message, tostring(fragment), tostring(text)), 2)
  end
end

local function excludes(text, fragment, message)
  assertions = assertions + 1
  if type(text) == "string" and text:find(fragment, 1, true) then
    error(("FAIL: %s\nunexpected: %s\ntext: %s")
      :format(message, tostring(fragment), tostring(text)), 2)
  end
end

local language = "en"
local i18n = {
  text = function(en, de) return language == "de" and de or en end,
  isGerman = function() return language == "de" end,
}

local function newWorldEvents(showMenu)
  local bucket, hooks = {}, {}
  local mod = {
    save = {
      get = function(_, key, fallback)
        local value = bucket[key]
        return value == nil and fallback or value
      end,
      set = function(_, key, value) bucket[key] = value end,
    },
    hooks = {
      wrap = function(_, name, fn, priority)
        hooks[name] = { fn = fn, priority = priority }
      end,
    },
    events = { on = function() end },
    ui = {
      insertBefore = function(rows, _, row)
        rows[#rows + 1] = row
        return rows
      end,
    },
  }
  local postgame = {
    hasHallOfFame = function() return true end,
  }
  local options = { i18n = i18n, postgame = postgame }
  if showMenu ~= nil then options.showMenu = showMenu end
  local controller =
    assert(loadfile(rootDir .. "/world_events.lua"))()(mod, options)
  local game = {
    save = { hallOfFame = { {} } },
    data = { pokemon = {} },
  }
  controller.install(game)
  return controller, hooks, game
end

do
  local world, hooks, game = newWorldEvents(false)
  local wrapper = assert(hooks["ui.start_menu.items"]).fn
  local rows = { { label = "SAVE" } }
  local out = wrapper(function(_, input) return input end, game, rows)
  equal(out, rows,
    "showMenu=false preserves the exact existing Start-menu table")
  equal(#out, 1,
    "showMenu=false suppresses the separate WORLD STATUS entry")
  contains(world.statusText(game), "The world is calm.",
    "statusText remains public when menu presentation is delegated")

  language = "de"
  contains(world.statusText(game), "Die Welt ist ruhig.",
    "delegated world status remains localized in German")
  language = "en"
end

do
  local _, hooks, game = newWorldEvents(nil)
  local wrapper = assert(hooks["ui.start_menu.items"]).fn
  local rows = wrapper(function(_, input) return input end,
    game, { { label = "SAVE" } })
  equal(#rows, 2,
    "omitting showMenu preserves the 5.3 WORLD entry by default")
  equal(rows[2].ascendantLabel, "WORLD STATUS",
    "the compatible default keeps the authored submenu label")
end

local signalObjective = {
  key = "mythic_retry",
  title = "CELEBI SIGNAL",
  location = "KANTO_ASCENDANT_DRIFTGLASS",
  current = 1,
  total = 3,
  detail = "Track CELEBI's echo.",
  species = "CELEBI",
}
local signalsHub = {
  objective = function() return signalObjective end,
  atlasLocations = function()
    return {
      KANTO_ASCENDANT_DRIFTGLASS = language == "de"
        and "DRIFTGLAS-POSTEN" or "DRIFTGLASS POST",
    }
  end,
}

local postgameState = {
  crownChampion = true,
  apexChampion = true,
  crownWins = {},
  eliteApexWins = {},
  eliteCrownWins = {},
}
local postgame = {
  hasHallOfFame = function() return true end,
  state = function() return postgameState end,
  phaseFor = function() return "complete" end,
}
local achievements = {
  cycle = 0,
  rocketStage = 0,
  tournament = { wins = 1 },
  mewCaught = true,
}
local ascendant = {
  evaluateAchievements = function() return achievements end,
  activeResearch = function() return nil end,
  questDoneCount = function() return 8 end,
  newGamePlusReady = function() return false end,
}
local trackerMod = {
  options = { get = function() return true end },
}
local tracker = assert(loadfile(rootDir .. "/quest_tracker.lua"))()(
  trackerMod, {
    i18n = i18n,
    postgame = postgame,
    postgameData = { gyms = {} },
    ascendant = ascendant,
    ascendantData = { rocket = {} },
    johtoMasters = { state = function() return { clears = 0 } end },
    signalsHub = signalsHub,
  })
local game = {
  save = {
    hallOfFame = { {} },
    pokedex = { seen = {}, owned = {} },
  },
  data = {
    maps = {},
    encounters = {},
    pokemon = {
      FIXMON_A = { dex = 1, name = "FIXMON A", evolutions = {} },
      CELEBI = { dex = 251, name = "CELEBI", evolutions = {} },
    },
    items = {},
  },
}
tracker.install(game)

equal(tracker.nextObjective(game).id, "gold",
  "a voluntary signal never replaces the connected Johto Masters objective")
local mainText = tracker.objectiveText(game)
contains(mainText, "JOHTO GATE: SILVER",
  "the authoritative main-objective page starts with the first sealed passage")
excludes(mainText, "OPTIONAL SIGNAL",
  "the main-objective API is not silently redefined as a side objective")

local optional = assert(tracker.signalsObjective(game))
equal(optional.id, "signals:mythic_retry",
  "the tracker exposes the hub's structured objective with a stable id")
equal(optional.location, "DRIFTGLASS POST",
  "the structured side objective receives the localized Atlas location")
contains(optional.title, "???",
  "an unseen objective species remains hidden")
excludes(optional.title, "CELEBI",
  "an unseen species name cannot leak through the objective title")
excludes(optional.detail, "CELEBI",
  "an unseen species name cannot leak through objective details")

local status = tracker.statusText(game)
local mainAt = assert(status:find("JOHTO GATE: SILVER", 1, true))
local sideAt = assert(status:find("OPTIONAL SIGNAL\nGOAL", 1, true))
equal(mainAt < sideAt, true,
  "Journal status always presents mandatory progress before the side goal")
contains(status, "PROGRESS: 1/3",
  "the voluntary objective retains structured progress")

game.save.pokedex.seen.CELEBI = true
contains(tracker.signalsObjectiveText(game), "CELEBI SIGNAL",
  "real Pokédex sighting reveals the objective species")
game.save.pokedex.seen.CELEBI = nil

language = "de"
contains(tracker.objectiveText(game), "JOHTO-TOR: SILBER",
  "the first connected Johto passage remains localized in German")
local germanSignals = tracker.signalsObjectiveText(game)
contains(germanSignals, "FREIWILLIGES\nSIGNALZIEL",
  "the voluntary Journal label is localized in German")
contains(germanSignals, "ORT: DRIFTGLAS-POSTEN",
  "the German signal location is sourced from the hub")
contains(germanSignals, "FORTSCHRITT: 1/3",
  "German side-goal progress is deterministic")
language = "en"

local function newAtlas(hub, quest)
  local hooks = {}
  local mod = {
    save = {
      get = function(_, _, fallback) return fallback end,
    },
    options = { get = function() return "balanced" end },
    hooks = {
      wrap = function(_, name, fn) hooks[name] = fn end,
    },
    content = {},
    ui = {
      insertBefore = function(rows, _, row)
        rows[#rows + 1] = row
        return rows
      end,
    },
  }
  return assert(loadfile(rootDir .. "/research_atlas.lua"))()(mod, {
    i18n = i18n,
    postgame = postgame,
    questTracker = quest,
    signalsHub = hub,
  })
end

do
  local atlas = newAtlas(signalsHub, tracker)
  equal(atlas.cleanMapName(game, "KANTO_ASCENDANT_DRIFTGLASS"),
    "DRIFTGLASS POST",
    "Atlas map cleanup prefers the hub's authored signal location")
  local text = atlas.objectiveText(game)
  contains(text, "JOHTO GATE: SILVER",
    "Atlas keeps the connected Johto Masters objective")
  contains(text, "OPTIONAL SIGNAL\nGOAL",
    "Atlas adds the voluntary signal objective as a separate page")
  contains(text, "LOCATION: DRIFTGLASS POST",
    "Atlas renders the signal destination with a clean location name")

  game.save.pokedex.seen.FIXMON_A = true
  local habitats = atlas.habitatRows(game)
  equal(#habitats, 1,
    "signal integration does not prefill the habitat Pokédex")
  equal(habitats[1].value, "FIXMON_A",
    "only a genuinely seen species enters known habitats")
  equal(game.save.pokedex.seen.CELEBI, nil,
    "opening signal-aware Atlas data never marks a species as seen")

  language = "de"
  equal(atlas.cleanMapName(game, "KANTO_ASCENDANT_DRIFTGLASS"),
    "DRIFTGLAS-POSTEN",
    "Atlas signal locations switch cleanly to German")
  contains(atlas.objectiveText(game), "ORT: DRIFTGLAS-POSTEN",
    "the German Atlas objective uses the localized signal destination")
  language = "en"
end

do
  local atlas = newAtlas(nil, nil)
  equal(atlas.signalsObjectiveText(game), nil,
    "an Atlas without a hub has no phantom signal objective")
  atlas.setSignalsHub(signalsHub)
  local directSignals = atlas.signalsObjectiveText(game)
  contains(directSignals, "DRIFTGLASS POST",
    "the late-wiring setter enables the same localized Atlas contract")
  excludes(directSignals, "CELEBI",
    "the Atlas fallback also hides an unseen objective species")
  tracker.setSignalsHub(nil)
  equal(tracker.signalsObjective(game), nil,
    "the tracker setter can safely detach an optional controller")
  tracker.setSignalsHub(signalsHub)
  equal(tracker.nextObjective(game).id, "gold",
    "reattaching side content still leaves main priority untouched")
end

io.write(("JOHTO SIGNALS UI PASS: %d assertions\n"):format(assertions))
