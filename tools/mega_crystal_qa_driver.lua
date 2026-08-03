-- Real-LOVE QA for Mega sprite ownership with bundled/external Crystal art.
--
-- MEGA_QA_FORM=x|y|charizard-x chooses the visible form; MEGA_QA_SHINY=1
-- selects its shiny palette. The same driver is run with Kanto Ascendant
-- alone and with Crystal Animated Sprites loaded.

return function(game)
  local U = dofile("tests/drivers/util.lua")
  local DIR = os.getenv("SHOT_DIR") or "/tmp/kanto-ascendant-mega-qa"
  local form = (os.getenv("MEGA_QA_FORM") or "x"):lower()
  local forcedShiny = os.getenv("MEGA_QA_SHINY") == "1"
  local Pokemon = require("src.pokemon.Pokemon")
  local Sprites = require("src.pokemon.Sprites")
  local BattleState = require("src.battle.BattleState")
  local Pipelines = require("src.render.Pipelines")

  U.wait(20)
  local api = assert(game.mods and game.mods.exports
    and game.mods.exports.trainer_rematch, "Kanto Ascendant export missing")
  local mega = assert(api.megaEvolution, "Mega controller missing")
  assert(form == "x" or form == "y" or form == "charizard-x",
    "MEGA_QA_FORM must be x, y or charizard-x")
  local charizard = form == "charizard-x"
  local species = charizard and "CHARIZARD" or "RAICHU"
  local profileId = charizard and "CHARIZARD_X"
    or (form == "y" and "RAICHU_Y" or "RAICHU_X")
  local stone = charizard and "CHARIZARDITE_X"
    or (form == "y" and "RAICHUNITE_Y" or "RAICHUNITE_X")
  local asset = charizard and "mega_charizard_x"
    or (form == "y" and "mega_raichu_y" or "mega_raichu_x")

  Pipelines.setLevel("voxel", charizard and 1 or 0)
  Pipelines.syncOptions(game.save.options)
  local dramatic = game.mods.exports.DRAMATIC_SHAPE
  if dramatic and dramatic.lib then
    local overworldBattle = dramatic.lib.require("OverworldBattle")
    overworldBattle.setting:setIndex(charizard and 1 or 2, game)
    overworldBattle.backSetting:setIndex(1, game)
  end

  game.save.flags = game.save.flags or {}
  game.save.flags.EVENT_BEAT_CHAMPION_RIVAL = true
  game.save.hallOfFame = { {} }
  game.save.pokedex = game.save.pokedex or { seen = {}, owned = {} }
  mega.unlock(game)
  local megaState = mega.state()
  megaState.stones[stone] = true
  megaState.preferences[species] = profileId

  local lead = Pokemon.new(game.data, species, 50,
    function() return forcedShiny and 10 or 8 end)
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
  local front = Sprites.path(game.data, species, "front", {
    mon = lead, kind = "battle",
  })
  local back = Sprites.path(game.data, species, "back", {
    mon = lead, kind = "battle",
  })
  local suffix = forcedShiny and "_shiny" or ""
  assert(front and front:find(
      "assets/mega/" .. asset .. "_front" .. suffix .. ".png", 1, true),
    "Mega front lost to Crystal sprite ownership: " .. tostring(front))
  assert(back and back:find(
      "assets/mega/" .. asset .. "_back" .. suffix .. ".png", 1, true),
    "Mega back lost to Crystal sprite ownership: " .. tostring(back))
  assert(not battle.player.__ascendantCrystalAnimation,
    "base Crystal animation kept running after Mega Evolution")
  assert(not battle.player.__crystalAnimation,
    "external Crystal animation kept running after Mega Evolution")
  if charizard then
    local animation = assert(battle.player.__ascendantMegaAnimation,
      "Mega Charizard X front animation did not attach in Voxel")
    local first = animation.frame
    for _ = 1, 120 do
      U.wait(1)
      if animation.frame ~= first then break end
    end
    assert(animation.frame ~= first,
      "Mega Charizard X front animation did not advance")
  end
  local label = charizard and "mega_charizard_x"
    or ("mega_raichu_" .. form)
  if forcedShiny then label = label .. "_shiny" end
  assert(U.shot(game, ("%s/%s.png"):format(DIR, label)))
  U.log(label, "front/back sprite ownership PASS")
end
