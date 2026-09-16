-- Reuse native party screens and lifecycle; no free attack or extra turn.
-- Scope receipts are transient. Checkpoint capture refuses a pending choice.
return function(mod,opts)
  local B=require('src.battle.BattleState')
  local A,F=opts.abilities,opts.switching;local tr=opts.i18n.text
  local M={CARD_ID='KASC-67-EMERGENCY-EXIT',OWNER='kasc.emergency-exit/v1'}
  local frames=setmetatable({},{__mode='k'})
  local pending=setmetatable({},{__mode='k'})
  function M.isPending(w)return pending[w]==true end
  local entryHP=setmetatable({},{__mode='k'})
  local names={WIMP_OUT={'Wimp Out!','Reißaus!'},EMERGENCY_EXIT={'Emergency Exit!','Rückzug!'}}
  local function active(b,w)return w and(w==b.player or w==b.enemy)and w.mon and w.mon.hp>0 end
  local function maxHP(w)return tonumber(w.mon.stats and w.mon.stats.hp)or 0 end
  local function crossed(w,before)return maxHP(w)>0 and before*2>maxHP(w)and w.mon.hp*2<=maxHP(w)end
  function M.epoch(b)
    local mark=b and b.data and b.data.move_effects and b.data.move_effects.HEAL_EFFECT
    return mark and mark.kascEmergencyExit67==M.OWNER and F.epoch(b)==7 and 7 or nil
  end
  function M.eligible(b,w)
    if not M.epoch(b)or not active(b,w)or maxHP(w)<=0 or w.mon.hp*2>maxHP(w)
        or F.isPending(w)then return false end
    local id=A.activeAbility(b,w);if not names[id]then return false end
    if b.kind=='wild'then
      if b.kaRocketNoEscape or b.kaMythicEcho then return false end
    elseif b.kind~='trainer'or #F.candidates(b,w)==0 then return false end
    return id
  end
  function M.choose(b,w,mon,menu)
    if not pending[w]or not M.eligible(b,w)then
      pending[w]=nil;if menu then menu:close()end;return false
    end
    local pick
    for _,row in ipairs(F.candidates(b,w))do if row.mon==mon then pick=row;break end end
    if not pick then
      if menu and menu.refuse then menu:refuse(tr('Choose another healthy Pokemon.','Wähle ein anderes kampffähiges Pokémon.'))end
      return false
    end
    pending[w]=nil;if menu then menu:close()end
    b.nextInsert=0
    return F.swap(b,w,pick,{voluntary=true,sourceCard=M.CARD_ID})
  end
  function M.openChoice(b,w)
    b:uiNext(function()
      -- Queue UI factories must always return a screen: the engine pushes
      -- their result unconditionally. choose/onCancel handle stale state.
      return b:buildScreen('PartyMenu',{battle=b,party=b:playerPartyView(),
        forceSwitch=true,keepOpen=true,
        onSwitch=function(mon,menu)return M.choose(b,w,mon,menu)end,
        -- The native PartyMenu allows B even in forceSwitch mode. A mandatory
        -- living-mon replacement has no fainted-menu guard to reopen it.
        -- Requeue through the same provider before any remaining battle action.
        onCancel=function()
          b.nextInsert=0
          if pending[w]and M.eligible(b,w)then M.openChoice(b,w)else pending[w]=nil end
        end})
    end)
  end
  function M.queue(b,w)
    if pending[w]or not M.eligible(b,w)then return false end
    pending[w]=true
    b:actNext(function()
      -- The native action wrapper otherwise schedules its berry checkpoint
      -- after this move-owned continuation. Settle HP berries first; the
      -- later ordinary checkpoint sees the consumed item and cannot heal twice.
      if active(b,w)then opts.berries.apply(b,true,w,true)end
      local id=M.eligible(b,w)
      if not id then pending[w]=nil;return end
      b:sayNext(tr(unpack(names[id])))
      if b.kind=='wild'then
        pending[w]=nil;b.result='run';b.afterQueue='finish'
        b:sayNext(tr('The wild battle ended!','Der wilde Kampf wurde beendet!'));return
      end
      if w==b.enemy then
        -- Prefer a healthy reserve deterministically; never mutate the
        -- trainer roster or borrow an arbitrary species from the registry.
        local pick,best=nil,-1
        for _,row in ipairs(F.candidates(b,w))do
          local score=row.mon.hp/math.max(1,row.mon.stats.hp)
          if score>best then pick,best=row,score end
        end
        if pick then M.choose(b,w,pick.mon)else pending[w]=nil end
      else
        M.openChoice(b,w)
      end
    end)
    return true
  end
  local function pack(...)return{n=select('#',...),...}end
  function M.scope(b,kind,user,move,fn)
    if not M.epoch(b)then return fn()end
    local previous=frames[b]
    local order=kind=='move'and{user,user==b.player and b.enemy or b.player}or{b.player,b.enemy}
    local frame={kind=kind,user=user,move=move,loss={},before={},order=order}
    for _,w in ipairs(order)do if w and w.mon then frame.before[w]=w.mon.hp end end
    frames[b]=frame
    local result=pack(pcall(fn));frames[b]=previous
    if not result[1]then error(result[2],0)end
    -- Contact/recoil can make both sides cross the threshold: the attacker
    -- reacts before the struck holder, never in Lua table-hash order.
    for _,w in ipairs(frame.order)do
      local before=frame.before[w]
      -- Residual controllers may write HP directly. For move scopes only
      -- actual applyDamage calls count: Substitute/Belly Drum/Pain Split
      -- costs or HP assignments must not masquerade as attacks.
      local crossing=frame.loss[w]or kind=='residual'and crossed(w,before)
      local suppressed=kind=='move'and w~=user and A.sheerForce(b,user,move)
      if crossing and not suppressed then M.queue(b,w)end
    end
    return unpack(result,2,result.n)
  end
  function M.damage(b,w,amount,fn)
    local frame=frames[b];local before=w and w.mon and w.mon.hp
    local result=pack(fn())
    if frame and before and active(b,w)and crossed(w,before)then frame.loss[w]=true end
    return unpack(result,1,result.n)
  end
  function M.validateCheckpoint(b)
    if pending[b.player]or pending[b.enemy]then return false,'emergency_switch_unsettled'end
    return true
  end
  B._kascEmergencyExit67=M
  if not B._kascEmergencyExitWrapped67 then
    local perform,damage,residual=B.performMove,B.applyDamage,B.endOfTurn
    B.performMove=function(b,u,t,slot,...)
      local args=pack(...);local id=type(slot)=='table'and slot.id
      return B._kascEmergencyExit67.scope(b,'move',u,b.data.moves[id],function()
        return perform(b,u,t,slot,unpack(args,1,args.n))end)
    end
    B.applyDamage=function(b,w,amount)
      return B._kascEmergencyExit67.damage(b,w,amount,function()return damage(b,w,amount)end)
    end
    B.endOfTurn=function(b,...)
      local args=pack(...)
      return B._kascEmergencyExit67.scope(b,'residual',nil,nil,function()return residual(b,unpack(args,1,args.n))end)
    end
    B._kascEmergencyExitWrapped67=true
  end
  mod.events:on('battle.battler_switched',function(ev)
    local w=ev.battler;if M.epoch(ev.battle)and w and w.mon then entryHP[w]=w.mon.hp end
    if ev.previous then pending[ev.previous]=nil end
  end,60000)
  mod.events:on('battle.battler_switched',function(ev)
    local w=ev.battler;local before=w and entryHP[w];if w then entryHP[w]=nil end
    if before and active(ev.battle,w)and crossed(w,before)then M.queue(ev.battle,w)end
  end,-20000)
  mod.events:on('battle.ended',function(ev)
    local b=ev.battle;pending[b.player]=nil;pending[b.enemy]=nil;frames[b]=nil
  end,80)
  mod.content.move_effects:patch('HEAL_EFFECT',{kascEmergencyExit67=M.OWNER})
  if opts.supportLog and opts.supportLog.registerSegment then
    opts.supportLog.registerSegment({segmentId=M.CARD_ID,cardId=M.CARD_ID,schema='kasc.optional-feature-card/v1',
      version='1.0.0',owner=M.OWNER,active=true,dependencyStatus='forced-switch-and-hp-berry-barrier',
      providerStatus='native-party-screen-selection',buildReceiptId='docs/EMERGENCY_EXIT_67.md',
      rollbackReceiptId='docs/EMERGENCY_EXIT_67.md'})
  end
  return M
end
