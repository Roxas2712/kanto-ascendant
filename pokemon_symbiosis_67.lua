-- Friendly held-item donation after genuine consumption; not theft or loot.
return function(mod,opts)
  local B=require('src.battle.BattleState')
  local M={CARD_ID='KASC-67-SYMBIOSIS',OWNER='kasc.symbiosis/v1'}
  local A,H=opts.abilities,opts.consumption
  function M.epoch(b)
    local r=b and b.data and b.data.move_effects and b.data.move_effects.HEAL_EFFECT
    local gen=getmetatable(b)==B and not b.result and r and r.kascSymbiosis67==M.OWNER
      and opts.status.epoch(b)
    return gen and gen>=6 and gen<=7 and gen or nil
  end
  function M.afterConsumption(b,w,id)
    local gen=M.epoch(b)
    if not gen or type(id)~='string'or not b.data.items[id]
        or not w or(w~=b.player and w~=b.enemy)or H.consumed(b,w)~=id then return false end
    -- Gen VII suppresses the pass when the recipient is leaving the field;
    -- Gen VI permits it. Use the actual KASC switch owner, not a fake flag.
    if gen>=7 and opts.pending(w)then return false end
    local held,err=opts.held(w.mon);if held or err then return false end
    local rows=opts.active(b);local lane
    for _,r in ipairs(rows)do if r.battler==w then lane=r.side;break end end
    if not lane then return false end
    local donors={}
    for _,r in ipairs(rows)do
      if r.side==lane and r.battler~=w and A.activeAbility(b,r.battler)=='SYMBIOSIS'then
        donors[#donors+1]={w=r.battler,speed=opts.speed(b,r.battler)}
      end
    end
    table.sort(donors,function(a,c)return a.speed>c.speed end)
    local i=1
    while i<=#donors do
      local j=i;while j<#donors and donors[j+1].speed==donors[i].speed do j=j+1 end
      for k=j,i+1,-1 do local pick=b.rng(i,k);donors[k],donors[pick]=donors[pick],donors[k]end
      i=j+1
    end
    for _,row in ipairs(donors)do
      local received=opts.transfer.giveToAlly(b,w,row.w)
      if received then
        local def=b.data.items[received];local names=def.names or{}
        b:sayNext(opts.i18n.text('%s shares %s with Symbiosis!','%s gibt %s durch Symbiose weiter!')
          :format(row.w.name or row.w.mon.species,
            opts.i18n.text(names.en or def.name or received,names.de or def.name or received)))
        b:drainNext()
        -- Do not claim the recipient's consumed item or invent a donor
        -- consumption record. A newly received berry may really be eaten.
        H.activateRestored(b,w,false)
        return true
      end
    end
    return false
  end
  function M.hasSource(b,w)
    if not M.epoch(b)then return false end
    local rows=opts.active(b);local lane
    for _,r in ipairs(rows)do if r.battler==w then lane=r.side;break end end
    if not lane then return false end
    for _,r in ipairs(rows)do
      if r.side==lane and r.battler~=w and A.activeAbility(b,r.battler)=='SYMBIOSIS'then return true end
    end
    return false
  end
  mod.content.move_effects:patch('HEAL_EFFECT',{kascSymbiosis67=M.OWNER})
  if opts.supportLog and opts.supportLog.registerSegment then
    opts.supportLog.registerSegment({segmentId=M.CARD_ID,cardId=M.CARD_ID,
      schema='kasc.optional-feature-card/v1',version='1.0.0',owner=M.OWNER,active=true,
      dependencyStatus='consumption-friendly-transfer',providerStatus='symbiosis-vi-vii',
      buildReceiptId='docs/SYMBIOSIS_67.md',rollbackReceiptId='docs/SYMBIOSIS_67.md'})
  end
  return M
end
