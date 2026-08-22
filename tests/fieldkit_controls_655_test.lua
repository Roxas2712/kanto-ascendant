-- 6.5.5 SELECT ownership regression: one touch/controller-safe dispatcher
-- distinguishes tap from hold, persists one favorite tool and is never
-- pre-empted by the legacy bicycle wrapper.

local root = os.getenv("TRAINER_REMATCH_MOD_DIR") or "."
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

local Menu = {}
local canonicalItemUses = {}
local BagMenu = {
  new = function(game)
    local list = {
      game = game,
      items = {
        { value = "BICYCLE" }, { value = "ITEMFINDER" },
      },
    }
    list.onChoose = function(row)
      game.stack:push(setmetatable({
        items = {
          { onSelect = function()
              local reason = row.value == "BICYCLE"
                and "no_place" or "nothing"
              canonicalItemUses[#canonicalItemUses + 1] = {
                id = row.value, reason = reason,
              }
              game.stack:push({ canonicalItemReason = reason })
            end },
          {},
        },
      }, Menu))
    end
    return list
  end,
}
package.loaded["src.ui.BagMenu"] = BagMenu
package.loaded["src.ui.Menu"] = Menu

local saved = {}
local options = {
  ascendant_quick_select = true,
  quick_select_tap = "bicycle",
  quick_select_empty_notice = true,
  ride_control = "select",
}
local hooks = {}
local activateCalls, openCalls = {}, 0
local mod = {
  id = "kanto_ascendant",
  exports = {},
  find = function() return nil end,
  options = { get = function(_, key) return options[key] end },
  save = {
    get = function(_, key) return saved[key] end,
    set = function(_, key, value) saved[key] = value end,
  },
  hooks = { wrap = function(_, name, fn, priority)
    if name == "input.step" then hooks[priority] = fn end
  end },
  ui = {
    TextBox = { new = function(_, text) return { text = text } end },
  },
}

local englishI18n = {
  isGerman = function() return false end,
  text = function(en) return en end,
}
local quick = assert(loadfile(root .. "/quick_select.lua"))()(mod, {
  i18n = englishI18n,
})
mod.exports.quickSelect = quick
mod.exports.fieldTech = {
  open = function() openCalls = openCalls + 1 end,
  activate = function(_, moveId)
    activateCalls[#activateCalls + 1] = moveId
    return moveId ~= "SURF", moveId == "SURF" and "no_water" or nil
  end,
}
assert(loadfile(root .. "/bicycle_select.lua"))()(mod, {
  i18n = { text = function(en) return en end },
})
check(type(hooks[500]) == "function" and type(hooks[120]) == "function",
  "both input wrappers installed for the ownership regression")

local states = {}
local overworld = {
  map = { id = "ROUTE_1", def = { tileset = "OVERWORLD" } },
  player = { moving = false, inputLocked = false },
  scriptMoves = {},
}
local game = {
  overworld = overworld,
  save = {
    inventory = { FIELD_KIT = 1, BICYCLE = 1, ITEMFINDER = 1 },
    options = { modOptions = { [mod.id] = options } },
  },
  input = { state = {}, pressQueue = {} },
}
game.stack = {
  states = states,
  top = function() return states[#states] end,
  push = function(_, state) states[#states + 1] = state end,
  pop = function() return table.remove(states) end,
}
states[1] = overworld

local function step(dt)
  hooks[500](function(stepGame, stepDt)
    hooks[120](function() end, stepGame, stepDt)
  end, game, dt or 0)
end
local function press(down)
  game.input.state.select = down == true
  game.input.pressQueue[#game.input.pressQueue + 1] = "select"
end
local function release()
  game.input.state.select = false
end

check(quick.setFavorite("FIELD:CUT"), "favorite CUT can be assigned")
eq(quick.favorite(game), "FIELD:CUT", "favorite persists in mod save")

-- A normal controller tap arms on press and fires exactly once on release.
press(true)
step(0.10)
eq(#activateCalls, 0, "tap does not fire before release")
release()
step(0.01)
eq(#activateCalls, 1, "tap activates one favorite tool")
eq(activateCalls[1], "CUT", "tap routes through Field Kit CUT authority")
check(not game.save.onBike, "legacy bicycle wrapper did not steal SELECT")

-- Holding crosses one explicit time threshold, opens once, and suppresses
-- touch/key-repeat edges until the physical control is released.
press(true)
step(0.10)
step(0.26)
eq(openCalls, 1, "hold opens the Field Kit at the threshold")
press(true) -- synthetic touch/controller repeat while still held
step(0.50)
eq(openCalls, 1, "held repeat cannot open a second Field Kit")
release()
step(0.01)
eq(#activateCalls, 1, "hold release never also fires the favorite")

-- A tap that begins and ends between fixed updates is represented by one
-- queued edge with no down state and must still work once.
press(false)
step(0.01)
eq(#activateCalls, 2, "between-frame touch tap activates exactly once")

-- No A+SELECT chord exists. An unrelated A edge remains available to the
-- normal owner while SELECT alone performs the favorite action.
game.input.pressQueue = { "select", "a" }
game.input.state.select = false
step(0.01)
eq(#activateCalls, 3, "SELECT requires no A chord")
eq(table.concat(game.input.pressQueue, ","), "a",
  "quick dispatcher consumes only its SELECT edge")
game.input.pressQueue = {}

-- Menus own their own SELECT. The overworld dispatcher and legacy bicycle
-- wrapper both leave the edge untouched when the overworld is not on top.
local menu = {}
states[#states + 1] = menu
press(false)
step(0.01)
eq(table.concat(game.input.pressQueue, ","), "select",
  "menu SELECT is not consumed by an overworld shortcut")
states[#states] = nil
game.input.pressQueue = {}

-- Invalid-context reasons come from the canonical Field Kit implementation,
-- rather than a duplicated shortcut-specific move implementation.
local ok, reason = quick.activateTool(game, "FIELD:SURF")
eq(ok, false, "invalid SURF context is rejected")
eq(reason, "no_water", "invalid SURF reason is preserved")

-- Bicycle and Itemfinder favorites enter the canonical Bag USE path. The
-- shortcut contains no second copy of their map/context policy, so the
-- canonical invalid-context result remains authoritative.
quick.activateTool(game, "ITEM:BICYCLE")
eq(canonicalItemUses[#canonicalItemUses].id, "BICYCLE",
  "Bicycle favorite delegates to canonical Bag USE")
eq(canonicalItemUses[#canonicalItemUses].reason, "no_place",
  "Bicycle invalid-context result stays canonical")
states[#states] = nil
quick.activateTool(game, "ITEM:ITEMFINDER")
eq(canonicalItemUses[#canonicalItemUses].id, "ITEMFINDER",
  "Itemfinder favorite delegates to canonical Bag USE")
eq(canonicalItemUses[#canonicalItemUses].reason, "nothing",
  "Itemfinder no-result context stays canonical")
states[#states] = nil

-- Old tap preferences migrate once without erasing an explicit favorite.
saved.favorite_tool = nil
saved.favorite_tool_version = nil
options.quick_select_tap = "field_kit"
eq(quick.favorite(game), "FIELD_KIT", "legacy FIELD KIT tap migrates")
quick.setFavorite("FIELD:FLY")
options.quick_select_tap = "bicycle"
eq(quick.favorite(game), "FIELD:FLY",
  "later option reads cannot overwrite an assigned favorite")

-- A fresh runtime instance reads the same explicit favorite without running
-- migration again, which is the save/reload boundary used by the real mod.
local reloadHooks = {}
local reloadedMod = {
  id = mod.id, exports = {}, find = mod.find, options = mod.options,
  save = mod.save, ui = mod.ui,
  hooks = { wrap = function(_, name, fn, priority)
    if name == "input.step" then reloadHooks[priority] = fn end
  end },
}
local reloaded = assert(loadfile(root .. "/quick_select.lua"))()(reloadedMod, {
  i18n = englishI18n,
})
eq(reloaded.favorite(game), "FIELD:FLY",
  "favorite survives a clean runtime reload")
check(type(reloadHooks[500]) == "function",
  "reloaded runtime reinstalls its one dispatcher")

print(("6.5.5 Field Kit controls test: PASS (%d checks)"):format(checks))
