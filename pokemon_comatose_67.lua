-- Virtual sleep and sleep-dependent move effects. Comatose itself is VII;
-- ordinary sleep moves keep their native/historical eras. No fake SLP save.
return function(mod,opts)
  local M={CARD_ID='KASC-67-COMATOSE',OWNER='kasc.comatose/v1'}
  local B=require('src.battle.BattleState')
  local E=opts.abilities;local tr=opts.i18n.text
  local function lane(b,w)return w==b.player and 'player'or w==b.enemy and 'enemy'end
  local function rows(b)return b and b.field and b.field.tokens and b.field.tokens[M.OWNER]end
  local function failed()return {tr('But, it failed!','Doch es schlug fehl!'),failed=true}end
  function M.epoch(b)
    local r=b and b.data and b.data.move_effects and b.data.move_effects.HEAL_EFFECT
    local gen=r and r.kascComatose67==M.OWNER and opts.status.epoch(b)
    if getmetatable(b)==B and not b.result and gen and gen>=2 and gen<=7 then return gen end
  end
  function M.nightmare(ctx)
    local b,t=ctx.battle,ctx.target;local key=lane(b,t)
    if not M.epoch(b)or not key or t.mon.hp<=0 or not E.isAsleep(b,t)
        or t.substituteHP or t.invulnerable or rows(b)and rows(b)[key]then return failed()end
    b.field=b.field or {};b.field.tokens=b.field.tokens or {}
    b.field.tokens[M.OWNER]=rows(b)or {}
    rows(b)[key]={species=t.mon.species,lastTurn=(b.turnCount or 0)-1}
    return {tr('%s has a nightmare!','%s hat einen Albtraum!'):format(t.name)}
  end
  function M.validateCheckpoint(b)
    local state=rows(b);if state==nil then return true end
    if type(state)~='table'then return false,'invalid nightmare state'end
    for key,row in pairs(state)do
      local w=(key=='player'or key=='enemy')and b[key]
      if not w or type(row)~='table'or row.species~=w.mon.species
          or type(row.lastTurn)~='number'or row.lastTurn%1~=0
          or row.lastTurn< -1 or row.lastTurn>(b.turnCount or 0)then
        return false,'invalid nightmare target/timeline'
      end
      for field in pairs(row)do if field~='species'and field~='lastTurn'then
        return false,'unknown nightmare field'end end
    end
    return true
  end
  function M.residual(ev)
    local b=ev.battle;local state=rows(b)
    if not state or not M.epoch(b)then return end
    assert(M.validateCheckpoint(b),'invalid nightmare receipt')
    for _,key in ipairs({'player','enemy'})do
      local row,w=state[key],b[key]
      if row then
        if w.mon.hp<=0 or not E.isAsleep(b,w)then state[key]=nil
        elseif row.lastTurn<(b.turnCount or 0)then
          row.lastTurn=b.turnCount or 0
          if not E.blocksIndirect(b,w,'nightmare')then
            local sub,bide,rage=w.substituteHP,w.bideTurns,w.rageMove
            w.substituteHP,w.bideTurns,w.rageMove=nil,nil,nil
            local ok,err=pcall(b.applyDamage,b,w,math.max(1,math.floor(w.mon.stats.hp/4)))
            w.substituteHP,w.bideTurns,w.rageMove=sub,bide,rage
            if not ok then error(err,0)end
            b:sayNext(tr('%s is locked in a nightmare!','%s leidet unter einem Albtraum!'):format(w.name))
            if w.mon.hp<=0 then b:onFaint(w)end
          end
        end
      end
    end
    if not next(state)then b.field.tokens[M.OWNER]=nil end
  end
  function M.switched(ev)
    local state=rows(ev.battle);local key=lane(ev.battle,ev.battler)
    if state and key then state[key]=nil
      if not next(state)then ev.battle.field.tokens[M.OWNER]=nil end
    end
  end
  function M.clearNightmare(b,w)
    local state,key=rows(b),lane(b,w)
    if state and key then state[key]=nil
      if not next(state)then b.field.tokens[M.OWNER]=nil end
    end
  end
  local old=assert(mod.content.move_effects:get('DREAM_EATER_EFFECT').gate)
  mod.content.move_effects:patch('DREAM_EATER_EFFECT',{gate=function(ctx)
    if M.epoch(ctx.battle)and E.isAsleep(ctx.battle,ctx.target)then return true end
    return old(ctx)
  end})
  mod.content.move_effects:register('KA_WAKE_UP_SLAP_67',{
    kind='secondary',run=function()return{}end,afterDamage=function(ctx)
      if (M.epoch(ctx.battle)or 0)<4 or (ctx.totalDealt or 0)<=0
          or ctx.target.substituteHP or ctx.brokeSub or ctx.target.mon.status~='SLP'then return end
      ctx.target.mon.status=nil;opts.lifecycle.clear(ctx.target,ctx.battle)
      ctx.say(tr('%s woke up!','%s ist aufgewacht!'):format(ctx.target.name))
    end})
  mod.content.move_effects:register('KA_NIGHTMARE_67',{
    kind='primary',accuracyChecked=false,run=M.nightmare})
  for id,effect in pairs({WAKE_UP_SLAP='KA_WAKE_UP_SLAP_67',NIGHTMARE='KA_NIGHTMARE_67'})do
    for _,alias in ipairs(opts.species.moveIds(id))do
      local move=mod.content.moves:get(alias)
      if move and not move.backendMoveOwner then mod.content.moves:patch(alias,{effect=effect})end
    end
  end
  for i=#opts.catalog.unsupportedStatus,1,-1 do
    if opts.catalog.unsupportedStatus[i]=='NIGHTMARE'then table.remove(opts.catalog.unsupportedStatus,i)end
  end
  -- Existing move-catalog animations remain intact; no sprite assets change.
  mod.events:on('battle.turn_ended',M.residual,150)
  mod.events:on('battle.battler_switched',M.switched,8000)
  mod.events:on('battle.ended',function(ev)
    if rows(ev.battle)then ev.battle.field.tokens[M.OWNER]=nil end
  end,80)
  mod.content.move_effects:patch('HEAL_EFFECT',{kascComatose67=M.OWNER})
  if opts.supportLog and opts.supportLog.registerSegment then
    opts.supportLog.registerSegment({segmentId=M.CARD_ID,cardId=M.CARD_ID,
      schema='kasc.optional-feature-card/v1',version='1.0.0',owner=M.OWNER,active=true,
      dependencyStatus='native-status-sleep-moves-variable-power',providerStatus='virtual-sleep-no-saved-status',
      buildReceiptId='docs/COMATOSE_67.md',rollbackReceiptId='docs/COMATOSE_67.md'})
  end
  return M
end
