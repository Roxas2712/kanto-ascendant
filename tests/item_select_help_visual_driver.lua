-- UI-001 package receipt. Run once against the English package and once with
-- the German translation package:
--   QA_ITEM_HELP_LANGUAGE=en|de SHOT_DIR=... POKEPORT_DRIVER=...
-- It drives abstract SELECT/START actions, which are fed by both keyboard and
-- controller bindings in the engine, over real Bag/PlayerPC/Shop screens. The
-- Bag uses SELECT for mark/place and START for help; PC/shop retain their
-- storage-specific SELECT-help contracts.

return function(game)
  assert(os.getenv("KA_PACKAGE_GATE") == "1",
    "KA_PACKAGE_GATE=1 is required; source runs are not package proof")
  local U = dofile(os.getenv("KA_TEST_UTIL") or "tests/drivers/util.lua")
  local expected = (os.getenv("QA_ITEM_HELP_LANGUAGE") or "en"):lower()
  local suffix = expected == "de" and "de" or "en"
  local dir = os.getenv("SHOT_DIR") or "/tmp/ka65-item-select-help"
  local PlayerPC = require("src.ui.PlayerPC")
  local ShopMenu = require("src.ui.ShopMenu")
  local Screens = require("src.ui.Screens")

  local physicalInputChecks = 0
  local function physicalKey(action, key, target)
    assert(game.input.keyBindings[key] == action,
      ("keyboard %s is not bound to %s"):format(key, action))
    game:keypressed(key)
    U.wait(1)
    game:keyreleased(key)
    physicalInputChecks = physicalInputChecks + 1
    return not target or game.stack:top() ~= target
  end
  local function physicalPad(action, button, target)
    assert(game.input.padBindings[button] == action,
      ("controller %s is not bound to %s"):format(button, action))
    game:gamepadpressed(nil, button)
    U.wait(1)
    game:gamepadreleased(nil, button)
    physicalInputChecks = physicalInputChecks + 1
    return not target or game.stack:top() ~= target
  end

  local pass, fail = 0, 0
  local function check(label, value)
    if value then pass = pass + 1 else fail = fail + 1 end
    U.log(value and "PASS" or "FAIL", label)
  end
  local function pageText(popup)
    local out = {}
    for _, page in ipairs(popup and popup.pages or {}) do
      for _, line in ipairs(page) do out[#out + 1] = line end
    end
    return table.concat(out, " ")
  end
  local function helpLanguageOkay(popup)
    local text = pageText(popup)
    if expected == "de" then return text:find("20 KP", 1, true) ~= nil end
    return text:find("20 HP", 1, true) ~= nil
  end
  local function sameCounts(before, after)
    for id, count in pairs(before) do
      if after[id] ~= count then return false end
    end
    for id in pairs(after) do
      if before[id] == nil then return false end
    end
    return true
  end
  local function copyMap(source)
    local result = {}
    for key, value in pairs(source or {}) do result[key] = value end
    return result
  end
  local function closeTo(target)
    while game.stack:top() and game.stack:top() ~= target do game.stack:pop() end
  end

  -- A disposable gameplay state; no story flags or map actions are needed.
  while game.stack:top() do game.stack:pop() end
  game.save.inventory = { POTION = 3, ANTIDOTE = 2, POKE_BALL = 5 }
  game.save.bagOrder = { "POTION", "ANTIDOTE", "POKE_BALL" }
  game.save.pcItems = { POTION = 2, ANTIDOTE = 1 }
  game.save.pcOrder = { "POTION", "ANTIDOTE" }
  game.save.money = 5000
  local beforeBag = copyMap(game.save.inventory)
  local beforePc = copyMap(game.save.pcItems)
  local beforeMoney = game.save.money

  Screens.push(game, "BagMenu")
  local bag = game.stack:top()
  U.wait(3)
  check("Bag footer exposes SELECT move and START help",
    bag.__ascendantBagSecondary == "move")
  check("Bag control screenshot",
    U.shot(game, dir .. "/01_bag_controls_" .. suffix .. ".png"))
  check("Bag keyboard SELECT marks without leaving the Bag",
    not physicalKey("select", "tab", bag) and bag.swapIndex == 1)
  U.tap(game, "down")
  check("Bag controller SELECT completes the same move",
    not physicalPad("select", "back", bag) and bag.swapIndex == nil)
  check("Bag SELECT move persists without changing counts",
    table.concat(game.save.bagOrder or {}, ",")
      == "ANTIDOTE,POTION,POKE_BALL"
      and sameCounts(beforeBag, game.save.inventory))
  check("Bag keyboard START reaches the live help callback",
    physicalKey("start", "escape", bag))
  U.wait(2)
  local bagHelp = game.stack:top()
  check("Bag START opens localized Potion help", helpLanguageOkay(bagHelp))
  check("Bag START help screenshot",
    U.shot(game, dir .. "/02_bag_help_" .. suffix .. ".png"))
  U.tap(game, "b")
  U.wait(2)
  closeTo(bag)
  game.stack:pop()

  Screens.push(game, "BagMenu")
  local padBag = game.stack:top()
  U.wait(2)
  for index, item in ipairs(padBag.items or {}) do
    if item.value == "POTION" then padBag.index = index break end
  end
  check("Bag controller START reaches the identical live help callback",
    physicalPad("start", "start", padBag))
  local padHelp = game.stack:top()
  check("controller START Bag help uses the requested language",
    helpLanguageOkay(padHelp))
  U.tap(game, "b")
  U.wait(1)
  closeTo(padBag)
  game.stack:pop()

  local pcRoot = PlayerPC.new(game, { direct = true })
  game.stack:push(pcRoot)
  pcRoot.items[1].onSelect()
  U.wait(3)
  local withdraw = game.stack:top()
  check("PC list exposes stable kind and START reorder",
    withdraw.kind == "pc_item_withdraw"
      and type(withdraw.onStartKey) == "function")
  check("PC control footer is visible",
    U.shot(game, dir .. "/03_pc_controls_" .. suffix .. ".png"))
  check("PC controller SELECT reaches the live help callback",
    physicalPad("select", "back", withdraw))
  U.wait(2)
  local pcHelp = game.stack:top()
  check("PC SELECT opens localized Potion help", helpLanguageOkay(pcHelp))
  check("PC SELECT help screenshot",
    U.shot(game, dir .. "/04_pc_help_" .. suffix .. ".png"))
  U.tap(game, "b")
  U.wait(2)
  withdraw.index = 1
  check("PC keyboard START reaches the reorder owner",
    not physicalKey("start", "escape", withdraw))
  U.tap(game, "down")
  check("PC controller START reaches the same reorder owner",
    not physicalPad("start", "start", withdraw))
  U.wait(2)
  check("PC START reorder persists without moving items",
    table.concat(game.save.pcOrder or {}, ",") == "ANTIDOTE,POTION"
      and game.save.pcItems.POTION == 2 and game.save.pcItems.ANTIDOTE == 1)
  while game.stack:top() do game.stack:pop() end
  local reopenedRoot = PlayerPC.new(game, {})
  reopenedRoot.items[1].onSelect()
  local reopened = game.stack:top()
  check("PC persisted order survives reopening",
    reopened and reopened.items[1] and reopened.items[1].value == "ANTIDOTE")
  while game.stack:top() do game.stack:pop() end

  for _, row in ipairs({
    { index = 1, label = "BUY", shot = "05_shop_buy_help_" },
    { index = 2, label = "SELL", shot = "06_shop_sell_help_" },
  }) do
    local root = ShopMenu.new(game, { "POTION", "ANTIDOTE" }, function() end)
    game.stack:push(root)
    root.items[row.index].onSelect()
    U.wait(2)
    local list = game.stack:top()
    check(row.label .. " list has SELECT item help",
      type(list.onSelectKey) == "function")
    -- SELL follows bagOrder, restored above with Potion first.
    list.index = 1
    if list.items[1] and list.items[1].value ~= "POTION" then
      for index, item in ipairs(list.items) do
        if item.value == "POTION" then list.index = index break end
      end
    end
    if row.label == "BUY" then
      check("BUY keyboard SELECT reaches item help",
        physicalKey("select", "tab", list))
    else
      check("SELL controller SELECT reaches item help",
        physicalPad("select", "back", list))
    end
    U.wait(2)
    local popup = game.stack:top()
    check(row.label .. " SELECT opens localized Potion help",
      helpLanguageOkay(popup))
    check(row.label .. " help screenshot",
      U.shot(game, dir .. "/" .. row.shot .. suffix .. ".png"))
    while game.stack:top() do game.stack:pop() end
  end

  check("all help paths preserve Bag counts",
    sameCounts(beforeBag, game.save.inventory))
  check("all help paths preserve PC counts",
    sameCounts(beforePc, game.save.pcItems))
  check("all help paths preserve money", game.save.money == beforeMoney)
  check("keyboard/controller matrix exercised nine physical inputs",
    physicalInputChecks == 9)

  U.log(("RESULT language=%s pass=%d fail=%d"):format(
    suffix, pass, fail))
  love.event.quit(fail == 0 and 0 or 1)
end
