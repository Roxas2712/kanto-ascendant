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
local mainKeys = {
  "johto_level_bonus", "ascendant_useful_bag", "ascendant_quick_select",
  "ascendant_qol", "modern_storage_ui", "catch_destination",
  "pokedex_filter", "box_filter", "text_speed", "ride_control",
  "pokemon_sprite_style", "sprite_style_battle", "sprite_style_summary",
  "sprite_style_dex", "sprite_style_box", "sprite_style_scenes",
  "ascendant_bag_mode", "party_icon_style", "catch_box_notice",
  "quick_select_tap", "quick_select_registration",
  "quick_select_empty_notice", "status_values", "modern_ball_skins",
  "fast_box_switch", "language",
}
for _, key in ipairs(mainKeys) do
  ok(main:find('key = "' .. key .. '"', 1, true) ~= nil,
    "main options expose " .. key)
end
for _, key in ipairs({
  "johto_level_bonus", "ascendant_quick_select", "ascendant_qol",
  "modern_storage_ui", "catch_destination", "pokedex_filter", "box_filter",
  "text_speed", "ride_control", "pokemon_sprite_style",
  "sprite_style_battle", "sprite_style_summary", "sprite_style_dex",
  "sprite_style_box", "sprite_style_scenes", "ascendant_bag_mode",
  "party_icon_style", "catch_box_notice", "quick_select_tap",
  "quick_select_registration", "quick_select_empty_notice", "status_values",
  "modern_ball_skins", "fast_box_switch", "qol_exp_bar",
  "qol_caught_indicator", "qol_easy_interactions",
  "qol_location_banners", "language",
}) do
  ok(featureHub:find('key = "' .. key .. '"', 1, true) ~= nil,
    "Ascendant Options exposes " .. key)
end
ok(manifest:find('"version": "6.5.0"', 1, true) ~= nil,
  "RC manifest reports 6.5.0")
ok(featureHub:find('drawFrame(Font, tr("ASCENDANT OPTIONS"', 1, true) ~= nil,
  "nested screen is branded for Kanto Ascendant")
ok(read("ascendant_menu.lua"):find('tr("OPTIONS", "OPTIONEN")', 1, true)
    ~= nil, "Ascendant Start-menu tree owns the Options entry")

local kinds = assert(loadfile("german_dex_kinds.lua"))()
local kindCount = 0
for _ in pairs(kinds) do kindCount = kindCount + 1 end
ok(kindCount == 151, "all 151 German Kanto categories are restored")
ok(kinds.GROWLITHE == "WELPEN",
  "FUKANO is no longer assigned SEEHUND")

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

  local caught2 = { species = "RATTATA", level = 5 }
  table.insert(game2.save.party, caught2)
  game2.save.options.modOptions.trainer_rematch.catch_destination = "box"
  game2.save.options.modOptions.trainer_rematch.catch_box_notice = true
  queued = nil
  catchHandlers["pokemon.caught"]({
    game = game2, mon = caught2,
    battle = { uiNext = function(_, factory) queued = factory end },
  })
  ok(type(queued) == "function",
    "direct BOX mode queues a transfer announcement")
  ok(queued().text:find("BOX 1", 1, true) ~= nil,
    "direct BOX announcement identifies the destination box")
end

print(("6.5 QOL FUNCTIONAL PASS: %d assertions"):format(assertions))
