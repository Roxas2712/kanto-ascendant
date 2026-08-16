-- Capture the complete Red title transition, including the frames the
-- ordinary title-mon sprite moves in from the right.  A settled screenshot
-- alone cannot reveal a second edition ribbon rendered by another wrapper.

return function(game)
  local U = dofile(os.getenv("KA_TEST_UTIL") or "tests/drivers/util.lua")
  local TitleState = require("src.ui.TitleState")
  local dir = assert(os.getenv("SHOT_DIR"), "SHOT_DIR is required")

  while game.stack:top() do game.stack:pop() end
  local title = TitleState.new(game, { onNewGame = function() end })
  game.stack:push(title)
  U.wait(4)
  assert(U.shot(game, dir .. "/01_settled.png"))

  -- Reproduce both reported paths deterministically.  A late Crystal provider
  -- can hand the 80x8 edition ribbon to the title-mon slot; alternatively the
  -- Crystal provider can be disabled and a lower compatibility resolver can
  -- return the same ribbon as its fallback.  Neither candidate may cross the
  -- already-settled "ROTE EDITION" strip.
  local controller = TitleState._ascendantCrystalV15Controller
  local originalTitleSprite = controller and controller.titleSprite
  if controller then
    controller.titleSprite = function(_, screen)
      return screen.version, false
    end
  end

  title.timer = 239
  U.wait(1)
  U.log("slide frame 01", "species=" .. tostring(
    title.cycleSpecies[title.cycleIndex]), "slide=" .. tostring(title.slideIn))
  assert(U.shot(game, dir .. "/02_slide_right.png"))
  U.wait(8)
  assert(U.shot(game, dir .. "/03_slide_middle.png"))
  U.wait(11)
  assert(U.shot(game, dir .. "/04_slide_landed.png"))
  if controller then
    controller.titleSprite = function() return nil, false end
  end

  for _, species in ipairs(title.cycleSpecies) do
    title.sprites[species] = { image = title.version, trueColor = false }
  end
  title.timer = 239
  U.wait(1)
  U.log("fallback slide frame 01", "species=" .. tostring(
    title.cycleSpecies[title.cycleIndex]), "slide=" .. tostring(title.slideIn))
  assert(U.shot(game, dir .. "/05_fallback_slide_right.png"))
  U.wait(8)
  assert(U.shot(game, dir .. "/06_fallback_slide_middle.png"))
  U.wait(11)
  assert(U.shot(game, dir .. "/07_fallback_slide_landed.png"))
  if controller then controller.titleSprite = originalTitleSprite end

  love.event.quit(0)
end
