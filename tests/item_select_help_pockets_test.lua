-- RC28-MANUAL-010 focused pocket-mode receipt: SELECT remains help, while
-- START/R3 reach the named action screen. This fixture has no Quick Select
-- provider, so it exposes MOVE plus the two deterministic sorts.

local engine = assert(os.getenv("GEN1RECOMP_DIR"),
  "GEN1RECOMP_DIR is required")
local modDir = os.getenv("TRAINER_REMATCH_MOD_DIR") or "."
package.path = engine .. "/?.lua;" .. engine .. "/?/init.lua;"
  .. package.path
love = love or require("tests.love_stub")

local T = require("tests.modkit")
package.loaded["src.core.Sound"] = { play = function() end }

local Data = require("tests.fixture_data")
Data = setmetatable({}, { __index = Data })
Data.items = {
  POTION = { id = "POTION", name = "POTION", price = 300 },
  ANTIDOTE = { id = "ANTIDOTE", name = "ANTIDOTE", price = 100 },
}
Data.moves = {}

local edge
local states = {}
local game = {
  data = Data,
  save = {
    player = { name = "RED" }, money = 0,
    inventory = { POTION = 2, ANTIDOTE = 1 },
    bagOrder = { "POTION", "ANTIDOTE" },
  },
  input = {
    wasPressed = function(_, action) return edge == action end,
    isDown = function() return false end,
  },
}
game.stack = {
  push = function(_, state) states[#states + 1] = state; return state end,
  pop = function() return table.remove(states) end,
  top = function() return states[#states] end,
}

local helpCount = 0
local ui = {
  tr = function(en) return en end,
  decorateBag = function(list, provider)
    list.ascendantBagDescription = provider
    return list
  end,
  showHelp = function(_, _, body)
    helpCount = helpCount + 1
    states[#states + 1] = { __help = true, body = body }
    return true
  end,
}
local itemHelp = assert(loadfile(modDir .. "/item_help.lua"))()({
  text = function(en) return en end,
})
assert(loadfile(modDir .. "/ascendant_bag.lua"))()({}, {
  ui = ui, itemHelp = itemHelp,
})

local ready
local screen
local mod = {
  exports = {},
  content = { screens = { override = function(_, id, factory)
    T.eq(id, "BagMenu", "Useful Bag owns only BagMenu")
    screen = factory
  end } },
  events = { on = function(_, name, fn)
    if name == "game.ready" then ready = fn end
  end },
}
assert(loadfile(modDir .. "/useful_bag.lua"))()(mod)
assert(ready and screen, "Useful Bag did not install its runtime seams")
ready({ game = game })

local bag = screen.new(game, {})
states[#states + 1] = bag
T.eq(bag.__ascendantBagSecondary, "actions",
  "pocket mode advertises its START action screen")
T.eq(bag.title, "MEDICINE", "first non-empty pocket is visible")

local beforeInventory = game.save.inventory.POTION
local beforeOrder = table.concat(game.save.bagOrder, ",")
edge = "select"
bag:update(0)
edge = nil
T.eq(helpCount, 1, "SELECT opens item help in pocket mode")
T.check(game.stack:top().__help, "SELECT pushed the help state")
game.stack:pop()
T.eq(game.save.inventory.POTION, beforeInventory,
  "pocket help does not consume an item")
T.eq(table.concat(game.save.bagOrder, ","), beforeOrder,
  "pocket help does not reorder the bag")

-- START is an abstract action available to keyboard and controller.
edge = "start"
bag:update(0)
edge = nil
bag:update(0) -- deferred owner-safe open after ListMenu handled START
local prompt = game.stack:top()
T.check(prompt ~= bag and prompt.__ascendantBagActions
    and prompt.title == "ITEM ACTIONS" and #prompt.items == 3,
  "START opens MOVE plus two sort actions")
T.eq(prompt.items[1].value, "move", "manual move stays reachable")
prompt.onChoose(prompt.items[2], prompt)
T.eq(table.concat(game.save.bagOrder, ","), "ANTIDOTE,POTION",
  "START sort rewrites persistent bagOrder")

-- R3 remains an optional controller shortcut to the identical action screen.
local Input = require("src.core.Input")
Input.gamepadpressed(Input, nil, "rightstick")
bag:update(0)
prompt = game.stack:top()
T.check(prompt ~= bag and prompt.__ascendantBagActions
    and #prompt.items == 3,
  "controller R3 opens the same action screen")
prompt.onChoose(prompt.items[3], prompt)
T.eq(table.concat(game.save.bagOrder, ","), "POTION,ANTIDOTE",
  "R3 count sort persists without item mutation")
T.eq(game.save.inventory.POTION, 2,
  "sort paths preserve item counts")

T.finish("item SELECT help pockets")
