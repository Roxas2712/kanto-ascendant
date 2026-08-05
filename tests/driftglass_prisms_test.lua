local root = (... and (...):match("^(.*)[/\\]tests[/\\]"))
  or "."
package.path = root .. "/?.lua;" .. package.path

local total = 0
local function equal(actual, expected, label)
  total = total + 1
  if actual ~= expected then
    error(("%s\nexpected: %s\nactual:   %s")
      :format(label, tostring(expected), tostring(actual)), 2)
  end
end
local function truthy(value, label)
  total = total + 1
  if not value then error(label, 2) end
end
local function contains(value, needle, label)
  total = total + 1
  if not tostring(value):find(needle, 1, true) then
    error(label .. "\nmissing: " .. needle .. "\nin: " .. tostring(value), 2)
  end
end

local language = "en"
local i18n = {
  text = function(en, de) return language == "de" and de or en end,
}
local rootState = {
  earlyJohto = { receiverRepaired = false },
  resonance = {},
  prismGrotto = {},
}
local persists = 0
local state = {
  section = function(name)
    rootState[name] = rootState[name] or {}
    return rootState[name]
  end,
  persist = function() persists = persists + 1 end,
  install = function() return true end,
}

local function registry()
  return {
    rows = {},
    order = {},
    register = function(self, id, value)
      assert(self.rows[id] == nil, "duplicate registry id " .. id)
      self.rows[id] = value
      self.order[#self.order + 1] = id
    end,
    get = function(self, id) return self.rows[id] end,
  }
end

local maps, scripts, mapSongs = registry(), registry(), registry()
local events = {}
local warps = {}
local mod = {
  id = "trainer_rematch",
  content = {
    maps = maps,
    map_songs = mapSongs,
    map_scripts = scripts,
  },
  events = {
    on = function(_, name, callback, priority)
      events[name] = events[name] or {}
      events[name][#events[name] + 1] = {
        callback = callback, priority = priority,
      }
    end,
  },
  world = {
    warpTo = function(_, mapId, x, y, facing)
      warps[#warps + 1] = {
        mapId = mapId, x = x, y = y, facing = facing,
      }
      return true
    end,
  },
  ui = {},
}

local content = {
  MAP_ID = "KANTO_ASCENDANT_DRIFTGLASS",
  PALLET_RETURN = { x = 10, y = 12, facing = "up" },
  mapSupported = true,
}
local displays, menus = {}, {}
local bagFull = false
local function showText(_, text, onDone, boxOpts)
  displays[#displays + 1] = {
    text = text, onDone = onDone, options = boxOpts,
  }
  if onDone and not (boxOpts and boxOpts.choice) then onDone() end
  return true
end
local function openMenu(_, title, rows, options)
  local menu = {
    title = title, rows = rows, options = options,
    close = function(self) self.closed = true end,
  }
  menus[#menus + 1] = menu
  return true
end
local function addItem(game, item)
  if bagFull then return false end
  local inventory = game.save.inventory
  inventory[item] = (inventory[item] or 0) + 1
  return true
end

local create = assert(loadfile(root .. "/driftglass_prisms.lua"))()
local prism = create.create(mod, {
  state = state,
  content = content,
  i18n = i18n,
  showText = showText,
  openMenu = openMenu,
  addItem = addItem,
})
local game = {
  save = {
    player = {
      map = content.MAP_ID, x = 12, y = 10, facing = "down",
    },
    inventory = {},
    party = {},
  },
  data = {
    items = {
      SUN_STONE = { name = "SUN STONE" },
      KINGS_ROCK = { name = "KING'S ROCK" },
      METAL_COAT = { name = "METAL COAT" },
      DRAGON_SCALE = { name = "DRAGON SCALE" },
      UPGRADE = { name = "UP-GRADE" },
    },
  },
}
prism.install(game)

truthy(prism.register(), "the Prism Grotto registers")
equal(prism.register(), false, "registration is idempotent")
equal(#maps.order, 1, "one self-contained grotto map is registered")
local map = maps:get(prism.MAP_ID)
equal(map.tileset, "CAVERN", "the grotto uses native cave rendering")
equal(map.palette, "CAVE", "the grotto requests the shared cave palette")
equal(mapSongs:get(prism.MAP_ID), "Music_Dungeon1",
  "the grotto uses its own ominous native cave theme")
equal(#map.blocks, map.width * map.height,
  "the grotto has a rectangular block layer")
equal(#map.objects, 8,
  "one tablet, one reader and six glass pillars are authored")
equal(#map.signs, 2, "the grotto has an exit and inscription sign")
equal(map.objects[1].name, "PRISM_TABLET",
  "a visible crystal tablet owns the pillar legend")
equal(map.objects[1].sprite, "SPRITE_KA_PRISM_TABLET",
  "the tablet uses its dedicated crystal art")
equal(map.objects[2].range, "UP",
  "the reader looks toward the crystal tablet")
local seenSprites = {}
for _, statue in ipairs(prism.statues) do
  truthy(statue.sprite and statue.sprite:find("SPRITE_KA_PRISM_", 1, true),
    statue.key .. " owns a dedicated Prism sprite")
  truthy(not seenSprites[statue.sprite],
    statue.key .. " does not reuse another pillar's art")
  seenSprites[statue.sprite] = true
end
local talk = scripts:get(prism.MAP_ID).talk
truthy(talk[prism.TEXT.TABLET], "the crystal tablet is readable")
truthy(talk[prism.TEXT.READER], "the Prism Reader is interactive")
for _, statue in ipairs(prism.statues) do
  truthy(talk[statue.text], statue.key .. " pillar is interactive")
end

prism.enter(game)
contains(displays[#displays].text, "Ask the researcher",
  "the grotto remains locked before Driftglass repair")
equal(#warps, 0, "locked entry cannot warp")
rootState.earlyJohto.receiverRepaired = true
prism.enter(game)
contains(displays[#displays].text, "PRISM GROTTO",
  "repaired entry identifies its destination")
displays[#displays].options.choice(false)
equal(#warps, 0, "declining the grotto stays on Driftglass")
prism.enter(game)
displays[#displays].options.choice(true)
equal(warps[#warps].mapId, prism.MAP_ID,
  "accepting enters only the production grotto")

local reader = { frozen = false }
prism.touchStatue(game, "SUN")
contains(displays[#displays].text, "SUN PILLAR",
  "an idle pillar identifies its visible symbol")
contains(displays[#displays].text, "tablet shows",
  "an idle pillar directs players to the visible legend")
talk[prism.TEXT.TABLET](game, nil, nil)
contains(displays[#displays].text, "SUN MOON WAVE",
  "the crystal tablet explains the left-to-right legend")
contains(displays[#displays].text, "CROWN DRAGON GEAR",
  "the crystal tablet names every visible pillar")
prism.interactReader(game, reader)
contains(displays[#displays].text, "tablet names",
  "the reader gives a short first-time introduction")
equal(menus[#menus].title, "PRISM ARCHIVE",
  "the introduction opens the inscription archive")
equal(#menus[#menus].rows, 6, "all five items and Eevee rite are listed")
equal(menus[#menus].rows[1].right, "NEW",
  "unread inscriptions carry a visible NEW marker")

local function choose(key, yes)
  local menu = menus[#menus]
  local row
  for _, candidate in ipairs(menu.rows) do
    if candidate.value == key then row = candidate break end
  end
  assert(row, "missing row " .. key)
  menu.options.onChoose(row, menu)
  local prompt = displays[#displays]
  prompt.options.choice(yes)
end

choose("sunStone", true)
equal(rootState.prismGrotto.active, "sunStone",
  "accepting an inscription starts only that puzzle")
for index, statue in ipairs({ "MOON", "WAVE", "CROWN" }) do
  prism.touchStatue(game, statue)
  contains(displays[#displays].text, index .. "/4",
    "a correct Sun Prism note reports progress")
  contains(displays[#displays].text, statue,
    "a correct Sun Prism note identifies the touched symbol")
end
prism.touchStatue(game, "SUN")
equal(game.save.inventory.SUN_STONE, 1,
  "the Sun Prism grants one guaranteed Sun Stone")
equal(rootState.prismGrotto.solved.sunStone, true,
  "the solved inscription persists")
equal(rootState.prismGrotto.active, nil,
  "completion closes the active sequence")

prism.interactReader(game, reader)
choose("sunStone", true)
for _, statue in ipairs({ "MOON", "WAVE", "CROWN", "SUN" }) do
  prism.touchStatue(game, statue)
end
equal(game.save.inventory.SUN_STONE, 1,
  "rehearsing a solved riddle cannot duplicate its reward")
contains(displays[#displays].text, "already\nclaimed",
  "rehearsal clearly explains why no duplicate appears")

prism.interactReader(game, reader)
choose("kingsRock", true)
prism.touchStatue(game, "MOON")
equal(rootState.prismGrotto.progress, 0,
  "a wrong pillar resets only sequence progress")
contains(displays[#displays].text, "sequence has\nreset",
  "wrong input is explained without punishment")
contains(displays[#displays].text, "Expected:\nSUN",
  "wrong input teaches the symbol that the inscription expected")

bagFull = true
for _, statue in ipairs({ "SUN", "CROWN", "WAVE", "CROWN" }) do
  prism.touchStatue(game, statue)
end
equal(game.save.inventory.KINGS_ROCK, nil,
  "a full Bag cannot lose or counterfeit the item")
equal(rootState.prismGrotto.pendingRewards[1], "KINGS_ROCK",
  "a full-Bag reward waits with the reader")
bagFull = false
prism.interactReader(game, reader)
equal(game.save.inventory.KINGS_ROCK, 1,
  "the reader delivers a reserved reward later")
equal(#rootState.prismGrotto.pendingRewards, 0,
  "a delivered reservation is removed atomically")

prism.interactReader(game, reader)
choose("twilight", true)
contains(displays[#displays].text, "only an EEVEE",
  "the twilight rite refuses a party without Eevee")
equal(rootState.prismGrotto.active, nil,
  "the refusal never leaves a phantom active puzzle")

game.save.party = {
  { species = "ESPEON" },
  { species = "UMBREON" },
  { species = "EEVEE", johtoBond = 12 },
}
-- The no-Eevee refusal returned to a fresh archive.
choose("twilight", true)
equal(rootState.prismGrotto.active, "twilight",
  "an Eevee in the party activates the mirror")
for _, statue in ipairs({
  "SUN", "MOON", "SUN", "SUN", "MOON",
  "SUN", "MOON", "SUN", "SUN", "MOON",
}) do
  prism.touchStatue(game, statue)
end
equal(game.save.party[3].johtoBond, 100,
  "the rite reaches the existing friendship evolution threshold")
equal(rootState.prismGrotto.twilightCompletions, 1,
  "repeatable rite completions are recorded")
contains(displays[#displays].text, "ESPEON",
  "completion explains the daytime branch")
contains(displays[#displays].text, "UMBREON",
  "completion explains the nighttime branch")

prism.interactReader(game, reader)
choose("twilight", false)
contains(displays[#displays].text, "ESPEON warms",
  "an owned Espeon reveals the sun-pillar hint")
contains(displays[#displays].text, "UMBREON shades",
  "an owned Umbreon reveals the moon-pillar hint")

contains(prism.modeHint("UNLEASHED"), "early\nmigrants",
  "Full Johto immediately points players toward evolution tools")
contains(prism.modeHint("KANTO_FIRST"), "extra grotto",
  "Kanto First keeps the content explicitly optional")

local snapshot = {
  player = {
    map = prism.MAP_ID, x = 7, y = 5, facing = "left", surfing = true,
  },
  lastOutdoor = { id = prism.MAP_ID, x = 7, y = 5 },
}
truthy(prism.secureSaveLocation(snapshot),
  "a grotto save is normalized to a native restart map")
equal(snapshot.player.map, "PALLET_TOWN",
  "the safe restart target is Pallet Town")
equal(snapshot.player.surfing, false,
  "the safe restart never resumes surfing")
equal(prism.secureSaveLocation(snapshot), false,
  "save normalization is idempotent")

language = "de"
contains(prism.dialogues(game).intro, "sechs Zeichen",
  "the reader introduction is localized")
contains(prism.dialogues(game).tablet, "KRISTALLTAFEL",
  "the visible tablet is localized")
contains(prism.puzzles.twilight.riddle[2], "Nur EVOLI",
  "the German twilight inscription names Eevee")
contains(prism.modeHint("UNLEASHED"), "frühe Wanderer",
  "the Full Johto hint is localized")

truthy(persists > 0, "all durable puzzle progress uses the save backend")
print(("DRIFTGLASS PRISMS PASS: %d assertions"):format(total))
