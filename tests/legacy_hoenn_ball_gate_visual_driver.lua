-- Real LÖVE acceptance for the visible left Hoenn partner ball.
-- Runs RED/BLUE/GREEN through a non-matching permanent seal, then their
-- exact permanent seal, a real selection, save/reload and a no-double-gift
-- retry.  It deliberately invokes Oak's installed map-talk handler.

return function(game)
  local U = dofile(os.getenv("KA_TEST_UTIL") or "tests/drivers/util.lua")
  local MapScripts = require("data.scripts.init")
  local TextBox = require("src.render.TextBox")
  local ChoiceBox = require("src.ui.ChoiceBox")
  local SaveData = require("src.core.SaveData")
  local dir = assert(os.getenv("SHOT_DIR"), "SHOT_DIR is required")
  local api = assert(game.mods.exports.kanto_ascendant)
  local starters = assert(api.legacyStarters)
  local journey = assert(api.legacyJourney)
  local characters = assert(api.extendedCharacters)
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
  local function isText(top)
    return top and getmetatable(top) == TextBox
  end
  local function stableText(frames)
    return waitFor(function()
      local top = game.stack:top()
      return isText(top) and (top.done or top.waiting) and top or nil
    end, frames or 1200)
  end
  local function advanceText()
    local top = assert(stableText(), "expected stable Oak text")
    U.tap(game, "a")
    return stableText()
  end
  local function waitCatalog()
    return waitFor(function()
      local top = game.stack:top()
      return getmetatable(top) == starters.Catalog and top or nil
    end, 900)
  end
  local function waitChoice()
    return waitFor(function()
      local top = game.stack:top()
      if getmetatable(top) == ChoiceBox then return top end
      if isText(top) then
        if top.waiting then U.tap(game, "a")
        elseif not top.done then
          game.input.state.a = true
          U.wait(1)
          game.input.state.a = false
        else U.wait(1) end
      else U.wait(1) end
      return nil
    end, 1200)
  end
  local function chooseYes()
    local choice = assert(waitChoice(), "expected default-NO choice")
    if choice.index == 2 then U.tap(game, "up") end
    U.tap(game, "a")
  end
  local function drain(frames)
    return waitFor(function()
      if game.stack:top() == game.overworld
          and not (game.overworld.runner and game.overworld.runner:isRunning()) then
        return true
      end
      if game.stack:top() ~= game.overworld then U.tap(game, "a") else U.wait(1) end
      return nil
    end, frames or 1600) == true
  end
  local function runLeftBall()
    local handler = MapScripts.talkScript("OAKS_LAB", "TEXT_OAKSLAB_CHARMANDER_POKE_BALL")
    local finished = false
    assert(type(handler) == "function" or type(handler) == "table",
      "installed left Oak-ball handler missing")
    if type(handler) == "function" then
      handler(game, game.overworld, nil, function() finished = true end)
    else
      game.overworld.runner:run(handler, { onDone = function() finished = true end })
    end
    return function() return finished end
  end
  local function count(value)
    local n = 0
    for _ in pairs(value or {}) do n = n + 1 end
    return n
  end
  local function state()
    local bucket = game.save.modData and game.save.modData.kanto_ascendant
    return bucket and bucket.legacy_journey
  end
  local heroData = {
    RED = { key = "red", cross = "blue", species = "TORCHIC" },
    BLUE = { key = "blue", cross = "green", species = "MUDKIP" },
    GREEN = { key = "green", cross = "red", species = "TREECKO" },
  }

  local function configure(hero, completed, tag)
    local spec = assert(heroData[hero])
    local runId = "hoenn-ball-visual-" .. hero:lower() .. "-" .. tag
    local archive = journey.archive.load()
    archive.completedPaths = completed
    archive.pathSealCycles = {
      red = completed.red and 10 or nil,
      blue = completed.blue and 20 or nil,
      green = completed.green and 30 or nil,
    }
    archive.current = {
      cycle = 77, runId = runId, avatar = hero, avatarQuestStage = 0,
      pathComplete = false, partnerChosen = false,
      bankUnlocked = true, wanderersEnabled = true,
    }
    assert(journey.archive.write(archive), "could not write disposable path-seal archive")

    game.save.party, game.save.inventory = {}, {}
    game.save.pokedex = { seen = {}, owned = {} }
    -- This is the live Oak-lab availability gate.  Without it the installed
    -- handler correctly reports the ordinary empty-ball branch, which would
    -- test neither the seal gate nor the Hoenn catalogue.
    game.save.flags = {
      KA_LEGACY_RIVAL_BALL_TAKEN = true,
      EVENT_FOLLOWED_OAK_INTO_LAB = true,
    }
    game.save.objectToggles = {}
    game.save.options = game.save.options or {}
    game.save.options.textSpeed = 1
    game.save.player.name = hero
    game.save.player.rival = hero == "RED" and "BLUE" or "RED"
    game.save.modData = game.save.modData or {}
    game.save.modData.kanto_ascendant = game.save.modData.kanto_ascendant or {}
    game.save.modData.kanto_ascendant.legacy_journey = {
      version = 6, cycle = 77, runId = runId, avatar = hero,
      avatarQuestStage = 0, pathComplete = false,
      completedPaths = completed, rivalBallTaken = true,
      bankUnlocked = true, wanderersEnabled = true,
    }
    game:adoptSave(game.save)
    characters.select(hero)
    starters.refresh(game)
    U.teleport(game, "OAKS_LAB", 5, 5, "up")
    U.wait(20)
    check(hero .. " visible left ball is in the real Oak lab",
      game.overworld.map.id == "OAKS_LAB" and starters.heroChoice(game.save).species == spec.species)
  end

  U.wait(30)
  for hero, spec in pairs(heroData) do
    local crossOnly = { red = false, blue = false, green = false }
    crossOnly[spec.cross] = true
    configure(hero, crossOnly, "cross-locked")
    check(hero .. " cross-character seal does not unlock left ball", not starters.hoennUnlocked(game.save))
    local lockedDone = runLeftBall()
    local lockPage = stableText()
    check(hero .. " locked requirement page is fully visible", lockPage ~= nil)
    check(hero .. " cross-seal locked capture",
      lockPage and U.shot(game, dir .. "/" .. hero:lower() .. "_01_cross_seal_locked.png"))
    local nextLife = advanceText()
    check(hero .. " next-life hint is fully visible", nextLife ~= nil)
    check(hero .. " next-life hint capture",
      nextLife and U.shot(game, dir .. "/" .. hero:lower() .. "_02_next_life_hint.png"))
    check(hero .. " locked interaction returns cleanly", drain() and lockedDone())
    check(hero .. " locked ball gave no party or Dex entry",
      #game.save.party == 0 and count(game.save.pokedex.seen) == 0
        and count(game.save.pokedex.owned) == 0 and not state().partnerChosen)

    local exact = { red = false, blue = false, green = false }
    exact[spec.key] = true
    configure(hero, exact, "exact-unlocked")
    check(hero .. " exact seal unlocks only its own left ball", starters.hoennUnlocked(game.save))
    local selectDone = runLeftBall()
    local catalog = waitCatalog()
    check(hero .. " exact seal opens its one-species Hoenn catalog",
      catalog and catalog.mode == "hoenn" and catalog.modeLocked
        and #catalog.rows == 1 and catalog:current().id == spec.species)
    check(hero .. " unlocked Hoenn partner capture",
      catalog and U.shot(game, dir .. "/" .. hero:lower() .. "_03_unlocked_catalog.png"))
    U.tap(game, "a")
    chooseYes()
    chooseYes()
    local receipt = stableText(1600)
    check(hero .. " received-partner text is fully visible", receipt ~= nil)
    check(hero .. " received partner capture",
      receipt and U.shot(game, dir .. "/" .. hero:lower() .. "_04_received_partner.png"))
    check(hero .. " selection returns to the lab", drain() and selectDone())
    check(hero .. " selection commits one correct party mon and only its Dex bits",
      #game.save.party == 1 and game.save.party[1].species == spec.species
        and game.save.pokedex.seen[spec.species] and game.save.pokedex.owned[spec.species]
        and count(game.save.pokedex.seen) == 1 and count(game.save.pokedex.owned) == 1
        and state().partnerChosen and state().partnerBall == "left")
    check(hero .. " post-selection lab capture",
      U.shot(game, dir .. "/" .. hero:lower() .. "_05_selected_lab.png"))
    check(hero .. " save after exact Hoenn selection", game:writeSave())
    local loaded = assert(SaveData.load(), "Hoenn selection save did not reload")
    game:restoreSave(loaded, false)
    U.wait(30)
    U.teleport(game, "OAKS_LAB", 5, 5, "up")
    check(hero .. " reload retains exact party, Dex and left-ball sentinel",
      #game.save.party == 1 and game.save.party[1].species == spec.species
        and game.save.pokedex.owned[spec.species] and state().partnerChosen)
    local retryDone = runLeftBall()
    local empty = stableText()
    check(hero .. " claimed left ball cannot award a second partner", empty ~= nil
      and #game.save.party == 1 and count(game.save.pokedex.owned) == 1)
    check(hero .. " reload no-double-gift capture",
      empty and U.shot(game, dir .. "/" .. hero:lower() .. "_06_reload_no_double_gift.png"))
    check(hero .. " no-double-gift interaction returns cleanly", drain() and retryDone())
  end
  U.log(("LEGACY HOENN LEFT BALL VISUAL RESULT pass=%d fail=%d"):format(pass, fail))
  love.event.quit(fail == 0 and 0 or 1)
end
