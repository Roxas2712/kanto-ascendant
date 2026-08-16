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
local pokemonCatalog, moveCatalog = registry(), registry()
pokemonCatalog:register("SCYTHER", { id = "SCYTHER", dex = 123 })
pokemonCatalog:register("MACHOP", { id = "MACHOP", dex = 66 })
moveCatalog:register("FALSE_SWIPE", { id = "FALSE_SWIPE" })
moveCatalog:register("CROSS_CHOP", { id = "CROSS_CHOP" })
moveCatalog:register("VITAL_THROW", { id = "VITAL_THROW" })
local events = {}
local warps = {}
local mod = {
  id = "kanto_ascendant",
  content = {
    maps = maps,
    map_songs = mapSongs,
    map_scripts = scripts,
    pokemon = pokemonCatalog,
    moves = moveCatalog,
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
local partyPickers = {}
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
local rememberedMoves = {}
local fieldTech = {
  recordRememberedMove = function(mon, moveId)
    rememberedMoves[#rememberedMoves + 1] = moveId
    mon.rememberedMoves = mon.rememberedMoves or {}
    mon.rememberedMoves[moveId] = true
  end,
}
local function openParty(_, options)
  partyPickers[#partyPickers + 1] = options
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
  openParty = openParty,
  fieldTech = fieldTech,
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
    pokemon = {
      GENGAR = { name = "GENGAR", dex = 94 },
      GROWLITHE = { name = "GROWLITHE", dex = 58 },
      SCYTHER = { name = "SCYTHER", dex = 123 },
      MACHOP = { name = "MACHOP", dex = 66 },
      CHIKORITA = { name = "CHIKORITA", dex = 152 },
      MAGIKARP = { name = "MAGIKARP", dex = 129 },
    },
    moves = {
      CRUNCH = { name = "CRUNCH", pp = 15 },
      METAL_CLAW = { name = "METAL CLAW", pp = 35 },
      FALSE_SWIPE = { name = "FALSE SWIPE", pp = 40 },
      CROSS_CHOP = { name = "CROSS CHOP", pp = 5 },
      VITAL_THROW = { name = "VITAL THROW", pp = 10 },
      IRON_TAIL = { name = "IRON TAIL", pp = 15 },
      SHADOW_BALL = { name = "SHADOW BALL", pp = 15 },
      FLAME_WHEEL = { name = "FLAME WHEEL", pp = 25 },
      GIGA_DRAIN = { name = "GIGA DRAIN", pp = 10 },
      SLUDGE_BOMB = { name = "SLUDGE BOMB", pp = 10 },
      POWDER_SNOW = { name = "POWDER SNOW", pp = 25 },
      CUT = { name = "CUT", pp = 30 },
      TACKLE = { name = "TACKLE", pp = 35 },
      LICK = { name = "LICK", pp = 30 },
      NIGHT_SHADE = { name = "NIGHT SHADE", pp = 15 },
      CONFUSE_RAY = { name = "CONFUSE RAY", pp = 10 },
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
equal(#map.objects, 9,
  "tablet, reader, six glass pillars and a visible exit are authored")
equal(#map.signs, 1, "only the wall inscription remains a hidden sign")
equal(map.objects[9].name, "PRISM_EXIT_ARCH",
  "the return interaction has an explicit visible map object")
equal(map.objects[9].x, prism.EXIT_ARCH.x,
  "the visible return arch uses the documented south approach cell")
equal(map.objects[9].y, prism.EXIT_ARCH.y,
  "the return arch no longer blocks the arrival lane")
equal(map.objects[9].sprite, "SPRITE_KA_PRISM_SEAM",
  "the return arch uses the entrance seam instead of duplicating the tablet")
truthy(map.objects[9].sprite ~= map.objects[1].sprite,
  "the south exit is visually distinct from the north crystal tablet")
truthy(prism.EXIT_STEP.y > prism.ARRIVAL.y,
  "the return trigger is south of the north-facing arrival")
truthy(prism.EXIT_STEP.y < prism.EXIT_ARCH.y,
  "the return trigger is the floor cell directly before the arch")
equal(map.objects[1].name, "PRISM_TABLET",
  "a visible crystal tablet owns the pillar legend")
equal(map.objects[1].sprite, "SPRITE_KA_PRISM_TABLET",
  "the tablet uses its dedicated crystal art")
equal(map.objects[2].range, "UP",
  "the reader looks toward the crystal tablet")
local resonanceSpecies = 0
for _ in pairs(prism.resonanceRules) do
  resonanceSpecies = resonanceSpecies + 1
end
equal(resonanceSpecies, 106,
  "all Kanto species covered by an implemented Crystal move are indexed")
equal(prism.resonanceRules.MACHOP.CROSS_CHOP.level, 37,
  "the 251-species source derives Machop's vetted Crystal Cross Chop level")
equal(prism.resonanceRules.MACHOP.VITAL_THROW.level, 31,
  "the 251-species source derives Machop's vetted Crystal Vital Throw level")
local auditedPursuit = false
for _, row in ipairs(prism.resonanceAudit.unsupportedLevelRows) do
  if row.species == "SCYTHER" and row.move == "PURSUIT"
      and row.level == 12 then
    auditedPursuit = row.reason == "move-unavailable"
    break
  end
end
truthy(auditedPursuit,
  "Scyther's unsupported Pursuit switch mechanic remains explicit in audit")
local seenSprites = {}
for _, statue in ipairs(prism.statues) do
  truthy(statue.sprite and statue.sprite:find("SPRITE_KA_PRISM_", 1, true),
    statue.key .. " owns a dedicated Prism sprite")
  truthy(not seenSprites[statue.sprite],
    statue.key .. " does not reuse another pillar's art")
  seenSprites[statue.sprite] = true
end
local mapScript = scripts:get(prism.MAP_ID)
local talk = mapScript.talk
truthy(type(mapScript.onStep) == "function",
  "the grotto owns a movement-triggered return hook")
truthy(talk[prism.TEXT.TABLET], "the crystal tablet is readable")
truthy(talk[prism.TEXT.READER], "the Prism Reader is interactive")
for _, statue in ipairs(prism.statues) do
  truthy(talk[statue.text], statue.key .. " pillar is interactive")
  truthy(statue.text ~= prism.TEXT.EXIT,
    statue.key .. " remains a puzzle control rather than a hidden exit")
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

-- The exit is a positional map hook, not a renderer- or A-target-dependent
-- NPC interaction.  This compact contract matrix covers the public 0.1.96
-- engine and the 0.1.98 integration profiles, every Gen-I ROM, the three
-- selectable protagonists, portrait/mobile input, Yellow follower presence,
-- and native/Voxel rendering without coupling the handler to any of them.
local exitMatrix = {
  {
    engine = "0.1.96", version = "red", avatar = "RED",
    orientation = "landscape", input = "keyboard",
    renderer = "native", follower = false, solved = false,
  },
  {
    engine = "0.1.98", version = "blue", avatar = "BLUE",
    orientation = "portrait", input = "touch",
    renderer = "native", follower = false, solved = true,
  },
  {
    engine = "0.1.96", version = "yellow", avatar = "GREEN",
    orientation = "portrait", input = "touch",
    renderer = "voxel", follower = true, solved = false,
  },
  {
    engine = "0.1.98", version = "yellow", avatar = "RED",
    orientation = "landscape", input = "controller",
    renderer = "voxel", follower = true, solved = true,
  },
}
local savedSolved = rootState.prismGrotto.solved
local persistsBeforeExit = persists
for _, profile in ipairs(exitMatrix) do
  local label = table.concat({
    profile.engine, profile.version, profile.avatar, profile.orientation,
    profile.input, profile.renderer,
    profile.follower and "follower-on" or "follower-off",
    profile.solved and "post-trial" or "pre-trial",
  }, "/")
  rootState.prismGrotto.solved = profile.solved and { sunStone = true } or {}
  local overworld = {
    player = {
      cellX = prism.ARRIVAL.x, cellY = prism.ARRIVAL.y,
      facing = prism.ARRIVAL.facing,
    },
    npcs = profile.follower and {
      { id = "PIKACHU_FOLLOWER", cellX = 7, cellY = 13 },
    } or {},
    profile = profile,
  }
  equal(mapScript.onStep(game, overworld,
      prism.EXIT_STEP.x, prism.EXIT_STEP.y - 1), false,
    label .. " does not exit one cell early")
  local before = #warps
  equal(mapScript.onStep(game, overworld,
      prism.EXIT_STEP.x, prism.EXIT_STEP.y), true,
    label .. " exits on the south floor trigger")
  equal(#warps, before + 1,
    label .. " starts exactly one return transition")
  equal(warps[#warps].mapId, prism.OUTPOST_MAP_ID,
    label .. " returns to Driftglass Post")
  equal(warps[#warps].x, prism.RETURN.x,
    label .. " preserves the established return x")
  equal(warps[#warps].y, prism.RETURN.y,
    label .. " preserves the established return y")
end
rootState.prismGrotto.solved = savedSolved
equal(persists, persistsBeforeExit,
  "leaving is independent of save writes and puzzle persistence")

local beforeFallback = #warps
talk[prism.TEXT.EXIT](game, nil, map.objects[9])
displays[#displays].options.choice(false)
equal(#warps, beforeFallback,
  "declining the arch's A-button fallback stays in the grotto")
talk[prism.TEXT.EXIT](game, nil, map.objects[9])
displays[#displays].options.choice(true)
equal(#warps, beforeFallback + 1,
  "the south arch retains an A-button fallback")
equal(warps[#warps].mapId, prism.OUTPOST_MAP_ID,
  "the fallback uses the same Driftglass return destination")

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
contains(displays[#displays].text, "Attune a Kanto",
  "the central tablet offers the separate Kanto move resonance")
local tabletPrompt = displays[#displays]
tabletPrompt.options.choice(true)
truthy(partyPickers[#partyPickers],
  "accepting move resonance opens a party picker")

local gengar = {
  species = "GENGAR", level = 40,
  moves = { { id = "TACKLE", pp = 35 } },
}
partyPickers[#partyPickers].onSwitch(gengar)
equal(menus[#menus].title, "JOHTO MEMORY",
  "a Kanto partner opens the Johto move list")
local gengarRows = prism.resonanceMoves(game, gengar)
local shadowBall
for _, row in ipairs(gengarRows) do
  if row.id == "SHADOW_BALL" then shadowBall = row break end
end
truthy(shadowBall, "Gengar receives its legal Crystal Shadow Ball access")
equal(shadowBall.source, "machine",
  "Gengar's Shadow Ball is identified as immediate TM access")
equal(shadowBall.locked, false,
  "TM-based resonance is not incorrectly level-gated")
truthy(prism.teachResonanceMove(game, gengar, "SHADOW_BALL"),
  "the crystal teaches an implemented legal Gen-II move")
equal(gengar.moves[2].id, "SHADOW_BALL",
  "a free move slot receives the resonant move")
equal(gengar.rememberedMoves.SHADOW_BALL, true,
  "a crystal-taught move remains available to the Move Reminder")

local growlithe = {
  species = "GROWLITHE", level = 33,
  moves = { { id = "TACKLE", pp = 35 } },
}
local growlitheRows = prism.resonanceMoves(game, growlithe)
local flameWheel
for _, row in ipairs(growlitheRows) do
  if row.id == "FLAME_WHEEL" then flameWheel = row break end
end
truthy(flameWheel, "Growlithe exposes its original level-up move")
equal(flameWheel.level, 34,
  "Growlithe keeps Crystal's Flame Wheel level")
equal(flameWheel.locked, true,
  "a genuinely under-levelled partner is visibly locked")
local learned, reason, required =
  prism.teachResonanceMove(game, growlithe, "FLAME_WHEEL")
equal(learned, false, "an under-levelled move cannot be taught early")
equal(reason, "level", "the refusal identifies the level gate")
equal(required, 34, "the refusal returns the exact required level")
prism.openResonanceMoves(game, growlithe)
local lockedMenu = menus[#menus]
local lockedFlameWheel
for _, row in ipairs(lockedMenu.rows) do
  if row.value.id == "FLAME_WHEEL" then
    lockedFlameWheel = row
    break
  end
end
truthy(lockedFlameWheel, "the locked move remains visible in the crystal menu")
equal(lockedFlameWheel.right, "LV34",
  "the move list previews the exact return level")
lockedMenu.options.onChoose(lockedFlameWheel, lockedMenu)
contains(displays[#displays].text, "Come back at\nLv. 34.",
  "the in-game refusal tells the player exactly when to return")
growlithe.level = 34
truthy(prism.teachResonanceMove(game, growlithe, "FLAME_WHEEL"),
  "the same move unlocks at the exact original level")

local scyther = {
  species = "SCYTHER", level = 17,
  moves = { { id = "TACKLE", pp = 35 } },
}
local scytherRows = prism.resonanceMoves(game, scyther)
local falseSwipe
for _, row in ipairs(scytherRows) do
  if row.id == "FALSE_SWIPE" then falseSwipe = row break end
end
truthy(falseSwipe,
  "Scyther exposes its implemented canonical Crystal move")
equal(falseSwipe.level, 18,
  "Scyther keeps Crystal's exact False Swipe level")
equal(falseSwipe.locked, true,
  "level-17 Scyther cannot receive level-18 False Swipe")
scyther.level = 18
truthy(prism.teachResonanceMove(game, scyther, "FALSE_SWIPE"),
  "level-18 Scyther can awaken False Swipe")
equal(scyther.moves[#scyther.moves].id, "FALSE_SWIPE",
  "Scyther receives the species-specific Johto move")

local johtoRows, johtoReason = prism.resonanceMoves(game, {
  species = "CHIKORITA", level = 20, moves = {},
})
equal(#johtoRows, 0, "the Kanto crystal does not rewrite Johto learnsets")
equal(johtoReason, "not-kanto",
  "non-Kanto partners receive the dedicated regional refusal")
local magikarpRows, magikarpReason = prism.resonanceMoves(game, {
  species = "MAGIKARP", level = 30, moves = {},
})
equal(#magikarpRows, 0,
  "a Kanto species without an implemented resonant move is unchanged")
equal(magikarpReason, "none",
  "a legal Kanto non-match is distinct from the regional refusal")

local fullGengar = {
  species = "GENGAR", level = 50,
  moves = {
    { id = "CUT", pp = 30 },
    { id = "TACKLE", pp = 35 },
    { id = "LICK", pp = 30 },
    { id = "NIGHT_SHADE", pp = 15 },
  },
}
local fullLearned, fullReason =
  prism.teachResonanceMove(game, fullGengar, "SHADOW_BALL")
equal(fullLearned, false, "the crystal never replaces one of four moves")
equal(fullReason, "full", "a full moveset receives the dedicated refusal")
local menuCountBeforeFull = #menus
prism.openResonanceMoves(game, fullGengar)
contains(displays[#displays].text, "Route 5\nMOVE DELETER",
  "a full moveset is directed to the existing Route 5 service")
equal(#menus, menuCountBeforeFull,
  "the crystal does not open a duplicate move-deletion menu")
equal(fullGengar.moves[1].id, "CUT",
  "the crystal leaves even a removable HM untouched")
table.remove(fullGengar.moves, 2)
truthy(prism.teachResonanceMove(game, fullGengar, "SHADOW_BALL"),
  "the crystal teaches after Route 5 has opened a move slot")
equal(fullGengar.moves[4].id, "SHADOW_BALL",
  "the crystal appends its move to the newly free slot")
equal(rememberedMoves[#rememberedMoves], "SHADOW_BALL",
  "the crystal-taught move is handed to the existing memory system")

prism.interactReader(game, reader)
contains(displays[#displays].text, "tablet names",
  "the reader gives a short first-time introduction")
contains(displays[#displays].text, "awakens Johto",
  "the reader introduces the tablet's second purpose")
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
contains(prism.dialogues(game).intro, "Johto-\nAttacken",
  "the reader's move-resonance explanation is localized")
contains(prism.dialogues(game).tabletResonance, "Kanto-POKéMON",
  "the tablet's attunement prompt is localized")
contains(prism.puzzles.twilight.riddle[2], "Nur EVOLI",
  "the German twilight inscription names Eevee")
contains(prism.modeHint("UNLEASHED"), "frühe Wanderer",
  "the Full Johto hint is localized")

truthy(persists > 0, "all durable puzzle progress uses the save backend")
print(("DRIFTGLASS PRISMS PASS: %d assertions"):format(total))
