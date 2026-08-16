-- Real Dramatic Shape audit for normal and shiny Celebi.

return function(game)
  local U = dofile("tests/drivers/util.lua")
  local BattleState = require("src.battle.BattleState")
  local Pipelines = require("src.render.Pipelines")
  local Pokemon = require("src.pokemon.Pokemon")
  local Stats = require("src.pokemon.Stats")

  U.wait(30)
  local exports = assert(game.mods and game.mods.exports
      and game.mods.exports.kanto_ascendant,
    "Kanto Ascendant export missing")
  local shiny = assert(exports.shinySystem, "Shiny controller missing")
  local dramatic = assert(game.mods.exports.DRAMATIC_SHAPE,
    "Dramatic Shape is not active")
  local overworldBattle = dramatic.lib.require("OverworldBattle")
  local shotDir = assert(os.getenv("SHOT_DIR"), "SHOT_DIR is required")

  Pipelines.setLevel("voxel", 1)
  Pipelines.syncOptions(game.save.options)
  overworldBattle.setting:setIndex(1, game)
  overworldBattle.backSetting:setIndex(1, game)
  game.save.pokedex = game.save.pokedex or { seen = {}, owned = {} }

  local function closeBattle()
    while game.stack:top() and game.stack:top() ~= game.overworld do
      game.stack:pop()
    end
  end

  for index, playerShiny in ipairs({ false, true }) do
    local player = Pokemon.new(game.data, "CELEBI", 70,
      function() return 9 end)
    if playerShiny then
      assert(shiny.forceMon(player, game.data.pokemon.CELEBI))
    end
    player.stats = Stats.calc(game.data.pokemon.CELEBI, 70,
      player.dvs, player.statExp)
    player.hp = player.stats.hp
    game.save.party = { player }

    U.teleport(game, "ROUTE_1", 5, 8, "down")
    U.wait(30)
    assert(overworldBattle.wantsFront(),
      "Dramatic Shape did not stage the Voxel arena")
    local battle = BattleState.newWild(game, "CELEBI", 70)
    if not playerShiny then
      assert(shiny.forceMon(battle.enemy.mon, game.data.pokemon.CELEBI))
      battle.enemy = BattleState.makeBattler(
        game.data, battle.enemy.mon, false, game.save)
    end
    battle.onFinish = function() end
    game.overworld:pushBattle(battle)
    for _ = 1, 320 do
      if battle.phase == "menu" then break end
      U.tap(game, "a")
      U.wait(4)
    end
    assert(battle.phase == "menu", "Voxel Celebi battle did not reach menu")
    assert(battle.player.__ascendantCrystalAnimation,
      "Voxel player Celebi did not use its Crystal front")
    assert(battle.enemy.__ascendantCrystalAnimation,
      "Voxel enemy Celebi did not use its Crystal front")
    assert(U.shot(game, ("%s/%02d_voxel_player_%s_enemy_%s.png")
      :format(shotDir, index,
        playerShiny and "shiny" or "normal",
        playerShiny and "normal" or "shiny")))
    closeBattle()
    U.wait(10)
  end

  U.log("CELEBI VOXEL QA PASS",
    os.getenv("POKEPORT_VERSION") or "unknown",
    "normal+shiny both sides")
end
