-- KASC-67-WEATHER: a single, checkpointed Gen2-7 battle weather owner.
-- Overworld rain and map backgrounds deliberately do not use this state.
return function(mod,opts)
  local Battle=require('src.battle.BattleState')
  local Status=require('src.battle.StatusRegistry')
  local Order=require('src.battle.TurnOrder')
  local M={CARD_ID='KASC-67-WEATHER',OWNER='kasc.battle-weather/v1'}
  local tr=opts.i18n.text
  local definitions={
    rain={move='RAIN_DANCE',gen=2,ability='DRIZZLE',abilityGen=3,rock='DAMP_ROCK',
      en='Rain began to fall!',de='Es beginnt zu regnen!'},
    sun={move='SUNNY_DAY',gen=2,ability='DROUGHT',abilityGen=3,rock='HEAT_ROCK',
      en='The sunlight turned harsh!',de='Die Sonne scheint grell!'},
    sand={move='SANDSTORM',gen=2,ability='SAND_STREAM',abilityGen=3,rock='SMOOTH_ROCK',
      en='A sandstorm kicked up!',de='Ein Sandsturm zieht auf!'},
    hail={move='HAIL',gen=3,ability='SNOW_WARNING',abilityGen=4,rock='ICY_ROCK',
      en='Hail began to fall!',de='Es beginnt zu hageln!'},
  }
  local abilityWeather={}
  for key,row in pairs(definitions)do
    abilityWeather[row.ability]=key
  end
  local moveNames={}
  for _,id in ipairs({'THUNDER','HURRICANE','BLIZZARD','SOLAR_BEAM','SOLAR_BLADE','WEATHER_BALL'})do
    for _,alias in ipairs(opts.species.moveIds(id))do moveNames[alias]=id end
  end
  local function copy(v)local out={};for k,x in pairs(v or {})do out[k]=x end;return out end
  local function pack(...)return {n=select('#',...),...}end
  local function alive(who)return who and who.mon and (tonumber(who.mon.hp)or 0)>0 end
  local function has(who,kind)for _,t in ipairs(who.curTypes or {})do if t==kind then return true end end end
  local function state(b)return b and b.field and b.field.tokens and b.field.tokens[M.OWNER]end
  function M.epoch(b)
    local row=b and b.data and b.data.move_effects and b.data.move_effects.HEAL_EFFECT
    local gen=row and row.kascWeatherOwner67==M.OWNER and opts.status.epoch(b)
    if getmetatable(b)==Battle and not b.result and gen and gen>=2 and gen<=7 then return gen end
  end
  function M.validateCheckpoint(b)
    local s=state(b);if s==nil then return true end
    if type(s)~='table' or not definitions[s.kind] or type(s.remaining)~='number'
        or s.remaining%1~=0 or s.remaining<0 or s.remaining>8
        or type(s.epoch)~='number' or s.epoch%1~=0 or s.epoch<2 or s.epoch>7
        or definitions[s.kind].gen>s.epoch
        or type(s.permanent)~='boolean' or s.permanent and (s.remaining~=0 or s.epoch<3 or s.epoch>5)
        or s.epoch<4 and s.remaining>5
        or not s.permanent and s.remaining<1
        or type(s.lastTurn)~='number' or s.lastTurn%1~=0 or s.lastTurn< -1
        or s.lastTurn>(b.turnCount or 0) then return false,'invalid KASC weather timeline' end
    return true
  end
  function M.current(b)
    if not M.epoch(b)then return end
    local s=state(b);if not s or not M.validateCheckpoint(b)then return end
    for _,who in ipairs({b.player,b.enemy})do
      if alive(who)then
        local id=opts.abilities.activeAbility(b,who)
        if id=='AIR_LOCK' or id=='CLOUD_NINE' then return end
      end
    end
    return s.kind
  end
  local weatherBallTypes={sun='FIRE',rain='WATER',sand='ROCK',hail='ICE'}
  local weatherBallAnimations={FIRE='KA_WEATHER_BALL_SUN',WATER='KA_WEATHER_BALL_RAIN',
    ROCK='KA_WEATHER_BALL_SAND',ICE='KA_WEATHER_BALL_HAIL'}
  local function animationCopy(v)
    if type(v)~='table'then return v end
    local out={};for k,x in pairs(v)do out[k]=animationCopy(x)end;return out
  end
  -- Keep every elemental effect above the native text box on both sides.
  -- Ember/Water Gun extend into it on the enemy turn. Fire Spin/Hydro Pump
  -- retain native elemental artwork without those overflowing trajectories.
  for kind,source in pairs({FIRE='FIRE_SPIN',WATER='HYDRO_PUMP',ROCK='ROCK_THROW',ICE='ICE_BEAM'})do
    local animation=animationCopy(assert(mod.content.battle_anims:get(source)))
    if kind=='ICE'then
      -- Use the native crystal impact, not the diagonal beam whose path
      -- crosses the HUD. Weather Ball remains a weather-dependent hit.
      local impact={}
      for _,row in ipairs(animation.seq)do
        if row.subanim==47 then row.sound=source;impact[#impact+1]=row end
      end
      assert(#impact>0,'missing native Weather Ball ice impact')
      animation.seq=impact
    end
    if kind=='ROCK'then
      local subId=670048
      while mod.content.battle_anims:get('subanim:'..subId)do subId=subId+1 end
      local sub=animationCopy(assert(mod.content.battle_anims:get('subanim:48')))
      -- Imported R/B/Y coordinates 36/40 are (104/136,64); 32/35 are
      -- the same columns at y=56. Raise only the final dust by one tile.
      for _,block in ipairs(sub.blocks)do
        if block.coord==36 then block.coord=32
        elseif block.coord==40 then block.coord=35 end
      end
      mod.content.battle_anims:register('subanim:'..subId,sub)
      for _,row in ipairs(animation.seq)do
        if row.subanim==48 then row.subanim=subId end
      end
    end
    mod.content.battle_anims:register(weatherBallAnimations[kind],animation)
  end
  M.weatherBallAnimations=weatherBallAnimations
  function M.moveDef(nextMove,b,instance,...)
    local move=nextMove(b,instance,...)
    if not move or moveNames[move.id]~='WEATHER_BALL' then return move end
    local weather=M.current(b)
    local kind=weatherBallTypes[weather]
    if not kind then return move end
    -- Resolve before the native immunity/absorption/hit pipeline, not only
    -- inside damage. Never change the shared registry or the saved move slot.
    local adjusted=copy(move)
    adjusted.type=kind;adjusted.power=(tonumber(move.power)or 50)*2
    local gen=M.epoch(b)
    adjusted.category=gen<=3 and kind=='ROCK' and 'physical' or 'special'
    adjusted.kascWeatherBall67=M.OWNER
    return adjusted
  end
  function M.weatherBallAnimation(ev)
    local b=ev and ev.battle;local move=ev and ev.move
    if not move or move.kascWeatherBall67~=M.OWNER or not M.epoch(b)then return end
    local alias=weatherBallAnimations[move.type]
    if alias and b.moveAnimRow and b.moveAnimRow.anim==move.id
        and b.data.battle_anims and b.data.battle_anims.moveAnims
        and b.data.battle_anims.moveAnims[alias]then
      -- Reuse the verified native elemental effect while keeping move text,
      -- PP, calls and history bound to Weather Ball's actual identity.
      b.moveAnimRow.anim=alias
    end
  end
  function M.supportsItem(game,id,gen)
    local row=game and game.data and game.data.items and game.data.items[id]
    return gen>=4 and gen<=7 and row and row.kascWeatherOwner67==M.OWNER or false
  end
  function M.set(b,kind,user,fromAbility)
    local gen=M.epoch(b);local def=definitions[kind]
    if not gen or not def or gen<def.gen or not alive(user)
        or user~=b.player and user~=b.enemy then return false end
    if fromAbility and gen<def.abilityGen then return false end
    local old=state(b)
    if old and old.kind==kind and not (fromAbility and gen<=5 and not old.permanent)
        and not (not fromAbility and gen==2 and kind~='sand')then return false end
    local duration=5
    if fromAbility and gen<=5 then duration=0
    elseif gen>=4 and opts.held(user.mon,b,user)==def.rock
        and M.supportsItem(b.game,def.rock,gen)then duration=8 end
    b.field=b.field or {};b.field.tokens=b.field.tokens or {}
    b.field.tokens[M.OWNER]={kind=kind,remaining=duration,permanent=duration==0,epoch=gen,lastTurn=-1}
    if fromAbility then b:sayNext(tr(def.en,def.de));b:drainNext()end
    return true
  end
  local entered=setmetatable({},{__mode='k'})
  function M.entry(ev)
    local b=ev and ev.battle;if not M.epoch(b)then return end
    -- A restored mid-battle checkpoint is not a fresh opening switch-in.
    if not ev.battler and (b.turnCount or 0)>0 then return end
    local rows=ev.battler and {ev.battler} or {b.player,b.enemy}
    if #rows==2 and not entered[rows[1]] and not entered[rows[2]] then
      local a,z=Order.effectiveSpeed(rows[1]),Order.effectiveSpeed(rows[2])
      -- Only draw a tie coin when both entry effects compete. Repeated
      -- notifications and ordinary battle starts must not consume RNG.
      local competing=abilityWeather[opts.abilities.activeAbility(b,rows[1])]
        and abilityWeather[opts.abilities.activeAbility(b,rows[2])]
      if a<z or a==z and competing and b.rng(0,1)==1 then
        rows[1],rows[2]=rows[2],rows[1]
      end
    end
    for _,who in ipairs(rows)do
      if alive(who) and (who==b.player or who==b.enemy) and not entered[who]then
        entered[who]=true
        local weather=abilityWeather[opts.abilities.activeAbility(b,who)]
        if weather then M.set(b,weather,who,true)end
      end
    end
  end
  function M.abilityChanged(b,who)
    entered[who]=nil;M.entry({battle=b,battler=who})
  end
  function M.speed(b,who,itemFactor,pendingItemLoss)
    local gen=M.epoch(b)
    local rooms=mod.exports and mod.exports.pokemonBattleRooms67
    local sideFactor=rooms and rooms.speedFactor(b,who)or 1
    if not gen or gen<=2 then return Order.effectiveSpeed(who)*sideFactor end
    -- Later profiles do not cap staged Speed at the Gen-I limit of 999.
    -- Ability/item factors precede paralysis, particularly for odd stats.
    local stage=math.max(-6,math.min(6,who.stages and who.stages.speed or 0))
    if gen==4 and alive(who) and opts.abilities.activeAbility(b,who)=='SIMPLE'then
      stage=math.max(-6,math.min(6,stage*2))
    end
    local speed=math.max(1,math.floor(who.curStats.speed*(stage>=0 and (2+stage)/2 or 2/(2-stage))))
    speed=require('src.battle.Damage').applyBadgeBoost(who,'speed',speed)
    local weather=M.current(b)
    local ability=alive(who)and opts.abilities.activeAbility(b,who)
    local quickFeet=gen>=4 and ability=='QUICK_FEET' and who.mon.status~=nil
    local abilityFactor=quickFeet and 1.5 or 1
    if opts.abilities.speedFactor then abilityFactor=abilityFactor*opts.abilities.speedFactor(b,who)end
    -- A Gem is consumed before variable power in V+. Pure previews need
    -- the resulting Unburden speed without writing a live ability token.
    if gen>=5 and pendingItemLoss and ability=='UNBURDEN'then abilityFactor=2 end
    if weather=='rain' and ability=='SWIFT_SWIM'
        or weather=='sun' and ability=='CHLOROPHYLL'
        or weather=='sand' and ability=='SAND_RUSH'
        or weather=='hail' and ability=='SLUSH_RUSH' and gen==7 then abilityFactor=2 end
    local held=mod.exports and mod.exports.pokemonHeldStats67
    local heldFactor=held and held.speedFactor(b,who)or 1
    local grounding=mod.exports and mod.exports.pokemonGrounding67
    heldFactor=heldFactor*(grounding and grounding.speedFactor(b,who)or 1)
    heldFactor=heldFactor*(itemFactor==1.5 and 1.5 or 1)
    heldFactor=heldFactor*sideFactor
    if gen>=5 then
      -- V+ chains the ability/item factor before rounding the resulting stat.
      speed=math.floor((speed*(4096*abilityFactor*heldFactor)+2047)/4096)
    else
      speed=math.floor(math.floor(speed*abilityFactor)*heldFactor)
    end
    if who.mon.status=='PAR' then
      if not quickFeet then speed=math.floor(speed/(gen>=7 and 2 or 4))end
    else speed=require('src.battle.Status').applyPenalty(who,'speed',speed)end
    return math.max(1,speed)
  end
  local activeBattle
  function M.scoped(original,b,...)
    local previous=activeBattle;activeBattle=b
    local result=pack(pcall(original,b,...));activeBattle=previous
    if not result[1]then error(result[2],0)end
    return unpack(result,2,result.n)
  end
  function M.order(nextOrder,a,am,z,zm,ctx)
    local b=activeBattle
    if not b or a~=b.player or z~=b.enemy then return nextOrder(a,am,z,zm,ctx)end
    local held=mod.exports and mod.exports.pokemonHeldStats67
    local grounding=mod.exports and mod.exports.pokemonGrounding67
    local function boosted(w)
      return alive(w)and (opts.abilities.activeAbility(b,w)=='QUICK_FEET' and w.mon.status
        or opts.abilities.speedFactor and opts.abilities.speedFactor(b,w)~=1
        or M.epoch(b)==4 and opts.abilities.activeAbility(b,w)=='SIMPLE'
        or held and held.speedFactor(b,w)~=1
        or grounding and grounding.speedFactor(b,w)~=1)
    end
    if not M.current(b)and not boosted(a)and not boosted(z)then return nextOrder(a,am,z,zm,ctx)end
    local function priority(move)
      return move and (move.priority or ({QUICK_ATTACK=1,COUNTER=-1})[move.id] or 0)or 0
    end
    -- Priority modifiers already ran; weather never overrides move priority.
    if priority(am)~=priority(zm)then return nextOrder(a,am,z,zm,ctx)end
    local rooms=mod.exports and mod.exports.pokemonBattleRooms67
    if rooms and rooms.hasOrderEffect(b)then return nextOrder(a,am,z,zm,ctx)end
    local sa,sz=M.speed(b,a),M.speed(b,z)
    if sa==Order.effectiveSpeed(a)and sz==Order.effectiveSpeed(z)then
      return nextOrder(a,am,z,zm,ctx)
    end
    if sa~=sz then return sa>sz end
    local first=(ctx.rng or b.rng)(0,1)==0
    if ctx.invertTie then first=not first end
    return first
  end
  function M.damage(nextDamage,ctx)
    local weather=ctx and M.current(ctx.battle)
    if not ctx or not ctx.move or ctx.opts and ctx.opts.typeless
        or ctx.move.category=='status' or (tonumber(ctx.move.power)or 0)<=0 then return nextDamage(ctx)end
    local dry=alive(ctx.target) and opts.abilities.activeAbility(ctx.battle,ctx.target)=='DRY_SKIN'
      and ctx.move.type=='FIRE'
    if not weather and not dry then return nextDamage(ctx)end
    local adjusted=copy(ctx);adjusted.opts=copy(ctx.opts)
    -- These modifiers belong inside the era damage calculation: Solar Power
    -- at its era's stat stage, Dry Skin before the attack/defence quotient. Never
    -- multiply already-rounded final damage or mutate a saved stat/move.
    adjusted.opts.kascDrySkin67=dry or nil
    adjusted.opts.kascSolarPower67=weather=='sun' and alive(ctx.user)
      and opts.abilities.activeAbility(ctx.battle,ctx.user)=='SOLAR_POWER' or nil
    local kind=ctx.move.type
    adjusted.opts.kascSandForce67=weather=='sand' and alive(ctx.user)
      and (kind=='GROUND' or kind=='ROCK' or kind=='STEEL')
      and opts.abilities.activeAbility(ctx.battle,ctx.user)=='SAND_FORCE' or nil
    local factor=(weather=='rain' and kind=='WATER' or weather=='sun' and kind=='FIRE') and 1.5
      or (weather=='rain' and kind=='FIRE' or weather=='sun' and kind=='WATER') and 0.5 or 1
    if moveNames[ctx.move.id]=='SOLAR_BEAM' and M.epoch(ctx.battle)==2 and weather=='rain' then
      factor=factor/2
    end
    adjusted.opts.kascWeatherFactor67=factor
    if M.epoch(ctx.battle)>=4 and weather=='sand' and has(ctx.target,'ROCK')then
      adjusted.opts.kascSandSpecialDefense67=true
    end
    return nextDamage(adjusted)
  end
  function M.solarPower(nextDamage,ctx)
    local weather=ctx and M.current(ctx.battle)
    -- A legitimately owned later-era gift retains its own move behaviour
    -- under an older manual/AUTO profile. Availability is checked by the
    -- learnset/receipt owner; the weather owner must not strip that effect.
    if weather and weather~='sun' and ctx.move
        and (M.epoch(ctx.battle)>=3 and moveNames[ctx.move.id]=='SOLAR_BEAM'
          or moveNames[ctx.move.id]=='SOLAR_BLADE') then
      local adjusted=copy(ctx);adjusted.move=copy(ctx.move)
      adjusted.move.power=math.floor(ctx.move.power/2)
      return nextDamage(adjusted)
    end
    return nextDamage(ctx)
  end
  function M.accuracy(nextAccuracy,ctx)
    local weather=ctx and M.current(ctx.battle)
    local id=ctx and ctx.move and moveNames[ctx.move.id]
    if not weather then return nextAccuracy(ctx)end
    local gen=M.epoch(ctx.battle)
    local rainMove=id=='THUNDER' or id=='HURRICANE' and gen>=5
    if rainMove and weather=='rain' or id=='BLIZZARD' and gen>=4 and weather=='hail' then
      -- Accuracy only: the native hit gate still owns invulnerability,
      -- Protect, type immunity and the actual damaging move pipeline.
      return true
    end
    if rainMove and weather=='sun' then
      local adjusted=copy(ctx);adjusted.move=copy(ctx.move);adjusted.move.accuracy=50
      return nextAccuracy(adjusted)
    end
    -- These are accuracy modifiers, not permanent evasion stages. Certain
    -- weather hits above remain certain; OHKO owns its separate level roll.
    if ctx.move and ctx.move.effect~='OHKO_EFFECT' and alive(ctx.target)
        and type(ctx.move.accuracy)=='number' then
      local ability=opts.abilities.activeAbility(ctx.battle,ctx.target)
      if weather=='sand' and ability=='SAND_VEIL'
          or weather=='hail' and ability=='SNOW_CLOAK' then
        local adjusted=copy(ctx);adjusted.move=copy(ctx.move)
        adjusted.move.accuracy=math.floor(ctx.move.accuracy*4/5)
        return nextAccuracy(adjusted)
      end
    end
    return nextAccuracy(ctx)
  end
  mod.hooks:wrap('battle.charge_required',function(nextCharge,ctx)
    if ctx and ctx.move and (moveNames[ctx.move.id]=='SOLAR_BEAM'
        or moveNames[ctx.move.id]=='SOLAR_BLADE')
        and M.current(ctx.battle)=='sun' then return false end
    return nextCharge(ctx)
  end,10000)
  -- Reuse the engine's two-turn move and charge/release animations. A
  -- registered physical attack without this effect would hit on turn one.
  for _,id in ipairs(opts.species.moveIds('SOLAR_BLADE'))do
    if mod.content.moves:get(id)then mod.content.moves:patch(id,{effect='CHARGE_EFFECT',
      chargeText=tr('%s\ngathers sunlight!','%s\nsammelt Licht!')})end
  end
  local frames={}
  function M.residualRows(b)
    local weather=M.current(b);local rows={}
    if weather~='sand' and weather~='hail' and weather~='sun' then return rows end
    for _,side in ipairs({'player','enemy'})do
      local who=b[side]
      local id=opts.abilities.activeAbility(b,who)
      if weather=='sun' then
        if alive(who) and (id=='DRY_SKIN' or id=='SOLAR_POWER')then
          local name=id=='DRY_SKIN' and tr('Dry Skin','Trockenheit') or tr('Solar Power','Solarkraft')
          rows[#rows+1]={side=side,amount=math.max(1,math.floor(who.mon.stats.hp/8)),
            message=tr('%s\nloses HP!','%s\nverliert KP!'):format(name)}
        end
      else
      local protected=weather=='sand' and (has(who,'ROCK')or has(who,'GROUND')or has(who,'STEEL'))
        or weather=='hail' and has(who,'ICE')
      if weather=='sand' and (id=='SAND_RUSH' or id=='SAND_FORCE' or id=='SAND_VEIL') then protected=true end
      if weather=='hail' and (id=='ICE_BODY' or id=='SNOW_CLOAK') then protected=true end
      if (weather=='sand' or weather=='hail') and id=='OVERCOAT' and M.epoch(b)>=5 then protected=true end
      if opts.abilities.blocksIndirect(b,who,'weather')then protected=true end
      local goggles=mod.exports.pokemonSafetyGoggles67
      if goggles and goggles.weatherShield(b,who,weather)then protected=true end
      -- Dig/Dive hide from damaging weather; Fly/Bounce do not.
      local charge=who.charging and who.charging.id
      if charge=='DIG' or charge=='DIVE' then protected=true end
      if alive(who)and not protected then
        rows[#rows+1]={side=side,amount=math.max(1,math.floor(who.mon.stats.hp/
          (M.epoch(b)==2 and 8 or 16))),message=tr('%s is hurt by the weather!',
          '%s wird vom Wetter getroffen!'):format(who.name)}
      end
      end
    end
    return rows
  end
  -- Weather recovery belongs to the same once-per-turn checkpointed pass,
  -- before poison/seed. Never implement it as a second late turn-ended heal.
  -- Gen4 Hydration runs in weather; Gen5+ runs immediately after weather,
  -- still before ordinary status damage. Both use the effective weather.
  function M.recover(b)
    local weather=M.current(b)
    local healer=mod.exports and mod.exports.pokemonHealer67
    local joint=healer and healer.hasSource(b)
    if not weather then return joint and healer.recover(b)or 0 end
    local changed=0
    for _,who in ipairs({b.player,b.enemy})do
      if alive(who) then
        local id=opts.abilities.activeAbility(b,who)
        if not joint and weather=='rain' and id=='HYDRATION' and
            ({PSN=true,BRN=true,PAR=true,SLP=true,FRZ=true})[who.mon.status] then
          who.mon.status=nil;who.toxicCounter=nil
          opts.lifecycle.clear(who) -- discard the persisted sleep counter too
          b:sayNext(tr('%s\nHydration!','%s\nHydration!'):format(who.name))
          b:drainNext();changed=changed+1
        elseif weather=='rain' and (id=='RAIN_DISH' or id=='DRY_SKIN') or weather=='hail' and id=='ICE_BODY' then
          local mon=who.mon
          local amount=math.min(mon.stats.hp-mon.hp,math.max(1,math.floor(mon.stats.hp/(id=='DRY_SKIN' and 8 or 16))))
          if amount>0 and not(mod.exports.pokemonHealBlock67 and mod.exports.pokemonHealBlock67.blocksRecovery(b,who,'ability'))then
            mon.hp=mon.hp+amount
            local name=id=='RAIN_DISH' and tr('Rain Dish','Regengenuss')
              or id=='DRY_SKIN' and tr('Dry Skin','Trockenheit') or tr('Ice Body','Eishaut')
            b:sayNext(tr('%s\nrestores HP!','%s\nheilt KP!'):format(name))
            b:drainNext(who,mon.hp);changed=changed+1
          end
        end
      end
    end
    return changed+(joint and healer.recover(b)or 0)
  end
  function M.endTurn(original,b,...)
    local s=state(b)
    local recovery=false
    if M.epoch(b)and s and s.lastTurn~=(b.turnCount or 0)then
      assert(M.validateCheckpoint(b),'invalid weather checkpoint')
      s.lastTurn=b.turnCount or 0
      if s.remaining>0 then s.remaining=s.remaining-1 end
      if s.remaining==0 and not s.permanent then
        b.field.tokens[M.OWNER]=nil
        b:sayNext(tr('The weather returned to normal.','Das Wetter normalisiert sich.'))
        b:drainNext()
      else
        frames[#frames+1]=b
        local result=pack(pcall(b.applyFieldResiduals,b))
        frames[#frames]=nil
        if not result[1]then error(result[2],0)end
        recovery=true
      end
    end
    local future=mod.exports and mod.exports.pokemonFutureStrikes67
    if future then future.beforeStatus(b)end
    if recovery then M.recover(b)end
    local healer=mod.exports and mod.exports.pokemonHealer67
    if healer then healer.recover(b)end
    local terrain=mod.exports and mod.exports.pokemonTerrain67
    if terrain then terrain.recover(b)end
    local wish=mod.exports and mod.exports.pokemonDeferredHealing67
    if wish then wish.beforeStatus(b)end
    return original(b,...)
  end
  function M.inResidualPass(b)
    local primal=mod.exports and mod.exports.pokemonPrimalWeather67
    return frames[#frames]==b or primal and primal.inResidualPass(b)or false
  end
  mod.hooks:wrap('battle.field_residual',function(nextRows,ctx)
    local b=frames[#frames]
    -- A separate native field pass places weather before Gen3+ poison/seed.
    -- Other field owners run once, in the normal end-of-turn pass afterwards.
    if b then return M.residualRows(b)end
    return nextRows(ctx)
  end,30000)
  function M.leafGuard(b,who)
    local gen=M.epoch(b)
    return gen~=nil and gen>=4 and alive(who)
      and (who==b.player or who==b.enemy) and M.current(b)=='sun'
      and opts.abilities.activeAbility(b,who)=='LEAF_GUARD' or false
  end
  function M.inflict(original,b,target,status,options,...)
    if status=='FRZ' and M.current(b)=='sun' then return {}end
    if ({SLP=true,PSN=true,PAR=true,BRN=true,FRZ=true})[status]
        and M.leafGuard(b,target)
        and not (M.epoch(b)==4 and options and options.source=='REST')then return {}end
    return original(b,target,status,options,...)
  end
  function M.rest(original,ctx)
    -- Native Rest writes HP/status directly, outside StatusRegistry.
    -- DPP permits this self-inflicted sleep; BW onward blocks the move.
    if ctx.move.id=='REST' and M.leafGuard(ctx.battle,ctx.user)
        and M.epoch(ctx.battle)>=5 then
      return {tr('But, it failed!','Doch es schlug fehl!'),failed=true}
    end
    return original(ctx)
  end
  for kind,row in pairs(definitions)do
    local effect='KA_WEATHER_'..row.move
    mod.content.move_effects:register(effect,{kind='primary',accuracyChecked=false,
      run=function(ctx)
        if M.set(ctx.battle,kind,ctx.user,false)then return {tr(row.en,row.de)}end
        return {tr('But, it failed!','Doch es schlug fehl!'),failed=true}
      end})
    for _,id in ipairs(opts.species.moveIds(row.move))do
      if mod.content.moves:get(id)then mod.content.moves:patch(id,{effect=effect})end
    end
    for i=#opts.catalog.unsupportedStatus,1,-1 do
      if opts.catalog.unsupportedStatus[i]==row.move then table.remove(opts.catalog.unsupportedStatus,i)end
    end
    local existing=mod.content.items:get(row.rock)
    local rock={id=row.rock,name=existing and existing.name or tr(row.rock:gsub('_',' '),({DAMP_ROCK='NASSBROCKEN',
      HEAT_ROCK='HEISSBROCKEN',SMOOTH_ROCK='GLATTBROCKEN',ICY_ROCK='EISBROCKEN'})[row.rock]),
      -- Pinned source/items.csv IDs 259..262: purchase cost 4000.
      -- Preserve a previously installed price rather than repricing saves.
      originGeneration=4,keyItem=false,tossable=true,needsTarget=false,
      price=existing and existing.price or 4000,
      kascWeatherOwner67=M.OWNER,kascEquipmentRewardEpochs={[4]=true,[5]=true,[6]=true,[7]=true}}
    if mod.content.items:get(row.rock)then mod.content.items:patch(row.rock,rock)
    else mod.content.items:register(row.rock,rock)end
  end
  local heal=mod.content.move_effects:get('HEAL_EFFECT').run
  mod.content.move_effects:patch('HEAL_EFFECT',{kascWeatherOwner67=M.OWNER,
    run=function(ctx)return M.rest(heal,ctx)end})
  mod.hooks:wrap('battle.damage',M.damage,-6500)
  mod.hooks:wrap('battle.damage',M.solarPower,15000)
  mod.hooks:wrap('battle.accuracy',M.accuracy,-6500)
  mod.hooks:wrap('battle.turn_order',M.order,-7000)
  mod.events:on('battle.started',M.entry,-10060)
  mod.events:on('battle.move_used',M.weatherBallAnimation,6000)
  mod.events:on('battle.battler_switched',M.entry,-10060)
  mod.events:on('battle.ended',function(ev)
    local b=ev and ev.battle;if b and b.field and b.field.tokens then b.field.tokens[M.OWNER]=nil end
  end,100)
  Battle._kascWeather67=M
  if not Battle._kascWeatherWrapped67 then
    local original=Battle.endOfTurn
    Battle.endOfTurn=function(...)return Battle._kascWeather67.endTurn(original,...)end
    local resolve=Battle.resolveTurn
    Battle.resolveTurn=function(...)return Battle._kascWeather67.scoped(resolve,...)end
    Battle._kascWeatherWrapped67=true
  end
  if not Battle._kascWeatherBallWrapped67 then
    local moveDef=Battle.moveDef
    Battle.moveDef=function(...)return Battle._kascWeather67.moveDef(moveDef,...)end
    Battle._kascWeatherBallWrapped67=true
  end
  Status._kascWeather67=M
  if not Status._kascWeatherWrapped67 then
    local original=Status.inflict
    Status.inflict=function(...)return Status._kascWeather67.inflict(original,...)end
    Status._kascWeatherWrapped67=true
  end
  if opts.supportLog and opts.supportLog.registerSegment then
    opts.supportLog.registerSegment({segmentId=M.CARD_ID,cardId=M.CARD_ID,
      schema='kasc.optional-feature-card/v1',version='1.0.0',owner=M.OWNER,active=true,
      dependencyStatus='native-battle-field-and-checkpoint',
      providerStatus='era-bound-battle-weather',
      buildReceiptId='qa/gen6-wave15-alignment-20260909/WEATHER-REVIEW.md',
      rollbackReceiptId='qa/gen6-wave15-alignment-20260909/WEATHER-REVIEW.md'})
  end
  return M
end
