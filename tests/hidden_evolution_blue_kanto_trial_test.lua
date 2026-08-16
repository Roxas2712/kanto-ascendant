-- Focused product gate for BLUE's native Gen-I frost campaign.
-- Run from gen1recomp with KA_HIDDEN_EVOLUTION_MOD set to Authority root.
package.path = "./?.lua;./?/init.lua;" .. package.path

local root=assert(os.getenv("KA_HIDDEN_EVOLUTION_MOD"),"KA_HIDDEN_EVOLUTION_MOD is required")
local Data=require("src.core.Data");Data:load()

local function registry(base)
  local r={values={},base=base or {}}
  function r:get(id) return self.values[id] or self.base[id] end
  function r:register(id,value)
    assert(self.values[id]==nil,"duplicate "..tostring(id));self.values[id]=value;return value
  end
  function r:patch(id,value)
    self.values[id]=self.values[id] or {}
    local dst=self.values[id]
    for key,row in pairs(value) do
      if type(row)=="table" and #row>0 then
        dst[key]=dst[key] or {};for _,entry in ipairs(row) do dst[key][#dst[key]+1]=entry end
      else dst[key]=row end
    end
  end
  return r
end

local saved={extended_characters={player_character="BLUE"},hevo_run={}}
local handlers,replacements,flags={},{},{}
local mod={
  save={
    get=function(_,id) return saved[id] end,
    set=function(_,id,value) saved[id]=value end,
  },
  events={on=function(_,id,fn) handlers[id]=handlers[id] or {};handlers[id][#handlers[id]+1]=fn end},
  hooks={wrap=function() end},
  world={
    setFlag=function(_,id,value) flags[id]=value;return true end,
    replaceBlock=function(_,bx,by,block) replacements[#replacements+1]={bx=bx,by=by,block=block};return true end,
  },
  content={
    maps=registry(),encounters=registry(),text=registry(),map_scripts=registry(),
    map_songs=registry(),field=registry(),
    text_pointers={patch=function() end},
  },
}
local finalSecret
local factory=assert(loadfile(root.."/hidden_evolution_blue_campaign.lua"))()
local blue=factory(mod,{activeCharacter=function() return "BLUE" end,showText=function() return true end,
  legacyDungeonAdapter={finalize=function() return true,{packages={}} end,
    claimSecret=function(_,payload) finalSecret=payload return true end}})
local emptyBlueRoot=saved.hevo_run
local emptyBlueReport=blue.completionProgress({})
assert(emptyBlueReport.statues==0 and emptyBlueReport.finalStatue==false
    and emptyBlueReport.switches.HALL==false
    and next(emptyBlueRoot)==nil and saved.hevo_run==emptyBlueRoot,
  "BLUE completion report created/normalized missing run state")
local blueState={sight=4,solved={DEPTHS_EAST=false},
  switches={HALL=true,ICE=false,DEPTHS=true},floorLights={HALL=true},
  hiddenMegaCache=true}
saved.hevo_run={hidden_evolution_blue=blueState}
local blueRoot=saved.hevo_run
local blueReport=blue.completionProgress({})
assert(blueReport.statues==4 and blueReport.finalStatue==false
    and blueReport.switches.HALL and not blueReport.switches.ICE
    and blueReport.switches.DEPTHS and blueReport.floorLights==nil
    and blueReport.hiddenMegaCache==nil and saved.hevo_run==blueRoot
    and blueRoot.hidden_evolution_blue==blueState,
  "BLUE completion report mutated state or included optional discoveries")
blueState.solved.DEPTHS_EAST=true
blueState.switches.HALL,blueState.switches.ICE,blueState.switches.DEPTHS=true,true,true
for _,missing in ipairs({"HALL","ICE","DEPTHS"}) do
  blueState.switches[missing]=false
  local report=blue.completionProgress({})
  assert(report.switches[missing]==false,
    "BLUE report masked missing "..missing.." switch")
  blueState.switches[missing]=true
end
blueState.solved.DEPTHS_EAST=false
assert(blue.completionProgress({}).finalStatue==false,
  "BLUE report masked the missing east-Depths statue")
saved.hevo_run={}
assert(blue.register())
local cavernOk,cavernWhy=blue.validateCavern(Data)
assert(cavernOk,"canonical CAVERN validation failed: "..tostring(cavernWhy))

local ids={blue.ids.THRESHOLD,blue.ids.HALL,blue.ids.ICE,blue.ids.DEPTHS,blue.ids.SHRINE}
for _,id in ipairs(ids) do
  local def=assert(mod.content.maps:get(id),id.." missing")
  assert(def.tileset=="CAVERN",id.." is not native Kanto CAVERN")
  assert(def.voxelMode=="FULL" and def.voxelRevision>=3,id.." lost native FULL Voxel profile")
  assert(def.outdoor==false and #def.blocks==def.width*def.height,id.." malformed map record")
  assert(mod.content.map_songs:get(id)=="Music_KA_DeepEvolution",
    id.." can inherit unrelated route music after a direct load")
end
local statueSprites,otherRelics=0,{}
for _,id in ipairs(ids) do for _,obj in ipairs(mod.content.maps:get(id).objects or {}) do
  local statue=tostring(obj.name):find("KA_HEVO_BLUE_STATUE_",1,true)==1
  if statue then
    statueSprites=statueSprites+1
    assert(obj.sprite=="SPRITE_KA_HEVO_QUIZ_STATUE"
        and obj.semanticRole=="quiz_statue",
      obj.name.." is not visually identifiable as a frost statue")
  elseif obj.sprite=="SPRITE_KA_HEVO_QUIZ_STATUE"
      or obj.semanticRole=="quiz_statue" then
    otherRelics[#otherRelics+1]=obj.name
  end
end end
assert(statueSprites==5,"BLUE does not expose exactly five frost-statue objects")
assert(#otherRelics==0,
  "non-statue BLUE objects reuse the quiz-statue role: "..table.concat(otherRelics,","))
local narrowBlocks={[26]=true,[38]=true,[29]=true,[57]=true}
for _,id in ipairs({blue.ids.THRESHOLD,blue.ids.HALL,blue.ids.DEPTHS,blue.ids.SHRINE}) do
  local count=0
  for _,block in ipairs(mod.content.maps:get(id).blocks) do
    if narrowBlocks[block] then count=count+1 end
  end
  assert(count>=2,id.." lacks genuine one-cell native CAVERN constrictions")
end
local glacierNarrow=0
for _,block in ipairs(mod.content.maps:get(blue.ids.ICE).blocks) do
  if narrowBlocks[block] then glacierNarrow=glacierNarrow+1 end
end
assert(glacierNarrow==9,
  "Glacier lost its six statue-cleft plus three light-fault half-blocks: "..glacierNarrow)
local dark=assert(mod.content.field.values.darkMaps,"BLUE darkness patch missing")
local darkSet={};for _,id in ipairs(dark.maps or {}) do darkSet[id]=true end
for _,id in ipairs(ids) do assert(darkSet[id],id.." is not in native darkMaps") end
local blind,clear=blue.sightProfile(0),blue.sightProfile(5)
assert(blind.radius>=1 and blind.radius<=2 and blind.outerOpacity==1,
  "BLUE opening sight cone is not a one-to-two-cell near-black tunnel")
assert(blind.innerOpacity>=0.60 and blind.outerOpacity>blind.innerOpacity+0.25,
  "BLUE opening cone clears its centre instead of dimming silhouettes")
assert(blind.featherPx>0 and blind.featherPx<=2,
  "BLUE opening cone regained a wide raster/stipple transition")
assert(clear.radius<=5.75 and clear.radius>blind.radius+3.5,
  "BLUE statue sight progression no longer grows across five clear steps")
for level=0,5 do
  local profile=blue.sightProfile(level)
  assert(profile.outerOpacity==1 and profile.innerOpacity>=0.45,
    "BLUE sight level "..level.." exposes distant markers or full-palette actors")
  assert(profile.featherPx==blind.featherPx and profile.featherPx<=2,
    "BLUE sight feather scales with progress/radius instead of screen pixels")
  if level>0 then
    local previous=blue.sightProfile(level-1)
    assert(profile.radius>previous.radius and profile.innerOpacity<previous.innerOpacity,
      "BLUE sight level "..level.." is not visibly brighter and wider")
  end
end

-- Dark-map OBP turns the ordinary native SEEL sheet completely black, which
-- vanishes against CAVERN $14 water.  BLUE may clone the renderer definition
-- for presentation, but it must preserve the exact native art/frames and
-- restore whichever renderer owned the player when this campaign was entered.
local nativeSurf=assert(Data.sprites.SPRITE_SEEL,"native SPRITE_SEEL missing")
local readableSurf=blue.readableSurfDefinition(nativeSurf)
assert(readableSurf~=nativeSurf and readableSurf.trueColor==true,
  "BLUE readable surf did not create an isolated true-colour definition")
for key,value in pairs(nativeSurf) do
  assert(readableSurf[key]==value,
    "BLUE readable surf changed native SEEL field "..tostring(key))
end
for key,value in pairs(readableSurf) do
  assert(key=="trueColor" or nativeSurf[key]==value,
    "BLUE readable surf added non-presentation field "..tostring(key))
end
assert(nativeSurf.trueColor~=true,
  "BLUE readable surf mutated the canonical SPRITE_SEEL definition")

local made={}
local fakeRenderer={new=function(def,seed)
  local renderer={def=def,seed=seed};made[#made+1]=renderer;return renderer
end}
local originalSurf={def=nativeSurf,owner="baseline"}
local fakePlayer={surfSprite=originalSurf}
local fakeOw={player=fakePlayer,map={id=blue.ids.THRESHOLD}}
local fakeGame={data={sprites={SPRITE_SEEL=nativeSurf}}}
local applied,why=blue.refreshSurfPresentation(
  fakeOw,fakeOw.map.id,fakeGame,fakeRenderer)
assert(applied and why=="installed" and #made==1,
  "BLUE readable surf was not installed on campaign entry")
local firstClone=fakePlayer.surfSprite
assert(firstClone~=originalSurf and firstClone.def.image==nativeSurf.image
    and firstClone.def.frames==nativeSurf.frames and firstClone.def.walker==nativeSurf.walker
    and firstClone.def.source==nativeSurf.source and firstClone.def.trueColor==true,
  "BLUE readable surf is not the native SEEL animation plus trueColor")
assert(blue.hasReadableSurfPresentation(fakePlayer),
  "BLUE readable surf state does not identify its active clone")

fakeOw.map.id=blue.ids.HALL
applied,why=blue.refreshSurfPresentation(fakeOw,fakeOw.map.id,fakeGame,fakeRenderer)
assert(applied and why=="active" and fakePlayer.surfSprite==firstClone and #made==1,
  "BLUE->BLUE map change duplicated the surf renderer")

-- A later character-presentation refresh wins ownership.  BLUE replaces it
-- for this floor, then restores that exact newer renderer on exit rather than
-- the stale object captured on first entry.
local refreshedSurf={def=nativeSurf,owner="refreshed"}
fakePlayer.surfSprite=refreshedSurf
fakeOw.map.id=blue.ids.DEPTHS
applied,why=blue.refreshSurfPresentation(fakeOw,fakeOw.map.id,fakeGame,fakeRenderer)
assert(applied and why=="installed" and fakePlayer.surfSprite~=firstClone and #made==2,
  "BLUE did not recover idempotently from an actor-presentation refresh")
local current=assert(blue.surfPresentationState(fakePlayer))
assert(current.original==refreshedSurf and current.clone==fakePlayer.surfSprite,
  "BLUE surf restore target drifted after actor refresh")

fakeOw.map.id="ROUTE_24"
applied,why=blue.refreshSurfPresentation(fakeOw,fakeOw.map.id,fakeGame,fakeRenderer)
assert(applied and why=="restored" and fakePlayer.surfSprite==refreshedSurf,
  "BLUE exit did not restore the exact prior surf renderer")
assert(not blue.hasReadableSurfPresentation(fakePlayer)
    and blue.surfPresentationState(fakePlayer)==nil,
  "BLUE exit leaked readable-surf presentation state")
local outside,where=blue.refreshSurfPresentation(fakeOw,fakeOw.map.id,fakeGame,fakeRenderer)
assert(not outside and where=="outside" and #made==2,
  "non-BLUE refresh manufactured or retained a surf clone")

-- Save reload replaces the player object.  Its fresh clone must be independent
-- and restore independently; the previous player's state stays empty.
local reloadedOriginal={def=nativeSurf,owner="reloaded"}
local reloadedPlayer={surfSprite=reloadedOriginal}
fakeOw.player=reloadedPlayer
fakeOw.map.id=blue.ids.DEPTHS
applied,why=blue.refreshSurfPresentation(fakeOw,fakeOw.map.id,fakeGame,fakeRenderer)
assert(applied and why=="installed" and #made==3
    and blue.hasReadableSurfPresentation(reloadedPlayer),
  "save-reloaded player did not receive an independent readable surf clone")
fakeOw.map.id="KA_HEVO_SHARED_SEALED_ANTECHAMBER"
blue.refreshSurfPresentation(fakeOw,fakeOw.map.id,fakeGame,fakeRenderer)
assert(reloadedPlayer.surfSprite==reloadedOriginal
    and not blue.hasReadableSurfPresentation(reloadedPlayer),
  "save-reloaded player leaked BLUE surf presentation outside the campaign")

-- Release composition gate at authored block scale: the first two teaching
-- floors need genuine return loops plus useful terminal branches, not a
-- monotone bottom-left -> top-right corridor.  Block-scale topology avoids
-- counting the four collision cells inside one metatile as fake loops.
local function blockTopology(def)
  local open={[25]=true,[21]=true,[1]=true,[124]=true,[26]=true,[38]=true,
    [29]=true,[57]=true,[41]=true}
  local nodes,edges,dead,components,seen=0,0,0,0,{}
  local function key(x,y)return x..":"..y end
  local function isOpen(x,y)
    return x>=0 and y>=0 and x<def.width and y<def.height
      and open[def.blocks[x+y*def.width+1]]==true
  end
  for y=0,def.height-1 do for x=0,def.width-1 do if isOpen(x,y) then
    nodes=nodes+1;local degree=0
    for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}})do if isOpen(x+d[1],y+d[2])then degree=degree+1 end end
    edges=edges+degree;if degree==1 then dead=dead+1 end
    if not seen[key(x,y)]then
      components=components+1;local queue,head={{x=x,y=y}},1;seen[key(x,y)]=true
      while queue[head]do local at=queue[head];head=head+1
        for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}})do local nx,ny=at.x+d[1],at.y+d[2]
          if isOpen(nx,ny)and not seen[key(nx,ny)]then seen[key(nx,ny)]=true;queue[#queue+1]={x=nx,y=ny}end
        end
      end
    end
  end end end
  return {cycles=edges/2-nodes+components,dead=dead}
end
for _,id in ipairs({blue.ids.THRESHOLD,blue.ids.HALL})do
  local topology=blockTopology(mod.content.maps:get(id))
  assert(topology.cycles>=2,id.." lacks meaningful return loops")
  assert(topology.dead>=2,id.." lacks fair landmark branches")
end
local thresholdExit=mod.content.maps:get(blue.ids.THRESHOLD).warps[2]
local hallExit=mod.content.maps:get(blue.ids.HALL).warps[2]
assert(thresholdExit.x<30 and hallExit.y>10,"BLUE teaching exits regressed to repeated top-right targets")

package.loaded["src.render.TileRenderer"]={new=function() return {} end}
local RuntimeMap=require("src.world.Map")
local Collision=require("src.world.Collision");Collision.load(Data)
local runtimes={}
for _,id in ipairs(ids) do
  local def=mod.content.maps:get(id);local runtime=RuntimeMap.new(def,assert(Data.tilesets.CAVERN));runtimes[id]=runtime
  for index=1,2 do
    local warp=assert(def.warps[index],id.." missing route warp "..index)
    assert(runtime:isWalkableCell(warp.x,warp.y),id.." route warp is not walkable")
    assert(runtime:isWarpTileCell(warp.x,warp.y),id.." route warp lacks native trigger")
  end
end

local iceDef=assert(mod.content.maps:get(blue.ids.ICE));local ice=runtimes[blue.ids.ICE]
assert(#iceDef.warps==8,"Glacier needs two stairs plus six fall warps")
for index=3,#iceDef.warps do
  local warp=iceDef.warps[index]
  assert(ice:warpPadOrHoleAt(warp.x,warp.y)=="hole","fall warp is not native CAVERN $22")
  assert(warp.destMap==blue.ids.ICE and warp.destWarp==1,"fall does not reset to section entrance")
  local target=blue.simulateFall(warp.x..","..warp.y)
  assert(target.map==blue.ids.ICE and target.x==3 and target.y==33,"fall simulation drift")
end

-- User-facing ice gate: the Glacier is one enormous connected native CAVERN
-- field, not a collection of Johto-looking ribbons.  Small dry shelves,
-- native holes and the Strength breakwater may interrupt individual blocks,
-- but the actual ice must retain one dominant component and broad bounds.
local glacierAllowed={[21]=true,[25]=true,[125]=true,[124]=true,[119]=true,
  [120]=true,[104]=true,[105]=true,[108]=true,[29]=true,[57]=true}
local iceBlocks={}
for y=0,iceDef.height-1 do for x=0,iceDef.width-1 do
  local block=iceDef.blocks[x+y*iceDef.width+1]
  assert(glacierAllowed[block],"Glacier contains non-native/private block "..tostring(block))
  if block==21 then iceBlocks[x..":"..y]={x=x,y=y} end
end end
local iceCount,largest,minX,maxX,minY,maxY=0,0,iceDef.width,0,iceDef.height,0
local visited={}
for key,row in pairs(iceBlocks) do
  iceCount=iceCount+1;minX=math.min(minX,row.x);maxX=math.max(maxX,row.x)
  minY=math.min(minY,row.y);maxY=math.max(maxY,row.y)
  if not visited[key] then
    local queue,head,size={{x=row.x,y=row.y}},1,0;visited[key]=true
    while queue[head] do
      local at=queue[head];head=head+1;size=size+1
      for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}}) do
        local other=(at.x+d[1])..":"..(at.y+d[2])
        if iceBlocks[other] and not visited[other] then
          visited[other]=true;queue[#queue+1]={x=at.x+d[1],y=at.y+d[2]}
        end
      end
    end
    largest=math.max(largest,size)
  end
end
io.write(string.format("BLUE_ICE_FIELD blocks=%d largest=%d share=%.1f%% bounds=%dx%d\n",
  iceCount,largest,largest/iceCount*100,maxX-minX+1,maxY-minY+1))
assert(iceCount>=220 and largest>=200 and largest/iceCount>=0.85,
  "Glacier is not one dominant contiguous native ice field")
assert(maxX-minX+1>=20 and maxY-minY+1>=12,
  "Glacier ice field is not visually broad in both axes")
if os.getenv("KA_BLUE_STRUCTURE_ASCII")=="1" then
  local glyph={[125]="#",[25]=".",[21]="i",[118]="~",[124]="P",[29]="T",
    [57]="B",[119]="o",[120]="o",[104]="o",[105]="o",[108]="s"}
  io.write(blue.ids.ICE.."\n")
  for y=0,iceDef.height-1 do
    local row={};for x=0,iceDef.width-1 do
      row[#row+1]=glyph[iceDef.blocks[x+y*iceDef.width+1]] or "?"
    end
    io.write(string.format("%02d %s\n",y,table.concat(row)))
  end
end

local function reachable(runtime,start,allowWater)
  local queue,seen,head={{x=start.x,y=start.y}},{[start.x..":"..start.y]=true},1
  while queue[head] do
    local at=queue[head];head=head+1
    for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}}) do
      local x,y=at.x+d[1],at.y+d[2];local key=x..":"..y
      if not seen[key] and runtime:inBounds(x,y)
          and (runtime:isWalkableCell(x,y) or (allowWater and runtime:isWaterCell(x,y))) then
        seen[key]=true;queue[#queue+1]={x=x,y=y}
      end
    end
  end
  return seen
end
local function reachableNative(runtime,start,allowWater,entities)
  local queue,seen,head={{x=start.x,y=start.y}},{[start.x..":"..start.y]=true},1
  while queue[head] do
    local at=queue[head];head=head+1
    for _,dir in ipairs({"right","left","down","up"}) do
      local mover={cellX=at.x,cellY=at.y,surfing=allowWater==true}
      if Collision.canMove(runtime,entities or {},mover,dir) then
        local d=({right={1,0},left={-1,0},down={0,1},up={0,-1}})[dir]
        local x,y=at.x+d[1],at.y+d[2];local key=x..":"..y
        if not seen[key] then seen[key]=true;queue[#queue+1]={x=x,y=y} end
      end
    end
  end
  return seen
end
local function beside(seen,x,y)
  return seen[(x+1)..":"..y] or seen[(x-1)..":"..y]
      or seen[x..":"..(y+1)] or seen[x..":"..(y-1)]
end

local DIR_ROWS={
  {name="right",dx=1,dy=0},{name="left",dx=-1,dy=0},
  {name="down",dx=0,dy=1},{name="up",dx=0,dy=-1},
}
local function cellKey(x,y)return x..":"..y end
local function statueBlockers(mapId)
  local blocked={}
  for _,statue in pairs(blue.statues) do
    if statue.map==mapId then blocked[cellKey(statue.x,statue.y)]=true end
  end
  return blocked
end
local function nativeGraph(runtime,mapId)
  local blocked=statueBlockers(mapId)
  local graph={}
  for y=0,runtime.def.height*2-1 do for x=0,runtime.def.width*2-1 do
    local key=cellKey(x,y)
    if not blocked[key] and runtime:isWalkableCell(x,y) then
      graph[key]=graph[key] or {}
      for _,dir in ipairs(DIR_ROWS) do
        local nx,ny=x+dir.dx,y+dir.dy;local nextKey=cellKey(nx,ny)
        if not blocked[nextKey]
            and Collision.canMove(runtime,{}, {cellX=x,cellY=y,surfing=false},dir.name) then
          graph[key][nextKey]=true
        end
      end
    end
  end end
  return graph
end
local function distances(graph,starts,avoid)
  local queue,head,dist={},1,{}
  for _,start in ipairs(starts) do
    local key=type(start)=="string" and start or cellKey(start.x,start.y)
    if graph[key] and not (avoid and avoid[key]) and dist[key]==nil then
      dist[key]=0;queue[#queue+1]=key
    end
  end
  while queue[head] do
    local at=queue[head];head=head+1
    for nextKey in pairs(graph[at] or {}) do
      if dist[nextKey]==nil and not(avoid and avoid[nextKey]) then
        dist[nextKey]=dist[at]+1;queue[#queue+1]=nextKey
      end
    end
  end
  return dist
end
local function statueApproaches(runtime,statue)
  local out={}
  for _,dir in ipairs(DIR_ROWS) do
    local x,y=statue.x+dir.dx,statue.y+dir.dy
    if runtime:inBounds(x,y) and runtime:isWalkableCell(x,y) then
      out[#out+1]=cellKey(x,y)
    end
  end
  assert(#out>0,"statue has no interaction cell")
  return out
end
local function minDistance(dist,targets)
  local best
  for _,key in ipairs(targets) do if dist[key]~=nil then
    best=not best and dist[key] or math.min(best,dist[key])
  end end
  return best
end
local function orderedDistance(graph,start,targets)
  local memberships={}
  for phase,set in ipairs(targets) do
    memberships[phase]={};for _,key in ipairs(set) do memberships[phase][key]=true end
  end
  local function advance(key,phase)
    while memberships[phase] and memberships[phase][key] do phase=phase+1 end
    return phase
  end
  local startKey=type(start)=="string" and start or cellKey(start.x,start.y)
  local startPhase=advance(startKey,1)
  local queue,head={{key=startKey,phase=startPhase}},1
  local seen={[startKey.."|"..startPhase]=0}
  while queue[head] do
    local at=queue[head];head=head+1
    local stateKey=at.key.."|"..at.phase;local travelled=seen[stateKey]
    if at.phase>#targets then return travelled end
    for nextKey in pairs(graph[at.key] or {}) do
      local phase=advance(nextKey,at.phase);local key=nextKey.."|"..phase
      if seen[key]==nil then
        seen[key]=travelled+1;queue[#queue+1]={key=nextKey,phase=phase}
      end
    end
  end
  return nil
end
local function minimumTurns(graph,starts,targets,allowed)
  local targetSet={};for _,key in ipairs(targets) do targetSet[key]=true end
  local queue,head,best={},1,{}
  for _,row in ipairs(starts) do
    local key=type(row)=="string" and row or cellKey(row.x,row.y)
    if graph[key] and (not allowed or allowed[key]) then
      local state=key.."|-";best[state]={turns=0,steps=0,key=key,dir="-"}
      queue[#queue+1]=best[state]
    end
  end
  local answer
  while queue[head] do
    local at=queue[head];head=head+1
    local live=best[at.key.."|"..at.dir]
    if live==at then
      if targetSet[at.key] and (not answer or at.turns<answer) then answer=at.turns end
      local ax,ay=at.key:match("^(-?%d+):(-?%d+)$");ax,ay=tonumber(ax),tonumber(ay)
      for nextKey in pairs(graph[at.key] or {}) do if not allowed or allowed[nextKey] then
        local nx,ny=nextKey:match("^(-?%d+):(-?%d+)$");nx,ny=tonumber(nx),tonumber(ny)
        local dir=nx>ax and "right" or nx<ax and "left" or ny>ay and "down" or "up"
        local turns=at.turns+((at.dir=="-" or at.dir==dir) and 0 or 1)
        local steps=at.steps+1;local state=nextKey.."|"..dir;local old=best[state]
        if not old or turns<old.turns or (turns==old.turns and steps<old.steps) then
          local row={turns=turns,steps=steps,key=nextKey,dir=dir}
          best[state]=row;queue[#queue+1]=row
        end
      end end
    end
  end
  return answer
end

-- Quantify the authored cave structure against the exact native movement
-- graph.  Cell-scale loops would count every ordinary 2x2 floor metatile as
-- a fake loop, so loops are measured after collapsing cells to CAVERN blocks.
-- Narrow share deliberately counts only straight cells with two opposite
-- neighbours and rock on both flanks; bends and room edges cannot inflate it.
local directions={
  {name="right",dx=1,dy=0},{name="left",dx=-1,dy=0},
  {name="down",dx=0,dy=1},{name="up",dx=0,dy=-1},
}
local function structureMetrics(runtime,def)
  local start,goal=def.warps[1],def.warps[2]
  local startKey=start.x..":"..start.y
  local queue,head={{x=start.x,y=start.y}},1
  local cells,adj,distance={[startKey]={x=start.x,y=start.y}},{[startKey]={}}, {[startKey]=0}
  while queue[head] do
    local at=queue[head];head=head+1
    local atKey=at.x..":"..at.y;adj[atKey]=adj[atKey] or {}
    for _,d in ipairs(directions) do
      local mover={cellX=at.x,cellY=at.y,surfing=false}
      if Collision.canMove(runtime,{},mover,d.name) then
        local x,y=at.x+d.dx,at.y+d.dy;local key=x..":"..y
        adj[atKey][key]=true;adj[key]=adj[key] or {};adj[key][atKey]=true
        if not cells[key] then
          cells[key]={x=x,y=y};distance[key]=distance[atKey]+1
          queue[#queue+1]={x=x,y=y}
        end
      end
    end
  end

  local cellCount,narrow=0,0
  for key,cell in pairs(cells) do
    cellCount=cellCount+1
    local neighbours=adj[key] or {}
    local left=neighbours[(cell.x-1)..":"..cell.y]
    local right=neighbours[(cell.x+1)..":"..cell.y]
    local up=neighbours[cell.x..":"..(cell.y-1)]
    local down=neighbours[cell.x..":"..(cell.y+1)]
    if (left and right and not up and not down)
        or (up and down and not left and not right) then narrow=narrow+1 end
  end

  local blocks,blockAdj,full={},{},{}
  local function bkey(bx,by)return bx..":"..by end
  for _,cell in pairs(cells) do
    local bx,by=math.floor(cell.x/2),math.floor(cell.y/2);local key=bkey(bx,by)
    blocks[key]=blocks[key] or {x=bx,y=by,count=0};blocks[key].count=blocks[key].count+1
  end
  for key,row in pairs(blocks) do full[key]=row.count==4;blockAdj[key]={} end
  for key,cell in pairs(cells) do
    local from=bkey(math.floor(cell.x/2),math.floor(cell.y/2))
    for other in pairs(adj[key]) do
      local ox,oy=other:match("^(-?%d+):(-?%d+)$")
      local to=bkey(math.floor(tonumber(ox)/2),math.floor(tonumber(oy)/2))
      if from~=to and blocks[to] then blockAdj[from][to]=true;blockAdj[to][from]=true end
    end
  end
  local blockCount,edgeCount=0,0
  for key in pairs(blocks) do
    blockCount=blockCount+1;for _ in pairs(blockAdj[key]) do edgeCount=edgeCount+1 end
  end
  local loops=edgeCount/2-blockCount+1

  local function neighboursAt(row)
    return {
      left=blockAdj[bkey(row.x,row.y)][bkey(row.x-1,row.y)]==true,
      right=blockAdj[bkey(row.x,row.y)][bkey(row.x+1,row.y)]==true,
      up=blockAdj[bkey(row.x,row.y)][bkey(row.x,row.y-1)]==true,
      down=blockAdj[bkey(row.x,row.y)][bkey(row.x,row.y+1)]==true,
    }
  end
  local horizontal,vertical={},{}
  for key,row in pairs(blocks) do
    local n=neighboursAt(row)
    horizontal[key]=full[key] and (n.left or n.right) and not n.up and not n.down
    vertical[key]=full[key] and (n.up or n.down) and not n.left and not n.right
  end
  local function maxRun(candidates,dx,dy)
    local best,bestAt=0,nil
    for key,row in pairs(blocks) do if candidates[key] then
      local previous=bkey(row.x-dx,row.y-dy)
      if not candidates[previous] then
        local length,x,y=0,row.x,row.y
        while candidates[bkey(x,y)] do length=length+1;x=x+dx;y=y+dy end
        if length>best then best=length;bestAt={x=row.x,y=row.y,dx=dx,dy=dy} end
      end
    end end
    return best*2,bestAt
  end
  local horizontalRun,horizontalAt=maxRun(horizontal,1,0)
  local verticalRun,verticalAt=maxRun(vertical,0,1)
  local maxParallel2,maxParallel2At=horizontalRun,horizontalAt
  if verticalRun>maxParallel2 then maxParallel2,maxParallel2At=verticalRun,verticalAt end
  local goalKey=goal.x..":"..goal.y
  local straight=math.sqrt((goal.x-start.x)^2+(goal.y-start.y)^2)
  return {
    cells=cellCount,narrow=narrow,narrowShare=narrow/cellCount,
    maxParallel2=maxParallel2,maxParallel2At=maxParallel2At,
    loops=loops,path=assert(distance[goalKey],def.id.." goal unreachable"),
    tortuosity=distance[goalKey]/straight,
  }
end

-- Each Strength rune is a real chokepoint, not decorative state: before its
-- block replacement the floor's exit must be physically isolated.
for _,id in ipairs({blue.ids.HALL,blue.ids.ICE,blue.ids.DEPTHS}) do
  local def=mod.content.maps:get(id);local seen=reachable(runtimes[id],def.warps[1],false)
  assert(not seen[def.warps[2].x..":"..def.warps[2].y],id.." Strength gate can be bypassed")
end

-- Solve each Strength gate in the static acceptance copy, then prove every
-- mandatory warp/statue has a physical land route.  The secret is separately
-- required to have a Surf route, so it cannot masquerade as mandatory.
for name,spec in pairs(blue.switches) do
  local def=mod.content.maps:get(spec.map)
  def.blocks[spec.gate.bx+spec.gate.by*def.width+1]=spec.gate.open
  local boulder
  for _,obj in ipairs(def.objects) do if obj.name==spec.boulder then boulder=obj break end end
  assert(boulder and boulder.pushable and boulder.sprite=="SPRITE_BOULDER",name.." lacks native Strength boulder")
  assert(boulder.y==spec.goal.y and boulder.x<spec.goal.x,name.." has no authored straight push lane")
  for x=boulder.x-1,spec.goal.x do
    assert(runtimes[spec.map]:isWalkableCell(x,boulder.y),name.." push lane is blocked at "..x..","..boulder.y)
  end
end
for _,id in ipairs(ids) do runtimes[id]=RuntimeMap.new(mod.content.maps:get(id),Data.tilesets.CAVERN) end
local structuralIds={blue.ids.THRESHOLD,blue.ids.HALL,blue.ids.DEPTHS,blue.ids.SHRINE}
for _,id in ipairs(structuralIds) do
  local def=mod.content.maps:get(id);local metrics=structureMetrics(runtimes[id],def)
  io.write(string.format("BLUE_STRUCTURE %s cells=%d narrow=%d share=%.1f%% max2=%d path=%d tort=%.2f loops=%d\n",
    id,metrics.cells,metrics.narrow,metrics.narrowShare*100,metrics.maxParallel2,
    metrics.path,metrics.tortuosity,metrics.loops))
  if metrics.maxParallel2At then
    io.write(string.format("BLUE_STRUCTURE_MAX2 %s start=%d,%d axis=%s\n",id,
      metrics.maxParallel2At.x,metrics.maxParallel2At.y,
      metrics.maxParallel2At.dx==1 and "horizontal" or "vertical"))
  end
  if id~=blue.ids.DEPTHS then
    assert(metrics.narrowShare>=0.15,id.." has fewer than 15% genuine one-cell corridor cells")
    assert(metrics.maxParallel2<=6,id.." retains a parallel two-cell run longer than six cells")
    assert(metrics.tortuosity>=1.15,id.." entry-to-exit route is too direct")
    assert(metrics.loops>=2,id.." lost its authored return loops")
  end
  if os.getenv("KA_BLUE_STRUCTURE_ASCII")=="1" then
    local glyph={[125]="#",[25]=".",[21]="i",[118]="~",[124]="P",[26]="L",[38]="R",
      [29]="T",[57]="B",[41]="s",[127]="o"}
    io.write(id.."\n")
    for y=0,def.height-1 do
      local row={};for x=0,def.width-1 do row[#row+1]=glyph[def.blocks[x+y*def.width+1]] or "?" end
      io.write(string.format("%02d %s\n",y,table.concat(row)))
    end
  end
end

-- Product topology gate requested for the final BLUE release: every statue
-- must sit behind a removable side-arm seam, while removing that seam leaves
-- the mandatory entry-to-exit route intact.  Distances use the same native
-- Collision.canMove graph as real D-pad movement and treat statue cells as
-- occupied objects rather than traversable shortcuts.
local graphs={}
for _,id in ipairs(ids) do graphs[id]=nativeGraph(runtimes[id],id) end
local statueBySight={}
for name,statue in pairs(blue.statues) do statueBySight[statue.sight]={name=name,row=statue} end
local branchDepths={}
for name,branch in pairs(blue.statueBranches) do
  local statue=assert(blue.statues[name],"branch without statue "..name)
  assert(statue.map==branch.map,"branch map drift for "..name)
  local def=mod.content.maps:get(branch.map);local graph=graphs[branch.map]
  local entry=def.warps[1];local exit=def.warps[2]
  local gateSet={};for _,cell in ipairs(branch.gate or {}) do gateSet[cellKey(cell.x,cell.y)]=true end
  assert(next(gateSet),name.." has no physical branch seam")
  local full=distances(graph,{entry})
  local cut=distances(graph,{entry},gateSet)
  local approaches=statueApproaches(runtimes[branch.map],statue)
  assert(minDistance(full,approaches),name.." side arm is unreachable")
  assert(cut[cellKey(exit.x,exit.y)]~=nil,name.." side arm lies on the mandatory route")
  if minDistance(cut,approaches) then
    local escaped={};for _,key in ipairs(approaches) do
      if cut[key]~=nil then escaped[#escaped+1]=key.."@"..cut[key] end
    end
    error(name.." statue has a second/main-route approach: "..table.concat(escaped,","))
  end
  local fromGate=distances(graph,branch.gate)
  local depth=assert(minDistance(fromGate,approaches),name.." branch depth is undefined")
  local interior=distances(graph,approaches,gateSet)
  local allowed={};for key in pairs(interior) do allowed[key]=true end
  for key in pairs(gateSet) do allowed[key]=true end
  local turns=assert(minimumTurns(graph,branch.gate,approaches,allowed),
    name.." branch turn count is undefined")
  branchDepths[name]=depth
  assert(depth>=branch.minDepth,
    ("%s branch is only %d D-pad cells deep (want %d)"):format(name,depth,branch.minDepth))
  assert(turns>=(branch.turns or 2),
    ("%s branch has only %d direction changes (want %d)"):format(name,turns,branch.turns or 2))
  io.write(string.format("BLUE_STATUE_BRANCH %s map=%s depth=%d turns=%d gate=%d\n",
    name,branch.map,depth,turns,#branch.gate))
end

local orderedByMap={
  [blue.ids.THRESHOLD]={},
  [blue.ids.HALL]={"HALL"},
  [blue.ids.ICE]={"ICE_NORTH","ICE_DEEP"},
  [blue.ids.DEPTHS]={"DEPTHS_WEST","DEPTHS_EAST"},
  [blue.ids.SHRINE]={},
}
local mandatoryDistance=0
local entryExit={}
for _,id in ipairs(ids) do
  local def=mod.content.maps:get(id);local graph=graphs[id]
  local plain=distances(graph,{def.warps[1]})
  local exitKey=cellKey(def.warps[2].x,def.warps[2].y)
  entryExit[id]=assert(plain[exitKey],id.." native entry->exit distance missing")
  local targets={}
  for _,name in ipairs(orderedByMap[id]) do
    targets[#targets+1]=statueApproaches(runtimes[id],blue.statues[name])
  end
  targets[#targets+1]={exitKey}
  local required=assert(orderedDistance(graph,def.warps[1],targets),
    id.." cannot visit its ordered memories and exit")
  mandatoryDistance=mandatoryDistance+required
  io.write(string.format("BLUE_FLOOR_ROUTE %s cells=%dx%d entryExit=%d required=%d\n",
    id,def.width*2,def.height*2,entryExit[id],required))
end
assert(mandatoryDistance>=250,
  "BLUE five-memory mandatory route is too short: "..mandatoryDistance)

local finalStatue=blue.statues.DEPTHS_EAST
local depthsExit=mod.content.maps:get(blue.ids.DEPTHS).warps[2]
local fromFinal=distances(graphs[blue.ids.DEPTHS],
  statueApproaches(runtimes[blue.ids.DEPTHS],finalStatue))
local postFifthDepths=assert(fromFinal[cellKey(depthsExit.x,depthsExit.y)],
  "fifth statue has no route to Depths exit")
local postFifth=postFifthDepths+entryExit[blue.ids.SHRINE]
assert(postFifth>40,
  "fifth statue is an exit marker instead of preceding a long finale")
io.write(string.format(
  "BLUE_PRODUCT_ROUTE mandatory=%d statue5ToFinal=%d depthsTail=%d shrine=%d wrongIceDecisions=3 fallCells=%d\n",
  mandatoryDistance,postFifth,postFifthDepths,entryExit[blue.ids.SHRINE],#iceDef.warps-2))
assert(blue.iceGraph.LOWER_BRAKE.RIGHT=="FALL_A"
    and blue.iceGraph.WEST_BRAKE.LEFT=="FALL_B"
    and blue.iceGraph.EAST_BRAKE.RIGHT=="FALL_C",
  "Glacier lost one of its three authored false-slide decisions")

-- The two same-floor pairs must be far beyond both the current sight cone
-- and a gameplay viewport.  Combined with the unique relic role above, a
-- close statue capture can contain exactly one statue-like object.
for _,pair in ipairs({{"ICE_NORTH","ICE_DEEP"},{"DEPTHS_WEST","DEPTHS_EAST"}}) do
  local first,second=blue.statues[pair[1]],blue.statues[pair[2]]
  assert(first.map==second.map,"same-floor statue pair drift")
  local runtime=runtimes[first.map];local graph=graphs[first.map]
  local between=distances(graph,statueApproaches(runtime,first))
  local separation=assert(minDistance(between,statueApproaches(runtime,second)),
    "same-floor statues cannot reach one another")
  assert(separation>=36,
    pair[1].."/"..pair[2].." are close enough to read as simultaneous markers")
  io.write(string.format("BLUE_STATUE_SEPARATION %s %s cells=%d\n",
    pair[1],pair[2],separation))
end
for _,id in ipairs(ids) do
  local def=mod.content.maps:get(id);local seen=reachable(runtimes[id],def.warps[1],false)
  assert(seen[def.warps[2].x..":"..def.warps[2].y],id.." has no solved entry-to-exit route")
  for _,statue in pairs(blue.statues) do
    if statue.map==id then assert(beside(seen,statue.x,statue.y),id.." statue is unreachable") end
  end
end
-- isWalkableCell alone misses CAVERN's native elevation-pair barriers.  The
-- release gate therefore repeats solved progression through the same
-- Collision.canMove contract used by the real D-pad runtime.
for _,id in ipairs(ids) do
  local def=mod.content.maps:get(id);local seen=reachableNative(runtimes[id],def.warps[1],false)
  assert(seen[def.warps[2].x..":"..def.warps[2].y],id.." has no native-collision entry-to-exit route")
  for _,statue in pairs(blue.statues) do
    if statue.map==id then assert(beside(seen,statue.x,statue.y),id.." statue is blocked by native elevation pairs") end
  end
end
local depthsDef=mod.content.maps:get(blue.ids.DEPTHS)
local function reachableSurf(runtime,start)
  local first=start.x..":"..start.y..":1"
  local queue,seen,seenCells,head={{x=start.x,y=start.y,surfing=true}},{[first]=true},
    {[start.x..":"..start.y]=true},1
  while queue[head] do
    local at=queue[head];head=head+1
    for _,dir in ipairs({"right","left","down","up"}) do
      local mover={cellX=at.x,cellY=at.y,surfing=at.surfing}
      if Collision.canMove(runtime,{},mover,dir) then
        local d=({right={1,0},left={-1,0},down={0,1},up={0,-1}})[dir]
        local x,y=at.x+d[1],at.y+d[2]
        -- The native controller dismounts on the first valid land cell.
        local surfing=at.surfing and not runtime:isWalkableCell(x,y)
        local key=x..":"..y..":"..(surfing and 1 or 0)
        if not seen[key] then
          seen[key]=true;seenCells[x..":"..y]=true
          queue[#queue+1]={x=x,y=y,surfing=surfing}
        end
      end
    end
  end
  return seenCells
end
local depthsRuntime=runtimes[blue.ids.DEPTHS]
local secret
for _,obj in ipairs(depthsDef.objects) do if obj.name=="KA_HEVO_BLUE_SWAMPERTITE_CACHE" then secret=obj break end end
assert(secret and secret.x==21 and secret.y==29,"SWAMPERTITE tidal landmark drifted")
assert(depthsRuntime:isWalkableCell(17,21) and depthsRuntime:isWaterCell(17,22),
  "mainland native shore is malformed")
assert(depthsRuntime:isWalkableCell(21,31) and depthsRuntime:isWaterCell(21,32),
  "secret-island native shore is malformed")
assert(Collision.canMove(depthsRuntime,{}, {cellX=17,cellY=22,surfing=true},"up"),
  "native water pair blocks mainland dismount")
assert(Collision.canMove(depthsRuntime,{}, {cellX=21,cellY=32,surfing=true},"up"),
  "native water pair blocks island dismount")
local surfSeen=reachableSurf(depthsRuntime,{x=17,y=22})
assert(beside(surfSeen,secret.x,secret.y),"SWAMPERTITE has no engine-legal Surf approach")
local returnSeen=reachableSurf(depthsRuntime,{x=21,y=32})
assert(returnSeen["17:21"],"SWAMPERTITE island has no engine-legal Surf return")
local landSeen=reachable(depthsRuntime,depthsDef.warps[1],false)
assert(not beside(landSeen,secret.x,secret.y),"SWAMPERTITE secret is reachable without its tidal Surf branch")

-- Runtime NPC positions reset on a native save/reload.  A solved Strength
-- gate must still leave a physical route from the Surf landing back to the
-- Shrine stair even while every authored object is at its original cell.
local reloadEntities={}
for _,obj in ipairs(depthsDef.objects) do
  reloadEntities[#reloadEntities+1]={cellX=obj.x,cellY=obj.y,passable=obj.passable==true,def=obj}
end
local reloadSeen=reachableNative(depthsRuntime,{x=17,y=21},false,reloadEntities)
local shrineWarp=depthsDef.warps[2]
if not beside(reloadSeen,shrineWarp.x,shrineWarp.y) then
  local released={}
  for omit,obj in ipairs(reloadEntities) do
    local others={};for index,row in ipairs(reloadEntities) do if index~=omit then others[#others+1]=row end end
    if beside(reachableNative(depthsRuntime,{x=17,y=21},false,others),shrineWarp.x,shrineWarp.y) then
      released[#released+1]=obj.def.name or tostring(omit)
    end
  end
  error("Depths reload objects seal the Shrine return: "..table.concat(released,","))
end

-- Switches only accept their own boulder at their own goal, persist in the
-- resettable journey bucket and restamp the matching live gate.
assert(not blue.markSwitch(blue.ids.HALL,"wrong",27,25))
for name,spec in pairs(blue.switches) do
  assert(blue.markSwitch(spec.map,spec.boulder,spec.goal.x,spec.goal.y))
  assert(blue.switchSolved(name) and flags[spec.flag]==true,name.." switch did not persist")
  local last=replacements[#replacements]
  assert(last.bx==spec.gate.bx and last.by==spec.gate.by and last.block==spec.gate.open,name.." gate not restamped")
end

-- The slide engine is one-cell-at-a-time.  It calls the normal landing
-- pipeline once per moved cell, stops for occupancy, and may enter a bound
-- native hole as a terminal cell even though the hole itself is not walkable.
local function fakeOw(x,y,facing,entities)
  local ow={map=ice,player={cellX=x,cellY=y,facing=facing,moving=false},entities=entities or {},steps=0,moves=0}
  function ow:scriptMove(player,dir,_,done)
    local d=({up={0,-1},down={0,1},left={-1,0},right={1,0}})[dir]
    player.cellX=player.cellX+d[1];player.cellY=player.cellY+d[2];self.moves=self.moves+1;done()
  end
  function ow:onStepComplete() self.steps=self.steps+1 end
  return ow
end
local function finishHoleBeat(ow)
  assert(blue._holeHold and blue._sliding and ow.player.inputLocked,
    "native-hole beat did not lock the landed player")
  for _=1,15 do
    assert(blue.tickHoleBeat(),"native-hole beat ended before one walk cycle")
    assert(blue._holeHold,"native-hole beat lost its visible hold early")
  end
  assert(blue.tickHoleBeat(),"native-hole beat did not complete")
  assert(not blue._holeHold and not blue._sliding and not ow.player.inputLocked,
    "native-hole beat leaked its lock/slide state")
end
local glide=fakeOw(8,29,"right")
local glideOk,glideWhy=blue.startIceSlide(glide);assert(glideOk,glideWhy)
assert(glide.player.cellX==24 and glide.player.cellY==29,
  ("safe opening glide stopped at %d,%d"):format(glide.player.cellX,glide.player.cellY))
assert(glide.moves==glide.steps and glide.moves>1 and not blue._sliding,"multi-cell jump bypassed landing pipeline")
local blocked=fakeOw(8,29,"right",{{cellX=10,cellY=29,passable=false}})
assert(blue.startIceSlide(blocked));assert(blocked.player.cellX==9 and blocked.moves==1 and blocked.steps==1,"occupancy did not stop slide")
local fall=fakeOw(26,28,"right")
local fallOk,fallWhy=blue.startIceSlide(fall);assert(fallOk,fallWhy)
assert(fall.player.cellX==29 and fall.player.cellY==28,"slide did not enter terminal hole")
assert(fall.moves==fall.steps+1 and blue._sliding,
  "hole slide did not pause before the native landing pipeline")
finishHoleBeat(fall)
assert(fall.moves==fall.steps,
  "hole slide skipped or duplicated its terminal onStepComplete")
for _,spec in ipairs({
  {26,28,"right",29,28},{26,29,"right",30,29},
  {6,16,"left",4,16},{6,17,"left",3,17},
  {38,6,"right",41,6},{38,7,"right",42,7},
}) do
  local branch=fakeOw(spec[1],spec[2],spec[3])
  local ok,why=blue.startIceSlide(branch);assert(ok,why)
  assert(math.abs(spec[4]-spec[1])+math.abs(spec[5]-spec[2])<=4,
    "wrong-line fracture drifted beyond the sight-3 close-up")
  assert(branch.player.cellX==spec[4] and branch.player.cellY==spec[5],
    ("wrong ice branch missed native hole %d,%d"):format(spec[4],spec[5]))
  assert(branch.moves==branch.steps+1 and blue._sliding,
    "wrong ice branch did not pause visibly on its native fracture")
  finishHoleBeat(branch)
  assert(branch.moves==branch.steps,
    "wrong ice branch skipped per-cell landing or continued after its hole")
end

local source=assert(io.open(root.."/hidden_evolution_blue_campaign.lua","rb")):read("*a")
assert(not source:find("KA_HEVO_G2_ICE_PATH",1,true),"Johto Ice Path reference remains in BLUE product")
assert(not source:find("privateAtlas",1,true) and not source:find("private_atlas",1,true),
  "BLUE Glacier depends on a private atlas")
assert(source:find("mix(innerOpacity,outerOpacity,edge)",1,true),
  "BLUE sight shader no longer darkens the inner Rock-Tunnel cone")
assert(source:find("min(featherPx,2.0)/radiusPx",1,true)
    and source:find('shader:send("featherPx",featherPx)',1,true),
  "BLUE sight aperture lacks its <=2-screen-pixel 2D/voxel feather gate")
assert(not source:find("smoothstep(0.82,1.0",1,true)
    and not source:find("smoothstep(0.58,1.0",1,true),
  "BLUE sight aperture restored a radius-proportional stipple band")
assert(not source:find("sightOpacity*edge",1,true),
  "BLUE sight shader restored the old full-palette/white-halo centre")
assert(source:find("queueWorldPostOverlay",1,true),
  "BLUE darkness no longer covers final player/item/voxel composite")
assert(source:find('or "atmosphere%-fallback"')
    and source:find("compatibilityFallback=true",1,true),
  "BLUE lost its released-runtime atmosphere fallback")
assert(source:find("ctx.worldToScreen(px,py)",1,true),
  "BLUE flat darkness is not centred on the physical player")
assert(source:find('voxelRenderer.module(C.game,"Voxel3D")',1,true)
    and source:find('voxelRenderer.module(C.game,"AntiAlias")',1,true),
  "BLUE DRAMALESS darkness lost its real projected-player adapter")
assert(source:find("ow.player.px+8,ow.player.py+16",1,true),
  "BLUE DRAMALESS cone is not projected from the player's actual base")
assert(not source:find("cx,cy=ctx.centerX",1,true),
  "BLUE DRAMALESS cone regressed to the one-cell-offset camera hint")
assert(source:find('setBlendMode("multiply","premultiplied")',1,true),
  "BLUE Glacier lost its world-only native CAVERN frost grade")
assert(not source:find("marchInPlace(player",1,true),
  "BLUE native-hole beat regressed to the NPC-only movement API")
local blueFinalGame={save={}}
local blueDirectSealCalls=0
blue.finalizeEndSeal=function(requestGame)
  assert(requestGame==blueFinalGame,"BLUE end seal changed game authority")
  blueDirectSealCalls=blueDirectSealCalls+1
  return true,{character="BLUE",seal=true,stoneStatus="granted"},"granted"
end
mod.content.map_scripts:get(blue.ids.SHRINE).talk.TEXT_KA_HEVO_BLUE_DOOR(
  blueFinalGame,nil,nil,function() end)
assert(blueDirectSealCalls==1,
  "BLUE visible end seal bypassed the canonical durable-handoff seam")
local driverSource=assert(io.open(root.."/tools/hidden_evolution_blue_pure_input_qa.lua","rb")):read("*a")
assert(driverSource:find('BLUE_QA_TARGETED_SHARED_VISUAL',1,true),
  "BLUE QA lost its bounded shared-tunnel visual mode")
assert(driverSource:find('ow.map.def.borderBlock == 3',1,true)
    and driverSource:find('ow.map.def.tileset == "CAVERN"',1,true),
  "bounded shared-tunnel QA no longer hard-gates native CAVERN border $03")
assert(driverSource:find('shared%-viewport%-receipt')
    and driverSource:find('longestBlankRun',1,true)
    and driverSource:find('width * 0.125',1,true)
    and driverSource:find('density < 0.65',1,true),
  "bounded shared-tunnel QA no longer rejects white/blank viewport bands")
assert(driverSource:find('"presentation%-only", "lower%-return%-pad%-camera"')
    and driverSource:find('"not%-a%-traversal%-proof"'),
  "lower return-pad camera receipt is no longer labelled presentation-only")
assert(driverSource:find('useWarp(2, "ROUTE_24")',1,true)
    and driverSource:find('"44_shared_tunnel_reentry"',1,true),
  "bounded shared-tunnel QA lost physical return or real fissure re-entry")
assert(driverSource:find('sharedVisualShot("01_shared_tunnel_blue_branch", "full journey shared entry")',1,true)
    and driverSource:find('sharedVisualShot("42_shared_tunnel_return_pad", "full journey lower return pad")',1,true)
    and driverSource:find('sharedVisualShot("44_shared_tunnel_reentry", "full journey real fissure re-entry")',1,true),
  "full BLUE journey no longer applies the native-border pixel receipt at entry/return/re-entry")
assert(driverSource:find('"renderer-receipt"',1,true)
    and driverSource:find('"projectedCell"',1,true)
    and driverSource:find('ow.map.def.voxelMode == "FULL"',1,true)
    and driverSource:find('render == "voxel" and pipelineLevel > 0',1,true),
  "full BLUE Voxel journey lost its real FULL/DRAMALESS renderer receipts")
print("hidden_evolution_blue_kanto_trial_test: PASS")
