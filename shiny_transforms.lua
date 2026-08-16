-- Crystal's shiny palettes, applied to the player's own imported Gen I art.
-- The source table is data/pokemon/palettes.asm plus each species' shiny.pal
-- from pret/pokecrystal. Crystal stores only the two middle 5-bit colors;
-- white and black are the fixed outer shades. Values below are expanded with
-- the Game Boy convention n << 3 and packed as RRGGBBRRGGBB in National-Dex
-- order. No Pokemon sprite pixels are shipped by this mod.

local STEMS = "bulbasaur,ivysaur,venusaur,charmander,charmeleon,charizard,squirtle,wartortle,blastoise,caterpie,metapod,butterfree,weedle,kakuna,beedrill,pidgey,pidgeotto,pidgeot,rattata,raticate,spearow,fearow,ekans,arbok,pikachu,raichu,sandshrew,sandslash,nidoranf,nidorina,nidoqueen,nidoranm,nidorino,nidoking,clefairy,clefable,vulpix,ninetales,jigglypuff,wigglytuff,zubat,golbat,oddish,gloom,vileplume,paras,parasect,venonat,venomoth,diglett,dugtrio,meowth,persian,psyduck,golduck,mankey,primeape,growlithe,arcanine,poliwag,poliwhirl,poliwrath,abra,kadabra,alakazam,machop,machoke,machamp,bellsprout,weepinbell,victreebel,tentacool,tentacruel,geodude,graveler,golem,ponyta,rapidash,slowpoke,slowbro,magnemite,magneton,farfetchd,doduo,dodrio,seel,dewgong,grimer,muk,shellder,cloyster,gastly,haunter,gengar,onix,drowzee,hypno,krabby,kingler,voltorb,electrode,exeggcute,exeggutor,cubone,marowak,hitmonlee,hitmonchan,lickitung,koffing,weezing,rhyhorn,rhydon,chansey,tangela,kangaskhan,horsea,seadra,goldeen,seaking,staryu,starmie,mr.mime,scyther,jynx,electabuzz,magmar,pinsir,tauros,magikarp,gyarados,lapras,ditto,eevee,vaporeon,jolteon,flareon,porygon,omanyte,omastar,kabuto,kabutops,aerodactyl,snorlax,articuno,zapdos,moltres,dratini,dragonair,dragonite,mewtwo,mew"

local COLORS = "a0e058f85030a0e058f8c04890c858f8b018f8c030f88010f8a878b84868a078a840a87068b84088c8f068b8409098f870a8388080a0d8c030f86088e09868c07000f878b878f800b8d828d038e8a0d82068883888a0684038d8f0e060a09840a89828987028f8a070788810b0b898a08868b8c878d08018f0d000c06808808050c08838a0b868485828909858a050f0f88800a01058a898a0c09810808050584078809020a83008d888e0288808f888f0307850f880f858684090a8f8884078a0b8f8b820c86888f87848b8f868c8409000f868c8409000f8c008b08008d8b0c88888b8f888f848c018f888f848c018d878f0508830e86098387800f8d020409058f8a828688860f8a818407868d89818706808f8a8489080287088f85828b08078f88830a89858206030d89858206030d8f8b060d01090f8e050e048d8a898f85058a0e050683888f098b058a08038b88830808030b8a038a86800c08878988808d040884040e84880d04050f858c0d0408878e0c050a04898e0c050a04898989818a810a87870583040487080583830c8708858486020a0a038a050a8b0e038984898a0b8187060f89898f840986888a0f828a000c08878786838b87060805838c87860983818b89880986860b098a08850d8b058d08800f8a850f890900098a098a03838788090905858a0807060a008e0b800908000f8c008908000a098b0e83828a098a090587080980858505078a048506818c08838a84820a060e05820f88088f02838585048d8400098f800e87860b878a820705838c068d8900050f048c8905068a8a0b0907820a8b048606858a0a0884810e0a0a0884810e0b8c830986048988840c07048b0b0b858784890a87870782088a8286840688088604018f8c0b048e0487080a0c84860b880a0c84860b8b07888785868b0a8a8606088d8c89868980890f000883030808098185818f860c06078f8f858d85020e8e89800f07000a8d890d0b0109080984068f0e848585858f8f858f888980088c000e04800701078f848d8f8c80090a000f870f0c02070b8b848585878f0d870487050c8c000808000c8a040d85028f868f88058f888b0e04860d89898a8607068d8a8f87850c0c8b000787830f08808c048007018d86058c8b89850605858c8e010605878b8c0a070905098a058507850b048b86048a8d8b0584838f898d0f86868b0f89800f82000f85870a80800a898c07058c0a898f8a078f888987098007098a8b078780090c0f83858d0"

local function byte(offset)
  return assert(tonumber(COLORS:sub(offset, offset + 1), 16))
end

return function(ctx)
  local index = 0
  for stem in STEMS:gmatch("[^,]+") do
    index = index + 1
    local offset = (index - 1) * 12 + 1
    local shades = {
      { 248, 248, 248 },
      { byte(offset), byte(offset + 2), byte(offset + 4) },
      { byte(offset + 6), byte(offset + 8), byte(offset + 10) },
      { 0, 0, 0 },
    }
    for _, rel in ipairs({
      "battle/front/" .. stem .. ".png",
      "battle/back/" .. stem .. "b.png",
    }) do
      if ctx.exists(rel) then
        -- Headless Modkit fixtures expose placeholder asset paths without a
        -- LOVE image backend. A failed decode is therefore "not installed",
        -- not a broken gameplay mod.
        local ok, image = pcall(ctx.readImage, rel)
        if ok and image then
          ctx.writeImage(ctx.recolor(image, shades), "shiny/" .. rel)
        end
      end
    end
  end
  -- Extended Characters uses the player's local imported cache for the
  -- handful of authentic baseline portraits.  These are recipes, not shipped
  -- ROM pixels: the files live under save/mod-derived/kanto_ascendant/.
  local characterSources = {
    ["battle/redb.png"] = "characters/red_back.png",
    ["trainer_card/red.png"] = "characters/red_front.png",
    ["battle/trainers/rival1.png"] = "characters/blue_rival.png",
    ["battle/trainers/cooltrainerf.png"] = "characters/green_rival_fallback.png",
  }
  for source, target in pairs(characterSources) do
    if ctx.exists(source) then
      local ok, image = pcall(ctx.readImage, source)
      if ok and image then ctx.writeImage(image, target) end
    end
  end
  assert(index == 151, "expected all 151 Gen I shiny palettes")

  -- The integrated QoL caught marker belongs to this mod's derived cache.
  -- Build it from the player's imported party-ball sheet, just as the
  -- standalone QoL mod does, without shipping ROM-derived pixels.
  if ctx.exists("battle/balls.png") then
    local ok, source = pcall(ctx.readImage, "battle/balls.png")
    if ok and source then
      local ball = ctx.blank(8, 8)
      ctx.blit(ball, source, 0, 0, 0, 0, 8, 8)
      ctx.writeImage(ball, "ui/ball.png")
    end
  end

  -- Hidden Evolution uses a few small field-object details
  -- derived from the player's imported Kanto cache.  They deliberately land
  -- in the mod-derived cache (and are addressed through assets/generated/ at
  -- runtime), so the package never contains ROM-near pixels.  Strength now
  -- uses the engine's native boulder directly.  The relic is a transparent
  -- authored rune and the sealed door is authored as a transparent field
  -- object. The fissure keeps the approved crack but adds a broken stone rim:
  -- the old 15-pixel hairline vanished on the dark side of a FULL voxel wall.
  local function read(rel)
    if not ctx.exists(rel) then return nil end
    local ok, image = pcall(ctx.readImage, rel)
    return ok and image or nil
  end
  -- The vanilla talk target remains present but is never entrance art. A
  -- real transparent frame keeps the 2D fallback honest; the voxel renderer
  -- additionally omits renderMode="none" entities entirely.
  -- The plain-Lua SDK deliberately has no `love.image` backend.  Keep the
  -- transform loadable there (all gameplay records can still be validated),
  -- while real LÖVE imports author the transparent anchor and wall art.
  -- The transform sandbox intentionally does not expose the global `love`
  -- table even in a real game. Probe the provided image API itself: it
  -- succeeds in LÖVE and fails harmlessly in the plain-Lua SDK fixture.
  local canAuthorImages, transparentAnchor = pcall(ctx.blank, 16, 16)
  canAuthorImages = canAuthorImages and transparentAnchor ~= nil
  if canAuthorImages then
    ctx.writeImage(transparentAnchor, "hidden_evolution/interaction_anchor.png")
  end

  -- The question statues use the standard Gen-I gym monster carving from
  -- the player's imported GYM tileset.  Keep it separate from the authored
  -- yellow relic: the latter is a floor light, while this is a tangible
  -- one-cell talk target.  The native carving is assembled from four 8x8
  -- tiles rather than copied as a rectangular atlas crop:
  --
  --     $02 $38
  --     $12 $13
  --
  -- Its plinth ($22/$23/$32/$33) deliberately stays out of the sprite.  A
  -- 16x32 object is not a portable contract: the engine SpriteRenderer and
  -- the supported voxel billboard renderers all select 16x16 frames.
  local gym = canAuthorImages and read("tilesets/gym.png") or nil
  if gym and type(gym.getDimensions) == "function" then
    local dimensionsOk, gymWidth, gymHeight = pcall(gym.getDimensions, gym)
    if dimensionsOk and gymWidth >= 128 and gymHeight >= 32 then
      local statue = ctx.blank(16, 16)
      local tiles = {
        { 0x02, 0, 0 }, { 0x38, 8, 0 },
        { 0x12, 0, 8 }, { 0x13, 8, 8 },
      }
      for _, tile in ipairs(tiles) do
        local id, targetX, targetY = tile[1], tile[2], tile[3]
        local sourceX = id % 16 * 8
        local sourceY = math.floor(id / 16) * 8
        ctx.blit(statue, gym, targetX, targetY, sourceX, sourceY, 8, 8)
      end

      -- The imported atlas is fully opaque.  Remove only background which
      -- can actually reach the outside of the assembled cell.  Edge shades
      -- vote for the possible ground colors; black is always a boundary.
      -- This preserves white/grey detail enclosed by the statue outline and
      -- avoids both an opaque 16x16 sticker and a destructive white key.
      local classes, background = {}, {}
      local function shadeClass(x, y)
        local r, g, b, a = statue:getPixel(x, y)
        if a == 0 then return "off" end
        local value = math.min(r, g, b)
        if value <= 0.17 then return "black" end
        if value <= 0.50 then return "dark" end
        if value <= 0.83 then return "light" end
        return "white"
      end
      for y = 0, 15 do
        for x = 0, 15 do classes[y * 16 + x] = shadeClass(x, y) end
      end
      local function vote(x, y)
        local class = classes[y * 16 + x]
        if class ~= "black" and class ~= "off" then background[class] = true end
      end
      for x = 0, 15 do vote(x, 0); vote(x, 15) end
      for y = 0, 15 do vote(0, y); vote(15, y) end

      local queueX, queueY, flooded, head = {}, {}, {}, 1
      local function seed(x, y)
        if x < 0 or x > 15 or y < 0 or y > 15 then return end
        local index = y * 16 + x
        if flooded[index] then return end
        local class = classes[index]
        if class == "off" or (class ~= "black" and background[class]) then
          flooded[index] = true
          queueX[#queueX + 1], queueY[#queueY + 1] = x, y
        end
      end
      for x = 0, 15 do seed(x, 0); seed(x, 15) end
      for y = 0, 15 do seed(0, y); seed(15, y) end
      while head <= #queueX do
        local x, y = queueX[head], queueY[head]
        head = head + 1
        if x > 0 then seed(x - 1, y) end
        if x < 15 then seed(x + 1, y) end
        if y > 0 then seed(x, y - 1) end
        if y < 15 then seed(x, y + 1) end
      end
      for index in pairs(flooded) do
        local x, y = index % 16, math.floor(index / 16)
        statue:setPixel(x, y, 0, 0, 0, 0)
      end
      ctx.writeImage(statue, "hidden_evolution/quiz_statue.png")
    end
  end

  local cavern = canAuthorImages and read("tilesets/cavern.png") or nil
  if cavern then
    -- A field object must not carry an opaque metatile-sized background: the
    -- rejected version read as a brown 16x16 sticker in the real renderer.
    -- Draw a compact standing tablet on transparency instead.  Coordinates
    -- are intentionally asymmetric so it reads as hand-cut Gen-I pixel art.
    local relic = ctx.blank(16, 16)
    local palette = {
      edge={28/255,22/255,26/255}, stone={92/255,72/255,62/255},
      light={170/255,137/255,91/255}, rune={238/255,198/255,91/255},
    }
    local function dot(x,y,color)
      local c=palette[color];relic:setPixel(x,y,c[1],c[2],c[3],1)
    end
    local outline={
      {6,2},{7,2},{8,2},{9,2},{5,3},{10,3},
      {4,4},{11,4},{4,5},{11,5},{4,6},{11,6},{4,7},{11,7},
      {4,8},{11,8},{4,9},{11,9},{4,10},{11,10},{5,11},{10,11},
      {5,12},{6,12},{9,12},{10,12},{6,13},{7,13},{8,13},{9,13},
    }
    for _,p in ipairs(outline) do dot(p[1],p[2],"edge") end
    for y=3,11 do
      local left,right=(y==3 and 6 or 5),(y==3 and 9 or 10)
      for x=left,right do dot(x,y,(x==left or y==3) and "light" or "stone") end
    end
    for _,p in ipairs({{8,4},{7,5},{8,5},{9,5},{8,6},{8,7},{7,8},{8,8},
                       {9,8},{8,9},{8,10}}) do dot(p[1],p[2],"rune") end
    ctx.writeImage(relic, "hidden_evolution/gen2_relic.png")

    -- Core geometry derived from the accepted Map-Studio
    -- references wall_crack_1.png and sealed_fissure_reference.png. Those two
    -- source files (not this tone-adapted output) share SHA-256
    -- 30a1e6126cb21378460c2f90ba0c4aff28d004f0c359eed5d44a97db6df3306e.
    -- Keep the whole readable mark inside the native eight-pixel south-wall
    -- face.  The former compact opening technically rendered, but its
    -- 48-pixel silhouette disappeared inside the alternating black/white
    -- Route-rock pattern.  This broader star fracture has a continuous dark
    -- recess, a cool broken-stone edge and selective pale glints.  Its two
    -- separated lower branches read as a crack instead of a doorway, while
    -- the transparent gaps keep it wall art (never a billboard, plaque or
    -- replacement metatile).
    local fissure = ctx.blank(16, 16)
    local core = {
      {7,0},{8,0},
      {6,1},{7,1},{8,1},
      {3,2},{4,2},{5,2},{6,2},{7,2},{8,2},{9,2},
      {3,3},{4,3},{6,3},{7,3},{8,3},{9,3},
      {5,4},{6,4},{7,4},{8,4},{9,4},{10,4},{11,4},
      {6,5},{7,5},{11,5},{12,5},
      {5,6},{6,6},{7,6},
      {4,7},{5,7},{6,7},
    }
    local rim = {
      {6,0},{9,0},{5,1},{9,1},{2,2},{10,2},
      {2,3},{5,3},{10,3},{4,4},{12,4},
      {5,5},{8,5},{10,5},{13,5},
      {4,6},{8,6},{3,7},{7,7},
    }
    local glint = {
      {5,0},{4,1},{10,1},{1,2},{11,2},{1,3},{11,3},
      {3,4},{13,4},{4,5},{14,5},{3,6},{9,6},{2,7},{8,7},
    }
    for _, point in ipairs(rim) do
      fissure:setPixel(point[1], point[2], 112 / 255, 142 / 255,
                       148 / 255, 1)
    end
    for _, point in ipairs(glint) do
      fissure:setPixel(point[1], point[2], 218 / 255, 232 / 255,
                       222 / 255, 1)
    end
    for _, point in ipairs(core) do
      fissure:setPixel(point[1], point[2], 8 / 255, 8 / 255, 10 / 255, 1)
    end
    ctx.writeImage(fissure, "hidden_evolution/sealed_fissure.png")

    -- A copied CAVERN metatile read as another pale boulder rather than the
    -- promised black door.  Keep the stable one-cell object contract, but
    -- author an unmistakable arched doorway on real transparency.  Its tiny
    -- red/blue/green tri-seal identifies the three completed paths without
    -- turning the object into a glowing marker.  This is deliberately a new
    -- derived sprite: no player, follower, item-ball or native ROM sheet is
    -- overwritten.
    local door = ctx.blank(16, 16)
    local doorPalette = {
      outline = { 8 / 255, 10 / 255, 14 / 255 },
      frameDark = { 34 / 255, 42 / 255, 46 / 255 },
      frame = { 68 / 255, 78 / 255, 78 / 255 },
      highlight = { 132 / 255, 142 / 255, 130 / 255 },
      recess = { 12 / 255, 14 / 255, 18 / 255 },
      panel = { 24 / 255, 28 / 255, 32 / 255 },
      threshold = { 86 / 255, 92 / 255, 84 / 255 },
      red = { 190 / 255, 54 / 255, 48 / 255 },
      blue = { 48 / 255, 90 / 255, 190 / 255 },
      green = { 54 / 255, 150 / 255, 72 / 255 },
    }
    local function doorDot(x, y, color)
      local c = doorPalette[color]
      door:setPixel(x, y, c[1], c[2], c[3], 1)
    end
    local function doorFill(x1, y1, x2, y2, color)
      for y = y1, y2 do
        for x = x1, x2 do doorDot(x, y, color) end
      end
    end

    -- Outer arch and threshold.  Transparent corners keep both the flat and
    -- DRAMALESS billboard paths free of a rectangular sticker/halo.
    doorFill(5, 0, 10, 0, "outline")
    doorFill(3, 1, 12, 1, "outline")
    doorFill(2, 2, 13, 2, "outline")
    doorFill(1, 3, 14, 14, "outline")
    doorFill(2, 15, 13, 15, "outline")
    doorFill(5, 1, 10, 1, "highlight")
    doorFill(3, 2, 12, 2, "frame")
    doorFill(2, 3, 13, 13, "frameDark")
    doorFill(2, 14, 13, 14, "threshold")

    -- Deep arched opening, two restrained door panels and masonry jambs.
    doorFill(6, 2, 9, 2, "recess")
    doorFill(4, 3, 11, 3, "recess")
    doorFill(3, 4, 12, 13, "recess")
    doorFill(5, 5, 7, 12, "panel")
    doorFill(9, 5, 11, 12, "panel")
    doorFill(4, 10, 11, 10, "frameDark")
    for y = 4, 13 do
      doorDot(2, y, y % 3 == 1 and "highlight" or "frame")
      doorDot(13, y, y % 3 == 0 and "frame" or "frameDark")
    end
    for _, point in ipairs({
      { 7, 7, "red" }, { 6, 8, "blue" }, { 8, 8, "green" },
    }) do doorDot(point[1], point[2], point[3]) end
    ctx.writeImage(door, "hidden_evolution/sealed_future_door.png")
  end

end
