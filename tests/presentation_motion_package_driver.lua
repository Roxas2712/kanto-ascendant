-- Historical <=0.1.86 installed-package dispatcher for the bounded L02
-- Battle Art matrix. Each invocation owns exactly one phase. Only `aggregate`
-- may create driver_result.txt. This remains regression evidence, not a
-- current 0.1.90 renderer-support claim.

return function(game)
  assert(os.getenv("KA_PACKAGE_GATE") == "1",
    "KA_PACKAGE_GATE=1 is required; SOURCE is not package evidence")
  assert(os.getenv("KA_CLOSURE_PROFILE") == "battle_art",
    "L02 requires the reviewed Battle Art package closure")

  local function requiredSha(name)
    local value = tostring(os.getenv(name) or "")
    assert(#value == 64 and value:match("^[0-9a-f]+$"),
      "must be a lowercase SHA256 receipt" .. ": " .. name)
    return value
  end

  local provenance = {
    engine = requiredSha("KA_ENGINE_PAYLOAD_SHA256"),
    authority = requiredSha("KA_AUTHORITY_PACKAGE_SHA256"),
    deutsch = requiredSha("KA_DEUTSCH_PACKAGE_SHA256"),
    battleArt = requiredSha("KA_BATTLE_ART_PACKAGE_SHA256"),
    gate = requiredSha("KA_PACKAGE_GATE_RECEIPT_SHA256"),
  }
  assert(provenance.battleArt
      == "10d7e80a58d9046b41ec446900f2f15aa6021335a1547d9209117f3a22a0604e",
    "reviewed Battle Art archive SHA drifted")

  local phase = assert(os.getenv("QA_PRESENTATION_PHASE"),
    "QA_PRESENTATION_PHASE is required")
  local renderer = assert(os.getenv("QA_RENDERER"), "QA_RENDERER is required")
  local source = assert(os.getenv("QA_PRESENTATION_SOURCE"),
    "QA_PRESENTATION_SOURCE is required")
  assert(renderer == "2D" or renderer == "BATTLE_ART_FULL",
    "renderer must be 2D or BATTLE_ART_FULL")
  assert(source == "FRESH" or source == "BLITZ",
    "source must be FRESH or BLITZ")
  local fresh = phase == "characters" or phase == "crystal_title_gorochu"
    or phase == "follower_wilds" or phase == "reload_verify"
    or phase == "aggregate"
  local blitz = phase == "blitz_restore" or phase == "reload_verify"
    or phase == "aggregate"
  assert(source == "FRESH" and fresh or source == "BLITZ" and blitz,
    "phase is not valid for this source")

  local GameVersion = require("src.core.GameVersion")
  local Pipelines = require("src.render.Pipelines")
  local edition = GameVersion.get()
  assert(edition == assert(os.getenv("POKEPORT_VERSION"), "edition required"),
    "wrong ROM edition mounted")
  if source == "BLITZ" then
    assert(edition == "red", "the immutable BLITZ snapshot is Red-only")
  end
  local identity = assert(os.getenv("POKEPORT_IDENTITY"), "identity required")
  local rendererSlug = renderer == "2D" and "2d" or "battle-art-full"
  local expectedIdentity = source == "FRESH"
    and ("ka65-presentation-motion-%s-%s"):format(edition, rendererSlug)
    or ("ka65-presentation-motion-blitz-red-%s"):format(rendererSlug)
  assert(identity == expectedIdentity,
    "wrong L02 identity; expected " .. expectedIdentity)

  local packageRoot = assert(love.filesystem.getSource(),
    "installed engine package root unavailable")
  assert(type(packageRoot) == "string" and packageRoot ~= "",
    "installed engine package root is empty")
  assert(not packageRoot:find(".worktrees", 1, true)
      and not packageRoot:find("/Documents/Recompile/", 1, true),
    "package gate refuses a source/developer checkout")
  local harnessRoot = assert(os.getenv("GEN1RECOMP_DIR"),
    "GEN1RECOMP_DIR materialized qa_harness root is required")
  assert(harnessRoot:sub(1, 1) == "/"
      and harnessRoot:find("/private/tmp/", 1, true)
      and harnessRoot:find("/qa_harness", 1, true)
      and not harnessRoot:find(".worktrees", 1, true)
      and not harnessRoot:find("/Documents/Recompile/", 1, true),
    "L02 harness must come from the pinned materialized qa_harness")
  local utilPath = assert(os.getenv("KA_TEST_UTIL"),
    "KA_TEST_UTIL materialized harness path is required")
  local compositePath = assert(os.getenv("KA_PRESENTATION_COMPOSITE"),
    "KA_PRESENTATION_COMPOSITE materialized harness path is required")
  local characterMatrixPath = assert(os.getenv("KA_CHARACTER_MATRIX"),
    "KA_CHARACTER_MATRIX materialized harness path is required")
  local function pinnedHarnessPath(path, suffix)
    assert(path:sub(1, #harnessRoot + 1) == harnessRoot .. "/"
        and path:sub(-#suffix) == suffix
        and not path:find(".worktrees", 1, true)
        and not path:find("/Documents/Recompile/", 1, true),
      "unpinned L02 harness path: " .. tostring(path))
    return path
  end
  local U = dofile(pinnedHarnessPath(utilPath, "/tests/drivers/util.lua"))
  local composite = dofile(pinnedHarnessPath(compositePath,
    "/tools/presentation_motion_package_composite.lua"))
  pinnedHarnessPath(characterMatrixPath,
    "/tools/blitz_character_presentation_matrix.lua")
  local outputDir = assert(os.getenv("SHOT_DIR"), "SHOT_DIR is required")

  local exports = assert(game.mods and game.mods.exports,
    "installed package exports unavailable")
  local ascendant = assert(exports.kanto_ascendant,
    "installed Kanto Ascendant export unavailable")
  local loadedPackages = assert(game.mods.mods,
    "installed package registry unavailable")
  local languageId = ({
    red = "deutsch", blue = "deutsch-blau", yellow = "deutsch-gelb",
  })[edition]
  local expectedPackages = {
    kanto_ascendant = true,
    [languageId] = true,
    BATTLE_ART_VOXEL_FORK = true,
  }
  local loadedCount = 0
  for id in pairs(loadedPackages) do
    loadedCount = loadedCount + 1
    assert(expectedPackages[id],
      "unexpected package leaked into L02 closure: " .. tostring(id))
  end
  assert(loadedCount == 3,
    "L02 Battle Art closure must contain exactly three packages")
  local authorityHandle = assert(game.mods.mods.kanto_ascendant,
    "installed Authority handle unavailable")
  local languageHandle = assert(loadedPackages[languageId],
    "edition-matched language package unavailable")
  local battleArtHandle = assert(loadedPackages.BATTLE_ART_VOXEL_FORK,
    "reviewed Battle Art package unavailable")
  for _, handle in ipairs({ authorityHandle, languageHandle, battleArtHandle }) do
    local installedPath = tostring(handle.path or "")
    assert(installedPath ~= ""
        and not installedPath:find(".worktrees", 1, true)
        and not installedPath:find("/Documents/Recompile/", 1, true)
        and not installedPath:find("/tests/", 1, true),
      "installed dependency escaped the package closure")
  end
  local resolver = assert(ascendant.voxelRendererCompat,
    "voxelRendererCompat unavailable")
  local rendererExport, rendererId, rendererReason, rendererHandle =
    resolver.resolve(game)
  assert(rendererExport and rendererId == "BATTLE_ART_VOXEL_FORK",
    "reviewed Battle Art export missing: " .. tostring(rendererReason))
  assert(rendererExport.version == "1.8.3"
      or rendererHandle and rendererHandle.manifest
        and rendererHandle.manifest.version == "1.8.3",
    "Battle Art package version is not 1.8.3")
  local overworldBattle, overworldId, overworldReason =
    resolver.module(game, "OverworldBattle")
  assert(overworldBattle and overworldId == rendererId,
    "Battle Art OverworldBattle seam missing: " .. tostring(overworldReason))
  local battleArt, battleArtId, battleArtReason =
    resolver.module(game, "BattleArt")
  assert(battleArt and battleArtId == rendererId,
    "Battle Art module seam missing: " .. tostring(battleArtReason))

  local SaveData = require("src.core.SaveData")
  local full = renderer == "BATTLE_ART_FULL"
  local expectedLevel = full and 1 or 0
  local function assertRendererContract(label, options)
    options = options or (game.save and game.save.options) or {}
    local bucket = options.modOptions
      and options.modOptions.BATTLE_ART_VOXEL_FORK or {}
    assert(Pipelines.level("voxel") == expectedLevel,
      label .. ": live voxel level drifted")
    assert(options.pipelines and options.pipelines.voxel == expectedLevel,
      label .. ": persisted voxel level drifted")
    assert(overworldBattle.setting and overworldBattle.setting:get() == full,
      label .. ": staged-battle setting drifted")
    assert(battleArt.setting and battleArt.setting:get() == "animated",
      label .. ": Battle Art setting drifted")
    assert(bucket.battles == full and bucket.battleArt == "animated",
      label .. ": persisted Battle Art settings drifted")
    if full then
      assert(Pipelines.levelLabel("voxel") == "FULL"
          and Pipelines.worldPipeline() == "voxel",
        label .. ": Battle Art FULL pipeline is not live")
    else
      assert(Pipelines.worldPipeline() ~= "voxel",
        label .. ": Battle Art must be installed but OFF in 2D")
    end
    return true
  end
  local function applyRendererContract(label, persist)
    overworldBattle.setting:setIndex(full and 1 or 2, game)
    battleArt.setting:setIndex(2, game)
    Pipelines.setLevel("voxel", expectedLevel)
    Pipelines.syncOptions(game.save.options or {})
    if persist then
      assert(pcall(game.writeOptions, game),
        label .. ": native options write failed")
    end
    U.wait(full and 20 or 3)
    assertRendererContract(label)
    if persist then
      assertRendererContract(label .. " disk round-trip", SaveData.loadOptions())
    end
    return true
  end
  -- reload_verify and aggregate are later native processes in the same cell.
  -- They must prove the previous writer persisted the requested renderer,
  -- never repair it before observing the disk-backed state.
  if phase == "reload_verify" or phase == "aggregate" then
    assertRendererContract("native process boot renderer")
  else
    applyRendererContract("phase renderer setup", true)
  end

  local passed, failed, rows = 0, 0, {}
  local function check(label, ok, detail)
    ok = ok and true or false
    if ok then passed = passed + 1 else failed = failed + 1 end
    rows[#rows + 1] = table.concat({
      ok and "PASS" or "FAIL", label, tostring(detail or ""),
    }, "\t")
    U.log(ok and "PASS" or "FAIL", label, detail or "")
    return ok
  end
  local function info(label, detail)
    rows[#rows + 1] = table.concat({ "INFO", label, tostring(detail or "") }, "\t")
  end

  local ctx = {
    game = game,
    U = U,
    check = check,
    info = info,
    edition = edition,
    renderer = renderer,
    source = source,
    phase = phase,
    identity = identity,
    packageRoot = packageRoot,
    harnessRoot = harnessRoot,
    characterMatrixPath = characterMatrixPath,
    outDir = outputDir,
    ascendant = ascendant,
    overworldBattle = overworldBattle,
    battleArt = battleArt,
    applyRendererContract = applyRendererContract,
    assertRendererContract = assertRendererContract,
    provenance = provenance,
    failCount = function() return failed end,
    passCount = function() return passed end,
    rows = rows,
  }

  local ok, reason = xpcall(function()
    if source == "BLITZ" then
      ctx.sourceSave = assert(os.getenv("KA_SOURCE_SAVE"),
        "KA_SOURCE_SAVE required for BLITZ")
      ctx.sourceOptions = assert(os.getenv("KA_SOURCE_OPTIONS"),
        "KA_SOURCE_OPTIONS required for BLITZ")
      ctx.sourceSaveSha = requiredSha("KA_SOURCE_SAVE_SHA256")
      ctx.sourceOptionsSha = requiredSha("KA_SOURCE_OPTIONS_SHA256")
    end
    assert(composite.run(ctx) == true, "L02 phase did not complete")
  end, debug.traceback)
  if not ok then
    check("phase raised an error", false, reason)
    pcall(composite.writeFailure, ctx, reason)
  end
  local fail = failed
  U.log("PRESENTATION MOTION PACKAGE", fail == 0 and "PASS" or "FAIL",
    edition, renderer, source, phase, passed, fail)
  love.event.quit(fail == 0 and 0 or 1)
end
