-- Real-LOVE integration UAT for Gorochu with Dramatic Shape and
-- PokéPC Followers (Voxel Merge). This is intentionally separate from the
-- ordinary Gorochu quest UAT: it fails unless the actual external renderer
-- and follower wrapper are loaded.

return function(game)
  local U = dofile("tests/drivers/util.lua")
  local BattleState = require("src.battle.BattleState")
  local GameVersion = require("src.core.GameVersion")
  local PikachuFollower = require("src.world.PikachuFollower")
  local Pipelines = require("src.render.Pipelines")
  local Pokemon = require("src.pokemon.Pokemon")
  local Stats = require("src.pokemon.Stats")

  local shotDir = os.getenv("SHOT_DIR")
    or "/tmp/kanto-ascendant-gorochu-voxel-qa"
  assert(GameVersion.isYellow(),
    "Gorochu Voxel QA must run with POKEPORT_VERSION=yellow")
  U.wait(24)

  local exports = assert(game.mods and game.mods.exports,
    "mod exports are unavailable")
  local ascendant = assert(exports.trainer_rematch,
    "Kanto Ascendant export missing")
  local shiny = assert(ascendant.shinySystem,
    "Ascendant shiny controller missing")
  local dramatic = assert(exports.DRAMATIC_SHAPE,
    "real Dramatic Shape mod is not loaded")
  local followers = assert(exports.PokePCFollowers_VoxelMerge,
    "real PokéPC Followers Voxel Merge mod is not loaded")
  assert(followers.supported and type(followers.select) == "function",
    "PokéPC follower selection API is unavailable")
  local overworldBattle = assert(
    dramatic.lib and dramatic.lib.require("OverworldBattle"),
    "Dramatic Shape battle renderer is unavailable")

  Pipelines.setLevel("voxel", 1)
  Pipelines.syncOptions(game.save.options)
  overworldBattle.setting:setIndex(1, game)
  overworldBattle.backSetting:setIndex(1, game)
  assert(overworldBattle.enabled(),
    "Dramatic Shape staged battles did not enable")
  assert(not overworldBattle.backPinned(),
    "Voxel UAT must render both Pokémon as camera-facing fronts")

  game.save.player = game.save.player or {}
  game.save.player.name = "VOXEL UAT"
  game.save.player.id = 5401
  game.save.flags = game.save.flags or {}
  game.save.flags.EVENT_GOT_STARTER = true
  game.save.flags.EVENT_CHOSE_PIKACHU = true
  game.save.pokedex = game.save.pokedex or { seen = {}, owned = {} }

  local lead = Pokemon.new(game.data, "GOROCHU", 61,
    function() return 9 end)
  lead.hp = lead.stats.hp
  game.save.party = { lead }

  U.teleport(game, "ROUTE_1", 5, 5, "down")
  assert(followers.select(lead, game, true),
    "PokéPC Followers rejected Gorochu")
  PikachuFollower.onMapEntered(game, game.overworld)
  U.wait(90)
  local follower = assert(PikachuFollower.current(game.overworld),
    "Gorochu follower did not spawn in the Voxel overworld")
  local followerDef = assert(
    game.data.sprites and game.data.sprites.SPRITE_PIKACHU,
    "follower sprite definition is missing")
  assert(followerDef.image and followerDef.image:find(
    "/assets/followers_runtime/normal/follower_GOROCHU.png", 1, true),
    "PokéPC wrapper did not receive Ascendant's Gorochu follower sheet: "
      .. tostring(followerDef.image))
  assert(follower.sprite and follower._pokepcFollowerSpecies == "GOROCHU",
    "visible Voxel follower was not rebuilt as Gorochu")
  assert(U.shot(game, shotDir .. "/gorochu_follower_voxel.png"),
    "Voxel follower screenshot failed")

  -- One live battle covers both palettes at once: normal player Gorochu and
  -- shiny enemy Gorochu, both rendered as fronts by Dramatic Shape.
  local battle = BattleState.newWild(game, "GOROCHU", 61)
  assert(shiny.forceMon(battle.enemy.mon, game.data.pokemon.GOROCHU),
    "could not force the enemy Gorochu shiny")
  battle.enemy = BattleState.makeBattler(
    game.data, battle.enemy.mon, false, game.save)
  assert(Stats.isShiny(battle.enemy.mon.dvs),
    "enemy Gorochu is not shiny")
  battle.onFinish = function() end
  game.overworld:pushBattle(battle)
  U.wait(190)
  for _ = 1, 50 do
    if battle.phase == "menu" then break end
    U.tap(game, "a")
    U.wait(8)
  end
  assert(battle.phase == "menu",
    "Voxel Gorochu battle did not reach the action menu")
  U.wait(45)

  local normalAnimation = assert(
    battle.player.__ascendantCrystalAnimation,
    "Voxel player Gorochu animation did not attach")
  local shinyAnimation = assert(
    battle.enemy.__ascendantCrystalAnimation,
    "Voxel enemy Gorochu animation did not attach")
  assert(normalAnimation.dex == 1026
      and normalAnimation.side == "front"
      and normalAnimation.variant == "normal",
    "Voxel player did not select Gorochu's normal animated front")
  assert(shinyAnimation.dex == 1026
      and shinyAnimation.side == "front"
      and shinyAnimation.variant == "shiny",
    "Voxel enemy did not select Gorochu's shiny animated front")

  local textures = assert(overworldBattle.textures(battle),
    "Dramatic Shape did not build battle textures")
  assert(textures.player and textures.player.canvas,
    "Dramatic Shape dropped the player Gorochu texture")
  assert(textures.enemy and textures.enemy.canvas,
    "Dramatic Shape dropped the enemy Gorochu texture")
  local playerWidth, playerHeight =
    textures.player.canvas:getDimensions()
  local enemyWidth, enemyHeight =
    textures.enemy.canvas:getDimensions()
  assert(playerWidth == 160 and playerHeight == 144,
    ("unexpected player billboard size: %sx%s")
      :format(tostring(playerWidth), tostring(playerHeight)))
  assert(enemyWidth == 160 and enemyHeight == 144,
    ("unexpected enemy billboard size: %sx%s")
      :format(tostring(enemyWidth), tostring(enemyHeight)))

  local normalFrame = normalAnimation.frame
  local shinyFrame = shinyAnimation.frame
  for _ = 1, 240 do
    U.wait(1)
    if normalAnimation.frame ~= normalFrame
        and shinyAnimation.frame ~= shinyFrame then break end
  end
  assert(normalAnimation.frame ~= normalFrame,
    "normal Gorochu animation did not advance in Voxel")
  assert(shinyAnimation.frame ~= shinyFrame,
    "shiny Gorochu animation did not advance in Voxel")
  assert(U.shot(game,
    shotDir .. "/gorochu_battle_voxel_normal_vs_shiny.png"),
    "Voxel battle screenshot failed")

  U.log("PASS real Gorochu Voxel UAT",
    "Dramatic Shape 3D battle",
    "normal+shiny camera-facing fronts",
    "both live animations",
    "PokéPC Voxel follower")
  love.event.quit(0)
end
