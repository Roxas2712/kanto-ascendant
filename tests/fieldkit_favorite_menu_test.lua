-- Focused Field Kit menu contract: A uses, SELECT assigns, B owns cancel.

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
local function findRow(rows, value)
  for _, row in ipairs(rows or {}) do
    if row.value == value then return row end
  end
end

local isOutside = false
package.loaded["src.world.Map"] = {
  isOutside = function() return isOutside end,
}
local screenPushes = {}
package.loaded["src.ui.Screens"] = {
  push = function(_, screen, opts)
    screenPushes[#screenPushes + 1] = { screen = screen, opts = opts }
  end,
}
package.loaded["src.render.TextBox"] = {
  new = function(_, text, done) return { text = text, onDone = done } end,
}

local saved = {
  field_tech = {
    version = 2, kit = true, rematchWins = 1, tmWins = 0,
    tmCursor = 0, tmCycles = 0, signatureUnlocked = {},
    signatureAwarded = {}, pendingTMs = {}, archivedTMs = {},
    archiveSeeded = true,
  },
}
local favorite = "ITEM:ITEMFINDER"
local activated
local menuOpts
local mod = {
  exports = {
    quickSelect = {
      favorite = function() return favorite end,
      setFavorite = function(toolId) favorite = toolId; return true end,
      activateTool = function(_, toolId) activated = toolId; return true end,
    },
  },
  save = {
    get = function(_, key) return saved[key] end,
    set = function(_, key, value) saved[key] = value end,
  },
  hooks = { wrap = function() end },
  content = {
    moves = { register = function() end },
    items = { register = function() end },
    pokemon = {
      get = function() return nil end,
      patch = function() end,
    },
  },
  ui = {
    KantoListMenu = { new = function(game, title, rows, opts)
      menuOpts = opts
      local menu = {
        game = game, title = title, items = rows,
        close = function(self) self.closed = true end,
      }
      menu.onChoose = opts.onChoose
      menu.onSelectKey = opts.onSelectKey
      menu.onCancel = opts.onCancel
      menu.footer = opts.footer
      return menu
    end },
  },
}

local fieldTech = assert(loadfile(root .. "/field_tech.lua"))()(mod, {
  i18n = { text = function(en) return en end },
})
local states = {}
local game = {
  data = {
    items = {
      BICYCLE = { name = "BICYCLE" },
      ITEMFINDER = { name = "ITEMFINDER" },
    },
    moves = {
      CUT = { name = "CUT" }, FLY = { name = "FLY" },
      SURF = { name = "SURF" }, STRENGTH = { name = "STRENGTH" },
      FLASH = { name = "FLASH" },
    },
    field = { outsideTilesets = { "OVERWORLD" } },
  },
  save = {
    inventory = {
      FIELD_KIT = 1,
      HM_CUT = 1, CASCADEBADGE = 1,
      HM_FLY = 1, THUNDERBADGE = 1,
      HM_SURF = 1, SOULBADGE = 1,
      BICYCLE = 1, ITEMFINDER = 1,
    },
  },
  overworld = {
    map = { id = "ROUTE_1", def = { tileset = "OVERWORLD" } },
    player = {},
    useCutFieldMove = function() return "nothing" end,
    useSurfFieldMove = function() return "no_water" end,
  },
}
game.stack = {
  push = function(_, state) states[#states + 1] = state end,
  pop = function() return table.remove(states) end,
  top = function() return states[#states] end,
}

local cancelled = 0
fieldTech.open(game, function() cancelled = cancelled + 1 end)
local menu = states[#states]
eq(menu.title, "FIELD KIT", "Field Kit opens its full tool menu")
check(menu.footer:find("SEL:FAV", 1, true),
  "footer documents SELECT favorite assignment")
check(type(menuOpts.onCancel) == "function", "B cancel owner is installed")
local cut = findRow(menu.items, "CUT")
local fly = findRow(menu.items, "FLY")
local bike = findRow(menu.items, "BICYCLE")
local finder = findRow(menu.items, "ITEMFINDER")
check(cut and fly and bike and finder,
  "full kit lists unlocked modules even when one is invalid here")
eq(finder.right, "FAV.", "persisted favorite is marked on open")

menu.onSelectKey(cut, menu)
eq(favorite, "FIELD:CUT", "SELECT assigns the highlighted Field Kit module")
eq(cut.right, "FAV.", "favorite marker moves to the assigned module")
eq(finder.right, nil, "old favorite marker is cleared")
check(states[#states].text:find("favorite", 1, true),
  "assignment confirmation is explicit")
states[#states] = nil

menu.onChoose(bike, menu)
eq(activated, "ITEM:BICYCLE", "A routes utility tool use to Quick Select")
check(menu.closed, "using a utility tool closes the Field Kit menu")
menu.onCancel()
eq(cancelled, 1, "B runs the caller's normal cancel callback")

-- Direct favorite activation uses the exact same field-policy functions as
-- A in this menu and returns their canonical failure reason to its caller.
local ok, reason = fieldTech.activate(game, "CUT")
eq(ok, false, "CUT favorite rejects an invalid facing tile")
eq(reason, "nothing", "CUT favorite preserves the canonical reason")
states[#states] = nil
ok, reason = fieldTech.activate(game, "SURF")
eq(ok, false, "SURF favorite rejects a non-water facing tile")
eq(reason, "no_water", "SURF favorite preserves the canonical reason")
states[#states] = nil
isOutside = false
ok, reason = fieldTech.activate(game, "FLY")
eq(ok, false, "FLY favorite rejects an ordinary interior")
eq(reason, "restricted", "FLY favorite preserves the canonical reason")
states[#states] = nil
isOutside = true
ok = fieldTech.activate(game, "FLY")
eq(ok, true, "FLY favorite remains usable outside")
eq(screenPushes[#screenPushes].screen, "TownMap",
  "valid FLY opens the canonical Town Map")

print(("Field Kit favorite menu test: PASS (%d checks)"):format(checks))
