-- Era-aware Taunt and Attract. Choice, Disable and Taunt intersect; an
-- exhausted intersection uses native Struggle, never an illegal fallback.
return function(mod,opts)
  local B=require('src.battle.BattleState')
  local M={CARD_ID='KASC-67-MOVE-RESTRICTIONS',OWNER='kasc.move-restrictions/v1'}
  local tr=opts.i18n.text
  local function side(b,w)return w==b.player and 'player' or w==b.enemy and 'enemy' or nil end
  local function rows(b,create)
    if create then b.field=b.field or {};b.field.tokens=b.field.tokens or {}
      b.field.tokens[M.OWNER]=b.field.tokens[M.OWNER]or{} end
    return b and b.field and b.field.tokens and b.field.tokens[M.OWNER]
  end
  function M.epoch(b)
    local r=b and b.data and b.data.move_effects and b.data.move_effects.HEAL_EFFECT
    local gen=r and r.kascMoveRestrictions67==M.OWNER and opts.status.epoch(b)
    if getmetatable(b)==B and not b.result and gen and gen>=3 and gen<=7 then return gen end
  end
  function M.clear(b,w)
    local r=rows(b);if not r then return end
    if w then local key=side(b,w);if key then r[key]=nil end
    else b.field.tokens[M.OWNER]=nil end
  end
  function M.validateCheckpoint(b)
    local r=rows(b);if not r then return true end
    if type(r)~='table'then return false,'invalid_taunt_container'end
    for key,v in pairs(r)do
      if (key~='player'and key~='enemy')or type(v)~='table'
          or type(v.applied)~='number'or v.applied%1~=0 or v.applied<0
          or v.applied>(b.turnCount or 0) or type(v.expires)~='number'
          or v.expires%1~=0 or v.expires<v.applied or v.expires>v.applied+5 then
        return false,'invalid_taunt_timeline'
      end
      for k in pairs(v)do if k~='applied'and k~='expires'then return false,'invalid_taunt_field'end end
    end
    return true
  end
  function M.taunted(b,w)
    local gen=M.epoch(b);local r=rows(b);local key=side(b,w);local v=r and r[key]
    if not v then return false end
    if not gen or not w.mon or w.mon.hp<=0 or (b.turnCount or 0)>v.expires
        or gen>=6 and opts.abilities.activeAbility(b,w)=='OBLIVIOUS'then
      r[key]=nil;return false
    end
    return true
  end
  local function failure()return {tr('But, it failed!','Doch es schlug fehl!'),failed=true}end
  function M.cast(ctx)
    local b,u,t=ctx.battle,ctx.user,ctx.target;local gen=M.epoch(b)
    if not gen or not side(b,u)or not side(b,t)or u==t or u.mon.hp<=0 or t.mon.hp<=0
        or opts.priority.blocks(ctx)then return failure()end
    if ctx.move.id=='ATTRACT'then
      -- Attract bypasses Substitute, but still goes through gender and
      -- ability checks shared with Cute Charm.
      if opts.infatuation.start(b,t,u)then return {}end
      return failure()
    end
    if ctx.move.id=='CAPTIVATE'then
      if not opts.infatuation.oppositeGender(b,u,t)or opts.abilities.activeAbility(b,t)=='OBLIVIOUS'then return failure()end
      return opts.split.changeStage(ctx,t,'specialAttack',-2,true)
    end
    if M.taunted(b,t)or gen>=6 and opts.abilities.activeAbility(b,t)=='OBLIVIOUS'
        or opts.abilities.blocksMentalEffect(b,t,'TAUNT')then return failure()end
    local duration=gen==3 and 2 or gen==4 and ctx.rng(3,5)or 3
    if gen>=5 and b._kascFlinchActed67 and b._kascFlinchActed67[t]then duration=duration+1 end
    local turn=b.turnCount or 0
    rows(b,true)[side(b,t)]={applied=turn,expires=turn+duration-1}
    return {tr('%s\nwas taunted!','%s\nwurde verhöhnt!'):format(t.name)}
  end
  local function statusMove(b,m)
    local def=m and b.data.moves[m.id]
    return def and (def.category=='status' or def.power==0)
  end
  local function grounding()return opts.grounding and opts.grounding()end
  local function uneaten(b,w,m)
    local use=mod.exports.pokemonConditionalUse67
    return use and m and use.blocksSelection(b,w,b:moveDef(m))or false
  end
  local function restricted(b,w)
    local g=grounding()
    if M.taunted(b,w)or g and g.gravity(b)then return true end
    for _,slot in ipairs(w.curMoves or{})do if uneaten(b,w,slot)then return true end end
    return false
  end
  local function blocked(b,w,m)
    local g=grounding()
    return M.taunted(b,w)and statusMove(b,m)or g and g.blockedMove(b,w,m)or uneaten(b,w,m)
  end
  local function notice()return tr('This move is blocked right now!','Diese Attacke ist gerade blockiert!')end
  function M.usable(b,w)
    local out={};local lock=opts.choice.locked(b,w)
    for i,m in ipairs(w.curMoves or{})do
      if (m.pp or 0)>0 and w.disabledSlot~=i and (not lock or m.id==lock.move)
          and not blocked(b,w,m)then out[#out+1]=m end
    end
    return out
  end
  function M.playerHasPP(original,b,...)
    if restricted(b,b.player)then return #M.usable(b,b.player)>0 end
    return original(b,...)
  end
  function M.chooseMove(original,b,i,...)
    if b.phase=='moveSelect'and blocked(b,b.player,b.player.curMoves[i])then
      b:say(notice())
      b.phase='messages';b.afterQueue='menu';return true
    end
    return original(b,i,...)
  end
  function M.enemyAction(original,b,...)
    local action=original(b,...)
    if not restricted(b,b.enemy)or action and action.special or b:lockedAction(b.enemy)then return action end
    local usable=M.usable(b,b.enemy)
    for _,m in ipairs(usable)do if action==m then return action end end
    return #usable>0 and usable[b.rng(1,#usable)]or{id='STRUGGLE',pp=1,struggle=true}
  end
  function M.perform(original,b,u,t,m,...)
    -- Reflection is an ability reaction, not the holder selecting a move.
    local bounce=mod.exports and mod.exports.pokemonMagicBounce67
    if bounce and bounce.isReflected(b,u,m)then return original(b,u,t,m,...)end
    -- III restricts selection only. IV+ can also cancel a status move
    -- queued before a faster Taunt; no PP is spent for that cancellation.
    local gen=M.epoch(b)
    local g=grounding()
    if g and g.blockedMove(b,u,m)then b:sayNext(notice());return end
    if gen and gen>=4 and M.taunted(b,u)and statusMove(b,m)then
      b:sayNext(tr('Taunt blocks status moves!','Verhöhner blockt Statusattacken!'));return
    end
    return original(b,u,t,m,...)
  end
  function M.endTurn(ev)
    local b=ev.battle;local r=rows(b);if not r then return end
    for _,key in ipairs({'player','enemy'})do
      local v=r[key]
      if v and (b.turnCount or 0)>=v.expires then r[key]=nil end
    end
  end
  local function copy(v)
    if type(v)~='table'then return v end
    local out={};for k,x in pairs(v)do out[k]=copy(x)end;return out
  end
  for id,anim in pairs({TAUNT='GROWL',ATTRACT='CONFUSE_RAY',CAPTIVATE='GROWL'})do
    local move=assert(mod.content.moves:get(id),'missing move '..id)
    assert(move.effect=='KA_GEN_MOVE_UNSUPPORTED_'..id
      or id=='CAPTIVATE'and move.effect=='KA_GEN_MOVE_STAT_CAPTIVATE','foreign restriction owner '..id)
    local effect='KA_RESTRICTION_67_'..id
    mod.content.move_effects:register(effect,{kind='primary',accuracyChecked=true,run=M.cast})
    mod.content.moves:patch(id,{effect=effect})
    local source=assert(mod.content.battle_anims:get(anim),'missing native animation '..anim)
    mod.content.battle_anims:patch(id,copy(source))
    for i=#opts.catalog.unsupportedStatus,1,-1 do
      if opts.catalog.unsupportedStatus[i]==id then table.remove(opts.catalog.unsupportedStatus,i)end
    end
  end
  mod.content.move_effects:patch('HEAL_EFFECT',{kascMoveRestrictions67=M.OWNER})
  mod.events:on('battle.turn_ended',M.endTurn,100)
  mod.events:on('battle.battler_switched',function(ev)M.clear(ev.battle,ev.battler)end,8000)
  mod.events:on('battle.ended',function(ev)M.clear(ev.battle)end,8000)
  B._kascMoveRestrictions67=M
  if not B._kascMoveRestrictionsWrapped67 then
    local perform,choose,enemy,pp=B.performMove,B.chooseMove,B.enemyAction,B.playerHasPP
    B.performMove=function(...)return B._kascMoveRestrictions67.perform(perform,...)end
    B.chooseMove=function(...)return B._kascMoveRestrictions67.chooseMove(choose,...)end
    B.enemyAction=function(...)return B._kascMoveRestrictions67.enemyAction(enemy,...)end
    B.playerHasPP=function(...)return B._kascMoveRestrictions67.playerHasPP(pp,...)end
    B._kascMoveRestrictionsWrapped67=true
  end
  if opts.supportLog and opts.supportLog.registerSegment then
    opts.supportLog.registerSegment({segmentId=M.CARD_ID,cardId=M.CARD_ID,
      schema='kasc.optional-feature-card/v1',version='1.0.0',owner=M.OWNER,active=true,
      dependencyStatus='native-selection-status-checkpoint',providerStatus='taunt-attract',
      buildReceiptId='docs/FINISH_1600_20260910.md',rollbackReceiptId='docs/FINISH_1600_20260910.md'})
  end
  return M
end
