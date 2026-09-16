-- One real outcome per native move use. Forecasts never choose an outcome,
-- spend RNG, generate damage provenance, or heal the opponent.
return function(mod,opts)
  local B=require('src.battle.BattleState');local FX=require('src.battle.EffectRegistry')
  local Damage=assert(opts.damage,'random strength needs actual KASC damage math')
  local TypeChart=require('src.battle.TypeChart');local Player=require('src.battle.AnimPlayer')
  local M={CARD_ID='KASC-67-RANDOM-STRENGTH',OWNER='kasc.random-strength/v1',HEAL_ANIM='KA_PRESENT_HEAL_67'}
  local tr=opts.i18n.text;local aliases={};local serial=0
  local frames=setmetatable({},{__mode='k'})
  local defs={PRESENT={number=217,type='NORMAL',pp=15,accuracy=90,target=10,part='EGG_BOMB'},
    MAGNITUDE={number=222,type='GROUND',pp=30,accuracy=100,target=9,part='EARTHQUAKE'}}
  local function copy(v)if type(v)~='table'then return v end;local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r end
  local function pack(...)return{n=select('#',...),...}end
  local function id(move)return move and(aliases[move.id]or move.id)end
  local function side(b,w)return w==b.player and'player'or w==b.enemy and'enemy'or nil end
  local function live(w)
    local m=w and w.mon
    return m and type(m.hp)=='number'and m.hp>0 and not w.fainted
      and not(m.isEgg or m.is_egg or m.egg or m.eggSpecies or m.status=='EGG')
  end
  function M.epoch(b,w,move)
    local r=b and b.kascGenerationRulesReceipt
    local d=defs[id(move)];local marker=move and b and b.data and b.data.move_effects and b.data.move_effects[move.effect]
    if getmetatable(b)~=B or b.demo or b.kind=='link'or b.result or not r or r.mode=='off'
        or type(r.activeEpoch)~='number'or r.activeEpoch%1~=0 or r.activeEpoch<1 or r.activeEpoch>7
        or not d or move.backendMoveOwner~=M.OWNER or not marker or marker.kascRandomStrength67~=M.OWNER then return end
    if r.activeEpoch<2 and not(live(w)and opts.rules.monMoveAvailable
        and opts.rules.monMoveAvailable(b.game,w.mon,move.id,r.activeEpoch,true))then return end
    return math.max(2,r.activeEpoch)
  end
  function M.dig(w)
    return w and w.invulnerable and w.charging and(aliases[w.charging.id]or w.charging.id)=='DIG'
  end
  -- Integer buckets intentionally retain Crystal/Emerald byte quantization.
  -- IV+ uses the pinned simulator's exact10/100-outcome distribution.
  function M.outcome(name,gen,value)
    if name=='PRESENT'then
      if gen==2 then
        return value<=102 and{power=40}or value<=179 and{power=80}or value<=204 and{power=120}or{heal=true,power=0}
      elseif gen==3 then
        return value<102 and{power=40}or value<178 and{power=80}or value<204 and{power=120}or{heal=true,power=0}
      end
      return value<2 and{heal=true,power=0}or value<6 and{power=40}or value<9 and{power=80}or{power=120}
    elseif name=='MAGNITUDE'then
      local limits=gen==2 and{13,38,89,166,217,242,255}or{4,14,34,64,84,94,99}
      local powers={10,30,50,70,90,110,150}
      for i,limit in ipairs(limits)do if value<=limit then return{power=powers[i],magnitude=i+3}end end
    end
  end
  function M.roll(ctx,gen)
    local name=id(ctx.move);local max=name=='PRESENT'and(gen<=3 and 255 or 9)or(gen==2 and 255 or 99)
    return assert(M.outcome(name,gen,ctx.rng(0,max)),'random strength RNG outside source range')
  end
  function M.preview(b,w,move)
    local gen=M.epoch(b,w,move);if not gen or not live(w)or not side(b,w)then return end
    local name=id(move)
    if name=='PRESENT'then return gen<=3 and 51.875 or 52,{healChance=gen==2 and 51/256 or gen==3 and 52/256 or 0.2}end
    return gen==2 and 70.78125 or 71,{healChance=0}
  end
  local function fail(b,text)
    b:cancelMoveAnim();b:sayNext(text or tr('But, it failed!','Doch es schlug fehl!'))
  end
  local function critOnce(ctx)
    local critical=assert(mod.exports.backendCriticalRules67,'random strength needs actual shared critical owner')
    local source={};for k,v in pairs(ctx)do source[k]=v end;source.opts={rng=ctx.rng}
    -- Invoke only the real owner's preparation/roll, not its damage math.
    -- This preserves II Scope Lens / exclusive items / Focus Energy and
    -- real defender critical immunity without an extra variance draw.
    local result=critical.prepare(function(prepared)return prepared.opts.forceCrit end,source)
    assert(type(result)=='boolean','random strength critical owner is not ready')
    return result
  end
  local function immune(ctx)return TypeChart.effectiveness(ctx.move.type,ctx.target.curTypes or ctx.target.def.types)==0 end
  local function earlyPresent(ctx,gen)
    local b=ctx.battle;local protection=assert(mod.exports.pokemonProtection67)
    if ctx.target.invulnerable then fail(b,tr('The attack missed!','Die Attacke ging daneben!'));return false end
    if protection.blocks(ctx)then fail(b,protection.notice(ctx,true));return false end
    if not ctx.accuracyRoll()then fail(b,tr('The attack missed!','Die Attacke ging daneben!'));return false end
    -- Crystal rolls critical before its Present command. This draw occurs
    -- even on the healing branch or the subsequent Normal immunity abort.
    local crit;if gen==2 then crit=critOnce(ctx)end
    if gen==2 and immune(ctx)then fail(b,tr('It does not affect the target!','Es hat keine Wirkung!'));return false end
    return true,crit
  end
  local function healPresent(ctx,gen,checked)
    local b,u,t=ctx.battle,ctx.user,ctx.target
    local protection=assert(mod.exports.pokemonProtection67)
    if not checked then
      if t.invulnerable then return fail(b,tr('The attack missed!','Die Attacke ging daneben!'))end
      if protection.blocks(ctx)then return fail(b,protection.notice(ctx,true))end
      -- Emerald explicitly clears Normal immunity for its healing branch;
      -- Crystal and IV+ retain it. No damaging pipeline is entered to heal.
      if gen~=3 and immune(ctx)then return fail(b,tr('It does not affect the target!','Es hat keine Wirkung!'))end
      if not ctx.accuracyRoll()then return fail(b,tr('The attack missed!','Die Attacke ging daneben!'))end
    end
    local block=assert(mod.exports.pokemonHealBlock67)
    if block.blocksRecovery(b,t,'present')then return fail(b,tr('Heal Block prevents recovery!','Heilblockade verhindert die Heilung!'))end
    local maximum=t.mon.stats.hp
    local amount=gen<=4 and math.floor(maximum/4)or math.floor(maximum/4+0.5)
    if gen<=3 then amount=math.max(1,amount)end
    if t.mon.hp>=maximum or amount<=0 then return fail(b,tr('No HP recovery was needed!','Es war keine KP-Heilung nötig!'))end
    local healer=assert(mod.exports.pokemonHealingMoves67)
    assert(healer.recoveryCause67==true,'Present needs actual shared recovery-cause API')
    if b.moveAnimRow then b.moveAnimRow.anim=M.HEAL_ANIM end
    for _,message in ipairs(healer.heal(ctx,t,amount,'present'))do b:sayNext(message)end
  end
  function M.perform(ctx)
    local b,u,t,move=ctx.battle,ctx.user,ctx.target,ctx.move;local gen=M.epoch(b,u,move)
    if not gen or not live(u)or not live(t)or u==t or not side(b,u)or not side(b,t)then return fail(b)end
    local name=id(move);local checked,crit=false,nil
    if name=='PRESENT'and gen<=3 then
      checked,crit=earlyPresent(ctx,gen);if not checked then return end
    elseif name=='MAGNITUDE'and gen==2 then crit=critOnce(ctx)end
    local selected=M.roll(ctx,gen);serial=serial+1
    local view=copy(move);view.power=selected.power;view.kascRandomStrength67=M.OWNER;view.kascRandomStrengthNonce67=serial
    local previous=frames[b]
    frames[b]={nonce=serial,name=name,user=u,target=t,crit=crit,heal=selected.heal,gen=gen,
      dig=name=='MAGNITUDE'and t.charging and(aliases[t.charging.id]or t.charging.id)=='DIG'and t.invulnerable~=nil}
    local out=pack(pcall(function()
      local actual=FX.makeCtx(b,u,t,view,ctx.moveInst,ctx.isCalled)
      if name=='MAGNITUDE'then b:sayNext(tr('Magnitude %d!','Intensität %d!'):format(selected.magnitude))end
      if selected.heal then return healPresent(actual,gen,checked)end
      local record=copy(assert(b.data.move_effects[move.effect]));record.perform=nil
      -- A projected damaging branch remains ordinary native FX, so Gems,
      -- Body/Counter, Parental Bond and contact effects see actual damage.
      if checked then record.neverMiss=true end
      local charge,invulnerable,mon=t.charging,t.invulnerable,t.mon
      local underground=name=='MAGNITUDE'and M.dig(t)
      if underground then t.invulnerable=nil end
      local result=pack(pcall(FX.runDamaging,b,actual,record))
      if underground and t.mon==mon and live(t)and t.charging==charge and t.invulnerable==nil then t.invulnerable=invulnerable end
      if not result[1]then error(result[2],0)end
      return unpack(result,2,result.n)
    end));frames[b]=previous
    if not out[1]then error(out[2],0)end
    return unpack(out,2,out.n)
  end
  function M.damage(nextDamage,ctx)
    if not ctx or ctx.opts and(ctx.opts.typeless or ctx.opts.typelessDamage)then return nextDamage(ctx)end
    local b,u,t,move=ctx.battle,ctx.user,ctx.target,ctx.move
    local gen=M.epoch(b,u,move);if not gen or not live(u)or not side(b,u)then return nextDamage(ctx)end
    local f=frames[b]
    local actual=f and f.user==u and f.target==t and id(move)==f.name
      and move.kascRandomStrength67==M.OWNER and move.kascRandomStrengthNonce67==f.nonce
    if actual and f.heal then return 0,{crit=false,typeMult=10}end
    local out={};for k,v in pairs(ctx)do out[k]=v end;out.opts=copy(ctx.opts or{})
    if actual then if f.crit~=nil then out.opts.forceCrit=f.crit end
    else
      out.move=copy(move);out.move.power=assert(M.preview(b,u,move))
      out.opts.forceCrit=false;out.opts.rng=function(_,hi)return hi end
    end
    -- During the actual FX scope invulnerability is temporarily masked, so
    -- retain Dig's canonical charging instance as the authoritative receipt.
    if id(move)=='MAGNITUDE'and(actual and f.dig or not actual and M.dig(t))then
      assert(Damage.kascRandomStrength67==M.OWNER,'Magnitude needs actual shared Dig-final-modifier API')
      out.opts.kascMagnitudeDig67=true
    end
    return nextDamage(out)
  end
  function M.noUseful(b,u,t,move)
    if not M.epoch(b,u,move)then return false end
    if not live(u)or not live(t)or u==t or not side(b,u)or not side(b,t)then return true end
    local A=mod.exports.pokemonAbilityEffects67
    if t.invulnerable and not(id(move)=='MAGNITUDE'and M.dig(t))
        and not(A and(A.activeAbility(b,u)=='NO_GUARD'or A.activeAbility(b,t)=='NO_GUARD'))then return true end
    local grounding=mod.exports.pokemonGrounding67
    if id(move)=='MAGNITUDE'and grounding and grounding.blocksGround(b,u,t,move)then return true end
    if id(move)=='MAGNITUDE'and grounding then
      return grounding.scope(b,u,t,move,function()return immune({move=move,target=t})end)
    end
    return immune({move=move,target=t})
  end
  function M.validateCheckpoint(b)return frames[b]==nil,'random_strength_move_unsettled'end
  for _,name in ipairs({'PRESENT','MAGNITUDE'})do
    local d=defs[name];local fact=assert(opts.facts.move(name,2));local old=assert(mod.content.moves:get(name))
    assert(fact.number==d.number and fact.generation==2 and fact.type==d.type and fact.category=='physical'
      and fact.power==0 and fact.accuracy==d.accuracy and fact.pp==d.pp and fact.priority==0 and fact.target==d.target,
      'random strength source drift '..name)
    assert(not old.backendMoveOwner and old.effect=='NO_ADDITIONAL_EFFECT','foreign random strength owner '..name)
    local effect='KA_RANDOM_STRENGTH_67_'..name
    mod.content.move_effects:register(effect,{kind='full',perform=M.perform,kascRandomStrength67=M.OWNER,
      gate=function(ctx)
        if M.epoch(ctx.battle,ctx.user,ctx.move)then return true end
        return false,tr('But, it failed!','Doch es schlug fehl!')
      end})
    for _,alias in ipairs(opts.species.moveIds(name))do if mod.content.moves:get(alias)then
      aliases[alias]=name
      mod.content.moves:patch(alias,{effect=effect,backendMoveOwner=M.OWNER,
        backendLearnsetRevision=old.backendLearnsetRevision or 1,originGeneration=2,backendMoveNumber=d.number,
        power=1,pp=d.pp,accuracy=d.accuracy,target=d.target,contact=false,anim=copy(assert(mod.content.moves:get(d.part)).anim)})
    end end;aliases[name]=name
    local animation=copy(assert(mod.content.battle_anims:get(d.part)));animation.source=M.OWNER
    if mod.content.battle_anims:get(name)then mod.content.battle_anims:patch(name,animation)
    else mod.content.battle_anims:register(name,animation)end
  end
  aliases.DIG='DIG'
  for _,alias in ipairs(opts.species.moveIds('DIG'))do aliases[alias]='DIG'end
  local heal=copy(assert(mod.content.battle_anims:get('RECOVER')));heal.source=M.OWNER
  mod.content.battle_anims:register(M.HEAL_ANIM,heal)
  local hud={{0,0,88,30},{72,56,160,94},{0,98,160,144}}
  function M.position(player,name)
    local row=player.data and player.data.moveAnims and player.data.moveAnims[name]
    if not(defs[name]or name==M.HEAL_ANIM)or not row or row.source~=M.OWNER then return end
    for _,step in ipairs(player.steps or{})do local sprites={};local shift=-16
      for _,s in ipairs(step.sprites or{})do if s.x>0 and s.x<168 and s.y>0 and s.y<160 then shift=math.max(shift,16-s.y)end end
      for i,s in ipairs(step.sprites or{})do local q=copy(s)
        if q.x>0 and q.x<168 and q.y>0 and q.y<160 then q.y=q.y+shift end
        local x,y=q.x-8,q.y-16
        for _,box in ipairs(hud)do if x<box[3]and x+8>box[1]and y<box[4]and y+8>box[2]then q.x=0;break end end
        sprites[i]=q
      end;step.sprites=sprites
    end
  end
  function M.install()
    Player._kascRandomStrength67=M
    if not Player._kascRandomStrengthWrapped67 then local start=Player.start
      Player.start=function(self,name,...)local out=pack(start(self,name,...));Player._kascRandomStrength67.position(self,name);return unpack(out,1,out.n)end
      Player._kascRandomStrengthWrapped67=true
    end
  end
  M.install();mod.hooks:wrap('battle.damage',M.damage,31530)
  mod.events:on('battle.ended',function(ev)if ev and ev.battle then frames[ev.battle]=nil end end,80)
  if opts.supportLog and opts.supportLog.registerSegment then opts.supportLog.registerSegment({
    segmentId=M.CARD_ID,cardId=M.CARD_ID,schema='kasc.optional-feature-card/v1',version='1.0.0',owner=M.OWNER,
    active=true,dependencyStatus='native-rng-fx-shared-healing-and-dig-math',providerStatus='one-era-correct-random-outcome-per-native-use',
    buildReceiptId='docs/RANDOM_STRENGTH_67.md',rollbackReceiptId='docs/RANDOM_STRENGTH_67.md'})end
  return M
end
