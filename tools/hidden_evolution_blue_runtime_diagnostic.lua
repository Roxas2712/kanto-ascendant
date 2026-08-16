-- Short diagnostic only: inspect live collision/object coordinates while
-- repairing a failed physical-input route.  This is never acceptance proof;
-- the pure driver remains the sole traversal/capture evidence.
return function(game)
  local U=dofile("tests/drivers/util.lua")
  local tracePath=os.getenv("KA_HEVO_DIAG_LOG")
  local trace=tracePath and assert(io.open(tracePath,"w")) or nil
  local function report(...)
    print(...)
    if trace then
      local row={};for i=1,select("#",...) do row[#row+1]=tostring(select(i,...)) end
      trace:write(table.concat(row,"\t"),"\n");trace:flush()
    end
  end
  local diagnosticMap=os.getenv("KA_HEVO_DIAG_MAP") or "KA_HEVO_BLUE_GLACIER_MAZE"
  local diagnosticX=tonumber(os.getenv("KA_HEVO_DIAG_X")) or 3
  local diagnosticY=tonumber(os.getenv("KA_HEVO_DIAG_Y")) or 29
  U.teleport(game,diagnosticMap,diagnosticX,diagnosticY,"up")
  U.wait(30)
  local ow=assert(game.overworld)
  local capture=os.getenv("KA_HEVO_DIAG_SHOT")
  if capture then
    -- Prototype capture only: close any location ribbon through normal input
    -- and leave the renderer a full settle window before saving the frame.
    U.tap(game,"b"); U.wait(30)
    assert(U.shot(game,capture), "diagnostic prototype capture failed")
  end
  print("BLUE DIAG MAP",ow.map.id,ow.player.cellX,ow.player.cellY)
  for _,n in ipairs(ow.npcs or {}) do
    print("BLUE DIAG NPC",tostring(n.def and n.def.text),n.cellX,n.cellY,
      ow.map:isWalkableCell(n.cellX,n.cellY),n.def and n.def.name or "")
  end
  for index,w in ipairs(ow.map.def.warps or {}) do
    local bx,by=math.floor(w.x/2),math.floor(w.y/2)
    print("BLUE DIAG WARP",index,w.x,w.y,"tile",ow.map:cellTile(w.x,w.y),"block",ow.map:blockAt(bx,by),
      "walk",ow.map:isWalkableCell(w.x,w.y),"native",ow.map:isWarpTileCell(w.x,w.y),"entry",ow.warpEntryCell and (ow.warpEntryCell.x..","..ow.warpEntryCell.y) or "nil","standing",tostring(ow.standingOnWarp))
  end
  local campaign=assert(game.mods.exports.kanto_ascendant.hiddenEvolutionCampaign)
  local blue=assert(campaign.modules and campaign.modules.BLUE)
  local function blockAt(x,y) return blue.cellBlock(blue.layouts[ow.map.id],x,y) end
  local function step(state,d)
    local x,y=state.x+d[1],state.y+d[2]
    if not ow.map:inBounds(x,y) or not ow.map:isWalkableCell(x,y) then return nil end
    local ICE=77
    if blockAt(x,y)==ICE then
      while true do
        local nx,ny=x+d[1],y+d[2]
        if not ow.map:inBounds(nx,ny) or not ow.map:isWalkableCell(nx,ny) then break end
        x,y=nx,ny
        if blockAt(x,y)~=ICE then break end
      end
    end
    return {x=x,y=y}
  end
  local function route(tx,ty)
    local start={x=3,y=33};local key=function(p)return p.x..":"..p.y end
    local queue,head={start},1;local prev={[key(start)]=false};local finish
    while queue[head] do
      local here=queue[head];head=head+1
      if here.x==tx and here.y==ty then finish=key(here);break end
      for _,d in ipairs({{1,0,"right"},{-1,0,"left"},{0,1,"down"},{0,-1,"up"}}) do
        local next=step(here,d);local tag=next and key(next)
        if tag and prev[tag]==nil then prev[tag]={key(here),d[3]};queue[#queue+1]=next end
      end
    end
    if not finish then print("BLUE DIAG NO ROUTE",tx,ty);return end
    local moves={};while prev[finish] do local row=prev[finish];moves[#moves+1]=row[2];finish=row[1] end
    local out={};for i=#moves,1,-1 do out[#out+1]=moves[i] end
    print("BLUE DIAG ROUTE",tx,ty,table.concat(out,","))
  end
  route(24,9);route(25,10);route(36,21);route(37,22);route(46,9)
  if os.getenv("KA_HEVO_DIAG_INPUT")=="1" then
    local function state(label)
      local p=ow.player; local bx,by=math.floor(p.cellX/2),math.floor(p.cellY/2)
      print("BLUE DIAG STATE",label,ow.map.id,p.cellX,p.cellY,p.facing,"tile",ow.map:cellTile(p.cellX,p.cellY),"block",ow.map:blockAt(bx,by),"native",ow.map:isWarpTileCell(p.cellX,p.cellY),"warp",ow.map:warpAtCell(p.cellX,p.cellY) and "yes" or "no","entry",ow.warpEntryCell and (ow.warpEntryCell.x..","..ow.warpEntryCell.y) or "nil","standing",tostring(ow.standingOnWarp))
    end
    if os.getenv("KA_HEVO_DIAG_WARP")=="1" then
      state("before")
      for _,dir in ipairs({"left","left"}) do U.tap(game,dir); U.wait(60); state("after-"..dir) end
      love.event.quit(0); return
    end
    local moves={"right","right","right","right","right","right","right","right",
      "up","up","up","up","up","up","up","up","up","up",
      "right","right","right","up","right","up","up","left","left","up","up","up","up"}
    for i,dir in ipairs(moves) do
      local x,y=ow.player.cellX,ow.player.cellY
      for _=1,2 do
        U.tap(game,dir);U.wait(42)
        if ow.player.cellX~=x or ow.player.cellY~=y then break end
      end
      assert(ow.player.cellX~=x or ow.player.cellY~=y,"diagnostic physical move blocked at "..x..","..y.." via "..dir)
      report("BLUE DIAG INPUT",i,dir,ow.player.cellX,ow.player.cellY,ow.player.moving)
    end
    assert(ow.player.cellX==24 and ow.player.cellY==9,
      ("diagnostic route ended %d,%d not north statue approach"):format(ow.player.cellX,ow.player.cellY))
    local shotDir=os.getenv("SHOT_DIR")
    if shotDir then assert(U.shot(game,shotDir.."/blue_ice_north_approach.png")) end
  end
  if trace then trace:close() end
  love.event.quit(0)
end
