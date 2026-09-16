-- Kanto Ascendant 6.7 compact starter-habitat tileset bridge.
--
-- Blocks/collision come from the exact reviewed Map Studio V2.1 project.  The
-- three PNGs are local checked-in assets, so 2D remains authoritative when no
-- Voxel/DRAMALESS renderer is installed.

return function(mod, opts)
  opts = opts or {}
  local Json = assert(opts.json,
    "starter habitat tilesets require the local JSON decoder")
  local T = {
    SOURCE_PROJECT_SHA256 =
      "322e29447f7481a12d71b14fd50cfebf8d5b2220b3c2622f62339ad79b576e31",
    ids = {
      generator_g2_johto = "KA_HABITAT_G2_JOHTO",
      stone = "KA_HABITAT_STONE",
      mystic = "KA_HABITAT_MYSTIC",
    },
    -- OverworldController accepts the normal shore+A SURF interaction only
    -- when the active tileset is also present in field.waterTilesets.  The
    -- per-tileset waterTiles table alone is not sufficient for that gate.
    -- Register all three private Habitat tilesets through the mod content API
    -- so the Loader attributes this additive patch to Kanto Ascendant and
    -- drops it automatically when the mod is rolled back or disabled at boot.
    waterTilesetIds = {
      "KA_HABITAT_G2_JOHTO",
      "KA_HABITAT_STONE",
      "KA_HABITAT_MYSTIC",
    },
    registered = false,
  }

  local cached
  local function data()
    if not cached then
      cached = Json.read(mod, "assets/starter_habitats/tilesets-v2.1.json")
      assert(cached.sourceProjectSha256 == T.SOURCE_PROJECT_SHA256,
        "starter habitat tileset source hash mismatch")
    end
    return cached
  end

  local function copy(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local out = {}
    seen[value] = out
    for key, child in pairs(value) do out[copy(key, seen)] = copy(child, seen) end
    return out
  end

  local ASSET = {
    generator_g2_johto = {
      file = "g2_johto.png", width = 128, height = 96,
      grassTiles = { 4 }, generation = 2,
    },
    stone = {
      file = "sector_stone.png", width = 512, height = 160,
      grassTiles = {}, generation = 1,
    },
    mystic = {
      file = "sector_mystic.png", width = 512, height = 160,
      grassTiles = {}, generation = 1,
    },
  }

  function T.definition(theme)
    local source = data().tilesets[theme]
    local asset = ASSET[theme]
    local id = T.ids[theme]
    if not (source and asset and id) then return nil end
    return {
      id = id,
      image = mod.path .. "/assets/starter_habitats/" .. asset.file,
      imageWidth = asset.width,
      imageHeight = asset.height,
      tilesPerRow = assert(source.tilesPerRow),
      trueColor = true,
      blocks = copy(source.blocks),
      walkable = copy(source.walkable or {}),
      waterTiles = copy(source.waterTiles or {}),
      grassTiles = copy(asset.grassTiles),
      warpTiles = copy(source.warpTiles or {}),
      sourceCellCollision = copy(source.cellCollision or {}),
      generation = asset.generation,
      voxelMode = "MAP_STUDIO",
      voxelSemanticProfile = {
        sourceProjectSha256 = T.SOURCE_PROJECT_SHA256,
        sourceTheme = theme,
        authority = "2D_BLOCKS",
        collision = source.cellCollision and "map-studio-cell-collision"
          or "source-walkable-tiles",
      },
    }
  end

  function T.register()
    if T.registered then return false, "already-registered" end
    assert(mod.content and mod.content.tilesets,
      "starter habitat tileset registry unavailable")
    assert(mod.content.field and type(mod.content.field.patch) == "function",
      "starter habitat field registry unavailable")
    for _, theme in ipairs({ "generator_g2_johto", "stone", "mystic" }) do
      local id = T.ids[theme]
      local existing = mod.content.tilesets:get(id)
      if not existing then mod.content.tilesets:register(id, T.definition(theme)) end
    end
    mod.content.field:patch("waterTilesets", copy(T.waterTilesetIds))
    T.registered = true
    return true
  end

  function T.catalog()
    local out = {}
    for _, theme in ipairs({ "generator_g2_johto", "stone", "mystic" }) do
      out[#out + 1] = T.definition(theme)
    end
    return out
  end

  T.copy = copy
  T.register()
  return T
end
