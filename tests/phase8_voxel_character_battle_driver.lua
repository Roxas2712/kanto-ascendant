-- Real-renderer acceptance for Ascendant's Voxel character, HUD-gender and
-- 6.0.11 camera compatibility bridge.

return function(game)
  local U = dofile("tests/drivers/util.lua")
  local BattleState = require("src.battle.BattleState")
  local Pokemon = require("src.pokemon.Pokemon")
  local Pipelines = require("src.render.Pipelines")
  local Runtime = require("src.mods.Runtime")
  local dir = assert(os.getenv("SHOT_DIR"), "SHOT_DIR is required")
  local exports = assert(game.mods and game.mods.exports)
  local ascendant = assert(exports.kanto_ascendant)
  local characters = assert(ascendant.extendedCharacters)
  local gender = assert(ascendant.pokemonGender)
  local camera = assert(ascendant.dramalessCameraCompat)
  local cameraOption = assert(ascendant.dramalessCameraOption)
  local dramatic = assert(exports.DRAMALESS_SHAPE or exports.DRAMATIC_SHAPE)
  local overworldBattle = assert(dramatic.lib.require("OverworldBattle"))
  local battleCam = assert(dramatic.lib.require("BattleCam"))
  local pass, fail = 0, 0

  local function check(label, value)
    if value then pass = pass + 1 else fail = fail + 1 end
    U.log(value and "PASS" or "FAIL", label)
  end

  local function clearStack()
    while game.stack:top() do game.stack:pop() end
  end

  Pipelines.setLevel("voxel", 1)
  Pipelines.syncOptions(game.save.options)
  game.save.options = game.save.options or {}
  game.save.options.modOptions = game.save.options.modOptions or {}
  game.mods.modOptions.kanto_ascendant =
    game.mods.modOptions.kanto_ascendant or {}
  game.mods.modOptions.kanto_ascendant.character_sprite_style = "crystal"
  game.save.options.modOptions.kanto_ascendant =
    game.mods.modOptions.kanto_ascendant
  Runtime.emit("mod.options_changed", {
    game = game, mod = "kanto_ascendant",
    key = "character_sprite_style", value = "crystal",
  })
  overworldBattle.setting:setIndex(1, game)
  cameraOption.set("classic", game)
  camera.apply(game)
  local tele = battleCam.RIGS.tele
  check("6.0.11 Classic Voxel distance is active",
    math.abs(tele.back - camera.CLASSIC_TELE.back) < 0.001)
  check("6.0.11 Classic Voxel framing is active",
    math.abs(tele.frameH - camera.CLASSIC_TELE.frameH) < 0.001)

  local cases = {
    { player = "RED", rival = "BLUE", party = 1,
      playerMon = "CHARMANDER", tag = "30_red_voxel" },
    { player = "BLUE", rival = "GREEN", party = 2,
      playerMon = "SQUIRTLE", tag = "31_blue_voxel" },
    { player = "GREEN", rival = "RED", party = 3,
      playerMon = "BULBASAUR", tag = "32_casey_voxel" },
  }

  for _, case in ipairs(cases) do
    U.teleport(game, "ROUTE_1", 5, 5, "down")
    characters.select(case.player)
    characters.refreshVisuals(game)
    game.save.player.name = case.player == "GREEN" and "CASEY" or "BLUE"
    game.save.player.rival = case.rival
    local lead = Pokemon.new(game.data, case.playerMon, 15)
    lead.dvs.attack = 15 -- male on all three starter lines
    game.save.party = { lead }

    local resolved = Runtime.call("player.sprite",
      function(path) return path end, "vanilla-back.png",
      { side = "back", kind = "battle" })
    local expected = "assets/characters/crystal_chars/"
      .. case.player:lower() .. "_voxel_front.png"
    U.log(case.player .. " resolved Voxel trainer path", tostring(resolved))
    check(case.player .. " Voxel resolves standing 64x64 front",
      type(resolved) == "string" and resolved:sub(-#expected) == expected)

    local battle = BattleState.newTrainer(game, "OPP_RIVAL1", case.party)
    battle.enemy.mon.dvs.attack = 0 -- female where the species allows it
    game.overworld:pushBattle(battle)
    local introReady = false
    for _ = 1, 420 do
      if battle.showEnemyTrainer and battle.showPlayerBack
          and battle.dramaticShapeShot and game.stack:top() == battle then
        introReady = true
        break
      end
      U.wait(1)
    end
    check(case.player .. " reaches staged Voxel trainer intro", introReady)
    local w, h = battle.playerBackPic:getDimensions()
    check(case.player .. " live trainer card is 64x64", w == 64 and h == 64)
    local texture = overworldBattle.sideTexture(battle, "player")
    check(case.player .. " standing trainer is mirrored as front art",
      texture and texture.trainer == false
        and texture.ascendantStandingTrainer == case.player)
    local textureW, textureH = texture.canvas:getDimensions()
    check(case.player .. " trainer billboard keeps HD facial pixels",
      texture.ascendantHighResTrainer == true
        and textureW == 320 and textureH == 288)
    local expectedPlayerHD = "assets/characters/crystal_chars/"
      .. case.player:lower() .. "_voxel_front_hd.png"
    check(case.player .. " player uses only its authored Crystal HD source",
      texture.ascendantHighResSource == expectedPlayerHD)
    check(case.player .. " player head stays inside the HD card",
      texture.ay * 2 - 128 >= 4)
    local enemyTexture = overworldBattle.sideTexture(battle, "enemy")
    local enemyW, enemyH = enemyTexture.canvas:getDimensions()
    check(case.player .. " rival billboard keeps HD facial pixels",
      enemyTexture.ascendantHighResTrainer == true
        and enemyW == 320 and enemyH == 288)
    local expectedRivalHD = "assets/characters/crystal_chars/"
      .. case.rival:lower() .. "_voxel_front_hd.png"
    check(case.player .. " rival uses only its authored Crystal HD source",
      enemyTexture.ascendantHighResSource == expectedRivalHD)
    check(case.player .. " rival head stays inside the HD card",
      enemyTexture.ay * 2 - 128 >= 4)
    U.wait(60)
    check(case.player .. " Voxel trainer screenshot",
      U.shot(game, dir .. "/" .. case.tag .. "_trainer.png"))

    local menuReady = false
    for _ = 1, 900 do
      if game.stack:top() == battle and battle.phase == "menu"
          and not battle.showEnemyTrainer and not battle.showPlayerBack then
        menuReady = true
        break
      end
      if U.frame() % 5 == 0 then U.tap(game, "a") else U.wait(1) end
    end
    check(case.player .. " reaches Voxel command menu", menuReady)
    check(case.player .. " player gender remains derived",
      gender.symbol(battle.player.mon, game) == "♂")
    check(case.player .. " Voxel HUD gender screenshot",
      U.shot(game, dir .. "/" .. case.tag .. "_gender_hud.png"))
    clearStack()
    U.wait(5)
  end

  U.log(("PHASE8 VOXEL CHARACTER RESULT pass=%d fail=%d")
    :format(pass, fail))
  love.event.quit(fail == 0 and 0 or 1)
end
