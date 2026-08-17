-- One fail-closed authority admits the official renderer families from their
-- hardened baselines through 2.x on a best-effort basis. Exact adapters stay
-- exact-version-only; repository spoofs, malformed/out-of-range versions,
-- broken capability shapes and multiple simultaneous renderers remain closed.

local root = assert(os.getenv("TRAINER_REMATCH_MOD_DIR"),
  "TRAINER_REMATCH_MOD_DIR is required")
local handles = {}
local fakeMod = { find = function(id) return handles[id] end }
local resolver = assert(loadfile(root .. "/voxel_renderer_compat.lua"))()(fakeMod)

local checks = 0
local function ok(value, message)
  checks = checks + 1
  assert(value, message)
end
local function eq(actual, expected, message)
  checks = checks + 1
  assert(actual == expected, ("%s (got %s, want %s)")
    :format(message, tostring(actual), tostring(expected)))
end

local modules = {
  AntiAlias = { id = "aa" },
  OverworldBattle = { id = "battle", sideTexture = function() end },
  BattleCam = { id = "camera" },
  FirstPerson = { id = "first-person" },
  VoxelScene = { id = "scene" },
  Voxel3D = { id = "voxel" },
  VoxelState = { id = "state" },
  Mat4 = { id = "matrix" },
  ShadowMap = { id = "shadow" },
  SpriteBillboards = { id = "billboards" },
  TerrainAtlas = { id = "terrain-atlas" },
}
local function export(version)
  return {
    version = version,
    lib = {
      require = function(name)
        return modules[name]
      end,
    },
  }
end

local function voxelExport(version)
  local out = export(version)
  out.apiVersion = 1
  out.renderer = {
    id = "VOXEL_ASCENDANT", version = version,
    pipeline = "voxel", cameraProfile = "orbit-only",
  }
  out.capabilities = {
    voxelWorld = true, battleCards = { "MAP", "DISCS" },
    wallDecals = 1, diskCache = false, stadium = false, vr = false,
  }
  return out
end

local function gameFor(id, version, companions, exported, github)
  exported = exported or export(version)
  handles = {
    [id] = {
      id = id, version = version, exports = exported, github = github,
    },
  }
  for companion, value in pairs(companions or {}) do
    handles[companion] = { id = companion, exports = value }
  end
  return exported
end

local function battleArtExport(version)
  local rawCalls = {}
  local rawLib = {
    mod = { id = "BATTLE_ART_VOXEL_FORK", assets = {} },
    path = "/separately-installed/battle-art",
    data = function() return { private = true } end,
  }
  rawLib.require = function(name)
    rawCalls[#rawCalls + 1] = name
    if modules[name] then return modules[name] end
    return { privateModule = name }
  end
  return {
    version = version,
    lib = rawLib,
    battleStage = {
      apiVersion = 1, sourceModId = "BATTLE_ART_VOXEL_FORK",
      ownership = { hud = true, animationProjection = true },
      state = function() return { staged = true } end,
    },
    battlePresentation = {
      apiVersion = 1, sourceModId = "BATTLE_ART_VOXEL_FORK",
      suppressHook = "battle.presentation.suppress_native.v1",
    },
  }, rawCalls, rawLib
end

local function potatoExport()
  local rawCalls = {}
  local rawLib = {
    mod = { id = "potato_voxel", assets = {} },
    path = "/separately-installed/potato-voxel",
    data = function() return { private = true } end,
  }
  rawLib.require = function(name)
    rawCalls[#rawCalls + 1] = name
    if name == "BattleCam" then return nil end
    if modules[name] then return modules[name] end
    return { privateModule = name }
  end
  return {
    -- PotatoVoxel 1.7.2's public release currently retains this stale
    -- compatibility string; the authoritative version is its manifest.
    version = "1.6.1",
    lib = rawLib,
    brick = {}, debug = {},
  }, rawCalls, rawLib
end

local function game(version, companions)
  return gameFor("DRAMALESS_SHAPE", version, companions)
end

local function voxelGame(version, companions, exported)
  return gameFor("VOXEL_ASCENDANT", version, companions,
    exported or voxelExport(version))
end

-- A renderer is optional. Native 2D is not an error and must never acquire
-- a synthetic renderer owner merely because Ascendant is installed.
handles = {}
local package, id, reason = resolver.resolve()
eq(package, nil, "native 2D requires no renderer package")
eq(id, nil, "native 2D has no renderer owner")
eq(reason, "renderer-absent", "native 2D reports the stable optional state")

local standalone = voxelGame("0.1.1")
package, id, reason = resolver.resolve(standalone)
ok(package ~= nil, "Voxel Ascendant resolves through its real manifest id")
eq(id, "VOXEL_ASCENDANT", "standalone renderer keeps its own identity")
eq(reason, nil, "standalone renderer has no resolver error")
local module, moduleId, moduleError, receipt = resolver.module(
  standalone, "OverworldBattle")
eq(module, modules.OverworldBattle,
  "Voxel Ascendant exposes the reviewed battle companion seam")
eq(moduleId, "VOXEL_ASCENDANT", "standalone module receipt names its owner")
eq(moduleError, nil, "standalone module load has no error")
eq(receipt.rendererVersion, "0.1.1",
  "standalone receipt pins the reviewed stable build")
eq(receipt.provenance, "roxas2712-voxel-ascendant-mit-v161",
  "standalone MIT provenance is explicit")
local genericCamera, genericCameraId, genericCameraError =
  resolver.cameraModule(standalone)
eq(genericCamera, nil,
  "the native-camera API never returns a closed-facade renderer module")
eq(genericCameraId, "VOXEL_ASCENDANT",
  "native-camera rejection keeps the installed renderer identity")
eq(genericCameraError, "not-native-camera",
  "native-camera rejection has a stable non-owner diagnostic")

local legacyRc = voxelGame("0.1.0-rc.1")
package, id, reason = resolver.resolve(legacyRc)
ok(package ~= nil,
  "the already reviewed Voxel Ascendant RC remains transition-compatible")
eq(id, "VOXEL_ASCENDANT", "legacy RC keeps its real renderer identity")
eq(reason, nil, "legacy RC has no resolver error")
module, moduleId, moduleError, receipt = resolver.module(
  legacyRc, "OverworldBattle")
eq(module, modules.OverworldBattle,
  "legacy RC receives the KASC battle anchor and scaling adapter")
eq(moduleId, "VOXEL_ASCENDANT", "legacy RC module receipt names its owner")
eq(moduleError, nil, "legacy RC module load has no error")
eq(receipt.rendererVersion, "0.1.0-rc.1",
  "legacy RC receipt preserves its exact reviewed version")
eq(receipt.provenance, "roxas2712-voxel-ascendant-mit-v161-rc1",
  "legacy RC provenance is explicit")

local futureVoxel = voxelGame("2.9.9")
package, id, reason = resolver.resolve()
ok(package ~= nil, "official Voxel Ascendant 2.x is admitted best-effort")
eq(id, "VOXEL_ASCENDANT", "future Voxel keeps canonical identity")
eq(reason, nil, "in-range Voxel has no admission error")
module, moduleId, moduleError, receipt = resolver.module(
  futureVoxel, "OverworldBattle")
eq(module, modules.OverworldBattle,
  "future Voxel receives only the common capability surface")
eq(receipt.provenance, "voxel-ascendant-supported-series-best-effort",
  "future Voxel receipt does not claim an exact-version review")

for _, version in ipairs({ "3.0.0", "latest" }) do
  voxelGame(version)
  package, id, reason = resolver.resolve()
  eq(package, nil, "out-of-range/malformed Voxel fails closed: " .. version)
  eq(reason, "unsupported-version:VOXEL_ASCENDANT:" .. version,
    "Voxel rejection names the supplied version")
end

local badCapability = voxelExport("0.1.1")
badCapability.capabilities.wallDecals = nil
voxelGame("0.1.1", nil, badCapability)
package, id, reason = resolver.resolve()
eq(package, nil, "standalone renderer without the frozen API fails closed")
eq(reason, "invalid-capability:VOXEL_ASCENDANT",
  "invalid standalone API is diagnosed precisely")

local unsafe = voxelExport("0.1.1")
unsafe.lib.mod = { storage = {} }
voxelGame("0.1.1", nil, unsafe)
package, id, reason = resolver.resolve()
eq(package, nil, "owner-scoped renderer authority is never accepted")
eq(reason, "unsafe-export:VOXEL_ASCENDANT",
  "owner-authority leak is diagnosed precisely")

local genericVoxel = voxelExport("0.1.1")
genericVoxel.lib.require = function(name)
  if name == "Storage" then return { write = function() end } end
  error("generic private resolver reached " .. tostring(name))
end
voxelGame("0.1.1", nil, genericVoxel)
package, id, reason = resolver.resolve()
eq(package, nil, "a generic standalone resolver fails closed")
eq(reason, "unsafe-export:VOXEL_ASCENDANT",
  "the private standalone resolver is diagnosed precisely")

local current = game("1.6.2-ST.190.1")
package, id, reason = resolver.resolve(current)
ok(package ~= nil, "the exact 0.1.90 compatibility build resolves")
eq(id, "DRAMALESS_SHAPE", "the reviewed package retains its manifest id")
eq(reason, nil, "the reviewed package has no resolver error")
module, moduleId, moduleError, receipt = resolver.module(
  current, "OverworldBattle")
eq(module, modules.OverworldBattle,
  "the reviewed build exposes its public battle companion seam")
eq(moduleId, "DRAMALESS_SHAPE", "the module receipt names its owner")
eq(moduleError, nil, "the reviewed module load has no error")
eq(receipt.schema, "ka-voxel-renderer-capability/v1",
  "the compatibility receipt stays versioned")
eq(receipt.rendererVersion, "1.6.2-ST.190.1",
  "the receipt pins the exact sandbox-compatible build")
eq(receipt.provenance, "artyrambles-classic-release-0190-compat",
  "the compatibility fork provenance is explicit")
eq(receipt.capability, "sideTexture",
  "the receipt names the required capability")

-- Upstream DRAMALESS 2.0.2 is an explicitly approved *native-only* renderer.
-- Its legacy V table deliberately retains the renderer owner's mod/path/data
-- authority, so KASC's generic module paths must never probe or forward it.
-- The exact camera path may request only literal BattleCam and return the
-- fixed control capability tested below. The package owns its standalone voxel
-- arena, card host and HUD; KASC must not make the historical Wilds alias claim it.
local nativeCalls = 0
local nativeNames = {}
local nativeCamera = {
  RIGS = {
    tele = {
      side = 78.79, back = 144.96, height = 37.88,
      lookX = -0.26, lookY = 0.34, frameH = 34.11,
    },
    wide = {
      side = 41.98, back = 41.16, height = 28.48,
      lookX = -3.24, lookY = -1.35, frameH = 55.62,
    },
  },
  DEFAULT_RIG = "tele", DEFAULT_ZOOM = 1.3,
  ZOOM_MIN = 0.45, ZOOM_MAX = 2.0,
  zoom = 1.3, zoomGoal = 1.3,
  rigFor = function() end, frameH = function() end, rig = function() end,
}
local nativeOnly = {
  version = "2.0.2",
  lib = {
    mod = { id = "DRAMALESS_SHAPE" },
    path = "/separately-installed/dramaless-2.0.2",
    require = function(name)
      nativeCalls = nativeCalls + 1
      nativeNames[#nativeNames + 1] = name
      if name == "BattleCam" then return nativeCamera end
      return { private = name }
    end,
  },
  voxelArenaProvider = {}, voxelCardProvider = {}, voxel2DBattleHost = {},
}
gameFor("DRAMALESS_SHAPE", "2.0.2", nil, nativeOnly)
local nativeHandle
package, id, reason, nativeHandle, receipt = resolver.resolve()
eq(package, nil, "DRAMALESS 2.0.2 never becomes a KASC renderer facade")
eq(id, "DRAMALESS_SHAPE", "native-only receipt keeps the real manifest id")
eq(reason, "renderer-native-owned:DRAMALESS_SHAPE",
  "native-only renderer reports its ownership boundary")
eq(nativeCalls, 0, "KASC never calls DRAMALESS 2.0.2's private loader")
eq(receipt.export, "renderer-native-only/v1",
  "receipt records the renderer-native fallback contract")
ok(receipt.nativeOnly == true,
  "receipt marks the deliberately non-bridged renderer path")
module, moduleId, moduleError = resolver.module(nil, "OverworldBattle")
eq(module, nil, "native-only DRAMALESS exposes no KASC battle module")
eq(moduleId, "DRAMALESS_SHAPE",
  "native-only module rejection keeps renderer identity")
eq(moduleError, "renderer-native-owned:DRAMALESS_SHAPE",
  "native-only module rejection is explicit")
eq(nativeCalls, 0, "module lookup still never touches the private loader")
eq(resolver.findAlias(fakeMod, "DRAMATIC_SHAPE"), nil,
  "Wilds' historical alias never reaches DRAMALESS 2.0.2")
eq(nativeCalls, 0, "alias rejection does not touch the private loader")

local fixedCamera, fixedCameraId, fixedCameraError, fixedCameraReceipt =
  resolver.cameraModule()
ok(type(fixedCamera) == "table" and fixedCamera ~= nativeCamera,
  "exact DRAMALESS 2.0.2 returns a narrow camera control, not raw BattleCam")
eq(fixedCamera.schema, "ka-dramaless-2.0.2-camera-control/v1",
  "fixed camera control has a versioned closed schema")
eq(fixedCamera.ownsNativeHud, true,
  "fixed camera control records that Dramaless retains native HUD ownership")
eq(fixedCamera.rawTargetFrameH, 34.11 * 3,
  "fixed camera control names its reviewed target as a raw rig value")
eq(fixedCameraId, "DRAMALESS_SHAPE",
  "fixed camera receipt keeps the renderer identity")
eq(fixedCameraError, nil, "reviewed fixed camera has no resolver error")
eq(nativeCalls, 1,
  "the fixed camera seam makes exactly one owner-loader request")
eq(nativeNames[1], "BattleCam",
  "the fixed camera seam can request only the literal BattleCam module")
eq(fixedCameraReceipt.capability,
  "dramaless-2.0.2-battle-camera/v1",
  "camera receipt names the exact reviewed capability")
eq(fixedCameraReceipt.export, "fixed-battle-camera/v1",
  "camera receipt distinguishes the narrow exception from a module facade")
local cachedCamera = resolver.cameraModule()
eq(cachedCamera, fixedCamera, "reviewed camera capability is cached")
eq(nativeCalls, 1, "cached camera lookup never re-enters the owner loader")
local rawLeak = false
for _, field in ipairs({
  "RIGS", "rigFor", "frameH", "rig", "installOakLabLens", "lib", "mod",
}) do
  if fixedCamera[field] ~= nil then rawLeak = true end
end
eq(rawLeak, false,
  "fixed camera control exposes no raw table, V closure or owner authority")
local writeOk = pcall(function() fixedCamera.RIGS = nativeCamera.RIGS end)
eq(writeOk, false, "fixed camera control is read-only")
eq(fixedCamera.apply("classic"), true,
  "fixed control applies only its reviewed classic preset")
eq(nativeCamera.RIGS.tele.frameH, 34.11 * 3,
  "fixed control applies the literal historical factor-3 tele rig")
eq(fixedCamera.state().neutralFrameH, 34.11 * 3 * 1.3,
  "control telemetry reports the renderer-owned 1.3 neutral zoom separately")
eq(fixedCamera.apply("anything-else"), false,
  "fixed control rejects arbitrary camera mutations")

-- A fresh KASC resolver may be constructed after the first one already
-- applied its camera setting. That reviewed normalized state must validate
-- without widening the accepted API or losing the canonical fork restore.
local reloadedResolver = assert(loadfile(root .. "/voxel_renderer_compat.lua"))()(fakeMod)
local reloadedCamera, _, reloadedError = reloadedResolver.cameraModule()
eq(reloadedError, nil,
  "camera capability validates after a prior KASC mutation/reload")
ok(reloadedCamera ~= nativeCamera,
  "reloaded camera capability still hides the raw renderer table")
eq(nativeCalls, 2,
  "fresh resolver makes exactly one new literal BattleCam request")
eq(reloadedCamera.apply("fork"), true,
  "reloaded control can restore the exact upstream fork framing")
eq(nativeCamera.RIGS.tele.frameH, 34.11,
  "fork restore remains canonical after resolver reload")

-- The generic seam stays closed even after the fixed camera was admitted.
module, moduleId, moduleError = resolver.module(nil, "VoxelScene")
eq(module, nil, "native-only DRAMALESS still exposes no generic module")
eq(moduleError, "renderer-native-owned:DRAMALESS_SHAPE",
  "fixed camera admission cannot open a second private module")
eq(nativeCalls, 2,
  "generic lookup after camera admission does not touch the owner loader")

-- Every other official Dramaless 2.x build remains renderer-native only and
-- cannot inherit the exact 2.0.2 camera adapter.
local futureNativeCalls = 0
local futureNative = {
  version = "2.0.3",
  lib = { require = function()
    futureNativeCalls = futureNativeCalls + 1
    return nativeCamera
  end },
  voxelArenaProvider = {}, voxelCardProvider = {}, voxel2DBattleHost = {},
}
gameFor("DRAMALESS_SHAPE", "2.0.3", nil, futureNative,
  "artyrambles/DRAMALESS_SHAPE")
package, id, reason, nativeHandle, receipt = resolver.resolve()
eq(package, nil, "Dramaless 2.0.3 remains renderer-native only")
eq(reason, "renderer-native-owned:DRAMALESS_SHAPE",
  "future Dramaless 2.x preserves native ownership")
eq(receipt.provenance, "dramaless-2.x-renderer-native-best-effort",
  "future Dramaless receipt does not claim exact 2.0.2 review")
local futureCamera, futureCameraId, futureCameraError = resolver.cameraModule()
eq(futureCamera, nil, "Dramaless 2.0.3 gets no 2.0.2 camera adapter")
eq(futureCameraId, "DRAMALESS_SHAPE",
  "future native camera rejection keeps renderer identity")
eq(futureCameraError, "unsupported-native-camera",
  "future native camera rejection is explicit")
eq(futureNativeCalls, 0,
  "future Dramaless private loader is never probed for the exact adapter")

local badCameraCalls = 0
local badCameraMod = {
  find = function(id)
    if id ~= "DRAMALESS_SHAPE" then return nil end
    return {
      id = id, version = "2.0.2",
      exports = {
        version = "2.0.2",
        voxelArenaProvider = {}, voxelCardProvider = {},
        voxel2DBattleHost = {},
        lib = { require = function(name)
          badCameraCalls = badCameraCalls + 1
          eq(name, "BattleCam",
            "invalid package can only be probed for the fixed camera literal")
          return { RIGS = { tele = {}, wide = {} } }
        end },
      },
    }
  end,
}
local badCameraResolver = assert(loadfile(
  root .. "/voxel_renderer_compat.lua"))()(badCameraMod)
local badCamera, badCameraId, badCameraError =
  badCameraResolver.cameraModule()
eq(badCamera, nil, "invalid exact-version camera shape fails closed")
eq(badCameraId, "DRAMALESS_SHAPE",
  "invalid exact-version camera error keeps package identity")
eq(badCameraError, "invalid-native-camera-api:DRAMALESS_SHAPE",
  "invalid exact-version camera API has a precise diagnostic")
eq(badCameraCalls, 1,
  "invalid shape receives no second owner-loader request")

local staleExportCalls = 0
local staleExportMod = {
  find = function(id)
    if id ~= "DRAMALESS_SHAPE" then return nil end
    return {
      id = id, version = "2.0.2",
      exports = {
        version = "2.0.0",
        voxelArenaProvider = {}, voxelCardProvider = {},
        voxel2DBattleHost = {},
        lib = { require = function()
          staleExportCalls = staleExportCalls + 1
          return nativeCamera
        end },
      },
    }
  end,
}
local staleExportResolver = assert(loadfile(
  root .. "/voxel_renderer_compat.lua"))()(staleExportMod)
local staleCamera, _, staleCameraError = staleExportResolver.cameraModule()
eq(staleCamera, nil,
  "manifest 2.0.2 with stale runtime export 2.0.0 fails closed")
eq(staleCameraError, "invalid-native-export:DRAMALESS_SHAPE",
  "runtime-version mismatch has a precise camera diagnostic")
eq(staleExportCalls, 0,
  "runtime-version mismatch is rejected before owner-loader access")

local wrongRepoCalls = 0
local wrongRepoMod = {
  find = function(id)
    if id ~= "DRAMALESS_SHAPE" then return nil end
    return {
      id = id, version = "2.0.2", github = "attacker/dramaless_shape",
      exports = {
        version = "2.0.2",
        voxelArenaProvider = {}, voxelCardProvider = {},
        voxel2DBattleHost = {},
        lib = { require = function()
          wrongRepoCalls = wrongRepoCalls + 1
          return nativeCamera
        end },
      },
    }
  end,
}
local wrongRepoResolver = assert(loadfile(
  root .. "/voxel_renderer_compat.lua"))()(wrongRepoMod)
local wrongCamera, _, wrongCameraError = wrongRepoResolver.cameraModule()
eq(wrongCamera, nil, "explicit wrong-repository 2.0.2 camera fails closed")
eq(wrongCameraError, "unsupported-repository:DRAMALESS_SHAPE",
  "wrong-repository camera diagnostic is precise")
eq(wrongRepoCalls, 0,
  "wrong repository is rejected before its owner loader can run")

local nativeAndVoxel = voxelExport("0.1.1")
gameFor("DRAMALESS_SHAPE", "2.0.2", {
  VOXEL_ASCENDANT = nativeAndVoxel,
}, nativeOnly)
package, id, reason = resolver.resolve()
eq(package, nil, "DRAMALESS 2.0.2 plus another renderer fails closed")
eq(reason, "ambiguous-renderers:DRAMALESS_SHAPE,VOXEL_ASCENDANT",
  "native-only package still enforces one renderer at runtime")

-- Upstream Battle Art 1.9.0 is admitted as a separate install. Its historical
-- owner loader remains untouched, while every KASC/Wilds consumer receives a
-- local read-only allowlist facade.
local rawBattleArt, rawBattleCalls, rawBattleLib = battleArtExport("1.9.0")
-- Real stock/clientfix mod.find handles contain only id/version/exports.  The
-- exact upstream repository is enforced by rich manifest policy, while the
-- reviewed ZIP hash is a release-QA check; neither is forged into this handle.
gameFor("BATTLE_ART_VOXEL_FORK", "1.9.0", nil, rawBattleArt)
local safeHandle
package, id, reason, safeHandle, receipt = resolver.resolve()
ok(package ~= nil, "exact upstream Battle Art 1.9.0 resolves")
eq(id, "BATTLE_ART_VOXEL_FORK",
  "Battle Art retains its real manifest identity")
eq(reason, nil, "reviewed Battle Art has no resolver error")
ok(package ~= rawBattleArt,
  "KASC never forwards Battle Art's owner export table")
ok(package.lib ~= rawBattleLib,
  "KASC never forwards Battle Art's generic owner loader")
eq(package.lib.mod, nil, "local facade contains no owner mod authority")
eq(package.lib.path, nil, "local facade contains no owner asset path")
eq(package.lib.require("__KA_PRIVATE_PROBE__"), nil,
  "unknown Battle Art modules fail closed without reaching the owner loader")
eq(#rawBattleCalls, 11,
  "Battle Art preflights the complete allowlisted compatibility surface")
local callsAfterPreflight = #rawBattleCalls
eq(package.lib.require("VoxelScene"), modules.VoxelScene,
  "bundled Wilds receives the reviewed VoxelScene module")
eq(#rawBattleCalls, callsAfterPreflight,
  "allowlisted modules are served from the preflight cache")
ok(package.battleStage ~= rawBattleArt.battleStage,
  "battle-stage table is copied into the local read-only facade")
eq(package.battleStage.state({ id = "battle" }).staged, true,
  "read-only battle-stage state function remains available")
ok(not pcall(function()
  package.battleStage.ownership.hud = false
end), "battle-stage ownership copy is immutable")
eq(receipt.export, "kasc-local-allowlist/v1",
  "receipt names the local Battle Art facade")
eq(receipt.provenance,
  "battle-art-1.9.0-reviewed-api-contract",
  "Battle Art receipt names its reviewed runtime API contract")
eq(receipt.repository, nil,
  "stock/clientfix runtime does not pretend to attest repository metadata")
eq(safeHandle.exports, package,
  "companion aliases receive only the safe Battle Art export")
eq(safeHandle.github, nil,
  "safe handle does not manufacture repository authority")
ok(not pcall(function() package.lib.require = function() end end),
  "Battle Art module facade is read-only")
eq(rawBattleArt.lib, rawBattleLib,
  "KASC does not mutate Battle Art's separately installed export")
eq(rawBattleLib.mod.id, "BATTLE_ART_VOXEL_FORK",
  "Battle Art retains its own options/assets owner")

module, moduleId, moduleError, receipt = resolver.module(
  nil, "OverworldBattle")
eq(module, modules.OverworldBattle,
  "Battle Art exposes the side-texture compatibility seam")
eq(moduleId, "BATTLE_ART_VOXEL_FORK",
  "Battle Art module receipt retains its identity")
eq(moduleError, nil, "Battle Art side-texture seam is valid")

local futureBattleArt, futureBattleCalls = battleArtExport("2.9.9")
gameFor("BATTLE_ART_VOXEL_FORK", "2.9.9", nil, futureBattleArt,
  "absol89/DramaticShapeVoxelMod")
package, id, reason, safeHandle, receipt = resolver.resolve()
ok(package ~= nil, "official Battle Art 2.x is admitted best-effort")
eq(receipt.provenance, "battle-art-supported-series-best-effort",
  "future Battle Art does not claim an exact-version review")
eq(receipt.cacheRepair, nil,
  "future Battle Art does not inherit the exact 1.9.2 cache adapter")
eq(#futureBattleCalls, 11,
  "future Battle Art must still pass the closed capability preflight")

local mismatchedBattleArt = battleArtExport("2.9.9")
gameFor("BATTLE_ART_VOXEL_FORK", "1.9.2", nil, mismatchedBattleArt,
  "absol89/DramaticShapeVoxelMod")
package, id, reason = resolver.resolve()
eq(package, nil,
  "Battle Art manifest/export mismatch cannot acquire the 1.9.2 repair")
eq(reason, "invalid-renderer-version:BATTLE_ART_VOXEL_FORK",
  "Battle Art version mismatch fails before exact adapter installation")

-- PotatoVoxel 1.7.2 keeps its historical owner loader, just like Battle Art.
-- KASC binds the exact manifest/repository pair and exposes only the reviewed
-- rendering modules needed by KASC and bundled Wilds. The stale exported
-- version must neither block 1.7.2 nor admit a generic 1.6.1 package.
local rawPotato, rawPotatoCalls, rawPotatoLib = potatoExport()
gameFor("potato_voxel", "1.7.2", nil, rawPotato,
  "ShaneMcGovernIE/potato_voxel")
package, id, reason, safeHandle, receipt = resolver.resolve()
ok(package ~= nil, "exact PotatoVoxel 1.7.2 resolves")
eq(id, "potato_voxel", "PotatoVoxel retains its real manifest identity")
eq(reason, nil, "reviewed PotatoVoxel has no resolver error")
ok(package ~= rawPotato,
  "KASC never forwards PotatoVoxel's owner export table")
ok(package.lib ~= rawPotatoLib,
  "KASC never forwards PotatoVoxel's generic owner loader")
eq(package.lib.mod, nil, "Potato facade contains no owner mod authority")
eq(package.lib.path, nil, "Potato facade contains no owner asset path")
eq(package.lib.require("__KA_PRIVATE_PROBE__"), nil,
  "unknown Potato modules fail closed without reaching the owner loader")
eq(#rawPotatoCalls, 10,
  "Potato preflights the complete reviewed compatibility surface")
local potatoCallsAfterPreflight = #rawPotatoCalls
eq(package.lib.require("VoxelState"), modules.VoxelState,
  "bundled Wilds receives PotatoVoxel's reviewed state module")
eq(#rawPotatoCalls, potatoCallsAfterPreflight,
  "Potato allowlisted modules are served from the preflight cache")
eq(receipt.rendererVersion, "1.7.2",
  "Potato receipt trusts the manifest rather than its stale export string")
eq(receipt.provenance, "potato-voxel-1.7.2-reviewed-api-contract",
  "Potato receipt names the reviewed runtime contract")
eq(receipt.export, "kasc-local-allowlist/v1",
  "Potato receipt names the local authority-safe facade")
eq(safeHandle.exports, package,
  "Potato aliases receive only the safe local export")
eq(rawPotatoLib.mod.id, "potato_voxel",
  "PotatoVoxel retains its own settings/assets owner")
module, moduleId, moduleError, receipt = resolver.module(nil, "OverworldBattle")
eq(module, modules.OverworldBattle,
  "PotatoVoxel exposes the side-texture compatibility seam")
eq(moduleId, "potato_voxel",
  "Potato module receipt retains its identity")
eq(moduleError, nil, "Potato side-texture seam is valid")
local potatoAlias = resolver.findAlias(fakeMod, "DRAMATIC_SHAPE")
eq(potatoAlias and potatoAlias.id, "potato_voxel",
  "bundled Wilds alias retains PotatoVoxel identity")
eq(potatoAlias and potatoAlias.exports, package,
  "bundled Wilds receives only the safe PotatoVoxel facade")

local futurePotato, futurePotatoCalls = potatoExport()
gameFor("potato_voxel", "2.9.9", nil, futurePotato,
  "ShaneMcGovernIE/potato_voxel")
package, id, reason, safeHandle, receipt = resolver.resolve()
ok(package ~= nil, "official PotatoVoxel 2.x is admitted best-effort")
eq(receipt.provenance, "potato-voxel-supported-series-best-effort",
  "future PotatoVoxel does not claim an exact-version review")
eq(#futurePotatoCalls, 10,
  "future PotatoVoxel must still pass the closed capability preflight")

local potatoWrongRepo = potatoExport()
gameFor("potato_voxel", "1.7.2", nil, potatoWrongRepo,
  "someone-else/potato_voxel")
package, id, reason = resolver.resolve()
eq(package, nil, "repository-spoofed PotatoVoxel fails closed")
eq(reason, "unsupported-repository:potato_voxel",
  "Potato repository mismatch is diagnosed precisely")

for _, version in ipairs({ "1.6.1", "1.6.9", "1.7.0", "1.7.1", "3.0.0" }) do
  local candidate = potatoExport()
  gameFor("potato_voxel", version, nil, candidate,
    "ShaneMcGovernIE/potato_voxel")
  package, id, reason = resolver.resolve()
  eq(package, nil, "unreviewed PotatoVoxel " .. version .. " fails closed")
  eq(reason, "unsupported-version:potato_voxel:" .. version,
    "unsupported PotatoVoxel version is named precisely")
end

-- A future loader may expose repository metadata.  An explicit mismatch then
-- fails closed, but absence remains the real 0.1.90 handle shape above.
local wrongRepo = battleArtExport("1.9.0")
gameFor("BATTLE_ART_VOXEL_FORK", "1.9.0", nil, wrongRepo,
  "someone-else/DramaticShapeVoxelMod")
package, id, reason = resolver.resolve()
eq(package, nil, "repository-spoofed Battle Art fails closed")
eq(reason, "unsupported-repository:BATTLE_ART_VOXEL_FORK",
  "repository mismatch is diagnosed precisely")

local missingStage = battleArtExport("1.9.0")
missingStage.battleStage = nil
gameFor("BATTLE_ART_VOXEL_FORK", "1.9.0", nil, missingStage,
  "absol89/DramaticShapeVoxelMod")
package, id, reason = resolver.resolve()
eq(package, nil, "Battle Art without its stage ownership contract fails closed")
eq(reason, "invalid-battle-stage:BATTLE_ART_VOXEL_FORK",
  "missing stage contract is diagnosed precisely")

local oldBattleArt = battleArtExport("1.8.3")
gameFor("BATTLE_ART_VOXEL_FORK", "1.8.3", nil, oldBattleArt,
  "absol89/DramaticShapeVoxelMod")
package, id, reason = resolver.resolve()
eq(package, nil, "Battle Art 1.8.3 remains blocked on engine 0.1.90")
eq(reason, "unsupported-version:BATTLE_ART_VOXEL_FORK:1.8.3",
  "old Battle Art diagnostic names the exact version")

local unsafeDramaless = export("1.6.2-ST.190.1")
unsafeDramaless.storage = { write = function() end }
gameFor("DRAMALESS_SHAPE", "1.6.2-ST.190.1", nil, unsafeDramaless)
package, id, reason = resolver.resolve()
eq(package, nil, "legacy DRAMALESS owner authority fails closed")
eq(reason, "unsafe-export:DRAMALESS_SHAPE",
  "the DRAMALESS owner-authority leak is diagnosed precisely")

local genericDramaless = export("1.6.2-ST.190.1")
genericDramaless.lib.require = function(name)
  if name == "Storage" then return { write = function() end } end
  error("generic private resolver reached " .. tostring(name))
end
gameFor("DRAMALESS_SHAPE", "1.6.2-ST.190.1", nil, genericDramaless)
package, id, reason = resolver.resolve()
eq(package, nil, "generic DRAMALESS module access fails closed")
eq(reason, "unsafe-export:DRAMALESS_SHAPE",
  "the generic DRAMALESS resolver is diagnosed precisely")

-- Malformed, pre-baseline and 3.x builds fail closed even if their public
-- export shape looks compatible.
for _, version in ipairs({ "1.6.2.ST", "1.6.1", "3.0.0" }) do
  game(version)
  package, id, reason = resolver.resolve()
  eq(package, nil, "unreviewed DRAMALESS " .. version .. " is rejected")
  eq(id, nil, "an unsupported version exposes no owner")
  eq(reason, "unsupported-version:DRAMALESS_SHAPE:" .. version,
    "the unsupported DRAMALESS version is named precisely")
end

local futureClassic = game("1.6.4")
package, id, reason = resolver.resolve()
ok(package ~= nil, "official Dramaless 1.x after baseline is best-effort")
module, moduleId, moduleError, receipt = resolver.module(
  futureClassic, "OverworldBattle")
eq(module, modules.OverworldBattle,
  "future Dramaless 1.x receives only the common capability surface")
eq(receipt.provenance, "dramaless-supported-series-best-effort",
  "future Dramaless 1.x does not claim an exact-version review")
local futureClassicCamera, _, futureClassicCameraError =
  resolver.cameraModule(futureClassic)
eq(futureClassicCamera, nil,
  "future Dramaless 1.x does not inherit the exact camera adapter")
eq(futureClassicCameraError, "not-native-camera",
  "future Dramaless 1.x stays on the common renderer path")

-- Packages that have not passed the exact 0.1.90 sandbox are not aliases for
-- the reviewed renderer and cannot create ambiguity or option ownership.
for _, row in ipairs({
  { "DRAMATIC_SHAPE", "1.7.2" },
  { "ds_fp_ceiling", "1.60.0" },
}) do
  handles = {
    [row[1]] = { id = row[1], version = row[2], exports = export(row[2]) },
  }
  package, id, reason = resolver.resolve()
  eq(package, nil, row[1] .. " is not an approved renderer")
  eq(id, nil, row[1] .. " cannot claim renderer ownership")
  eq(reason, "renderer-absent", row[1] .. " remains outside discovery")
  eq(resolver.findAlias(fakeMod, row[1]), nil,
    row[1] .. " is never invented as an alias")
end

game("1.6.2-ST.190.1")
handles.DRAMATIC_SHAPE = {
  id = "DRAMATIC_SHAPE", version = "1.7.2", exports = export("1.7.2"),
}
package, id, reason = resolver.resolve()
ok(package ~= nil,
  "an unsupported foreign package cannot hide the reviewed renderer")
eq(id, "DRAMALESS_SHAPE", "the exact reviewed renderer remains authoritative")
eq(reason, nil, "unsupported foreign packages create no false ambiguity")
ok(resolver.isRendererRequest("DRAMATIC_SHAPE"),
  "bundled Wilds' historical renderer request is recognized")
ok(not resolver.isRendererId("DRAMATIC_SHAPE"),
  "the historical request is not promoted to an approved renderer id")
eq(resolver.findAlias(fakeMod, "DRAMATIC_SHAPE"),
  handles.DRAMALESS_SHAPE,
  "bundled Wilds receives only the reviewed DRAMALESS handle")

voxelGame("0.1.1")
eq(resolver.findAlias(fakeMod, "DRAMATIC_SHAPE"),
  handles.VOXEL_ASCENDANT,
  "bundled Wilds also reaches the standalone reviewed renderer")

game("1.6.2-ST.190.1")
handles.VOXEL_ASCENDANT = {
  id = "VOXEL_ASCENDANT", version = "0.1.1",
  exports = voxelExport("0.1.1"),
}
package, id, reason = resolver.resolve()
eq(package, nil, "two approved renderer owners fail closed")
eq(reason, "ambiguous-renderers:DRAMALESS_SHAPE,VOXEL_ASCENDANT",
  "ambiguous renderer diagnostic is stable and sorted")
eq(resolver.findAlias(fakeMod, "DRAMATIC_SHAPE"), nil,
  "historical request never chooses between two renderer owners")

game("1.6.2-ST.190.1")
local ambiguousBattleArt = battleArtExport("1.9.0")
handles.BATTLE_ART_VOXEL_FORK = {
  id = "BATTLE_ART_VOXEL_FORK", version = "1.9.0",
  github = "absol89/DramaticShapeVoxelMod",
  exports = ambiguousBattleArt,
}
package, id, reason = resolver.resolve()
eq(package, nil, "Battle Art plus DRAMALESS fails closed")
eq(reason,
  "ambiguous-renderers:BATTLE_ART_VOXEL_FORK,DRAMALESS_SHAPE",
  "three-choice resolver reports Battle Art ambiguity deterministically")
eq(resolver.findAlias(fakeMod, "DRAMATIC_SHAPE"), nil,
  "bundled Wilds never chooses between Battle Art and DRAMALESS")

game("3.0.0")
handles.DRAMATIC_SHAPE = {
  id = "DRAMATIC_SHAPE", version = "1.7.2", exports = export("1.7.2"),
}
eq(resolver.findAlias(fakeMod, "DRAMATIC_SHAPE"), nil,
  "the historical request rejects an out-of-range DRAMALESS target")
eq(resolver.lastError, "unsupported-version:DRAMALESS_SHAPE:3.0.0",
  "the rejected alias reports the actual out-of-range target")

handles = { DRAMALESS_SHAPE = {
  id = "DRAMALESS_SHAPE", version = "1.6.2-ST.190.1",
  exports = { version = "1.6.2-ST.190.1" },
} }
package, id, reason = resolver.resolve()
eq(package, nil, "a malformed reviewed export fails closed")
eq(reason, "invalid-export:DRAMALESS_SHAPE",
  "the malformed export reports its real package id")

local missingCapability = game("1.6.2-ST.190.1")
missingCapability.lib.require = function(name)
  if name == "OverworldBattle" then
    return { id = "battle-without-side-texture" }
  end
  return nil
end
local missingModule, missingId, missingReason = resolver.module(
  missingCapability, "OverworldBattle")
eq(missingModule, nil, "reviewed build without sideTexture fails closed")
eq(missingId, "DRAMALESS_SHAPE",
  "the missing-capability diagnostic retains package identity")
eq(missingReason,
  "missing-capability:DRAMALESS_SHAPE:OverworldBattle.sideTexture",
  "the diagnostic names the exact required seam")

handles = { DRAMALESS_SHAPE = {
  id = "DRAMALESS_SHAPE", exports = {
    lib = { require = function() return {} end },
  },
} }
package, id, reason = resolver.resolve()
eq(package, nil, "an unversioned reviewed package fails closed")
eq(reason, "missing-version:DRAMALESS_SHAPE",
  "the missing-version diagnostic names the renderer")

game("1.6.2-ST.190.1")
local handle, foundId, findError, foundExport = resolver.find(fakeMod)
eq(handle, handles.DRAMALESS_SHAPE,
  "mod.find returns the exact reviewed handle")
eq(foundId, "DRAMALESS_SHAPE", "mod.find retains the manifest identity")
eq(findError, nil, "valid mod.find resolution has no error")
eq(foundExport, handles.DRAMALESS_SHAPE.exports,
  "mod.find returns the matching export")
eq(resolver.findAlias(fakeMod, "DRAMALESS_SHAPE"), handle,
  "embedded systems receive the reviewed renderer handle")
eq(resolver.findAlias(fakeMod, "unknown_renderer"), nil,
  "unknown renderer aliases are never invented")

ok(resolver.optionRowMatches("pipeline:voxel"),
  "the engine Voxel pipeline row is recognized")
ok(resolver.optionRowMatches("DRAMALESS_SHAPE:voxel"),
  "the reviewed renderer option row is recognized")
ok(resolver.optionRowMatches("VOXEL_ASCENDANT:voxel"),
  "the standalone renderer option row is recognized")
ok(resolver.optionRowMatches("BATTLE_ART_VOXEL_FORK:battle_art"),
  "the exact reviewed Battle Art option row is recognized")
ok(not resolver.optionRowMatches("ds_fp_ceiling:weather"),
  "First Person rows do not masquerade as renderer controls")

print(("voxel_renderer_compat_test: PASS (%d checks)"):format(checks))
