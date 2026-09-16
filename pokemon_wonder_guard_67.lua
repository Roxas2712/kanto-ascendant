-- Direct move immunity; residual/status/confusion damage stays with its owner.
return function(mod,opts)
  local M={CARD_ID='KASC-67-WONDER-GUARD',OWNER='kasc.wonder-guard/v1'}
  local Battle=require('src.battle.BattleState')
  local Effects=require('src.battle.EffectRegistry')
  local TypeChart=require('src.battle.TypeChart')
  local firefang={};for _,id in ipairs(opts.species.moveIds('FIRE_FANG'))do firefang[id]=true end
  local function epoch(b)
    local marker=b and b.data and b.data.move_effects and b.data.move_effects.HEAL_EFFECT
    if not marker or marker.kascWonderGuard67~=M.OWNER then return end
    local gen=opts.status.epoch(b)
    if getmetatable(b)==Battle and not b.result and gen and gen>=3 and gen<=7 then return gen end
  end
  function M.blocks(b,user,target,move,options)
    local gen=epoch(b)
    local future=mod.exports and mod.exports.pokemonFutureStrikes67
    local delayed=future and future.striking(b,user,target,move)
    if not gen or not user or not target or user==target or not move
        or not user.mon or not target.mon or user.mon.hp<=0 and not delayed or target.mon.hp<=0
        or move.category=='status' or move.id=='STRUGGLE' or move.type=='???'
        or move.ignoreAbility or options and options.typeless
        or opts.abilities.activeAbility(b,target)~='WONDER_GUARD' then return false end
    if gen==4 and firefang[move.id] then return false end
    return TypeChart.effectiveness(move.type,target.curTypes or target.def.types)<=10
  end
  local function run(original,b,ctx,record)
    if not M.blocks(b,ctx.user,ctx.target,ctx.move)then return original(b,ctx,record)end
    local selected={};for k,v in pairs(record or {})do selected[k]=v end
    local gate=selected.gate
    selected.gate=function(c)
      if gate then local ok,message=gate(c);if not ok then return ok,message end end
      if M.blocks(b,c.user,c.target,c.move)then
        -- Explosion still sacrifices its user on immunity, just as the
        -- native type-immunity path invokes that record's onMiss callback.
        if selected.onMiss then selected.onMiss(c,'immune')end
        return false,opts.i18n.text('Wonder Guard!','Wunderwache!')
      end
      return true
    end
    return original(b,ctx,selected)
  end
  Effects._kascWonderGuard67=M;M.run=run
  if not Effects._kascWonderGuardWrapped67 then
    local original=Effects.runDamaging
    Effects.runDamaging=function(...)return Effects._kascWonderGuard67.run(original,...)end
    Effects._kascWonderGuardWrapped67=true
  end
  -- AI/damage previews use the same immunity without emitting messages or
  -- touching move instances, PP, HP, RNG or per-battle state.
  mod.hooks:wrap('battle.damage',function(nextDamage,ctx)
    if M.blocks(ctx.battle,ctx.user,ctx.target,ctx.move,ctx.opts)then
      return 0,{crit=false,typeMult=0}
    end
    return nextDamage(ctx)
  end,23000)
  mod.content.move_effects:patch('HEAL_EFFECT',{kascWonderGuard67=M.OWNER})
  return M
end
