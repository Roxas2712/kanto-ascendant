-- Scripted visual QA for POKEPORT_DRIVER. It mutates only the temporary
-- in-memory game created for the driver and exits without writing a save.

return function(game)
  local U = dofile("tests/drivers/util.lua")
  local DIR = os.getenv("SHOT_DIR") or "/tmp/kanto-ascendant-shiny-qa"
  local Pokemon = require("src.pokemon.Pokemon")
  local Stats = require("src.pokemon.Stats")
  local Pipelines = require("src.render.Pipelines")
  local BattleState = require("src.battle.BattleState")
  local PikachuFollower = require("src.world.PikachuFollower")

  U.wait(15)
  local api = assert(game.mods and game.mods.exports
    and game.mods.exports.trainer_rematch, "Kanto Ascendant export missing")
  local shiny = assert(api.shinySystem, "shiny controller missing")

  game.save.pokedex = game.save.pokedex or { seen = {}, owned = {} }
  game.save.flags = game.save.flags or {}
  game.save.flags.EVENT_BEAT_CHAMPION_RIVAL = true
  local followerApi = game.mods.exports.PokePCFollowers_VoxelMerge
  assert(followerApi and followerApi.select and followerApi.activeMon,
    "follower API missing")

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

    local function assertLiveFollower(stage)
      local active = assert(followerApi.activeMon(game),
        stage .. " PokéPC selection has no active follower")
      assert(active == mon and active.species == mon.species,
        stage .. " PokéPC selected " .. tostring(active.species)
          .. " instead of " .. tostring(mon.species))

      local def = assert(game.data.sprites
          and game.data.sprites.SPRITE_PIKACHU,
        stage .. " live follower sprite definition is missing")
      assert(def.image == followerPath,
        stage .. " live follower sheet differs from Ascendant's bundled art: "
          .. tostring(def.image) .. " ~= " .. tostring(followerPath))
      assert(def.image:find(
          "/follower_" .. mon.species .. ".png", 1, true),
        stage .. " live follower silently changed species: "
          .. tostring(def.image))
      assert(not def.image:find("/follower_BLASTOISE.png", 1, true),
        stage .. " live follower silently used the Blastoise proxy")

      local npc = assert(PikachuFollower.current(game.overworld),
        stage .. " visible follower NPC is missing")
      assert(npc.sprite and npc._pokepcFollowerSpecies == mon.species,
        stage .. " visible follower was not rebuilt as " .. mon.species
          .. ": " .. tostring(npc._pokepcFollowerSpecies))
    end

    Pipelines.setLevel("voxel", 0)
    Pipelines.syncOptions(game.save.options)
    -- (5,8) is a verified open Route 1 staging cell for both the ordinary
    -- overworld and Dramatic Shape. The old (5,5) cell made Voxel QA fall
    -- back to the 2D battle renderer before the follower assertions ran.
    U.teleport(game, "ROUTE_1", 5, 8, "down")
    assert(followerApi.select(mon, game, true), "could not select " .. stem)
    U.wait(45)
    assertLiveFollower("2D " .. stem)
    assert(U.shot(game, DIR .. "/" .. stem .. "_follower_2d.png"))

    Pipelines.setLevel("voxel", 1)
    Pipelines.syncOptions(game.save.options)
    if followerApi.sync then followerApi.sync(game, game.overworld) end
    U.wait(90)
    assertLiveFollower("Voxel " .. stem)
    assert(U.shot(game, DIR .. "/" .. stem .. "_follower_voxel.png"))
  end

  local totodile = Pokemon.new(game.data, "TOTODILE", 25,
    function() return 8 end)
  captureFollower(totodile, false, "totodile")

  local normalFeraligatr = Pokemon.new(game.data, "FERALIGATR", 50,
    function() return 8 end)
  captureFollower(normalFeraligatr, false, "feraligatr")

  local lead = Pokemon.new(game.data, "FERALIGATR", 50,
    function() return 10 end)
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
