-- Exercise the real German Red title transition without replacing any asset
-- provider.  The trace records the exact image returned for the moving title
-- slot so a duplicate edition ribbon cannot hide behind a synthetic test.

return function(game)
  local U = dofile(os.getenv("KA_TEST_UTIL") or "tests/drivers/util.lua")
  local TitleState = require("src.ui.TitleState")
  local dir = assert(os.getenv("SHOT_DIR"), "SHOT_DIR is required")

  local function dimensions(image)
    if not (image and image.getDimensions) then return "nil" end
    local ok, width, height = pcall(image.getDimensions, image)
    return ok and (tostring(width) .. "x" .. tostring(height)) or "error"
  end

  while game.stack:top() do game.stack:pop() end
  local title = TitleState.new(game, { onNewGame = function() end })
  game.stack:push(title)
  U.wait(4)
  local initial, initialTrueColor = title:currentSprite()
  U.log("initial", "species=" .. tostring(title.cycleSpecies[title.cycleIndex]),
    "sprite=" .. dimensions(initial), "version=" .. dimensions(title.version),
    "same=" .. tostring(initial == title.version),
    "trueColor=" .. tostring(initialTrueColor))
  assert(U.shot(game, dir .. "/01_settled.png"))

  title.timer = 239
  -- Drive the real state method directly as well as yielding a render frame;
  -- packaged macOS builds pause background windows, and a second QA instance
  -- must still exercise the exact 240-frame transition deterministically.
  title:update(1 / 60)
  U.wait(1)
  local moving, movingTrueColor = title:currentSprite()
  U.log("natural transition",
    "species=" .. tostring(title.cycleSpecies[title.cycleIndex]),
    "sprite=" .. dimensions(moving), "version=" .. dimensions(title.version),
    "same=" .. tostring(moving == title.version),
    "trueColor=" .. tostring(movingTrueColor),
    "slide=" .. tostring(title.slideIn))
  assert(U.shot(game, dir .. "/02_slide_right.png"))
  for _ = 1, 8 do title:update(1 / 60) end
  U.wait(1)
  assert(U.shot(game, dir .. "/03_slide_middle.png"))
  for _ = 1, 11 do title:update(1 / 60) end
  U.wait(1)
  assert(U.shot(game, dir .. "/04_slide_landed.png"))

  love.event.quit(0)
end
