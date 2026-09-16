-- Paired primary effects; existing status/stage owners retain immunities,
-- ability reactions and history. No saved extra state and no new UI.
return function(mod,opts)
  local B=require('src.battle.BattleState')
  local M={CARD_ID='KASC-67-DUAL-STATUS',OWNER='kasc.dual-status/v1'}
  local tr=opts.i18n.text
  local ids={TEARFUL_LOOK=true,TOXIC_THREAD=true}
  local function copy(v)if type(v)~='table'then return v end;local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r end
  local function failed()return {tr('But, it failed!','Doch es schlug fehl!'),failed=true}end
  function M.epoch(b)
    local r=b and b.kascGenerationRulesReceipt
    local marker=b and b.data and b.data.move_effects and b.data.move_effects.KA_DUAL_STATUS_67_TEARFUL_LOOK
    if getmetatable(b)==B and not b.demo and b.kind~='link'and not b.result
        and r and r.mode~='off'and marker and marker.kascDualStatus67==M.OWNER then return r.activeEpoch end
  end
  local function snapshot(w)
    local s=w.stages or{}
    return table.concat({s.attack or 0,s.special or 0,s.specialAttack or 0,s.speed or 0,tostring(w.mon.status)},'|')
  end
  function M.cast(ctx)
    local b,u,t,m=ctx.battle,ctx.user,ctx.target,ctx.move;local gen=M.epoch(b)
    if not gen or not ids[m.id]or not u or not t or u==t or u.mon.hp<=0 or t.mon.hp<=0
        or t.invulnerable or t.substituteHP then return failed()end
    local priority=mod.exports.pokemonPriorityAbilities67
    if priority and priority.blocks(ctx)then return failed()end
    local before=snapshot(t);local messages,refusals={},{}
    local function apply(fn)
      local previous=snapshot(t);local rows=fn()
      -- The engine also interprets the first line when deciding whether to
      -- animate. A refused first component must not hide a successful second.
      local dest=snapshot(t)~=previous and messages or refusals
      for _,line in ipairs(rows or{})do dest[#dest+1]=line end
    end
    local split=assert(mod.exports.backendSplitSpecial67)
    if m.id=='TEARFUL_LOOK'then
      apply(function()return split.changeStage(ctx,t,'attack',-1,true)end)
      apply(function()return split.changeStage(ctx,t,gen==1 and'special'or'specialAttack',-1,true)end)
    else
      -- Poison immunity and a capped speed stage are independent. Do not
      -- short-circuit the second effect just because the first was blocked.
      apply(function()return split.changeStage(ctx,t,'speed',-1,true)end)
      apply(function()
        if gen>=2 and t.safeguard then return failed()end
        return ctx.inflict(t,'PSN',{source=m.id,moveType=m.type,kascStatusSource67=u})
      end)
    end
    for _,line in ipairs(refusals)do messages[#messages+1]=line end
    if snapshot(t)==before then messages.failed=true end
    if #messages==0 then return failed()end
    return messages
  end
  local function has(w,id)for _,t in ipairs(w.curTypes or{})do if t==id then return true end end;return false end
  function M.noUseful(b,u,t,move)
    if not move or not ids[move.id]or not M.epoch(b)then return false end
    if not u or not t or not t.mon or t.mon.hp<=0 then return true end
    local A=mod.exports.pokemonAbilityEffects67
    local gen=M.epoch(b)
    local function usefulDrop(stat)
      local delta=A.stageDelta(b,t,-1)
      -- Raising an opponent through Contrary is not a useful stat drop.
      return delta<0 and not t.mist and ((t.stages or{})[stat]or 0)>-6
        and not A.blockStatDrop(b,t,stat,-1,true)
    end
    return A.moveScope(b,u,t,true,function()
      if t.substituteHP or t.invulnerable then return true end
      if A.activeAbility(b,t)=='MAGIC_BOUNCE'and gen>=5 then return true end
      local ctx={battle=b,user=u,target=t,move=move}
      local priority,protection=mod.exports.pokemonPriorityAbilities67,mod.exports.pokemonProtection67
      if priority and priority.blocks(ctx)or protection and protection.blocks(ctx)then return true end
      if move.id=='TEARFUL_LOOK'then
        return not usefulDrop('attack')and not usefulDrop(gen==1 and'special'or'specialAttack')
      end
      local corrosion=A.activeAbility(b,u)=='CORROSION'and gen>=7
      local poison=not t.mon.status and (gen==1 or not t.safeguard)
        and (corrosion or not has(t,'POISON')and (gen==1 or not has(t,'STEEL')))
        and not A.blockStatus(b,t,'PSN',{source=move.id,kascStatusSource67=u})
      return not usefulDrop('speed')and not poison
    end,move)
  end
  for _,row in ipairs({{id='TEARFUL_LOOK',number=715,type='NORMAL',always=true,parts={'GROWL','WATER_GUN'}},
      {id='TOXIC_THREAD',number=672,type='POISON',always=false,parts={'STRING_SHOT','POISONPOWDER'}}})do
    local fact=assert(opts.facts.move(row.id,7))
    assert(fact.number==row.number and fact.type==row.type and fact.category=='status'
      and fact.pp==20 and fact.accuracy==100 and fact.alwaysHits==row.always and fact.target==10,
      'Dual status source drift '..row.id)
    assert(not mod.content.moves:get(row.id),'foreign dual status owner '..row.id)
    local effect='KA_DUAL_STATUS_67_'..row.id
    mod.content.move_effects:register(effect,{kind='primary',accuracyChecked=not row.always,
      kascDualStatus67=M.OWNER,run=M.cast})
    mod.content.moves:register(row.id,{id=row.id,name=tr(fact.names.en,fact.names.de),
      type=fact.type,category='status',power=0,accuracy=100,pp=20,priority=0,effect=effect,
      originGeneration=7,backendMoveNumber=row.number,backendMoveOwner=M.OWNER,backendLearnsetRevision=14})
    local anim={seq={}}
    for _,part in ipairs(row.parts)do
      local source=assert(mod.content.battle_anims:get(part),'missing dual-status animation '..part)
      for _,step in ipairs(source.seq)do anim.seq[#anim.seq+1]=copy(step)end
    end
    mod.content.battle_anims:register(row.id,anim)
  end
  if opts.supportLog and opts.supportLog.registerSegment then
    opts.supportLog.registerSegment({segmentId=M.CARD_ID,cardId=M.CARD_ID,schema='kasc.optional-feature-card/v1',
      version='1.0.0',owner=M.OWNER,active=true,dependencyStatus='native-stages-status-and-ability-owners',
      providerStatus='paired-primary-effects',buildReceiptId='docs/DUAL_STATUS_67.md',
      rollbackReceiptId='docs/GEN6_WAVE15_SCOPE_20260909.md'})
  end
  return M
end
