-- Regression for the 6.7 protected-release list/controller mismatch.
-- Modern Storage is installed before the Shiny System wraps Bill's PC, just
-- as it is in main.lua.  The release screen must remain a vertical ListMenu;
-- the storage grid owns only the native BOX/PARTY transfer screens.

package.path = "./?.lua;./?/init.lua;" .. package.path

local assertions = 0
local function eq(actual, expected, message)
  assertions = assertions + 1
  assert(actual == expected, (message or "values differ") .. ": "
    .. tostring(actual) .. " ~= " .. tostring(expected))
end
local function ok(value, message)
  assertions = assertions + 1
  assert(value, message)
end

love = { graphics = {
  setColor = function() end, rectangle = function() end,
  circle = function() end, arc = function() end, polygon = function() end,
} }

package.loaded["src.render.Font"] = {
  width = function(value) return #tostring(value or "") * 8 end,
  split = function(value)
    local out = {}
    for index = 1, #tostring(value or "") do
      out[index] = { from = index, to = index }
    end
    return out
  end,
  spansFitting = function(spans, budget)
    return math.min(#spans, math.floor((budget or 0) / 8))
  end,
  draw = function() end, drawCode = function() end,
}
package.loaded["src.core.Strings"] = function(value, ...)
  return select("#", ...) > 0 and tostring(value):format(...) or tostring(value)
end
package.loaded["src.ui.Theme"] = { cursor = 1, cursorHollow = 2, moreArrow = 3 }
package.loaded["src.render.PaletteFX"] = {
  trueColorZone = function() return { colors = false } end,
}

local Input = {}
Input.__index = Input
function Input.new() return setmetatable({ pressed = {} }, Input) end
function Input:queue(action) self.pressed[action] = true end
function Input:wasPressed(action) return self.pressed[action] == true end
function Input:isDown() return false end
function Input:finish() self.pressed = {} end
function Input:gamepad(button)
  self:queue(assert(({ dpup = "up", dpdown = "down",
    dpleft = "left", dpright = "right" })[button]))
end
function Input:touch(direction) self:queue(direction) end

local function syncScroll(menu)
  if menu.index - menu.scroll > menu.rows then
    menu.scroll = menu.index - menu.rows
  end
  if menu.index - menu.scroll < 1 then menu.scroll = menu.index - 1 end
end

-- Minimal engine ListMenu authority: adjacent up/down navigation, six-row
-- scroll synchronization after KASC decorates it, and unchanged A/B behavior.
local ListMenu = {}
function ListMenu.new(game, title, items, opts)
  opts = opts or {}
  local menu = {
    game = game, title = title, items = items or {}, index = 1, scroll = 0,
    rows = opts.rows or 7, pageJump = opts.pageJump,
    onChoose = opts.onChoose, onCancel = opts.onCancel,
  }
  function menu:update()
    local input, count = self.game.input, #self.items
    if count == 0 then
      if input:wasPressed("a") or input:wasPressed("b") then
        self.game.stack:pop()
        if self.onCancel then self.onCancel() end
      end
      return
    end
    if input:wasPressed("up") then
      self.index = math.max(1, self.index - 1)
    elseif input:wasPressed("down") then
      self.index = math.min(count, self.index + 1)
    elseif self.pageJump and input:wasPressed("left") then
      self.index = math.max(1, self.index - self.rows)
    elseif self.pageJump and input:wasPressed("right") then
      self.index = math.min(count, self.index + self.rows)
    elseif input:wasPressed("b") then
      self.game.stack:pop()
      if self.onCancel then self.onCancel() end
      return
    elseif input:wasPressed("a") then
      if self.onChoose then self.onChoose(self.items[self.index], self) end
      return
    end
    syncScroll(self)
  end
  function menu:removeCurrent()
    table.remove(self.items, self.index)
    self.index = math.max(1, math.min(self.index, #self.items))
  end
  function menu:close()
    if self.game.stack:top() == self then self.game.stack:pop() end
  end
  return menu
end
package.loaded["src.ui.ListMenu"] = ListMenu

local boxes = {}
package.loaded["src.pokemon.Boxes"] = {
  COUNT = 12,
  active = function(gameSave) return gameSave.box end,
  ensure = function(gameSave) return gameSave.boxes or {} end,
}

local BoxMenu = {}
function BoxMenu.new(game)
  return {
    game = game,
    items = { { label = "WITHDRAW" }, { label = "DEPOSIT" },
      { label = "RELEASE" } },
    update = function() end,
  }
end
package.loaded["src.ui.BoxMenu"] = BoxMenu
package.loaded["src.ui.SummaryMenu"] = { draw = function() end }

local TextBox = {}
function TextBox.new(_, text, onDone)
  return { kind = "text", text = text, onDone = onDone }
end
package.loaded["src.render.TextBox"] = TextBox

local ChoiceBox = {}
function ChoiceBox.new(_, choose, opts)
  return { kind = "choice", choose = choose, opts = opts }
end
package.loaded["src.ui.ChoiceBox"] = ChoiceBox

local cries = 0
package.loaded["src.core.Sound"] = {
  playCry = function() cries = cries + 1 end,
}

local saveBucket = {}
local mod = {
  id = "kanto_ascendant",
  exports = {},
  options = { get = function(_, key)
    if key == "modern_storage_ui" then return true end
    if key == "shiny_protection" then return false end
    return nil
  end },
  find = function() return nil end,
  save = {
    get = function(_, key) return saveBucket[key] end,
    set = function(_, key, value) saveBucket[key] = value end,
  },
  events = { on = function() end },
  hooks = { wrap = function() end },
  ui = { ListMenu = ListMenu, insertBefore = function(items) return items end },
}

-- Real installation order: shared KASC list facade, then mods.loaded storage
-- wrapper, then per-game Shiny System BoxMenu wrapper.
local ui = assert(loadfile("ascendant_ui.lua"))()(mod)
mod.ui.KantoListMenu = ui.ListMenu
assert(loadfile("modern_storage_ui.lua"))()(mod)
local shiny = assert(loadfile("shiny_system.lua"))()(mod)

local function makeMons(count)
  local out = {}
  for index = 1, count do
    out[index] = { species = "MON" .. index, nickname = "MON" .. index,
      level = index, dvs = {} }
  end
  return out
end

local function newGame(count)
  local game = {
    input = Input.new(),
    save = { box = makeMons(count), currentBox = 1,
      options = { modOptions = { kanto_ascendant = {} } } },
    data = { pokemon = {} },
    writes = 0,
  }
  for index = 1, count do
    game.data.pokemon["MON" .. index] = { name = "MON" .. index }
  end
  game.stack = { states = {} }
  function game.stack:push(screen) self.states[#self.states + 1] = screen end
  function game.stack:pop() return table.remove(self.states) end
  function game.stack:top() return self.states[#self.states] end
  function game:writeSave() self.writes = self.writes + 1 end
  return game
end

shiny.install(newGame(0))

local function openRelease(game)
  local root = BoxMenu.new(game)
  root.items[3].onSelect()
  return game.stack:top()
end

local function press(menu, source, direction)
  if source == "controller" then
    menu.game.input:gamepad(({ up = "dpup", down = "dpdown",
      left = "dpleft", right = "dpright" })[direction])
  else
    menu.game.input:touch(direction)
  end
  menu:update(0)
  menu.game.input:finish()
end

-- Empty boxes retain the existing explanatory TextBox and never construct a
-- selectable release screen.
local emptyGame = newGame(0)
local empty = openRelease(emptyGame)
eq(empty.kind, "text", "empty box keeps release explanation")
ok(empty.text:find("no POKéMON", 1, true) ~= nil,
  "empty-box explanation remains specific")

-- Small lists use adjacent vertical navigation. Horizontal input must not
-- accidentally retain the underlying storage-grid controller.
local smallGame = newGame(3)
local small = openRelease(smallGame)
eq(small.rows, 6, "release list keeps the six-row viewport")
eq(small.__ascendantBoxGrid, nil,
  "protected release list is not claimed as a storage grid")
press(small, "controller", "down")
eq(small.index, 2, "controller Down selects the adjacent Pokemon")
press(small, "touch", "down")
eq(small.index, 3, "touch Down selects the adjacent Pokemon")
press(small, "controller", "up")
eq(small.index, 2, "controller Up selects the adjacent Pokemon")
press(small, "touch", "up")
eq(small.index, 1, "touch Up selects the adjacent Pokemon")
press(small, "controller", "right")
eq(small.index, 1, "horizontal controller input does not drive a vertical list")
press(small, "touch", "left")
eq(small.index, 1, "horizontal touch input does not drive a vertical list")
eq(small.scroll, 0, "small list never scrolls")

-- Long lists advance one row, scroll exactly when the seventh row is chosen,
-- and keep the selected cursor inside the visible six-row window in both
-- directions and for both input sources.
local longGame = newGame(10)
local long = openRelease(longGame)
for _ = 1, 3 do press(long, "controller", "down") end
for _ = 1, 3 do press(long, "touch", "down") end
eq(long.index, 7, "six Down presses select the seventh Pokemon")
eq(long.scroll, 1, "seventh Pokemon scrolls the six-row window once")
ok(long.index > long.scroll and long.index <= long.scroll + long.rows,
  "selected cursor remains visible after downward scroll")
press(long, "touch", "up")
eq(long.index, 6, "Up returns to the previous Pokemon")
eq(long.scroll, 1, "window remains stable while cursor is still visible")
for _ = 1, 5 do press(long, "controller", "up") end
eq(long.index, 1, "repeated Up reaches the first Pokemon")
eq(long.scroll, 0, "upward navigation restores the first window")
ok(long.index > long.scroll and long.index <= long.scroll + long.rows,
  "selected cursor remains visible after upward scroll")

-- Confirmation remains default-NO, mutates neither box nor saves on decline,
-- and removes exactly the selected Pokemon on acceptance. Release has never
-- forced a disk save; preserve that behavior.
for _ = 1, 6 do press(long, "controller", "down") end
local selected = longGame.save.box[7]
long.onChoose(long.items[long.index], long)
local warning = longGame.stack:top()
eq(warning.kind, "text", "release still opens the irreversible warning")
warning.onDone()
local declined = longGame.stack:top()
eq(declined.opts.defaultNo, true, "release confirmation still defaults to NO")
declined.choose(false)
eq(#longGame.save.box, 10, "declining release preserves the box")
eq(longGame.writes, 0, "declining release does not write the save")

long.onChoose(long.items[long.index], long)
longGame.stack:top().onDone()
longGame.stack:top().choose(true)
eq(#longGame.save.box, 9, "confirming release removes one boxed Pokemon")
ok(longGame.save.box[7] ~= selected,
  "confirmation removes the highlighted Pokemon, not another row")
eq(#long.items, 9, "visible release rows stay aligned with the box")
eq(long.index, 7, "cursor remains on the successor after release")
ok(long.index > long.scroll and long.index <= long.scroll + long.rows,
  "cursor remains visible after confirmed release")
eq(cries, 1, "confirmed release plays exactly one cry")
eq(longGame.writes, 0, "confirmed release preserves deferred save behavior")

print(("PASS release menu scroll 6.7: %d assertions"):format(assertions))
