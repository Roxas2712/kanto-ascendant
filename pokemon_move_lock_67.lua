-- Soft move restrictions keep item/run/switch menus and intersect native
-- PP/Disable/Choice/Taunt. Nothing is stored as a saved Pokémon status.
return function(mod,opts)
  local B=require('src.battle.BattleState');local Status=require('src.battle.Status')
  local Player=require('src.battle.AnimPlayer')
  local M={CARD_ID='KASC-67-MOVE-LOCK',OWNER='kasc.move-lock/v1'}
  local tr=opts.i18n.text;local A=assert(opts.abilities)
  local frames=setmetatable({},{__mode='k'});local statusFrames=setmetatable({},{__mode='k'})
  local defs={ENCORE={number=227,generation=2,pp=5,type='NORMAL',target=10,flags={protect=1,mirror=1,bypasssub=1,metronome=1,failencore=1},parts={'GROWL','BARRIER'}},
    TORMENT={number=259,generation=3,pp=15,type='DARK',target=10,flags={protect=1,mirror=1,bypasssub=1,metronome=1},parts={'CONFUSE_RAY','GROWL'}},
    IMPRISON={number=286,generation=3,pp=10,type='PSYCHIC_TYPE',target=7,flags={bypasssub=1,metronome=1},parts={'BARRIER','CONFUSE_RAY'}},
    SPITE={number=180,generation=2,pp=10,type='GHOST',target=10,flags={protect=1,mirror=1,bypasssub=1,metronome=1},parts={'CONFUSE_RAY','LEER'}}}
  local denied={};for _,n in ipairs({274,383,227,382,118,102,119,267,166,214,165,144})do denied[n]=true end
  local noEncoreII={METRONOME=true,MIMIC=true,MIRROR_MOVE=true,SKETCH=true,SLEEP_TALK=true,TRANSFORM=true}
  local function copy(v)if type(v)~='table'then return v end;local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r end
  local function pack(...)return{n=select('#',...),...}end
  local function living(w)local m=w and w.mon;return m and type(m.hp)=='number'and m.hp>0 and not w.fainted
    and not(m.isEgg or m.egg or m.is_egg or m.eggSpecies)end
  local function side(b,w)return w==b.player and'player'or w==b.enemy and'enemy'or nil end
  local function index(b,w)
    local s=side(b,w);if not s then return end
    local party=s=='player'and b.game and b.game.save.party or b.enemyParty or{b.enemy.mon}
    for i,m in ipairs(party or{})do if i<=6 and m==w.mon then return i end end
  end
  local function slotIndex(w,slot)for i,m in ipairs(w and w.curMoves or{})do if m==slot and i<=4 then return i end end end
  local function state(b,create)
    if create then b.field=b.field or{};b.field.tokens=b.field.tokens or{}
      b.field.tokens[M.OWNER]=b.field.tokens[M.OWNER]or{history={},effects={}}end
    return b and b.field and b.field.tokens and b.field.tokens[M.OWNER]
  end
  function M.epoch(b)
    local r=b and b.kascGenerationRulesReceipt
    local e=b and b.data and b.data.move_effects and b.data.move_effects.KA_MOVE_LOCK_67_ENCORE
    if getmetatable(b)==B and not b.demo and b.kind~='link'and not b.result and r and r.mode~='off'
        and type(r.activeEpoch)=='number'and r.activeEpoch%1==0 and r.activeEpoch>=1 and r.activeEpoch<=7
        and e and e.kascMoveLock67==M.OWNER then return r.activeEpoch end
  end
  function M.moveEpoch(b,u,move)
    local gen=M.epoch(b);local d=move and defs[move.id]
    local e=d and b.data.move_effects[move.effect]
    if not gen or not d or move.backendMoveOwner~=M.OWNER or not e or e.kascMoveLock67~=M.OWNER then return end
    if gen<d.generation and not(living(u)and opts.rules.ownedGiftBattleCompatible
        and opts.rules.ownedGiftBattleCompatible(b.game,u.mon,b.data.pokemon[u.mon.species]))then return end
    return math.max(gen,d.generation)
  end
  local function validIdentity(b,w,row)
    return w and w.mon and index(b,w)and row and row.species==w.mon.species and row.party==index(b,w)
  end
  function M.effect(b,w,name)
    local gen=M.epoch(b);local s=state(b);local r=s and s.effects[side(b,w)]
    local row=r and r[name]
    if not gen or not living(w)or not validIdentity(b,w,row)or row.profile~=gen or(b.turnCount or 0)<row.applied
        or row.expires and(b.turnCount or 0)>row.expires then return end
    return row
  end
  function M.last(b,w,gen)
    local s=state(b);local row=s and s.history[side(b,w)]
    local slot=row and w.curMoves and w.curMoves[row.slot]
    if not M.epoch(b)or not living(w)or not validIdentity(b,w,row)or not slot or slot.id~=row.move
        or gen<=2 and row.noEncoreII then return end
    return row,slot,b:moveDef(slot)
  end
  local function failencore(move)
    local f=move.flags or{};if f.failencore then return true end
    for _,v in ipairs(f)do if v=='failencore'then return true end end
    local fact=opts.facts.data.moves[move.id]
    return denied[move.backendMoveNumber or fact and fact.number]or move.isZ or move.isMax or move.isZOrMaxPowered
  end
  function M.encoreSlot(b,w)
    local e=M.effect(b,w,'encore');if not e then return end
    for _,slot in ipairs(w.curMoves or{})do if slot.id==e.move then return slot,e end end
  end
  function M.selectionBlocked(b,w,slot)
    if not M.epoch(b)or not living(w)or not slot or slot.struggle or slot.id=='STRUGGLE'then return false end
    local e=M.effect(b,w,'encore');if e and slot.id~=e.move then return 'encore'end
    local t=M.effect(b,w,'torment');local last=t and M.last(b,w,t.epoch)
    if last and last.move==slot.id and last.move~='STRUGGLE'then return 'torment'end
    local foe=w==b.player and b.enemy or w==b.enemy and b.player
    if foe and M.effect(b,foe,'imprison')then
      for _,m in ipairs(foe.curMoves or{})do if m.id==slot.id then return 'imprison'end end
    end
    return false
  end
  function M.imprisoned(b,w,slot)
    if not M.epoch(b)or not living(w)or not slot or slot.struggle or slot.id=='STRUGGLE'then return false end
    local foe=w==b.player and b.enemy or w==b.enemy and b.player
    if not foe or not M.effect(b,foe,'imprison')then return false end
    for _,m in ipairs(foe.curMoves or{})do if m.id==slot.id then return true end end
    return false
  end
  local function overlap(a,z)
    for _,x in ipairs(a.curMoves or{})do if x.id~='STRUGGLE'then
      for _,y in ipairs(z.curMoves or{})do if x.id==y.id then return true end end
    end end
    return false
  end
  local function blocked(ctx)
    return defs[ctx.move.id].target~=7 and(mod.exports.pokemonProtection67.blocks(ctx)
      or mod.exports.pokemonPriorityAbilities67.blocks(ctx)
      or A.blocksMentalEffect(ctx.battle,ctx.target,ctx.move.id))or false
  end
  function M.plan(b,u,t,move)
    local gen=M.moveEpoch(b,u,move);if not gen or not living(u)or not living(t)or not index(b,u)
        or not index(b,t)or u==t then return end
    local ctx={battle=b,user=u,target=t,move=move}
    if blocked(ctx)or defs[move.id].target~=7 and t.invulnerable then return end
    if move.id=='IMPRISON'then
      if M.effect(b,u,'imprison')or gen<=4 and not overlap(u,t)then return end
      return{epoch=gen,name='imprison',target=u}
    elseif move.id=='TORMENT'then
      if M.effect(b,t,'torment')then return end
      return{epoch=gen,name='torment',target=t}
    end
    local history,slot,last=M.last(b,t,gen)
    if not history or not slot or(slot.pp or 0)<=0 or not last then return end
    if move.id=='ENCORE'then
      if M.effect(b,t,'encore')or failencore(last)then return end
      return{epoch=gen,name='encore',target=t,move=slot.id}
    end
    if move.id=='SPITE'and not last.isZ and slot.id~='STRUGGLE'then return{epoch=gen,target=t,slot=slot}end
  end
  function M.noUseful(b,u,t,move)
    if not M.epoch(b)or not move then return false end
    if M.selectionBlocked(b,u,move)then return true end
    if not defs[move.id]or not M.moveEpoch(b,u,move)then return false end
    return A.moveScope(b,u,t,true,function()return not M.plan(b,u,t,move)end,move)
  end
  local function failure()return{tr('But, it failed!','Doch es schlug fehl!'),failed=true}end
  function M.cast(ctx)
    local b=ctx.battle;local p=M.plan(b,ctx.user,ctx.target,ctx.move);if not p then return failure()end
    if ctx.move.id=='SPITE'then
      local amount=p.epoch<=3 and ctx.rng(2,5)or 4;local lost=math.min(amount,p.slot.pp)
      p.slot.pp=p.slot.pp-lost
      return{tr('%s lost %d PP!','%s verliert %d AP!'):format(b.data.moves[p.slot.id].name,lost)}
    end
    local s=state(b,true);local key=side(b,p.target);s.effects[key]=s.effects[key]or{}
    local turn=b.turnCount or 0
    local row={species=p.target.mon.species,party=index(b,p.target),profile=M.epoch(b),epoch=p.epoch,applied=turn}
    if p.name=='encore'then
      local duration=p.epoch<=3 and ctx.rng(3,6)or p.epoch==4 and ctx.rng(4,8)or 3
      if p.epoch>=5 and b._kascFlinchActed67 and b._kascFlinchActed67[p.target]then duration=duration+1 end
      row.move=p.move;row.expires=turn+duration-1
    end
    s.effects[key][p.name]=row
    return{tr('%s is affected by %s!','%s steht unter %s!'):format(p.target.name,ctx.move.name)}
  end
  function M.used(ev)
    local f=ev and frames[ev.battle]
    if f and ev.user==f.user and not ev.isCalled and ev.move and ev.move.id==f.move then f.used=true end
  end
  local function notice(b,why)
    local id=why:upper();local move=b.data.moves[id]
    local name=move and move.name or tr(id,id)
    return tr('This move is blocked by %s!','Diese Attacke wird durch %s blockiert!'):format(name)
  end
  function M.perform(original,b,u,t,slot,called)
    local bounce=mod.exports.pokemonMagicBounce67
    if not(bounce and bounce.isReflected(b,u,slot))and M.imprisoned(b,u,slot)then b:sayNext(notice(b,'imprison'));return end
    local at=slotIndex(u,slot);local move=slot and b:moveDef(slot)
    if not M.epoch(b)or called or not at or not move or not index(b,u)then return original(b,u,t,slot,called)end
    local prior=frames[b];local f={user=u,move=move.id,used=false};frames[b]=f
    local out=pack(pcall(original,b,u,t,slot,called));frames[b]=prior
    if not out[1]then error(out[2],0)end
    if f.used and index(b,u)and slotIndex(u,slot)==at and slot.id==move.id then
      state(b,true).history[side(b,u)]={species=u.mon.species,party=index(b,u),slot=at,
        move=move.id,turn=b.turnCount or 0,noEncoreII=noEncoreII[move.id]or false}
    end
    return unpack(out,2,out.n)
  end
  -- Selection is an actual action surface, not an AI forecast. Reuse the
  -- current shared intersection rather than invent a second Choice/Taunt.
  function M.usable(b,w)
    local out={};local pool=assert(mod.exports.pokemonHealBlock67).usable(b,w)
    for _,slot in ipairs(pool)do if not M.selectionBlocked(b,w,slot)then out[#out+1]=slot end end
    return out
  end
  local function relevant(b,w)return M.effect(b,w,'encore')or M.effect(b,w,'torment')
    or M.effect(b,w==b.player and b.enemy or b.player,'imprison')end
  function M.override(b,w,action)
    if not action or action.special or action.struggle or not M.epoch(b)or not M.effect(b,w,'encore')
        or b:menuLockedAction(w)or b:fightLockedAction(w)then return action end
    local slot=M.encoreSlot(b,w)
    for _,m in ipairs(M.usable(b,w))do if m==slot then return m end end
    return{id='STRUGGLE',pp=1,struggle=true}
  end
  function M.execute(original,b,u,t,action,...)
    return original(b,u,t,M.override(b,u,action),...)
  end
  function M.resolve(original,b,action,...)
    return original(b,M.override(b,b.player,action),...)
  end
  function M.playerHasPP(original,b,...)
    if not M.epoch(b)or not relevant(b,b.player)then return original(b,...)end
    return#M.usable(b,b.player)>0
  end
  function M.choose(original,b,i,...)
    local slot=b.player and b.player.curMoves and b.player.curMoves[i]
    local why=b.phase=='moveSelect'and slot and M.selectionBlocked(b,b.player,slot)
    if why then b:say(notice(b,why));b.phase='messages';b.afterQueue='menu';return true end
    return original(b,i,...)
  end
  function M.enemy(original,b,...)
    local action=original(b,...)
    if not M.epoch(b)or not relevant(b,b.enemy)or not action or action.special or b:lockedAction(b.enemy)then return action end
    local pool=M.usable(b,b.enemy);for _,slot in ipairs(pool)do if action==slot then return action end end
    -- Keep fallback pure and deterministic; the native AI already made
    -- its genuine random decision before this legality intersection.
    local best=pool[1];for _,slot in ipairs(pool)do local def=b:moveDef(slot)
      if def.category~='status'and(def.power or 0)>0 then best=slot;break end end
    if best~=action then b.enemyActionForced=true end
    return best or{id='STRUGGLE',pp=1,struggle=true}
  end
  function M.before(original,w,rng,b,id,...)
    if not M.imprisoned(b,w,{id=id})then return original(w,rng,b,id,...)end
    -- Genuine early checks (flinch/sleep/freeze/held/Disable/Truant) retain
    -- their own owner. Imprison precedes confusion and the late paralysis
    -- phase: suspend only those leaves, never manufacture a status ID.
    local confused=w.confusedTurns
    local prior=statusFrames[b];statusFrames[b]={who=w,id=id};w.confusedTurns=nil
    local out=pack(pcall(original,w,rng,b,id,...))
    w.confusedTurns=confused;statusFrames[b]=prior
    if not out[1]then error(out[2],0)end
    if out[2]then local messages=out[3]or{};messages[#messages+1]=notice(b,'imprison');return false,messages,false end
    return unpack(out,2,out.n)
  end
  -- The existing KASC lifecycle's paralysis handler consults this lazy
  -- helper before its own generation gate. Raw saved PAR remains visible
  -- to all genuine early status/ability/item owners throughout the scope.
  function M.suspendsLateStatus(b,w)
    local f=statusFrames[b]
    return f and f.who==w and M.imprisoned(b,w,{id=f.id})or false
  end
  function M.clear(b,w)
    local s=state(b);if not s then return end
    if w then local key=side(b,w);if key then s.history[key]=nil;s.effects[key]=nil end
    else b.field.tokens[M.OWNER]=nil end
  end
  function M.endTurn(ev)
    local b=ev.battle;local s=state(b);if not s then return end
    for _,key in ipairs({'player','enemy'})do local effects=s.effects[key]
      if effects then for name,row in pairs(effects)do
        local slot=name=='encore'and M.encoreSlot(b,b[key])
        if not M.effect(b,b[key],name)or row.expires and(b.turnCount or 0)>=row.expires
            or name=='encore'and(not slot or(slot.pp or 0)<=0)then effects[name]=nil end
      end end
    end
  end
  local function integer(n,a,z)return type(n)=='number'and n%1==0 and n>=a and n<=z end
  function M.validateCheckpoint(b)
    if frames[b]or statusFrames[b]then return false,'move_lock_unsettled'end
    local s=state(b);if s==nil then return true end
    if type(s)~='table'or type(s.history)~='table'or type(s.effects)~='table'then return false,'invalid_move_lock_container'end
    for k in pairs(s)do if k~='history'and k~='effects'then return false,'unknown_move_lock_field'end end
    for key,row in pairs(s.history)do local w=(key=='player'or key=='enemy')and b[key]
      local slot=type(row)=='table'and w and w.curMoves and w.curMoves[row.slot]
      if not w or type(row)~='table'or not validIdentity(b,w,row)or not integer(row.slot,1,4)
          or not slot or slot.id~=row.move or not b.data.moves[row.move]or not integer(row.turn,0,b.turnCount or 0)
          or type(row.noEncoreII)~='boolean'or row.noEncoreII~=(noEncoreII[row.move]or false)then return false,'invalid_move_lock_history'end
      for k in pairs(row)do if k~='species'and k~='party'and k~='slot'and k~='move'and k~='turn'and k~='noEncoreII'then return false,'unknown_move_lock_history_field'end end
    end
    for key,effects in pairs(s.effects)do local w=(key=='player'or key=='enemy')and b[key]
      if not w or type(effects)~='table'then return false,'invalid_move_lock_side'end
      for name,row in pairs(effects)do
        local minimum=name=='encore'and 2 or(name=='torment'or name=='imprison')and 3
        if not minimum or type(row)~='table'or not validIdentity(b,w,row)or row.profile~=M.epoch(b)
            or not integer(row.epoch,minimum,7)or row.epoch~=math.max(minimum,row.profile)
            or not integer(row.applied,0,b.turnCount or 0)then return false,'invalid_move_lock_identity'end
        if name=='encore'then
          local duration=row.epoch<=3 and 6 or row.epoch==4 and 8 or 4
          local shortest=row.epoch==4 and 4 or 3
          if not integer(row.expires,row.applied+shortest-1,row.applied+duration-1)or not b.data.moves[row.move]
              or failencore(b.data.moves[row.move])then return false,'invalid_encore_timeline'end
          local found;for _,m in ipairs(w.curMoves or{})do if m.id==row.move then found=true end end
          if not found then return false,'invalid_encore_slot'end
        elseif row.move~=nil or row.expires~=nil then return false,'unexpected_move_lock_timeline'end
        for k in pairs(row)do if k~='species'and k~='party'and k~='profile'and k~='epoch'and k~='applied'and k~='move'and k~='expires'then return false,'unknown_move_lock_effect_field'end end
      end
    end
    return true
  end
  for _,id in ipairs({'ENCORE','TORMENT','IMPRISON','SPITE'})do
    local d=defs[id];local f=assert(opts.facts.move(id,7));local old=assert(mod.content.moves:get(id))
    assert(f.number==d.number and f.generation==d.generation and f.category=='status'and f.power==0
      and f.type==d.type and f.pp==d.pp and f.accuracy==100 and f.priority==0 and f.target==d.target,'move lock source drift '..id)
    assert(not old.backendMoveOwner and old.effect=='KA_GEN_MOVE_UNSUPPORTED_'..id,'foreign move lock owner '..id)
    local effect='KA_MOVE_LOCK_67_'..id
    mod.content.move_effects:register(effect,{kind='primary',accuracyChecked=id~='IMPRISON',run=M.cast,kascMoveLock67=M.OWNER})
    local flags=copy(d.flags);if id=='IMPRISON'then flags.snatch=1;flags.mustpressure=1 elseif id~='IMPRISON'then flags.reflectable=1 end
    mod.content.moves:patch(id,{effect=effect,power=0,pp=d.pp,accuracy=100,priority=0,type=d.type,category='status',target=d.target,
      flags=flags,kascBypassSub67=true,backendMoveOwner=M.OWNER,backendMoveNumber=d.number,
      originGeneration=d.generation,backendLearnsetRevision=old.backendLearnsetRevision or 1})
    local animation={seq={},source=M.OWNER}
    for _,part in ipairs(d.parts)do for _,step in ipairs(assert(mod.content.battle_anims:get(part)).seq)do animation.seq[#animation.seq+1]=copy(step)end end
    mod.content.battle_anims:patch(id,animation)
    for i=#opts.moves.unsupportedStatus,1,-1 do if opts.moves.unsupportedStatus[i]==id then table.remove(opts.moves.unsupportedStatus,i)end end
  end
  function M.position(player,id)
    local animation=player.data and player.data.moveAnims and player.data.moveAnims[id]
    if not defs[id]or not animation or animation.source~=M.OWNER then return end
    for _,step in ipairs(player.steps or{})do local sprites={}
      for i,s in ipairs(step.sprites or{})do local q=copy(s)
        if q.x>0 and q.x<168 and q.y>0 and q.y<160 and mod.exports.pokemonPartnerHits67.inHud(q)then q.x=0 end
        sprites[i]=q
      end;step.sprites=sprites
    end
  end
  function M.install()
    B._kascMoveLock67=M;Status._kascMoveLock67=M;Player._kascMoveLock67=M
    local wrappers={performMove='perform',executeAction='execute',resolveTurn='resolve',playerHasPP='playerHasPP',chooseMove='choose',enemyAction='enemy'}
    B._kascMoveLockWrappers67=B._kascMoveLockWrappers67 or{}
    for name,method in pairs(wrappers)do
      if B[name]~=B._kascMoveLockWrappers67[name]then local original=B[name];local key=method
        local wrapper=function(...)return B._kascMoveLock67[key](original,...)end
        B[name]=wrapper;B._kascMoveLockWrappers67[name]=wrapper
      end
    end
    if not Status._kascMoveLockWrapped67 then local original=Status.beforeMove
      Status.beforeMove=function(...)return Status._kascMoveLock67.before(original,...)end;Status._kascMoveLockWrapped67=true end
    if not Player._kascMoveLockWrapped67 then local original=Player.start
      Player.start=function(self,id,...)local out=pack(original(self,id,...));Player._kascMoveLock67.position(self,id);return unpack(out,1,out.n)end
      Player._kascMoveLockWrapped67=true end
  end
  mod.events:on('battle.move_used',M.used,6501)
  mod.events:on('battle.turn_ended',M.endTurn,-30001)
  mod.events:on('battle.battler_switched',function(ev)M.clear(ev.battle,ev.battler)end,8000)
  mod.events:on('battle.ended',function(ev)M.clear(ev.battle)end,8000)
  M.install()
  if opts.supportLog and opts.supportLog.registerSegment then opts.supportLog.registerSegment({segmentId=M.CARD_ID,
    cardId=M.CARD_ID,schema='kasc.optional-feature-card/v1',version='1.0.0',owner=M.OWNER,active=true,
    dependencyStatus='native-action-slot-pp-and-round-provenance',providerStatus='encore-torment-imprison-spite',
    buildReceiptId='docs/MOVE_LOCK_67.md',rollbackReceiptId='docs/MOVE_LOCK_67.md'})end
  return M
end
