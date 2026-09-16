-- Battle-local fatal volatiles. No major status or saved species is changed.
-- Destiny Bond observes a genuine scoped lethal BODY strike, never a forecast.
return function(mod,opts)
  local B=require('src.battle.BattleState');local FX=require('src.battle.EffectRegistry')
  local Player=require('src.battle.AnimPlayer');local Order=require('src.battle.TurnOrder')
  local M={CARD_ID='KASC-67-FATAL-CONDITIONS',OWNER='kasc.fatal-conditions/v1'}
  local tr=opts.i18n.text;local A=assert(opts.abilities)
  local defs={CURSE={number=174,pp=10,type='GHOST',target=1,parts={'CONFUSE_RAY','BARRIER'}},
    DESTINY_BOND={number=194,pp=5,type='GHOST',target=7,parts={'CONFUSE_RAY'}},
    PERISH_SONG={number=195,pp=5,type='NORMAL',target=14,parts={'SING'}}}
  local aliases={};local dispatch=setmetatable({},{__mode='k'});local strikes=setmetatable({},{__mode='k'})
  local actions=setmetatable({},{__mode='k'});local transfers=setmetatable({},{__mode='k'})
  local function copy(v)if type(v)~='table'then return v end;local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r end
  local function pack(...)return{n=select('#',...),...}end
  local function int(v,a,z)return type(v)=='number'and v%1==0 and v>=a and v<=z end
  local function id(move)return move and(aliases[move.id]or move.id)end
  local function side(b,w)return b and w and(w==b.player and'player'or w==b.enemy and'enemy')or nil end
  local function party(b,key)return key=='player'and b.game.save.party or key=='enemy'and(b.enemyParty or{b.enemy.mon})or{}end
  local function index(b,w)local key=side(b,w);for i,mon in ipairs(party(b,key))do if i<=6 and mon==w.mon then return i end end end
  local function live(w)local m=w and w.mon;return m and type(m.hp)=='number'and m.hp>0 and not w.fainted
    and not(m.egg or m.isEgg or m.is_egg or m.eggSpecies or m.status=='EGG')end
  local function slotIndex(w,slot)for i,s in ipairs(w and w.curMoves or{})do if i<=4 and s==slot then return i end end end
  local function slotNamed(w,name)for _,s in ipairs(w and w.curMoves or{})do if id(s)==name then return s end end end
  local function state(b,create)
    if create then b.field=b.field or{};b.field.tokens=b.field.tokens or{};b.field.tokens[M.OWNER]=b.field.tokens[M.OWNER]or{}end
    return b and b.field and b.field.tokens and b.field.tokens[M.OWNER]
  end
  function M.epoch(b,u,move)
    local r=b and b.kascGenerationRulesReceipt;local marker=b and b.data and b.data.move_effects and b.data.move_effects.HEAL_EFFECT
    if getmetatable(b)~=B or b.demo or b.kind=='link'or b.result or type(r)~='table'
        or not int(r.activeEpoch,1,7)or r.mode~='gen'..r.activeEpoch or not marker or marker.kascFatalConditions67~=M.OWNER then return end
    if not move then return r.activeEpoch end
    local d=defs[id(move)];local e=b.data.move_effects[move.effect]
    if not d or move.backendMoveOwner~=M.OWNER or move.backendMoveNumber~=d.number or not e or e.kascFatalConditions67~=M.OWNER then return end
    if r.activeEpoch<2 and not(live(u)and side(b,u)and index(b,u)
        and opts.rules.monMoveAvailable(b.game,u.mon,move.id,r.activeEpoch,true))then return end
    return math.max(2,r.activeEpoch)
  end
  local function conditionsValid(r,profile,turn)
    for key,v in pairs({curse=r.curse,perish=r.perish,bond=r.bond})do
      if type(v)~='table'or v.epoch~=math.max(2,profile)or not int(v.applied,0,turn)then return false end
      if key=='perish'and(not int(v.last,v.applied-1,turn)or not int(v.count,1,3)
          or v.count~=3-math.max(0,v.last-v.applied))then return false end
    end;return true
  end
  function M.row(b,w)
    local profile=M.epoch(b);local s=state(b);local r=s and s[side(b,w)]
    return profile and type(r)=='table'and w.mon and r.species==w.mon.species and r.index==index(b,w)
      and r.profile==profile and conditionsValid(r,profile,b.turnCount or 0)and r or nil
  end
  local function put(b,w,key,value)
    local s=state(b,true);local lane=assert(side(b,w));local r=M.row(b,w)
    if not r then r={species=w.mon.species,index=assert(index(b,w)),profile=M.epoch(b)};s[lane]=r end
    r[key]=value;return r
  end
  function M.clear(b,w,key)
    local s=state(b);if not s then return end
    if not w then b.field.tokens[M.OWNER]=nil;return end
    local lane=side(b,w);local r=s[lane];if not lane then return end
    if key and type(r)=='table'then r[key]=nil;if not(r.curse or r.perish or r.bond)then s[lane]=nil end else s[lane]=nil end
    if not next(s)then b.field.tokens[M.OWNER]=nil end
  end
  function M.ghost(w)for _,typ in ipairs(w.curTypes or w.def and w.def.types or{})do if typ=='GHOST'then return true end end;return false end
  local function fail()return{tr('But, it failed!','Doch es schlug fehl!'),failed=true}end
  local function append(a,b)for _,v in ipairs(b or{})do a[#a+1]=v end end
  -- These are non-body costs/residuals: Substitute, Bide and Rage do not
  -- intercept them. Still use actual applyDamage so real HP-loss observers
  -- (e.g. Assurance) see the native loss, rather than a fabricated journal.
  function M.directLoss(b,w,amount)
    if not live(w)or not int(amount,1,1000000)then return 0 end
    local sub,bide,rage=w.substituteHP,w.bideTurns,w.rageMove
    w.substituteHP,w.bideTurns,w.rageMove=nil,nil,nil
    local out=pack(pcall(b.applyDamage,b,w,amount));w.substituteHP,w.bideTurns,w.rageMove=sub,bide,rage
    if not out[1]then error(out[2],0)end
    if w.mon.hp<=0 then b:onFaint(w)end
    return unpack(out,2,out.n)
  end
  local function curseBlocked(b,u,t,move,gen)
    return A.moveScope(b,u,t,true,function()
      local r=M.row(b,t)
      return not live(t)or not index(b,t)or u==t or t.invulnerable or gen<=4 and t.substituteHP~=nil or r and r.curse~=nil
    end,move)
  end
  local function songCanHit(b,u,w,move,gen)
    return live(w)and index(b,w)and A.moveScope(b,u,w,true,function()
      return not w.invulnerable and(gen<3 or A.activeAbility(b,w)~='SOUNDPROOF')
    end,move)
  end
  function M.noUseful(b,u,t,move)
    local gen=M.epoch(b,u,move);if not gen then return false end
    if not live(u)or not index(b,u)then return true end
    local name=id(move)
    if name=='CURSE'then
      if M.ghost(u)then return not not curseBlocked(b,u,t,move,gen)end
      local s=u.stages or{};local contrary=gen>=5 and A.activeAbility(b,u)=='CONTRARY'
      return contrary and(s.attack or 0)<=-6 and(s.defense or 0)<=-6 and(s.speed or 0)>=6
        or not contrary and(s.attack or 0)>=6 and(s.defense or 0)>=6 and(s.speed or 0)<=-6
    elseif name=='PERISH_SONG'then
      for _,w in ipairs({b.player,b.enemy})do local r=M.row(b,w)
        if songCanHit(b,u,w,move,gen)and not(r and r.perish)then return false end
      end;return true
    end
    local r=M.row(b,u);if gen>=7 and r and r.bond then return true end
    if not live(t)or u==t then return true end
    for _,slot in ipairs(t.curMoves or{})do local d=b:moveDef(slot);local e=d and b.data.move_effects[d.effect]
      if d and d.category~='status'and((d.power or 0)>0 or e and e.kind=='full')then return false end
    end;return true
  end
  function M.cast(ctx)
    local b,u,t,move=ctx.battle,ctx.user,ctx.target,ctx.move;local gen=M.epoch(b,u,move)
    if not gen or not live(u)or not index(b,u)then return fail()end
    local name=id(move);local turn=b.turnCount or 0
    if name=='CURSE'then
      if not M.ghost(u)then
        if M.noUseful(b,u,t,move)then return fail()end
        local split=assert(mod.exports.backendSplitSpecial67,'Curse needs the shared stage owner');local out={}
        local boosts=gen<=4 and{{'attack',1},{'defense',1},{'speed',-1}}or{{'speed',-1},{'attack',1},{'defense',1}}
        for _,boost in ipairs(boosts)do append(out,split.changeStage(ctx,u,boost[1],boost[2],false))end
        return #out>0 and out or fail()
      end
      if curseBlocked(b,u,t,move,gen)then return fail()end
      put(b,t,'curse',{applied=turn,epoch=gen})
      M.directLoss(b,u,math.max(1,math.floor(u.mon.stats.hp/2)))
      return{tr('%s cut its own HP and put a curse on %s!','%s opfert KP und verflucht %s!'):format(u.name,t.name)}
    elseif name=='DESTINY_BOND'then
      local action=actions[b];if action and action.user==u then action.reachedBond=true end
      local r=M.row(b,u);local had=r and r.bond;M.clear(b,u,'bond')
      -- VII's exact onPrepareHit removes the volatile even when it fails;
      -- III-VI merely remove and renew it. This is not a lastMove guess.
      if gen>=7 and had then return fail()end
      put(b,u,'bond',{applied=turn,epoch=gen})
      return{tr('%s is trying to take its foe down with it!','%s will den Gegner mit sich nehmen!'):format(u.name)}
    elseif name=='PERISH_SONG'then
      local any=false;local hits={}
      for _,w in ipairs({b.player,b.enemy})do
        if live(w)and index(b,w)then
          local r=M.row(b,w)
          if songCanHit(b,u,w,move,gen)then
            if not(r and r.perish)then put(b,w,'perish',{applied=turn,last=turn-1,count=3,epoch=gen});any=true end
          else hits[#hits+1]=tr('%s is unaffected!','%s ist nicht betroffen!'):format(w.name);any=true end
        end
      end
      if not any then return fail()end
      table.insert(hits,1,tr('All affected Pokémon will faint in three turns!','Alle betroffenen Pokémon fallen in drei Runden!'));return hits
    end
    return fail()
  end
  function M.curseTick(b,w)
    local r=M.row(b,w);local v=r and r.curse
    if not v or not live(w)then return end
    if A.blocksIndirect(b,w,'curse')then return end
    b:sayNext(tr('%s is hurt by the curse!','%s leidet unter dem Fluch!'):format(w.name))
    M.directLoss(b,w,math.max(1,math.floor(w.mon.stats.hp/4)));b:drainNext()
  end
  local function afterAction(b,f)
    if f.bondSelected and not f.reachedBond then M.clear(b,f.user,'bond')end
    local r=M.row(b,f.user)
    -- Gen-II AfterMoveSelf skips a successful self-switch or opposing KO;
    -- an aborted native attempted action still performs this residual.
    if r and r.curse and r.curse.epoch==2 and live(f.user)and side(b,f.user)
        and live(f.target)and not f.selfSwitch then M.curseTick(b,f.user)end
  end
  local function startAction(b,u,t,inst)
    local name=id(inst);if name~='DESTINY_BOND'then M.clear(b,u,'bond')end
    return{user=u,target=t,bondSelected=name=='DESTINY_BOND',selfSwitch=false}
  end
  function M.execute(original,b,u,t,action,...)
    if not M.epoch(b)or not live(u)or not live(t)or not action or actions[b]then return original(b,u,t,action,...)end
    local f=startAction(b,u,t,action);actions[b]=f
    local out=pack(pcall(original,b,u,t,action,...));actions[b]=nil
    if not out[1]then error(out[2],0)end;afterAction(b,f);return unpack(out,2,out.n)
  end
  function M.perform(original,b,u,t,inst,called)
    if not M.epoch(b)or not live(u)or not inst then return original(b,u,t,inst,called)end
    local move=b:moveDef(inst);if not move then return original(b,u,t,inst,called)end
    local prior=dispatch[b];local record=b:effectRecord(move.effect);local source
    if called then if prior and prior.user==u and prior.callsMove then source=prior.source end
    elseif slotIndex(u,inst)or inst.struggle then source={user=u,slot=inst,index=slotIndex(u,inst),id=inst.id}end
    local own=not called and source and not actions[b];local f=own and startAction(b,u,t,inst)
    if own then actions[b]=f end
    dispatch[b]={user=u,move=move,source=source,callsMove=record and type(record.callsMove)=='function'}
    local out=pack(pcall(original,b,u,t,inst,called));dispatch[b]=prior
    if own then actions[b]=nil end
    if not out[1]then error(out[2],0)end;if own then afterAction(b,f)end;return unpack(out,2,out.n)
  end
  function M.capture(original,b,u,t,move,source,continuation,...)
    if not M.epoch(b)or not live(t)or not side(b,u)or not side(b,t)or u==t then return original(...)end
    local old=strikes[b];local f={user=u,target=t,move=move,source=source,continuation=continuation};strikes[b]=f
    local raw,apply=rawget(b,'applyDamage'),b.applyDamage
    b.applyDamage=function(self,w,amount)
      local survival=mod.exports.pokemonLethalHitSurvival67
      local attempt=survival and survival.incomingHit and survival.incomingHit(self,w)or amount
      local direct=w==t and w.mon.hp>0 and type(attempt)=='number'and attempt>0
      local sub=direct and w.substituteHP~=nil;local dealt=apply(self,w,amount)
      if w==t then f.hit={damage=dealt,direct=direct,substitute=sub,lethal=direct and w.mon.hp<=0}end
      return dealt
    end
    local out=pack(pcall(original,...));b.applyDamage=raw;strikes[b]=old
    if not out[1]then error(out[2],0)end
    if f.bondKO and f.user.mon.hp<=0 and not f.user.faintQueued then b:onFaint(f.user)end
    return unpack(out,2,out.n)
  end
  function M.run(original,b,ctx,record)
    if not ctx or not ctx.move then return original(b,ctx,record)end
    local d=dispatch[b];local source=d and d.user==ctx.user and d.source
    return M.capture(original,b,ctx.user,ctx.target,ctx.move,source,false,b,ctx,record)
  end
  function M.continue(original,b,u,t,name,...)
    if not live(u)then return original(b,u,t,...)end
    local slot=name=='BIDE'and slotNamed(u,'BIDE')or type(u.trapMove)=='string'and slotNamed(u,id({id=u.trapMove}))or u.trapMove
    local move=type(slot)=='table'and b:moveDef(slot);local at=slotIndex(u,slot)
    if not move or not at or name=='BIDE'and not u.bideTurns or name~='BIDE'and not u.trappingTurns then return original(b,u,t,...)end
    return M.capture(original,b,u,t,move,{user=u,slot=slot,index=at,id=slot.id},true,b,u,t,...)
  end
  function M.hit(ev)
    local f=ev and strikes[ev.battle];local h=f and f.hit
    local body=mod.exports.pokemonBodyCounter67;local proof=body and body.nativeHit(ev.battle,ev)
    if h and h.direct and not h.substitute and h.lethal and proof and proof.direct and not proof.substitute
        and ev.user==f.user and ev.target==f.target and ev.damage==h.damage and ev.move
        and ev.move.id==f.move.id and ev.move.effect==f.move.effect and ev.move.backendMoveOwner==f.move.backendMoveOwner
        and ev.move.backendMoveNumber==f.move.backendMoveNumber then f.confirmed=true;f.landed=ev.move end
  end
  function M.faint(ev)
    local b,w=ev.battle,ev.battler;if not w or not w.mon or w.mon.hp>0 then return end
    local row=M.row(b,w);local bond=row and row.bond
    M.clear(b,w);if not bond then return end
    local f=strikes[b];local h=f and f.hit;local s=f and f.source;local move=f and(f.landed or f.move)
    if not h or not h.direct or h.substitute or not h.lethal or not(f.confirmed or f.continuation)
        or f.target~=w or not live(f.user)or f.user.faintQueued or not s or s.user~=f.user or not index(b,f.user)
        or(s.index and f.user.curMoves[s.index]~=s.slot)or s.slot.id~=s.id or not(s.index or s.slot.struggle)
        or move.flags and move.flags.futuremove or move.kascFutureStrike67 or move.kascFutureStrikes67 then return end
    -- Native FX subsequently emits the source faint AFTER the victim faint.
    -- Do not recursively insert source presentation/EXP ahead of the victim.
    f.user.mon.hp=0;f.bondKO=true;b:drainNext()
    b:sayNext(tr('%s took its attacker down using Destiny Bond!','%s nimmt den Angreifer durch Abgangsbund mit!'):format(w.name))
  end
  local function ordered(b,field,minimumEpoch)
    local a={};for _,w in ipairs({b.player,b.enemy})do local r=M.row(b,w);local v=r and r[field]
      if v and live(w)and(not minimumEpoch or v.epoch>=minimumEpoch)then a[#a+1]=w end
    end
    if#a<2 then return a end
    local weather=mod.exports.pokemonWeather67
    local function speed(w)return weather and weather.speed(b,w)or Order.effectiveSpeed(w)end
    local p,e=speed(a[1]),speed(a[2]);if e>p or e==p and b.rng(0,1)==1 then a[1],a[2]=a[2],a[1]end;return a
  end
  function M.curses(ev)
    local b=ev and ev.battle;if not M.epoch(b)then return end
    local s=state(b);if not s then return end
    for _,w in ipairs(ordered(b,'curse',3))do M.curseTick(b,w)end
  end
  function M.perish(ev)
    local b=ev and ev.battle;if not M.epoch(b)then return end
    local s=state(b);if not s then return end
    local turn=b.turnCount or 0
    for _,w in ipairs(ordered(b,'perish'))do local r=M.row(b,w);local v=r and r.perish
      if v and live(w)and turn>v.last then
        v.last=turn;v.count=math.max(0,3-(turn-v.applied))
        b:sayNext(tr('%s\'s perish count fell to %d!','Der Abgesang-Zähler von %s fällt auf %d!'):format(w.name,v.count))
        if v.count==0 then M.clear(b,w,'perish');w.mon.hp=0;b:drainNext();b:onFaint(w)end
      end
    end
  end
  function M.transfer(b,old,fresh)
    local lane=side(b,fresh);local s=state(b);local r=s and lane and s[lane]
    if not M.epoch(b)or not lane or not live(fresh)or not old or not old.mon or old.mon==fresh.mon or old.isPlayer~=fresh.isPlayer
        or not r or r.profile~=M.epoch(b)or not conditionsValid(r,r.profile,b.turnCount or 0)
        or r.species~=old.mon.species or party(b,lane)[r.index]~=old.mon then return false end
    local nextRow={species=fresh.mon.species,index=assert(index(b,fresh)),profile=r.profile,curse=copy(r.curse),perish=copy(r.perish)}
    transfers[b]={old=old,fresh=fresh,lane=lane}
    s[lane]=(nextRow.curse or nextRow.perish)and nextRow or nil
    if not next(s)then b.field.tokens[M.OWNER]=nil end
    local f=actions[b];if f and f.user==old then f.selfSwitch=true end
    return nextRow.curse~=nil or nextRow.perish~=nil
  end
  function M.switched(ev)
    local b,w=ev and ev.battle,ev and ev.battler;local lane=side(b,w);if not lane then return end
    local f=transfers[b]
    if f and ev.sourceCard=='KASC-67-BATON-PASS'and ev.previous==f.old and w==f.fresh and lane==f.lane then transfers[b]=nil;return end
    local old=ev.previous;local s=state(b);local r=s and s[lane]
    -- Only the actual incoming side and an outgoing anchored party mon
    -- clear a volatile. Resume notifications or forged same-mon events
    -- cannot erase a valid serializable arm/countdown.
    if not old or not old.mon or old.mon==w.mon or old.isPlayer~=w.isPlayer
        or not r or r.species~=old.mon.species or party(b,lane)[r.index]~=old.mon then return end
    M.clear(b,w);transfers[b]=nil
    local a=actions[b];if a and ev.previous==a.user then a.selfSwitch=true end
  end
  function M.validateCheckpoint(b)
    if actions[b]or dispatch[b]or strikes[b]or transfers[b]then return false,'unsettled_fatal_condition'end
    local s=state(b);if s==nil then return true end;if not M.epoch(b)or type(s)~='table'then return false,'invalid_fatal_container'end
    local turn=b.turnCount or 0;local gen=math.max(2,M.epoch(b))
    for lane,r in pairs(s)do
      local w=(lane=='player'or lane=='enemy')and b[lane]
      if not w or not live(w)or not M.row(b,w)or not(r.curse or r.perish or r.bond)then return false,'invalid_fatal_identity'end
      for k in pairs(r)do if k~='species'and k~='index'and k~='profile'and k~='curse'and k~='perish'and k~='bond'then return false,'unknown_fatal_row_field'end end
      for key,v in pairs({curse=r.curse,perish=r.perish,bond=r.bond})do
        if type(v)~='table'or v.epoch~=gen or not int(v.applied,0,turn)then return false,'invalid_fatal_epoch_or_application'end
        if key=='perish'and(not int(v.last,v.applied-1,turn)or not int(v.count,1,3)
            or v.count~=3-math.max(0,v.last-v.applied))then return false,'invalid_perish_timeline'end
        for k in pairs(v)do if k~='epoch'and k~='applied'and not(key=='perish'and(k=='last'or k=='count'))then return false,'unknown_fatal_condition_field'end end
      end
    end;return true
  end
  function M.finish(ev)local b=ev.battle;M.clear(b);actions[b]=nil;dispatch[b]=nil;strikes[b]=nil;transfers[b]=nil end
  for name,d in pairs(defs)do
    local fact=assert(opts.facts.move(name,7));local old=assert(mod.content.moves:get(name),'fatal move missing '..name)
    assert(fact.number==d.number and fact.generation==2 and fact.power==0 and fact.pp==d.pp and fact.type==d.type
      and fact.category=='status'and fact.target==d.target and fact.accuracy==100 and fact.alwaysHits and fact.priority==0,'fatal source drift '..name)
    assert(not old.backendMoveOwner and old.effect=='KA_GEN_MOVE_UNSUPPORTED_'..name,'foreign fatal owner '..name)
    local effect='KA_FATAL_CONDITIONS_67_'..name
    mod.content.move_effects:register(effect,{kind='primary',run=M.cast,accuracyChecked=false,kascFatalConditions67=M.OWNER})
    for _,alias in ipairs(opts.species.moveIds(name))do if mod.content.moves:get(alias)then aliases[alias]=name
      mod.content.moves:patch(alias,{effect=effect,power=0,pp=d.pp,type=d.type,category='status',target=d.target,
        flags={bypasssub=1,metronome=1,sound=name=='PERISH_SONG'and 1 or nil},kascBypassSub67=true,
        backendMoveOwner=M.OWNER,backendMoveNumber=d.number,originGeneration=2,backendLearnsetRevision=old.backendLearnsetRevision or 1})end end
    aliases[name]=name;local anim={seq={},source=M.OWNER}
    for _,part in ipairs(d.parts)do for _,step in ipairs(assert(mod.content.battle_anims:get(part)).seq)do anim.seq[#anim.seq+1]=copy(step)end end
    mod.content.battle_anims:patch(name,anim)
    for i=#opts.catalog.unsupportedStatus,1,-1 do if opts.catalog.unsupportedStatus[i]==name then table.remove(opts.catalog.unsupportedStatus,i)end end
  end
  mod.content.move_effects:patch('HEAL_EFFECT',{kascFatalConditions67=M.OWNER})
  function M.position(player,name)
    local a=player.data and player.data.moveAnims and player.data.moveAnims[name];if not defs[name]or not a or a.source~=M.OWNER then return end
    local hud=assert(mod.exports.pokemonPartnerHits67,'fatal conditions need actual HUD owner')
    for _,step in ipairs(player.steps or{})do local sprites={}
      for i,s in ipairs(step.sprites or{})do local q=copy(s)
        if q.x>0 and q.x<168 and q.y>0 and q.y<160 and(q.y<16 or hud.inHud(q))then q.x=0 end;sprites[i]=q
      end;step.sprites=sprites
    end
  end
  function M.install()
    B._kascFatalConditions67=M;FX._kascFatalConditions67=M;Player._kascFatalConditions67=M
    if not B._kascFatalConditionsWrapped67 then
      local perform,execute,bide,trap=B.performMove,B.executeAction,B.continueBide,B.continueTrapping
      B.performMove=function(...)return B._kascFatalConditions67.perform(perform,...)end
      B.executeAction=function(...)return B._kascFatalConditions67.execute(execute,...)end
      B.continueBide=function(b,u,t,...)return B._kascFatalConditions67.continue(bide,b,u,t,'BIDE',...)end
      B.continueTrapping=function(b,u,t,...)return B._kascFatalConditions67.continue(trap,b,u,t,'TRAP',...)end
      B._kascFatalConditionsWrapped67=true
    end
    if FX.runDamaging~=FX._kascFatalConditionsRun67 then local original=FX.runDamaging
      local wrapper=function(...)return FX._kascFatalConditions67.run(original,...)end;FX.runDamaging=wrapper;FX._kascFatalConditionsRun67=wrapper end
    if not Player._kascFatalConditionsWrapped67 then local start=Player.start
      Player.start=function(self,name,...)local out=pack(start(self,name,...));Player._kascFatalConditions67.position(self,name);return unpack(out,1,out.n)end
      Player._kascFatalConditionsWrapped67=true end
  end
  mod.events:on('battle.damage_dealt',M.hit,31001)
  mod.events:on('battle.fainted',M.faint,100000)
  mod.events:on('battle.battler_switched',M.switched,8000)
  mod.events:on('battle.turn_ended',M.curses,95)
  mod.events:on('battle.turn_ended',M.perish,-5000)
  mod.events:on('battle.ended',M.finish,10100)
  M.install()
  if opts.supportLog and opts.supportLog.registerSegment then opts.supportLog.registerSegment({segmentId=M.CARD_ID,cardId=M.CARD_ID,
    schema='kasc.optional-feature-card/v1',version='1.0.0',owner=M.OWNER,active=true,
    dependencyStatus='native-attempt-body-KO-and-actual-Baton-prepare',providerStatus='curse-destinybond-perish-volatiles',
    buildReceiptId='docs/FATAL_CONDITIONS_67.md',rollbackReceiptId='docs/FATAL_CONDITIONS_67.md'})end
  return M
end
