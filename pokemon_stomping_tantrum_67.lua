-- Fruststampfer: observe completed actions, never infer failure from HP alone
-- or translated dialogue. Only the previous round, not the last hit, counts.
return function(mod,opts)
  local B=require('src.battle.BattleState')
  local M={CARD_ID='KASC-67-STOMPING-TANTRUM',OWNER='kasc.stomping-tantrum/v1'}
  local frames=setmetatable({},{__mode='k'})
  local id='STOMPING_TANTRUM'
  local function pack(...)return{n=select('#',...),...}end
  local function copy(v,seen)
    if type(v)~='table'then return v end
    seen=seen or{};if seen[v]then return seen[v]end
    local out={};seen[v]=out;for k,x in pairs(v)do out[k]=copy(x,seen)end;return out
  end
  local function equal(a,b,seen)
    if type(a)~=type(b)then return false end
    if type(a)~='table'then return a==b end
    seen=seen or{};if seen[a]==b then return true end;seen[a]=b
    for k,v in pairs(a)do if not equal(v,b[k],seen)then return false end end
    for k in pairs(b)do if a[k]==nil then return false end end
    return true
  end
  local function side(b,w)return w==b.player and'player'or w==b.enemy and'enemy'or nil end
  local function rows(b,create)
    if create then b.field=b.field or{};b.field.tokens=b.field.tokens or{}
      b.field.tokens[M.OWNER]=b.field.tokens[M.OWNER]or{}end
    return b and b.field and b.field.tokens and b.field.tokens[M.OWNER]
  end
  function M.enabled(b)
    local r=b and b.kascGenerationRulesReceipt
    local marker=b and b.data and b.data.moves and b.data.moves[id]
    return getmetatable(b)==B and not b.demo and b.kind~='link'and not b.result
      and r and r.mode~='off'and marker and marker.kascStompingTantrum67==M.OWNER
  end
  function M.clear(b,w)
    local r=rows(b);if not r then return end
    if w then local key=side(b,w);if key then r[key]=nil end
    else b.field.tokens[M.OWNER]=nil end
  end
  function M.record(b,w,result)
    local key=side(b,w);if not M.enabled(b)or not key or not w.mon or w.mon.hp<=0 then return end
    local r=rows(b,true);local old=r[key];local turn=b.turnCount or 0;local previous='skipped'
    if old then
      if old.turn==turn then previous=old.previous
      elseif old.turn==turn-1 then previous=old.current end
    end
    r[key]={turn=turn,current=result,previous=previous}
  end
  function M.boosted(b,w)
    if not M.enabled(b)or not w or not w.mon or w.mon.hp<=0 then return false end
    local r=rows(b);local key=side(b,w);local v=r and key and r[key];local turn=b.turnCount or 0
    if not v then return false end
    if v.turn==turn then return v.previous==false end
    return v.turn==turn-1 and v.current==false
  end
  function M.damage(nextDamage,ctx)
    local m=ctx and ctx.move
    if not m or m.id~=id or m.kascStompingTantrum67~=M.OWNER
        or ctx.opts and ctx.opts.typeless or not M.boosted(ctx.battle,ctx.user)then return nextDamage(ctx)end
    local out={};for k,v in pairs(ctx)do out[k]=v end
    out.move={};for k,v in pairs(m)do out.move[k]=v end;out.move.power=150
    return nextDamage(out)
  end
  -- Primary effects can succeed without damage or visible animation. Compare
  -- their mechanical state around the actual callback, after PP spending.
  -- Exclude shared registries/render handles and this observer's own history.
  local ignored={def=true,statuses=true,badgeBoosts=true,sprite=true,side=true,
    name=true,shownHP=true,shownPx=true,shownStatus=true}
  local function snapshot(b,u,t)
    local function who(w)local out={};for k,v in pairs(w or{})do if not ignored[k]then out[k]=v end end;return out end
    local tokens={};for k,v in pairs(b.field and b.field.tokens or{})do if k~=M.OWNER then tokens[k]=v end end
    return copy({user=who(u),target=who(t),tokens=tokens,weather=b.weather,result=b.result,
      sides=b.sides and {b.sides[1]and b.sides[1].tokens,b.sides[2]and b.sides[2].tokens}})
  end
  function M.callback(original,ctx,...)
    local f=frames[ctx.battle]
    if not f or f.user~=ctx.user then return original(ctx,...)end
    local before=snapshot(ctx.battle,ctx.user,ctx.target)
    local result=pack(original(ctx,...));local messages=result[1]
    if not(type(messages)=='table'and messages.failed)then
      if not equal(before,snapshot(ctx.battle,ctx.user,ctx.target))
          or ctx.move.id=='SPLASH'or ctx.move.id=='CELEBRATE'then f.result=true end
    end
    return unpack(result,1,result.n)
  end
  function M.effectRecord(original,b,effect)
    local record=original(b,effect)
    if not frames[b]or not record then return record end
    local out={};for k,v in pairs(record)do out[k]=v end
    if record.perform then out.perform=function(...)return M.callback(record.perform,...)end end
    if record.kind=='primary'and record.run then out.run=function(...)return M.callback(record.run,...)end end
    return out
  end
  local function scoped(original,b,u,t,action,called,isAction)
    if not M.enabled(b)or not side(b,u)or not u.mon or u.mon.hp<=0
        or not t or not t.mon or t.mon.hp<=0 or not action then return original(b,u,t,action,called)end
    local bounce=mod.exports and mod.exports.pokemonMagicBounce67
    if not isAction and bounce and bounce.isReflected(b,u,action)then return original(b,u,t,action,called)end
    local parent=frames[b];local f={user=u,target=t,result=false};frames[b]=f
    -- Recharge and trainer item/switch actions do not attempt a move.
    -- Locked Bide/trapping continuations do: an empty Bide release fails,
    -- whereas storing energy or landing the release succeeds.
    if isAction and(action.special=='recharge'or action.special=='aiItem'
        or action.special=='aiSwitch')then f.result='skipped'end
    if isAction and action.special=='bide'and(u.bideTurns or 0)>1 then f.result=true end
    if isAction and b.ghost and not u.isPlayer then f.result='skipped'end
    local charging=u.charging
    local result=pack(pcall(original,b,u,t,action,called))
    frames[b]=parent
    if not result[1]then error(result[2],0)end
    if not isAction and not charging and u.charging and u.chargeReady then f.result=true end
    M.record(b,u,f.result)
    -- Metronome/Sleep Talk inherit the called move's result. A different
    -- actor's Dancer/reaction never overwrites this actor's pending outcome.
    if parent and parent.user==u then parent.result=f.result end
    return unpack(result,2,result.n)
  end
  function M.perform(original,b,u,t,action,called)return scoped(original,b,u,t,action,called,false)end
  function M.action(original,b,u,t,action)return scoped(original,b,u,t,action,nil,true)end
  function M.applyDamage(original,b,target,amount,...)
    local result=pack(original(b,target,amount,...));local f=frames[b]
    -- Includes Substitute, Endure-at-1 and Disguise: a landed zero-damage
    -- hit is a success. Confusion/recoil is not a hit on the selected foe.
    if f and target==f.target and target~=f.user and type(amount)=='number'and amount>=0 then f.result=true end
    return unpack(result,1,result.n)
  end
  function M.interrupt(original,b,...)
    local result=pack(original(b,...));if result[1]and frames[b]then frames[b].result=false end
    return unpack(result,1,result.n)
  end
  function M.trainerAction(original,b,...)
    local result=pack(original(b,...));local action=result[1]
    if frames[b]and action and action.special then frames[b].result='skipped'end
    return unpack(result,1,result.n)
  end
  function M.validateCheckpoint(b)
    if frames[b]then return false,'move_outcome_unsettled'end
    local r=rows(b);if r==nil then return true end
    if type(r)~='table'then return false,'invalid_move_outcome_container'end
    local function valid(v)return v==true or v==false or v=='skipped'end
    for key,v in pairs(r)do
      if(key~='player'and key~='enemy')or not b[key]or type(v)~='table'
          or type(v.turn)~='number'or v.turn%1~=0 or v.turn<0 or v.turn>(b.turnCount or 0)
          or not valid(v.current)or not valid(v.previous)then return false,'invalid_move_outcome_timeline'end
      for k in pairs(v)do if k~='turn'and k~='current'and k~='previous'then return false,'unknown_move_outcome_field'end end
    end
    return true
  end
  function M.install()
    B._kascMoveOutcome67=M
    if not B._kascMoveOutcomeWrapped67 then
      for method,handler in pairs({performMove='perform',executeAction='action',effectRecord='effectRecord',
        applyDamage='applyDamage',statusInterrupt='interrupt',preRechargeChecks='interrupt',trainerAIAction='trainerAction'})do
        local original=B[method];local name=handler
        B[method]=function(...)return B._kascMoveOutcome67[name](original,...)end
      end
      B._kascMoveOutcomeWrapped67=true
    end
    local protection=assert(mod.exports.pokemonProtection67)
    if not protection._kascMoveOutcome67 then
      local old=protection.notice
      protection.notice=function(ctx,...)
        local result=pack(old(ctx,...));local f=frames[ctx.battle]
        if result[1]and f and f.user==ctx.user then f.result=true end
        return unpack(result,1,result.n)
      end
      protection._kascMoveOutcome67=true
    end
  end
  local row=assert(opts.facts.move(id,7))
  assert(row.number==707 and row.power==75 and row.type=='GROUND'and row.category=='physical'
    and row.accuracy==100 and row.pp==10 and row.priority==0 and row.target==10,'Fruststampfer source drift')
  assert(not mod.content.moves:get(id),'foreign Fruststampfer owner')
  mod.content.moves:register(id,{id=id,name=opts.i18n.text(row.names.en,row.names.de),type=row.type,
    category='physical',power=75,accuracy=100,pp=10,priority=0,contact=true,effect='NO_ADDITIONAL_EFFECT',
    originGeneration=7,backendMoveNumber=707,backendMoveOwner=M.OWNER,backendLearnsetRevision=11,
    kascStompingTantrum67=M.OWNER,anim=copy(assert(mod.content.moves:get('STOMP')).anim)})
  local anim={seq={}}
  for _,part in ipairs({'EARTHQUAKE','STOMP'})do
    for _,v in ipairs(assert(mod.content.battle_anims:get(part)).seq)do anim.seq[#anim.seq+1]=copy(v)end
  end
  mod.content.battle_anims:register(id,anim)
  mod.hooks:wrap('battle.damage',M.damage,31500)
  mod.events:on('battle.battler_switched',function(ev)M.clear(ev.battle,ev.battler)end,8000)
  mod.events:on('battle.fainted',function(ev)M.clear(ev.battle,ev.battler)end,8000)
  mod.events:on('battle.ended',function(ev)M.clear(ev.battle)end,8000)
  if opts.supportLog and opts.supportLog.registerSegment then
    opts.supportLog.registerSegment({segmentId=M.CARD_ID,cardId=M.CARD_ID,
      schema='kasc.optional-feature-card/v1',version='1.0.0',owner=M.OWNER,active=true,
      dependencyStatus='completed-native-actions-and-checkpoints',providerStatus='previous-round-outcome',
      buildReceiptId='docs/STOMPING_TANTRUM_67.md',rollbackReceiptId='docs/GEN6_WAVE15_SCOPE_20260909.md'})
  end
  return M
end
