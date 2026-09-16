-- Targeted healing and temporary Roost types on the existing move pipeline.
-- No replacement menu, no saved-species/type changes.
return function(mod,opts)
  local B=require('src.battle.BattleState')
  local M={OWNER='kasc.healing-moves/v1',CARD_ID='KASC-67-HEALING-MOVES',recoveryCause67=true}
  local tr=opts.i18n.text
  local custom={HEAL_PULSE=true,FLORAL_HEALING=true,PURIFY=true,ROOST=true,
    SHORE_UP=true,MORNING_SUN=true,SYNTHESIS=true,MOONLIGHT=true}
  local aliases={}
  for id in pairs(opts.facts.data.moves)do
    for _,a in ipairs(opts.species.moveIds(id))do aliases[a]=id end
  end
  local function copy(v)local r={};for k,x in pairs(v or{})do r[k]=x end;return r end
  local function rows(b,create)
    if create then b.field=b.field or{};b.field.tokens=b.field.tokens or{}
      b.field.tokens[M.OWNER]=b.field.tokens[M.OWNER]or{}end
    return b and b.field and b.field.tokens and b.field.tokens[M.OWNER]
  end
  local function side(b,w)return w==b.player and 'player'or w==b.enemy and 'enemy'or nil end
  function M.epoch(b)
    local r=b and b.data and b.data.move_effects and b.data.move_effects.HEAL_EFFECT
    local gen=r and r.kascHealingMoves67==M.OWNER and opts.status.epoch(b)
    if getmetatable(b)==B and not b.result and gen and gen>=3 and gen<=7 then return gen end
  end
  local function failed()return {tr('But, it failed!','Doch es schlug fehl!'),failed=true}end
  function M.heal(ctx,w,amount,cause)
    local block=mod.exports.pokemonHealBlock67
    if block and block.blocksRecovery(ctx.battle,w,cause or'move')then return failed()end
    if w.mon.hp<=0 or w.mon.hp>=w.mon.stats.hp then return failed()end
    w.mon.hp=math.min(w.mon.stats.hp,w.mon.hp+math.max(1,amount));ctx.drain()
    return {tr('%s regained HP!','%s hat KP zurückerhalten!'):format(w.name)}
  end
  function M.cast(original,ctx)
    local b,u,t=ctx.battle,ctx.user,ctx.target;local gen=M.epoch(b)
    local id=aliases[ctx.move.id]or ctx.move.id
    local block=mod.exports.pokemonHealBlock67
    if block and block.moveBlocked(b,u,ctx.move,t)then return failed()end
    if not gen or id=='REST'then return original(ctx)end
    if custom[id]and opts.priority.blocks(ctx)then return failed()end
    local facts=opts.facts.move(id,gen);local healing=facts and facts.meta and facts.meta.healing
    if not custom[id]then
      if not healing or healing<=0 or facts.target~=7 or id=='SWALLOW'then return original(ctx)end
      local amount=u.mon.stats.hp*healing/100
      return M.heal(ctx,u,gen<=4 and math.floor(amount)or math.floor(amount+0.5))
    end
    local target=(id=='HEAL_PULSE'or id=='FLORAL_HEALING')and t or u
    if (id=='HEAL_PULSE'or id=='FLORAL_HEALING'or id=='PURIFY')
        and (u==t or t.substituteHP or t.mon.hp<=0)then return failed()end
    if id=='PURIFY'then
      if not t.mon.status then return failed()end
      t.mon.status=nil;t.toxicCounter=nil;opts.lifecycle.clear(t,b)
      if u.mon.hp>=u.mon.stats.hp then return {tr('The status was cured!','Die Statusveränderung wurde geheilt!')}end
    end
    local amount=math.ceil(target.mon.stats.hp/2)
    if id=='HEAL_PULSE'and opts.abilities.activeAbility(b,u)=='MEGA_LAUNCHER'then
      amount=math.floor((target.mon.stats.hp*3072+2047)/4096)
    elseif id=='FLORAL_HEALING'then
      local terrain=mod.exports and mod.exports.pokemonTerrain67
      if terrain and terrain.current(b)=='grassy'then amount=math.floor((target.mon.stats.hp*2732+2047)/4096)end
    elseif id=='SHORE_UP'or id=='MORNING_SUN'or id=='SYNTHESIS'or id=='MOONLIGHT'then
      local weather=opts.weather.current(b);local factor=2048
      if id=='SHORE_UP'then if weather=='sand'then factor=2732 end
      elseif weather=='sun'then factor=2732
      elseif weather then factor=1024 end
      amount=math.floor((target.mon.stats.hp*factor+2047)/4096)
    elseif id=='ROOST'then amount=gen<=4 and math.floor(u.mon.stats.hp/2)or math.ceil(u.mon.stats.hp/2)end
    local result=M.heal(ctx,target,amount)
    if id=='ROOST'and not result.failed then
      local key=side(b,u);local out={};local flying=false
      for _,typ in ipairs(u.curTypes or{})do if typ=='FLYING'then flying=true else out[#out+1]=typ end end
      if flying and key then
        if #out==0 then out={'NORMAL'}end
        rows(b,true)[key]={original=copy(u.curTypes),applied=out}
        u.curTypes=copy(out)
      end
    end
    return result
  end
  function M.restore(ev)
    local b=ev.battle;local r=rows(b);if not r then return end
    for key,v in pairs(r)do
      local w=b[key];local same=w and #w.curTypes==#v.applied
      for i,typ in ipairs(v.applied)do if not w or w.curTypes[i]~=typ then same=false end end
      if same then w.curTypes=copy(v.original)end
    end
    b.field.tokens[M.OWNER]=nil
  end
  function M.typesForTransform(b,w)
    local r=rows(b);local v=r and r[side(b,w)]
    if v and #w.curTypes==#v.applied then
      local same=true
      for i,typ in ipairs(v.applied)do if w.curTypes[i]~=typ then same=false end end
      if same then return copy(v.original)end
    end
    return copy(w.curTypes)
  end
  function M.roostActive(b,w)
    local r=rows(b);return r and r[side(b,w)]~=nil or false
  end
  function M.validateCheckpoint(b)
    local r=rows(b);if not r then return true end
    if type(r)~='table'then return false,'invalid_roost_container'end
    local types={NORMAL=true,FIRE=true,WATER=true,ELECTRIC=true,GRASS=true,ICE=true,FIGHTING=true,POISON=true,
      GROUND=true,FLYING=true,PSYCHIC=true,PSYCHIC_TYPE=true,BUG=true,ROCK=true,GHOST=true,DRAGON=true,DARK=true,STEEL=true,FAIRY=true,['???']=true}
    for key,v in pairs(r)do
      if (key~='player'and key~='enemy')or type(v)~='table'then return false,'invalid_roost_side'end
      local changing=mod.exports.pokemonTypeChanges67
      local addition=changing and changing.added(b,b[key])
      local limit=addition and 3 or 2
      for field,list in pairs(v)do
        if (field~='original'and field~='applied')or type(list)~='table'or #list<1 or #list>limit then return false,'invalid_roost_types'end
        for i,typ in pairs(list)do if type(i)~='number'or i%1~=0 or i<1 or i>#list or not types[typ]then return false,'invalid_roost_type'end end
      end
      if not v.original or not v.applied then return false,'missing_roost_types'end
    end
    return true
  end
  local old=assert(mod.content.move_effects:get('HEAL_EFFECT').run)
  mod.content.move_effects:patch('HEAL_EFFECT',{kascHealingMoves67=M.OWNER,run=function(ctx)return M.cast(old,ctx)end})
  local function deep(v)
    if type(v)~='table'then return v end
    local r={};for k,x in pairs(v)do r[k]=deep(x)end;return r
  end
  for id in pairs(custom)do
    local effect='KA_HEALING_67_'..id
    mod.content.move_effects:register(effect,{kind='primary',accuracyChecked=true,run=function(ctx)return M.cast(old,ctx)end})
    if not mod.content.moves:get(id)then
      local r=assert(opts.facts.move(id,7));assert(r.category=='status'and r.generation<=7)
      local base=assert(mod.content.moves:get('RECOVER'))
      mod.content.battle_anims:register(id,deep(assert(mod.content.battle_anims:get('RECOVER'))))
      mod.content.moves:register(id,{id=id,name=tr(r.names.en,r.names.de),type=r.type,
        category='status',power=0,accuracy=r.accuracy or 100,pp=r.pp,priority=r.priority,
        effect=effect,anim=deep(base.anim),originGeneration=r.generation,
        backendMoveOwner=M.OWNER,backendMoveNumber=r.number,backendLearnsetRevision=2})
      aliases[id]=id
    end
    for _,alias in ipairs(opts.species.moveIds(id))do if mod.content.moves:get(alias)then mod.content.moves:patch(alias,{effect=effect})end end
  end
  mod.events:on('battle.turn_ended',M.restore,80)
  mod.events:on('battle.battler_switched',function(ev)
    local r=rows(ev.battle);if r then r[side(ev.battle,ev.battler)]=nil end
  end,80)
  mod.events:on('battle.ended',M.restore,80)
  return M
end
