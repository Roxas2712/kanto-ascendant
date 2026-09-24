-- Neutral, read-only scene data. Gameplay remains with the access owners.
return function(mod)
  local M = {}
  function M.forMap(game, mapId)
    local e, out = mod.exports, {}
    for _, key in ipairs({"hiddenAccessReveal", "hoennEndgameAccess67"}) do
      local owner=e[key]
      if owner and owner.wayfinding then
        for _, marker in ipairs(owner.wayfinding(game, mapId)) do out[#out+1]=marker end
      end
    end
    local habitat = e.starterHabitats and e.starterHabitats.maps[mapId]
    if habitat then
      out[#out+1]={id=mapId.."_EXIT",kind="exit",x=habitat.exit.x,
        y=habitat.exit.y,facing="down",lit=true}
    end
    local regis = e.hoennResearchSanctums67
    local row = regis and regis.byMap[mapId]
    if row then
      -- The existing return sign also acts as a walk-through exit.
      out[#out+1]={id=mapId.."_RETURN",kind="exit",x=8,y=13,
        facing="down",theme=row.species,lit=true}
    end
    return out
  end
  local glyphs={E={"111","100","110","100","111"},X={"101","101","010","101","101"},
    I={"111","010","010","010","111"},T={"111","010","010","010","010"}}
  local angles={south=0,down=0,north=math.pi,up=math.pi,
    east=math.pi/2,right=math.pi/2,west=-math.pi/2,left=-math.pi/2}
  local flatCache={}
  function M.drawFlat(game, ow, camX, camY)
    if not (ow and ow.map and love and love.graphics) then return end
    local now=love.timer.getTime()
    if flatCache.map~=ow.map or flatCache.save~=game.save or now>=(flatCache.untilTime or 0) then
      flatCache={map=ow.map,save=game.save,untilTime=now+.2,rows=M.forMap(game,ow.map.id)}
    end
    if #flatCache.rows==0 then return end
    local g=love.graphics
    g.push("all");g.setShader();g.setColor(1,1,1,1)
    local function mark(x,y,facing,kind,lit)
      local water=ow.map:inBounds(x,y) and ow.map:isWaterCell(x,y)
      g.push();g.translate(x*16+8-math.floor(camX),y*16+8-math.floor(camY))
      if water then
        -- Small luminous buoys, with a dark waterline and white/red float.
        for _,dx in ipairs({-6,6})do
          g.setColor(.06,.22,.28,1);g.rectangle('fill',dx-3,2,6,2)
          g.setColor(.88,.94,.94,1);g.rectangle('fill',dx-2,0,4,2)
          g.setColor(.83,.30,.20,1);g.rectangle('fill',dx-1,-2,2,2)
          g.setColor(.46,1,.73,1);g.rectangle('fill',dx-1,-4,2,2)
        end
      else
        g.rotate(-(angles[facing]or 0))
        local function paint(x,y,w,h)
          -- A one-pixel dark edge keeps luminous paint legible on snow,
          -- pale sand and the original monochrome habitat palette.
          g.setColor(.10,.25,.20,1);g.rectangle('fill',x,y+1,w,h)
          g.setColor(lit and .65 or .45,lit and 1 or .53,lit and .78 or .48,1)
          g.rectangle('fill',x,y,w,h)
        end
        if kind=='exit' then
          for i,ch in ipairs({'E','X','I','T'})do for yy,line in ipairs(glyphs[ch])do
            for xx=1,3 do if line:sub(xx,xx)=='1'then paint(-8+(i-1)*4+xx-1,yy-8,1,1)end end
          end end
        end
        paint(-1,-1,2,6);paint(-3,2,6,1);paint(-2,3,4,1)
      end
      g.pop()
    end
    for _,row in ipairs(flatCache.rows)do
      mark(row.x,row.kind=='researcher'and row.y+1 or row.y,row.facing,row.kind,row.lit)
      for i,p in ipairs(row.path or{})do if i%2==1 then
        local x,y=p.x or p[1],p.y or p[2]
        local n=row.path[i+1]or{x=row.x,y=row.y};local nx,ny=n.x or n[1],n.y or n[2]
        mark(x,y,nx>x and'east'or nx<x and'west'or ny<y and'north'or'south','trail',true)
      end end
    end
    g.pop()
  end
  function M.install(game)
    local OW=require('src.world.OverworldController')
    local holder=OW.__kaAccessWayfinding
    if holder then holder.owner=M;holder.game=game;return end
    if type(OW.drawShipAnim)~='function' then return false end
    holder={owner=M,game=game};OW.__kaAccessWayfinding=holder
    local draw=OW.drawShipAnim
    -- The engine calls this seam after terrain, before actors, only on its
    -- native flat/tilt path (including a genuine renderer fallback).
    OW.drawShipAnim=function(ow,x,y,...)
      local result=draw(ow,x,y,...)
      holder.owner.drawFlat(holder.game,ow,x,y)
      return result
    end
    return true
  end
  if mod.events and mod.events.on then
    for _,event in ipairs({'game.ready','save.loaded'})do
      mod.events:on(event,function(ev)M.install(ev and ev.game or require('src.core.Game'))end,2810)
    end
  end
  return M
end
