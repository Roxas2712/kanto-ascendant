-- Exact-package real-LÖVE acceptance for the official PotatoVoxel 1.7.2
-- release beside Kanto Ascendant. The runner installs the reviewed ZIP
-- unchanged and verifies its SHA-256 before launching this driver.

return function(game)
  local expectedEngine = assert(os.getenv("EXPECT_ENGINE"))
  local edition = assert(os.getenv("POKEPORT_VERSION"))
  local language = assert(os.getenv("TEST_LANGUAGE"))
  local shotDir = assert(os.getenv("SHOT_DIR"))
  local resultPath = assert(os.getenv("RESULT_PATH"))
  local caseId = assert(os.getenv("CASE_ID"))
  local logicSpeed = tonumber(os.getenv("TEST_SPEED")) or 1
  local expectedPackageSha =
    "200153d7623db14e08925d1b51f99f8ccbfa5e32db134922f51c8179bd64fd33"
  local engineContracts = {
    ["0.1.96"] = {
      tag = "0196",
      commit = "73fbaaa25093338585923b8b9809f2fea7fc59dc",
      sha256 =
        "eea83b7f73300994429d70fa4b1003dd9a1c1e524d70842380ef595bcc1a8249",
    },
    ["0.1.98"] = {
      tag = "0198",
      commit = "0e40a7a1f4cd956b37fd74ad50193c259161aac5",
      sha256 =
        "a28b914f5265a52132cb743ba632e1c7bb81f5eb989829816c571adde798db55",
    },
  }
  local expectedLabels = {
    red = {
      en = { command = "FIGHT", move = "GROWL" },
      de = { command = "KMPF", move = "HEULER" },
    },
    blue = {
      en = { command = "FIGHT", move = "GROWL" },
      de = { command = "KMPF", move = "HEULER" },
    },
    yellow = {
      en = { command = "FIGHT", move = "QUICK ATTACK" },
      de = { command = "KMPF", move = "RUCKZUCKHIEB" },
    },
  }
  local languagePackages = {
    red = { id = "deutsch", version = "2.1.6" },
    blue = { id = "deutsch-blau", version = "1.0.2" },
    yellow = { id = "deutsch-gelb", version = "1.0.5" },
  }
  local engineContract = assert(engineContracts[expectedEngine],
    "engine is not in the immutable PotatoVoxel 1.7.2 matrix")
  local labels = assert(expectedLabels[edition]
      and expectedLabels[edition][language],
    "edition/language is not in the immutable PotatoVoxel 1.7.2 matrix")
  local expectedEngineSha = assert(os.getenv("EXPECT_ENGINE_SHA256"),
    "runner did not provide its preflighted engine artifact SHA-256")
  assert(expectedEngineSha == engineContract.sha256,
    "engine artifact SHA-256 drift")
  assert(caseId == engineContract.tag .. "_" .. edition .. "_" .. language,
    "matrix case id drift")

  local function wait(frames)
    for _ = 1, frames do coroutine.yield() end
  end

  local function tap(button)
    table.insert(game.input.pressQueue, button)
    wait(1)
    game.input.state[button] = false
  end

  local function waitFor(predicate, frames, message)
    for _ = 1, frames do
      if predicate() then return true end
      wait(1)
    end
    error(message or "timed out", 0)
  end

  local function waitBattle(battle, predicate, frames)
    return waitFor(function()
      if predicate(battle) then return true end
      if game.stack:top() == battle and battle.phase == "messages"
          and (battle.msgWaiting or battle.msgPrompt) then
        tap("a")
      end
      return false
    end, frames or 4200, "battle did not reach requested phase")
  end

  local shotNames = {}
  local function take(name)
    local filename = caseId .. "_" .. name .. ".png"
    local path = shotDir .. "/" .. filename
    game.capturePath = path
    waitFor(function() return game.capturePath == nil end, 240,
      "screenshot was not consumed: " .. name)
    wait(2)
    local file = assert(io.open(path, "rb"))
    assert(file:seek("end") > 100, "empty screenshot: " .. name)
    assert(file:close())
    shotNames[#shotNames + 1] = filename
    return path
  end

  local function close(actual, expected, message)
    assert(type(actual) == "number"
      and math.abs(actual - expected) < 0.000001,
      (message or "numbers differ") .. ": " .. tostring(actual)
        .. " != " .. tostring(expected))
  end

  local rows = {}
  local function clean(value)
    return tostring(value):gsub("[\r\n=]", " ")
  end
  local function record(key, value)
    rows[#rows + 1] = clean(key) .. "=" .. clean(value)
  end

  wait(180)
  local Version = require("src.core.Version")
  assert(Version.engine == expectedEngine, "engine version drift")
  local buildInfo = love.filesystem.read("build-info.json") or ""
  local buildCommit = buildInfo:match(
    '"gitCommitFull"%s*:%s*"([0-9a-f]+)"') or "missing"
  assert(buildInfo:find('"version"%s*:%s*"' .. expectedEngine .. '"'),
    "build-info engine version drift")
  assert(buildCommit == engineContract.commit, "engine commit drift")

  local identity = love.filesystem.getIdentity()
  local expectedIdentity = "ka-potato-172-" .. engineContract.tag .. "-"
    .. edition .. "-" .. language
  assert(identity ~= "pokemon-love2d" and identity == expectedIdentity,
    "unsafe or unexpected identity")
  assert(os.getenv("POKEPORT_IDENTITY") == identity,
    "identity environment divergence")
  assert(os.getenv("POKEPORT_TOUCH") == "1",
    "touch coverage must use the forced desktop overlay")
  assert(#(game.modStatus and game.modStatus.errors or {}) == 0,
    "unexpected mod loader errors")

  local handles = assert(game.mods and game.mods.mods)
  local exports = assert(game.mods and game.mods.exports)
  local potatoHandle = assert(handles.potato_voxel)
  local kascHandle = assert(handles.kanto_ascendant)
  assert(potatoHandle.manifest.version == "1.7.2")
  assert(potatoHandle.manifest.github == "ShaneMcGovernIE/potato_voxel")
  local raw = assert(exports.potato_voxel)
  assert(raw.version == "1.6.1",
    "official 1.7.2 stale owner export changed unexpectedly")
  assert(raw.lib and type(raw.lib.require) == "function")
  assert(raw.lib.mod and raw.lib.mod.id == "potato_voxel",
    "Potato lost its native owner namespace")
  local languagePackage, languagePackageVersion = "none", "none"
  if language == "de" then
    local wanted = assert(languagePackages[edition])
    local languageHandle = assert(handles[wanted.id],
      "German language package absent: " .. wanted.id)
    assert(languageHandle.manifest.version == wanted.version,
      "German language package version drift")
    languagePackage, languagePackageVersion = wanted.id, wanted.version
  end

  local rendererCount = 0
  for _, id in ipairs({
    "VOXEL_ASCENDANT", "DRAMALESS_SHAPE", "BATTLE_ART_VOXEL_FORK",
    "potato_voxel",
  }) do
    if handles[id] then rendererCount = rendererCount + 1 end
  end
  assert(rendererCount == 1, "exactly one renderer must be installed")
  assert(handles.DRAMALESS_SHAPE == nil
      and handles.BATTLE_ART_VOXEL_FORK == nil
      and handles.VOXEL_ASCENDANT == nil,
    "a second renderer was installed beside PotatoVoxel")

  local kasc = assert(exports.kanto_ascendant)
  local resolver = assert(kasc.voxelRendererCompat)
  local resolved, rendererId, reason, safeHandle, receipt =
    resolver.resolve(game)
  assert(type(resolved) == "table" and resolved ~= raw)
  assert(rendererId == "potato_voxel" and reason == nil)
  assert(resolved.version == "1.7.2",
    "KASC did not trust the authoritative 1.7.2 manifest")
  assert(receipt
      and receipt.schema == "ka-voxel-renderer-capability/v1"
      and receipt.rendererVersion == "1.7.2"
      and receipt.provenance == "potato-voxel-1.7.2-reviewed-api-contract"
      and receipt.export == "kasc-local-allowlist/v1")
  assert(safeHandle and safeHandle.id == "potato_voxel"
      and safeHandle.version == "1.7.2"
      and safeHandle.exports == resolved)
  assert(safeHandle.manifest == nil and safeHandle.path == nil)
  assert(resolved.lib.mod == nil and resolved.lib.path == nil
      and resolved.lib.storage == nil and resolved.lib.options == nil)
  assert(resolved.lib.require("__KA_PRIVATE_PROBE__") == nil)

  local deniedCamera, deniedCameraId, deniedCameraReason =
    resolver.module(game, "BattleCam")
  assert(deniedCamera == nil and deniedCameraId == "potato_voxel"
      and deniedCameraReason == "missing-module:potato_voxel:BattleCam")
  local cameraControl, cameraId, cameraReason = resolver.cameraModule(game)
  assert(cameraControl == nil and cameraId == "potato_voxel"
      and cameraReason == "not-native-camera")
  local deniedCache, deniedCacheId, deniedCacheReason =
    resolver.module(game, "MeshCache")
  assert(deniedCache == nil and deniedCacheId == "potato_voxel"
      and deniedCacheReason == "missing-module:potato_voxel:MeshCache")

  -- The driver may inspect the owner package directly. KASC receives only
  -- the allowlisted facade above: Potato keeps its camera, HUD and cache.
  local ownerCamera = assert(raw.lib.require("BattleCam"))
  local cameraFrameFn, cameraRigFn, cameraRigForFn = ownerCamera.frameH,
    ownerCamera.rig, ownerCamera.rigFor
  local nativeCameraZoom = ownerCamera.zoom
  local cameraInfo = debug.getinfo(cameraFrameFn, "S")
  assert(tostring(cameraInfo.source):find(
    "mods/potato_voxel/lib/BattleCam.lua", 1, true),
    "battle camera is not Potato-owned")
  close(ownerCamera.RIGS.tele.frameH, 34.11,
    "Potato camera was multiplied by the Dramaless x3 preset")
  close(nativeCameraZoom, 1, "Potato native zoom drift")
  assert(ownerCamera.DEFAULT_ZOOM == nil,
    "Dramaless resting-zoom semantics leaked into Potato")
  close(ownerCamera.frameH({}), 34.11, "Potato frameH drift")
  local canonical = ownerCamera.rig({ mid = { 0, 0 } }, 0, true)
  local dx = canonical.eye[1] - canonical.focus[1]
  local dy = canonical.eye[2] - canonical.focus[2]
  local dz = canonical.eye[3] - canonical.focus[3]
  local distance = math.sqrt(dx * dx + dy * dy + dz * dz)
  close(2 * distance * math.tan(canonical.fov / 2), 34.11,
    "Potato canonical camera gained the Dramaless x3 factor")
  assert(kasc.dramalessCameraCompat.apply(game) == false,
    "KASC camera compatibility applied to Potato")
  close(ownerCamera.RIGS.tele.frameH, 34.11,
    "KASC changed Potato's native camera rig")
  assert(ownerCamera.frameH == cameraFrameFn
      and ownerCamera.rig == cameraRigFn
      and ownerCamera.rigFor == cameraRigForFn,
    "KASC replaced a Potato camera function")

  local ownerBattle = assert(raw.lib.require("OverworldBattle"))
  local ownerHudInfo = debug.getinfo(ownerBattle.drawHudPanels, "S")
  assert(tostring(ownerHudInfo.source):find(
    "mods/potato_voxel/lib/OverworldBattle.lua", 1, true),
    "battle HUD is not Potato-owned")
  assert(ownerBattle.snapHUDs == nil,
    "Potato unexpectedly exposes the Dramaless snapHUD surface")
  local rendererHud = assert(kasc.rendererBattleHud)
  assert(rendererHud.refresh(game) == true)
  local hudInspect = rendererHud.inspect()
  assert(hudInspect.profile == "RENDERER_NATIVE"
      and hudInspect.rendererId == "potato_voxel"
      and hudInspect.rendererVersion == "1.7.2")
  assert(hudInspect.snapCount == 0 and hudInspect.nativeSnapCount == 0
      and hudInspect.fallbackCount == 0)
  assert(rawget(ownerBattle, rendererHud.snapHookKey) == nil,
    "KASC installed a snapHUD wrapper on Potato")

  local BattleState = require("src.battle.BattleState")
  assert(rawget(BattleState, "__kascWideBattleHudState") == nil,
    "KASC installed its wide-HUD wrapper for Potato")
  local OptionsMenu = require("src.ui.OptionsMenu")
  local optionMenu = OptionsMenu.new(game)
  local ownerSettingsRows, cameraRows = 0, 0
  for _, row in ipairs(optionMenu.rows or {}) do
    if row.id == "potato_voxel:settings" then
      ownerSettingsRows = ownerSettingsRows + 1
    elseif row.id == "kanto_ascendant:dramaless_battle_camera" then
      cameraRows = cameraRows + 1
    end
  end
  assert(ownerSettingsRows == 1,
    "Potato's native VOXEL SETTINGS launcher is missing or duplicated")
  assert(cameraRows == 0,
    "KASC exposed its Dramaless camera row for Potato")

  local ownerMeshCache = assert(raw.lib.require("MeshCache"))
  local cacheInfo = debug.getinfo(ownerMeshCache.identity, "S")
  assert(tostring(cacheInfo.source):find(
    "mods/potato_voxel/lib/MeshCache.lua", 1, true),
    "mesh cache is not Potato-owned")
  assert(ownerMeshCache.GEOMETRY_VERSION == 18)
  assert(ownerMeshCache.identity():match("^PVMC1|18|"),
    "Potato cache identity drift")
  local debugOverlay = assert(raw.lib.require("DebugOverlay"))
  assert(debugOverlay.sendingAllowed() == false,
    "isolated QA must keep Potato LOGS TO DEV disabled")

  local Pokemon = require("src.pokemon.Pokemon")
  local Pipelines = require("src.render.Pipelines")
  local Font = require("src.render.Font")
  local gender = assert(kasc.pokemonGender)
  local VoxelState = assert(raw.lib.require("VoxelState"))
  local Voxel3D = assert(raw.lib.require("Voxel3D"))

  local function clearStack()
    ownerBattle.finish()
    while game.stack:top() do game.stack:pop() end
  end

  local function setupField()
    clearStack()
    local Overworld = require("src.world.OverworldController")
    game.stack:push(Overworld, "ROUTE_1", 5, 5, "down")
    wait(50)
    assert(game.overworld and game.overworld.map.id == "ROUTE_1")
    Pipelines.setLevel("voxel", 1)
    Pipelines.syncOptions(game.save.options)
    assert(Pipelines.worldPipeline() == "voxel")
    waitFor(function()
      return VoxelState.loading ~= true and Voxel3D.available() == true
    end, 3600, "Potato voxel world did not become available")
    wait(24 * logicSpeed)
  end

  local function makeMon(species, level, attackDv, status)
    local mon = Pokemon.new(game.data, species, level or 30)
    mon.dvs.attack = attackDv
    mon.dvs.defense = 9
    mon.dvs.speed = 9
    mon.dvs.special = 9
    mon.dvs.hp = nil
    mon.status = status
    mon.hp = mon.stats.hp
    return mon
  end

  local function setViewport(kind)
    local wantedW, wantedH = kind == "portrait" and 540 or 960,
      kind == "portrait" and 900 or 540
    local ok, err = love.window.setMode(wantedW, wantedH, {
      resizable = true, vsync = 1,
    })
    assert(ok, "could not set " .. kind .. " window: " .. tostring(err))
    wait(12 * logicSpeed)
    local w, h = love.graphics.getDimensions()
    if kind == "portrait" then assert(w < h, "portrait window not tall")
    else assert(w > h, "landscape window not wide") end
    local touch = assert(game.touchControls)
    touch:currentBucket()
    assert(touch:visible(), "touch overlay is not visible")
    assert(touch.orientation == kind, "touch orientation drift")
    return w, h
  end

  local function beginWild(staged)
    setupField()
    -- Entering a map refreshes Potato's option objects from the save. Apply
    -- the per-case 3D-BTL value afterwards so the battle observes it exactly.
    ownerBattle.setting:setValue(staged and true or false, game)
    ownerBattle.backSetting:setValue(false, game)
    game.save.party = { makeMon("PIKACHU", 30, 15, "PAR") }
    game.save.pokedex = game.save.pokedex or { seen = {}, owned = {} }
    local battle = BattleState.newWild(game, "PIDGEY", 20)
    battle.enemy.mon.dvs.attack = 0
    battle.enemy.mon.dvs.defense = 9
    battle.enemy.mon.dvs.speed = 9
    battle.enemy.mon.dvs.special = 9
    battle.enemy.mon.dvs.hp = nil
    battle.onFinish = function() end
    game.overworld:pushBattle(battle)
    return battle
  end

  local function inspectFrame(battle, name, expectHud)
    local calls = {}
    local originalDraw = Font.draw
    Font.draw = function(text, x, y, ...)
      calls[#calls + 1] = { text = text, x = x, y = y }
      return originalDraw(text, x, y, ...)
    end
    -- POKEPORT_SPEED may execute several logic ticks before the next draw.
    -- Observe multiple presentation frames so the proof cannot race a resize
    -- or menu transition, then normalize the receipt to visible/not-visible.
    wait(4 * logicSpeed)
    Font.draw = originalDraw
    wait(2 * logicSpeed)
    take(name)

    local enemyGender, playerGender, statusCount = 0, 0, 0
    local commandLabel, moveLabel
    for _, call in ipairs(calls) do
      if call.x == 72 and call.y == 8
          and (call.text == "♀" or call.text == "♂") then
        enemyGender = enemyGender + 1
        assert(call.text == "♀")
      elseif call.x == 104 and call.y == 64
          and (call.text == "♀" or call.text == "♂") then
        playerGender = playerGender + 1
        assert(call.text == "♂")
      elseif call.x == 120 and call.y == 64 and call.text == "PAR" then
        statusCount = statusCount + 1
      elseif call.x >= 64 and call.x <= 96 and call.y == 112
          and battle.phase == "menu" then
        -- The German command label is shifted left relative to FIGHT.
        commandLabel = tostring(call.text)
      elseif call.x == 48 and call.y == 104
          and battle.phase == "moveSelect" then
        moveLabel = tostring(call.text)
      end
    end
    if expectHud then
      assert(enemyGender >= 1, "enemy gender glyph was not drawn")
      assert(playerGender >= 1, "player gender glyph was not drawn")
      assert(statusCount >= 1, "player status label was not drawn")
    end
    return {
      commandLabel = commandLabel,
      moveLabel = moveLabel,
      enemyGender = enemyGender > 0 and 1 or 0,
      playerGender = playerGender > 0 and 1 or 0,
      statusCount = statusCount > 0 and 1 or 0,
    }
  end

  local landscapeW, landscapeH = setViewport("landscape")
  local stagedBattle = beginWild(true)
  assert(waitFor(function()
    return game.stack:top() == stagedBattle
      and stagedBattle.phase == "messages"
      and (stagedBattle.msgPrompt or stagedBattle.msgWaiting)
      and ownerBattle.shot() ~= nil
  end, 4800, "native Potato textbox/stage did not settle"))
  assert(stagedBattle.dramaticShapeShot ~= nil,
    "Potato did not install its native battle shot")
  assert(rendererHud.context(stagedBattle) == nil,
    "KASC produced snap geometry for Potato")
  assert(rawget(stagedBattle, rendererHud.snapReceiptKey) == nil,
    "KASC wrote a snapHUD receipt for Potato")
  inspectFrame(stagedBattle, "3d_on_landscape_textbox", false)

  assert(waitBattle(stagedBattle,
    function(battle) return battle.phase == "menu" end, 4800))
  wait(12 * logicSpeed)
  assert(ownerBattle.shot() ~= nil and stagedBattle.dramaticShapeShot ~= nil)
  assert(gender.symbol(stagedBattle.enemy.mon, game) == "♀")
  assert(gender.symbol(stagedBattle.player.mon, game) == "♂")
  assert(stagedBattle.player.shownStatus == "PAR")
  local command = inspectFrame(
    stagedBattle, "3d_on_landscape_command", true)
  assert(command.commandLabel == labels.command,
    "localized command menu label drift")

  local portraitW, portraitH = setViewport("portrait")
  assert(ownerBattle.shot() ~= nil,
    "Potato lost its native stage after portrait resize")
  tap("a")
  assert(waitFor(function() return stagedBattle.phase == "moveSelect" end,
    240, "FIGHT did not open the move menu"))
  local move = inspectFrame(stagedBattle, "3d_on_portrait_move", true)
  assert(move.moveLabel == labels.move,
    "localized move menu label drift: actual=" .. tostring(move.moveLabel)
      .. " expected=" .. labels.move)

  ownerBattle.finish()
  clearStack()
  local offLandscapeW, offLandscapeH = setViewport("landscape")
  local flatBattle = beginWild(false)
  assert(waitBattle(flatBattle,
    function(battle) return battle.phase == "menu" end, 4800))
  wait(12 * logicSpeed)
  assert(ownerBattle.shot() == nil and flatBattle.dramaticShapeShot == nil,
    "3D-BTL OFF still produced a Potato stage")
  assert(rendererHud.context(flatBattle) == nil)
  assert(rawget(flatBattle, rendererHud.snapReceiptKey) == nil)
  local flat = inspectFrame(flatBattle, "3d_off_landscape_command", true)
  assert(flat.commandLabel == labels.command,
    "3D-BTL OFF localized command menu label drift")

  close(ownerCamera.RIGS.tele.frameH, 34.11,
    "battle lifecycle applied Dramaless x3 to Potato")
  assert(ownerCamera.frameH == cameraFrameFn
      and ownerCamera.rig == cameraRigFn
      and ownerCamera.rigFor == cameraRigForFn)
  hudInspect = rendererHud.inspect()
  assert(hudInspect.profile == "RENDERER_NATIVE"
      and hudInspect.snapCount == 0 and hudInspect.nativeSnapCount == 0
      and hudInspect.fallbackCount == 0)

  record("status", "PASS")
  record("engine", expectedEngine)
  record("engine_artifact_sha256", expectedEngineSha)
  record("engine_commit", buildCommit)
  record("edition", edition)
  record("language", language)
  record("language_package", languagePackage)
  record("language_package_version", languagePackageVersion)
  record("identity", identity)
  record("package_sha256", expectedPackageSha)
  record("manifest_version", potatoHandle.manifest.version)
  record("raw_export_version", raw.version)
  record("kasc_version", kascHandle.manifest.version)
  record("renderer_count", rendererCount)
  record("resolver_renderer", rendererId)
  record("resolver_provenance", receipt.provenance)
  record("resolver_export", receipt.export)
  record("camera_owner", cameraInfo.source)
  record("camera_frameH", ownerCamera.RIGS.tele.frameH)
  record("camera_zoom", nativeCameraZoom)
  record("camera_kasc_apply", false)
  record("camera_row_count", cameraRows)
  record("hud_owner", ownerHudInfo.source)
  record("hud_profile", hudInspect.profile)
  record("hud_snap_count", hudInspect.snapCount)
  record("hud_native_snap_count", hudInspect.nativeSnapCount)
  record("hud_fallback_count", hudInspect.fallbackCount)
  record("owner_settings_rows", ownerSettingsRows)
  record("cache_owner", cacheInfo.source)
  record("cache_geometry_version", ownerMeshCache.GEOMETRY_VERSION)
  record("cache_identity", ownerMeshCache.identity())
  record("cache_backend", ownerMeshCache.dir() or "unbound")
  record("logs_to_dev", debugOverlay.sendingAllowed())
  record("command_label", command.commandLabel)
  record("move_label", move.moveLabel)
  record("flat_command_label", flat.commandLabel)
  record("gender_enemy", command.enemyGender)
  record("gender_player", command.playerGender)
  record("status_par", command.statusCount)
  record("touch_visible", game.touchControls:visible())
  record("landscape", landscapeW .. "x" .. landscapeH)
  record("portrait", portraitW .. "x" .. portraitH)
  record("off_landscape", offLandscapeW .. "x" .. offLandscapeH)
  record("battle_3d_on", true)
  record("battle_3d_off", true)
  record("screenshots", table.concat(shotNames, ","))
  record("screenshot_count", #shotNames)
  table.sort(rows)
  local out = assert(io.open(resultPath, "wb"))
  assert(out:write(table.concat(rows, "\n"), "\n"))
  assert(out:close())
  love.event.quit(0)
end
