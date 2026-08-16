-- Consolidated product gate for the exact 16-map HEVO presentation surface.
-- This catches the two user-visible regressions that source-local map tests
-- could miss after later main.lua patches: decorative-looking ladder cells
-- without warps and field altars masquerading as extra quiz statues.
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local Data = require("src.core.Data")
Data:load()
local root = assert(os.getenv("KA_HEVO_MOD"), "KA_HEVO_MOD required")
local sdkRoot = root:sub(1, 1) == "/" and "/" or "."
-- The SDK loader owns an io-backed, deliberately headless filesystem.  A
-- real LOVE global would make the transform probe believe image output is
-- available, then try to write through that read-focused fixture filesystem.
-- Hide only the image backend while loading; this is the same no-ROM/headless
-- path used by the canonical SDK gate, not an exemption from main.lua.
local realLove = rawget(_G, "love")
_G.love = nil
local run = T.sdk.loadMod(root, { data = Data, root = sdkRoot })
_G.love = realLove
T.eq(#run.errors, 0, "Authority main.lua loads the complete HEVO surface")

local RuntimeMap = require("src.world.Map")
local Collision = require("src.world.Collision")
Collision.load(Data)
local greenTopology = assert(loadfile(root .. "/hidden_evolution_green_grove.lua"))()({}, {})
local rows = {
  -- map, all objects, visible objects, quiz statues, floor lights, item
  -- markers, visible native ladder cells. Keeping these map-local catches an extra
  -- relic or decorative ladder even if another floor loses one and the
  -- character-wide total accidentally stays unchanged.
  { "KA_HEVO_TUNNEL_ALL", 0, 0, 0, 0, 0, 3 },
  { "KA_HEVO_RED_UPPER", 11, 8, 2, 3, 0, 2 },
  { "KA_HEVO_RED_ABYSS", 7, 5, 2, 3, 0, 2 },
  { "KA_HEVO_RED_RECOVERY", 3, 1, 0, 0, 1, 6 },
  { "KA_HEVO_RED_LOWER", 9, 7, 1, 3, 0, 2 },
  { "KA_HEVO_RED_SHRINE", 3, 1, 0, 0, 1, 2 },
  { "KA_HEVO_BLUE_FROST_THRESHOLD", 3, 3, 0, 3, 0, 2 },
  { "KA_HEVO_BLUE_FROST_HALL", 7, 7, 1, 3, 2, 2 },
  { "KA_HEVO_BLUE_GLACIER_MAZE", 9, 9, 2, 3, 3, 2 },
  { "KA_HEVO_BLUE_TIDAL_DEPTHS", 8, 8, 2, 3, 2, 2 },
  { "KA_HEVO_BLUE_KYOGRE_SHRINE", 4, 4, 0, 0, 3, 2 },
  { "KA_HEVO_SHARED_SEALED_ANTECHAMBER", 1, 1, 0, 0, 0, 3 },
  { "KA_HEVO_GREEN_THRESHOLD", 6, 5, 0, 3, 2, 2 },
  { "KA_HEVO_GREEN_GROVE", 13, 13, 2, 3, 8, 2 },
  { "KA_HEVO_GREEN_MIST", 14, 12, 3, 3, 6, 2 },
  { "KA_HEVO_GREEN_RAYQUAZA_SHRINE", 4, 4, 0, 0, 4, 2 },
}

-- Every CAVERN block whose native pixels show a ladder has one exact trigger
-- cell.  A visible ladder anywhere else is a product bug, not decoration.
local cavernLadderCells = {
  [61]={{1,1}}, [62]={{1,1}}, [97]={{1,0}}, [98]={{1,1}},
  [124]={{1,1}}, [127]={{0,1}},
}

local statuePrefixes = {
  RED = "KA_RED_STATUE_",
  BLUE = "KA_HEVO_BLUE_STATUE_",
  GREEN = "KA_GREEN_STATUE_",
}
local statueCounts = { RED=0, BLUE=0, GREEN=0 }
local floorLightCounts = { RED=0, BLUE=0, GREEN=0 }
local itemCounts = { RED=0, BLUE=0, GREEN=0 }
local altarNames = {
  KA_HEVO_ALTAR_MAGNETIC_FIELD = true,
  KA_HEVO_ALTAR_ICE_FIELD = true,
  KA_HEVO_ALTAR_MOSS_FIELD = true,
}
local altarCount = 0

local function owner(id)
  if id:find("_RED_", 1, true) then return "RED" end
  if id:find("_BLUE_", 1, true) then return "BLUE" end
  if id:find("_GREEN_", 1, true) then return "GREEN" end
end

local solvedGateBlocks = {
  KA_HEVO_BLUE_FROST_HALL={{15,12,25}},
  KA_HEVO_BLUE_GLACIER_MAZE={{23,11,21}},
  KA_HEVO_BLUE_TIDAL_DEPTHS={{20,7,25}},
  KA_HEVO_GREEN_MIST={{12,10,57},{27,3,57}},
  KA_HEVO_GREEN_RAYQUAZA_SHRINE={{27,3,57}},
}
local directions = {
  {name="right",dx=1,dy=0},{name="left",dx=-1,dy=0},
  {name="down",dx=0,dy=1},{name="up",dx=0,dy=-1},
}
local function stateKey(x,y,surfing)
  return x..":"..y..":"..(surfing and "S" or "D")
end
local function solvedRuntime(def)
  local copy={}
  for key,value in pairs(def) do copy[key]=value end
  copy.blocks={};for index,block in ipairs(def.blocks) do copy.blocks[index]=block end
  for _,row in ipairs(solvedGateBlocks[def.id] or {}) do
    copy.blocks[row[1]+row[2]*def.width+1]=row[3]
  end
  local runtime=RuntimeMap.new(copy,assert(Data.tilesets[def.tileset]))
  -- RED LOWER's compatibility seam promotes native tile $20 to a local Surf
  -- shore at runtime without mutating the global CAVERN tileset.
  for _,tile in ipairs(def.shoreTiles or {}) do runtime.waterTiles[tile]=true end
  return runtime
end
local function movementGraph(def)
  local runtime=solvedRuntime(def)
  local blockers,blocked={},{}
  for _,object in ipairs(def.objects or {}) do
    -- Pushable/hidden puzzle pieces are absent from the solved traversal.
    -- Every tangible light, statue, tablet and unclaimed item remains real
    -- Collision authority while its map is being audited.
    if object.passable~=true and object.hidden~=true and object.pushable~=true then
      local entity={cellX=object.x,cellY=object.y,passable=false}
      blockers[#blockers+1]=entity;blocked[object.x..":"..object.y]=true
    end
  end
  local graph,reverse={},{ }
  local function ensure(key) graph[key]=graph[key] or {};reverse[key]=reverse[key] or {} end
  local function link(from,to)
    ensure(from);ensure(to);graph[from][to]=true;reverse[to][from]=true
  end
  for y=0,def.height*2-1 do for x=0,def.width*2-1 do
    if not blocked[x..":"..y] then
      if runtime:isWalkableCell(x,y) then ensure(stateKey(x,y,false)) end
      if runtime:isWaterCell(x,y) then ensure(stateKey(x,y,true)) end
    end
  end end
  for y=0,def.height*2-1 do for x=0,def.width*2-1 do
    if not blocked[x..":"..y] then for _,surfing in ipairs({false,true}) do
      local from=stateKey(x,y,surfing)
      if graph[from] then
        for _,dir in ipairs(directions) do
          local nx,ny=x+dir.dx,y+dir.dy
          local to=stateKey(nx,ny,surfing)
          local targetMatches=surfing and runtime:isWaterCell(nx,ny)
            or (not surfing and runtime:isWalkableCell(nx,ny))
          if graph[to] and targetMatches
              and Collision.canMove(runtime,blockers,
                {cellX=x,cellY=y,surfing=surfing},dir.name) then
            link(from,to)
          end
        end
        -- Native shore cells are both walkable and water-authoritative.  A
        -- mode switch here models the real mount/dismount action without
        -- inventing a geometric edge across CAVERN elevation seams.
        if runtime:isWalkableCell(x,y) and runtime:isWaterCell(x,y) then
          link(from,stateKey(x,y,not surfing))
        end
      end
    end end
  end end
  return runtime,graph,reverse,blocked
end
local function distances(graph,start)
  local queue,head,dist={start},1,{[start]=0}
  while queue[head] do
    local at=queue[head];head=head+1
    for nextKey in pairs(graph[at] or {}) do if dist[nextKey]==nil then
      dist[nextKey]=dist[at]+1;queue[#queue+1]=nextKey
    end end
  end
  return dist
end
local forwardWarpCoordinates={RED={},BLUE={},GREEN={}}

for _, row in ipairs(rows) do
  local id, objectCount, visibleCount = row[1], row[2], row[3]
  local expectedStatues, expectedLights = row[4], row[5]
  local expectedItems, expectedLadders = row[6], row[7]
  local def = assert(Data.maps[id], id .. " missing")
  T.eq(Data.audio.mapSongs[id], "Music_KA_DeepEvolution",
    id .. " owns its direct-load/reload dungeon music")
  T.eq(#(def.objects or {}), objectCount,
    id .. " exact object inventory drifted")
  local visible, mapStatues, mapLights, mapItems = 0, 0, 0, 0
  local lightCells = {}
  local occupied, solidOccupied = {}, {}
  local runtime = RuntimeMap.new(def, assert(Data.tilesets[def.tileset]))
  for _, object in ipairs(def.objects or {}) do
    local cell = tostring(object.x) .. "," .. tostring(object.y)
    T.check(occupied[cell] == nil,
      id .. " object collision at " .. cell .. " with " .. tostring(occupied[cell]))
    occupied[cell] = object.name
    if object.passable ~= true then solidOccupied[cell] = object.name end
    if object.renderMode ~= "none" then visible = visible + 1 end
    local pathOwner = owner(id)
    if object.sprite == "SPRITE_KA_EVOLUTION_RELIC" then
      if tostring(object.name):find("KA_HEVO_FLOOR_LIGHT_", 1, true) == 1 then
        local lightOwner=tostring(object.name):match("^KA_HEVO_FLOOR_LIGHT_([A-Z]+)_")
        T.eq(lightOwner,pathOwner,id .. " floor light belongs to wrong character")
        T.eq(object.semanticRole,"floor_light",
          object.name .. " lost its exclusive floor-light role")
        floorLightCounts[pathOwner]=floorLightCounts[pathOwner]+1
        mapLights=mapLights+1
        lightCells[#lightCells+1]={x=object.x,y=object.y,name=object.name}
        T.eq(object.passable,false,
          object.name .. " must remain a tangible light stone")
        T.check(runtime:isWalkableCell(object.x,object.y),
          object.name .. " is not on a native-walkable cell")
        T.check(runtime:warpAtCell(object.x,object.y)==nil,
          object.name .. " overlaps a warp")
      else
        error(id .. " has a relic object outside the floor-light contract")
      end
    elseif object.sprite == "SPRITE_KA_HEVO_QUIZ_STATUE" then
      local matched
      for character, prefix in pairs(statuePrefixes) do
        if tostring(object.name):find(prefix, 1, true) == 1 then
          matched = character
          statueCounts[character] = statueCounts[character] + 1
        end
      end
      T.eq(matched, pathOwner,id .. " has a foreign quiz statue")
      T.eq(object.semanticRole,"quiz_statue",
        object.name .. " lost its exclusive quiz role")
      mapStatues = mapStatues + 1
    elseif object.sprite == "SPRITE_POKE_BALL" and pathOwner then
      itemCounts[pathOwner] = itemCounts[pathOwner] + 1
      mapItems = mapItems + 1
    end
    if altarNames[object.name] then
      altarCount = altarCount + 1
      T.eq(object.sprite, "SPRITE_POKE_BALL",
        object.name .. " must look like an item marker, not a sixth statue")
    end
  end
  T.eq(visible, visibleCount, id .. " exact visible-object inventory drifted")
  T.eq(mapStatues, expectedStatues, id .. " exact quiz-statue count drifted")
  T.eq(mapLights, expectedLights, id .. " exact floor-light count drifted")
  T.eq(mapItems, expectedItems, id .. " exact item-marker count drifted")

  if id == "KA_HEVO_RED_UPPER" then
    -- Regression: the first solid light used to occupy (7,31).  Together
    -- with the solid Strength tablet at (11,31), that sealed both entrances
    -- to the survey loop.  Prove the real initial object layout can reach the
    -- first junction without walking through any solid NPC.
    T.eq(solidOccupied["16,33"],"KA_HEVO_FLOOR_LIGHT_RED_UPPER_1",
      "first RED light left its optional bottom fault")
    local start,goal=assert(def.warps[1]),{x=9,y=27}
    local queue,seen={{x=start.x,y=start.y}},
      {[start.x..","..start.y]=true}
    local cursor=1
    while queue[cursor] do
      local point=queue[cursor];cursor=cursor+1
      for _,step in ipairs({{1,0},{-1,0},{0,1},{0,-1}}) do
        local x,y=point.x+step[1],point.y+step[2]
        local cell=x..","..y
        if x>=0 and y>=0 and x<def.width*2 and y<def.height*2
            and not seen[cell] and not solidOccupied[cell]
            and runtime:isWalkableCell(x,y) then
          seen[cell]=true;queue[#queue+1]={x=x,y=y}
        end
      end
    end
    T.check(seen[goal.x..","..goal.y],
      "first RED solid light and tablet seal the entrance corridor")
  end

  if expectedLights > 0 then
    T.check(math.sqrt((def.width*2)^2+(def.height*2)^2)<96,
      id .. " exceeds the stage-three floor-wide visibility radius")
    local entrance,exit=assert(def.warps[1],id.." missing entrance warp"),
      assert(def.warps[2],id.." missing exit warp")
    local solved,graph,reverse,blocked=movementGraph(def)
    local entranceKey=stateKey(entrance.x,entrance.y,false)
    local exitKey=stateKey(exit.x,exit.y,false)
    local fromEntrance=distances(graph,entranceKey)
    local toExit=distances(reverse,exitKey)
    local shortest=fromEntrance[exitKey]
    T.check(shortest~=nil,id
      .." has no continuous native-Collision entry-to-exit traversal")
    local minY,maxY=math.huge,-math.huge
    for _,light in ipairs(lightCells) do
      T.check(blocked[light.x..":"..light.y]==true,
        light.name.." is absent from the native Collision blocker set")
      local approaches,bestExtra=0,nil
      for _,dir in ipairs(directions) do
        local x,y=light.x+dir.dx,light.y+dir.dy
        local key=stateKey(x,y,false)
        if graph[key] and fromEntrance[key] and toExit[key] then
          approaches=approaches+1
          local extra=fromEntrance[key]+toExit[key]-shortest
          bestExtra=bestExtra and math.min(bestExtra,extra) or extra
        end
      end
      T.check(approaches>=1,light.name
        .." has no continuous entrance -> cardinal A approach -> retreat -> exit route")
      T.check(bestExtra and bestExtra>=6,light.name
        .." can be activated from the mandatory route (detour "
        ..tostring(bestExtra)..", want >=6)")
      minY=math.min(minY,light.y);maxY=math.max(maxY,light.y)
    end
    T.check(minY<=math.floor(def.height*2*0.35),id
      .." has no light in the authored upper map sector")
    T.check(maxY>=math.floor(def.height*2*0.65),id
      .." has no light in the authored lower map sector")
    for left=1,#lightCells do for right=left+1,#lightCells do
      local a,b=lightCells[left],lightCells[right]
      local distance=math.abs(a.x-b.x)+math.abs(a.y-b.y)
      T.check(distance>=12,a.name .. " and " .. b.name
        .. " are not graphically distributed (Manhattan " .. distance .. ")")
    end end
  end

  local ladderCount,visibleWarpCells = 0,{}
  if def.tileset == "CAVERN" then
    local runtime = RuntimeMap.new(def, assert(Data.tilesets.CAVERN))
    for by=0,def.height-1 do for bx=0,def.width-1 do
      local block = def.blocks[by*def.width+bx+1]
      for _, cell in ipairs(cavernLadderCells[block] or {}) do
        ladderCount = ladderCount + 1
        local x, y = bx*2+cell[1], by*2+cell[2]
        visibleWarpCells[x..","..y]=true
        T.check(runtime:warpAtCell(x, y) ~= nil,
          id .. " visible ladder at " .. x .. "," .. y .. " is decorative")
      end
    end end
  elseif def.tileset == "FOREST" then
    local runtime = RuntimeMap.new(def, assert(Data.tilesets.FOREST))
    for by=0,def.height-1 do for bx=0,def.width-1 do
      if def.blocks[by*def.width+bx+1]==25 then
        ladderCount=ladderCount+1
        local x,y=bx*2+1,by*2+1
        visibleWarpCells[x..","..y]=true
        T.check(runtime:warpAtCell(x,y)~=nil,
          id.." visible tree door at "..x..","..y.." is decorative")
      end
    end end
  end
  T.eq(ladderCount, expectedLadders,
    id .. " exact visible native-ladder inventory drifted")
  if owner(id) then
    for index=1,math.min(2,#(def.warps or {})) do
      local warp=def.warps[index]
      T.check(visibleWarpCells[warp.x..","..warp.y]==true,
        id.." declared route warp "..index.." has no visible native ladder/door")
    end
    local forward=assert(def.warps[2],id.." missing forward warp")
    forwardWarpCoordinates[owner(id)][#forwardWarpCoordinates[owner(id)]+1]
      ={x=forward.x,y=forward.y,map=id}
  end
end

-- Upgrade safety for saves made on 6.5.2's retired exit approaches.  This is
-- the exact old-walkable -> new-wall footprint that was reachable from an old
-- map warp under native Collision at base 7a968a408a: twelve RED cells and
-- eight GREEN cells.  They must remain ordinary connected floor, never a
-- decorative copy of the old ladder/tree door.
local legacySaveCells = {
  KA_HEVO_RED_ABYSS={{44,2},{45,2}},
  KA_HEVO_RED_RECOVERY={{44,2},{45,2},{44,3}},
  KA_HEVO_RED_LOWER={{44,2},{45,2},{44,3},{42,6}},
  KA_HEVO_RED_SHRINE={{44,2},{45,2},{44,3}},
  KA_HEVO_GREEN_THRESHOLD={{57,3},{57,4}},
  KA_HEVO_GREEN_MIST={{57,3},{57,4},{57,5},{57,6},{56,7},{57,7}},
}
local retiredExits = {
  KA_HEVO_RED_ABYSS={45,3},
  KA_HEVO_RED_RECOVERY={45,3},
  KA_HEVO_RED_LOWER={45,3},
  KA_HEVO_RED_SHRINE={45,3},
  KA_HEVO_GREEN_THRESHOLD={57,3},
  KA_HEVO_GREEN_MIST={57,3},
}
local legacyCellCount=0
for id,cells in pairs(legacySaveCells) do
  local def=assert(Data.maps[id],id.." missing legacy-save map")
  local runtime,graph=movementGraph(def)
  local entrance,exit=assert(def.warps[1]),assert(def.warps[2])
  for _,point in ipairs(cells) do
    local x,y=point[1],point[2];legacyCellCount=legacyCellCount+1
    T.check(runtime:isWalkableCell(x,y),id.." walls legacy save cell "..x..","..y)
    T.check(runtime:warpAtCell(x,y)==nil,id.." legacy save cell retained a warp "..x..","..y)
    local fromLegacy=distances(graph,stateKey(x,y,false))
    T.check(fromLegacy[stateKey(entrance.x,entrance.y,false)]
        or fromLegacy[stateKey(exit.x,exit.y,false)],
      id.." legacy save cell cannot retreat to a current route "..x..","..y)
  end
  local old=assert(retiredExits[id])
  T.check(runtime:warpAtCell(old[1],old[2])==nil,
    id.." retained its retired forward warp")
  local block=def.blocks[math.floor(old[1]/2)+math.floor(old[2]/2)*def.width+1]
  if def.tileset=="CAVERN" then
    T.check(cavernLadderCells[block]==nil,id.." retained a decorative old ladder")
  else
    T.check(block~=25,id.." retained a decorative old tree door")
  end
end
T.eq(legacyCellCount,20,"exact native-reachable 6.5.2 save footprint drifted")

for _, character in ipairs({ "RED", "BLUE", "GREEN" }) do
  T.eq(statueCounts[character], 5,
    character .. " exposes exactly the five quiz statues")
end
T.eq(floorLightCounts.RED,9,"RED exposes three lights on each of three trial floors")
T.eq(floorLightCounts.BLUE,12,"BLUE exposes three lights from threshold through depths")
T.eq(floorLightCounts.GREEN,9,"GREEN exposes three lights from threshold through mist")
T.eq(floorLightCounts.RED+floorLightCounts.BLUE+floorLightCounts.GREEN,30,
  "exactly 30 independent floor lights exist")
for character,warps in pairs(forwardWarpCoordinates) do
  local coordinates,rowsSeen={},{}
  for _,warp in ipairs(warps) do
    coordinates[warp.x..","..warp.y]=true;rowsSeen[warp.y]=true
  end
  local distinct,distinctRows=0,0
  for _ in pairs(coordinates) do distinct=distinct+1 end
  for _ in pairs(rowsSeen) do distinctRows=distinctRows+1 end
  T.eq(distinct,#warps,character.." repeats a forward ladder coordinate")
  T.check(distinctRows>=3,character
    .." forward ladders remain pinned to one top-right row")
end
T.eq(altarCount, 3, "exactly three reusable field-evolution item markers exist")
T.eq(itemCounts.RED, 2, "RED exact visible item-marker count")
T.eq(itemCounts.BLUE, 10, "BLUE exact visible item-marker count")
T.eq(itemCounts.GREEN, 20, "GREEN exact visible item-marker count")

run.release()
T.finish("hidden_evolution_map_surface_contract_test")
