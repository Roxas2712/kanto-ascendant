-- KASC-67-TYPE-ABSORPTION: water/electric immunity plus actual-hit healing.
-- Damage/accuracy previews never heal. Both sides share the native pipeline.
return function(mod,opts)
  local Battle=require('src.battle.BattleState')
  local Effects=require('src.battle.EffectRegistry')
  local M={CARD_ID='KASC-67-TYPE-ABSORPTION',OWNER='kasc.type-absorption/v1'}
  local tr=opts.i18n.text
  local types={WATER_ABSORB='WATER',VOLT_ABSORB='ELECTRIC',DRY_SKIN='WATER',
    MOTOR_DRIVE='ELECTRIC',LIGHTNING_ROD='ELECTRIC',STORM_DRAIN='WATER',SAP_SIPPER='GRASS'}
  local boosts={MOTOR_DRIVE='speed',LIGHTNING_ROD='specialAttack',
    STORM_DRAIN='specialAttack',SAP_SIPPER='attack'}
  local labels={WATER_ABSORB={'Water Absorb!','H2O-Absorber!'},
    VOLT_ABSORB={'Volt Absorb!','Voltabsorber!'},DRY_SKIN={'Dry Skin!','Trockenheit!'},
    MOTOR_DRIVE={'Motor Drive!','Starthilfe!'},LIGHTNING_ROD={'Lightning Rod!','Blitzfänger!'},
    STORM_DRAIN={'Storm Drain!','Sturmsog!'},SAP_SIPPER={'Sap Sipper!','Vegetarier!'},
    SOUNDPROOF={'Soundproof!','Lärmschutz!'},BULLETPROOF={'Bulletproof!','Kugelsicher!'},
    OVERCOAT={'Overcoat!','Partikelschutz!'}}
  local immunity={SOUNDPROOF='sound',BULLETPROOF='ballistics',OVERCOAT='powder'}
  local flags={}
  -- Targeted status moves only. Rain Dance, Water Sport, Charge, terrain
  -- and other self/field moves must not be stolen by the opposing ability.
  local targeted,waves={},{}
  for name,row in pairs(opts.facts.data.moves)do
    local f={};for _,flag in ipairs(row.flags or {})do f[flag]=true end
    for _,id in ipairs(opts.species.moveIds(name))do
      flags[id]=f
      if (f.sound or f.powder) and (row.target==2 or row.target==8 or row.target==9
          or row.target==10 or row.target==11)then targeted[id]=true end
    end
  end
  for _,name in ipairs({'THUNDER_WAVE','SOAK','EERIE_IMPULSE','ELECTRIFY',
      'SPORE','SLEEP_POWDER','STUN_SPORE','LEECH_SEED','COTTON_SPORE',
      'GRASS_WHISTLE','WORRY_SEED','FORESTS_CURSE','STRENGTH_SAP'})do
    for _,id in ipairs(opts.species.moveIds(name))do
      targeted[id]=true
      if name=='THUNDER_WAVE' then waves[id]=true end
    end
  end
  function M.epoch(b)
    local marker=b and b.data and b.data.move_effects and b.data.move_effects.HEAL_EFFECT
    if not marker or marker.kascTypeAbsorption67~=M.OWNER then return end
    local gen=opts.status.epoch(b)
    if getmetatable(b)==Battle and not b.result and gen and gen>=3 and gen<=7 then return gen end
  end
  function M.canAbsorb(b,user,target,move)
    local gen=M.epoch(b)
    if not gen or not user or not target or user==target or not user.mon or not target.mon
        or user.mon.hp<=0 or target.mon.hp<=0 or not move
        or target~=b.player and target~=b.enemy then return false end
    local id=opts.abilities.activeAbility(b,target)
    if id and immunity[id]then
      return (flags[move.id]or{})[immunity[id]]
        and (move.category~='status' or targeted[move.id])
        and (id=='SOUNDPROOF' or gen>=6) and id or false
    end
    if not id or types[id]~=move.type then return false end
    -- In III/IV Lightning Rod and Storm Drain only redirect in doubles;
    -- they must not grant immunity or a boost in a native singles battle.
    if (id=='LIGHTNING_ROD' or id=='STORM_DRAIN' or id=='SAP_SIPPER') and gen<5
        or id=='MOTOR_DRIVE' and gen<4 then return false end
    if move.category=='status' and not targeted[move.id] then return false end
    -- Gen3 Thunder Wave is the historical exception to Volt Absorb.
    if gen==3 and id=='VOLT_ABSORB' and waves[move.id] then return false end
    return id
  end
  function M.absorb(b,ctx)
    local id=M.canAbsorb(b,ctx.user,ctx.target,ctx.move)
    if not id then return false end
    local mon=ctx.target.mon
    local max=mon.stats.hp
    b:cancelMoveAnim()
    b:sayNext(tr(labels[id][1],labels[id][2]))
    if immunity[id]then return true
    elseif boosts[id] then
      for _,msg in ipairs(opts.split.changeStage(ctx,ctx.target,boosts[id],1,false))do
        b:sayNext(msg)
      end
    else
      local block=mod.exports.pokemonHealBlock67
      if block and block.blocksRecovery(b,ctx.target,'ability')then return true end
      mon.hp=math.min(max,mon.hp+math.max(1,math.floor(max/4)))
      b:drainNext(ctx.target,mon.hp)
    end
    return true
  end
  function M.runDamaging(original,b,ctx,record)
    if not M.canAbsorb(b,ctx.user,ctx.target,ctx.move) then return original(b,ctx,record)end
    local selected={};for k,v in pairs(record or {})do selected[k]=v end
    local gate=selected.gate
    selected.gate=function(c)
      if gate then local ok,msg=gate(c);if not ok then return ok,msg end end
      if M.absorb(b,c) then return false end
      return true
    end
    -- Keeps native invulnerability before absorption; skips accuracy, all
    -- hits, recoil, contact reactions and secondary effects once absorbed.
    return original(b,ctx,selected)
  end
  local patched={}
  for id in pairs(targeted)do
    local move=mod.content.moves:get(id)
    local effect=move and move.effect
    local record=effect and mod.content.move_effects:get(effect)
    if record and not patched[effect] then
      patched[effect]=true
      if record.kind=='primary' and record.run then
        local original=record.run
        mod.content.move_effects:patch(effect,{run=function(ctx)
          if not ctx.target.invulnerable and M.absorb(ctx.battle,ctx) then return {}end
          return original(ctx)
        end})
      elseif record.perform then
        local original=record.perform
        mod.content.move_effects:patch(effect,{perform=function(ctx)
          if not ctx.target.invulnerable and M.absorb(ctx.battle,ctx) then return end
          return original(ctx)
        end})
      end
    end
  end
  mod.content.move_effects:patch('HEAL_EFFECT',{kascTypeAbsorption67=M.OWNER})
  mod.hooks:wrap('battle.damage',function(nextDamage,ctx)
    if ctx and not (ctx.opts and ctx.opts.typeless)
        and ctx.move and ctx.move.category~='status'
        and M.canAbsorb(ctx.battle,ctx.user,ctx.target,ctx.move) then
      return 0,{crit=false,typeMult=0}
    end
    return nextDamage(ctx)
  end,22000)
  mod.hooks:wrap('battle.accuracy',function(nextAccuracy,ctx)
    if ctx and ctx.move and targeted[ctx.move.id]
        and M.canAbsorb(ctx.battle,ctx.user,ctx.target,ctx.move) then return true end
    return nextAccuracy(ctx)
  end,22000)
  Effects._kascTypeAbsorption67=M
  if not Effects._kascTypeAbsorptionWrapped67 then
    local original=Effects.runDamaging
    Effects.runDamaging=function(...)return Effects._kascTypeAbsorption67.runDamaging(original,...)end
    Effects._kascTypeAbsorptionWrapped67=true
  end
  if opts.supportLog and opts.supportLog.registerSegment then
    opts.supportLog.registerSegment({segmentId=M.CARD_ID,cardId=M.CARD_ID,
      schema='kasc.optional-feature-card/v1',version='1.0.0',owner=M.OWNER,
      active=true,dependencyStatus='native-effect-pipeline',providerStatus='gen3-7-water-electric-absorption',
      buildReceiptId='qa/gen6-wave15-alignment-20260909/ABILITY-ABSORPTION-REVIEW.md',
      rollbackReceiptId='qa/gen6-wave15-alignment-20260909/ABILITY-ABSORPTION-REVIEW.md'})
  end
  return M
end
