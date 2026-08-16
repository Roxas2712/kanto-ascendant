-- Fused desktop diagnostic: prove which title assets Red resolves after the
-- engine's edition cache and all enabled translation mods are active.

return function(game)
  local U = dofile(os.getenv("KA_TEST_UTIL") or "tests/drivers/util.lua")
  local dir = assert(os.getenv("SHOT_DIR"), "SHOT_DIR is required")
  local GameVersion = require("src.core.GameVersion")
  local Assets = require("src.render.Assets")
  local TitleState = require("src.ui.TitleState")
  local expected = os.getenv("KA_EXPECT_VERSION") or "red"
  local pass, fail = 0, 0

  local function check(label, condition)
    if condition then pass = pass + 1 else fail = fail + 1 end
    U.log(condition and "PASS" or "FAIL", label)
  end

  local function value(entry)
    return type(entry) == "table" and entry.path or entry
  end
  local field = game.data.field or {}
  local title = field.title or {}
  local bootTitle = field.boot and field.boot.title or {}
  U.log("engine version", require("src.core.Version").engine)
  U.log("game version", GameVersion.get())
  U.log("field title logo", tostring(value(title.logo)))
  U.log("boot title logo", tostring(value(bootTitle.logo)))
  U.log("field version ribbon", tostring(value(title.versionRibbon)))
  U.log("boot version ribbon", tostring(value(bootTitle.versionRibbon)))
  for _, path in ipairs({ value(title.logo), value(bootTitle.logo),
      value(title.versionRibbon), value(bootTitle.versionRibbon) }) do
    if path then
      U.log("resolved", path, Assets.resolve(path),
        love.filesystem.getRealDirectory(Assets.resolve(path)))
    end
  end

  while game.stack:top() do game.stack:pop() end
  local screen = TitleState.new(game, { onNewGame = function() end })
  game.stack:push(screen)
  U.log("screen flags", "blue=" .. tostring(screen.blue),
    "yellow=" .. tostring(screen.yellow),
    "yellowLayout=" .. tostring(screen.yellowLayout))
  U.log("screen trainer", tostring(screen.kaTitleTrainerId))
  check("runtime is expected edition", GameVersion.get() == expected)
  if expected == "yellow" then
    check("Yellow keeps its own localized layout",
      screen.yellow == true and screen.yellowLayout == true
        and screen.kaTitleLogoRecovered ~= true)
  else
    check(expected .. " never enters Yellow layout",
      screen.yellow == false and screen.yellowLayout == false)
    check("foreign inactive Yellow logo was rejected",
      screen.kaTitleLogoRecovered == true
        and tostring(screen.kaTitleLogoRejected):match(
          "deutsch%-gelb/overrides/title/pokemon_logo%.png$") ~= nil)
  end
  U.wait(90)
  local ok = U.shot(game, dir .. "/" .. expected .. "_title_resolved.png")
  check(expected .. " title diagnostic screenshot", ok)
  U.log(("EDITION TITLE RESULT pass=%d fail=%d"):format(pass, fail))
  love.event.quit(fail == 0 and 0 or 1)
end
