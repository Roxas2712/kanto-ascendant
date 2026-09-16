-- Positive active stat stages are stolen only after accuracy/immunity gates.
-- AI damage views simulate the same transfer without changing either battler.
return function(mod,opts)
  local B=require('src.battle.BattleState');local FX=require('src.battle.EffectRegistry')
  local M={CARD_ID='KASC-67-SPECTRAL-THIEF',OWNER='kasc.spectral-thief/v1',ID='SPECTRAL_THIEF'}
  local function copy(v)if type(v)~='table'then return v end;local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r end
  local function shallow(v)local r={};for k,x in pairs(v or{})do r[k]=x end;return r end
  local function pack(...)return{n=select('#',...),...}end
  function M.active(b,move)
    local r=b and b.kascGenerationRulesReceipt
    local effect=b and b.data and b.data.move_effects and b.data.move_effects.KA_SPECTRAL_THIEF_67
    return getmetatable(b)==B and not b.demo and b.kind~='link'and not b.result
      and r and r.mode~='off'and type(r.activeEpoch)=='number'and r.activeEpoch>=1 and r.activeEpoch<=7
      and move and move.id==M.ID and move.backendMoveOwner==M.OWNER
      and effect and effect.kascSpectralThief67==M.OWNER
  end
  local function keys(b)
    if b.kascGenerationRulesReceipt.activeEpoch==1 then return{'attack','defense','speed','special','accuracy','evasion'}end
    return{'attack','defense','speed','specialAttack','specialDefense','accuracy','evasion'}
  end
  function M.project(ctx)
    local b,u,t=ctx and ctx.battle,ctx and ctx.user,ctx and ctx.target
    if not M.active(b,ctx and ctx.move)or not u or not t or u==t
        or not u.mon or not t.mon or u.mon.hp<=0 or t.mon.hp<=0 or ctx.opts and ctx.opts.typeless then return ctx end
    local out=shallow(ctx);out.user=shallow(u);out.target=shallow(t)
    out.user.stages=shallow(u.stages);out.target.stages=shallow(t.stages);out.target.substituteHP=nil
    for _,key in ipairs(keys(b))do
      local amount=out.target.stages[key]or 0
      if amount>0 then
        local delta=mod.exports.pokemonAbilityEffects67.stageDelta(b,u,amount)
        out.user.stages[key]=math.max(-6,math.min(6,(out.user.stages[key]or 0)+delta))
        out.target.stages[key]=0
      end
    end
    return out
  end
  function M.steal(ctx)
    local b,u,t=ctx.battle,ctx.user,ctx.target
    local stolen={};for _,key in ipairs(keys(b))do
      local amount=t.stages and t.stages[key]or 0
      if amount>0 then stolen[#stolen+1]={key,amount}end
    end
    if #stolen==0 then return end
    b:sayNext(opts.i18n.text('Positive stat changes were stolen!','Positive Statuswerte wurden gestohlen!'))
    for _,row in ipairs(stolen)do
      -- Removing the target's boost is not an opposing stat-drop event.
      -- Clear Body/Defiant/Competitive must not block/react to this reset.
      t.stages[row[1]]=0
      for _,message in ipairs(mod.exports.backendSplitSpecial67.changeStage(ctx,u,row[1],row[2],false))do b:sayNext(message)end
    end
  end
  function M.chooseDamage(ctx)
    local b,u,t=ctx.battle,ctx.user,ctx.target
    -- The actual-hit call site has passed accuracy and ability/protection
    -- gates. Ask the existing read-only damage chain about remaining type
    -- immunity with a fixed probe RNG; do not consume a second battle roll
    -- or duplicate Foresight/Normalize/Ion/type-chart rules here.
    local _,info=b:computeDamage(u,t,ctx.move,{forceCrit=false,rng=function(lo,hi)return hi or lo end})
    if not info or info.typeMult~=0 then M.steal(ctx)end
    return b:computeDamage(u,t,ctx.move,{rng=b.rng})
  end
  mod.content.move_effects:register('KA_SPECTRAL_THIEF_67',{kind='full',kascSpectralThief67=M.OWNER,
    gate=function(ctx)
      if M.active(ctx.battle,ctx.move)then return true end
      return false,opts.i18n.text('But, it failed!','Doch es schlug fehl!')
    end,chooseDamage=M.chooseDamage})
  local f=assert(opts.facts.move(M.ID,7));assert(f.number==712 and f.type=='GHOST'and f.category=='physical'
    and f.power==90 and f.accuracy==100 and f.pp==10 and f.priority==0 and f.target==10,'Spectral Thief source drift')
  assert(not mod.content.moves:get(M.ID),'foreign Spectral Thief owner')
  mod.content.moves:register(M.ID,{id=M.ID,name=opts.i18n.text(f.names.en,f.names.de),type='GHOST',category='physical',
    power=90,accuracy=100,pp=10,priority=0,target=10,contact=true,kascBypassSub67=true,
    effect='KA_SPECTRAL_THIEF_67',originGeneration=7,backendMoveNumber=712,
    backendMoveOwner=M.OWNER,backendLearnsetRevision=27,anim=copy(assert(mod.content.moves:get('NIGHT_SHADE')).anim)})
  local anim={seq={},source=M.OWNER}
  for _,source in ipairs({'NIGHT_SHADE','SLASH'})do
    for _,row in ipairs(assert(mod.content.battle_anims:get(source)).seq)do anim.seq[#anim.seq+1]=copy(row)end
  end
  mod.content.battle_anims:register(M.ID,anim)
  mod.hooks:wrap('battle.damage',function(nextDamage,ctx)return nextDamage(M.project(ctx))end,30500)
  function M.run(original,b,ctx,record)
    if not M.active(b,ctx and ctx.move)then return original(b,ctx,record)end
    local target=ctx.target;local sub=target and target.substituteHP
    if not sub then return original(b,ctx,record)end
    target.substituteHP=nil
    local result=pack(pcall(original,b,ctx,record))
    if target.mon.hp>0 then target.substituteHP=sub end
    if not result[1]then error(result[2],0)end
    return unpack(result,2,result.n)
  end
  FX._kascSpectralThief67=M
  if not FX._kascSpectralThiefWrapped67 then local original=FX.runDamaging
    FX.runDamaging=function(...)return FX._kascSpectralThief67.run(original,...)end
    FX._kascSpectralThiefWrapped67=true
  end
  local Player=require('src.battle.AnimPlayer')
  function M.position(player,id)
    local row=player.data and player.data.moveAnims and player.data.moveAnims[id]
    if id~=M.ID or not row or row.source~=M.OWNER then return end
    for _,step in ipairs(player.steps or{})do local shift=-16;local sprites={}
      for _,s in ipairs(step.sprites or{})do
        if s.x>0 and s.x<168 and s.y>0 and s.y<160 then shift=math.max(shift,16-s.y)end
      end
      for i,s in ipairs(step.sprites or{})do local q=copy(s)
        if q.x>0 and q.x<168 and q.y>0 and q.y<160 then q.y=q.y+shift end
        if mod.exports.pokemonPartnerHits67.inHud(q)then q.x=0 end;sprites[i]=q
      end;step.sprites=sprites
    end
  end
  Player._kascSpectralThiefAnimation67=M
  if not Player._kascSpectralThiefAnimationWrapped67 then local original=Player.start
    Player.start=function(self,id,...)
      local result=original(self,id,...);Player._kascSpectralThiefAnimation67.position(self,id);return result
    end;Player._kascSpectralThiefAnimationWrapped67=true
  end
  if opts.supportLog and opts.supportLog.registerSegment then
    opts.supportLog.registerSegment({segmentId=M.CARD_ID,cardId=M.CARD_ID,schema='kasc.optional-feature-card/v1',
      version='1.0.0',owner=M.OWNER,active=true,dependencyStatus='native-hit-gates-and-shared-stat-owners',
      providerStatus='positive-stage-theft-before-damage',buildReceiptId='docs/SPECTRAL_THIEF_67.md',
      rollbackReceiptId='docs/GEN6_WAVE15_SCOPE_20260909.md'})
  end
  return M
end
