-- Focused headless acceptance for the post-Hall-of-Fame HEVO researchers.
-- Run from gen1recomp with KA_HIDDEN_EVOLUTION_MOD set to the Authority root.
package.path = "./?.lua;./?/init.lua;" .. package.path
if not _G.love then _G.love = require("tests.love_stub") end

local root = assert(os.getenv("KA_HIDDEN_EVOLUTION_MOD"),
  "KA_HIDDEN_EVOLUTION_MOD is required")
local Data = require("src.core.Data")
Data:load()
local MapLoader = require("src.world.MapLoader")
local Font = require("src.render.Font")
local TextBox = require("src.render.TextBox")

local checks = 0
local function check(ok, message)
  assert(ok, message)
  checks = checks + 1
end
local function eq(actual, expected, message)
  assert(actual == expected,
    (message or "values differ") .. ": expected " .. tostring(expected)
      .. ", got " .. tostring(actual))
  checks = checks + 1
end
local function tableCount(value)
  local count = 0
  for _ in pairs(value or {}) do count = count + 1 end
  return count
end

-- Measure German strings with the shipped German font mapping, not byte
-- length.  Umlauts are one rendered glyph in that mapping.
local germanCharmap = assert(loadfile("mods/deutsch/lang/charmap.lua"))()
for sequence, code in pairs(germanCharmap) do
  Data.font.charmap[#Data.font.charmap + 1] = {
    seq = sequence, code = code,
  }
end
Font.load(Data)

local saved, registeredText, registeredScripts, eventHandlers = {}, {}, {}, {}
local activeCharacter = "RED"
local activeOw
local spawned, removed, worldFlags = {}, {}, {}
local mod = {
  id = "kanto_ascendant",
  ui = {},
  save = {
    get = function(_, key) return saved[key] end,
    set = function(_, key, value) saved[key] = value end,
  },
  content = {
    text = { register = function(_, id, value) registeredText[id] = value end },
    text_pointers = { patch = function() end },
    map_scripts = {
      register = function(_, id, value) registeredScripts[id] = value end,
    },
  },
  events = {
    on = function(_, name, callback)
      eventHandlers[name] = eventHandlers[name] or {}
      eventHandlers[name][#eventHandlers[name] + 1] = callback
    end,
  },
}

local writeCount = 0
local game = {
  data = Data,
  save = { flags = {}, hallOfFame = {} },
  stack = { push = function() end },
  writeSave = function() writeCount = writeCount + 1 end,
}

local function npcAtCell(x, y)
  for _, npc in ipairs(activeOw and activeOw.npcs or {}) do
    if npc.def and npc.def.x == x and npc.def.y == y then return npc end
  end
end

mod.world = {
  overworld = function() return activeOw end,
  setFlag = function(_, name, value)
    worldFlags[name] = value
    game.save.flags[name] = value
    return true
  end,
  spawnNpc = function(_, mapId, object)
    local map = assert(Data.maps[mapId])
    local copy = {}
    for key, value in pairs(object) do copy[key] = value end
    copy.index = 900 + #spawned
    copy.runtime, copy.owner = true, mod.id
    map.objects[#map.objects + 1] = copy
    local id = mapId .. "_obj_" .. tostring(copy.index)
    local npc = { id = id, def = copy, frozen = false,
      facePlayer = function() end }
    activeOw.npcs[#activeOw.npcs + 1] = npc
    spawned[#spawned + 1] = { id = id, map = mapId, def = copy }
    return id
  end,
  removeNpc = function(_, id)
    if not activeOw then return nil, "no overworld" end
    local mapId = id:match("^(.-)_obj_")
    local map = mapId and Data.maps[mapId]
    for index = #(map and map.objects or {}), 1, -1 do
      local object = map.objects[index]
      if mapId .. "_obj_" .. tostring(object.index) == id
          and object.runtime and object.owner == mod.id then
        table.remove(map.objects, index)
      end
    end
    for index = #(activeOw and activeOw.npcs or {}), 1, -1 do
      if activeOw.npcs[index].id == id then table.remove(activeOw.npcs, index) end
    end
    removed[#removed + 1] = id
    return true
  end,
}

local postgame = {
  -- Same canonical rule exported by postgame.lua: native hall history or
  -- the Champion migration flag opens postgame content.
  hasHallOfFame = function(save)
    return save and ((type(save.hallOfFame) == "table"
        and #save.hallOfFame > 0)
      or (type(save.flags) == "table"
        and save.flags.EVENT_BEAT_CHAMPION_RIVAL == true)) or false
  end,
}

local displayed, displayOptions, menus, completed = {}, {}, {}, 0
local hints = assert(loadfile(root .. "/hidden_evolution_story_hints.lua"))()(mod, {
  activeCharacter = function() return activeCharacter end,
  postgame = postgame,
  showText = function(_, text, done, options)
    displayed[#displayed + 1] = text
    displayOptions[#displayed] = options
    if done then done() end
    return true
  end,
  openMenu = function(_, title, rows, options)
    menus[#menus + 1] = { title = title, rows = rows, options = options }
    return true
  end,
})

check(hints.register(), "researcher package registers")
check(hints.install(game), "researcher package installs")
eq(#eventHandlers["map.entered"], 1, "map entry installs one refresh hook")
eq(#eventHandlers["save.loaded"], 1, "save load installs one refresh hook")
eq(#eventHandlers["save.loading"], 1, "save transition installs one purge hook")
eq(#eventHandlers["save.created"], 1, "new game installs one reconciliation hook")
eq(#eventHandlers["map.reloaded"], 1, "map reload installs one researcher reconciliation hook")
eq(#eventHandlers["world.stepped"], 1,
  "field step installs one occupied-cell retry hook")

local placement = {
  RED = { map = "CELADON_CITY", x = 38, y = 22, access = 3 },
  BLUE = { map = "CINNABAR_ISLAND", x = 6, y = 11, access = 4 },
  GREEN = { map = "PEWTER_CITY", x = 8, y = 3, access = 4 },
}
for _, key in ipairs({ "RED", "BLUE", "GREEN" }) do
  local hint, expected = hints.HINTS[key], placement[key]
  activeCharacter = key
  eq(hint.map, expected.map, key .. " researcher city")
  eq(hint.x, expected.x, key .. " researcher x")
  eq(hint.y, expected.y, key .. " researcher y")
  eq(hint.sprite, "SPRITE_SCIENTIST",
    key .. " researcher is visibly a scientist")
  check(registeredText[hint.text] ~= nil, key .. " text is registered")
  check(registeredScripts[hint.map]
      and registeredScripts[hint.map].talk[hint.text],
    key .. " city talk script is registered")

  local map = MapLoader.load(Data, hint.map)
  check(map:isWalkableCell(hint.x, hint.y),
    key .. " researcher cell is native walkable street")
  check(not map:warpAtCell(hint.x, hint.y),
    key .. " researcher cell is not a warp")
  local access = 0
  for _, delta in ipairs({ { 0, -1 }, { 1, 0 }, { 0, 1 }, { -1, 0 } }) do
    if map:isWalkableCell(hint.x + delta[1], hint.y + delta[2]) then
      access = access + 1
    end
  end
  eq(access, expected.access,
    key .. " has the audited four-way/street approach count")
  local nearest = math.huge
  for _, object in ipairs(Data.maps[hint.map].objects or {}) do
    if not object.runtime then
      check(not (object.x == hint.x and object.y == hint.y),
        key .. " does not overlap a base NPC")
      nearest = math.min(nearest,
        math.abs(object.x - hint.x) + math.abs(object.y - hint.y))
    end
  end
  eq(nearest, 12, key .. " base-NPC Manhattan clearance")

  -- Pre-Hall-of-Fame: absent.  Champion state: exact-cell spawn.  Removing
  -- the hall state and refreshing removes the owned runtime object again.
  activeOw = { map = map, npcs = {}, player = { cellX = 0, cellY = 0 } }
  function activeOw:npcAtCell(x, y) return npcAtCell(x, y) end
  game.save.hallOfFame, game.save.flags = {}, {}
  local before = #spawned
  local ok, why = hints.refresh(game, hint.map)
  check(ok == false and why == "pre-hall",
    key .. " researcher is absent before Hall of Fame")
  eq(#spawned, before, key .. " pre-Hall refresh spawns nothing")
  game.save.flags.EVENT_BEAT_CHAMPION_RIVAL = true
  check(hints.refresh(game, hint.map),
    key .. " Champion migration authority spawns researcher")
  local live = assert(activeOw.npcs[1], key .. " runtime researcher missing")
  eq(live.def.x, hint.x, key .. " runtime researcher exact x")
  eq(live.def.y, hint.y, key .. " runtime researcher exact y")
  eq(live.def.movement, "STAY", key .. " runtime researcher stays on audited cell")
  local spawnedAfterMigration = #spawned
  check(hints.refresh(game, hint.map),
    key .. " repeated Champion refresh keeps researcher active")
  eq(#spawned, spawnedAfterMigration,
    key .. " repeated Champion refresh does not duplicate researcher")
  eq(#activeOw.npcs, 1,
    key .. " repeated Champion refresh keeps exactly one live researcher")
  game.save.flags.EVENT_BEAT_CHAMPION_RIVAL = nil
  local removedBefore = #removed
  ok, why = hints.refresh(game, hint.map)
  check(ok == false and why == "pre-hall",
    key .. " closing Hall state removes researcher")
  eq(#removed, removedBefore + 1, key .. " owned runtime researcher removed")
  eq(#activeOw.npcs, 0, key .. " no pre-Hall live researcher remains")
  ok, why = hints.refresh(game, hint.map)
  check(ok == false and why == "pre-hall",
    key .. " repeated pre-Hall refresh remains closed")
  eq(#removed, removedBefore + 1,
    key .. " repeated pre-Hall refresh is removal-idempotent")

  -- A staged ambient Pokémon may momentarily reserve the professor's first
  -- audited cell. The researcher must use the next audited street cell and
  -- survive the public map-reload reconciliation instead of disappearing.
  game.save.flags.EVENT_BEAT_CHAMPION_RIVAL = true
  local ambient = { id = "ambient", def = { name = "AMBIENT", x = hint.x, y = hint.y } }
  activeOw.npcs = { ambient }
  check(hints.refresh(game, hint.map), key .. " occupied primary cell uses fallback")
  local fallback = assert(activeOw.npcs[2], key .. " fallback researcher missing")
  check(fallback.def.x ~= hint.x or fallback.def.y ~= hint.y,
    key .. " fallback did not leave occupied primary cell")
  local beforeReload = #spawned
  eventHandlers["map.reloaded"][1]({ game = game, mapId = hint.map })
  eq(#spawned, beforeReload,
    key .. " map reload keeps one fallback researcher")
  game.save.flags.EVENT_BEAT_CHAMPION_RIVAL = nil
  hints.refresh(game, hint.map)
  activeOw.npcs = {}

  -- If every audited cell is temporarily occupied, the real public field-step
  -- event retries once those staged actors have moved away.
  game.save.flags.EVENT_BEAT_CHAMPION_RIVAL = true
  for index, cell in ipairs(hint.cells) do
    activeOw.npcs[index] = {
      id = "blocker-" .. index,
      def = { name = "BLOCKER_" .. index, x = cell[1], y = cell[2] },
    }
  end
  ok, why = hints.refresh(game, hint.map)
  check(ok == false and why == "occupied",
    key .. " all occupied researcher cells fail closed")
  eq(#activeOw.npcs, #hint.cells,
    key .. " occupied refresh does not overwrite staged actors")
  activeOw.npcs = {}
  local beforeStep = #spawned
  eventHandlers["world.stepped"][1]({ game = game, mapId = hint.map })
  eq(#spawned, beforeStep + 1,
    key .. " public field-step retry restores the researcher")
  eq(#activeOw.npcs, 1,
    key .. " field-step retry leaves exactly one live researcher")
  game.save.flags.EVENT_BEAT_CHAMPION_RIVAL = nil
  hints.refresh(game, hint.map)
  activeOw.npcs = {}

  -- Native Hall history and save.loaded use the same canonical gate.  This
  -- models a migrated/continued slot losing and regaining Hall authority
  -- while its map is already live, which is the runtime regression caught
  -- by the visual pilot.
  game.save.hallOfFame = { { qa = "native-hall" } }
  eventHandlers["save.loaded"][1]({ game = game })
  eq(#activeOw.npcs, 1,
    key .. " native Hall reload restores exactly one live researcher")
  local spawnedAfterNativeHall = #spawned
  eventHandlers["save.loaded"][1]({ game = game })
  eq(#spawned, spawnedAfterNativeHall + 1,
    key .. " repeated post-Hall save reload rebuilds one owned researcher")
  eq(#activeOw.npcs, 1,
    key .. " repeated post-Hall save reload keeps exactly one researcher")
  local spawnedBeforeSteps = #spawned
  local textRowsBeforeSteps = tableCount(registeredText)
  local scriptRowsBeforeSteps = tableCount(registeredScripts)
  for _ = 1, 64 do
    eventHandlers["world.stepped"][1]({ game = game, mapId = hint.map })
  end
  eq(#spawned, spawnedBeforeSteps,
    key .. " repeated field steps do not duplicate researcher actors")
  eq(#activeOw.npcs, 1,
    key .. " repeated field steps retain exactly one live researcher")
  eq(tableCount(registeredText), textRowsBeforeSteps,
    key .. " field-step reconciliation does not register text")
  eq(tableCount(registeredScripts), scriptRowsBeforeSteps,
    key .. " field-step reconciliation does not register map scripts")
  game.save.hallOfFame = {}
  eventHandlers["save.loaded"][1]({ game = game })
  eq(#activeOw.npcs, 0,
    key .. " Hall loss on save reload removes the active runtime researcher")

  -- Only the matching post-Hall character gets this city's scientist.  This
  -- prevents unrelated runtime actors and riddles leaking across character
  -- slots while the merged map catalog remains resident.
  game.save.flags.EVENT_BEAT_CHAMPION_RIVAL = true
  activeCharacter = key == "RED" and "BLUE" or "RED"
  ok, why = hints.refresh(game, hint.map)
  check(ok == false and why == "character",
    key .. " wrong-character city refresh stays closed")
  eq(#activeOw.npcs, 0,
    key .. " wrong-character city has no researcher actor")
  activeCharacter = key

  -- Continue -> New Game must clear the outgoing process-wide runtime object
  -- before the fresh save becomes authoritative.
  check(hints.refresh(game, hint.map),
    key .. " post-Hall researcher restored before slot-transition proof")
  eq(#activeOw.npcs, 1, key .. " transition fixture starts with one researcher")
  activeOw = nil
  eventHandlers["save.loading"][1]({ game = game })
  local stale = 0
  for _, object in ipairs(Data.maps[hint.map].objects or {}) do
    if object.runtime and object.owner == mod.id
        and object.name == hint.object then stale = stale + 1 end
  end
  eq(stale, 0,
    key .. " title-bound save.loading purges outgoing researcher definition")
  game.save.flags, game.save.hallOfFame = {}, {}
  activeOw = { map = map, npcs = {}, player = { cellX = 0, cellY = 0 } }
  function activeOw:npcAtCell(x, y) return npcAtCell(x, y) end
  eventHandlers["save.created"][1]({ game = game })
  eq(#activeOw.npcs, 0, key .. " New Game keeps researcher absent")
end

-- The deduction is now deliberately fair: each text names two real landmarks
-- bracketing the authored fissure instead of asking about an unexplained
-- abstract "stone face".  The answer still selects the matching location.
local landmarkClues = {
  RED = { en = { "viridian", "indigo" }, de = { "vertania", "indigo" } },
  GREEN = { en = { "pewter", "mt moon" }, de = { "marmoria", "mondberg" } },
  BLUE = { en = { "cerulean", "nugget" }, de = { "azuria", "nugget" } },
}
for _, key in ipairs({ "RED", "BLUE", "GREEN" }) do
  local hint = hints.HINTS[key]
  eq(#hint.choices, 3, key .. " has exactly three deductions")
  check(type(hint.professor) == "string"
      and hint.professor:match("^Professor "),
    key .. " retains an individual professor identity")
  for _, language in ipairs({ "en", "de" }) do
    local menuTitle = hint.question[language]
    check(not menuTitle:find("[\n\r\f]"),
      key .. " " .. language .. " ListMenu question is exactly one line")
    check(Font.width(menuTitle) <= 18 * 8,
      key .. " " .. language .. " ListMenu question exceeds 18 glyph pixels")
    local riddle = hint.riddle[language]:lower()
    for _, token in ipairs(landmarkClues[key][language]) do
      check(riddle:find(token, 1, true) ~= nil,
        key .. " " .. language .. " riddle lacks fair landmark " .. token)
    end
    for _, field in ipairs({ "riddle", "question", "wrong", "solved",
        "cooldown", "retry", "dismissal" }) do
      local pages = TextBox.paginate(hint[field][language], 18)
      for page, lines in ipairs(pages) do
        check(#lines <= 2,
          key .. " " .. language .. " " .. field
            .. " overflows page " .. page .. ": "
            .. table.concat(lines, " | "))
        for _, line in ipairs(lines) do
          check(Font.width(line) <= 18 * 8,
            key .. " " .. language .. " " .. field
              .. " overwide line: " .. line)
        end
      end
    end
    for _, choice in ipairs(hint.choices) do
      check(Font.width(choice[language]) <= 18 * 8,
        key .. " " .. language .. " choice is too wide")
    end
    if language == "en" then
      check(hint.solved.en:find("Fissure opened", 1, true) ~= nil,
        key .. " solved directions explicitly open the fissure")
    else
      check(hint.solved.de:find("Riss geöffnet", 1, true) ~= nil,
        key .. " solved directions explicitly open the fissure")
    end
    check(hint.wrong[language]:lower():find(language == "de"
        and "komm wieder" or "come back", 1, true) ~= nil,
      key .. " " .. language .. " wrong answer lacks return instruction")
    check(hint.cooldown[language]:lower():find(language == "de"
        and "später" or "later", 1, true) ~= nil,
      key .. " " .. language .. " cooldown lacks later instruction")
  end
end

-- Real dialogue flow: one wrong answer closes the conversation, persists a
-- 250-physical-step cooldown, and leaves the fissure sealed.  Exact step 249
-- remains locked; exact step 250 offers a safe-default-NO retry.  Only YES +
-- a correct fresh answer writes the canonical discovery authority.
local warpCount = 0
mod.world.warpTo = function() warpCount = warpCount + 1 end
for _, key in ipairs({ "RED", "BLUE", "GREEN" }) do
  local hint = hints.HINTS[key]
  saved[hints.RUN_STATE] = nil
  game.save.flags = { EVENT_BEAT_CHAMPION_RIVAL = true }
  activeCharacter = key == "RED" and "BLUE" or "RED"
  local menuBefore, doneBefore = #menus, completed
  local npc = { frozen = false, facePlayer = function() end }
  check(hints.talk(key, game, { player = {} }, npc,
    function() completed = completed + 1 end),
    key .. " wrong-character dialogue opens")
  eq(#menus, menuBefore, key .. " wrong character receives no quiz")
  eq(completed, doneBefore + 1, key .. " wrong-character dialogue completes")
  check(game.save.flags[hints.FLAG_PREFIX .. key] ~= true,
    key .. " wrong character sets no discovery")

  activeCharacter = key
  menuBefore, doneBefore = #menus, completed
  npc = { frozen = false, facePlayer = function() end }
  check(hints.talk(key, game, { player = {} }, npc,
    function() completed = completed + 1 end),
    key .. " matching-character dialogue opens")
  eq(#menus, menuBefore + 1, key .. " matching character receives a quiz")
  local firstMenu = menus[#menus]
  eq(#firstMenu.rows, 3, key .. " runtime menu has three answers")
  firstMenu.options.onCancel()
  eq(hints.retryProgress(key), nil,
    key .. " cancelling the answer menu starts no cooldown")
  eq(completed, doneBefore + 1,
    key .. " cancelling the answer menu exits cleanly")
  npc = { frozen = false, facePlayer = function() end }
  check(hints.talk(key, game, { player = {} }, npc,
    function() completed = completed + 1 end),
    key .. " deduction can be reopened immediately after cancel")
  eq(#menus, menuBefore + 2,
    key .. " cancel does not suppress a fresh first attempt")
  firstMenu = menus[#menus]
  doneBefore = completed
  local wrong
  for _, row in ipairs(firstMenu.rows) do
    if row.value ~= hint.correct then wrong = row break end
  end
  local writesBeforeFailure = writeCount
  firstMenu.options.onChoose(wrong)
  eq(#menus, menuBefore + 2, key .. " wrong answer does not reopen quiz")
  check(game.save.flags[hints.FLAG_PREFIX .. key] ~= true,
    key .. " wrong answer sets no discovery")
  eq(completed, doneBefore + 1,
    key .. " wrong answer ends and unfreezes the dialogue")
  check(displayed[#displayed]:find("Come back when you", 1, true) ~= nil,
    key .. " wrong answer gives the promised return instruction")
  local steps, target, attempts = hints.retryProgress(key)
  eq(steps, 0, key .. " wrong answer starts cooldown at zero steps")
  eq(target, 250, key .. " cooldown requires exactly 250 steps")
  eq(attempts, 1, key .. " first wrong answer records first attempt")
  eq(writeCount, writesBeforeFailure + 1,
    key .. " wrong-answer gate transition is flushed immediately")

  -- Merely changing the presentation character, entering/reloading a map or
  -- talking again cannot advance or erase the save-local penalty.
  activeCharacter = key == "RED" and "BLUE" or "RED"
  for _ = 1, 5 do
    eventHandlers["world.stepped"][1]({ game = game, mapId = "ROUTE_1" })
  end
  eq(hints.retryProgress(key), 0,
    key .. " wrong character cannot work off cooldown steps")
  activeCharacter = key
  eventHandlers["map.entered"][1]({ game = game, mapId = "ROUTE_1" })
  eventHandlers["map.reloaded"][1]({ game = game, mapId = "ROUTE_1" })
  eq(hints.retryProgress(key), 0,
    key .. " map enter/reload cannot bypass the cooldown")

  local originalSlot = saved
  saved = {}
  local originalSave = game.save
  game.save = { flags = {}, hallOfFame = {} }
  eventHandlers["save.created"][1]({ game = game })
  eq(hints.retryProgress(key), nil,
    key .. " New Game inherits no cooldown from the outgoing slot")
  saved = originalSlot
  game.save = originalSave
  eventHandlers["save.loaded"][1]({ game = game })
  eq(hints.retryProgress(key), 0,
    key .. " loading the original slot restores its cooldown")

  local cooldownMenus, cooldownDone = #menus, completed
  check(hints.talk(key, game, { player = {} }, npc,
    function() completed = completed + 1 end),
    key .. " early cooldown talk opens")
  eq(#menus, cooldownMenus, key .. " early cooldown talk has no answer menu")
  eq(completed, cooldownDone + 1, key .. " early cooldown talk completes")
  check(displayed[#displayed]:find("Come back", 1, true)
      and displayed[#displayed]:find("later", 1, true),
    key .. " early cooldown says to come back later")

  for _ = 1, 249 do
    eventHandlers["world.stepped"][1]({ game = game, mapId = "ROUTE_1" })
  end
  eq(hints.retryProgress(key), 249,
    key .. " exact 249 completed cells remain locked")
  cooldownMenus = #menus
  hints.talk(key, game, { player = {} }, npc)
  eq(#menus, cooldownMenus, key .. " step 249 still offers no quiz")

  local writesBeforeReady = writeCount
  eventHandlers["world.stepped"][1]({ game = game, mapId = "ROUTE_1" })
  eq(hints.retryProgress(key), 250,
    key .. " exact step 250 unlocks the retry prompt")
  eq(writeCount, writesBeforeReady + 1,
    key .. " ready boundary is flushed for save/reload safety")

  local readyDone = completed
  check(hints.talk(key, game, { player = {} }, npc,
    function() completed = completed + 1 end),
    key .. " ready retry prompt opens")
  local retryOptions = displayOptions[#displayed]
  check(retryOptions and retryOptions.defaultNo == true
      and type(retryOptions.choice) == "function",
    key .. " retry question is safe-default NO")
  check(displayed[#displayed]:find("try the", 1, true)
      and displayed[#displayed]:find("riddle again", 1, true),
    key .. " retry question explicitly offers another attempt")
  retryOptions.choice(false)
  eq(completed, readyDone + 1, key .. " retry NO exits cleanly")
  eq(hints.retryProgress(key), 250, key .. " retry NO remains ready")
  check(game.save.flags[hints.FLAG_PREFIX .. key] ~= true,
    key .. " retry NO leaves fissure sealed")

  local retryMenus = #menus
  check(hints.talk(key, game, { player = {} }, npc,
    function() completed = completed + 1 end),
    key .. " second ready retry prompt opens")
  retryOptions = displayOptions[#displayed]
  retryOptions.choice(true)
  eq(#menus, retryMenus + 1,
    key .. " retry YES repeats full riddle then opens answer menu")
  local retry = menus[#menus]
  local right
  for _, row in ipairs(retry.rows) do
    if row.value == hint.correct then right = row break end
  end
  retry.options.onChoose(right)
  check(game.save.flags[hints.FLAG_PREFIX .. key] == true,
    key .. " correct retry sets canonical discovery flag")
  check(worldFlags[hints.FLAG_PREFIX .. key] == true,
    key .. " discovery is mirrored through WorldAPI")
  eq(hints.retryProgress(key), nil,
    key .. " correct retry clears cooldown state")
  check(npc.frozen == false, key .. " researcher unfreezes after resolution")
  eq(warpCount, 0, key .. " researcher dialogue never warps")

  menuBefore = #menus
  check(hints.talk(key, game, { player = {} }, npc),
    key .. " solved researcher remains readable")
  eq(#menus, menuBefore, key .. " solved researcher does not repeat quiz")
end

-- A non-HEVO/transitional identity is authoritative invalid data, not the
-- absence marker used by genuine pre-6.5 Red saves. It must neither spawn
-- Aster nor work off an existing Red cooldown during a slot switch.
saved[hints.RUN_STATE] = {
  version = hints.STATE_VERSION, hints = {}, discovery = {},
  researcherRetry = { RED = {
    version = 1, failed = true, steps = 0, attempts = 1,
  } },
}
game.save.flags = { EVENT_BEAT_CHAMPION_RIVAL = true }
activeCharacter = "YELLOW"
check(hints.shouldSpawn("RED", game) == false,
  "invalid explicit identity cannot fall back to legacy Red")
for _ = 1, 8 do
  eventHandlers["world.stepped"][1]({ game = game, mapId = "ROUTE_1" })
end
eq(hints.retryProgress("RED"), 0,
  "invalid explicit identity cannot advance Red's cooldown")
local invalidMenus = #menus
check(hints.talk("RED", game, { player = {} },
  { frozen = false, facePlayer = function() end }),
  "invalid explicit identity receives a closed dialogue")
eq(#menus, invalidMenus,
  "invalid explicit identity receives no Red answer menu")

-- Production-shaped authority regression: legacyJourney can return nil for
-- a future raw identity while extendedCharacters' presentation API silently
-- normalizes that same record to RED.  The raw slot record must win before
-- either callback, otherwise a transitioning slot spawns Aster and advances
-- somebody else's cooldown.
local wiredSaved = {
  extended_characters = { player_character = "FUTURE" },
  [hints.RUN_STATE] = {
    version = hints.STATE_VERSION, hints = {}, discovery = {},
    researcherRetry = { RED = {
      version = 1, failed = true, steps = 0, attempts = 1,
    } },
  },
}
local wiredHandlers = {}
local wiredMod = {
  id = "kanto_ascendant",
  save = {
    get = function(_, name) return wiredSaved[name] end,
    set = function(_, name, value) wiredSaved[name] = value end,
  },
  events = { on = function(_, name, callback)
    wiredHandlers[name] = wiredHandlers[name] or {}
    wiredHandlers[name][#wiredHandlers[name] + 1] = callback
  end },
  world = {},
}
local wiredGame = {
  data = { maps = {} },
  save = {
    flags = { EVENT_BEAT_CHAMPION_RIVAL = true }, hallOfFame = {},
    modData = { kanto_ascendant = wiredSaved },
  },
  stack = { push = function() end },
}
local wiredMenus = 0
local wiredHints = assert(loadfile(
  root .. "/hidden_evolution_story_hints.lua"))()(wiredMod, {
    -- This is the exact two-stage production leak caught by the independent
    -- audit: Journey rejects FUTURE, then the visual API reports fallback RED.
    activeCharacter = function() return nil end,
    characters = { getPlayerCharacter = function() return "RED" end },
    postgame = postgame,
    showText = function(_, _, done) if done then done() end return true end,
    openMenu = function() wiredMenus = wiredMenus + 1 return true end,
  })
check(wiredHints.install(wiredGame),
  "production-shaped identity fixture installs")
check(wiredHints.shouldSpawn("RED", wiredGame) == false,
  "future raw record beats normalized RED presentation callback")
check(wiredHints.talk("RED", wiredGame, { player = {} },
  { frozen = false, facePlayer = function() end }),
  "future raw record receives only a closed dismissal")
eq(wiredMenus, 0,
  "future raw record cannot receive Aster's answer menu")
for _ = 1, 8 do
  wiredHandlers["world.stepped"][1]({ game = wiredGame, mapId = "ROUTE_1" })
end
eq(wiredHints.retryProgress("RED"), 0,
  "future raw record cannot advance Red's save-local cooldown")
wiredSaved.extended_characters = { player_character = "BLUE" }
check(wiredHints.shouldSpawn("RED", wiredGame) == false
    and wiredHints.shouldSpawn("BLUE", wiredGame) == true,
  "valid raw BLUE record also beats stale normalized RED callback")
wiredSaved.extended_characters = nil
check(wiredHints.shouldSpawn("RED", wiredGame),
  "only exact raw-record absence enables legacy RED migration")
-- During Continue/New Game, ModAPI may still momentarily expose the outgoing
-- slot. A concrete empty modData table on the incoming save is authoritative
-- absence and must not read that stale BLUE wrapper state.
wiredSaved.extended_characters = { player_character = "BLUE" }
wiredGame.save.modData = {}
check(wiredHints.shouldSpawn("RED", wiredGame)
    and wiredHints.shouldSpawn("BLUE", wiredGame) == false,
  "incoming empty slot ignores outgoing ModAPI identity state")
wiredGame.save.modData = { kanto_ascendant = wiredSaved }
wiredSaved.extended_characters = nil

-- Official pre-6.5 saves contain no extended-character bucket because Red
-- was the only playable identity. They must still receive Red's researcher
-- quiz rather than three permanent wrong-character dismissals.
activeCharacter = nil
saved[hints.RUN_STATE] = nil
game.save.flags = { EVENT_BEAT_CHAMPION_RIVAL = true }
local legacyMenus = #menus
check(hints.talk("RED", game, { player = {} },
  { frozen = false, facePlayer = function() end }),
  "legacy Red without extended-character state opens researcher dialogue")
eq(#menus, legacyMenus + 1,
  "legacy Red without extended-character state receives the Red quiz")
menus[#menus].options.onCancel()

-- German runtime wiring (not only static string inspection): the menu, wrong
-- response, early cooldown, 250-step retry question and solved response all
-- select their DE branch through the same production callbacks.
local deSaved, deShown, deOptions, deMenus = {}, {}, {}, {}
local deMod = {
  id = "kanto_ascendant",
  save = {
    get = function(_, name) return deSaved[name] end,
    set = function(_, name, value) deSaved[name] = value end,
  },
  world = {},
}
local deGame = {
  save = { flags = { EVENT_BEAT_CHAMPION_RIVAL = true } },
  writeSave = function() end,
}
deMod.world.setFlag = function(_, name, value)
  deGame.save.flags[name] = value
end
local deHints = assert(loadfile(root .. "/hidden_evolution_story_hints.lua"))()(deMod, {
  activeCharacter = function() return "RED" end,
  i18n = { text = function(_, de) return de end },
  showText = function(_, text, done, options)
    deShown[#deShown + 1] = text
    deOptions[#deShown] = options
    if done then done() end
    return true
  end,
  openMenu = function(_, title, rows, options)
    deMenus[#deMenus + 1] = { title = title, rows = rows, options = options }
    return true
  end,
})
check(deHints.talk("RED", deGame, { player = {} },
  { frozen = false, facePlayer = function() end }),
  "German Aster first dialogue opens")
check(deShown[#deShown]:find("VERTANIA", 1, true) ~= nil
    and deShown[#deShown]:find("INDIGO%-PLATEAU") ~= nil,
  "German Aster riddle exposes both logical landmarks")
eq(deMenus[#deMenus].title, "WO LIEGT DER RISS?",
  "German Aster answer menu repeats the question")
local deWrong
for _, row in ipairs(deMenus[#deMenus].rows) do
  if row.value ~= deHints.HINTS.RED.correct then deWrong = row break end
end
deMenus[#deMenus].options.onChoose(deWrong)
check(deShown[#deShown]:find("Komm wieder, wenn", 1, true) ~= nil,
  "German wrong answer gives the requested return instruction")
deHints.talk("RED", deGame, { player = {} },
  { frozen = false, facePlayer = function() end })
check(deShown[#deShown]:find("später wieder", 1, true) ~= nil,
  "German early cooldown says Komm später wieder")
deSaved[deHints.RUN_STATE].researcherRetry.RED.steps = 250
deHints.talk("RED", deGame, { player = {} },
  { frozen = false, facePlayer = function() end })
check(deShown[#deShown]:find("Willst du", 1, true) ~= nil
    and deShown[#deShown]:find("versuchen", 1, true) ~= nil,
  "German ready dialogue asks whether to try again")
check(deOptions[#deShown] and deOptions[#deShown].defaultNo == true,
  "German retry prompt defaults to NO")

print(("hidden_evolution_professor_discovery_gate_test: PASS (%d assertions)")
  :format(checks))
