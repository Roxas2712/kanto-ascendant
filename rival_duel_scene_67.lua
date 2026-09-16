-- A Rival's Life owns this local world presentation, including its two
-- temporary frontsprite NPCs. VASC consumes normal sprite instances; neither
-- a second BattleState nor another mod's renderer is installed or patched.
return function(mod,opts)
  local load=assert(opts.load)
  local snapshots=load('rival_duel_snapshot_67.lua')(mod,{rules=opts.rules})
  local controller=load('rival_spectator_duel_presentation.lua')
  local commands={}
  for _,actor in ipairs({'RED','BLUE','GREEN'})do
    commands[actor]=load('rival_spectator_commands_'..actor:lower()..'.lua')
  end
  local D={}
  local function raw(entry)return entry.npc.npc or entry.npc end
  local function locale()
    return opts.i18n and opts.i18n.text and opts.i18n.text('en','de')or'en'
  end
  -- First reserve the entire five-cell exchange and one clear passing lane.
  -- Nothing is spawned while checking: NPC safety excludes nearby objects.
  function D.reserve(find,safe)
    local rejected={}
    for _=1,128 do
      local first=find(rejected)
      if not first then break end
      for _,sign in ipairs({1,-1})do
        local valid=true
        for dx=0,4 do
          if not safe(first.x+sign*dx,first.y)then valid=false;break end
        end
        local passage=false
        if valid then
          for _,dy in ipairs({-1,1})do
            local clear=true
            for dx=0,4 do
              if not safe(first.x+sign*dx,first.y+dy)then clear=false;break end
            end
            if clear then passage={x=first.x+2*sign,y=first.y+dy};break end
          end
        end
        valid=valid and passage
        if valid then
          return {trainers={first,{x=first.x+4*sign,y=first.y}},
            pokemon={{x=first.x+sign,y=first.y},{x=first.x+3*sign,y=first.y}},
            passage=passage}
        end
      end
      rejected[#rejected+1]=first
    end
  end
  local function frontSprite(game,mon,mirrored)
    local graphics=love.graphics
    local image=require('src.battle.BattleState').makeBattler(game.data,mon,false).sprite
    if not image then error('missing rival frontsprite '..mon.species)end
    local path=require('src.pokemon.Sprites').path(game.data,mon.species,'front',
      {mon=mon,kind='battle'})
    local w,h=image:getDimensions()
    local hi=graphics.newCanvas(w,h)
    local small=graphics.newCanvas(16,16)
    hi:setFilter('nearest','nearest');small:setFilter('nearest','nearest')
    local quad=graphics.newQuad(0,0,16,16,16,16)
    local sprite={def={image=path,frames=1,trueColor=true,frameWidth=w,frameHeight=h}}
    function sprite:paint(effect,amount)
      graphics.push('all')
      graphics.setShader();graphics.setBlendMode('alpha','alphamultiply')
      graphics.setCanvas(hi);graphics.clear(0,0,0,0);graphics.setColor(1,1,1,1)
      graphics.draw(image,mirrored and w or 0,0,0,mirrored and -1 or 1,1)
      if effect and amount>0 then
        local color=effect=='HEAL'and{0.25,1,0.5}or effect=='PROTECT'and{0.3,0.7,1}
          or{1,0.75,0.2}
        graphics.setColor(color[1],color[2],color[3],amount*0.8)
        graphics.setLineWidth(2)
        graphics.ellipse('line',w/2,h/2,math.max(1,w/2-2),math.max(1,h/2-2))
      end
      graphics.setCanvas(small);graphics.clear(0,0,0,0);graphics.setColor(1,1,1,1)
      graphics.setBlendMode('alpha','premultiplied')
      local scale=16/math.max(w,h)
      graphics.draw(hi,(16-w*scale)/2,16-h*scale,0,scale,scale)
      graphics.pop()
    end
    function sprite:resolveImage()return hi end
    function sprite:draw(px,py,camX,camY)
      local palette=require('src.render.PaletteFX')
      local x,y=math.floor(px-(camX or 0)),math.floor(py-(camY or 0))-4
      graphics.setColor(1,1,1,1);graphics.draw(small,x,y)
      if palette.spriteRedrawPassActive()then
        palette.markSpriteRedraw(small,quad,x,y,1)
      else palette.markTrueColor(x,y,16,16)end
    end
    function sprite:release()hi:release();small:release();quad:release()end
    sprite:paint(nil,0)
    return sprite
  end
  function D.start(active,layout,persist)
    local visit=active.visit
    local data=visit.duelPresentation
    if not data then
      local reason
      data,reason=snapshots.build(active.game,visit)
      if not data then return false,reason end
    end
    local scene={entries={},elapsed=0,active=active,persist=persist,data=data,layout=layout}
    local function cleanup()
      for _,entry in ipairs(scene.entries)do
        if entry.npcId then mod.world:removeNpc(entry.npcId)end
        if entry.sprite then entry.sprite:release()end
      end
      scene.entries={}
    end
    local ok,why=pcall(function()
      for index,actor in ipairs(data.pair)do
        local cell=layout.pokemon[index]
        local facing=layout.pokemon[1].x<layout.pokemon[2].x
        local sprite=frontSprite(active.game,data.mons[actor],index==1 and facing or index==2 and not facing)
        local entry={actor=actor,cell=cell,sprite=sprite}
        scene.entries[#scene.entries+1]=entry
        entry.npcId=assert(mod.world:spawnNpc(active.mapId,{
          name='KA_LIFE_DUEL_'..actor,sprite='SPRITE_POKE_BALL',
          movement='STAY',range='DOWN',text=opts.text or 'TEXT_KA_LIFE_ACTOR',
          x=cell.x,y=cell.y}))
        entry.npc=assert(mod.world:npc(active.mapId,entry.npcId))
        local npc=raw(entry);npc.sprite=sprite;npc.frozen=true
        entry.px,entry.py=npc.px,npc.py
      end
      scene.control=controller(mod,{actorPair=data.pair,enabled=function()return true end,
        snapshots={capture=function(actor)return data.snapshots[actor]end},commands=commands,
        agenda={context=function()return{actorSet=table.concat(data.pair,'_'),agendaId=data.sceneId}end,
          resolveSpectator=function()return true end},
        localization={name=function(kind,id)
          local records=kind=='pokemon'and active.game.data.pokemon or active.game.data.moves
          return records[id]and records[id].name or id:gsub('_',' ')
        end},
        localFallback={present=function(action)scene.action=action;scene.elapsed=0;return true end}})
      assert(scene.control.start(data.sceneId,data.opportunity),'invalid rival snapshot')
      if visit.duelProgress then
        assert(scene.control.restoreProgress(visit.duelProgress),'invalid rival progress')
      end
    end)
    if not ok then cleanup();return false,tostring(why)end
    visit.duelPresentation=data
    active.duelScene=scene
    persist()
    return true
  end
  local function resetSprites(scene)
    for _,entry in ipairs(scene.entries)do
      raw(entry).px,raw(entry).py=entry.px,entry.py
      entry.sprite:paint(nil,0)
    end
  end
  local function finishAction(scene)
    resetSprites(scene)
    scene.action=nil;scene.control.finishAction()
    scene.active.visit.duelProgress=scene.control.progress();scene.persist()
  end
  function D.tick(active,dt)
    local scene=active.duelScene
    if not scene or active.talking or active.game.overworld~=active.ow then return end
    local stack=active.game.stack
    if not stack or stack:top()~=active.ow then return end
    local seconds=tonumber(dt)or 0
    if seconds~=seconds or seconds<=0 then return end
    seconds=math.min(seconds,0.1)
    if scene.action then
      scene.elapsed=scene.elapsed+seconds
      local progress=math.min(1,scene.elapsed/0.85)
      local pulse=math.sin(progress*math.pi)
      for _,entry in ipairs(scene.entries)do
        if entry.actor==scene.action.actor then
          local other=entry==scene.entries[1]and scene.entries[2]or scene.entries[1]
          local direction=other.px>entry.px and 1 or -1
          local semantic=scene.action.semanticClass
          raw(entry).px=entry.px+(semantic=='MELEE'and direction*12*pulse or 0)
          raw(entry).py=entry.py-(semantic=='MULTIPHASE'and 8*pulse or 0)
          entry.sprite:paint(semantic,pulse)
        elseif scene.action.impactTarget==entry.actor then
          entry.sprite:paint('IMPACT',pulse)
        end
      end
      if progress>=1 then finishAction(scene)end
    else scene.control.tick(seconds)end
  end
  function D.entryFor(active,npc)
    local scene=active.duelScene
    if not scene or not npc then return end
    for index,entry in ipairs(scene.entries)do
      if npc==entry.npc or npc==raw(entry)or npc.id==entry.npcId then return active.entries[index]end
    end
  end
  function D.talk(active,actor)
    local scene=active.duelScene
    if not scene then return end
    if scene.action then finishAction(scene)end
    if scene.control.active.resolved then
      local de=locale()=='de'
      local lines={
        RED=de and'Das war knapp. Beim nächsten Mal bin ich schneller.'or'That was close. Next time I will be quicker.',
        BLUE=de and'Gar nicht schlecht. Aber ich habe noch ein paar Tricks auf Lager.'or'Not bad. But I still have a few tricks left.',
        GREEN=de and'Guter Kampf. Jetzt weiß ich, woran wir noch arbeiten müssen.'or'Good battle. Now I know what we need to work on.'}
      return lines[actor]
    end
    local line=scene.control.talk(actor,'BEFORE_ACTION',locale())
    return line and line.text
  end
  function D.releaseTalk(active,actor)
    local scene=active.duelScene
    if not scene then return end
    scene.control.finishTalk(actor)
    for index,entry in ipairs(active.entries)do
      local direction=scene.entries[1].px<scene.entries[2].px
      local facing=(index==1 and direction or index==2 and not direction)and'right'or'left'
      if entry.npc.face then entry.npc:face(facing)end
    end
  end
  function D.cleanup(active)
    local scene=active.duelScene
    if not scene then return end
    -- A same-map save/load resumes the next action, not a newly rolled team.
    active.visit.duelProgress=scene.control.progress();scene.persist()
    scene.control.onMapLeaving()
    for _,entry in ipairs(scene.entries)do
      mod.world:removeNpc(entry.npcId);entry.sprite:release()
    end
    active.duelScene=nil
  end
  return D
end
