-- Passive support from actual active partners; never from party reserves.
return function(mod,opts)
  local B=require('src.battle.BattleState')
  local Effects=require('src.battle.EffectRegistry')
  local M={CARD_ID='KASC-67-ALLY-DAMAGE',OWNER='kasc.ally-damage/v1'}
  local function copy(v)local t={};for k,x in pairs(v or{})do t[k]=x end;return t end
  function M.epoch(b)
    local r=b and b.data and b.data.move_effects and b.data.move_effects.HEAL_EFFECT
    local gen=getmetatable(b)==B and not b.result and r and r.kascAllyDamage67==M.OWNER
      and opts.status.epoch(b)
    return gen and gen>=5 and gen<=7 and gen or nil
  end
  function M.count(b,w,id)
    local gen=M.epoch(b)
    if not gen or id~='BATTERY'and id~='FRIEND_GUARD'or id=='BATTERY'and gen<7 then return 0 end
    if id=='FRIEND_GUARD'and opts.abilities.moveBypassesAbility(b,id)then return 0 end
    local rows=opts.active(b);local side
    for _,row in ipairs(rows)do if row.battler==w then side=row.side;break end end
    if not side then return 0 end
    local count=0
    for _,row in ipairs(rows)do
      if row.side==side and row.battler~=w and opts.abilities.activeAbility(b,row.battler)==id then count=count+1 end
    end
    return count
  end
  function M.damage(nextDamage,ctx)
    if not ctx or not ctx.move or ctx.move.category=='status'or ctx.opts and ctx.opts.typeless
        or not M.epoch(ctx.battle)then return nextDamage(ctx)end
    local batteries=M.count(ctx.battle,ctx.user,'BATTERY')
    local guards=M.count(ctx.battle,ctx.target,'FRIEND_GUARD')
    if batteries==0 and guards==0 then return nextDamage(ctx)end
    local out=copy(ctx);out.opts=copy(ctx.opts)
    out.opts.kascBatteryCount67=batteries;out.opts.kascFriendGuardCount67=guards
    return nextDamage(out)
  end
  function M.telepathy(b,user,target,move)
    if not M.epoch(b)or not move or move.category=='status'or user==target
        or opts.abilities.activeAbility(b,target)~='TELEPATHY'then return false end
    local us,ts
    for _,row in ipairs(opts.active(b))do
      if row.battler==user then us=row.side end
      if row.battler==target then ts=row.side end
    end
    return us~=nil and us==ts
  end
  function M.runDamaging(original,b,ctx,record)
    if not M.telepathy(b,ctx.user,ctx.target,ctx.move)then return original(b,ctx,record)end
    local selected=copy(record);local gate=selected.gate
    selected.gate=function(c)
      if gate then local ok,msg=gate(c);if not ok then return ok,msg end end
      if M.telepathy(b,c.user,c.target,c.move)then
        return false,opts.i18n.text('Telepathy!','Telepathie!')
      end
      return true
    end
    -- Use the actual pre-hit gate: no HP damage, secondary, recoil,
    -- contact reactions or accuracy rolls. Includes fixed damage and OHKO.
    return original(b,ctx,selected)
  end
  Effects._kascAllyDamage67=M
  if not Effects._kascAllyDamageWrapped67 then
    local original=Effects.runDamaging
    Effects.runDamaging=function(...)return Effects._kascAllyDamage67.runDamaging(original,...)end
    Effects._kascAllyDamageWrapped67=true
  end
  mod.hooks:wrap('battle.damage',function(nextDamage,ctx)
    if not(ctx.opts and ctx.opts.typeless)and M.telepathy(ctx.battle,ctx.user,ctx.target,ctx.move)then
      return 0,{crit=false,typeMult=0}
    end
    return nextDamage(ctx)
  end,22000)
  -- Before detached split-special and ability calculation views.
  mod.hooks:wrap('battle.damage',M.damage,20501)
  mod.content.move_effects:patch('HEAL_EFFECT',{kascAllyDamage67=M.OWNER})
  if opts.supportLog and opts.supportLog.registerSegment then
    opts.supportLog.registerSegment({segmentId=M.CARD_ID,cardId=M.CARD_ID,
      schema='kasc.optional-feature-card/v1',version='1.0.0',owner=M.OWNER,active=true,
      dependencyStatus='native-active-sides-damage-hit-gates',providerStatus='gen5-7-friend-guard-telepathy-gen7-battery',
      buildReceiptId='docs/ALLY_DAMAGE_67.md',rollbackReceiptId='docs/ALLY_DAMAGE_67.md'})
  end
  return M
end
