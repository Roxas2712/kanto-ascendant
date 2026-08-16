-- Real Red/Blue/Yellow runtime smoke test for the 5.2.3 visual/Wilds fix.
-- Run with Kanto Ascendant and Wilds of Kanto enabled in a disposable
-- POKEPORT_IDENTITY.

return function(game)
  local U = dofile("tests/drivers/util.lua")
  local BattleState = require("src.battle.BattleState")
  local GameVersion = require("src.core.GameVersion")
  local Pokemon = require("src.pokemon.Pokemon")
  local Runtime = require("src.mods.Runtime")
  local Sprites = require("src.pokemon.Sprites")

  U.wait(20)
  local exports = assert(game.mods and game.mods.exports,
    "mod exports unavailable")
  local ascendant = assert(exports.kanto_ascendant,
    "Kanto Ascendant export missing")
  local wilds = assert(exports.overworld_wild_spawns,
    "Wilds of Kanto export missing")
  local oakRuntimeDemo
  assert(ascendant.wildsCompat and ascendant.wildsCompat.installed,
    "Wilds of Kanto compatibility did not install")
  if GameVersion.isYellow() then
    assert(game.data.strings.PIKACHU == "PIKACHU",
      "a follower mod renamed Yellow's starter to Charmander")
    assert(not game.data.text._OaksLabPikachuDislikesPokeballsText2:find(
      "CHARMANDER", 1, true),
      "a follower mod replaced Yellow's Pikachu story dialogue")
    assert(BattleState.YELLOW_OAK_PIKACHU_ENCOUNTER
        == "yellow_oak_pikachu",
      "the engine does not expose the stable Oak encounter marker")
    assert(ascendant.followerCompat
        and ascendant.followerCompat.isYellowOakPikachuRequest,
      "Ascendant's Yellow Oak compatibility guard is unavailable")

    -- Reproduce PokéPC Followers 1.3.0 exactly outside Ascendant's wrapper:
    -- the outer mod sees Pikachu/5, changes it to Charmander and forwards all
    -- varargs. The explicit story marker must still win in the final battle.
    local convertedSpecies
    local function pokepc130Wrapper(g, species, level, ...)
      if species == "PIKACHU" and level == 5 then
        species = "CHARMANDER"
      end
      convertedSpecies = species
      return BattleState.newWild(g, species, level, ...)
    end
    oakRuntimeDemo = pokepc130Wrapper(game, "PIKACHU", 5, {
      scriptedEncounter = BattleState.YELLOW_OAK_PIKACHU_ENCOUNTER,
    })
    assert(convertedSpecies == "CHARMANDER",
      "QA fixture did not reproduce PokéPC's Charmander conversion")
    assert(oakRuntimeDemo.enemy and oakRuntimeDemo.enemy.mon
        and oakRuntimeDemo.enemy.mon.species == "PIKACHU"
        and oakRuntimeDemo.enemy.mon.level == 5,
      "the marked Oak encounter was not repaired to level-5 Pikachu")
    assert(oakRuntimeDemo.scriptedEncounter
        == BattleState.YELLOW_OAK_PIKACHU_ENCOUNTER,
      "the Oak encounter identity was lost through the wrapper")
    oakRuntimeDemo:makeOldManDemo("PROF.OAK")
    assert(oakRuntimeDemo.demo and oakRuntimeDemo.demoName == "PROF.OAK",
      "the repaired encounter lost Professor Oak's demo presentation")
  end
  assert(ascendant.wildsCompat.registeredSprites == 100,
    "Wilds compatibility did not reserve all 100 Johto sprite IDs")
  assert(wilds.render.speciesSpriteIds.NATU
      == ascendant.wildsCompat.spriteIds.NATU,
    "Wilds did not receive Ascendant's registered Natu sprite ID")

  local normalCount, shinyCount = 0, 0
  for _ in pairs(ascendant.kantoCrystalBacks.normal) do
    normalCount = normalCount + 1
  end
  for _ in pairs(ascendant.kantoCrystalBacks.shiny) do
    shinyCount = shinyCount + 1
  end
  assert(normalCount == 151 and shinyCount == 151,
    ("Kanto Crystal back pack incomplete: %d normal / %d shiny")
      :format(normalCount, shinyCount))

  local pikachu = Pokemon.new(game.data, "PIKACHU", 18,
    function() return 8 end)
  local ctx = {
    species = "PIKACHU",
    side = "back",
    kind = "battle",
    data = game.data,
    mon = pikachu,
  }
  local requested = game.data.pokemon.PIKACHU.spriteBack
  local path = Runtime.call("pokemon.sprite",
    function(original) return original end, requested, ctx)
  assert(path:find(
    "assets/crystal/kanto/025_back.png", 1, true),
    "Pikachu did not resolve to the bundled Crystal back: " .. tostring(path))
  local image = love.image.newImageData(path)
  local width, height = image:getDimensions()
  assert(width == 56 and height == 56,
    ("Pikachu Crystal back has wrong dimensions: %dx%d"):format(width, height))
  assert(BattleState.resolveBattleScale(
    game.data, "back", path, "PIKACHU") == 1,
    "Pikachu Crystal back did not use native 1x scale")

  local oakDemoPikachu = Pokemon.new(game.data, "PIKACHU", 5,
    function() return 8 end)
  local oakDemoPath = Sprites.path(game.data, "PIKACHU", "front", {
    kind = "battle",
    mon = oakDemoPikachu,
  })
  assert(oakDemoPath
      and oakDemoPath:find(
        "assets/crystal_animated/front/normal/25/001.png", 1, true),
    "Oak's Yellow intro Pikachu resolved to the wrong front: "
      .. tostring(oakDemoPath))

  pikachu.dvs = {
    attack = 10, defense = 10, speed = 10, special = 10, hp = 0,
  }
  local shinyPath = Runtime.call("pokemon.sprite",
    function(original) return original end, requested, {
      species = "PIKACHU",
      side = "back",
      kind = "battle",
      data = game.data,
      mon = pikachu,
    })
  assert(shinyPath:find(
    "assets/crystal/kanto/025_back_shiny.png", 1, true),
    "shiny Pikachu did not resolve to its matching Crystal back")

  game.save.hallOfFame = game.save.hallOfFame or { {} }
  game.save.pokedex = game.save.pokedex or { seen = {}, owned = {} }
  local researchState = ascendant.johtoResearch.state()
  researchState.rewards.NATU = true
  local habitat = assert(ascendant.johtoResearch.rollHabitat(
    "ROUTE_22", "grass", function(lo) return lo end),
    "real Johto habitat selector did not return researched Natu")
  assert(habitat.species == "NATU" and habitat.level == 18,
    "real Natu habitat returned the wrong species or level")

  U.teleport(game, "ROUTE_22", 8, 8, "down")
  U.wait(30)
  local logic = assert(wilds.logic, "Wilds spawn logic missing")
  if logic._clearMap then logic:_clearMap("ROUTE_22") end
  local realRoll = ascendant.johtoResearch.rollHabitat
  ascendant.johtoResearch.rollHabitat = function(mapId, terrain)
    assert(mapId == "ROUTE_22" and terrain == "grass",
      "Wilds forwarded the wrong habitat context")
    return { species = "NATU", level = 18 }
  end
  local ok, record, spawnErr, entity = pcall(
    logic.trySpawn, logic, game, { force = true, x = 10, y = 8 })
  ascendant.johtoResearch.rollHabitat = realRoll
  assert(ok, "Wilds Johto spawn threw: " .. tostring(record))
  assert(record, "Wilds Johto spawn failed: " .. tostring(spawnErr))
  assert(record.species == "NATU" and record.level == 18,
    "Wilds did not materialize the selected Natu habitat")
  assert(entity and entity.sprite and entity.sprite.def,
    "Wilds did not build a visible Natu renderer")

  local asset = wilds.render:resolveAsset("NATU", game, { force = true })
  assert(asset and asset.status == "LOADED" and not asset.fallbackUsed,
    "Wilds could not load Natu's real overworld asset")
  assert(entity.sprite.def.image == asset.path,
    "Wilds rendered a fallback instead of Natu's generated overworld art")

  local shotDir = os.getenv("SHOT_DIR")
  if shotDir then
    while game.stack:top() and game.stack:top() ~= game.overworld do
      game.stack:pop()
    end
    U.wait(10)
    assert(U.shot(game, shotDir .. "/natu_wilds_overworld.png"),
      "Natu Wilds screenshot failed")
    pikachu.dvs = {
      attack = 8, defense = 8, speed = 8, special = 8, hp = 8,
    }
    game.save.party = { pikachu }
    U.teleport(game, "ROUTE_1", 5, 5, "down")
    local battle = BattleState.newWild(game, "PIDGEY", 8)
    battle.onFinish = function() end
    game.overworld:pushBattle(battle)
    U.wait(220)
    for _ = 1, 40 do
      if battle.phase == "menu" then break end
      U.tap(game, "a")
      U.wait(6)
    end
    assert(battle.phase == "menu",
      "Pikachu battle did not reach the action menu")
    assert(U.shot(game, shotDir .. "/yellow_pikachu_crystal_back.png"),
      "Pikachu battle screenshot failed")
    while game.stack:top() and game.stack:top() ~= game.overworld do
      game.stack:pop()
    end
    if GameVersion.isYellow() then
      local demo = assert(oakRuntimeDemo,
        "Oak's repaired Yellow demo was not prepared")
      demo.onFinish = function() end
      game.overworld:pushBattle(demo)
      U.wait(220)
      assert(U.shot(game, shotDir .. "/yellow_oak_pikachu_intro.png"),
        "Oak Pikachu intro screenshot failed")
    end
  end

  U.log("PASS 5.2.3", GameVersion.get(),
    "Pikachu Crystal back", "Oak Pikachu intro",
    "shiny back", "Natu Wilds habitat")
end
