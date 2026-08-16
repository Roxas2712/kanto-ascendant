-- UI-001: real v0.1.79 ListMenu / PlayerPC / ShopMenu contract.
-- SELECT must be read-only bilingual item help everywhere. START remains the
-- explicit, persistent Player-PC order control; the plain Bag keeps its old
-- manual reorder on START (pocket mode promotes that key to its sort prompt).

local engine = assert(os.getenv("GEN1RECOMP_DIR"),
  "GEN1RECOMP_DIR is required")
local modDir = os.getenv("TRAINER_REMATCH_MOD_DIR") or "."
package.path = engine .. "/?.lua;" .. engine .. "/?/init.lua;"
  .. package.path

love = love or require("tests.love_stub")

local checks = 0
local function check(value, message)
  checks = checks + 1
  assert(value, "FAIL: " .. message)
end
local function eq(actual, expected, message)
  checks = checks + 1
  assert(actual == expected, "FAIL: " .. message .. " (got "
    .. tostring(actual) .. ", expected " .. tostring(expected) .. ")")
end
local function sameMap(actual, expected, message)
  for key, value in pairs(expected) do
    eq(actual[key], value, message .. " / " .. tostring(key))
  end
  for key in pairs(actual) do
    check(expected[key] ~= nil, message .. " / unexpected " .. tostring(key))
  end
end

-- No audio cache is needed for a headless order receipt.
package.loaded["src.core.Sound"] = { play = function() end }

local Data = require("tests.fixture_data")
Data = setmetatable({}, { __index = Data })
Data.items = {
  POTION = { id = "POTION", name = "POTION", price = 300,
    tossable = true },
  ANTIDOTE = { id = "ANTIDOTE", name = "ANTIDOTE", price = 100,
    tossable = true },
  POKE_BALL = { id = "POKE_BALL", name = "POKé BALL", price = 200,
    ball = "POKE_BALL", tossable = true },
}
Data.text = Data.text or {}
Data.field = Data.field or {}
Data.field.pcItemCap = 50

local edge
local input = {
  wasPressed = function(_, action) return edge == action end,
  isDown = function() return false end,
}
local states = {}
local stack = {
  push = function(_, state) states[#states + 1] = state; return state end,
  pop = function() return table.remove(states) end,
  top = function() return states[#states] end,
}
local game = {
  data = Data,
  input = input,
  stack = stack,
  save = {
    player = { name = "RED" }, money = 5000,
    inventory = { POTION = 3, ANTIDOTE = 2, POKE_BALL = 5 },
    bagOrder = { "POTION", "ANTIDOTE", "POKE_BALL" },
    pcItems = { POTION = 2, ANTIDOTE = 1 },
    pcOrder = { "POTION", "ANTIDOTE" },
  },
}

local english = { text = function(en) return en end }
local itemHelp = assert(loadfile(modDir .. "/item_help.lua"))()(english)
local shown = {}
local ui = {
  tr = function(en) return en end,
  decorateBag = function(list, provider)
    list.ascendantBagDescription = provider
    return list
  end,
  showHelp = function(helpGame, title, body)
    local popup = { __itemHelp = true, title = title, body = body }
    shown[#shown + 1] = popup
    helpGame.stack:push(popup)
    return true
  end,
}
assert(loadfile(modDir .. "/ascendant_bag.lua"))()({}, {
  ui = ui, itemHelp = itemHelp,
})

local function tap(list, action)
  edge = action
  list:update(0)
  edge = nil
end

local function snapshot()
  return {
    inventory = {
      POTION = game.save.inventory.POTION,
      ANTIDOTE = game.save.inventory.ANTIDOTE,
      POKE_BALL = game.save.inventory.POKE_BALL,
    },
    pcItems = {
      POTION = game.save.pcItems.POTION,
      ANTIDOTE = game.save.pcItems.ANTIDOTE,
    },
    money = game.save.money,
  }
end
local before = snapshot()

-- Plain Ascendant Bag: SELECT info, START retains the old reorder callback.
local bag = require("src.ui.BagMenu").new(game, {})
states[#states + 1] = bag
eq(bag.kind, "bag", "Bag exposes its stable kind")
check(type(bag.onSelectKey) == "function", "Bag SELECT callback exists")
check(type(bag.onStartKey) == "function", "Bag START reorder callback exists")
tap(bag, "select")
check(stack:top().__itemHelp and stack:top().body:find("20 HP", 1, true),
  "Bag SELECT opens English item help")
stack:pop()
eq(table.concat(game.save.bagOrder, ","), "POTION,ANTIDOTE,POKE_BALL",
  "Bag help does not reorder inventory")

-- Player PC: every list gets help; START marks/moves and survives reopening.
states = {}
stack.push = function(_, state) states[#states + 1] = state; return state end
stack.pop = function() return table.remove(states) end
stack.top = function() return states[#states] end
local PlayerPC = require("src.ui.PlayerPC")
local pcRoot = PlayerPC.new(game, { direct = true })
pcRoot.items[1].onSelect()
local withdraw = stack:top()
eq(withdraw.kind, "pc_item_withdraw", "withdraw stable kind")
check(withdraw.controlHint:find("SELECT: INFO", 1, true)
    and withdraw.controlHint:find("START: MOVE", 1, true),
  "PC footer documents help and reorder")
tap(withdraw, "select")
check(stack:top().__itemHelp and stack:top().body:find("20 HP", 1, true),
  "PC SELECT opens item help")
stack:pop()
withdraw.index = 1
tap(withdraw, "start")
eq(withdraw.swapIndex, 1, "START marks a PC item")
withdraw.index = 2
tap(withdraw, "start")
eq(withdraw.swapIndex, nil, "second START completes PC move")
eq(table.concat(game.save.pcOrder, ","), "ANTIDOTE,POTION",
  "PC move persists in save.pcOrder")
eq(withdraw.items[1].value, "ANTIDOTE", "live PC rows follow persisted order")

-- Cancel while marked is non-destructive and stays in the list.
withdraw.index = 1
tap(withdraw, "start")
local topBeforeCancel = stack:top()
tap(withdraw, "b")
eq(withdraw.swapIndex, nil, "B cancels a pending PC move")
eq(stack:top(), topBeforeCancel, "first B after marking keeps PC list open")
eq(table.concat(game.save.pcOrder, ","), "ANTIDOTE,POTION",
  "cancelled PC move does not mutate order")

states = {}
local reopenedRoot = PlayerPC.new(game, {})
reopenedRoot.items[1].onSelect()
local reopened = stack:top()
eq(reopened.items[1].value, "ANTIDOTE",
  "PC order survives closing and reopening")

-- Deposit uses the real bag order, not a private projection.
states = {}
local depositRoot = PlayerPC.new(game, {})
depositRoot.items[2].onSelect()
local deposit = stack:top()
eq(deposit.kind, "pc_item_deposit", "deposit stable kind")
deposit.index = 1
tap(deposit, "start")
deposit.index = 2
tap(deposit, "start")
eq(table.concat(game.save.bagOrder, ","), "ANTIDOTE,POTION,POKE_BALL",
  "deposit reorder persists through save.bagOrder")

-- Shop BUY and SELL both expose the same read-only SELECT action.
local ShopMenu = require("src.ui.ShopMenu")
for _, row in ipairs({
  { index = 1, kind = "shop_buy" },
  { index = 2, kind = "shop_sell" },
}) do
  states = {}
  local root = ShopMenu.new(game, { "POTION", "ANTIDOTE" }, function() end)
  root.items[row.index].onSelect()
  local list = stack:top()
  eq(list.kind, row.kind, row.kind .. " stable kind")
  check(type(list.onSelectKey) == "function", row.kind .. " SELECT exists")
  local expectedBody = itemHelp.describe(game, list.items[list.index].value)
  tap(list, "select")
  check(stack:top().__itemHelp and stack:top().body == expectedBody,
    row.kind .. " SELECT opens item help")
  stack:pop()
end

local after = snapshot()
sameMap(after.inventory, before.inventory, "SELECT help preserves Bag counts")
sameMap(after.pcItems, before.pcItems, "SELECT help preserves PC counts")
eq(after.money, before.money, "SELECT help preserves money")
check(#shown == 4, "Bag, PC, BUY and SELL each opened one help popup")

-- Policy is bilingual: a German runtime gets German prose through the same
-- installed wrapper without changing list behavior.
local german = { text = function(_, de) return de end }
local germanHelp = assert(loadfile(modDir .. "/item_help.lua"))()(german)
ui.tr = function(_, de) return de end
assert(loadfile(modDir .. "/ascendant_bag.lua"))()({}, {
  ui = ui, itemHelp = germanHelp,
})
states = {}
local germanRoot = ShopMenu.new(game, { "POTION" }, function() end)
germanRoot.items[1].onSelect()
local germanBuy = stack:top()
tap(germanBuy, "select")
check(stack:top().body:find("20 KP", 1, true),
  "German shop SELECT uses German item help")

print(("item SELECT help engine test: PASS (%d checks)"):format(checks))
