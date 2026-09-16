-- Species-specific held stats. Choice items require a separate persistent
-- move-lock owner and are deliberately NOT advertised by this module.
return function(mod,opts)
  local M={CARD_ID='KASC-67-HELD-STATS',OWNER='kasc.held-stats/v1'}
  local items={LIGHT_BALL=2,THICK_CLUB=2,METAL_POWDER=2,DEEP_SEA_TOOTH=3,DEEP_SEA_SCALE=3,SOUL_DEW=3,QUICK_POWDER=4,EVIOLITE=5}
  local function copy(v)local r={};for k,x in pairs(v or {})do r[k]=x end;return r end
  function M.itemMetadata(id)
    if id=='QUICK_POWDER'then
      return {id=id,generation=4,names={en='QUICK POWDER',de='FLOTTSTAUB'},flags={'holdable','holdable-passive'}}
    elseif id=='EVIOLITE'then
      return {id=id,generation=5,names={en='EVIOLITE',de='EVOLITH'},flags={'holdable','holdable-passive'},
        sourceCommit='6b4bc34e44cc2541929cc4b8fff96e756ab3f268',showdownNumber=538}
    end
  end
  if not mod.content.items:get('EVIOLITE')then
    mod.content.items:register('EVIOLITE',{id='EVIOLITE',name=opts.i18n.text('EVIOLITE','EVOLITH'),
      names=M.itemMetadata('EVIOLITE').names,price=0,keyItem=false,tossable=true,needsTarget=false,
      field=false,battle=false,originGeneration=5})
  end
  if not mod.content.items:get('QUICK_POWDER')then
    mod.content.items:register('QUICK_POWDER',{id='QUICK_POWDER',name=opts.i18n.text('QUICK POWDER','FLOTTSTAUB'),
      names=M.itemMetadata('QUICK_POWDER').names,price=1000,keyItem=false,field=false,battle=false})
  end
  for id,gen in pairs(items)do
    if mod.content.items:get(id)then
      local ready={};for epoch=gen,7 do ready[epoch]=true end
      mod.content.items:patch(id,{kascHeldStatOwner67=M.OWNER,kascEquipmentRewardEpochs=ready})
    end
  end
  function M.supportsItem(game,id,gen)
    local def=game and game.data and game.data.items and game.data.items[id]
    local math=game and game.data and game.data.move_effects and game.data.move_effects.FOCUS_ENERGY_EFFECT
    return items[id] and def and def.kascHeldStatOwner67==M.OWNER
      and math and math.kascCriticalOwner67=='kasc.critical-rules/v1'
      and (id~='QUICK_POWDER' or game.data.move_effects.HEAL_EFFECT
        and game.data.move_effects.HEAL_EFFECT.kascWeatherOwner67=='kasc.battle-weather/v1')
      and type(gen)=='number' and gen%1==0 and gen>=items[id] and gen<=7 or false
  end
  function M.epoch(b)
    if not b or b.demo or b.kind=='link' or b.result then return end
    local r=b.kascGenerationRulesReceipt
    local bucket=b.game and b.game.save and b.game.save.modData
    local s=bucket and bucket[mod.id] and bucket[mod.id][opts.rules.SAVE_KEY]
    if r then return r.mode~='off' and tonumber(r.activeEpoch) or nil end
    return s and s.activeMode~='off' and tonumber(s.activeEpoch) or nil
  end
  local function live(who)
    local mon=who and who.mon
    return mon and not mon.isEgg and not mon.egg and not mon.eggSpecies and (tonumber(mon.hp)or 0)>0
  end
  local function identity(b,who,gen,id)
    if not live(who)then return end
    local species=who.mon.species
    if gen>=3 and gen<=4 and id~='SOUL_DEW' and id~='METAL_POWDER' and opts.identity then
      species=opts.identity.current(b,who)
    end
    local key=species and opts.species.bySpecies[species]
    local row=key and opts.catalog.entries[key]
    return row and row.nationalDex
  end
  local function introduced(species,definition)
    local key=opts.species.bySpecies[species]
    local row=key and opts.catalog.entries[key]
    local gen=row and row.originGeneration or definition and definition.originGeneration
    -- Gorochu is an authored KASC species, not the unrelated Dex slot #279.
    -- Its actual native evolution edge may qualify its parent; it has no
    -- outgoing edge itself. No unknown species gets an assumed Dex era.
    if not gen and species=='GOROCHU'then gen=1 end
    if type(gen)=='number'and gen%1==0 and gen>=1 and gen<=9 then return gen,row end
  end
  function M.evioliteEligible(b,who,gen)
    if getmetatable(b)~=require('src.battle.BattleState')or not live(who)
        or type(gen)~='number'or gen%1~=0 or gen<5 or gen>7 then return false end
    -- mon.species stays original under Transform. Copied stats, appearance,
    -- ability or a birth backendKey must not grant/remove this item's bonus.
    local species=who.mon.species;local definition=b.data and b.data.pokemon and b.data.pokemon[species]
    if not definition or definition.isMega or definition.isGigantamax
        or who.mon._ascMegaForm or who.mon.ascMegaForm then return false end
    local born,row=introduced(species,definition)
    if not born or row and(row.isMega or row.isGigantamax)then return false end
    local era=math.max(gen,born)
    for _,edge in ipairs(definition.evolutions or{})do
      local target=edge.species;local targetDef=target and b.data.pokemon[target]
      local targetBorn,targetRow=introduced(target,targetDef)
      if targetDef and target~=species and targetBorn and targetBorn<=era
          and not targetDef.isMega and not targetDef.isGigantamax
          and not(targetRow and(targetRow.isMega or targetRow.isGigantamax))then return true end
    end
    return false
  end
  function M.speedFactor(b,who)
    local gen=M.epoch(b)
    if not gen or not live(who)or opts.held(who.mon,b,who)~='QUICK_POWDER'
        or not M.supportsItem(b.game,'QUICK_POWDER',gen)
        or not opts.identity or opts.identity.transformed(who)then return 1 end
    return identity(b,who,gen,'QUICK_POWDER')==132 and 2 or 1
  end
  function M.modifiers(b,user,target,move)
    local gen=M.epoch(b);if not gen then return end
    local category=move.category or require('src.battle.TypeChart').category(move.type)
    local special=category=='special'
    local uid=live(user)and opts.held(user.mon,b,user);local zid=live(target)and opts.held(target.mon,b,target)
    if not M.supportsItem(b.game,uid,gen)then uid=nil end
    if not M.supportsItem(b.game,zid,gen)then zid=nil end
    local a,z=identity(b,user,gen,uid),identity(b,target,gen,zid)
    local result={}
    if uid=='LIGHT_BALL' and a==25 then
      if gen==4 then result.kascHeldPowerDouble67=true
      elseif special or gen>=5 then result.kascHeldAttack67=8192 end
    elseif uid=='THICK_CLUB' and (a==104 or a==105)and not special then result.kascHeldAttack67=8192
    elseif uid=='DEEP_SEA_TOOTH' and a==366 and special then result.kascHeldAttack67=8192
    elseif uid=='SOUL_DEW' and (a==380 or a==381)then
      if gen<=6 and special then result.kascHeldAttack67=6144
      elseif gen==7 and (move.type=='DRAGON' or move.type=='PSYCHIC_TYPE' or move.type=='PSYCHIC')then
        result.kascHeldTypeBoost67=true
      end
    end
    if zid=='EVIOLITE'and M.evioliteEligible(b,target,gen)then result.kascHeldDefense67=6144
    elseif zid=='DEEP_SEA_SCALE' and z==366 and special then result.kascHeldDefense67=8192
    elseif zid=='SOUL_DEW' and (z==380 or z==381)and gen<=6 and special then result.kascHeldDefense67=6144
    elseif zid=='METAL_POWDER' and z==132 then
      if gen==2 then result.kascMetalPowder67=true;result.kascHeldDefense67=6144
      elseif not special and opts.identity and not opts.identity.transformed(target)then
        result.kascHeldDefense67=8192
      end
    end
    return result
  end
  function M.damage(nextDamage,ctx)
    if not ctx or not ctx.move or not ctx.user or not ctx.target
        or ctx.opts and ctx.opts.typeless or ctx.move.category=='status'
        or (tonumber(ctx.move.power)or 0)<=0 then return nextDamage(ctx)end
    local modifiers=M.modifiers(ctx.battle,ctx.user,ctx.target,ctx.move)
    if not modifiers or not next(modifiers)then return nextDamage(ctx)end
    local adjusted=copy(ctx);adjusted.opts=copy(ctx.opts)
    for k,v in pairs(modifiers)do adjusted.opts[k]=v end
    return nextDamage(adjusted)
  end
  mod.hooks:wrap('battle.damage',M.damage,-7900)
  return M
end
