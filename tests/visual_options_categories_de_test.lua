-- German exact-engine acceptance for the focused VISUALS submenus.

package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local Version = require("src.core.Version")
local modPath = os.getenv("TRAINER_REMATCH_MOD_DIR")
  or "mods/kanto_ascendant"

local savedEngine = Version.engine
if Version.engine == "0.0.0-dev" then
  Version.engine = os.getenv("KASC_TEST_ENGINE_VERSION") or "0.1.96"
end
local Data = T.fixtures.load()
local sdkOpts = { data = Data }
if modPath:sub(1, 1) == "/" then sdkOpts.root = "/" end
local run = T.sdk.loadMods({
  modPath .. "/tests/fixtures/language_mods/deutsch", modPath,
}, sdkOpts)
Version.engine = savedEngine

local unexpected = {}
for _, message in ipairs(run.errors) do
  message = tostring(message)
  if not message:find("asset transform failed", 1, true) then
    unexpected[#unexpected + 1] = message
  end
end
T.eq(#unexpected, 0,
  "German fixture and Kanto Ascendant load without unexpected errors")

local modId = "kanto_ascendant"
local stack = { states = {} }
function stack:push(value) self.states[#self.states + 1] = value end
function stack:pop() return table.remove(self.states) end
function stack:top() return self.states[#self.states] end

local pressed
local game = {
  data = Data,
  input = {
    wasPressed = function(_, key)
      local hit = pressed == key
      if hit then pressed = nil end
      return hit
    end,
    isDown = function() return false end,
  },
  mods = run.loader,
  save = {
    options = { modOptions = { [modId] = {} } },
    party = {}, inventory = {}, pcItems = {}, flags = {}, modData = {},
    player = { name = "ROT" },
  },
  stack = stack,
  writeOptions = function() return true end,
}

local root = assert(Data.screens.AscendantVisualOptions.new(game, {}))
T.eq(root.title, "GRAFIK", "German Visuals root title is localized")
T.eq(root.items[1].label, "POKéMON-SPRITES",
  "German Pokémon subgroup is explicit")
T.eq(root.items[1].screen, "AscendantPokemonSpriteOptions",
  "German Pokémon subgroup keeps the canonical route")
T.eq(root.items[2].label, "FIGUREN / TRAINER",
  "German character/trainer subgroup is explicit")
T.eq(root.items[2].screen, "AscendantCharacterTrainerOptions",
  "German character/trainer subgroup keeps the canonical route")
T.check(root.items[1].help:find("Globale Pokémon", 1, true) ~= nil,
  "German Pokémon subgroup has localized SELECT help")

local qol = assert(Data.screens.AscendantQolOptions.new(game, {}))
local qolLabels = {}
for _, item in ipairs(qol.items) do qolLabels[item.value] = item.label end
T.eq(qolLabels.qol_exp_bar, "KAMPF-EP-LEISTE",
  "German battle EXP bar option label is localized")
T.eq(qolLabels.qol_caught_indicator, "GEFANGEN-ICON",
  "German caught-indicator option label is localized")

root.index = 2
pressed = "select"
root:update(0)
T.eq(#stack.states, 1, "SELECT opens German subgroup help")
stack:pop()
pressed = "a"
root:update(0)
local characters = assert(stack:top())
T.eq(characters.title, "FIGUREN / TRAINER",
  "A opens the German character/trainer page")
T.eq(#characters.items, 2,
  "German character/trainer page contains exactly its two controls")
T.eq(characters.items[1].value, "character_sprite_style",
  "field character style is first")
T.eq(characters.items[2].value, "trainer_portrait_style",
  "trainer portrait style is second")
stack:pop()

root.index = 1
pressed = "a"
root:update(0)
local pokemon = assert(stack:top())
T.eq(pokemon.title, "POKéMON-SPRITES",
  "A opens the German Pokémon sprite page")
local expected = {
  "pokemon_sprite_style", "sprite_style_battle", "sprite_style_summary",
  "sprite_style_dex", "sprite_style_box", "sprite_style_scenes",
}
T.eq(#pokemon.items, #expected,
  "German Pokémon page contains style plus all five surface controls")
for index, key in ipairs(expected) do
  T.eq(pokemon.items[index].value, key,
    "German Pokémon page order is stable at row " .. index)
end

run.loader.modOptions[modId] = run.loader.modOptions[modId] or {}
run.loader.modOptions[modId].pokemon_sprite_style = "crystal"
game.save.options.modOptions[modId].pokemon_sprite_style = "crystal"
local before = game.save.options.modOptions[modId].pokemon_sprite_style
pressed = "right"
pokemon:update(0)
local after = game.save.options.modOptions[modId].pokemon_sprite_style
T.check(after ~= before, "L/R changes the focused German Pokémon control")
pressed = "left"
pokemon:update(0)
T.eq(game.save.options.modOptions[modId].pokemon_sprite_style, before,
  "reverse L/R restores the German Pokémon control")
pressed = "select"
pokemon:update(0)
T.eq(#stack.states, 2,
  "SELECT opens localized help from the German Pokémon page")

T.finish("visual_options_categories_de_test")
