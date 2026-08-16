-- Renderer-backed proof for the Kanto Ascendant title trainer cycle.

return function(game)
  local U = dofile("tests/drivers/util.lua")
  local TitleState = require("src.ui.TitleState")
  local Font = require("src.render.Font")
  local dir = assert(os.getenv("SHOT_DIR"), "SHOT_DIR is required")
  local exports = game.mods and game.mods.exports
    and game.mods.exports.kanto_ascendant
  local intro = exports and exports.titleIntro
  U.log("kanto-mod-path", game.mods and game.mods.mods
    and game.mods.mods.kanto_ascendant
    and game.mods.mods.kanto_ascendant.path)
  local pass, fail = 0, 0

  local function check(label, value)
    if value then pass = pass + 1 else fail = fail + 1 end
    U.log(value and "PASS" or "FAIL", label)
  end

  while game.stack:top() do game.stack:pop() end
  local title = TitleState.new(game, { onNewGame = function() end })
  table.insert(game.stack.states, title)
  U.wait(8)

  check("title intro API loaded", intro ~= nil)
  check("title footer is KANTO ASCENDANT",
    title.title and title.title.copyrightText == "KANTO ASCENDANT")
  check("KANTO ASCENDANT footer is horizontally centered",
    title.kaTitleFooterX == math.floor((160 - Font.width("KANTO ASCENDANT")) / 2))
  check("title starts with Green and an animated Crystal Pokemon",
    title.kaTitlePhase == "pair" and title.kaTitleTrainerId == "GREEN"
      and title.player ~= nil and title:currentSprite() ~= nil)
  local zones = title:sgbPalettes(game)
  local paper = zones and zones[1] and zones[1].colors
    and zones[1].colors[1]
  U.log("title-paper", paper and paper[1], paper and paper[2],
    paper and paper[3], "footer-x", title.kaTitleFooterX,
    "expected", math.floor((160 - Font.width("KANTO ASCENDANT")) / 2))
  check("title palette uses true white paper",
    paper and paper[1] == 255 and paper[2] == 255 and paper[3] == 255)
  check("title coordinates remain exactly vanilla",
    title.kaTitleTrainerX == 82 and title.kaTitlePokemonOffsetX == 0)
  local greenData = title.kaTitleTrainers[1].image:newImageData()
  local _, _, _, greenCornerAlpha = greenData:getPixel(0, 0)
  check("Green title art has a transparent background", greenCornerAlpha == 0)
  local blueData = title.kaTitleTrainers[2].image:newImageData()
  local _, _, _, blueCornerAlpha = blueData:getPixel(0, 0)
  check("Blue title art has a transparent background", blueCornerAlpha == 0)
  check("Green + Pokemon pair capture",
    U.shot(game, dir .. "/19_title_green_pair_first.png"))

  title.timer = 239
  U.wait(22)
  check("the complete pair advances from Green to Blue",
    title.kaTitlePhase == "pair" and title.kaTitleTrainerId == "BLUE"
      and title.player ~= nil and title:currentSprite() ~= nil)
  check("Blue + Pokemon pair capture",
    U.shot(game, dir .. "/20_title_blue_pair_second.png"))

  title.timer = 239
  U.wait(22)
  check("the complete pair advances from Blue to Red",
    title.kaTitlePhase == "pair" and title.kaTitleTrainerId == "RED"
      and title.player ~= nil and title:currentSprite() ~= nil)
  check("Red + Pokemon pair capture",
    U.shot(game, dir .. "/21_title_red_pair_third.png"))

  title.timer = 239
  U.wait(22)
  check("the complete pair loops from Red to Green",
    title.kaTitlePhase == "pair" and title.kaTitleTrainerId == "GREEN"
      and title.player ~= nil and title:currentSprite() ~= nil)

  U.log(("PHASE8 TITLE RESULT pass=%d fail=%d"):format(pass, fail))
  love.event.quit(fail == 0 and 0 or 1)
end
