-- Pixel-exact visual receipt for RC28-MANUAL-010's German action surface.
-- Functional input/persistence is covered by bag_item_actions_test.lua; this
-- driver renders only the isolated Kanto UI, without loading a campaign save.

return function(game)
  local modDir = os.getenv("TRAINER_REMATCH_MOD_DIR") or "."
  local output = assert(os.getenv("KA_BAG_ACTIONS_SHOT"),
    "KA_BAG_ACTIONS_SHOT is required")
  local U = dofile(os.getenv("KA_TEST_UTIL") or "tests/drivers/util.lua")

  local i18n = { text = function(_, de) return de end }
  local mod = { ui = { ListMenu = require("src.ui.ListMenu") } }
  local ui = assert(loadfile(modDir .. "/ascendant_ui.lua"))()(mod, {
    i18n = i18n,
  })
  local rows = {
    { value = "move", label = "ITEM VERSCHIEBEN" },
    { value = "quick_select", label = "SCHNELLWAHL", right = "REG." },
    { value = "sort_name", label = "NACH NAME SORTIEREN" },
    { value = "sort_count", label = "NACH ANZAHL", right = "SORT." },
  }
  local menu = ui.ListMenu.new(game, "ITEM-AKTIONEN", rows, {
    kind = "ascendant_bag_actions",
  })
  menu.__ascendantBagActions = true

  while game.stack:top() do game.stack:pop() end
  game.stack:push(menu)
  U.wait(3)
  assert(U.shot(game, output), "Bag action screenshot was not written")
  print("Bag item actions visual: PASS " .. output)
  love.event.quit(0)
end
