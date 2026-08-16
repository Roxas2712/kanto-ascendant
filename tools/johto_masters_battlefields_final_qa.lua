-- Bounded final visual acceptance for the three Johto Master battlefields.
-- This is a renderer sampler, not a passage traversal or battle-result proof:
-- it enters each registered finale at its real threshold, captures the live
-- Master, starts the production Johto battle context, captures the trainer
-- intro, then discards that unresolved battle in an isolated QA identity.

return function(game)
  local engine = os.getenv("GEN1RECOMP_DIR") or "."
  local U = dofile(engine .. "/tests/drivers/util.lua")
  local GBCFX = require("src.render.GBCFX")
  local Pipelines = require("src.render.Pipelines")
  local Pokemon = require("src.pokemon.Pokemon")
  local mode = assert(os.getenv("JOHTO_BATTLEFIELD_MODE"),
    "JOHTO_BATTLEFIELD_MODE=2d|voxel required")
  local root = assert(os.getenv("SHOT_DIR"), "SHOT_DIR required")
  assert(mode == "2d" or mode == "voxel", "invalid Johto battlefield mode")

  local exports = assert(game.mods and game.mods.exports,
    "mod exports missing")
  local ascendant = assert(exports.kanto_ascendant,
    "Kanto Ascendant did not load")
  local passages = assert(ascendant.johtoMastersPassages,
    "Johto passages export missing")
  local masters = assert(ascendant.johtoMasters,
    "Johto Masters controller missing")
  local onboarding = assert(ascendant.onboarding,
    "postgame onboarding controller missing")
  local characters = assert(ascendant.extendedCharacters,
    "extended character export missing")
  assert(passages.contentEnabled, "Johto production maps are disabled")

  -- This bounded visual identity is intentionally post-Hall-of-Fame. Start
  -- the current production cadence instead of relying on the removed v2
  -- fixture shape, so eligibility and active-run guards remain observable.
  game.save.hallOfFame = { { qa = "johto-battlefield-visual" } }
  -- This visual probe is not the onboarding test. Mark the one-time Oak
  -- orientation as already seen before the first map.entered event so no
  -- unrelated TextBox can contaminate an arena screenshot.
  onboarding.state().shown = true
  local began, beginReason = masters.beginRun(game)
  assert(began, "Johto visual cadence did not start: " .. tostring(beginReason))

  game.save.options = game.save.options or {}
  game.save.options.textSpeed = 1
  game.save.options.gbcfx = 0
  GBCFX.setLevel(0)
  assert(GBCFX.level == 0 and not GBCFX.active(),
    "GBCFX must be hard OFF for battlefield evidence")

  local dramatic, overworldBattle
  if mode == "voxel" then
    dramatic = assert(exports.DRAMALESS_SHAPE,
      "DRAMALESS_SHAPE dependency did not load")
    overworldBattle = assert(dramatic.lib.require("OverworldBattle"),
      "DRAMALESS OverworldBattle missing")
    -- Enter FULL from a non-FULL rung so its one-shot preset applies, then
    -- explicitly retain staged battles for a deterministic trainer intro.
    Pipelines.setLevel("voxel", 2)
    U.wait(3)
    Pipelines.setLevel("voxel", 1)
    Pipelines.syncOptions(game.save.options)
    overworldBattle.setting:setIndex(1, game)
    overworldBattle.backSetting:setIndex(1, game)
    assert(Pipelines.level("voxel") == 1
      and Pipelines.levelLabel("voxel") == "FULL"
      and Pipelines.worldPipeline() == "voxel",
      "DRAMALESS FULL world pipeline is not active")
  else
    Pipelines.setLevel("voxel", 0)
    Pipelines.syncOptions(game.save.options)
    assert(Pipelines.level("voxel") == 0
      and Pipelines.worldPipeline() ~= "voxel",
      "2D acceptance accidentally retained Voxel")
    assert(not exports.DRAMALESS_SHAPE,
      "2D acceptance must not load DRAMALESS")
  end

  -- Make the negative alias assertion observable: BLUE's Kanto rival would
  -- be GREEN, but none of the Johto classes may resolve through that path.
  characters.select("BLUE")
  characters.refreshVisuals(game)
  game.save.party = { Pokemon.new(game.data, "MEWTWO", 100) }

  local cases = {
    {
      key = "silver", field = "SILVER_FINALE", tag = "01_silver",
      class = "KA_JOHTO_SILVER", tileset = "GYM",
      source = "BRUNOS_ROOM", sprite = "SPRITE_KA_JOHTO_SILVER",
      front = "assets/johto_masters/battle/silver_front.png",
      voxel = "assets/johto_masters/battle/silver_voxel_front_hd.png",
    },
    {
      key = "kris", field = "KRIS_FINALE", tag = "02_kris",
      class = "KA_JOHTO_KRIS", tileset = "CEMETERY",
      source = "AGATHAS_ROOM", sprite = "SPRITE_KA_JOHTO_KRIS",
      front = "assets/johto_masters/battle/kris_front.png",
      voxel = "assets/johto_masters/battle/kris_voxel_front_hd.png",
    },
    {
      key = "gold", field = "GOLD_FINALE", tag = "03_gold",
      class = "KA_JOHTO_GOLD", tileset = "GYM",
      source = "CHAMPIONS_ROOM", sprite = "SPRITE_KA_JOHTO_GOLD",
      front = "assets/johto_masters/battle/gold_front_color_v1.png",
      voxel = "assets/johto_masters/battle/gold_voxel_front_hd.png",
    },
  }

  local function endsWith(path, suffix)
    return type(path) == "string" and path:sub(-#suffix) == suffix
  end

  local function alphaCoverage(imageData)
    local count, colors = 0, {}
    for y = 0, imageData:getHeight() - 1 do
      for x = 0, imageData:getWidth() - 1 do
        local r, g, b, a = imageData:getPixel(x, y)
        if a > 0.02 then
          count = count + 1
          colors[(math.floor(r * 31) * 1024)
            + (math.floor(g * 31) * 32) + math.floor(b * 31)] = true
        end
      end
    end
    local colorCount = 0
    for _ in pairs(colors) do colorCount = colorCount + 1 end
    return count, colorCount
  end

  local seenVoxelSources = {}
  for _, row in ipairs(cases) do
    local spec = assert(passages.MAPS[row.field])
    local mapDef = assert(game.data.maps[spec.id], "live finale missing")
    assert(spec.arenaRole == "johto_master_battlefield"
      and spec.arenaSource == row.source,
      row.key .. " is not the audited Indigo battlefield")
    assert(mapDef.tileset == row.tileset and mapDef.voxelMode == "MAP_STUDIO"
      and mapDef.outdoor == false, row.key .. " map renderer contract")
    assert(#mapDef.objects == 1
      and mapDef.objects[1].sprite == row.sprite,
      row.key .. " has a wrong Master or duplicate finale actor")
    local visibleObjects = 0
    for _, object in ipairs(mapDef.objects) do
      if object.renderMode ~= "none" then visibleObjects = visibleObjects + 1 end
    end
    assert(visibleObjects == 1, row.key .. " has duplicate visible finale actors")

    U.teleport(game, spec.id, spec.entryX, spec.entryY, "up")
    U.wait(mode == "voxel" and 360 or 120)
    assert(game.overworld and game.overworld.map.id == spec.id
      and game.overworld.map.def.tileset == row.tileset
      and game.overworld.map.def.voxelMode == "MAP_STUDIO",
      row.key .. " runtime entered the wrong battlefield")
    assert(game.overworld.player.cellX == spec.entryX
      and game.overworld.player.cellY == spec.entryY,
      row.key .. " runtime missed the arena entrance")
    if mode == "voxel" then
      assert(Pipelines.level("voxel") == 1
        and Pipelines.worldPipeline() == "voxel",
        row.key .. " fell out of FULL Voxel")
    else
      assert(Pipelines.level("voxel") == 0,
        row.key .. " left native 2D")
    end
    assert(GBCFX.level == 0 and not GBCFX.active(),
      row.key .. " re-enabled GBCFX")
    assert(U.shot(game, root .. "/" .. row.tag .. "_arena.png"),
      row.key .. " arena screenshot failed")

    local master
    for _, npc in ipairs(game.overworld.npcs or {}) do
      if npc.def and npc.def.text == "TEXT_KA_JOHTO_"
          .. row.key:upper() .. "_MASTER" then
        assert(not master, row.key .. " spawned duplicate Master NPCs")
        master = npc
      end
    end
    assert(master and master.def.sprite == row.sprite,
      row.key .. " live Master identity missing")

    local state = assert(passages.state(true))
    local passageState = assert(state.passages[row.key])
    passageState.status = "entered"
    passageState.clue, passageState.step, passageState.puzzle = true, 3, true
    assert(passages.startBattle(game, game.overworld, master, row.key),
      row.key .. " production battle did not start")

    local battle
    for _ = 1, 1200 do
      local top = game.stack:top()
      if top and top.johtoPassage == true and top.showEnemyTrainer
          and (top.introSlide or 1) <= 0 and top.phase == "messages"
          and (top.total or 0) > 0 then
        battle = top
        break
      end
      U.wait(1)
    end
    assert(battle, row.key .. " trainer intro never became visible")
    assert(battle.oppClass == row.class and battle.trainer
      and battle.trainer.class == row.class and battle.trainer.id == row.class,
      row.key .. " battle class leaked into a Kanto namespace")
    assert(battle.johtoPassage == true and battle.noPrizeMoney == true
      and battle.postgameTier == nil and battle.postgameForcedTier == nil,
      row.key .. " battle lost its isolated Johto context")
    assert(characters.voxelStandingTrainerCharacter(battle, "enemy") == nil,
      row.key .. " aliased to the selected Kanto rival")

    local trainerDef = assert(game.data.trainers[row.class])
    assert(endsWith(trainerDef.pic, row.front),
      row.key .. " 2D trainer source mismatch: " .. tostring(trainerDef.pic))
    local okData, frontData = pcall(love.image.newImageData, trainerDef.pic)
    assert(okData and frontData, row.key .. " 2D trainer source cannot load")
    local pixels, colors = alphaCoverage(frontData)
    assert(pixels > 250 and colors >= 4,
      row.key .. " 2D trainer source is blank or a flat fallback")

    if mode == "voxel" then
      local johtoSpec = assert(characters.voxelStandingTrainerSpec(battle, "enemy"))
      assert(johtoSpec.path == row.voxel,
        row.key .. " Voxel class resolved the wrong source")
      assert(not seenVoxelSources[johtoSpec.path],
        row.key .. " shares another Master's Voxel source")
      seenVoxelSources[johtoSpec.path] = true
      local texture = assert(overworldBattle.sideTexture(battle, "enemy"),
        row.key .. " Voxel trainer texture missing")
      assert(texture.johtoMasterClass == row.class
        and texture.johtoMasterVoxel == true
        and texture.ascendantHighResSource == row.voxel
        and texture.ascendantHighResTrainer == true
        and texture.ascendantStandingTrainer == row.class:gsub("KA_", ""),
        row.key .. " Voxel texture used a fallback or Kanto-rival alias")
      local width, height = texture.canvas:getDimensions()
      assert(width == 320 and height == 288,
        row.key .. " Voxel HD canvas dimensions changed")
      local canvasData = texture.canvas:newImageData()
      local canvasPixels, canvasColors = alphaCoverage(canvasData)
      assert(canvasPixels > 1000 and canvasColors >= 4,
        row.key .. " Voxel trainer canvas is blank or flat")
    end
    assert(GBCFX.level == 0 and not GBCFX.active(),
      row.key .. " battle intro re-enabled GBCFX")
    U.wait(24)
    assert(U.shot(game, root .. "/" .. row.tag .. "_battle_intro.png"),
      row.key .. " battle-intro screenshot failed")

    while game.stack:top() and game.stack:top() ~= game.overworld do
      game.stack:pop()
    end
    U.wait(6)
  end

  if mode == "voxel" then
    local count = 0
    for _ in pairs(seenVoxelSources) do count = count + 1 end
    assert(count == 3, "Voxel evidence did not use three distinct sources")
  end
  U.log("JOHTO BATTLEFIELDS FINAL " .. mode:upper() .. " PASS", root)
  love.event.quit(0)
end
