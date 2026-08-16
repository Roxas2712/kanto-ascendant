-- Focused renderer proof: only native 16x16 overworld walking art.

return function(game)
  local U = dofile("tests/drivers/util.lua")
  local Pipelines = require("src.render.Pipelines")
  local Runtime = require("src.mods.Runtime")
  local SpriteRenderer = require("src.render.SpriteRenderer")
  local dir = assert(os.getenv("SHOT_DIR"), "SHOT_DIR is required")
  local exports = assert(game.mods and game.mods.exports)
  local ascendant = assert(exports.kanto_ascendant)
  local characters = ascendant.extendedCharacters
  local pass, fail = 0, 0

  local function check(label, value)
    if value then pass = pass + 1 else fail = fail + 1 end
    U.log(value and "PASS" or "FAIL", label)
  end

  Pipelines.setLevel("voxel", 0)
  Pipelines.syncOptions(game.save.options)
  game.mods.modOptions.kanto_ascendant =
    game.mods.modOptions.kanto_ascendant or {}
  game.mods.modOptions.kanto_ascendant.character_sprite_style = "crystal"
  Runtime.emit("mod.options_changed", {
    game = game, mod = "kanto_ascendant",
    key = "character_sprite_style", value = "crystal",
  })

  U.teleport(game, "ROUTE_1", 5, 5, "down")
  U.wait(90) -- let the route banner and entry palette transition finish

  local cases = {
    { id = "RED", tag = "red" },
    { id = "GREEN", tag = "casey" },
    { id = "BLUE", tag = "blue" },
  }
  for _, case in ipairs(cases) do
    local player = game.overworld.player
    local spriteId = "SPRITE_KA_CRYSTAL_" .. case.id .. "_WALK"
    if characters then
      characters.select(case.id)
      characters.refreshVisuals(game)
    else
      -- Packaged-release proof can address the registered sheet directly;
      -- the test remains about walking assets and never enters battle code.
      player.sprite = SpriteRenderer.new(assert(game.data.sprites[spriteId]),
        "walking-native-proof")
    end
    check(case.id .. " resolves its Crystal walking sheet",
      game.data.sprites[spriteId] ~= nil)
    for _, facing in ipairs({ "down", "left", "up" }) do
      player.facing = facing
      player.bumpFrames = 0
      player.animClock = 0
      U.wait(10)
      check(case.id .. " " .. facing .. " screenshot",
        U.shot(game, dir .. "/" .. case.tag .. "_" .. facing .. ".png"))
    end
  end

  U.log(("WALKING NATIVE POLISH RESULT pass=%d fail=%d"):format(pass, fail))
  love.event.quit(fail == 0 and 0 or 1)
end
