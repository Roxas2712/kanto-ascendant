-- Real-LOVE compatibility QA for Kanto Ascendant, Crystal Animated Sprites
-- with Shiny Visuals, and Dramatic Shape's voxel battle renderer.
--
-- CRYSTAL_QA_MODE=2d:    shiny Johto enemy front, original Crystal player back
-- CRYSTAL_QA_MODE=kanto: bundled shiny Kanto enemy without the external mod
-- CRYSTAL_QA_MODE=voxel: normal Johto enemy + shiny Johto player, both fronts
-- CRYSTAL_QA_MODE=mixed: shiny Kanto enemy from the external mod + shiny Johto
--                        player from Ascendant in one voxel battle

return function(game)
  local U = dofile("tests/drivers/util.lua")
  local mode = os.getenv("CRYSTAL_QA_MODE") or "2d"
  local DIR = os.getenv("SHOT_DIR") or "/tmp/kanto-ascendant-crystal-qa"
  local Pokemon = require("src.pokemon.Pokemon")
  local Stats = require("src.pokemon.Stats")
  local Pipelines = require("src.render.Pipelines")
  local BattleState = require("src.battle.BattleState")

  U.wait(20)
  local api = assert(game.mods and game.mods.exports
    and game.mods.exports.trainer_rematch, "Kanto Ascendant export missing")
  local animation = assert(api.crystalAnimation,
    "Ascendant Crystal animation controller missing")
  local shiny = assert(api.shinySystem, "Ascendant shiny controller missing")
  assert(animation.available[1] and animation.shinyAvailable[1]
      and animation.available[158] and animation.shinyAvailable[160],
    "normal/shiny #001-251 animation packs are incomplete")

  local voxel = mode == "voxel" or mode == "mixed"
  Pipelines.setLevel("voxel", voxel and 1 or 0)
  Pipelines.syncOptions(game.save.options)
  -- Dramatic Shape's staged-battle switch is independent from the world
  -- pipeline. Make the two QA scenes unambiguous: ordinary 2D really asks
  -- for the player's back, while voxel mode asks for both fronts.
  local dramatic = game.mods.exports.DRAMATIC_SHAPE
  if dramatic and dramatic.lib then
    local overworldBattle = dramatic.lib.require("OverworldBattle")
    overworldBattle.setting:setIndex(voxel and 1 or 2, game)
    overworldBattle.backSetting:setIndex(1, game)
  end
  game.save.flags = game.save.flags or {}
  game.save.flags.EVENT_BEAT_CHAMPION_RIVAL = true
  game.save.pokedex = game.save.pokedex or { seen = {}, owned = {} }

  local lead = Pokemon.new(game.data, "FERALIGATR", 50,
    function() return 8 end)
  if voxel then
    assert(shiny.forceMon(lead, game.data.pokemon.FERALIGATR))
    assert(Stats.isShiny(lead.dvs), "player Feraligatr is not shiny")
  end
  game.save.party = { lead }

  U.teleport(game, "ROUTE_1", 5, 5, "down")
  local enemySpecies = mode == "2d" and "SUICUNE"
    or (mode == "mixed" or mode == "kanto") and "BULBASAUR" or "TOTODILE"
  local battle = BattleState.newWild(game, enemySpecies, 35)
  if mode ~= "voxel" then
    assert(shiny.forceMon(battle.enemy.mon, game.data.pokemon[enemySpecies]))
    battle.enemy = BattleState.makeBattler(
      game.data, battle.enemy.mon, false, game.save)
    assert(Stats.isShiny(battle.enemy.mon.dvs), "enemy is not shiny")
  end
  battle.onFinish = function() end
  game.overworld:pushBattle(battle)
  U.wait(180)
  for _ = 1, 24 do U.tap(game, "a"); U.wait(12) end
  U.wait(90)

  local external = game.mods.exports.crystal_animated_sprites_with_shiny_visuals
  if mode == "mixed" then
    assert(external, "external Crystal Animated Sprites mod is not loaded")
    assert(battle.enemy.__crystalAnimation,
      "external Kanto animation did not attach to the enemy")
    assert(not battle.enemy.__ascendantCrystalAnimation,
      "Ascendant did not yield bundled Kanto art to the external mod")
    assert(shiny.externalActive(battle.enemy.mon),
      "external Kanto shiny presentation was not detected")
    assert(not shiny.externalActive(battle.player.mon),
      "Kanto-only external visuals incorrectly suppressed Johto effects")
  else
    if mode == "kanto" then
      assert(not external,
        "standalone Kanto QA requires the external Crystal mod to be disabled")
    end
    assert(battle.enemy.__ascendantCrystalAnimation,
      "Ascendant bundled animation did not attach to the enemy")
  end
  if voxel then
    assert(battle.player.__ascendantCrystalAnimation,
      "voxel player did not receive Ascendant's front animation")
  else
    assert(not battle.player.__ascendantCrystalAnimation,
      "ordinary 2D player back must remain the authentic static back sprite")
  end

  local state = mode == "mixed" and battle.enemy.__crystalAnimation
    or battle.enemy.__ascendantCrystalAnimation
  local firstFrame = assert(state.frame, "animation frame is unavailable")
  assert(U.shot(game, ("%s/%s_frame_a.png"):format(DIR, mode)))
  for _ = 1, 240 do
    U.wait(1)
    if state.frame ~= firstFrame then break end
  end
  assert(state.frame ~= firstFrame, "animation did not advance")
  assert(U.shot(game, ("%s/%s_frame_b.png"):format(DIR, mode)))
  U.log(mode, "Crystal animation advanced", firstFrame, "->", state.frame)
end
