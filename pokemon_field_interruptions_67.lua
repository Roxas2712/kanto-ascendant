-- Fairy Lock is a field condition; Powder cancels an actual typed action.
-- Neither is a saved status, damage attack, or permanent trapping link.
return function(mod,opts)
  local B=require('src.battle.BattleState');local FX=require('src.battle.EffectRegistry')
  local Player=require('src.battle.AnimPlayer');local A=assert(opts.abilities)
  local M={OWNER='kasc.field-interruptions/v1',CARD_ID='KASC-67-FIELD-INTERRUPTIONS'}
  local defs={FAIRY_LOCK={number=587,birth=6,type='FAIRY',pp=10,priority=0,parts={'BARRIER','MEAN_LOOK'}},
    POWDER={number=600,birth=6,type='BUG',pp=20,priority=1,parts={'STUN_SPORE'}}}
  local aliases={};for id in pairs(defs)do for _,a in ipairs(opts.species.moveIds(id))do aliases[a]=id end end
  local tr=opts.i18n.text;local frames=setmetatable({},{__mode='k'})
  local function copy(v)if type(v)~='table'then return v end;local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r end
  local function pack(...)return{n=select('#',...),...}end
  local function int(v,a,z)return type(v)=='number'and v%1==0 and v>=a and v<=z end
  local function side(b,w)return b and(w==b.player and'player'or w==b.enemy and'enemy')or nil end
  local function party(b,key)return key=='player'and b:playerPartyView()or key=='enemy'and(b.enemyParty or{b.enemy.mon})end
  local function index(b,w)for i,p in ipairs(party(b,side(b,w))or{})do if i<=6 and p==w.mon then return i end end end
  local function live(w)local p=w and w.mon;return p and int(p.hp,1,999999)and not w.fainted
    and not(p.egg or p.isEgg or p.is_egg or p.eggSpecies or p.species=='EGG')end
  local function has(w,typ)for _,t in ipairs(w.curTypes or{})do if t==typ then return true end end;return false end
  local function rows(b,create)if create then b.field=b.field or{};b.field.tokens=b.field.tokens or{}
    b.field.tokens[M.OWNER]=b.field.tokens[M.OWNER]or{powder={}}end
    return b and b.field and b.field.tokens and b.field.tokens[M.OWNER]end
  local function seal(v)local r=copy(v);r.proof=nil;return opts.rules.receipts.hash(M.OWNER..':'..opts.rules.receipts.canonical(r))end
  function M.epoch(b,u,move)
    local r=b and b.kascGenerationRulesReceipt;local e=b and b.data and b.data.move_effects and b.data.move_effects.HEAL_EFFECT
    if getmetatable(b)~=B or b.demo or b.kind=='link'or b.result or not r or not int(r.activeEpoch,1,7)
      or not(r.mode=='auto'or r.mode=='gen'..r.activeEpoch)or not e or e.kascFieldInterruptions67~=M.OWNER then return end
    if not move then return r.activeEpoch end
    local id=aliases[move.id]or move.id;local d=defs[id];local rec=d and b:effectRecord(move.effect)
    if not d or move.backendMoveOwner~=M.OWNER or move.backendMoveNumber~=d.number
      or not rec or rec.kascFieldInterruptions67~=M.OWNER then return end
    if r.activeEpoch<d.birth and not(live(u)and index(b,u)
      and opts.rules.monMoveAvailable(b.game,u.mon,move.id,r.activeEpoch,true))then return end
    return math.max(d.birth,r.activeEpoch),id
  end
  function M.lock(b)
    local r=rows(b);local h=r and r.lock;local t=b and(b.turnCount or 0)
    if M.epoch(b)and type(h)=='table'and h.profile==M.epoch(b)and h.proof==seal(h)
      and t>=h.applied and t<=h.expires then return h end
  end
  function M.powder(b,w)
    local r=rows(b);local h=r and r.powder and r.powder[side(b,w)]
    if M.epoch(b)and live(w)and type(h)=='table'and h.species==w.mon.species and h.party==index(b,w)
      and h.profile==M.epoch(b)and h.turn==(b.turnCount or 0)and h.proof==seal(h)then return h end
  end
  function M.blocked(b,w,forRun)
    local h=M.lock(b);if not h or not live(w)or not index(b,w)or(b.turnCount or 0)<h.applied+1 or has(w,'GHOST')then return false end
    local partial=mod.exports.backendPartialTrapping67
    local held=opts.held and opts.held(w.mon,b,w)
    if not forRun and partial and partial.supportsItem(b.game,held,M.epoch(b))
      and held=='SHED_SHELL'and A.activeAbility(b,w)~='KLUTZ'then return false end
    return true
  end
  function M.blocksSwitch(b,w,context)
    if not context or not context.voluntary or not M.blocked(b,w,false)then return false end
    local baton=mod.exports.pokemonBatonPass67
    if context.sourceCard=='KASC-67-BATON-PASS'and baton and baton.active(b,b.data.moves[w.lastMove])then return false end
    local pivot=mod.exports.pokemonPivotMoves67
    if pivot and pivot.authenticatesSwitch and pivot.authenticatesSwitch(b,w,context)then return false end
    return true
  end
  local function fail()return{tr('But, it failed!','Doch es schlug fehl!'),failed=true}end
  local function powderAbilityImmune(b,t,gen)
    -- This move's licensed source era is VI even inside a frozen earlier
    -- profile. Never extend the shared historical powder rules or activate
    -- dormant abilities: consult only the real effective, scoped owner.
    return gen>=6 and A.activeAbility(b,t)=='OVERCOAT'
  end
  local function heldPowderShield(b,u,t,move)
    local shield=opts.powderShield and opts.powderShield()
    if not shield then return false end
    if type(shield.powderShield)=='function'then return shield.powderShield(b,t,move)==true end
    return type(shield.blocksPowder)=='function'and shield.blocksPowder(b,u,t,move)==true or false
  end
  local function powderImmune(b,u,t,move,gen)
    if gen>=6 and has(t,'GRASS')then return true end
    if powderAbilityImmune(b,t,gen)then return true end
    local absorption=mod.exports.pokemonTypeAbsorption67
    if absorption and absorption.canAbsorb(b,u,t,move)then return true end
    -- Delegate only to an actual installed powder-shield owner. Possession
    -- of an unimplemented/unknown item is not a fabricated passive effect.
    return heldPowderShield(b,u,t,move)
  end
  function M.noUseful(b,u,t,move)
    if not move or not M.epoch(b)then return false end
    local gen,id=M.epoch(b,u,move)
    if not gen then return M.shouldInterrupt(b,u,t,move)~=nil end
    if not live(u)or not index(b,u)then return true end
    if id=='FAIRY_LOCK'then return M.lock(b)~=nil end
    if not live(t)or not index(b,t)or u==t or M.powder(b,t)then return true end
    return A.moveScope(b,u,t,true,function()
      local memory=mod.exports.pokemonTargetMemory67
      return opts.priority.blocks({battle=b,user=u,target=t,move=move})
        or opts.protection.blocks({battle=b,user=u,target=t,move=move})
        or t.invulnerable and not(memory and memory.phaseBypass(b,u,t,move))
        or powderImmune(b,u,t,move,gen)
    end,move)
  end
  function M.cast(ctx)
    local b,u,t,move=ctx.battle,ctx.user,ctx.target,ctx.move;local gen,id=M.epoch(b,u,move)
    if not gen or not live(u)or not index(b,u)then return fail()end
    if id=='FAIRY_LOCK'then
      if M.lock(b)then return fail()end
      local h={applied=b.turnCount or 0,expires=(b.turnCount or 0)+1,profile=M.epoch(b),epoch=gen,
        source=side(b,u),species=u.mon.species,party=index(b,u)};h.proof=seal(h);rows(b,true).lock=h
      return{tr('No one will be able to run away during the next turn!','In der nächsten Runde kann niemand entkommen!')}
    end
    if not live(t)or not index(b,t)or u==t or M.powder(b,t)then return fail()end
    return A.moveScope(b,u,t,true,function()
      local memory=mod.exports.pokemonTargetMemory67
      if opts.priority.blocks(ctx)or opts.protection.blocks(ctx)
        or t.invulnerable and not(memory and memory.phaseBypass(b,u,t,move))then return fail()end
      local absorption=mod.exports.pokemonTypeAbsorption67
      if gen>=6 and has(t,'GRASS')then return fail()end
      if powderAbilityImmune(b,t,gen)then
        -- The shared absorption owner may be using the earlier native
        -- profile; it must not be globally promoted to this licensed move's
        -- source era. Its normal VI/VII announcement is reused when valid.
        if absorption and absorption.absorb(b,ctx)then return{}end
        return{tr('Overcoat!','Partikelschutz!'),failed=true}
      end
      if absorption and absorption.absorb(b,ctx)then return{}end
      if heldPowderShield(b,u,t,move)then return fail()end
      if not b:accuracyRoll(move,u,t)then return fail()end
      local h={species=t.mon.species,party=index(b,t),profile=M.epoch(b),epoch=gen,turn=b.turnCount or 0}
      h.proof=seal(h);rows(b,true).powder[side(b,t)]=h
      return{tr('%s was covered in powder!','%s ist mit Pulver bedeckt!'):format(t.name)}
    end,move)
  end
  local function finalMove(b,u,move)
    local conversion=mod.exports.pokemonMoveConversion67 or opts.conversion
    return conversion and conversion.project(b,u,move)or move
  end
  function M.shouldInterrupt(b,u,t,move)
    local h=M.powder(b,u);if not h or not move then return end
    move=finalMove(b,u,move);if not move or move.type~='FIRE'then return end
    if h.epoch>=7 then
      -- VII Powder(-1) follows actual primal weather(0) and the genuine
      -- Burn Up TryMove prerequisite. VI Powder(+1) precedes weather(0).
      local primal=mod.exports.pokemonPrimalWeather67
      if primal and primal.forbidden(b,move)then return end
      local burn=mod.exports.pokemonBurnUp67
      if move.id=='BURN_UP'and burn and burn.active(b,move)and not burn.hasFire(u)then return end
    end
    return h,move
  end
  function M.powderLoss(b,u)
    if not M.powder(b,u)then return end
    local maximum=u.mon.stats and u.mon.stats.hp
    if not int(maximum,1,999999)then return end
    if A.blocksIndirect(b,u,'powder')then return 0 end
    return math.max(1,math.floor((maximum+2)/4))
  end
  function M.interrupt(ctx)
    local b,u=ctx and ctx.battle,ctx and ctx.user;local f=b and frames[b]
    if not f or f.ctx~=ctx or not f.declared or f.user~=u or f.target~=ctx.target
      or f.slot~=ctx.moveInst or f.party~=index(b,u)or f.species~=u.mon.species then return false end
    local h,move=M.shouldInterrupt(b,u,ctx.target,ctx.move);if not h then return false end
    local amount=M.powderLoss(b,u);if amount==nil then return false end
    f.interrupted=true;b:cancelMoveAnim();u.lastMove=ctx.move.id
    b:sayNext(tr('The powder exploded when %s used %s!','Das Pulver explodiert bei %s\' Einsatz von %s!'):format(u.name,move.name))
    if amount>0 then assert(mod.exports.pokemonFatalConditions67,'Powder needs genuine indirect HP-loss owner').directLoss(b,u,amount)end
    return true
  end
  function M.used(ev)
    local f=ev and frames[ev.battle]
    if f and ev.user==f.user and ev.target==f.target and ev.move.id==f.move.id
      and ev.move.effect==f.move.effect and ev.isCalled==f.called then f.declared=true end
  end
  function M.context(original,b,u,t,move,slot,called,...)
    local ctx=original(b,u,t,move,slot,called,...);local f=frames[b]
    if f and f.declared and f.user==u and f.target==t and f.slot==slot and f.called==not not called
      and ctx.move and ctx.move.id==f.move.id then f.ctx=ctx end
    return ctx
  end
  function M.perform(original,b,u,t,slot,called,...)
    local move=slot and b:moveDef(slot)
    if not M.powder(b,u)or not move or not live(t)or not index(b,u)then return original(b,u,t,slot,called,...)end
    local before=frames[b];local f={user=u,target=t,slot=slot,move=move,called=not not called,
      species=u.mon.species,party=index(b,u)};frames[b]=f
    local raw,previous=rawget(b,'effectRecord'),b.effectRecord
    b.effectRecord=function(self,id)local rec=previous(self,id)
      if id~=move.effect or not rec then return rec end
      local proxy={};for k,v in pairs(rec)do if k~='callsMove'then proxy[k]=v end end
      return setmetatable(proxy,{__index=function(_,key)
        if key=='callsMove'and frames[b]==f and f.ctx and M.shouldInterrupt(b,u,t,f.ctx.move)then
          return function(actual)if not M.interrupt(actual)then error('unsettled Powder native phase',0)end;return nil end
        end;return rec[key]
      end})
    end
    local out=pack(pcall(original,b,u,t,slot,called,...));b.effectRecord=raw;frames[b]=before
    if not out[1]then error(out[2],0)end;return unpack(out,2,out.n)
  end
  function M.damage(nextDamage,ctx)
    if ctx and not(ctx.opts and(ctx.opts.typeless or ctx.opts.typelessDamage))
      and M.shouldInterrupt(ctx.battle,ctx.user,ctx.target,ctx.move)then
      return 0,{crit=false,typeMult=10,kascPowder67=M.OWNER,powderLoss=M.powderLoss(ctx.battle,ctx.user)}
    end;return nextDamage(ctx)
  end
  function M.switch(ev)local r=rows(ev.battle);if r and ev.battler then local key=side(ev.battle,ev.battler);if key then r.powder[key]=nil end end end
  function M.endTurn(ev)local b=ev.battle;local r=rows(b);if not r then return end;r.powder={}
    if r.lock and(b.turnCount or 0)>=r.lock.expires then r.lock=nil end end
  function M.validateCheckpoint(b)
    if frames[b]then return false,'field_interruption_unsettled'end
    local r=rows(b);if r==nil then return true end
    if not M.epoch(b)or type(r)~='table'or type(r.powder)~='table'then return false,'invalid_field_interruptions_container'end
    for k in pairs(r)do if k~='powder'and k~='lock'then return false,'unknown_field_interruptions_container_field'end end
    local h=r.lock
    if h then local list=type(h)=='table'and party(b,h.source);local source=list and list[h.party]
      if type(h)~='table'or not int(h.applied,0,b.turnCount or 0)or h.expires~=h.applied+1
        or(b.turnCount or 0)>h.expires or h.profile~=M.epoch(b)or h.epoch~=math.max(6,h.profile)
        or not source or source.species~=h.species or not b.data.pokemon[h.species]or h.proof~=seal(h)then return false,'invalid_fairy_lock_receipt'end
      for k in pairs(h)do if not({applied=true,expires=true,profile=true,epoch=true,source=true,species=true,party=true,proof=true})[k]then return false,'unknown_fairy_lock_field'end end
    end
    for key,h in pairs(r.powder)do local w=(key=='player'or key=='enemy')and b[key]
      if not w or not M.powder(b,w)or not int(h.epoch,6,7)or h.epoch~=math.max(6,h.profile)then return false,'invalid_powder_receipt'end
      for k in pairs(h)do if not({species=true,party=true,profile=true,epoch=true,turn=true,proof=true})[k]then return false,'unknown_powder_field'end end
    end;return true
  end
  local function sourceMove(id)for _,a in ipairs(opts.species.moveIds(id))do local r=mod.content.moves:get(a);if r then return r end end end
  local function sourceAnimation(id)for _,a in ipairs(opts.species.moveIds(id))do local r=mod.content.battle_anims:get(a);if r then return r end end end
  for id,d in pairs(defs)do local f=assert(opts.facts.move(id,6));local old=assert(mod.content.moves:get(id))
    assert(f.number==d.number and f.generation==6 and f.type==d.type and f.category=='status'and f.power==0
      and f.pp==d.pp and f.priority==d.priority and f.alwaysHits==(id=='FAIRY_LOCK')and(id~='POWDER'or f.accuracy==100),
      'Field interruption source drift '..id)
    assert(not old.backendMoveOwner and old.effect=='KA_GEN_MOVE_UNSUPPORTED_'..id,'foreign Field interruption owner '..id)
    local effect='KA_FIELD_INTERRUPTION_67_'..id
    mod.content.move_effects:register(effect,{kind='primary',accuracyChecked=false,run=M.cast,kascFieldInterruptions67=M.OWNER})
    for _,alias in ipairs(opts.species.moveIds(id))do if mod.content.moves:get(alias)then mod.content.moves:patch(alias,{
      effect=effect,backendMoveOwner=M.OWNER,backendMoveNumber=d.number,backendLearnsetRevision=old.backendLearnsetRevision or 1,
      originGeneration=6,type=d.type,power=0,category='status',priority=d.priority,target=f.target,
      anim=copy(assert(sourceMove(d.parts[1]),'missing source move '..d.parts[1]).anim)})end end
    local animation={seq={},source=M.OWNER};for _,part in ipairs(d.parts)do
      for _,step in ipairs(assert(sourceAnimation(part),'missing source animation '..part).seq)do animation.seq[#animation.seq+1]=copy(step)end end
    if mod.content.battle_anims:get(id)then mod.content.battle_anims:patch(id,animation)else mod.content.battle_anims:register(id,animation)end
    if opts.catalog then for i=#opts.catalog.unsupportedStatus,1,-1 do if opts.catalog.unsupportedStatus[i]==id then table.remove(opts.catalog.unsupportedStatus,i)end end end
  end
  mod.content.move_effects:patch('HEAL_EFFECT',{kascFieldInterruptions67=M.OWNER})
  function M.position(p,id)
    local row=p.data and p.data.moveAnims and p.data.moveAnims[id];if not defs[id]or not row or row.source~=M.OWNER then return end
    local hud={{0,0,88,30},{72,56,160,94},{0,98,160,144}}
    for _,step in ipairs(p.steps or{})do local out={};local shift=-16
      for _,s in ipairs(step.sprites or{})do if s.x>0 and s.x<168 and s.y>0 and s.y<160 then shift=math.max(shift,16-s.y)end end
      for i,s in ipairs(step.sprites or{})do local q=copy(s);if q.x>0 and q.x<168 and q.y>0 and q.y<160 then q.y=q.y+shift end
        local x,y=q.x-8,q.y-16;for _,box in ipairs(hud)do if x<box[3]and x+8>box[1]and y<box[4]and y+8>box[2]then q.x=0;break end end;out[i]=q end
      step.sprites=out
    end
  end
  function M.install()
    B._kascFieldInterruptions67=M;FX._kascFieldInterruptions67=M;Player._kascFieldInterruptions67=M
    if not B._kascFieldInterruptionsWrapped67 then local perform=B.performMove
      B.performMove=function(...)return B._kascFieldInterruptions67.perform(perform,...)end;B._kascFieldInterruptionsWrapped67=true end
    if not FX._kascFieldInterruptionsWrapped67 then local context=FX.makeCtx
      FX.makeCtx=function(...)return FX._kascFieldInterruptions67.context(context,...)end;FX._kascFieldInterruptionsWrapped67=true end
    if not Player._kascFieldInterruptionsWrapped67 then local start=Player.start
      Player.start=function(self,id,...)local out=pack(start(self,id,...));Player._kascFieldInterruptions67.position(self,id);return unpack(out,1,out.n)end;Player._kascFieldInterruptionsWrapped67=true end
  end
  M.install();mod.hooks:wrap('battle.damage',M.damage,65000)
  mod.events:on('battle.move_used',M.used,100100)
  mod.events:on('battle.battler_switched',M.switch,8002)
  mod.events:on('battle.fainted',M.switch,8002)
  mod.events:on('battle.turn_ended',M.endTurn,8002)
  mod.events:on('battle.ended',function(ev)if rows(ev.battle)then ev.battle.field.tokens[M.OWNER]=nil end;frames[ev.battle]=nil end,8002)
  if opts.supportLog and opts.supportLog.registerSegment then opts.supportLog.registerSegment({
    segmentId=M.CARD_ID,cardId=M.CARD_ID,schema='kasc.optional-feature-card/v1',version='1.0.0',owner=M.OWNER,active=true,
    dependencyStatus='native-typed-post-AP-phase-field-switch-and-indirect-loss',providerStatus='fairy-lock-and-powder',
    buildReceiptId='docs/FIELD_INTERRUPTIONS_67.md',rollbackReceiptId='docs/FIELD_INTERRUPTIONS_67.md'})end
  return M
end
