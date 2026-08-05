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
  local data = opts.data or {}
  local spriteAssets = opts.spriteAssets
  local W = {
    game = nil, logic = nil, installed = false,
    spriteIds = {}, shinySpriteIds = {}, registeredSprites = 0,
    providerInstalled = false, wildsVersion = nil,
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

  local function wildsExport(game)
    local mods = game and game.mods
    local exports = mods and mods.exports
    return type(exports) == "table"
      and exports.overworld_wild_spawns or nil
  end

  local function integrationEnabled()
    if mod.options and type(mod.options.get) == "function" then
      return mod.options:get("johto_wilds_integration") ~= false
    end
    return true
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
      modId = "trainer_rematch",
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
          providerMod = "trainer_rematch",
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

  function W.install(game, deps)
    W.game = game
    deps = deps or {}
    local wilds = wildsExport(game)
    local logic = type(wilds) == "table" and wilds.logic or nil
    if type(logic) ~= "table" or type(logic.trySpawn) ~= "function" then
      return false, "Wilds of Kanto is not active"
    end
    W.wildsVersion = wilds.version
    installSpriteProvider(wilds, game)
    if logic._kantoAscendantHabitatWrapped then
      W.logic, W.installed = logic, true
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

    local random = deps.random
      or (love and love.math and love.math.random)
      or math.random
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
        selected = johtoResearch.rollHabitat(
          mapId, terrain, random, nil, nil)
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

  function W.runtimeStatus()
    return {
      installed = W.installed,
      enabled = integrationEnabled(),
      wildsVersion = W.wildsVersion,
      providerInstalled = W.providerInstalled,
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
      end
    end, -20)
  end

  W.terrainForSurface = terrainForSurface
  W.integrationEnabled = integrationEnabled
  return W
end
