-- Bounded release acceptance for Oak's Crystal demo card.  The regression
-- only existed in the final palette composition, so source/animation tests
-- are insufficient: capture two real OakSpeech frames after MEWMON.
return function(game)
  local U = dofile("tests/drivers/util.lua")
  local OakSpeech = require("src.ui.OakSpeech")
  local Runtime = require("src.mods.Runtime")
  local dir = assert(os.getenv("SHOT_DIR"), "SHOT_DIR required")
  local exports = assert(game.mods.exports.kanto_ascendant)
  local crystal = assert(exports.crystalAnimation)

  game.mods.modOptions.kanto_ascendant =
    game.mods.modOptions.kanto_ascendant or {}
  local options = game.mods.modOptions.kanto_ascendant
  options.pokemon_sprite_style = "crystal"
  options.crystal_animation = true
  options.sprite_style_scenes = true
  Runtime.emit("mod.options_changed", { game=game, mod="kanto_ascendant" })

  while game.stack:top() do game.stack:pop() end
  local speech = OakSpeech.new(game, function() end)
  -- Match the user's RED intro: the demo species may be replaced by another
  -- content provider, but the final card must retain the Crystal true-color
  -- contract either way.
  speech.demoSpecies = "CHARMANDER"
  local state = crystal.presentationAnimation("CHARMANDER", nil,
    "front", "scenes", { data=game.data })
  assert(state and state.image and state.trueColor == true,
    "Charmander Crystal presentation missing or not true-color")
  speech.__ascendantCrystalV15OakDemo = state
  speech.demoPic, speech.demoTrueColor = state.image, true
  speech.pic, speech.picFlip, speech.picTrueColor = state.image, true, true
  game.stack:push(speech)
  U.wait(5)
  assert(U.shot(game, dir .. "/01_charmander_crystal_oak_frame_a.png"))
  local first = state.image
  crystal.advancePresentation(state, 0.35, game)
  speech.demoPic, speech.pic = state.image, state.image
  assert(state.image ~= first, "Charmander animation did not advance")
  U.wait(5)
  assert(U.shot(game, dir .. "/02_charmander_crystal_oak_frame_b.png"))
  local receipt = assert(io.open(dir .. "/driver_result.txt", "wb"))
  receipt:write("PASS\nframes=2\ntrueColor=true\npalette=MEWMON+exclusion\n")
  receipt:close()
  love.event.quit(0)
end
