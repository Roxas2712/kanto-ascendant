-- Heal Block owns a five-round volatile and recovery/selection queries.
return function(mod,opts)
  local B=require('src.battle.BattleState')
  local M={CARD_ID='KASC-67-HEAL-BLOCK',OWNER='kasc.heal-block/v1'}
  local id,effect='HEAL_BLOCK','KA_HEAL_BLOCK_67'
  local tr=opts.i18n.text
  local heals,aliases={},{}
  for name,row in pairs(opts.facts.data.moves)do
    for _,alias in ipairs(opts.species.moveIds(name))do aliases[alias]=name end
    for _,flag in ipairs(row.flags or{})do if flag=='heal'then heals[name]=true end end
  end
  local function copy(v)if type(v)~='table'then return v end;local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r end
  local function pack(...)return{n=select('#',...),...}end
  local function side(b,w)return w==b.player and'player'or w==b.enemy and'enemy'or nil end
  local function rows(b,create)
    if create then b.field=b.field or{};b.field.tokens=b.field.tokens or{};b.field.tokens[M.OWNER]=b.field.tokens[M.OWNER]or{}end
    return b and b.field and b.field.tokens and b.field.tokens[M.OWNER]
  end
  function M.epoch(b)
    local r=b and b.kascGenerationRulesReceipt
    local mark=b and b.data and b.data.move_effects and b.data.move_effects[effect]
    if getmetatable(b)==B and not b.demo and b.kind~='link'and not b.result and r and r.mode~='off'
        and type(r.activeEpoch)=='number'and r.activeEpoch>=1 and r.activeEpoch<=7
        and mark and mark.kascHealBlock67==M.OWNER then return r.activeEpoch end
  end
  function M.blocked(b,w)
    if not M.epoch(b)or not w or not w.mon or w.mon.hp<=0 then return false end
    local r=rows(b);local key=side(b,w);local v=key and r and r[key]
    return v and(b.turnCount or 0)>=v.applied and(b.turnCount or 0)<=v.expires or false
  end
  function M.blocksRecovery(b,w,cause)
    local gen=M.epoch(b)
    -- IV blocks drain/seed/Wish and selected healing moves, but still permits
    -- held-item and ability recovery. V+ blocks those recovery sources too.
    return gen and M.blocked(b,w)and(gen>=5 or cause=='move'or cause=='drain'
      or cause=='leechseed'or cause=='wish')or false
  end
  function M.moveBlocked(b,w,move,target)
    if not move or not M.blocked(b,w)or move.isZ or move.isMax or move.isZOrMaxPowered then return false end
    local key=aliases[move.id]or move.id
    local puff=mod.exports.pokemonPollenPuff67
    if key=='POLLEN_PUFF'then return puff and puff.ally(b,w,target)or false end
    if not heals[key]then return false end
    local fact=opts.facts.move(key,M.epoch(b))
    -- The heal flag was added to damaging drain moves in VI. Earlier eras
    -- permit their damage but suppress their recovery separately.
    return not(M.epoch(b)<=5 and fact and fact.category~='status'and fact.meta and(fact.meta.drain or 0)>0)
  end
  function M.clear(b,w)
    local r=rows(b);if not r then return end
    if w then local key=side(b,w);if key then r[key]=nil end else b.field.tokens[M.OWNER]=nil end
  end
  function M.start(b,w)
    if not M.epoch(b)or not side(b,w)or not w.mon or w.mon.hp<=0 or M.blocked(b,w)then return false end
    local turn=b.turnCount or 0;rows(b,true)[side(b,w)]={applied=turn,expires=turn+4};return true
  end
  function M.noUseful(b,u,t,move)
    if not M.epoch(b)or not move then return false end
    if M.moveBlocked(b,u,move,t)then return true end
    if move.id~=id then return false end
    if not t or not t.mon or t.mon.hp<=0 or t.substituteHP or t.invulnerable or M.blocked(b,t)then return true end
    local A=mod.exports.pokemonAbilityEffects67
    return A.moveScope(b,u,t,true,function()
      local ctx={battle=b,user=u,target=t,move=move}
      return A.blocksMentalEffect(b,t,id)or mod.exports.pokemonPriorityAbilities67.blocks(ctx)
        or mod.exports.pokemonProtection67.blocks(ctx)
    end,move)
  end
  local function failed()return{tr('But, it failed!','Doch es schlug fehl!'),failed=true}end
  function M.cast(ctx)
    local b,u,t=ctx.battle,ctx.user,ctx.target
    if not M.epoch(b)or not u or not t or u==t or not side(b,u)or not side(b,t)
        or u.mon.hp<=0 or t.mon.hp<=0 or t.substituteHP or t.invulnerable then return failed()end
    if mod.exports.pokemonPriorityAbilities67.blocks(ctx)
        or mod.exports.pokemonAbilityEffects67.blocksMentalEffect(b,t,id)or not M.start(b,t)then return failed()end
    return{tr('%s cannot recover HP!','%s kann keine KP heilen!'):format(t.name)}
  end
  function M.endTurn(ev)
    local b=ev.battle;local r=rows(b);if not r then return end
    for _,key in ipairs({'player','enemy'})do local v=r[key]
      if v and(not M.epoch(b)or not b[key]or b[key].mon.hp<=0 or(b.turnCount or 0)>=v.expires)then
        r[key]=nil
        if M.epoch(b)and b[key]and b[key].mon.hp>0 then
          b:sayNext(tr('%s can recover HP again!','%s kann wieder KP heilen!'):format(b[key].name))
        end
      end
    end
  end
  function M.validateCheckpoint(b)
    local r=rows(b);if r==nil then return true end
    if type(r)~='table'then return false,'invalid_heal_block_container'end
    for key,v in pairs(r)do
      if(key~='player'and key~='enemy')or not b[key]or type(v)~='table'
          or type(v.applied)~='number'or v.applied%1~=0 or v.applied<0
          or v.applied>(b.turnCount or 0)or v.expires~=v.applied+4 then return false,'invalid_heal_block_timeline'end
      for k in pairs(v)do if k~='applied'and k~='expires'then return false,'unknown_heal_block_field'end end
    end
    return true
  end
  local function notice()return tr('Heal Block prevents\nthis move!','Heilsperre verhindert\ndiese Attacke!')end
  function M.perform(original,b,u,t,inst,called)
    local bounce=mod.exports.pokemonMagicBounce67
    if not(bounce and bounce.isReflected(b,u,inst))and M.moveBlocked(b,u,b:moveDef(inst),t)then
      b:sayNext(notice());return
    end
    return original(b,u,t,inst,called)
  end
  function M.usable(b,w)
    local out={};local ex=mod.exports;local lock=ex.pokemonChoiceItems67.locked(b,w)
    for i,slot in ipairs(w.curMoves or{})do local def=b:moveDef(slot)
      local unlimited=not w.isPlayer and b.ruleset and b.ruleset.enemyUnlimitedPP and M.epoch(b)==1
      local taunt=ex.pokemonMoveRestrictions67
      local ground=ex.pokemonGrounding67
      local throat=ex.pokemonThroatChop67
      local use=ex.pokemonConditionalUse67
      if def and i~=w.disabledSlot and(unlimited or(slot.pp or 0)>0)and(not lock or slot.id==lock.move)
          and not M.moveBlocked(b,w,def,w==b.player and b.enemy or b.player)
          and not(taunt and taunt.taunted(b,w)and(def.category=='status'or def.power==0))
          and not(ground and ground.blockedMove(b,w,slot))and not(throat and throat.blocked(b,w,def))
          and not(use and use.blocksSelection(b,w,def))then out[#out+1]=slot end
    end
    return out
  end
  function M.playerHasPP(original,b,...)
    if not M.blocked(b,b.player)then return original(b,...)end
    return original(b,...)and#M.usable(b,b.player)>0
  end
  function M.chooseMove(original,b,i,...)
    local slot=b.player and b.player.curMoves and b.player.curMoves[i]
    if b.phase=='moveSelect'and slot and M.moveBlocked(b,b.player,b:moveDef(slot),b.enemy)then
      b:say(notice());b.phase='messages';b.afterQueue='menu';return true
    end
    return original(b,i,...)
  end
  function M.enemyAction(original,b,...)
    local action=original(b,...)
    if not action or action.special or not M.moveBlocked(b,b.enemy,b:moveDef(action),b.player)or b:lockedAction(b.enemy)then return action end
    local pool=M.usable(b,b.enemy);local best=pool[1]
    for _,slot in ipairs(pool)do local def=b:moveDef(slot)
      if def.category~='status'and(def.power or 0)>0 then best=slot;break end
    end
    return best or{id='STRUGGLE',pp=1,struggle=true}
  end
  function M.earlySeed(original,w,opponent,b)
    local gen=M.epoch(b)
    if not gen or gen>=3 or not w.leechSeeded or not M.blocksRecovery(b,opponent,'leechseed')then return original(w,opponent,b)end
    -- This native leaf has no healing event. Suppress only its seed leaf,
    -- keep native poison first, then reproduce its existing seed HP loss
    -- and shared Toxic counter without recovering the blocked recipient.
    local seed=w.leechSeeded;w.leechSeeded=nil
    local out=pack(pcall(original,w,opponent,b));w.leechSeeded=seed
    if not out[1]then error(out[2],0)end
    local messages=out[2]
    if w.mon.hp>0 and opponent.mon.hp>0 then
      local damage=math.max(1,math.floor(w.mon.stats.hp/16))
      if w.toxicCounter then damage=damage*w.toxicCounter;w.toxicCounter=w.toxicCounter+1 end
      w.mon.hp=w.mon.hp-math.min(w.mon.hp,damage)
      messages[#messages+1]=b:romText('_HurtByLeechSeedText','LEECH SEED saps\n%s!',w.name)
    end
    return messages
  end
  function M.install()
    B._kascHealBlock67=M
    if B._kascHealBlockWrapped67 then return end
    local perform,choose,enemy,pp=B.performMove,B.chooseMove,B.enemyAction,B.playerHasPP
    B.performMove=function(...)return B._kascHealBlock67.perform(perform,...)end
    B.chooseMove=function(...)return B._kascHealBlock67.chooseMove(choose,...)end
    B.enemyAction=function(...)return B._kascHealBlock67.enemyAction(enemy,...)end
    B.playerHasPP=function(...)return B._kascHealBlock67.playerHasPP(pp,...)end
    local Status=require('src.battle.Status');local residual=Status.residual
    Status.residual=function(...)return B._kascHealBlock67.earlySeed(residual,...)end
    B._kascHealBlockWrapped67=true
  end
  local f=assert(opts.facts.move(id,4));local old=assert(mod.content.moves:get(id))
  assert(f.number==377 and f.category=='status'and f.pp==15 and f.accuracy==100 and f.target==11,'Heal Block source drift')
  assert(old.effect=='KA_GEN_MOVE_UNSUPPORTED_'..id,'foreign Heal Block owner')
  mod.content.move_effects:register(effect,{kind='primary',accuracyChecked=true,kascHealBlock67=M.OWNER,run=M.cast})
  mod.content.moves:patch(id,{effect=effect,backendMoveOwner=M.OWNER,backendLearnsetRevision=old.backendLearnsetRevision or 1})
  local anim=copy(assert(mod.content.battle_anims:get('DISABLE')));anim.source=M.OWNER
  mod.content.battle_anims:patch(id,anim)
  local Player=require('src.battle.AnimPlayer')
  function M.position(player,moveId)
    local row=player.data and player.data.moveAnims and player.data.moveAnims[moveId]
    if moveId~=id or not row or row.source~=M.OWNER then return end
    for _,step in ipairs(player.steps or{})do local sprites={}
      for i,s in ipairs(step.sprites or{})do local q=copy(s)
        if q.x>0 and q.x<168 and q.y>0 and q.y<160 and mod.exports.pokemonPartnerHits67.inHud(q)then q.x=0 end
        sprites[i]=q
      end;step.sprites=sprites
    end
  end
  Player._kascHealBlockAnimation67=M
  if not Player._kascHealBlockAnimationWrapped67 then local start=Player.start
    Player.start=function(self,moveId,...)local out=start(self,moveId,...);Player._kascHealBlockAnimation67.position(self,moveId);return out end
    Player._kascHealBlockAnimationWrapped67=true
  end
  for i=#opts.catalog.unsupportedStatus,1,-1 do if opts.catalog.unsupportedStatus[i]==id then table.remove(opts.catalog.unsupportedStatus,i)end end
  mod.events:on('battle.turn_ended',M.endTurn,-30000)
  mod.events:on('battle.battler_switched',function(ev)M.clear(ev.battle,ev.battler)end,8000)
  mod.events:on('battle.ended',function(ev)M.clear(ev.battle)end,8000)
  if opts.supportLog and opts.supportLog.registerSegment then
    opts.supportLog.registerSegment({segmentId=M.CARD_ID,cardId=M.CARD_ID,schema='kasc.optional-feature-card/v1',version='1.0.0',
      owner=M.OWNER,active=true,dependencyStatus='native-move-selection-and-recovery-owners',providerStatus='five-round-heal-block',
      buildReceiptId='docs/HEAL_BLOCK_67.md',rollbackReceiptId='docs/GEN6_WAVE15_SCOPE_20260909.md'})
  end
  return M
end
