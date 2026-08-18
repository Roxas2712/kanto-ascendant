-- Exact-engine rendering contract for the bounded 6.5.7 German correction.

package.path = "./?.lua;./?/init.lua;" .. package.path

local root = assert(os.getenv("TRAINER_REMATCH_MOD_DIR"),
  "TRAINER_REMATCH_MOD_DIR is required")
local edition = assert(os.getenv("POKEPORT_VERSION"),
  "POKEPORT_VERSION is required")
assert(edition == "red" or edition == "blue" or edition == "yellow",
  "POKEPORT_VERSION must be red, blue or yellow")

local dialogue = assert(loadfile(root .. "/character_dialogue.lua"))()
local row = assert(dialogue.rival.GREEN._OaksLabRivalTakesText1)

local Data = require("src.core.Data")
Data:load()
require("src.render.Font").load(Data)
local TextBox = require("src.render.TextBox")
local GameVersion = require("src.core.GameVersion")
local makePagination = assert(loadfile(root .. "/dialogue_pagination.lua"))()
local registry = { register = function() end, override = function() end }
local pagination = makePagination({ path = root,
  content = { text = registry } }, { TextBox = TextBox })

local previous = GameVersion.get()
GameVersion.set(edition)
local game = {
  save = { version = edition,
    player = { name = "BLAU", rival = "GRÜN" } },
  data = { tokens = TextBox.TOKENS },
}
local box = TextBox.new(game, pagination.gateText(game, row[2]))
GameVersion.set(previous)

local checks = 0
local function check(value, message)
  checks = checks + 1
  assert(value, message)
end

check(row[1] == "{RIVAL}: {PLAYER},\nI picked this one!\f"
    .. "...Wait. Was this yours?",
  "the German-only hotfix changed the English line")
check(row[2] == "{RIVAL}: Ich nehme\ndieses POKéMON!\f"
    .. "Moment, {PLAYER}!\nWar das für dich?",
  "the engine did not load the approved German line")
check(dialogue.rival.BLUE == nil,
  "Kanto Ascendant gained a Blue dialogue overlay")
check(#box.pages == 2,
  edition .. " did not keep the authored exchange on two pages")
check(table.concat(box.pages[1], "|") ==
    "GRÜN: Ich nehme|dieses POKéMON!",
  edition .. " did not render the first German page as two complete rows")
check(table.concat(box.pages[2], "|") ==
    "Moment, BLAU!|War das für dich?",
  edition .. " did not render the second German page as two complete rows")

io.stdout:write(("yellow_german_oak_dialogue_engine_test: %s %d checks passed\n")
  :format(edition, checks))
