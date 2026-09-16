-- Grudge is an attempted-action volatile, not a major Pokémon status.
-- Only an authentic native lethal body strike can consume actual own AP.
return function(mod,opts)
  local B=require('src.battle.BattleState');local FX=require('src.battle.EffectRegistry')
  local Status=require('src.battle.Status');local Player=require('src.battle.AnimPlayer')
  local M={CARD_ID='KASC-67-GRUDGE',OWNER='kasc.grudge/v1',ID='GRUDGE'}
  local tr=opts.i18n.text;local effect='KA_GRUDGE_67'
  local dispatch=setmetatable({},{__mode='k'});local strikes=setmetatable({},{__mode='k'})
  local function copy(v)if type(v)~='table'then return v end;local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r end
  local function pack(...)return{n=select('#',...),...}end
  local function integer(v,a,z)return type(v)=='number'and v%1==0 and v>=a and v<=z end
  local function live(w)local m=w and w.mon;return m and(tonumber(m.hp)or 0)>0 and not w.fainted
    and not(m.egg or m.isEgg or m.is_egg or m.eggSpecies)end
  local function side(b,w)return w==b.player and'player'or w==b.enemy and'enemy'or nil end
  local function index(b,w)
    local key=side(b,w);if not key then return end
    if key=='enemy'and b.kind=='wild'then return 1 end
    local party=key=='player'and b.game and b.game.save and b.game.save.party or b.enemyParty
    for i,m in ipairs(party or{})do if i<=6 and m==w.mon then return i end end
  end
  local function slotIndex(w,slot)for i,s in ipairs(w and w.curMoves or{})do if i<=4 and s==slot then return i end end end
  local function slotNamed(w,id)for _,s in ipairs(w and w.curMoves or{})do if s.id==id then return s end end end
  local function state(b,create)
    if create then b.field=b.field or{};b.field.tokens=b.field.tokens or{};b.field.tokens[M.OWNER]=b.field.tokens[M.OWNER]or{}end
    return b and b.field and b.field.tokens and b.field.tokens[M.OWNER]
  end
  function M.epoch(b)
    local r=b and b.kascGenerationRulesReceipt;local e=b and b.data and b.data.move_effects and b.data.move_effects[effect]
    return getmetatable(b)==B and not b.demo and b.kind~='link'and not b.result
      and r and r.mode~='off'and integer(r.activeEpoch,1,7)and e and e.kascGrudge67==M.OWNER and r.activeEpoch or nil
  end
  function M.moveEpoch(b,u,move)
    local gen=M.epoch(b);local e=move and b.data.move_effects[move.effect]
    if not gen or not move or move.id~=M.ID or move.backendMoveOwner~=M.OWNER or not e or e.kascGrudge67~=M.OWNER then return end
    if gen<3 and not(live(u)and opts.rules.ownedGiftBattleCompatible
        and opts.rules.ownedGiftBattleCompatible(b.game,u.mon,b.data.pokemon[u.mon.species]))then return end
    return math.max(3,gen)
  end
  function M.row(b,w)
    local gen=M.epoch(b);local s=state(b);local row=s and s[side(b,w)]
    return gen and type(row)=='table'and w.mon and row.species==w.mon.species and row.party==index(b,w)
      and row.profile==gen and row.epoch==math.max(3,gen)and integer(row.applied,0,b.turnCount or 0)and row or nil
  end
  function M.clear(b,w)
    local s=state(b);if not s then return end
    if w then local key=side(b,w);if key then s[key]=nil end else b.field.tokens[M.OWNER]=nil end
  end
  local function proof(row)
    local r=copy(row);r.proof=nil
    return opts.rules.receipts.hash(M.OWNER..':'..opts.rules.receipts.canonical(r))
  end
  function M.blockedSlot(b,w,slot)
    if M.epoch(b)~=1 or w~=b.enemy or not live(w)then return false end
    local s=state(b);local key=side(b,w);local party=index(b,w);local i=slotIndex(w,slot)
    local rows=s and s.drained and s.drained[key];local row=rows and rows[party]and rows[party][i]
    return row and row.owner==M.OWNER and row.profile==1 and row.epoch==3
      and row.species==w.mon.species and row.party==party and row.slot==i and row.move==slot.id
      and row.proof==proof(row)and slot.pp==0 or false
  end
  function M.filterAction(b,action)
    if M.epoch(b)~=1 or not action or action.special or action.struggle or not action.id
        or b:lockedAction(b.enemy)then return action end
    local actual=slotIndex(b.enemy,action)and action or slotNamed(b.enemy,action.id)
    if not actual or not M.blockedSlot(b,b.enemy,actual)then return action end
    local usable={}
    for i,slot in ipairs(b.enemy.curMoves or{})do
      -- This authentic effect restricts only its drained slot. Ordinary
      -- zero-AP Gen-I slots still follow genuine unlimited enemy AP.
      if i~=b.enemy.disabledSlot and b:moveDef(slot)and not M.blockedSlot(b,b.enemy,slot)then usable[#usable+1]=slot end
    end
    return #usable>0 and usable[b.rng(1,#usable)]or{id='STRUGGLE',pp=1,struggle=true}
  end
  function M.noUseful(b,u,t,move)
    if not M.moveEpoch(b,u,move)then return false end
    if not live(u)or not live(t)or not index(b,u)or u==t then return true end
    -- Reusing Grudge genuinely renews its window after this attempted
    -- action. A current arm alone must not make the move fail forecasting.
    for _,slot in ipairs(t.curMoves or{})do local d=b:moveDef(slot);local e=d and b.data.move_effects[d.effect]
      if d and d.category~='status'and(slot.pp or 0)>0 and((d.power or 0)>0 or e and e.kind=='full')then return false end
    end
    return true
  end
  function M.cast(ctx)
    local b,u=ctx.battle,ctx.user;local gen=M.moveEpoch(b,u,ctx.move)
    if not gen or not live(u)or not index(b,u)then return{tr('But, it failed!','Doch es schlug fehl!'),failed=true}end
    state(b,true)[side(b,u)]={species=u.mon.species,party=index(b,u),profile=M.epoch(b),epoch=gen,applied=b.turnCount or 0}
    return{tr('%s wants the foe to bear a grudge!','%s setzt Nachspiel ein!'):format(u.name)}
  end
  function M.before(original,w,rng,b,...)
    if M.epoch(b)then M.clear(b,w)end
    return original(w,rng,b,...)
  end
  function M.perform(original,b,u,t,inst,called)
    if not M.epoch(b)or not live(u)or not inst then return original(b,u,t,inst,called)end
    local move=b:moveDef(inst);if not move then return original(b,u,t,inst,called)end
    local prior=dispatch[b];local record=b:effectRecord(move.effect);local source
    if called then
      if prior and prior.user==u and prior.callsMove then source=prior.source end
    elseif slotIndex(u,inst)then
      -- Direct native performMove fixtures also represent an own move
      -- attempt; real executeAction already cleared at priority100 above.
      M.clear(b,u)
      local continuation=u.charging==inst and u.chargeReady
        or u.thrashTurns and u.thrashTurns>0 and u.thrashMove==inst or u.rageMove==inst
      if M.blockedSlot(b,u,inst)and not continuation then
        b:sayNext(tr('%s has no PP left!','%s hat keine AP mehr!'):format(u.name));return
      end
      source={user=u,slot=inst,index=slotIndex(u,inst),id=inst.id}
    end
    dispatch[b]={user=u,move=move,source=source,callsMove=record and type(record.callsMove)=='function'}
    local out=pack(pcall(original,b,u,t,inst,called));dispatch[b]=prior
    if not out[1]then error(out[2],0)end;return unpack(out,2,out.n)
  end
  function M.capture(original,b,u,t,move,source,nativeContinuation,...)
    if not M.epoch(b)or not live(t)or not side(b,u)or not side(b,t)or u==t then return original(...)end
    local old=strikes[b];local frame={user=u,target=t,move=move,source=source,nativeContinuation=nativeContinuation};strikes[b]=frame
    local raw,apply=rawget(b,'applyDamage'),b.applyDamage
    b.applyDamage=function(self,w,amount)
      local survival=mod.exports.pokemonLethalHitSurvival67
      local attempt=survival and survival.incomingHit and survival.incomingHit(self,w)or amount
      local direct=w==t and w.mon.hp>0 and type(attempt)=='number'and attempt>0
      local sub=direct and w.substituteHP~=nil;local dealt=apply(self,w,amount)
      if w==t then frame.hit={damage=dealt,direct=direct,substitute=sub,lethal=direct and w.mon.hp<=0}end
      return dealt
    end
    local out=pack(pcall(original,...));b.applyDamage=raw;strikes[b]=old
    if not out[1]then error(out[2],0)end;return unpack(out,2,out.n)
  end
  function M.run(original,b,ctx,record)
    if not ctx or not ctx.move then return original(b,ctx,record)end
    local own=dispatch[b];local source=own and own.user==ctx.user and own.source
    return M.capture(original,b,ctx.user,ctx.target,ctx.move,source,false,b,ctx,record)
  end
  function M.continue(original,b,u,t,id,...)
    if not live(u)then return original(b,u,t,...)end
    -- Native trapping stores a canonical move ID, not an AP-slot pointer.
    local inst=id=='BIDE'and slotNamed(u,'BIDE')or type(u.trapMove)=='string'and slotNamed(u,u.trapMove)
      or type(u.trapMove)=='table'and u.trapMove
    local move=inst and b:moveDef(inst);local source=inst and slotIndex(u,inst)
      and{user=u,slot=inst,index=slotIndex(u,inst),id=inst.id}
    if not move or not source or id=='BIDE'and not u.bideTurns or id~='BIDE'and not u.trappingTurns then return original(b,u,t,...)end
    return M.capture(original,b,u,t,move,source,true,b,u,t,...)
  end
  function M.hit(ev)
    local f=ev and strikes[ev.battle];local h=f and f.hit
    if h and h.direct and not h.substitute and h.lethal and ev.user==f.user and ev.target==f.target
        and ev.move and ev.move.id==f.move.id and ev.move.effect==f.move.effect
        and ev.move.backendMoveOwner==f.move.backendMoveOwner
        and ev.move.backendMoveNumber==f.move.backendMoveNumber and ev.damage==h.damage then
      -- Owned immutable power/type projections may detach the move table
      -- inside FX. Identity remains canonical ID/effect/owner/number, and
      -- the actual scoped body damage must still match the native event.
      f.confirmed=true;f.landedMove=ev.move
    end
  end
  function M.faint(ev)
    local b,w=ev.battle,ev.battler;local row=M.row(b,w);if not row or w.mon.hp>0 then return end
    M.clear(b,w)
    local f=strikes[b];local h=f and f.hit;local source=f and f.source
    local landed=f and(f.landedMove or f.move);local flags=landed and landed.flags or{}
    -- An authentic current action started alive. Final Gambit may have
    -- zero HP here before its own actual faint notification; an already
    -- notified/fainted source is excluded by the primary source condition.
    if not h or not h.direct or h.substitute or not h.lethal or not(f.confirmed or f.nativeContinuation)
        or w~=f.target or f.user.fainted or f.user.faintQueued or not source or source.user~=f.user
        or not index(b,f.user)or source.slot~=f.user.curMoves[source.index]or source.slot.id~=source.id
        or source.id=='STRUGGLE'or flags.futuremove or landed.kascFutureStrike67
        or not integer(source.slot.pp,0,255)then return end
    source.slot.pp=0
    if row.profile==1 and f.user==b.enemy then
      -- Only a proven licensed early Grudge KO overrides Gen-I unlimited
      -- enemy selection for this particular real slot. Other zero-AP slots
      -- and all normal Gen-I PP behavior remain native and unchanged.
      local s=state(b,true);local key=side(b,f.user);local party=index(b,f.user)
      s.drained=s.drained or{};s.drained[key]=s.drained[key]or{};s.drained[key][party]=s.drained[key][party]or{}
      local drain={owner=M.OWNER,species=f.user.mon.species,party=party,slot=source.index,move=source.id,
        profile=1,epoch=3,applied=b.turnCount or 0,victimSpecies=row.species,victimParty=row.party}
      drain.proof=proof(drain);s.drained[key][party][source.index]=drain
    end
    b:sayNext(tr('%s lost all PP due to Grudge!','%s verliert durch Nachspiel alle AP!'):format(b.data.moves[source.id].name))
  end
  function M.validateCheckpoint(b)
    if dispatch[b]or strikes[b]then return false,'grudge_unsettled'end
    local s=state(b);if s==nil then return true end;if type(s)~='table'then return false,'invalid_grudge_container'end
    for key,row in pairs(s)do
      if key=='drained'then
        if M.epoch(b)~=1 or type(row)~='table'then return false,'invalid_grudge_drain_container'end
        for lane,parties in pairs(row)do
          if lane~='enemy'or type(parties)~='table'then return false,'invalid_grudge_drain_side'end
          local party=lane=='player'and b.game.save.party or b.kind=='wild'and{b.enemy.mon}or b.enemyParty
          local victimParty=lane=='enemy'and b.game.save.party or b.kind=='wild'and{b.enemy.mon}or b.enemyParty
          for at,slots in pairs(parties)do
            if not integer(at,1,6)or type(slots)~='table'or not party or not party[at]then return false,'invalid_grudge_drain_party'end
            for i,d in pairs(slots)do local mon=party[at]
              local moves=b[lane]and b[lane].mon==mon and b[lane].curMoves or mon.moves
              local slot=integer(i,1,4)and moves and moves[i]
              if type(d)~='table'or not slot or d.owner~=M.OWNER or d.profile~=1 or d.epoch~=3
                  or d.species~=mon.species or d.party~=at or d.slot~=i or d.move~=slot.id or not b.data.moves[d.move]
                  or not integer(d.applied,0,b.turnCount or 0)or not integer(d.victimParty,1,6)
                  or not victimParty or not victimParty[d.victimParty]or victimParty[d.victimParty].species~=d.victimSpecies
                  or type(d.proof)~='string'or d.proof~=proof(d)then return false,'invalid_grudge_drain_identity'end
              for k in pairs(d)do if k~='owner'and k~='profile'and k~='epoch'and k~='species'and k~='party'and k~='slot'
                  and k~='move'and k~='applied'and k~='victimSpecies'and k~='victimParty'and k~='proof'then return false,'unknown_grudge_drain_field'end end
            end
          end
        end
      else local w=(key=='player'or key=='enemy')and b[key]
        if not w or type(row)~='table'or not M.row(b,w)then return false,'invalid_grudge_identity'end
        for k in pairs(row)do if k~='species'and k~='party'and k~='profile'and k~='epoch'and k~='applied'then return false,'unknown_grudge_field'end end
      end
    end
    return true
  end
  function M.switched(ev)
    local b=ev.battle;M.clear(b,ev.battler)
    local s=state(b);local sides=s and s.drained
    for lane,parties in pairs(sides or{})do
      local party=lane=='player'and b.game.save.party or b.kind=='wild'and{b.enemy.mon}or b.enemyParty
      for at,slots in pairs(parties)do local mon=party and party[at]
        local moves=mon and(b[lane]and b[lane].mon==mon and b[lane].curMoves or mon.moves)
        for i,d in pairs(slots)do
          -- Transform/Mimic copied AP revert with their own native owner.
          -- Never turn a transformed slot receipt into original saved AP.
          if not moves or not moves[i]or moves[i].id~=d.move then slots[i]=nil end
        end
      end
    end
  end
  local fact=assert(opts.facts.move(M.ID,7));local old=assert(mod.content.moves:get(M.ID))
  assert(fact.number==288 and fact.generation==3 and fact.power==0 and fact.pp==5 and fact.type=='GHOST'
    and fact.category=='status'and fact.target==7 and fact.priority==0 and fact.accuracy==100,'Grudge source drift')
  assert(not old.backendMoveOwner and old.effect=='KA_GEN_MOVE_UNSUPPORTED_GRUDGE','foreign Grudge owner')
  mod.content.move_effects:register(effect,{kind='primary',run=M.cast,accuracyChecked=false,kascGrudge67=M.OWNER})
  mod.content.moves:patch(M.ID,{effect=effect,power=0,pp=5,type='GHOST',category='status',target=7,priority=0,accuracy=100,
    flags={bypasssub=1,metronome=1},kascBypassSub67=true,backendMoveOwner=M.OWNER,backendMoveNumber=288,
    originGeneration=3,backendLearnsetRevision=old.backendLearnsetRevision or 1})
  local animation={seq={},source=M.OWNER};for _,id in ipairs({'CONFUSE_RAY','BARRIER'})do
    for _,step in ipairs(assert(mod.content.battle_anims:get(id)).seq)do animation.seq[#animation.seq+1]=copy(step)end
  end;mod.content.battle_anims:patch(M.ID,animation)
  for i=#opts.moves.unsupportedStatus,1,-1 do if opts.moves.unsupportedStatus[i]==M.ID then table.remove(opts.moves.unsupportedStatus,i)end end
  function M.position(player,id)
    local anim=player.data and player.data.moveAnims and player.data.moveAnims[id];if id~=M.ID or not anim or anim.source~=M.OWNER then return end
    for _,step in ipairs(player.steps or{})do local sprites={};for i,s in ipairs(step.sprites or{})do local q=copy(s)
      if q.x>0 and q.x<168 and q.y>0 and q.y<160 and mod.exports.pokemonPartnerHits67.inHud(q)then q.x=0 end;sprites[i]=q
    end;step.sprites=sprites end
  end
  function M.install()
    B._kascGrudge67=M;FX._kascGrudge67=M;Status._kascGrudge67=M;Player._kascGrudge67=M
    if not B._kascGrudgeWrapped67 then
      local perform,bide,trap=B.performMove,B.continueBide,B.continueTrapping
      B.performMove=function(...)return B._kascGrudge67.perform(perform,...)end
      B.continueBide=function(b,u,t,...)return B._kascGrudge67.continue(bide,b,u,t,'BIDE',...)end
      B.continueTrapping=function(b,u,t,...)return B._kascGrudge67.continue(trap,b,u,t,'TRAP',...)end
      B._kascGrudgeWrapped67=true
    end
    if FX.runDamaging~=FX._kascGrudgeRun67 then local original=FX.runDamaging
      local wrapper=function(...)return FX._kascGrudge67.run(original,...)end;FX.runDamaging=wrapper;FX._kascGrudgeRun67=wrapper end
    if Status.beforeMove~=Status._kascGrudgeBefore67 then local original=Status.beforeMove
      local wrapper=function(...)return Status._kascGrudge67.before(original,...)end;Status.beforeMove=wrapper;Status._kascGrudgeBefore67=wrapper end
    if not Player._kascGrudgeWrapped67 then local original=Player.start
      Player.start=function(self,id,...)local out=pack(original(self,id,...));Player._kascGrudge67.position(self,id);return unpack(out,1,out.n)end
      Player._kascGrudgeWrapped67=true end
  end
  mod.events:on('battle.damage_dealt',M.hit,31002)
  mod.events:on('battle.fainted',M.faint,100001)
  mod.events:on('battle.battler_switched',M.switched,8000)
  mod.events:on('battle.ended',function(ev)M.clear(ev.battle)end,8000)
  M.install()
  if opts.supportLog and opts.supportLog.registerSegment then opts.supportLog.registerSegment({segmentId=M.CARD_ID,cardId=M.CARD_ID,
    schema='kasc.optional-feature-card/v1',version='1.0.0',owner=M.OWNER,active=true,
    dependencyStatus='native-attempt-lethal-body-source-and-own-slot',providerStatus='grudge-actual-KO-AP-zero',
    buildReceiptId='docs/GRUDGE_67.md',rollbackReceiptId='docs/GRUDGE_67.md'})end
  return M
end
