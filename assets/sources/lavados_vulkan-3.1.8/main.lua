-- Lavados Vulkan: the pureRGB Cinnabar Volcano ported to gen1recomp.
--
-- Every map, tileset and warp below is generated from the pureRGB
-- disassembly by tools/build_mod.py; this file only wires the data into the
-- mod registries and owns the quest scripts.
return function(mod)
  local VERSION = mod.version or "3.1.8"

  local function loadModule(relative)
    local source = mod:read(relative)
    if not source then
      error("missing mod file: " .. relative)
    end
    -- LuaJIT is Lua 5.1: loadstring is the one that takes a source string
    local compile = loadstring or load
    local chunk, compileErr = compile(source, "@" .. mod.path .. "/" .. relative)
    if not chunk then
      error(compileErr or ("failed to compile " .. relative))
    end
    return chunk()
  end

  local mapData = loadModule("data_maps.lua")
  local tileData = loadModule("data_tilesets.lua")
  local questData = loadModule("data_quest.lua")

  -- ------- sprites
  --
  -- The two sheets the player wears inside the volcano, copied out of pureRGB:
  -- LavaSuitSprite on foot and MonsterSwimmingSprite -- the RHYDON -- on the
  -- lava (LoadLavaSuitSpriteGraphics / LoadSurfingPlayerSpriteGraphics,
  -- home/overworld.asm).  Both are 16x96 four-shade sheets, the same shape as
  -- the engine's own extracted red.png, so they need no conversion.
  -- paletteSource points at the player's row in SpriteSheetPointerTable, which
  -- is what PaletteFX.spriteObp reads to give mod art a real OBJ palette under
  -- RED++ instead of leaving it in flat DMG shades.
  for _, sprite in ipairs(questData.sprites) do
    mod.content.sprites:register(sprite.id, {
      id = sprite.id,
      image = mod.assets:path(sprite.image),
      frames = sprite.frames,
      walker = sprite.walker,
      paletteSource = sprite.paletteSource,
    })
  end

  local Volcano = loadModule("scripts/volcano.lua")(mod, questData)

  -- ------- tilesets

  -- Only the block table grows: pureRGB's volcano-island blocks 128..154 are
  -- appended to Red's 128.  Every tile they name already exists in the base
  -- game's overworld sheet, so there is no image override and no change to
  -- walkable/warpTiles that other Kanto maps would inherit.
  mod.content.tilesets:patch("OVERWORLD", { blocks = tileData.overworld_blocks })

  local volcanoTileset = tileData.volcano
  volcanoTileset.image = mod.assets:path("assets/tilesets/volcano.png")
  mod.content.tilesets:register("VOLCANO", volcanoTileset)

  -- Under RED++ colours (options.colors = "redpp") the overworld is true
  -- colour: TileRenderer bakes real per-tile colours into the tileset atlas and
  -- SpriteRenderer bakes each sprite's OBJ palette, after which
  -- OverworldState:sgbWorldZones returns an empty zone list so the DMG
  -- shade-remap shader never runs.  TileRenderer only bakes that atlas for a
  -- tileset data/palettes_gbc.lua knows (PaletteFX.hasWorldTileset), so an
  -- unregistered VOLCANO sent the whole world canvas -- the already-baked
  -- sprites included -- back through the shader, flattening the player and
  -- every NPC into the map's 4-colour SGB palette.  There is no mod registry
  -- for the pack, so the entry goes in directly; it is purely additive and
  -- inert in every other colour mode.
  local function registerVolcanoTrueColor()
    local loaded, pack = pcall(require, "data.palettes_gbc")
    if not loaded or type(pack) ~= "table" then return false end
    local world = pack.world
    if type(world) ~= "table" or type(world.groupColors) ~= "table"
       or type(world.tileGroups) ~= "table" then
      return false
    end
    world.groupColors.VOLCANO = tileData.volcano_gbc.groupColors
    world.tileGroups.VOLCANO = tileData.volcano_gbc.tileGroups
    return true
  end

  local trueColorOk = registerVolcanoTrueColor()

  -- lava is surfable (pureRGB data/tilesets/water_tilesets.asm: "but it's lava")
  mod.content.field:patch("waterTilesets", { "VOLCANO" })

  -- ------- maps

  mod.content.maps:patch("ROUTE_21", {
    blocks = mapData.route21_blocks,
    warps = mapData.route21_warps,
    signs = mapData.route21_signs,
  })

  mod.content.maps:register("CINNABAR_VOLCANO", mapData.cinnabar_volcano)
  mod.content.maps:register("CINNABAR_VOLCANO_WEST", mapData.cinnabar_volcano_west)

  mod.content.map_songs:register("CINNABAR_VOLCANO", "Music_Dungeon1")
  mod.content.map_songs:register("CINNABAR_VOLCANO_WEST", "Music_Dungeon1")

  mod.content.encounters:register("CINNABAR_VOLCANO", questData.encounters)
  mod.content.encounters:register("CINNABAR_VOLCANO_WEST", questData.encounters)

  mod.content.field:patch("townMap", {
    locations = {
      CINNABAR_VOLCANO = { x = 2, y = 13, name = "VULKAN" },
      CINNABAR_VOLCANO_WEST = { x = 2, y = 13, name = "VULKAN" },
    },
  })

  -- ------- texts and scripts

  for label, text in pairs(Volcano.texts) do
    mod.content.text:register(label, text)
  end
  for mapLabel, pointers in pairs(Volcano.textPointers) do
    mod.content.text_pointers:patch(mapLabel, pointers)
  end
  for mapId, script in pairs(Volcano.maps) do
    mod.content.map_scripts:register(mapId, script)
  end

  mod.log:info(("Lavados Vulkan v%s: CINNABAR_VOLCANO %dx%d (%d Warps), " ..
                "CINNABAR_VOLCANO_WEST %dx%d, Route-21-Eingang (%d,%d), " ..
                "RED++-Farben %s")
    :format(VERSION,
            mapData.cinnabar_volcano.width, mapData.cinnabar_volcano.height,
            #mapData.cinnabar_volcano.warps,
            mapData.cinnabar_volcano_west.width, mapData.cinnabar_volcano_west.height,
            mapData.route21_warps[1].x, mapData.route21_warps[1].y,
            trueColorOk and "registriert" or "nicht verfuegbar"))
end
