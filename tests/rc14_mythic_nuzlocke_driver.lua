-- Real-engine Nuzlocke proof for Ho-Oh, Celebi and Mew defeat handling.

return function(game)
  local U = dofile("tests/drivers/util.lua")
  local Pokemon = require("src.pokemon.Pokemon")
  local BattleState = require("src.battle.BattleState")
  local dir = assert(os.getenv("SHOT_DIR"), "SHOT_DIR is required")
  local safety = assert(game.mods.exports.kanto_ascendant.mythicSafety)
  local pass, fail = 0, 0

  local function check(label, value)
    if value then pass = pass + 1 else fail = fail + 1 end
    U.log(value and "PASS" or "FAIL", label)
  end
  local nuzlocke = game.mods.mods and game.mods.mods.nuzlocke
  check("bundled Nuzlocke mod is loaded",
    nuzlocke and nuzlocke.state == "loaded")

  game.save.lastHeal = {
    map = "VIRIDIAN_POKECENTER", x = 3, y = 4, facing = "up",
  }

  local function prepare(species)
    U.teleport(game, "ROUTE_2", 4, 48, "down")
    local mon = Pokemon.new(game.data, "PIKACHU", 12)
    game.save.party = { mon }
    return mon, BattleState.newWild(game, species, 70)
  end

  -- Lugia is deliberately ordinary: there is no vision and no mythical
  -- Nuzlocke exception attached to its regular catch encounter.
  local _, lugia = prepare("LUGIA")
  lugia.postgameLegend = "LUGIA"
  check("Lugia is not protected", safety.protect(lugia) == false)
  lugia.player.mon.hp = 0
  lugia:onFaint(lugia.player)
  check("ordinary Lugia follows Nuzlocke faint removal",
    #game.save.party == 0)

  local cases = {
    { label = "HO_OH LEGEND", species = "HO_OH",
      tag = "postgameLegend" },
    { label = "CELEBI LEGEND", species = "CELEBI",
      tag = "postgameLegend" },
    { label = "CELEBI SIGNAL", species = "CELEBI",
      tag = "kaMythicTrue" },
    { label = "MEW ROUTE 24", species = "MEW",
      tag = "ascendantMew", value = true },
    { label = "MEW ECHO", species = "MEW",
      tag = "kaMythicEcho" },
  }
  for _, row in ipairs(cases) do
    local mon, battle = prepare(row.species)
    battle[row.tag] = row.value or row.species
    check(row.label .. " safety attaches", safety.protect(battle))
    battle.player.mon.hp = 0
    battle:onFaint(battle.player)
    check(row.label .. " faint keeps the Pokemon",
      #game.save.party == 1 and game.save.party[1] == mon)
    battle:playerMonFainted()
    check(row.label .. " produces a normal loss",
      battle.result == "lose" and not battle.nuzlockeGameOver)
    game.overworld:afterBattle("lose", battle)
    for _ = 1, 300 do
      if game.overworld.map.id == "VIRIDIAN_POKECENTER" then break end
      U.wait(1)
    end
    check(row.label .. " returns to the Pokemon Center healed",
      game.overworld.map.id == "VIRIDIAN_POKECENTER"
        and #game.save.party == 1
        and mon.hp == mon.stats.hp)
  end

  check("Pokemon Center proof screenshot",
    U.shot(game, dir .. "/01_mythic_nuzlocke_center.png"))
  U.log(("RC14 MYTHIC NUZLOCKE RESULT pass=%d fail=%d"):format(pass, fail))
  love.event.quit(fail == 0 and 0 or 1)
end
