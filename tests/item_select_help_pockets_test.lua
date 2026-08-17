-- 6.5.5 focused pocket-mode receipt: SELECT marks/places, START opens help,
-- and the optional R3 action screen retains deterministic bulk sorts.

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
T.eq(bag.__ascendantBagSecondary, "move",
  "pocket mode advertises SELECT move and START info")
T.eq(bag.title, "MEDICINE", "first non-empty pocket is visible")

local beforeInventory = game.save.inventory.POTION
local beforeOrder = table.concat(game.save.bagOrder, ",")
edge = "select"
bag:update(0)
edge = nil
T.eq(bag.swapIndex, 1, "first SELECT marks a pocket row")
edge = "down"
bag:update(0)
edge = nil
edge = "select"
bag:update(0)
edge = nil
T.eq(bag.swapIndex, nil, "second SELECT places a pocket row")
T.eq(game.save.inventory.POTION, beforeInventory,
  "pocket move does not consume an item")
T.check(table.concat(game.save.bagOrder, ",") ~= beforeOrder,
  "pocket move persists in bagOrder")

-- START is the item-help action available to keyboard and controller.
edge = "start"
bag:update(0)
edge = nil
T.eq(helpCount, 1, "START opens item help in pocket mode")
T.check(game.stack:top().__help, "START pushed the help state")
game.stack:pop()

-- R3 remains an optional controller shortcut to the extended action screen.
local Input = require("src.core.Input")
Input.gamepadpressed(Input, nil, "rightstick")
bag:update(0)
local prompt = game.stack:top()
T.check(prompt ~= bag and prompt.__ascendantBagActions
    and #prompt.items == 3,
  "controller R3 opens the extended action screen")
prompt.onChoose(prompt.items[3], prompt)
T.eq(table.concat(game.save.bagOrder, ","), "POTION,ANTIDOTE",
  "R3 count sort persists without item mutation")
T.eq(game.save.inventory.POTION, 2,
  "sort paths preserve item counts")

T.finish("item SELECT help pockets")
