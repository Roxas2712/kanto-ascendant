-- Chip Away / Sacred Sword / Darkest Lariat ignore defensive/evasion stages only.
-- Keep real battlers, saved stats, ability/item owners and attacker stages intact.
return function(mod,opts)
  local B=require('src.battle.BattleState')
  local M={CARD_ID='KASC-67-STAGE-BYPASS',OWNER='kasc.stage-bypass/v1',registered={},patched={},preserved={}}
  local specs={
    CHIP_AWAY={number=498,gen=5,type='NORMAL',power=70,pp=20,revision=1,parts={'HEADBUTT'}},
    -- Gen V has 20 PP; the existing era projector supplies 15 from VI.
    SACRED_SWORD={number=533,gen=5,type='FIGHTING',power=90,pp=20,revision=1,parts={'SLASH'}},
    DARKEST_LARIAT={number=663,gen=7,type='DARK',power=85,pp=10,revision=19,parts={'BITE','MEGA_PUNCH'}},
  }
  local function shallow(v)local r={};for k,x in pairs(v or{})do r[k]=x end;return r end
  local function deep(v)if type(v)~='table'then return v end;local r={};for k,x in pairs(v)do r[k]=deep(x)end;return r end
  function M.active(ctx)
    local b,m=ctx and ctx.battle,ctx and ctx.move
    local r=b and b.kascGenerationRulesReceipt
    return getmetatable(b)==B and not b.demo and b.kind~='link'and not b.result
      and r and r.mode~='off'and type(r.activeEpoch)=='number'and r.activeEpoch>=1 and r.activeEpoch<=7
      and m and specs[m.id]and m.kascStageBypass67==M.OWNER
      and not(ctx.opts and ctx.opts.typeless)and ctx.target and ctx.target.stages
  end
  local function project(nextFn,ctx,keys)
    if not M.active(ctx)then return nextFn(ctx)end
    local out=shallow(ctx);out.target=shallow(ctx.target);out.target.stages=shallow(ctx.target.stages)
    for _,key in ipairs(keys)do out.target.stages[key]=0 end
    -- mon and curStats retain their identities: this is not an ability
    -- suppression or a replacement target, just a detached stage view.
    return nextFn(out)
  end
  function M.damage(nextFn,ctx)return project(nextFn,ctx,{'defense','specialDefense','special'})end
  function M.accuracy(nextFn,ctx)return project(nextFn,ctx,{'evasion'})end
  for _,id in ipairs({'CHIP_AWAY','SACRED_SWORD','DARKEST_LARIAT'})do
    local s=specs[id];local f=assert(opts.facts.move(id,s.gen))
    assert(f.number==s.number and f.generation==s.gen and f.type==s.type and f.category=='physical'
      and f.power==s.power and f.pp==s.pp and f.accuracy==100 and f.priority==0 and f.target==10,'stage-bypass source drift '..id)
    local old=mod.content.moves:get(id)
    if old and old.effect~='NO_ADDITIONAL_EFFECT'and old.kascStageBypass67~=M.OWNER then
      M.preserved[id]=old.effect
    else
      local fields={id=id,name=opts.i18n.text(f.names.en,f.names.de),type=s.type,category='physical',
        power=s.power,accuracy=100,pp=s.pp,priority=0,effect='NO_ADDITIONAL_EFFECT',contact=true,
        ignoreDefensive=true,ignoreEvasion=true,kascStageBypass67=M.OWNER,
        originGeneration=s.gen,backendMoveNumber=s.number,backendMoveOwner=M.OWNER,
        backendLearnsetRevision=old and(old.backendLearnsetRevision or 1)or s.revision,
        anim=deep(assert(mod.content.moves:get(s.parts[#s.parts])).anim)}
      if old then mod.content.moves:patch(id,fields);M.patched[#M.patched+1]=id
      else mod.content.moves:register(id,fields);M.registered[#M.registered+1]=id end
      local anim={seq={},source=M.OWNER}
      for _,part in ipairs(s.parts)do
        for _,row in ipairs(assert(mod.content.battle_anims:get(part)).seq)do anim.seq[#anim.seq+1]=deep(row)end
      end
      if mod.content.battle_anims:get(id)then mod.content.battle_anims:patch(id,anim)
      else mod.content.battle_anims:register(id,anim)end
    end
  end
  -- After split-Special projection (20000), before item/ability modifiers.
  -- Zero the projected native Special stage as well, preserving Gen I–III
  -- type-based categories instead of forcing the modern physical split.
  mod.hooks:wrap('battle.damage',M.damage,19000)
  mod.hooks:wrap('battle.accuracy',M.accuracy,19000)
  if opts.supportLog and opts.supportLog.registerSegment then
    opts.supportLog.registerSegment({segmentId=M.CARD_ID,cardId=M.CARD_ID,schema='kasc.optional-feature-card/v1',
      version='1.0.0',owner=M.OWNER,active=true,dependencyStatus='native-damage-and-accuracy-stage-views',
      providerStatus='defensive-stages-only',buildReceiptId='docs/STAGE_BYPASS_67.md',
      rollbackReceiptId='docs/GEN6_WAVE15_SCOPE_20260909.md'})
  end
  return M
end
