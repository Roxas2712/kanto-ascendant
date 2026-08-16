-- Exact Battle Art 1.9.2 cache adapter contract.
--
-- The optional raw-stream cache may be unavailable on current desktop
-- engines, or a live map may be ineligible after a runtime mutation. Neither
-- state invalidates the GPU mesh ChunkMesher has already built. Real writes,
-- however, remain wholly owned by Battle Art and must preserve false/error
-- returns and exceptions.

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

local cacheAvailable, mapEligible = false, true
local terrainMode, auxMode = "false", "false"
local terrainCalls, auxCalls, terrainLoadCalls, auxLoadCalls = 0, 0, 0, 0
local disk = {
  available = function() return cacheAvailable end,
  staticEligible = function() return mapEligible end,
  loadTerrain = function(map)
    terrainLoadCalls = terrainLoadCalls + 1
    return { map = map, kind = "terrain" }, "terrain-loaded"
  end,
  loadAux = function(map)
    auxLoadCalls = auxLoadCalls + 1
    return { map = map, kind = "aux" }, "aux-loaded"
  end,
  saveTerrain = function()
    terrainCalls = terrainCalls + 1
    if terrainMode == "throw" then error("terrain encoder exploded", 0) end
    if terrainMode == "true" then return true, "terrain-written" end
    return false, "terrain write denied"
  end,
  saveAux = function()
    auxCalls = auxCalls + 1
    if auxMode == "throw" then error("aux encoder exploded", 0) end
    if auxMode == "true" then return true, "aux-written" end
    return false, "aux write denied"
  end,
}
local originalTerrain, originalAux = disk.saveTerrain, disk.saveAux
local originalLoadTerrain, originalLoadAux = disk.loadTerrain, disk.loadAux

local moduleNames = {
  AntiAlias = true, BattleCam = true, FirstPerson = true, Mat4 = true,
  OverworldBattle = true, ShadowMap = true, SpriteBillboards = true,
  TerrainAtlas = true, Voxel3D = true, VoxelScene = true, VoxelState = true,
}
local rawCalls = {}
local rawLib = {
  mod = { id = "BATTLE_ART_VOXEL_FORK" },
  path = "/separately-installed/battle-art-1.9.2",
}
rawLib.require = function(name)
  rawCalls[#rawCalls + 1] = name
  if name == "VoxelMeshDisk" then return disk end
  if moduleNames[name] then
    if name == "OverworldBattle" then
      return { sideTexture = function() return {} end }
    end
    return { name = name }
  end
  return { private = name }
end

local exported = {
  version = "1.9.2",
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
}
handles.BATTLE_ART_VOXEL_FORK = {
  id = "BATTLE_ART_VOXEL_FORK", version = "1.9.2", exports = exported,
  github = "absol89/DramaticShapeVoxelMod",
}

local safe, id, reason, safeHandle, receipt = resolver.resolve()
ok(safe ~= nil, "exact Battle Art 1.9.2 resolves")
eq(id, "BATTLE_ART_VOXEL_FORK", "repair retains renderer identity")
eq(reason, nil, "repair has no resolver error")
ok(safe ~= exported, "repair never exposes the raw owner export")
ok(safeHandle.exports == safe, "safe handle exposes only the local facade")
eq(receipt.provenance, "battle-art-1.9.2-reviewed-api-cache-adapter",
  "receipt pins the exact reviewed adapter")
eq(receipt.cacheRepair.schema, "ka-battle-art-cache-repair/v1",
  "receipt identifies the cache repair schema")
eq(receipt.cacheRepair.optionalCache, "unavailable-or-ineligible-noop",
  "receipt limits the successful no-op to optional-cache states")
ok(disk.saveTerrain ~= originalTerrain and disk.saveAux ~= originalAux,
  "repair wraps only the private cache persistence seam")
eq(disk.loadTerrain, originalLoadTerrain,
  "terrain cache reload remains wholly owned by Battle Art")
eq(disk.loadAux, originalLoadAux,
  "aux cache reload remains wholly owned by Battle Art")
eq(safe.lib.require("VoxelMeshDisk"), nil,
  "foreign cache authority is absent from the public facade")

-- Cache reads are not part of the failing persistence seam. A valid reload
-- must retain every original return value and identity.
local loadMap = { id = "ROUTE_1" }
local loaded, loadDetail = disk.loadTerrain(loadMap)
eq(loaded.map, loadMap, "terrain cache reload preserves its map identity")
eq(loaded.kind, "terrain", "terrain cache reload preserves its payload")
eq(loadDetail, "terrain-loaded", "terrain cache reload detail is preserved")
eq(terrainLoadCalls, 1, "terrain cache reload delegates exactly once")
loaded, loadDetail = disk.loadAux(loadMap)
eq(loaded.map, loadMap, "aux cache reload preserves its map identity")
eq(loaded.kind, "aux", "aux cache reload preserves its payload")
eq(loadDetail, "aux-loaded", "aux cache reload detail is preserved")
eq(auxLoadCalls, 1, "aux cache reload delegates exactly once")

-- Current macOS desktop: no supported persistence backend. The completed
-- live mesh proceeds and no write is attempted.
local saved, detail = disk.saveTerrain({ id = "ROUTE_1" }, "full", nil, {}, {})
eq(saved, true, "unavailable terrain cache is an allowed no-op")
eq(detail, nil, "unavailable cache invents no storage receipt")
eq(terrainCalls, 0, "unavailable cache never reaches the writer")
saved = disk.saveAux({ id = "ROUTE_1" }, {})
eq(saved, true, "unavailable aux cache is an allowed no-op")
eq(auxCalls, 0, "unavailable aux cache never reaches the writer")

-- A dynamic/non-snapshotted map is also valid for RAM/GPU rendering, but not
-- for a persistent static-geometry key.
cacheAvailable, mapEligible = true, false
saved = disk.saveTerrain({ id = "DYNAMIC_TEST" }, "full", nil, {}, {})
eq(saved, true, "ineligible terrain persistence is an allowed no-op")
eq(terrainCalls, 0, "ineligible terrain never reaches the writer")
saved = disk.saveAux({ id = "DYNAMIC_TEST" }, {})
eq(saved, true, "ineligible aux persistence is an allowed no-op")
eq(auxCalls, 0, "ineligible aux never reaches the writer")

-- Once persistence is available and the map is eligible, every return value
-- and exception remains Battle Art's. This is the write-error recovery seam:
-- KASC does not convert genuine storage failures into success.
mapEligible = true
saved, detail = disk.saveTerrain({ id = "ROUTE_1" }, "full", nil, {}, {})
eq(saved, false, "eligible terrain write failure remains fatal")
eq(detail, "terrain write denied", "terrain writer detail is preserved")
eq(terrainCalls, 1, "eligible terrain delegates exactly once")
saved, detail = disk.saveAux({ id = "ROUTE_1" }, {})
eq(saved, false, "eligible aux write failure remains fatal")
eq(detail, "aux write denied", "aux writer detail is preserved")
eq(auxCalls, 1, "eligible aux delegates exactly once")

terrainMode, auxMode = "true", "true"
saved, detail = disk.saveTerrain({ id = "ROUTE_1" }, "full", nil, {}, {})
eq(saved, true, "eligible terrain success is preserved")
eq(detail, "terrain-written", "terrain success detail is preserved")
saved, detail = disk.saveAux({ id = "ROUTE_1" }, {})
eq(saved, true, "eligible aux success is preserved")
eq(detail, "aux-written", "aux success detail is preserved")

terrainMode, auxMode = "throw", "throw"
local called, thrown = pcall(disk.saveTerrain,
  { id = "ROUTE_1" }, "full", nil, {}, {})
eq(called, false, "eligible terrain exception is not swallowed")
ok(tostring(thrown):find("terrain encoder exploded", 1, true) ~= nil,
  "terrain exception text is preserved")
called, thrown = pcall(disk.saveAux, { id = "ROUTE_1" }, {})
eq(called, false, "eligible aux exception is not swallowed")
ok(tostring(thrown):find("aux encoder exploded", 1, true) ~= nil,
  "aux exception text is preserved")

-- Re-resolution is idempotent and cannot layer a second wrapper.
local terrainWrapper, auxWrapper = disk.saveTerrain, disk.saveAux
safe, id, reason = resolver.resolve()
ok(safe ~= nil and id == "BATTLE_ART_VOXEL_FORK" and reason == nil,
  "exact package remains valid after repeated discovery")
eq(disk.saveTerrain, terrainWrapper, "terrain repair installs exactly once")
eq(disk.saveAux, auxWrapper, "aux repair installs exactly once")

-- If another owner replaces the repaired seam after admission, discovery
-- fails closed rather than assuming KASC still controls the tested contract.
disk.saveTerrain = function() return true end
safe, id, reason = resolver.resolve()
eq(safe, nil, "overridden cache seam fails closed")
eq(reason, "cache-repair-overridden:BATTLE_ART_VOXEL_FORK",
  "override diagnostic is exact")

print(("battle_art_192_cache_compat_test: %d checks passed"):format(checks))
