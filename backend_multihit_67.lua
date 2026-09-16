-- Gen3-7 ordinary multi-hit attacks reuse the native single-hit pipeline,
-- but calculate damage/crit and resolve reactions for each strike.
-- Beat Up / Triple Kick require their own different rules, not this card.
return function(mod,opts)
  local Effects=require('src.battle.EffectRegistry')
  local Battle=require('src.battle.BattleState')
  local M={CARD_ID='KASC-67-MULTIHIT',OWNER='kasc.multihit/v1'}
  local moves={}
  -- Ordinary pre-VII moves retain their historical profile. Audited special
  -- additions below must present their own effect/ownership receipt.
  for id,row in pairs(opts.facts.data.moves)do
    local meta=row.meta
    if row.generation<=6 and meta and id~='BEAT_UP' and id~='TRIPLE_KICK'
        and (meta.min_hits==2 and (meta.max_hits==2 or meta.max_hits==5)) then
      for _,alias in ipairs(opts.species.moveIds(id))do
        moves[alias]={min=meta.min_hits,max=meta.max_hits,generation=row.generation}
      end
    end
  end
  function M.profile(b,ctx)
    if getmetatable(b)~=Battle or b.demo or b.kind=='link' or b.result then return end
    local marker=b.data and b.data.move_effects and b.data.move_effects.ATTACK_TWICE_EFFECT
    if not marker or marker.kascMultihitOwner67~=M.OWNER then return end
    local bash=mod.exports and mod.exports.pokemonDoubleIronBash67
    if bash then local special,gen=bash.profile(b,ctx);if special then return special,gen end end
    local bonds=mod.exports and mod.exports.pokemonBondForms67
    if bonds then local row,gen=bonds.shurikenProfile(b,ctx);if row then return row,gen end end
    local epoch=opts.status.epoch(b)
    local row=ctx and ctx.move and moves[ctx.move.id]
    if not row or not epoch or epoch<3 or epoch>7 or row.generation>epoch then return end
    return row,epoch
  end
  function M.hitCount(b,row,epoch,user)
    if row.min==row.max then return row.max end
    if user and user.mon and user.mon.hp>0 and opts.abilities
        and opts.abilities.activeAbility(b,user)=='SKILL_LINK'then return row.max end
    if epoch<=4 then return ({2,2,2,3,3,3,4,5})[b.rng(1,8)]end
    local roll=b.rng(1,100)
    return roll<=35 and 2 or roll<=70 and 3 or roll<=85 and 4 or 5
  end
  function M.run(original,b,ctx,record)
    local row,epoch=M.profile(b,ctx)
    if not row then return original(b,ctx,record)end
    local selected={};for k,v in pairs(record or {})do selected[k]=v end
    local count
    selected.hitCount=function()
      if selected.neverMiss and not count then count=M.hitCount(b,row,epoch,ctx.user)end
      return 1
    end
    local rawAccuracy,previous=rawget(b,'accuracyRoll'),b.accuracyRoll
    local oldAnim=b.moveAnimRow
    local rawFaint,previousFaint=rawget(b,'onFaint'),b.onFaint
    local pendingFaints,seen={},{}
    b.onFaint=function(self,who)
      if who~=ctx.user and who~=ctx.target then return previousFaint(self,who)end
      if not seen[who] then seen[who]=true;pendingFaints[#pendingFaints+1]=who end
    end
    local startedAsleep=ctx.user.mon.status=='SLP'
    local firstAccuracy=true
    b.accuracyRoll=function(self,move,user,target)
      if move~=ctx.move or user~=ctx.user or target~=ctx.target then
        return previous(self,move,user,target)
      end
      if not firstAccuracy then return true end
      firstAccuracy=false
      local hit=previous(self,move,user,target)
      if hit then count=M.hitCount(b,row,epoch,ctx.user)end
      return hit
    end
    local function execute()
      local hit,total,landed,broke=1,0,0,false
      while hit<=(count or 1) do
        if ctx.user.mon.hp<=0 or ctx.target.mon.hp<=0 then break end
        if hit>1 and ctx.user.mon.status=='SLP'
            and not (startedAsleep and ctx.isCalled and epoch~=4) then break end
        if hit>1 then
          b.moveAnimRow=b:animNext(ctx.move.id,ctx.user.isPlayer)
          selected.beforeAccuracy=nil
        end
        local single=Effects.makeCtx(b,ctx.user,ctx.target,ctx.move,ctx.moveInst,ctx.isCalled)
        original(b,single,selected)
        if single.totalDealt==nil then break end
        landed=landed+1;total=total+single.totalDealt
        broke=broke or single.brokeSub
        ctx.rawDamage,ctx.hitSfx=single.rawDamage,single.hitSfx
        hit=hit+1
      end
      ctx.hits,ctx.totalDealt,ctx.brokeSub=landed,total,broke
      if landed>1 then
        b:sayNext(b:romText(ctx.user.isPlayer and '_MultiHitText' or '_HitXTimesText',
          ctx.user.isPlayer and 'Hit the enemy\n%d times!' or 'Hit %d times!',landed))
      end
      -- Keep the hit-count message before native faint/EXP/finish queues.
      for _,who in ipairs(pendingFaints)do previousFaint(b,who)end
    end
    local ok,err=pcall(execute)
    b.accuracyRoll=rawAccuracy;b.moveAnimRow=oldAnim;b.onFaint=rawFaint
    if not ok then error(err,0)end
  end
  function M.install()
    Effects._kascMultihitOwner67=M
    if Effects._kascMultihitWrapped67 then return end
    local original=Effects.runDamaging
    Effects.runDamaging=function(b,ctx,record)
      return Effects._kascMultihitOwner67.run(original,b,ctx,record)
    end
    Effects._kascMultihitWrapped67=true
  end
  mod.content.move_effects:patch('ATTACK_TWICE_EFFECT',{kascMultihitOwner67=M.OWNER})
  M.install()
  if opts.supportLog and opts.supportLog.registerSegment then
    opts.supportLog.registerSegment({segmentId=M.CARD_ID,cardId=M.CARD_ID,
      schema='kasc.optional-feature-card/v1',version='1.0.0',owner=M.OWNER,
      active=true,dependencyStatus='native-single-hit-and-contact-pipeline',
      providerStatus='gen3-7-ordinary-multihit',
      buildReceiptId='docs/WAVE_W_ABILITIES_20260908.md',
      rollbackReceiptId='docs/WAVE_W_ABILITIES_20260908.md'})
  end
  return M
end
