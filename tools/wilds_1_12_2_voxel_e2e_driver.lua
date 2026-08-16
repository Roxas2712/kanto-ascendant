return function(game)
  local U = dofile("tests/drivers/util.lua")
  local PaletteFX = require("src.render.PaletteFX")
  local Pipelines = require("src.render.Pipelines")
  local Pokemon = require("src.pokemon.Pokemon")
  local shotDir = assert(os.getenv("SHOT_DIR"), "SHOT_DIR is required")

  U.wait(30)
  local exports = assert(game.mods and game.mods.exports, "exports missing")
  local ascendant = assert(exports.kanto_ascendant, "Ascendant missing")
  local wilds = assert(exports.overworld_wild_spawns, "Wilds missing")
  assert(wilds.version == "1.12.2", "Wilds 1.12.2 required")
  assert(exports.DRAMALESS_SHAPE, "supported Dramaless Shape fork missing")
  local compat = assert(ascendant.wildsCompat, "Wilds adapter missing")
  assert(compat.installed and compat.wildsVersion == "1.12.2",
    "Ascendant did not bind Wilds 1.12.2")
  assert(compat.voxelAliasInstalled,
    "Dramaless Shape alias was not installed")
  assert(compat.waterWrapped,
    "Johto water-spawn adapter was not installed")

  local provider = assert(wilds.getSpriteProvider("followers_ex"),
    "Ascendant Johto provider missing")
  local normalCount, shinyCount = 0, 0
  for _, species in ipairs(assert(ascendant.johtoData.order)) do
    local normal = assert(provider:resolve(species, "normal", game),
      species .. " normal walker missing")
    local shiny = assert(provider:resolve(species, "shiny", game),
      species .. " shiny walker missing")
    local nw, nh = love.image.newImageData(normal.image):getDimensions()
    local sw, sh = love.image.newImageData(shiny.image):getDimensions()
    assert(nw == 16 and nh == 96,
      species .. " normal walker is not 16x96")
    assert(sw == 16 and sh == 96,
      species .. " shiny walker is not 16x96")
    normalCount = normalCount + 1
    shinyCount = shinyCount + 1
  end
  assert(normalCount == 100 and shinyCount == 100,
    "Johto walker matrix incomplete")

  game.save.party = {
    Pokemon.new(game.data, "BLASTOISE", 80, function() return 15 end),
  }
  game.save.options = game.save.options or {}
  -- The reusable QA identity may retain a tester's SGB/DMG palette.  Pin this
  -- visual proof to Ascendant's default advanced-colour presentation so a
  -- previous local option cannot make valid true-colour art look corrupted.
  game.save.options.colors = "redpp"
  PaletteFX.setMode("redpp")
  local logic = assert(wilds.logic, "Wilds logic missing")
  local voxel = assert(logic.voxel, "Wilds Voxel adapter missing")
  local SpawnFx = assert(wilds.lib.require("spawn_fx"),
    "Wilds spawn FX module missing")

  local function setVoxel(enabled)
    Pipelines.setLevel("voxel", enabled and 1 or 0)
    Pipelines.syncOptions(game.save.options)
    U.wait(enabled and 90 or 30)
    if enabled then
      assert(voxel:isVoxelCameraActive(),
        "Wilds did not recognize the Dramaless Voxel camera")
    end
  end

  local function clearMap(mapId)
    if logic._clearMap then logic:_clearMap(mapId) else logic:clearAll() end
    U.wait(10)
  end

  local function dismissMapBanner()
    U.wait(90)
    U.tap(game, "b")
    U.wait(45)
  end

  local function spawnGroup(rows)
    local player = assert(game.overworld and game.overworld.player)
    local offsets = {
      { 2, 0 }, { 0, 2 }, { 2, 2 }, { -2, 0 }, { 0, -2 },
      { -2, 2 }, { 2, -2 }, { -3, 1 }, { 3, 1 }, { -1, 3 },
      { 1, 3 }, { -3, -1 }, { 3, -1 }, { -1, -3 }, { 1, -3 },
      { -4, 0 }, { 4, 0 }, { 0, -4 }, { 0, 4 },
    }
    local nextOffset = 1
    local out = {}
    for index, row in ipairs(rows) do
      local record, err, entity
      while nextOffset <= #offsets and not record do
        local offset = offsets[nextOffset]
        nextOffset = nextOffset + 1
        record, err, entity = logic:trySpawn(game, {
          force = true,
          x = player.cellX + offset[1],
          y = player.cellY + offset[2],
          species = row.species,
          level = row.level,
          behavior = row.behavior or "IDLE_LOOK",
        })
      end
      assert(record, row.species .. " spawn failed: " .. tostring(err))
      assert(entity and entity.sprite and entity.sprite.def,
        row.species .. " entity renderer missing")
      assert(record.species == row.species and record.level == row.level,
        row.species .. " spawn identity changed")
      assert(entity.sprite.def.image:find(
          "/follower_" .. row.species .. ".png", 1, true),
        row.species .. " did not use Ascendant's walker: "
          .. tostring(entity.sprite.def.image))
      assert(not entity.usingFallback,
        row.species .. " used a fallback sprite")
      -- The driver runs 30 logic ticks per rendered frame. Finish the short
      -- wall-clock spawn pop deterministically before probing the billboard.
      SpawnFx.updateEntity(entity, 1, { map = game.overworld.map })
      assert(logic:_attach(entity),
        row.species .. " could not attach after its spawn pop")
      out[#out + 1] = { record = record, entity = entity }
    end
    U.wait(75)
    return out
  end

  local function assert2D(group)
    assert(Pipelines.level("voxel") == 0,
      "Voxel pipeline was not disabled for the 2D comparison")
    for _, row in ipairs(group) do
      local entity = row.entity
      print(row.record.species .. " 2D renderer:",
        tostring(entity.worldRenderer), tostring(entity.pokemonRenderer))
      assert(entity.render2DFallback ~= true,
        row.record.species .. " entered an emergency fallback")
    end
  end

  local function assertVoxel(group)
    for _, row in ipairs(group) do
      local entity = row.entity
      voxel:updateEntity(entity)
      assert(entity.worldRenderer == "DRAMATIC_SHAPE",
        row.record.species .. " did not enter the Voxel world renderer")
      assert(entity.pokemonRenderer == "NATIVE_SPRITE_RENDERER",
        row.record.species .. " did not use a native Voxel billboard")
      assert(entity.voxelRegistered and entity.voxelUpdateOk,
        row.record.species .. " Voxel registration failed")
      assert(entity.render2DFallback ~= true
          and entity.dramaticBillboardSkipped ~= true,
        row.record.species .. " fell back to a post-Voxel overlay")
      local poseOk, poseErr = voxel.probePose(entity)
      assert(poseOk, row.record.species .. " unsafe Voxel pose: "
        .. tostring(poseErr))
    end
  end

  setVoxel(false)
  U.teleport(game, "ROUTE_22", 8, 8, "down")
  dismissMapBanner()
  clearMap("ROUTE_22")
  local starters = spawnGroup({
    { species = "CHIKORITA", level = 12 },
    { species = "NATU", level = 18 },
    { species = "AMPHAROS", level = 30 },
  })
  assert2D(starters)
  assert(U.shot(game, shotDir .. "/01_route22_johto_2d.png"))

  setVoxel(true)
  assertVoxel(starters)
  U.wait(90)
  assert(U.shot(game, shotDir .. "/02_route22_johto_voxel.png"))

  clearMap("ROUTE_22")
  local mixed = spawnGroup({
    { species = "TOTODILE", level = 14 },
    { species = "UMBREON", level = 32 },
    { species = "SUICUNE", level = 50 },
  })
  assertVoxel(mixed)
  U.wait(90)
  assert(U.shot(game, shotDir .. "/03_route22_johto_mixed_voxel.png"))

  U.teleport(game, "ROUTE_22", 24, 11, "up")
  dismissMapBanner()
  clearMap("ROUTE_22")
  local waterRecord, waterErr, waterEntity = logic:trySpawnWater(game, {
    force = true,
    species = "MANTINE",
    level = 42,
  })
  assert(waterRecord and waterEntity,
    "MANTINE water spawn failed: " .. tostring(waterErr))
  assert(waterRecord.species == "MANTINE" and waterRecord.level == 42
      and waterRecord.surface == "WATER",
    "Johto water identity/surface changed")
  SpawnFx.updateEntity(waterEntity, 1, { map = game.overworld.map })
  assert(logic:_attach(waterEntity),
    "MANTINE could not attach after its water spawn pop")
  assertVoxel({ { record = waterRecord, entity = waterEntity } })
  U.wait(90)
  assert(U.shot(game, shotDir .. "/04_route22_johto_water_voxel.png"))

  U.teleport(game, "MT_MOON_1F", 14, 33, "up")
  dismissMapBanner()
  clearMap("MT_MOON_1F")
  local cave = spawnGroup({
    { species = "CROBAT", level = 36 },
    { species = "SNEASEL", level = 34 },
    { species = "TYRANITAR", level = 55 },
  })
  assertVoxel(cave)
  U.wait(90)
  assert(U.shot(game, shotDir .. "/05_mt_moon_johto_voxel.png"))

  assert(logic:_startBattle(cave[3].record),
    "Wilds contact battle did not queue")
  local battle
  for _ = 1, 480 do
    local top = game.stack:top()
    if top and top.phase then battle = top end
    if battle and battle.phase == "menu" then break end
    U.tap(game, "a")
    U.wait(3)
  end
  assert(battle and battle.phase == "menu",
    "Wilds contact battle did not reach the command menu")
  assert(battle.enemy and battle.enemy.mon
      and battle.enemy.mon.species == "TYRANITAR"
      and battle.enemy.mon.level == 55,
    "Wilds contact battle changed Tyranitar's identity")
  U.wait(60)
  assert(U.shot(game, shotDir .. "/06_tyranitar_contact_battle_voxel.png"))

  print("WILDS 1.12.2 JOHTO MATRIX PASS: 100 normal + 100 shiny sheets")
  print("WILDS 1.12.2 2D PASS: CHIKORITA NATU AMPHAROS")
  print("WILDS 1.12.2 VOXEL PASS: 10 representative Johto species")
  print("WILDS 1.12.2 WATER PASS: MANTINE L42")
  print("WILDS 1.12.2 CONTACT BATTLE PASS: TYRANITAR L55")
end
