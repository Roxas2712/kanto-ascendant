-- Exhaustive in-game option contract for Kanto Ascendant.
--
-- This loads the complete mod through the real Modkit loader, then verifies
-- every schema row that the large Start-menu tree exposes.  A must never
-- mutate a leaf value; Left/Right must move it in both directions; SELECT
-- must open non-generic help; and both live and save-local option buckets
-- must stay synchronized.

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
local run = T.sdk.loadMod(modPath, { data = Data, root = "/" })
Version.engine = savedEngine

local unexpectedLoadErrors = {}
local derivedWritePrefix = "kanto_ascendant: asset transform failed: "
  .. "could not write save/mod-derived/kanto_ascendant/hidden_evolution/"
  .. "interaction_anchor.png:"
for _, message in ipairs(run.errors) do
  message = tostring(message)
  if message:sub(1, #derivedWritePrefix) ~= derivedWritePrefix then
    unexpectedLoadErrors[#unexpectedLoadErrors + 1] = message
  end
end
T.eq(#unexpectedLoadErrors, 0,
  "full option fixture has no loader/schema error beyond the known "
    .. "headless derived-image write stub: "
    .. table.concat(unexpectedLoadErrors, " | "))

local modId = "kanto_ascendant"
local schema = assert(run.loader.optionSchemas[modId],
  "Kanto Ascendant option schema missing")
local exports = assert(run.loader.exports[modId],
  "Kanto Ascendant exports missing")
local optionHelp = assert(exports.optionHelp, "option help export missing")

local byKey = {}
for _, row in ipairs(schema) do
  T.check(byKey[row.key] == nil, "option key is unique: " .. row.key)
  byKey[row.key] = row
  T.check(row.type == "toggle" or row.type == "choice"
      or row.type == "number", "option type is supported: " .. row.key)

  if row.type == "choice" then
    T.check(type(row.choices) == "table" and #row.choices > 0,
      "choice option has values: " .. row.key)
    local defaultFound = false
    for _, choice in ipairs(row.choices) do
      if choice[2] == row.default then defaultFound = true end
    end
    T.check(defaultFound, "choice default is selectable: " .. row.key)
  elseif row.type == "number" then
    T.check(type(row.min) == "number" and type(row.max) == "number"
        and row.min <= row.default and row.default <= row.max,
      "number default is in range: " .. row.key)
  else
    T.check(type(row.default) == "boolean",
      "toggle default is boolean: " .. row.key)
  end

  local help = optionHelp.entry(row.key)
  T.check(type(help.en) == "string" and #help.en > 20
      and type(help.de) == "string" and #help.de > 20,
    "option has substantive bilingual help: " .. row.key)
  T.check(help.en ~= "Controls this Kanto Ascendant feature."
      and help.de ~= "Steuert diese Kanto-Ascendant-Funktion.",
    "option does not use generic help: " .. row.key)
end
T.check(#schema >= 93, "complete 6.5 option schema is present")

local stack = { states = {} }
function stack:push(value) self.states[#self.states + 1] = value end
function stack:pop() return table.remove(self.states) end
function stack:top() return self.states[#self.states] end

local pressed
local input = {
  wasPressed = function(_, key)
    local hit = pressed == key
    if hit then pressed = nil end
    return hit
  end,
  isDown = function() return false end,
}

run.loader.modOptions[modId] = {}
local savedOptions = {}
local writes = 0
local game = {
  data = Data,
  input = input,
  mods = run.loader,
  save = {
    options = { modOptions = { [modId] = savedOptions } },
    party = {}, inventory = {}, pcItems = {}, flags = {}, modData = {},
    player = { name = "RED" },
  },
  stack = stack,
  writeOptions = function() writes = writes + 1 return true end,
}

local function values(row)
  if row.type == "toggle" then return { row.default, not row.default } end
  if row.type == "choice" then
    local out = {}
    for _, choice in ipairs(row.choices) do out[#out + 1] = choice[2] end
    return out
  end
  if row.presets and #row.presets > 0 then return row.presets end
  local nextValue = row.default + (row.step or 1)
  if nextValue > row.max then nextValue = row.min end
  return { row.default, nextValue }
end

local function adjacent(row, direction)
  local choices = values(row)
  for index, value in ipairs(choices) do
    if value == row.default then
      return choices[((index - 1 + direction) % #choices) + 1]
    end
  end
  error("default missing from value list: " .. row.key)
end

local leafScreens = {
  "AscendantCoreOptions", "AscendantRematchOptions",
  "AscendantFollowerOptions", "AscendantVisualOptions",
  "AscendantPokemonSpriteOptions", "AscendantCharacterTrainerOptions",
  "AscendantAdventureOptions", "AscendantLivingEncounterOptions",
  "AscendantLivingBehaviorOptions", "AscendantLivingTownOptions",
  "AscendantJohtoOptions", "AscendantLegendOptions",
  "AscendantHeritageOptions", "AscendantCaptureOptions",
  "AscendantControlOptions", "AscendantQolOptions",
  "AscendantMenuOptions",
}

local reachable = {}
for _, screenId in ipairs(leafScreens) do
  local factory = assert(Data.screens[screenId], screenId .. " missing")
  local list = assert(factory.new(game, {}), screenId .. " did not open")
  T.eq(list.pageJump, false, screenId .. " disables page-jump input")

  for index, item in ipairs(list.items) do
    if item.schema then
      local row = item.schema
      T.check(reachable[row.key] == nil,
        "schema leaf appears in only one category: " .. row.key)
      reachable[row.key] = screenId
      list.index = index
      run.loader.modOptions[modId][row.key] = row.default
      savedOptions[row.key] = row.default

      pressed = "a"
      list:update(0)
      T.eq(run.loader.modOptions[modId][row.key], row.default,
        "A does not change option: " .. row.key)
      T.eq(savedOptions[row.key], row.default,
        "A leaves saved option untouched: " .. row.key)

      pressed = "right"
      list:update(0)
      local expectedRight = adjacent(row, 1)
      T.eq(run.loader.modOptions[modId][row.key], expectedRight,
        "Right advances live option: " .. row.key)
      T.eq(savedOptions[row.key], expectedRight,
        "Right persists option: " .. row.key)

      pressed = "left"
      list:update(0)
      T.eq(run.loader.modOptions[modId][row.key], row.default,
        "Left reverses live option: " .. row.key)
      T.eq(savedOptions[row.key], row.default,
        "Left reverses saved option: " .. row.key)

      local beforeHelp = #stack.states
      pressed = "select"
      list:update(0)
      T.eq(#stack.states, beforeHelp + 1,
        "SELECT opens option help: " .. row.key)
      stack:pop()
    end
  end
end

for _, row in ipairs(schema) do
  if row.key ~= "legacy_wanderer_frequency" then
    T.check(reachable[row.key] ~= nil,
      "schema option is reachable in the Start-menu tree: " .. row.key)
  end
end
T.check(reachable.pokemon_sprite_style == "AscendantPokemonSpriteOptions",
  "Pokémon sprite style is reachable in the focused Pokémon page")
for _, key in ipairs({ "sprite_style_battle", "sprite_style_summary",
    "sprite_style_dex", "sprite_style_box", "sprite_style_scenes" }) do
  T.check(reachable[key] == "AscendantPokemonSpriteOptions",
    key .. " is reachable in the focused Pokémon page")
end
T.check(reachable.character_sprite_style == "AscendantCharacterTrainerOptions",
  "field character style is reachable in the character/trainer page")
T.check(reachable.trainer_portrait_style == "AscendantCharacterTrainerOptions",
  "trainer portrait style is reachable in the character/trainer page")

local visualRoot = assert(Data.screens.AscendantVisualOptions.new(game, {}),
  "Visuals root did not open")
T.eq(visualRoot.items[1].label, "POKéMON SPRITES",
  "Visuals exposes Pokémon sprites as its first visible subgroup")
T.eq(visualRoot.items[1].screen, "AscendantPokemonSpriteOptions",
  "Pokémon subgroup opens its focused screen")
T.eq(visualRoot.items[2].label, "CHARACTERS / TRAINERS",
  "Visuals exposes characters and trainers as its second subgroup")
T.eq(visualRoot.items[2].screen, "AscendantCharacterTrainerOptions",
  "character/trainer subgroup opens its focused screen")

visualRoot.index = 1
local writesBeforeGroupInput = writes
pressed = "right"
visualRoot:update(0)
T.eq(writes, writesBeforeGroupInput,
  "L/R does not mutate options while a Visuals subgroup is highlighted")
pressed = "select"
visualRoot:update(0)
T.eq(#stack.states, 1,
  "SELECT opens help for a Visuals subgroup")
stack:pop()
pressed = "a"
visualRoot:update(0)
T.eq(stack:top().title, "POKéMON SPRITES",
  "A opens the highlighted Visuals subgroup")
stack:pop()

T.check(reachable.language == nil and byKey.language == nil,
  "translation language is not exposed as a dead private option")
T.check(writes >= 2 * (#schema - 1),
  "bidirectional option changes use the persistent write seam")

-- The compact feature hub is a second route to a reviewed subset.  It must
-- contain only real schema keys and obey the same A/L/R/SELECT contract.
local features = assert(exports.ascendantFeatures,
  "compact Ascendant feature export missing")
for _, row in ipairs(features.rows) do
  T.check(byKey[row.key] ~= nil,
    "compact feature row maps to real schema: " .. row.key)
end

local registered = Data.screens
for groupKey, group in pairs(features.groups) do
  local screenId = ({
    storage = "JohtoAscendantStorageOptions",
    sprites = "JohtoAscendantSpriteOptions",
    qol = "JohtoAscendantQolOptions",
    quick = "JohtoAscendantQuickOptions",
    display = "JohtoAscendantDisplayOptions",
    johto = "JohtoAscendantJohtoOptions",
  })[groupKey]
  local screen = assert(registered[screenId].new(game))
  for index, row in ipairs(group.rows) do
    screen.index = index
    run.loader.modOptions[modId][row.key] = byKey[row.key].default
    savedOptions[row.key] = byKey[row.key].default
    local before = savedOptions[row.key]

    pressed = "a"
    screen:update()
    T.eq(savedOptions[row.key], before,
      "compact A leaves option unchanged: " .. row.key)

    pressed = "right"
    screen:update()
    T.check(savedOptions[row.key] ~= before or #row.values == 1,
      "compact Right changes option: " .. row.key)

    pressed = "left"
    screen:update()
    T.eq(savedOptions[row.key], before,
      "compact Left restores option: " .. row.key)

    local beforeHelp = #stack.states
    pressed = "select"
    screen:update()
    T.eq(#stack.states, beforeHelp + 1,
      "compact SELECT opens help: " .. row.key)
    stack:pop()
  end
end

run.release()
T.finish("Kanto Ascendant full option contract")
