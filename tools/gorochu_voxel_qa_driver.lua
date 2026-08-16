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
  local ascendant = assert(exports.kanto_ascendant,
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
  local followerImage = assert(follower.sprite and follower.sprite.image,
    "live Gorochu follower renderer has no image")
  local followerWidth, followerHeight = followerImage:getDimensions()
  assert(followerWidth == 16 and followerHeight == 96,
    ("unexpected Gorochu follower sheet size: %sx%s")
      :format(tostring(followerWidth), tostring(followerHeight)))
  assert(follower.sprite and follower._pokepcFollowerSpecies == "GOROCHU",
    "visible Voxel follower was not rebuilt as Gorochu")

  -- Exercise all six authored follower frames in the real renderer. The
  -- contact sheet is assembled from these captures after the run, while the
  -- assertions below prove the live wrapper selected the new sheet rather
  -- than a Raichu/Pikachu fallback.
  local followerPoses = {
    { "stand_down", "down", 0 },
    { "stand_up", "up", 0 },
    { "stand_left", "left", 0 },
    { "walk_down", "down", 1 },
    { "walk_up", "up", 1 },
    { "walk_left", "left", 1 },
  }
  -- Put the QA actor beside the player rather than directly behind them,
  -- where the tilted camera can hide both billboards on the same sightline.
  follower.cellX, follower.cellY =
    game.overworld.player.cellX + 2, game.overworld.player.cellY
  follower.px, follower.py = follower.cellX * 16, follower.cellY * 16
  for _, pose in ipairs(followerPoses) do
    follower.facing = pose[2]
    follower.idle = pose[3] == 1
      and { kind = "walk", frames = 0x30, tick = 0, phase = 1 }
      or nil
    U.wait(2)
    assert(U.shot(game,
      shotDir .. "/gorochu_follower_" .. pose[1] .. "_voxel.png"),
      "Voxel follower screenshot failed for " .. pose[1])
  end
  follower.idle = nil

  local shinyFollowerMon = Pokemon.new(game.data, "GOROCHU", 61,
    function() return 10 end)
  shinyFollowerMon.hp = shinyFollowerMon.stats.hp
  assert(shiny.forceMon(
    shinyFollowerMon, game.data.pokemon.GOROCHU),
    "could not force the follower Gorochu shiny")
  game.save.party = { shinyFollowerMon }
  assert(followers.select(shinyFollowerMon, game, true),
    "PokéPC Followers rejected shiny Gorochu")
  PikachuFollower.onMapEntered(game, game.overworld)
  U.wait(4)
  local shinyFollower = assert(PikachuFollower.current(game.overworld),
    "shiny Gorochu follower did not spawn")
  assert(followerDef.image and followerDef.image:find(
    "/assets/followers_runtime/shiny/follower_GOROCHU.png", 1, true),
    "PokéPC wrapper did not select Gorochu's shiny follower sheet: "
      .. tostring(followerDef.image))
  shinyFollower.cellX, shinyFollower.cellY =
    game.overworld.player.cellX + 2, game.overworld.player.cellY
  shinyFollower.px, shinyFollower.py =
    shinyFollower.cellX * 16, shinyFollower.cellY * 16
  shinyFollower.facing = "down"
  assert(U.shot(game,
    shotDir .. "/gorochu_follower_shiny_stand_down_voxel.png"),
    "shiny Voxel follower screenshot failed")
  game.save.party = { lead }
  assert(followers.select(lead, game, true),
    "PokéPC Followers did not restore normal Gorochu")

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
  assert(textures.player.kantoAscendantGorochuSupersampled == true,
    "player Gorochu did not use Ascendant's supersampled Voxel route")
  assert(textures.enemy.kantoAscendantGorochuSupersampled == true,
    "enemy Gorochu did not use Ascendant's supersampled Voxel route")
  local expectedNormalSource =
    ("assets/voxel/gorochu/animation/normal/%03d.png")
      :format(normalAnimation.frame)
  local expectedShinySource =
    ("assets/voxel/gorochu/animation/shiny/%03d.png")
      :format(shinyAnimation.frame)
  assert(textures.player.kantoAscendantGorochuSource
      == expectedNormalSource,
    "player Voxel Gorochu did not use the approved normal front master: "
      .. tostring(textures.player.kantoAscendantGorochuSource))
  assert(textures.enemy.kantoAscendantGorochuSource
      == expectedShinySource,
    "enemy Voxel Gorochu did not use the approved shiny front master: "
      .. tostring(textures.enemy.kantoAscendantGorochuSource))
  assert(not textures.player.kantoAscendantGorochuSource:find(
      "crystal", 1, true)
      and not textures.enemy.kantoAscendantGorochuSource:find(
        "crystal", 1, true),
    "Voxel Gorochu must never upscale a 56px Crystal battle frame")
  local playerWidth, playerHeight =
    textures.player.canvas:getDimensions()
  local enemyWidth, enemyHeight =
    textures.enemy.canvas:getDimensions()
  assert(playerWidth == 230 and playerHeight == 207,
    ("unexpected player billboard size: %sx%s")
      :format(tostring(playerWidth), tostring(playerHeight)))
  assert(enemyWidth == 230 and enemyHeight == 207,
    ("unexpected enemy billboard size: %sx%s")
      :format(tostring(enemyWidth), tostring(enemyHeight)))

  local normalFrame = normalAnimation.frame
  local shinyFrame = shinyAnimation.frame
  local playerVoxelFrame =
    textures.player.kantoAscendantGorochuAnimationFrame
  local enemyVoxelFrame =
    textures.enemy.kantoAscendantGorochuAnimationFrame
  for _ = 1, 240 do
    U.wait(1)
    if normalAnimation.frame ~= normalFrame
        and shinyAnimation.frame ~= shinyFrame then break end
  end
  assert(normalAnimation.frame ~= normalFrame,
    "normal Gorochu animation did not advance in Voxel")
  assert(shinyAnimation.frame ~= shinyFrame,
    "shiny Gorochu animation did not advance in Voxel")
  local animatedTextures = assert(overworldBattle.textures(battle),
    "Dramatic Shape did not rebuild animated Gorochu textures")
  assert(animatedTextures.player.kantoAscendantGorochuAnimationFrame
      ~= playerVoxelFrame,
    "normal high-resolution Voxel master ignored the animation clock")
  assert(animatedTextures.enemy.kantoAscendantGorochuAnimationFrame
      ~= enemyVoxelFrame,
    "shiny high-resolution Voxel master ignored the animation clock")
  assert(animatedTextures.player.kantoAscendantGorochuSource
      == ("assets/voxel/gorochu/animation/normal/%03d.png")
        :format(normalAnimation.frame),
    "normal Voxel renderer did not load the advanced authored frame")
  assert(animatedTextures.enemy.kantoAscendantGorochuSource
      == ("assets/voxel/gorochu/animation/shiny/%03d.png")
        :format(shinyAnimation.frame),
    "shiny Voxel renderer did not load the advanced authored frame")
  assert(U.shot(game,
    shotDir .. "/gorochu_battle_voxel_normal_vs_shiny.png"),
    "Voxel battle screenshot failed")

  U.log("PASS real Gorochu Voxel UAT",
    "Dramatic Shape 3D battle",
    "dedicated 96px normal+shiny camera-facing fronts",
    "both high-resolution animation clocks",
    "six-pose PokéPC Voxel follower")
  love.event.quit(0)
end
