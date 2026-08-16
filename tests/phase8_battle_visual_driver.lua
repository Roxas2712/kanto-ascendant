-- Renderer-backed proof for the three Phase-8 player/rival combinations and
-- the three Oak's Lab starter-counter rosters.

return function(game)
  local U = dofile("tests/drivers/util.lua")
  local BattleState = require("src.battle.BattleState")
  local Pokemon = require("src.pokemon.Pokemon")
  local dir = assert(os.getenv("SHOT_DIR"), "SHOT_DIR is required")
  local exports = game.mods and game.mods.exports
    and game.mods.exports.kanto_ascendant
  local characters = exports and exports.extendedCharacters
  local rivalTeams = exports and exports.rivalTeams
  local pass, fail = 0, 0

  local function check(label, value)
    if value then pass = pass + 1 else fail = fail + 1 end
    U.log(value and "PASS" or "FAIL", label)
  end

  local function clearStack()
    while game.stack:top() do game.stack:pop() end
  end

  local cases = {
    { player = "RED", rival = "BLUE", party = 1,
      lead = "CHARMANDER", enemy = "SQUIRTLE", tag = "13_red_vs_blue" },
    { player = "BLUE", rival = "GREEN", party = 2,
      lead = "SQUIRTLE", enemy = "BULBASAUR", tag = "14_blue_vs_green" },
    { player = "GREEN", rival = "RED", party = 3,
      lead = "BULBASAUR", enemy = "CHARMANDER", tag = "15_green_vs_red" },
  }

  check("Kanto Ascendant character API loaded", characters ~= nil)
  if not characters then love.event.quit(1) return end
  game.save.options = game.save.options or {}
  game.save.options.textSpeed = 1
  U.wait(12)

  -- Exhaustive construction audit: every rival roster in all three trainer
  -- classes must build as its identity-specific species/level data. This
  -- covers the Lab, Route 22, Cerulean, S.S. Anne, Pokémon Tower, Silph,
  -- Route 22 rematch and Champion progression, including all starter branches
  -- (24 rosters × 3 identity maps).
  local identityMatrix = {
    RED = "BLUE", BLUE = "GREEN", GREEN = "RED",
  }
  local rivalClasses = { "OPP_RIVAL1", "OPP_RIVAL2", "OPP_RIVAL3" }
  local rosterCases = 0
  for player, expectedRival in pairs(identityMatrix) do
    local state = characters.select(player)
    characters.refreshVisuals(game)
    game.save.player.name = player
    game.save.player.rival = expectedRival
    game.save.party = { Pokemon.new(game.data, "PIKACHU", 100) }
    check(player .. " exhaustive battle identity",
      state.rival_character == expectedRival)
    for _, class in ipairs(rivalClasses) do
      local trainer = assert(game.data.trainers[class], class)
      for partyIndex, expected in ipairs(trainer.parties) do
        rosterCases = rosterCases + 1
        local expected = rivalTeams.resolve(expectedRival, class,
          partyIndex, trainer.parties[partyIndex])
        local battle = BattleState.newTrainer(game, class, partyIndex)
        local exact = #battle.enemyParty == #expected
        for slot, authored in ipairs(expected) do
          local actual = battle.enemyParty[slot]
          exact = exact and actual ~= nil
            and actual.species == authored.species
            and actual.level == authored.level
        end
        check(('%s %s party %02d exact roster'):format(
          player, class, partyIndex), exact)
      end
    end
  end
  check("all 72 character/rival roster constructions executed",
    rosterCases == 72)

  characters.select("GREEN")
  local redFinal = BattleState.newTrainer(game, "OPP_RIVAL3", 3)
  local expectedRed = {
    "PIKACHU:81", "ESPEON:73", "SNORLAX:75", "VENUSAUR:77",
    "CHARIZARD:77", "BLASTOISE:77",
  }
  local actualRed = {}
  for _, mon in ipairs(redFinal.enemyParty) do
    actualRed[#actualRed + 1] = mon.species .. ":" .. mon.level
  end
  check("Red Champion uses canonical Mt. Silver Gold/Crystal team",
    table.concat(actualRed, ",") == table.concat(expectedRed, ","))

  characters.select("RED")
  local blueFinal = BattleState.newTrainer(game, "OPP_RIVAL3", 1)
  check("Blue Champion remains the original authored roster",
    blueFinal.enemyParty[1].species == "PIDGEOT"
      and blueFinal.enemyParty[6].species == "BLASTOISE")

  for _, case in ipairs(cases) do
    U.teleport(game, "ROUTE_1", 5, 5, "down")
    local state = characters.select(case.player)
    characters.refreshVisuals(game)
    game.save.player.name = case.player
    game.save.player.rival = case.rival
    game.save.party = { Pokemon.new(game.data, case.lead, 5) }

    local battle = BattleState.newTrainer(game, "OPP_RIVAL1", case.party)
    check(case.tag .. " identity matrix", state.player_character == case.player
      and state.rival_character == case.rival)
    check(case.tag .. " opening rival roster", #battle.enemyParty == 1
      and battle.enemyParty[1].species == case.enemy
      and battle.enemyParty[1].level == 5)
    check(case.tag .. " battle back is final",
      characters.getPlayerSprite("battleBack").status == "final")

    game.overworld:pushBattle(battle)
    local introReady = false
    for _ = 1, 360 do
      if battle.showEnemyTrainer and battle.introBalls
          and game.stack:top() == battle then
        introReady = true
        break
      end
      U.wait(1)
    end
    check(case.tag .. " reaches trainer intro", introReady)
    U.wait(80)
    check(case.tag .. " trainer/back capture",
      U.shot(game, dir .. "/" .. case.tag .. "_trainer_intro.png"))

    local menuReady = false
    for _ = 1, 900 do
      if game.stack:top() == battle and battle.phase == "menu"
          and not battle.showEnemyTrainer and not battle.showPlayerBack then
        menuReady = true
        break
      end
      if U.frame() % 5 == 0 then U.tap(game, "a") else U.wait(1) end
    end
    check(case.tag .. " reaches live battle menu", menuReady)
    check(case.tag .. " starter field capture",
      U.shot(game, dir .. "/" .. case.tag .. "_starter_field.png"))
    clearStack()
    U.wait(3)
  end

  U.log(("PHASE8 BATTLE RESULT pass=%d fail=%d"):format(pass, fail))
  love.event.quit(fail == 0 and 0 or 1)
end
