-- The seventh Gym keeps its quiz rooms; only its leader moves underground.
-- No quest/save gates: these maps also serve existing campaigns and NG+.
return function(mod, opts)
  opts = opts or {}
  local R = { GYM = 'CINNABAR_GYM', TUNNEL = 'KA_BLAINE_GYM_TUNNEL',
    FOOT = 'KA_BLAINE_VOLCANO_FOOT', CHAMBER = 'KA_BLAINE_VOLCANO_GYM' }
  local function tr(en, de)
    return opts.i18n and opts.i18n.text(en, de) or en
  end
  local function copy(v)
    if type(v) ~= 'table' then return v end
    local out = {}; for k, child in pairs(v) do out[k] = copy(child) end
    return out
  end
  function R.canonicalMap(id)
    return id == R.CHAMBER and R.GYM or id
  end
  function R.trainerKey(ow, npc)
    if ow and ow.map and ow.map.id == R.CHAMBER and npc and npc.def
        and npc.def.name == 'CINNABARGYM_BLAINE' then
      return 'CINNABAR_GYM_obj_1'
    end
  end
  local function map(id, index, label, tileset, w, h, border)
    local m = {id=id,index=index,label=label,tileset=tileset,width=w,height=h,
      borderBlock=border,blocks={},objects={},warps={},signs={},connections={},
      voxelMode='FULL',voxelRevision=1,voxelAuthority='2D_BLOCKS',
      kaOwner='kasc.blaine-volcano-route/v1'}
    for i=1,w*h do m.blocks[i]=border end
    return m
  end
  local function put(m,x,y,b) m.blocks[y*m.width+x+1]=b end
  local function rect(m,x1,y1,x2,y2,b)
    for y=y1,y2 do for x=x1,x2 do put(m,x,y,b) end end
  end
  -- Explicit landings sit beside the trigger, never on the reciprocal stair.
  R.links = {
    [R.GYM]={{x=3,y=2,map=R.TUNNEL,toX=44,toY=8,facing='left'}},
    [R.TUNNEL]={
      {x=45,y=8,map=R.GYM,toX=3,toY=3,facing='down'},
      {x=5,y=4,map=R.FOOT,toX=15,toY=19,facing='up'},
    },
    [R.FOOT]={
      {x=15,y=20,map=R.TUNNEL,toX=5,toY=5,facing='down'},
      {x=15,y=12,map=R.CHAMBER,toX=24,toY=28,facing='up'},
    },
    [R.CHAMBER]={{x=24,y=29,map=R.FOOT,toX=15,toY=13,facing='down'}},
  }
  function R.onStep(game, ow, x, y)
    for _,link in ipairs(R.links[ow.map.id] or {}) do
      if link.x==x and link.y==y then
        local ok,reason=mod.world:warpTo(link.map,link.toX,link.toY,link.facing)
        if ok then
          -- Scripted links bypass native door SFX; play exactly one normal
          -- map-transition cue without enabling the door auto-walk behavior.
          require('src.core.Sound').play(game.data,link.map==R.FOOT and 'Go_Outside' or 'Go_Inside')
        end
        return ok,reason
      end
    end
    return false
  end
  function R.register()
    if R.registered then return false,'registered' end
    local gym=mod.content.maps:get(R.GYM)
    if not gym then return false,'missing-gym' end
    local volcano=assert(opts.volcanoTileset,'volcano tileset missing')
    local skin=assert(mod.content.tilesets:get(volcano),'volcano skin unavailable')
    local palette='KA_BLAINE_VOLCANIC_ROCK'
    if mod.content.palettes then
      mod.content.palettes:register(palette,
        {{255,226,189},{206,132,74},{115,66,49},{25,16,16}})
    end
    local arenaSkin=copy(skin)
    arenaSkin.id='KA_BLAINE_VOLCANO_ARENA'
    -- Lava is scenery, never surfable water or a walkable shortcut.
    arenaSkin.waterTiles={};arenaSkin.shoreTiles={}
    arenaSkin.blocks[129]={20,20,20,20,20,20,20,20,20,20,20,20,20,20,20,20}
    mod.content.tilesets:register(arenaSkin.id,arenaSkin)
    local ok,palettes=pcall(require,'data.palettes_gbc')
    if ok and palettes.world then
      local w=palettes.world
      if w.groupColors and w.tileGroups then
        w.groupColors[arenaSkin.id]=copy(w.groupColors[volcano])
        w.tileGroups[arenaSkin.id]=copy(w.tileGroups[volcano])
      end
    end
    for id,m in mod.content.maps:each() do
      assert(not (m.index and m.index>=1996 and m.index<=1998),
        'Blaine route map index occupied: '..id)
    end
    local tunnel=map(R.TUNNEL,1996,tr('GYM SERVICE TUNNEL','ARENA-VERBINDUNGSGANG'),
      gym.tileset,24,7,46)
    -- The native Gym's checkerboard floor, panelled walls and equipment.
    rect(tunnel,1,1,22,5,14)
    for x=1,22 do put(tunnel,x,1,65);put(tunnel,x,5,73) end
    for y=2,4 do put(tunnel,1,y,68);put(tunnel,22,y,70) end
    for _,x in ipairs{8,13,18} do put(tunnel,x,2,19) end
    put(tunnel,2,2,110);put(tunnel,22,4,110)
    -- A broad ash clearing in front of the volcano, with a visible cave mouth.
    local foot=map(R.FOOT,1997,tr('VOLCANO FOOTHILLS','AM VULKANFUSS'),volcano,16,12,125)
    foot.outdoor=true;foot.voxelSurround='volcano';foot.palette=palette
    rect(foot,2,3,13,10,25)
    for x=2,13 do put(foot,x,3,64);put(foot,x,10,33) end
    for y=4,9 do put(foot,2,y,23);put(foot,13,y,26) end
    rect(foot,4,1,10,5,125)
    for x=4,10 do put(foot,x,5,33) end
    put(foot,7,5,117)
    put(foot,7,10,61)
    put(foot,3,7,77);put(foot,11,7,77)
    -- Native label/index keep Blaine's exact battle header and victory text.
    local chamber=map(R.CHAMBER,1998,gym.label,arenaSkin.id,24,18,125)
    chamber.voxelSurround='volcano';chamber.palette=palette
    rect(chamber,1,1,22,16,128)
    rect(chamber,8,5,16,10,25)
    for x=8,16 do put(chamber,x,5,41);put(chamber,x,10,41) end
    rect(chamber,12,11,12,14,41)
    put(chamber,12,14,60)
    -- A compact 3:2 Pokemon court leaves a lava moat on every side.
    -- Keep the broad crater envelope; only the platform and entrance bridge
    -- are walkable. VASC consumes this versioned geometry contract.
    chamber.kaArenaGeometry={version=2,kind='suspended-over-lava',
      platform={x=16,y=10,width=18,height=12},
      bridge={x=24,y=22,width=2,height=8},
      suspensionAnchors={{16,10},{33,10},{16,21},{33,21}},
      leader={x=25,y=12},entry={x=24,y=28},lavaBlock=128,
      lavaBounds={x=2,y=2,width=44,height=32},
      coordinateUnit='16px-cell',rendering='compact-court-awaiting-VASC-suspension'}
    local objects={};local leader
    for _,o in ipairs(gym.objects or {}) do
      if o.name=='CINNABARGYM_BLAINE' then leader=copy(o)
      else objects[#objects+1]=copy(o) end
    end
    assert(leader and leader.index==1,'native Blaine identity missing')
    leader.x,leader.y,leader.range=25,12,'DOWN'
    chamber.objects={leader}
    local blocks=copy(gym.blocks);blocks[1*gym.width+1+1]=111
    local warps=copy(gym.warps)
    -- The outdoor clearing becomes lastMap. Gym doors still lead to town.
    for _,w in ipairs(warps) do
      if w.destMap=='LAST_MAP' then w.destMap='CINNABAR_ISLAND' end
    end
    local function stairs(m,points)
      m.kaBlaineStairs={owner='kasc.blaine-volcano-route/v1',points=points}
    end
    local pins={{x=3,y=2,class='stair_down_w'}}
    mod.content.maps:patch(R.GYM,{objects=objects,blocks=blocks,warps=warps,
      kaBlaineStairs={owner='kasc.blaine-volcano-route/v1',points=pins}})
    stairs(tunnel,{{x=45,y=8,class='stair_e'},{x=5,y=4,class='stair_e'}})
    stairs(foot,{{x=15,y=20,class='stair_down_w'}})
    R.maps={tunnel,foot,chamber}
    for _,m in ipairs(R.maps) do
      mod.content.maps:register(m.id,m)
      mod.content.encounters:register(m.id,{grass={rate=0,slots={}}})
      if mod.content.map_songs then
        mod.content.map_songs:register(m.id,m.id==R.FOOT and 'Music_Dungeon1' or 'Music_Gym')
      end
    end
    for id in pairs(R.links) do
      local contribution={priority=3390,onStep=R.onStep}
      if id==R.CHAMBER then
        contribution.talk={[leader.text]=function(game,ow,npc,done)
          -- Forward to the live Gym script, including other installed patches.
          local script=require('src.script.MapScripts').talkScript(R.GYM,leader.text)
          if type(script)=='function' then return script(game,ow,npc,done) end
          if ow:trainerDefeated(npc) or (game.save.inventory or {}).VOLCANOBADGE then
            game.stack:push(require('src.render.TextBox').new(game,
              game.data.text._CinnabarGymBlainePostBattleAdviceText or '...',done))
          else ow:engageTrainer(npc,done) end
        end}
      end
      mod.content.map_scripts:register(id,contribution)
    end
    R.registered=true
    return true
  end
  return R
end
