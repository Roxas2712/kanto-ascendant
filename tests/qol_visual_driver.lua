-- Real-LOVE visual smoke driver for the 6.5 FireRed-inspired Bag and boxes.
-- Run from the engine checkout with this mod linked as mods/trainer_rematch.

return function(game)
  local U = dofile("tests/drivers/util.lua")
  local DIR = os.getenv("SHOT_DIR") or "/tmp/ka65-qol-shots"
  local Pokemon = require("src.pokemon.Pokemon")
  local Boxes = require("src.pokemon.Boxes")
  local Screens = require("src.ui.Screens")

  local pass, fail = 0, 0
  local function check(label, ok)
    if ok then pass = pass + 1; U.log("PASS", label)
    else fail = fail + 1; U.log("FAIL", label) end
  end
  local loaded = game.mods and game.mods.mods
    and game.mods.mods.trainer_rematch
  U.log("MODPATH", loaded and loaded.path or "missing",
    loaded and loaded.manifest and loaded.manifest.version or "missing")

  U.teleport(game, "ROUTE_1", 5, 5, "down")
  game.save.inventory = {
    POTION = 7, ANTIDOTE = 3, POKE_BALL = 12, GREAT_BALL = 4,
    RARE_CANDY = 2, ESCAPE_ROPE = 1, BICYCLE = 1, TOWN_MAP = 1,
    X_ATTACK = 2, TM01 = 1,
  }
  game.save.bagOrder = {
    "POTION", "ANTIDOTE", "POKE_BALL", "GREAT_BALL", "RARE_CANDY",
    "ESCAPE_ROPE", "BICYCLE", "TOWN_MAP", "X_ATTACK", "TM01",
  }

  Screens.push(game, "BagMenu")
  U.wait(8)
  local bag = game.stack:top()
  check("integrated Bag uses the modern renderer",
    bag and bag.__ascendantModernBag == true)
  check("Bag keeps the five-row FireRed layout", bag and bag.rows == 5)
  check("Bag screenshot", U.shot(game, DIR .. "/bag_items.png"))
  U.tap(game, "right")
  U.wait(3)
  check("pocket navigation changes the visible pocket",
    bag and bag.title == "MEDICINE")
  check("medicine pocket screenshot",
    U.shot(game, DIR .. "/bag_medicine.png"))
  U.tap(game, "b")
  U.wait(3)

  local boxes = Boxes.ensure(game.save)
  game.save.currentBox = 1
  boxes[1] = {
    Pokemon.new(game.data, "PIKACHU", 18),
    Pokemon.new(game.data, "BULBASAUR", 12),
    Pokemon.new(game.data, "CHARMANDER", 14),
    Pokemon.new(game.data, "SQUIRTLE", 13),
    Pokemon.new(game.data, "PIDGEY", 9),
    Pokemon.new(game.data, "RATTATA", 8),
    Pokemon.new(game.data, "NIDORAN_M", 11),
  }

  Screens.push(game, "BoxMenu")
  U.wait(8)
  check("storage main screenshot",
    U.shot(game, DIR .. "/box_main.png"))
  U.tap(game, "a") -- WITHDRAW
  U.wait(8)
  local grid = game.stack:top()
  check("withdraw opens the FireRed-style grid",
    grid and grid.__ascendantBoxGrid == true)
  check("box grid screenshot", U.shot(game, DIR .. "/box_grid.png"))
  U.tap(game, "right")
  U.tap(game, "down")
  check("grid D-pad navigation uses five columns", grid and grid.index == 7)
  check("box grid selection screenshot",
    U.shot(game, DIR .. "/box_grid_selected.png"))
  U.tap(game, "b")
  U.tap(game, "b")
  U.wait(3)

  Screens.push(game, "JohtoAscendantFeatures")
  U.wait(5)
  local features = game.stack:top()
  check("JOHTO ASCENDANT FT. screen opens", features ~= nil)
  check("feature hub screenshot",
    U.shot(game, DIR .. "/ascendant_features.png"))
  local oldBagOption = game.mods.modOptions.trainer_rematch
    and game.mods.modOptions.trainer_rematch.ascendant_useful_bag
  U.tap(game, "right")
  local newBagOption = game.mods.modOptions.trainer_rematch
    and game.mods.modOptions.trainer_rematch.ascendant_useful_bag
  check("feature hub writes the selected option",
    oldBagOption ~= newBagOption)

  U.log(("RESULT pass=%d fail=%d"):format(pass, fail))
end
