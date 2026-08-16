-- Renderer-backed acceptance test for the recurring Red Gyarados event.
-- Exercises the real encounter hook, first-frame shiny preparation, battle
-- presentation, Master Ball capture and one-time event completion.

return function(game)
  local U = dofile("tests/drivers/util.lua")
  local BattleState = require("src.battle.BattleState")
  local Pokemon = require("src.pokemon.Pokemon")
  local Pipelines = require("src.render.Pipelines")
  local Runtime = require("src.mods.Runtime")
  local Stats = require("src.pokemon.Stats")
  local shotDir = assert(os.getenv("SHOT_DIR"), "SHOT_DIR is required")

  U.wait(25)
  local exports = assert(game.mods and game.mods.exports
      and game.mods.exports.kanto_ascendant,
    "Kanto Ascendant export missing")
  local shiny = assert(exports.shinySystem, "shiny system missing")
  local dramatic = game.mods.exports.DRAMATIC_SHAPE
  if os.getenv("REQUIRE_VOXEL") == "1" then
    assert(dramatic, "Dramatic Shape is required for Voxel Red Gyarados QA")
  end
  local overworldBattle = dramatic and dramatic.lib
    and dramatic.lib.require("OverworldBattle") or nil

  game.save.player = game.save.player or { name = "RED QA" }
  game.save.player.name = game.save.player.name or "RED QA"
  game.save.party = {
    Pokemon.new(game.data, "BLASTOISE", 100, function() return 15 end),
  }
  game.save.pokedex = game.save.pokedex or { seen = {}, owned = {} }
  game.save.pokedex.seen = game.save.pokedex.seen or {}
  game.save.pokedex.owned = game.save.pokedex.owned or {}
  game.save.inventory = game.save.inventory or {}
  game.save.bagOrder = game.save.bagOrder or {}
  game.save.options = game.save.options or {}
  game.save.options.textSpeed = 1
  game.save.flags = game.save.flags or {}
  game.save.flags.EVENT_BEAT_CHAMPION_RIVAL = true

  game.mods.modOptions.kanto_ascendant.red_gyarados = true
  game.mods.modOptions.kanto_ascendant.kanto_crystal_art = true
  game.mods.modOptions.kanto_ascendant.crystal_animation = true

  local state = shiny.state()
  state.redGyaradosUnlocked = true
  state.redGyaradosAnnounced = true
  state.redGyaradosCaught = false
  state.rematchStreak = math.max(25, state.rematchStreak or 0)

  local function rollEvent()
    local encounter = Runtime.call("encounter.roll",
      function() return { species = "ZUBAT", level = 32 } end,
      game.data.encounters.SEAFOAM_ISLANDS_B4F,
      {
        mapId = "SEAFOAM_ISLANDS_B4F",
        terrain = "indoor",
        rng = function(_, hi) return hi end,
      })
    assert(encounter and encounter.species == "GYARADOS"
        and encounter.level == 50,
      "Seafoam event did not replace the encounter with Lv50 Gyarados")
    return encounter
  end

  local function openBattle(voxel)
    Pipelines.setLevel("voxel", voxel and 1 or 0)
    Pipelines.syncOptions(game.save.options)
    if voxel and overworldBattle then
      overworldBattle.setting:setIndex(1, game)
      overworldBattle.backSetting:setIndex(1, game)
      U.teleport(game, "SEAFOAM_ISLANDS_B4F", 19, 4, "down")
      U.wait(30)
      assert(overworldBattle.wantsFront(),
        "Dramatic Shape did not stage the Red Gyarados arena")
    end
    local encounter = rollEvent()
    local battle = BattleState.newWild(
      game, encounter.species, encounter.level)
    battle.onFinish = function() end
    game.overworld:pushBattle(battle)
    for _ = 1, 360 do
      if battle.phase == "menu" then break end
      U.tap(game, "a")
      U.wait(3)
    end
    assert(battle.phase == "menu", "Red Gyarados battle did not reach menu")
    assert(battle.enemy and battle.enemy.mon
        and battle.enemy.mon.species == "GYARADOS",
      "event battle changed species")
    assert(Stats.isShiny(battle.enemy.mon.dvs),
      "event Gyarados did not receive canonical shiny DVs")
    assert(battle.enemy.mon.ascendantShinyEvent == true,
      "event Gyarados lost its capture marker")
    if voxel and overworldBattle then
      assert(battle.enemy.__ascendantCrystalAnimation,
        "Voxel Red Gyarados did not attach its shiny Crystal animation")
    end
    return battle
  end

  U.teleport(game, "SEAFOAM_ISLANDS_B4F", 19, 4, "down")
  local battle2d = openBattle(false)
  U.wait(40)
  assert(U.shot(game, shotDir .. "/red_gyarados_crystal_2d.png"))
  while game.stack:top() and game.stack:top() ~= game.overworld do
    game.stack:pop()
  end
  U.wait(12)

  -- It must recur until caught, and the Voxel pipeline must still see the
  -- shiny DVs before selecting its artwork.
  local battleVoxel = openBattle(true)
  U.wait(90)
  assert(U.shot(game, shotDir .. "/red_gyarados_voxel.png"))

  game.save.inventory.MASTER_BALL = nil
  battleVoxel:throwBall("MASTER_BALL")
  for frame = 1, 1800 do
    local top = game.stack:top()
    if top ~= battleVoxel and top ~= game.overworld then
      U.tap(game, "b")
      U.wait(2)
    elseif frame % 18 == 0 then
      U.tap(game, "a")
    else
      U.wait(1)
    end
    if state.redGyaradosCaught then break end
  end
  assert(state.redGyaradosCaught == true,
    "catching the event Gyarados did not complete the event")
  assert(game.save.pokedex.owned.GYARADOS == true,
    "caught Red Gyarados was not recorded in the Pokédex")

  -- A later encounter on the same floor must return to the normal table.
  local later = Runtime.call("encounter.roll",
    function() return { species = "ZUBAT", level = 32 } end,
    game.data.encounters.SEAFOAM_ISLANDS_B4F,
    {
      mapId = "SEAFOAM_ISLANDS_B4F",
      terrain = "indoor",
      rng = function(_, hi) return hi end,
    })
  assert(later.species == "ZUBAT",
    "Red Gyarados remained forced after it was caught")

  U.log("RED GYARADOS 2D+VOXEL+CATCH QA PASS", shotDir)
  love.event.quit()
end
