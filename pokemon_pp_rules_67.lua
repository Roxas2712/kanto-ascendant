-- Gen 2-7 enemy PP use on the native Gen-I host. The native move owner
-- retains deduction, called/continuation exceptions and persistent slots.
return function(mod,opts)
  local M={CARD_ID='KASC-67-ERA-PP',OWNER='kasc.era-pp/v1'}
  local Battle=require('src.battle.BattleState')
  local TrainerAI=require('src.battle.TrainerAI')
  local function pack(...)return {n=select('#',...),...}end
  function M.epoch(b)
    local row=b and b.data and b.data.move_effects and b.data.move_effects.HEAL_EFFECT
    local gen=row and row.kascPPOwner67==M.OWNER and opts.status.epoch(b)
    if getmetatable(b)==Battle and not b.result and gen and gen>=2 and gen<=7 then return gen end
  end
  function M.scoped(original,b,...)
    if not M.epoch(b)then return original(b,...)end
    local previous=b.ruleset;local rules={}
    for k,v in pairs(previous or {})do rules[k]=v end
    rules.enemyUnlimitedPP=false;b.ruleset=rules
    local out=pack(pcall(original,b,...))
    b.ruleset=previous
    if not out[1]then error(out[2],0)end
    return unpack(out,2,out.n)
  end
  function M.choose(original,b,...)
    if not M.epoch(b)then
      local action=original(b,...)
      local grudge=mod.exports and mod.exports.pokemonGrudge67
      return grudge and grudge.filterAction(b,action)or action
    end
    return M.scoped(function(bb,...)
      local action=original(bb,...)
      -- A custom trainer brain may still return a depleted slot. Do not
      -- replace recharge, charging releases, bound turns, items or switches.
      if not action or action.special or action.struggle or not action.id
          or bb:lockedAction(bb.enemy)then return action end
      -- Bind copied decisions back to the real finite slot; a fresh action
      -- table with an old PP value must not refill the trainer every turn.
      for index,slot in ipairs(bb.enemy.curMoves or {})do
        if slot==action and index~=bb.enemy.disabledSlot and (tonumber(slot.pp) or 0)>0 then return slot end
      end
      for index,slot in ipairs(bb.enemy.curMoves or {})do
        if slot.id==action.id and index~=bb.enemy.disabledSlot and (tonumber(slot.pp) or 0)>0 then return slot end
      end
      return TrainerAI.chooseMove(bb.enemy,bb.rng,bb)
    end,b,...)
  end
  function M.perform(original,b,user,target,move,isCalled)
    if M.epoch(b) and move and not isCalled and not move.struggle
        and tonumber(move.pp) and move.pp<=0 and b:moveDef(move) then
      local continuation=user.charging==move and user.chargeReady
        or user.thrashTurns and user.thrashTurns>0 and user.thrashMove==move
        or user.rageMove==move
      if not continuation then
        b:sayNext(opts.i18n.text('%s has no PP left!','%s hat keine AP mehr!'):format(user.name))
        return
      end
    end
    return M.scoped(original,b,user,target,move,isCalled)
  end
  mod.content.move_effects:patch('HEAL_EFFECT',{kascPPOwner67=M.OWNER})
  Battle._kascPPRules67=M
  if not Battle._kascPPRulesWrapped67 then
    local perform=Battle.performMove
    Battle.performMove=function(...)return Battle._kascPPRules67.perform(perform,...)end
    local enemy=Battle.enemyAction
    Battle.enemyAction=function(...)return Battle._kascPPRules67.choose(enemy,...)end
    local vanilla=Battle.vanillaEnemyAction
    Battle.vanillaEnemyAction=function(...)return Battle._kascPPRules67.scoped(vanilla,...)end
    Battle._kascPPRulesWrapped67=true
  end
  if opts.supportLog and opts.supportLog.registerSegment then
    opts.supportLog.registerSegment({segmentId=M.CARD_ID,cardId=M.CARD_ID,
      schema='kasc.optional-feature-card/v1',version='1.0.0',owner=M.OWNER,active=true,
      dependencyStatus='native-pp-and-ai-selection',providerStatus='era-bound-finite-enemy-pp',
      buildReceiptId='docs/WAVE_W_ABILITIES_20260908.md',
      rollbackReceiptId='docs/WAVE_W_ABILITIES_20260908.md'})
  end
  return M
end
