-- Extreme weather is battle-only; map skyboxes and volcano margins stay separate.
return function(mod,opts)
  local B=require('src.battle.BattleState');local FX=require('src.battle.EffectRegistry')
  local Chart=require('src.battle.TypeChart');local W=assert(opts.weather)
  local M={CARD_ID='KASC-67-PRIMAL-WEATHER',OWNER='kasc.primal-weather/v1'}
  local defs={PRIMORDIAL_SEA={kind='sea',weather='rain',en='Heavy rain began!',de='Starker Regen setzt ein!'},
    DESOLATE_LAND={kind='land',weather='sun',en='Extremely harsh sunlight!',de='Die Sonne scheint extrem grell!'},
    DELTA_STREAM={kind='stream',en='Strong winds began!',de='Starke Winde ziehen auf!'}}
  local byKind={};for id,row in pairs(defs)do row.id=id;byKind[row.kind]=row end
  local entered=setmetatable({},{__mode='k'});local frames={}
  local function pack(...)return{n=select('#',...),...}end
  local function alive(w)return w and w.mon and (tonumber(w.mon.hp)or 0)>0 end
  local function side(b,w)return w==b.player and'player'or w==b.enemy and'enemy'or nil end
  local function state(b)return b and b.field and b.field.tokens and b.field.tokens[M.OWNER]end
  function M.epoch(b)
    local r=b and b.kascGenerationRulesReceipt
    local h=b and b.data and b.data.move_effects and b.data.move_effects.HEAL_EFFECT
    local gen=r and r.mode~='off'and r.activeEpoch
    return getmetatable(b)==B and not b.demo and b.kind~='link'and not b.result
      and h and h.kascPrimalWeather67==M.OWNER and type(gen)=='number'and gen%1==0
      and gen>=6 and gen<=7 and gen or nil
  end
  function M.supportsAbility(game,id,gen)
    local h=game and game.data and game.data.move_effects and game.data.move_effects.HEAL_EFFECT
    return defs[id]and type(gen)=='number'and gen%1==0 and gen>=6 and gen<=7 and h
      and h.kascAbilityOwner67=='kasc.ability-effects/v1'
      and h.kascWeatherOwner67==W.OWNER and h.kascPrimalWeather67==M.OWNER or false
  end
  function M.validateCheckpoint(b)
    local s=state(b);if s==nil then return true end
    if type(s)~='table'or not byKind[s.kind]or(s.source~='player'and s.source~='enemy')
        or type(s.species)~='string'or not b[s.source]or b[s.source].mon.species~=s.species
        or type(s.epoch)~='number'or s.epoch%1~=0 or s.epoch<6 or s.epoch>7
        or type(s.lastTurn)~='number'or s.lastTurn%1~=0 or s.lastTurn< -1
        or s.lastTurn>(b.turnCount or 0)then return false,'invalid_primal_weather'end
    for k in pairs(s)do
      if k~='kind'and k~='source'and k~='species'and k~='epoch'and k~='lastTurn'then
        return false,'unknown_primal_weather_field'
      end
    end
    return true
  end
  function M.raw(b)
    local s=state(b)
    if not M.epoch(b)or not s or not M.validateCheckpoint(b)then return end
    local w=b[s.source]
    if alive(w)and opts.abilities.activeAbility(b,w)==byKind[s.kind].id then return s.kind end
  end
  function M.current(b)
    local kind=M.raw(b);if not kind then return end
    for _,w in ipairs({b.player,b.enemy})do
      local id=alive(w)and opts.abilities.activeAbility(b,w)
      if id=='AIR_LOCK'or id=='CLOUD_NINE'then return end
    end
    return kind
  end
  function M.normalized(b)local kind=M.current(b);return kind and byKind[kind].weather end
  function M.forbidden(b,move)
    local kind=M.current(b)
    return move and move.category~='status'and(kind=='sea'and move.type=='FIRE'
      or kind=='land'and move.type=='WATER')or false
  end
  function M.set(b,w)
    local gen=M.epoch(b);local id=gen and alive(w)and side(b,w)and opts.abilities.activeAbility(b,w)
    local d=defs[id];if not d then return false end
    b.field=b.field or{};b.field.tokens=b.field.tokens or{}
    local old=state(b)
    -- Replacing extreme weather discards the old weather, not suspends it.
    b.field.tokens[W.OWNER]=nil
    b.field.tokens[M.OWNER]={kind=d.kind,source=side(b,w),species=w.mon.species,epoch=gen,
      lastTurn=old and old.lastTurn or -1}
    if not old or old.kind~=d.kind then b:sayNext(opts.i18n.text(d.en,d.de));b:drainNext()end
    return true
  end
  function M.sync(b)
    local s=state(b);if not M.epoch(b)or not s or M.raw(b)then return end
    -- Leaving/losing the weather ability can transfer its source only to a
    -- surviving holder of THE SAME weather. An earlier different weather
    -- source does not spontaneously start its old weather again.
    local d=byKind[s.kind]
    if d then for _,w in ipairs({b.player,b.enemy})do
      if alive(w)and opts.abilities.activeAbility(b,w)==d.id then
        s.source=side(b,w);s.species=w.mon.species;return
      end
    end end
    b.field.tokens[M.OWNER]=nil
    b:sayNext(opts.i18n.text('The extreme weather ended.','Das Extremwetter endet.'));b:drainNext()
  end
  function M.entry(ev)
    local b=ev and ev.battle;if not M.epoch(b)then return end
    M.sync(b)
    if not ev.battler and (b.turnCount or 0)>0 then return end
    local rows=ev.battler and{ev.battler}or{b.player,b.enemy}
    if #rows==2 and not entered[rows[1]]and not entered[rows[2]]then
      local a,z=W.speed(b,rows[1]),W.speed(b,rows[2])
      local competing=defs[opts.abilities.activeAbility(b,rows[1])]
        and defs[opts.abilities.activeAbility(b,rows[2])]
      if a<z or a==z and competing and b.rng(0,1)==1 then rows[1],rows[2]=rows[2],rows[1]end
    end
    for _,w in ipairs(rows)do if alive(w)and not entered[w]then entered[w]=true;M.set(b,w)end end
  end
  function M.abilityChanged(b,w)entered[w]=nil;M.sync(b);M.entry({battle=b,battler=w})end
  function M.endTurn(original,b,...)
    M.sync(b);local s=state(b)
    if M.raw(b)and s.lastTurn~=(b.turnCount or 0)then
      s.lastTurn=b.turnCount or 0
      frames[#frames+1]=b;local out=pack(pcall(b.applyFieldResiduals,b));frames[#frames]=nil
      if not out[1]then error(out[2],0)end
      local future=mod.exports and mod.exports.pokemonFutureStrikes67
      if future then future.beforeStatus(b)end
      W.recover(b)
      local wish=mod.exports and mod.exports.pokemonDeferredHealing67
      if wish then wish.beforeStatus(b)end
    end
    return original(b,...)
  end
  function M.inResidualPass(b)return frames[#frames]==b end
  local function sameTypes(a,z)
    if type(a)~='table'or type(z)~='table'or #a~=#z then return false end
    for i,t in ipairs(a)do if z[i]~=t then return false end end;return true
  end
  local chartFrames={}
  function M.chartActive(kind,types)
    local f=chartFrames[#chartFrames];if not f or kind~=f.kind or not sameTypes(types,f.types)then return end
    for _,t in ipairs(types)do if t=='FLYING'then return true end end
  end
  function M.damage(nextDamage,ctx)
    local b=ctx and ctx.battle;local move=ctx and ctx.move
    if M.forbidden(b,move)then return 0,{crit=false,typeMult=10,kascPrimalWeather67=M.OWNER}end
    if M.current(b)~='stream'or not move or move.category=='status'or ctx.opts and ctx.opts.typeless
        or not ctx.target or not ctx.target.curTypes then return nextDamage(ctx)end
    -- Scope only this calculation. Never rewrite the world's type chart or
    -- a saved species' Flying type. Other dual-type weaknesses remain.
    chartFrames[#chartFrames+1]={kind=move.type,types=ctx.target.curTypes}
    local result=pack(pcall(nextDamage,ctx));chartFrames[#chartFrames]=nil
    if not result[1]then error(result[2],0)end;return unpack(result,2,result.n)
  end
  function M.run(original,b,ctx,record)
    M.sync(b)
    if M.forbidden(b,ctx and ctx.move)then
      b:cancelMoveAnim();b:sayNext(opts.i18n.text('The extreme weather\nstopped the move!',
        'Das Extremwetter\nverhindert die Attacke!'));return
    end
    return original(b,ctx,record)
  end
  function M.install()
    FX._kascPrimalWeather67=M
    if not FX._kascPrimalWeatherWrapped67 then local original=FX.runDamaging
      FX.runDamaging=function(...)return FX._kascPrimalWeather67.run(original,...)end
      FX._kascPrimalWeatherWrapped67=true
    end
  end
  -- Composable adapters retain the existing weather owner and its native
  -- accuracy/charge/recovery/type-rounding pipelines.
  W._kascPrimal67=M
  if not W._kascPrimalWrapped67 then
    local current,set,changed,endTurn=W.current,W.set,W.abilityChanged,W.endTurn
    W.current=function(b,...)
      local owner=W._kascPrimal67
      if owner.epoch(b)and state(b)then return owner.normalized(b)end
      return current(b,...)
    end
    W.set=function(b,...)if W._kascPrimal67.raw(b)then return false end;return set(b,...)end
    W.abilityChanged=function(b,w,...)
      W._kascPrimal67.abilityChanged(b,w);return changed(b,w,...)
    end
    W.endTurn=function(original,b,...)
      return W._kascPrimal67.endTurn(function(x,...)return endTurn(original,x,...)end,b,...)
    end
    W._kascPrimalWrapped67=true
  end
  Chart._kascPrimal67=M
  if not Chart._kascPrimalWrapped67 then
    local rows,effectiveness=Chart.rows,Chart.effectiveness
    Chart.rows=function(kind,types,...)
      local result=rows(kind,types,...)
      if Chart._kascPrimal67.chartActive(kind,types)and effectiveness(kind,{'FLYING'})>10 then
        for i,value in ipairs(result)do if value==20 then result[i]=10;break end end
      end
      return result
    end
    Chart.effectiveness=function(kind,types,...)
      local result=effectiveness(kind,types,...)
      if Chart._kascPrimal67.chartActive(kind,types)and effectiveness(kind,{'FLYING'})>10 then
        result=math.floor(result/2)
      end
      return result
    end
    Chart._kascPrimalWrapped67=true
  end
  mod.content.move_effects:patch('HEAL_EFFECT',{kascPrimalWeather67=M.OWNER})
  mod.hooks:wrap('battle.damage',M.damage,45000)
  mod.hooks:wrap('battle.field_residual',function(nextRows,ctx)
    local b=frames[#frames];if b then return W.residualRows(b)end;return nextRows(ctx)
  end,45000)
  -- Normal entry weather has run first. Extreme weather wins regardless of
  -- the ordinary weather source's Speed; competing extremes run in Speed order.
  mod.events:on('battle.started',M.entry,-10061)
  mod.events:on('battle.battler_switched',M.entry,-10061)
  mod.events:on('battle.move_used',function(ev)M.sync(ev.battle)end,14000)
  mod.events:on('battle.ended',function(ev)
    if state(ev.battle)then ev.battle.field.tokens[M.OWNER]=nil end
  end,101)
  if opts.supportLog and opts.supportLog.registerSegment then opts.supportLog.registerSegment({
    segmentId=M.CARD_ID,cardId=M.CARD_ID,schema='kasc.optional-feature-card/v1',version='1.0.0',
    owner=M.OWNER,active=true,dependencyStatus='native-weather-hit-type-chart-and-checkpoint',
    providerStatus='gen-vi-vii-extreme-weather',buildReceiptId='docs/PRIMAL_WEATHER_67.md',
    rollbackReceiptId='docs/GEN6_WAVE15_SCOPE_20260909.md'})end
  return M
end
