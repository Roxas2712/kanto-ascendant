-- Historical status gates on the Gen-I host; native lifecycle stays owned
-- by StatusRegistry/Status and the existing KASC ability adapter.
return function(mod,opts)
  local M={CARD_ID='KASC-67-STATUS-RULES',OWNER='kasc.status-rules/v1'}
  local rules=assert(opts.rules)
  local known={SLP=true,PAR=true,PSN=true,BRN=true,FRZ=true}
  local powder={SLEEP_POWDER=true,STUN_SPORE=true,POISON_POWDER=true,POISONPOWDER=true,SPORE=true}
  local soundSleep={SING=true,GRASS_WHISTLE=true}
  local aliases={}
  for id in pairs(opts.facts.data.moves)do
    for _,alias in ipairs(opts.species.moveIds(id))do aliases[alias]=id end
  end
  mod.content.move_effects:patch('PARALYZE_EFFECT',{kascStatusRulesOwner67=M.OWNER})
  function M.epoch(b)
    if not b or b.demo or b.kind=='link' then return end
    local game=b.game
    local record=game and game.data and game.data.move_effects
      and game.data.move_effects.PARALYZE_EFFECT
    if not record or record.kascStatusRulesOwner67~=M.OWNER then return end
    local receipt=b.kascGenerationRulesReceipt
    if not receipt then
      local md=game.save and game.save.modData and game.save.modData[mod.id]
      local s=md and md[rules.SAVE_KEY]
      receipt=s and {mode=s.activeMode,activeEpoch=s.activeEpoch}
    end
    if receipt and receipt.mode~='off' then return tonumber(receipt.activeEpoch)end
  end
  local function has(who,id)
    for _,t in ipairs(who.curTypes or {})do if t==id then return true end end
    return false
  end
  function M.inflict(original,b,target,status,options)
    local secret=mod.exports and mod.exports.pokemonSecretPower67
    local authored=secret and secret.authorizedStatusEpoch(b,target,status,options)
    local psycho=mod.exports and mod.exports.pokemonPsychoShift67
    authored=authored or psycho and psycho.authorizedStatusEpoch(b,target,status,options)
    local epoch=authored or M.epoch(b)
    if not epoch or epoch<2 or not known[status] then return original(b,target,status,options)end
    local o=options or {}
    local source=aliases[o.source] or o.source
    if target.mon.hp<=0 or target.mon.status then return {} end
    local move=o.source and b.data.moves[o.source]
    local sound=epoch>=6 and soundSleep[source] and status=='SLP'
    -- A Substitute created AFTER Yawn does not intercept its delayed sleep.
    -- Require the installed effect's explicit receipt; ordinary sleep moves
    -- and even an ordinary direct Yawn infliction keep the normal gate.
    local yawn=b.data.move_effects.KA_DELAYED_YAWN_67
    local delayed=source=='YAWN' and status=='SLP' and not o.secondary
      and o.kascDelayedSleep67=='kasc.delayed-sleep/v1'
      and yawn and yawn.kascDelayedSleep67==o.kascDelayedSleep67
    if target.substituteHP and (o.secondary or move and source~='REST')
        and not sound and not delayed then return {} end
    if status=='PSN' and has(target,'STEEL')
        and not (epoch==2 and source=='TWINEEDLE' and o.secondary) then return {} end
    if status=='PAR' and epoch>=6 and has(target,'ELECTRIC') then return {} end
    if epoch>=6 and powder[source] and has(target,'GRASS') then return {} end
    -- Only Gen I prohibits every matching-type secondary (e.g. Body Slam
    -- vs Normal). Gates above already handled Substitute; native per-status
    -- type rules and ability immunity must still run with the real move type.
    -- Copy options: do not mutate the move caller's secondary flag.
    if o.secondary then
      local adjusted={};for k,v in pairs(o)do adjusted[k]=v end
      adjusted.secondary=false;adjusted.kascOriginalSecondary67=true
      return original(b,target,status,adjusted)
    end
    return original(b,target,status,options)
  end
  local Registry=require('src.battle.StatusRegistry')
  Registry._kascStatusRulesOwner67=M
  if not Registry._kascStatusRulesWrapped67 then
    local original=Registry.inflict
    Registry.inflict=function(...)
      return Registry._kascStatusRulesOwner67.inflict(original,...)
    end
    Registry._kascStatusRulesWrapped67=true
  end
  local ailment={PAR=1,FRZ=3,BRN=4,PSN=5}
  local nativeSides={}
  for status,id in pairs({PSN='POISON_SIDE_EFFECT1',BRN='BURN_SIDE_EFFECT1',
    FRZ='FREEZE_SIDE_EFFECT1',PAR='PARALYZE_SIDE_EFFECT1'})do
    nativeSides[status]=mod.content.move_effects:get(id).run
  end
  function M.secondary(original,status,ctx)
    local epoch=M.epoch(ctx.battle)
    if not epoch or epoch<2 then return original(ctx)end
    local id=aliases[ctx.move.id]
    local base=id and opts.facts.data.moves[id]
    local row=id and opts.facts.move(id,math.max(epoch,base and base.generation or epoch))
    if not row or not row.meta or row.meta.meta_ailment_id~=ailment[status] then
      return original(ctx)
    end
    -- Damage pipeline reports a substitute which broke during this hit.
    -- The registry alone cannot see that after substituteHP was removed.
    if ctx.target.substituteHP or ctx.brokeSub or ctx.target.mon.hp<=0 then return {} end
    if ctx.move.type=='FIRE' and ctx.target.mon.status=='FRZ' then
      return original(ctx) -- native thaw text/lifecycle, independent of burn roll
    end
    local chance=tonumber(row.effectChance) or tonumber(row.meta.ailment_chance) or 0
    local ability=opts.abilities and opts.abilities()
    if epoch>=3 and ability and ability.secondaryChance then
      chance=ability.secondaryChance(ctx,chance)
    end
    local success=epoch==2 and ctx.rng(0,255)<math.floor(chance*255/100)
      or epoch>2 and ctx.rng(1,100)<=chance
    if not success then return {} end
    return ctx.inflict(ctx.target,status,{moveType=ctx.move.type,
      secondary=true,source=ctx.move.id})
  end
  for id,status in pairs({PARALYZE_SIDE_EFFECT1='PAR',PARALYZE_SIDE_EFFECT2='PAR',
    FREEZE_SIDE_EFFECT1='FRZ',BURN_SIDE_EFFECT1='BRN',BURN_SIDE_EFFECT2='BRN',
    POISON_SIDE_EFFECT1='PSN',POISON_SIDE_EFFECT2='PSN',TWINEEDLE_EFFECT='PSN'})do
    local record=mod.content.move_effects:get(id)
    if record and record.run then
      local original=record.run
      mod.content.move_effects:patch(id,{run=function(ctx)return M.secondary(original,status,ctx)end})
    end
  end
  -- Earlier Crystal move aliases may already exist with a plain-damage
  -- placeholder, causing the later catalog to preserve a missing effect.
  -- Restore this verified identity without replacing other owners
  -- or changing their behavior in Gen I/AUS/classic links.
  local missingSide={SLUDGE_BOMB='PSN',FLAME_WHEEL='BRN',POWDER_SNOW='FRZ',SPARK='PAR'}
  local plain=mod.content.move_effects:get('NO_ADDITIONAL_EFFECT')
  local plainRun=plain and plain.run or function()return {}end
  mod.content.move_effects:patch('NO_ADDITIONAL_EFFECT',{run=function(ctx)
    local epoch=M.epoch(ctx.battle)
    local status=missingSide[aliases[ctx.move.id]]
    if epoch and epoch>=2 and status then return M.secondary(nativeSides[status],status,ctx)end
    return plainRun(ctx)
  end})
  -- A defrost move bypasses only the freeze gate, not flinch, Disable,
  -- confusion or a forfeited turn. Do not temporarily clear the mon's
  -- status while those checks execute. Crystal thaws after the move;
  -- later profiles thaw when the move actually begins (even on a miss).
  local defrost={FLAME_WHEEL=true,SACRED_FIRE=true,SIZZLY_SLIDE=true,BURN_UP=true}
  local selected=setmetatable({},{__mode='k'})
  function M.selfThawEpoch(b,who,id)
    local epoch=M.epoch(b)
    if epoch and epoch>=2 and who.mon.status=='FRZ'
      and defrost[aliases[id] or id] and b.data.moves[id] then return epoch end
  end
  function M.beforeMove(original,who,rng,b,id)
    local previous=selected[who]
    selected[who]=M.selfThawEpoch(b,who,id) and id or nil
    local ok,canMove,msgs,selfHit=pcall(original,who,rng,b,id)
    selected[who]=previous
    if not ok then error(canMove,0)end
    return canMove,msgs,selfHit
  end
  local frozen=mod.content.statuses:get('FRZ').beforeMove
  mod.content.statuses:patch('FRZ',{beforeMove=function(who,rng,b)
    if selected[who] and M.selfThawEpoch(b,who,selected[who]) then return true,{}end
    return frozen(who,rng,b)
  end})
  local function thaw(b,who)
    if who.mon.status~='FRZ' then return end
    who.mon.status=nil
    b:sayStatusMsg(who,b:romText('_FireDefrostedText','Fire defrosted\n%s!',who.name))
  end
  function M.performMove(original,b,who,target,inst,...)
    local epoch=M.selfThawEpoch(b,who,inst.id)
    if epoch and epoch>=3 then thaw(b,who)end
    local result=original(b,who,target,inst,...)
    if epoch==2 then thaw(b,who)end
    return result
  end
  local Status=require('src.battle.Status')
  local Battle=require('src.battle.BattleState')
  Status._kascDefrostOwner67=M
  Battle._kascDefrostOwner67=M
  if not Status._kascDefrostWrapped67 then
    local original=Status.beforeMove
    Status.beforeMove=function(...)
      return Status._kascDefrostOwner67.beforeMove(original,...)
    end
    Status._kascDefrostWrapped67=true
  end
  if not Battle._kascDefrostWrapped67 then
    local original=Battle.performMove
    Battle.performMove=function(...)
      return Battle._kascDefrostOwner67.performMove(original,...)
    end
    Battle._kascDefrostWrapped67=true
  end
  if opts.supportLog and opts.supportLog.registerSegment then
    opts.supportLog.registerSegment({segmentId=M.CARD_ID,cardId=M.CARD_ID,
      schema='kasc.optional-feature-card/v1',version='1.0.0',owner=M.OWNER,
      active=true,dependencyStatus='native-status-registry-and-generation-receipt',
      providerStatus='gen2-plus-status-immunities',
      buildReceiptId='docs/BACKEND_STATUS_RULES_67.md',
      rollbackReceiptId='docs/NEW_RC_CARD_MATRIX_20260907.md'})
  end
  return M
end
