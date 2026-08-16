-- Live acceptance for the permanent FRLG opponent presentation. Deliberately
-- retain the old Ascendant field option to catch the RC regression where it
-- used to disable every 64x64 trainer front.

return function(game)
  local U = dofile("tests/drivers/util.lua")
  local Assets = require("src.render.Assets")
  local Font = require("src.render.Font")
  local Pokemon = require("src.pokemon.Pokemon")
  local BattleState = require("src.battle.BattleState")
  local Runtime = require("src.mods.Runtime")
  local dir = assert(os.getenv("SHOT_DIR"), "SHOT_DIR is required")
  local exports = assert(game.mods.exports.kanto_ascendant)
  local pack = assert(exports.frlgTrainerPack)
  local characters = assert(exports.extendedCharacters)
  local pass, fail = 0, 0

  local function check(label, value)
    if value then pass = pass + 1 else fail = fail + 1 end
    U.log(value and "PASS" or "FAIL", label)
  end

  U.wait(20)
  game.mods.modOptions.kanto_ascendant =
    game.mods.modOptions.kanto_ascendant or {}
  game.mods.modOptions.kanto_ascendant.character_sprite_style = "ascendant"
  Runtime.emit("mod.options_changed", {
    game = game, mod = "kanto_ascendant",
    key = "character_sprite_style", value = "ascendant",
  })
  pack.refresh(game)
  check("legacy Ascendant value remains field-only",
    characters.characterStyle() == "ascendant")
  characters.select("GREEN")
  characters.refreshVisuals(game)

  local ids = {}
  for id in pairs(pack.fronts) do ids[#ids + 1] = id end
  table.sort(ids)
  check("all 42 used Kanto opponent classes are mapped", #ids == 42)

  local pictures = {}
  for _, id in ipairs(ids) do
    local trainer = game.data.trainers[id]
    local expected = pack.fronts[id]
    local correct = trainer and trainer.trueColor == true
      and trainer.pic and trainer.pic:sub(-#expected) == expected
    check(id .. " resolves to its FRLG front", correct)
    if correct then
      local image = Assets.image(trainer.pic)
      local width, height = image:getDimensions()
      check(id .. " is native 64x64", width == 64 and height == 64)
      pictures[#pictures + 1] = { id = id, image = image }
    end
  end

  while game.stack:top() do game.stack:pop() end
  local gallery = { isOpaque = true, page = 1 }
  function gallery:draw()
    love.graphics.setColor(.94, .92, .84, 1)
    love.graphics.rectangle("fill", 0, 0, 160, 144)
    love.graphics.setColor(.10, .18, .30, 1)
    Font.draw(("FRLG TRAINERS %d/3"):format(self.page), 8, 2)
    local first = (self.page - 1) * 20 + 1
    for slot = 0, 19 do
      local pic = pictures[first + slot]
      if not pic then break end
      local column, row = slot % 5, math.floor(slot / 5)
      local x, y = column * 32, 14 + row * 32
      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.draw(pic.image, x, y, 0, .5, .5)
      love.graphics.setColor(.10, .18, .30, 1)
      Font.draw(('%02d'):format(first + slot), x, y + 24)
    end
    love.graphics.setColor(1, 1, 1, 1)
  end
  game.stack:push(gallery)
  for page = 1, 3 do
    gallery.page = page
    U.wait(3)
    check("FRLG trainer gallery page " .. page,
      U.shot(game, ("%s/%02d_gallery.png"):format(dir, page)))
  end
  game.stack:pop()

  game.save.party = { Pokemon.new(game.data, "BULBASAUR", 50) }
  local battles = {
    { "OPP_BROCK", 1, "brock" }, { "OPP_MISTY", 1, "misty" },
    { "OPP_ROCKET", 1, "rocket" }, { "OPP_SABRINA", 1, "sabrina" },
    { "OPP_AGATHA", 1, "agatha" }, { "OPP_GIOVANNI", 1, "giovanni" },
  }
  for _, spec in ipairs(battles) do
    U.teleport(game, "ROUTE_1", 5, 5, "down")
    local battle = BattleState.newTrainer(game, spec[1], spec[2])
    game.overworld:pushBattle(battle)
    local ready = false
    for _ = 1, 480 do
      if battle.showEnemyTrainer and battle.showPlayerBack
          and game.stack:top() == battle then
        ready = true
        break
      end
      U.wait(1)
    end
    check(spec[1] .. " battle intro renders", ready)
    U.wait(30)
    check(spec[1] .. " battle screenshot",
      U.shot(game, dir .. "/10_" .. spec[3] .. "_battle.png"))
    while game.stack:top() do game.stack:pop() end
  end

  U.log(("FRLG TRAINER PACK LIVE RESULT pass=%d fail=%d"):format(pass, fail))
  love.event.quit(fail == 0 and 0 or 1)
end
