-- Real LÖVE acceptance for the historical follower-idle and visible-Wilds
-- pursuit regressions. Run once flat and once with DRAMALESS_SHAPE enabled.

return function(game)
  local U = dofile(os.getenv("KA_TEST_UTIL") or "tests/drivers/util.lua")
  local Pokemon = require("src.pokemon.Pokemon")
  local NPC = require("src.world.NPC")
  local Pipelines = require("src.render.Pipelines")
  local shotDir = assert(os.getenv("SHOT_DIR"), "SHOT_DIR is required")
  local expectVoxel = os.getenv("EXPECT_VOXEL") == "1"

  U.wait(45)
  local exports = assert(game.mods and game.mods.exports, "mod exports missing")
  local ascendant = assert(exports.kanto_ascendant, "Ascendant missing")
  local native = assert(ascendant.singleFollower, "native follower missing")
  local wilds = assert(exports.overworld_wild_spawns, "bundled Wilds missing")
  local logic = assert(wilds.logic, "Wilds logic missing")
  local Behavior = assert(wilds.lib.require("behavior"))
  local Movement = assert(wilds.lib.require("movement"))
  local SpawnFx = assert(wilds.lib.require("spawn_fx"))

  assert(ascendant.internalWilds and ascendant.internalWilds.bundled == true,
    "motion QA accidentally loaded standalone Wilds")
  if expectVoxel then
    assert(exports.DRAMALESS_SHAPE or exports.DRAMATIC_SHAPE,
      "DRAMALESS/DRAMATIC Shape is required for Voxel QA")
    Pipelines.setLevel("voxel", 1)
    Pipelines.syncOptions(game.save.options)
    U.wait(90)
    assert(logic.voxel:isVoxelCameraActive(),
      "Wilds did not observe an active Voxel camera")
  else
    Pipelines.setLevel("voxel", 0)
    Pipelines.syncOptions(game.save.options)
    U.wait(20)
    assert(Pipelines.level("voxel") == 0, "flat QA did not disable Voxel")
  end

  game.save.flags = game.save.flags or {}
  game.save.flags.EVENT_FOLLOWED_OAK_INTO_LAB = true
  game.save.flags.EVENT_GOT_STARTER = true
  game.save.flags.EVENT_GOT_POKEDEX = true
  game.save.onBike = false
  game.save.repelSteps = 9999
  game.save.party = { Pokemon.new(game.data, "RAICHU", 30) }

  local function dismissBanner()
    U.wait(90)
    U.tap(game, "b")
    U.wait(30)
  end

  local function cellFree(ow, x, y)
    local map = ow.map
    if not map:inBounds(x, y) or not map:isWalkableCell(x, y) then return false end
    if map.warpAtCell and map:warpAtCell(x, y) then return false end
    local at = ow.npcAtCell and ow:npcAtCell(x, y)
    return not at or at.pikachuFollower or at._ascendantNativeFollower
  end

  local function findLane(ow)
    local map = ow.map
    for y = 2, map.heightCells - 3 do
      for x = 2, map.widthCells - 8 do
        local ok = true
        -- Player/wild lane plus open north/south detour around x+1.
        for xx = x - 1, x + 6 do
          for yy = y - 1, y + 1 do
            if not cellFree(ow, xx, yy) then ok = false break end
          end
          if not ok then break end
        end
        if ok then return x, y end
      end
    end
    error("no open 8x3 motion-QA lane on " .. tostring(map.id))
  end

  -- ------------------------------------------------ follower idle (real engine)
  U.teleport(game, "ROUTE_22", 8, 8, "right")
  dismissBanner()
  if logic._clearMap then logic:_clearMap("ROUTE_22") end
  local laneX, laneY = findLane(game.overworld)
  U.teleport(game, "ROUTE_22", laneX + 3, laneY, "right")
  U.wait(20)
  assert(native.refresh(game), "native follower did not refresh")
  U.wait(20)

  local beforePlayerX = game.overworld.player.cellX
  for _ = 1, 80 do
    table.insert(game.input.pressQueue, "right")
    game.input.state.right = true
    coroutine.yield()
    if game.overworld.player.cellX ~= beforePlayerX then break end
  end
  game.input.state.right = false
  assert(game.overworld.player.cellX ~= beforePlayerX,
    "real player step did not commit")
  U.wait(28)

  local follower = assert(native.entities(game)[1], "real follower absent")
  local stableFacing = follower.facing
  local stableX, stableY = follower.cellX, follower.cellY
  assert(follower.followerSpecies == "RAICHU", "wrong real follower species")
  assert(U.shot(game, shotDir .. "/01_follower_idle_start.png"))
  local facingChanges, pixelOffsets = 0, 0
  for _ = 1, 240 do
    coroutine.yield()
    if follower.facing ~= stableFacing then facingChanges = facingChanges + 1 end
    if follower.px ~= follower.cellX * 16 or follower.py ~= follower.cellY * 16 then
      pixelOffsets = pixelOffsets + 1
    end
    assert(follower.cellX == stableX and follower.cellY == stableY,
      "idle follower changed committed cell")
  end
  assert(facingChanges == 0,
    "generic follower changed facing while idle: " .. facingChanges)
  assert(pixelOffsets == 0,
    "generic follower retained idle pixel offsets: " .. pixelOffsets)
  assert(follower.idle == nil, "generic follower retained Pikachu idle state")
  assert(U.shot(game, shotDir .. "/02_follower_idle_after_240f.png"))

  -- Remove the real follower before constructing controlled Wilds geometry.
  game.save.party = {}
  native.refresh(game)
  U.wait(12)
  assert(#native.entities(game) == 0, "follower remained after empty party")

  local function removeEntity(ow, wanted)
    for index = #ow.entities, 1, -1 do
      if ow.entities[index] == wanted then table.remove(ow.entities, index) end
    end
  end

  local blockerSeq = 0
  local function makeBlocker(ow, x, y)
    blockerSeq = blockerSeq + 1
    local npc = NPC.new(game.data, ow.map.id, {
      index = 0x7f00 + blockerSeq,
      name = "ASCENDANT_QA_FOLLOWER_" .. blockerSeq,
      sprite = "SPRITE_PIKACHU", movement = "STAY", range = "NONE",
      x = x, y = y,
    })
    npc.passable = true
    npc._ascendantNativeFollower = true
    npc._ascendantChainIndex = blockerSeq + 1
    ow.entities[#ow.entities + 1] = npc
    return npc
  end

  local function spawnAggressive(ow, x, y, species)
    local record, err, entity = logic:trySpawn(game, {
      force = true, x = x, y = y,
      species = species or "MANKEY", level = 18,
      behavior = Behavior.AGGRESSIVE,
    })
    assert(record and entity, "aggressive spawn failed: " .. tostring(err))
    SpawnFx.updateEntity(entity, 1, { map = ow.map, spawnFx = logic.spawnFx })
    assert(logic:_attach(entity), "aggressive spawn could not attach")
    Movement.setFacing(entity, "right")
    entity.behaviorState.nextActionAt = math.huge
    if expectVoxel then
      logic.voxel:updateEntity(entity)
      assert(entity.worldRenderer == "DRAMATIC_SHAPE"
          and entity.pokemonRenderer == "NATIVE_SPRITE_RENDERER"
          and entity.voxelRegistered == true,
        "aggressive wild is not a native Voxel billboard")
    end
    return record, entity
  end

  -- ------------------------------------------ Wilds alert + one-tile detour
  local ow = game.overworld
  laneX, laneY = findLane(ow)
  ow.player.cellX, ow.player.cellY = laneX + 4, laneY
  ow.player.px, ow.player.py = ow.player.cellX * 16, ow.player.cellY * 16
  ow.player.facing = "left"
  local blocker = makeBlocker(ow, laneX + 1, laneY)
  local record, wild = spawnAggressive(ow, laneX, laneY, "MANKEY")
  local startDistance = math.abs(wild.cellX - ow.player.cellX)

  local sawAlert = false
  for _ = 1, 180 do
    coroutine.yield()
    if ow.emote and ow.emote.npc == wild then sawAlert = true break end
  end
  assert(sawAlert, "real aggressive Wilds alert never appeared")
  assert(U.shot(game, shotDir .. "/03_wild_alert_before_detour.png"))

  local sawDetour = false
  for _ = 1, 240 do
    coroutine.yield()
    assert(not (wild.cellX == blocker.cellX and wild.cellY == blocker.cellY),
      "real aggressive Wild overlapped follower blocker")
    if wild.cellY ~= laneY or (wild.targetY and wild.targetY ~= laneY) then
      sawDetour = true
      break
    end
  end
  assert(sawDetour, "real aggressive Wild did not take the open detour")
  local currentDistance = math.abs(wild.cellX - ow.player.cellX)
    + math.abs(wild.cellY - ow.player.cellY)
  assert(currentDistance <= startDistance,
    "real detour moved irrecoverably away from player")
  assert(U.shot(game, shotDir .. "/04_wild_running_detour.png"))
  logic:_despawn(record.id, true)
  removeEntity(ow, blocker)
  U.wait(12)

  -- ------------------------------------------ permanent block + real deaggro
  laneX, laneY = findLane(ow)
  ow.player.cellX, ow.player.cellY = laneX + 4, laneY
  ow.player.px, ow.player.py = ow.player.cellX * 16, ow.player.cellY * 16
  ow.player.facing = "left"
  local blockers = {
    makeBlocker(ow, laneX + 1, laneY),
    makeBlocker(ow, laneX - 1, laneY),
    makeBlocker(ow, laneX, laneY - 1),
    makeBlocker(ow, laneX, laneY + 1),
  }
  local sealedRecord, sealed = spawnAggressive(ow, laneX, laneY, "GROWLITHE")
  local chaseBegan = false
  for _ = 1, 240 do
    coroutine.yield()
    if sealed.behaviorState.chasing then chaseBegan = true break end
  end
  assert(chaseBegan, "sealed aggressive Wild never began chase")
  assert(U.shot(game, shotDir .. "/05_wild_blocked_chase.png"))

  local deaggro = false
  for _ = 1, 180 do
    coroutine.yield()
    if not sealed.behaviorState.chasing
        and sealed.behaviorState.state == Behavior.STATE.IDLE then
      deaggro = true
      Movement.setFacing(sealed, "left") -- keep the proof stable after release
      break
    end
  end
  assert(deaggro, "permanently blocked Wild did not deaggro")
  assert(not Movement.isBusy(sealed), "deaggro left a movement reservation busy")
  assert(U.shot(game, shotDir .. "/06_wild_deaggro_after_block.png"))

  logic:_despawn(sealedRecord.id, true)
  for _, npc in ipairs(blockers) do removeEntity(ow, npc) end

  print(("FOLLOWER/WILDS MOTION %s PASS: idle=%d frames, detour=yes, deaggro=yes")
    :format(expectVoxel and "VOXEL" or "2D", 240))
end
