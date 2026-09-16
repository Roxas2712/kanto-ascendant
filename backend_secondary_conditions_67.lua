-- Reviewed compound/volatile secondaries on the Gen-I host.
return function(mod,opts)
  local M={CARD_ID='KASC-67-SECONDARY-CONDITIONS',OWNER='kasc.secondary-conditions/v1'}
  local aliases={}
  for id in pairs(opts.facts.data.moves)do
    for _,alias in ipairs(opts.species.moveIds(id))do aliases[alias]=id end
  end
  local function epoch(b)
    local row=b and b.data and b.data.move_effects and b.data.move_effects.CONFUSION_SIDE_EFFECT
    if not row or row.kascSecondaryConditions67~=M.OWNER then return end
    local e=opts.status.epoch(b)
    if e and e>=2 then return e end
  end
  local function blocked(ctx)
    return ctx.target.mon.hp<=0 or ctx.target.substituteHP or ctx.brokeSub
  end
  local function roll(ctx,e,chance)
    if e==2 then return ctx.rng(0,255)<math.floor(chance*255/100)end
    local ability=opts.abilities and opts.abilities()
    if ability and ability.secondaryChance then chance=ability.secondaryChance(ctx,chance)end
    return ctx.rng(1,100)<=chance
  end
  local primary=mod.content.move_effects:get('CONFUSION_EFFECT').run
  local function guard(ctx)
    local recovery=mod.exports.pokemonTeamRecovery67
    if recovery and recovery.blocksVolatile(ctx.battle,ctx.target,'confusion',ctx.user,ctx.move)then
      return {opts.i18n.text('Safeguard prevents confusion!','Bodyguard verhindert Verwirrung!')}
    end
  end
  function M.confuse(original,ctx,secondary)
    local e=epoch(ctx.battle)
    if not e then
      local protected=guard(ctx)
      if not protected then return original(ctx)end
      -- The raw-I native secondary pierces Substitute and rolls 25/256
      -- before applying confusion. Preserve that chance, but never draw a
      -- duration or mutate the volatile when the actual side guard blocks.
      if secondary then
        if ctx.target.confusedTurns or ctx.rng(0,255)>=25 then return {}end
      elseif ctx.target.confusedTurns or ctx.target.substituteHP then return original(ctx)end
      return protected
    end
    if blocked(ctx) then return {}end
    if secondary then
      if ctx.target.confusedTurns then return {}end
      local id=aliases[ctx.move.id] or ctx.move.id
      local base=opts.facts.data.moves[id]
      local row=opts.facts.move(id,math.max(e,base and base.generation or e))
      if not row or not row.meta or row.meta.meta_ailment_id~=6 then return original(ctx)end
      if not roll(ctx,e,tonumber(row.effectChance) or row.meta.ailment_chance or 0)then return {}end
    end
    local protected=guard(ctx);if protected then return protected end
    local ability=opts.abilities()
    local immune=e>=3 and ability.blockConfusion(ctx.battle,ctx.target)
    if immune then return immune end
    return primary(ctx) -- native volatile duration, localized name/text
  end
  mod.content.move_effects:patch('CONFUSION_EFFECT',{run=function(ctx)return M.confuse(primary,ctx,false)end})
  local side=mod.content.move_effects:get('CONFUSION_SIDE_EFFECT').run
  mod.content.move_effects:patch('CONFUSION_SIDE_EFFECT',{
    kascSecondaryConditions67=M.OWNER,run=function(ctx)return M.confuse(side,ctx,true)end})
  -- Crystal checks move type (Normal for Tri Attack), not status type.
  -- A private token bypasses only the BRN/FRZ type gate for this invocation;
  -- Registry infliction, ability hooks and the real target remain intact.
  local triToken={}
  for _,id in ipairs({'BRN','FRZ'})do
    local original=mod.content.statuses:get(id).canInflict
    mod.content.statuses:patch(id,{canInflict=function(target,o)
      if o and o._kascTriTypeToken67==triToken then return true end
      return not original or original(target,o)
    end})
  end
  function M.tri(ctx,e)
    if blocked(ctx) then return {}end
    local success=roll(ctx,e,20)
    -- Gen II selects the branch even when the 20% status roll failed.
    -- Its burn branch still thaws a frozen target in that case.
    if not success and e>2 then return {}end
    local status=({'PAR','FRZ','BRN'})[ctx.rng(1,3)]
    if e==2 and status=='BRN' and ctx.target.mon.status=='FRZ' then
      ctx.target.mon.status=nil
      local name=ctx.target.name
      if not ctx.target.isPlayer then name=require('src.core.Strings')('Enemy %s',name)end
      return {ctx.battle:romText('_FireDefrostedText','Fire defrosted\n%s!',name)}
    end
    if not success then return {}end
    return ctx.inflict(ctx.target,status,{source=ctx.move.id,moveType=ctx.move.type,
      secondary=true,_kascTriTypeToken67=e==2 and triToken or nil})
  end
  local plain=mod.content.move_effects:get('NO_ADDITIONAL_EFFECT').run
  mod.content.move_effects:patch('NO_ADDITIONAL_EFFECT',{run=function(ctx)
    local e=epoch(ctx.battle)
    local id=aliases[ctx.move.id] or ctx.move.id
    if e and id=='DIZZY_PUNCH' then return M.confuse(plain,ctx,true)end
    if e and id=='TRI_ATTACK' then return M.tri(ctx,e)end
    return plain(ctx)
  end})
  -- Own Tempo also cures confusion inherited on entry or created by native
  -- rampage/other compound effects, not just these two registry handlers.
  function M.cure(b,who)
    local e=epoch(b)
    if e and e>=3 then return opts.abilities().cureConfusion(b,who)end
  end
  local Status=require('src.battle.Status')
  local Battle=require('src.battle.BattleState')
  Status._kascSecondaryConditions67=M;Battle._kascSecondaryConditions67=M
  if not Status._kascSecondaryConditionsWrapped67 then
    local before=Status.beforeMove
    Status.beforeMove=function(who,rng,b,...)
      Status._kascSecondaryConditions67.cure(b,who)
      return before(who,rng,b,...)
    end
    Status._kascSecondaryConditionsWrapped67=true
  end
  if not Battle._kascSecondaryConditionsWrapped67 then
    local perform=Battle.performMove
    Battle.performMove=function(b,who,target,...)
      local result=perform(b,who,target,...)
      Battle._kascSecondaryConditions67.cure(b,who)
      Battle._kascSecondaryConditions67.cure(b,target)
      return result
    end
    Battle._kascSecondaryConditionsWrapped67=true
  end
  if opts.supportLog and opts.supportLog.registerSegment then
    opts.supportLog.registerSegment({segmentId=M.CARD_ID,cardId=M.CARD_ID,
      schema='kasc.optional-feature-card/v1',version='1.0.0',owner=M.OWNER,
      active=true,dependencyStatus='status-rules-and-native-secondary-pipeline',
      providerStatus='tri-attack-confusion-and-own-tempo',
      buildReceiptId='docs/BACKEND_SECONDARY_CONDITIONS_67.md',
      rollbackReceiptId='docs/NEW_RC_CARD_MATRIX_20260907.md'})
  end
  return M
end
