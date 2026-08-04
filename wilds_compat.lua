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
  local crystalNames = opts.crystalNames or {}
  local W = {
    game = nil, logic = nil, installed = false,
    spriteIds = {}, registeredSprites = 0,
  }

  -- Content registries are still open while Ascendant's entry chunk runs,
  -- but Wilds has already finished its own 151-species registration. Reserve
  -- stable companion IDs now; install() links them into Wilds' exported
  -- renderer after all merged species data is available.
  if opts.contentEnabled ~= false and mod.content
      and mod.content.sprites then
    for _, species in ipairs(data.order or {}) do
      local name = crystalNames[species]
      local relative = name and ("assets/crystal/" .. name .. "_front.png")
      if relative and mod:read(relative) ~= nil then
        local id = "KANTO_ASCENDANT_WILDS_" .. species
        mod.content.sprites:register(id, {
          id = id,
          image = mod.path .. "/" .. relative,
          frames = 1,
          trueColor = true,
        })
        W.spriteIds[species] = id
        W.registeredSprites = W.registeredSprites + 1
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

  function W.install(game, deps)
    W.game = game
    deps = deps or {}
    local wilds = wildsExport(game)
    local logic = type(wilds) == "table" and wilds.logic or nil
    if type(logic) ~= "table" or type(logic.trySpawn) ~= "function" then
      return false, "Wilds of Kanto is not active"
    end
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
      if not incoming.species and not incoming.testSpawn
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
        "Wilds of Kanto compatibility active: %d Johto sprites, researched habitats visible",
        W.registeredSprites)
    end
    return true
  end

  W.terrainForSurface = terrainForSurface
  return W
end
