-- Real Authority-main/LÖVE evidence for the first Hall-of-Fame -> Oak's Lab
-- Legacy orientation.  It reaches begin() only after the authored HEVO
-- door/Oak unlock, then cancels at the second default-NO confirmation so
-- every capture proves the guarded PC flow is non-destructive.

return function(game)
  local U = dofile(os.getenv("KA_TEST_UTIL") or "tests/drivers/util.lua")
  local TextBox = require("src.render.TextBox")
  local ChoiceBox = require("src.ui.ChoiceBox")
  local SaveData = require("src.core.SaveData")
  local Serializer = require("src.core.SaveSerializer")
  local GameVersion = require("src.core.GameVersion")
  local Sound = require("src.core.Sound")
  local Runtime = require("src.mods.Runtime")
  local Pipelines = require("src.render.Pipelines")
  local dir = assert(os.getenv("SHOT_DIR"), "SHOT_DIR is required")
  local api = assert(game.mods.exports.kanto_ascendant)
  local journey = assert(api.legacyJourney)
  local locale = assert(os.getenv("QA_LANGUAGE"), "QA_LANGUAGE is required")
  local renderer = os.getenv("QA_RENDERER") or "2d"
  assert(renderer == "2d" or renderer == "voxel",
    "QA_RENDERER must be 2d or voxel")
  local pass, fail = 0, 0

  local function check(label, value)
    if value then pass = pass + 1 else fail = fail + 1 end
    U.log(value and "PASS" or "FAIL", label)
    return value
  end
  local function waitFor(predicate, frames)
    for _ = 1, frames or 900 do
      local value = predicate()
      if value then return value end
      U.wait(1)
    end
    return nil
  end
  local function isText(value)
    return value and getmetatable(value) == TextBox
  end
  local function clearToOverworld()
    return waitFor(function()
      local top = game.stack:top()
      if top == game.overworld then return true end
      if top and (top.waiting or top.done) then U.tap(game, "a")
      else U.wait(1) end
      return nil
    end, 1200) == true
  end
  local function menu()
    local top = game.stack:top()
    return top and type(top.items) == "table" and top or nil
  end
  local function findItem(items, needle)
    for index, row in ipairs(items or {}) do
      if tostring(row.label):find(needle, 1, true) then return index, row end
    end
  end
  local function selectMenu(index)
    local current = assert(menu(), "expected real PC menu")
    while current.index ~= index do U.tap(game, "down") end
    U.tap(game, "a")
  end
  local function showStableText()
    return waitFor(function()
      local top = game.stack:top()
      return isText(top) and (top.done or top.waiting) and top or nil
    end, 1200)
  end
  local function textPageContains(box, needle)
    return box and table.concat(box.pages[box.pageIndex] or {}, "\n")
      :find(needle, 1, true) ~= nil
  end
  local function captureTextPage(needle, path)
    for _ = 1, 100 do
      local box = assert(showStableText(), "expected visible text page")
      if textPageContains(box, needle) then return U.shot(game, path) end
      U.tap(game, "a")
    end
    return false
  end
  local function allText(box)
    local rows = {}
    for _, page in ipairs(box and box.pages or {}) do
      rows[#rows + 1] = table.concat(page, "\n")
    end
    return table.concat(rows, "\f")
  end
  local function advanceToChoice(box)
    return waitFor(function()
      local top = game.stack:top()
      if top and getmetatable(top) == ChoiceBox then return top end
      if top == box and (top.waiting or top.done) then U.tap(game, "a")
      else U.wait(1) end
      return nil
    end, 2400)
  end
  local function clearMenuAndText()
    while game.stack:top() and game.stack:top() ~= game.overworld do
      U.tap(game, "b")
      U.wait(1)
    end
  end
  local function currentLanguage()
    return api.language and api.language() or "en"
  end
  local function noLegacyRun()
    local bucket = game.save.modData and game.save.modData.kanto_ascendant
    return not (bucket and bucket.legacy_journey)
  end
  local function semanticSaveBytes(save)
    -- Game:step advances playTime on every TextBox/ChoiceBox frame.  Compare
    -- the complete serialized save except for that expected clock, rather
    -- than claiming two snapshots taken seconds apart can be byte-identical.
    local copy = assert(Serializer.decode(Serializer.encode(save)))
    copy.playTime = nil
    return Serializer.encode(copy)
  end
  local function directlyOverOverworld(state)
    local states = game.stack and game.stack.states or {}
    return states[#states] == state and states[#states - 1] == game.overworld
  end

  -- Every visual run owns a reserved slot inside its disposable QA identity.
  -- Starting from SaveData.newGame is important here: a Blue or Yellow cache
  -- must never inherit Red's prior Hall/Legacy fields merely because an old
  -- slot happened to be active in that identity.
  local edition = GameVersion.get()
  local slot = os.getenv("QA_SLOT")
    or ("slot65storygate_" .. edition .. "_" .. locale)
  assert(SaveData.setActiveSlot(edition, slot) == slot,
    "could not reserve isolated story-gate slot")
  local fresh = SaveData.newGame(game:bootConfig())
  game.save = fresh
  game:adoptSave(fresh)
  Runtime.emit("save.created", { save = fresh })

  U.wait(35)
  local pipelineLevel = Pipelines.setLevel("voxel", renderer == "voxel" and 1 or 0)
  Pipelines.syncOptions(game.save.options)
  check("requested renderer is active",
    renderer == "voxel" and pipelineLevel > 0 or pipelineLevel == 0)
  check("requested translation is active", currentLanguage() == locale)
  game.save.party = game.save.party or {}
  game.save.flags = game.save.flags or {}
  game.save.options = game.save.options or {}
  game.save.options.textSpeed = 1
  game.save.player.name = locale == "de" and "ROT" or "RED"
  game.save.hallOfFame = nil
  game.save.flags.EVENT_BEAT_CHAMPION_RIVAL = nil
  game.save.modData = game.save.modData or {}
  game.save.modData.kanto_ascendant = nil
  game:adoptSave(game.save)

  -- The composed first-clear Champion dialogue is the one real map payload
  -- that Oak uses immediately before Hall of Fame.  Teleporting in lets the
  -- existing postgame map hook select it; rendering that exact installed
  -- string avoids forging an NPC or a Champion win.
  U.teleport(game, "CHAMPIONS_ROOM", 5, 3, "up")
  U.wait(35)
  local hallText = tostring(game.data.text._ChampionsRoomOakComeWithMeText or "")
  check("before Hall of Fame Oak payload is installed", hallText:find("LEGACY", 1, true)
    or hallText:find("VERMÄCHTNIS", 1, true))
  check("before Hall of Fame has no Legacy availability", not journey.archive.isEligible(game.save)
    and noLegacyRun())
  game.stack:push(TextBox.new(game,
    hallText:gsub("{PLAYER}", game.save.player.name), function() end))
  check("first-Hall Oak bridge capture",
    captureTextPage(locale == "de" and "VERMÄCHTNIS" or "LEGACY",
      dir .. "/01_before_first_hall_oak_bridge.png"))
  clearToOverworld()

  U.teleport(game, "OAKS_LAB", 5, 5, "up")
  U.wait(25)
  game.overworld:openPC(function() end)
  local preMenu = waitFor(menu)
  local infoNeedle = locale == "de" and "LEGACY-INFO" or "LEGACY INFO"
  local infoIndex = preMenu and findItem(preMenu.items, infoNeedle)
  local beginIndex = preMenu and findItem(preMenu.items,
    locale == "de" and "REISE STARTEN" or "BEGIN LEGACY")
  check("real Lab PC exposes info before Hall", infoIndex ~= nil)
  check("real Lab PC does not expose Legacy start before Hall", beginIndex == nil)
  check("pre-Hall Lab PC menu capture",
    preMenu and U.shot(game, dir .. "/02_pre_hall_lab_pc_menu.png"))
  selectMenu(infoIndex)
  local preHint = showStableText()
  check("pre-Hall PC hint is visible and non-destructive", preHint ~= nil
    and not journey.archive.isEligible(game.save) and noLegacyRun())
  check("pre-Hall PC hint capture",
    preHint and captureTextPage(locale == "de" and "Betritt" or "Enter the",
      dir .. "/03_pre_hall_pc_hint.png"))
  clearMenuAndText()

  -- Hall is necessary, but deliberately insufficient.  This first pass is
  -- the migration/safety regression: a post-Hall save gets information only
  -- and can neither expose nor auto-start the next cycle.
  game.save.hallOfFame = { { name = game.save.player.name } }
  game.save.flags.EVENT_BEAT_CHAMPION_RIVAL = true
  game:adoptSave(game.save)
  check("first Hall record enables Legacy eligibility only", journey.archive.isEligible(game.save)
    and noLegacyRun())
  U.teleport(game, "OAKS_LAB", 5, 5, "up")
  U.wait(25)
  game.overworld:openPC(function() end)
  local postMenu = waitFor(menu)
  infoIndex = postMenu and findItem(postMenu.items, infoNeedle)
  beginIndex = postMenu and findItem(postMenu.items,
    locale == "de" and "REISE STARTEN" or "BEGIN LEGACY")
  check("post-Hall-only Lab PC has info but no Legacy start",
    infoIndex ~= nil and beginIndex == nil)
  check("post-Hall PC menu capture",
    postMenu and U.shot(game, dir .. "/04_post_hall_lab_pc_menu.png"))
  selectMenu(infoIndex)
  local postHint = showStableText()
  check("post-Hall PC requires the matching fissure path", postHint ~= nil
    and noLegacyRun() and game.save.hallOfFame and #game.save.hallOfFame == 1)
  check("post-Hall PC repeat hint capture",
    postHint and captureTextPage(locale == "de" and "Vollende" or "Complete",
      dir .. "/05_post_hall_pc_hint.png"))
  clearMenuAndText()

  check("save post-Hall-only safety state", game:writeSave())
  local loaded = assert(SaveData.load(), "story-gate save did not reload")
  game:restoreSave(loaded, false)
  U.wait(30)
  U.teleport(game, "OAKS_LAB", 5, 5, "up")
  U.wait(20)
  game.overworld:openPC(function() end)
  local reloadMenu = waitFor(menu)
  local reloadInfo = reloadMenu and findItem(reloadMenu.items, infoNeedle)
  local reloadBegin = reloadMenu and findItem(reloadMenu.items,
    locale == "de" and "REISE STARTEN" or "BEGIN LEGACY")
  check("reload preserves the post-Hall-only lock",
    reloadInfo ~= nil and reloadBegin == nil and journey.archive.isEligible(game.save)
      and noLegacyRun())
  check("post-Hall-only reload capture",
    reloadMenu and U.shot(game, dir .. "/06_post_reload_pc_menu.png"))
  clearMenuAndText()

  -- Bounded authoritative end harness: use the real durable adapter boundary
  -- (never a direct item/flag grant), then walk to and press the real shared
  -- black door.  Puzzle traversal is outside this driver's stated proof; the
  -- focused RED/BLUE/GREEN suites own it.  This sequence proves that finalize
  -- alone is still too early and that the physical door owns cry -> not-yet
  -- text -> Oak call -> readiness.
  api.extendedCharacters.select("RED")
  local finalized, finalizeResult = api.legacyDungeonAdapter.finalize(game, {
    character = "RED", questionIds = { "QA_LEGACY_STORY_GATE" },
  })
  check("real RED completion boundary seals without Mega auto-grant",
    finalized == true and finalizeResult.character == "RED"
      and not api.legacyDungeonAdapter.hasSecret(game.save, "RED"))
  check("finalize alone still cannot expose the next cycle",
    not journey.canBegin(game.save)
      and game.save.flags[journey.HEVO_READY_FLAG] ~= true)

  U.teleport(game, "KA_HEVO_SHARED_SEALED_ANTECHAMBER", 15, 6, "up")
  U.wait(25)
  local cryReceipt = {}
  local originalPlayCry = Sound.playCry
  Sound.playCry = function(data, species, ...)
    if data == game.data then cryReceipt[#cryReceipt + 1] = species end
    return originalPlayCry(data, species, ...)
  end
  U.tap(game, "a")
  Sound.playCry = originalPlayCry
  check("physical RED door emits exactly its registered GROUDON cry",
    #cryReceipt == 1 and cryReceipt[1] == "GROUDON")
  local notYet = waitFor(function()
    local top = game.stack:top()
    local needle = locale == "de" and "Zeit ist noch nicht reif"
      or "time is not yet right"
    local rendered = type(top and top.lines) == "table"
      and table.concat(top.lines, "\n") or ""
    rendered = rendered:gsub("%s+", " ")
    return top and top.isOpaque == true
      and tostring(top.text or ""):find(needle, 1, true)
      and rendered:find(needle, 1, true) and top or nil
  end, 1200)
  if notYet then U.wait(2) end
  check("matching legendary cry reaches explicit visible not-yet beat",
    notYet ~= nil)
  check("shared black-door not-yet capture",
    notYet and U.shot(game, dir .. "/07_black_door_not_yet.png"))
  if notYet then U.tap(game, "a") end
  local oakCall = showStableText()
  check("real Oak call follows the black-door beat", oakCall ~= nil
    and allText(oakCall):find(locale == "de" and "PROF. EICH"
      or "PROF. OAK", 1, true) ~= nil
    and allText(oakCall):find(locale == "de" and "LABOR-PC"
      or "LAB PC", 1, true) ~= nil)
  check("Oak call capture",
    oakCall and U.shot(game, dir .. "/08_oak_legacy_call.png"))
  check("complete call and epilogue", clearToOverworld())
  local gateBucket = game.save.modData.kanto_ascendant
  local gateState = gateBucket[journey.HEVO_GATE_KEY]
  check("door visit and completed Oak call arm readiness exactly once",
    gateBucket.hidden_evolution_story_campaign.doorVisits.RED == true
      and gateState and gateState.character == "RED"
      and gateState.ready == true and gateState.oakCalled == true
      and game.save.flags[journey.HEVO_READY_FLAG] == true
      and game.save.flags[journey.HEVO_OAK_CALLED_FLAG] == true
      and journey.canBegin(game.save))

  U.teleport(game, "OAKS_LAB", 5, 5, "up")
  U.wait(25)
  game.overworld:openPC(function() end)
  local armedMenu = waitFor(menu)
  local armedInfo = armedMenu and findItem(armedMenu.items, infoNeedle)
  local armedBegin = armedMenu and findItem(armedMenu.items,
    locale == "de" and "REISE STARTEN" or "BEGIN LEGACY")
  check("black-door/Oak sequence exposes BEGIN beside INFO",
    armedInfo ~= nil and armedBegin ~= nil and armedInfo < armedBegin)
  check("newly armed Lab PC capture",
    armedMenu and U.shot(game, dir .. "/09_armed_lab_pc_menu.png"))
  clearMenuAndText()

  check("save armed gate", game:writeSave())
  loaded = assert(SaveData.load(), "armed story-gate save did not reload")
  game:restoreSave(loaded, false)
  U.wait(30)
  U.teleport(game, "OAKS_LAB", 5, 5, "up")
  U.wait(20)
  game.overworld:openPC(function() end)
  local armedReloadMenu = waitFor(menu)
  local armedReloadBegin = armedReloadMenu and findItem(armedReloadMenu.items,
    locale == "de" and "REISE STARTEN" or "BEGIN LEGACY")
  check("matching readiness survives Save/Reload without another Oak call",
    armedReloadBegin ~= nil and journey.canBegin(game.save) and noLegacyRun())
  check("armed post-reload Lab PC capture",
    armedReloadMenu and U.shot(game, dir .. "/10_armed_reload_pc_menu.png"))

  -- Inspect both real TextBox confirmations.  Each must create a ChoiceBox
  -- whose cursor starts on NO.  Choose YES only on page one, then accept the
  -- default NO on page two.  The play clock advances while reading; every
  -- other save byte, the durable archive and the no-write contract must hold.
  local beforeConfirm = semanticSaveBytes(game.save)
  local beforePlayTime = tonumber(game.save.playTime) or 0
  local beforeProfile = Serializer.encode(journey.profile())
  local originalWriteSave = game.writeSave
  local confirmationWrites = 0
  game.writeSave = function(self, ...)
    confirmationWrites = confirmationWrites + 1
    return originalWriteSave(self, ...)
  end
  selectMenu(armedReloadBegin)
  local firstConfirm = showStableText()
  check("BEGIN closes the PC menu before the first confirmation",
    firstConfirm ~= nil and directlyOverOverworld(firstConfirm))
  check("first archive/reset summary is explicit", firstConfirm ~= nil
    and firstConfirm.defaultNo == true
    and allText(firstConfirm):find(locale == "de" and "ARCHIV BEHÄLT"
      or "ARCHIVE KEEPS", 1, true) ~= nil
    and allText(firstConfirm):find(locale == "de" and "TEAM UND BEUTEL"
      or "PARTY AND BAG", 1, true) ~= nil)
  check("first reset-consequence capture",
    firstConfirm and captureTextPage(
      locale == "de" and "NEUER ZYKLUS SETZT" or "RESET FOR NEW CYCLE",
      dir .. "/11_first_confirmation.png"))
  local firstChoice = firstConfirm and advanceToChoice(firstConfirm)
  check("first confirmation defaults to NO",
    firstChoice ~= nil and firstChoice.index == 2)
  check("first real default-NO ChoiceBox capture",
    firstChoice and firstChoice.index == 2
      and U.shot(game, dir .. "/12_first_confirmation_default_no.png"))
  if firstChoice then U.tap(game, "up"); U.tap(game, "a") end

  local finalConfirm = showStableText()
  local finalText = allText(finalConfirm)
  check("final confirmation also sits directly over the Lab",
    finalConfirm ~= nil and directlyOverOverworld(finalConfirm))
  check("final contract summary names every required consequence",
    finalConfirm ~= nil and finalConfirm.defaultNo == true
      and finalText:find("129", 1, true) ~= nil
      and finalText:find("RED", 1, true) ~= nil
      and finalText:find(locale == "de" and "FLEMMLI" or "TORCHIC", 1, true) ~= nil
      and finalText:find(locale == "de" and "linken" or "left LAB ball", 1, true) ~= nil
      and finalText:find(locale == "de" and "Lauf endet" or "run ends", 1, true) ~= nil)
  check("final run-end consequence capture",
    finalConfirm and captureTextPage(
      locale == "de" and "Dieser Lauf endet" or "This run ends",
      dir .. "/13_final_confirmation.png"))
  local finalChoice = finalConfirm and advanceToChoice(finalConfirm)
  check("final confirmation defaults to NO",
    finalChoice ~= nil and finalChoice.index == 2)
  check("final real default-NO ChoiceBox capture",
    finalChoice and finalChoice.index == 2
      and U.shot(game, dir .. "/14_final_confirmation_default_no.png"))
  if finalChoice then U.tap(game, "a") end
  local returnedToLab = waitFor(function()
    return game.stack:top() == game.overworld and true or nil
  end, 600)
  game.writeSave = originalWriteSave
  local afterPlayTime = tonumber(game.save.playTime) or 0
  check("default-NO cancellation changes only the expected play clock",
    returnedToLab == true and afterPlayTime >= beforePlayTime
      and semanticSaveBytes(game.save) == beforeConfirm)
  check("default-NO cancellation writes, archives and starts nothing",
    confirmationWrites == 0
      and Serializer.encode(journey.profile()) == beforeProfile
      and noLegacyRun() and journey.canBegin(game.save))
  clearMenuAndText()
  U.log(("LEGACY STORY GATE RESULT locale=%s pass=%d fail=%d")
    :format(locale, pass, fail))
  local result = assert(io.open(dir .. "/driver_result.txt", "wb"))
  result:write((fail == 0 and "PASS" or "FAIL"), "\n")
  result:write(("locale=%s\nrenderer=%s\npass=%d\nfail=%d\n")
    :format(locale, renderer, pass, fail))
  result:close()
  love.event.quit(fail == 0 and 0 or 1)
end
