-- Recycle restores a genuine consumed-item receipt. Acquisition, theft,
-- held-slot editing, and battle-only Harvest rolls remain separate owners.
return function(mod,opts)
  local M={CARD_ID='KASC-67-RECYCLE',OWNER='kasc.recycle/v1'}
  local tr=opts.i18n.text
  local effect='KA_RECYCLE_67'
  function M.canCast(b,w)return not not opts.consumption.candidate(b,w,false)end
  function M.cast(ctx)
    local b,w=ctx.battle,ctx.user
    -- An available gift move keeps its behaviour in an earlier manual era.
    -- Gen I has no active held-item consumption; OFF/demo/links stay closed.
    local id,def=opts.consumption.restoreConsumed(b,w,false)
    if not id then return {tr('But, it failed!','Doch es schlug fehl!'),failed=true}end
    local names=def.names or{}
    b:sayNext(tr('%s\nwas recycled!','%s\nwurde aufbereitet!')
      :format(tr(names.en or def.name or id,names.de or def.name or id)))
    b:drainNext()
    opts.consumption.activateRestored(b,w,true)
    return {}
  end
  local move=assert(mod.content.moves:get('RECYCLE'),'missing Recycle data')
  assert(move.effect=='KA_GEN_MOVE_UNSUPPORTED_RECYCLE','foreign Recycle owner')
  local function copy(v)
    if type(v)~='table'then return v end
    local out={};for k,x in pairs(v)do out[k]=copy(x)end;return out
  end
  local anim=assert(mod.content.battle_anims:get('RECOVER'),'missing native recovery animation')
  assert(anim.seq and #anim.seq>0,'empty native recovery animation')
  -- This owner queues success text and immediate berry activation itself.
  -- A primary run returning no text makes the native engine cancel its
  -- animation. The full perform path preserves the queued success sequence.
  mod.content.move_effects:register(effect,{kind='full',accuracyChecked=false,kascRecycle67=M.OWNER,
    perform=function(ctx)
      local result=M.cast(ctx)
      if result.failed then
        ctx.battle:cancelMoveAnim()
        for _,msg in ipairs(result)do ctx.battle:sayNext(msg)end
        ctx.battle:drainNext()
      end
    end})
  mod.content.moves:patch('RECYCLE',{effect=effect})
  mod.content.battle_anims:patch('RECYCLE',copy(anim))
  for i=#opts.catalog.unsupportedStatus,1,-1 do
    if opts.catalog.unsupportedStatus[i]=='RECYCLE'then table.remove(opts.catalog.unsupportedStatus,i)end
  end
  M.animationReview={parts={'RECOVER'},receipt='qa/gen6-wave15-alignment-20260909/RECYCLE-REVIEW.md'}
  if opts.supportLog and opts.supportLog.registerSegment then
    opts.supportLog.registerSegment({segmentId=M.CARD_ID,cardId=M.CARD_ID,
      schema='kasc.optional-feature-card/v1',version='1.0.0',owner=M.OWNER,active=true,
      dependencyStatus='native-consumption-and-held-effects',providerStatus='recycle-consumed-items',
      buildReceiptId='docs/GEN6_WAVE15_SCOPE_20260909.md',rollbackReceiptId='docs/GEN6_WAVE15_SCOPE_20260909.md'})
  end
  return M
end
