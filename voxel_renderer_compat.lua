-- Single authority for optional Voxel-renderer discovery.
--
-- Engine 0.1.90 sandboxes every mod.  Voxel Ascendant is the standalone,
-- sandbox-native renderer; the dedicated DRAMALESS 1.6.2-ST.190.1 build,
-- upstream Battle Art 1.9.0 and PotatoVoxel 1.7.2 are exact reviewed packages.
-- DRAMALESS 2.0.2 is
-- separately admitted as a renderer-native stack: it owns its modern world,
-- native-card battle path and HUD. Its exact 2.0.2 release has one deliberately
-- narrow exception: this resolver may inspect the literal reviewed BattleCam
-- module and expose only fixed camera-preset control in order to preserve the
-- user-facing Classic/Wide option. The raw table, generic modules, HUD and
-- owner authority never escape that exception. Older upstream
-- DRAMALESS, DRAMATIC_SHAPE, Battle Art and First Person builds touch APIs that
-- the reviewed sandbox removes, so this authority must reject them instead of
-- advertising a partial bridge.

return function(ownerMod)
  local R = {}
  R.ids = {
    "VOXEL_ASCENDANT",
    "DRAMALESS_SHAPE",
    "BATTLE_ART_VOXEL_FORK",
    "potato_voxel",
  }
  R.pinnedVersions = {
    VOXEL_ASCENDANT = "0.1.1",
    DRAMALESS_SHAPE = "1.6.2-ST.190.1",
    BATTLE_ART_VOXEL_FORK = "1.9.0",
    potato_voxel = "1.7.2",
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
    potato_voxel = {
      ["1.7.2"] = "potato-voxel-1.7.2-reviewed-api-contract",
    },
  }
  -- This is deliberately distinct from `approvedVersions`. A native-only
  -- package never receives an alias, general module facade, HUD wrapper or
  -- Wilds renderer hook from KASC. The exact 2.0.2 camera path below exposes
  -- only a fixed, read-only capability; raw renderer authority stays private.
  -- That keeps DRAMALESS 2.0.2's providers authoritative and ensures a spoofed
  -- runtime handle cannot gain cross-mod authority through KASC.
  R.nativeRendererVersions = {
    DRAMALESS_SHAPE = {
      ["2.0.2"] = "artyrambles-dramaless-2.0.2-native-card-provider",
    },
  }
  R.approvedRepositories = {
    BATTLE_ART_VOXEL_FORK = "absol89/dramaticshapevoxelmod",
    potato_voxel = "shanemcgovernie/potato_voxel",
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
  -- DRAMALESS 2.0.2 still exports its owner-scoped V loader. It is not safe
  -- to turn that into a general facade, but the exact upstream package needs
  -- KASC's long-standing camera calibration. Cache only a read-only control
  -- facade after a strict shape/value check; the raw BattleCam table and its
  -- V-closing functions never leave this resolver.
  local nativeCameraCache = setmetatable({}, { __mode = "k" })
  local lastChoice

  -- PotatoVoxel still exports its historical owner namespace (`lib = V`).
  -- Its exact 1.7.2 release is compatible, but forwarding that namespace
  -- would also forward the renderer's mod/path/data authority. Expose only
  -- the modules KASC and bundled Wilds actually consume. BattleCam is
  -- intentionally absent: Potato owns its own camera and KASC must not apply
  -- the historical Dramaless camera preset to it.
  local POTATO_MODULES = {
    AntiAlias = true,
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
  local potatoFacadeCache = setmetatable({}, { __mode = "k" })
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

  local function finite(value)
    return type(value) == "number" and value == value
      and value ~= math.huge and value ~= -math.huge
  end

  local function near(actual, expected)
    return finite(actual) and math.abs(actual - expected) < 0.000001
  end

  local function validateDramaless202Camera(row)
    if not row or row.id ~= "DRAMALESS_SHAPE"
        or tostring(versionOf(row.handle, row.exported)) ~= "2.0.2" then
      return nil, "unsupported-native-camera"
    end
    local expectedRepository = "artyrambles/dramaless_shape"
    local runtimeRepository = repositoryOf(row.handle, row.exported)
    if runtimeRepository ~= nil and runtimeRepository ~= expectedRepository then
      return nil, "unsupported-repository:DRAMALESS_SHAPE"
    end
    local exported = row.exported
    if type(exported) ~= "table"
        or tostring(exported.version) ~= "2.0.2"
        or type(exported.voxelArenaProvider) ~= "table"
        or type(exported.voxelCardProvider) ~= "table"
        or type(exported.voxel2DBattleHost) ~= "table"
        or type(exported.lib) ~= "table"
        or type(exported.lib.require) ~= "function" then
      return nil, "invalid-native-camera-export:DRAMALESS_SHAPE"
    end
    local cached = nativeCameraCache[exported]
    if cached then return cached end

    -- This literal is intentional. Never accept a caller-provided name here:
    -- the surrounding V table owns mod/path/data authority in upstream 2.0.2.
    local ok, camera = pcall(exported.lib.require, "BattleCam")
    local rigs = type(camera) == "table" and camera.RIGS or nil
    local tele = type(rigs) == "table" and rigs.tele or nil
    local wide = type(rigs) == "table" and rigs.wide or nil
    local teleFrameReviewed = type(tele) == "table"
      and (near(tele.frameH, 34.11) or near(tele.frameH, 34.11 * 3))
    if not ok or type(camera) ~= "table"
        or type(camera.rigFor) ~= "function"
        or type(camera.frameH) ~= "function"
        or type(camera.rig) ~= "function"
        or camera.DEFAULT_RIG ~= "tele"
        or not near(camera.DEFAULT_ZOOM, 1.3)
        or not near(camera.ZOOM_MIN, 0.45)
        or not near(camera.ZOOM_MAX, 2.0)
        or not finite(camera.zoom) or not finite(camera.zoomGoal)
        or camera.zoom < camera.ZOOM_MIN or camera.zoom > camera.ZOOM_MAX
        or camera.zoomGoal < camera.ZOOM_MIN
        or camera.zoomGoal > camera.ZOOM_MAX
        or type(tele) ~= "table" or type(wide) ~= "table"
        or not near(tele.side, 78.79)
        or not near(tele.back, 144.96)
        or not near(tele.height, 37.88)
        or not near(tele.lookX, -0.26)
        or not near(tele.lookY, 0.34)
        or not teleFrameReviewed
        or not near(wide.side, 41.98)
        or not near(wide.back, 41.16)
        or not near(wide.height, 28.48)
        or not near(wide.lookX, -3.24)
        or not near(wide.lookY, -1.35)
        or not near(wide.frameH, 55.62) then
      return nil, "invalid-native-camera-api:DRAMALESS_SHAPE"
    end

    local function state()
      return readonly({
        back = tele.back,
        height = tele.height,
        baseFrameH = tele.frameH,
        neutralFrameH = tele.frameH * camera.DEFAULT_ZOOM,
        currentZoom = camera.zoom,
        currentZoomGoal = camera.zoomGoal,
      })
    end
    local function apply(mode)
      if mode == "fork" then
        tele.back, tele.height, tele.frameH = 144.96, 37.88, 34.11
        return true
      end
      if mode ~= "classic" and mode ~= "wide" then return false end
      tele.back, tele.height = 144.96, 37.88
      -- Preserve the historical KASC contract literally. DRAMALESS keeps
      -- complete ownership of frameH(), zoom, steering and canonical rigs;
      -- this capability edits only the reviewed tele rig fields.
      tele.frameH = 34.11 * 3
      return true
    end
    local facade = readonly({
      schema = "ka-dramaless-2.0.2-camera-control/v1",
      rendererId = "DRAMALESS_SHAPE",
      rendererVersion = "2.0.2",
      ownsNativeHud = true,
      defaultZoom = 1.3,
      rawTargetFrameH = 34.11 * 3,
      state = state,
      apply = apply,
    })
    nativeCameraCache[exported] = facade
    return facade
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

  local function potatoFacade(id, version, exported, handle)
    local expectedRepository = R.approvedRepositories[id]
    local runtimeRepository = repositoryOf(handle, exported)
    if runtimeRepository ~= nil and runtimeRepository ~= expectedRepository then
      return nil, "unsupported-repository:" .. tostring(id)
    end

    local rawLib = exported.lib
    local cached = potatoFacadeCache[exported]
    if cached and cached.version == version then
      return cached.exported, nil, readonly({
        id = id, version = version, exports = cached.exported,
      })
    end

    local cache = {}
    for name in pairs(POTATO_MODULES) do
      local ok, value = pcall(rawLib.require, name)
      if not ok or type(value) ~= "table" then
        return nil, ("missing-module:%s:%s"):format(tostring(id), name)
      end
      cache[name] = value
    end
    local function safeRequire(name)
      if not POTATO_MODULES[name] then return nil end
      return cache[name]
    end
    local safeLib = readonly({ require = safeRequire })
    local safeExport = readonly({ version = version, lib = safeLib })
    potatoFacadeCache[exported] = {
      version = version, exported = safeExport,
    }
    return safeExport, nil, readonly({
      id = id, version = version, exports = safeExport,
    })
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
    elseif id == "potato_voxel" then
      local facade, facadeReason
      facade, facadeReason, safeHandle =
        potatoFacade(id, version, exported, handle)
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
      export = (id == "BATTLE_ART_VOXEL_FORK" or id == "potato_voxel")
        and "kasc-local-allowlist/v1" or "lib.require",
      -- Usually nil on 0.1.90: mod.find() does not expose manifest metadata.
      -- Never turn the package-policy repository pin into a fake live receipt.
      repository = repositoryOf(handle, exported),
      safeHandle = safeHandle,
    }, exported
  end

  local function choose(candidates)
    lastChoice = nil
    if #candidates == 0 then return nil, nil, "renderer-absent" end
    if #candidates > 1 then
      local ids = {}
      for _, row in ipairs(candidates) do ids[#ids + 1] = row.id end
      table.sort(ids)
      return nil, nil, "ambiguous-renderers:" .. table.concat(ids, ",")
    end
    local row = candidates[1]
    lastChoice = row
    local nativeVersions = R.nativeRendererVersions[row.id]
    local nativeProvenance = nativeVersions
      and nativeVersions[tostring(versionOf(row.handle, row.exported))]
    if nativeProvenance then
      -- Do not probe or forward `exports.lib`: DRAMALESS 2.0.2's legacy V
      -- table retains its renderer owner's mod/path/data authority. The one
      -- fixed BattleCam request lives in cameraModule() below; its built-in
      -- arena/card host and native HUD remain fully renderer-owned.
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

  -- Fixed capability adapter for the exact official DRAMALESS 2.0.2 camera.
  -- Unlike module(), this API accepts no module name and can therefore never
  -- be used as a generic path into the renderer owner's V loader. Reviewed
  -- closed-facade renderers keep using the ordinary module() path.
  function R.cameraModule(gameOrExports)
    local exported, id, reason, _, receipt = R.resolve(gameOrExports)
    if exported then return nil, id, "not-native-camera" end
    if id ~= "DRAMALESS_SHAPE"
        or reason ~= "renderer-native-owned:DRAMALESS_SHAPE" then
      return nil, id, reason
    end
    local control, cameraReason = validateDramaless202Camera(lastChoice)
    if not control then
      R.lastError = cameraReason
      R.lastReceipt = nil
      return nil, id, cameraReason
    end
    local cameraReceipt = {
      schema = "ka-voxel-renderer-capability/v1",
      rendererId = "DRAMALESS_SHAPE",
      rendererVersion = "2.0.2",
      provenance = R.nativeRendererVersions.DRAMALESS_SHAPE["2.0.2"],
      export = "fixed-battle-camera/v1",
      nativeOnly = true,
      module = "BattleCam",
      capability = "dramaless-2.0.2-battle-camera/v1",
      repository = repositoryOf(lastChoice.handle, lastChoice.exported),
    }
    R.lastError = nil
    R.lastReceipt = cameraReceipt
    return control, id, nil, cameraReceipt
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
