-- Type-changing abilities project detached move views. The saved moves,
-- PP slots, base catalogue and Pokemon types are never rewritten.
return function(mod,opts)
  local B=require('src.battle.BattleState');local FX=require('src.battle.EffectRegistry')
  local M={OWNER='kasc.move-conversion/v1',CARD_ID='KASC-67-MOVE-CONVERSION'}
  local converters={NORMALIZE={gen=4,type='NORMAL'},PIXILATE={gen=6,type='FAIRY'},
    AERILATE={gen=6,type='FLYING'},REFRIGERATE={gen=6,type='ICE'},
    GALVANIZE={gen=7,type='ELECTRIC'},LIQUID_VOICE={gen=7,type='WATER'}}
  local excluded={JUDGMENT=true,MULTI_ATTACK=true,NATURAL_GIFT=true,REVELATION_DANCE=true,
    TECHNO_BLAST=true,WEATHER_BALL=true,STRUGGLE=true}
  local aliases,sound={},{ }
  for id,row in pairs(opts.facts.data.moves)do
    for _,alias in ipairs(opts.species.moveIds(id))do
      aliases[alias]=id
      for _,flag in ipairs(row.flags or{})do if flag=='sound'then sound[alias]=true end end
    end
  end
  local function copy(v)local r={};for k,x in pairs(v or{})do r[k]=x end;return r end
  function M.epoch(b)
    local r=b and b.data and b.data.move_effects and b.data.move_effects.HEAL_EFFECT
    local gen=r and r.kascMoveConversion67==M.OWNER and opts.status.epoch(b)
    if getmetatable(b)==B and not b.result and gen and gen>=4 and gen<=7 then return gen end
  end
  local function projectAbility(b,u,move)
    local gen=M.epoch(b)
    if not move or move.kascConverted67 or not u or not u.mon or u.mon.hp<=0 then return move end
    local id=aliases[move.id]or move.id
    local typeItems=mod.exports and mod.exports.pokemonTypeItems67
    if typeItems then move=typeItems.projectMove(b,u,move,id)end
    local epoch=opts.status.epoch(b)
    -- Owned later gifts may legitimately retain this move in an older
    -- manual/AUTO profile. Selection remains guarded by generation rules;
    -- its actual type mechanic must not turn into a Normal-only fallback.
    if id=='REVELATION_DANCE'and getmetatable(b)==B and not b.result
        and epoch and epoch>=1 and epoch<=7 and u.curTypes and u.curTypes[1]then
      local out=copy(move);out.type=u.curTypes[1];out.kascConverted67=M.OWNER;return out
    end
    if not gen then return move end
    local ability=opts.abilities.activeAbility(b,u);local spec=converters[ability]
    if not spec or gen<spec.gen then return move end
    if id=='STRUGGLE'then return move end
    local multiplier
    if ability=='LIQUID_VOICE'then
      if not sound[move.id]then return move end
    elseif ability=='NORMALIZE'then
      if gen>=7 then
        if excluded[id]or id=='HIDDEN_POWER'then return move end
        multiplier=4915
      else
        -- Older Normalize also converts originally non-Normal special-type
        -- moves, while an originally Normal variable-type move keeps its type.
        local row=opts.facts.move(id,gen)
        if row and row.type=='NORMAL'and move.type~='NORMAL'then return move end
      end
    else
      if excluded[id]or move.type~='NORMAL'then return move end
      multiplier=gen==6 and 5325 or 4915
    end
    local out=copy(move);out.type=spec.type;out.kascConverted67=M.OWNER
    out.kascConversionPower67=multiplier
    return out
  end
  function M.project(b,u,move)
    local future=mod.exports and mod.exports.pokemonFutureStrikes67
    if future and future.preservesType(b,u,move)then return move end
    local out=projectAbility(b,u,move)
    local ion=mod.exports and mod.exports.pokemonIonDeluge67
    -- Field conversion follows ability/item types. Normalize can therefore
    -- become Electric, whereas an already Aerilate-converted move stays Flying.
    if out and out.type=='NORMAL'and out.id~='STRUGGLE'and ion and ion.active(b)then
      out=copy(out);out.type='ELECTRIC';out.kascIonDeluge67=ion.OWNER
    end
    local changing=mod.exports.pokemonTypeChanges67
    if changing then out=changing.electrifyProject(b,u,out)end
    return out
  end
  function M.damage(nextDamage,ctx)
    if not ctx or ctx.opts and ctx.opts.typeless then return nextDamage(ctx)end
    local out=copy(ctx);out.move=M.project(ctx.battle,ctx.user,ctx.move)
    if out.move and out.move.kascConversionPower67 then
      out.opts=copy(ctx.opts);out.opts.kascConversionPower67=out.move.kascConversionPower67
    end
    return nextDamage(out)
  end
  function M.protean(ev)
    local b,u,move=ev and ev.battle,ev and ev.user,ev and ev.move
    local gen=M.epoch(b)
    if not gen or gen<6 or b.demo or b.kind=='link' or not u or not u.mon
        or u.mon.hp<=0 or opts.abilities.activeAbility(b,u)~='PROTEAN' or not move then return end
    move=M.project(b,u,move)
    local id=aliases[move.id]or move.id
    local record=b:effectRecord(move.effect)
    -- Only the called move supplies the type, never Metronome/Mirror Move.
    -- Future attacks and Struggle do not change the holder's type.
    if id=='STRUGGLE' or id=='FUTURE_SIGHT' or id=='DOOM_DESIRE'
        or record and record.callsMove then return end
    -- Burn Up's TryMove prerequisite precedes Protean's PrepareHit type
    -- change. Do not manufacture Fire for an otherwise ineligible user.
    local burn=mod.exports and mod.exports.pokemonBurnUp67
    if id=='BURN_UP'and burn and burn.active(b,move)and not burn.hasFire(u)then return end
    local typ=move.type
    if not typ or typ=='???' or #u.curTypes==1 and u.curTypes[1]==typ then return end
    u.curTypes={typ}
    b:sayNext(opts.i18n.text('Protean!','Wandlungskunst!'))
  end
  FX._kascMoveConversion67=M
  if not FX._kascMoveConversionWrapped67 then
    local old=FX.makeCtx
    FX.makeCtx=function(b,u,t,...)
      local ctx=old(b,u,t,...);ctx.move=FX._kascMoveConversion67.project(b,u,ctx.move);return ctx
    end
    FX._kascMoveConversionWrapped67=true
  end
  mod.hooks:wrap('battle.damage',M.damage,31000)
  mod.events:on('battle.move_used',M.protean,6500)
  mod.hooks:wrap('battle.accuracy',function(nextAccuracy,ctx)
    local out=copy(ctx);out.move=M.project(ctx.battle,ctx.user,ctx.move);return nextAccuracy(out)
  end,31000)
  mod.content.move_effects:patch('HEAL_EFFECT',{kascMoveConversion67=M.OWNER})
  return M
end
