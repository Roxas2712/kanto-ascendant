-- KASC-owned fire absorption. Only executed hits prime the battle-local
-- token; damage/accuracy previews are pure. Never save a boosted base stat.
return function(mod,opts)
  local Battle=require('src.battle.BattleState')
  local Effects=require('src.battle.EffectRegistry')
  local M={CARD_ID='KASC-67-FLASH-FIRE',OWNER='kasc.flash-fire/v1'}
  local tr=opts.i18n.text
  local wisps={}
  for _,id in ipairs(opts.species.moveIds('WILL_O_WISP'))do wisps[id]=true end
  local function side(b,who)return who==b.player and 'player' or who==b.enemy and 'enemy' or nil end
  local function tokens(b,create)
    if create then b.field=b.field or {};b.field.tokens=b.field.tokens or {}end
    local rows=b and b.field and b.field.tokens
    if create and not rows[M.OWNER] then rows[M.OWNER]={}end
    return rows and rows[M.OWNER]
  end
  function M.epoch(b)
    local data=b and b.data and b.data.move_effects
    local marker=data and data.HEAL_EFFECT
    local critical=data and data.FOCUS_ENERGY_EFFECT
    if not marker or marker.kascFlashFire67~=M.OWNER or not critical
        or critical.kascCriticalOwner67~='kasc.critical-rules/v1' then return end
    local gen=opts.status.epoch(b)
    if getmetatable(b)==Battle and not b.result and gen and gen>=3 and gen<=7 then return gen end
  end
  function M.validateCheckpoint(b)
    local rows=tokens(b)
    if rows==nil then return true end
    if type(rows)~='table' then return false,'invalid_flash_fire_token' end
    for key,value in pairs(rows)do
      if (key~='player' and key~='enemy') or value~=true then return false,'invalid_flash_fire_side' end
    end
    return true
  end
  function M.clear(b,who)
    local rows=tokens(b)
    if not rows then return end
    if who then local key=side(b,who);if key then rows[key]=nil end
    else b.field.tokens[M.OWNER]=nil end
  end
  function M.boosted(b,who)
    local rows=tokens(b);local key=b and side(b,who)
    return M.epoch(b)~=nil and rows~=nil and key~=nil and rows[key]==true
      and who.mon.hp>0 and opts.abilities.activeAbility(b,who)=='FLASH_FIRE' or false
  end
  function M.canAbsorb(b,user,target,move)
    local gen=M.epoch(b)
    if not gen or not user or not target or user==target or not move or move.type~='FIRE'
        or user.mon.hp<=0 or target.mon.hp<=0 or not side(b,target)
        or opts.abilities.activeAbility(b,target)~='FLASH_FIRE' then return false end
    if move.category=='status' and not wisps[move.id] then return false end
    if gen<=4 and target.mon.status=='FRZ' then return false end
    if gen==3 and wisps[move.id] then
      if target.mon.status or target.substituteHP then return false end
      for _,id in ipairs(target.curTypes or {})do if id=='FIRE' then return false end end
    end
    return true
  end
  function M.absorb(b,ctx)
    if not M.canAbsorb(b,ctx.user,ctx.target,ctx.move) then return false end
    tokens(b,true)[side(b,ctx.target)]=true
    b:cancelMoveAnim()
    b:sayNext(tr('Flash Fire!','Feuerfänger!'))
    return true
  end
  function M.runDamaging(original,b,ctx,record)
    if not M.canAbsorb(b,ctx.user,ctx.target,ctx.move) then return original(b,ctx,record)end
    -- The native invulnerability and custom move gates still run first;
    -- successful absorption skips accuracy, damage and secondary effects.
    local selected={};for k,v in pairs(record or {})do selected[k]=v end
    local gate=selected.gate
    selected.gate=function(c)
      if gate then local ok,msg=gate(c);if not ok then return ok,msg end end
      if M.absorb(b,c) then return false end
      return true
    end
    return original(b,ctx,selected)
  end
  local function copy(v)local r={};for k,x in pairs(v or {})do r[k]=x end;return r end
  function M.damage(nextDamage,ctx)
    local b=ctx and ctx.battle
    if not ctx or not M.epoch(b) or not ctx.move or ctx.move.category=='status'
        or ctx.opts and ctx.opts.typeless then return nextDamage(ctx)end
    if M.canAbsorb(b,ctx.user,ctx.target,ctx.move) then return 0,{crit=false,typeMult=0}end
    if ctx.move.type=='FIRE' and M.boosted(b,ctx.user) then
      local adjusted=copy(ctx);adjusted.opts=copy(ctx.opts);adjusted.opts.kascFlashFire67=true
      return nextDamage(adjusted)
    end
    return nextDamage(ctx)
  end
  -- Will-O-Wisp is a primary effect. Keep the native PP/announcement,
  -- invulnerability check and effect queue; do not intercept Sunny Day.
  local patched={}
  for id in pairs(wisps)do
    local move=mod.content.moves:get(id)
    local effect=move and move.effect
    local record=effect and mod.content.move_effects:get(effect)
    if record and record.kind=='primary' and record.run and not patched[effect] then
      local original=record.run;patched[effect]=true
      mod.content.move_effects:patch(effect,{run=function(ctx)
        if wisps[ctx.move.id] and M.absorb(ctx.battle,ctx) then return {}end
        return original(ctx)
      end})
    end
  end
  mod.content.move_effects:patch('HEAL_EFFECT',{kascFlashFire67=M.OWNER})
  mod.hooks:wrap('battle.damage',M.damage,22000)
  mod.hooks:wrap('battle.accuracy',function(nextAccuracy,ctx)
    if wisps[ctx.move.id] and M.canAbsorb(ctx.battle,ctx.user,ctx.target,ctx.move) then return true end
    return nextAccuracy(ctx)
  end,22000)
  Effects._kascFlashFire67=M
  if not Effects._kascFlashFireWrapped67 then
    local original=Effects.runDamaging
    Effects.runDamaging=function(...)return Effects._kascFlashFire67.runDamaging(original,...)end
    Effects._kascFlashFireWrapped67=true
  end
  mod.events:on('battle.battler_switched',function(ev)M.clear(ev.battle,ev.battler)end,8000)
  mod.events:on('battle.fainted',function(ev)M.clear(ev.battle,ev.battler)end,8000)
  mod.events:on('battle.ended',function(ev)M.clear(ev.battle)end,8000)
  -- Losing/suppressing the ability in a real action ends its volatile.
  -- Never do this during a damage preview, including AI comparisons.
  mod.events:on('battle.move_used',function(ev)
    local b=ev.battle
    if not M.epoch(b) then M.clear(b);return end
    for _,who in ipairs({b.player,b.enemy})do
      if opts.abilities.activeAbility(b,who)~='FLASH_FIRE' then M.clear(b,who)end
    end
  end,8000)
  if opts.supportLog and opts.supportLog.registerSegment then
    opts.supportLog.registerSegment({segmentId=M.CARD_ID,cardId=M.CARD_ID,
      schema='kasc.optional-feature-card/v1',version='1.0.0',owner=M.OWNER,
      active=true,dependencyStatus='native-hit-and-critical-math',providerStatus='gen3-7-fire-absorption',
      buildReceiptId='qa/wave1-pokemon-20260907/FLASH-FIRE-REVIEW-20260908.md',
      rollbackReceiptId='qa/wave1-pokemon-20260907/FLASH-FIRE-REVIEW-20260908.md'})
  end
  return M
end
