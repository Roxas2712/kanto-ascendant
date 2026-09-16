-- Historical move properties shared by menus, teachers and native damage.
-- This is not an assertion that every catalogued special effect is supported.
return function(opts)
  local facts,species=assert(opts.facts),assert(opts.species)
  local M={CARD_ID='KASC-67-BACKEND-LIVE-MOVE-RULES',
    OWNER='kasc.backend.live-move-rules/v1',audit={}}
  local owners,cache={},{}
  local function refreshOwners()
    for id in pairs(facts.data.moves)do
      for _,native in ipairs(species.moveIds(id))do
        assert(not owners[native] or owners[native]==id,'ambiguous move alias '..native)
        owners[native]=id
      end
    end
  end
  local function projected(id,epoch)
    local key=id..':'..epoch
    if cache[key]==nil then
      local source=facts.move(id,id=='FAKE_OUT'and math.max(epoch,3)or epoch)
      cache[key]=source and {type=source.type,category=source.category,
        power=source.power,accuracy=source.accuracy,pp=source.pp,priority=source.priority,
        generation=source.effectiveGeneration} or false
    end
    return cache[key]
  end
  function M.apply(game,epoch)
    -- Later Cards can register genuine moves after this provider is bound.
    -- Refresh at a profile change, never in the per-hit calculation path.
    refreshOwners()
    local audit={activeEpoch=epoch,projected=0,notIntroduced=0,variablePower={}}
    for native,id in pairs(owners)do
      local record=game.data.moves[native]
      local row=record and projected(id,epoch)
      if row then
        record.type,record.category=row.type,row.category
        record.accuracy,record.pp=row.accuracy,row.pp
        if record.kascFirstAction67 then record.priority=row.priority end
        if row.power>0 or row.category=='status' then record.power=row.power
        else
          -- Fixed/variable-damage handlers may use an engine sentinel power.
          -- Their real formula belongs to the effect owner, not this adapter.
          audit.variablePower[native]=true
        end
        audit.projected=audit.projected+1
      elseif record then audit.notIntroduced=audit.notIntroduced+1 end
    end
    M.audit=audit
    return true,audit
  end
  if opts.supportLog and type(opts.supportLog.registerSegment)=='function' then
    opts.supportLog.registerSegment({segmentId=M.CARD_ID,cardId=M.CARD_ID,
      schema='kasc.optional-feature-card/v1',version='1.0.0',owner=M.OWNER,
      active=true,dependencyStatus='pinned-local-data',
      providerStatus='historical-properties-only',
      buildReceiptId='docs/BACKEND_GIFT_MOVESETS_GENERATIONS_20260907.md',
      rollbackReceiptId='docs/NEW_RC_CARD_MATRIX_20260907.md'})
  end
  return M
end
