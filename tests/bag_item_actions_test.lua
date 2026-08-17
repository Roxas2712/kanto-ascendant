-- RC28-MANUAL-010: focused Bag action contract.
--
-- Runs on the real ListMenu/BagMenu modules, but never starts a campaign.
-- It proves SELECT move, START help, optional R3 actions, pocket-safe
-- cancel/place semantics, Quick Select registration, DE/EN labels,
-- empty/single pockets, battle isolation and persisted reopen order.

local engine = assert(os.getenv("GEN1RECOMP_DIR"),
  "GEN1RECOMP_DIR is required")
local modDir = os.getenv("TRAINER_REMATCH_MOD_DIR") or "."
package.path = engine .. "/?.lua;" .. engine .. "/?/init.lua;"
  .. package.path

love = love or require("tests.love_stub")
package.loaded["src.core.Sound"] = { play = function() end }

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
local function row(menu, value)
  for _, candidate in ipairs(menu.items or {}) do
    if candidate.value == value then return candidate end
  end
end
local function joined(value)
  return table.concat(value or {}, ",")
end
local function inventorySnapshot(inventory)
  local out = {}
  for id, count in pairs(inventory or {}) do out[id] = count end
  return out
end
local function sameInventory(actual, expected, message)
  for id, count in pairs(expected) do eq(actual[id], count, message .. "/" .. id) end
  for id in pairs(actual) do check(expected[id] ~= nil, message .. "/extra " .. id) end
end

local Data = require("tests.fixture_data")
Data = setmetatable({}, { __index = Data })
Data.items = {
  Z_ITEM = { id = "Z_ITEM", name = "ZETA", price = 100 },
  A_ITEM = { id = "A_ITEM", name = "ALPHA", price = 100 },
  M_ITEM = { id = "M_ITEM", name = "MU", price = 100 },
  ONLY_ITEM = { id = "ONLY_ITEM", name = "ONLY", price = 100 },
  POTION = { id = "POTION", name = "POTION", price = 300 },
  POKE_BALL = { id = "POKE_BALL", name = "POKé BALL", price = 200,
    ball = "POKE_BALL" },
  X_ATTACK = { id = "X_ATTACK", name = "X ATTACK", price = 500 },
  X_DEFEND = { id = "X_DEFEND", name = "X DEFEND", price = 550 },
}
Data.moves = {}
Data.field = Data.field or {}

local language = "en"
local optionDefaults = {
  ascendant_quick_select = true,
  quick_select_registration = true,
  quick_select_empty_notice = true,
  quick_select_tap = "none",
}
local quickSave = {}
local inputHook
local ListMenu = require("src.ui.ListMenu")
local mod = {
  id = "trainer_rematch",
  exports = {},
  find = function() return nil end,
  options = { get = function(_, key)
    if key == "language" then return language end
    return optionDefaults[key]
  end },
  save = {
    get = function(_, key) return quickSave[key] end,
    set = function(_, key, value) quickSave[key] = value end,
  },
  hooks = { wrap = function(_, name, fn)
    if name == "input.step" then inputHook = fn end
  end },
  ui = {
    KantoListMenu = { new = function(game, title, items, opts)
      return ListMenu.new(game, title, items, opts)
    end },
    TextBox = { new = function(_, text, done)
      return { __text = true, text = text, done = done }
    end },
  },
}

-- Install in production order: Quick Select supplies explicit Bag metadata,
-- Ascendant preserves SELECT move, then Useful Bag owns the pocket screen.
assert(loadfile(modDir .. "/quick_select.lua"))()(mod)
check(type(inputHook) == "function", "Quick Select installed its field hook")

local helpCount = 0
local ui = {
  tr = function(en, de) return language == "de" and de or en end,
  decorateBag = function(list, provider)
    list.ascendantBagDescription = provider
    return list
  end,
  showHelp = function(game, title, body)
    helpCount = helpCount + 1
    game.stack:push({ __help = true, title = title, body = body })
    return true
  end,
}
local itemHelp = assert(loadfile(modDir .. "/item_help.lua"))()({
  text = function(en, de) return language == "de" and de or en end,
})
assert(loadfile(modDir .. "/ascendant_bag.lua"))()(mod, {
  ui = ui, itemHelp = itemHelp,
})

local screen
local ready
mod.content = { screens = { override = function(_, id, factory)
  eq(id, "BagMenu", "Useful Bag owns the Bag screen")
  screen = factory
end } }
mod.events = { on = function(_, name, fn)
  if name == "game.ready" then ready = fn end
end }
assert(loadfile(modDir .. "/useful_bag.lua"))()(mod)
check(screen and ready, "Useful Bag installed screen and ready callback")

local function makeGame(inventory, order)
  local states = {}
  local game = {
    data = Data,
    save = {
      player = { name = "RED" }, money = 0,
      inventory = inventory,
      bagOrder = order,
      options = { modOptions = { [mod.id] = {
        ascendant_quick_select = optionDefaults.ascendant_quick_select,
        quick_select_registration = optionDefaults.quick_select_registration,
        quick_select_empty_notice = true,
        quick_select_tap = "none",
      } } },
    },
    input = {
      edge = nil,
      wasPressed = function(self, action) return self.edge == action end,
      isDown = function() return false end,
    },
  }
  game.stack = {
    states = states,
    push = function(_, state) states[#states + 1] = state; return state end,
    pop = function() return table.remove(states) end,
    top = function() return states[#states] end,
  }
  return game
end

local function pushBag(game, opts)
  local bag = screen.new(game, opts or {})
  game.stack:push(bag)
  return bag
end

local function tap(state, action)
  state.game.input.edge = action
  state:update(0)
  state.game.input.edge = nil
end

local function openActions(bag)
  require("src.core.Input").gamepadpressed(
    require("src.core.Input"), nil, "rightstick")
  bag:update(0)
  if bag.game.stack:top() == bag then bag:update(0) end
  local menu = bag.game.stack:top()
  check(menu ~= bag and menu.__ascendantBagActions,
    "R3 opens the explicit Bag action screen")
  return menu
end

local function choose(menu, value)
  local choice = row(menu, value)
  check(choice ~= nil, "action row exists: " .. tostring(value))
  menu.onChoose(choice, menu)
  return choice
end

local fieldGame = makeGame({
  Z_ITEM = 1, POTION = 5, A_ITEM = 3, POKE_BALL = 7,
  M_ITEM = 2, X_ATTACK = 6, X_DEFEND = 4,
}, { "Z_ITEM", "POTION", "A_ITEM", "POKE_BALL", "M_ITEM",
  "X_ATTACK", "X_DEFEND" })
ready({ game = fieldGame })
local bag = pushBag(fieldGame)
eq(bag.title, "ITEMS", "field Bag opens on the first non-empty pocket")
eq(joined(bag.__pocketIds), "Z_ITEM,A_ITEM,M_ITEM",
  "generic pocket is a projection of interleaved hidden order")
eq(bag.__ascendantBagSecondary, "move",
  "Bag footer advertises SELECT move and START info")

local untouched = inventorySnapshot(fieldGame.save.inventory)
local beforeHelpOrder = joined(fieldGame.save.bagOrder)
tap(bag, "start")
check(fieldGame.stack:top().__help and helpCount == 1,
  "START directly opens item help")
fieldGame.stack:pop()
eq(joined(fieldGame.save.bagOrder), beforeHelpOrder,
  "START help never reorders items")
sameInventory(fieldGame.save.inventory, untouched,
  "START help preserves item counts")

-- SELECT alone provides the classic mark/place gesture.
tap(bag, "select")
eq(bag.swapIndex, 1, "first SELECT marks the current pocket row")
tap(bag, "down")
tap(bag, "down")
tap(bag, "select")
eq(bag.swapIndex, nil, "second SELECT places the marked row")
eq(joined(fieldGame.save.bagOrder),
  "M_ITEM,POTION,A_ITEM,POKE_BALL,Z_ITEM,X_ATTACK,X_DEFEND",
  "SELECT swaps only the two projected pocket rows")

local actions = openActions(bag)
eq(actions.title, "ITEM ACTIONS", "English action title is localized")
eq(#actions.items, 4, "active field Bag exposes four actions")
eq(row(actions, "move").fullLabel, "MOVE ITEM",
  "move action has stable English wording")
eq(row(actions, "quick_select").fullLabel, "QUICK SELECT",
  "Quick Select action is explicit")
choose(actions, "move")
eq(bag.swapIndex, bag.index, "MOVE ITEM marks the current pocket row")
tap(bag, "b")
eq(bag.swapIndex, nil, "B cancels an action-menu move marker")
sameInventory(fieldGame.save.inventory, untouched,
  "manual move preserves item counts")

-- Closing/reopening rebuilds from persisted bagOrder, not transient rows.
fieldGame.stack:pop()
bag = pushBag(fieldGame)
eq(joined(bag.__pocketIds), "M_ITEM,A_ITEM,Z_ITEM",
  "manual order survives Bag reopen")

-- B, L and R all cancel a marked move without mutation or pocket changes.
for _, cancelKey in ipairs({ "b", "left", "right" }) do
  local before = joined(fieldGame.save.bagOrder)
  local pocketBefore = bag.__pocketIndex
  actions = openActions(bag)
  choose(actions, "move")
  tap(bag, "down")
  tap(bag, cancelKey)
  eq(bag.swapIndex, nil, cancelKey .. " clears the move marker")
  eq(joined(fieldGame.save.bagOrder), before,
    cancelKey .. " cancels without mutation")
  eq(bag.__pocketIndex, pocketBefore,
    cancelKey .. " cancellation does not switch pocket")
  eq(fieldGame.stack:top(), bag, cancelKey .. " keeps the Bag open")
end

-- A second SELECT is the explicit place key after marking.
actions = openActions(bag)
choose(actions, "move")
tap(bag, "down")
tap(bag, "select")
eq(joined(bag.__pocketIds), "A_ITEM,M_ITEM,Z_ITEM",
  "second SELECT places the marked row")

-- Favorite assignment is reached through the optional action, not through
-- SELECT. It is immediate: the 6.5.5 overworld has one favorite tool rather
-- than exposing the legacy four-direction picker.
actions = openActions(bag)
choose(actions, "quick_select")
eq(quickSave.favorite_tool, "ITEM:" .. bag.items[bag.index].value,
  "chosen item persists as the single favorite tool")
check(fieldGame.stack:top().__text,
  "favorite confirmation uses the normal Quick Select message")
fieldGame.stack:pop()

-- Both sorts are persistent and cannot mutate counts.
actions = openActions(bag)
choose(actions, "sort_name")
eq(joined(fieldGame.save.bagOrder),
  "A_ITEM,M_ITEM,POKE_BALL,POTION,X_ATTACK,X_DEFEND,Z_ITEM",
  "name sort rewrites the complete hidden order deterministically")
actions = openActions(bag)
choose(actions, "sort_count")
eq(joined(fieldGame.save.bagOrder),
  "POKE_BALL,X_ATTACK,POTION,X_DEFEND,A_ITEM,M_ITEM,Z_ITEM",
  "count sort rewrites the complete hidden order deterministically")
sameInventory(fieldGame.save.inventory, untouched,
  "move/register/sorts preserve every item count")

-- An inactive registration option removes only that field action.
fieldGame.save.options.modOptions[mod.id].quick_select_registration = false
actions = openActions(bag)
eq(#actions.items, 3, "inactive Quick Select leaves move and both sorts")
check(row(actions, "quick_select") == nil,
  "inactive Quick Select is not offered")
fieldGame.stack:pop()
fieldGame.save.options.modOptions[mod.id].quick_select_registration = true

-- Battle Bag: never exposes registration; move and sort are pure UI/order
-- actions and therefore cannot consume an item or call battle:itemUsed.
local battleCalls = 0
local battle = { itemUsed = function() battleCalls = battleCalls + 1 end }
local battleGame = makeGame({ X_ATTACK = 2, X_DEFEND = 3 },
  { "X_ATTACK", "X_DEFEND" })
local battleBag = pushBag(battleGame, { battle = battle })
eq(battleBag.title, "BATTLE ITEMS", "battle Bag opens on battle items")
local battleCounts = inventorySnapshot(battleGame.save.inventory)
actions = openActions(battleBag)
eq(#actions.items, 3, "battle Bag exposes move plus two sorts")
check(row(actions, "quick_select") == nil,
  "battle Bag never offers Quick Select registration")
choose(actions, "move")
tap(battleBag, "down")
tap(battleBag, "a")
eq(joined(battleGame.save.bagOrder), "X_DEFEND,X_ATTACK",
  "battle move persists without using an item")
actions = openActions(battleBag)
choose(actions, "sort_name")
eq(battleCalls, 0, "move/sort consume no battle turn")
sameInventory(battleGame.save.inventory, battleCounts,
  "battle move/sort consume no item")

-- Empty and single-row pockets remain fully operable.
local emptyGame = makeGame({}, {})
local emptyBag = pushBag(emptyGame)
actions = openActions(emptyBag)
eq(#actions.items, 2, "empty Bag safely offers only the two sorts")
check(row(actions, "move") == nil and row(actions, "quick_select") == nil,
  "empty Bag has no item-dependent action")
choose(actions, "sort_name")
eq(joined(emptyGame.save.bagOrder), "", "empty sort is a no-op")

local singleGame = makeGame({ ONLY_ITEM = 1 }, { "ONLY_ITEM" })
local singleBag = pushBag(singleGame)
actions = openActions(singleBag)
choose(actions, "move")
tap(singleBag, "down")
tap(singleBag, "a")
eq(joined(singleGame.save.bagOrder), "ONLY_ITEM",
  "single-row move is safe and persistent")
sameInventory(singleGame.save.inventory, { ONLY_ITEM = 1 },
  "single-row move preserves count")

-- With no pending mark, B keeps the normal ListMenu ownership and exits.
local exitGame = makeGame({ ONLY_ITEM = 1 }, { "ONLY_ITEM" })
local exitBag = pushBag(exitGame)
eq(exitGame.stack:top(), exitBag, "exit witness starts in the Bag")
tap(exitBag, "b")
eq(exitGame.stack:top(), nil, "B exits the Bag when no move is pending")

-- German uses the exact requested title/full action labels and the same
-- functional registration bridge.
language = "de"
local germanGame = makeGame({ A_ITEM = 1, M_ITEM = 2 },
  { "A_ITEM", "M_ITEM" })
local germanBag = pushBag(germanGame)
actions = openActions(germanBag)
eq(actions.title, "ITEM-AKTIONEN", "German action title is localized")
eq(row(actions, "move").fullLabel, "ITEM VERSCHIEBEN",
  "German move action is localized")
eq(row(actions, "quick_select").fullLabel,
  "SCHNELLWAHL REGISTRIEREN",
  "German Quick Select action is localized")
eq(row(actions, "sort_name").fullLabel, "NACH NAME SORTIEREN",
  "German name sort is localized")
eq(row(actions, "sort_count").fullLabel, "NACH ANZAHL SORTIEREN",
  "German count sort is localized")
choose(actions, "quick_select")
eq(quickSave.favorite_tool, "ITEM:" .. germanBag.items[germanBag.index].value,
  "German action assigns the same favorite contract")
check(germanGame.stack:top().__text
    and germanGame.stack:top().text:find("Favorit", 1, true),
  "German favorite confirmation is localized")
germanGame.stack:pop()
language = "en"

print(("Bag item actions test: PASS (%d checks)"):format(checks))
