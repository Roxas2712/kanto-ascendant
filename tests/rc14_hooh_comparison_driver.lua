-- Visual comparison proof for the later, ordinary catchable Ho-Oh encounter.

return function(game)
  local U = dofile("tests/drivers/util.lua")
  local BattleState = require("src.battle.BattleState")
  local Pokemon = require("src.pokemon.Pokemon")
  local Pipelines = require("src.render.Pipelines")
  local dir = assert(os.getenv("SHOT_DIR"), "SHOT_DIR is required")
  local pass, fail = 0, 0

  local function check(label, value)
    if value then pass = pass + 1 else fail = fail + 1 end
    U.log(value and "PASS" or "FAIL", label)
  end

  while game.stack:top() and game.stack:top() ~= game.overworld do
    game.stack:pop()
  end

  local options = game.mods.modOptions.kanto_ascendant or {}
  game.mods.modOptions.kanto_ascendant = options
  options.pokemon_sprite_style = "crystal"
  options.crystal_animation = true
  options.sprite_style_battle = true
  game.save.options.modOptions = game.save.options.modOptions or {}
  game.save.options.modOptions.kanto_ascendant = options

  U.teleport(game, "ROUTE_2", 4, 48, "down")
  game.save.party = { Pokemon.new(game.data, "PIKACHU", 60) }

  local dramatic = game.mods.exports.DRAMALESS_SHAPE
    or game.mods.exports.DRAMATIC_SHAPE
  if dramatic then
    Pipelines.setLevel("voxel", 1)
    Pipelines.syncOptions(game.save.options)
    local overworldBattle = dramatic.lib.require("OverworldBattle")
    if overworldBattle and overworldBattle.setting then
      overworldBattle.setting:setIndex(1, game)
    end
  end

  local battle = BattleState.newWild(game, "HO_OH", 95)
  battle.postgameLegend = "HO_OH"
  battle.onFinish = function() end
  game.overworld:pushBattle(battle)

  local reachedMenu = false
  for frame = 1, 1500 do
    if game.stack:top() == battle and battle.phase == "menu" then
      reachedMenu = true
      break
    end
    if frame % 5 == 0 then U.tap(game, "a") else U.wait(1) end
  end

  check("later Ho-Oh reaches a normal player-controlled battle", reachedMenu)
  check("later Ho-Oh reveals its identity and level",
    battle.enemy.name ~= "???" and battle.enemy.mon.level == 95)
  check("later Ho-Oh uses its ordinary palette",
    battle.enemy.__ascendantVisionGold ~= true)
  check("later Ho-Oh remains catchable",
    battle.noCatch ~= true and battle.demo ~= true)
  check("regular Ho-Oh comparison screenshot",
    U.shot(game, dir .. "/02_later_regular_catchable_hooh.png"))

  U.log(("RC14 HO-OH COMPARISON RESULT pass=%d fail=%d"):format(pass, fail))
  love.event.quit(fail == 0 and 0 or 1)
end
