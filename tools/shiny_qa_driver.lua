-- Scripted visual QA for POKEPORT_DRIVER. It mutates only the temporary
-- in-memory game created for the driver and exits without writing a save.

return function(game)
  local U = dofile("tests/drivers/util.lua")
  local DIR = os.getenv("SHOT_DIR") or "/tmp/kanto-ascendant-shiny-qa"
  local Pokemon = require("src.pokemon.Pokemon")
  local Stats = require("src.pokemon.Stats")
  local Pipelines = require("src.render.Pipelines")
  local BattleState = require("src.battle.BattleState")

  U.wait(15)
  local api = assert(game.mods and game.mods.exports
    and game.mods.exports.trainer_rematch, "Kanto Ascendant export missing")
  local shiny = assert(api.shinySystem, "shiny controller missing")

  game.save.pokedex = game.save.pokedex or { seen = {}, owned = {} }
  game.save.flags = game.save.flags or {}
  game.save.flags.EVENT_BEAT_CHAMPION_RIVAL = true
  local followerApi = game.mods.exports.PokePCFollowers_VoxelMerge
  assert(followerApi and followerApi.select, "follower API missing")

  local function captureFollower(mon, isShiny, stem)
    game.save.party = { mon }
    game.save.pokedex.seen[mon.species] = true
    game.save.pokedex.owned[mon.species] = true
    local followerPath = assert(
      api.spriteAssets.follower(mon.species, isShiny),
      stem .. " follower sheet missing")
    if isShiny then
      assert(followerPath:find("/shiny/", 1, true),
        "shiny follower did not select its shiny cache variant")
    else
      assert(not followerPath:find("/shiny/", 1, true),
        "normal follower selected a shiny cache variant")
    end
    U.log(stem .. " follower:", followerPath)

    Pipelines.setLevel("voxel", 0)
    Pipelines.syncOptions(game.save.options)
    U.teleport(game, "ROUTE_1", 5, 5, "down")
    assert(followerApi.select(mon, game, true), "could not select " .. stem)
    U.wait(45)
    assert(U.shot(game, DIR .. "/" .. stem .. "_follower_2d.png"))

    Pipelines.setLevel("voxel", 1)
    Pipelines.syncOptions(game.save.options)
    if followerApi.sync then followerApi.sync(game, game.overworld) end
    U.wait(90)
    assert(U.shot(game, DIR .. "/" .. stem .. "_follower_voxel.png"))
  end

  local totodile = Pokemon.new(game.data, "TOTODILE", 25,
    function() return 8 end)
  captureFollower(totodile, false, "totodile")

  local lead = Pokemon.new(game.data, "FERALIGATR", 50,
    function() return 8 end)
  assert(shiny.forceMon(lead, game.data.pokemon.FERALIGATR))
  captureFollower(lead, true, "shiny_feraligatr")

  local battle = BattleState.newWild(game, "SUICUNE", 50)
  assert(shiny.forceMon(battle.enemy.mon, game.data.pokemon.SUICUNE))
  battle.enemy = BattleState.makeBattler(
    game.data, battle.enemy.mon, false, game.save)
  assert(Stats.isShiny(battle.enemy.mon.dvs),
    "forced Suicune does not carry canonical shiny DVs")
  battle.onFinish = function() end
  game.overworld:pushBattle(battle)
  -- Let the wipe and camera settle before pressing through each intro page;
  -- otherwise the taps land while input is intentionally locked.
  U.wait(180)
  for _ = 1, 24 do U.tap(game, "a"); U.wait(12) end
  U.wait(120)
  assert(U.shot(game, DIR .. "/shiny_suicune_voxel_battle.png"))
end
