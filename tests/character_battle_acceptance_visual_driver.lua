-- Real-renderer audit of the generated character battle saves and all
-- 72 identity/stage/starter constructions.

return function(game)
  local U = dofile("tests/drivers/util.lua")
  local BattleState = require("src.battle.BattleState")
  local SaveData = require("src.core.SaveData")
  local Pipelines = require("src.render.Pipelines")
  local dir = assert(os.getenv("SHOT_DIR"), "SHOT_DIR is required")
  local exports = assert(game.mods and game.mods.exports
    and game.mods.exports.kanto_ascendant)
  local characters = assert(exports.extendedCharacters)
  local teams = assert(exports.rivalTeams)
  local qa = assert(exports.battleAcceptance)
  local pass, fail = 0, 0

  local function check(label, value)
    if value then pass = pass + 1 else fail = fail + 1 end
    U.log(value and "PASS" or "FAIL", label)
  end

  local function clearStack()
    while game.stack:top() do game.stack:pop() end
  end

  local function loadSlot(id)
    assert(SaveData.setActiveSlot("red", id) == id)
    local loaded = assert(SaveData.load("red"))
    game:restoreSave(loaded, false)
    -- This suite proves the authored 2D backs.  Acceptance saves inherit the
    -- user's display preferences, so pin the renderer without changing the
    -- save on disk; the separate Voxel suite owns the standing-front proof.
    Pipelines.setLevel("voxel", 0)
    Pipelines.syncOptions(game.save.options)
    game.save.options.battleLayout = "wide"
    U.wait(18)
    return loaded
  end

  U.wait(24)
  local slots = {
    { id = "slot6511", player = "RED", rival = "BLUE", tag = "blue" },
    { id = "slot6512", player = "BLUE", rival = "GREEN", tag = "green" },
    { id = "slot6513", player = "GREEN", rival = "RED", tag = "red" },
  }
  local rows = qa.rows()
  check("battle acceptance exposes 24 stage/branch rows", #rows == 24)

  local rosterCount = 0
  for _, slot in ipairs(slots) do
    loadSlot(slot.id)
    local state = characters.getState()
    check(slot.tag .. " save player identity", state.player_character == slot.player)
    check(slot.tag .. " save rival identity", state.rival_character == slot.rival)
    check(slot.tag .. " save QA marker", qa.enabled())
    for _, row in ipairs(rows) do
      local trainer = assert(game.data.trainers[row.value.class])
      local original = assert(trainer.parties[row.value.partyIndex])
      local expected = teams.resolve(slot.rival, row.value.class,
        row.value.partyIndex, original)
      local battle = BattleState.newTrainer(game, row.value.class,
        row.value.partyIndex)
      local exact = #battle.enemyParty == #expected
        and not battle.trainerPartyHookFallback
      for index, authored in ipairs(expected) do
        local actual = battle.enemyParty[index]
        exact = exact and actual and actual.species == authored.species
          and actual.level == authored.level
      end
      rosterCount = rosterCount + 1
      check(slot.tag .. " " .. row.label .. " roster", exact)
    end
  end
  check("all 72 rival rosters constructed from generated saves",
    rosterCount == 72)

  loadSlot("slot6513")
  qa.open(game)
  U.wait(12)
  check("Rival Test list screenshot",
    U.shot(game, dir .. "/01_rival_test_menu.png"))
  clearStack()

  local championRow = rows[22] -- Champion / water starter branch
  for _, slot in ipairs(slots) do
    loadSlot(slot.id)
    local battle = qa.launch(game, championRow.value)
    local introReady = false
    for _ = 1, 420 do
      if battle.showEnemyTrainer and battle.introBalls
          and game.stack:top() == battle then
        introReady = true
        break
      end
      U.wait(1)
    end
    check(slot.tag .. " champion reaches trainer intro", introReady)
    U.wait(60)
    check(slot.tag .. " Champion trainer screenshot",
      U.shot(game, dir .. "/02_champion_" .. slot.tag .. "_trainer.png"))

    local menuReady = false
    for _ = 1, 900 do
      if game.stack:top() == battle and battle.phase == "menu"
          and not battle.showEnemyTrainer and not battle.showPlayerBack then
        menuReady = true
        break
      end
      if U.frame() % 5 == 0 then U.tap(game, "a") else U.wait(1) end
    end
    check(slot.tag .. " Champion reaches battle menu", menuReady)
    check(slot.tag .. " Champion field screenshot",
      U.shot(game, dir .. "/03_champion_" .. slot.tag .. "_field.png"))
    clearStack()
  end

  U.log(("CHARACTER BATTLE ACCEPTANCE RESULT pass=%d fail=%d")
    :format(pass, fail))
  love.event.quit(fail == 0 and 0 or 1)
end
