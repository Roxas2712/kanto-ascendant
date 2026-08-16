-- Single authority for optional Voxel-renderer discovery.
--
-- Engine 0.1.90 sandboxes every mod.  Voxel Ascendant is the standalone,
-- sandbox-native renderer; the dedicated DRAMALESS 1.6.2-ST.190.1 build and
-- upstream Battle Art 1.9.0 are exact reviewed packages.  DRAMALESS 2.0.2 is
-- separately admitted as a renderer-native stack: it owns its modern world
-- and native-card battle path, but does not publish the closed module/HUD
-- contract KASC needs for its optional renderer bridges. Older upstream
-- DRAMALESS, DRAMATIC_SHAPE, Battle Art and First Person builds touch APIs that
-- the reviewed sandbox removes, so this authority must reject them instead of
-- advertising a partial bridge.

return function(ownerMod)
  local R = {}
  R.ids = {
    "VOXEL_ASCENDANT",
    "DRAMALESS_SHAPE",
    "BATTLE_ART_VOXEL_FORK",
  }
  R.pinnedVersions = {
    VOXEL_ASCENDANT = "0.1.1",
    DRAMALESS_SHAPE = "1.6.2-ST.190.1",
    BATTLE_ART_VOXEL_FORK = "1.9.0",
  }
  R.approvedVersions = {
    VOXEL_ASCENDANT = {
      ["0.1.0-rc.1"] = "roxas2712-voxel-ascendant-mit-v161-rc1",
      ["0.1.1"] = "roxas2712-voxel-ascendant-mit-v161",
    },
    DRAMALESS_SHAPE = {
      ["1.6.2-ST.190.1"] = "artyrambles-classic-release-0190-compat",
    },
    BATTLE_ART_VOXEL_FORK = {
      ["1.9.0"] = "battle-art-1.9.0-reviewed-api-contract",
    },
  }
  -- This is deliberately distinct from `approvedVersions`. A native-only
  -- package is allowed by the manifest but never receives an alias, module
  -- facade, HUD wrapper, camera mutation or Wilds renderer hook from KASC.
  -- That keeps DRAMALESS 2.0.2's own providers authoritative and ensures a
  -- spoofed runtime handle cannot gain cross-mod authority through KASC.
  R.nativeRendererVersions = {
    DRAMALESS_SHAPE = {
      ["2.0.2"] = "artyrambles-dramaless-2.0.2-native-card-provider",
    },
  }
  R.approvedRepositories = {
    BATTLE_ART_VOXEL_FORK = "absol89/dramaticshapevoxelmod",
  }
  -- Battle Art 1.9.0 still publishes its historical `lib = V` owner loader.
  -- KASC never forwards that table. After exact id/version/capability review,
  -- it creates a local facade containing only modules used by KASC and its
  -- bundled Wilds renderer adapter. Rich manifest policy pins the repository,
  -- while release QA verifies the reviewed ZIP hash; neither datum is exposed
  -- by the 0.1.90 runtime handle. Unknown/private module names always return nil and the
  -- separately installed renderer retains all asset, option and save ownership.
  local BATTLE_ART_MODULES = {
    AntiAlias = true,
    BattleCam = true,
    FirstPerson = true,
    Mat4 = true,
    OverworldBattle = true,
    ShadowMap = true,
    SpriteBillboards = true,
    TerrainAtlas = true,
    Voxel3D = true,
    VoxelScene = true,
    VoxelState = true,
  }
  local battleArtFacadeCache = setmetatable({}, { __mode = "k" })
  -- Bundled Wilds 1.12.2 predates the DRAMALESS manifest id and asks for
  -- DRAMATIC_SHAPE.  Treat that name only as a capability request for the
  -- one reviewed renderer that is actually installed; it must never make an
  -- installed upstream DRAMATIC_SHAPE package an approved renderer.
  R.requestAliases = {
    DRAMATIC_SHAPE = true,
  }
  R.lastError = nil
  R.lastReceipt = nil

  local known = {}
  for _, id in ipairs(R.ids) do known[id] = true end

  local function versionOf(handle, exported)
    local manifest = type(handle) == "table" and handle.manifest or nil
    return manifest and manifest.version
      or type(handle) == "table" and handle.version
      or type(exported) == "table" and exported.version
      or nil
  end

  local function repositoryOf(handle, exported)
    local manifest = type(handle) == "table" and handle.manifest or nil
    local repository = manifest and manifest.github
      or type(handle) == "table" and handle.github
      or type(exported) == "table" and exported.github
      or nil
    return type(repository) == "string" and repository:lower() or nil
  end

  local function readonly(values)
    return setmetatable({}, {
      __index = values,
      __newindex = function()
        error("read-only renderer compatibility facade", 2)
      end,
      __metatable = false,
    })
  end

  local function battleArtFacade(id, version, exported, handle)
    local expectedRepository = R.approvedRepositories[id]
    -- Stock 0.1.90 and the reviewed clientfix deliberately expose only
    -- { id, version, exports } through mod.find().  Repository provenance is
    -- enforced by rich manifest policy; release QA separately verifies the
    -- reviewed ZIP hash. Neither claim is invented here. If a future loader
    -- does supply repository metadata
    -- we still reject an explicit mismatch.
    local runtimeRepository = repositoryOf(handle, exported)
    if runtimeRepository ~= nil and runtimeRepository ~= expectedRepository then
      return nil, "unsupported-repository:" .. tostring(id)
    end
    if type(exported.battleStage) ~= "table"
        or exported.battleStage.apiVersion ~= 1
        or exported.battleStage.sourceModId ~= id
        or type(exported.battleStage.state) ~= "function"
        or type(exported.battleStage.ownership) ~= "table"
        or exported.battleStage.ownership.hud ~= true
        or exported.battleStage.ownership.animationProjection ~= true then
      return nil, "invalid-battle-stage:" .. tostring(id)
    end
    if type(exported.battlePresentation) ~= "table"
        or exported.battlePresentation.apiVersion ~= 1
        or exported.battlePresentation.sourceModId ~= id
        or type(exported.battlePresentation.suppressHook) ~= "string" then
      return nil, "invalid-battle-presentation:" .. tostring(id)
    end

    local rawLib = exported.lib
    local cached = battleArtFacadeCache[exported]
    if cached and cached.version == version then
      local safeHandle = readonly({
        id = id,
        version = version,
        exports = cached.exported,
      })
      return cached.exported, nil, safeHandle
    end

    local cache = {}
    -- Preflight the entire compatibility surface once. The exact supported
    -- ID/version/API contract is necessary but not sufficient: a locally
    -- incomplete install must fail before KASC enables world, HUD, sprites or
    -- fissures. Release QA, outside this runtime handle, binds upstream bytes.
    for name in pairs(BATTLE_ART_MODULES) do
      local ok, value = pcall(rawLib.require, name)
      if not ok or type(value) ~= "table" then
        return nil, ("missing-module:%s:%s"):format(tostring(id), name)
      end
      cache[name] = value
    end
    local function safeRequire(name)
      if not BATTLE_ART_MODULES[name] then return nil end
      return cache[name]
    end
    local rawStage = exported.battleStage
    local stageOwnership = {}
    for name, claimed in pairs(rawStage.ownership) do
      if type(name) == "string" and type(claimed) == "boolean" then
        stageOwnership[name] = claimed
      end
    end
    local safeStage = readonly({
      apiVersion = 1,
      sourceModId = id,
      ownership = readonly(stageOwnership),
      enabled = type(rawStage.enabled) == "function" and function()
        return rawStage.enabled() == true
      end or nil,
      state = function(expectedBattle)
        return rawStage.state(expectedBattle)
      end,
    })
    local rawPresentation = exported.battlePresentation
    local presentationSurfaces = {}
    for name, surface in pairs(rawPresentation.surfaces or {}) do
      if type(name) == "string" and type(surface) == "string" then
        presentationSurfaces[name] = surface
      end
    end
    local safePresentation = readonly({
      apiVersion = 1,
      sourceModId = id,
      suppressHook = rawPresentation.suppressHook,
      surfaces = readonly(presentationSurfaces),
    })
    local safeLib = readonly({ require = safeRequire })
    local safeExport = readonly({
      version = version,
      lib = safeLib,
      battleStage = safeStage,
      battlePresentation = safePresentation,
    })
    battleArtFacadeCache[exported] = {
      version = version,
      exported = safeExport,
    }
    local safeHandle = readonly({
      id = id,
      version = version,
      exports = safeExport,
    })
    return safeExport, nil, safeHandle
  end

  local function validate(id, exported, handle)
    if type(exported) ~= "table" or type(exported.lib) ~= "table"
        or type(exported.lib.require) ~= "function" then
      return false, "invalid-export:" .. tostring(id)
    end
    local version = versionOf(handle, exported)
    local approved = R.approvedVersions[id]
    if approved and version == nil then
      return false, "missing-version:" .. tostring(id)
    end
    version = version and tostring(version) or nil
    if approved and not approved[version] then
      return false, ("unsupported-version:%s:%s"):format(
        tostring(id), tostring(version))
    end
    local safeHandle
    if id == "BATTLE_ART_VOXEL_FORK" then
      local facade, facadeReason
      facade, facadeReason, safeHandle =
        battleArtFacade(id, version, exported, handle)
      if not facade then return false, facadeReason end
      exported = facade
    end
    if id == "VOXEL_ASCENDANT" then
      local renderer = exported.renderer
      local capabilities = exported.capabilities
      if exported.apiVersion ~= 1
          or type(renderer) ~= "table"
          or renderer.id ~= id
          or renderer.version ~= version
          or renderer.pipeline ~= "voxel"
          or renderer.cameraProfile ~= "orbit-only"
          or type(capabilities) ~= "table"
          or capabilities.voxelWorld ~= true
          or capabilities.wallDecals ~= 1
          or capabilities.diskCache ~= false
          or capabilities.stadium ~= false
          or capabilities.vr ~= false
          or type(capabilities.battleCards) ~= "table"
          or capabilities.battleCards[1] ~= "MAP"
          or capabilities.battleCards[2] ~= "DISCS" then
        return false, "invalid-capability:" .. tostring(id)
      end
    end
    -- Every reviewed renderer must expose a closed module facade.  The
    -- legacy `lib = V` shape hands companion mods the renderer owner's mod,
    -- save, storage and content authority, even when its rendering modules
    -- themselves are compatible.  Reject direct authority fields and reject
    -- generic/private resolvers: a closed facade returns nil for an unknown
    -- module name without consulting the owner's loader.
    local authorityFields = {
      "mod", "path", "data", "cache", "storage", "save", "content",
      "fs", "ffi", "read", "write", "options", "events", "hooks",
      "find",
    }
    for _, field in ipairs(authorityFields) do
      if exported[field] ~= nil or exported.lib[field] ~= nil then
        return false, "unsafe-export:" .. tostring(id)
      end
    end
    local probeOk, probeValue = pcall(
      exported.lib.require, "__KA_PRIVATE_PROBE__")
    if not probeOk or probeValue ~= nil then
      return false, "unsafe-export:" .. tostring(id)
    end
    return true, nil, {
      schema = "ka-voxel-renderer-capability/v1",
      rendererId = id,
      rendererVersion = version,
      provenance = approved and approved[version] or "unversioned",
      export = id == "BATTLE_ART_VOXEL_FORK"
        and "kasc-local-allowlist/v1" or "lib.require",
      -- Usually nil on 0.1.90: mod.find() does not expose manifest metadata.
      -- Never turn the package-policy repository pin into a fake live receipt.
      repository = repositoryOf(handle, exported),
      safeHandle = safeHandle,
    }, exported
  end

  local function choose(candidates)
    if #candidates == 0 then return nil, nil, "renderer-absent" end
    if #candidates > 1 then
      local ids = {}
      for _, row in ipairs(candidates) do ids[#ids + 1] = row.id end
      table.sort(ids)
      return nil, nil, "ambiguous-renderers:" .. table.concat(ids, ",")
    end
    local row = candidates[1]
    local nativeVersions = R.nativeRendererVersions[row.id]
    local nativeProvenance = nativeVersions
      and nativeVersions[tostring(versionOf(row.handle, row.exported))]
    if nativeProvenance then
      -- Do not read, probe or forward `exports.lib`: DRAMALESS 2.0.2's
      -- legacy V table retains its renderer owner's mod/path/data authority.
      -- Its built-in arena/card host remains fully renderer-owned, while
      -- KASC keeps every optional overlay in its ordinary native-2D path.
      return nil, row.id, "renderer-native-owned:" .. row.id,
        nil, {
          schema = "ka-voxel-renderer-capability/v1",
          rendererId = row.id,
          rendererVersion = tostring(versionOf(row.handle, row.exported)),
          provenance = nativeProvenance,
          export = "renderer-native-only/v1",
          nativeOnly = true,
        }
    end
    local ok, reason, receipt, safeExport =
      validate(row.id, row.exported, row.handle)
    if not ok then return nil, nil, reason end
    return safeExport or row.exported, row.id, nil,
      receipt and receipt.safeHandle or row.handle, receipt
  end

  function R.resolve(explicitExports)
    -- Runtime discovery has exactly one supported boundary: mod.find(id) and
    -- the returned handle's exports.  `explicitExports` exists only for the
    -- resolver's isolated data-table tests; live game/loader internals are
    -- never inspected.
    if ownerMod and type(ownerMod.find) == "function" then
      local handle, id, reason, exported, receipt = R.find(ownerMod)
      return exported, id, reason, handle, receipt
    end
    local exports = explicitExports
    if type(exports) ~= "table" then
      R.lastError = "renderer-absent"
      return nil, nil, R.lastError
    end
    local candidates = {}
    for _, id in ipairs(R.ids) do
      if exports[id] ~= nil then
        candidates[#candidates + 1] = {
          id = id,
          exported = exports[id],
          handle = nil,
        }
      end
    end
    local exported, id, reason, handle, receipt = choose(candidates)
    R.lastError = reason
    R.lastReceipt = receipt
    return exported, id, reason, handle, receipt
  end

  function R.find(mod)
    if not (mod and type(mod.find) == "function") then
      R.lastError = "renderer-absent"
      return nil, nil, R.lastError
    end
    local candidates = {}
    for _, id in ipairs(R.ids) do
      local ok, handle = pcall(mod.find, id)
      if ok and handle ~= nil then
        candidates[#candidates + 1] = {
          id = id,
          handle = handle,
          exported = handle.exports,
        }
      end
    end
    local exported, id, reason, handle, receipt = choose(candidates)
    R.lastError = reason
    R.lastReceipt = receipt
    return handle, id, reason, exported, receipt
  end

  function R.module(gameOrExports, name)
    local exported, id, reason, _, receipt = R.resolve(gameOrExports)
    if not exported then return nil, id, reason end
    local ok, value = pcall(exported.lib.require, name)
    if not ok or type(value) ~= "table" then
      reason = ("missing-module:%s:%s"):format(tostring(id), tostring(name))
      R.lastError = reason
      return nil, id, reason
    end
    if name == "OverworldBattle" and type(value.sideTexture) ~= "function" then
      reason = ("missing-capability:%s:%s.sideTexture"):format(
        tostring(id), tostring(name))
      R.lastError = reason
      R.lastReceipt = nil
      return nil, id, reason
    end
    receipt = receipt or {}
    receipt.module = name
    receipt.capability = name == "OverworldBattle"
      and "sideTexture" or "module-table"
    R.lastError = nil
    R.lastReceipt = receipt
    return value, id, nil, receipt
  end

  function R.isRendererId(id)
    return known[id] == true
  end

  function R.isRendererRequest(id)
    return known[id] == true or R.requestAliases[id] ~= nil
  end

  function R.findAlias(mod, requestedId)
    local expectedId = known[requestedId] and requestedId
      or R.requestAliases[requestedId]
    if not expectedId then return nil end
    local handle, resolvedId = R.find(mod)
    if expectedId ~= true and resolvedId ~= expectedId then return nil end
    return handle
  end

  function R.optionRowMatches(id)
    if id == "pipeline:voxel" then return true end
    if type(id) ~= "string" then return false end
    for _, rendererId in ipairs(R.ids) do
      if id:find("^" .. rendererId .. ":") then return true end
    end
    return false
  end

  return R
end
