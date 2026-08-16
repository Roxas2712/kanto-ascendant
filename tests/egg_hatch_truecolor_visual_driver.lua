-- Focused disposable-renderer proof for TEST-RC-002.  This constructs only
-- the hatch state: no overworld progress, user save or unrelated game route.

return function(game)
  local U = dofile(assert(os.getenv("KA_TEST_UTIL"), "KA_TEST_UTIL required"))
  local out = assert(os.getenv("SHOT_DIR"), "SHOT_DIR required")
  local Pokemon = require("src.pokemon.Pokemon")
  local hatch = assert(game.mods.exports.kanto_ascendant.eggHatchAnimation,
    "Kanto Ascendant hatch animation export missing")

  game.mods.modOptions = game.mods.modOptions or {}
  local options = game.mods.modOptions.kanto_ascendant or {}
  game.mods.modOptions.kanto_ascendant = options
  options.pokemon_sprite_style = "crystal"
  options.sprite_style_scenes = true
  options.crystal_animation = true

  while game.stack:top() do game.stack:pop() end
  local mon = Pokemon.new(game.data, "BULBASAUR", 5)
  local finalized = 0
  local state = hatch.State.new(game, { mon }, function(target)
    assert(target == mon, "hatch finalizer received another Pokemon")
    finalized = finalized + 1
    return "BULBASAUR hat sich aus dem EI befreit!"
  end)
  game.stack:push(state)

  while state.frame < 160 do game:step(1 / 60) end
  assert(finalized == 1 and state.sprite and state.spriteTrueColor == true,
    "newborn did not retain the resolver true-color bit")
  assert(hatch.fragmentsVisible(state.frame),
    "short shell burst is missing during its authored reveal window")
  assert(U.shot(game, out .. "/01_reveal_neutral_fragments.png"))

  while state.frame < hatch.timeline.fragmentEnd do game:step(1 / 60) end
  assert(not hatch.fragmentsVisible(state.frame),
    "shell fragments survived their cleanup frame")
  assert(U.shot(game, out .. "/02_settled_truecolor_newborn.png"))

  while state.frame < hatch.timeline.revealEnd do game:step(1 / 60) end
  assert(state.messagePushed and not hatch.fragmentsVisible(state.frame),
    "message began while loose shell fragments were still active")
  assert(U.shot(game, out .. "/03_message_no_loose_fragments.png"))

  local receipt = assert(io.open(out .. "/driver_result.txt", "wb"))
  receipt:write(
    "status=PASS\n",
    "scope=TEST-RC-002-EGG-HATCH-TRUECOLOR-FRAGMENT-LIFECYCLE\n",
    "species=BULBASAUR\n",
    "true_color=1/1\n",
    "fragment_cleanup=1/1\n",
    "message_clean=1/1\n",
    "screenshots=3/3\n",
    "save_write=0\n",
    "fail=0\n")
  receipt:close()
  print("EGG HATCH TRUECOLOR RESULT pass=4 fail=0")
  love.event.quit(0)
end
