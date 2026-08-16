-- Native battle-screen proof for the four representative #252-279 species.
-- Each pair proves the actual player back and enemy front in both shiny
-- combinations, through BattleState and the live screen stack.

return function(game)
  local U = dofile(os.getenv("KA_TEST_UTIL") or "tests/drivers/util.lua")
  local Pokemon = require("src.pokemon.Pokemon")
  local BattleState = require("src.battle.BattleState")
  local output = assert(os.getenv("EXTENDED_BATTLE_DIR"), "EXTENDED_BATTLE_DIR required")
  local order = {}
  for species in (os.getenv("EXTENDED_SCENE_SPECIES")
      or "TREECKO,AMBIPOM,AZURILL,WYNAUT"):gmatch("[^,%s]+") do
    order[#order + 1] = species:upper()
  end
  U.wait(45)
  local ascendant = assert(game.mods.exports.kanto_ascendant, "Ascendant missing")
  for _, species in ipairs(order) do
    assert(ascendant.extendedSpeciesRuntime.bySpecies[species],
      "not an extended-runtime species: " .. species)
  end
  local shiny = assert(ascendant.shinySystem, "shiny runtime missing")
  local captures = {}

  local function clear()
    while game.stack:top() do game.stack:pop() end
  end
  local function make(species, isShiny)
    local value = Pokemon.new(game.data, species, 30, function() return 8 end)
    if isShiny then
      assert(shiny.forceMon(value, game.data.pokemon[species]), "could not force shiny " .. species)
      assert(shiny.isShiny(value), "shiny did not persist " .. species)
    end
    return value
  end
  local function shot(species, name)
    local path = output .. "/" .. species:lower() .. "_" .. name .. ".png"
    assert(U.shot(game, path), "battle capture failed " .. path)
    captures[#captures + 1] = { species = species, case = name, path = path }
  end
  local function capture(species, playerShiny, enemyShiny)
    clear()
    local player = make(species, playerShiny)
    game.save.party = { player }
    U.teleport(game, "ROUTE_1", 5, 5, "down")
    local battle = BattleState.newWild(game, species, 30)
    if enemyShiny then
      assert(shiny.forceMon(battle.enemy.mon, game.data.pokemon[species]),
        "could not force enemy shiny " .. species)
      assert(shiny.isShiny(battle.enemy.mon), "enemy shiny did not persist " .. species)
    end
    battle.onFinish = function() end
    game.overworld:pushBattle(battle)
    U.wait(180)
    for _ = 1, 40 do
      if battle.phase == "menu" then break end
      U.tap(game, "a")
      U.wait(6)
    end
    assert(battle.phase == "menu", "battle did not reach menu " .. species)
    local name = (playerShiny and "player_shiny" or "player_normal")
      .. "_" .. (enemyShiny and "enemy_shiny" or "enemy_normal")
    shot(species, name)
  end

  for _, species in ipairs(order) do
    capture(species, false, true)
    capture(species, true, false)
  end
  local file = assert(io.open(output .. "/battle_capture_manifest.json", "wb"))
  file:write(ascendant.extendedSpeciesRuntime.encodeJson({
    status = "partial", evidence = "live-BattleState-screen-stack",
    species = order, captures = captures,
  }))
  file:close()
  print(("EXTENDED SPECIES BATTLE CAPTURE PASS: %d screenshots"):format(#captures))
  love.event.quit(0)
end
