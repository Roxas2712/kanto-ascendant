-- Restore a frozen rules receipt before the native command menu resumes.
-- No battle.started replay, no save edits and no Gen2/engine file patches.
return function(mod,opts)
  local M={OWNER='kasc.generation-checkpoint/v1',CARD_ID='KASC-67-BATTLE-CHECKPOINT'}
  local Battle=require('src.battle.BattleState')
  local validators={}
  local continuations={}
  function M.addValidator(fn)validators[#validators+1]=assert(fn)end
  function M.addContinuation(fn)continuations[#continuations+1]=assert(fn)end
  function M.resume(b)
    local marker=b.data and b.data.move_effects and b.data.move_effects.FOCUS_ENERGY_EFFECT
    if b.demo or b.kind=='link' or not marker or marker.kascCheckpointOwner67~=M.OWNER then return end
    -- Native restoration serializes the immutable receipt in field.tokens,
    -- not the top-level battle property. Authenticate/copy it before Card
    -- validators need its era; global registry synchronization stays below.
    local frozen,reason=opts.rules.receipts.restoreBattle(b)
    assert(frozen or reason=='legacy_checkpoint_without_receipt',
      'KASC battle checkpoint: '..tostring(reason))
    for _,validate in ipairs(validators)do
      local ok,why=validate(b)
      assert(ok,'KASC battle checkpoint: '..tostring(why))
    end
    local derivedTypes={}
    for _,who in ipairs({b.player,b.enemy})do
      if who.def and who.curTypes==who.def.types then derivedTypes[#derivedTypes+1]=who end
    end
    local receipt,why=opts.rules.resumeBattle(b)
    assert(receipt,'KASC battle checkpoint: '..tostring(why))
    for _,who in ipairs(derivedTypes)do who.curTypes=who.def.types end
    for _,continue in ipairs(continuations)do continue(b)end
  end
  if type(Battle.resumeCheckpoint)=='function' then
    mod.content.move_effects:patch('FOCUS_ENERGY_EFFECT',{kascCheckpointOwner67=M.OWNER})
    Battle._kascCheckpointOwner67=M
    if not Battle._kascCheckpointWrapped67 then
      local original=Battle.resumeCheckpoint
      Battle.resumeCheckpoint=function(self,...)
        Battle._kascCheckpointOwner67.resume(self)
        return original(self,...)
      end
      Battle._kascCheckpointWrapped67=true
    end
  end
  if opts.supportLog and opts.supportLog.registerSegment then
    opts.supportLog.registerSegment({segmentId=M.CARD_ID,cardId=M.CARD_ID,
      schema='kasc.optional-feature-card/v1',version='1.0.0',owner=M.OWNER,
      active=type(Battle.resumeCheckpoint)=='function',
      dependencyStatus='native-semantic-checkpoint',
      providerStatus='frozen-rules-and-data-only-field-tokens',
      buildReceiptId='docs/BATTLE_CHECKPOINT_67.md',
      rollbackReceiptId='docs/NEW_RC_CARD_MATRIX_20260907.md'})
  end
  return M
end
