-- Mirror Coat reflects this turn's last qualifying Special body hit.
-- The native shared lastDamage register is not a qualifying hit receipt.
return function(mod,opts)
  local B=require('src.battle.BattleState');local FX=require('src.battle.EffectRegistry')
  local TypeChart=require('src.battle.TypeChart')
  local M={CARD_ID='KASC-67-MIRROR-COAT',OWNER='kasc.mirror-coat/v1',ID='MIRROR_COAT'}
  local effect='KA_MIRROR_COAT_67';local frames=setmetatable({},{__mode='k'});local activeBattle
  local function copy(v)if type(v)~='table'then return v end;local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r end
  local function shallow(v)local r={};for k,x in pairs(v or{})do r[k]=x end;return r end
  local function pack(...)return{n=select('#',...),...}end
  local function side(b,w)
    if not b or not w then return end
    if w==b.player or b.player and w.mon==b.player.mon then return'player'end
    if w==b.enemy or b.enemy and w.mon==b.enemy.mon then return'enemy'end
  end
  local function state(b,create)
    if create then b.field=b.field or{};b.field.tokens=b.field.tokens or{}
      b.field.tokens[M.OWNER]=b.field.tokens[M.OWNER]or{turn=b.turnCount or 0,armed={}}
    end
    return b and b.field and b.field.tokens and b.field.tokens[M.OWNER]
  end
  function M.epoch(b)
    local r=b and b.kascGenerationRulesReceipt
    local marker=b and b.data and b.data.move_effects and b.data.move_effects[effect]
    if getmetatable(b)==B and not b.demo and b.kind~='link'and not b.result and r and r.mode~='off'
        and type(r.activeEpoch)=='number'and r.activeEpoch%1==0 and r.activeEpoch>=1 and r.activeEpoch<=7
        and marker and marker.kascMirrorCoat67==M.OWNER then return r.activeEpoch end
  end
  function M.active(b,move)return M.epoch(b)and move and move.id==M.ID and move.backendMoveOwner==M.OWNER or false end
  function M.clear(b)if state(b)then b.field.tokens[M.OWNER]=nil end end
  function M.begin(ev)
    local b=ev and ev.battle;if not M.epoch(b)then return end
    M.clear(b);local r=state(b,true)
    for _,key in ipairs({'player','enemy'})do
      local a=ev[key..'Action'];local move=a and b.data.moves[a.id]
      if a and not a.special and M.active(b,move)then r.armed[key]=true end
    end
  end
  function M.category(b,move)
    local gen=M.epoch(b)
    if gen<=3 then
      -- II/III Counter/Mirror Coat classify Hidden Power as Physical,
      -- irrespective of the move's actual resulting damage type.
      if move.id=='HIDDEN_POWER'then return'physical'end
      return TypeChart.category(move.type)
    end
    return move.category or TypeChart.category(move.type)
  end
  function M.hit(ev)
    local b=ev and ev.battle;local f=b and frames[b];local hit=f and f.hit
    local gen=b and M.epoch(b);local r=b and state(b);local k=ev and side(b,ev.target)
    if not gen or not r or r.turn~=(b.turnCount or 0)or not k or not hit or hit.consumed
        or hit.user~=ev.user or hit.target~=ev.target or hit.move~=ev.move or hit.damage~=ev.damage
        or not hit.direct or not side(b,ev.user)or ev.user==ev.target then return end
    hit.consumed=true
    if hit.substitute then
      -- Crystal records a real decoy strike with zero body damage, while
      -- accuracy/Protect misses do not replace lastAttackedBy.
      if gen<=2 then r[k]=nil end
      return
    end
    if M.category(b,ev.move)=='special'then
      r[k]={source=side(b,ev.user),move=ev.move.id,damage=hit.damage}
    elseif gen<=2 then
      -- Gen II uses lastAttackedBy, so a later Physical hit replaces the
      -- earlier Special opportunity. III+ retain the Special volatile.
      r[k]=nil
    end
  end
  function M.receipt(b,u,t)
    local gen=M.epoch(b);local r=state(b);local key=side(b,u);local hit=r and key and r[key]
    if not gen or not r or r.turn~=(b.turnCount or 0)or not hit or hit.source~=side(b,t)then return end
    if gen>=3 and not r.armed[key]then return end
    if gen<=2 and (not t or t.lastMove~=hit.move or hit.damage<=0)then return end
    return hit
  end
  function M.choose(ctx)
    if not M.active(ctx.battle,ctx.move)then return nil,opts.i18n.text('But, it failed!','Doch es schlug fehl!')end
    local hit=M.receipt(ctx.battle,ctx.user,ctx.target)
    if not hit then return nil,opts.i18n.text('But, it failed!','Doch es schlug fehl!')end
    -- Fixed damage ignores resistance and boosts, while actual type
    -- immunity remains. In particular, Psychic cannot hit Dark types.
    if TypeChart.effectiveness(ctx.move.type,ctx.target.curTypes)==0 then return 0,{crit=false,typeMult=0}end
    return math.min(65535,math.max(1,hit.damage*2)),{crit=false,typeMult=10}
  end
  function M.damage(nextDamage,ctx)
    if not M.active(ctx and ctx.battle,ctx and ctx.move)or ctx.opts and ctx.opts.typeless then return nextDamage(ctx)end
    local amount,info=M.choose(ctx)
    if not amount then return 0,{crit=false,typeMult=10,missed=true}end
    return amount,info
  end
  function M.run(original,b,ctx,record)
    if not M.epoch(b)or not ctx or not ctx.user or not ctx.target or ctx.user==ctx.target then return original(b,ctx,record)end
    local prior=frames[b];local f={};frames[b]=f
    local raw,previous=rawget(b,'applyDamage'),b.applyDamage
    b.applyDamage=function(self,w,amount)
      local survival=mod.exports and mod.exports.pokemonLethalHitSurvival67
      local attempted=survival and survival.incomingHit(self,w) or amount
      local direct=w==ctx.target and w.mon.hp>0 and type(attempted)=='number'and attempted>0
      local sub=direct and w.substituteHP~=nil
      local damage=previous(self,w,amount)
      if w==ctx.target then f.hit={user=ctx.user,target=w,move=ctx.move,damage=damage,direct=direct,substitute=sub}end
      return damage
    end
    local out=pack(pcall(original,b,ctx,record));b.applyDamage=raw;frames[b]=prior
    if not out[1]then error(out[2],0)end;return unpack(out,2,out.n)
  end
  function M.scoped(original,b,...)
    local old=activeBattle;activeBattle=b;local out=pack(pcall(original,b,...));activeBattle=old
    if not out[1]then error(out[2],0)end;return unpack(out,2,out.n)
  end
  function M.order(nextOrder,a,aMove,z,zMove,ctx)
    local b=activeBattle;local gen=M.epoch(b)
    if gen and a==b.player and z==b.enemy then
      if M.active(b,aMove)then aMove=shallow(aMove);aMove.priority=gen<=2 and -1 or -5 end
      if M.active(b,zMove)then zMove=shallow(zMove);zMove.priority=gen<=2 and -1 or -5 end
    end
    return nextOrder(a,aMove,z,zMove,ctx)
  end
  function M.validateCheckpoint(b)
    if frames[b]or activeBattle==b then return false,'mirror_coat_unsettled'end
    local r=state(b);if not r then return true end
    if type(r)~='table'or type(r.turn)~='number'or r.turn%1~=0 or r.turn~=(b.turnCount or 0)or type(r.armed)~='table'then
      return false,'invalid_mirror_coat_container'
    end
    for k,v in pairs(r.armed)do if(k~='player'and k~='enemy')or v~=true then return false,'invalid_mirror_coat_arm'end end
    for k,v in pairs(r)do if k~='turn'and k~='armed'then
      if(k~='player'and k~='enemy')or type(v)~='table'or(v.source~='player'and v.source~='enemy')or v.source==k
          or type(v.move)~='string'or not b.data.moves[v.move]or type(v.damage)~='number'or v.damage%1~=0 or v.damage<0 or v.damage>65535 then
        return false,'invalid_mirror_coat_receipt'
      end
      for field in pairs(v)do if field~='source'and field~='move'and field~='damage'then return false,'unknown_mirror_coat_receipt_field'end end
    end end
    return true
  end
  local f=assert(opts.facts.move(M.ID,7));assert(f.number==243 and f.type=='PSYCHIC_TYPE'and f.category=='special'
    and f.power==0 and f.accuracy==100 and f.pp==20 and f.priority==-5,'Mirror Coat source drift')
  local prior=assert(mod.content.moves:get(M.ID),'Mirror Coat catalog missing')
  assert(not prior.backendMoveOwner and prior.effect=='NO_ADDITIONAL_EFFECT','foreign Mirror Coat projection')
  mod.content.move_effects:register(effect,{kind='full',kascMirrorCoat67=M.OWNER,chooseDamage=M.choose})
  mod.content.moves:patch(M.ID,{effect=effect,backendMoveOwner=M.OWNER,backendMoveNumber=243,
    backendLearnsetRevision=prior.backendLearnsetRevision or 1,originGeneration=2,kascFixedDamage67=true,
    power=1,accuracy=100,pp=20,priority=-5,category='special',contact=false})
  local animation={seq={},source=M.OWNER}
  for _,id in ipairs({'BARRIER','PSYBEAM'})do for _,row in ipairs(assert(mod.content.battle_anims:get(id)).seq)do animation.seq[#animation.seq+1]=copy(row)end end
  mod.content.battle_anims:patch(M.ID,animation)
  local Player=require('src.battle.AnimPlayer')
  function M.position(player,id)
    local row=player.data and player.data.moveAnims and player.data.moveAnims[id]
    if id~=M.ID or not row or row.source~=M.OWNER then return end
    for _,step in ipairs(player.steps or{})do local shift=-16;local sprites={}
      for _,s in ipairs(step.sprites or{})do if s.x>0 and s.x<168 and s.y>0 and s.y<160 then shift=math.max(shift,16-s.y)end end
      for i,s in ipairs(step.sprites or{})do local q=copy(s);if q.x>0 and q.x<168 and q.y>0 and q.y<160 then q.y=q.y+shift end
        if mod.exports.pokemonPartnerHits67.inHud(q)then q.x=0 end;sprites[i]=q
      end;step.sprites=sprites
    end
  end
  Player._kascMirrorCoatAnimation67=M
  if not Player._kascMirrorCoatAnimationWrapped67 then local original=Player.start
    Player.start=function(self,id,...)local out=pack(original(self,id,...));Player._kascMirrorCoatAnimation67.position(self,id);return unpack(out,1,out.n)end
    Player._kascMirrorCoatAnimationWrapped67=true
  end
  mod.hooks:wrap('battle.damage',M.damage,12000)
  mod.hooks:wrap('battle.turn_order',M.order,1000)
  mod.events:on('battle.turn_started',M.begin,5100)
  mod.events:on('battle.damage_dealt',M.hit,1100)
  mod.events:on('battle.turn_ended',function(ev)M.clear(ev.battle)end,-5100)
  mod.events:on('battle.battler_switched',function(ev)M.clear(ev.battle)end,9000)
  mod.events:on('battle.ended',function(ev)M.clear(ev.battle)end,9000)
  function M.install()
    FX._kascMirrorCoat67=M;B._kascMirrorCoat67=M
    if not FX._kascMirrorCoatWrapped67 then local original=FX.runDamaging
      FX.runDamaging=function(...)return FX._kascMirrorCoat67.run(original,...)end;FX._kascMirrorCoatWrapped67=true
    end
    if not B._kascMirrorCoatWrapped67 then local original=B.resolveTurn
      B.resolveTurn=function(...)return B._kascMirrorCoat67.scoped(original,...)end;B._kascMirrorCoatWrapped67=true
    end
  end
  if opts.supportLog and opts.supportLog.registerSegment then opts.supportLog.registerSegment({segmentId=M.CARD_ID,cardId=M.CARD_ID,
    schema='kasc.optional-feature-card/v1',version='1.0.0',owner=M.OWNER,active=true,
    dependencyStatus='native-actual-damaging-hit-and-frozen-era',providerStatus='special-body-hit-fixed-reflection',
    buildReceiptId='docs/MIRROR_COAT_67.md',rollbackReceiptId='docs/GEN6_WAVE15_SCOPE_20260909.md'})end
  return M
end
