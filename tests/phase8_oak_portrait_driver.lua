-- Live colour proof for the FRLG Oak portrait and the selected RGB trainer
-- portraits inside the real OakSpeech renderer.

return function(game)
  local U = dofile("tests/drivers/util.lua")
  local OakSpeech = require("src.ui.OakSpeech")
  local dir = assert(os.getenv("SHOT_DIR"), "SHOT_DIR is required")
  local exports = assert(game.mods.exports.kanto_ascendant)
  local characters = assert(exports.extendedCharacters)
  local pass, fail = 0, 0
  local function check(label, value)
    if value then pass = pass + 1 else fail = fail + 1 end
    U.log(value and "PASS" or "FAIL", label)
  end

  while game.stack:top() do game.stack:pop() end
  game.mods.modOptions.kanto_ascendant =
    game.mods.modOptions.kanto_ascendant or {}
  game.mods.modOptions.kanto_ascendant.character_sprite_style = "crystal"
  require("src.mods.Runtime").emit("mod.options_changed", {
    game = game, mod = "kanto_ascendant",
    key = "character_sprite_style", value = "crystal",
  })
  characters.select("GREEN")
  characters.refreshVisuals(game)
  local speech = OakSpeech.new(game, function() end)
  speech.steps = speech:buildSteps()
  table.insert(game.stack.states, speech)

  speech:applyPic({ pic = "oak" })
  check("FRLG Oak keeps true-colour metadata", speech.picTrueColor == true)
  speech:sayText(game.data.text._OakSpeechText1 or "PROF. EICH", function() end)
  U.wait(110)
  check("clean Oak portrait capture",
    U.shot(game, dir .. "/oak_01_true_colour.png"))

  while game.stack:top() and game.stack:top() ~= speech do game.stack:pop() end
  speech:applyPic({ pic = "player" })
  check("Casey intro portrait keeps true colour", speech.picTrueColor == true)
  speech:sayText("CASEY", function() end)
  U.wait(40)
  check("clean Casey intro portrait capture",
    U.shot(game, dir .. "/oak_02_casey_true_colour.png"))

  U.log(("OAK PORTRAIT RESULT pass=%d fail=%d"):format(pass, fail))
  love.event.quit(fail == 0 and 0 or 1)
end
