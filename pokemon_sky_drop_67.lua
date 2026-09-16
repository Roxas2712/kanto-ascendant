-- Sky Drop is a linked lift, not Fly's generic one-battler charge.
return function(mod,opts)
  local B=require('src.battle.BattleState');local FX=require('src.battle.EffectRegistry')
  local M={CARD_ID='KASC-67-SKY-DROP',OWNER='kasc.sky-drop/v1',ID='SKY_DROP'}
  local effect='KA_SKY_DROP_67';local tr=opts.i18n.text
  local aliases,canonical={},{}
  for id in pairs(opts.facts.data.moves)do for _,key in ipairs(opts.species.moveIds(id))do canonical[key]=id end end
  for _,key in ipairs(opts.species.moveIds(M.ID))do aliases[key]=true end
  local frames=setmetatable({},{__mode='k'});local bindings=setmetatable({},{__mode='k'})
  local executing=setmetatable({},{__mode='k'})
  local phases=setmetatable({},{__mode='k'})
  local function copy(v)if type(v)~='table'then return v end;local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r end
  local function pack(...)return{n=select('#',...),...}end
  local function int(v,a,z)return type(v)=='number'and v%1==0 and v>=a and v<=z end
  local function side(b,w)return w==b.player and'player'or w==b.enemy and'enemy'or nil end
  local function party(b,k)return k=='player'and b:playerPartyView()or b.enemyParty or{b.enemy and b.enemy.mon}end
  local function index(b,w)local key=side(b,w);if not key or not w.mon then return end
    for i,p in ipairs(party(b,key)or{})do if i<=6 and p==w.mon then return i end end
  end
  local function slot(w,inst)for i,s in ipairs(w.curMoves or{})do if i<=4 and s==inst then return i end end end
  local function live(w)local p=w and w.mon;return p and int(p.hp,1,999999)and not w.fainted
    and not(p.egg or p.isEgg or p.is_egg or p.eggSpecies or p.species=='EGG')end
  local function has(w,typ)for _,t in ipairs(w.curTypes or{})do if t==typ then return true end end;return false end
  local function raw(b)return b and b.field and b.field.tokens and b.field.tokens[M.OWNER]end
  local function seal(h)local v=copy(h);v.proof=nil
    return opts.rules.receipts.hash(M.OWNER..':'..opts.rules.receipts.canonical(v))end
  local fields={source=true,target=true,sourceParty=true,targetParty=true,sourceSpecies=true,targetSpecies=true,
    slot=true,move=true,profile=true,start=true,release=true,proof=true}
  local function shape(h)
    if type(h)~='table'or(h.source~='player'and h.source~='enemy')or(h.target~='player'and h.target~='enemy')
        or h.source==h.target or not int(h.sourceParty,1,6)or not int(h.targetParty,1,6)
        or type(h.sourceSpecies)~='string'or type(h.targetSpecies)~='string'or not int(h.slot,0,4)
        or not aliases[h.move]or not int(h.profile,1,7)or not int(h.start,0,99999999)
        or h.release~=h.start+1 or type(h.proof)~='string'then return false end
    for k,v in pairs(h)do if not fields[k]or type(v)=='table'then return false end end
    return h.proof==seal(h)
  end
  function M.epoch(b)
    local r=b and b.kascGenerationRulesReceipt;local e=b and b.data and b.data.move_effects and b.data.move_effects[effect]
    return getmetatable(b)==B and not b.demo and b.kind~='link'and not b.result and r and r.mode~='off'
      and int(r.activeEpoch,1,7)and(r.mode=='auto'or r.mode=='gen'..r.activeEpoch)
      and e and e.kascSkyDrop67==M.OWNER and r.activeEpoch or nil
  end
  function M.profile(b,w,m)
    local gen=M.epoch(b);local e=gen and m and b.data.move_effects[m.effect]
    if not gen or not live(w)or not index(b,w)or not m or not aliases[m.id]
        or m.backendMoveOwner~=M.OWNER or m.backendMoveNumber~=507 or m.power~=60 or m.category~='physical'
        or not e or e.kascSkyDrop67~=M.OWNER then return end
    if gen<5 then
      local called=mod.exports.pokemonCalledMoves67
      local owned=opts.rules.ownedGiftBattleCompatible(b.game,w.mon,b.data.pokemon[w.mon.species])
      local licensed=called and called.permission(b.game,w.mon,m.id,gen,true)
      if not(owned or licensed)or not opts.rules.monMoveAvailable(b.game,w.mon,m.id,gen,true)then return end
    end
    return math.max(5,gen)
  end
  function M.pair(b)
    local h=raw(b);if not M.epoch(b)or not shape(h)or h.profile~=M.epoch(b)
        or(b.turnCount or 0)<h.start or(b.turnCount or 0)>h.release then return end
    local u,t=b[h.source],b[h.target]
    if not live(u)or not live(t)or u.mon.species~=h.sourceSpecies or t.mon.species~=h.targetSpecies
        or index(b,u)~=h.sourceParty or index(b,t)~=h.targetParty then return end
    local bound=bindings[b];local inst=h.slot>0 and u.curMoves and u.curMoves[h.slot]
      or bound and bound.inst
    if not inst or inst.id~=h.move or not aliases[inst.id]then return end
    local f=frames[b];local releasing=f and f.user==u and f.inst==inst and f.release
    local phase=phases[b]
    local function elevated(w)return w.invulnerable==true or phase and phase.target==w and phase.allowed end
    if not releasing and(u.charging~=inst or u.chargeReady~=true or not elevated(u))then return end
    if not elevated(t)then return end
    return h,u,t,inst
  end
  function M.held(b,w)local h,u,t=M.pair(b);return h and w==t or false end
  function M.involved(b,w)local h,u,t=M.pair(b);return h and(w==u or w==t)or false end
  function M.lock(b,w)local h,u,t,inst=M.pair(b);if h and w==u then return inst end end
  function M.clear(b,interrupt)
    local h=raw(b);local bound=bindings[b]
    if shape(h)then
      local u,t=bound and bound.user or b[h.source],bound and bound.target or b[h.target]
      if u and u.mon and u.mon.species==h.sourceSpecies then
        if u.charging and u.charging.id==h.move then u.charging=nil;u.chargeReady=nil end
        if not u.charging then u.invulnerable=nil end
      end
      if t and t.mon and t.mon.species==h.targetSpecies and not t.charging then t.invulnerable=nil end
      for _,w in ipairs({u,t})do local pf=b.picFx and b.picFx[w]
        if pf and w and not w.charging then pf.hidden=nil;pf.kind=nil;pf.ox=0;pf.oy=0 end end
      if interrupt and b.sayNext then b:sayNext(tr('The lifted Pokémon was released!','Das hochgehobene Pokémon kommt frei!'))end
    end
    if b and b.field and b.field.tokens then b.field.tokens[M.OWNER]=nil end
    bindings[b]=nil
  end
  -- Called off-slot lifts remain weak/native continuations, not learning
  -- rights. They deliberately cannot cross a checkpoint mid-lift.
  function M.isContinuation(b,w,inst,called)
    local h,u,t,s=M.pair(b);return not called and h and w==u and inst==s or false
  end
  function M.pressureTargets(b,w,m)return M.profile(b,w,m)~=nil end
  function M.groundingDown(b,w,permanent)
    if not M.involved(b,w)then return false end
    if permanent then return true end -- Smack Down does not remove Sky Drop.
    M.clear(b,true);return false -- Genuine Gravity cancels both linked actors.
  end
  function M.switchBlock(b,w)
    if M.involved(b,w)then return tr('Sky Drop prevents switching!','Freier Fall verhindert den Wechsel!')end
  end
  local function blocked(ctx)
    local ex=mod.exports;local p,g=ex.pokemonPriorityAbilities67,ex.pokemonProtection67
    return p and p.blocks(ctx)or g and g.blocks(ctx)
  end
  function M.canLift(b,u,t,m,actual)
    local gen=M.profile(b,u,m)
    if not gen or not live(t)or not index(b,t)or u==t or u.mon==t.mon or raw(b)
        or t.invulnerable or u.invulnerable or u.charging or(u.substituteHP and u.charging)
        or not actual and(t.substituteHP or 0)>0 then return false end
    local grounding=mod.exports.pokemonGrounding67
    if not grounding or grounding.gravity(b)or blocked({battle=b,user=u,target=t,move=m})then return false end
    -- Existing TryHit absorption is an actual typed defensive ability,
    -- before Sky Drop's own onTryHit Substitute/weight gate. The first
    -- non-damaging lift deliberately never runs Wonder Guard's damage gate.
    if actual then return true end
    if gen>=6 then
      local variable=mod.exports.backendVariablePower67
      local weight=variable and variable.weight(b,t)
      if not int(weight,1,9999999)or weight>=2000 then return false end
    end
    if require('src.battle.TypeChart').effectiveness(m.type,t.curTypes or{})==0 then return false end
    local absorb=mod.exports.pokemonTypeAbsorption67
    if absorb and absorb.canAbsorb(b,u,t,m)then return false end
    return true
  end
  function M.noUseful(b,u,t,m)
    if not M.profile(b,u,m)then return false end
    local a=mod.exports.pokemonAbilityEffects67
    return a.moveScope(b,u,t,true,function()
      local h,source,target=M.pair(b)
      if h then return u~=source or t~=target or has(t,'FLYING')or blocked({battle=b,user=u,target=t,move=m})end
      return not M.canLift(b,u,t,m)or has(t,'FLYING')
    end,m)
  end
  local function fail(ctx)
    ctx.battle:cancelMoveAnim();ctx.battle:sayNext(tr('But, it failed!','Doch es schlug fehl!'))
  end
  function M.cast(ctx)
    local b,u,t,m=ctx.battle,ctx.user,ctx.target,ctx.move;local f=frames[b]
    if not f or f.user~=u or f.inst~=ctx.moveInst or not M.profile(b,u,m)then return fail(ctx)end
    local h,source,target=M.pair(b)
    if f.release then
      if not h or source~=u or target~=t then M.clear(b,true);return fail(ctx)end
      M.clear(b,false)
      if has(t,'FLYING')then b:cancelMoveAnim();b:sayNext(tr('Flying Pokémon cannot be hurt by the drop!',
        'Flug-Pokémon bleiben beim Fallen unversehrt!'));return end
      -- One genuine native damaging phase, same declaration/action and AP.
      FX.runDamaging(b,ctx,b:effectRecord(m.effect))
      b:sayNext(tr('%s was dropped!','%s wurde fallengelassen!'):format(ctx.displayName(t)))
      return
    end
    if not M.canLift(b,u,t,m,true)then return fail(ctx)end
    local absorb=mod.exports.pokemonTypeAbsorption67
    if absorb and absorb.absorb(b,ctx)then return end
    if not M.canLift(b,u,t,m)then return fail(ctx)end
    local real=slot(u,ctx.moveInst)
    if not real and not ctx.isCalled then return fail(ctx)end
    local row={source=side(b,u),target=side(b,t),sourceParty=index(b,u),targetParty=index(b,t),
      sourceSpecies=u.mon.species,targetSpecies=t.mon.species,slot=real or 0,move=m.id,
      profile=M.epoch(b),start=b.turnCount or 0,release=(b.turnCount or 0)+1}
    row.proof=seal(row);b.field=b.field or{};b.field.tokens=b.field.tokens or{};b.field.tokens[M.OWNER]=row
    bindings[b]={user=u,target=t,inst=ctx.moveInst}
    u.charging=ctx.moveInst;u.chargeReady=true;u.invulnerable=true;t.invulnerable=true
    local charge=assert(b:effectRecord('FLY_EFFECT').charge,'native Fly charge missing')
    b:cancelMoveAnim();b:animNext(not u.isPlayer and charge.enemyAnim or charge.anim,u.isPlayer)
    b:animNext(not t.isPlayer and charge.enemyAnim or charge.anim,t.isPlayer)
    b:sayNext(tr('%s lifted %s into the sky!','%s hebt %s in den Himmel!'):format(ctx.displayName(u),ctx.displayName(t)))
  end
  function M.project(b,w,m)
    local profile=M.profile(b,w,m);if not profile then return m end
    local out=copy(m);local f=frames[b];local h,u=M.pair(b)
    local release=f and f.user==w and f.release or h and u==w
    out.contact=release and true or false;out.flags=copy(m.flags);out.flags.contact=release and 1 or nil
    if profile==5 then out.flags.noassist=nil end
    out.kascSkyDropLift67=not release and M.OWNER or nil
    return out
  end
  function M.move(original,b,inst,...)
    local m=original(b,inst,...);if not m or not aliases[m.id]then return m end
    local f=frames[b];if f and f.inst==inst then return M.project(b,f.user,m)end
    for _,w in ipairs({b.player,b.enemy})do if w and slot(w,inst)then return M.project(b,w,m)end end
    return m
  end
  function M.perform(original,b,u,t,inst,called)
    if M.held(b,u)then return end
    local m=inst and b:moveDef(inst)
    local h,source,target,locked=M.pair(b);local release=h and u==source and inst==locked and not called
    -- The inner Called owner establishes a genuine child's source licence
    -- only after this outer wrapper is entered. Set a weak candidate scope,
    -- not availability rights; cast still validates the actual inner licence.
    local candidate=m and aliases[m.id]and m.backendMoveOwner==M.OWNER and m.backendMoveNumber==507
      and(called or release)and M.epoch(b)and live(u)and index(b,u)
    if not M.profile(b,u,m)and not candidate then
      local h,source,target=M.pair(b);local prior=phases[b]
      local a,memory=mod.exports.pokemonAbilityEffects67,mod.exports.pokemonTargetMemory67
      local bypass=h and t and(t==source or t==target)and m and
        (a and(a.activeAbility(b,u)=='NO_GUARD'or a.activeAbility(b,t)=='NO_GUARD')
          or memory and memory.phaseBypass(b,u,t,m))
      if bypass then phases[b]={target=t,allowed=true}end
      local out=pack(pcall(original,b,u,t,inst,called));phases[b]=prior
      if not out[1]then error(out[2],0)end;return unpack(out,2,out.n)
    end
    if h and not release or not release and not slot(u,inst)and not called then return end
    if release then t=target end
    local prior=frames[b];frames[b]={user=u,inst=inst,release=not not release}
    if executing[b]and executing[b].user==u then executing[b].performed=true end
    local out=pack(pcall(original,b,u,t,inst,called));frames[b]=prior
    if not out[1]then M.clear(b,true);error(out[2],0)end
    return unpack(out,2,out.n)
  end
  function M.execute(original,b,u,t,action)
    local h,source,target,inst=M.pair(b)
    if not h then return original(b,u,t,action)end
    if u==target then
      -- Class-item decisions are trainer actions, not the held Pokemon's
      -- move. Resolve actual class AI once; no second action or status tick.
      if u==b.enemy and not b.enemyActionForced then action=b:trainerAIAction()or action;b.enemyActionForced=true end
      if action and action.special=='aiItem'then return original(b,u,t,action)end
      if u==b.enemy then b.enemyActionForced=nil end
      b:sayNext(tr('%s cannot act while being lifted!','%s kann hochgehoben nicht handeln!'):format(FX.displayName(u)))
      return
    end
    if u~=source then return original(b,u,t,action)end
    if u==b.enemy and not b.enemyActionForced then
      local decision=b:trainerAIAction()or action;b.enemyActionForced=true
      if decision and decision.special=='aiItem'then
        local out=pack(pcall(original,b,u,target,decision));M.clear(b,true)
        if not out[1]then error(out[2],0)end;return unpack(out,2,out.n)
      end
    end
    local prior=executing[b];local f={user=u,performed=false};executing[b]=f
    local out=pack(pcall(original,b,u,target,inst));executing[b]=prior
    if raw(b)and not f.performed then M.clear(b,true)end
    if not out[1]then M.clear(b,true);error(out[2],0)end;return unpack(out,2,out.n)
  end
  function M.menu(original,b,w,...)
    local inst=M.lock(b,w);if inst then return inst end;return original(b,w,...)
  end
  function M.resolveSwitch(original,b,...)
    local text=M.switchBlock(b,b.player);if text then b:sayNext(text);return end
    return original(b,...)
  end
  function M.tryRun(original,b,...)
    if M.involved(b,b.player)then b:sayNext(tr('Sky Drop prevents escaping!','Freier Fall verhindert die Flucht!'));return end
    return original(b,...)
  end
  function M.clearVolatiles(original,b,w,...)
    if M.involved(b,w)then M.clear(b,true)end;return original(b,w,...)
  end
  local exceptions={GUST=true,TWISTER=true,SKY_UPPERCUT=true,THUNDER=true,HURRICANE=true,SMACK_DOWN=true,THOUSAND_ARROWS=true}
  function M.run(original,b,ctx,record)
    local h,u,t=M.pair(b);local who=ctx and ctx.target;local id=ctx and ctx.move and canonical[ctx.move.id]
    if not h or(who~=u and who~=t)then return original(b,ctx,record)end
    if not exceptions[id]then
      -- Swift's native Gen-I neverMiss record does not grant permission to
      -- hit a genuine linked Sky Drop. Real No Guard/Lock-On scopes still do.
      if who.invulnerable and record and record.neverMiss then local out={}
        for k,v in pairs(record)do out[k]=v end;out.neverMiss=nil;return original(b,ctx,out)end
      return original(b,ctx,record)
    end
    local prior=phases[b];phases[b]={target=who,allowed=true}
    local before=who.invulnerable;who.invulnerable=nil
    local out=pack(pcall(original,b,ctx,record))
    if M.pair(b)then who.invulnerable=before end
    phases[b]=prior
    if not out[1]then error(out[2],0)end;return unpack(out,2,out.n)
  end
  function M.damage(nextDamage,ctx)
    local b=ctx and ctx.battle;local h,u,t;if b then h,u,t=M.pair(b)end;local id=ctx and ctx.move and canonical[ctx.move.id]
    if not h or not ctx.target or(ctx.target.mon~=u.mon and ctx.target.mon~=t.mon)
        or(id~='GUST'and id~='TWISTER')or ctx.opts and ctx.opts.typeless then return nextDamage(ctx)end
    local out={};for k,v in pairs(ctx)do out[k]=v end;out.move=copy(ctx.move);out.move.power=out.move.power*2
    return nextDamage(out)
  end
  function M.validateCheckpoint(b)
    if frames[b]or executing[b]or phases[b]then return false,'sky_drop_dispatch_unsettled'end
    local h=raw(b);if h==nil then return true end
    if not shape(h)then return false,'invalid_sky_drop_pair'end
    if h.slot==0 then return false,'called_sky_drop_offslot_checkpoint'end
    if not M.pair(b)then return false,'sky_drop_identity_or_charge_mismatch'end
    if mod.exports.pokemonGrounding67.gravity(b)then return false,'sky_drop_under_gravity'end
    return true
  end
  function M.resume(b)
    bindings[b]=nil;frames[b]=nil;executing[b]=nil;phases[b]=nil
    local h=raw(b)
    if h and shape(h)and h.slot>0 then bindings[b]={user=b[h.source],target=b[h.target],inst=b[h.source].curMoves[h.slot]}end
    return M.validateCheckpoint(b)
  end
  function M.install()
    B._kascSkyDrop67=M;FX._kascSkyDrop67=M
    for method,owner in pairs({performMove='perform',executeAction='execute',moveDef='move',menuLockedAction='menu',
        resolveSwitch='resolveSwitch',tryRun='tryRun',clearVolatiles='clearVolatiles'})do
      local key='_kascSkyDropWrapper67_'..method
      if B[method]~=B[key]then local original=B[method];local wrapper=function(...)return B._kascSkyDrop67[owner](original,...)end
        B[method]=wrapper;B[key]=wrapper end
    end
    if FX.runDamaging~=FX._kascSkyDropRun67 then local original=FX.runDamaging
      local wrapper=function(...)return FX._kascSkyDrop67.run(original,...)end
      FX.runDamaging=wrapper;FX._kascSkyDropRun67=wrapper end
  end
  local f=assert(opts.facts.move(M.ID,7));local old=assert(mod.content.moves:get(M.ID))
  assert(f.number==507 and f.generation==5 and f.power==60 and f.pp==10 and f.type=='FLYING'
    and f.category=='physical'and f.accuracy==100 and f.priority==0,'Sky Drop source drift')
  assert(not old.backendMoveOwner and old.effect=='FLY_EFFECT','unexpected generic Sky Drop')
  mod.content.move_effects:register(effect,{kind='full',perform=M.cast,kascSkyDrop67=M.OWNER})
  for id in pairs(aliases)do local prior=assert(mod.content.moves:get(id))
    mod.content.moves:patch(id,{effect=effect,power=60,pp=10,accuracy=100,category='physical',originGeneration=5,
      backendMoveNumber=507,backendMoveOwner=M.OWNER,backendLearnsetRevision=prior.backendLearnsetRevision or 1,
      flags={contact=1,charge=1,protect=1,mirror=1,gravity=1,distance=1,metronome=1,nosleeptalk=1,noassist=1,failinstruct=1}})
    assert(mod.content.battle_anims:get(id),'existing Sky Drop release animation missing')
  end
  mod.hooks:wrap('battle.damage',M.damage,26000)
  mod.events:on('battle.fainted',function(ev)if raw(ev.battle)then M.clear(ev.battle,true)end end,100000)
  mod.events:on('battle.battler_switched',function(ev)if raw(ev.battle)then M.clear(ev.battle,true)end end,100000)
  mod.events:on('battle.turn_ended',function(ev)
    local h=raw(ev.battle);if h and(shape(h)and(ev.battle.turnCount or 0)>=h.release or not M.pair(ev.battle))then M.clear(ev.battle,true)end
  end,-100000)
  mod.events:on('battle.ended',function(ev)M.clear(ev.battle,false);frames[ev.battle]=nil;executing[ev.battle]=nil;phases[ev.battle]=nil end,100000)
  if opts.supportLog and opts.supportLog.registerSegment then opts.supportLog.registerSegment({segmentId=M.CARD_ID,
    cardId=M.CARD_ID,schema='kasc.optional-feature-card/v1',version='1.0.0',owner=M.OWNER,active=true,
    dependencyStatus='native-linked-charge-action-weight-and-checkpoint',providerStatus='true-two-turn-singles-sky-drop',
    buildReceiptId='docs/SKY_DROP_67.md',rollbackReceiptId='docs/SKY_DROP_67.md'})end
  return M
end
