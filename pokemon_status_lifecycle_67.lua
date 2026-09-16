-- Era-bound sleep/freeze/paralysis lifecycle on the native battle host.
-- Counter state belongs to the saved Pokemon, not a disposable battler.
return function(mod,opts)
  local M={CARD_ID='KASC-67-STATUS-LIFECYCLE',OWNER='kasc.status-lifecycle/v1',KEY='sleepLifecycle67'}
  local Status=require('src.battle.Status')
  local Battle=require('src.battle.BattleState')
  local romText=require('src.core.RomText')
  local frames=setmetatable({},{__mode='k'})
  local entered=setmetatable({},{__mode='k'})
  local activeBattle
  local function pack(...)return {n=select('#',...),...}end
  function M.epoch(b)
    local row=b and b.data and b.data.move_effects and b.data.move_effects.HEAL_EFFECT
    local gen=row and row.kascStatusLifecycle67==M.OWNER and opts.status.epoch(b)
    if getmetatable(b)==Battle and not b.result and gen and gen>=2 and gen<=7 then return gen end
  end
  local function bucket(mon,create)
    if create then
      mon.extra=mon.extra or {};mon.extra.kanto_ascendant=mon.extra.kanto_ascendant or {}
    end
    return mon.extra and mon.extra.kanto_ascendant
  end
  local function integer(v,lo,hi)
    return type(v)=='number' and v%1==0 and v>=lo and v<=hi
  end
  local function valid(row)
    return type(row)=='table' and row.version==1 and integer(row.initial,1,7)
      and integer(row.remaining,1,row.initial)
      and (row.skipped==nil or integer(row.skipped,0,row.initial-row.remaining))
  end
  local function discardInactive(b,who)
    local marker=b and b.data and b.data.move_effects and b.data.move_effects.HEAL_EFFECT
    if getmetatable(b)~=Battle or b.demo or b.kind=='link' or b.result
        or not marker or marker.kascStatusLifecycle67~=M.OWNER then return end
    local data=bucket(who.mon,false)
    if data then data[M.KEY]=nil end
  end
  function M.clear(who,b)
    local data=bucket(who.mon,false)
    if data then data[M.KEY]=nil end
    who.sleepTurns=nil;who.nightmare=nil
    opts.abilities.onStatusCured(b,who)
  end
  function M.setSleep(who,count)
    assert(integer(count,1,7),'invalid sleep duration')
    local row={version=1,initial=count,remaining=count}
    bucket(who.mon,true)[M.KEY]=row;who.sleepTurns=count;who.nightmare=nil
    return row
  end
  local function duration(b,gen)
    -- Inclusive native RNG; the counter also includes the wake-up action.
    return b.rng(2,gen==2 and 7 or gen<=4 and 5 or 4)
  end
  function M.sleepState(b,who)
    if who.mon.status~='SLP' then M.clear(who,b);return end
    local data=bucket(who.mon,false);local row=data and data[M.KEY]
    if valid(row)then who.sleepTurns=row.remaining;return row end
    -- Old saves/checkpoints already have a native counter when available.
    -- Missing counters are seeded once, never once per switch or reload.
    return M.setSleep(who,integer(who.sleepTurns,1,7) and who.sleepTurns
      or duration(b,assert(M.epoch(b))))
  end
  function M.validateCheckpoint(b)
    for _,who in ipairs({b.player,b.enemy})do
      local data=who.mon and bucket(who.mon,false);local row=data and data[M.KEY]
      if row~=nil and not valid(row)then return false,'invalid sleep lifecycle state' end
      if M.epoch(b) and row and who.mon.status=='SLP' and who.sleepTurns~=nil
          and who.sleepTurns~=row.remaining then return false,'sleep counter disagreement' end
    end
    local token=b.field and b.field.tokens and b.field.tokens[M.OWNER]
    if token~=nil and not integer(token,0,b.turnCount or 0)then return false,'invalid freeze timeline' end
    return true
  end
  function M.inflict(original,b,who,options,display)
    local psycho=mod.exports and mod.exports.pokemonPsychoShift67
    local authored=psycho and psycho.authorizedStatusEpoch(b,who,'SLP',options)
    local gen=authored or M.epoch(b)
    if not gen then discardInactive(b,who);return original(b,who,options,display)end
    M.setSleep(who,duration(b,gen))
    return {romText(b.data,'_FellAsleepText','%s\nfell asleep!',display)}
  end
  function M.sleep(original,who,rng,b)
    if not M.epoch(b)then return original(who,rng,b)end
    if frames[who] and frames[who].checked then return true,{}end
    local row=M.sleepState(b,who)
    if not row then return true,{}end
    local step=opts.abilities.activeAbility(b,who)=='EARLY_BIRD' and 2 or 1
    row.remaining=row.remaining-step
    if row.remaining<=0 then
      who.mon.status=nil;M.clear(who,b)
      return true,{romText(b.data,'_WokeUpText','%s\nwoke up!',who.name)}
    end
    who.sleepTurns=row.remaining
    local moves=opts.sleepMoves and opts.sleepMoves()
    local usable=moves and moves.sleepUsable(b,frames[who] and frames[who].id) or false
    -- ADV restores consecutive Snore/Sleep Talk turns upon switching.
    -- Early Bird still restores one per action, not its two counter ticks.
    row.skipped=M.epoch(b)==3 and (usable and (row.skipped or 0)+1 or 0) or nil
    return usable,{romText(b.data,'_FastAsleepText','%s\nis fast asleep!',who.name)}
  end
  function M.rest(original,ctx)
    local gen=M.epoch(ctx.battle)
    if gen and gen>=3 and ctx.move.id=='REST' and ctx.user.mon.status=='SLP' then
      return {opts.i18n.text('But, it failed!','Doch es schlug fehl!'),failed=true}
    end
    local hp=ctx.user.mon.hp
    local result=original(ctx)
    if ctx.move.id=='REST' and ctx.user.mon.status=='SLP'
        and ctx.user.mon.hp>hp and ctx.user.sleepTurns==2 then
      if M.epoch(ctx.battle)then
        M.setSleep(ctx.user,3) -- two missed actions, then wake and act
      else discardInactive(ctx.battle,ctx.user)end
    end
    return result
  end
  function M.entry(ctx)
    local b=ctx.battle;local gen=M.epoch(b)
    if not gen then
      if b then for _,who in ipairs({b.player,b.enemy})do discardInactive(b,who)end end
      return
    end
    if ctx.previous and ctx.previous.mon.status~='SLP' then M.clear(ctx.previous,b)end
    for _,who in ipairs(ctx.battler and {ctx.battler} or {b.player,b.enemy})do
      if not entered[who] then
        entered[who]=true
        local row=M.sleepState(b,who)
        if row then
          if gen==3 then row.remaining=row.remaining+(row.skipped or 0) end
          row.skipped=nil;who.sleepTurns=row.remaining
        end
        if row and gen==5 then row.remaining=row.initial;who.sleepTurns=row.remaining end
      end
    end
  end
  local function thaw(b,who)
    who.mon.status=nil
    return opts.i18n.text('%s thawed out!','%s ist aufgetaut!'):format(who.name)
  end
  function M.freeze(original,who,rng,b)
    local gen=M.epoch(b)
    if not gen then return original(who,rng,b)end
    local frame=frames[who]
    if frame and frame.checked then return true,{}end
    local defrost=frame and opts.status.selfThawEpoch(b,who,frame.id)
    -- Gen III/IV roll before defrost moves; V+ bypass that roll.
    if (gen==2 or gen>=5) and defrost then return true,{}end
    if gen>=3 and rng(1,5)==1 then return true,{thaw(b,who)}end
    if defrost then return true,{}end
    return original(who,rng,b)
  end
  function M.endTurn(ctx)
    local b=ctx.battle
    if M.epoch(b)~=2 then return end
    b.field=b.field or {};b.field.tokens=b.field.tokens or {}
    local turn=b.turnCount or 0
    if b.field.tokens[M.OWNER]==turn then return end
    b.field.tokens[M.OWNER]=turn
    for _,who in ipairs({b.player,b.enemy})do
      if who.mon.hp>0 and who.mon.status=='FRZ' and b.rng(0,255)<25 then
        b:sayStatusMsg(who,thaw(b,who))
      end
    end
  end
  function M.paralysis(original,who,rng,b)
    local lock=mod.exports and mod.exports.pokemonMoveLock67
    if lock and lock.suspendsLateStatus(b,who)then return true,{}end
    local gen=M.epoch(b)
    if not gen or gen==2 then return original(who,rng,b)end
    -- Keep native messages and caller ordering; change only this roll.
    return original(who,function(lo,hi)
      if lo==0 and hi==255 then return rng(1,4)==1 and 0 or 255 end
      return rng(lo,hi)
    end,b)
  end
  function M.beforeMove(original,who,rng,b,id)
    local gen=M.epoch(b)
    if not gen then
      -- A later manual Gen-I/OFF battle uses the native counter exclusively.
      -- Discard only our stale extension, not the engine's status/counter.
      discardInactive(b,who)
      return original(who,rng,b,id)
    end
    local previous=frames[who];frames[who]={id=id}
    if who.mon.status~='SLP' then M.clear(who,b)end
    local initialConfusion=who.confusedTurns;local confusionRolled=false
    local function scopedRng(lo,hi)
      if gen==7 and not confusionRolled and initialConfusion and initialConfusion>1
          and who.confusedTurns==initialConfusion-1 and lo==0 and hi==255 then
        confusionRolled=true
        return rng(1,100)<=33 and 0 or 255
      end
      return rng(lo,hi)
    end
    local out=pack(pcall(function()
      local first={}
      -- II+ sleep/freeze precede flinch. Keep the rest of the native
      -- gauntlet, but do not run the same status handler twice.
      if not who.skipMove and (who.mon.status=='SLP' or who.mon.status=='FRZ')then
        local allowed,msgs=Status.recordFor(b.data.statuses,who.mon.status).beforeMove(who,rng,b)
        if not allowed then return false,msgs end
        first=msgs or {};frames[who].checked=true
      end
      local allowed,msgs,selfHit=original(who,scopedRng,b,id)
      for _,line in ipairs(msgs or {})do first[#first+1]=line end
      return allowed,first,selfHit
    end))
    frames[who]=previous
    if not out[1]then error(out[2],0)end
    return unpack(out,2,out.n)
  end
  -- Recharge stays with backend_flinch_effects_67: it also owns Crystal's
  -- preselected-action exception. Do not replace its preRechargeChecks.
  function M.scoped(original,b,...)
    local previous=activeBattle;activeBattle=b
    local out=pack(pcall(original,b,...));activeBattle=previous
    if not out[1]then error(out[2],0)end
    return unpack(out,2,out.n)
  end
  function M.penalty(original,who,stat,value)
    local gen=M.epoch(activeBattle)
    if gen and (who==activeBattle.player or who==activeBattle.enemy)
        and stat=='speed' and who.mon.status=='PAR' then
      -- Modern status penalties are not Gen-I stacked/baked stat glitches.
      return math.max(1,math.floor(value/(gen==7 and 2 or 4)))
    end
    return original(who,stat,value)
  end
  local slp=mod.content.statuses:get('SLP')
  local inflict,sleep=slp.onInflict,slp.beforeMove
  mod.content.statuses:patch('SLP',{
    onInflict=function(...)return M.inflict(inflict,...)end,
    beforeMove=function(...)return M.sleep(sleep,...)end})
  for id,fn in pairs({FRZ=M.freeze,PAR=M.paralysis})do
    local original=mod.content.statuses:get(id).beforeMove
    mod.content.statuses:patch(id,{beforeMove=function(...)return fn(original,...)end})
  end
  local heal=mod.content.move_effects:get('HEAL_EFFECT').run
  mod.content.move_effects:patch('HEAL_EFFECT',{
    run=function(ctx)return M.rest(heal,ctx)end,kascStatusLifecycle67=M.OWNER})
  Status._kascStatusLifecycle67=M;Battle._kascStatusLifecycle67=M
  function M.beginNonMoveTurn(b,kind)
    if not M.epoch(b)or kind=='tryRun'and b.kind=='trainer'then return end
    b.turnCount=(b.turnCount or 0)+1
    if Battle._kascFlinchOwner67 then Battle._kascFlinchOwner67.beforeTurn(b)end
    require('src.mods.Runtime').emit('battle.turn_started',{
      battle=b,turn=b.turnCount,playerAction={special=kind},enemyAction=nil})
  end
  if not Status._kascStatusLifecycleWrapped67 then
    local original=Status.beforeMove
    Status.beforeMove=function(...)return Status._kascStatusLifecycle67.beforeMove(original,...)end
    local penalty=Status.applyPenalty
    Status.applyPenalty=function(...)return Status._kascStatusLifecycle67.penalty(penalty,...)end
    Status._kascStatusLifecycleWrapped67=true
  end
  if not Battle._kascStatusLifecycleWrapped67 then
    for _,name in ipairs({'resolveTurn','executeAction','endOfTurn'})do
      local method=Battle[name]
      Battle[name]=function(...)return Battle._kascStatusLifecycle67.scoped(method,...)end
    end
    -- The Gen-I host advances its counter only in resolveTurn. Successful
    -- bag use, voluntary switching, throwing a ball and attempted wild
    -- escape spend a full modern turn as well. Rejected switches are caught
    -- by the outer trapping owner before reaching this wrapper.
    for _,name in ipairs({'resolveSwitch','itemUsed','throwBall','tryRun'})do
      local method=Battle[name]
      Battle[name]=function(b,...)
        Battle._kascStatusLifecycle67.beginNonMoveTurn(b,name)
        return method(b,...)
      end
    end
    Battle._kascStatusLifecycleWrapped67=true
  end
  mod.events:on('battle.started',M.entry,6900)
  mod.events:on('battle.battler_switched',M.entry,6900)
  mod.events:on('battle.turn_ended',M.endTurn,100)
  mod.events:on('battle.ended',function(ctx)
    local b=ctx.battle
    if b and b.field and b.field.tokens then b.field.tokens[M.OWNER]=nil end
  end,100)
  if opts.supportLog and opts.supportLog.registerSegment then
    opts.supportLog.registerSegment({segmentId=M.CARD_ID,cardId=M.CARD_ID,
      schema='kasc.optional-feature-card/v1',version='1.0.0',owner=M.OWNER,active=true,
      dependencyStatus='native-status-and-frozen-generation',providerStatus='historical-status-lifecycle',
      buildReceiptId='qa/gen6-wave15-alignment-20260909/STATUS-LIFECYCLE-REVIEW.md',
      rollbackReceiptId='qa/gen6-wave15-alignment-20260909/STATUS-LIFECYCLE-REVIEW.md'})
  end
  return M
end
