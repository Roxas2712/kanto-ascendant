-- Real field-scene capture for the representative #252-279 P1 acceptance.
-- It deliberately uses the native follower and bundled Wilds interfaces, not
-- raw runtime sheets. EXTENDED_WORLD_VOXEL=1 additionally asserts the real
-- DRAMALESS voxel camera and its registered Wild entity.

return function(game)
  local U = dofile(os.getenv("KA_TEST_UTIL") or "tests/drivers/util.lua")
  local Pokemon = require("src.pokemon.Pokemon")
  local Pipelines = require("src.render.Pipelines")
  local PaletteFX = require("src.render.PaletteFX")
  local output = assert(os.getenv("EXTENDED_WORLD_DIR"), "EXTENDED_WORLD_DIR required")
  local expectVoxel = os.getenv("EXTENDED_WORLD_VOXEL") == "1"
  local captureMap = os.getenv("EXTENDED_WORLD_MAP") or "ROUTE_1"
  local order = {}
  for species in (os.getenv("EXTENDED_SCENE_SPECIES")
      or "TREECKO,AMBIPOM,AZURILL,WYNAUT"):gmatch("[^,%s]+") do
    order[#order + 1] = species:upper()
  end

  U.wait(45)
  local exports = assert(game.mods and game.mods.exports, "mod exports missing")
  local ascendant = assert(exports.kanto_ascendant, "Ascendant missing")
  for _, species in ipairs(order) do
    assert(ascendant.extendedSpeciesRuntime.bySpecies[species],
      "not an extended-runtime species: " .. species)
  end
  local native = assert(ascendant.singleFollower, "native follower missing")
  local wilds = assert(exports.overworld_wild_spawns, "bundled Wilds missing")
  local logic = assert(wilds.logic, "Wilds logic missing")
  local Behavior = assert(wilds.lib.require("behavior"), "Wilds behavior missing")
  local SpawnFx = assert(wilds.lib.require("spawn_fx"), "Wilds spawn FX missing")
  assert(ascendant.internalWilds and ascendant.internalWilds.bundled == true,
    "world capture did not load Ascendant's bundled Wilds")

  if expectVoxel then
    assert(exports.DRAMALESS_SHAPE or exports.DRAMATIC_SHAPE,
      "DRAMALESS/DRAMATIC Shape required for Voxel capture")
    Pipelines.setLevel("voxel", 1)
    Pipelines.syncOptions(game.save.options)
    U.wait(90)
    assert(logic.voxel:isVoxelCameraActive(), "Voxel camera was not active")
  else
    Pipelines.setLevel("voxel", 0)
    Pipelines.syncOptions(game.save.options)
    U.wait(20)
  end

  game.save.flags = game.save.flags or {}
  game.save.flags.EVENT_FOLLOWED_OAK_INTO_LAB = true
  game.save.flags.EVENT_GOT_STARTER = true
  game.save.flags.EVENT_GOT_POKEDEX = true
  game.save.onBike, game.save.repelSteps = false, 9999
  -- ADVANCED is a genuine engine palette mode, selected here solely to make
  -- per-species identity reviewable in field/voxel evidence.
  game.save.options = game.save.options or {}
  game.save.options.colors = "redpp"
  PaletteFX.setMode("redpp")
  -- Exercise the real banner feature, but select its shortest supported
  -- duration so this capture can wait for *its actual expiry* rather than
  -- hide an overlay or photograph through it at fast-forward speed.
  game.mods.modOptions = game.mods.modOptions or {}
  game.mods.modOptions.kanto_ascendant = game.mods.modOptions.kanto_ascendant or {}
  game.mods.modOptions.kanto_ascendant.qol_location_banners = 1
  game.save.options = game.save.options or {}
  game.save.options.modOptions = game.save.options.modOptions or {}
  game.save.options.modOptions.kanto_ascendant = game.mods.modOptions.kanto_ascendant
  U.teleport(game, captureMap, 8, 8, "right")

  local function free(ow, x, y)
    local map = ow.map
    if not map:inBounds(x, y) or not map:isWalkableCell(x, y) then return false end
    if map.warpAtCell and map:warpAtCell(x, y) then return false end
    return not (ow.npcAtCell and ow:npcAtCell(x, y))
  end
  local function lane(ow)
    local map = ow.map
    for y = math.max(2, math.floor(map.heightCells / 2) - 2), map.heightCells - 3 do
      for x = 2, map.widthCells - 7 do
        local open = true
        for xx = x, x + 5 do
          if not free(ow, xx, y) then open = false break end
        end
        if open then return x, y end
      end
    end
    error("no capture lane on " .. tostring(map.id))
  end
  local captures = {}
  local prefix = expectVoxel and "voxel" or "field_2d"
  local function settleMap()
    -- A teleport can queue a native map-entry TextBox.  Fast-forward leaves
    -- its wall-clock fade frozen, so wait for the real stack to settle and
    -- dismiss it through its public input route rather than photographing it.
    for _ = 1, 240 do
      if game.stack:top() == game.overworld then break end
      U.tap(game, "a")
      U.wait(2)
    end
    assert(game.stack:top() == game.overworld, "field-entry overlay did not settle")
    love.timer.sleep(1.1) -- actual 1-second location-banner option above
    U.wait(18)
  end
  local function placePlayer(x, y)
    local player = game.overworld.player
    player.cellX, player.cellY = x, y
    player.px, player.py = x * 16, y * 16
    player.targetX, player.targetY = x, y
    player.facing = "right"
    if logic._clearMap then logic:_clearMap(captureMap) end
  end
  settleMap()
  if logic._clearMap then logic:_clearMap(captureMap) end
  local function shot(group, species)
    local path = output .. "/" .. group .. "/" .. species:lower() .. ".png"
    assert(U.shot(game, path), "shot failed " .. path)
    captures[#captures + 1] = {
      group = group, species = species, path = path,
      visualGate = "pending-manual-contact-review",
    }
  end

  for _, species in ipairs(order) do
    local x, y = lane(game.overworld)
    placePlayer(x + 3, y)
    game.save.party = { Pokemon.new(game.data, species, 30) }
    assert(native.refresh(game), "follower refresh failed " .. species)
    U.wait(18)
    local follower = assert(native.entities(game)[1], "missing follower " .. species)
    assert(follower.followerSpecies == species, "wrong follower " .. tostring(follower.followerSpecies))
    local before = game.overworld.player.cellX
    for _ = 1, 80 do
      game.input.state.right = true
      coroutine.yield()
      if game.overworld.player.cellX ~= before then break end
    end
    game.input.state.right = false
    U.wait(28)
    assert(game.overworld.player.cellX ~= before, "player did not move " .. species)
    assert(follower.cellX ~= follower.targetX or follower.cellY ~= follower.targetY
      or follower.cellX ~= x + 2, "follower did not participate in movement " .. species)
    assert(not (game.overworld.emote and game.overworld.emote.npc == follower),
      "follower was obscured by an emote " .. species)
    shot(prefix .. "_follower", species)
    game.save.party = {}
    native.refresh(game)
    U.wait(12)

    x, y = lane(game.overworld)
    placePlayer(x + 3, y)
    local record, err, entity = logic:trySpawn(game, {
      force = true, x = x + 1, y = y, species = species, level = 30,
      -- A deliberate non-aggressive pose is a visibility control, not an
      -- attachment shortcut: no alert bubble may obscure this evidence.
      behavior = Behavior.IDLE_LOOK,
    })
    assert(record and entity, "wild spawn failed " .. species .. ": " .. tostring(err))
    SpawnFx.updateEntity(entity, 1, { map = game.overworld.map, spawnFx = logic.spawnFx })
    assert(logic:_attach(entity), "wild attach failed " .. species)
    assert(entity.cellX == x + 1 and entity.cellY == y,
      "wild did not remain in the clear capture lane " .. species)
    assert(not (game.overworld.emote and game.overworld.emote.npc == entity),
      "wild was obscured by an emote " .. species)
    if expectVoxel then
      logic.voxel:updateEntity(entity)
      assert(entity.voxelRegistered == true and entity.worldRenderer == "DRAMATIC_SHAPE",
        "wild was not registered in Voxel " .. species)
    end
    U.wait(12)
    shot(prefix .. "_wilds", species)
    logic:_despawn(record.id, true)
    U.wait(12)
  end

  local file = assert(io.open(output .. "/world_capture_manifest.json", "wb"))
  file:write(ascendant.extendedSpeciesRuntime.encodeJson({
    status = "partial", evidence = expectVoxel and "real-dramaless-voxel" or "real-2d-field",
    species = order, captures = captures,
    visualCriteria = {
      "location-banner expired before capture", "target placed two clear cells from player",
      "target was IDLE_LOOK (no alert emote)",
      expectVoxel and "target was registered with DRAMALESS before capture" or "native 2D field scene",
    },
  }))
  file:close()
  print(("EXTENDED SPECIES %s WORLD CAPTURE PASS: %d screenshots")
    :format(expectVoxel and "VOXEL" or "2D", #captures))
  love.event.quit(0)
end
