-- Canonical single-battle failure for moves requiring another active ally
-- or a multi-battler action order. Never invent a partner from party reserves.
return function(mod,opts)
  local Battle=require('src.battle.BattleState')
  local M={CARD_ID='KASC-67-SINGLES-SUPPORT',OWNER='kasc.singles-support/v1'}
  local specs={AFTER_YOU={495,5,15},ALLY_SWITCH={502,5,15},FOLLOW_ME={266,3,20},
    HELPING_HAND={270,3,20},HOLD_HANDS={607,6,40},QUASH={511,5,15},RAGE_POWDER={476,5,20}}
  local aliases={}
  local function fail()
    -- The explicit failure bit also cancels native success animations when
    -- translated text cannot be recognized by the engine's English sniffer.
    return{opts.i18n.text('But, it failed!','Doch es schlug fehl!'),failed=true}
  end
  function M.noUseful(b,u,t,m)
    local receipt=b and b.kascGenerationRulesReceipt
    return getmetatable(b)==Battle and not b.demo and not b.result and b.kind~='link'
      and type(receipt)=='table'and type(receipt.activeEpoch)=='number'
      and receipt.activeEpoch>=1 and receipt.activeEpoch<=7
      and(receipt.mode=='auto'or receipt.mode=='gen'..receipt.activeEpoch)
      and m~=nil and aliases[m.id]==m.effect and m.backendMoveOwner==M.OWNER or false
  end
  for id,spec in pairs(specs)do
    local fact=assert(opts.facts.move(id,7));local old=assert(mod.content.moves:get(id))
    assert(fact.number==spec[1]and fact.generation==spec[2]and fact.pp==spec[3]
      and fact.power==0 and fact.category=='status','single-support source drift '..id)
    assert(not old.backendMoveOwner and old.effect=='KA_GEN_MOVE_UNSUPPORTED_'..id,
      'foreign single-support owner '..id)
    local effect='KA_SINGLES_SUPPORT_67_'..id
    mod.content.move_effects:register(effect,{kind='primary',accuracyChecked=id=='QUASH',
      kascSinglesSupport67=M.OWNER,run=fail})
    for _,alias in ipairs(opts.species.moveIds(id))do
      if mod.content.moves:get(alias)then
        aliases[alias]=effect
        mod.content.moves:patch(alias,{effect=effect,backendMoveOwner=M.OWNER,
          backendMoveNumber=spec[1],originGeneration=spec[2],
          backendLearnsetRevision=old.backendLearnsetRevision or 1})
      end
    end
    aliases[id]=effect
    for i=#opts.catalog.unsupportedStatus,1,-1 do
      if opts.catalog.unsupportedStatus[i]==id then table.remove(opts.catalog.unsupportedStatus,i)end
    end
  end
  -- No persistent state, PP writer, action reordering or temporary effects:
  -- the engine owns declaration, attempt cost, protection and move calling.
  if opts.supportLog and opts.supportLog.registerSegment then
    opts.supportLog.registerSegment({segmentId=M.CARD_ID,cardId=M.CARD_ID,
      schema='kasc.optional-feature-card/v1',version='1.0.0',owner=M.OWNER,active=true,
      dependencyStatus='native-single-battle',providerStatus='canonical-no-partner-failure',
      buildReceiptId='docs/SINGLES_SUPPORT_67.md',rollbackReceiptId='docs/SINGLES_SUPPORT_67.md'})
  end
  return M
end
