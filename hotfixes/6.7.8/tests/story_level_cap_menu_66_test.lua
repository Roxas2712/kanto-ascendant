local checks = 0
local function eq(actual, expected, label)
  checks = checks + 1
  assert(actual == expected, (label or "values differ") .. ": "
    .. tostring(actual) .. " ~= " .. tostring(expected))
end
local function ok(value, label)
  checks = checks + 1
  assert(value, label)
end

local language = "en"
local i18n = {
  text = function(en, de) return language == "de" and de or en end,
  isGerman = function() return language == "de" end,
}
local mode, editable, future = "story", true, false
local overrides = {}
local current = { id = "gym:misty", label = "MISTY", level = 21 }
local upcoming = { id = "gym:surge", label = "LT.SURGE", level = 24 }
local controller = {}
function controller.mode() return mode end
function controller.canEdit() return editable and not future end
function controller.isFutureState() return future end
function controller.currentStage() return current end
function controller.upcomingStage() return upcoming end
function controller.levelForStage(stage)
  if not stage then return nil end
  return { id = stage.id, label = stage.label,
    level = overrides[stage.id] or stage.level }
end
function controller.effective()
  if mode == "off" then return nil end
  return controller.levelForStage(current)
end
function controller.summary()
  local cap = controller.effective()
  return cap and ("CAP: %s · LV%d"):format(cap.label, cap.level) or "CAP: OFF"
end
function controller.setMode(value)
  if not controller.canEdit() then return false end
  mode = value
  return true
end
function controller.setOverride(id, level)
  if not controller.canEdit() then return false end
  overrides[id] = level
  return true
end
function controller.resetOverride(id)
  if not controller.canEdit() then return false end
  overrides[id] = nil
  return true
end
function controller.resetAll()
  if not controller.canEdit() then return false end
  overrides = {}
  return true
end

local hook
local screens = {}
local stack = { pushed = {} }
function stack:push(value) self.pushed[#self.pushed + 1] = value end
function stack:pop() self.popped = (self.popped or 0) + 1 end
function stack:top() return self.pushed[#self.pushed] end
local game = { stack = stack, input = { wasPressed = function() return false end } }
local mod = {
  hooks = { wrap = function(_, name, fn)
    if name == "ui.start_menu.items" then hook = fn end
  end },
  ui = {
    ListMenu = { new = function(_, title, items, opts)
      return { title = title, items = items, index = 1, opts = opts,
        update = function() end,
        close = function(self) self.closed = true end }
    end },
  },
  content = { screens = { register = function(_, name, def)
    screens[name] = def
  end } },
}

local menuApi = assert(loadfile("story_level_cap_menu.lua"))()(mod, {
  i18n = i18n, controller = controller,
})
eq(hook, nil, "level cap does not add a second Ascendant main-menu row")
local screenDef = screens.AscendantStoryLevelCap
ok(screenDef and type(screenDef.new) == "function",
  "level-cap editor is registered as an options screen")
local screen = screenDef.new(game)
eq(screen.title, "STORY LEVEL CAP", "English menu title")
eq(screen.items[1].label, "CAP: MISTY · LV21", "screen repeats exact cap")
eq(screen.items[2].label, "MODE", "English mode label")
eq(screen.items[3].right, "MISTY LV21", "current stage is explicit")
eq(screen.items[4].right, "LT.SURGE LV24", "upcoming stage is explicit")
eq(#stack.pushed, 0, "screen construction does not double-push itself")
menuApi.open(game)
eq(stack.pushed[#stack.pushed].title, "STORY LEVEL CAP",
  "legacy direct opener remains reachable without a duplicate gateway")
local opened = stack.pushed[#stack.pushed]
opened.index = 2
opened.opts.onChoose(opened.items[opened.index])
eq(mode, "custom", "A changes the focused level-cap mode")
opened.opts.onCancel()
eq(stack.popped, 1, "B returns from the level-cap editor")

ok(menuApi.adjust(game, { key = "current", stage = current }, 1),
  "current stage can be raised")
eq(overrides["gym:misty"], 22, "current override uses stable stage id")
ok(menuApi.adjust(game, { key = "upcoming", stage = upcoming }, -1),
  "upcoming stage can be lowered")
eq(overrides["gym:surge"], 23, "upcoming override uses stable stage id")

overrides["gym:misty"] = 100
ok(menuApi.adjust(game, { key = "current", stage = current }, 1),
  "upper-bound edit is accepted")
eq(overrides["gym:misty"], 100, "override is clamped to level 100")
overrides["gym:surge"] = 1
menuApi.adjust(game, { key = "upcoming", stage = upcoming }, -1)
eq(overrides["gym:surge"], 1, "override is clamped to level 1")
ok(menuApi.activate(game, { key = "reset_current", stage = current }),
  "reset current action succeeds")
eq(overrides["gym:misty"], nil, "reset current leaves upcoming intact")
ok(menuApi.activate(game, { key = "reset_all" }), "reset-all action succeeds")
eq(next(overrides), nil, "reset all clears every stable-id override")

editable = false
eq(menuApi.adjust(game, { key = "mode" }, 1), false,
  "battle lock blocks menu changes")
eq(mode, "custom", "blocked edit leaves mode untouched")
editable, future = true, true
eq(menuApi.adjust(game, { key = "current", stage = current }, 1), false,
  "future schema is read-only in menu")
eq(overrides["gym:misty"], nil, "future edit writes no override")
future = false

language = "de"
mode = "off"
local rows = menuApi.rows(game)
eq(rows[1].label, "CAP: AUS", "German OFF summary")
eq(rows[2].label, "MODUS", "German mode label")
eq(rows[3].label, "AKTUELL", "German current label")
eq(rows[6].label, "ALLE ZURÜCKSETZEN", "German reset-all label")

print(("story_level_cap_menu_66_test: PASS checks=%d"):format(checks))
