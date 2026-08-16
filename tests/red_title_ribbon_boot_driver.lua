-- Real Engine 0.1.76 boot-ribbon acceptance test.  The German compatibility
-- layer and the engine's native continuous-ribbon animation are both active;
-- every frame must contain at most one "ROTE EDITION" strip.

return function(game)
  local U = dofile(os.getenv("KA_TEST_UTIL") or "tests/drivers/util.lua")
  local TitleState = require("src.ui.TitleState")
  local dir = assert(os.getenv("SHOT_DIR"), "SHOT_DIR is required")

  while game.stack:top() do game.stack:pop() end
  local title = TitleState.new(game, { onNewGame = function() end })
  game.stack:push(title)
  U.log("boot ribbon", "phase=" .. tostring(title.phase),
    "versionFull=" .. tostring(title.versionFull),
    "germanFull=" .. tostring(title.title
      and title.title.germanFullVersionRibbon))
  assert(title.versionFull == true,
    "Engine 0.1.76 continuous-ribbon path was not active")
  assert(title.title and title.title.germanFullVersionRibbon == true,
    "German full-ribbon compatibility path was not active")

  local guard = 0
  while title.phase ~= "ribbon" and guard < 120 do
    title:update(1 / 60)
    guard = guard + 1
  end
  assert(title.phase == "ribbon", "title never entered ribbon phase")
  U.wait(4)
  assert(U.shot(game, dir .. "/01_ribbon_right.png"))

  for _ = 1, 14 do title:update(1 / 60) end
  U.wait(4)
  U.log("boot ribbon middle", "phase=" .. tostring(title.phase),
    "offset=" .. tostring(title.ribbonOffset))
  assert(U.shot(game, dir .. "/02_ribbon_middle.png"))

  guard = 0
  while title.phase ~= "loop" and guard < 120 do
    title:update(1 / 60)
    guard = guard + 1
  end
  assert(title.phase == "loop", "title ribbon never landed")
  U.wait(4)
  assert(U.shot(game, dir .. "/03_ribbon_landed.png"))
  love.event.quit(0)
end
