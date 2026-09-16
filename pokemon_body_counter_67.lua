-- Actual body-hit provenance for Counter II+, Metal Burst, Endeavor and
-- Final Gambit. Gen-I Counter retains the native shared-register branch.
return function(mod,opts)
  local B=require('src.battle.BattleState');local FX=require('src.battle.EffectRegistry')
  local TypeChart=require('src.battle.TypeChart');local Player=require('src.battle.AnimPlayer')
  local M={CARD_ID='KASC-67-BODY-COUNTER',OWNER='kasc.body-counter/v1'}
  local frames=setmetatable({},{__mode='k'});local activeBattle
  local private='KA_BODY_COUNTER_DISPATCH_67'
  local defs={COUNTER={number=68,gen=1,type='FIGHTING',category='physical',pp=20,parts={'COUNTER'}},
    ENDEAVOR={number=283,gen=3,type='NORMAL',category='physical',pp=5,contact=true,parts={'TAKE_DOWN'}},
    METAL_BURST={number=368,gen=4,type='STEEL',category='physical',pp=10,parts={'BARRIER','COMET_PUNCH'}},
    FINAL_GAMBIT={number=515,gen=5,type='FIGHTING',category='special',pp=5,parts={'FOCUS_ENERGY','SEISMIC_TOSS'}}}
  local tr=opts.i18n.text
  local function copy(v)if type(v)~='table'then return v end;local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r end
  local function shallow(v)local r={};for k,x in pairs(v or{})do r[k]=x end;return r end
  local function pack(...)return{n=select('#',...),...}end
  local function id(move)return move and(move.id==private and'COUNTER'or move.id)end
  local function side(b,w)return b and w and(w==b.player and'player'or w==b.enemy and'enemy'or nil)or nil end
  local function live(w)
    local m=w and w.mon
    return m and type(m.hp)=='number'and m.hp>0 and not w.fainted
      and not(m.isEgg or m.egg or m.is_egg or m.eggSpecies)
  end
  local function state(b,create)
    if create then b.field=b.field or{};b.field.tokens=b.field.tokens or{}
      b.field.tokens[M.OWNER]=b.field.tokens[M.OWNER]or{turn=b.turnCount or 0,armed={},counter={},burst={}}
    end
    return b and b.field and b.field.tokens and b.field.tokens[M.OWNER]
  end
  function M.epoch(b)
    local r=b and b.kascGenerationRulesReceipt
    local marker=b and b.data and b.data.move_effects and b.data.move_effects.HEAL_EFFECT
    if getmetatable(b)==B and not b.demo and b.kind~='link'and not b.result and r and r.mode~='off'
        and type(r.activeEpoch)=='number'and r.activeEpoch%1==0 and r.activeEpoch>=1 and r.activeEpoch<=7
        and marker and marker.kascBodyCounter67==M.OWNER then return r.activeEpoch end
  end
  function M.active(b,move,u)
    local gen=M.epoch(b);local d=defs[id(move)]
    local record=move and b and b.data and b.data.move_effects and b.data.move_effects[move.effect]
    if not gen or not d or move.backendMoveOwner~=M.OWNER or not record or record.kascBodyCounter67~=M.OWNER then return false end
    if id(move)=='COUNTER'and gen==1 then return false end
    if gen<d.gen then
      return live(u)and opts.rules.ownedGiftBattleCompatible
        and opts.rules.ownedGiftBattleCompatible(b.game,u.mon,b.data.pokemon[u.mon.species])or false
    end
    return true
  end
  function M.category(b,move)
    if (M.epoch(b)or 1)<=3 then
      if move.id=='HIDDEN_POWER'then return'physical'end
      return TypeChart.category(move.type)
    end
    return move.category or TypeChart.category(move.type)
  end
  function M.clear(b,w)
    local r=state(b);if not r then return end
    if not w then b.field.tokens[M.OWNER]=nil;return end
    local key=side(b,w);if key then r.armed[key]=nil;r.counter[key]=nil;r.burst[key]=nil end
    -- Source slot, not source identity, owns the redirected destination in
    -- III+: Counter/Metal Burst may hit a replacement occupying that slot.
  end
  function M.begin(ev)
    local b=ev and ev.battle;if not M.epoch(b)then return end
    M.clear(b);local r=state(b,true)
    if M.epoch(b)<3 then return end
    for _,key in ipairs({'player','enemy'})do
      local a=ev[key..'Action'];local move=a and b.data.moves[a.id]
      if a and not a.special and id(move)=='COUNTER'and M.active(b,move,b[key])then r.armed[key]=true end
    end
  end
  function M.nativeHit(b,ev)
    local f=b and frames[b];local hit=f and f.hit
    if not ev or ev.battle~=b or not M.epoch(b)or not hit
        or hit.user~=ev.user or hit.target~=ev.target or hit.move~=ev.move or hit.damage~=ev.damage
        or not hit.direct or not side(b,ev.user)or not side(b,ev.target)or ev.user==ev.target then return end
    -- A read-only copy of the current genuine FX hit, not a durable receipt
    -- and not the shared lastDamage register. Observers cannot consume it.
    return shallow(hit)
  end
  function M.hit(ev)
    local b=ev and ev.battle;local f=b and frames[b];local hit=f and f.hit
    local r=b and state(b);local key=b and ev and side(b,ev.target)
    if not M.nativeHit(b,ev)or not r or r.turn~=(b.turnCount or 0)or not key or hit.consumed then return end
    hit.consumed=true
    if hit.substitute then
      -- II's lastAttackedBy includes an actual Substitute strike with zero
      -- body damage. Accuracy/Protect misses never enter this hit boundary.
      if M.epoch(b)==2 then r.counter[key]=nil end
      return
    end
    local row={source=side(b,ev.user),move=id(ev.move),damage=hit.damage}
    r.burst[key]=row
    if M.category(b,ev.move)=='physical'then r.counter[key]=copy(row)
    elseif M.epoch(b)==2 then r.counter[key]=nil end
  end
  function M.receipt(b,u,t,kind)
    local gen=M.epoch(b);local r=state(b);local key=side(b,u);local hit=r and key and r[kind]and r[kind][key]
    if not gen or not r or r.turn~=(b.turnCount or 0)or not hit or hit.source~=side(b,t)then return end
    if kind=='counter'then
      if gen>=3 and not r.armed[key]then return end
      if gen==2 and (hit.damage<=0 or not t or t.lastMove~=hit.move)then return end
    end
    return hit
  end
  function M.choose(ctx)
    local b,u,t,m=ctx and ctx.battle,ctx and ctx.user,ctx and ctx.target,ctx and ctx.move
    if not M.active(b,m,u)or not live(u)or not live(t)or u==t or not side(b,u)or not side(b,t)then
      return nil,tr('But, it failed!','Doch es schlug fehl!')
    end
    local source=id(m);local damage
    if source=='ENDEAVOR'then
      if u.mon.hp>=t.mon.hp then return nil,tr('But, it failed!','Doch es schlug fehl!')end
      damage=t.mon.hp-u.mon.hp
    elseif source=='FINAL_GAMBIT'then damage=u.mon.hp
    else
      local hit=M.receipt(b,u,t,source=='COUNTER'and'counter'or'burst')
      if not hit then return nil,tr('But, it failed!','Doch es schlug fehl!')end
      damage=math.max(1,math.floor(hit.damage*(source=='COUNTER'and 2 or 1.5)))
    end
    if TypeChart.effectiveness(m.type,t.curTypes)==0 then return 0,{crit=false,typeMult=0}end
    return math.min(65535,damage),{crit=false,typeMult=10}
  end
  function M.damage(nextDamage,ctx)
    if not ctx or ctx.opts and ctx.opts.typeless or not M.active(ctx.battle,ctx.move,ctx.user)then return nextDamage(ctx)end
    local amount,info=M.choose(ctx)
    if not amount then return 0,{crit=false,typeMult=10,missed=true}end
    return amount,info
  end
  function M.run(original,b,ctx,record)
    if not M.epoch(b)or not ctx or not ctx.user or not ctx.target or ctx.user==ctx.target then return original(b,ctx,record)end
    local previousFrame=frames[b];local f={};frames[b]=f
    local originalCtx=ctx;local dispatch
    local rawAccuracy,previousAccuracy=rawget(b,'accuracyRoll'),b.accuracyRoll
    if id(ctx.move)=='COUNTER'and M.active(b,ctx.move,ctx.user)then
      -- Only this detached instance bypasses the host's id==COUNTER branch.
      -- Restore its canonical ID during chooseDamage, before all hit events.
      ctx=shallow(ctx);dispatch=copy(ctx.move);dispatch.id=private;ctx.move=dispatch
      dispatch.flags=copy(opts.facts.data.moves.COUNTER.flags)
      record=shallow(record);record.chooseDamage=function(c)
        c.move.id='COUNTER';return M.choose(c)
      end
      b.accuracyRoll=function(self,move,u,t)
        return previousAccuracy(self,move==dispatch and originalCtx.move or move,u,t)
      end
    elseif id(ctx.move)=='FINAL_GAMBIT'and M.active(b,ctx.move,ctx.user)then
      record=shallow(record);record.chooseDamage=function(c)
        local amount,info=M.choose(c)
        if amount and amount>0 and info.typeMult~=0 then
          -- Actual successful damage choice is AFTER accuracy, Protect,
          -- Substitute interception and type immunity. This is faint(),
          -- not recoil: no own Substitute, Endure, Magic Guard or item save.
          c.user.mon.hp=0
        end
        return amount,info
      end
    end
    local raw,previous=rawget(b,'applyDamage'),b.applyDamage
    b.applyDamage=function(self,w,amount)
      local survival=mod.exports and mod.exports.pokemonLethalHitSurvival67
      local attempt=survival and survival.incomingHit and survival.incomingHit(self,w)or amount
      local direct=w==ctx.target and w.mon.hp>0 and type(attempt)=='number'and attempt>0
      local substitute=direct and w.substituteHP~=nil
      local dealt=previous(self,w,amount)
      if w==ctx.target then f.hit={user=ctx.user,target=w,move=ctx.move,damage=dealt,direct=direct,substitute=substitute}end
      return dealt
    end
    local out=pack(pcall(original,b,ctx,record))
    b.applyDamage=raw;b.accuracyRoll=rawAccuracy;frames[b]=previousFrame
    if dispatch then dispatch.id='COUNTER'end
    if not out[1]then error(out[2],0)end
    if dispatch then
      -- Native FX wrote these outcomes on the private dispatch context.
      -- Outer strike owners (notably Familienbande) must receive the actual
      -- result on their original context, without adopting the private move.
      for _,key in ipairs({'totalDealt','hits','rawDamage','brokeSub','hitSfx'})do originalCtx[key]=ctx[key]end
    end
    return unpack(out,2,out.n)
  end
  function M.makeCtx(original,b,u,t,...)
    local ctx=original(b,u,t,...)
    if id(ctx.move)=='FINAL_GAMBIT'and M.active(b,ctx.move,u)then
      ctx.move=copy(ctx.move);ctx.move.contact=math.max(5,M.epoch(b))==5
    end
    return ctx
  end
  function M.scoped(original,b,...)
    local prior=activeBattle;activeBattle=b;local out=pack(pcall(original,b,...));activeBattle=prior
    if not out[1]then error(out[2],0)end;return unpack(out,2,out.n)
  end
  function M.order(nextOrder,a,am,z,zm,ctx)
    local b=activeBattle;local gen=M.epoch(b)
    if gen and gen>=2 and a==b.player and z==b.enemy then
      if id(am)=='COUNTER'and M.active(b,am,a)then am=copy(am);am.priority=gen==2 and -1 or -5 end
      if id(zm)=='COUNTER'and M.active(b,zm,z)then zm=copy(zm);zm.priority=gen==2 and -1 or -5 end
    end
    return nextOrder(a,am,z,zm,ctx)
  end
  function M.validateCheckpoint(b)
    if frames[b]or activeBattle==b then return false,'body_counter_unsettled'end
    local r=state(b);if r==nil then return true end
    if type(r)~='table'or type(r.turn)~='number'or r.turn%1~=0 or r.turn~=(b.turnCount or 0)
        or type(r.armed)~='table'or type(r.counter)~='table'or type(r.burst)~='table'then return false,'invalid_body_counter_container'end
    for k in pairs(r)do if k~='turn'and k~='armed'and k~='counter'and k~='burst'then return false,'unknown_body_counter_container_field'end end
    for k,v in pairs(r.armed)do if(k~='player'and k~='enemy')or v~=true then return false,'invalid_body_counter_arm'end end
    for _,kind in ipairs({'counter','burst'})do for key,v in pairs(r[kind])do
      if(key~='player'and key~='enemy')or type(v)~='table'or(v.source~='player'and v.source~='enemy')or v.source==key
          or type(v.move)~='string'or not b.data.moves[v.move]or type(v.damage)~='number'or v.damage%1~=0 or v.damage<0 or v.damage>65535 then return false,'invalid_body_counter_receipt'end
      for k in pairs(v)do if k~='source'and k~='move'and k~='damage'then return false,'unknown_body_counter_receipt_field'end end
    end end
    return true
  end
  for _,source in ipairs({'COUNTER','ENDEAVOR','METAL_BURST','FINAL_GAMBIT'})do
    local d=defs[source];local fact=assert(opts.facts.move(source,math.max(4,d.gen)))
    assert(fact.number==d.number and fact.generation==d.gen and fact.type==d.type and fact.category==d.category
      and fact.power==0 and fact.pp==d.pp and fact.accuracy==100,'body counter source drift '..source)
    local prior=assert(mod.content.moves:get(source),'body counter catalog missing '..source)
    assert(not prior.backendMoveOwner and (source=='COUNTER'or prior.effect=='NO_ADDITIONAL_EFFECT'),'foreign body counter owner '..source)
    local effect='KA_BODY_COUNTER_67_'..source;local fields={kind='full',chooseDamage=M.choose,kascBodyCounter67=M.OWNER}
    if source=='COUNTER'then fields=copy(assert(mod.content.move_effects:get(prior.effect)));fields.kind='full';fields.chooseDamage=M.choose;fields.kascBodyCounter67=M.OWNER end
    mod.content.move_effects:register(effect,fields)
    local patch={effect=effect,backendMoveOwner=M.OWNER,backendMoveNumber=d.number,kascFixedDamage67=true}
    if source~='COUNTER'then
      patch.power=1;patch.originGeneration=d.gen;patch.category=d.category;patch.type=d.type;patch.accuracy=100
      patch.pp=d.pp;patch.priority=0;patch.contact=d.contact==true;patch.target=source=='METAL_BURST'and 1 or 10
      patch.backendLearnsetRevision=prior.backendLearnsetRevision or 1
      if source=='ENDEAVOR'or source=='FINAL_GAMBIT'then patch.flags={noparentalbond=1}end
      patch.anim=copy(assert(mod.content.moves:get(d.parts[1])).anim)
      local animation={seq={},source=M.OWNER}
      for _,part in ipairs(d.parts)do for _,step in ipairs(assert(mod.content.battle_anims:get(part)).seq)do animation.seq[#animation.seq+1]=copy(step)end end
      mod.content.battle_anims:patch(source,animation)
    end
    mod.content.moves:patch(source,patch)
  end
  function M.position(player,source)
    local row=player.data and player.data.moveAnims and player.data.moveAnims[source]
    if source=='COUNTER'or not defs[source]or not row or row.source~=M.OWNER then return end
    for _,step in ipairs(player.steps or{})do
      local shift=-16;for _,s in ipairs(step.sprites or{})do if s.x>0 and s.x<168 and s.y>0 and s.y<160 then shift=math.max(shift,16-s.y)end end
      local sprites={};for i,s in ipairs(step.sprites or{})do local q=copy(s)
        if q.x>0 and q.x<168 and q.y>0 and q.y<160 then q.y=q.y+shift
          if mod.exports.pokemonPartnerHits67.inHud(q)then q.x=0 end end;sprites[i]=q
      end;step.sprites=sprites
    end
  end
  function M.install()
    B._kascBodyCounter67=M;FX._kascBodyCounter67=M;Player._kascBodyCounter67=M
    if not FX._kascBodyCounterWrapped67 then
      local run,make=FX.runDamaging,FX.makeCtx
      FX.runDamaging=function(...)return FX._kascBodyCounter67.run(run,...)end
      FX.makeCtx=function(...)return FX._kascBodyCounter67.makeCtx(make,...)end;FX._kascBodyCounterWrapped67=true
    end
    if not B._kascBodyCounterWrapped67 then local original=B.resolveTurn
      B.resolveTurn=function(...)return B._kascBodyCounter67.scoped(original,...)end;B._kascBodyCounterWrapped67=true end
    if not Player._kascBodyCounterWrapped67 then local original=Player.start
      Player.start=function(self,source,...)local out=pack(original(self,source,...));Player._kascBodyCounter67.position(self,source);return unpack(out,1,out.n)end;Player._kascBodyCounterWrapped67=true end
  end
  mod.content.move_effects:patch('HEAL_EFFECT',{kascBodyCounter67=M.OWNER})
  mod.hooks:wrap('battle.damage',M.damage,31000)
  mod.hooks:wrap('battle.turn_order',M.order,-6901)
  mod.events:on('battle.turn_started',M.begin,7001)
  mod.events:on('battle.damage_dealt',M.hit,1101)
  mod.events:on('battle.turn_ended',function(ev)M.clear(ev.battle)end,-6001)
  mod.events:on('battle.battler_switched',function(ev)M.clear(ev.battle,ev.battler)end,8001)
  mod.events:on('battle.ended',function(ev)M.clear(ev.battle)end,8001)
  M.install()
  if opts.supportLog and opts.supportLog.registerSegment then opts.supportLog.registerSegment({segmentId=M.CARD_ID,
    cardId=M.CARD_ID,schema='kasc.optional-feature-card/v1',version='1.0.0',owner=M.OWNER,active=true,
    dependencyStatus='native-damage-choice-and-body-hit-receipts',providerStatus='counter-ii-7-endeavor-metal-burst-final-gambit',
    buildReceiptId='docs/BODY_COUNTER_67.md',rollbackReceiptId='docs/BODY_COUNTER_67.md'})end
  return M
end
