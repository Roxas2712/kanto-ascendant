-- Bounded 2D/FULL acceptance for the three ordinary-trainer portrait modes.
-- Fixed Red/Blue/Green and Silver/Kris/Gold identities are deliberately
-- sampled as a negative control: the ordinary option must not replace them.

return function(game)
  local U = dofile("tests/drivers/util.lua")
  local Assets = require("src.render.Assets")
  local Font = require("src.render.Font")
  local Pokemon = require("src.pokemon.Pokemon")
  local BattleState = require("src.battle.BattleState")
  local Pipelines = require("src.render.Pipelines")
  local Runtime = require("src.mods.Runtime")
  local style = assert(os.getenv("QA_TRAINER_STYLE"), "QA_TRAINER_STYLE required")
  local renderer = os.getenv("QA_RENDERER") or "2d"
  local dir = assert(os.getenv("SHOT_DIR"), "SHOT_DIR required")
  assert(style == "crystal_hd" or style == "original" or style == "frlg")
  local exports = assert(game.mods.exports.kanto_ascendant)
  local pack = assert(exports.frlgTrainerPack)
  local characters = assert(exports.extendedCharacters)
  local pass, fail = 0, 0

  local function check(label, value)
    if value then pass = pass + 1 else fail = fail + 1 end
    U.log(value and "PASS" or "FAIL", label)
  end

  local function finish()
    local result = ("TRAINER PORTRAIT MODES %s/%s pass=%d fail=%d")
      :format(style, renderer, pass, fail)
    U.log(result)
    local file = io.open(dir .. "/driver_result.txt", "wb")
    if file then file:write(result, "\n"); file:close() end
    love.event.quit(fail == 0 and 0 or 1)
  end

  U.wait(20)
  game.mods.modOptions.kanto_ascendant =
    game.mods.modOptions.kanto_ascendant or {}
  game.mods.modOptions.kanto_ascendant.trainer_portrait_style = style
  game.save.options = game.save.options or {}
  game.save.options.modOptions = game.save.options.modOptions or {}
  game.save.options.modOptions.kanto_ascendant =
    game.save.options.modOptions.kanto_ascendant or {}
  game.save.options.modOptions.kanto_ascendant.trainer_portrait_style = style
  Runtime.emit("mod.options_changed", {
    game = game, mod = "kanto_ascendant",
    key = "trainer_portrait_style", value = style,
  })
  pack.refresh(game)
  check("selected style is live", pack.selectedStyle(game) == style)
  Pipelines.setLevel("voxel", renderer == "voxel" and 1 or 0)
  Pipelines.syncOptions(game.save.options)
  local dramatic = renderer == "voxel" and assert(
    game.mods.exports.DRAMALESS_SHAPE or game.mods.exports.DRAMATIC_SHAPE,
    "FULL run requires DRAMALESS") or nil
  local overworldBattle
  if dramatic then
    overworldBattle = assert(dramatic.lib.require("OverworldBattle"))
  end
  check("requested renderer is live", renderer == "voxel"
    and Pipelines.level("voxel") == 1
    and Pipelines.levelLabel("voxel") == "FULL"
    or renderer == "2d" and Pipelines.level("voxel") == 0)

  local ids = {}
  for id in pairs(pack.fronts) do ids[#ids + 1] = id end
  table.sort(ids)
  check("all 42 ordinary Kanto classes remain mapped", #ids == 42)
  local pictures = {}
  for _, id in ipairs(ids) do
    local trainer = game.data.trainers[id]
    check(id .. " carries selected style",
      trainer and trainer.ascendantTrainerPortraitStyle == style)
    if trainer and trainer.pic then
      local ok, image = pcall(Assets.image, trainer.pic)
      check(id .. " selected picture loads", ok and image ~= nil)
      if ok and image then pictures[#pictures + 1] = { id = id, image = image } end
    end
  end
  check("42 selected pictures load", #pictures == 42)

  while game.stack:top() do game.stack:pop() end
  local gallery = { isOpaque = true, page = 1 }
  function gallery:draw()
    love.graphics.setColor(.08, .10, .14, 1)
    love.graphics.rectangle("fill", 0, 0, 160, 144)
    love.graphics.setColor(1, 1, 1, 1)
    Font.draw(("%s %d/3"):format(style:upper(), self.page), 6, 2)
    local first = (self.page - 1) * 20 + 1
    for slot = 0, 19 do
      local pic = pictures[first + slot]
      if not pic then break end
      local column, row = slot % 5, math.floor(slot / 5)
      local x, y = column * 32, 14 + row * 32
      local width, height = pic.image:getDimensions()
      local scale = math.min(30 / width, 26 / height)
      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.draw(pic.image, x + 16, y + 25, 0, scale, scale,
        width / 2, height)
      love.graphics.setColor(.75, .84, 1, 1)
      Font.draw(('%02d'):format(first + slot), x, y + 24)
    end
    love.graphics.setColor(1, 1, 1, 1)
  end
  game.stack:push(gallery)
  for page = 1, 3 do
    gallery.page = page
    U.wait(3)
    check("gallery page " .. page,
      U.shot(game, ("%s/%02d_gallery.png"):format(dir, page)))
  end
  game.stack:pop()

  game.save.party = { Pokemon.new(game.data, "BULBASAUR", 50) }
  local battles = {
    { "OPP_PROF_OAK", 1, "oak" },
    { "OPP_BROCK", 1, "brock" },
    { "OPP_YOUNGSTER", 1, "youngster_adult" },
    { "OPP_AGATHA", 1, "agatha" },
    { "OPP_RIVAL1", 1, "fixed_rival" },
  }
  for _, spec in ipairs(battles) do
    if game.data.trainers[spec[1]] then
      U.teleport(game, "ROUTE_1", 5, 5, "down")
      local battle = BattleState.newTrainer(game, spec[1], spec[2])
      game.overworld:pushBattle(battle)
      local ready = false
      for _ = 1, 480 do
        if battle.showEnemyTrainer and battle.showPlayerBack
            and game.stack:top() == battle then
          ready = true; break
        end
        U.wait(1)
      end
      check(spec[1] .. " intro renders", ready)
      local receiptBefore = renderer == "voxel" and overworldBattle.shot()
      U.wait(30)
      if renderer == "voxel" then
        local receipt = overworldBattle.shot()
        check(spec[1] .. " has fresh FULL battle receipt",
          receipt and receipt.canvas and receipt.canvas.getDimensions
            and receipt ~= receiptBefore
            and overworldBattle.battle() == battle
            and overworldBattle.arena() ~= nil
            and battle.dramaticShapeShot
            and battle.dramaticShapeShot.canvas
            and Pipelines.level("voxel") == 1)
      end
      check(spec[1] .. " screenshot",
        U.shot(game, dir .. "/10_" .. spec[3] .. "_battle.png"))
      local authored = characters.voxelStandingTrainerSpec({
        oppClass = spec[1], showEnemyTrainer = true,
      }, "enemy")
      if spec[1] == "OPP_RIVAL1" then
        check("fixed rival remains outside ordinary portrait table",
          authored == nil)
      elseif renderer == "voxel" and style == "crystal_hd" then
        check(spec[1] .. " has dedicated FULL source", authored ~= nil)
      end
      while game.stack:top() do game.stack:pop() end
    end
  end
  finish()
end
