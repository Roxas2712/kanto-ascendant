-- Real-engine acceptance for the unmodified official Battle Art 1.9.2 ZIP
-- beside this Kanto Ascendant candidate. The host identity must contain only
-- those two mods (plus the edition-matched German language pack in DE lanes).

return function(game)
  local expectedEngine = assert(os.getenv("QA_ENGINE"),
    "QA_ENGINE is required")
  local edition = assert(os.getenv("QA_EDITION"),
    "QA_EDITION is required")
  local language = assert(os.getenv("QA_LANGUAGE"),
    "QA_LANGUAGE is required")
  assert(expectedEngine == "0.1.96" or expectedEngine == "0.1.98",
    "unsupported QA_ENGINE")
  assert(edition == "red" or edition == "blue" or edition == "yellow",
    "unsupported QA_EDITION")
  assert(language == "en" or language == "de",
    "unsupported QA_LANGUAGE")

  local function wait(frames)
    for _ = 1, frames do coroutine.yield() end
  end

  local function status(id)
    for _, row in ipairs(game.modStatus and game.modStatus.available or {}) do
      if row.id == id then return row end
    end
  end

  local function shot(name)
    local path = assert(os.getenv("SHOT_DIR"), "SHOT_DIR is required")
      .. "/" .. name
    game.capturePath = path
    for _ = 1, 300 do
      if not game.capturePath then break end
      coroutine.yield()
    end
    assert(game.capturePath == nil, "screenshot not consumed: " .. name)
    local file = assert(io.open(path, "rb"), "screenshot absent: " .. path)
    assert(file:seek("end") > 1000, "screenshot empty: " .. path)
    assert(file:close())
  end

  local function tap(button)
    table.insert(game.input.pressQueue, button)
    wait(1)
    game.input.state[button] = false
  end

  local function rectInside(inner, outer)
    return type(inner) == "table" and type(outer) == "table"
      and inner[1] >= outer[1] and inner[2] >= outer[2]
      and inner[1] + inner[3] <= outer[1] + outer[3]
      and inner[2] + inner[4] <= outer[2] + outer[4]
  end

  local function rectsOverlap(a, b)
    return a[1] < b[1] + b[3] and b[1] < a[1] + a[3]
      and a[2] < b[2] + b[4] and b[2] < a[2] + a[4]
  end

  wait(120)
  assert(require("src.core.Version").engine == expectedEngine,
    "runtime engine differs from QA_ENGINE")
  local identity = love.filesystem.getIdentity()
  assert(type(identity) == "string"
      and identity:match("^ka%-ba192%-repair%-")
      and identity ~= "pokemon-love2d",
    "unsafe QA identity: " .. tostring(identity))
  assert(os.getenv("POKEPORT_IDENTITY") == identity,
    "POKEPORT_IDENTITY and LÖVE identity diverged")

  local errors = game.modStatus and game.modStatus.errors or {}
  assert(#errors == 0, "mod loader errors: " .. tostring(errors[1]))
  assert(status("kanto_ascendant")
      and status("kanto_ascendant").state == "loaded",
    "Kanto Ascendant did not load")
  assert(status("BATTLE_ART_VOXEL_FORK")
      and status("BATTLE_ART_VOXEL_FORK").state == "loaded",
    "Battle Art 1.9.2 did not load")
  local languageId = edition == "red" and "deutsch"
    or edition == "blue" and "deutsch-blau" or "deutsch-gelb"
  if language == "de" then
    assert(status(languageId) and status(languageId).state == "loaded",
      "edition-matched German package did not load")
  else
    assert(not status("deutsch") and not status("deutsch-blau")
        and not status("deutsch-gelb"),
      "English lane contains a German package")
  end

  local handles = assert(game.mods and game.mods.mods, "mod handles absent")
  local baHandle = assert(handles.BATTLE_ART_VOXEL_FORK,
    "Battle Art handle absent")
  assert(baHandle.manifest and baHandle.manifest.version == "1.9.2"
      and baHandle.manifest.github == "absol89/DramaticShapeVoxelMod",
    "wrong Battle Art package provenance")
  local rendererCount = 0
  for _, id in ipairs({
    "VOXEL_ASCENDANT", "DRAMALESS_SHAPE", "BATTLE_ART_VOXEL_FORK",
  }) do
    if handles[id] then rendererCount = rendererCount + 1 end
  end
  assert(rendererCount == 1, "double renderer authority detected")
  assert(not handles.DRAMATIC_SHAPE and not handles.overworld_wild_spawns,
    "forbidden renderer/Wilds alias installed")

  local exports = assert(game.mods.exports, "mod exports absent")
  local battleArt = assert(exports.BATTLE_ART_VOXEL_FORK,
    "Battle Art export absent")
  local kasc = assert(exports.kanto_ascendant, "KASC export absent")
  local facade, rendererId, reason, _, receipt =
    kasc.voxelRendererCompat.resolve()
  assert(facade and rendererId == "BATTLE_ART_VOXEL_FORK" and reason == nil,
    "KASC renderer bridge rejected Battle Art: " .. tostring(reason))
  assert(facade ~= battleArt and facade.lib ~= battleArt.lib,
    "KASC leaked Battle Art owner authority")
  assert(receipt and receipt.rendererVersion == "1.9.2"
      and receipt.provenance == "battle-art-1.9.2-reviewed-api-cache-adapter"
      and receipt.cacheRepair
      and receipt.cacheRepair.schema == "ka-battle-art-cache-repair/v1",
    "KASC exact-version/cache-repair receipt drifted")
  assert(facade.lib.require("VoxelMeshDisk") == nil,
    "private cache authority leaked through KASC facade")
  local ownerBattleModule = assert(battleArt.lib.require("OverworldBattle"),
    "Battle Art owner battle module absent")
  local bridgeBattleModule = assert(kasc.voxelRendererCompat.module(
    game, "OverworldBattle"), "KASC Battle Art battle module absent")
  assert(ownerBattleModule == bridgeBattleModule,
    "KASC battle facade diverged from the reviewed owner module")
  local snapHook = rawget(ownerBattleModule,
    kasc.rendererBattleHud.snapHookKey)
  assert(type(snapHook) == "table" and type(snapHook.wrapper) == "function"
      and ownerBattleModule.snapHUDs == snapHook.wrapper,
    "Battle Art snap-receipt hook was not installed on the owner module")

  assert(type(kasc.ascendantUi) == "table"
      and type(kasc.legacyJourney) == "table"
      and type(kasc.legacyOakFinale) == "table"
      and type(kasc.ascendantMenu) == "table"
      and type(kasc.hiddenEvolutionCampaign) == "table",
    "KASC UI/Legacy Oak/quiz exports incomplete")
  assert(kasc.hiddenEvolutionCampaign.validateNoPrototypeFallback(),
    "Hidden Evolution quiz fell back to a prototype")
  local compatible, presentation =
    kasc.hiddenEvolutionCampaign.runtimePreflight(game)
  assert(compatible and presentation,
    "Hidden Evolution presentation preflight failed")

  while game.stack:top() do game.stack:pop() end
  local Overworld = require("src.world.OverworldController")
  game.stack:push(Overworld, "ROUTE_1", 5, 5, "down")
  wait(60)
  assert(game.overworld and game.overworld.map
      and game.overworld.map.id == "ROUTE_1",
    "overworld did not reach Route 1")
  local Pipelines = require("src.render.Pipelines")
  local applied = Pipelines.setLevel("voxel",
    math.min(1, Pipelines.maxLevel("voxel")))
  Pipelines.syncOptions(game.save.options)
  assert(applied == 1 and Pipelines.level("voxel") == 1
      and Pipelines.worldPipeline() == "voxel",
    "Battle Art did not own the voxel world pipeline")

  local ChunkMesher = assert(battleArt.lib.require("ChunkMesher"),
    "Battle Art ChunkMesher absent")
  local MeshDisk = assert(battleArt.lib.require("VoxelMeshDisk"),
    "Battle Art VoxelMeshDisk absent")
  -- Both reviewed current desktop engines deliberately have no persistent
  -- cache backend on macOS. The repaired save call must still let the already
  -- built live mesh land in ChunkMesher's active slot.
  assert(MeshDisk.available() == false,
    "desktop QA unexpectedly acquired a persistent cache backend")
  local terrain, water
  for _ = 1, 1800 do
    terrain, water = ChunkMesher.pair(game.overworld.map, false)
    if terrain then break end
    wait(1)
  end
  assert(terrain, "Battle Art never produced an active Route 1 terrain mesh: "
    .. tostring(ChunkMesher.jobFailure("ROUTE_1", false)))
  assert(ChunkMesher.jobFailure("ROUTE_1", false) == nil,
    "Route 1 mesh retained a failure after activation")
  local matrixLane = os.getenv("QA_MATRIX") == "1"
  if not matrixLane then
    -- Exercise the same non-persistent build path twice in each engine's
    -- primary lane. The remaining edition/language matrix repeats active
    -- world+battle rendering without paying this duplicate cache cost.
    local evict = ChunkMesher.evictRuntime or ChunkMesher.invalidate
    assert(type(evict) == "function",
      "Battle Art exposes no runtime eviction seam")
    evict("ROUTE_1")
    terrain, water = nil, nil
    for _ = 1, 1800 do
      terrain, water = ChunkMesher.pair(game.overworld.map, false)
      if terrain then break end
      wait(1)
    end
    assert(terrain and ChunkMesher.jobFailure("ROUTE_1", false) == nil,
      "Battle Art could not rebuild an evicted non-persistent Route 1 mesh")
  end
  local lane = expectedEngine .. "-" .. edition .. "-" .. language
  shot("battle-art-1.9.2-" .. lane .. "-active-voxel-world.png")

  local Pokemon = require("src.pokemon.Pokemon")
  local BattleState = require("src.battle.BattleState")
  local player = Pokemon.new(game.data, "PIKACHU", 30)
  player.dvs.attack = 15
  player.dvs.defense, player.dvs.speed, player.dvs.special = 9, 9, 9
  player.hp = player.stats.hp
  game.save.party = { player }
  game.save.pokedex = game.save.pokedex or { seen = {}, owned = {} }
  game.save.pokedex.seen = game.save.pokedex.seen or {}
  game.save.pokedex.owned = game.save.pokedex.owned or {}
  local battle = BattleState.newTrainer(game, "OPP_RIVAL1", 1)
  battle.enemy.mon.dvs.attack = 0
  battle.enemy.mon.dvs.defense, battle.enemy.mon.dvs.speed,
    battle.enemy.mon.dvs.special = 9, 9, 9
  battle.onFinish = function() end
  game.overworld:pushBattle(battle)
  for _ = 1, 3600 do
    if battle.phase == "menu" then break end
    if game.stack:top() == battle and battle.phase == "messages"
        and (battle.msgWaiting or battle.msgPrompt) then
      tap("a")
    else
      wait(1)
    end
  end
  assert(battle.phase == "menu", "battle did not reach command menu")
  -- The phase changes during update; allow the renderer-owned draw pass to
  -- publish the exact-shot snap receipt before inspecting HUD geometry.
  wait(60)
  local stage = assert(battleArt.battleStage.state(battle),
    "Battle Art did not publish the staged battle host")
  assert(stage.staged and stage.ready and stage.externalCamera
      and stage.layerOwnsProjection and stage.surfaceOwned
      and stage.ownership and stage.ownership.camera
      and stage.ownership.hud and stage.ownership.battlers
      and stage.ownership.trainers,
    "Battle Art did not retain single staged camera/HUD ownership")
  assert(kasc.rendererBattleHud.inspect().profile ==
      "BATTLE_ART_RENDERER_NATIVE",
    "KASC did not select Battle Art HUD ownership")
  local gender = assert(kasc.pokemonGender, "gender service absent")
  assert(gender.symbol(battle.player.mon, game) == "♂",
    "male player symbol drifted")
  assert(gender.symbol(battle.enemy.mon, game) == "♀",
    "female enemy symbol drifted")
  local genderless = Pokemon.new(game.data, "MAGNEMITE", 20)
  assert(gender.symbol(genderless, game) == nil,
    "genderless Pokémon received a symbol")

  local Font = require("src.render.Font")
  local originalFontDraw, genderDraws = Font.draw, {}
  Font.draw = function(text, x, y, ...)
    genderDraws[#genderDraws + 1] = { text = text, x = x, y = y }
  end
  local genderDrawOk, genderDrawError = pcall(
    gender.drawBattleHUD, battle, 0)
  Font.draw = originalFontDraw
  assert(genderDrawOk, "real battle gender draw failed: "
    .. tostring(genderDrawError))
  assert(#genderDraws == 2
      and genderDraws[1].text == "♀"
      and genderDraws[1].x == 72 and genderDraws[1].y == 8
      and genderDraws[2].text == "♂"
      and genderDraws[2].x == 104 and genderDraws[2].y == 64,
    "real battle gender cells drifted or were duplicated")

  local context
  for _ = 1, 120 do
    context = kasc.rendererBattleHud.context(battle)
    if context then break end
    wait(1)
  end
  shot("battle-art-1.9.2-" .. lane .. "-battle-menu-raw.png")
  local hudInspect = kasc.rendererBattleHud.inspect()
  local snapReceipt = battle[kasc.rendererBattleHud.snapReceiptKey]
  local Voxel3D = assert(battleArt.lib.require("Voxel3D"),
    "Battle Art Voxel3D module absent")
  local hudMode
  if context then
    assert(context.schema == kasc.rendererBattleHud.contextSchema
        and context.rendererId == "BATTLE_ART_VOXEL_FORK"
        and context.profile == "BATTLE_ART_RENDERER_NATIVE",
      "Battle Art HUD context lost exact renderer ownership")
    local worldBounds = { 0, 0, context.shot.pw, context.shot.ph }
    assert(rectInside(context.hp.enemy, worldBounds)
        and rectInside(context.hp.player, worldBounds),
      "Battle Art status panels exceed the active world surface")
    assert(not rectsOverlap(context.hp.enemy, context.hp.player),
      "enemy and player status panels overlap")
    for key, textRect in pairs(context.text or {}) do
      assert(not rectsOverlap(context.hp.enemy, textRect)
          and not rectsOverlap(context.hp.player, textRect),
        "Battle Art status panel overlaps text/menu rect " .. tostring(key))
    end
    -- These are the two Crystal HUD cells after Battle Art's renderer-owned
    -- per-side band transform. Each full glyph cell must stay inside its own
    -- status panel; a genderless mon contributes no third cell.
    local enemyGenderCell = {
      context.bands.enemy[1] + 72 * context.enemyScale,
      context.bands.enemy[2] + 8 * context.enemyScale,
      8 * context.enemyScale, 8 * context.enemyScale,
    }
    local playerGenderCell = {
      context.bands.player[1] + 104 * context.playerScale,
      context.bands.player[2] + 16 * context.playerScale,
      8 * context.playerScale, 8 * context.playerScale,
    }
    assert(rectInside(enemyGenderCell, context.hp.enemy),
      "female enemy gender cell overlaps/leaves its Battle Art HUD")
    assert(rectInside(playerGenderCell, context.hp.player),
      "male player gender cell overlaps/leaves its Battle Art HUD")
    hudMode = "wide-snapped"
  else
    -- Battle Art intentionally keeps Metal (the iOS family) on the engine's
    -- classic in-frame HUD because its canvas-to-canvas band blit is inverted.
    -- macOS Apple-Silicon reports the same renderer family. This is still an
    -- active 3D battle, not the flat renderer fallback; verify that the only
    -- two glyphs remain in the exact classic cells and KASC does not fabricate
    -- a wide receipt or a second pair of bands.
    assert(Voxel3D.metalRenderer() == true
        and hudInspect.lastError == "current-shot-not-snapped"
        and snapReceipt == nil and battle.dramaticShapeShot ~= nil,
      ("unexpected unsnapped Battle Art HUD: %s; receipt=%s/%s; shot=%s")
        :format(tostring(hudInspect.lastError),
          tostring(snapReceipt and snapReceipt.snapped),
          tostring(snapReceipt and snapReceipt.reason),
          tostring(battle.dramaticShapeShot ~= nil)))
    hudMode = "metal-classic-single-band"
  end
  local inspectBefore = kasc.rendererBattleHud.inspect()
  BattleState.drawHUDs(battle, 14)
  local inspectAfter = kasc.rendererBattleHud.inspect()
  assert(inspectAfter.snapCount == inspectBefore.snapCount
      and inspectAfter.nativeSnapCount == inspectBefore.nativeSnapCount,
    "KASC decorated Battle Art's renderer-owned HUD a second time")
  shot("battle-art-1.9.2-" .. lane .. "-battle-menu-gender.png")

  local result = assert(io.open(assert(os.getenv("RESULT_PATH")), "wb"))
  assert(result:write(table.concat({
    "status=PASS", "engine=" .. expectedEngine,
    "battle_art=1.9.2", "edition=" .. edition,
    "language=" .. language, "renderer_count=1",
    "bridge=kasc-local-allowlist/v1",
    "cache_repair=ka-battle-art-cache-repair/v1",
    "cache_rebuild=" .. (matrixLane and "primary-lanes" or "pass"),
    "world=active-voxel", "battle=staged",
    "camera=battle-art-owned-single-stage",
    "hud=" .. hudMode,
    "gender=male-female-genderless-bounds-pass",
    "legacy_oak=present", "quiz=present",
  }, "\n"), "\n"))
  assert(result:close())
end
