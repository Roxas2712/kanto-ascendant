-- Reflect one native status-move execution, not its saved move or its PP.
-- The effect proxy is local to performMove: defer the decision until after
-- makeCtx enables Mold Breaker, but before native status accuracy is rolled.
return function(mod,opts)
  local B=require('src.battle.BattleState')
  local TC=require('src.battle.TypeChart')
  local M={CARD_ID='KASC-67-MAGIC-BOUNCE',OWNER='kasc.magic-bounce/v1'}
  local frames=setmetatable({},{__mode='k'})
  local reflected=setmetatable({},{__mode='k'})
  local aliases,flags={},{}
  for id,row in pairs(opts.facts.data.moves)do
    for _,flag in ipairs(row.flags or{})do if flag=='reflectable'then
      flags[id]=true
      for _,alias in ipairs(opts.species.moveIds(id))do flags[alias]=true;aliases[alias]=id end
    end end
  end
  local function pack(...)return{n=select('#',...),...}end
  function M.epoch(b)
    local r=b and b.data and b.data.move_effects and b.data.move_effects.HEAL_EFFECT
    local gen=r and r.kascMagicBounce67==M.OWNER and opts.status.epoch(b)
    if getmetatable(b)==B and not b.result and gen and gen>=5 and gen<=7 then return gen end
  end
  function M.isReflected(b,u,slot)
    local r=reflected[b];return r and r.user==u and r.slot==slot or false
  end
  function M.reflectionSource(b,u,move)
    local r=reflected[b]
    return r and r.user==u and move and r.slot.id==move.id and r.source or nil
  end
  function M.eligible(b,u,t,move)
    local caster=mod.exports and mod.exports.pokemonCasterStrikes67
    if caster and not caster.canCast(b,u,t,move)then return false end
    local gen=M.epoch(b);local frame=frames[b]
    local hazards=mod.exports and mod.exports.pokemonEntryHazards67
    local sideTarget=hazards and hazards.sideTarget(b,u,move)
    if not gen or reflected[b]or not frame or frame.invulnerable and not sideTarget or not flags[move.id]
        or move.category~='status'and not(move.id=='SAPPY_SEED'and move.backendMoveOwner=='kasc.partner-hits/v1')
        or u==t or not u or not t or not u.mon or not t.mon
        or u.mon.hp<=0 or t.mon.hp<=0 or t.invulnerable and not sideTarget
        or opts.abilities.activeAbility(b,t)~='MAGIC_BOUNCE'then return false end
    local ctx={battle=b,user=u,target=t,move=move}
    if not sideTarget and opts.protection.blocks(ctx)then return false end
    local id=aliases[move.id]or move.id
    if gen==5 and (id=='ROAR'or id=='WHIRLWIND')then
      local guard=opts.protection.active(b,t)
      if guard and guard~='ENDURE'then return false end
    end
    -- V/VI test Thunder Wave's type immunity before TryHit; VII reverses
    -- that order. Other reflected status moves ignore type effectiveness.
    if gen<=6 and id=='THUNDER_WAVE'then
      local projected=opts.conversion.project(b,u,move)
      if TC.effectiveness(projected.type,t.curTypes or{})==0 then return false end
    end
    return true
  end
  function M.reflect(ctx,notice)
    local b,u,t=ctx.battle,ctx.user,ctx.target
    b:cancelMoveAnim()
    b:sayNext(notice or opts.i18n.text('Magic Bounce reflected the move!','Magiespiegel wirft die Attacke zurück!'))
    local slot={id=ctx.move.id,pp=1}
    local previous=reflected[b];reflected[b]={user=t,slot=slot,source=u}
    local last=t.lastMove
    local out=pack(pcall(b.performMove,b,t,u,slot,true))
    reflected[b]=previous;t.lastMove=last
    if not out[1]then error(out[2],0)end
    return unpack(out,2,out.n)
  end
  function M.bounce(ctx)return M.reflect(ctx)end
  function M.perform(original,b,u,t,slot,...)
    local move=slot and b:moveDef(slot)
    if not M.epoch(b)or not move or not flags[move.id]or reflected[b]then
      return original(b,u,t,slot,...)
    end
    local previous=frames[b];frames[b]={invulnerable=t and t.invulnerable}
    local raw,old=rawget(b,'effectRecord'),b.effectRecord
    b.effectRecord=function(self,id)
      local record=old(self,id)
      if id~=move.effect or not record then return record end
      local proxy={};for k,v in pairs(record)do if k~='perform'then proxy[k]=v end end
      return setmetatable(proxy,{__index=function(_,key)
        if key=='perform'and M.eligible(b,u,t,move)then return M.bounce end
        return record[key]
      end})
    end
    local out=pack(pcall(original,b,u,t,slot,...))
    b.effectRecord=raw;frames[b]=previous
    if not out[1]then error(out[2],0)end
    return unpack(out,2,out.n)
  end
  function M.validateCheckpoint(b)
    return not frames[b]and not reflected[b],'magic_bounce_unsettled'
  end
  B._kascMagicBounce67=M
  if not B._kascMagicBounceWrapped67 then local old=B.performMove
    B.performMove=function(...)return B._kascMagicBounce67.perform(old,...)end
    B._kascMagicBounceWrapped67=true
  end
  mod.content.move_effects:patch('HEAL_EFFECT',{kascMagicBounce67=M.OWNER})
  if opts.supportLog and opts.supportLog.registerSegment then
    opts.supportLog.registerSegment({segmentId=M.CARD_ID,cardId=M.CARD_ID,
      schema='kasc.optional-feature-card/v1',version='1.0.0',owner=M.OWNER,active=true,
      dependencyStatus='native-performMove-status-protection',providerStatus='single-reflection-no-PP-copy',
      buildReceiptId='docs/MAGIC_BOUNCE_67.md',rollbackReceiptId='docs/MAGIC_BOUNCE_67.md'})
  end
  return M
end
