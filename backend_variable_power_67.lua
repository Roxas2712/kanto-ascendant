-- Shared variable-strength formulas on detached move views. Base move data
-- and saved Pokemon are never changed by previews or a single attack.
return function(mod,opts)
  local M={CARD_ID='KASC-67-VARIABLE-POWER',OWNER='kasc.variable-power/v1'}
  local B=require('src.battle.BattleState');local Effects=require('src.battle.EffectRegistry')
  local ids={LOW_KICK=3,GRASS_KNOT=4,HEAVY_SLAM=5,HEAT_CRASH=5,
    GYRO_BALL=4,ELECTRO_BALL=5,FLAIL=2,REVERSAL=2,ERUPTION=3,WATER_SPOUT=3,BRINE=4,ACROBATICS=5,
    HEX=5,WAKE_UP_SLAP=4}
  local aliases={}
  for id in pairs(ids)do for _,alias in ipairs(opts.species.moveIds(id))do aliases[alias]=id end end
  local function copy(v)local r={};for k,x in pairs(v or{})do r[k]=x end;return r end
  function M.epoch(b)
    local r=b and b.data and b.data.move_effects and b.data.move_effects.HEAL_EFFECT
    local gen=r and r.kascVariablePower67==M.OWNER and opts.status.epoch(b)
    if getmetatable(b)==B and not b.result and gen and gen>=2 and gen<=7 then return gen end
  end
  function M.rawWeight(b,w)
    local species=opts.identity.current(b,w)
    if not species then return end
    local key=opts.binding.key(b.game,{species=species})
    key=opts.identity.formKey and opts.identity.formKey(b,w)or key
    local forms=mod.exports and mod.exports.pokemonHPForms67
    if forms and forms.canonicalKey then key=forms.canonicalKey(key)end
    local mega=mod.exports and mod.exports.backendMegaForms67
    if mega and (M.epoch(b)or 1)>=6 then
      local visual=opts.identity.visualMon(b,w)
      key=mega.abilityKey(visual)or key
    end
    local row=key and opts.catalog.entries[key]
    local kg=row and tonumber(row.weightKg)
    if not kg or kg<=0 then return end
    return math.max(1,math.floor(kg*10+0.5)),key
  end
  function M.weight(b,w)
    local hg,key=M.rawWeight(b,w);if not hg then return end
    local body=mod.exports and mod.exports.pokemonBodyUtilities67
    if body then hg=body.adjustWeight(b,w,hg,key)end
    local id=opts.abilities.activeAbility(b,w)
    if id=='HEAVY_METAL'then hg=hg*2 elseif id=='LIGHT_METAL'then hg=math.floor(hg/2)end
    return math.max(1,hg)
  end
  function M.power(b,u,t,move)
    local gen=M.epoch(b);local id=move and aliases[move.id]
    if not gen or not id or gen<ids[id] or not u or not t or u.mon.hp<=0 or t.mon.hp<=0 then return end
    if id=='HEX'then
      return move.power*((t.mon.status or opts.abilities.isAsleep(b,t))and 2 or 1)
    elseif id=='WAKE_UP_SLAP'then
      return move.power*(opts.abilities.isAsleep(b,t)and 2 or 1)
    elseif id=='ACROBATICS'then
      local held,err=opts.held(u.mon);local gems=opts.gems and opts.gems()
      local conversion=opts.conversion and opts.conversion()
      local finalMove=conversion and conversion.project(b,u,move)or move
      local empty=not err and (not held or gems and gems.emptyAfterHit(b,u,finalMove))
      return (move.power or 55)*(empty and 2 or 1)
    elseif id=='LOW_KICK'or id=='GRASS_KNOT'then
      local weight=M.weight(b,t);if not weight then return end
      return weight>=2000 and 120 or weight>=1000 and 100 or weight>=500 and 80
        or weight>=250 and 60 or weight>=100 and 40 or 20
    elseif id=='HEAVY_SLAM'or id=='HEAT_CRASH'then
      local a,z=M.weight(b,u),M.weight(b,t);if not a or not z then return end
      return a>=z*5 and 120 or a>=z*4 and 100 or a>=z*3 and 80 or a>=z*2 and 60 or 40
    elseif id=='GYRO_BALL'or id=='ELECTRO_BALL'then
      local a,z=opts.choice.speed(b,u),opts.choice.speed(b,t)
      local gems=opts.gems and opts.gems()
      local conversion=opts.conversion and opts.conversion()
      local finalMove=conversion and conversion.project(b,u,move)or move
      a=gems and gems.projectedSpeed(b,u,finalMove)or a
      if id=='GYRO_BALL'then return math.min(150,math.floor(25*z/a)+1)end
      return ({40,60,80,120,150})[math.min(4,math.floor(a/z))+1]
    elseif id=='ERUPTION'or id=='WATER_SPOUT'then
      return math.max(1,math.floor(150*u.mon.hp/u.mon.stats.hp))
    elseif id=='BRINE'then
      return (move.power or 65)*(t.mon.hp*2<=t.mon.stats.hp and 2 or 1)
    elseif id=='FLAIL'or id=='REVERSAL'then
      local ratio=math.max(1,math.floor(u.mon.hp*(gen<=4 and 64 or 48)/u.mon.stats.hp))
      local bounds=gen<=4 and {2,6,13,22,43}or{2,5,10,17,33}
      for i,v in ipairs(bounds)do if ratio<v then return ({200,150,100,80,40})[i]end end
      return 20
    end
  end
  function M.project(b,u,t,move)
    if not move or move.kascVariablePower67==M.OWNER then return move end
    local power=M.power(b,u,t,move);if not power then return move end
    local out=copy(move);out.power=power;out.kascVariablePower67=M.OWNER;return out
  end
  function M.damage(nextDamage,ctx)
    if not ctx or ctx.opts and ctx.opts.typeless then return nextDamage(ctx)end
    local move=M.project(ctx.battle,ctx.user,ctx.target,ctx.move)
    local out=copy(ctx);out.move=move
    local id=move and aliases[move.id]
    if M.epoch(ctx.battle)==2 and (id=='FLAIL'or id=='REVERSAL')then
      out.opts=copy(ctx.opts);out.opts.forceCrit=false;out.opts.kascNoVariance67=true
    end
    return nextDamage(out)
  end
  Effects._kascVariablePower67=M
  if not Effects._kascVariablePowerWrapped67 then
    local old=Effects.makeCtx
    Effects.makeCtx=function(b,u,t,...)
      local ctx=old(b,u,t,...)
      -- The inner context enables Mold Breaker's live scope first, so an
      -- ignored defensive Heavy/Light Metal cannot change target weight.
      ctx.move=Effects._kascVariablePower67.project(b,u,t,ctx.move)
      return ctx
    end
    Effects._kascVariablePowerWrapped67=true
  end
  local low=mod.content.moves:get('LOW_KICK');local effect=low and mod.content.move_effects:get(low.effect)
  if effect and effect.run then
    local old=effect.run
    mod.content.move_effects:patch(low.effect,{run=function(ctx)
      if aliases[ctx.move.id]=='LOW_KICK'and (M.epoch(ctx.battle)or 1)>=3 then return {}end
      return old(ctx)
    end})
  end
  mod.hooks:wrap('battle.damage',M.damage,29000)
  mod.content.move_effects:patch('HEAL_EFFECT',{kascVariablePower67=M.OWNER})
  if opts.supportLog and opts.supportLog.registerSegment then
    opts.supportLog.registerSegment({segmentId=M.CARD_ID,cardId=M.CARD_ID,
      schema='kasc.optional-feature-card/v1',version='1.0.0',owner=M.OWNER,active=true,
      dependencyStatus='native-damage-weight-speed',providerStatus='twelve-variable-power-formulas',
      buildReceiptId='docs/FINISH_1600_20260910.md',rollbackReceiptId='docs/FINISH_1600_20260910.md'})
  end
  return M
end
