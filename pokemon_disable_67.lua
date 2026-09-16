-- Modern Disable/Cursed Body owns a round timeline, not Gen I's random
-- slot and before-action countdown. Native menu/AI use the projected slot.
return function(mod,opts)
  local B=require('src.battle.BattleState');local Status=require('src.battle.Status')
  local M={CARD_ID='KASC-67-DISABLE',OWNER='kasc.disable/v1'}
  local tr=opts.i18n.text
  local function side(b,w)return b and (w==b.player and 'player' or w==b.enemy and 'enemy') or nil end
  local function rows(b,create)
    if create then
      b.field=b.field or {};b.field.tokens=b.field.tokens or {}
      b.field.tokens[M.OWNER]=b.field.tokens[M.OWNER]or{}
    end
    return b and b.field and b.field.tokens and b.field.tokens[M.OWNER]
  end
  function M.epoch(b)
    local gen=b and opts.status.epoch(b)
    if getmetatable(b)==B and not b.result and not b.demo and b.kind~='link'
        and gen and gen>=3 and gen<=7 then return gen end
  end
  function M.clear(b,w)
    local r=rows(b);local key=side(b,w)
    if r and key and r[key]then
      r[key]=nil;w.disabledSlot=nil;w.disabledTurns=nil
    end
  end
  function M.refresh(b,w)
    local r=rows(b);local key=side(b,w);local v=r and r[key]
    if not v then return end
    if not M.epoch(b)or w.mon.hp<=0 or (b.turnCount or 0)>v.expires then M.clear(b,w);return end
    for i,m in ipairs(w.curMoves or{})do
      if m.id==v.move then
        w.disabledSlot=i;w.disabledTurns=v.expires-(b.turnCount or 0)+1;return v
      end
    end
    M.clear(b,w)
  end
  function M.start(b,w,move,curse)
    if not M.epoch(b)or not side(b,w)or not w.mon or w.mon.hp<=0 or not move
        or move=='STRUGGLE'then return false end
    if opts.abilities and opts.abilities.blocksMentalEffect(b,w,'DISABLE')then return false end
    M.refresh(b,w)
    if w.disabledSlot then return false end
    local slot
    for i,m in ipairs(w.curMoves or{})do if m.id==move and (m.pp or 0)>0 then slot=i;break end end
    if not slot then return false end
    local gen=M.epoch(b)
    local duration=gen==3 and b.rng(2,5)or gen==4 and b.rng(4,7)or 4
    -- Cursed Body occurs within the attacker's own active move. An ordinary
    -- slower Disable instead includes four following turns, not just three.
    if not curse and b._kascFlinchActed67 and b._kascFlinchActed67[w]then duration=duration+1 end
    local turn=b.turnCount or 0
    rows(b,true)[side(b,w)]={move=move,applied=turn,expires=turn+duration-1}
    w.disabledSlot=slot;w.disabledTurns=duration
    return true
  end
  function M.validateCheckpoint(b)
    local r=rows(b);if r==nil then return true end
    if type(r)~='table'then return false,'invalid_disable_container'end
    for key,v in pairs(r)do
      if (key~='player'and key~='enemy')or type(v)~='table' or type(v.move)~='string'
          or not(b.data and b.data.moves and b.data.moves[v.move])
          or type(v.applied)~='number' or v.applied%1~=0 or v.applied<0
          or v.applied>(b.turnCount or 0)or type(v.expires)~='number' or v.expires%1~=0
          or v.expires<v.applied or v.expires>v.applied+7 then return false,'invalid_disable_timeline'end
      for field in pairs(v)do
        if field~='move'and field~='applied'and field~='expires'then return false,'invalid_disable_field'end
      end
    end
    return true
  end
  function M.endTurn(ev)
    local b=ev and ev.battle;local r=rows(b);if not r then return end
    for _,w in ipairs({b.player,b.enemy})do
      local v=r[side(b,w)]
      if v and (b.turnCount or 0)>=v.expires then
        M.clear(b,w);b:sayNext(tr('Disable wore off!','Aussetzer lässt nach!'))
      else M.refresh(b,w)end
    end
  end
  local original=assert(mod.content.move_effects:get('DISABLE_EFFECT').run)
  mod.content.move_effects:patch('DISABLE_EFFECT',{kascDisable67=M.OWNER,run=function(ctx)
    local b=ctx.battle
    if not M.epoch(b)then return original(ctx)end
    if opts.priority.blocks(ctx)or not M.start(b,ctx.target,ctx.target.lastMove,false)then
      return {tr('But, it failed!','Doch es schlug fehl!'),failed=true}
    end
    return {tr('The last move was disabled!','Die letzte Attacke wurde blockiert!')}
  end})
  -- Keep native slot checks, but never let sleep/flinch/extra actions alter
  -- this round-based duration. Restore the projected count even on errors.
  Status._kascDisable67=M
  if not Status._kascDisableWrapped67 then
    local before=Status.beforeMove
    Status.beforeMove=function(w,rng,b,...)
      local owner=Status._kascDisable67;local v=owner.refresh(b,w)
      if not v then return before(w,rng,b,...)end
      local count=w.disabledTurns;w.disabledTurns=nil
      local function pack(...)return {n=select('#',...),...}end
      local result=pack(pcall(before,w,rng,b,...))
      if w.disabledSlot then w.disabledTurns=count end
      if not result[1]then error(result[2],0)end
      return unpack(result,2,result.n)
    end
    Status._kascDisableWrapped67=true
  end
  mod.events:on('battle.turn_ended',M.endTurn,90)
  mod.events:on('battle.ended',function(ev)
    local b=ev.battle
    for _,w in ipairs({b.player,b.enemy})do M.clear(b,w)end
    if rows(b)then b.field.tokens[M.OWNER]=nil end
  end,90)
  mod.events:on('battle.battler_switched',function(ev)
    -- The token belongs to a side; project neither the old slot nor its
    -- remaining duration onto the replacement Pokemon.
    local r=rows(ev.battle);local key=side(ev.battle,ev.battler)
    if r and key then r[key]=nil end
  end,8000)
  if opts.supportLog and opts.supportLog.registerSegment then
    opts.supportLog.registerSegment({segmentId=M.CARD_ID,cardId=M.CARD_ID,
      schema='kasc.optional-feature-card/v1',version='1.0.0',owner=M.OWNER,active=true,
      dependencyStatus='native-slot-round-checkpoint',providerStatus='disable-iii-vii-cursed-body-v-vii',
      buildReceiptId='docs/GEN6_WAVE15_SCOPE_20260909.md',rollbackReceiptId='docs/GEN6_WAVE15_SCOPE_20260909.md'})
  end
  return M
end
