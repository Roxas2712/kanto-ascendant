-- Party-side screens. Gen I's original battler flags remain native.
return function(mod,opts)
  local B=require('src.battle.BattleState')
  local M={CARD_ID='KASC-67-SCREENS',OWNER='kasc.screens/v1'}
  local names={REFLECT='reflect',LIGHT_SCREEN='lightScreen',AURORA_VEIL='auroraVeil'}
  local tr=opts.i18n.text
  local function pack(...)return {n=select('#',...),...}end
  local function copy(v)if type(v)~='table'then return v end;local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r end
  local function side(b,w)return w==b.player and'player'or w==b.enemy and'enemy'or nil end
  local function rows(b,create)
    if create then b.field=b.field or{};b.field.tokens=b.field.tokens or{}
      b.field.tokens[M.OWNER]=b.field.tokens[M.OWNER]or{}end
    return b and b.field and b.field.tokens and b.field.tokens[M.OWNER]
  end
  function M.epoch(b)
    local r=b and b.kascGenerationRulesReceipt
    local d=b and b.data and b.data.move_effects and b.data.move_effects.KA_SCREEN_67_AURORA_VEIL
    if getmetatable(b)==B and not b.demo and b.kind~='link'and not b.result
        and r and r.mode~='off'and d and d.kascScreens67==M.OWNER then return r.activeEpoch end
  end
  function M.active(b,w,id)
    local key=b and w and side(b,w);local r=rows(b);local v=r and key and r[key]and r[key][id]
    return M.epoch(b)and v and(b.turnCount or 0)>=v.applied and(b.turnCount or 0)<=v.expires or false
  end
  function M.supportsItem(game,id,gen)
    local d=game and game.data and game.data.items and game.data.items[id]
    return id=='LIGHT_CLAY'and d and d.kascScreens67==M.OWNER
      and type(gen)=='number'and gen>=4 and gen<=7 or false
  end
  function M.noUseful(b,w,move)
    if not move or not names[move.id]or not M.epoch(b)then return false end
    if M.active(b,w,move.id)then return true end
    if move.id=='AURORA_VEIL'then
      local weather=mod.exports.pokemonWeather67
      return not weather or weather.current(b)~='hail'
    end
    return w[names[move.id]]==true
  end
  function M.cast(ctx)
    local b,u,id=ctx.battle,ctx.user,ctx.move.id;local gen=M.epoch(b)
    local key=side(b,u)
    if not gen or not key or not names[id]or not u.mon or u.mon.hp<=0 then return false end
    if id~='AURORA_VEIL'and gen<2 then return false end
    if M.active(b,u,id)then return false end
    if id=='AURORA_VEIL'then
      local weather=mod.exports.pokemonWeather67
      if not weather or weather.current(b)~='hail'then return false end
    end
    local equipment=mod.exports.pokemonEquipment67
    local clay=equipment and equipment.battleHeldId(u.mon,b,u)=='LIGHT_CLAY'
      and M.supportsItem(b.game,'LIGHT_CLAY',gen)
    local turn=b.turnCount or 0;local r=rows(b,true);r[key]=r[key]or{}
    r[key][id]={applied=turn,expires=turn+(clay and 8 or 5)-1}
    if id~='AURORA_VEIL'then u[names[id]]=true end
    return true
  end
  function M.clear(b,w)
    local r=rows(b);local key=w and side(b,w)
    if not w then if r then b.field.tokens[M.OWNER]=nil end;return end
    if r and key then r[key]=nil end
    -- A real removal must not look like Infiltrator's temporary nil mask:
    -- its outer scope restores masked values only when they remain nil.
    w.reflect=false;w.lightScreen=false
  end
  function M.switched(ev)
    local b,w=ev.battle,ev.battler
    if not M.epoch(b)or M.epoch(b)<2 then return end
    for id,flag in pairs(names)do if id~='AURORA_VEIL'then
      w[flag]=M.active(b,w,id)or nil
    end end
  end
  function M.endTurn(ev)
    local b=ev.battle;local r=rows(b);if not r then return end
    for key,values in pairs(r)do for id,v in pairs(values)do
      if not M.epoch(b)or(b.turnCount or 0)>=v.expires then
        values[id]=nil
        if id~='AURORA_VEIL'and b[key]then b[key][names[id]]=nil end
        if M.epoch(b)then b:sayNext(tr('The protective screen\nwore off!','Der Schutzschild\nist verschwunden!'))end
      end
    end end
  end
  function M.validateCheckpoint(b)
    local r=rows(b);if r==nil then return true end
    if type(r)~='table'then return false,'invalid_screen_container'end
    for key,values in pairs(r)do
      if(key~='player'and key~='enemy')or type(values)~='table'then return false,'invalid_screen_side'end
      for id,v in pairs(values)do
        if not names[id]or type(v)~='table'or type(v.applied)~='number'or v.applied%1~=0
            or v.applied<0 or v.applied>(b.turnCount or 0)
            or type(v.expires)~='number'or(v.expires~=v.applied+4 and v.expires~=v.applied+7)then
          return false,'invalid_screen_timeline'
        end
        for k in pairs(v)do if k~='applied'and k~='expires'then return false,'unknown_screen_field'end end
      end
    end
    return true
  end
  function M.damage(nextDamage,ctx)
    local b,u,t,m=ctx.battle,ctx.user,ctx.target,ctx.move;local gen=M.epoch(b)
    if not gen or not u or not t or u==t or not m or m.category=='status'
        or ctx.opts and ctx.opts.typeless then return nextDamage(ctx)end
    local ability=mod.exports.pokemonAbilityEffects67
    local bypass=ability and ability.activeAbility(b,u)=='INFILTRATOR'
    local veil=not bypass and M.active(b,t,'AURORA_VEIL')
    local r=rows(b);local key=side(b,t);local owned=r and key and r[key]
    if not veil and not owned then return nextDamage(ctx)end
    local out={};for k,v in pairs(ctx)do out[k]=v end;out.opts={};for k,v in pairs(ctx.opts or{})do out.opts[k]=v end
    out.opts.kascAuroraVeil67=veil or nil
    -- Read side state even if Haze or an incoming battler cleared a native
    -- display flag. Never change actor identity in the damage hook chain.
    if gen>=2 and owned then out.opts.kascScreens67={}
      for id,flag in pairs(names)do if id~='AURORA_VEIL'then
        out.opts.kascScreens67[flag]=not bypass and(M.active(b,t,id)or t[flag]==true)or false
      end end
    end
    local damage,info=nextDamage(out)
    -- Gen I keeps its native formula. Only an explicitly active later
    -- gift screen contributes this final modifier; no native screen stacks.
    if veil and info and not info.kascAuroraVeilHandled67 and not info.crit and damage>0
        and not(m.category=='special'and t.lightScreen or m.category~='special'and t.reflect)then
      damage=math.max(1,math.floor(damage/2))
    end
    return damage,info
  end
  -- Screen-breaking hits remove protection before damage, including a
  -- Substitute hit, but never from AI damage previews or missed attempts.
  function M.breakingHit(original,b,ctx,record)
    if not M.epoch(b)or(ctx.move.id~='BRICK_BREAK'and ctx.move.id~='PSYCHIC_FANGS')then
      return original(b,ctx,record)
    end
    local raw,old=rawget(b,'accuracyRoll'),b.accuracyRoll
    b.accuracyRoll=function(self,move,u,t,...)
      local hit=old(self,move,u,t,...)
      if hit and move.id==ctx.move.id and u==ctx.user and t==ctx.target
          and require('src.battle.TypeChart').effectiveness(move.type,t.curTypes)>0 then M.clear(b,t)end
      return hit
    end
    local result=pack(pcall(original,b,ctx,record));b.accuracyRoll=raw
    if not result[1]then error(result[2],0)end;return unpack(result,2,result.n)
  end
  local FX=require('src.battle.EffectRegistry');FX._kascScreens67=M
  if not FX._kascScreensWrapped67 then local old=FX.runDamaging
    FX.runDamaging=function(...)return FX._kascScreens67.breakingHit(old,...)end
    FX._kascScreensWrapped67=true
  end
  local defog=mod.content.moves:get('DEFOG')
  if defog then
    local previous=assert(mod.content.move_effects:get(defog.effect));assert(previous.run,'Defog primary missing')
    local replacement=copy(previous)
    replacement.run=function(ctx)
      local result=previous.run(ctx)
      if M.epoch(ctx.battle)then
        local b,t=ctx.battle,ctx.target
        local removed=t.reflect or t.lightScreen or t.mist or t.safeguard
          or M.active(b,t,'REFLECT')or M.active(b,t,'LIGHT_SCREEN')or M.active(b,t,'AURORA_VEIL')
        M.clear(b,t);t.mist=false;t.safeguard=false
        if removed then
          result=result or{};result.failed=nil
          result[#result+1]=tr('The protective screens\nwere cleared!','Die Schutzschilde\nwurden entfernt!')
        end
      end
      return result
    end
    mod.content.move_effects:register('KA_SCREEN_67_DEFOG',replacement)
    mod.content.moves:patch('DEFOG',{effect='KA_SCREEN_67_DEFOG'})
  end
  for _,id in ipairs({'REFLECT','LIGHT_SCREEN','AURORA_VEIL'})do
    local effect='KA_SCREEN_67_'..id;local existing=mod.content.moves:get(id)
    local previous=existing and mod.content.move_effects:get(existing.effect)
    if id~='AURORA_VEIL'then assert(previous and previous.run,'native screen effect absent')end
    mod.content.move_effects:register(effect,{kind='primary',accuracyChecked=false,kascScreens67=M.OWNER,
      run=function(ctx)
        if id~='AURORA_VEIL'and(not M.epoch(ctx.battle)or M.epoch(ctx.battle)<2)then return previous.run(ctx)end
        if M.cast(ctx)then return {tr('A protective screen\nappeared!','Ein Schutzschild\nerscheint!')}end
        return {tr('But, it failed!','Doch es schlug fehl!'),failed=true}
      end})
    if existing then mod.content.moves:patch(id,{effect=effect})
    else
      local fact=assert(opts.facts.move(id,7))
      assert(fact.number==694 and fact.type=='ICE'and fact.category=='status'and fact.pp==20 and fact.target==4)
      mod.content.moves:register(id,{id=id,name=tr(fact.names.en,fact.names.de),type=fact.type,
        category='status',power=0,accuracy=100,pp=20,priority=0,effect=effect,
        originGeneration=7,backendMoveNumber=694,backendMoveOwner=M.OWNER,backendLearnsetRevision=12})
      mod.content.battle_anims:register(id,copy(assert(mod.content.battle_anims:get('LIGHT_SCREEN'))))
    end
  end
  -- Psychic Fangs shares the hit-owned screen removal above. It is a bite
  -- (Strong Jaw/contact owners read the pinned move traits), not a status
  -- effect and not a damage-preview mutation.
  local fang=assert(opts.facts.move('PSYCHIC_FANGS',7))
  assert(fang.number==706 and fang.type=='PSYCHIC_TYPE'and fang.category=='physical'
    and fang.power==85 and fang.accuracy==100 and fang.pp==10 and fang.target==10,
    'Psychic Fangs source drift')
  assert(not mod.content.moves:get('PSYCHIC_FANGS'),'foreign Psychic Fangs owner')
  mod.content.moves:register('PSYCHIC_FANGS',{id='PSYCHIC_FANGS',
    name=tr(fang.names.en,fang.names.de),type=fang.type,category='physical',
    power=85,accuracy=100,pp=10,priority=0,contact=true,effect='NO_ADDITIONAL_EFFECT',
    originGeneration=7,backendMoveNumber=706,backendMoveOwner=M.OWNER,
    backendLearnsetRevision=13,anim=copy(assert(mod.content.moves:get('BITE')).anim)})
  local fangAnim={seq={}}
  for _,part in ipairs({'PSYCHIC_M','BITE'})do
    local source=mod.content.battle_anims:get(part)
    if not source and part=='PSYCHIC_M'then source=mod.content.battle_anims:get('PSYCHIC')end
    for _,step in ipairs(assert(source,'Psychic Fangs animation source').seq)do
      fangAnim.seq[#fangAnim.seq+1]=copy(step)
    end
  end
  mod.content.battle_anims:register('PSYCHIC_FANGS',fangAnim)
  local clay=mod.content.items:get('LIGHT_CLAY')
  local patch={id='LIGHT_CLAY',name=clay and clay.name or tr('LIGHT CLAY','LICHTLEHM'),
    originGeneration=4,keyItem=false,tossable=true,needsTarget=false,price=clay and clay.price or 4000,
    kascScreens67=M.OWNER,kascEquipmentRewardEpochs={[4]=true,[5]=true,[6]=true,[7]=true}}
  if clay then mod.content.items:patch('LIGHT_CLAY',patch)else mod.content.items:register('LIGHT_CLAY',patch)end
  mod.hooks:wrap('battle.damage',M.damage,23000)
  mod.events:on('battle.turn_ended',M.endTurn,95)
  mod.events:on('battle.battler_switched',M.switched,8000)
  mod.events:on('battle.ended',function(ev)M.clear(ev.battle)end,95)
  if opts.supportLog and opts.supportLog.registerSegment then
    opts.supportLog.registerSegment({segmentId=M.CARD_ID,cardId=M.CARD_ID,schema='kasc.optional-feature-card/v1',
      version='1.0.0',owner=M.OWNER,active=true,dependencyStatus='weather-side-state-damage-math',
      providerStatus='timed-screens-and-light-clay',buildReceiptId='docs/SCREENS_67.md',
      rollbackReceiptId='docs/GEN6_WAVE15_SCOPE_20260909.md'})
  end
  return M
end
