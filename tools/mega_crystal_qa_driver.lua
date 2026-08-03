-- Real-LOVE QA for Mega sprite ownership with bundled/external Crystal art.
--
-- MEGA_QA_FORM=x|y chooses Mega Raichu X or Y. The same driver is run once
-- with Kanto Ascendant alone and once with Crystal Animated Sprites loaded.

return function(game)
  local U = dofile("tests/drivers/util.lua")
  local DIR = os.getenv("SHOT_DIR") or "/tmp/kanto-ascendant-mega-qa"
  local form = (os.getenv("MEGA_QA_FORM") or "x"):lower()
  local Pokemon = require("src.pokemon.Pokemon")
  local Sprites = require("src.pokemon.Sprites")
  local BattleState = require("src.battle.BattleState")
  local Pipelines = require("src.render.Pipelines")

  U.wait(20)
  local api = assert(game.mods and game.mods.exports
    and game.mods.exports.trainer_rematch, "Kanto Ascendant export missing")
  local mega = assert(api.megaEvolution, "Mega controller missing")
  assert(form == "x" or form == "y", "MEGA_QA_FORM must be x or y")
  local profileId = form == "y" and "RAICHU_Y" or "RAICHU_X"
  local stone = form == "y" and "RAICHUNITE_Y" or "RAICHUNITE_X"
  local asset = form == "y" and "mega_raichu_y" or "mega_raichu_x"

  Pipelines.setLevel("voxel", 0)
  Pipelines.syncOptions(game.save.options)
  local dramatic = game.mods.exports.DRAMATIC_SHAPE
  if dramatic and dramatic.lib then
    local overworldBattle = dramatic.lib.require("OverworldBattle")
    overworldBattle.setting:setIndex(2, game)
    overworldBattle.backSetting:setIndex(1, game)
  end

  game.save.flags = game.save.flags or {}
  game.save.flags.EVENT_BEAT_CHAMPION_RIVAL = true
  game.save.hallOfFame = { {} }
  game.save.pokedex = game.save.pokedex or { seen = {}, owned = {} }
  mega.unlock(game)
  local megaState = mega.state()
  megaState.stones[stone] = true
  megaState.preferences.RAICHU = profileId

  local lead = Pokemon.new(game.data, "RAICHU", 50, function() return 10 end)
  game.save.party = { lead }
  U.teleport(game, "ROUTE_1", 5, 5, "down")
  local battle = BattleState.newWild(game, "BULBASAUR", 35)
  battle.onFinish = function() end
  game.overworld:pushBattle(battle)

  U.wait(120)
  for _ = 1, 60 do
    if battle.phase == "menu" and not battle.showPlayerBack then break end
    U.tap(game, "a")
    U.wait(8)
  end
  assert(battle.phase == "menu", "battle did not reach the command menu")
  local ok, reason = mega.activate(battle, battle.player, "player")
  assert(ok, "Mega activation failed: " .. tostring(reason))
  for _ = 1, 18 do U.tap(game, "a"); U.wait(12) end
  U.wait(45)

  assert(lead._ascMegaForm == profileId,
    "live Pokémon did not enter " .. profileId)
  assert(battle.player._ascMegaForm == profileId,
    "live battler did not enter " .. profileId)
  local front = Sprites.path(game.data, "RAICHU", "front", {
    mon = lead, kind = "battle",
  })
  local back = Sprites.path(game.data, "RAICHU", "back", {
    mon = lead, kind = "battle",
  })
  assert(front and front:find(
      "assets/mega/" .. asset .. "_front.png", 1, true),
    "Mega front lost to Crystal sprite ownership: " .. tostring(front))
  assert(back and back:find(
      "assets/mega/" .. asset .. "_back.png", 1, true),
    "Mega back lost to Crystal sprite ownership: " .. tostring(back))
  assert(not battle.player.__ascendantCrystalAnimation,
    "base Crystal animation kept running after Mega Evolution")
  assert(not battle.player.__crystalAnimation,
    "external Crystal animation kept running after Mega Evolution")
  assert(U.shot(game, ("%s/mega_raichu_%s.png"):format(DIR, form)))
  U.log("Mega Raichu " .. form:upper(), "front/back sprite ownership PASS")
end
