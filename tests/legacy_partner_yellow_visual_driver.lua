-- Focused renderer-backed Yellow regressions for the Legacy catalogue:
-- cancelling it must release the interaction, and a non-Pikachu partner must
-- not inherit Yellow's post-battle Pikachu cry/dialogue beat.
--
-- Run from Gen1 Recomp with POKEPORT_VERSION=yellow and a disposable identity.

return function(game)
  local U = dofile(os.getenv("KA_TEST_UTIL") or "tests/drivers/util.lua")
  local MapScripts = require("data.scripts.init")
  local TextBox = require("src.render.TextBox")
  local ChoiceBox = require("src.ui.ChoiceBox")
  local dir = assert(os.getenv("SHOT_DIR"), "SHOT_DIR is required")
  local exports = assert(game.mods.exports.kanto_ascendant)
  local starters = assert(exports.legacyStarters)
  local pass, fail = 0, 0

  local function check(label, value)
    if value then pass = pass + 1 else fail = fail + 1 end
    U.log(value and "PASS" or "FAIL", label)
    return value
  end
  local function countKeys(value)
    local count = 0
    for _ in pairs(value or {}) do count = count + 1 end
    return count
  end
  local function state()
    return game.save.modData.kanto_ascendant.legacy_journey
  end
  local function isCatalog(value)
    return value and getmetatable(value) == starters.Catalog
  end
  local function isText(value)
    return value and getmetatable(value) == TextBox
  end
  local function isChoice(value)
    return value and getmetatable(value) == ChoiceBox
  end
  local function waitFor(predicate, frames)
    for _ = 1, frames or 600 do
      local value = predicate()
      if value then return value end
      U.wait(1)
    end
    return nil
  end
  local function waitForChoice(frames)
    for _ = 1, frames or 700 do
      local top = game.stack:top()
      if isChoice(top) then return top end
      if isText(top) then
        if top.waiting then
          U.tap(game, "a")
        elseif not top.done then
          game.input.state.a = true
          U.wait(1)
          game.input.state.a = false
        else
          U.wait(1)
        end
      else
        U.wait(1)
      end
    end
    game.input.state.a = false
    return nil
  end
  local function openYellowBall()
    local done = false
    local handler = MapScripts.talkScript(
      "OAKS_LAB", "TEXT_OAKSLAB_EEVEE_POKE_BALL")
    handler(game, game.overworld, nil, function() done = true end)
    return function() return done end
  end
  local function contains(rows, verb, arg)
    for _, row in ipairs(rows or {}) do
      if row[1] == verb and (arg == nil or row[2] == arg) then return true end
    end
    return false
  end
  local function captureOnStepRows(species)
    local s = state()
    s.partnerChosen, s.partnerSpecies = true, species
    game.save.flags.EVENT_GOT_STARTER = true
    game.save.flags.EVENT_BATTLED_RIVAL_IN_OAKS_LAB = nil
    local runner = game.overworld.runner
    local realRun = runner.run
    local captured
    runner.run = function(_, rows)
      captured = rows
      return true
    end
    local ok, handled = pcall(MapScripts.get("OAKS_LAB").onStep,
      game, game.overworld, 4, 6)
    runner.run = realRun
    return ok, handled, captured
  end

  game.save.party = {}
  game.save.pokedex = { seen = {}, owned = {} }
  game.save.flags = { EVENT_OAK_ASKED_TO_CHOOSE_MON = true }
  game.save.objectToggles = {}
  game.save.options.textSpeed = 1
  game.save.modData = game.save.modData or {}
  game.save.modData.kanto_ascendant =
    game.save.modData.kanto_ascendant or {}
  game.save.modData.kanto_ascendant.legacy_journey = {
    version = 5, cycle = 65, runId = "legacy-yellow-cancel", avatar = "RED",
  }
  starters.refresh(game)
  U.teleport(game, "OAKS_LAB", 7, 4, "up")
  U.wait(24)
  check("Yellow's real Oak lab has its authored Eevee ball handler",
    type(MapScripts.talkScript(
      "OAKS_LAB", "TEXT_OAKSLAB_EEVEE_POKE_BALL")) == "function")

  local firstDone = openYellowBall()
  local firstQuestion = waitForChoice(700)
  check("Yellow Legacy choice reaches the Pikachu/catalog question",
    firstQuestion ~= nil)
  if firstQuestion then
    -- B answers NO to Pikachu and enters the catalogue without committing.
    U.tap(game, "b")
  end
  local firstCatalog = waitFor(function()
    local top = game.stack:top()
    return isCatalog(top) and top or nil
  end, 200)
  check("Yellow's NO branch opens the shared graphical catalogue",
    firstCatalog and firstCatalog.mode == "balanced")
  if firstCatalog then
    check("Yellow catalogue-before-cancel screenshot",
      U.shot(game, dir .. "/01_yellow_catalog_before_cancel.png"))
    U.tap(game, "b")
  end
  check("Yellow catalogue B releases the interaction callback",
    waitFor(firstDone, 120) == true)
  check("Yellow cancel returns control to the overworld",
    game.stack:top() == game.overworld
      and not game.overworld.runner:isRunning())
  check("Yellow cancel commits no flags, Dex row or Pokémon",
    #game.save.party == 0
      and countKeys(game.save.pokedex.seen) == 0
      and countKeys(game.save.pokedex.owned) == 0
      and not state().partnerChosen
      and game.save.flags.EVENT_GOT_STARTER == nil
      and game.save.flags.EVENT_CHOSE_PIKACHU == nil)

  -- A second interaction must open normally. This is the exact regression
  -- guard for the old softlock/stuck-interaction failure.
  local secondDone = openYellowBall()
  local reopened = waitForChoice(700)
  check("Yellow ball can be interacted with again after catalogue cancel",
    reopened ~= nil)
  if reopened then
    check("Yellow choice-reopened screenshot",
      U.shot(game, dir .. "/02_yellow_choice_reopened.png"))
    U.tap(game, "b")
  end
  local reopenedCatalog = waitFor(function()
    local top = game.stack:top()
    return isCatalog(top) and top or nil
  end, 200)
  if reopenedCatalog then U.tap(game, "b") end
  check("second Yellow cancel also completes exactly once",
    waitFor(secondDone, 120) == true and game.stack:top() == game.overworld)

  -- Inspect the real composed Yellow onStep hook without entering a lengthy
  -- trainer battle. Its base script still contains the battle and rival-exit
  -- beats, but the Legacy wrapper must remove only the Pikachu escape cry and
  -- two explicit Pikachu text rows for a catalogue partner.
  local okOther, handledOther, otherRows = captureOnStepRows("CHIKORITA")
  check("non-Pikachu postbattle path remains a handled real map event",
    okOther and handledOther == true and type(otherRows) == "table")
  check("non-Pikachu path preserves the rival battle",
    contains(otherRows, "start_battle"))
  check("non-Pikachu path removes Pikachu's escape cry",
    not contains(otherRows, "play_cry", "PIKACHU"))
  check("non-Pikachu path removes Pikachu dislikes text 1",
    not contains(otherRows, "show_text",
      "_OaksLabPikachuDislikesPokeballsText1"))
  check("non-Pikachu path removes Pikachu dislikes text 2",
    not contains(otherRows, "show_text",
      "_OaksLabPikachuDislikesPokeballsText2"))

  local okPika, handledPika, pikaRows = captureOnStepRows("PIKACHU")
  check("Pikachu's own postbattle path remains handled",
    okPika and handledPika == true and type(pikaRows) == "table")
  check("Pikachu's own path keeps its authored escape cry and text",
    contains(pikaRows, "play_cry", "PIKACHU")
      and contains(pikaRows, "show_text",
        "_OaksLabPikachuDislikesPokeballsText1")
      and contains(pikaRows, "show_text",
        "_OaksLabPikachuDislikesPokeballsText2"))

  U.log(("LEGACY PARTNER YELLOW RESULT pass=%d fail=%d"):format(pass, fail))
  love.event.quit(fail == 0 and 0 or 1)
end
