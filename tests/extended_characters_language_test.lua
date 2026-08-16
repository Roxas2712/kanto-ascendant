-- Real translation-mod integration for Extended Character Selection.
-- The character layer must follow the loaded game language; it has no
-- private language switch that can create a mixed English/German playthrough.

package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local Data = require("src.core.Data")
Data:load()
local modPath = os.getenv("TRAINER_REMATCH_MOD_DIR")
  or "mods/kanto_ascendant"
local run = T.sdk.loadMods({ "mods/deutsch", modPath }, { data = Data })
T.eq(#run.errors, 0, "German Red and Kanto Ascendant load together")

local exports = assert(run.loader.exports.kanto_ascendant)
local characters = assert(exports.extendedCharacters)
T.eq(exports.language(), "de", "character text follows the real German mod")
T.eq(characters.displayName("GREEN"), "GRÜN", "Green label is German")
T.eq(characters.displayName("BLUE"), "BLAU", "Blue label is German")
T.eq(characters.displayName("RED"), "ROT", "Red label is German")
T.eq(characters.selectionLabel("GREEN"), "GRÜN",
  "German selector identifies Green canonically")
T.eq(characters.selectionLabel("BLUE"), "BLAU",
  "German selector identifies Blue canonically")
T.eq(characters.selectionLabel("RED"), "ROT",
  "German selector identifies Red canonically")

characters.select("GREEN")
local text = {
  _RedsHouse1FMomWakeUpText = "Alle Jungen ziehen los.",
  _PalletTownRivalsHouseSignText = "BLAUS HAUS",
  _BluesHouseDaisyRivalAtLabText = "BLAU ist im Labor.",
  _OaksLabRivalGrampsText = "{RIVAL}: Opa!",
  _OaksLabRivalIllTakeYouOnText = "vanilla",
}
characters.refreshCharacterDialogue({ data = { text = text } },
  characters.getState())
T.check(text._RedsHouse1FMomWakeUpText:find("Mädchen", 1, true) ~= nil,
  "German mother dialogue identifies Green as a girl")
T.eq(text._PalletTownRivalsHouseSignText, "HAUS DER FAMILIE\nEICH",
  "German family-house sign is role-neutral")
T.check(text._BluesHouseDaisyRivalAtLabText:find("{RIVAL}", 1, true) ~= nil,
  "German Daisy dialogue uses the selected rival name")
T.check(text._OaksLabRivalIllTakeYouOnText:find("Sehen wir", 1, true) ~= nil,
  "quiet Red receives his German personality dialogue")
T.check(not text._OaksLabRivalIllTakeYouOnText:find("Let's", 1, true),
  "German custom dialogue contains no English fragment")

local steps = run.loader.hooks:call("intro.oak_speech.build",
  function(rows) return rows end, {
    { id = "world_spiel", kind = "say" },
    { id = "name_player", kind = "name" },
    { id = "ask_rival_name", kind = "say" },
    { id = "name_rival", kind = "name" },
  }, {})
local byId = {}
for _, step in ipairs(steps) do byId[step.id] = step end

local Screens = require("src.ui.Screens")
local originalPush, pushed = Screens.push, nil
Screens.push = function(_, id, opts) pushed = { id = id, opts = opts } end
local speech = {
  game = { save = { player = {} } }, nameLen = 7,
  recordAnswer = function() end,
}
byId.name_player.run(speech, function() end)
T.eq(pushed.opts.title, "IHR NAME?", "German Green naming is feminine")
T.eq(table.concat(pushed.opts.presets, ","), "GRÜN,CASEY,JEAN",
  "German Green presets are Grün, Casey and Jean")
T.eq(pushed.opts.newNameLast, true,
  "German free-name entry is ordered below the presets")
byId.name_rival.run(speech, function() end)
T.eq(table.concat(pushed.opts.presets, ","), "ROT,ASH,JACK",
  "Green route gives the Red rival Red's localized suggestions")
T.eq(pushed.opts.newNameLast, true,
  "German rival free-name entry is ordered below the presets")
Screens.push = originalPush

local askLine
byId.ask_rival_name.run({
  applyPic = function() end,
  sayText = function(_, line, done) askLine = line; done() end,
}, function() end)
T.eq(askLine,
  "Dieser Junge ist\naus ALABASTIA.\f...Seinen Namen habe\nich wohl vergessen.",
  "German Red introduction asks for the forgotten Pallet trainer name")
T.check(not askLine:find("PALLET", 1, true),
  "German introduction never leaks the English town name")

T.finish("extended_characters_language_test")
