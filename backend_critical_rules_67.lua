-- KASC-owned critical rules. Context is passed through the existing damage
-- chain, including split Special, abilities and the direct Gen-II item path.
return function(mod, opts)
  local facts, rules, species = assert(opts.facts), assert(opts.rules), assert(opts.species)
  local mathOwner = assert(opts.damage)
  local M = {CARD_ID='KASC-67-CRITICAL-RULES', OWNER='kasc.critical-rules/v1'}
  assert(assert(facts.item('SCOPE_LENS',2)).effect=='HELD_CRITICAL_UP')
  local items={
    SCOPE_LENS={gen=2,bonus=1,en='SCOPE LENS',de='SCOPE-LINSE'},
    RAZOR_CLAW={gen=4,bonus=1,en='RAZOR CLAW',de='SCHARFKLAUE'},
    LUCKY_PUNCH={gen=2,bonus=2,dex=113,en='LUCKY PUNCH',de='GLÜCKSFAUST'},
    STICK={gen=2,bonus=2,dex=83,en='STICK',de='LAUCHSTANGE'},
  }
  for id,row in pairs(items)do
    local fields={kascCriticalItemOwner67=M.OWNER,kascEquipmentRewardEpochs={}}
    for gen=row.gen,7 do fields.kascEquipmentRewardEpochs[gen]=true end
    if mod.content.items:get(id)then
      -- In particular preserve Razor Claw's existing evolution item owner.
      mod.content.items:patch(id,fields)
    else
      local metadata=facts.item(id,row.gen) or {}
      fields.id=id;fields.name=opts.i18n.text(row.en,row.de)
      fields.names={en=row.en,de=row.de};fields.price=metadata.cost or 0
      fields.keyItem=false;fields.tossable=true;fields.needsTarget=false
      fields.originGeneration=row.gen
      mod.content.items:register(id,fields)
    end
  end
  function M.supportsItem(game,id,epoch)
    local def=game and game.data and game.data.items and game.data.items[id]
    local marker=game and game.data and game.data.move_effects and game.data.move_effects.FOCUS_ENERGY_EFFECT
    return items[id] and def and def.kascCriticalItemOwner67==M.OWNER
      and marker and marker.kascCriticalOwner67==M.OWNER
      and type(epoch)=='number' and epoch%1==0
      and epoch>=items[id].gen and epoch<=7 or false
  end
  function M.itemStage(b,user,epoch)
    if not b or b.demo or b.kind=='link' or not user or not user.mon
        or user.mon.isEgg or user.mon.egg or user.mon.eggSpecies
        or (tonumber(user.mon.hp) or 0)<=0 then return 0 end
    local receipt=b.kascGenerationRulesReceipt
    local bucket=b.game and b.game.save and b.game.save.modData
    local state=bucket and bucket[mod.id] and bucket[mod.id][rules.SAVE_KEY]
    -- A later gift move may use a newer damage formula. It must not unlock
    -- held items before their actual battle rule profile permits them.
    if receipt then epoch=receipt.mode=='off' and 1 or tonumber(receipt.activeEpoch) or 1
    elseif state then epoch=state.activeMode=='off' and 1 or tonumber(state.activeEpoch) or 1
    else return 0 end
    local id=opts.held and opts.held(user.mon,b,user)
    if not M.supportsItem(b.game,id,epoch)then return 0 end
    local row=items[id]
    -- III/IV test Transform's copied species; II and V+ use the real species.
    -- Birth provenance never grants Chansey's effect to an evolved Blissey.
    local current=user.mon.species
    if epoch>=3 and epoch<=4 and opts.identity then current=opts.identity.current(b,user)end
    if row.dex and current~=species.byKey['dex:'..row.dex]then return 0 end
    return row.bonus
  end
  local owners = {}
  for id in pairs(facts.data.moves) do
    for _, native in ipairs(species.moveIds(id)) do owners[native] = id end
  end
  local function copy(v) local r={};for k,x in pairs(v or {}) do r[k]=x end;return r end
  function M.epoch(b, user, move)
    if not b or b.demo or b.kind=='link' or not move then return nil end
    local game=b.game
    local marker=game and game.data and game.data.move_effects
      and game.data.move_effects.FOCUS_ENERGY_EFFECT
    if not marker or marker.kascCriticalOwner67~=M.OWNER then return nil end
    local receipt=b.kascGenerationRulesReceipt
    if not receipt then
      local bucket=game.save and game.save.modData and game.save.modData[mod.id]
      local state=bucket and bucket[rules.SAVE_KEY]
      if state then receipt={mode=state.activeMode,activeEpoch=state.activeEpoch} end
    end
    if not receipt or receipt.mode=='off' then return nil end
    local epoch=tonumber(receipt.activeEpoch) or 1
    local row=facts.data.moves[owners[move.id] or move.id]
    if row and row.generation>epoch then
      if not (user and rules.ownedGiftBattleCompatible
          and rules.ownedGiftBattleCompatible(game,user.mon,game.data.pokemon[user.mon.species])) then
        return nil
      end
      epoch=row.generation
    end
    return epoch>=2 and epoch or nil
  end
  function M.roll(epoch, user, move, rng, bonus,exclusiveItem)
    local row=facts.move(owners[move.id] or move.id,epoch)or facts.data.moves[owners[move.id] or move.id]
    local rate=row and row.meta and tonumber(row.meta.crit_rate) or 0
    if rate>=6 then return true end
    local stage=math.max(rate,move.highCrit and 1 or 0)
    -- Gen II high-critical moves add two stages; Focus Energy adds one.
    if epoch==2 then stage=stage>0 and stage+1 or stage end
    if user.focusEnergy then stage=stage+(epoch==2 and 1 or 2) end
    stage=stage+(bonus or 0)
    -- Crystal jumps directly to the tally for Chansey/Lucky Punch and
    -- Farfetch'd/Stick: Focus Energy and high-crit moves do not stack there.
    if epoch==2 and exclusiveItem then stage=2 end
    if epoch==2 then return rng(0,255)<({17,32,64,85,128})[math.min(stage,4)+1] end
    local ratios=epoch<=5 and {16,8,4,3,2}
      or epoch==6 and {16,8,2,1} or {24,8,2,1}
    local denominator=ratios[math.min(stage,#ratios-1)+1]
    return denominator==1 or rng(1,denominator)==1
  end
  function M.prepare(nextDamage, ctx)
    local epoch=ctx and M.epoch(ctx.battle,ctx.user,ctx.move)
    if not epoch or not ctx.target or (ctx.opts and ctx.opts.typeless)
        or ctx.move.category=='status' or (tonumber(ctx.move.power) or 0)<=0 then
      return nextDamage(ctx)
    end
    local adjusted=copy(ctx);adjusted.opts=copy(ctx.opts)
    adjusted.opts.kascCriticalEpoch67=epoch
    local abilities=opts.abilities and opts.abilities()
    if adjusted.opts.forceCrit==nil then
      local itemBonus=M.itemStage(ctx.battle,ctx.user,epoch)
      local bonus=itemBonus
      if abilities and abilities.criticalStageBonus then
        bonus=bonus+abilities.criticalStageBonus(ctx.battle,ctx.user)
      end
      if abilities and abilities.activeAbility(ctx.battle,ctx.user)=='MERCILESS'
          and ctx.user.mon.hp>0 and ctx.target.mon.hp>0 and ctx.target.mon.status=='PSN'then adjusted.opts.forceCrit=true
      else adjusted.opts.forceCrit=M.roll(epoch,ctx.user,ctx.move,
        adjusted.opts.rng or ctx.rng or ctx.battle.rng or love.math.random,bonus,itemBonus==2)end
    end
    if abilities and abilities.blocksCritical and abilities.blocksCritical(ctx.battle,ctx.target) then
      adjusted.opts.forceCrit=false
    end
    return nextDamage(adjusted)
  end
  function M.damage(nextDamage, ctx)
    if ctx.opts and ctx.opts.kascCriticalEpoch67 and M.epoch(ctx.battle,ctx.user,ctx.move) then
      return mathOwner.compute(ctx.ruleset,ctx.user,ctx.target,ctx.move,ctx.opts)
    end
    return nextDamage(ctx)
  end
  mod.content.move_effects:patch('FOCUS_ENERGY_EFFECT',{kascCriticalOwner67=M.OWNER})
  mod.hooks:wrap('battle.damage',M.prepare,21000)
  mod.hooks:wrap('battle.damage',M.damage,-9000)
  if opts.supportLog and opts.supportLog.registerSegment then
    opts.supportLog.registerSegment({segmentId=M.CARD_ID,cardId=M.CARD_ID,
      schema='kasc.optional-feature-card/v1',version='1.0.0',owner=M.OWNER,
      active=true,dependencyStatus='native-damage-chain',
      providerStatus='historical-critical-rules-and-held-items',
      buildReceiptId='docs/BACKEND_CRITICAL_RULES_67.md',
      rollbackReceiptId='docs/NEW_RC_CARD_MATRIX_20260907.md'})
  end
  return M
end
