-- Instruct repeats an observed own move slot as an extra native action.
-- Unlike a called move, the repeated action spends that slot's normal PP.
return function(mod,opts)
  local B=require('src.battle.BattleState')
  local M={CARD_ID='KASC-67-INSTRUCT',OWNER='kasc.instruct/v1',ID='INSTRUCT'}
  local effect='KA_INSTRUCT_67';local tr=opts.i18n.text
  local frames=setmetatable({},{__mode='k'});local repeating=setmetatable({},{__mode='k'})
  local pending=setmetatable({},{__mode='k'})
  local function copy(v)if type(v)~='table'then return v end;local out={};for k,x in pairs(v)do out[k]=copy(x)end;return out end
  local function pack(...)return {n=select('#',...),...}end
  local function side(b,w)return b and(w==b.player and'player'or w==b.enemy and'enemy')or nil end
  local function living(w)
    local mon=w and w.mon
    return mon and type(mon.hp)=='number'and mon.hp>0 and not w.fainted
      and not(mon.isEgg or mon.egg or mon.is_egg or mon.eggSpecies)
  end
  local function rows(b,create)
    if create then b.field=b.field or{};b.field.tokens=b.field.tokens or{};b.field.tokens[M.OWNER]=b.field.tokens[M.OWNER]or{}end
    return b and b.field and b.field.tokens and b.field.tokens[M.OWNER]
  end
  function M.epoch(b)
    local r=b and b.kascGenerationRulesReceipt
    local mark=b and b.data and b.data.move_effects and b.data.move_effects[effect]
    if getmetatable(b)==B and not b.demo and b.kind~='link'and not b.result
        and r and r.mode~='off'and type(r.activeEpoch)=='number'and r.activeEpoch%1==0
        and r.activeEpoch>=1 and r.activeEpoch<=7 and mark and mark.kascInstruct67==M.OWNER then return r.activeEpoch end
  end
  function M.isRepeating(b)return repeating[b]==true end
  function M.active(b,move)return M.epoch(b)and move and move.id==M.ID and move.backendMoveOwner==M.OWNER or false end
  -- Source-verified failinstruct/charge/recharge move numbers from the
  -- pinned Showdown moves.ts. Numeric identities cover native aliases too.
  local deniedNumbers={}
  for _,number in ipairs({13,19,37,63,76,80,91,102,117,118,119,130,143,144,165,166,
    200,205,214,253,264,267,274,291,301,307,308,338,340,382,383,416,439,448,459,467,
    507,553,554,562,566,588,601,606,607,669,689,690,704,711,744,792,794,795,800,
    896,897,898,899,900,905})do deniedNumbers[number]=true end
  -- Z-/Max-only definitions are independently excluded, even when an
  -- imported definition does not carry the source's boolean fields.
  for n=622,658 do deniedNumbers[n]=true end
  for n=695,703 do deniedNumbers[n]=true end
  deniedNumbers[719]=true;for n=723,728 do deniedNumbers[n]=true end
  deniedNumbers[743]=true;for n=757,774 do deniedNumbers[n]=true end;deniedNumbers[1000]=true
  local sources,denied={},{}
  for id,row in pairs(opts.facts.data.moves)do
    for _,alias in ipairs(opts.species.moveIds(id))do
      sources[alias]=id;if deniedNumbers[row.number]then denied[alias]=true end
    end
  end
  local function flagged(move,name)
    local flags=move and move.flags or{}
    if flags[name]then return true end
    for _,flag in ipairs(flags)do if flag==name then return true end end
    return false
  end
  function M.allowedMove(b,move)
    local record=move and b.data.move_effects[move.effect]
    local number=move and(move.backendMoveNumber or opts.facts.data.moves[sources[move.id]or move.id]
      and opts.facts.data.moves[sources[move.id]or move.id].number)
    return move and record and not denied[move.id]and not deniedNumbers[number]
      and not(move.isZ or move.isMax or move.isZOrMaxPowered)
      and not flagged(move,'failinstruct')and not flagged(move,'noinstruct')
      and not flagged(move,'charge')and not flagged(move,'recharge')
      and not record.charge and not record.callsMove and not record.recharge
      and not move.effect:find('UNSUPPORTED',1,true)or false
  end
  function M.clear(b,w)
    local r=rows(b);if not r then return end
    if w then local key=side(b,w);if key then r[key]=nil end else b.field.tokens[M.OWNER]=nil end
  end
  local function ownSlot(w,slot)
    for i,current in ipairs(w and w.curMoves or{})do if current==slot then return i end end
  end
  function M.used(ev)
    local frame=ev and frames[ev.battle]
    if frame and not ev.isCalled and ev.user==frame.user and ev.move and ev.move.id==frame.move then frame.used=true end
  end
  function M.observe(original,b,u,t,slot,called)
    local index=ownSlot(u,slot);local move=slot and b:moveDef(slot)
    if not M.epoch(b)or not move or not living(u)or not side(b,u)or not side(b,t)then
      return original(b,u,t,slot,called)
    end
    if called or not index then
      local out=pack(pcall(original,b,u,t,slot,called))
      if not out[1]then error(out[2],0)end
      local r=rows(b);local history=r and r[side(b,u)]
      -- A genuine detached/called action can replace native lastMove. It
      -- cannot create own-slot repeat rights, and an older own record must
      -- not survive that change to fail native checkpoint validation.
      if history and history.move~=u.lastMove then M.clear(b,u)end
      return unpack(out,2,out.n)
    end
    local prior=frames[b];local frame={user=u,move=move.id,used=false};frames[b]=frame
    local out=pack(pcall(original,b,u,t,slot,called));frames[b]=prior
    if not out[1]then error(out[2],0)end
    if frame.used and M.epoch(b)and living(u)and ownSlot(u,slot)==index
        and slot.id==move.id and u.lastMove==move.id and side(b,u)then
      rows(b,true)[side(b,u)]={species=u.mon.species,move=move.id,slot=index,target=side(b,t)}
    elseif frame.used then M.clear(b,u)end
    return unpack(out,2,out.n)
  end
  function M.target(b,w,move,history)
    local source=sources[move.id]or move.id
    local fact=opts.facts.move(source,M.epoch(b));local target=move.target or fact and fact.target
    if target==4 or target==7 or target==13 or target==15 then return w end
    if target==3 then return nil end -- no second active ally on this host
    local chosen=history and b[history.target]
    if target==5 then return chosen==w and w or nil end
    return chosen
  end
  function M.plan(b,u,t,instruct)
    if not M.active(b,instruct)or repeating[b]or not living(u)or not living(t)or u==t
        or not side(b,u)or not side(b,t)or t.invulnerable or t.mustRecharge or t.charging
        or t.thrashTurns or t.rageMove or t.bideTurns or t.trappingTurns
        or t.dynamax or t.isDynamaxed then return nil end
    local prepared=mod.exports.pokemonPreparedMoves67
    if prepared and prepared.prepared(b,t)then return nil end
    local r=rows(b);local history=r and r[side(b,t)]
    local slot=history and t.curMoves and t.curMoves[history.slot]
    local move=slot and b:moveDef(slot)
    if not history or history.species~=t.mon.species or history.move~=t.lastMove
        or not slot or slot.id~=history.move or(slot.pp or 0)<=0 or not M.allowedMove(b,move)then return nil end
    local lock=mod.exports.pokemonMoveLock67
    if lock and lock.selectionBlocked(b,t,slot)then return nil end
    local target=M.target(b,t,move,history)
    if not living(target)then return nil end
    return {user=t,slot=slot,move=move,target=target}
  end
  function M.noUseful(b,u,t,move)
    if not M.active(b,move)then return false end
    local plan=M.plan(b,u,t,move)
    if not plan then return true end
    local heal=mod.exports.pokemonHealBlock67
    return heal and heal.moveBlocked and heal.moveBlocked(b,t,plan.move,plan.target)or false
  end
  function M.repeatMove(b,ctx)
    local plan=M.plan(b,ctx.user,ctx.target,ctx.move);if not plan then return end
    local w,slot,target=plan.user,plan.slot,plan.target
    local opponent=w==b.player and b.enemy or b.player
    repeating[b]=true
    local flinch,skip,forced=w.flinched,w.skipMove,b.enemyActionForced
    local raw,perform=rawget(b,'performMove'),b.performMove
    b.performMove=function(self,user,other,inst,called)
      if user==w and inst==slot and not called then
        -- The ordinary III Taunt owner restricts selection only. This
        -- extra action is selected now, rather than before the Taunt.
        local taunt=mod.exports.pokemonMoveRestrictions67
        if M.epoch(self)==3 and taunt and taunt.taunted(self,w)
            and(plan.move.category=='status'or plan.move.power==0)then
          self:sayNext(tr('Taunt blocks status moves!','Verhöhner blockt Statusattacken!'));return
        end
        return perform(self,user,target,inst,false)
      end
      return perform(self,user,other,inst,called)
    end
    if w==b.enemy then b.enemyActionForced=true end
    -- executeAction refreshes binding and runs all native before-move
    -- checks against the physical foe. Only resolution uses the repeated
    -- move's original/self target, preserving confusion screen semantics.
    local out=pack(pcall(b.executeAction,b,w,opponent,slot))
    b.performMove=raw;b.enemyActionForced=forced
    if flinch then w.flinched=flinch end;if skip then w.skipMove=skip end
    repeating[b]=nil
    if not out[1]then error(out[2],0)end
  end
  function M.resolve(ctx)
    local b=ctx.battle;local priority=mod.exports.pokemonPriorityAbilities67
    -- This move is registered after Protection's initial record wrapping.
    -- Consult that actual shared flag/guard owner, not a duplicate shield.
    local protection=assert(mod.exports.pokemonProtection67)
    if protection.blocks(ctx)then b:sayNext(protection.notice(ctx,true));return end
    if not M.plan(b,ctx.user,ctx.target,ctx.move)or priority and priority.blocks(ctx)then
      b:cancelMoveAnim();b:sayNext(tr('But, it failed!','Doch es schlug fehl!'));return
    end
    b:sayNext(tr('%s received an instruction!','%s erhält ein Kommando!'):format(ctx.target.name))
    pending[b]=(pending[b]or 0)+1
    b:actNext(function()
      local out=pack(pcall(M.repeatMove,b,ctx))
      pending[b]=(pending[b]or 1)-1;if pending[b]<=0 then pending[b]=nil end
      if not out[1]then error(out[2],0)end
    end)
  end
  function M.validateCheckpoint(b)
    if frames[b]or repeating[b]or pending[b]then return false,'instruct_unsettled'end
    local r=rows(b);if r==nil then return true end
    if type(r)~='table'then return false,'invalid_instruct_container'end
    for key,v in pairs(r)do
      local w=(key=='player'or key=='enemy')and b[key]
      local slot=type(v)=='table'and w and w.curMoves and w.curMoves[v.slot]
      if not w or type(v)~='table'or type(v.species)~='string'or v.species~=w.mon.species
          or type(v.move)~='string'or not b.data.moves[v.move]or v.move~=w.lastMove
          or type(v.slot)~='number'or v.slot%1~=0 or v.slot<1 or v.slot>4
          or not slot or slot.id~=v.move or(v.target~='player'and v.target~='enemy')then
        return false,'invalid_instruct_last_action'
      end
      for field in pairs(v)do
        if field~='species'and field~='move'and field~='slot'and field~='target'then return false,'unknown_instruct_field'end
      end
    end
    return true
  end
  function M.install()
    B._kascInstruct67=M
    if B._kascInstructWrapped67 then return end
    local perform=B.performMove
    B.performMove=function(...)return B._kascInstruct67.observe(perform,...)end
    B._kascInstructWrapped67=true
  end
  local f=assert(opts.facts.move(M.ID,7))
  assert(f.number==689 and f.generation==7 and f.type=='PSYCHIC_TYPE'and f.category=='status'
    and f.power==0 and f.accuracy==100 and f.alwaysHits and f.pp==15 and f.priority==0 and f.target==10,'Instruct source drift')
  assert(not mod.content.moves:get(M.ID),'foreign Instruct owner')
  mod.content.move_effects:register(effect,{kind='primary',accuracyChecked=false,kascInstruct67=M.OWNER,perform=M.resolve})
  mod.content.moves:register(M.ID,{id=M.ID,name=tr(f.names.en,f.names.de),type=f.type,category='status',
    power=0,accuracy=100,pp=15,priority=0,target=10,effect=effect,kascBypassSub67=true,
    originGeneration=7,backendMoveNumber=689,backendMoveOwner=M.OWNER,backendLearnsetRevision=33,
    anim=copy(assert(mod.content.moves:get('METRONOME')).anim)})
  local animation=copy(assert(mod.content.battle_anims:get('METRONOME')));animation.source=M.OWNER
  mod.content.battle_anims:register(M.ID,animation)
  local Player=require('src.battle.AnimPlayer')
  function M.position(player,id)
    local row=player.data and player.data.moveAnims and player.data.moveAnims[id]
    if id~=M.ID or not row or row.source~=M.OWNER then return end
    for _,step in ipairs(player.steps or{})do local sprites={}
      for i,s in ipairs(step.sprites or{})do local q=copy(s)
        if q.x>0 and q.x<168 and q.y>0 and q.y<160 and mod.exports.pokemonPartnerHits67.inHud(q)then q.x=0 end
        sprites[i]=q
      end;step.sprites=sprites
    end
  end
  Player._kascInstructAnimation67=M
  if not Player._kascInstructAnimationWrapped67 then local start=Player.start
    Player.start=function(self,id,...)local out=start(self,id,...);Player._kascInstructAnimation67.position(self,id);return out end
    Player._kascInstructAnimationWrapped67=true
  end
  mod.events:on('battle.move_used',M.used,9000)
  mod.events:on('battle.battler_switched',function(ev)M.clear(ev.battle,ev.battler)end,8000)
  mod.events:on('battle.ended',function(ev)M.clear(ev.battle);pending[ev.battle]=nil end,8000)
  if opts.supportLog and opts.supportLog.registerSegment then
    opts.supportLog.registerSegment({segmentId=M.CARD_ID,cardId=M.CARD_ID,schema='kasc.optional-feature-card/v1',
      version='1.0.0',owner=M.OWNER,active=true,dependencyStatus='native-actual-slots-before-move-and-checkpoint-history',
      providerStatus='instruct-extra-native-action-normal-pp',buildReceiptId='docs/INSTRUCT_67.md',
      rollbackReceiptId='docs/GEN6_WAVE15_SCOPE_20260909.md'})
  end
  return M
end
