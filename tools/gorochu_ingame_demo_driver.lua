-- Interactive, disposable in-game presentation for the 6.5 Gorochu assets.
-- The driver deliberately stays alive after setup so the real battle remains
-- visible and controllable until the tester closes the game window.

return function(game)
  local U = dofile("tests/drivers/util.lua")
  local BattleState = require("src.battle.BattleState")
  local PaletteFX = require("src.render.PaletteFX")
  local Pipelines = require("src.render.Pipelines")
  local Pokemon = require("src.pokemon.Pokemon")
  local voxel = os.getenv("GOROCHU_DEMO_VOXEL") == "1"

  U.wait(20)
  local ascendant = assert(game.mods and game.mods.exports
      and game.mods.exports.kanto_ascendant,
    "Kanto Ascendant export missing")
  assert(ascendant.gorochu and ascendant.gorochu.available,
    "Gorochu species is not available")
  assert(game.data.pokemon and game.data.pokemon.GOROCHU,
    "Gorochu species data is missing")

  game.save.options = game.save.options or {}
  game.save.options.modOptions = game.save.options.modOptions or {}
  game.save.options.modOptions.kanto_ascendant =
    game.save.options.modOptions.kanto_ascendant or {}
  game.mods.modOptions.kanto_ascendant =
    game.mods.modOptions.kanto_ascendant or {}

  local function setOption(key, value)
    game.mods.modOptions.kanto_ascendant[key] = value
    game.save.options.modOptions.kanto_ascendant[key] = value
    if game.mods.events then
      game.mods.events:emit("mod.options_changed", {
        mod = "kanto_ascendant", key = key, value = value,
      })
    end
  end

  -- The same driver can prove either the self-contained Crystal path or the
  -- supported Voxel companion path without changing the player's options.
  setOption("pokemon_sprite_style", "crystal")
  setOption("sprite_style_battle", true)
  setOption("crystal_animation", true)
  game.save.options.colors = "redpp"
  PaletteFX.setMode("redpp")
  Pipelines.setLevel("voxel", voxel and 1 or 0)
  Pipelines.syncOptions(game.save.options)
  local dramatic, overworldBattle
  if voxel then
    dramatic = game.mods.exports.DRAMALESS_SHAPE
      or game.mods.exports.DRAMATIC_SHAPE
    assert(dramatic and dramatic.lib and dramatic.lib.require,
      "supported Voxel renderer is not loaded")
    overworldBattle = assert(dramatic.lib.require("OverworldBattle"),
      "Voxel battle renderer is unavailable")
    overworldBattle.setting:setIndex(1, game)
    -- Both combatants face the camera so normal and shiny use the authored
    -- high-resolution front sequence together in one real battle.
    overworldBattle.backSetting:setIndex(1, game)
  end

  game.save.player = game.save.player or {}
  game.save.player.name = "GORO DEMO"
  game.save.player.id = 6500
  game.save.flags = game.save.flags or {}
  game.save.flags.EVENT_GOT_STARTER = true
  game.save.inventory = game.save.inventory or {}
  game.save.boxes = game.save.boxes or {}
  game.save.pokedex = game.save.pokedex or { seen = {}, owned = {} }
  game.save.pokedex.seen = game.save.pokedex.seen or {}
  game.save.pokedex.owned = game.save.pokedex.owned or {}

  local playerGorochu = Pokemon.new(game.data, "GOROCHU", 61,
    function() return 9 end)
  BattleState.stampOT(game.save, playerGorochu)
  playerGorochu.hp = playerGorochu.stats.hp
  game.save.party = { playerGorochu }

  U.teleport(game, "ROUTE_1", 5, 5, "down")
  local battle = BattleState.newWild(game, "GOROCHU", 61)
  local shinySystem = assert(ascendant.shinySystem,
    "Kanto Ascendant shiny controller missing")
  assert(shinySystem.forceMon(
    battle.enemy.mon, game.data.pokemon.GOROCHU),
    "could not make the opponent Gorochu shiny")
  battle.enemy = BattleState.makeBattler(
    game.data, battle.enemy.mon, false, game.save)
  battle.onFinish = function() end
  game.overworld:pushBattle(battle)

  -- Advance only when the typewriter is explicitly waiting for a button.
  -- Blindly mashing A can leave one queued press behind and immediately pick
  -- a battle command on the first menu frame, which is the opposite of a
  -- stable visual demo.
  for _ = 1, 900 do
    if battle.phase == "menu" then break end
    if battle.msgWaiting or battle.msgPrompt then
      U.tap(game, "a")
    else
      U.wait(1)
    end
  end
  assert(battle.phase == "menu",
    "Gorochu battle did not reach the action menu")
  assert(game.stack:top() == battle,
    "Gorochu battle is not the visible game state")
  game.input.pressQueue = {}
  for key in pairs(game.input.state) do
    game.input.state[key] = false
  end

  if love.window and love.window.setTitle then
    love.window.setTitle(voxel
      and "Kanto Ascendant 6.5 - Gorochu Voxel Demo"
      or "Kanto Ascendant 6.5 - Gorochu Crystal Demo")
  end
  U.log("READY Gorochu", voxel and "Voxel" or "Crystal",
    "battle demo; mod path", game.mods.mods.kanto_ascendant.path,
    "close the window to end")
  local shotDir = os.getenv("SHOT_DIR")
  if shotDir then
    assert(U.shot(game, shotDir .. (voxel
      and "/gorochu_voxel_ingame.png"
      or "/gorochu_crystal_ingame.png")),
      "in-game demo screenshot failed")
  end

  -- Optional bounded release receipt.  A still image cannot prove an
  -- animation; record a second real frame only after both the Crystal clock
  -- and DRAMALESS' high-resolution source have advanced.
  if os.getenv("GOROCHU_QA_EXIT") == "1" then
    local playerAnimation = assert(battle.player.__ascendantCrystalAnimation,
      "player Gorochu animation did not attach")
    local enemyAnimation = assert(battle.enemy.__ascendantCrystalAnimation,
      "enemy Gorochu animation did not attach")
    local firstPlayerFrame, firstEnemyFrame =
      playerAnimation.frame, enemyAnimation.frame
    local firstPlayerSource, firstEnemySource
    if voxel then
      local first = assert(overworldBattle.textures(battle),
        "Voxel Gorochu textures missing")
      firstPlayerSource = first.player.kantoAscendantGorochuSource
      firstEnemySource = first.enemy.kantoAscendantGorochuSource
      assert(firstPlayerSource and firstEnemySource,
        "Voxel Gorochu used a static/fallback source")
      assert(first.player.kantoAscendantGorochuAssetLane
          == "crystal-primary"
          and first.enemy.kantoAscendantGorochuAssetLane
            == "crystal-primary",
        "Voxel Gorochu did not select the complete Crystal-primary family")
      assert(firstPlayerSource:find(
          "assets/voxel/gorochu/crystal/normal/", 1, true)
          and firstEnemySource:find(
            "assets/voxel/gorochu/crystal/shiny/", 1, true),
        "Voxel Gorochu resolved an unexpected primary source")
      assert(first.player.kantoAscendantGorochuFallbackReason == nil
          and first.enemy.kantoAscendantGorochuFallbackReason == nil,
        "healthy Crystal-primary unexpectedly reported a fallback")
    end
    for _ = 1, 360 do
      U.wait(1)
      if playerAnimation.frame ~= firstPlayerFrame
          and enemyAnimation.frame ~= firstEnemyFrame then break end
    end
    assert(playerAnimation.frame ~= firstPlayerFrame
        and enemyAnimation.frame ~= firstEnemyFrame,
      "Gorochu battle animation clocks did not advance")
    if voxel then
      local second = assert(overworldBattle.textures(battle),
        "advanced Voxel Gorochu textures missing")
      assert(second.player.kantoAscendantGorochuSource ~= firstPlayerSource
          and second.enemy.kantoAscendantGorochuSource ~= firstEnemySource,
        "DRAMALESS kept a static Gorochu source after animation advance")
      assert(second.player.kantoAscendantGorochuAssetLane
          == "crystal-primary"
          and second.enemy.kantoAscendantGorochuAssetLane
            == "crystal-primary",
        "Voxel animation switched away from the Crystal-primary family")
    end
    if shotDir then
      assert(U.shot(game, shotDir .. (voxel
        and "/gorochu_voxel_ingame_advanced.png"
        or "/gorochu_crystal_ingame_advanced.png")),
        "advanced Gorochu screenshot failed")
      local result = assert(io.open(shotDir .. "/driver_result.txt", "wb"))
      result:write(("PASS renderer=%s lane=%s player=%d->%d enemy=%d->%d\n")
        :format(voxel and "FULL" or "2D",
          voxel and "crystal-primary" or "crystal-2d",
          firstPlayerFrame, playerAnimation.frame,
          firstEnemyFrame, enemyAnimation.frame))
      result:close()
    end
    love.event.quit(0)
    return
  end

  -- Keep the scripted session alive but yield every frame. Normal game input
  -- and animation updates continue through Game:update below this coroutine.
  while true do
    coroutine.yield()
  end
end
