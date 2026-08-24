-- Kanto Ascendant 6.5.11 runtime-locale authority regression.
--
-- Every bundled helper must follow the translation for the active ROM
-- edition.  An unrelated German pack or the removed private language option
-- must never produce mixed-language UI inside an English Red/Blue/Yellow
-- game.  This focused test exercises visible output from all five late/early
-- installers without starting LÖVE.

local root = assert(os.getenv("TRAINER_REMATCH_MOD_DIR"),
  "TRAINER_REMATCH_MOD_DIR is required")
package.path = "./?.lua;./?/init.lua;" .. package.path

local GameVersion = require("src.core.GameVersion")
local previousEdition = GameVersion.get()
local assertions = 0

local function eq(actual, expected, message)
  assertions = assertions + 1
  assert(actual == expected, ("FAIL: %s (got %q, expected %q)")
    :format(message, tostring(actual), tostring(expected)))
end

local function check(value, message)
  assertions = assertions + 1
  assert(value, "FAIL: " .. message)
end

local function read(path)
  local file = assert(io.open(path, "rb"))
  local body = assert(file:read("*a"))
  file:close()
  return body
end

love = {
  graphics = {
    setColor = function() end,
    rectangle = function() end,
    circle = function() end,
    arc = function() end,
    polygon = function() end,
  },
}

local function installEngineStubs(draws)
  local Font = {
    draw = function(text) draws[#draws + 1] = tostring(text) end,
    drawCode = function() end,
    width = function(text) return #tostring(text or "") * 8 end,
    split = function(text)
      local out = {}
      for index = 1, #tostring(text or "") do
        out[index] = { from = index, to = index }
      end
      return out
    end,
    spansFitting = function(spans, budget)
      return math.min(#spans, math.max(0, math.floor(budget / 8)))
    end,
  }
  local Boxes = {
    COUNT = 12,
    CAPACITY = 20,
    ensure = function(save)
      save.boxes = save.boxes or {}
      for index = 1, 12 do save.boxes[index] = save.boxes[index] or {} end
      return save.boxes
    end,
    active = function(save)
      return Boxes.ensure(save)[save.currentBox or 1]
    end,
    deposit = function(save, mon)
      for index, box in ipairs(Boxes.ensure(save)) do
        if #box < 20 then
          box[#box + 1] = mon
          return index
        end
      end
      return nil
    end,
  }
  local BagMenu = {
    new = function(game)
      return { game = game, items = {}, onChoose = function() end }
    end,
  }
  local Menu = {
    new = function(game, items, opts)
      return { game = game, items = items, opts = opts }
    end,
  }
  local ListMenu = {
    new = function(game, title, items, opts)
      return { game = game, title = title, items = items, opts = opts,
        index = 1 }
    end,
  }
  local BoxMenu = {
    new = function(game)
      return { game = game, items = {}, index = 1,
        update = function() end }
    end,
  }
  local SummaryMenu = { update = function() end, draw = function() end }
  local PartyMenu = { draw = function() end }
  local TextBox = {
    new = function(_, text, done, opts)
      return {
        text = text, done = done,
        choice = opts and opts.choice,
        defaultNo = opts and opts.defaultNo,
      }
    end,
  }

  package.loaded["src.render.Font"] = Font
  package.loaded["src.render.PaletteFX"] = {
    trueColorZone = function() return {} end,
    markTrueColor = function() end,
  }
  package.loaded["src.render.TextBox"] = TextBox
  package.loaded["src.pokemon.Boxes"] = Boxes
  package.loaded["src.pokemon.Party"] = { MAX = 6 }
  package.loaded["src.ui.Theme"] = {
    cursor = ">", cursorHollow = "o", moreArrow = "v",
  }
  package.loaded["src.core.Strings"] = function(format, ...)
    return string.format(format, ...)
  end
  package.loaded["src.core.Sound"] = { play = function() end }
  package.loaded["src.ui.BagMenu"] = BagMenu
  package.loaded["src.ui.Menu"] = Menu
  package.loaded["src.ui.ListMenu"] = ListMenu
  package.loaded["src.ui.BoxMenu"] = BoxMenu
  package.loaded["src.ui.SummaryMenu"] = SummaryMenu
  package.loaded["src.ui.PartyMenu"] = PartyMenu
  return {
    Boxes = Boxes,
    Menu = Menu,
    SummaryMenu = SummaryMenu,
  }
end

local exactPack = {
  red = "deutsch", blue = "deutsch-blau", yellow = "deutsch-gelb",
}
local wrongPack = {
  red = "deutsch-blau", blue = "deutsch-gelb", yellow = "deutsch",
}

local function runCase(edition, case)
  GameVersion.set(edition)
  local draws, handlers, screens = {}, {}, {}
  local engine = installEngineStubs(draws)
  local installed = {}
  for _, id in ipairs(case.mods or {}) do installed[id] = true end
  local optionValues = {
    language = case.stale and "de" or nil,
    ascendant_useful_bag = false,
    modern_storage_ui = true,
    status_values = "dv",
    catch_destination = "ask",
  }
  local saved = {}
  local mod = {
    id = "kanto_ascendant",
    exports = {},
    find = function(id) return installed[id] and { id = id } or nil end,
    options = { get = function(_, key) return optionValues[key] end },
    save = {
      get = function(_, key) return saved[key] end,
      set = function(_, key, value) saved[key] = value end,
    },
    hooks = { wrap = function() end },
    events = { on = function(_, name, fn) handlers[name] = fn end },
    content = { screens = { register = function(_, id, spec)
      screens[id] = spec
    end } },
    ui = {
      push = function() end,
      TextBox = package.loaded["src.render.TextBox"],
      ListMenu = { new = function(game, title, items, opts)
        return { game = game, title = title, items = items,
          onChoose = opts and opts.onChoose }
      end },
    },
    read = function() return nil end,
  }

  local i18n = assert(loadfile(root .. "/localization.lua"))()(mod)
  local quick = assert(loadfile(root .. "/quick_select.lua"))()(mod, {
    i18n = i18n,
  })
  assert(loadfile(root .. "/ascendant_features.lua"))()(mod, {
    i18n = i18n,
  })
  assert(loadfile(root .. "/modern_storage_ui.lua"))()(mod, {
    i18n = i18n,
  })
  assert(loadfile(root .. "/summary_insights.lua"))()(mod, {
    i18n = i18n,
  })
  assert(loadfile(root .. "/catch_destination.lua"))()(mod, {
    i18n = i18n,
  })

  local bucket = {
    language = case.stale and "de" or nil,
    catch_destination = "ask",
    -- Keep the storage helper enabled while exercising its runtime-locale
    -- authority.  Setting the saved master switch to false correctly yields
    -- to the engine-owned PC and therefore cannot test Ascendant's labels.
    modern_storage_ui = true,
    status_values = "dv",
  }
  local game = {
    data = { pokemon = { TESTMON = { name = "TESTMON" } }, moves = {} },
    save = {
      player = { name = "RED" }, party = {}, boxes = {}, currentBox = 1,
      options = { modOptions = { kanto_ascendant = bucket } },
    },
    input = { wasPressed = function() return false end },
    stack = { push = function() end, pop = function() end },
  }

  local expectedGerman = case.german == true
  local suffix = edition .. "/" .. case.id

  draws = {}
  package.loaded["src.render.Font"].draw = function(text)
    draws[#draws + 1] = tostring(text)
  end
  assert(screens.JohtoAscendantFeatures, "feature screen was not registered")
  screens.JohtoAscendantFeatures.new(game):draw()
  eq(draws[1], expectedGerman and "ASCENDANT-OPTIONEN" or "ASCENDANT OPTIONS",
    suffix .. " ascendant_features visible title")

  local pcRows = { { label = "DEPOSIT" } }
  engine.Menu.new(game, pcRows, {})
  eq(pcRows[1].label, expectedGerman and "ABLEGEN" or "DEPOSIT",
    suffix .. " modern_storage_ui visible action")

  eq(quick.toolLabel(game, "FIELD_KIT"),
    expectedGerman and "FELD-KIT" or "FIELD KIT",
    suffix .. " quick_select visible tool label")

  draws = {}
  package.loaded["src.render.Font"].draw = function(text)
    draws[#draws + 1] = tostring(text)
  end
  engine.SummaryMenu._ascendantInsightsBridge.drawValues({
    game = game,
    mon = { species = "TESTMON", dvs = {}, statExp = {} },
  })
  eq(draws[1], expectedGerman and "WERTE" or "VALUES",
    suffix .. " summary_insights visible title")

  local caught = { species = "TESTMON", level = 5 }
  game.save.party = { caught }
  local queued
  handlers["pokemon.caught"]({
    game = game, mon = caught, destination = "party",
    battle = { uiNext = function(_, factory) queued = factory end },
  })
  check(type(queued) == "function",
    suffix .. " catch_destination queues its visible prompt")
  local prompt = queued()
  local fragment = expectedGerman and "Wohin soll" or "Where should"
  check(prompt.text:find(fragment, 1, true) ~= nil,
    suffix .. " catch_destination visible prompt language")
end

for _, edition in ipairs({ "red", "blue", "yellow" }) do
  local exact, wrong = exactPack[edition], wrongPack[edition]
  local cases = {
    { id = "no_pack", mods = {}, german = false },
    { id = "exact_pack", mods = { exact }, german = true },
    { id = "wrong_pack", mods = { wrong }, german = false },
    { id = "stale_no_pack", mods = {}, stale = true, german = false },
    { id = "stale_wrong_pack", mods = { wrong }, stale = true,
      german = false },
    { id = "exact_pack_stale", mods = { exact }, stale = true,
      german = true },
  }
  for _, case in ipairs(cases) do runCase(edition, case) end
end

GameVersion.set(previousEdition)

-- Keep the production ownership seam explicit: main.lua constructs one i18n
-- object and passes that exact authority to every affected installer.
local normalizedMain = read(root .. "/main.lua"):gsub("%s+", " ")
for _, fragment in ipairs({
  "installQuickSelect(mod, { i18n = i18n })",
  "installAscendantFeatures(mod, { optionHelp = optionHelp, i18n = i18n, })",
  "installStorage(mod, { i18n = i18n })",
  "installCatchDestination(mod, { i18n = i18n })",
  "installSummaryInsights(mod, { i18n = i18n })",
}) do
  check(normalizedMain:find(fragment, 1, true) ~= nil,
    "main passes canonical runtime locale authority: " .. fragment)
end

print(("6.5.11 runtime locale authority: PASS (%d assertions)")
  :format(assertions))
