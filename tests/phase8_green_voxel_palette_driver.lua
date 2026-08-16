-- Real Dramatic Shape proof for Green's overworld sprite and colour modes.

return function(game)
  local U = dofile("tests/drivers/util.lua")
  local PaletteFX = require("src.render.PaletteFX")
  local Pipelines = require("src.render.Pipelines")
  local Runtime = require("src.mods.Runtime")
  local BattleState = require("src.battle.BattleState")
  local Pokemon = require("src.pokemon.Pokemon")
  local dir = assert(os.getenv("SHOT_DIR"), "SHOT_DIR is required")
  local exports = assert(game.mods and game.mods.exports,
    "mod exports unavailable")
  local characters = assert(exports.kanto_ascendant
    and exports.kanto_ascendant.extendedCharacters,
    "character API unavailable")
  local dramatic = assert(exports.DRAMATIC_SHAPE,
    "real Dramatic Shape mod is required")
  local pass, fail = 0, 0

  local function check(label, value)
    if value then pass = pass + 1 else fail = fail + 1 end
    U.log(value and "PASS" or "FAIL", label)
  end

  local function signature(image)
    local w, h = image:getDimensions()
    local canvas = love.graphics.newCanvas(w, h)
    love.graphics.push("all")
    love.graphics.setCanvas(canvas)
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(image, 0, 0)
    love.graphics.setCanvas()
    love.graphics.pop()
    local data = canvas:newImageData()
    local colors = {}
    for y = 0, data:getHeight() - 1 do
      for x = 0, data:getWidth() - 1 do
        local r, g, b, a = data:getPixel(x, y)
        if a > 0.5 then
          colors[("%03d,%03d,%03d"):format(
            math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5),
            math.floor(b * 255 + 0.5))] = true
        end
      end
    end
    local out = {}
    for color in pairs(colors) do out[#out + 1] = color end
    table.sort(out)
    return table.concat(out, ";")
  end

  check("Dramatic Shape export is live", dramatic.lib ~= nil)
  characters.select("GREEN")
  Pipelines.setLevel("voxel", 1)
  Pipelines.syncOptions(game.save.options)
  U.teleport(game, "PALLET_TOWN", 10, 12, "down")
  characters.refreshVisuals(game)
  -- Keep the proof frame unambiguous: the isolated QA map contains only the
  -- selected player, so no green-clothed Pallet NPC can be mistaken for her.
  game.overworld.entities = { game.overworld.player }
  game.overworld.npcs = {}
  game.overworld.player.facing = "down"
  U.wait(60)
  local pipeline = Pipelines.worldPipeline()
  check("Voxel owns the live world pass", pipeline == "voxel")
  local def = game.data.sprites.SPRITE_KA_GREEN
  check("Green has a RED++ palette source",
    def and def.paletteSource == "ROM:SpriteSheetPointerTable[21]")
  check("live player uses Green's authored sheet", game.overworld.player
    and game.overworld.player.sprite
    and game.overworld.player.sprite.def == def)
  local walkW, walkH = game.overworld.player.sprite:resolveImage():getDimensions()
  check("Voxel keeps Casey's walking sheet exactly 16x96",
    walkW == 16 and walkH == 96)

  local voxelBattleBack = Runtime.call("player.sprite",
    function(path) return path end, "vanilla-player-back.png",
    { side = "back", kind = "battle" })
  check("Voxel swaps only Green's battle back to full standing Casey",
    type(voxelBattleBack) == "string"
    and voxelBattleBack:match("/assets/characters/green_voxel_front%.png$") ~= nil)

  local modes = {
    { "redpp", "22_green_voxel_advanced.png" },
    { "ogred", "23_green_voxel_og_red.png" },
    { "gbc", "24_green_voxel_sgb.png" },
    { "classic", "25_green_voxel_classic.png" },
  }
  local signatures = {}
  for _, row in ipairs(modes) do
    game.save.options.colors = row[1]
    PaletteFX.setMode(row[1])
    characters.refreshVisuals(game)
    game.overworld.entities = { game.overworld.player }
    game.overworld.npcs = {}
    game.overworld.player.facing = "down"
    U.wait(35)
    local player = assert(game.overworld.player)
    local walk = player.sprite:resolveImage()
    local sw, sh = walk:getDimensions()
    check(row[1] .. " leaves walking art 16x96", sw == 16 and sh == 96)
    signatures[row[1]] = signature(walk)
    U.log(row[1] .. " Green palette", signatures[row[1]])
    check(row[1] .. " Voxel capture", U.shot(game, dir .. "/" .. row[2]))
  end
  check("Advanced and OG Red resolve different Green palettes",
    signatures.redpp ~= signatures.ogred)
  check("Advanced and Classic resolve different Green palettes",
    signatures.redpp ~= signatures.classic)

  -- Build a real trainer battle while Voxel is live.  The intro surface must
  -- now be the 56x56 standing Casey art, while the overworld checks above
  -- prove that no walking frame was enlarged or replaced.
  game.save.player.name = "CASEY"
  game.save.player.rival = "RED"
  game.save.party = { Pokemon.new(game.data, "BULBASAUR", 5) }
  local battle = BattleState.newTrainer(game, "OPP_RIVAL1", 3)
  game.overworld:pushBattle(battle)
  local introReady = false
  for _ = 1, 360 do
    if battle.showEnemyTrainer and battle.showPlayerBack
        and game.stack:top() == battle then
      introReady = true
      break
    end
    U.wait(1)
  end
  check("Voxel Casey battle reaches trainer intro", introReady)
  local bw, bh = battle.playerBackPic:getDimensions()
  check("live Voxel battle loads standing Casey at 56x56",
    bw == 56 and bh == 56)
  U.wait(80)
  check("Voxel standing Casey battle capture",
    U.shot(game, dir .. "/26_green_voxel_battle_stand.png"))

  U.log(("PHASE8 GREEN VOXEL RESULT pass=%d fail=%d")
    :format(pass, fail))
  love.event.quit(fail == 0 and 0 or 1)
end
