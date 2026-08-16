-- Focused acceptance proof for GREEN's native-Kanto woodland trial.
-- Run from gen1recomp with KA_HIDDEN_EVOLUTION_MOD set to this worktree.
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local Data = require("src.core.Data")
local Map = require("src.world.Map")
Data:load()

local root = assert(os.getenv("KA_HIDDEN_EVOLUTION_MOD"),
  "KA_HIDDEN_EVOLUTION_MOD is required")
local sourcePath = root .. "/hidden_evolution_green_grove.lua"
local factory = assert(loadfile(sourcePath))()
local forest = assert(Data.tilesets.FOREST, "engine data provides native FOREST")
local blockCount = #forest.blocks
local warpSignature = table.concat(forest.warpTiles or {}, ",")
local requestedTilesets, registeredMaps, registeredScripts = {}, {}, {}
local atmosphere, enteredHandler, lastWarp, lastReplacement

local function registry(write)
  return { register = function(_, id, value) write(id, value) end }
end

local currentMapId = "KA_HEVO_GREEN_GROVE"
local mod = {
  content = {
    tilesets = { get = function(_, id)
      requestedTilesets[#requestedTilesets + 1] = id
      return Data.tilesets[id]
    end },
    maps = registry(function(id, value) registeredMaps[id] = value end),
    map_songs = registry(function() end),
    field = { patch = function(_, id, value)
      T.eq(id, "mapAtmospheres", "GREEN patches the engine atmosphere registry")
      atmosphere = value
    end },
    text = registry(function() end),
    text_pointers = { patch = function() end },
    map_scripts = registry(function(id, value) registeredScripts[id] = value end),
  },
  exports = {},
  events = { on = function(_, id, handler)
    T.eq(id, "map.entered", "GREEN restores gates on map entry")
    enteredHandler = handler
  end },
  world = {
    current = function() return nil end,
    overworld = function() return { map = { id = currentMapId } } end,
    warpTo = function(_, mapId, x, y, facing, options)
      lastWarp = { mapId = mapId, x = x, y = y, facing = facing }
      if options and options.onDone then options.onDone() end
    end,
    replaceBlock = function(_, x, y, block)
      lastReplacement = { x = x, y = y, block = block }
    end,
  },
}

local function copy(value)
  if type(value) ~= "table" then return value end
  local out = {}
  for key, child in pairs(value) do out[copy(key)] = copy(child) end
  return out
end

local finalized, claimed, persistedAtFinalize
local green = factory(mod, {
  activeCharacter = function() return "GREEN" end,
  showText = function(_, _, done) if done then done() end end,
  legacyDungeonAdapter = {
    finalize = function(game, payload)
      finalized = payload
      local run = game.save.hevo_run
      run.dungeonLegacy = run.dungeonLegacy or { seals = {}, reentered = {} }
      run.dungeonLegacy.seals.GREEN = true
      -- Match the real adapter's durable boundary: the authority seal is
      -- saved before G.complete writes its local presentation marker.
      persistedAtFinalize = copy(run)
      return true
    end,
    claimSecret = function(_, payload) claimed = payload return true end,
  },
})
local floorLightFactory=assert(loadfile(root.."/hidden_evolution_floor_lights.lua"))()
local floorLightCatalog=floorLightFactory({id="kanto_ascendant"},{routes={}})

local sourceFile = assert(io.open(sourcePath, "rb"))
local source = sourceFile:read("*a")
sourceFile:close()
local e2eSourceFile = assert(io.open(
  root .. "/tools/hidden_evolution_green_input_e2e.lua", "rb"))
local e2eSource = e2eSourceFile:read("*a")
e2eSourceFile:close()
local visualSourceFile = assert(io.open(
  root .. "/tools/hidden_evolution_green_visual_gate.lua", "rb"))
local visualSource = visualSourceFile:read("*a")
visualSourceFile:close()
T.check(not source:find("KA_HEVO_G2_FOREST", 1, true),
  "GREEN has no Crystal/custom forest dependency")
T.check(source:find('ow:partyKnows("CUT")',1,true)~=nil,
  "living roots use the running Overworld field-move eligibility path")
T.check(source:find("useCutFieldMove",1,true)==nil,
  "living roots do not invoke the vanilla cut-tree action on a custom gate")
T.check(source:find("queueWorldPostOverlay",1,true)~=nil,
  "GREEN queues one final fog mask after flat/Voxel sprites and before UI")
T.check(source:find("fogRadius - fogEdgePixels",1,true)~=nil
    and source:find("fogRadius,",1,true)~=nil,
  "GREEN completes one narrow visibility boundary inside the authored radius")
T.check(green.FOG_EDGE_SCREEN_PIXELS<=2,
  "GREEN's inner-to-outer alpha transition is at most two screen pixels")
T.eq(green.FOG_OUTER_ALPHA,1,
  "GREEN's exterior visibility mask is mathematically opaque")
for channel=1,3 do
  T.eq(green.FOG_OUTER_COLOR[channel],30/255,
    "GREEN exterior channel "..channel.." is the exact neutral dark gray")
end
T.check(green.FOG_OUTER_PIXEL_TOLERANCE<=2/255,
  "GREEN exterior runtime comparison uses a tight pixel tolerance")
T.check(source:find("fogOuterColor",1,true)~=nil
    and source:find("mix(innerFog, vec4(fogOuterColor, 1.0), edge)",1,true)~=nil
    and source:find("haze * fogMotionAlpha * (1.0 - edge)",1,true)~=nil,
  "GREEN shader makes the exterior constant/opaque and confines moving wisps to the aperture")
T.check(source:find("extern number fogOpacity",1,true)==nil,
  "GREEN shader cannot accidentally restore a translucent authored exterior")
T.check(source:find('contract="OPAQUE_OUTER_V1"',1,true)~=nil
    and source:find('blendMode="alpha/alphamultiply"',1,true)~=nil
    and source:find('textureSampled=false',1,true)~=nil
    and source:find("Texel(",1,true)==nil,
  "GREEN records an explicit opaque/no-texture/final-blend renderer contract")
T.check(source:find('voxelRenderer.module(game,"Voxel3D")',1,true)~=nil
    and source:find('voxelRenderer.module(game,"AntiAlias")',1,true)~=nil
    and source:find('voxelRenderer.module(game,"VoxelScene")',1,true)~=nil
    and source:find('voxelRenderer.module(game,"VoxelState")',1,true)~=nil,
  "Voxel fog derives the same card lean, terrain height, camera and AA canvas as DRAMALESS")
local uprightX,uprightY,uprightZ=green.voxelUprightMidpoint(
  100,200,0,math.rad(35),0)
T.eq(uprightX,108,
  "DRAMALESS upright midpoint remains centred across the 16-pixel card")
T.check(math.abs(uprightY-8*math.sin(math.rad(35)))<0.000001
    and math.abs(uprightZ-(208-8*math.cos(math.rad(35))))<0.000001,
  "FULL midpoint applies the billboard's exact pivot-at-feet lean transform")
local _,firstPersonY,firstPersonZ=green.voxelUprightMidpoint(100,200,3,
  math.rad(75),1)
T.check(firstPersonY==11 and firstPersonZ==208,
  "free-camera midpoint becomes the true upright centre above its terrain")
T.check(source:find("centerX,centerY=ctx.centerX",1,true)==nil,
  "Voxel fog never falls back to the offset generic pipeline centre")
T.check(source:find("_kaGreenFogBaseWorldPresent",1,true)==nil
    and source:find("drawVoxelFog",1,true)==nil,
  "GREEN has no duplicate pre-composite worldPresent fog path")
T.check(source:find("fogWispSamples",1,true)==nil
    and source:find("sample.w",1,true)==nil,
  "final GREEN fog has no post-composite pixel-sample grid around sprites")
T.check(e2eSource:find('log("shot-receipt",name,mapId',1,true)~=nil,
  "full GREEN Voxel QA records a fresh renderer receipt for every screenshot")
T.check(e2eSource:find('voxelReceipt.pipeline=="voxel"',1,true)~=nil
    and e2eSource:find('postWorldPresent=true',1,true)~=nil,
  "full Voxel QA rejects transient flat fallback frames on all maps")
T.check(e2eSource:find('green.layouts[mapId].voxelMode=="FULL"',1,true)~=nil,
  "every GREEN Voxel screenshot proves terrain-derived FULL mode")
T.check(e2eSource:find(
    'fogReceipt.projection=="DRAMALESS_UPRIGHT_MIDPOINT"',1,true)~=nil
    and e2eSource:find('fogReceipt.postComposite',1,true)~=nil,
  "every GREEN Voxel screenshot proves final upright post-composite fog")
T.check(e2eSource:find('or "GENERAL"',1,true)~=nil,
  "Route 3/shared screenshots retain explicit general worldPresent receipts")
for _,driverSource in ipairs({visualSource,e2eSource}) do
  T.check(driverSource:find("love.image.newImageData",1,true)~=nil
      and driverSource:find("love.filesystem.newFileData",1,true)~=nil
      and driverSource:find("evidence.outerSamples",1,true)~=nil
      and driverSource:find("#evidence.outerSamples>=8",1,true)~=nil
      and driverSource:find("a>=1-1/255",1,true)~=nil,
    "every GREEN visual driver samples real PNG exterior RGB/alpha")
  T.check(driverSource:find("differs between unrelated scene samples",1,true)~=nil,
    "every GREEN visual driver rejects scene-dependent exterior pixels")
  T.check(driverSource:find("samples are not byte-identical",1,true)~=nil
      and driverSource:find("not a neutral dark gray",1,true)~=nil,
    "every GREEN visual driver requires byte-identical neutral dark pixels")
end
T.check(visualSource:find('GREEN_QA_OPAQUE_ONLY',1,true)~=nil
    and visualSource:find('sight0/3/5 exact exterior pixels',1,true)~=nil,
  "targeted GREEN renderer gate covers opaque exteriors at sight 0/3/5")
T.check(visualSource:find('green.layouts[mapId].voxelMode=="FULL"',1,true)~=nil
    and visualSource:find('"voxelMode="',1,true)~=nil,
  "targeted GREEN Voxel receipts prove terrain-derived FULL mode")

local valid, why = green.validateForest(forest)
T.check(valid, why or "native FOREST roles validate")
green.register()
T.eq(#requestedTilesets, 1, "GREEN resolves one terrain tileset")
T.eq(requestedTilesets[1], "FOREST", "GREEN resolves native Viridian Forest")
T.eq(#forest.blocks, blockCount, "registration does not append custom metatiles")
T.eq(table.concat(forest.warpTiles or {}, ","), warpSignature,
  "registration does not mutate native warp semantics")

local nativeBlocks = {}
for _, id in pairs(green.FOREST_BLOCKS) do nativeBlocks[id] = true end
for id in pairs(green.FOREST_SHAPED_BLOCKS) do nativeBlocks[id] = true end
local solvedEntryExit = {
  [green.IDS.threshold]=98,
  [green.IDS.grove]=114,
  [green.IDS.mist]=96,
  [green.IDS.shrine]=116,
}
local function exitFor(id)
  return assert(green.FORWARD_WARPS[id],id.." has no authored forward door")
end
for _, id in pairs(green.IDS) do
  local def = assert(registeredMaps[id], id .. " is registered")
  T.eq(def.width,30,id .. " retains the full 30-block / 60-cell width")
  T.eq(def.height,20,id .. " retains the full 20-block / 40-cell height")
  T.eq(def.tileset, "FOREST", id .. " uses native FOREST")
  T.eq(def.sourceTileset, "FOREST", id .. " retains native voxel provenance")
  T.eq(def.voxelMode, "FULL", id .. " uses terrain-derived full voxel mode")
  T.eq(def.outdoor, false, id .. " remains an indoor trial")
  T.eq(def.voxelCells, nil, id .. " has no positional voxel wallpaper")
  T.eq(def.voxelSurfaceCells, nil, id .. " has no custom voxel surface layer")
  T.eq(def.fog, nil, id .. "does not carry inert map-local fog metadata")
  local relicCount=0
  for _,object in ipairs(def.objects or {}) do
    local isStatue=object.name:find("KA_GREEN_STATUE_",1,true)==1
    if isStatue then
      relicCount=relicCount+1
      T.eq(object.sprite,"SPRITE_KA_HEVO_QUIZ_STATUE",
        id .. " " .. object.name .. " uses the quiz-statue silhouette")
      T.eq(object.semanticRole,"quiz_statue",
        id .. " " .. object.name .. " exposes the quiz-statue role")
    else
      T.check(object.sprite~="SPRITE_KA_HEVO_QUIZ_STATUE"
          and object.semanticRole~="quiz_statue",
        id .. " " .. object.name .. " cannot masquerade as another statue")
    end
    if object.name=="KA_GREEN_INTERNAL_CUT"
        or object.name=="KA_GREEN_CANOPY_GATE" then
      T.eq(object.renderMode,"none",
        id .. " " .. object.name .. " is an invisible map-root anchor")
      T.eq(object.passable,true,
        id .. " " .. object.name .. " does not add a hidden collision wall")
      T.eq(object.sprite,"SPRITE_KA_HEVO_FISSURE_ANCHOR",
        id .. " " .. object.name .. " reuses the transparent anchor asset")
    end
  end
  T.eq(relicCount,id==green.IDS.grove and 2 or id==green.IDS.mist and 3 or 0,
    id .. " exposes exactly its authored number of statue-like relics")
  for _, block in ipairs(def.blocks) do
    T.check(nativeBlocks[block] == true,
      id .. " uses only audited native FOREST block roles")
  end
  local shaped, fullyOpen = 0, 0
  for _, block in ipairs(def.blocks) do
    if green.FOREST_SHAPED_BLOCKS[block] then shaped = shaped + 1 end
    if block == green.FOREST_BLOCKS.FLOOR
        or block == green.FOREST_BLOCKS.PLAIN
        or block == green.FOREST_BLOCKS.GRASS then fullyOpen = fullyOpen + 1 end
  end
  T.check(shaped >= 70,
    id .. " builds its route from native one-cell collision silhouettes")
  T.check(fullyOpen <= 3,
    id .. " reserves 2x2 openings for three staggered landmark pockets")
  local metrics = green.topologyMetrics(id)
  T.check(metrics.nodes >= 150 and metrics.nodes <= 280,
    id .. " is a long cell-authored route, not an open room")
  T.check(metrics.loops >= 7, id .. " has disorienting but recoverable loops")
  local denseDecoyFloor=id==green.IDS.grove or id==green.IDS.mist
  T.check(metrics.decisions >= (denseDecoyFloor and 24 or 15),
    id .. " retains frequent real graph decisions")
  T.check(metrics.deadends >= (denseDecoyFloor and 10 or 5),
    id .. " has the required landmark-bearing dead ends")
  T.check(metrics.pathLength and metrics.pathLength >= 90,
    id .. " is not a direct lower-left-to-upper-right walk")
  T.eq(metrics.pathLength,solvedEntryExit[id],
    id .. " solved entry-to-exit distance cannot silently shorten")
  local feedbackCells = {}
  for _, object in ipairs(def.objects) do
    feedbackCells[object.x .. ":" .. object.y] = object.name
  end
  local lightFloor=floorLightCatalog.byMap[id]
  for _,stone in ipairs(lightFloor and lightFloor.stones or {}) do
    feedbackCells[stone.x..":"..stone.y]=stone.name
  end
  local feedbackEnds = 0
  local legacyExitEnds = {
    [green.IDS.threshold]={["57:3"]=true},
    [green.IDS.mist]={["57:3"]=true},
  }
  local function degree(x,y)
    local n=0
    for _,delta in ipairs({{1,0},{-1,0},{0,1},{0,-1}}) do
      if green.cellIsOpen(id,x+delta[1],y+delta[2],true) then n=n+1 end
    end
    return n
  end
  local function distance(sx,sy,tx,ty)
    local queue,seen,cursor={{sx,sy}},{[sx..":"..sy]=0},1
    while queue[cursor] do
      local x,y=queue[cursor][1],queue[cursor][2]
      local value=seen[x..":"..y]
      if x==tx and y==ty then return value end
      for _,delta in ipairs({{1,0},{-1,0},{0,1},{0,-1}}) do
        local nx,ny=x+delta[1],y+delta[2];local key=nx..":"..ny
        if green.cellIsOpen(id,nx,ny,true) and seen[key]==nil then
          seen[key]=value+1;queue[#queue+1]={nx,ny}
        end
      end
      cursor=cursor+1
    end
  end
  local statueEnds=0
  for _,object in ipairs(def.objects) do
    if object.name:find("KA_GREEN_STATUE_",1,true)==1 then
      statueEnds=statueEnds+1
      T.eq(degree(object.x,object.y),1,
        id .. " " .. object.name .. " occupies a true remote alcove end")
      local px,py=object.x,object.y
      local x,y,depth
      for _,delta in ipairs({{1,0},{-1,0},{0,1},{0,-1}}) do
        local nx,ny=object.x+delta[1],object.y+delta[2]
        if nx and green.cellIsOpen(id,nx,ny,true) then x,y,depth=nx,ny,1;break end
      end
      while x and degree(x,y)==2 do
        local nextX,nextY
        for _,delta in ipairs({{1,0},{-1,0},{0,1},{0,-1}}) do
          local nx,ny=x+delta[1],y+delta[2]
          if green.cellIsOpen(id,nx,ny,true) and not (nx==px and ny==py) then
            nextX,nextY=nx,ny;break
          end
        end
        px,py=x,y;x,y=nextX,nextY;depth=depth+1
      end
      T.check(depth and depth>=8,
        id .. " " .. object.name .. " is at least eight cells behind its fork")
      T.check(x and degree(x,y)>=3,
        id .. " " .. object.name .. " rejoins at a real decision junction")
      T.eq(distance(object.x,object.y,x,y),depth,
        id .. " " .. object.name .. " has an unbroken return trail")
      local entryTo=assert(distance(3,37,object.x,object.y))
      local exit=exitFor(id)
      local toExit=assert(distance(object.x,object.y,exit.x,exit.y))
      T.check(entryTo+toExit>=metrics.pathLength+depth*2,
        id .. " " .. object.name .. " cannot lie on the mandatory spine")
    end
  end
  T.eq(statueEnds,id==green.IDS.grove and 2 or id==green.IDS.mist and 3 or 0,
    id .. " keeps the authored statue allocation")
  for y = 0, def.height * 2 - 1 do for x = 0, def.width * 2 - 1 do
    if green.cellIsOpen(id, x, y, true) then
      local cellDegree=degree(x,y)
      local exit=exitFor(id)
      local isDoor = (x == green.WARP_CELLS.entrance.x and y == green.WARP_CELLS.entrance.y)
        or (x == exit.x and y == exit.y)
      local isCheckpoint = x == green.ENTRY_CELL.x and y == green.ENTRY_CELL.y
      if cellDegree == 1 and not isDoor and not isCheckpoint then
        local cell=x..":"..y
        if not (legacyExitEnds[id] and legacyExitEnds[id][cell]) then
          feedbackEnds = feedbackEnds + 1
          T.check(feedbackCells[cell] ~= nil,
            id .. " cell dead end " .. cell .. " ends at explicit feedback")
        end
      end
    end
  end end
  T.check(feedbackEnds >= (denseDecoyFloor and 8 or 1),
    id .. " contains the required deliberate feedback dead ends")
  if denseDecoyFloor then
    T.check(feedbackEnds-statueEnds>=8,
      id .. " keeps eight non-statue false/feedback dead ends")
  end
  if denseDecoyFloor then
    local decoys={}
    for _,object in ipairs(def.objects) do
      if object.name:find("KA_GREEN_DECOY_",1,true)==1 then decoys[#decoys+1]=object end
    end
    T.check(#decoys>=3,id .. " has at least three explicit decoy trails")
    for _,object in ipairs(decoys) do
      T.eq(object.sprite,"SPRITE_POKE_BALL",
        id .. " decoy uses a visible native Gen-I landmark")
      T.eq(degree(object.x,object.y),1,
        id .. " decoy landmark terminates a true dead end")
      local x,y,previous,length=object.x,object.y,nil,0
      while length<100 do
        if previous and degree(x,y)~=2 then break end
        local nextCell
        for _,delta in ipairs({{1,0},{-1,0},{0,1},{0,-1}}) do
          local nx,ny=x+delta[1],y+delta[2]
          if green.cellIsOpen(id,nx,ny,true)
              and (not previous or nx~=previous[1] or ny~=previous[2]) then
            nextCell={nx,ny};break
          end
        end
        if not nextCell then break end
        previous={x,y};x,y=nextCell[1],nextCell[2];length=length+1
      end
      T.check(length>=4,
        id .. " decoy is a consciously walkable trail, not a one-cell nib")
    end
  end
end

local function cloneDef(def, replacements)
  local copy = {}
  for key, value in pairs(def) do copy[key] = value end
  copy.blocks = {}
  for index, block in ipairs(def.blocks) do copy.blocks[index] = block end
  for _, replacement in ipairs(replacements or {}) do
    copy.blocks[replacement.y * def.width + replacement.x + 1] = replacement.block
  end
  return copy
end

local directions = { {1,0}, {-1,0}, {0,1}, {0,-1} }
local function graphDistance(id,sx,sy,tx,ty)
  local queue,seen,cursor={{sx,sy}},{[sx..":"..sy]=0},1
  while queue[cursor] do
    local x,y=queue[cursor][1],queue[cursor][2]
    local value=seen[x..":"..y]
    if x==tx and y==ty then return value end
    for _,delta in ipairs(directions) do
      local nx,ny=x+delta[1],y+delta[2];local key=nx..":"..ny
      if green.cellIsOpen(id,nx,ny,true) and seen[key]==nil then
        seen[key]=value+1;queue[#queue+1]={nx,ny}
      end
    end
    cursor=cursor+1
  end
end
local function graphDistances(id,sx,sy)
  local queue,seen,cursor={{sx,sy}},{[sx..":"..sy]=0},1
  while queue[cursor] do
    local x,y=queue[cursor][1],queue[cursor][2]
    local value=seen[x..":"..y]
    for _,delta in ipairs(directions) do
      local nx,ny=x+delta[1],y+delta[2];local key=nx..":"..ny
      if green.cellIsOpen(id,nx,ny,true) and seen[key]==nil then
        seen[key]=value+1;queue[#queue+1]={nx,ny}
      end
    end
    cursor=cursor+1
  end
  return seen
end
local function objectApproach(id,name)
  local found
  for _,object in ipairs(green.layouts[id].objects) do
    if object.name==name then found=object;break end
  end
  T.check(found~=nil,id .. " has authored object " .. name)
  if not found then return end
  local approaches={}
  for _,delta in ipairs(directions) do
    local x,y=found.x+delta[1],found.y+delta[2]
    if green.cellIsOpen(id,x,y,true) then approaches[#approaches+1]={x,y} end
  end
  T.eq(#approaches,1,id .. " " .. name .. " has one honest interaction approach")
  return approaches[1][1],approaches[1][2]
end
local function statueApproach(id,name)
  return objectApproach(id,name)
end
local function orderedDistance(id,names)
  local x,y=3,37;local total=0
  for _,name in ipairs(names) do
    local tx,ty=statueApproach(id,name)
    local step=assert(graphDistance(id,x,y,tx,ty))
    total=total+step;x,y=tx,ty
  end
  local exit=exitFor(id)
  return total+assert(graphDistance(id,x,y,exit.x,exit.y))
end
local groveMandatory=orderedDistance(green.IDS.grove,{
  "KA_GREEN_STATUE_1","KA_GREEN_STATUE_2",
})
local mistMandatory=orderedDistance(green.IDS.mist,{
  "KA_GREEN_STATUE_3","KA_GREEN_STATUE_4","KA_GREEN_STATUE_5",
})
T.eq(groveMandatory,150,
  "Grove's ordered two-statue traversal remains a 150-step lower bound")
T.eq(mistMandatory,186,
  "Mist's ordered three-statue traversal remains a 186-step lower bound")
local mandatoryAllFloors=solvedEntryExit[green.IDS.threshold]+groveMandatory
  +mistMandatory+solvedEntryExit[green.IDS.shrine]
T.eq(mandatoryAllFloors,550,
  "four GREEN floors plus all five ordered solvers require at least 550 steps")
local s5x,s5y=statueApproach(green.IDS.mist,"KA_GREEN_STATUE_5")
local mistExit=exitFor(green.IDS.mist)
local finalMist=assert(graphDistance(green.IDS.mist,s5x,s5y,
  mistExit.x,mistExit.y))
T.eq(graphDistance(green.IDS.mist,s5x,s5y,29,21),23,
  "statue 5 keeps a twenty-four-cell post-CUT cul-de-sac including its relic cell")
T.eq(finalMist,71,
  "statue 5 approach leaves an exact seventy-one-cell Mist return and exit tail")
T.check(finalMist>50,
  "statue 5 leaves more than fifty real Mist cells before its exit")
T.check(finalMist+solvedEntryExit[green.IDS.shrine]>=160,
  "statue 5 leaves a long Mist tail plus the complete Shrine labyrinth")

local mistStatues={}
for _,object in ipairs(green.layouts[green.IDS.mist].objects) do
  if object.name:find("KA_GREEN_STATUE_",1,true)==1 then
    mistStatues[#mistStatues+1]=object
  end
end
local maximumFogEdge=atmosphere[green.IDS.mist].visibility
  +green.FOG_EDGE_SCREEN_PIXELS/16
for _,reveal in ipairs(atmosphere[green.IDS.mist].revealFlags) do
  maximumFogEdge=math.max(maximumFogEdge,
    reveal.radius+green.FOG_EDGE_SCREEN_PIXELS/16)
end
for left=1,#mistStatues-1 do for right=left+1,#mistStatues do
  local a,b=mistStatues[left],mistStatues[right]
  local dx,dy=a.x-b.x,a.y-b.y
  local separation=math.sqrt(dx*dx+dy*dy)
  T.check(separation>maximumFogEdge,
    a.name.." and "..b.name
      .." remain farther apart than the maximum solved fog feather")
  T.check(separation>14,
    a.name.." and "..b.name
      .." retain an additional screen-proof buffer beyond the fog edge")
end end

-- A graph detour alone cannot hide a relic through a one-cell wall.  Build
-- the exact shortest cells used by the ordered pre-/post-gate itinerary and
-- compare every one against Statue 5's geometric fog circle at the sight
-- stage active on that leg.  This is the regression that the former (21,25)
-- placement failed at the living-root approach (21,23), despite its valid
-- twelve-step graph branch.
local s5Object
for _,object in ipairs(green.layouts[green.IDS.mist].objects) do
  if object.name=="KA_GREEN_STATUE_5" then s5Object=object;break end
end
T.check(s5Object~=nil,"Mist has the fifth statue for geometric visibility proof")
local function fogEdgeAtSight(sight)
  local radius=atmosphere[green.IDS.mist].visibility
  for index=1,sight do
    local reveal=atmosphere[green.IDS.mist].revealFlags[index]
    if reveal and reveal.radius then radius=reveal.radius end
  end
  return radius+green.FOG_EDGE_SCREEN_PIXELS/16
end
local function shortestCells(id,sx,sy,tx,ty)
  local fromStart,fromEnd=graphDistances(id,sx,sy),graphDistances(id,tx,ty)
  local total=assert(fromStart[tx..":"..ty])
  local cells={}
  for key,startDistance in pairs(fromStart) do
    if fromEnd[key] and startDistance+fromEnd[key]==total then
      local x,y=key:match("^(%-?%d+):(%-?%d+)$")
      cells[#cells+1]={tonumber(x),tonumber(y)}
    end
  end
  return cells,total
end
local s3ax,s3ay=statueApproach(green.IDS.mist,"KA_GREEN_STATUE_3")
local s4ax,s4ay=statueApproach(green.IDS.mist,"KA_GREEN_STATUE_4")
local rootX,rootY=objectApproach(green.IDS.mist,"KA_GREEN_INTERNAL_CUT")
local hintX,hintY=objectApproach(green.IDS.mist,"KA_GREEN_SECRET_HINT")
local secretX,secretY=objectApproach(green.IDS.mist,"KA_GREEN_SCEPTILITE_SECRET")
local canopyX,canopyY=objectApproach(green.IDS.mist,"KA_GREEN_CANOPY_GATE")
local visibilityLegs={
  {name="entry to statue 3",sight=2,from={3,37},to={s3ax,s3ay}},
  {name="statue 3 to living roots",sight=3,from={s3ax,s3ay},to={rootX,rootY}},
  {name="living roots to secret hint",sight=3,from={rootX,rootY},to={hintX,hintY}},
  {name="secret hint to Sceptilite",sight=3,from={hintX,hintY},to={secretX,secretY}},
  {name="Sceptilite to statue 4",sight=3,from={secretX,secretY},to={s4ax,s4ay}},
  {name="statue 4 back to the S5 fork",sight=4,from={s4ax,s4ay},to={29,21}},
  {name="post-S5 fork to canopy",sight=5,from={29,21},to={canopyX,canopyY}},
  {name="canopy to Mist exit",sight=5,from={canopyX,canopyY},
    to={mistExit.x,mistExit.y}},
}
local nearestRequiredDistance,nearestRequiredCell=math.huge
for _,leg in ipairs(visibilityLegs) do
  local cells=shortestCells(green.IDS.mist,
    leg.from[1],leg.from[2],leg.to[1],leg.to[2])
  local edge=fogEdgeAtSight(leg.sight)
  for _,cell in ipairs(cells) do
    local dx,dy=s5Object.x-cell[1],s5Object.y-cell[2]
    local separation=math.sqrt(dx*dx+dy*dy)
    if separation<nearestRequiredDistance then
      nearestRequiredDistance=separation
      nearestRequiredCell=cell[1]..":"..cell[2]
    end
    T.check(separation>edge,
      ("Statue 5 stays outside sight %d (%.3f cells) on %s at %d:%d")
        :format(leg.sight,edge,leg.name,cell[1],cell[2]))
  end
end
T.check(nearestRequiredDistance>=14,
  ("Statue 5 keeps a fourteen-cell geometric buffer from every foreign "
    .."required/gate route cell (nearest %s is %.3f)")
    :format(nearestRequiredCell or "missing",nearestRequiredDistance))

local function navigation(id, replacements)
  local def = assert(green.layouts[id])
  local map = Map.new(cloneDef(def, replacements), forest)
  local blocked = {}
  for _, object in ipairs(def.objects or {}) do
    blocked[object.x .. ":" .. object.y] = true
    T.check(map:isWalkableCell(object.x, object.y),
      id .. " object " .. object.name .. " stands on native walkable terrain")
  end
  local start = green.ENTRY_CELL
  local startKey = start.x .. ":" .. start.y
  T.check(map:isWalkableCell(start.x, start.y) and not blocked[startKey],
    id .. " reset/checkpoint cell is safe")
  local queue, seen, cursor = { {start.x, start.y} }, { [startKey] = true }, 1
  while queue[cursor] do
    local x, y = queue[cursor][1], queue[cursor][2]
    for _, delta in ipairs(directions) do
      local nx, ny = x + delta[1], y + delta[2]
      local key = nx .. ":" .. ny
      if map:inBounds(nx, ny) and map:isWalkableCell(nx, ny)
          and not blocked[key] and not seen[key] then
        seen[key] = true
        queue[#queue + 1] = { nx, ny }
      end
    end
    cursor = cursor + 1
  end
  return def, map, seen
end

local function canTalk(seen, object)
  for _, delta in ipairs(directions) do
    if seen[(object.x + delta[1]) .. ":" .. (object.y + delta[2])] then
      return true
    end
  end
  return false
end

local function checkObjects(id, replacements, names)
  local def, map, seen = navigation(id, replacements)
  local wanted = {}
  for _, name in ipairs(names) do wanted[name] = false end
  for _, object in ipairs(def.objects) do
    if wanted[object.name] ~= nil then wanted[object.name] = canTalk(seen, object) end
  end
  for name, reachable in pairs(wanted) do
    T.check(reachable, id .. " keeps " .. name .. " interactable without crossing an NPC")
  end
  return map, seen
end

local function checkDoorCells(id, map)
  local entrance, exit = green.WARP_CELLS.entrance, exitFor(id)
  T.check(map:isWalkableCell(entrance.x, entrance.y)
      and map:isWarpTileCell(entrance.x, entrance.y)
      and map:warpAtCell(entrance.x, entrance.y) ~= nil,
    id .. " entrance uses the live native tree-door cell")
  T.check(map:isWalkableCell(exit.x, exit.y)
      and map:isWarpTileCell(exit.x, exit.y)
      and map:warpAtCell(exit.x, exit.y) ~= nil,
    id .. " exit uses the live native tree-door cell")
end

local thresholdMap, thresholdSeen = checkObjects(green.IDS.threshold, nil, {
  "KA_GREEN_LANDMARK_THRESHOLD", "KA_GREEN_RESET_THRESHOLD", "KA_GREEN_SHORTCUT",
})
checkDoorCells(green.IDS.threshold, thresholdMap)
local thresholdExit=exitFor(green.IDS.threshold)
T.check(thresholdSeen[thresholdExit.x..":"..thresholdExit.y],
  "threshold exit is reachable with every NPC present")

local groveMap, groveSeen = checkObjects(green.IDS.grove, nil, {
  "KA_GREEN_STATUE_1", "KA_GREEN_STATUE_2", "KA_GREEN_MOON_POOL", "KA_GREEN_RESET_GROVE",
  "KA_GREEN_DECOY_GROVE_SPORE", "KA_GREEN_DECOY_GROVE_HUSK",
  "KA_GREEN_DECOY_GROVE_DEW", "KA_GREEN_DECOY_GROVE_THORN",
  "KA_GREEN_DECOY_GROVE_BRAMBLE", "KA_GREEN_DECOY_GROVE_MOSS",
})
checkDoorCells(green.IDS.grove, groveMap)
local groveExit=exitFor(green.IDS.grove)
T.check(groveSeen[groveExit.x..":"..groveExit.y],
  "grove exit is reachable with every NPC present")

local mistMap, mistSeen = checkObjects(green.IDS.mist, nil, {
  "KA_GREEN_STATUE_3", "KA_GREEN_INTERNAL_CUT", "KA_GREEN_RESET_MIST",
  "KA_GREEN_DECOY_MIST_SPORE",
})
checkDoorCells(green.IDS.mist, mistMap)
T.check(not mistSeen[mistExit.x..":"..mistExit.y],
  "living roots prevent bypassing both mist gates")
local rootOpen = { {x=12, y=10, block=green.FOREST_BLOCKS.GATE_PATH} }
local _, mistRootSeen = checkObjects(green.IDS.mist, rootOpen, {
  "KA_GREEN_STATUE_4", "KA_GREEN_STATUE_5", "KA_GREEN_SECRET_HINT",
  "KA_GREEN_SCEPTILITE_SECRET", "KA_GREEN_CANOPY_GATE",
  "KA_GREEN_DECOY_MIST_HUSK", "KA_GREEN_DECOY_MIST_DEW",
})
T.check(not mistRootSeen[mistExit.x..":"..mistExit.y],
  "opening the first roots does not bypass the five-light canopy")
local bothOpen = {
  {x=12, y=10, block=green.FOREST_BLOCKS.GATE_PATH},
  {x=27, y=3, block=green.FOREST_BLOCKS.GATE_PATH},
}
local _, mistOpenMap, mistOpenSeen = navigation(green.IDS.mist, bothOpen)
checkDoorCells(green.IDS.mist, mistOpenMap)
T.check(mistOpenSeen[mistExit.x..":"..mistExit.y],
  "both taught gates open a collision-safe mist exit")
local function setSize(values)local n=0;for _ in pairs(values)do n=n+1 end;return n end
T.eq(setSize(mistSeen),80,
  "closed living roots preserve a substantial pre-CUT labyrinth")
T.eq(setSize(mistRootSeen),251,
  "real CUT opens the authored 171-cell inner labyrinth branch")
T.eq(setSize(mistOpenSeen),267,
  "five lights add the final canopy tail plus six legacy-save safety cells")

local shrineMap, shrineSeen = checkObjects(green.IDS.shrine, nil, {
  "KA_GREEN_RESEARCH_CACHE", "KA_GREEN_RAYQUAZA_SEAL", "KA_GREEN_RESET_SHRINE",
})
checkDoorCells(green.IDS.shrine, shrineMap)
local shrineExit=exitFor(green.IDS.shrine)
T.check(not shrineSeen[shrineExit.x..":"..shrineExit.y],
  "final archive gate cannot be bypassed")
local _, shrineOpenMap, shrineOpenSeen = navigation(green.IDS.shrine, {
  {x=27, y=3, block=green.FOREST_BLOCKS.GATE_PATH},
})
checkDoorCells(green.IDS.shrine, shrineOpenMap)
T.check(shrineOpenSeen[shrineExit.x..":"..shrineExit.y],
  "completion opens the sealed-antechamber route")

T.check(atmosphere ~= nil, "GREEN supplies real mapAtmospheres data")
for _, id in pairs(green.IDS) do
  local fog = assert(atmosphere[id], id .. " has an atmosphere")
  T.eq(fog.effect, "fog", id .. " uses the engine fog renderer")
  T.check(fog.intensity > 0 and fog.opacity > 0 and #fog.revealFlags > 0,
    id .. " fog is visible and save-flag driven")
  T.eq(fog.visibility,1,
    id .. " starts with an integer one-cell Rock-Tunnel sight core")
  T.eq(fog.opacity,1,
    id .. " starts with a fully opaque Rock-Tunnel exterior")
  T.eq(#fog.revealFlags,5,
    id .. " has one permanent fog/radius step for every statue")
  local previousRadius = fog.visibility
  for index, reveal in ipairs(fog.revealFlags) do
    T.eq(reveal.radius,math.floor(reveal.radius),
      id .. " reveal stage " .. index .. " satisfies the integer schema")
    T.check(reveal.radius > previousRadius,
      id .. " reveal stage " .. index .. " expands the permanent sight cone")
    T.eq(reveal.opacity,1,
      id .. " reveal stage " .. index .. " keeps the exterior fully opaque")
    previousRadius = reveal.radius
  end
end
T.check(atmosphere[green.IDS.mist].revealFlags[1].opacity==1
    and atmosphere[green.IDS.mist].revealFlags[3].opacity==1
    and atmosphere[green.IDS.mist].revealFlags[5].opacity==1,
  "outer maze is fully hidden at sight 1, 3 and 5; only radius expands")
T.eq(atmosphere[green.IDS.mist].revealFlags[5].flag,
  "KA_HEVO_GREEN_SIGHT_5", "the fifth statue permanently reveals the deepest fog")
local thickMotion = green.fogMotionProfile(12, 0)
local movedMotion = green.fogMotionProfile(13, 0)
local revealedMotion = green.fogMotionProfile(12, 5)
T.check(thickMotion.alpha > revealedMotion.alpha,
  "broad GREEN wisps thin as permanent sight grows")
T.check(thickMotion.phaseA ~= movedMotion.phaseA
    and thickMotion.phaseB ~= movedMotion.phaseB,
  "GREEN's continuous fog bands move between real-time samples")
T.check(math.abs(thickMotion.phaseA-movedMotion.phaseA)<=0.25
    and math.abs(thickMotion.phaseB-movedMotion.phaseB)<=0.18,
  "GREEN's low-frequency fog motion cannot flash or jump")
T.eq(thickMotion.lowFrequency,true,
  "GREEN marks its final motion field as continuous low-frequency fog")
local fog2d0 = green.fogPresentation(0, "2d")
local fog2d2 = green.fogPresentation(2, "2d")
local fog2d5 = green.fogPresentation(5, "2d")
local fogVoxel = green.fogPresentation(0, "voxel")
T.check(fog2d0.veilAlpha > fog2d2.veilAlpha
    and fog2d2.veilAlpha > fog2d5.veilAlpha,
  "native 2D silhouette veil thins at every permanent reveal stage")
T.eq(fog2d0.veilAlpha,green.fogInnerOpacity(0),
  "2D sight core uses the same nonzero silhouette opacity contract")
T.check(green.fogInnerOpacity(0)>=0.68
    and green.fogInnerOpacity(0)<=0.75
    and green.fogInnerOpacity(5)<=0.18,
  "sight-0 actors are muted silhouettes while sight-5 remains readable")
T.check(fog2d0.motionAlpha > fog2d2.motionAlpha
    and fog2d2.motionAlpha > fog2d5.motionAlpha,
  "bright FOREST receives legible early bands and a calmer sight-5")
T.eq(fogVoxel.veilAlpha, 0,
  "DRAMALESS does not double-apply the native 2D milk veil")
T.eq(green.answerValue({true, false}, 2), false,
  "the visible NO row preserves boolean false instead of falling through to YES")
T.eq(green.answerValue({92, 93}, 2), 93,
  "numeric answer rows preserve their explicit second value")

local emptyGreenSave={hevo_run={cycle=7}}
local emptyGreenRoot=emptyGreenSave.hevo_run
local emptyGreenReport=green.completionProgress(emptyGreenSave)
T.check(emptyGreenReport.statues==0 and not emptyGreenReport.rootgate
    and not emptyGreenReport.canopy and emptyGreenSave.hevo_run==emptyGreenRoot
    and emptyGreenRoot.cycle==7
    and emptyGreenRoot.hidden_evolution_story_campaign==nil
    and emptyGreenSave.flags==nil,
  "GREEN completion report created/reset campaign state or flags")
local reportGreen={sight=3,rootgate=true,canopy=false,
  floorLights={GROVE=true},hiddenMegaCache=true}
local reportCampaign={greenToken="7:GREEN",green=reportGreen}
local reportGreenSave={hevo_run={cycle=7,
  hidden_evolution_story_campaign=reportCampaign}}
local populatedGreenReport=green.completionProgress(reportGreenSave)
T.check(populatedGreenReport.statues==3 and populatedGreenReport.rootgate
    and not populatedGreenReport.canopy
    and populatedGreenReport.floorLights==nil
    and populatedGreenReport.hiddenMegaCache==nil
    and reportGreenSave.hevo_run.hidden_evolution_story_campaign==reportCampaign
    and reportCampaign.green==reportGreen and reportGreenSave.flags==nil,
  "GREEN completion report mutated state or included optional discoveries")
reportGreen.rootgate=false
T.check(not green.completionProgress(reportGreenSave).rootgate,
  "GREEN report masked the missing root gate")
reportGreen.rootgate=true;reportGreen.canopy=false
T.check(not green.completionProgress(reportGreenSave).canopy,
  "GREEN report masked the missing canopy")

local save = { flags = {}, inventory = {}, party = {}, hevo_run = { cycle = 7 } }
local outOfOrder, orderReason = green.answer(save, 2, true)
T.check(not outOfOrder and orderReason == "order", "statue order is taught and enforced")
local first = assert(green.questionFor(save, 1))
local wrong = first.kind == "number" and first.answer + 1000 or not first.answer
local wrongOk, wrongReason = green.answer(save, 1, wrong)
T.check(not wrongOk and wrongReason == "wrong", "wrong answers give retry feedback")
local fresh = assert(green.questionFor(save, 1))
T.neq(fresh.id, first.id, "a wrong answer advances to a fresh question")
T.check(green.answer(save, 1, fresh.answer), "the fresh first question can be solved")
local eligibilityCalls=0
local realCutUser={species="BULBASAUR",moves={{id="CUT",pp=30}}}
local eligibleOw={partyKnows=function(_,move)
  eligibilityCalls=eligibilityCalls+1;T.eq(move,"CUT","root asks for CUT eligibility")
  return realCutUser
end}
local rootEarly, rootReason = green.openRootgate(save,eligibleOw)
T.check(not rootEarly and rootReason == "statues", "one light cannot open the roots")
T.eq(eligibilityCalls,0,"statue prerequisite fails before consulting the field user")
local second = assert(green.questionFor(save, 2))
T.check(green.answer(save, 2, second.answer), "second statue can be solved")
local noBadge,badgeReason=green.openRootgate(save,eligibleOw)
T.check(not noBadge and badgeReason=="badge",
  "two lights and CUT still cannot bypass a missing Cascade Badge")
T.eq(eligibilityCalls,0,"missing badge fails before a hook or party user is accepted")
save.inventory.CASCADEBADGE=true
local noCutCalls=0
local noCut,cutReason=green.openRootgate(save,{partyKnows=function(_,move)
  noCutCalls=noCutCalls+1;T.eq(move,"CUT","negative eligibility asks for CUT")
  return nil
end})
T.check(not noCut and cutReason=="cut",
  "two lights and badge still require a real party/Field-Tech CUT user")
T.eq(noCutCalls,1,"negative no-CUT path consults live Overworld exactly once")
T.check(not green.rootgateOpen(save),"failed CUT checks never mutate the root gate")
local fieldKitUser={nickname="FIELD KIT",moves={}}
local hookedUser,hookedReason=green.cutEligibility(save,{partyKnows=function(_,move)
  T.eq(move,"CUT","Field-Tech eligibility is requested through partyKnows")
  return fieldKitUser
end})
T.eq(hookedUser,fieldKitUser,"a live fieldmove.eligibility hook user is accepted")
T.eq(hookedReason,"eligible","Field-Tech hook result shares the honest eligibility contract")
T.check(green.openRootgate(save,eligibleOw),
  "two lights, Cascade Badge and a live CUT user open the roots")
T.eq(eligibilityCalls,1,"successful root gate consults live Overworld exactly once")
T.eq(realCutUser.moves[1].pp,30,"living-root CUT consumes no move PP")
local canopyEarly, canopyReason = green.openCanopy(save)
T.check(not canopyEarly and canopyReason == "statues", "canopy waits for all five lights")
for statue = 3, 5 do
  local question = assert(green.questionFor(save, statue))
  T.check(green.answer(save, statue, question.answer),
    "statue " .. statue .. " accepts its audited answer")
end
T.check(green.openCanopy(save), "all five lights open the canopy")
T.eq(green.progress(save).sight, 5, "all five answers persist in run state")

T.check(green.claimMega({ save = save }), "the secret Sceptilite claim survives")
T.eq(claimed.secret, "KA_GREEN_SCEPTILITE_SECRET", "secret save ID is stable")
T.eq(claimed.stone, "SCEPTILITE", "secret still awards Sceptilite")
T.check(green.complete({ save = save }), "five lights finalize GREEN through the legacy adapter")
T.eq(finalized.character, "GREEN", "finalization remains character-scoped")
T.check(#finalized.questionIds >= 6, "finalization preserves consumed question evidence")
T.check(green.isCollisionSafe(green.IDS.shrine, 27, 3, save),
  "completed save reopens the final collision gate")
T.check(green.progress(save).completed,
  "GREEN live completion marker was not set")
save.hevo_run = persistedAtFinalize
T.check(not (save.hevo_run.hidden_evolution_story_campaign.green.completed),
  "GREEN persistence fixture accidentally captured the post-save marker")
T.check(green.progress(save).completed,
  "GREEN final seal cannot recover its last-chance branch after reload")

-- Older/interrupted releases can contain the opposite half-transaction: the
-- route-local presentation marker was saved, but dungeonLegacy.seals.GREEN
-- was not.  The marker must not suppress the real adapter boundary; that
-- boundary still owns character/Beyond/puzzle authorization in production.
local markerOnlySave = {
  flags = {}, inventory = {}, party = {},
  hevo_run = {
    cycle = 8,
    hidden_evolution_story_campaign = {
      greenToken = "8:GREEN",
      green = {
        asked = { OLD_GREEN_1 = true, OLD_GREEN_2 = true },
        sight = 5, rootgate = true, canopy = true, completed = true,
        checkpoint = green.IDS.shrine, checkpointRank = 5,
      },
    },
  },
}
finalized = nil
T.check(green.complete({ save = markerOnlySave }),
  "GREEN marker-only save re-enters the authorized adapter finalization")
T.check(finalized and finalized.character == "GREEN"
    and markerOnlySave.hevo_run.dungeonLegacy
    and markerOnlySave.hevo_run.dungeonLegacy.seals.GREEN == true,
  "GREEN marker-only recovery backfills the authoritative GREEN seal")

claimed = nil
local greenFinalGame={save=save}
local greenDirectSealCalls=0
green.finalizeEndSeal=function(requestGame)
  T.eq(requestGame,greenFinalGame,"GREEN end seal changed game authority")
  greenDirectSealCalls=greenDirectSealCalls+1
  return true,{character="GREEN",seal=true,stoneStatus="granted"},"granted"
end
registeredScripts[green.IDS.shrine].talk.TEXT_KA_GREEN_RAYQUAZA_SEAL(
  greenFinalGame, nil, nil, function() end)
T.eq(greenDirectSealCalls,1,
  "GREEN visible end seal bypassed the canonical durable-handoff seam")

local checkpointSave = { flags = {}, hevo_run = { cycle = 9 } }
T.eq(green.checkpoint(checkpointSave, green.IDS.grove), green.IDS.grove,
  "forward progress updates the checkpoint")
T.eq(green.checkpoint(checkpointSave, green.IDS.threshold), green.IDS.grove,
  "backtracking cannot lower the checkpoint")

local done = false
registeredScripts[green.IDS.grove].talk.TEXT_KA_GREEN_RESET(
  { save = save }, nil, nil, function() done = true end)
T.check(done and lastWarp and lastWarp.mapId == green.IDS.grove
    and lastWarp.x == 3 and lastWarp.y == 35 and lastWarp.facing == "up",
  "reset root resolves the live overworld map and returns to a safe cell")

green.install({ save = save })
T.check(type(enteredHandler) == "function", "GREEN installs its restore handler")
lastReplacement = nil
enteredHandler({ mapId = green.IDS.mist })
T.check(lastReplacement and lastReplacement.x == 27 and lastReplacement.y == 3
    and lastReplacement.block == green.FOREST_BLOCKS.GATE_PATH,
  "map entry restores the persisted mist gates")
lastReplacement = nil
enteredHandler({ mapId = green.IDS.shrine })
T.check(lastReplacement and lastReplacement.x == 27 and lastReplacement.y == 3
    and lastReplacement.block == green.FOREST_BLOCKS.GATE_PATH,
  "map entry restores the persisted completion gate")

T.finish("hidden_evolution_green_kanto_test")
