-- Battle-only Synchronize (III-VII). Provenance belongs to the infliction,
-- never to a guessed opponent or a persistent reference in the Pokemon save.
return function(mod,opts)
  local Battle=require('src.battle.BattleState')
  local Effects=require('src.battle.EffectRegistry')
  local Status=require('src.battle.StatusRegistry')
  local M={CARD_ID='KASC-67-SYNCHRONIZE',OWNER='kasc.synchronize/v1'}
  local reflected={PSN=true,BRN=true,PAR=true}
  local legacy=setmetatable({},{__mode='k'})
  function M.epoch(b)
    local row=b and b.data and b.data.move_effects and b.data.move_effects.HEAL_EFFECT
    local gen=row and row.kascSynchronize67==M.OWNER and opts.status.epoch(b)
    if getmetatable(b)==Battle and not b.result and gen and gen>=3 and gen<=7 then return gen end
  end
  local function living(b,who)
    return who and (who==b.player or who==b.enemy) and who.mon and who.mon.hp>0
  end
  function M.inflict(original,b,target,status,options)
    local gen=M.epoch(b)
    local o=options or {}
    local ctx=legacy[b]
    local source=o.kascStatusSource67 or ctx and ctx.target==target
      and ctx.move.id==o.source and ctx.user
    local eligible=gen and reflected[status] and not o.kascSynchronized67
      and source~=target and living(b,target) and living(b,source)
      and not target.mon.status and o.source~='TOXIC_SPIKES'
      and opts.abilities.activeAbility(b,target)=='SYNCHRONIZE'
    -- Corrosion shares this existing, explicit infliction provenance.
    -- Remove only type immunities for the synchronous poison check; the
    -- target's ability, Substitute, terrain and existing status still apply.
    local types=target.curTypes
    local corrosive=gen==7 and status=='PSN'and living(b,source)
      and opts.abilities.activeAbility(b,source)=='CORROSION'
    if corrosive then
      local view={};for _,kind in ipairs(types or{})do
        if kind~='POISON'and kind~='STEEL'then view[#view+1]=kind end
      end
      target.curTypes=view
    end
    -- Forward the proven source to other immunity owners as well. Do not
    -- mutate the caller's options or guess a source for items/hazards.
    local forwarded={};for k,v in pairs(o)do forwarded[k]=v end
    forwarded.kascStatusSource67=source
    local ok,messages=pcall(original,b,target,status,forwarded)
    if corrosive then target.curTypes=types end
    if not ok then error(messages,0)end
    -- Failed accuracy rolls do not call this owner; immunity/blocked status
    -- can return a message without inflicting anything. Check the result.
    if not eligible or target.mon.status~=status or not living(b,source) then return messages end
    local sub=source.substituteHP
    source.substituteHP=nil -- reflected status bypasses the source's substitute
    local ok,reply=pcall(Status.inflict,b,source,status,{
      source='SYNCHRONIZE',kascSynchronized67=true,kascStatusSource67=target,
      toxic=status=='PSN' and gen>=5 and o.toxic==true,
    })
    source.substituteHP=sub
    if not ok then error(reply,0)end
    local out={};for _,msg in ipairs(messages or {})do out[#out+1]=msg end
    out[#out+1]=opts.i18n.text('%s: Synchronize!','%s: Synchro!'):format(target.name)
    for _,msg in ipairs(reply or {})do out[#out+1]=msg end
    return out
  end
  function M.context(original,b,user,...)
    local ctx=original(b,user,...)
    if not M.epoch(b) then return ctx end
    local inflict=ctx.inflict
    ctx.inflict=function(who,status,options)
      local o={};for k,v in pairs(options or {})do o[k]=v end
      -- Self-status (Rest), items and passive hazards must not be mistaken
      -- for an opposing attack. Contact retaliation supplies its own owner.
      o.kascStatusSource67=user
      return inflict(who,status,o)
    end
    return ctx
  end
  mod.content.move_effects:patch('HEAL_EFFECT',{kascSynchronize67=M.OWNER})
  -- Native Gen-I primary handlers predate ctx.inflict and call the status
  -- registry directly. Supply provenance only while those exact records
  -- run, and only for their own target and move id (not unrelated events).
  for _,id in ipairs({'POISON_EFFECT','PARALYZE_EFFECT','SLEEP_EFFECT'})do
    local original=assert(mod.content.move_effects:get(id).run)
    mod.content.move_effects:patch(id,{run=function(ctx)
      if not M.epoch(ctx.battle)then return original(ctx)end
      local prior=legacy[ctx.battle];legacy[ctx.battle]=ctx
      local ok,messages=pcall(original,ctx);legacy[ctx.battle]=prior
      if not ok then error(messages,0)end
      return messages
    end})
  end
  Status._kascSynchronize67=M;Effects._kascSynchronize67=M
  if not Status._kascSynchronizeWrapped67 then
    local inflict=Status.inflict
    Status.inflict=function(...)return Status._kascSynchronize67.inflict(inflict,...)end
    local makeCtx=Effects.makeCtx
    Effects.makeCtx=function(...)return Effects._kascSynchronize67.context(makeCtx,...)end
    Status._kascSynchronizeWrapped67=true
  end
  if opts.supportLog and opts.supportLog.registerSegment then
    opts.supportLog.registerSegment({segmentId=M.CARD_ID,cardId=M.CARD_ID,
      schema='kasc.optional-feature-card/v1',version='1.0.0',owner=M.OWNER,active=true,
      dependencyStatus='native-status-and-move-context',providerStatus='battle-only-era-bound-reflection',
      buildReceiptId='docs/WAVE_W_ABILITIES_20260908.md',
      rollbackReceiptId='docs/WAVE_W_ABILITIES_20260908.md'})
  end
  return M
end
