-- Gen VII offensive final damage and terrain-dependent Speed. No save tokens.
return function(mod,opts)
  local B=require('src.battle.BattleState')
  local M={CARD_ID='KASC-67-LATE-ABILITY-POWER',OWNER='kasc.late-ability-power/v1'}
  local function copy(v)local r={};for k,x in pairs(v or{})do r[k]=x end;return r end
  local function alive(w)
    local m=w and w.mon
    return m and (tonumber(m.hp)or 0)>0 and not m.isEgg and not m.egg and not m.eggSpecies
  end
  function M.supportsAbility(game,id,gen)
    local d=game and game.data;local heal=d and d.move_effects and d.move_effects.HEAL_EFFECT
    if gen~=7 or not heal or heal.kascLateAbilityPower67~=M.OWNER
        or heal.kascAbilityOwner67~='kasc.ability-effects/v1' then return false end
    if id=='SURGE_SURFER' then
      return heal.kascTerrain67=='kasc.terrain/v1'
        and heal.kascWeatherOwner67=='kasc.battle-weather/v1'
        and opts.terrain and opts.terrain.OWNER=='kasc.terrain/v1'
        and type(opts.terrain.current)=='function' or false
    end
    if id=='NEUROFORCE' then
      local crit=d.move_effects.FOCUS_ENERGY_EFFECT
      return crit and crit.kascCriticalOwner67=='kasc.critical-rules/v1'
        and opts.damage and opts.damage.kascLateAbilityPower67==M.OWNER or false
    end
    return false
  end
  function M.epoch(b)
    local heal=b and b.data and b.data.move_effects and b.data.move_effects.HEAL_EFFECT
    if getmetatable(b)==B and not b.result and heal and heal.kascLateAbilityPower67==M.OWNER
        and opts.status.epoch(b)==7 then return 7 end
  end
  function M.speedFactor(b,w)
    -- Field.isTerrain in the source does NOT require this holder to be grounded.
    if M.epoch(b) and alive(w) and M.supportsAbility(b.game,'SURGE_SURFER',7)
        and opts.abilities.activeAbility(b,w)=='SURGE_SURFER'
        and opts.terrain.current(b)=='electric' then return 2 end
    return 1
  end
  function M.neuroforce(b,w,move,options)
    if not M.epoch(b) or not alive(w) or not move or move.category=='status'
        or not move.power or move.power<=0 or options and options.typeless
        or not M.supportsAbility(b.game,'NEUROFORCE',7)
        or opts.abilities.activeAbility(b,w)~='NEUROFORCE' then return false end
    local effect=b.data.move_effects[move.effect]
    -- Fixed/OHKO effects do not use the ordinary final-damage formula.
    if move.kascFixedDamage67 or move.id=='COUNTER' or effect and effect.chooseDamage
        or move.effect=='OHKO_EFFECT' then return false end
    -- This is offensive, not a breakable target ability. Do not consult
    -- moveBypassesAbility: an opposing Mold Breaker never removes this bonus.
    return true
  end
  function M.damage(nextDamage,ctx)
    if not ctx then return nextDamage(ctx)end
    local enabled=M.neuroforce(ctx.battle,ctx.user,ctx.move,ctx.opts)
    if not enabled and not(ctx.opts and ctx.opts.kascNeuroforce67)then return nextDamage(ctx)end
    local out=copy(ctx);out.opts=copy(ctx.opts)
    out.opts.kascNeuroforce67=enabled and 5120 or nil
    -- Actual hit typeMult, including Disguise, is resolved by the owned
    -- damage-math final chain, never approximated from species type here.
    return nextDamage(out)
  end
  function M.install()
    local a=opts.abilities
    a._kascLateAbilityPower67=M
    if not a._kascLateAbilityPowerWrapped67 then
      local original=a.speedFactor
      a.speedFactor=function(b,w)
        return (original and original(b,w)or 1)*a._kascLateAbilityPower67.speedFactor(b,w)
      end
      a._kascLateAbilityPowerWrapped67=true
    end
  end
  -- Before detached split-special/ability calculation views; no RNG or writes.
  mod.hooks:wrap('battle.damage',M.damage,20502)
  mod.content.move_effects:patch('HEAL_EFFECT',{kascLateAbilityPower67=M.OWNER})
  M.install()
  if opts.supportLog and opts.supportLog.registerSegment then
    opts.supportLog.registerSegment({segmentId=M.CARD_ID,cardId=M.CARD_ID,
      schema='kasc.optional-feature-card/v1',version='1.0.0',owner=M.OWNER,active=true,
      dependencyStatus='native-speed-and-combined-final-damage',providerStatus='gen7-surge-surfer-neuroforce',
      buildReceiptId='docs/LATE_ABILITY_POWER_67.md',rollbackReceiptId='docs/LATE_ABILITY_POWER_67.md'})
  end
  return M
end
