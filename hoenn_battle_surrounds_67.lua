-- Card-local outer scenery for the small Hoenn endgame overworld maps.
--
-- The authored map, its blocks, puzzles, collision and warps remain wholly
-- untouched. This module owns only the Overworld map letterbox: the physical
-- pixels outside the engine's enlarged map canvas. The engine's
-- `render.letterbox` seam runs *under* that canvas, so this Card uses the
-- public post-composite `render.hud` seam and scissors every draw to the
-- actually uncovered bars. It is deliberately inactive as soon as
-- any battle/menu state covers the overworld, so the standard battle field,
-- HUD and battle surround remain byte-for-byte on their existing renderer
-- path. Switching the owning Card OFF is an immediate cold pass-through.

return function(mod,opts)
  opts=opts or{}
  local C={
    OWNER="kasc.hoenn-endgame-overworld-letterbox/v3",
    CONTRACT="kasc-card-local-overworld-map-letterbox/v3",
    installed=false,lastError=nil,drawCount=0,animationFrame=0,
    lastTarget=nil,lastBars=0,
  }
  local activeGame
  local TARGETS={
    KA_MOLTRES_VOLCANO_BASE={kind="volcano",option="hoenn_moltres_volcano"},
    KA_MOLTRES_VOLCANO_ASCENT={kind="volcano",option="hoenn_moltres_volcano"},
    KA_MOLTRES_VOLCANO={kind="volcano",option="hoenn_moltres_volcano"},
    KA_HEVO_RAYQUAZA_CHAMBER={kind="sky",option="hoenn_legend_portals"},
  }
  C.targets=TARGETS

  local function optionEnabled(game,key)
    local bucket=game and game.mods and game.mods.modOptions
      and game.mods.modOptions[mod.id]
    if type(bucket)=="table"and bucket[key]~=nil then
      return bucket[key]~=false
    end
    local saved=game and game.save and game.save.options
      and game.save.options.modOptions
      and game.save.options.modOptions[mod.id]
    if type(saved)=="table"and saved[key]~=nil then return saved[key]~=false end
    local value=mod.options and type(mod.options.get)=="function"
      and mod.options:get(key)
    return value~=false
  end

  local function mapId(map)
    return type(map)=="table"and tostring(map.id
      or type(map.def)=="table"and map.def.id or"")or tostring(map or"")
  end
  function C.activeTarget(game,map)
    local target=TARGETS[mapId(map)]
    if not target or not optionEnabled(game,target.option)then return nil end
    return target
  end

  -- The source map normally remains below BattleState for BATTLE BG WORLD.
  -- Requiring OverworldController itself to be top prevents the decoration
  -- from leaking into any battle/menu merely because that map still exists.
  function C.mapViewTarget(game)
    -- Padding rectangles use the flat map camera. A world renderer has its
    -- own camera and complete sky/terrain; these rectangles would cover it
    -- with opaque blocks, even though the native map data is unchanged.
    local ok,pipelines=pcall(require,"src.render.Pipelines")
    if ok and pipelines and type(pipelines.worldPipeline)=="function"then
      local success,owner=pcall(pipelines.worldPipeline)
      if success and owner then return nil end
    end
    local stack=game and game.stack
    local top=stack and type(stack.top)=="function"and stack:top()or nil
    if not(top and(top==game.overworld or top.isOverworld==true))then return nil end
    return C.activeTarget(game,game.overworld and game.overworld.map)
  end

  local function color(g,c)
    g.setColor(c[1]/255,c[2]/255,c[3]/255,(c[4]or 255)/255)
  end
  local function rect(g,c,x,y,w,h)
    color(g,c);g.rectangle("fill",math.floor(x),math.floor(y),
      math.ceil(w),math.ceil(h))
  end

  local function paintSky(g,w,h,t)
    rect(g,{35,91,157},0,0,w,h*.28)
    rect(g,{65,139,199},0,h*.28,w,h*.28)
    rect(g,{116,188,225},0,h*.56,w,h*.44)
    -- Slow cloud drift animates Voxel-capable presentation; t=0 remains a
    -- deterministic, complete fallback for fixed/headless renderers.
    local drift=(t*w*.009)%(w*1.28)-w*.28
    local function cloud(x,y,s)
      rect(g,{218,240,248},x,y,w*.22*s,h*.038*s)
      rect(g,{242,250,252},x+w*.036*s,y-h*.030*s,w*.13*s,h*.068*s)
      rect(g,{187,220,236},x+w*.019*s,y+h*.038*s,w*.18*s,h*.015*s)
    end
    cloud(drift,h*.24,1)
    cloud((drift+w*.58)%(w*1.24)-w*.18,h*.57,.72)
    cloud((drift+w*.21)%(w*1.22)-w*.15,h*.76,.55)
    -- These edge wisps remain visible in the narrow right/bottom padding of
    -- the 8x8 Rayquaza platform while still drifting between frames.
    cloud(w*.83+math.sin(t*.08)*w*.055,h*.34,.46)
    cloud(w*.67+math.sin(t*.055+1.7)*w*.08,h*.88,.70)
  end

  local function paintVolcano(g,w,h,t)
    -- Airborne crater atmosphere, not another rock/lava floor around the
    -- authored room: smoke banks, hot haze and drifting ash.
    rect(g,{29,14,19},0,0,w,h)
    rect(g,{61,25,27},0,h*.22,w,h*.78)
    local drift=(t*w*.007)%(w*1.32)-w*.32
    local function smog(x,y,s,hot)
      rect(g,hot and{128,55,37}or{76,58,57},x,y,w*.30*s,h*.052*s)
      rect(g,hot and{164,69,37}or{96,72,66},x+w*.048*s,y-h*.043*s,
        w*.18*s,h*.09*s)
      rect(g,{48,38,41},x+w*.019*s,y+h*.05*s,w*.245*s,h*.025*s)
    end
    smog(drift,h*.24,1,false)
    smog((drift+w*.53)%(w*1.32)-w*.25,h*.52,.86,true)
    smog((drift+w*.17)%(w*1.28)-w*.19,h*.79,.64,false)
    -- The playable volcano nearly fills the viewport.  These two layered
    -- plumes are deliberately anchored at the narrow left/right letterbox
    -- bars so the intended airborne smoke remains unmistakable even when the
    -- broad drifting banks happen to be behind the authored map body.  The
    -- scissor installed by the caller still prevents a single map pixel from
    -- being covered.
    local edgeDrift=math.sin(t*.055)*w*.026
    local function plume(x,y,flip)
      local d=flip and-edgeDrift or edgeDrift
      rect(g,{67,55,57},x+d,y,w*.19,h*.042)
      rect(g,{95,72,66},x+w*.025+d,y-h*.035,w*.14,h*.075)
      rect(g,{119,70,55},x+w*.052-d*.45,y-h*.067,w*.095,h*.060)
      rect(g,{48,40,44},x+w*.012-d*.25,y+h*.042,w*.165,h*.026)
    end
    plume(-w*.075,h*.18,false)
    plume(-w*.10,h*.55,true)
    plume(w*.88,h*.31,true)
    plume(w*.855,h*.70,false)
    local particle=w<400 and 1 or 5
    for i=0,25 do
      local x=((i*w*.187+w*.043+t*(i%3+2)*w*.005)%(w+w*.032))-w*.016
      local y=((i*h*.113+h*.071+t*(i%4+1)*h*.003)%(h+h*.024))-h*.012
      local hot=i%6==0
      rect(g,hot and{242,119,35}or{138,119,105},x,y,
        hot and particle+2 or particle,hot and particle+2 or particle)
    end
  end

  function C.paint(kind,g,w,h,t)
    t=tonumber(t)or 0
    if kind=="sky"then paintSky(g,w,h,t);return true end
    if kind=="volcano"then paintVolcano(g,w,h,t);return true end
    return false
  end

  local function renderer()
    if opts.renderer then return opts.renderer end
    local ok,value=pcall(require,"src.render.Renderer")
    if ok then return value end
  end

  -- Exact uncovered rectangles around the enlarged Overworld world canvas.
  -- The result is window-space only and never overlaps a single map pixel.
  function C.outerBars(frame,world)
    if type(frame)~="table"or type(world)~="table"then return{}end
    local vx=tonumber(frame.vux or frame.x)or 0
    local vy=tonumber(frame.vuy or frame.y)or 0
    local vw=tonumber(frame.vuw or frame.width)or 0
    local vh=tonumber(frame.vuh or frame.height)or 0
    local wx=tonumber(world.x)or 0
    local wy=tonumber(world.y)or 0
    local ww=tonumber(world.width)or 0
    local wh=tonumber(world.height)or 0
    if vw<=0 or vh<=0 or ww<=0 or wh<=0 then return{}end
    local x1,y1,x2,y2=vx,vy,vx+vw,vy+vh
    local ix1=math.max(x1,math.min(x2,wx))
    local iy1=math.max(y1,math.min(y2,wy))
    local ix2=math.max(x1,math.min(x2,wx+ww))
    local iy2=math.max(y1,math.min(y2,wy+wh))
    local bars={}
    local function add(x,y,w,h)if w>0 and h>0 then bars[#bars+1]={x,y,w,h}end end
    add(x1,y1,vw,iy1-y1)
    add(x1,iy2,vw,y2-iy2)
    add(x1,iy1,ix1-x1,iy2-iy1)
    add(ix2,iy1,x2-ix2,iy2-iy1)
    return bars
  end

  function C.worldPresentation()
    local R=renderer()
    if not(R and type(R.frameRects)=="function"and R.worldCanvas
        and type(R.worldCanvas.getWidth)=="function"
        and type(R.worldCanvas.getHeight)=="function")then return nil,nil end
    local frame=R:frameRects()
    local sp=frame.Sp
    local ok,Zoom=pcall(require,"src.render.Zoom")
    if ok and Zoom and type(Zoom.scale)=="function"then sp=Zoom.scale(sp)end
    sp=tonumber(sp)or 1
    local sx=sp/(tonumber(frame.dpiX)or 1)
    local sy=sp/(tonumber(frame.dpiY)or 1)
    local cw,ch=R.worldCanvas:getWidth(),R.worldCanvas:getHeight()
    local wx=((tonumber(frame.vx)or 0)
      +math.floor(((tonumber(frame.pw)or 0)-cw*sp)/2))/(tonumber(frame.dpiX)or 1)
    local wy=((tonumber(frame.vy)or 0)
      +math.floor(((tonumber(frame.ph)or 0)-ch*sp)/2)
      -(tonumber(frame.lift)or 0))/(tonumber(frame.dpiY)or 1)
    return frame,{x=wx,y=wy,width=cw*sx,height=ch*sy,
      scaleX=sx,scaleY=sy}
  end

  -- The imported editor maps intentionally retain padding blocks around the
  -- playable room. They are part of the immutable block array, so replacing
  -- them in data would violate map authority. Instead, identify only those
  -- visual padding cells and cover their projected rectangles after the map
  -- composite. Non-padding blocks, collision and object layers are untouched.
  function C.mapBodyRect(game,frame,world)
    local map=game and game.overworld and game.overworld.map
    local def=map and(map.def or map)
    local mw=def and tonumber(def.width)
    local mh=def and tonumber(def.height)
    local cam=game and game.overworld and game.overworld.camera
    if not(mw and mh and cam and world)then return nil end
    local sx,sy=world.scaleX or 1,world.scaleY or 1
    return{x=world.x-math.floor(tonumber(cam.x)or 0)*sx,
      y=world.y-math.floor((tonumber(cam.y)or 0)
        +(tonumber(game.overworld.bgShakeY)or 0))*sy,
      width=mw*32*sx,height=mh*32*sy,scaleX=sx,scaleY=sy}
  end

  function C.mapPaddingRects(game,target,frame,world)
    local map=game and game.overworld and game.overworld.map
    local def=map and(map.def or map)
    local blocks=def and def.blocks
    local mw=def and tonumber(def.width)
    local mh=def and tonumber(def.height)
    local body=C.mapBodyRect(game,frame,world)
    if type(blocks)~="table"or not(mw and mh and body)then return{}end
    local padding=target.kind=="volcano"and 0 or target.kind=="sky"and 2
    if padding==nil then return{}end
    local sx,sy=body.scaleX,body.scaleY
    local ox,oy=body.x,body.y
    local vx,vy=frame.vux,frame.vuy
    local vx2,vy2=vx+frame.vuw,vy+frame.vuh
    local out={}
    for by=0,mh-1 do for bx=0,mw-1 do
      if blocks[by*mw+bx+1]==padding then
        local x1=math.max(vx,ox+bx*32*sx)
        local y1=math.max(vy,oy+by*32*sy)
        local x2=math.min(vx2,ox+(bx+1)*32*sx)
        local y2=math.min(vy2,oy+(by+1)*32*sy)
        if x2>x1 and y2>y1 then out[#out+1]={x1,y1,x2-x1,y2-y1}end
      end
    end end
    return out
  end

  local function installLetterbox()
    if C.installed then return true,"refreshed"end
    if not(mod.hooks and type(mod.hooks.wrap)=="function")then
      C.lastError="render-hud-hook-unavailable";return false,C.lastError
    end
    mod.hooks:wrap("render.hud",function(nextDraw,game,context)
      local result=nextDraw(game,context)
      local target=C.mapViewTarget(activeGame)
      local g=love and love.graphics
      if not(target and g and type(g.setColor)=="function"
          and type(g.rectangle)=="function"and type(g.setScissor)=="function")then
        return result
      end
      local frame,world=C.worldPresentation()
      local bars=C.outerBars(frame,world)
      local body=C.mapBodyRect(activeGame,frame,world)
      for _,bar in ipairs(C.outerBars(frame,body))do bars[#bars+1]=bar end
      local padding=C.mapPaddingRects(activeGame,target,frame,world)
      for _,bar in ipairs(padding)do bars[#bars+1]=bar end
      local w=tonumber(frame and frame.ww)or tonumber(context and context.width)or 0
      local h=tonumber(frame and frame.wh)or tonumber(context and context.height)or 0
      if w<=0 or h<=0 then return result end
      C.animationFrame=C.animationFrame+1
      local t=C.animationFrame
      for _,bar in ipairs(bars)do
        g.setScissor(bar[1],bar[2],bar[3],bar[4])
        C.paint(target.kind,g,w,h,t)
      end
      g.setScissor()
      g.setColor(1,1,1,1)
      if #bars>0 then C.drawCount=C.drawCount+1 end
      C.lastTarget=target.kind;C.lastBars=#bars
      return result
    end,900)
    C.installed=true;C.lastError=nil
    return true,"installed"
  end
  function C.install(game)
    activeGame=game or activeGame
    return installLetterbox()
  end

  function C.status()
    return{owner=C.OWNER,contract=C.CONTRACT,
      installed=C.installed,
      lastError=C.lastError,
      maps={"KA_MOLTRES_VOLCANO_BASE","KA_MOLTRES_VOLCANO_ASCENT",
        "KA_MOLTRES_VOLCANO","KA_HEVO_RAYQUAZA_CHAMBER"},
      mapMutation=false,battleMutation=false,battleRendererMutation=false,
      rendererSeams={"render.hud"},drawCount=C.drawCount,
      lastTarget=C.lastTarget,lastBars=C.lastBars,
      animationFrame=C.animationFrame,
      animation="render-frame-drift-with-static-t0-fallback",
      rollback="owning-card-option"}
  end
  return C
end
