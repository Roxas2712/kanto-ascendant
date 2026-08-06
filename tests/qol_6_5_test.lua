-- Small host-side checks for the 6.5-only option plumbing.  Engine-backed
-- renderer checks remain in the Modkit/launcher QA stages.

local assertions = 0
local function ok(value, message)
  assertions = assertions + 1
  if not value then error("FAIL: " .. message, 2) end
end

local function read(path)
  local file = assert(io.open(path, "r"))
  local body = file:read("*a")
  file:close()
  return body
end

local main = read("main.lua")
local manifest = read("manifest.json")
local featureHub = read("ascendant_features.lua")
for _, key in ipairs({
  "johto_level_bonus", "ascendant_useful_bag", "ascendant_quick_select",
  "ascendant_qol", "modern_storage_ui", "catch_destination",
  "pokedex_filter", "box_filter", "text_speed", "ride_control",
}) do
  ok(main:find('key = "' .. key .. '"', 1, true) ~= nil,
    "main options expose " .. key)
  ok(featureHub:find('key = "' .. key .. '"', 1, true) ~= nil,
    "JOHTO ASCENDANT FT. exposes " .. key)
end
ok(manifest:find('"version": "6.5.0"', 1, true) ~= nil,
  "RC manifest reports 6.5.0")

local handlers, speedValue = {}, "fast"
local mod = {
  options = { get = function() return speedValue end },
  events = { on = function(_, name, fn) handlers[name] = fn end },
}
local install = assert(loadfile("text_speed.lua"))()
install(mod)
local game = { save = { options = {} } }
handlers["game.ready"]({ game = game })
ok(game.save.options.textSpeed == 1, "FAST preset maps to one-frame text speed")
speedValue = "slow"
handlers["mod.options_changed"]({})
ok(game.save.options.textSpeed == 5,
  "options-changed reapplies text speed through the remembered game")

print(("6.5 QOL PLUMBING PASS: %d assertions"):format(assertions))

-- Catch destination: a full party catch starts in a box. Choosing PARTY must
-- offer a party replacement and swap without cloning or losing either mon.
do
  local caught = { species = "RATTATA", level = 4 }
  local oldParty = { species = "PIDGEY", level = 7 }
  local party = {
    { species = "BULBASAUR", level = 10 }, oldParty,
    { species = "CHARMANDER", level = 10 },
    { species = "SQUIRTLE", level = 10 },
    { species = "PIKACHU", level = 10 },
    { species = "CATERPIE", level = 10 },
  }
  local boxes = { { caught } }
  for i = 2, 12 do boxes[i] = {} end
  package.loaded["src.pokemon.Boxes"] = {
    CAPACITY = 20,
    ensure = function() return boxes end,
    active = function() return boxes[1] end,
  }
  package.loaded["src.pokemon.Party"] = { MAX = 6 }
  package.loaded["src.ui.ChoiceBox"] = {
    new = function(_, onChoose) return { onChoose = onChoose } end,
  }
  package.loaded["src.render.TextBox"] = {
    new = function(_, text, onDone)
      return { text = text, onDone = onDone }
    end,
  }

  local catchHandlers, pushed, queued = {}, {}, nil
  local game2 = {
    data = { pokemon = {
      RATTATA = { name = "RATTATA" }, PIDGEY = { name = "PIDGEY" },
    } },
    save = {
      party = party, boxes = boxes, currentBox = 1,
      options = { modOptions = { trainer_rematch = {
        catch_destination = "ask",
      } } },
    },
  }
  game2.stack = {
    push = function(_, value) pushed[#pushed + 1] = value end,
  }
  local catchMod = {
    id = "trainer_rematch",
    find = function() return nil end,
    options = { get = function(_, key)
      return key == "catch_destination" and "ask" or nil
    end },
    events = { on = function(_, name, fn) catchHandlers[name] = fn end },
    ui = { ListMenu = { new = function(_, _, items, opts)
      return {
        items = items, onChoose = opts.onChoose,
        close = function(self) self.closed = true end,
      }
    end } },
  }
  assert(loadfile("catch_destination.lua"))()(catchMod)
  catchHandlers["pokemon.caught"]({
    game = game2, mon = caught,
    battle = { uiNext = function(_, factory) queued = factory end },
  })
  ok(type(queued) == "function",
    "catch prompt is queued after the battle capture messages")
  local prompt = queued()
  prompt.onDone()
  local choice = pushed[#pushed]
  choice.onChoose(true)
  local replacement = pushed[#pushed]
  replacement.onChoose({ value = 2 }, replacement)
  ok(game2.save.party[2] == caught,
    "choosing PARTY replaces the selected full-party member")
  ok(boxes[1][1] == oldParty,
    "the replaced party member occupies the caught mon's box slot")
end

print(("6.5 QOL FUNCTIONAL PASS: %d assertions"):format(assertions))
