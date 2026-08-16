package.path = "./?.lua;./?/init.lua;" .. package.path

local S = require("tests.harness").suite("pre-game speed guard")
local eq = S.eq
local modDir = assert(os.getenv("TRAINER_REMATCH_MOD_DIR"))

local Game = require("src.core.Game")
local OakSpeech = require("src.ui.OakSpeech")
assert(loadfile(modDir .. "/pre_game_speed.lua"))()()

local function fake(states, speed)
  return setmetatable({
    save = { options = { speed = speed } },
    stack = { states = states },
  }, { __index = Game })
end

eq(fake({ { screenId = "TitleState" } }, 20):logicSpeed(), 1,
  "saved fast-forward is disabled on the title")
eq(fake({ setmetatable({}, { __index = OakSpeech }) }, 20):logicSpeed(), 1,
  "saved fast-forward is disabled throughout Oak's introduction")
eq(fake({ { screenId = "OverworldState" } }, 20):logicSpeed(), 20,
  "saved fast-forward resumes after gameplay begins")

S.finish()
