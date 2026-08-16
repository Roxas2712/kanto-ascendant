-- Live renderer acceptance for the complete optional CRYSTAL CHARS family.

return function(game)
  local U = dofile("tests/drivers/util.lua")
  local Screens = require("src.ui.Screens")
  local Pokemon = require("src.pokemon.Pokemon")
  local BattleState = require("src.battle.BattleState")
  local Pipelines = require("src.render.Pipelines")
  local Runtime = require("src.mods.Runtime")
  local dir = assert(os.getenv("SHOT_DIR"), "SHOT_DIR is required")
  local ascendant = assert(game.mods and game.mods.exports
    and game.mods.exports.kanto_ascendant)
  local characters = assert(ascendant.extendedCharacters)
  local pass, fail = 0, 0

  local function check(label, value)
    if value then pass = pass + 1 else fail = fail + 1 end
    U.log(value and "PASS" or "FAIL", label)
  end

  local function clearStack()
    while game.stack:top() do game.stack:pop() end
  end

  U.wait(20)
  Pipelines.setLevel("voxel", 0)
  Pipelines.syncOptions(game.save.options)
  local dramatic = game.mods.exports.DRAMALESS_SHAPE
    or game.mods.exports.DRAMATIC_SHAPE
  local overworldBattle = dramatic and dramatic.lib
    and dramatic.lib.require("OverworldBattle")
  if overworldBattle and overworldBattle.setting then
    overworldBattle.setting:setIndex(5, game) -- OFF: prove native 2D backs
  end
  check("2D overworld pipeline is forced for flat acceptance",
    Pipelines.level("voxel") == 0)
  game.save.options = game.save.options or {}
  game.save.options.modOptions = game.save.options.modOptions or {}
  game.mods.modOptions.kanto_ascendant =
    game.mods.modOptions.kanto_ascendant or {}
  local options = game.mods.modOptions.kanto_ascendant
  options.character_sprite_style = "crystal"
  game.save.options.modOptions.kanto_ascendant = options
  Runtime.emit("mod.options_changed", {
    game = game, mod = "kanto_ascendant",
    key = "character_sprite_style", value = "crystal",
  })
  check("CRYSTAL CHARS option is live", characters.characterStyle() == "crystal")

  clearStack()
  Screens.push(game, "JohtoAscendantDisplayOptions")
  U.wait(8)
  check("display menu exposes CRYSTAL CHARS",
    U.shot(game, dir .. "/00_crystal_chars_option.png"))

  local cases = {
    { id = "RED", rival = "BLUE", party = 1, mon = "CHARMANDER", tag = "red" },
    { id = "GREEN", rival = "RED", party = 3, mon = "BULBASAUR", tag = "casey" },
    { id = "BLUE", rival = "GREEN", party = 2, mon = "SQUIRTLE", tag = "blue" },
  }

  for _, case in ipairs(cases) do
    U.teleport(game, "ROUTE_1", 5, 5, "down")
    characters.select(case.id)
    characters.refreshVisuals(game)
    game.save.player.name = case.id == "GREEN" and "CASEY" or case.id
    game.save.player.rival = case.rival
    local player = game.overworld.player

    check(case.id .. " walking renderer is native 16x16",
      player.sprite and player.sprite.def
        and player.sprite.def.frameWidth == nil
        and player.sprite.def.frameHeight == nil)
    U.wait(6)
    check(case.id .. " overworld screenshot",
      U.shot(game, dir .. "/10_" .. case.tag .. "_walk.png"))

    player.onBike = true
    player.facing = "left"
    player.animClock = 0
    U.wait(6)
    check(case.id .. " bicycle renderer is native 16x16",
      player.bikeSprite and player.bikeSprite.def
        and player.bikeSprite.def.frameWidth == nil
        and player.bikeSprite.def.frameHeight == nil)
    check(case.id .. " bicycle screenshot",
      U.shot(game, dir .. "/11_" .. case.tag .. "_bike.png"))

    player.onBike = false
    player.fishing = true
    player.facing = "left"
    game.overworld.fishing = { facing = "left" }
    U.wait(6)
    check(case.id .. " fishing renderer is native 16x16",
      player.fishingSprite and player.fishingSprite.def
        and player.fishingSprite.def.frameWidth == nil
        and player.fishingSprite.def.frameHeight == nil)
    check(case.id .. " fishing screenshot",
      U.shot(game, dir .. "/12_" .. case.tag .. "_fish.png"))
    player.fishing = nil
    game.overworld.fishing = nil

    game.save.party = { Pokemon.new(game.data, case.mon, 15) }
    local back = characters.getPlayerSprite("battleBack")
    local front = characters.getRivalSprite("rivalPortrait")
    check(case.id .. " battle back belongs to Crystal family",
      back and back.path:find("/crystal_chars/", 1, true) ~= nil)
    check(case.rival .. " rival front belongs to Crystal family",
      front and front.path:find("/crystal_chars/", 1, true) ~= nil)
    local battle = BattleState.newTrainer(game, "OPP_RIVAL1", case.party)
    game.overworld:pushBattle(battle)
    local ready = false
    for _ = 1, 480 do
      if battle.showEnemyTrainer and battle.showPlayerBack
          and game.stack:top() == battle then
        ready = true
        break
      end
      U.wait(1)
    end
    check(case.id .. " reaches two-trainer battle intro", ready)
    if ready then
      local width, height = battle.playerBackPic:getDimensions()
      check(case.id .. " battle back is native 64x64",
        width == 64 and height == 64)
      local frontWidth, frontHeight = battle.trainerPic:getDimensions()
      check(case.rival .. " rival front is high-detail 64x64",
        frontWidth == 64 and frontHeight == 64)
    end
    U.wait(45)
    check(case.id .. " battle front/back screenshot",
      U.shot(game, dir .. "/13_" .. case.tag .. "_battle.png"))

    local throwPics = battle.playerBackThrowPics or {}
    check(case.id .. " owns five native trainer throw poses", #throwPics == 5)
    local captured, captureCount = {}, 0
    for tick = 1, 1200 do
      for index, pic in ipairs(throwPics) do
        if battle.playerBackPic == pic and not captured[index] then
          captured[index] = U.shot(game,
            dir .. ("/14_%s_throw_%d.png"):format(case.tag, index))
          if captured[index] then captureCount = captureCount + 1 end
        end
      end
      if captureCount == 5 then break end
      if tick % 4 == 0 then U.tap(game, "a") else U.wait(1) end
    end
    check(case.id .. " renders all five throw frames", captureCount == 5)
    clearStack()
    U.wait(5)
  end

  U.log(("CRYSTAL CHARS LIVE RESULT pass=%d fail=%d"):format(pass, fail))
  love.event.quit(fail == 0 and 0 or 1)
end
