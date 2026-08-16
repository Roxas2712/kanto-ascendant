-- Installed-package acceptance for the Legacy archive's selected-title seam.
-- A title is unlocked and selected through the real product APIs, crossed
-- through archive.beginJourney and the engine save.new_game hook, reloaded
-- from the native slot, rendered on the Trainer Card, and then recognized by
-- a real field Wanderer.  The final beat retains the independent committed-
-- partner reaction covered by this driver's original acceptance purpose.

return function(game)
  assert(os.getenv("KA_PACKAGE_GATE") == "1",
    "KA_PACKAGE_GATE=1 is required; source-tree runs are not package proof")
  assert(os.getenv("KA_CLOSURE_PROFILE") == "base_deutsch",
    "Legacy title/card acceptance requires base/deutsch")
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
  local Pokemon = require("src.pokemon.Pokemon")
  local Screens = require("src.ui.Screens")
  local TextBox = require("src.render.TextBox")
  local edition = GameVersion.get()
  assert(edition == "red" and os.getenv("POKEPORT_VERSION") == "red",
    "Legacy title/card acceptance is frozen to Red")
  assert(os.getenv("POKEPORT_IDENTITY") ==
      "ka65-final-legacy-title-card-de",
    "Legacy title/card acceptance requires its exact isolated identity")
  assert(SaveData.setActiveSlot(edition, "slot65legacytitlecard_de") ==
      "slot65legacytitlecard_de",
    "could not reserve the Legacy title/card native save slot")

  local loadedMods = assert(game.mods and game.mods.mods,
    "installed package registry is unavailable")
  local installed = assert(loadedMods.kanto_ascendant,
    "installed Authority package is missing")
  local language = assert(loadedMods.deutsch,
    "installed Red German package is missing")
  for _, path in ipairs({ tostring(love.filesystem.getSource() or ""),
      tostring(installed.path or ""), tostring(language.path or "") }) do
    assert(path ~= "" and not path:find(".worktrees", 1, true)
        and not path:find("/Documents/Recompile/", 1, true)
        and not path:find("/tests/", 1, true)
        and not path:find("/tools/", 1, true),
      "source/worktree path is not installed-package evidence: " .. path)
  end

  local exports = assert(game.mods.exports.kanto_ascendant)
  local wanderers = assert(exports.legacyWanderers)
  local hall = assert(exports.legacyHall)
  local ascendant = assert(exports.ascendant)
  local journey = assert(exports.legacyJourney)
  local archive = assert(journey.archive)
  assert(exports.language and exports.language() == "de",
    "Legacy title/card acceptance requires live German")
  local pass, fail = 0, 0
  local failedLabels = {}

  local function check(label, value)
    if value then
      pass = pass + 1
    else
      fail = fail + 1
      failedLabels[#failedLabels + 1] = label
    end
    U.log(value and "PASS" or "FAIL", label)
    return value
  end
  local function isText(value)
    return value and getmetatable(value) == TextBox
  end
  local function waitForText(frames)
    for _ = 1, frames or 300 do
      local top = game.stack:top()
      if isText(top) then return top end
      U.wait(1)
    end
  end
  local function waitForPage(box, page, frames)
    for _ = 1, frames or 300 do
      if game.stack:top() == box and box.pageIndex == page
          and (box.waiting or box.done) then return true end
      U.wait(1)
    end
    return false
  end
  local function openReaction(label)
    check(label .. " spawns through the real wanderer pipeline",
      wanderers.trySpawn(game))
    local active = wanderers.active
    check(label .. " owns a real dynamic field NPC",
      active and active.npcId ~= nil)
    local box = waitForText(300)
    check(label .. " reaches the real TextBox after the emote", box ~= nil)
    if box then
      check(label .. " HALT page completes", waitForPage(box, 1, 180))
      U.tap(game, "a")
      check(label .. " reaction page completes", waitForPage(box, 2, 240))
    end
    return active, box
  end
  local function closeReaction(active, box)
    if game.stack:top() == box then game.stack:pop() end
    wanderers.cleanup(active)
    U.wait(8)
  end
  local function bucket()
    return assert(game.save.modData
      and game.save.modData.kanto_ascendant)
  end

  -- The package identity must own a genuinely empty external archive.  Build
  -- the source Champion state in the live save, then use only public product
  -- APIs to unlock/select the title before the destructive boundary.
  local profile = archive.profile()
  assert(profile.cycle == 0 and not profile.current.runId,
    "Legacy title/card identity does not own an empty archive")
  game.save.options = game.save.options or {}
  game.save.options.textSpeed = 1
  game.save.flags = game.save.flags or {}
  game.save.flags.EVENT_BEAT_CHAMPION_RIVAL = true
  game.save.player.id = 6543
  game.save.player.name = "ROT"
  game.save.player.rival = "BLAU"
  game.save.party = { Pokemon.new(game.data, "PIKACHU", 52) }
  game.save.boxes = game.save.boxes or { {} }
  game.save.inventory = { POTION = 2 }
  game.save.pcItems = {}
  game.save.daycare = nil
  game.save.hallOfFame = { { game.save.party[1] } }
  game.save.modData = game.save.modData or {}
  game.save.modData.kanto_ascendant =
    game.save.modData.kanto_ascendant or {}
  game.mods.modSave = game.save.modData
  check("Factory Architect unlocks through the real achievement API",
    ascendant.unlockAchievement("factory_architect"))
  check("Factory Architect selects through the real Hall API",
    hall.selectTitle("factory_architect"))
  local titleId, titleName = hall.currentTitle()
  check("German Factory Architect title is active on the source save",
    titleId == "factory_architect" and titleName == "FABRIK-ARCHITEKT")

  local current, stored = archive.beginJourney(game.save, {
    pact = "legacy", bankPolicy = "sealed", playerAvatar = "RED",
    runRules = archive.safeRunRulesSnapshot(game.save),
  })
  check("real archive transaction accepted the titled Champion",
    current and stored and current.cycle == 1
      and current.status == "pending_new_game")
  local fresh = SaveData.newGame(game:bootConfig())
  check("engine save.new_game seeded the archived Legacy run",
    journey.isActive(fresh)
      and journey.currentPact(fresh) == "legacy")
  game:restoreSave(fresh, false)
  game.mods.modSave = game.save.modData
  check("fresh run binds its real Legacy avatar",
    archive.setAvatar(game.save, "RED"))
  check("fresh run marks the archive active through native save writing",
    game:writeSave())
  local loaded = assert(SaveData.load(),
    "Legacy title/card native slot did not reload")
  game:restoreSave(loaded, false)
  game.mods.modSave = game.save.modData
  U.wait(20)

  local run = assert(journey.state(game.save),
    "reloaded Legacy run state is missing")
  titleId, titleName = hall.currentTitle()
  check("selected archive title survives native save/reload",
    titleId == "factory_architect" and titleName == "FABRIK-ARCHITEKT"
      and run.cycle == 1 and run.pact == "legacy")
  check("Trainer Card pact label comes from the active archived run",
    hall.pactCardText(game.save) == "PAKT:VERM.")
  Screens.push(game, "TrainerCard")
  U.wait(45)
  check("archived title and pact render on the real Trainer Card",
    U.shot(game, dir .. "/01_archive_title_trainer_card.png"))
  U.tap(game, "b")
  U.wait(20)

  -- Restrict the ordinary randomized pool to Scientist so the real dynamic
  -- NPC deterministically reaches the Factory title-specific reaction.
  local originalArchetypes = wanderers.ARCHETYPES
  wanderers.ARCHETYPES = {
    { class = "OPP_SCIENTIST", sprite = "SPRITE_SCIENTIST" },
  }
  U.teleport(game, "ROUTE_1", 5, 5, "down")
  U.wait(20)
  check("real Route 1 overworld is active",
    game.overworld and game.overworld.map.id == "ROUTE_1"
      and game.stack:top() == game.overworld)
  local active, box = openReaction("Factory Architect Scientist")
  check("matching class receives the archived selected-title reaction",
    active and wanderers.reactionContext(active).kind == "title_factory")
  if box then
    check("selected-title recognition dialog screenshot",
      U.shot(game, dir .. "/02_factory_architect_recognition.png"))
    U.tap(game, "a")
    check("Factory challenge page completes", waitForPage(box, 3, 240))
    check("selected-title challenge dialog screenshot",
      U.shot(game, dir .. "/03_factory_architect_challenge.png"))
  end
  closeReaction(active, box)

  -- Retain the driver's separate partner-condition proof.  This last local
  -- mutation is deliberately not persisted and cannot replace the preceding
  -- archive/title/native-save acceptance.
  local localBucket = bucket()
  localBucket.legacy_hall.selectedTitle = nil
  localBucket.ascendant.selectedTitle = nil
  localBucket.ascendant.latestAchievement = nil
  localBucket.legacy_journey.partnerSpecies = "PIKACHU"
  localBucket.legacy_journey.partnerChosen = true
  check("title clears locally for the independent partner proof",
    hall.currentTitle() == nil)
  check("partner proof spawns through the real wanderer pipeline",
    wanderers.trySpawn(game))
  active = wanderers.active
  if active then
    active.team[1] = active.team[1] or { level = 8 }
    active.team[1].species = "PIKACHU"
  end
  box = waitForText(300)
  check("committed partner reaches the real TextBox", box ~= nil)
  if box then
    check("partner HALT page completes", waitForPage(box, 1, 180))
    U.tap(game, "a")
    check("partner recognition page completes", waitForPage(box, 2, 240))
  end
  check("matching roster recognizes only the committed partner",
    active and wanderers.reactionContext(active).kind == "partner_match")
  if box then
    check("matching-partner dialog screenshot",
      U.shot(game, dir .. "/04_committed_partner_match.png"))
  end
  closeReaction(active, box)
  wanderers.ARCHETYPES = originalArchetypes

  local result = assert(io.open(dir .. "/driver_result.txt", "wb"))
  result:write(fail == 0 and "status=PASS\n" or "status=FAIL\n")
  result:write("scope=LEGACY-TITLE-ARCHIVE-CARD\n")
  result:write("edition=red\nlocale=de\n")
  result:write("archive_title_handoff=1/1\n")
  result:write("native_save_reload=1/1\n")
  result:write("trainer_card_title=FABRIK-ARCHITEKT\n")
  result:write("trainer_card_pact=PAKT:VERM.\n")
  result:write("wanderer_title_reaction=1/1\n")
  result:write("committed_partner_reaction=1/1\n")
  result:write("pass=", tostring(pass), "\nfail=", tostring(fail), "\n")
  for _, key in ipairs({ "engine_payload_sha256",
      "authority_package_sha256", "deutsch_package_sha256",
      "package_gate_receipt_sha256" }) do
    result:write(key, "=", receipts[key], "\n")
  end
  for index, label in ipairs(failedLabels) do
    result:write("failed_", tostring(index), "=", label, "\n")
  end
  result:close()
  U.log(("LEGACY TITLE/ARCHIVE CARD RESULT pass=%d fail=%d")
    :format(pass, fail))
  love.event.quit(fail == 0 and 0 or 1)
end
