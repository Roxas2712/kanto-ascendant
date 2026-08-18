-- Real 0.1.98 client capture for the bounded 6.5.7 HD standard card.

return function(game)
  local U = dofile(assert(os.getenv("KA_TEST_UTIL"),
    "KA_TEST_UTIL is required"))
  local shotDir = assert(os.getenv("SHOT_DIR"), "SHOT_DIR is required")
  local shotWidth = tonumber(os.getenv("SHOT_WIDTH")) or 1280
  local shotHeight = tonumber(os.getenv("SHOT_HEIGHT")) or 800
  local shotName = os.getenv("SHOT_NAME")
    or "trainer-card-hd-standard-0198-red-de.png"
  local Version = require("src.core.Version")
  local Screens = require("src.ui.Screens")
  local Badges = require("src.inventory.Badges")
  assert(Version.engine == "0.1.98", "visual gate requires exact 0.1.98")

  love.window.setMode(shotWidth, shotHeight, {
    fullscreen = false, resizable = false, highdpi = false,
  })
  U.wait(4)
  local width, height = love.graphics.getDimensions()
  assert(width == shotWidth and height == shotHeight,
    ("unexpected capture window %dx%d"):format(width, height))

  local exports = assert(game.mods and game.mods.exports
    and game.mods.exports.kanto_ascendant)
  local renderer = assert(exports.trainerCardHDStandard)
  local characters = assert(exports.extendedCharacters)
  local hall = assert(exports.legacyHall)
  local ascendant = assert(exports.ascendant)

  characters.select("GREEN")
  game.save.player = game.save.player or {}
  game.save.player.name = "GREEN"
  game.save.money = 83000
  game.save.playTime = 5760
  game.save.inventory = game.save.inventory or {}
  game.save.flags = game.save.flags or {}
  game.save.flags.EVENT_BEAT_GIOVANNI = nil
  game.save.flags.EVENT_BEAT_VIRIDIAN_GYM_GIOVANNI = nil
  local badges = Badges.list(game.data)
  for index = 1, 4 do
    game.save.inventory[assert(Badges.itemFor(badges[index]))] = 1
  end
  assert(ascendant.unlockAchievement("master_circuit"))
  assert(hall.selectTitle("master_circuit"))

  while game.stack:top() do game.stack:pop() end
  local screen = Screens.push(game, "TrainerCard")
  assert(screen[renderer.marker] == true,
    "effective TrainerCard silently fell back to native")
  U.wait(5)
  assert(renderer.lastError == nil,
    "HD card renderer failed: " .. tostring(renderer.lastError))
  local model = assert(screen[renderer.modelKey])
  assert(model.brand == "KANTO ASCENDANT")
  assert(model.title == "WAPPENTRÄGER")
  assert(model.identity == "GREEN")
  assert(model.badgesOwned == 4)
  assert(model.badges[8].hidden == true)
  assert(U.shot(game, shotDir .. "/" .. shotName))
  U.wait(3)
  U.log("PASS HD standard Trainer Card screenshot")
  love.event.quit(0)
end
