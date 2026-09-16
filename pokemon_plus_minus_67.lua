-- Plus/Minus: III can use an opponent; IV needs the opposite allied
-- ability; V+ accepts either allied ability. Party reserves never count.
return function(mod,opts)
  local B=require('src.battle.BattleState')
  local M={CARD_ID='KASC-67-PLUS-MINUS',OWNER='kasc.plus-minus/v1'}
  local function copy(v)local t={};for k,x in pairs(v or{})do t[k]=x end;return t end
  local function living(w)
    local m=w and w.mon
    return m and type(m.hp)=='number'and m.hp>0 and not w.fainted
      and not(m.isEgg or m.egg or m.is_egg or m.eggSpecies)
  end
  function M.epoch(b)
    local r=b and b.data and b.data.move_effects and b.data.move_effects.HEAL_EFFECT
    local gen=getmetatable(b)==B and not b.result and r and r.kascPlusMinus67==M.OWNER
      and opts.status.epoch(b)
    return gen and gen>=3 and gen<=7 and gen or nil
  end
  -- The engine owns sides[].battlers. Do not infer activity from party,
  -- isPlayer alone, a copied wrapper, or from the rival scene's bystanders.
  function M.active(b)
    local rows,seen={},{}
    for index,side in ipairs(b.sides or{})do
      for position,w in ipairs(side.battlers or{})do
        if living(w)and not seen[w.mon]and w.isPlayer==(index==1)then
          seen[w.mon]=true;rows[#rows+1]={battler=w,side=index,position=position}
        end
      end
    end
    return rows
  end
  function M.bonus(b,w)
    local gen=M.epoch(b);if not gen or not living(w)then return false end
    local id=opts.abilities.activeAbility(b,w)
    if id~='PLUS'and id~='MINUS'then return false end
    local rows=M.active(b);local side
    for _,row in ipairs(rows)do if row.battler==w then side=row.side;break end end
    if not side then return false end
    for _,row in ipairs(rows)do
      if row.battler~=w and(gen==3 or row.side==side)then
        local other=opts.abilities.activeAbility(b,row.battler)
        if(other=='PLUS'or other=='MINUS')and(gen>=5 or other~=id)then return true end
      end
    end
    return false
  end
  function M.damage(nextDamage,ctx)
    if not ctx or not ctx.move or ctx.move.category=='status'
        or ctx.opts and ctx.opts.typeless or not M.bonus(ctx.battle,ctx.user)then return nextDamage(ctx)end
    local out=copy(ctx);out.opts=copy(ctx.opts);out.opts.kascPlusMinus67=true
    return nextDamage(out)
  end
  -- Before the split-special adapter creates detached calculation views.
  mod.hooks:wrap('battle.damage',M.damage,20500)
  mod.content.move_effects:patch('HEAL_EFFECT',{kascPlusMinus67=M.OWNER})
  if opts.supportLog and opts.supportLog.registerSegment then
    opts.supportLog.registerSegment({segmentId=M.CARD_ID,cardId=M.CARD_ID,
      schema='kasc.optional-feature-card/v1',version='1.0.0',owner=M.OWNER,active=true,
      dependencyStatus='native-active-sides-damage',providerStatus='gen3-7-plus-minus',
      buildReceiptId='docs/PLUS_MINUS_67.md',rollbackReceiptId='docs/PLUS_MINUS_67.md'})
  end
  return M
end
