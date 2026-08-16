-- Real-LÖVE visual gate for the redesigned three-path convergence room.
-- SHOT_DIR is required.  Set KA_HEVO_SHARED_VOXEL=1 and load the
-- qa008_dramaless_runner dependency closure for genuine Voxel captures.
return function(game)
  local U = dofile("tests/drivers/util.lua")
  local Game = require("src.core.Game")
  local Pipelines = require("src.render.Pipelines")
  local RuntimeMap = require("src.world.Map")
  local root = assert(os.getenv("SHOT_DIR"), "SHOT_DIR is required")
  local voxel = os.getenv("KA_HEVO_SHARED_VOXEL") == "1"
  local mapId = "KA_HEVO_SHARED_SEALED_ANTECHAMBER"
  local def = assert(game.data.maps[mapId], "shared room is not registered")
  local runtime = RuntimeMap.new(def, assert(game.data.tilesets.CAVERN))

  game.save.options = game.save.options or {}
  game.save.options.modOptions = game.save.options.modOptions or {}
  game.save.options.modOptions.kanto_ascendant =
    game.save.options.modOptions.kanto_ascendant or {}
  game.save.options.modOptions.kanto_ascendant.qol_location_banners = false

  local receipt
  if voxel then
    Pipelines.setLevel("voxel", 1)
    Pipelines.syncOptions(game.save.options)
    assert(Pipelines.worldPipeline() == "voxel", "DRAMALESS pipeline is not live")
    local present = Pipelines.worldPresent
    Pipelines.worldPresent = function(canvas, ctx)
      local out = present(canvas, ctx)
      local current = ctx and ctx.state and ctx.state.map and ctx.state.map.id
      if out and current then receipt = current end
      return out
    end
  end

  local function capture(tag, x, y, facing)
    assert(runtime:isWalkableCell(x, y),
      "shared-room viewpoint is not walkable: " .. tag)
    receipt = nil
    if voxel then Game.renderer:setWorldOverride(nil) end
    U.teleport(game, mapId, x, y, facing)
    assert(game.overworld and game.overworld.map.id == mapId,
      "shared-room teleport failed")
    assert(game.overworld.player.cellX == x and game.overworld.player.cellY == y,
      "shared-room viewpoint was relocated")
    for _ = 1, 4 do
      if game.stack:top() == game.overworld then break end
      U.tap(game, "b")
      U.wait(12)
    end
    assert(game.stack:top() == game.overworld, "overlay obscures shared room")
    if voxel then
      local ready = false
      for _ = 1, 1800 do
        if receipt == mapId then ready = true break end
        U.wait(1)
      end
      assert(ready, "no DRAMALESS worldPresent receipt for shared room")
    end
    U.wait(30)
    local lane = voxel and "voxel" or "2d"
    assert(U.shot(game, root .. "/" .. lane .. "/" .. tag .. ".png"),
      "shared-room screenshot failed: " .. tag)
  end

  capture("01_red_return_alcove", 3, 19, "up")
  capture("02_blue_return_alcove", 15, 19, "up")
  capture("03_green_return_alcove", 27, 19, "up")
  capture("04_central_landmark_loop", 13, 13, "right")
  capture("05_sealed_door", 15, 6, "up")
  U.log("HEVO shared antechamber visual PASS", voxel and "Voxel" or "2D", 5)
  love.event.quit(0)
end
