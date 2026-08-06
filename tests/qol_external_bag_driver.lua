-- Verifies the standalone Useful Bag takes over after Ascendant Bag is off.

return function(game)
  local U = dofile("tests/drivers/util.lua")
  local DIR = os.getenv("SHOT_DIR") or "/tmp/ka65-external-bag-shots"
  local Screens = require("src.ui.Screens")
  local pass, fail = 0, 0
  local function check(label, value)
    if value then pass = pass + 1; U.log("PASS", label)
    else fail = fail + 1; U.log("FAIL", label) end
  end

  U.teleport(game, "ROUTE_1", 5, 5, "down")
  game.save.inventory = { POTION = 3, POKE_BALL = 5, BICYCLE = 1 }
  game.save.bagOrder = { "POTION", "POKE_BALL", "BICYCLE" }
  Screens.push(game, "BagMenu")
  U.wait(8)
  local bag = game.stack:top()
  local exports = game.mods and game.mods.exports
    and game.mods.exports.trainer_rematch
  check("Ascendant records the external Useful Bag owner",
    exports and exports.externalUsefulBag == true)
  check("Ascendant renderer is absent while its Bag option is off",
    bag and bag.__ascendantModernBag ~= true)
  check("external Bag screenshot",
    U.shot(game, DIR .. "/external_useful_bag.png"))
  U.log(("RESULT pass=%d fail=%d"):format(pass, fail))
end
