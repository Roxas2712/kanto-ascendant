-- Side shields and the battler's shared stall counter are separate owners:
-- the former survives a same-turn switch; the latter does not.
return function(mod,opts)
  local B=require('src.battle.BattleState');local FX=require('src.battle.EffectRegistry')
  local M={CARD_ID='KASC-67-SIDE-GUARDS',OWNER='kasc.side-guards/v1'}
  local rules,facts,species=assert(opts.rules),assert(opts.facts),assert(opts.species)
  local tr=opts.i18n.text;local frames=setmetatable({},{__mode='k'})
  local defs={WIDE_GUARD={number=469,gen=5,pp=10,priority=3,type='ROCK'},
    QUICK_GUARD={number=501,gen=5,pp=15,priority=3,type='FIGHTING'},
    MAT_BLOCK={number=561,gen=6,pp=10,priority=0,type='FIGHTING'},
    CRAFTY_SHIELD={number=578,gen=6,pp=10,priority=3,type='FAIRY'}}
  local order={'WIDE_GUARD','QUICK_GUARD','MAT_BLOCK','CRAFTY_SHIELD'}
  local personal={PROTECT=true,DETECT=true,ENDURE=true,KINGS_SHIELD=true,SPIKY_SHIELD=true,BANEFUL_BUNKER=true}
  local breakers={FEINT=4,SHADOW_FORCE=4,PHANTOM_FORCE=6,HYPERSPACE_HOLE=6,HYPERSPACE_FURY=6}
  local aliases={}
  for id in pairs(facts.data.moves)do for _,key in ipairs(species.moveIds(id))do aliases[key]=id end end
  local function copy(v)if type(v)~='table'then return v end;local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r end
  local function pack(...)return{n=select('#',...),...}end
  local function int(v,a,z)return type(v)=='number'and v%1==0 and v>=a and v<=z end
  local function lane(b,w)return b and w and(w==b.player and'player'or w==b.enemy and'enemy')end
  local function actual(b,w)
    if not b or not w or not w.mon then return end
    if b.player and b.player.mon==w.mon then return b.player end
    if b.enemy and b.enemy.mon==w.mon then return b.enemy end
  end
  local function party(b,key)return key=='player'and b:playerPartyView()or key=='enemy'and(b.enemyParty or{b.enemy.mon})end
  local function slot(b,w)local key=lane(b,w);for i,p in ipairs(party(b,key)or{})do if i<=6 and p==w.mon then return i end end end
  local function live(w)local p=w and w.mon;return p and int(p.hp,1,999999)and not w.fainted
    and not(p.egg or p.isEgg or p.is_egg or p.eggSpecies or p.species=='EGG')end
  local function rows(b,create)
    if create then b.field=b.field or{};b.field.tokens=b.field.tokens or{}
      b.field.tokens[M.OWNER]=b.field.tokens[M.OWNER]or{guards={},stall={}}end
    return b and b.field and b.field.tokens and b.field.tokens[M.OWNER]
  end
  function M.epoch(b)
    local r=b and b.kascGenerationRulesReceipt;local h=b and b.data and b.data.move_effects and b.data.move_effects.HEAL_EFFECT
    if getmetatable(b)==B and not b.demo and not b.result and b.kind~='link'and type(r)=='table'
      and int(r.activeEpoch,1,7)and(r.mode=='auto'or r.mode=='gen'..r.activeEpoch)
      and h and h.kascSideGuards67==M.OWNER then return r.activeEpoch end
  end
  function M.moveEpoch(b,u,m)
    local gen=M.epoch(b);local id=m and aliases[m.id];local d=id and defs[id]
    local e=d and b.data.move_effects[m.effect]
    if not gen or not d or not lane(b,u)or not live(u)or not slot(b,u)
      or m.backendMoveOwner~=M.OWNER or m.backendMoveNumber~=d.number or m.category~='status'
      or m.target~=4 or m.power~=0 or not e or e.kascSideGuards67~=M.OWNER then return end
    if gen<d.gen and not(rules.ownedGiftBattleCompatible(b.game,u.mon,b.data.pokemon[u.mon.species])
      and rules.monMoveAvailable(b.game,u.mon,m.id,gen,true))then return end
    return math.max(gen,d.gen),id
  end
  local function proof(b,w,era)
    return{sourceSlot=slot(b,w),sourceSpecies=w.mon.species,profile=M.epoch(b),era=era,turn=b.turnCount or 0}
  end
  local function sourceValid(b,key,v,active)
    if type(v)~='table'then return false end
    local gen=M.epoch(b);local p=party(b,key);local mon=p and p[v.sourceSlot]
    if not gen or not int(v.sourceSlot,1,6)or type(v.sourceSpecies)~='string' or not mon
      or mon.species~=v.sourceSpecies or v.profile~=gen or not int(v.era,5,7)
      or not int(v.turn,0,b.turnCount or 0)then return false end
    if active then local w=b[key];return w and w.mon==mon and live(w)end
    return true
  end
  function M.active(b,w,id)
    w=actual(b,w)
    local key=lane(b,w);local r=rows(b);local v=type(r)=='table'and type(r.guards)=='table'
      and type(r.guards[key])=='table'and r.guards[key][id]
    return live(w)and defs[id]and type(v)=='table'and sourceValid(b,key,v,false)
      and v.turn==(b.turnCount or 0)and v.era==math.max(v.profile,defs[id].gen)and v or nil
  end
  function M.clearSide(b,w)
    local key=lane(b,w);local r=rows(b);if key and r and r.guards then r.guards[key]=nil end
  end
  function M.clearStall(b,w)
    local key=lane(b,w);local r=rows(b);if key and r and r.stall then r.stall[key]=nil end
  end
  local function stall(b,w)
    local key=lane(b,w);local r=rows(b);local v=type(r)=='table'and type(r.stall)=='table'and r.stall[key]
    return type(v)=='table'and sourceValid(b,key,v,true)and v.turn>=(b.turnCount or 0)-1
      and int(v.count,1,8)and(personal[v.move]and v.era==v.profile
        or (v.move=='WIDE_GUARD'or v.move=='QUICK_GUARD')and v.era==math.max(v.profile,5))and v or nil
  end
  -- nil means no new owner history: the original personal-shield owner
  -- must retain its historical II-IV calculation and untouched fallback.
  function M.stallChance(b,w,era)
    local v=stall(b,w);if not v or not int(era,5,7)then return end
    return 1,era==5 and(v.count>=8 and 4294967296 or 2^v.count)or 3^math.min(6,v.count)
  end
  local function currentCount(b,w)
    local v=stall(b,w);if v then return v.count end
    local r=b.field and b.field.tokens and b.field.tokens['kasc.protection/v1']
    local old=r and r[lane(b,w)]
    return old and old.lastTurn==(b.turnCount or 0)-1 and int(old.count,1,8)and old.count or 0
  end
  local function addStall(b,w,era,id,previousCount)
    local count=previousCount or currentCount(b,w);local v=proof(b,w,era);v.count=math.min(8,count+1);v.move=id
    rows(b,true).stall[lane(b,w)]=v
  end
  local function same(a,z)return a and z and a.id==z.id and a.effect==z.effect end
  function M.used(ev)local f=ev and frames[ev.battle]
    if f and f.user==ev.user and f.target==ev.target and same(f.move,ev.move)
      and ev.isCalled==f.called then f.declared=true end
  end
  function M.context(nextCtx,b,u,t,...)
    local ctx=nextCtx(b,u,t,...);local f=frames[b]
    if f and f.declared and f.user==u and f.target==t and same(f.move,ctx.move)then f.ctx=ctx end
    return ctx
  end
  local function declared(ctx)local f=ctx and frames[ctx.battle]
    return f and f.declared and f.ctx==ctx and f.user==ctx.user and f.target==ctx.target end
  -- Root invokes these from the actual successful/failed Protection.cast.
  -- An event, copied old row or standalone synthetic context cannot extend
  -- a battler's stall counter or license an otherwise unavailable move.
  function M.noteProtection(ctx,gen)
    if declared(ctx)and personal[aliases[ctx.move.id]or ctx.move.id]and int(gen,5,7)
      and M.epoch(ctx.battle)==gen and live(ctx.user)and slot(ctx.battle,ctx.user)then
      addStall(ctx.battle,ctx.user,gen,aliases[ctx.move.id]or ctx.move.id,frames[ctx.battle].stallBefore);return true end
    return false
  end
  function M.noteFailure(ctx,gen)
    if declared(ctx)and int(gen,6,7)then M.clearStall(ctx.battle,ctx.user)end
  end
  local function failure()return{tr('But, it failed!','Doch es schlug fehl!'),failed=true}end
  function M.plan(b,u,t,m)
    local gen,id=M.moveEpoch(b,u,m);if not gen or not lane(b,t)or not live(t)or not slot(b,t)or u==t then return end
    if b._kascFlinchActed67 and b._kascFlinchActed67[t]or M.active(b,u,id)then return end
    if id=='MAT_BLOCK'then local first=mod.exports.pokemonFirstAction67
      if not first or not first.allowed(b,u)then return end end
    local n,d=1,1
    if gen==5 then
      n,d=M.stallChance(b,u,gen)
      if not n then local count=currentCount(b,u);n,d=1,count>=8 and 4294967296 or 2^count end
    end
    return{id=id,epoch=gen,numerator=n,denominator=d}
  end
  function M.noUseful(b,u,t,m)
    if not M.moveEpoch(b,u,m)then return false end
    local p=M.plan(b,u,t,m);return not p or p.denominator>1
  end
  function M.cast(ctx)
    local b,u,t,m=ctx.battle,ctx.user,ctx.target,ctx.move;local p=M.plan(b,u,t,m)
    if not declared(ctx)or not p then return failure()end
    if p.denominator>1 and b.rng(1,p.denominator)>p.numerator then return failure()end
    local r=rows(b,true);local key=lane(b,u);r.guards[key]=r.guards[key]or{}
    r.guards[key][p.id]=proof(b,u,p.epoch)
    if p.id=='WIDE_GUARD'or p.id=='QUICK_GUARD'then addStall(b,u,p.epoch,p.id)end
    return{tr('The side is protected!','Die Seite ist geschützt!')}
  end
  local function moveFlag(m,flag)
    local current=m.flags
    if current==nil then local f=facts.data.moves[aliases[m.id]or m.id];current=f and f.flags end
    if type(current)~='table'then return false end
    if current[flag]~=nil then return current[flag]==true or current[flag]==1 end
    for _,f in ipairs(current)do if f==flag then return true end end
    return false
  end
  local function targetKind(m)local f=facts.data.moves[aliases[m.id]or m.id];return m.target or f and f.target end
  local function targeted(kind)return kind==2 or kind==8 or kind==9 or kind==10 or kind==11 end
  function M.blocks(ctx)
    local b,u,t,m=ctx and ctx.battle,ctx and ctx.user,ctx and ctx.target,ctx and ctx.move
    u,t=actual(b,u),actual(b,t)
    if not M.epoch(b)or not m or not live(u)or not live(t)or u==t or not lane(b,u)or not lane(b,t)
      or not slot(b,u)or not slot(b,t)then return false end
    local kind=targetKind(m);if not targeted(kind)then return false end
    local protected=moveFlag(m,'protect');local status=m.category=='status'
    local v=M.active(b,t,'WIDE_GUARD')
    if v and protected and(kind==9 or kind==11)and(not status or v.era>=7)then return'WIDE_GUARD'end
    v=M.active(b,t,'QUICK_GUARD')
    if v and protected then
      local prio
      if v.era==5 then local f=facts.move(aliases[m.id]or m.id,5);prio=f and f.priority or 0
      else local owner=mod.exports.pokemonPriorityAbilities67
        -- The real priority owner also knows reflected Prankster; item
        -- ordering bonuses are deliberately not promoted to move priority.
        if owner and owner.effectivePriority then prio=owner.effectivePriority(b,u,m)end
      end
      if prio and prio>0.1 then return'QUICK_GUARD'end
    end
    if M.active(b,t,'MAT_BLOCK')and protected and not status then return'MAT_BLOCK'end
    -- Unlike the other shields, Crafty Shield does not require the move's
    -- protect flag. It still cannot intercept Haze/all-field or side moves.
    if M.active(b,t,'CRAFTY_SHIELD')and status then return'CRAFTY_SHIELD'end
    return false
  end
  function M.notice(ctx)
    if not M.blocks(ctx)then return end
    ctx.battle:cancelMoveAnim();return tr('The side shield\nblocked the move!','Der Seitenschutz\nwehrt die Attacke ab!')
  end
  function M.breakingHit(original,b,ctx,record)
    local id=aliases[ctx.move.id]or ctx.move.id;local gen=M.epoch(b);local birth=breakers[id]
    local f=frames[b]
    if not birth or not gen or not f or not f.declared or f.ctx~=ctx
      or gen<birth and not rules.monMoveAvailable(b.game,ctx.user.mon,ctx.move.id,gen,true)then return original(b,ctx,record)end
    local proxy=copy(record or{});local choose=record and record.chooseDamage
    proxy.chooseDamage=function(c)
      local damage,info
      if choose then damage,info=choose(c)else damage,info=c.computeDamage({rng=b.rng,explode=record and record.explode or nil})end
      local typeMult=type(info)=='table'and info.typeMult or 10
      if damage~=nil and typeMult~=0 and not(type(info)=='table'and info.missed)then
        -- Executed after native phase/gate/accuracy/type-ability immunity,
        -- before the native hit loop and Substitute. No extra attack/PP.
        M.clearSide(b,ctx.target)
        if math.max(gen,birth)>=6 then M.clearStall(b,ctx.target)end
      end
      return damage,info
    end
    return original(b,ctx,proxy)
  end
  function M.damage(original,b,ctx,record)
    local contact=mod.exports.pokemonContactAbilities67
    if record and record.explode and contact and contact.damp(b)then return original(b,ctx,record)end
    if M.blocks(ctx)then b:sayNext(M.notice(ctx));if record and record.onMiss then record.onMiss(ctx,'protected')end;return end
    return M.breakingHit(original,b,ctx,record)
  end
  function M.perform(original,b,u,t,inst,called,...)
    local m=inst and b:moveDef(inst)
    if not M.epoch(b)or not m or not lane(b,u)or not lane(b,t)or not live(u)or not live(t)
      or not slot(b,u)or not slot(b,t)then return original(b,u,t,inst,called,...)end
    local previous=frames[b];local f={user=u,target=t,move=m,inst=inst,called=called or false,
      stallBefore=currentCount(b,u)};frames[b]=f
    local raw,old=rawget(b,'effectRecord'),b.effectRecord
    b.effectRecord=function(self,id)
      local rec=old(self,id);if id~=m.effect or not rec then return rec end
      local proxy={};for k,v in pairs(rec)do if k~='perform'then proxy[k]=v end end
      return setmetatable(proxy,{__index=function(_,key)
        if key=='perform'and f.declared and f.ctx and M.blocks(f.ctx)then
          return function(ctx)b:sayNext(M.notice(ctx));if rec.onMiss then rec.onMiss(ctx,'protected')end end
        end
        return rec[key]
      end})
    end
    local out=pack(pcall(original,b,u,t,inst,called,...));b.effectRecord=raw;frames[b]=previous
    if not out[1]then error(out[2],0)end;return unpack(out,2,out.n)
  end
  local allowedProof={sourceSlot=true,sourceSpecies=true,profile=true,era=true,turn=true}
  function M.validateCheckpoint(b)
    if frames[b]then return false,'side_guard_in_flight'end
    local r=rows(b);if r==nil then return true end
    if type(r)~='table'or type(r.guards)~='table'or type(r.stall)~='table'then return false,'invalid_side_guard_container'end
    for k in pairs(r)do if k~='guards'and k~='stall'then return false,'unknown_side_guard_container_field'end end
    for key,v in pairs(r.guards)do
      if(key~='player'and key~='enemy')or type(v)~='table'then return false,'invalid_side_guard_side'end
      for id,p in pairs(v)do
        if not defs[id]or not sourceValid(b,key,p,false)or p.turn~=(b.turnCount or 0)
          or p.era~=math.max(p.profile,defs[id].gen)then
          return false,'invalid_side_guard_proof'end
        for k in pairs(p)do if not allowedProof[k]then return false,'unknown_side_guard_proof_field'end end
      end
    end
    for key,p in pairs(r.stall)do
      if(key~='player'and key~='enemy')or not sourceValid(b,key,p,true)or not int(p.count,1,8)
        or p.turn<(b.turnCount or 0)-1 or not(personal[p.move]and p.era==p.profile
          or(p.move=='WIDE_GUARD'or p.move=='QUICK_GUARD')and p.era==math.max(p.profile,5))then
        return false,'invalid_side_guard_stall'end
      for k in pairs(p)do if not allowedProof[k]and k~='count'and k~='move'then return false,'unknown_side_guard_stall_field'end end
    end
    return true
  end
  for _,id in ipairs(order)do local d=defs[id];local fact=assert(facts.move(id,7))
    assert(fact.number==d.number and fact.generation==d.gen and fact.pp==d.pp and fact.priority==d.priority
      and fact.type==d.type and fact.target==4 and fact.category=='status'and fact.power==0 and fact.alwaysHits,
      'side guard source drift '..id)
    local effect='KA_SIDE_GUARD_67_'..id
    mod.content.move_effects:register(effect,{kind='primary',accuracyChecked=false,run=M.cast,kascSideGuards67=M.OWNER})
    for _,key in ipairs(species.moveIds(id))do local old=assert(mod.content.moves:get(key))
      assert(not old.backendMoveOwner and old.effect=='KA_GEN_MOVE_UNSUPPORTED_'..id,'foreign side guard '..key)
      local flags={};if id~='CRAFTY_SHIELD'then flags.snatch=1 end
      if id=='MAT_BLOCK'then flags.nonsky=1;flags.noassist=1;flags.failcopycat=1 end
      mod.content.moves:patch(key,{effect=effect,target=4,category='status',power=0,accuracy=100,pp=d.pp,
        priority=d.priority,type=d.type,originGeneration=d.gen,backendMoveOwner=M.OWNER,backendMoveNumber=d.number,
        backendLearnsetRevision=old.backendLearnsetRevision or 1,kascBypassSub67=true,flags=flags,
        anim=copy(assert(mod.content.moves:get('BARRIER')).anim)})
      local anim=copy(assert(mod.content.battle_anims:get('BARRIER')));anim.source=M.OWNER
      if mod.content.battle_anims:get(key)then mod.content.battle_anims:patch(key,anim)else mod.content.battle_anims:register(key,anim)end
      aliases[key]=id
    end
    for i=#opts.moves.unsupportedStatus,1,-1 do if opts.moves.unsupportedStatus[i]==id then table.remove(opts.moves.unsupportedStatus,i)end end
  end
  mod.content.move_effects:patch('HEAL_EFFECT',{kascSideGuards67=M.OWNER})
  mod.events:on('battle.move_used',M.used,95002)
  mod.events:on('battle.turn_ended',function(ev)local r=rows(ev.battle)
    if r then r.guards={};for key,v in pairs(r.stall)do if v.turn<=(ev.battle.turnCount or 0)-1 then r.stall[key]=nil end end end
  end,10002)
  mod.events:on('battle.battler_switched',function(ev)M.clearStall(ev.battle,ev.battler)end,8002)
  mod.events:on('battle.fainted',function(ev)M.clearStall(ev.battle,ev.battler)end,8002)
  mod.events:on('battle.ended',function(ev)local b=ev.battle;if rows(b)then b.field.tokens[M.OWNER]=nil end end,92)
  mod.hooks:wrap('battle.damage',function(nextDamage,ctx)
    if not(ctx.opts and ctx.opts.typeless)and M.blocks(ctx)then return 0,{crit=false,typeMult=0}end
    return nextDamage(ctx)
  end,32002)
  function M.install()
    B._kascSideGuards67=M;FX._kascSideGuards67=M
    if B.performMove~=B._kascSideGuardsPerform67 then local old=B.performMove
      local w=function(...)return B._kascSideGuards67.perform(old,...)end;B.performMove=w;B._kascSideGuardsPerform67=w end
    if FX.makeCtx~=FX._kascSideGuardsContext67 then local old=FX.makeCtx
      local w=function(...)return FX._kascSideGuards67.context(old,...)end;FX.makeCtx=w;FX._kascSideGuardsContext67=w end
    if FX.runDamaging~=FX._kascSideGuardsDamage67 then local old=FX.runDamaging
      local w=function(...)return FX._kascSideGuards67.damage(old,...)end;FX.runDamaging=w;FX._kascSideGuardsDamage67=w end
  end
  M.install()
  if opts.supportLog and opts.supportLog.registerSegment then opts.supportLog.registerSegment({segmentId=M.CARD_ID,
    cardId=M.CARD_ID,schema='kasc.optional-feature-card/v1',version='1.0.0',owner=M.OWNER,active=true,
    dependencyStatus='native-singles-target-flags-priority-first-action-and-shared-stall',
    providerStatus='four-one-turn-side-shields-with-source-era-repetition',buildReceiptId='docs/SIDE_GUARDS_67.md',
    rollbackReceiptId='docs/SIDE_GUARDS_67.md'})end
  return M
end
