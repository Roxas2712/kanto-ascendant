-- Later-rule flinch semantics on the Gen-I host. No engine/VASC edits.
return function(mod,opts)
  local facts,rules,species=assert(opts.facts),assert(opts.rules),assert(opts.species)
  local M={CARD_ID='KASC-67-FLINCH-EFFECTS',OWNER='kasc.flinch-effects/v1'}
  local aliases={}
  for id in pairs(facts.data.moves)do
    for _,native in ipairs(species.moveIds(id))do aliases[native]=id end
  end
  function M.epoch(b)
    if not b or b.demo or b.kind=='link' then return end
    local game=b.game
    local record=game and game.data and game.data.move_effects
      and game.data.move_effects.FLINCH_SIDE_EFFECT1
    if not record or record.kascFlinchOwner67~=M.OWNER then return end
    local receipt=b.kascGenerationRulesReceipt
    if not receipt then
      local md=game.save and game.save.modData and game.save.modData[mod.id]
      local state=md and md[rules.SAVE_KEY]
      if state then receipt={mode=state.activeMode,activeEpoch=state.activeEpoch}end
    end
    if receipt and receipt.mode~='off' then return tonumber(receipt.activeEpoch)end
  end
  function M.beforeTurn(b)
    local epoch=M.epoch(b)
    if not epoch or epoch<1 then return end
    b._kascFlinchActed67={}
    -- Observe real raw-I actions for licensed future secondary owners only;
    -- native Gen-I flinch clearing/recharge semantics stay unchanged.
    if epoch<2 then return end
    for _,who in ipairs({b.player,b.enemy})do
      if who then who.flinched=false end
    end
  end
  function M.secondary(original,ctx)
    local epoch=M.epoch(ctx.battle)
    if not epoch or epoch<2 then return original(ctx)end
    local id=aliases[ctx.move.id]
    local row=id and facts.move(id,epoch)
    local chance=row and row.meta and tonumber(row.meta.flinch_chance)
    if not chance or chance<=0 then return original(ctx)end
    local target,b=ctx.target,ctx.battle
    if target.substituteHP or ctx.brokeSub or target.mon.hp<=0 then return {} end
    if epoch==2 then
      -- Crystal MOVE_CHANCE: percent = floor(percent * $ff / 100).
      -- EffectChance draws before FlinchTarget checks sleep/order.
      local rolled=ctx.rng(0,255)<math.floor(chance*255/100)
      if not rolled or target.mon.status=='SLP' or target.mon.status=='FRZ'
        or b._kascFlinchActed67 and b._kascFlinchActed67[target] then return {} end
      target.flinched=true
      target.mustRecharge=nil -- Crystal EndRechargeOpp, not an extra lost turn.
      return {}
    end
    if b._kascFlinchActed67 and b._kascFlinchActed67[target] then return {} end
    local ability=opts.abilities and opts.abilities()
    if ability and ability.blocksFlinch(b,target) then return {} end
    if ability and ability.secondaryChance then chance=ability.secondaryChance(ctx,chance)end
    if ctx.rng(1,100)<=chance then target.flinched=true end
    return {}
  end
  for _,id in ipairs({'FLINCH_SIDE_EFFECT1','FLINCH_SIDE_EFFECT2'})do
    local record=mod.content.move_effects:get(id)
    if record and record.run then
      local original=record.run
      mod.content.move_effects:patch(id,{kascFlinchOwner67=M.OWNER,
        run=function(ctx)return M.secondary(original,ctx)end})
    end
  end
  local Battle=require('src.battle.BattleState')
  Battle._kascFlinchOwner67=M
  if not Battle._kascFlinchWrapped67 then
    local clear,resolve,execute=Battle.clearTurnFlinches,Battle.resolveTurn,Battle.executeAction
    local recharge=Battle.preRechargeChecks
    Battle.preRechargeChecks=function(self,user,...)
      local epoch=Battle._kascFlinchOwner67.epoch(self)
      if epoch and epoch>=2 then
        -- Gen-II FlinchTarget already removed recharge. The host may
        -- still hold its preselected recharge action; consume the flinch
        -- through the normal status path instead of saying recharge.
        if epoch==2 and not user.mustRecharge and user.flinched then
          return recharge(self,user,...)
        end
        -- Modern recharge precedes flinch/sleep and consumes this turn.
        -- Keep the native action dispatcher, faint/escape guards and text.
        user.flinched=false
        return false
      end
      return recharge(self,user,...)
    end
    Battle.clearTurnFlinches=function(self,...)
      local result=clear(self,...)
      Battle._kascFlinchOwner67.beforeTurn(self)
      return result
    end
    Battle.resolveTurn=function(self,...)
      -- Forced recharge/Rage actions can bypass the command-menu reset.
      Battle._kascFlinchOwner67.beforeTurn(self)
      return resolve(self,...)
    end
    Battle.executeAction=function(self,user,...)
      local owner=Battle._kascFlinchOwner67
      local epoch=owner.epoch(self)
      if epoch and epoch>=1 then
        self._kascFlinchActed67=self._kascFlinchActed67 or {}
        self._kascFlinchActed67[user]=true
      end
      return execute(self,user,...)
    end
    Battle._kascFlinchWrapped67=true
  end
  if opts.supportLog and opts.supportLog.registerSegment then
    opts.supportLog.registerSegment({segmentId=M.CARD_ID,cardId=M.CARD_ID,
      schema='kasc.optional-feature-card/v1',version='1.0.0',owner=M.OWNER,
      active=true,dependencyStatus='native-damage-secondary-pipeline',
      providerStatus='historical-gen2-plus-flinch-and-turn-boundaries',
      buildReceiptId='docs/BACKEND_FLINCH_EFFECTS_67.md',
      rollbackReceiptId='docs/NEW_RC_CARD_MATRIX_20260907.md'})
  end
  return M
end
