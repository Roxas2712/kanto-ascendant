-- Real-LÖVE matrix driver for the five configurable ASC bag modes.

return function(game)
  local U = dofile("tests/drivers/util.lua")
  local expected = assert(os.getenv("QA_BAG_MODE"), "QA_BAG_MODE missing")
  local DIR = os.getenv("SHOT_DIR") or "/tmp/ka65-bag-modes"
  local Screens = require("src.ui.Screens")
  local Bag = require("src.inventory.Bag")
  local wantModern = expected == "skin"
    or expected == "expanded" or expected == "pockets"
  local wantCapacity = (expected == "expanded" or expected == "pockets")
    and 999 or 20

  U.teleport(game, "ROUTE_1", 5, 5, "down")
  game.save.inventory = {
    POTION = 3, POKE_BALL = 8, BICYCLE = 1, TM01 = 1,
  }
  game.save.bagOrder = { "POTION", "POKE_BALL", "BICYCLE", "TM01" }
  Screens.push(game, "BagMenu")
  U.wait(5)
  local bag = game.stack:top()
  assert((bag.__ascendantModernBag == true) == wantModern,
    expected .. " modern renderer mismatch")
  assert(Bag.capacity(game.data) == wantCapacity,
    expected .. " capacity mismatch")
  if expected == "pockets" then
    assert(bag.__pocketIndex ~= nil, "pockets mode missing pocket controller")
  else
    assert(bag.__pocketIndex == nil, expected .. " unexpectedly has pockets")
  end
  assert(U.shot(game, DIR .. "/bag_mode_" .. expected .. ".png"))
  U.log("PASS bag mode", expected, "capacity", Bag.capacity(game.data))
end
