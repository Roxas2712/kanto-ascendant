-- Dancer reacts to completed native move effects, not announcements. Its
-- extra execution is not a selected action and never copies saved PP.
return function(mod,opts)
  local B=require('src.battle.BattleState')
  local M={CARD_ID='KASC-67-DANCER',OWNER='kasc.dancer/v1'}
  local frames=setmetatable({},{__mode='k'})
  local reacting=setmetatable({},{__mode='k'})
  local dances={}
  for id,row in pairs(opts.facts.data.moves)do if row.generation<=7 then
    for _,flag in ipairs(row.flags or{})do if flag=='dance'then
      for _,alias in ipairs(opts.species.moveIds(id))do dances[alias]=true end
    end end
  end end
  local function pack(...)return{n=select('#',...),...}end
  local function copy(t)local r={};for k,v in pairs(t or{})do r[k]=v end;return r end
  function M.epoch(b)
    local r=b and b.data and b.data.move_effects and b.data.move_effects.HEAL_EFFECT
    return getmetatable(b)==B and not b.result and r and r.kascDancer67==M.OWNER
      and opts.status.epoch(b)==7
  end
  local function snapshot(w)
    return {hp=w.mon.hp,confused=w.confusedTurns,stages=copy(w.stages)}
  end
  local function changed(w,old)
    if w.mon.hp~=old.hp or w.confusedTurns~=old.confused then return true end
    for k,v in pairs(w.stages or{})do if v~=(old.stages[k]or 0)then return true end end
    for k,v in pairs(old.stages)do if v~=((w.stages or{})[k]or 0)then return true end end
    return false
  end
  function M.react(b,u,holder,move)
    if not M.epoch(b)or reacting[b]or holder==u or not holder or not holder.mon
        or holder~=b.player and holder~=b.enemy or holder.mon.hp<=0 or holder.invulnerable
        or opts.abilities.activeAbility(b,holder)~='DANCER'then return end
    reacting[b]=true
    local out=pack(pcall(function()
      b:sayNext(opts.i18n.text('Dancer copies the dance!','Tänzer macht den Tanz nach!'))
      -- Unlike Magic Bounce, Dancer runs the normal before-move checks.
      -- Sleep/freeze/paralysis/confusion/Disable can prevent this reaction.
      local flinch,skip=holder.flinched,holder.skipMove
      local stopped=pack(pcall(b.statusInterrupt,b,holder,u,move.id))
      -- Native beforeMove consumes these flags for a selected action. An
      -- extra dance must not erase the holder's still-pending lost turn.
      if flinch then holder.flinched=flinch end
      if skip then holder.skipMove=skip end
      if not stopped[1]then error(stopped[2],0)end
      if stopped[2]then return end
      local last=holder.lastMove
      local lock={holder.thrashTurns,holder.thrashMove,holder.thrashAnnounced}
      holder.thrashTurns,holder.thrashMove,holder.thrashAnnounced=nil,nil,nil
      local result=pack(pcall(b.performMove,b,holder,u,{id=move.id,pp=1},true))
      holder.lastMove=last
      holder.thrashTurns,holder.thrashMove,holder.thrashAnnounced=lock[1],lock[2],lock[3]
      if not result[1]then error(result[2],0)end
    end))
    reacting[b]=nil
    if not out[1]then error(out[2],0)end
  end
  function M.perform(original,b,u,t,slot,...)
    local move=slot and b:moveDef(slot)
    local bounce=mod.exports and mod.exports.pokemonMagicBounce67
    if not M.epoch(b)or reacting[b]or not move or not dances[move.id]
        or bounce and bounce.isReflected(b,u,slot)then return original(b,u,t,slot,...)end
    -- Only the original holder can respond. A replacement sent out after a
    -- KO does not inherit the outgoing Pokémon's opportunity to dance.
    local holder=u==b.player and b.enemy or b.player
    local prior=frames[b];local frame={success=false};frames[b]=frame
    local raw,old=rawget(b,'effectRecord'),b.effectRecord
    b.effectRecord=function(self,id)
      local record=old(self,id)
      if not record or id~=move.effect then return record end
      local projected={}
      if record.kind=='primary'and record.run then
        projected.run=function(ctx)
          local a,z=snapshot(ctx.user),snapshot(ctx.target)
          local out=record.run(ctx)
          if ctx.moveInst==slot and (changed(ctx.user,a)or changed(ctx.target,z))then frame.success=true end
          return out
        end
      else
        projected.afterDamage=function(ctx,...)
          -- The engine reaches this callback on a successful hit even when
          -- Endure leaves the recipient at 1 HP and deals zero actual HP.
          if ctx.moveInst==slot then frame.success=true end
          if record.afterDamage then return record.afterDamage(ctx,...)end
        end
      end
      return setmetatable(projected,{__index=record})
    end
    local out=pack(pcall(original,b,u,t,slot,...))
    b.effectRecord=raw;frames[b]=prior
    if not out[1]then error(out[2],0)end
    if frame.success then M.react(b,u,holder,move)end
    return unpack(out,2,out.n)
  end
  function M.validateCheckpoint(b)
    return not frames[b]and not reacting[b],'dancer_unsettled'
  end
  B._kascDancer67=M
  if not B._kascDancerWrapped67 then local old=B.performMove
    B.performMove=function(...)return B._kascDancer67.perform(old,...)end
    B._kascDancerWrapped67=true
  end
  mod.content.move_effects:patch('HEAL_EFFECT',{kascDancer67=M.OWNER})
  if opts.supportLog and opts.supportLog.registerSegment then
    opts.supportLog.registerSegment({segmentId=M.CARD_ID,cardId=M.CARD_ID,
      schema='kasc.optional-feature-card/v1',version='1.0.0',owner=M.OWNER,active=true,
      dependencyStatus='native-effects-status-before-move',providerStatus='dance-reaction-single-battles',
      buildReceiptId='docs/DANCER_67.md',rollbackReceiptId='docs/DANCER_67.md'})
  end
  return M
end
