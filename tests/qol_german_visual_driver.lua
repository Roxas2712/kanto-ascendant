-- Real-LÖVE German regression driver for the 6.5 RC surfaces.

return function(game)
  local U = dofile("tests/drivers/util.lua")
  local DIR = os.getenv("SHOT_DIR") or "/tmp/ka65-qol-de"
  local Screens = require("src.ui.Screens")
  local Strings = require("src.core.Strings")

  local pass, fail = 0, 0
  local function check(label, value)
    if value then pass = pass + 1; U.log("PASS", label)
    else fail = fail + 1; U.log("FAIL", label) end
  end

  local german = game.mods and game.mods.mods and game.mods.mods.deutsch
  local ascendant = game.mods and game.mods.mods
    and game.mods.mods.kanto_ascendant
  check("German and Ascendant loaded together", german and ascendant)

  U.teleport(game, "ROUTE_1", 5, 5, "down")
  local growlithe = game.data.pokemon.GROWLITHE
  check("Growlithe keeps the German species name",
    growlithe and growlithe.name == "FUKANO")
  check("Growlithe category is no longer Seel",
    growlithe and growlithe.dexEntry
      and growlithe.dexEntry.kind == "WELPEN")
  local presets = game.data.field and game.data.field.boot
    and game.data.field.boot.namePresets
  check("ASH remains an intact player preset",
    presets and presets.player and presets.player[2] == "ASH")
  check("Deposit uses Ablegen",
    Strings("DEPOSIT <PK><MN>"):find("ABLEGEN", 1, true) ~= nil)

  game.save.pokedex.seen.GROWLITHE = true
  game.save.pokedex.owned.GROWLITHE = true
  Screens.push(game, "DexEntryMenu", "GROWLITHE")
  U.wait(4)
  check("German Fukano Dex screenshot",
    U.shot(game, DIR .. "/fukano_welpen_dex.png"))
  U.tap(game, "b")

  game.save.player.name = "ASH"
  Screens.push(game, "TrainerCard")
  U.wait(4)
  check("ASH trainer-card screenshot",
    U.shot(game, DIR .. "/ash_name_intact.png"))
  U.tap(game, "b")

  Screens.push(game, "BoxMenu")
  U.wait(4)
  check("German storage screenshot",
    U.shot(game, DIR .. "/box_ablegen.png"))
  U.tap(game, "b")

  Screens.push(game, "JohtoAscendantFeatures")
  U.wait(4)
  check("German Ascendant options screenshot",
    U.shot(game, DIR .. "/ascendant_optionen.png"))

  U.log(("RESULT pass=%d fail=%d"):format(pass, fail))
end
