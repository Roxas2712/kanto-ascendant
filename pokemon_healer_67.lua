-- Healer V-VII: one checked phase before status damage, never party-wide.
return function(mod,opts)
  local B=require('src.battle.BattleState')
  local M={CARD_ID='KASC-67-HEALER',OWNER='kasc.healer/v1'}
  local known={PSN=true,BRN=true,PAR=true,SLP=true,FRZ=true}
  local function token(b)return b and b.field and b.field.tokens and b.field.tokens[M.OWNER]end
  function M.epoch(b)
    local r=b and b.data and b.data.move_effects and b.data.move_effects.HEAL_EFFECT
    local gen=getmetatable(b)==B and not b.result and r and r.kascHealer67==M.OWNER and opts.status.epoch(b)
    return gen and gen>=5 and gen<=7 and gen or nil
  end
  function M.hasSource(b)
    if not M.epoch(b)then return false end
    for _,row in ipairs(opts.active(b))do
      if opts.abilities.activeAbility(b,row.battler)=='HEALER'then return true end
    end
    return false
  end
  function M.validateCheckpoint(b)
    local s=token(b);if s==nil then return true end
    if type(s)~='table'or type(s.lastTurn)~='number'or s.lastTurn%1~=0
        or s.lastTurn<1 or s.lastTurn>(b.turnCount or 0)then return false,'invalid_healer_timeline'end
    for k in pairs(s)do if k~='lastTurn'then return false,'unknown_healer_field'end end
    return true
  end
  function M.targets(b,source)
    local rows=opts.active(b);local own
    for _,row in ipairs(rows)do if row.battler==source then own=row;break end end
    local targets={};if not own then return targets end
    for _,row in ipairs(rows)do
      if row.side==own.side and row.battler~=source and math.abs(row.position-own.position)==1
          and known[row.battler.mon.status]then targets[#targets+1]=row.battler end
    end
    return targets
  end
  function M.cure(b,w,id)
    if not known[w.mon.status]then return false end
    w.mon.status=nil;w.toxicCounter=nil;opts.lifecycle.clear(w,b)
    b:sayNext(opts.i18n.text(id=='HEALER'and'Healer!'or'Hydration!',id=='HEALER'and'Heilherz!'or'Hydration!'))
    b:drainNext();return true
  end
  function M.recover(b)
    if not M.hasSource(b)then return 0 end
    local turn=b.turnCount
    if type(turn)~='number'or turn%1~=0 or turn<1 then return 0 end
    assert(M.validateCheckpoint(b),'invalid Healer checkpoint')
    if token(b)and token(b).lastTurn==turn then return 0 end
    b.field.tokens[M.OWNER]={lastTurn=turn}
    local rows={};local rain=opts.weather.current(b)=='rain'
    for _,row in ipairs(opts.active(b))do
      local w=row.battler;local id=opts.abilities.activeAbility(b,w)
      if id=='HEALER'and #M.targets(b,w)>0 or id=='HYDRATION'and rain and known[w.mon.status]then
        rows[#rows+1]={w=w,id=id,speed=opts.speed(b,w)}
      end
    end
    -- Hydration and Healer share the same residual phase. Faster holders
    -- act first; shuffle ties without a random/non-transitive comparator.
    table.sort(rows,function(a,z)return a.speed>z.speed end)
    local first=1
    while first<=#rows do
      local last=first;while rows[last+1]and rows[last+1].speed==rows[first].speed do last=last+1 end
      for j=last,first+1,-1 do local k=b.rng(first,j);rows[j],rows[k]=rows[k],rows[j]end
      first=last+1
    end
    local changed=0
    for _,row in ipairs(rows)do
      if row.id=='HYDRATION'then
        if opts.weather.current(b)=='rain'and M.cure(b,row.w,row.id)then changed=changed+1 end
      else
        for _,w in ipairs(M.targets(b,row.w))do
          if b.rng(1,10)<=3 and M.cure(b,w,row.id)then changed=changed+1 end
        end
      end
    end
    return changed
  end
  mod.content.move_effects:patch('HEAL_EFFECT',{kascHealer67=M.OWNER})
  mod.events:on('battle.ended',function(ev)
    local b=ev and ev.battle;if b and b.field and b.field.tokens then b.field.tokens[M.OWNER]=nil end
  end,100)
  if opts.supportLog and opts.supportLog.registerSegment then
    opts.supportLog.registerSegment({segmentId=M.CARD_ID,cardId=M.CARD_ID,
      schema='kasc.optional-feature-card/v1',version='1.0.0',owner=M.OWNER,active=true,
      dependencyStatus='native-weather-status-checkpoint',providerStatus='healer-v-vii',
      buildReceiptId='docs/HEALER_67.md',rollbackReceiptId='docs/HEALER_67.md'})
  end
  return M
end
