-- Power Trip / Stored Power / Punishment use stages, not effective stats.
-- Resolve before Unaware/critical/stat projection and Technician modifiers.
return function(mod,opts)
  local B=require('src.battle.BattleState')
  local M={CARD_ID='KASC-67-STAGE-POWER',OWNER='kasc.stage-power/v1',registered={},patched={},preserved={}}
  local definitions={
    POWER_TRIP={number=681,gen=7,power=20,pp=10,type='DARK',category='physical',contact=true,parts={'RAGE','BITE'},revision=10},
    STORED_POWER={number=500,gen=5,power=20,pp=10,type='PSYCHIC_TYPE',category='special',contact=false,parts={'FOCUS_ENERGY','PSYBEAM'},revision=1},
    -- The historical Gen-IV facts encode the minimum power (60), whereas
    -- later source rows use 0 as the variable-power sentinel.
    PUNISHMENT={number=386,gen=4,power=60,pp=5,type='DARK',category='physical',contact=true,parts={'LEER','BITE'},revision=1,target=true},
  }
  local function copy(v)
    if type(v)~='table'then return v end
    local out={};for k,x in pairs(v)do out[k]=copy(x)end;return out
  end
  function M.positive(w,gen)
    local s=w and w.stages or{};local total=0
    local function add(k)local v=tonumber(s[k])or 0
      total=total+math.max(0,math.min(6,math.floor(v)))end
    for _,k in ipairs({'attack','defense','speed','accuracy','evasion'})do add(k)end
    if gen>=2 then add('specialAttack');add('specialDefense')else add('special')end
    return total
  end
  function M.power(b,u,t,id)
    local d=definitions[id];if not d then return end
    local r=b and b.kascGenerationRulesReceipt
    local gen=r and r.activeEpoch or 1
    local value=(d.target and 60 or 20)+20*M.positive(d.target and t or u,gen)
    return d.target and math.min(200,value)or value
  end
  function M.damage(nextDamage,ctx)
    local b,m=ctx and ctx.battle,ctx and ctx.move
    local r=b and b.kascGenerationRulesReceipt
    if not m or m.kascStagePower67~=M.OWNER or not definitions[m.id]
        or getmetatable(b)~=B or b.result or b.demo or b.kind=='link'
        or not r or r.mode=='off'or ctx.opts and ctx.opts.typeless then return nextDamage(ctx)end
    local out={};for k,v in pairs(ctx)do out[k]=v end
    out.move={};for k,v in pairs(m)do out.move[k]=v end
    out.move.power=M.power(b,ctx.user,ctx.target,m.id)
    return nextDamage(out)
  end
  for _,id in ipairs({'POWER_TRIP','STORED_POWER','PUNISHMENT'})do
    local d=definitions[id];local row=assert(opts.facts.move(id,d.gen))
    assert(row.number==d.number and row.generation==d.gen and row.power==d.power
      and row.type==d.type and row.category==d.category and row.pp==d.pp
      and row.accuracy==100 and row.priority==0 and row.target==10,'stage-power source drift '..id)
    local old=mod.content.moves:get(id)
    -- Only replace this project's catalog's plain-damage placeholder.
    -- A foreign effect for the same ID must not be silently erased.
    if old and old.effect~='NO_ADDITIONAL_EFFECT'and old.kascStagePower67~=M.OWNER then
      M.preserved[id]=old.effect
    else
      local fields={id=id,name=opts.i18n.text(row.names.en,row.names.de),type=d.type,
        category=d.category,power=d.target and 60 or 20,accuracy=100,pp=d.pp,priority=0,
        effect='NO_ADDITIONAL_EFFECT',contact=d.contact,originGeneration=d.gen,
        backendMoveNumber=d.number,backendMoveOwner=M.OWNER,kascStagePower67=M.OWNER,
        backendLearnsetRevision=old and(old.backendLearnsetRevision or 1)or d.revision}
      fields.anim=copy(assert(mod.content.moves:get(d.parts[#d.parts])).anim)
      if old then mod.content.moves:patch(id,fields);M.patched[#M.patched+1]=id
      else mod.content.moves:register(id,fields);M.registered[#M.registered+1]=id end
      local animation={seq={}}
      for _,part in ipairs(d.parts)do
        for _,r in ipairs(assert(mod.content.battle_anims:get(part)).seq)do animation.seq[#animation.seq+1]=copy(r)end
      end
      if mod.content.battle_anims:get(id)then mod.content.battle_anims:patch(id,animation)
      else mod.content.battle_anims:register(id,animation)end
    end
  end
  mod.hooks:wrap('battle.damage',M.damage,31500)
  if opts.supportLog and opts.supportLog.registerSegment then
    opts.supportLog.registerSegment({segmentId=M.CARD_ID,cardId=M.CARD_ID,
      schema='kasc.optional-feature-card/v1',version='1.0.0',owner=M.OWNER,active=true,
      dependencyStatus='native-stage-view-before-stat-modifiers',providerStatus='reviewed-stage-dependent-power',
      buildReceiptId='docs/STAGE_POWER_67.md',rollbackReceiptId='docs/GEN6_WAVE15_SCOPE_20260909.md'})
  end
  return M
end
