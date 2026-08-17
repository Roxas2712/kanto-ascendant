-- Bundled Wilds of Kanto 1.12.2 spawn runtime for Kanto Ascendant.
--
-- Only the visible-wild, ambient-town, renderer and AI surfaces are started.
-- Wilds' standalone follower controller and settings menus intentionally stay
-- disabled because Ascendant already owns those hooks and UI trees.

local JOHTO_MAP_PREFIX = "KA_JOHTO_"
local JOHTO_MAP_BLOCK_REASON = "authored Johto map"

local function mapIdOf(value)
  if type(value) == "string" then return value end
  if type(value) ~= "table" then return nil end
  return value.mapId or value.id
    or (type(value.map) == "table" and value.map.id)
end

local function isAuthoredJohtoMap(value)
  local mapId = mapIdOf(value)
  return type(mapId) == "string"
    and mapId:upper():sub(1, #JOHTO_MAP_PREFIX) == JOHTO_MAP_PREFIX
end

local function activeLogicMapId(logic, hint)
  -- Runtime events/contexts identify their map as mapId (or nested map.id).
  -- Do not treat an unrelated spawn option's generic `id` as a map id.
  local mapId = type(hint) == "string" and hint
    or (type(hint) == "table" and (hint.mapId
      or (type(hint.map) == "table" and hint.map.id)))
  if mapId then return mapId end
  local world = logic and logic.mod and logic.mod.world
  if world and type(world.overworld) == "function" then
    local ok, ow = pcall(world.overworld, world)
    if ok then
      mapId = mapIdOf(ow and ow.map)
      if mapId then return mapId end
    end
  end
  return logic and (logic._kantoAscendantExcludedMapId
    or logic.activeMapId) or nil
end

local function currentOverworld(logic)
  local world = logic and logic.mod and logic.mod.world
  if not (world and type(world.overworld) == "function") then return nil end
  local ok, ow = pcall(world.overworld, world)
  return ok and ow or nil
end

local function exclusionReason(mapId)
  return JOHTO_MAP_BLOCK_REASON .. ": " .. tostring(mapId or "unknown")
end

local function suppressLogic(logic, mapId)
  if logic._kantoAscendantExcludedMapId ~= mapId
      and type(logic.clearAll) == "function" then
    pcall(logic.clearAll, logic)
  end
  -- Leaving activeMapId on the protected map would let Wilds' late-init path
  -- rebuild the population on the next world.stepped event.
  logic.activeMapId = nil
  logic._kantoAscendantExcludedMapId = mapId
  return nil, exclusionReason(mapId)
end

-- Gate both the bundled core and the short-lived external provider used by a
-- hot-reloaded development session.  These authored Champion rooms are story
-- arenas, not encounter habitats or safe-town ambience.  Keeping the policy
-- in Ascendant's adapter avoids modifying the vendored Wilds release.
local function installAuthoredJohtoMapExclusion(exports)
  if type(exports) ~= "table" then return false end
  if exports._kantoAscendantJohtoMapExclusion then return true end

  local logic = exports.logic
  if type(logic) == "table" then
    if type(logic.onMapEntered) == "function" then
      local original = logic.onMapEntered
      logic.onMapEntered = function(self, ev)
        local mapId = activeLogicMapId(self, ev)
        if isAuthoredJohtoMap(mapId) then
          return suppressLogic(self, mapId)
        end
        self._kantoAscendantExcludedMapId = nil
        return original(self, ev)
      end
    end
    if type(logic.onStepped) == "function" then
      local original = logic.onStepped
      logic.onStepped = function(self, ev)
        local mapId = activeLogicMapId(self, ev)
        if isAuthoredJohtoMap(mapId) then
          if self._kantoAscendantExcludedMapId ~= mapId then
            suppressLogic(self, mapId)
          end
          return nil, exclusionReason(mapId)
        end

        -- A development hot import can install this bundled runtime after
        -- the engine has already emitted map.entered/save.loaded.  Wilds'
        -- original onStepped returns before its own late-init branch whenever
        -- activeMapId is still nil, leaving the current map permanently empty.
        -- Repair only an exact live-map event: a stale/foreign step must never
        -- initialize, clear or repopulate another map.
        local eventMapId = type(ev) == "table" and ev.mapId or nil
        local ow = currentOverworld(self)
        local liveMapId = mapIdOf(ow and ow.map)
        local state = self.state
        local stateMatches = type(state) == "table"
          and state.mapId == eventMapId
        if eventMapId and liveMapId == eventMapId
            and (self.activeMapId ~= eventMapId or not stateMatches)
            and type(self.onMapEntered) == "function" then
          pcall(self.onMapEntered, self, {
            mapId = eventMapId,
            map = ow.map,
            hotImportRecovery = true,
          })
        end
        return original(self, ev)
      end
    end
    if type(logic.initializeForMap) == "function" then
      local original = logic.initializeForMap
      logic.initializeForMap = function(self, mapId, game)
        if isAuthoredJohtoMap(mapId) then
          return suppressLogic(self, mapId)
        end
        return original(self, mapId, game)
      end
    end
    local function guardedSpawn(original)
      return function(self, game, spawnOpts)
        local mapId = activeLogicMapId(self, spawnOpts)
        if isAuthoredJohtoMap(mapId) then
          return nil, exclusionReason(mapId)
        end
        return original(self, game, spawnOpts)
      end
    end
    for _, method in ipairs({ "trySpawn", "trySpawnWater" }) do
      if type(logic[method]) == "function" then
        logic[method] = guardedSpawn(logic[method])
      end
    end
    if type(logic.shouldSuppressClassicEncounter) == "function" then
      local original = logic.shouldSuppressClassicEncounter
      logic.shouldSuppressClassicEncounter = function(self, ctx)
        local mapId = activeLogicMapId(self, ctx)
        if isAuthoredJohtoMap(mapId) then return true end
        return original(self, ctx)
      end
    end
    if type(logic.onCollision) == "function" then
      local original = logic.onCollision
      logic.onCollision = function(self, allowed, ctx)
        local mapId = activeLogicMapId(self, ctx)
        if isAuthoredJohtoMap(mapId) then return allowed end
        return original(self, allowed, ctx)
      end
    end
  end

  local ambient = exports.ambient
  if type(ambient) == "table" and type(ambient.spawnForMap) == "function" then
    local original = ambient.spawnForMap
    ambient.spawnForMap = function(self, game, ow)
      local mapId = mapIdOf(ow and ow.map)
        or activeLogicMapId(logic)
      if isAuthoredJohtoMap(mapId) then
        if type(self.clearAll) == "function" then self:clearAll(ow) end
        self.activeMapId = mapId
        return 0, exclusionReason(mapId)
      end
      return original(self, game, ow)
    end
  end

  exports.isMapExcluded = isAuthoredJohtoMap
  exports._kantoAscendantJohtoMapExclusion = true
  return true
end

return function(mod, opts)
  opts = opts or {}
  local voxelRenderer = opts.voxelRenderer
  local external = mod.find and mod.find("overworld_wild_spawns")
  if external and type(external.exports) == "table" then
    installAuthoredJohtoMapExclusion(external.exports)
    if opts.spawnSafety and type(opts.spawnSafety.install) == "function" then
      opts.spawnSafety.install(external.exports)
    end
    return {
      bundled = false,
      version = external.version,
      exports = external.exports,
      source = "external",
    }
  end

  local ROOT = "vendor/wilds_1_12_2"
  local proxy = {
    id = "overworld_wild_spawns",
    version = "1.12.2",
    path = mod.path .. "/" .. ROOT,
    content = mod.content,
    events = mod.events,
    hooks = mod.hooks,
    ui = mod.ui,
    input = mod.input,
    world = mod.world,
    exports = {},
    DELETE = mod.DELETE,
    speciesRuntimeIdentity = opts.extendedRuntime,
  }

  proxy.log = {
    info = function(_, fmt, ...)
      mod.log:info("[internal Wilds 1.12.2] " .. fmt, ...)
    end,
    warn = function(_, fmt, ...)
      mod.log:warn("[internal Wilds 1.12.2] " .. fmt, ...)
    end,
    error = function(_, fmt, ...)
      mod.log:error("[internal Wilds 1.12.2] " .. fmt, ...)
    end,
  }

  function proxy:read(relative)
    return mod:read(ROOT .. "/" .. relative)
  end

  proxy.assets = setmetatable({
    path = function(_, relative)
      return proxy.path .. "/" .. relative
    end,
    image = function(_, relative)
      assert(love and love.graphics,
        "internal Wilds image load needs a graphics context")
      return love.graphics.newImage(proxy.path .. "/" .. relative)
    end,
  }, { __index = mod.assets })

  proxy.find = function(first, second)
    local id = second == nil and first or second
    local hit
    -- Renderer requests are capability-owned by Ascendant's pinned resolver.
    -- Resolve them before the ordinary cross-mod path so the historical
    -- DRAMATIC_SHAPE request can reach the reviewed DRAMALESS build without
    -- ever accepting an installed, unsupported DRAMATIC_SHAPE package.
    if voxelRenderer and type(voxelRenderer.isRendererRequest) == "function"
        and voxelRenderer.isRendererRequest(id) then
      hit = voxelRenderer.findAlias(mod, id)
    elseif mod.find then
      hit = mod.find(id)
    end
    return hit
  end

  -- Keep the embedded subsystem's saved state separate from Ascendant's
  -- ordinary keys while still using the engine-provided persistence surface.
  proxy.save = {
    get = function(_, key, default)
      local bucket = mod.save:get("internal_wilds", {})
      local value = type(bucket) == "table" and bucket[key] or nil
      if value == nil then return default end
      return value
    end,
    set = function(_, key, value)
      local bucket = mod.save:get("internal_wilds", {})
      if type(bucket) ~= "table" then bucket = {} end
      bucket[key] = value
      mod.save:set("internal_wilds", bucket)
    end,
  }

  local ASCENDANT_OPTION = {
    enabled = "living_world_enabled",
    spawn_density = "living_world_density",
    random_encounters = "living_world_random_encounters",
    water_spawns = "living_world_water",
    cave_spawns = "living_world_caves",
    pokemon_grass_render_mode = "living_world_grass",
    wild_silhouettes = "living_world_silhouettes",
    enable_idle = "living_world_idle",
    enable_wander = "living_world_wander",
    enable_aggressive = "living_world_chase",
    enable_hidden = "living_world_hidden",
    town_pokemon = "living_world_towns",
  }
  local schemaDefaults = {}

  local function game()
    return proxy.world and proxy.world.game
  end

  proxy.options = {
    define = function(_, schema)
      for _, row in ipairs(schema or {}) do
        if type(row) == "table" and type(row.key) == "string" then
          schemaDefaults[row.key] = row.default
        end
      end
      return schema
    end,
    get = function(_, key)
      local ascendantKey = ASCENDANT_OPTION[key]
      if ascendantKey and mod.options and mod.options.get then
        local value = mod.options:get(ascendantKey)
        if value ~= nil then return value end
      end
      return schemaDefaults[key]
    end,
  }

  local legacyUpvalues
  if debug and debug.getupvalue and debug.setupvalue then
    -- Dormant standalone follower modules still use their historical
    -- upvalue seam on older, unsandboxed hosts. Exact 0.1.86 leaves this nil.
    legacyUpvalues = { get = debug.getupvalue, set = debug.setupvalue }
  end
  local V = { mod = proxy, path = proxy.path, upvalues = legacyUpvalues }
  function V.read(relative)
    if type(relative) ~= "string" or relative == "" then return nil end
    local prefix = proxy.path .. "/"
    if relative:sub(1, #prefix) == prefix then
      relative = relative:sub(#prefix + 1)
    end
    local ok, bytes = pcall(proxy.read, proxy, relative)
    return ok and bytes or nil
  end
  function V.exists(path)
    if V.read(path) ~= nil then return true end
    -- Cross-mod and save-derived paths are outside KA's mod:read root. The
    -- engine-owned Assets facade performs that lookup without exposing the
    -- denied love.filesystem object to sandboxed code.
    local okAssets, Assets = pcall(require, "src.render.Assets")
    if not (okAssets and Assets and type(Assets.exists) == "function") then
      return false
    end
    local ok, exists = pcall(Assets.exists, path)
    return ok and exists == true
  end
  local modules = {}
  local function chunkFor(relative)
    local source = proxy:read(relative)
    if not source then
      error(("internal Wilds 1.12.2: %s is missing"):format(relative), 0)
    end
    local loadcode = loadstring or load
    local chunk, err = loadcode(source, "@" .. proxy.path .. "/" .. relative)
    if not chunk then
      error(("internal Wilds 1.12.2: %s did not compile: %s")
        :format(relative, tostring(err)), 0)
    end
    return chunk
  end
  function V.require(name)
    if modules[name] ~= nil then return modules[name] end
    local value = chunkFor("lib/" .. name .. ".lua")(V)
    modules[name] = value
    return value
  end

  local Config = V.require("config")
  local SpawnRender = V.require("spawn_render")
  local SpawnLogic = V.require("spawn_logic")
  local BehaviorTick = V.require("behavior_tick")
  local AmbientPokemon = V.require("ambient_pokemon")
  local Diagnostics = V.require("diagnostics")
  local DebugLog = V.require("debug_log")

  Config.defineOptions(proxy)
  Config.migrateSpriteStyleOption(proxy)
  Config.migrateRandomEncountersOption(proxy)
  Config.migrateWaterDisplayMode(proxy)
  Config.migrateCaveSpawnMode(proxy)
  Config.migrateDevOverlayOption(proxy)
  Config.migrateSpriteFadeOption(proxy)
  Config.migrateSpriteColorOption(proxy)

  local render = SpawnRender.new(proxy)
  local registered, registerErr = render:registerContent()
  if not registered then
    error("internal Wilds 1.12.2 sprite registration failed: "
      .. tostring(registerErr), 0)
  end
  local logic = SpawnLogic.new(proxy, render)
  local behaviorTick = BehaviorTick.new(proxy, logic)
  logic:attachDevTools(nil, nil, nil, behaviorTick, nil)
  local ambient = AmbientPokemon.new(proxy, {
    render = render,
    logic = logic,
    follower = nil,
  })
  ambient:install()
  behaviorTick:register()

  local function safe(label, fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then
      DebugLog.error(proxy, "%s error: %s", label, tostring(err))
      if logic.state then logic.state:markError(err) end
      if logic._restoreVanillaEncounters then
        logic:_restoreVanillaEncounters(label .. " error")
      end
    end
    return ok
  end

  proxy.events:on("map.entered", function(ev)
    safe("map.entered", logic.onMapEntered, logic, ev)
    safe("ambient map.entered", ambient.onMapEntered, ambient, ev)
    render._pendingSpriteRefresh = true
  end)
  proxy.events:on("map.exited", function(ev)
    safe("map.exited", logic.onMapExited, logic, ev)
    safe("ambient map.exited", ambient.onMapExited, ambient, ev)
  end)
  proxy.events:on("map.reloaded", function(ev)
    safe("map.reloaded", logic.onMapReloaded, logic, ev)
  end)
  proxy.events:on("world.stepped", function(ev)
    safe("world.stepped", logic.onStepped, logic, ev)
    if render._pendingSpriteRefresh then
      render._pendingSpriteRefresh = false
      pcall(render.refreshAllEntitySprites, render, logic, game())
    end
  end)
  proxy.events:on("battle.ended", function()
    logic:onBattleEnded()
  end)
  proxy.events:on("save.loaded", function()
    safe("save.loaded", logic.onSaveLoaded, logic)
  end)
  proxy.events:on("save.created", function()
    logic:clearAll()
    logic.activeMapId = nil
    logic.stepsOnMap = 0
  end)
  proxy.events:on("game.ready", function()
    behaviorTick:syncPipelineLevel()
    Config.migrateSpriteStyleOption(proxy)
    Config.migrateRandomEncountersOption(proxy)
    Config.migrateWaterDisplayMode(proxy)
    Config.migrateCaveSpawnMode(proxy)
    Config.migrateDevOverlayOption(proxy)
    Config.migrateSpriteFadeOption(proxy)
    Config.migrateSpriteColorOption(proxy)
    render:finalizeSpriteProviders(game())
  end)
  proxy.events:on("mods.loaded", function()
    Config.migrateSpriteStyleOption(proxy)
    render:finalizeSpriteProviders(game())
  end)

  local unwraps = {}
  local function removeHooks()
    for key, unwrap in pairs(unwraps) do
      if type(unwrap) == "function" then unwrap() end
      unwraps[key] = nil
    end
    logic.state.vanillaSuppressed = false
  end
  local function restoreVanillaEncounters()
    logic.state.vanillaSuppressed = false
  end
  logic:setRestoreVanilla(restoreVanillaEncounters)

  local function installHooks()
    if unwraps.encounter or unwraps.collision then return end
    unwraps.encounter = proxy.hooks:wrap("encounter.roll",
      function(next, encDef, ctx)
        if logic:shouldSuppressClassicEncounter(ctx) then return nil end
        return next(encDef, ctx)
      end)
    unwraps.collision = proxy.hooks:wrap("movement.collision",
      function(next, allowed, ctx)
        local base = next(allowed, ctx)
        local ok, result = pcall(logic.onCollision, logic, base, ctx)
        if ok then return result end
        DebugLog.error(proxy, "movement.collision error: %s", tostring(result))
        logic.state:markError(result)
        logic:_restoreVanillaEncounters("collision error")
        return base
      end)
  end

  local function syncFeatureState()
    if Config.isEnabled(proxy) then
      installHooks()
      logic.state.vanillaSuppressed = false
    else
      removeHooks()
      logic:clearAll()
      ambient:onTownPokemonToggled(false, game())
    end
  end

  local function handleOptionsChanged(payload)
    safe("options_changed", logic.onOptionsChanged, logic, payload)
    safe("ambient options_changed", ambient.onOptionsChanged, ambient, payload)
    if payload and payload.mod == proxy.id and payload.key == "enabled" then
      syncFeatureState()
    end
  end
  proxy.events:on("mod.options_changed", handleOptionsChanged)
  syncFeatureState()

  local E = proxy.exports
  E.version = "1.12.2"
  E.bundledBy = mod.id
  E.logic = logic
  E.render = render
  E.animated = render.animated
  E.spriteProviders = render.spriteProviders
  E.ambient = ambient
  E.behaviorTick = behaviorTick
  E.handleOptionsChanged = handleOptionsChanged
  E.lib = V
  E.isBattleableWild = Config.isBattleableWild
  E.clearAll = function() logic:clearAll() end
  E.removeHooks = removeHooks
  E.installHooks = installHooks
  E.canSuppressVanilla = function() return logic:canSuppressVanilla() end
  E.spawnSystemState = function() return logic.state:snapshot() end
  E.hudSnapshot = function() return Diagnostics.hudSnapshot(logic) end
  E.hudLines = function() return Diagnostics.hudLines(logic) end
  E.testSpawn = function(species, opts) return logic:testSpawn(species, opts) end
  E.restoreVanillaEncounters = function(reason)
    logic:_restoreVanillaEncounters(reason or "export")
  end
  E.registerSpriteProvider = function(id, provider)
    if type(provider) ~= "table" then return false, "provider table required" end
    if type(id) == "string" and provider.id == nil then provider.id = id end
    return render.spriteProviders:register(provider)
  end
  E.unregisterSpriteProvider = function(id)
    return render.spriteProviders:unregister(id)
  end
  E.getSpriteProvider = function(id)
    return render.spriteProviders:get(id)
  end
  E.listSpriteProviders = function()
    return render.spriteProviders:list()
  end
  E.refreshAllEntitySprites = function(activeGame)
    return render:refreshAllEntitySprites(logic, activeGame or game())
  end
  E.refreshEntitySprite = function(entity, opts)
    opts = opts or {}
    opts.game = opts.game or game()
    return logic:refreshEntitySprite(entity, opts)
  end
  E.resolveWaterSprite = function(speciesId, shiny, form, opts)
    opts = opts or {}
    opts.game = opts.game or game()
    return logic:resolveWaterSprite(speciesId, shiny, form, opts)
  end
  E.setWaterDisplayMode = function(value, source, opts)
    opts = opts or {}
    opts.game = opts.game or game()
    opts.logic = opts.logic or logic
    return Config.setWaterMons(proxy, value, source or "ascendant", opts)
  end
  E.occupancy = function() return logic.occupancy end
  installAuthoredJohtoMapExclusion(E)
  if opts.spawnSafety and type(opts.spawnSafety.install) == "function" then
    opts.spawnSafety.install(E)
  end

  proxy.log:info("spawn core ready (followers/menu ownership: Ascendant)")
  return {
    bundled = true,
    version = "1.12.2",
    exports = E,
    proxy = proxy,
    source = "bundled",
  }
end
