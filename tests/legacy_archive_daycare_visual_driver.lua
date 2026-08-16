-- Real Authority-main/LÖVE acceptance for the destructive Legacy boundary.
-- Exercises both vanilla Day-Care and Day-Care Plus holdings through the
-- actual Oak's Lab PC action, closes/retries with B, then clears the holdings
-- and completes the two-confirmation fresh-game hand-off.

return function(game)
  assert(os.getenv("KA_PACKAGE_GATE") == "1",
    "KA_PACKAGE_GATE=1 is required; source-tree runs are not package proof")
  assert(os.getenv("KA_CLOSURE_PROFILE") == "base_deutsch",
    "Legacy Day-Care acceptance requires base/deutsch")
  local function requiredSha(name)
    local value = os.getenv(name)
    assert(type(value) == "string" and #value == 64
        and value:match("^[0-9a-f]+$"),
      name .. " must be a lowercase SHA256 receipt")
    return value
  end
  local receipts = {
    engine_payload_sha256 = requiredSha("KA_ENGINE_PAYLOAD_SHA256"),
    authority_package_sha256 = requiredSha("KA_AUTHORITY_PACKAGE_SHA256"),
    deutsch_package_sha256 = requiredSha("KA_DEUTSCH_PACKAGE_SHA256"),
    package_gate_receipt_sha256 = requiredSha(
      "KA_PACKAGE_GATE_RECEIPT_SHA256"),
  }
  local dir = assert(os.getenv("SHOT_DIR"), "SHOT_DIR is required")
  local utilPath = assert(os.getenv("KA_TEST_UTIL"),
    "KA_TEST_UTIL packaged harness path is required")
  for _, path in ipairs({ dir, utilPath }) do
    assert(path:sub(1, 1) == "/"
        and not path:find(".worktrees", 1, true)
        and not path:find("/Documents/Recompile/", 1, true),
      "source/worktree path is not package evidence: " .. path)
  end
  local U = dofile(utilPath)
  local SaveData = require("src.core.SaveData")
  local GameVersion = require("src.core.GameVersion")
  local TextBox = require("src.render.TextBox")
  local ChoiceBox = require("src.ui.ChoiceBox")
  local locale = assert(os.getenv("QA_LANGUAGE"), "QA_LANGUAGE is required")
  local edition = GameVersion.get()
  assert(edition == "red" and os.getenv("POKEPORT_VERSION") == "red",
    "Legacy Day-Care package cell is frozen to Red")
  assert(locale == "en" or locale == "de",
    "QA_LANGUAGE must be exactly en or de")
  assert(os.getenv("POKEPORT_IDENTITY") ==
      "ka65-final-legacy-daycare-" .. locale,
    "Legacy Day-Care cell requires its exact isolated identity")
  local slot = "slot65legacydaycare_" .. locale
  assert(SaveData.setActiveSlot(edition, slot) == slot,
    "could not reserve the Legacy Day-Care native save slot")
  local loadedMods = assert(game.mods and game.mods.mods,
    "installed package registry is unavailable")
  local installed = assert(loadedMods.kanto_ascendant,
    "installed Authority package is missing")
  for _, path in ipairs({ tostring(love.filesystem.getSource() or ""),
      tostring(installed.path or "") }) do
    assert(path ~= "" and not path:find(".worktrees", 1, true)
        and not path:find("/Documents/Recompile/", 1, true)
        and not path:find("/tests/", 1, true)
        and not path:find("/tools/", 1, true),
      "source/worktree path is not installed-package evidence: " .. path)
  end
  local api = assert(game.mods.exports.kanto_ascendant)
  local journey = assert(api.legacyJourney)
  local pass, fail = 0, 0

  local function check(label, value)
    if value then pass = pass + 1 else fail = fail + 1 end
    U.log(value and "PASS" or "FAIL", label)
    return value
  end
  local function waitFor(predicate, frames)
    for _ = 1, frames or 1200 do
      local value = predicate()
      if value then return value end
      U.wait(1)
    end
    return nil
  end
  local function menu()
    local top = game.stack:top()
    return top and type(top.items) == "table" and top or nil
  end
  local function stableText()
    return waitFor(function()
      local top = game.stack:top()
      return top and getmetatable(top) == TextBox
        and (top.done or top.waiting) and top or nil
    end)
  end
  local function pageText(box)
    return table.concat(box and box.pages[box.pageIndex] or {}, "\n")
  end
  local function evidenceShot(path)
    local ok = U.shot(game, path)
    -- On the macOS scripted renderer, captureScreenshot observes alternating
    -- back buffers while a PC/TextBox stack is active. Consume the other
    -- buffer explicitly so every durable evidence path receives a drawn frame.
    U.wait(2)
    U.shot(game, dir .. "/_discard_backbuffer.png")
    return ok
  end
  local function findMenuItem(needle)
    local current = assert(waitFor(menu), "expected real PC menu")
    for index, row in ipairs(current.items) do
      if tostring(row.label):find(needle, 1, true) then return current, index end
    end
    error("missing PC item " .. needle)
  end
  local function chooseMenu(index)
    local current = assert(menu(), "expected PC menu")
    while current.index ~= index do U.tap(game, "down") end
    U.tap(game, "a")
  end
  local function openBegin()
    game.overworld:openPC(function() end)
    local _, index = findMenuItem(locale == "de" and "REISE STARTEN"
      or "BEGIN LEGACY")
    chooseMenu(index)
  end
  local function closeToOverworldWithB()
    return waitFor(function()
      if game.stack:top() == game.overworld then return true end
      U.tap(game, "b")
      return nil
    end, 400) == true
  end
  local function waitChoice()
    return waitFor(function()
      local top = game.stack:top()
      if top and getmetatable(top) == ChoiceBox then return top end
      if top and getmetatable(top) == TextBox then
        if top.waiting or top.done then U.tap(game, "a") end
      else
        U.wait(1)
      end
      return nil
    end)
  end
  local function chooseYes()
    local choice = assert(waitChoice(), "expected default-NO choice")
    if choice.index == 2 then U.tap(game, "up") end
    U.tap(game, "a")
  end
  local function activeRun()
    local bucket = game.save.modData and game.save.modData.kanto_ascendant
    return bucket and bucket.legacy_journey
  end
  local function emptyArchive()
    local profile = journey.archive.profile()
    local locker = journey.archive.locker()
    return profile.cycle == 0 and profile.current.runId == nil
      and #journey.archive.availableMons(game.save) == 0
      and next(locker.items) == nil and locker.money == 0
  end

  U.wait(40)
  check("requested translation is active",
    not api.language or api.language() == locale)
  game.save.player.name = locale == "de" and "ROT" or "RED"
  game.save.player.id = locale == "de" and 6502 or 6501
  game.save.options = game.save.options or {}
  game.save.options.textSpeed = 1
  game.save.flags = { EVENT_BEAT_CHAMPION_RIVAL = true }
  game.save.hallOfFame = { { name = game.save.player.name } }
  game.save.party = {
    { species = "PIKACHU", nickname = "SPARK", level = 50,
      moves = { { id = "TACKLE", pp = 35 } } },
  }
  game.save.boxes = game.save.boxes or { {} }
  game.save.inventory = { POTION = 2, BICYCLE = 1, HM_SURF = 1 }
  game.save.pcItems = {}
  game.save.money = 7654
  game.save.modData = game.save.modData or {}
  game.save.modData.kanto_ascendant = {}
  game.save.daycare = {
    mon = { species = "EEVEE", level = 30,
      moves = { { id = "TACKLE", pp = 35 } } },
    depositLevel = 30, steps = 128,
  }
  game:adoptSave(game.save)
  U.teleport(game, "OAKS_LAB", 5, 5, "up")
  U.wait(30)
  check("fresh QA identity starts with an empty Legacy archive", emptyArchive())

  -- Day-Care remains this driver's subject. Arm the newly required Journey
  -- gate through the real completion/door controller seams, without a full
  -- unrelated dungeon replay and without claiming the optional Mega secret.
  api.extendedCharacters.select("RED")
  local sealed, sealResult = api.legacyDungeonAdapter.finalize(game, {
    character = "RED", questionIds = { "QA_DAYCARE_GATE" },
  })
  check("bounded HEVO authority completion leaves Mega optional",
    sealed == true and sealResult.character == "RED"
      and not api.legacyDungeonAdapter.hasSecret(game.save, "RED"))
  check("adapter finalize alone does not unlock the PC",
    not journey.canBegin(game.save))
  check("matching shared black-door seam arms the gate",
    api.hiddenEvolutionCampaign.modules.shared.doorInteraction(game) == true)
  check("Oak unlock call closes cleanly", closeToOverworldWithB())
  check("Day-Care fixture now owns full HOF/seal/door readiness",
    journey.canBegin(game.save)
      and game.save.flags[journey.HEVO_OAK_CALLED_FLAG] == true)

  openBegin()
  local vanilla = assert(stableText(), "expected vanilla Day-Care block")
  local vanillaText = pageText(vanilla)
  check("vanilla Day-Care block is localized and explicit",
    vanillaText:find(locale == "de" and "PENSION" or "DAY%-CARE") ~= nil)
  U.wait(3)
  check("vanilla Day-Care block capture",
    evidenceShot(dir .. "/01_vanilla_daycare_block.png"))
  check("B leaves the blocked PC flow", closeToOverworldWithB())
  check("vanilla block is side-effect free",
    emptyArchive() and game.save.daycare and game.save.daycare.mon
      and #game.save.party == 1)

  -- Simulate collecting the vanilla resident, then exercise both live
  -- Day-Care Plus containers. They remain in the same actual save bucket the
  -- production controller uses.
  game.save.daycare = nil
  game.save.modData.kanto_ascendant.daycare_plus = {
    version = 3,
    parents = {
      { mon = { species = "BULBASAUR", level = 31,
        moves = { { id = "TACKLE", pp = 35 } } }, depositLevel = 31 },
    },
    reservedEggs = { { species = "PIKACHU", steps = 64,
      origin = "LEGACY QA" } },
  }
  openBegin()
  local plus = assert(stableText(), "expected Day-Care Plus block")
  local plusText = pageText(plus)
  check("Day-Care Plus parent/reservation uses the same clear localized gate",
    plusText:find(locale == "de" and "EIER" or "EGGS", 1, true) ~= nil)
  check("B leaves Day-Care Plus block", closeToOverworldWithB())
  check("Day-Care Plus block preserves parent and reserved Egg",
    emptyArchive()
      and #game.save.modData.kanto_ascendant.daycare_plus.parents == 1
      and #game.save.modData.kanto_ascendant.daycare_plus.reservedEggs == 1)

  -- Retry without changing state: the same gate must remain deterministic
  -- and must not have staged a hidden transaction on the first attempt.
  openBegin()
  local retry = assert(stableText(), "expected retry block")
  check("blocked retry repeats without archive mutation",
    pageText(retry) == plusText and emptyArchive())
  U.wait(3)
  check("Day-Care Plus side-effect-free retry capture",
    evidenceShot(dir .. "/02_daycare_plus_retry_block.png"))
  check("B leaves retry cleanly", closeToOverworldWithB())

  -- Establish the post-collection save state directly. Collection itself is
  -- owned by the separate Day-Care controllers and is intentionally outside
  -- this focused driver. From this clear-state fixture onward, the next PC
  -- attempt must reach both real confirmations and the actual New Game hook
  -- rather than a direct archive call.
  game.save.modData.kanto_ascendant.daycare_plus.parents = {}
  game.save.modData.kanto_ascendant.daycare_plus.reservedEggs = {}
  openBegin()
  local summary = assert(stableText(), "expected Legacy summary confirmation")
  check("cleared Day-Care reaches real first confirmation",
    pageText(summary):find(locale == "de" and "VERMÄCHTNIS" or "LEGACY") ~= nil)
  U.wait(3)
  check("successful retry summary capture",
    evidenceShot(dir .. "/03_cleared_summary_confirmation.png"))
  chooseYes()
  local finalConfirm = assert(stableText(), "expected final Legacy confirmation")
  check("second confirmation is visible before reset",
    pageText(finalConfirm):find(locale == "de" and "LETZTE PRÜFUNG"
      or "FINAL REVIEW", 1, true) ~= nil)
  U.wait(3)
  check("final confirmation capture",
    evidenceShot(dir .. "/04_final_confirmation.png"))
  chooseYes()

  local fresh = waitFor(function()
    local run = activeRun()
    return run and run.cycle == 1 and run or nil
  end, 1800)
  check("actual New Game hook seeds cycle one", fresh ~= nil)
  local profile = journey.archive.profile()
  local available = journey.archive.availableMons(game.save)
  local locker = journey.archive.locker()
  check("successful hand-off archives exact ordinary payload",
    profile.cycle == 1 and #available == 1
      and available[1].mon.species == "PIKACHU"
      and locker.items.POTION == 2 and locker.money == 7654)
  check("successful hand-off excludes story items and Day-Care containers",
    locker.items.BICYCLE == nil and locker.items.HM_SURF == nil
      and game.save.daycare == nil
      and next(game.save.modData.kanto_ascendant.daycare_plus or {}) == nil)
  U.wait(90)
  check("fresh Oak flow capture",
    evidenceShot(dir .. "/05_fresh_legacy_oak_flow.png"))

  check("Fresh Day-Care hand-off writes through the native save", game:writeSave())
  local reloaded, recovered = SaveData.load()
  check("Fresh Day-Care hand-off reloads without recovery",
    reloaded ~= nil and recovered == nil)
  if reloaded then
    game:restoreSave(reloaded, recovered)
    U.wait(45)
  end
  local durableRun = activeRun()
  local durableProfile = journey.archive.profile()
  local durableLocker = journey.archive.locker()
  check("Day-Care clear-state hand-off is durable and exact after reload",
    durableRun and durableRun.cycle == 1
      and durableProfile.cycle == 1
      and durableLocker.items.POTION == 2
      and durableLocker.money == 7654)

  U.log(("LEGACY ARCHIVE DAYCARE VISUAL RESULT locale=%s pass=%d fail=%d")
    :format(locale, pass, fail))
  local result = assert(io.open(dir .. "/driver_result.txt", "wb"))
  result:write("status=", fail == 0 and "PASS" or "FAIL", "\n")
  result:write("scope=LEGACY-ARCHIVE-DAYCARE\n")
  result:write("edition=red\nlocale=", locale, "\n")
  result:write("vanilla_daycare_block=1/1\n")
  result:write("daycare_plus_block=1/1\n")
  result:write("blocked_retry_side_effect_free=1/1\n")
  result:write("fresh_handoff=1/1\n")
  result:write("native_save_reload=1/1\n")
  result:write("engine_payload_sha256=", receipts.engine_payload_sha256, "\n")
  result:write("authority_package_sha256=",
    receipts.authority_package_sha256, "\n")
  result:write("deutsch_package_sha256=", receipts.deutsch_package_sha256,
    "\n")
  result:write("package_gate_receipt_sha256=",
    receipts.package_gate_receipt_sha256, "\n")
  result:write("fail=", tostring(fail), "\n")
  result:close()
  love.event.quit(fail == 0 and 0 or 1)
end
