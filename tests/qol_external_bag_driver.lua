-- Verifies the declared Useful Bag conflict leaves the standalone owner active
-- while Kanto Ascendant is safely disabled by the loader.

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
    and game.mods.exports.kanto_ascendant
  check("Ascendant is disabled beside standalone Useful Bag",
    exports == nil)
  check("standalone Useful Bag remains the active renderer",
    bag and bag.externalUsefulBagTestDouble == true
      and bag.__ascendantModernBag ~= true)
  check("external Bag screenshot",
    U.shot(game, DIR .. "/external_useful_bag.png"))
  U.log(("RESULT pass=%d fail=%d"):format(pass, fail))
end
