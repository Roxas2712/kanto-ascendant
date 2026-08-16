-- Crystal tileset bridge for the Hidden Evolution campaign.
-- Source: pret/pokecrystal (via the checked-in Hidden-Evolution Map Editor
-- catalog).  The authored block/collision meaning remains intact; this module
-- deliberately does not touch the retired 1902--1913 prototype package.
return function(mod)
  local derivedAsset = "assets/" .. "generated/hidden_evolution/"
  local function decodeBlocks(encoded)
    local chunk, err = loadstring("return " .. encoded, "@hevo_tileset_blocks")
    assert(chunk, err)
    return chunk()
  end
  local function register(id, image, blocks, walkable, water, animation, collision, profile)
    local decodedBlocks = decodeBlocks(blocks)
    local decodedCollision = decodeBlocks(collision)
    local record = {
      id=id, image=mod.path .. image, imageWidth=128, imageHeight=96,
      tilesPerRow=16, trueColor=true, blocks=decodedBlocks,
      walkable=walkable, waterTiles=water, grassTiles={}, warpTiles={},
      animation=animation, voxelMode="MAP_STUDIO",
      voxelSemanticProfile=profile,
    }
    -- Retain the catalog's per-cell collision vocabulary and palette in the
    -- shipped record. The engine consumes walkable/water for movement; these
    -- source fields keep the finer Crystal semantics available to Map Studio
    -- and future ice/forest interaction handlers without reverse-engineering.
    record.sourceCellCollision=decodedCollision
    record.sourcePalette={}; for i=0,63 do record.sourcePalette[#record.sourcePalette+1]=i end
    mod.content.tilesets:register(id, record)
    return record
  end

  register("KA_HEVO_G2_ICE_PATH", "/assets/hidden_evolution/tilesets/ice_path.png",
    [=[{{16,16,16,16,16,16,16,16,16,16,16,16,16,16,16,16},{16,16,16,16,16,16,16,16,16,16,16,16,16,16,16,16},{154,25,154,154,25,154,25,25,154,25,25,25,170,25,25,154},{154,154,25,25,154,25,25,154,25,25,10,11,154,25,26,27},{136,137,138,139,152,153,154,154,168,169,154,155,168,169,154,154},{138,139,138,139,154,154,154,154,154,155,154,154,170,170,155,154},{138,139,140,141,154,154,156,157,154,154,172,173,154,154,172,173},{154,171,155,170,25,25,25,155,25,25,42,43,154,25,58,59},{168,169,154,155,168,169,154,154,168,169,154,154,168,169,154,155},{170,170,170,154,170,25,25,154,170,25,25,155,154,170,154,25},{154,154,172,173,154,154,172,173,155,154,172,173,154,154,172,173},{192,193,194,195,208,209,210,211,192,193,194,195,208,209,210,211},{168,169,154,155,168,169,154,154,184,185,186,186,200,201,202,202},{154,154,154,154,154,154,154,154,186,187,186,186,202,203,202,202},{155,154,172,173,154,154,172,173,186,187,188,189,202,203,204,205},{9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9},{154,154,154,154,154,154,155,18,154,155,160,161,154,18,176,177},{154,154,154,154,155,170,154,154,162,163,170,154,178,179,170,154},{18,155,170,18,155,171,155,155,128,129,174,175,144,145,190,191},{154,155,18,170,155,18,170,155,196,197,4,5,212,213,20,21},{192,193,194,195,208,209,210,211,196,197,155,25,212,213,170,25},{196,197,196,197,212,213,212,213,25,25,154,154,25,170,25,25},{196,197,196,197,212,213,212,213,25,154,196,197,25,25,212,213},{25,154,154,170,170,25,154,170,142,143,25,154,158,159,25,25},{196,197,25,154,212,213,25,25,196,197,25,25,212,213,170,25},{132,133,134,135,148,149,150,151,164,165,166,167,180,181,182,183},{170,25,130,131,155,25,146,147,170,25,196,197,171,25,212,213},{154,25,142,143,154,25,158,159,170,25,25,154,155,155,154,154},{196,197,170,170,212,213,154,25,192,193,194,195,208,209,210,211},{25,25,155,155,25,25,25,155,192,193,194,195,208,209,210,211},{25,155,196,197,170,170,212,213,196,197,6,7,212,213,22,23},{198,199,198,199,214,215,214,215,198,199,198,199,214,215,214,215},{196,197,154,25,212,213,25,25,170,25,25,25,170,25,170,25},{25,155,155,170,25,25,170,170,130,131,25,170,146,147,25,25},{170,25,6,7,25,25,22,23,25,170,25,155,25,25,170,25},{155,25,25,170,170,25,25,25,25,155,196,197,25,25,212,213},{153,154,25,170,169,154,170,25,169,155,170,171,200,186,186,186},{25,25,25,170,25,25,170,170,170,155,155,155,186,186,186,186},{155,25,170,172,25,170,155,172,155,170,155,172,186,186,186,205},{152,25,25,25,152,25,170,25,152,25,25,25,152,170,25,170},{155,155,155,156,25,154,155,156,154,170,155,156,170,25,155,156},{154,25,25,154,25,155,25,25,25,25,25,25,170,171,25,155},{66,67,138,139,170,25,155,155,155,155,155,155,155,155,155,155},{12,13,12,13,28,29,28,29,12,13,12,13,28,29,28,29},{130,131,198,199,146,147,214,215,198,199,198,199,214,215,214,215},{198,199,198,199,214,215,214,215,130,131,198,199,146,147,214,215},{198,199,130,131,214,215,146,147,198,199,198,199,214,215,214,215},{198,199,198,199,214,215,214,215,198,199,130,131,214,215,146,147},{82,82,82,82,83,83,40,83,12,13,62,56,28,29,40,84},{82,82,82,82,44,45,45,46,73,14,15,74,72,30,31,75},{82,82,82,82,83,41,83,83,57,63,12,13,86,41,28,29},{82,82,82,82,83,83,83,83,12,13,12,13,28,29,28,29},{12,13,62,84,28,29,76,77,12,13,92,93,28,29,28,29},{88,89,90,91,56,47,47,57,87,71,71,71,28,29,28,29},{85,63,12,13,78,79,28,29,94,95,12,13,28,29,28,29},{155,155,155,155,155,170,25,171,170,18,10,11,170,18,26,27},{155,170,155,154,170,25,170,170,18,25,42,43,170,18,58,59},{152,153,154,154,168,169,154,154,184,185,174,175,200,201,190,191},{154,154,156,157,154,154,172,173,174,175,188,189,190,191,204,205},{136,137,140,141,152,153,156,157,184,185,188,189,200,201,204,205},{38,39,12,13,54,55,28,29,69,70,12,13,28,29,28,29},{12,13,12,13,28,29,28,29,12,13,12,13,28,29,28,29},{154,154,154,154,155,154,154,154,128,129,185,186,144,145,201,202},{52,52,52,52,52,52,52,52,52,52,52,52,52,52,52,52}}]=],
    -- Tile $10 is reserved for BLUE's melt-water cells; it is deliberately
    -- absent from walkable so Surf, rather than ordinary walking, owns them.
    {20,25,26,28,47,52,56,58,154,155,158,170,171,190,214}, {16},
    nil, [=[{{"FLOOR","FLOOR","FLOOR","FLOOR"},{"WALL","WALL","WALL","WALL"},{"FLOOR","FLOOR","FLOOR","FLOOR"},{"FLOOR","FLOOR","FLOOR","LADDER"},{"WALL","UP_WALL","WALL","FLOOR"},{"UP_WALL","UP_WALL","FLOOR","FLOOR"},{"UP_WALL","WALL","FLOOR","WALL"},{"FLOOR","FLOOR","FLOOR","LADDER"},{"WALL","FLOOR","WALL","FLOOR"},{"FLOOR","FLOOR","FLOOR","FLOOR"},{"FLOOR","WALL","FLOOR","WALL"},{"WALL","WALL","WALL","WALL"},{"WALL","FLOOR","WALL","WALL"},{"FLOOR","FLOOR","WALL","WALL"},{"FLOOR","WALL","WALL","WALL"},{"WALL","WALL","WALL","WALL"},{"FLOOR","FLOOR","FLOOR","WALL"},{"FLOOR","FLOOR","WALL","FLOOR"},{"FLOOR","FLOOR","WALL","FLOOR"},{"FLOOR","FLOOR","WALL","CAVE"},{"WALL","WALL","WALL","FLOOR"},{"WALL","WALL","FLOOR","FLOOR"},{"WALL","WALL","FLOOR","WALL"},{"FLOOR","FLOOR","PIT","FLOOR"},{"WALL","FLOOR","WALL","FLOOR"},{"WALL","WALL","WALL","WALL"},{"FLOOR","WALL","FLOOR","WALL"},{"FLOOR","PIT","FLOOR","FLOOR"},{"WALL","FLOOR","WALL","WALL"},{"FLOOR","FLOOR","WALL","WALL"},{"FLOOR","WALL","WALL","WALL"},{"ICE","ICE","ICE","ICE"},{"WALL","FLOOR","FLOOR","FLOOR"},{"FLOOR","FLOOR","WALL","FLOOR"},{"FLOOR","WALL","FLOOR","FLOOR"},{"FLOOR","FLOOR","FLOOR","WALL"},{"WALL","HOP_DOWN_LEFT","WALL","WALL"},{"HOP_DOWN","HOP_DOWN","WALL","WALL"},{"HOP_DOWN_RIGHT","WALL","WALL","WALL"},{"WALL","HOP_LEFT","WALL","HOP_LEFT"},{"HOP_RIGHT","WALL","HOP_RIGHT","WALL"},{"FLOOR","FLOOR","WARP_CARPET_DOWN","FLOOR"},{"WALL","WALL","WALL","WALL"},{"FLOOR","FLOOR","FLOOR","FLOOR"},{"WALL","ICE","ICE","ICE"},{"ICE","ICE","WALL","ICE"},{"ICE","WALL","ICE","ICE"},{"ICE","ICE","ICE","WALL"},{"WALL","WALL","FLOOR","WALL"},{"WALL","WALL","WALL","WALL"},{"WALL","WALL","WALL","FLOOR"},{"WALL","WALL","FLOOR","FLOOR"},{"FLOOR","WALL","FLOOR","FLOOR"},{"FLOOR","FLOOR","FLOOR","FLOOR"},{"WALL","FLOOR","FLOOR","FLOOR"},{"FLOOR","FLOOR","FLOOR","LADDER"},{"FLOOR","FLOOR","FLOOR","LADDER"},{"WALL","FLOOR","WALL","FLOOR"},{"FLOOR","WALL","FLOOR","WALL"},{"WALL","WALL","WALL","WALL"},{"WALL","FLOOR","FLOOR","FLOOR"},{"FLOOR","FLOOR","WARP_CARPET_DOWN","WARP_CARPET_DOWN"},{"FLOOR","FLOOR","WALL","WALL"},{"ICE","ICE","ICE","LADDER"}}]=], { iceTiles={16,52,154,155,170,171}, pitBlocks={23,27},
      stopperBlocks={32,44,45,46,47}, wallHeight=24, floorHeight=0 })

  -- The exported Crystal sheet is a compact 96-tile source bank.  The native
  -- 64 metatiles remain above verbatim for provenance, but their original
  -- Game Boy VRAM references cannot be sampled one-to-one by the compact
  -- atlas renderer.  BLUE therefore uses these source-cell compositions:
  -- every pixel still comes from Ice Path, while each block is a stable,
  -- collision-audited runtime surface with a clear visual role.
  local ice = mod.content.tilesets:get("KA_HEVO_G2_ICE_PATH")
  -- All authored BLUE exit pads use the quiet frost field tile $AE.  Map
  -- warps remain restricted by map:warpAtCell, but that tile must still be a
  -- native warp surface so players can trigger the declared pads by walking.
  ice.warpTiles = { 174 }
  local function iceBlock(name, cells, walkable, water)
    local index = #ice.blocks
    ice.blocks[#ice.blocks + 1] = cells
    local semantic = water and "WATER" or (walkable and "FLOOR" or "WALL")
    ice.sourceCellCollision[#ice.sourceCellCollision + 1] = {
      { semantic, semantic, semantic, semantic }, { semantic, semantic, semantic, semantic },
      { semantic, semantic, semantic, semantic }, { semantic, semantic, semantic, semantic },
    }
    ice.hevoBlocks = ice.hevoBlocks or {}
    ice.hevoBlocks[name] = index
    if walkable then
      local known = {}; for _, tile in ipairs(ice.walkable) do known[tile] = true end
      for _, tile in ipairs(cells) do if not known[tile] then ice.walkable[#ice.walkable + 1] = tile; known[tile] = true end end
    end
    if water then
      local known = {}; for _, tile in ipairs(ice.waterTiles) do known[tile] = true end
      for _, tile in ipairs(cells) do if not known[tile] then ice.waterTiles[#ice.waterTiles + 1] = tile; known[tile] = true end end
    end
  end
  iceBlock("ICE_FIELD", {96,97,98,99,112,113,114,115,128,129,130,131,144,145,146,147}, true)
  iceBlock("ICE_GLINT", {100,101,102,103,116,117,118,119,132,133,134,135,148,149,150,151}, true)
  iceBlock("ICE_DRIFT", {104,105,106,107,120,121,122,123,136,137,138,139,152,153,154,155}, true)
  iceBlock("CRYSTAL_WALL", {32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47})
  iceBlock("MELTWATER", {48,49,50,51,52,53,54,55,56,57,58,59,60,61,62,63}, false, true)
  iceBlock("BRAKE_CRYSTAL", {64,65,66,67,68,69,70,71,72,73,74,75,76,77,78,79}, true)
  -- The lower-right Ice Path source group is the sheet's circular ice-hole
  -- landmark.  It is water-semantic and non-walkable, unlike an opaque black
  -- fill, so a chasm reads as a real frozen pool in both 2D and Map Studio.
  iceBlock("FROST_HOLE", {108,109,110,111,124,125,126,127,140,141,142,143,156,157,158,159}, false, true)
  -- These two roles use deliberately quiet, real Ice Path cells. They form a
  -- readable snow floor and a dark-blue cliff mass without the macro-sized
  -- checker pattern produced by repeating a whole decorative metatile.
  iceBlock("SNOWFIELD", {174,174,174,174,174,174,174,174,174,174,174,174,174,174,174,174}, true)
  iceBlock("ICE_CLIFF", {47,47,47,47,47,47,47,47,47,47,47,47,47,47,47,47})
  -- These are complete, visually audited metatiles copied from Crystal's
  -- original Ice Path block table (blocks 2, 3, 4 and 15 respectively).
  -- They are intentionally not a new art approximation: compact rendering
  -- samples the same source cells as the reference maps while these semantic
  -- roles supply unambiguous collision to the runtime and Map Studio.
  iceBlock("NATIVE_ICE_FLOOR", {154,25,154,154,25,154,25,25,154,25,25,25,170,25,25,154}, true)
  iceBlock("NATIVE_ICE_BRAKE", {154,154,25,25,154,25,25,154,25,25,10,11,154,25,26,27}, true)
  iceBlock("NATIVE_ICE_CLIFF", {136,137,138,139,152,153,154,154,168,169,154,155,168,169,154,154})
  iceBlock("NATIVE_FROST_POOL", {9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9}, false, true)
  iceBlock("NATIVE_ICE_SLIDE", {154,171,155,170,25,25,25,155,25,25,42,43,154,25,58,59}, true)
  iceBlock("NATIVE_ICE_OUTCROP", {168,169,154,155,168,169,154,154,168,169,154,154,168,169,154,155})
  -- A low-frequency glint field keeps traversable ice readable without
  -- turning it into the high-contrast checkerboard made by a repeated cave
  -- wall.  All cells are native Ice Path source cells.
  iceBlock("NATIVE_ICE_GLINT_FIELD", {174,174,174,174,174,182,174,174,174,174,174,183,174,174,174,174}, true)
  -- Crystal's adjoining cliff cells make a continuous, small-grain ridge in
  -- the compact renderer.  This avoids treating one 32px prop metatile as a
  -- repeated wall while retaining the exact Ice Path palette and source art.
  -- 160--165 are native Ice Path cliff cells that are not referenced by any
  -- walkable custom role.  Keeping this set disjoint is essential: collision
  -- is tile-based in the engine, so reusing a gliding cell here would create
  -- an invisible hole through an otherwise solid ridge.
  iceBlock("NATIVE_ICE_RIDGE", {160,160,160,160,160,160,160,160,160,160,160,160,160,160,160,160})
  -- Deep, non-walkable Ice Path cells supply the exterior backdrop.  It is a
  -- separate role from the ridge so authored rooms use only one or two rows
  -- of visible rock rather than filling every unused block with a wall.
  iceBlock("NATIVE_ICE_DEEP_BACKGROUND", {31,31,31,31,31,31,31,31,31,31,31,31,31,31,31,31})
  -- A quiet, direction-neutral slide lane.  The movement hook, rather than
  -- an art tile, owns BLUE's slide behaviour; this native light-ice grouping
  -- keeps the lane legible without introducing the brown source fragment in
  -- the older mixed metatile.
  iceBlock("NATIVE_ICE_SLIDE_LANE", {174,174,182,174,174,174,174,183,174,174,174,174,174,182,174,174}, true)
  -- Crystal Forest's original animated water/flower semantics map to the
  -- renderer's data-driven animation contract (tile $14/$03).
  register("KA_HEVO_G2_FOREST", "/assets/hidden_evolution/tilesets/forest.png",
    [=[{{12,13,14,15,28,29,30,31,44,45,46,47,60,61,62,63},{5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5},{20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20},{42,42,42,42,20,20,20,20,20,20,20,20,20,20,20,20},{5,5,5,5,5,3,5,3,3,5,3,5,5,5,5,5},{12,13,14,15,28,29,30,31,44,45,46,47,60,61,62,63},{5,5,19,19,5,5,19,19,5,5,19,19,5,5,19,19},{9,42,42,42,27,20,20,20,27,20,20,20,27,20,20,20},{38,39,38,39,54,55,54,55,38,39,5,5,54,55,5,5},{38,39,38,39,54,55,54,55,5,5,5,5,5,5,5,5},{27,20,20,20,27,20,20,20,27,20,20,20,27,20,20,20},{20,20,20,25,20,20,20,25,20,20,20,25,20,20,20,25},{38,39,5,5,54,55,5,5,38,39,5,5,54,55,5,5},{42,42,42,11,20,20,20,25,20,20,20,25,20,20,20,25},{5,5,38,39,5,5,54,55,5,5,38,39,5,5,54,55},{5,5,5,5,5,5,5,5,40,57,38,39,56,58,54,55},{38,39,5,5,54,55,5,5,38,39,38,39,54,55,54,55},{5,5,5,5,5,5,5,5,38,39,38,39,54,55,54,55},{5,5,38,39,5,5,54,55,38,39,38,39,54,55,54,55},{5,5,5,5,5,5,5,5,5,5,1,6,5,5,21,22},{38,39,5,5,54,55,5,5,5,5,5,5,5,5,5,5},{5,5,38,39,5,5,54,55,5,5,5,5,5,5,5,5},{5,5,5,5,5,5,5,5,38,39,5,5,54,55,5,5},{5,5,5,5,5,5,5,5,5,5,38,39,5,5,54,55},{25,5,5,5,25,5,5,5,25,5,5,5,25,5,5,5},{25,5,5,5,25,5,5,5,25,5,5,5,41,42,42,42},{5,5,5,5,5,5,5,5,5,5,5,5,42,42,42,42},{5,5,5,27,5,5,5,27,5,5,5,27,42,42,42,43},{5,5,5,5,5,5,5,5,5,5,5,5,42,42,5,5},{16,17,17,17,32,33,33,33,32,33,33,33,32,33,33,33},{17,17,17,17,33,33,33,33,33,33,33,33,33,33,33,33},{17,17,17,18,33,33,33,34,33,33,33,34,33,33,33,34},{16,18,5,5,48,50,5,5,21,22,5,5,5,5,5,5},{32,33,33,33,48,49,49,49,35,36,36,36,35,4,4,36},{33,33,33,33,49,49,49,49,36,36,36,36,36,4,4,36},{33,33,33,34,49,49,49,50,36,36,36,37,36,4,4,37},{35,36,36,36,35,36,36,36,35,36,7,8,51,52,23,24},{35,36,36,36,35,36,36,36,35,36,36,36,51,52,52,52},{36,36,36,36,36,36,36,36,36,36,36,36,52,52,52,52},{36,36,36,37,36,36,36,37,36,36,36,37,52,52,52,53}}]=],
    {5,19,23,54,56}, {20}, "TILEANIM_WATER_FLOWER", [=[{{"WALL","WALL","WALL","WALL"},{"FLOOR","FLOOR","FLOOR","FLOOR"},{"WATER","WATER","WATER","WATER"},{"WATER","WATER","WATER","WATER"},{"FLOOR","FLOOR","FLOOR","FLOOR"},{"WALL","WALL","WALL","WALL"},{"FLOOR","WARP_CARPET_RIGHT","FLOOR","WARP_CARPET_RIGHT"},{"WATER","WATER","WATER","WATER"},{"HEADBUTT_TREE","HEADBUTT_TREE","HEADBUTT_TREE","FLOOR"},{"HEADBUTT_TREE","HEADBUTT_TREE","FLOOR","FLOOR"},{"WATER","WATER","WATER","WATER"},{"WATER","WATER","WATER","WATER"},{"HEADBUTT_TREE","FLOOR","HEADBUTT_TREE","FLOOR"},{"WATER","WATER","WATER","WATER"},{"FLOOR","HEADBUTT_TREE","FLOOR","HEADBUTT_TREE"},{"FLOOR","FLOOR","CUT_TREE","HEADBUTT_TREE"},{"HEADBUTT_TREE","FLOOR","HEADBUTT_TREE","HEADBUTT_TREE"},{"FLOOR","FLOOR","HEADBUTT_TREE","HEADBUTT_TREE"},{"FLOOR","HEADBUTT_TREE","HEADBUTT_TREE","HEADBUTT_TREE"},{"FLOOR","FLOOR","FLOOR","WALL"},{"HEADBUTT_TREE","FLOOR","FLOOR","FLOOR"},{"FLOOR","HEADBUTT_TREE","FLOOR","FLOOR"},{"FLOOR","FLOOR","HEADBUTT_TREE","FLOOR"},{"FLOOR","FLOOR","FLOOR","HEADBUTT_TREE"},{"WALL","HOP_LEFT","WALL","HOP_LEFT"},{"WALL","HOP_DOWN_LEFT","WALL","WALL"},{"HOP_DOWN","HOP_DOWN","WALL","WALL"},{"HOP_DOWN_RIGHT","WALL","WALL","WALL"},{"HOP_DOWN","FLOOR","WALL","FLOOR"},{"WALL","WALL","WALL","WALL"},{"WALL","WALL","WALL","WALL"},{"WALL","WALL","WALL","WALL"},{"WALL","FLOOR","FLOOR","FLOOR"},{"WALL","WALL","WALL","WALL"},{"WALL","WALL","WALL","WALL"},{"WALL","WALL","WALL","WALL"},{"WALL","WALL","WALL","DOOR"},{"WALL","WALL","WALL","WALL"},{"WALL","WALL","WALL","WALL"},{"WALL","WALL","WALL","WALL"}}]=],
    { treeBlocks={8,9,12,14,15,16,17,18,20,21,22,23},
      waterTiles={20}, canopyHeight=32, treeHeight=24, fog="forest" })

  local forest = mod.content.tilesets:get("KA_HEVO_G2_FOREST")
  forest.animatedTiles = {
    {tile=3, kind="frames", period=24, sequence={1,2}, images={
      mod.path .. "/assets/hidden_evolution/tilesets/animations/forest_tile_03_flower_1.png",
      mod.path .. "/assets/hidden_evolution/tilesets/animations/forest_tile_03_flower_2.png"}},
    {tile=20, kind="frames", period=24, sequence={1,2,3,4}, images={
      derivedAsset .. "forest_tile_14_water_1.png",
      derivedAsset .. "forest_tile_14_water_2.png",
      derivedAsset .. "forest_tile_14_water_3.png",
      derivedAsset .. "forest_tile_14_water_4.png"}},
  }
end
