-- Private Bald Crew character. No vanilla trainer/hero identity is replaced.
-- Green contract: six native walker frames, 4x3 HD cards, five throw poses
-- at six native ticks each. Blink timing follows Green's presentation clock.
return function(mod,opts)
  opts=opts or{}
  local M={spriteId=opts.spriteId or 'SPRITE_KA_BALD_CREW_FEMALE',
    classId=opts.classId or 'KA_BALD_CREW_FEMALE'}
  local classes=opts.classes or {[M.classId]='FabelleMoon'}
  local rel=opts.rel or 'assets/characters/bald_crew_female_v1/'
  local role=opts.role or 'bald-crew-female'
  local controller=opts.controller or '_kaBaldCrewController'
  local wrapped=controller..'Wrapped'
  local root=assert(mod.path)..'/'..rel
  local images={}
  local function image(path)
    if not images[path]then images[path]=require('src.render.Assets').image(path)end
    return images[path]
  end
  local function clock()return opts.clock and opts.clock()or love.timer.getTime()end
  local function own(def)return def and def.id==M.spriteId end
  function M.ownsClass(classId)return classes[classId]~=nil end
  local function ownBattle(b)
    return b and M.ownsClass(b.oppClass) and b.trainer
      and b.trainer.id==b.oppClass and b.trainer.pic==root..'battle_56_1.png'
  end
  function M.matchesBattle(b)return ownBattle(b)==true end
  function M.blink(state,now,eligible,seed)
    if not eligible or type(now)~='number' or now~=now or math.abs(now)==math.huge then
      state.nextBlink,state.observed=nil,nil;return false
    end
    if state.observed and (now<state.observed or now-state.observed>.25)then state.nextBlink=nil end
    state.observed=now
    if not state.nextBlink then
      local first=state.serial==nil;state.serial=state.serial or 0
      local phase=((tonumber(seed)or 0)*.754877666+state.serial*.618033989)%1
      state.nextBlink=now+(first and 1 or 2.4)+phase*(first and 1.2 or 2.4)
    end
    local age=now-state.nextBlink
    if age>=.26 then
      state.serial=(state.serial or 0)+1
      state.nextBlink=now+2.4+(((tonumber(seed)or 0)*.754877666+state.serial*.618033989)%1)*2.4
    end
    -- Discrete eyelids use Green's .07 close/.04 hold/.15 open envelope.
    return age>=.035 and age<.185
  end
  function M.presentation(def,now,state,moving)
    if not own(def)then return nil end
    if moving then state.lastMoved=now end
    local closed=M.blink(state,now,not state.lastMoved or now-state.lastMoved>=.7,state.seed or 17)
    return root..(closed and 'blink.png'or'walk.png'),
      root..(closed and 'cards_blink_4x3.png'or'cards_4x3.png')
  end
  function M.register()
    if M.registered then return false end
    assert(not mod.content.sprites:get(M.spriteId),'Crew sprite ID occupied')
    for id in pairs(classes)do assert(not mod.content.trainers:get(id),'Crew trainer ID occupied: '..id)end
    mod.content.sprites:register(M.spriteId,{id=M.spriteId,image=root..'walk.png',
      frames=6,walker=true,trueColor=true,frameWidth=16,frameHeight=16,anchorX=8,anchorY=16,
      ascendantAtlasImage=root..'cards_4x3.png',ascendantRole=role,
      ascendantScaleClass='human_child',kaBaldCrewCharacter=true})
    -- Deliberately no placeholder party. The event must supply approved data.
    for id,name in pairs(classes)do
      mod.content.trainers:register(id,{id=id,name=name,
        pic=root..'battle_56_1.png',trueColor=true,baseMoney=0,parties={}})
    end
    M.registered=true;return true
  end
  function M.portraitSpec(battle,classId)
    local pose=ownBattle(battle)and battle._kaCrewPose or 1
    if type(pose)~='number'or pose<1 or pose>6 then pose=1 end
    classId=ownBattle(battle)and battle.oppClass or M.ownsClass(classId)and classId or M.classId
    return{id=classId,class=classId,path=rel..'battle_128_'..pose..'.png',
      fallback=rel..'battle_56_'..pose..'.png',authored=true,
      animation={idle={rel..'battle_128_1.png',rel..'battle_128_2.png'},
        throw={rel..'battle_128_1.png',rel..'battle_128_3.png',rel..'battle_128_4.png',
          rel..'battle_128_5.png',rel..'battle_128_6.png'},throwTicks=6,releaseFrame=4}}
  end
  function M.install()
    M.bindBattleHeroes()
    local SR=require('src.render.SpriteRenderer')
    local BS=require('src.battle.BattleState')
    SR[controller]=M;BS[controller]=M
    if not SR[wrapped] and type(SR.resolveImage)=='function'and type(SR.draw)=='function'then
      SR[wrapped]=true
      local resolve,draw,new=SR.resolveImage,SR.draw,SR.new
      if type(new)=='function'then
        SR.new=function(def,...)
          if own(def)then
            local instance={};for k,v in pairs(def)do instance[k]=v end
            def=instance -- Atlas selection belongs to one actor, never registry state.
          end
          return new(def,...)
        end
      end
      local states=setmetatable({},{__mode='k'})
      local function sync(s,moving)
        if not own(s.def)then return end
        if not states[s]then
          local seed=0;for c in tostring(s.seed or ''):gmatch('.')do seed=(seed*131+c:byte())%104729 end
          states[s]={seed=seed/104729}
        end
        local active=SR[controller]
        local path,atlas=active.presentation(s.def,clock(),states[s],moving)
        if path then
          if opts.heterochromia~=false and path:match('/walk.png$')then
            if s._kaCrewFacing=='right'then path=root..'walk_right.png'
            elseif s._kaCrewFacing=='down'and s._kaCrewStepFlip then path=root..'walk_stepflip.png'end
          end
          s.image=image(path);s.def.ascendantAtlasImage=atlas
        end
      end
      SR.resolveImage=function(s,...)sync(s,false);return resolve(s,...)end
      SR.draw=function(s,x,y,camX,camY,facing,walkPhase,stepFlip,...)
        if own(s.def)then s._kaCrewFacing=facing;s._kaCrewStepFlip=walkPhase==1 and stepFlip end
        sync(s,walkPhase==1)
        return draw(s,x,y,camX,camY,facing,walkPhase,stepFlip,...)
      end
    end
    if not BS[wrapped] and type(BS.slidePic)=='function'and type(BS.update)=='function'then
      BS[wrapped]=true
      local slide,update=BS.slidePic,BS.update
      BS.slidePic=function(b,slot,from,to,step)
        if ownBattle(b)and slot=='foe'and from==0 and to==64
            and b.showEnemyTrainer and not b._kaCrewThrew and type(b.queue)=='table'then
          b._kaCrewThrew=true;b._kaCrewThrowing=true
          local sequence={};local frames={1,3,4,5,6}
          -- Resolve before changing the queue, so an asset failure cannot
          -- leave half a presentation sequence between native battle actions.
          local pics={};for i,f in ipairs(frames)do pics[i]=image(root..'battle_56_'..f..'.png')end
          for i,pic in ipairs(pics)do
            local frame,pose=pic,frames[i]
            sequence[#sequence+1]={fn=function()b.trainerPic=frame;b._kaCrewPose=pose end}
            sequence[#sequence+1]={wait=6}
          end
          sequence[#sequence+1]={fn=function()
            b._kaCrewThrowing=false;b._kaCrewThrowFinished=true;slide(b,slot,from,to,step)
          end}
          for i=#sequence,1,-1 do table.insert(b.queue,1,sequence[i])end
          return
        end
        return slide(b,slot,from,to,step)
      end
      BS.update=function(b,dt,...)
        if ownBattle(b)then M.bindBattleHeroes()end
        if ownBattle(b)and b.showEnemyTrainer and not b._kaCrewThrowing and not b._kaCrewThrowFinished then
          b._kaCrewBlink=b._kaCrewBlink or{}
          local closed=M.blink(b._kaCrewBlink,clock(),true,19)
          b._kaCrewPose=closed and 2 or 1
          b.trainerPic=image(root..(closed and'battle_56_2.png'or'battle_56_1.png'))
        end
        return update(b,dt,...)
      end
    end
    return true
  end
  function M.bindBattleHeroes()
    if type(mod.find)~='function'then return false end
    local renderer=mod:find('VOXEL_ASCENDANT')
    local standalone=mod:find('ascendant_battle_heroes')
    local api=standalone and standalone.exports or renderer and renderer.exports and renderer.exports.battleHeroes
    local registry=api and api.charsprite
    if not registry or registry.schema~='ascendant.charsprite/v1' then return false end
    if M.heroRegistry==registry then return true end
    local id='kasc/'..role
    assert(not registry.characters[id],'Crew battle hero ID occupied')
    registry.register(id,{path=root..'battle_heroes_3x10.png',columns=3,rows=10,
      frontRow=0,backRow=2,leftRow=1,rightRow=3,height=18,width=12,
      clips={idle_enemy={{0,1,200},{0,7,9}},idle_player={{0,3,200},{0,9,9}},
        throw={{0,4,6},{1,4,6},{2,4,6},{0,5,6},{1,5,6}}}})
    for classId in pairs(classes)do registry.bindTrainer(classId,id)end
    M.heroRegistry=registry;return true
  end
  return M
end
