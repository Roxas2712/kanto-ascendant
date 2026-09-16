-- Yawn's drowsiness is a volatile visit to the active battler, not sleep.
-- Data-only field receipts survive a native checkpoint, not a switch.
return function(mod,opts)
  local Battle=require('src.battle.BattleState')
  local Status=require('src.battle.StatusRegistry')
  local M={CARD_ID='KASC-67-DELAYED-SLEEP',OWNER='kasc.delayed-sleep/v1'}
  local effect='KA_DELAYED_YAWN_67'
  local tr=opts.i18n.text
  local function failed()return {tr('But, it failed!','Doch es schlug fehl!'),failed=true}end
  local function alive(who)return who and who.mon and (tonumber(who.mon.hp)or 0)>0 end
  local function state(b)return b and b.field and b.field.tokens and b.field.tokens[M.OWNER]end
  local function side(b,who)
    if who==b.player then return 'player'elseif who==b.enemy then return 'enemy'end
  end
  local function slot(b,lane)
    if lane=='enemy'then return b.kind=='trainer' and b.enemyIndex or 1 end
    for i,mon in ipairs(b.game.save.party or {})do if mon==b.player.mon then return i end end
  end
  function M.epoch(b)
    local row=b and b.data and b.data.move_effects and b.data.move_effects[effect]
    local gen=row and row.kascDelayedSleep67==M.OWNER and opts.status.epoch(b)
    -- A later gift's legitimately available move keeps its own behaviour
    -- under an earlier manual/AUTO era. AUS/demo/classic links stay closed.
    if getmetatable(b)==Battle and not b.result and gen and gen>=1 and gen<=7 then return gen end
  end
  function M.validateCheckpoint(b)
    local rows=state(b);if rows==nil then return true end
    if type(rows)~='table'then return false,'invalid drowsiness container'end
    for lane,row in pairs(rows)do
      local who=(lane=='player' or lane=='enemy')and b[lane]
      if not who or type(row)~='table' or row.species~=who.mon.species
          or type(row.slot)~='number' or row.slot%1~=0 or row.slot<1 or row.slot>6
          or row.slot~=slot(b,lane) or type(row.appliedTurn)~='number'
          or row.appliedTurn%1~=0 or row.appliedTurn<0
          or row.appliedTurn>(b.turnCount or 0)
          or (b.turnCount or 0)>row.appliedTurn+1 then
        return false,'invalid drowsiness target/timeline'
      end
      for k in pairs(row)do
        if k~='species' and k~='slot' and k~='appliedTurn'then return false,'unknown drowsiness field'end
      end
    end
    return true
  end
  function M.protected(b,who,applying)
    return opts.weather.leafGuard(b,who) or opts.abilities.blockStatus(b,who,'SLP',
      {source='YAWN',kascYawnApplication67=applying})~=nil
  end
  function M.canCast(b,user,target)
    if not M.epoch(b) or not alive(user) or not side(b,user) or not alive(target)
        or target.mon.status or target.substituteHP or target.invulnerable
        or M.protected(b,target,true)then return false end
    local lane=side(b,target);local index=lane and slot(b,lane)
    if not index then return false end
    local recovery=mod.exports.pokemonTeamRecovery67
    if recovery and recovery.blocksVolatile(b,target,'yawn',user,b.data.moves.YAWN)then return false end
    local rows=state(b)
    return not(rows and rows[lane])
  end
  function M.cast(ctx)
    local b,target=ctx.battle,ctx.target
    if not M.canCast(b,ctx.user,target)then return failed()end
    local lane=side(b,target);local index=slot(b,lane)
    local rows=state(b)
    b.field=b.field or {};b.field.tokens=b.field.tokens or {}
    rows=rows or {};b.field.tokens[M.OWNER]=rows
    rows[lane]={species=target.mon.species,slot=index,appliedTurn=b.turnCount or 0}
    return {tr('%s\ngrew drowsy!','%s\nwird schläfrig!'):format(target.name)}
  end
  function M.endTurn(ev)
    local b=ev and ev.battle;local rows=state(b)
    if not rows or not M.epoch(b)then return end
    assert(M.validateCheckpoint(b),'invalid delayed sleep checkpoint')
    for _,lane in ipairs({'player','enemy'})do
      local row=rows[lane]
      if row and (b.turnCount or 0)>row.appliedTurn then
        rows[lane]=nil -- consume before callbacks; no replay/re-roll
        local who=b[lane]
        if alive(who) and not who.mon.status and not M.protected(b,who)then
          local messages=Status.inflict(b,who,'SLP',{
            source='YAWN',moveType='NORMAL',kascDelayedSleep67=M.OWNER})
          for _,text in ipairs(messages)do b:sayNext(text)end
          if #messages>0 then b:drainNext()end
        end
      end
    end
    if not next(rows)then b.field.tokens[M.OWNER]=nil end
  end
  function M.switch(ev)
    local b=ev and ev.battle;local rows=state(b)
    if not rows then return end
    local lane=side(b,ev.battler)
    if lane then rows[lane]=nil end
    if not next(rows)then b.field.tokens[M.OWNER]=nil end
  end
  function M.finish(ev)
    local b=ev and ev.battle
    if b and b.field and b.field.tokens then b.field.tokens[M.OWNER]=nil end
  end
  local move=mod.content.moves:get('YAWN')
  if not move or move.backendMoveOwner or move.effect~='KA_GEN_MOVE_UNSUPPORTED_YAWN' then
    M.pending='missing-or-foreign-Yawn';return M
  end
  -- Native sleep-cloud puff. REST's fixed-position Z letters cross the
  -- player's HUD when replayed by an enemy under another move ID; do not
  -- borrow those coordinates. Separate tables, native sound, no art edits.
  local function copy(v)
    if type(v)~='table'then return v end
    local out={};for k,x in pairs(v)do out[k]=copy(x)end;return out
  end
  local animation={seq={}}
  local parts={'SLEEP_POWDER'}
  for _,id in ipairs(parts)do
    local anim=mod.content.battle_anims:get(id)
    if not anim or not anim.seq or #anim.seq==0 then M.pending='missing-animation:'..id;return M end
    for _,step in ipairs(anim.seq)do animation.seq[#animation.seq+1]=copy(step)end
  end
  mod.content.move_effects:register(effect,{kind='primary',accuracyChecked=false,
    kascDelayedSleep67=M.OWNER,run=M.cast})
  mod.content.moves:patch('YAWN',{effect=effect})
  if mod.content.battle_anims:get('YAWN')then mod.content.battle_anims:patch('YAWN',animation)
  else mod.content.battle_anims:register('YAWN',animation)end
  for i=#opts.catalog.unsupportedStatus,1,-1 do
    if opts.catalog.unsupportedStatus[i]=='YAWN'then table.remove(opts.catalog.unsupportedStatus,i)end
  end
  M.animationReview={parts=parts,status='native-composition-needs-visual-review'}
  mod.events:on('battle.turn_ended',M.endTurn,200)
  mod.events:on('battle.battler_switched',M.switch,8000)
  mod.events:on('battle.ended',M.finish,200)
  if opts.supportLog and opts.supportLog.registerSegment then
    opts.supportLog.registerSegment({segmentId=M.CARD_ID,cardId=M.CARD_ID,
      schema='kasc.optional-feature-card/v1',version='1.0.0',owner=M.OWNER,active=true,
      dependencyStatus='native-status-weather-and-checkpoint',
      providerStatus='delayed-sleep-with-switch-lifetime',
      buildReceiptId='qa/gen6-wave15-alignment-20260909/LEAF-GUARD-YAWN-REVIEW.md',
      rollbackReceiptId='qa/gen6-wave15-alignment-20260909/LEAF-GUARD-YAWN-REVIEW.md'})
  end
  return M
end
