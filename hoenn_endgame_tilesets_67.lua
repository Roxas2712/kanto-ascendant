-- KASC 6.7 visual authority for the optional Hoenn endgame rooms.
-- The air atlas and block/collision catalogue come from the reviewed Hidden
-- Evolution Map Studio project.  The volcano skin is a visual-only clone of
-- CAVERN: it swaps only the atlas and palette, retaining every block and
-- collision tile verbatim. Disabling the owning
-- encounter Cards leaves both additive themes unused and patches no native map.

return function(mod,opts)
  opts=opts or{}
  local Json=assert(opts.json,"Hoenn endgame tilesets require JSON decoder")
  local T={ID="KA_HOENN_SKY_67",VOLCANO_ID="KA_MOLTRES_VOLCANO_67",
    registered=false,
    SOURCE_PROJECT_SHA256="cb470cbde5cd5693eb9122c68b72f9177927c2f2a31291303662fd5fdc047585",
    ASSET_SHA256="8e5d38917dc2c35f0866b4155e86bb4fa4cdea0604500ca0fa791745066b740f",
    VOLCANO_SOURCE_ASSET_SHA256="f69441cb181061017a591cb389a88e06bdcc479949433b37a64a358c5fc55696",
    VOLCANO_ASSET_SHA256="feb54d1de81fd286a0ec0d683cf09f84a746842d8fb1d5f6020239ccdea0d989"}
  local cached
  local function data()
    if not cached then
      cached=Json.read(mod,"assets/hoenn_endgame_67/air-tileset-v1.json")
      assert(cached.sourceProjectSha256==T.SOURCE_PROJECT_SHA256,
        "Hoenn sky source project mismatch")
      assert(cached.assetSha256==T.ASSET_SHA256,"Hoenn sky atlas mismatch")
      assert(cached.sourceTheme=="air"and type(cached.tileset)=="table",
        "Hoenn sky theme missing")
    end
    return cached.tileset
  end
  local function copy(value,seen)
    if type(value)~="table"then return value end
    seen=seen or{};if seen[value]then return seen[value]end
    local out={};seen[value]=out
    for key,child in pairs(value)do out[copy(key,seen)]=copy(child,seen)end
    return out
  end
  function T.definition()
    local source=data()
    return{id=T.ID,
      image=mod.path.."/assets/hoenn_endgame_67/sector_air.png",
      imageWidth=512,imageHeight=160,tilesPerRow=assert(source.tilesPerRow),
      trueColor=true,alphaOverhangs=false,blocks=copy(source.blocks),
      walkable=copy(source.walkable or{}),waterTiles={},grassTiles={},
      warpTiles=copy(source.warpTiles or{}),animatedTiles={},
      voxelMode="MAP_STUDIO",voxelSemanticProfile={
        authority="hidden-evolution-map-studio-air",
        sourceProjectSha256=T.SOURCE_PROJECT_SHA256,
        sourceTheme="air",collision="source-walkable-tiles"}}
  end
  function T.volcanoDefinition(cavern)
    cavern=assert(cavern,"CAVERN tileset required for volcano visual clone")
    local out=copy(cavern)
    out.id=T.VOLCANO_ID
    out.image=mod.path.."/assets/hoenn_endgame_67/volcano-readable-exits.png"
    out.imageWidth,out.imageHeight,out.tilesPerRow=128,40,16
    assert(type(out.blocks)=="table"and out.blocks[126],
      "CAVERN block catalogue incomplete")
    -- Block graphics also encode collision: a cell is classified by its
    -- bottom-left tile. Replacing block 41's floor tiles with wall tiles
    -- sealed the base/ascent approach despite an unchanged walkable list.
    -- Keep the complete native block catalogue; the atlas supplies the skin.
    out.voxelMode="FULL"
    out.voxelSemanticProfile={
      authority="kasc-hoenn-moltres-volcano-visual",
      source="lavados_vulkan-3.1.8",assetSha256=T.VOLCANO_ASSET_SHA256,
      collision="cavern-clone-unchanged"}
    return out
  end
  local function volcanoPalette()
    local rock={{255,226,189},{206,132,74},{115,66,49},{25,16,16}}
    local lava={{255,239,148},{255,156,33},{222,66,16},{90,16,16}}
    local groups={}
    for index=1,8 do groups[index]=copy(index==2 and lava or rock)end
    local tileGroups={}
    for tile=0,79 do tileGroups[tile]=0 end
    for _,tile in ipairs({6,20,33,35,36,37,38})do tileGroups[tile]=1 end
    return groups,tileGroups
  end
  function T.registerVolcanoTrueColor()
    local loaded,pack=pcall(require,"data.palettes_gbc")
    local world=loaded and type(pack)=="table"and pack.world
    if type(world)~="table"or type(world.groupColors)~="table"
        or type(world.tileGroups)~="table"then return false end
    local groups,tiles=volcanoPalette()
    world.groupColors[T.VOLCANO_ID]=groups
    world.tileGroups[T.VOLCANO_ID]=tiles
    return true
  end
  function T.register()
    if T.registered then return false,"already-registered"end
    local registry=assert(mod.content and mod.content.tilesets,
      "Hoenn endgame tileset registry unavailable")
    if not registry:get(T.ID)then registry:register(T.ID,T.definition())end
    local cavern=registry:get("CAVERN")
    if cavern and not registry:get(T.VOLCANO_ID)then
      registry:register(T.VOLCANO_ID,T.volcanoDefinition(cavern))
    end
    T.volcanoRegistered=registry:get(T.VOLCANO_ID)~=nil
    T.volcanoTrueColor=T.volcanoRegistered and T.registerVolcanoTrueColor()or false
    T.registered=true;return true
  end
  T.copy=copy
  return T
end
