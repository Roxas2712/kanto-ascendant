-- Renderer-backed proof for the direct, identity-hidden Ho-Oh vision.

return function(game)
  local U = dofile("tests/drivers/util.lua")
  local Pokemon = require("src.pokemon.Pokemon")
  local Pipelines = require("src.render.Pipelines")
  local dir = assert(os.getenv("SHOT_DIR"), "SHOT_DIR is required")
  local exports = assert(game.mods.exports.kanto_ascendant)
  local visions = assert(exports.visionEncounters)
  local pass, fail = 0, 0

  local function check(label, value)
    if value then pass = pass + 1 else fail = fail + 1 end
    U.log(value and "PASS" or "FAIL", label)
  end
  local function settlePage(battle)
    local found = false
    -- Dramaless reveals its cinematic text on the renderer's cadence rather
    -- than the driver's queue cadence. Give the real animation time to play,
    -- while proving the intended localized page is the active queue item.
    for _ = 1, 900 do
      if battle.current and battle.current.text then found = true end
      U.wait(1)
    end
    return found
  end
  local function advancePrompt(battle)
    local page = battle.current
    for _ = 1, 120 do
      -- Dramaless consumes input at the real render cadence. Repeat a short
      -- tap until this exact message page is gone instead of assuming that
      -- one synthetic frame was observed by both layers.
      U.tap(game, "a")
      if battle.current ~= page then return true end
      U.wait(1)
    end
    return false
  end

  while game.stack:top() and game.stack:top() ~= game.overworld do
    game.stack:pop()
  end
  local options = game.mods.modOptions.kanto_ascendant or {}
  game.mods.modOptions.kanto_ascendant = options
  options.pokemon_sprite_style = "crystal"
  options.crystal_animation = true
  options.sprite_style_battle = true
  game.save.options.modOptions = game.save.options.modOptions or {}
  game.save.options.modOptions.kanto_ascendant = options

  U.teleport(game, "ROUTE_2", 4, 48, "down")
  game.save.party = { Pokemon.new(game.data, "PIKACHU", 12) }
  local hp = game.save.party[1].hp
  game.save.pokedex.seen.HO_OH = nil

  local dramatic = game.mods.exports.DRAMALESS_SHAPE
    or game.mods.exports.DRAMATIC_SHAPE
  if dramatic then
    Pipelines.setLevel("voxel", 1)
    Pipelines.syncOptions(game.save.options)
    local overworldBattle = dramatic.lib.require("OverworldBattle")
    if overworldBattle and overworldBattle.setting then
      overworldBattle.setting:setIndex(1, game)
    end
  end

  check("Ho-Oh mystery vision starts", visions.start(game, visions.DEFS[1]))
  local battle = visions.active
  check("vision appears directly without BattleTransition",
    game.stack:top() == battle)
  check("identity and level are hidden",
    battle.enemy.name == "???" and battle.enemy.mon.level == "???")
  check("private encounter data stays available to the renderer",
    battle.visionRealSpecies == "HO_OH" and battle.visionRealLevel == 70)
  check("Ho-Oh remains unknown in the Pokedex",
    game.save.pokedex.seen.HO_OH ~= true)
  check("no player Pokemon or command menu can appear",
    battle.demo == true and battle.showPlayerBack == false
      and battle.phase == "messages" and battle.afterQueue == "finish")
  check("the one-off vision is gold",
    battle.enemy.__ascendantVisionGold == true)

  check("opening mystery page is active", settlePage(battle))
  check("mystery HUD screenshot",
    U.shot(game, dir .. "/01_hooh_unknown_hud.png"))
  check("opening prompt closes", advancePrompt(battle))
  check("strange-melody page is active",
    settlePage(battle))
  check("strange melody screenshot",
    U.shot(game, dir .. "/02_hooh_strange_melody.png"))
  check("melody prompt closes", advancePrompt(battle))
  check("vanishing page is active", settlePage(battle))
  check("Ho-Oh vanishes before the closing line", battle.enemyHidden == true)
  check("vision vanished screenshot",
    U.shot(game, dir .. "/03_hooh_vanished.png"))
  check("closing prompt closes", advancePrompt(battle))

  for _ = 1, 360 do
    if game.stack:top() == game.overworld then break end
    U.wait(1)
  end
  check("script returns directly to Route 2",
    game.stack:top() == game.overworld
      and game.overworld.map.id == "ROUTE_2"
      and game.overworld.player.cellX == 4
      and game.overworld.player.cellY == 48)
  check("script cannot damage the party", game.save.party[1].hp == hp)
  check("one-time vision state is complete and inactive",
    visions.active == nil
      and game.save.modData.kanto_ascendant.vision_encounters.ho_oh == true)
  check("field return screenshot",
    U.shot(game, dir .. "/04_route2_return.png"))

  U.log(("RC13 HO-OH MYSTERY RESULT pass=%d fail=%d"):format(pass, fail))
  love.event.quit(fail == 0 and 0 or 1)
end
