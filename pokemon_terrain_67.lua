-- Gen VI/VII terrain: one checkpointed field, grounded combatants only.
return function(mod,opts)
  local B=require('src.battle.BattleState')
  local M={OWNER='kasc.terrain/v1',CARD_ID='KASC-67-TERRAIN'}
  local tr=opts.i18n.text
  local defs={electric={move='ELECTRIC_TERRAIN',gen=6,en='Electric Terrain',de='Elektrofeld',type='ELECTRIC'},
    grassy={move='GRASSY_TERRAIN',gen=6,en='Grassy Terrain',de='Grasfeld',type='GRASS'},
    misty={move='MISTY_TERRAIN',gen=6,en='Misty Terrain',de='Nebelfeld'},
    psychic={move='PSYCHIC_TERRAIN',gen=7,en='Psychic Terrain',de='Psychofeld',type='PSYCHIC_TYPE'}}
  local surge={ELECTRIC_SURGE='electric',GRASSY_SURGE='grassy',MISTY_SURGE='misty',PSYCHIC_SURGE='psychic'}
  local function copy(v)local r={};for k,x in pairs(v or{})do r[k]=x end;return r end
  local function state(b)return b and b.field and b.field.tokens and b.field.tokens[M.OWNER]end
  function M.epoch(b)
    local r=b and b.data and b.data.move_effects and b.data.move_effects.HEAL_EFFECT
    local gen=r and r.kascTerrain67==M.OWNER and opts.status.epoch(b)
    if getmetatable(b)==B and not b.result and gen and gen>=6 and gen<=7 then return gen end
  end
  function M.current(b)local r=state(b);return M.epoch(b)and r and r.remaining>0 and r.kind or nil end
  function M.grounded(b,w)
    return w and w.mon and w.mon.hp>0 and not w.invulnerable and not opts.grounding.airborne(b,w)or false
  end
  function M.set(b,kind,who)
    local gen=M.epoch(b);local def=defs[kind]
    if not gen or not def or gen<def.gen or M.current(b)==kind or not who or who.mon.hp<=0 then return false end
    b.field=b.field or{};b.field.tokens=b.field.tokens or{}
    b.field.tokens[M.OWNER]={kind=kind,remaining=5}
    b:sayNext(tr('%s spreads across the field!','%s breitet sich aus!'):format(tr(def.en,def.de)))
    return true
  end
  function M.blocksStatus(b,w,status)
    local kind=M.current(b)
    return M.grounded(b,w)and (kind=='electric'and status=='SLP'
      or kind=='misty'and ({PSN=true,BRN=true,PAR=true,SLP=true,FRZ=true})[status])or false
  end
  function M.blocksConfusion(b,w)
    return M.epoch(b)==7 and M.current(b)=='misty'and M.grounded(b,w)or false
  end
  function M.damage(nextDamage,ctx)
    local b=ctx and ctx.battle;local kind=M.current(b);local move=ctx and ctx.move
    if not kind or not move or ctx.opts and ctx.opts.typeless then return nextDamage(ctx)end
    local factor
    if kind=='misty'and move.type=='DRAGON'and M.grounded(b,ctx.target)then factor=2048
    elseif kind=='grassy'and (move.id=='EARTHQUAKE'or move.id=='BULLDOZE'or move.id=='MAGNITUDE')
        and M.grounded(b,ctx.target)then factor=2048
    elseif (move.type==defs[kind].type or kind=='psychic'and move.type=='PSYCHIC')and M.grounded(b,ctx.user)then factor=6144 end
    if not factor then return nextDamage(ctx)end
    local out=copy(ctx);out.opts=copy(ctx.opts);out.opts.kascTerrainPower67=factor
    return nextDamage(out)
  end
  function M.recover(b)
    local r=state(b);if M.current(b)~='grassy'or r.healTurn==(b.turnCount or 0)then return end
    r.healTurn=b.turnCount or 0
    for _,w in ipairs({b.player,b.enemy})do
      if M.grounded(b,w)and w.mon.hp<w.mon.stats.hp
          and not(mod.exports.pokemonHealBlock67 and mod.exports.pokemonHealBlock67.blocksRecovery(b,w,'terrain'))then
        w.mon.hp=math.min(w.mon.stats.hp,w.mon.hp+math.max(1,math.floor(w.mon.stats.hp/16)))
        b:sayNext(tr('Grassy Terrain restores HP!','Das Grasfeld heilt KP!'));b:drainNext()
      end
    end
  end
  function M.endTurn(ev)
    local b=ev.battle;local r=state(b);if not r or not M.epoch(b)or r.lastTurn==(b.turnCount or 0)then return end
    r.lastTurn=b.turnCount or 0;r.remaining=r.remaining-1
    if r.remaining<=0 then
      b.field.tokens[M.OWNER]=nil;b:sayNext(tr('The terrain returned to normal.','Das Feld normalisiert sich.'))
    end
  end
  local entered=setmetatable({},{__mode='k'})
  function M.entry(ev)
    local b=ev.battle;if M.epoch(b)~=7 then return end
    local list=ev.battler and {ev.battler}or {b.player,b.enemy}
    if #list==2 and not entered[list[1]] and not entered[list[2]] then
      local a,z=opts.weather.speed(b,list[1]),opts.weather.speed(b,list[2])
      if a<z or a==z and surge[opts.abilities.activeAbility(b,list[1])]
          and surge[opts.abilities.activeAbility(b,list[2])]and b.rng(0,1)==1 then list[1],list[2]=list[2],list[1]end
    end
    for _,w in ipairs(list)do
      local kind=surge[opts.abilities.activeAbility(b,w)]
      if kind and not entered[w]then entered[w]=true;M.set(b,kind,w)end
    end
  end
  function M.abilityChanged(b,w)
    entered[w]=nil;M.entry({battle=b,battler=w})
  end
  function M.validateCheckpoint(b)
    local r=state(b);if not r then return true end
    if type(r)~='table'or not defs[r.kind]or type(r.remaining)~='number'
        or r.remaining%1~=0 or r.remaining<1 or r.remaining>5 then return false,'invalid_terrain'end
    for key,v in pairs(r)do
      if key=='healTurn'or key=='lastTurn'then
        if type(v)~='number'or v%1~=0 or v<0 or v>(b.turnCount or 0)then return false,'invalid_terrain_turn'end
      elseif key~='kind'and key~='remaining'then return false,'unknown_terrain_field'end
    end
    return true
  end
  local function deep(v)if type(v)~='table'then return v end;local r={};for k,x in pairs(v)do r[k]=deep(x)end;return r end
  for kind,def in pairs(defs)do
    local id=def.move;local effect='KA_TERRAIN_67_'..id
    mod.content.move_effects:register(effect,{kind='primary',accuracyChecked=false,run=function(ctx)
      if M.set(ctx.battle,kind,ctx.user)then return {}end
      return {tr('But, it failed!','Doch es schlug fehl!'),failed=true}
    end})
    if not mod.content.moves:get(id)then
      local r=assert(opts.facts.move(id,def.gen));assert(r.category=='status')
      local base=assert(mod.content.moves:get('LIGHT_SCREEN'))
      mod.content.battle_anims:register(id,deep(assert(mod.content.battle_anims:get('LIGHT_SCREEN'))))
      mod.content.moves:register(id,{id=id,name=tr(r.names.en,r.names.de),type=r.type,
        category='status',power=0,accuracy=100,pp=r.pp,priority=r.priority,effect=effect,
        anim=deep(base.anim),originGeneration=r.generation,backendMoveOwner=M.OWNER,
        backendMoveNumber=r.number,backendLearnsetRevision=2})
    else mod.content.moves:patch(id,{effect=effect})end
    for i=#opts.moves.unsupportedStatus,1,-1 do if opts.moves.unsupportedStatus[i]==id then table.remove(opts.moves.unsupportedStatus,i)end end
  end
  mod.content.move_effects:patch('HEAL_EFFECT',{kascTerrain67=M.OWNER})
  mod.hooks:wrap('battle.damage',M.damage,26500)
  mod.events:on('battle.started',M.entry,-11100)
  mod.events:on('battle.battler_switched',M.entry,-11100)
  mod.events:on('battle.turn_ended',M.endTurn,-13000)
  mod.events:on('battle.ended',function(ev)if state(ev.battle)then ev.battle.field.tokens[M.OWNER]=nil end end,80)
  return M
end
