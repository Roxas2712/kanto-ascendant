-- One fail-closed authority accepts only the Voxel packages whose exact
-- 0.1.90 sandbox, renderer and companion contracts have been verified.

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
  OverworldBattle = { id = "battle", sideTexture = function() end },
  BattleCam = { id = "camera" },
  VoxelScene = { id = "scene" },
  Voxel3D = { id = "voxel" },
  Mat4 = { id = "matrix" },
  SpriteBillboards = { id = "billboards" },
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

voxelGame("0.1.2")
package, id, reason = resolver.resolve()
eq(package, nil, "an unreviewed future Voxel Ascendant build fails closed")
eq(reason, "unsupported-version:VOXEL_ASCENDANT:0.1.2",
  "future renderer diagnostic names its exact version")

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

-- Unreviewed upstream builds fail closed even if their public export shape
-- looks compatible.
for _, version in ipairs({ "1.6.2.ST", "1.6.4", "1.6.5" }) do
  game(version)
  package, id, reason = resolver.resolve()
  eq(package, nil, "unreviewed DRAMALESS " .. version .. " is rejected")
  eq(id, nil, "an unsupported version exposes no owner")
  eq(reason, "unsupported-version:DRAMALESS_SHAPE:" .. version,
    "the unsupported DRAMALESS version is named precisely")
end

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

game("1.6.4")
handles.DRAMATIC_SHAPE = {
  id = "DRAMATIC_SHAPE", version = "1.7.2", exports = export("1.7.2"),
}
eq(resolver.findAlias(fakeMod, "DRAMATIC_SHAPE"), nil,
  "the historical request rejects an unreviewed DRAMALESS target")
eq(resolver.lastError, "unsupported-version:DRAMALESS_SHAPE:1.6.4",
  "the rejected alias reports the actual unreviewed target")

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
