-- Compatibility with Wilds of Kanto / overworld_wild_spawns.
--
-- Wilds selects directly from the merged map encounter table so it never
-- reaches Ascendant's encounter.roll habitat replacement. Wrap only its
-- exported spawn instance and feed researched Johto specimens through the
-- same rare-habitat selector used by ordinary encounters.

return function(mod, opts)
  opts = opts or {}
  local johtoResearch = assert(opts.johtoResearch,
    "Wilds compatibility needs Johto research")
  local johtoSignals = opts.johtoSignals or opts.earlyJohto or {
    allowedSpeciesPool = function() return {} end,
  }
  local data = opts.data or {}
  local spriteAssets = opts.spriteAssets
  local extendedRuntime = opts.extendedRuntime
  local voxelRenderer = opts.voxelRenderer
  local encounterLevels = opts.encounterLevels
    or johtoResearch.encounterLevels or {
      routeAverage = function() return nil end,
    }
  local W = {
    game = nil, logic = nil, installed = false,
    spriteIds = {}, shinySpriteIds = {}, registeredSprites = 0,
    providerInstalled = false, wildsVersion = nil,
    voxelAliasInstalled = false, waterWrapped = false,
    ambient = nil, townDensityWrapped = false, townSpeciesWrapped = false,
    townCriesInstalled = false, townCryNames = 0,
    sourceDexIdentityInstalled = false,
  }

  local dexToSpecies = {}
  for species, definition in pairs(data.species or {}) do
    local dex = definition and tonumber(definition.dex)
    if dex then dexToSpecies[dex] = species end
  end

  local function runtimeRelative(species, shiny)
    return "assets/followers_runtime/"
      .. (shiny and "shiny/" or "normal/")
      .. "follower_" .. tostring(species) .. ".png"
  end

  -- Reserve renderer-ready 16x96 walker sheets while content registries are
  -- still open. Older releases registered Crystal battle fronts here, which
  -- made visible Johto Pokémon look like large static battle portraits.
  if opts.contentEnabled ~= false and mod.content
      and mod.content.sprites then
    for _, species in ipairs(data.order or {}) do
      local relative = runtimeRelative(species, false)
      local shinyRelative = runtimeRelative(species, true)
      if mod:read(relative) ~= nil then
        local id = "KANTO_ASCENDANT_WILDS_" .. species
        mod.content.sprites:register(id, {
          id = id,
          image = mod.path .. "/" .. relative,
          frames = 6,
          walker = true,
          trueColor = true,
        })
        W.spriteIds[species] = id
        W.registeredSprites = W.registeredSprites + 1
      end
      if mod:read(shinyRelative) ~= nil then
        local id = "KANTO_ASCENDANT_WILDS_SHINY_" .. species
        mod.content.sprites:register(id, {
          id = id,
          image = mod.path .. "/" .. shinyRelative,
          frames = 6,
          walker = true,
          trueColor = true,
        })
        W.shinySpriteIds[species] = id
      end
    end
  end

  local TERRAIN_FOR_SURFACE = {
    GRASS = "grass",
    CAVE = "indoor",
    INTERIOR = "indoor",
    WATER = "water",
  }

  local function terrainForSurface(surface)
    return TERRAIN_FOR_SURFACE[tostring(surface or ""):upper()]
  end

  local function overworldFor(logic)
    local world = logic and logic.mod and logic.mod.world
    return world and world.overworld and world:overworld() or nil
  end

  local function initializeCurrentMap(logic, game, source)
    if type(logic) ~= "table"
        or type(logic.onMapEntered) ~= "function" then
      return false, "Wilds map-enter API unavailable"
    end
    local okWorld, ow = pcall(overworldFor, logic)
    local mapId = okWorld and ow and ow.map and ow.map.id or nil
    if not mapId then return false, "overworld map unavailable" end

    -- This runs both on the first compatibility install and on a later hot
    -- reload.  Do not replay map entry when Wilds already owns coherent state:
    -- replaying would clear and duplicate the live population.
    local state = logic.state
    if logic.activeMapId == mapId and type(state) == "table"
        and state.mapId == mapId then
      return false, "already initialized"
    end

    local ok, result = pcall(logic.onMapEntered, logic, {
      mapId = mapId,
      map = ow.map,
      game = game,
      hotImportRecovery = true,
    })
    if not ok then
      if mod.log and type(mod.log.warn) == "function" then
        mod.log:warn("Wilds current-map initialization failed (%s): %s",
          tostring(source or "install"), tostring(result))
      end
      return false, result
    end
    return true, result
  end

  local function wildsExport(game)
    local ok, handle = false, nil
    if mod and type(mod.find) == "function" then
      ok, handle = pcall(function() return mod.find("overworld_wild_spawns") end)
    end
    local public = ok and type(handle) == "table" and handle.exports or nil
    if public then return public end
    local internal = mod.exports and mod.exports.internalWilds
    return type(internal) == "table" and internal.exports or nil
  end

  local function installSourceDexIdentity(wilds, game)
    if not (extendedRuntime and wilds and wilds.lib
        and type(wilds.lib.require) == "function") then return false end
    local ok, animated = pcall(wilds.lib.require, "animated_sprites")
    if not (ok and type(animated) == "table"
        and type(animated.resolveSpeciesId) == "function") then
      return false
    end
    if animated.supportsSourceDex == true then
      W.sourceDexIdentityInstalled = true
      return true
    end
    if not animated._kantoAscendantSourceDexOriginal then
      local original = animated.resolveSpeciesId
      animated.resolveSpeciesId = function(speciesKey, activeGame, wildsMod)
        -- A numeric id is already an explicitly resolved National Dex and
        -- remains literal. Species keys cross Ascendant's private-slot
        -- boundary here and resolve through sourceDex instead.
        if type(speciesKey) == "string" and not tonumber(speciesKey) then
          local source = extendedRuntime.sourceDex(
            speciesKey, activeGame and activeGame.data or game and game.data)
          if source then return source end
        end
        return original(speciesKey, activeGame, wildsMod)
      end
      animated._kantoAscendantSourceDexOriginal = original
      animated.supportsSourceDex = true
    end
    W.sourceDexIdentityInstalled = true
    return true
  end

  local function integrationEnabled()
    if mod.options and type(mod.options.get) == "function" then
      return mod.options:get("johto_wilds_integration") ~= false
    end
    return true
  end

  -- Ascendant presents the supported Wilds surface as LIVING REGIONS.  Keep
  -- the external module's stable option keys behind this adapter so players
  -- do not need to hunt through a second mod page, while Wilds still owns
  -- placement, movement and battle startup.
  local LIVING_WORLD_OPTIONS = {
    living_world_enabled = { key = "enabled" },
    living_world_density = { key = "spawn_density" },
    living_world_random_encounters = { key = "random_encounters" },
    living_world_water = { key = "water_spawns", choiceSince = "1.12.0" },
    living_world_caves = { key = "cave_spawns", since = "1.12.0" },
    living_world_grass = { key = "pokemon_grass_render_mode" },
    living_world_silhouettes = {
      key = "wild_silhouettes", since = "1.12.0",
    },
    living_world_idle = { key = "enable_idle" },
    living_world_wander = { key = "enable_wander" },
    living_world_chase = { key = "enable_aggressive" },
    living_world_hidden = { key = "enable_hidden" },
    living_world_towns = { key = "town_pokemon", since = "1.12.0" },
  }

  local function versionAtLeast(current, wanted)
    local function parts(value)
      local a, b, c = tostring(value or ""):match("^(%d+)%.(%d+)%.(%d+)")
      return tonumber(a) or 0, tonumber(b) or 0, tonumber(c) or 0
    end
    local a, b, c = parts(current)
    local x, y, z = parts(wanted)
    if a ~= x then return a > x end
    if b ~= y then return b > y end
    return c >= z
  end

  local function syncLivingWorldOption(game, ascendantKey)
    if not (mod.options and type(mod.options.get) == "function") then
      return false
    end
    local spec = LIVING_WORLD_OPTIONS[ascendantKey]
    if spec and spec.since
        and not versionAtLeast(W.wildsVersion, spec.since) then return false end
    local externalKey = spec and spec.key
    if not (externalKey and game) then return false end
    local value = mod.options:get(ascendantKey)
    if ascendantKey == "living_world_water"
        and spec.choiceSince
        and not versionAtLeast(W.wildsVersion, spec.choiceSince) then
      -- Wilds 1.7.1 used a boolean water switch. Preserve that contract while
      -- 1.12.x receives the full five-choice presentation value.
      value = value ~= "disabled" and value ~= "classic_encounters"
    end
    local wilds = wildsExport(game)
    local lib = type(wilds) == "table" and wilds.lib or nil
    local okConfig, Config = false, nil
    if type(lib) == "table" and type(lib.require) == "function" then
      okConfig, Config = pcall(lib.require, "config")
    end
    -- Cross-mod writes are owned by Wilds itself.  Kanto Ascendant may call
    -- its exported Config seam, but never reaches into another loader bucket
    -- or forges its options_changed event.
    if okConfig and type(Config) == "table"
        and type(Config.setOption) == "function" and type(lib.mod) == "table" then
      local okSet, changed = pcall(Config.setOption, lib.mod, externalKey,
        value, mod.id, { game = game })
      return okSet and changed == true
    end
    if type(wilds) == "table" and type(wilds.setOption) == "function" then
      local okSet, changed = pcall(wilds.setOption, externalKey, value, {
        game = game, source = mod.id,
      })
      return okSet and changed == true
    end
    return false
  end

  local function syncLivingWorldOptions(game)
    local changed = 0
    for ascendantKey in pairs(LIVING_WORLD_OPTIONS) do
      if syncLivingWorldOption(game, ascendantKey) then changed = changed + 1 end
    end
    return changed
  end

  local function townPokemonAmount()
    if not (mod.options and type(mod.options.get) == "function") then
      return nil
    end
    local value = mod.options:get("wilds_town_pokemon_amount")
    if value == nil or value == "auto" then return nil end
    value = tonumber(value)
    if not value then return nil end
    return math.max(0, math.min(5, math.floor(value)))
  end

  local function townPokemonSpecies()
    if not (mod.options and type(mod.options.get) == "function") then
      return "mixed"
    end
    local value = tostring(
      mod.options:get("wilds_town_pokemon_species") or "mixed"):lower()
    if value == "kanto" or value == "johto" then return value end
    return "mixed"
  end

  local TOWN_JOHTO_BLOCK = {
    RAIKOU = true, ENTEI = true, SUICUNE = true,
    LUGIA = true, HO_OH = true, HOHO = true, CELEBI = true,
  }

  local function townJohtoPool()
    local out, seen = {}, {}
    local hasHabitats = type(data.habitats) == "table"
    local allowed = type(johtoSignals.allowedSpeciesPool) == "function"
      and johtoSignals.allowedSpeciesPool(nil, false) or {}
    for _, species in ipairs(allowed) do
      local habitat = hasHabitats and data.habitats[species] or nil
      -- Authored habitat bases are the stable, city-safe subset.  Families
      -- that only exist as evolutions and the finale Larvitar path do not
      -- appear as unexplained decorative spoilers in early cities.
      local eligible = not hasHabitats or (habitat
        and habitat.unlock ~= "final")
      if eligible and not TOWN_JOHTO_BLOCK[species] and not seen[species] then
        seen[species] = true
        out[#out + 1] = species
      end
    end
    return out
  end

  local function speciesKey(speciesId)
    if type(speciesId) == "string" and speciesId ~= "" then
      return speciesId
    end
    return dexToSpecies[tonumber(speciesId)]
  end

  local function copyDef(def)
    if type(def) ~= "table" or type(def.image) ~= "string" then return nil end
    return {
      id = def.id,
      image = def.image,
      frames = tonumber(def.frames) or 6,
      walker = def.walker ~= false,
      trueColor = def.trueColor ~= false,
    }
  end

  local function installSpriteProvider(wilds, game)
    local register = wilds and wilds.registerSpriteProvider
    if type(register) ~= "function" then
      return false, "Wilds sprite-provider API unavailable"
    end
    local original
    if type(wilds.getSpriteProvider) == "function" then
      original = wilds.getSpriteProvider("followers_ex")
    elseif wilds.render and wilds.render.spriteProviders
        and type(wilds.render.spriteProviders.get) == "function" then
      original = wilds.render.spriteProviders:get("followers_ex")
    end

    local provider = {
      id = "followers_ex",
      modId = mod.id,
    }
    function provider:isAvailable(activeGame)
      if W.registeredSprites > 0 then
        return true, "Kanto Ascendant Johto walker sheets"
      end
      if original and type(original.isAvailable) == "function" then
        return original:isAvailable(activeGame)
      end
      return false, "no follower sheets"
    end
    function provider:resolve(speciesId, variant, activeGame)
      local species = speciesKey(speciesId)
      local shiny = tostring(variant or ""):lower() == "shiny"
        or variant == true
      local id = species and (shiny and W.shinySpriteIds[species]
        or W.spriteIds[species])
      if not id and species then id = W.spriteIds[species] end
      local def = id and activeGame and activeGame.data
        and activeGame.data.sprites and activeGame.data.sprites[id]
      def = copyDef(def)
      if not def and species and data.species and data.species[species]
          and spriteAssets
          and type(spriteAssets.follower) == "function" then
        local path = spriteAssets.follower(species, shiny)
          or spriteAssets.follower(species, false)
        if path then
          def = {
            id = id or ("KANTO_ASCENDANT_WILDS_" .. species),
            image = path,
            frames = 6,
            walker = true,
            trueColor = true,
          }
        end
      end
      if def then
        return def, {
          providerId = "followers_ex",
          providerMod = mod.id,
          usedVariant = shiny and W.shinySpriteIds[species]
            and "shiny" or "normal",
          loadPath = def.image,
          frames = 6,
          walker = true,
          bodyRenderer = "NATIVE_SPRITE_RENDERER",
          kind = "kanto_ascendant_johto",
        }, nil
      end
      if original and type(original.resolve) == "function" then
        return original:resolve(speciesId, variant, activeGame)
      end
      return nil, nil, "no compatible follower sheet"
    end

    local ok, reason = register("followers_ex", provider)
    W.providerInstalled = ok == true
    if ok and type(wilds.refreshAllEntitySprites) == "function" then
      pcall(wilds.refreshAllEntitySprites, game)
    end
    return ok, reason
  end

  local function installDramalessAlias(logic)
    local wildsMod = logic and logic.mod
    if not (wildsMod and type(wildsMod.find) == "function") then
      return false
    end
    if wildsMod._kantoAscendantDramalessFind then
      W.voxelAliasInstalled = true
      return true
    end
    local originalFind = wildsMod.find
    wildsMod.find = function(first, second)
      local id = second == nil and first or second
      local found = originalFind(first, second)
      if found or not (voxelRenderer
          and voxelRenderer.isRendererId(id)) then return found end
      return voxelRenderer.findAlias(mod, id)
    end
    wildsMod._kantoAscendantDramalessFind = originalFind
    W.voxelAliasInstalled = true
    if logic.voxel and type(logic.voxel.refreshPresence) == "function" then
      pcall(logic.voxel.refreshPresence, logic.voxel)
    end
    return true
  end

  local function installTownControls(wilds)
    local ambient = wilds and wilds.ambient
    if type(ambient) ~= "table" then return false end
    W.ambient = ambient
    local mt = getmetatable(ambient)
    local class = mt and mt.__index
    if type(class) ~= "table" or type(class.targetCount) ~= "function"
        or type(class.speciesPool) ~= "function" then
      return false
    end
    if class._kantoAscendantTownDensity
        and class._kantoAscendantTownSpecies then
      W.townDensityWrapped = true
      W.townSpeciesWrapped = true
      return true
    end
    if not class._kantoAscendantTownDensity then
      local originalTargetCount = class.targetCount
      class.targetCount = function(game, mapId, map)
        local configured = townPokemonAmount()
        if configured ~= nil then return configured end
        return originalTargetCount(game, mapId, map)
      end
      class._kantoAscendantTownDensity = originalTargetCount
    end
    if not class._kantoAscendantTownSpecies then
      local originalSpeciesPool = class.speciesPool
      class.speciesPool = function(game, mapId, map)
        local mode = townPokemonSpecies()
        local kanto = originalSpeciesPool(game, mapId, map) or {}
        if mode == "kanto" then return kanto end
        local johto = townJohtoPool()
        if mode == "johto" then
          return #johto > 0 and johto or kanto
        end
        local mixed, seen = {}, {}
        local function append(pool)
          for _, species in ipairs(pool) do
            if not seen[species] then
              seen[species] = true
              mixed[#mixed + 1] = species
            end
          end
        end
        append(kanto)
        append(johto)
        return mixed
      end
      class._kantoAscendantTownSpecies = originalSpeciesPool
    end
    W.townDensityWrapped = true
    W.townSpeciesWrapped = true
    return true
  end

  local function installTownCryNames(wilds, game)
    if not (wilds and wilds.lib and type(wilds.lib.require) == "function") then
      return false
    end
    local ok, cries = pcall(wilds.lib.require, "ambient_cries")
    if not ok or type(cries) ~= "table"
        or type(cries.CURATED) ~= "table" then return false end
    local pokemon = game and game.data and game.data.pokemon
    if type(pokemon) ~= "table" then return false end
    local count = 0
    for species, def in pairs(pokemon) do
      local name = type(def) == "table" and def.name
      if type(species) == "string" and type(name) == "string"
          and name ~= "" then
        -- Wilds already plays the real species cry before opening its text
        -- box.  Supply the localized display name as the written cry instead
        -- of the generic [...] fallback; German packs and Ascendant's Johto
        -- localization have already updated game.data at this point.
        cries.CURATED[species] = name .. "!"
        count = count + 1
      end
    end
    W.townCriesInstalled = count > 0
    W.townCryNames = count
    return W.townCriesInstalled
  end

  function W.install(game, deps)
    W.game = game
    deps = deps or {}
    local wilds = wildsExport(game)
    local logic = type(wilds) == "table" and wilds.logic or nil
    if type(logic) ~= "table" or type(logic.trySpawn) ~= "function" then
      return false, "Wilds of Kanto is not active"
    end
    W.wildsVersion = wilds.version
    syncLivingWorldOptions(game)
    installSourceDexIdentity(wilds, game)
    installDramalessAlias(logic)
    installSpriteProvider(wilds, game)
    installTownControls(wilds)
    installTownCryNames(wilds, game)
    local random = deps.random
      or (love and love.math and love.math.random)
      or math.random

    -- Wilds 1.12.x owns water encounters through a separate synchronous
    -- trySpawnWater path.  Its public options do not accept a species override,
    -- so the land wrapper alone could never surface researched Johto swimmers.
    -- Intercept only the one zone pick made during this call, then restore the
    -- Wilds library immediately; all placement, spacing and water behaviour
    -- remain owned by Wilds itself.
    if type(logic.trySpawnWater) == "function"
        and not logic._kantoAscendantWaterWrapped
        and wilds.lib and type(wilds.lib.require) == "function" then
      local okWater, waterSpawn = pcall(wilds.lib.require, "water_spawn")
      if okWater and type(waterSpawn) == "table"
          and type(waterSpawn.pickForZone) == "function" then
        local originalTrySpawnWater = logic.trySpawnWater
        logic.trySpawnWater = function(self, spawnGame, spawnOpts)
          local incoming = spawnOpts or {}
          local selected
          local explicit = speciesKey(incoming.species)
          if explicit and data.species and data.species[explicit] then
            selected = {
              species = explicit,
              level = tonumber(incoming.level) or 1,
            }
          elseif integrationEnabled()
              and not incoming.testSpawn and not incoming.readinessProbe then
            local ow = overworldFor(self)
            local mapId = ow and ow.map and ow.map.id or self.activeMapId
            local encDef = spawnGame and spawnGame.data
              and spawnGame.data.encounters
              and spawnGame.data.encounters[mapId]
            selected = johtoResearch.rollHabitat(
              mapId, "water", random, nil, nil,
              encounterLevels.routeAverage(encDef, "water"))
          end
          if not selected then
            return originalTrySpawnWater(self, spawnGame, incoming)
          end

          local originalPick = waterSpawn.pickForZone
          waterSpawn.pickForZone = function(_, zone)
            return {
              species = selected.species,
              speciesId = selected.species,
              level = selected.level,
              levelMin = selected.level,
              levelMax = selected.level,
              source = "ascendant_habitat",
              rodTier = waterSpawn.ROD_TIER
                and waterSpawn.ROD_TIER.SURF or 0,
              zone = zone,
              spawnRule = "ANY_WEIGHTED",
              encounterSource = "ASCENDANT_HABITAT",
            }
          end
          local ok, record, err, entity = pcall(
            originalTrySpawnWater, self, spawnGame, incoming)
          waterSpawn.pickForZone = originalPick
          if not ok then error(record, 0) end
          return record, err, entity
        end
        logic._kantoAscendantWaterWrapped = true
        logic._kantoAscendantOriginalTrySpawnWater = originalTrySpawnWater
        W.waterWrapped = true
      end
    elseif logic._kantoAscendantWaterWrapped then
      W.waterWrapped = true
    end
    if logic._kantoAscendantHabitatWrapped then
      W.logic, W.installed = logic, true
      initializeCurrentMap(logic, game, "existing compatibility wrapper")
      return true
    end

    local render = type(wilds.render) == "table" and wilds.render
      or logic.render
    if type(render) == "table" then
      render.speciesSpriteIds = render.speciesSpriteIds or {}
      render.registrationInfo = render.registrationInfo or {}
      for species, id in pairs(W.spriteIds) do
        local sprite = game.data and game.data.sprites
          and game.data.sprites[id]
        if sprite then
          render.speciesSpriteIds[species] = id
          render.registrationInfo[species] = {
            status = "REGISTERED_COMPANION",
            image = sprite.image,
            source = sprite.image,
            kind = "native_runtime_sheet",
            frames = 6,
            walker = true,
          }
          if type(render.invalidateAssetCache) == "function" then
            pcall(render.invalidateAssetCache, render, species)
          end
        end
      end
    end

    local originalTrySpawn = logic.trySpawn
    logic.trySpawn = function(self, spawnGame, spawnOpts)
      local selected
      local incoming = spawnOpts or {}
      if integrationEnabled()
          and not incoming.species and not incoming.testSpawn
          and not incoming.readinessProbe then
        local ow = overworldFor(self)
        local mapId = ow and ow.map and ow.map.id or self.activeMapId
        local surface = self.surfaceInfo and self.surfaceInfo.surface
        local terrain = terrainForSurface(surface)
        local encounterKind = terrain == "water" and "water" or "grass"
        local encDef = spawnGame and spawnGame.data
          and spawnGame.data.encounters
          and spawnGame.data.encounters[mapId]
        local routeAverageLevel =
          encounterLevels.routeAverage(encDef, encounterKind)
        selected = johtoResearch.rollHabitat(
          mapId, terrain, random, nil, nil, routeAverageLevel)
      end

      if selected then
        local augmented = {}
        for key, value in pairs(incoming) do augmented[key] = value end
        augmented.species = selected.species
        augmented.level = selected.level
        if self.render
            and type(self.render.invalidateAssetCache) == "function" then
          pcall(self.render.invalidateAssetCache,
            self.render, selected.species)
        end
        return originalTrySpawn(self, spawnGame, augmented)
      end
      return originalTrySpawn(self, spawnGame, incoming)
    end

    logic._kantoAscendantHabitatWrapped = true
    logic._kantoAscendantOriginalTrySpawn = originalTrySpawn
    W.logic, W.installed = logic, true
    initializeCurrentMap(logic, game, "compatibility install")
    if mod.log and mod.log.info then
      mod.log:info(
        "Wilds of Kanto %s compatibility active: %d Johto walker sheets, researched habitats visible=%s",
        tostring(W.wildsVersion or "?"), W.registeredSprites,
        tostring(integrationEnabled()))
    end
    return true
  end

  function W.refreshVisible(reason)
    if not W.logic then return false, "Wilds of Kanto is not active" end
    if type(W.logic.clearAll) == "function" then
      W.logic:clearAll()
      if mod.log and type(mod.log.info) == "function" then
        mod.log:info("Wilds visible encounters refreshed (%s)",
          tostring(reason or "Ascendant state changed"))
      end
      return true
    end
    return false, "Wilds clearAll API unavailable"
  end

  function W.refreshTownPokemon(reason)
    local ambient = W.ambient
    local ow = overworldFor(W.logic)
    if not (ambient and ow) then
      return false, "Wilds town Pokemon are not active"
    end
    if type(ambient.clearAll) == "function" then
      ambient:clearAll(ow)
    end
    ambient.activeMapId = nil
    if type(ambient.spawnForMap) == "function" then
      ambient:spawnForMap(W.game, ow)
    end
    if mod.log and type(mod.log.info) == "function" then
      mod.log:info("Wilds town Pokemon refreshed: amount=%s region=%s (%s)",
        tostring(townPokemonAmount() or "auto"),
        tostring(townPokemonSpecies()),
        tostring(reason or "Ascendant option changed"))
    end
    return true
  end

  function W.runtimeStatus()
    return {
      installed = W.installed,
      enabled = integrationEnabled(),
      wildsVersion = W.wildsVersion,
      providerInstalled = W.providerInstalled,
      voxelAliasInstalled = W.voxelAliasInstalled,
      waterWrapped = W.waterWrapped,
      townDensityWrapped = W.townDensityWrapped,
      townSpeciesWrapped = W.townSpeciesWrapped,
      townPokemonAmount = townPokemonAmount() or "auto",
      townPokemonSpecies = townPokemonSpecies(),
      townCriesInstalled = W.townCriesInstalled,
      townCryNames = W.townCryNames,
      registeredSprites = W.registeredSprites,
    }
  end

  if mod.events and type(mod.events.on) == "function" then
    mod.events:on("mod.options_changed", function(ev)
      local refreshKeys = {
        johto_wilds_integration = true,
        johto_signals_enable = true,
        mythic_signals_enable = true,
      }
      if ev and ev.mod == mod.id and refreshKeys[ev.key] then
        W.refreshVisible(tostring(ev.key) .. " option changed")
      elseif ev and ev.mod == mod.id
          and (ev.key == "wilds_town_pokemon_amount"
            or ev.key == "wilds_town_pokemon_species") then
        W.refreshTownPokemon("town population option changed")
      elseif ev and ev.mod == mod.id and LIVING_WORLD_OPTIONS[ev.key] then
        syncLivingWorldOption(W.game, ev.key)
      end
    end, -20)
    mod.events:on("mod.kanto_ascendant.johto_migration_changed", function(ev)
      W.refreshVisible(ev and ev.reason or "Driftglass state changed")
      W.refreshTownPokemon(ev and ev.reason or "Driftglass state changed")
    end, -20)
  end

  W.terrainForSurface = terrainForSurface
  W.integrationEnabled = integrationEnabled
  W.syncLivingWorldOptions = syncLivingWorldOptions
  W.townPokemonAmount = townPokemonAmount
  W.townPokemonSpecies = townPokemonSpecies
  W.townJohtoPool = townJohtoPool
  return W
end
