-- Native selected-action interception; no second move/round or called AP.
return function(mod,opts)
  local B=require('src.battle.BattleState');local FX=require('src.battle.EffectRegistry')
  local Runtime=require('src.mods.Runtime');local Chart=require('src.battle.TypeChart')
  local M={CARD_ID='KASC-67-PURSUIT',OWNER='kasc.pursuit/v1',ID='PURSUIT'}
  local aliases={};for _,id in ipairs(opts.species.moveIds(M.ID))do aliases[id]=true end
  local plans=setmetatable({},{__mode='k'});local selecting=setmetatable({},{__mode='k'})
  local hits=setmetatable({},{__mode='k'});local pending=setmetatable({},{__mode='k'})
  local executing=setmetatable({},{__mode='k'});local resuming=setmetatable({},{__mode='k'})
  local replacements=setmetatable({},{__mode='k'});local effect='KA_PURSUIT_67'
  local function copy(v)if type(v)~='table'then return v end;local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r end
  local function pack(...)return{n=select('#',...),...}end
  local function integer(v,a,z)return type(v)=='number'and v%1==0 and v>=a and v<=z end
  local function live(w)local p=w and w.mon;return p and integer(p.hp,1,99999)and not w.fainted
    and not(p.egg or p.isEgg or p.is_egg or p.eggSpecies or p.species=='EGG')end
  local function side(b,w)return w==b.player and'player'or w==b.enemy and'enemy'or nil end
  local function other(key)return key=='player'and'enemy'or'player'end
  local function party(b,key)return key=='player'and b:playerPartyView()or b.enemyParty or{b.enemy.mon}end
  local function index(b,w)local key=side(b,w);if not key then return end
    for i,p in ipairs(party(b,key))do if i<=6 and p==w.mon then return i end end
  end
  local function slot(w,inst)for i,m in ipairs(w and w.curMoves or{})do if i<=4 and m==inst then return i end end end
  function M.epoch(b)
    local r=b and b.kascGenerationRulesReceipt;local marker=b and b.data and b.data.move_effects and b.data.move_effects[effect]
    return getmetatable(b)==B and not b.demo and b.kind~='link'and not b.result and r
      and(r.mode=='auto'or r.mode=='gen'..tostring(r.activeEpoch))
      and integer(r.activeEpoch,1,7)and marker and marker.kascPursuit67==M.OWNER and r.activeEpoch or nil
  end
  function M.profile(b,w,m)
    local gen=M.epoch(b);local e=gen and m and b.data.move_effects[m.effect]
    if not gen or not live(w)or not index(b,w)or not m or not aliases[m.id]
        or m.backendMoveOwner~=M.OWNER or m.backendMoveNumber~=228 or not e or e.kascPursuit67~=M.OWNER then return end
    if gen<2 and not(opts.rules.ownedGiftBattleCompatible(b.game,w.mon,b.data.pokemon[w.mon.species])
        and opts.rules.monMoveAvailable(b.game,w.mon,m.id,gen,true))then return end
    return math.max(2,gen)
  end
  local function ownedChoice(b,w,inst)
    if not slot(w,inst)then return end
    local m=b:moveDef(inst);local gen=M.profile(b,w,m)
    local unlimited=gen and M.epoch(b)==1 and not w.isPlayer and b.ruleset.enemyUnlimitedPP
    return gen and(unlimited or integer(inst.pp,1,99))and gen or nil
  end
  local function hasPursuit(b,w)
    for _,inst in ipairs(w and w.curMoves or{})do if ownedChoice(b,w,inst)then return true end end
  end
  local function bind(b,playerAction,enemyAction,cached)
    local p={turn=b.turnCount or 0}
    for _,key in ipairs({'player','enemy'})do local w=b[key]
      local action;if key=='player'then action=playerAction else action=enemyAction end
      p[key]={user=w,mon=w.mon,party=index(b,w),inst=action,
        spent=false,cachedClass=key=='enemy'and cached or false}
    end
    if ownedChoice(b,b.player,playerAction)or ownedChoice(b,b.enemy,enemyAction)then plans[b]=p end
    return p
  end
  local function lane(b,w)
    local p=plans[b];local key=side(b,w);local row=p and key and p[key]
    return M.epoch(b)and p and p.turn==(b.turnCount or 0)and row and row.user==w
      and row.mon==w.mon and row.party==index(b,w)and row or nil
  end
  function M.turnStarted(ev)
    local b=ev.battle;plans[b]=nil
    if M.epoch(b)then bind(b,ev.playerAction,ev.enemyAction,selecting[b]and selecting[b].cached)end
  end
  local function classDecision(b,action)
    if not b.enemyActionForced then action=b:trainerAIAction()or action end
    -- The real class decision has already been made, exactly once.
    b.enemyActionForced=true;return action
  end
  function M.enemyAction(original,b,...)
    local action=original(b,...);local f=selecting[b]
    if f and M.epoch(b)and ownedChoice(b,b.player,f.action)then
      action=classDecision(b,action);f.cached=true
    end;return action
  end
  function M.resolveTurn(original,b,action,...)
    if not M.epoch(b)or not ownedChoice(b,b.player,action)then return original(b,action,...)end
    local prior=selecting[b];selecting[b]={action=action}
    local out=pack(pcall(original,b,action,...));selecting[b]=prior
    if not out[1]then error(out[2],0)end;return unpack(out,2,out.n)
  end
  function M.order(nextOrder,a,am,z,zm,ctx)
    for b,p in pairs(plans)do
      if a==b.player and z==b.enemy and M.epoch(b)and p.turn==(b.turnCount or 0)
          and p.enemy.inst and p.enemy.inst.special=='aiSwitch'and ownedChoice(b,a,p.player.inst)then
        return false -- an actual selected switch precedes a normal move
      end
    end;return nextOrder(a,am,z,zm,ctx)
  end
  local function blocked(b,w)
    local owner=mod.exports.backendPartialTrapping67
    return owner and owner.blocked(b,w)or false
  end
  local function pickValid(b,w,pick)
    if not live(w)or not index(b,w)or type(pick)~='table'or not integer(pick.index,1,6)
        or pick.mon==w.mon or not live({mon=pick.mon})or party(b,side(b,w))[pick.index]~=pick.mon then return false end
    return b.data.pokemon[pick.mon.species]~=nil
  end
  local function voluntary(b,w,context)
    if not context or not context.voluntary then return false end
    if context.sourceCard==M.CARD_ID then return context.kind=='manual'or context.kind=='aiSwitch'end
    local baton=mod.exports.pokemonBatonPass67
    if context.sourceCard=='KASC-67-BATON-PASS'and baton then
      return baton.active(b,b.data.moves[w.lastMove])==true
    end
    -- This host has no honest U-turn/Volt Switch/Parting Shot replacement
    -- owner yet. A future owner must authenticate its genuine declaration.
    local pivot=mod.exports.pokemonPivotMoves67
    return pivot and pivot.authenticatesSwitch and pivot.authenticatesSwitch(b,w,context)==true or false
  end
  local function canIntercept(b,w,row)
    local gen=row and not row.spent and ownedChoice(b,w,row.inst)
    if not gen then return end
    local lock=mod.exports.pokemonMoveLock67
    local encored=lock and lock.encoreSlot(b,w)
    if encored and not aliases[encored.id]then return end
    local action=b:lockedAction(w)
    if action and action~=row.inst then return end
    if gen==3 or gen==4 then
      local A=opts.abilities;local state=b.field and b.field.tokens and b.field.tokens[A.owner]
      if A.isAsleep(b,w)or w.mon.status=='FRZ'or A.activeAbility(b,w)=='TRUANT'
          and state and state.truant and state.truant[side(b,w)]then return end
    end;return gen
  end
  local function clearBond(b,u,t,gen)
    local fatal=mod.exports.pokemonFatalConditions67;if not fatal then return end
    local clear=gen>=3
    if gen==2 then local speed=require('src.battle.TurnOrder').effectiveSpeed
      local us,ts=speed(u),speed(t);clear=us<ts or us==ts and b.rng(0,1)==0
    end
    if clear then fatal.clear(b,t,'bond')end
  end
  function M.defer(b,w,pick,context,continuation)
    if type(continuation)~='function'or resuming[b]or not M.epoch(b)or pending[b]or not pickValid(b,w,pick)
        or not voluntary(b,w,context)then return false end
    local key=side(b,w);local u=b[other(key)];local row=lane(b,u);local gen=canIntercept(b,u,row)
    if not gen or not live(w)or not live(u)then return false end
    row.spent=true;pending[b]={target=w,source=u,pick=pick,context=context}
    b:actNext(function()
      local proof=pending[b]
      if not proof or proof.target~=w then return end
      if side(b,w)and side(b,u)and live(w)and live(u)and M.epoch(b)then
        clearBond(b,u,w,gen)
        hits[b]={source=u,target=w,inst=row.inst,epoch=gen}
        executing[b]={source=u,inst=row.inst}
        local ok,err=pcall(function()
          if gen==3 or gen==4 then b:performMove(u,w,row.inst,false)
          else b:executeAction(u,w,row.inst)end
        end)
        if u==b.enemy and row.cachedClass then b.enemyActionForced=false end
        hits[b]=nil;executing[b]=nil
        if not ok then pending[b]=nil;error(err,0)end
      end
      b:actNext(function()
        pending[b]=nil
        -- Native Pursuit faint/replacement handling owns a KO. Never send
        -- the originally selected reserve over a fainted/replaced actor.
        if not M.epoch(b)or b.result or not side(b,w)or not live(w)or not pickValid(b,w,pick)then return end
        resuming[b]=true
        local out=pack(pcall(continuation));resuming[b]=nil
        if not out[1]then error(out[2],0)end
      end)
    end)
    return true
  end
  function M.replacementAllowed(b,w,pick,context)
    local r=replacements[b]
    return M.epoch(b)and r and r.target==w and r.pick==pick and r.context==context
      and context.sourceCard==M.CARD_ID and context.kind=='manual'and context.voluntary
      and pickValid(b,w,pick)or false
  end
  function M.resolveSwitch(original,b,mon,...)
    if not M.epoch(b)or not hasPursuit(b,b.enemy)or blocked(b,b.player)then return original(b,mon,...)end
    local old=b.player;local pick
    for i,p in ipairs(b:playerPartyView())do if p==mon then pick={mon=p,index=i};break end end
    if not pickValid(b,old,pick)then return original(b,mon,...)end
    local action=classDecision(b,b:enemyAction());local before=b.turnCount or 0
    local lifecycle=assert(mod.exports.pokemonStatusLifecycle67)
    lifecycle.beginNonMoveTurn(b,'resolveSwitch')
    if(b.turnCount or 0)==before then b.turnCount=before+1
      Runtime.emit('battle.turn_started',{battle=b,turn=b.turnCount,playerAction={special='resolveSwitch'},enemyAction=action})
    end
    local p=bind(b,nil,action,true);plans[b]=p
    local context={voluntary=true,sourceCard=M.CARD_ID,kind='manual'}
    local function commit()
      if not side(b,old)or not live(old)or not pickValid(b,old,pick)then return end
      b:sayNextAuto(b:withdrawText(old.name));b:queueRetreatAnim()
      b:actNext(function()
        if not side(b,old)or not live(old)then return end
        replacements[b]={target=old,pick=pick,context=context}
        local out=pack(pcall(mod.exports.pokemonForcedSwitch67.swap,b,old,pick,context));replacements[b]=nil
        if not out[1]then error(out[2],0)end;assert(out[2],'Pursuit requires exact native replacement seam')
      end)
    end
    b.phase='messages';b.afterQueue='menu'
    b:act(function()if not M.defer(b,old,pick,context,commit)then commit()end end)
    b:act(function()if live(b.enemy)and live(b.player)then b:executeAction(b.enemy,b.player,action)end end)
    b:act(function()b:endOfTurn()end)
  end
  function M.execute(original,b,w,t,action,...)
    local row=lane(b,w);local own=executing[b]
    if row and row.spent and action==row.inst and not(own and own.source==w and own.inst==action)then
      if w==b.enemy and row.cachedClass then b.enemyActionForced=false end
      return
    end
    if row and row.cachedClass and action==row.inst then b.enemyActionForced=true end
    if M.epoch(b)and w==b.enemy and action and action.special=='aiSwitch'and not blocked(b,w)then
      local pick={mon=b.enemyParty and b.enemyParty[action.index],index=action.index}
      local context={voluntary=true,sourceCard=M.CARD_ID,kind='aiSwitch'}
      if M.defer(b,w,pick,context,function()b.enemyActionForced=true;b:executeAction(w,b.player,action)end)then return end
    end
    if row and action==row.inst then
      row.spent=true
      -- A final reinstall may compose outside an earlier native owner.
      -- Authorize this exact synchronous action through both adapters;
      -- only its later queued duplicate is canceled, never the inner call.
      local prior=executing[b];executing[b]={source=w,inst=action}
      local out=pack(pcall(original,b,w,t,action,...));executing[b]=prior
      if w==b.enemy and row.cachedClass then b.enemyActionForced=false end
      if not out[1]then error(out[2],0)end;return unpack(out,2,out.n)
    end
    return original(b,w,t,action,...)
  end
  function M.project(b,w,m,intercept)
    local gen=M.profile(b,w,m);if not gen then return m end
    local out=copy(m);out.power=40
    -- A licensed Gen-II move can exist in a Gen-I chart without a DARK
    -- record. Keep its source-era category instead of falling through to
    -- the Gen-IV physical split; an actual effective type still wins.
    out.category=gen<=3 and(Chart.category(out.type)or(out.type=='DARK'and'special'))or'physical'
    local hit=hits[b]
    if intercept and hit and hit.source==w and hit.epoch==gen and side(b,hit.target)and live(hit.target)then
      out.power=80;out.kascPursuitIntercept67=M.OWNER
    end;return out
  end
  function M.move(original,b,inst,...)
    local m=original(b,inst,...);if not m or not aliases[m.id]then return m end
    local hit=hits[b]
    for _,w in ipairs({b.player,b.enemy})do if slot(w,inst)then
      return M.project(b,w,m,hit and hit.source==w and hit.inst==inst)
    end end;return m
  end
  function M.damage(nextDamage,ctx)
    if not ctx or not aliases[ctx.move and ctx.move.id]or not M.epoch(ctx.battle)then return nextDamage(ctx)end
    local b=ctx.battle;local active
    for _,w in ipairs({b.player,b.enemy})do if ctx.user and ctx.user.mon==w.mon then active=w;break end end
    if not active then return nextDamage(ctx)end
    local hit=hits[b];local intercepted=hit and hit.source==active and ctx.target and ctx.target.mon==hit.target.mon
      and ctx.move.kascPursuitIntercept67==M.OWNER
    local out={};for k,v in pairs(ctx)do out[k]=v end
    out.move=M.project(b,active,ctx.move,intercepted)
    local bond=mod.exports.pokemonParentalBond67
    if bond then bond.projected(b,ctx.user,ctx.target,ctx.move,out.move)end
    return nextDamage(out)
  end
  function M.run(original,b,ctx,record)
    local hit=hits[b]
    if hit and hit.source==ctx.user and hit.target==ctx.target and hit.inst==ctx.moveInst
        and ctx.move.kascPursuitIntercept67==M.OWNER and M.profile(b,ctx.user,ctx.move)==hit.epoch and hit.epoch>=3 then
      record=copy(record);record.neverMiss=true -- true accuracy + tracksTarget, not Protect bypass
    end;return original(b,ctx,record)
  end
  function M.validateCheckpoint(b)
    if b.field and b.field.tokens and b.field.tokens[M.OWNER]~=nil then return false,'unexpected_saved_pursuit_state'end
    if plans[b]or selecting[b]or hits[b]or pending[b]or executing[b]or resuming[b]or replacements[b]then
      return false,'native_pursuit_action_or_switch_in_flight'
    end;return true
  end
  function M.install()
    B._kascPursuit67=M;FX._kascPursuit67=M
    -- Reinstall outside later genuine-action owners, without wrapping ours
    -- repeatedly when no intervening owner has changed the native method.
    for method,owner in pairs({resolveTurn='resolveTurn',resolveSwitch='resolveSwitch',executeAction='execute',
        enemyAction='enemyAction',moveDef='move'})do
      local key='_kascPursuitWrapper67_'..method
      if B[method]~=B[key]then local original=B[method]
        local wrapper=function(...)return B._kascPursuit67[owner](original,...)end
        B[method]=wrapper;B[key]=wrapper
      end
    end
    if FX.runDamaging~=FX._kascPursuitRun67 then local original=FX.runDamaging
      local wrapper=function(...)return FX._kascPursuit67.run(original,...)end
      FX.runDamaging=wrapper;FX._kascPursuitRun67=wrapper
    end
  end
  local fact=assert(opts.facts.move(M.ID,7));local old=assert(mod.content.moves:get(M.ID))
  assert(fact.number==228 and fact.generation==2 and fact.type=='DARK'and fact.power==40
    and fact.pp==20 and fact.accuracy==100 and fact.category=='physical','Pursuit source drift')
  assert(not old.backendMoveOwner,'foreign Pursuit owner')
  local row=copy(assert(mod.content.move_effects:get(old.effect)));row.kascPursuit67=M.OWNER
  mod.content.move_effects:register(effect,row)
  for id in pairs(aliases)do local native=assert(mod.content.moves:get(id))
    mod.content.moves:patch(id,{effect=effect,backendMoveOwner=M.OWNER,backendMoveNumber=228,
      backendLearnsetRevision=native.backendLearnsetRevision or 1,flags={contact=1,protect=1,mirror=1,metronome=1}})
    assert(mod.content.battle_anims:get(id),'existing Pursuit animation missing')
  end
  mod.events:on('battle.turn_started',M.turnStarted,100000)
  mod.events:on('battle.turn_ended',function(ev)plans[ev.battle]=nil;pending[ev.battle]=nil end,-100000)
  mod.events:on('battle.ended',function(ev)
    local b=ev.battle;plans[b]=nil;selecting[b]=nil;hits[b]=nil;pending[b]=nil;executing[b]=nil;resuming[b]=nil;replacements[b]=nil
  end,100000)
  mod.hooks:wrap('battle.turn_order',M.order,100000)
  mod.hooks:wrap('battle.damage',M.damage,49000)
  M.install()
  if opts.supportLog and opts.supportLog.registerSegment then opts.supportLog.registerSegment({segmentId=M.CARD_ID,
    cardId=M.CARD_ID,schema='kasc.optional-feature-card/v1',version='1.0.0',owner=M.OWNER,active=true,
    dependencyStatus='actual-selected-native-action-and-deferred-before-replacement',providerStatus='pursuit-switch-intercept',
    buildReceiptId='docs/PURSUIT_67.md',rollbackReceiptId='docs/PURSUIT_67.md'})end
  return M
end
