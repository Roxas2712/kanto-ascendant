-- Single-battle Pressure, III-VII. Native performMove owns the ordinary
-- PP deduction; this owner adds only the ability cost at move_used.
return function(mod,opts)
  local Battle=require('src.battle.BattleState')
  local M={CARD_ID='KASC-67-PRESSURE',OWNER='kasc.pressure/v1'}
  local scopes=setmetatable({},{__mode='k'})
  local aliases={}
  for id in pairs(opts.facts.data.moves)do
    for _,alias in ipairs(opts.species.moveIds(id))do aliases[alias]=id end
  end
  local mustPressure={IMPRISON=true,SNATCH=true,SPIKES=true,STEALTH_ROCK=true,TOXIC_SPIKES=true}
  local foes={[2]=true,[8]=true,[9]=true,[10]=true,[11]=true,[12]=true,[14]=true}
  local function pack(...)return {n=select('#',...),...}end
  function M.epoch(b)
    local row=b and b.data and b.data.move_effects and b.data.move_effects.HEAL_EFFECT
    local gen=row and row.kascPressure67==M.OWNER and opts.pp.epoch(b)
    if gen and gen>=3 and gen<=7 then return gen end
  end
  function M.targetsFoe(b,user,move,gen)
    local id=move and (aliases[move.id] or move.id)
    if not id or id=='STRUGGLE' then return false end
    local sky=mod.exports.pokemonSkyDrop67
    if sky and sky.pressureTargets(b,user,move)then return true end
    local row=opts.facts.move(id,gen)
    if not row then return false end
    -- The fact catalog has no old target row for Mirror Move. ADV/DPP
    -- treat the caller as self-targeting; V+ targets the chosen opponent.
    if id=='MIRROR_MOVE' and gen<=4 then return false end
    -- III/IV Snatch/Imprison have effect-specific PP loss, not the later
    -- unconditional usage flag. Their unimplemented move owners must not
    -- gain V+ behavior merely because this battle adapter is installed.
    if (id=='IMPRISON' or id=='SNATCH') and gen<=4 then return false end
    if mustPressure[id]then return true end
    if id=='CURSE'then
      for _,kind in ipairs(user.curTypes or {})do if kind=='GHOST'then return true end end
      return false
    end
    return foes[row.target]==true
  end
  function M.used(ev)
    local b=ev and ev.battle;local frame=b and scopes[b]
    if not frame or frame.seen or frame.user~=ev.user or not ev.move
        or ev.move.id~=frame.move.id then return end
    frame.seen=true
    local gen=M.epoch(b)
    if not gen or not frame.slot or frame.user.mon.hp<=0 then return end
    local foe=frame.user==b.player and b.enemy or b.player
    if not foe or not foe.mon or foe.mon.hp<=0
        or opts.abilities.activeAbility(b,foe)~='PRESSURE'
        or not M.targetsFoe(b,frame.user,ev.move,gen)then return end
    frame.slot.pp=math.max(0,frame.slot.pp-1)
  end
  function M.perform(original,b,user,target,inst,isCalled)
    local gen=M.epoch(b)
    if not gen or not user or not inst or not (user==b.player or user==b.enemy)then
      return original(b,user,target,inst,isCalled)
    end
    local move=b:moveDef(inst)
    if not move then return original(b,user,target,inst,isCalled)end
    local previous=scopes[b]
    local continuation=user.charging==inst and user.chargeReady
      or user.thrashTurns and user.thrashTurns>0 and user.thrashMove==inst
      or user.rageMove==inst
    local slot
    if not isCalled and not inst.struggle and not continuation and (tonumber(inst.pp)or 0)>0 then
      slot=inst
    elseif isCalled and gen>=4 and previous and previous.user==user and previous.callsMove then
      -- IV+: a called attack can charge its caller's real PP slot, never
      -- the temporary {pp=1} instance. III charges only the outer move.
      slot=previous.slot
    end
    local record=b:effectRecord(move.effect)
    scopes[b]={user=user,move=move,slot=slot,callsMove=record and record.callsMove~=nil}
    local result=pack(pcall(original,b,user,target,inst,isCalled))
    scopes[b]=previous
    if not result[1]then error(result[2],0)end
    return unpack(result,2,result.n)
  end
  mod.content.move_effects:patch('HEAL_EFFECT',{kascPressure67=M.OWNER})
  Battle._kascPressure67=M
  if not Battle._kascPressureWrapped67 then
    local original=Battle.performMove
    Battle.performMove=function(...)return Battle._kascPressure67.perform(original,...)end
    Battle._kascPressureWrapped67=true
  end
  mod.events:on('battle.move_used',M.used,9000)
  if opts.supportLog and opts.supportLog.registerSegment then
    opts.supportLog.registerSegment({segmentId=M.CARD_ID,cardId=M.CARD_ID,
      schema='kasc.optional-feature-card/v1',version='1.0.0',owner=M.OWNER,active=true,
      dependencyStatus='native-finite-pp-and-move-used',providerStatus='battle-only-era-bound-extra-pp',
      buildReceiptId='docs/WAVE_W_ABILITIES_20260908.md',
      rollbackReceiptId='docs/WAVE_W_ABILITIES_20260908.md'})
  end
  return M
end
