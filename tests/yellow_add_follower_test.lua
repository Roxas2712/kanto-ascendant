-- Regression for Yellow's party-menu ADD FOLLOWER action.
--
-- Yellow keeps its authored partner in follower slot 1, but the menu action
-- must still make another selected party member visible immediately. A boxed
-- or fainted partner keeps the chain hidden (native Yellow story contract),
-- so that state needs explicit feedback instead of looking like a no-op.

local root = os.getenv("TRAINER_REMATCH_MOD_DIR") or "."
local function factory(name) return assert(loadfile(root .. "/" .. name))() end

local engineRoot = os.getenv("GEN1RECOMP_ROOT")
if engineRoot then
  local version = assert(loadfile(engineRoot .. "/src/core/Version.lua"))()
  local expected = os.getenv("KA_EXPECT_ENGINE")
  assert(not expected or version.engine == expected,
    ("expected engine %s, got %s"):format(
      tostring(expected), tostring(version.engine)))
  local handle = assert(io.open(engineRoot .. "/src/ui/PartyMenu.lua", "rb"),
    "exact engine PartyMenu source missing")
  local source = handle:read("*a")
  handle:close()
  assert(source:find("entry.onSelect(mon, self.game)", 1, true),
    "exact engine does not forward the selected mon/game to follower hook")
end

local function harness(bucket)
  local partyHook
  local stack = { values = {} }
  function stack:push(value) self.values[#self.values + 1] = value end
  function stack:pop() return table.remove(self.values) end
  function stack:top() return self.values[#self.values] end

  local mod = {
    id = "kanto_ascendant",
    save = {
      get = function(_, key, default)
        local value = bucket[key]
        return value == nil and default or value
      end,
      set = function(_, key, value) bucket[key] = value end,
    },
    events = { on = function() end },
    hooks = {
      wrap = function(_, name, fn)
        if name == "ui.party.submenu" then partyHook = fn end
      end,
    },
    ui = {
      ListMenu = {
        new = function(game, title, items, opts)
          local list = { game = game, title = title, items = items, opts = opts }
          function list:close()
            if self.game.stack:top() == self then self.game.stack:pop() end
          end
          return list
        end,
      },
    },
  }
  return mod, stack, function() return partyHook end
end

local function mon(species, hp)
  return { species = species, nickname = species, hp = hp, dvs = {} }
end

local function scenario(partnerHp, boxed, language)
  local bucket = {}
  local mod, stack, getPartyHook = harness(bucket)
  local pikachu = mon("PIKACHU", partnerHp)
  local togepi = mon("TOGEPI", 20)
  local game = {
    save = {
      party = boxed and { togepi } or { pikachu, togepi },
      boxes = boxed and { { pikachu } } or {},
      options = { modOptions = {} }, flags = { EVENT_GOT_STARTER = true },
    },
    mods = { modOptions = {} },
    data = { pokemon = { PIKACHU = { name = "PIKACHU" },
                         TOGEPI = { name = "TOGEPI" } } },
    stack = stack,
  }
  local gameVersion = {
    get = function() return "yellow" end,
    isYellow = function() return true end,
  }
  local yellowPartner = { partner = function() return pikachu end }
  local messages = {}
  local textBox = {
    new = function(_, text)
      messages[#messages + 1] = text
      return { kind = "text", text = text }
    end,
  }
  local config = factory("follower_config.lua")(mod, {
    i18n = { text = function(en, de) return language == "de" and de or en end },
    gameVersion = gameVersion,
    yellowPartner = yellowPartner,
    textBox = textBox,
  })
  config.install(game, { applyConfig = function() end })
  local selection = factory("follower_selection.lua")({
    gameVersion = gameVersion,
    yellowPartner = yellowPartner,
    config = config,
  })

  local hook = assert(getPartyHook(), "party follower hook missing")
  local items = hook(function(_, current) return current end,
    game, {}, togepi, { battle = false })
  assert(items[#items]
      and items[#items].label == (language == "de" and "BEGLEITER" or "FOLLOWER"),
    "party submenu has no FOLLOWER action")
  items[#items].onSelect(togepi, game)
  local editor = assert(stack:top(), "follower editor did not open")
  assert(editor.items[1] and editor.items[1].value == "custom_add",
    "first party selection does not offer CUSTOM ADD")
  editor.opts.onChoose(editor.items[1], editor)

  assert(config.mode() == "custom", "CUSTOM ADD did not switch order mode")
  assert(config.count() == 2,
    "Yellow ADD FOLLOWER left Count=1, so partner slot 1 hid the new follower")
  assert(#config.customIds() == 1,
    "Yellow ADD FOLLOWER did not persist exactly one selected extra")
  assert(type(messages[1]) == "string" and messages[1] ~= "",
    "Yellow ADD FOLLOWER gave no explicit result feedback")
  return {
    game = game, config = config, selection = selection,
    pikachu = pikachu, togepi = togepi, message = messages[1],
  }
end

local healthy = scenario(20, false)
assert(healthy.message:find("TOGEPI is now\nfollowing you!", 1, true)
    and healthy.message:find("FOLLOWER #2", 1, true)
    and healthy.message:find("FOLLOWER #1", 1, true),
  "healthy Yellow result lacks natural confirmation/reserved partner slot")
local rows = healthy.selection.activeMany(healthy.game, healthy.config.count())
assert(#rows == 2 and rows[1].mon == healthy.pikachu
    and rows[2].mon == healthy.togepi,
  "healthy Yellow partner did not stay #1 with selected follower #2")

local fainted = scenario(0, false)
assert(#fainted.selection.activeMany(fainted.game, fainted.config.count()) == 0,
  "fainted Yellow partner was silently replaced by another follower")
assert(fainted.message:find("fit", 1, true),
  "fainted Yellow partner did not explain why the chain stays hidden")
fainted.pikachu.hp = 20
rows = fainted.selection.activeMany(fainted.game, fainted.config.count())
assert(#rows == 2 and rows[2].mon == fainted.togepi,
  "reviving Yellow partner did not reveal the saved extra follower")

local boxed = scenario(20, true)
assert(#boxed.selection.activeMany(boxed.game, boxed.config.count()) == 0,
  "boxed Yellow partner was silently replaced by another follower")
assert(boxed.message:find("in your party", 1, true),
  "boxed Yellow partner did not explain why the chain stays hidden")
table.insert(boxed.game.save.party, 1, table.remove(boxed.game.save.boxes[1], 1))
rows = boxed.selection.activeMany(boxed.game, boxed.config.count())
assert(#rows == 2 and rows[1].mon == boxed.pikachu
    and rows[2].mon == boxed.togepi,
  "withdrawing Yellow partner did not reveal the saved extra follower")

-- A save affected by the old no-op bug already contains the custom ID but
-- still has Count=1. It must be recoverable in place, without remove/re-add.
healthy.config.setCount(1)
healthy.config._openEditor(healthy.game, healthy.togepi)
local recoveryEditor = assert(healthy.game.stack:top(),
  "affected-save follower editor did not open")
assert(recoveryEditor.items[1]
    and recoveryEditor.items[1].value == "show",
  "affected save has no SHOW FOLLOWER recovery action")
recoveryEditor.opts.onChoose(recoveryEditor.items[1], recoveryEditor)
assert(healthy.config.count() == 2,
  "SHOW FOLLOWER did not repair the affected save's hidden slot")

local german = scenario(20, false, "de")
assert(german.message:find("TOGEPI folgt dir\njetzt!", 1, true)
    and german.message:find("BEGLEITER #2", 1, true)
    and german.message:find("BEGLEITER #1", 1, true),
  "German Yellow result lacks natural confirmation/both follower slots")

print("PASS Yellow ADD FOLLOWER: visible #2, EN/DE partner gate, saved recovery")
