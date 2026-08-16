-- Authored Gen-II tileset bridge for the Johto Masters passages.
-- The checked-in catalog is a verbatim local pokecrystal-derived source;
-- this adapter preserves its blocks and walkability instead of repainting
-- CAVERN.  See docs/JOHTO_MASTERS_PASSAGES_PROVENANCE_DE.md.
return function(mod)
  -- Deliberately local: JSON is data parsing here, not network access.  Mods
  -- must not reach into src.link.Json (which would require the unrelated
  -- network permission and fail strict packaging).  This small decoder is
  -- sufficient for the checked-in catalog and travels with the adapter.
  local function decodeJson(text)
    local function skipWhitespace(index)
      return text:find("[^ \t\r\n]", index) or (#text + 1)
    end
    local decodeValue
    local function decodeString(index)
      local out = {}
      index = index + 1
      while index <= #text do
        local char = text:sub(index, index)
        if char == '"' then return table.concat(out), index + 1 end
        if char ~= "\\" then
          out[#out + 1] = char
          index = index + 1
        else
          local escape = text:sub(index + 1, index + 1)
          local simple = {
            ['"'] = '"', ["\\"] = "\\", ["/"] = "/",
            b = "\b", f = "\f", n = "\n", r = "\r", t = "\t",
          }
          if simple[escape] then
            out[#out + 1] = simple[escape]
            index = index + 2
          elseif escape == "u" then
            local code = tonumber(text:sub(index + 2, index + 5), 16)
            assert(code, "invalid unicode escape")
            if code < 0x80 then
              out[#out + 1] = string.char(code)
            elseif code < 0x800 then
              out[#out + 1] = string.char(
                0xC0 + math.floor(code / 0x40), 0x80 + code % 0x40)
            else
              out[#out + 1] = string.char(
                0xE0 + math.floor(code / 0x1000),
                0x80 + math.floor(code / 0x40) % 0x40,
                0x80 + code % 0x40)
            end
            index = index + 6
          else
            error("invalid JSON escape")
          end
        end
      end
      error("unterminated JSON string")
    end
    decodeValue = function(index)
      index = skipWhitespace(index)
      local char = text:sub(index, index)
      if char == '"' then return decodeString(index) end
      if char == "{" then
        local object = {}
        index = skipWhitespace(index + 1)
        if text:sub(index, index) == "}" then return object, index + 1 end
        while true do
          local key
          key, index = decodeString(skipWhitespace(index))
          index = skipWhitespace(index)
          assert(text:sub(index, index) == ":", "expected : in JSON object")
          local value
          value, index = decodeValue(index + 1)
          object[key] = value
          index = skipWhitespace(index)
          local delimiter = text:sub(index, index)
          if delimiter == "}" then return object, index + 1 end
          assert(delimiter == ",", "expected , or } in JSON object")
          index = index + 1
        end
      end
      if char == "[" then
        local array = {}
        index = skipWhitespace(index + 1)
        if text:sub(index, index) == "]" then return array, index + 1 end
        while true do
          local value
          value, index = decodeValue(index)
          array[#array + 1] = value
          index = skipWhitespace(index)
          local delimiter = text:sub(index, index)
          if delimiter == "]" then return array, index + 1 end
          assert(delimiter == ",", "expected , or ] in JSON array")
          index = index + 1
        end
      end
      if text:sub(index, index + 3) == "true" then return true, index + 4 end
      if text:sub(index, index + 4) == "false" then return false, index + 5 end
      if text:sub(index, index + 3) == "null" then return nil, index + 4 end
      local number = text:match("^-?%d+%.?%d*[eE]?[+-]?%d*", index)
      assert(number and #number > 0, "unexpected JSON token at " .. index)
      return assert(tonumber(number)), index + #number
    end
    local value, nextIndex = decodeValue(1)
    assert(skipWhitespace(nextIndex) == #text + 1, "trailing JSON data")
    return value
  end
  local ids = {
    underground = "KA_JOHTO_G2_UNDERGROUND",
    radio_tower = "KA_JOHTO_G2_RADIO_TOWER",
    ruins_of_alph = "KA_JOHTO_G2_RUINS_OF_ALPH",
    lab = "KA_JOHTO_G2_LAB",
    tower = "KA_JOHTO_G2_TOWER",
    champions_room = "KA_JOHTO_G2_CHAMPIONS_ROOM",
    silver_signal = "KA_JOHTO_G2_SILVER_SIGNAL",
    kris_archive = "KA_JOHTO_G2_KRIS_ARCHIVE",
    -- v9 is intentionally a separate, authored passage skin.  It keeps the
    -- historical block indices and collision data, but does not inherit a
    -- global floor motif as a full-map substitute.
    silver_signal_v9 = "KA_JOHTO_G2_SILVER_SIGNAL_V9",
    kris_archive_v9 = "KA_JOHTO_G2_KRIS_ARCHIVE_V9",
  }
  local sources = {
    underground = ids.underground, radio_tower = ids.radio_tower,
    ruins_of_alph = ids.ruins_of_alph, lab = ids.lab, tower = ids.tower,
    champions_room = ids.champions_room,
  }

  local cached
  local function catalog()
    if cached then return cached end
    -- Read through the public mod filesystem.  mod.path is a virtual loader
    -- path in installed/ZIP/SDK builds and must not be passed to host io.
    local raw, readErr = mod:read("assets/johto_masters/gen2_catalog.json")
    assert(raw, readErr or "Johto Masters Gen-II catalog missing")
    local ok, decoded = pcall(decodeJson, raw)
    assert(ok and decoded, "invalid Johto Masters catalog: " .. tostring(decoded))
    cached = decoded
    return cached
  end

  local function register()
    local catalog = catalog()
    if not (catalog and mod.content and mod.content.tilesets) then return false end
    for source, id in pairs(sources) do
      if not mod.content.tilesets:get(id) then
        local row = assert(catalog.tilesets and catalog.tilesets[source],
          "Gen-II catalog tileset missing: " .. source)
        mod.content.tilesets:register(id, {
          id = id,
          image = mod.path .. "/assets/johto_masters/tilesets/" .. source .. ".png",
          imageWidth = row.imageWidth, imageHeight = row.imageHeight,
          tilesPerRow = row.tilesPerRow, trueColor = true,
          blocks = row.blocks, walkable = row.walkable,
          waterTiles = row.waterTiles or {}, grassTiles = row.grassTiles or {},
          warpTiles = row.warpTiles or {}, sourceCellCollision = row.cellCollision,
          sourcePalette = row.palette, generation = 2,
          voxelMode = "MAP_STUDIO",
          voxelSemanticProfile = {
            sourceTileset = source, collision = "pokecrystal-catalog",
            wallHeight = 24, floorHeight = 0,
          },
        })
      end
    end
    -- Passage-local visual variants: their block indices deliberately retain
    -- the source collision table.  We only replace tile art inside existing
    -- all-floor slots, never a map's cell geometry or warp lattice.
    local function cloneBlocks(blocks)
      local copy={}
      for index,block in ipairs(blocks) do
        copy[index]={};for tileIndex,tile in ipairs(block) do copy[index][tileIndex]=tile end
      end
      return copy
    end
    local function registerVariant(id,source,mutate,imageName,extraWalkable)
      if mod.content.tilesets:get(id) then return end
      local row=assert(catalog.tilesets[source],"variant source missing: "..source)
      local blocks=cloneBlocks(row.blocks);mutate(blocks,row)
      local walkable={};for _,tile in ipairs(row.walkable or {}) do walkable[#walkable+1]=tile end
      for _,tile in ipairs(extraWalkable or {}) do walkable[#walkable+1]=tile end
      mod.content.tilesets:register(id,{id=id,
        image=mod.path.."/assets/johto_masters/tilesets/"..(imageName or source)..".png",
        imageWidth=row.imageWidth,imageHeight=row.imageHeight,tilesPerRow=row.tilesPerRow,trueColor=true,
        blocks=blocks,walkable=walkable,waterTiles=row.waterTiles or {},grassTiles=row.grassTiles or {},warpTiles=row.warpTiles or {},
        sourceCellCollision=row.cellCollision,sourcePalette=row.palette,generation=2,voxelMode="MAP_STUDIO",
        voxelSemanticProfile={sourceTileset=source,variant="johto-passage-local",collision="pokecrystal-catalog",wallHeight=24,floorHeight=0}})
    end
    registerVariant(ids.silver_signal,"radio_tower",function(blocks)
      -- block $13 (Lua index 20) is an all-floor neutral relay-room panel;
      -- its charcoal tiles come from the same Radio Tower atlas. $14 adds a
      -- thin blue cable trace on the otherwise quiet panel.
      blocks[20]={57,57,57,57,57,57,57,57,57,57,57,57,57,57,57,57}
      blocks[21]={57,57,57,57,57,57,57,57,44,45,44,45,60,61,60,61}
    end)
    registerVariant(ids.kris_archive,"ruins_of_alph",function(blocks)
      -- block $33 (Lua index 52) is collision-equivalent to the existing
      -- archive floor but uses calm carved-stone tiles from the same atlas.
      blocks[52]={2,3,2,3,3,2,3,2,2,3,2,3,3,2,3,2}
      -- The repeated gold wall faces are retained as collision, but shown as
      -- quiet archive stone in this passage-only variant.  This makes the
      -- narrow routes and three rune slabs visually legible without changing
      -- a single blocked cell.
      blocks[11]={2,3,2,3,3,2,3,2,2,3,2,3,3,2,3,2}
      blocks[12]={2,3,2,3,3,2,3,2,2,3,2,3,3,2,3,2}
    end)
    -- v9 local metatile art.  The source collision profile remains attached
    -- verbatim: walls become shelves/window frames, floors become calm stone
    -- or steel, and the few selected alternate floor blocks become explicit
    -- route cues.  It is an overlay at the tileset layer, not a global block
    -- remap and not a change to passage geometry.
    local function fill(tile)
      local out={};for i=1,16 do out[i]=tile end;return out
    end
    local function quadrants(collision, floor, wall, feature)
      local out={}
      for q=1,4 do
        local tile=(collision[q]=="FLOOR" and floor) or
          (collision[q]=="WINDOW" and feature) or wall
        local base=((q-1)%2)*2 + math.floor((q-1)/2)*8
        out[base+1],out[base+2],out[base+5],out[base+6]=tile,tile,tile,tile
      end
      return out
    end
    registerVariant(ids.silver_signal_v9,"radio_tower",function(blocks,row)
      for index, collision in ipairs(row.cellCollision) do
        -- 160 is the quiet blue-grey floor; 164/165 form bounded structural
        -- edges and windows from the existing collision mask.
        blocks[index]=quadrants(collision,160,164,165)
      end
      -- Collision-equivalent all-floor route markers: cyan cable, red status
      -- lamp and console/relay plates.  The map applies these only at a few
      -- authored stations, never as a carpet.
      blocks[20]={160,160,160,160,160,174,174,160,160,174,174,160,160,160,160,160}
      blocks[21]={170,170,170,170,170,171,171,170,170,171,171,170,170,170,170,170}
      blocks[40]={168,168,168,168,168,169,169,168,168,169,169,168,168,168,168,168}
      blocks[45]={172,172,172,172,172,173,173,172,172,173,173,172,172,172,172,172}
    end,"silver_signal_v9",{160,161,162,163,166,167,168,169,170,171,172,173,174,175})
    registerVariant(ids.kris_archive_v9,"ruins_of_alph",function(blocks,row)
      for index, collision in ipairs(row.cellCollision) do
        -- Existing walls stay exactly where their collision says they are,
        -- but render as shelving and stone borders instead of gold carpet.
        blocks[index]=quadrants(collision,160,164,165)
      end
      -- $33 is the calm archive floor; $0d is used only for three small rune
      -- islands.  Both preserve their source all-floor collision profile.
      blocks[52]=fill(160)
      blocks[14]={168,168,168,168,168,169,169,168,168,169,169,168,168,168,168,168}
      -- $03 is collision-equivalent to the floor islands and therefore may
      -- become a lectern/stele without moving a single reachable cell.
      blocks[4]={171,171,171,171,171,172,172,171,171,172,172,171,171,171,171,171}
      -- Existing partial-floor archive blocks read as narrow bridges and
      -- lecterns without changing any blocked quarter-cell.
      blocks[19]=quadrants(row.cellCollision[19],166,164,165)
      blocks[20]=quadrants(row.cellCollision[20],166,164,165)
    end,"kris_archive_v9",{160,161,162,163,166,167,168,169,170,171,172,173,174,175})
  end

  local function layout(id)
    local catalog = catalog()
    for _, map in ipairs(catalog.maps or {}) do
      if map.id == id then return map end
    end
    error("Gen-II catalog map missing: " .. tostring(id))
  end
  return { ids = ids, register = register, layout = layout }
end
