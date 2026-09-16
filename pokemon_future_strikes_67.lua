-- Slot-local delayed attacks. Application is ONE native action; impact is
-- ONE native FX strike, not a called move, another action, or a field HP delta.
return function(mod,opts)
  local B=require('src.battle.BattleState')
  local FX=require('src.battle.EffectRegistry')
  local A,W=assert(opts.abilities),assert(opts.weather)
  local M={CARD_ID='KASC-67-FUTURE-STRIKES',OWNER='kasc.future-strikes/v1'}
  local frames=setmetatable({},{__mode='k'})
  local aliases,defs={}, {FUTURE_SIGHT={number=248,generation=2},DOOM_DESIRE={number=353,generation=3}}
  local tr=opts.i18n.text
  local function copy(t)local out={};for k,v in pairs(t or{})do out[k]=v end;return out end
  local function pack(...)return{n=select('#',...),...}end
  local function integer(v,lo,hi)return type(v)=='number'and v%1==0 and v>=lo and v<=hi end
  local function living(w)
    local p=w and w.mon
    return p and type(p.hp)=='number'and p.hp>0 and not p.isEgg and not p.egg
      and not p.is_egg and not p.eggSpecies
  end
  local function lane(b,w)return w==b.player and'player'or w==b.enemy and'enemy'or nil end
  local function list(b,key)
    if key=='player'then return b:playerPartyView()end
    return b.kind=='wild'and {b.enemy.mon}or b.enemyParty
  end
  local function index(b,key,mon)
    for i,p in ipairs(list(b,key)or{})do if p==mon then return i end end
  end
  local function state(b,create)
    if create then b.field=b.field or{};b.field.tokens=b.field.tokens or{}
      b.field.tokens[M.OWNER]=b.field.tokens[M.OWNER]or{}end
    return b and b.field and b.field.tokens and b.field.tokens[M.OWNER]
  end
  function M.epoch(b)
    local h=b and b.data and b.data.move_effects and b.data.move_effects.HEAL_EFFECT
    local gen=h and h.kascFutureStrikes67==M.OWNER and opts.status.epoch(b)
    return getmetatable(b)==B and not b.demo and b.kind~='link'and not b.result
      and integer(gen,1,7)and gen or nil
  end
  function M.spec(id,gen)
    local d=defs[id];if not d or not integer(gen,1,7)then return end
    -- Explicit backwards-gift baseline: Seher uses II, Kismetwunsch III.
    -- Neither permission nor an active global era is unlocked by this fact.
    local era=math.max(gen,d.generation)
    local fact=assert(opts.facts.move(id,era))
    assert(fact.number==d.number and fact.category~='status'and fact.power>0)
    return {id=id,number=d.number,epoch=era,power=id=='FUTURE_SIGHT'and(era<=4 and 80 or era==5 and 100 or 120)
        or era<=4 and 120 or 140,
      accuracy=era<=4 and(id=='FUTURE_SIGHT'and 90 or 85)or 100,
      category=id=='DOOM_DESIRE'and era==3 and'physical'or'special',
      type=era<=4 and'???'or fact.type,pp=id=='FUTURE_SIGHT'and(era<=4 and 15 or 10)or 5}
  end
  function M.hitMove(b,row)
    local spec=assert(M.spec(row.move,row.epoch))
    local out=copy(assert(b.data.moves[row.native]))
    out.id=row.native;out.type=spec.type;out.category=spec.category
    out.power,out.accuracy=spec.power,spec.accuracy
    out.effect='NO_ADDITIONAL_EFFECT';out.multiHit=nil
    out.flags={futuremove=true};out.kascFutureStrike67=M.OWNER
    out.kascConverted67=M.OWNER;out.kascConversionPower67=nil;out.kascIonDeluge67=nil
    out.backendMoveOwner=M.OWNER;out.backendMoveNumber=spec.number
    return out
  end
  -- Narrow shared seams. Only a synchronously verified attack/snapshot can
  -- suppress conversion or the original reserve's abilities/held effects.
  function M.preservesType(b,w,move)
    local f=frames[b]
    return f and f.user and w and f.user.mon==w.mon and move
      and move.kascFutureStrike67==M.OWNER and move.id==f.move.id or false
  end
  function M.striking(b,u,t,move)
    local f=frames[b]
    return M.epoch(b)and f and f.phase=='impact'and f.user==u and f.target==t
      and move and move.id==f.move.id and move.kascFutureStrike67==M.OWNER or false
  end
  function M.sourceInactive(b,w)
    local f=frames[b]
    return f and f.phase=='impact'and f.epoch>=5 and f.inactive and w and w.mon==f.user.mon or false
  end
  -- A delayed strike skips ordinary onModifyMove. In particular, it
  -- does not acquire Mold Breaker/Scrappy/Stench or item-added flinch.
  -- The pinned slot condition explicitly applies ONLY VI+ Normalize
  -- (type, no type-changer power bonus) and VI+ Infiltrator at impact.
  function M.abilityScope(b,u,t,fn)
    local f=frames[b];assert(f and f.phase=='impact'and f.user==u and f.target==t)
    local id=A.activeAbility(b,u)
    local oldInvulnerable=t.invulnerable
    local noGuard=id=='NO_GUARD'or A.activeAbility(b,t)=='NO_GUARD'
    local protection={}
    if f.epoch>=6 and id=='INFILTRATOR'then
      for _,key in ipairs({'reflect','lightScreen','mist','safeguard','substituteHP'})do
        if t[key]~=nil then protection[key]=t[key];t[key]=nil end
      end
    end
    if noGuard then t.invulnerable=false end
    local out=pack(pcall(fn))
    if noGuard and t.invulnerable==false then t.invulnerable=oldInvulnerable end
    for key,value in pairs(protection)do if t[key]==nil then t[key]=value end end
    if not out[1]then error(out[2],0)end
    return unpack(out,2,out.n)
  end
  function M.pending(b,w)
    local rows=state(b);local key=w and lane(b,w)
    return M.epoch(b)and rows and key and rows[key]or nil
  end
  function M.noUseful(b,u,t,move)
    return move and defs[aliases[move.id]or move.id]and move.backendMoveOwner==M.OWNER
      and M.pending(b,t)~=nil or false
  end
  local function failed(b)
    b:cancelMoveAnim();b:sayNext(tr('But, it failed!','Doch es schlug fehl!'))
  end
  function M.canCast(ctx)
    local b,u,t,move=ctx.battle,ctx.user,ctx.target,ctx.move
    local gen=M.epoch(b);local id=move and(aliases[move.id]or move.id)
    local d=defs[id];local side=gen and lane(b,u);local target=gen and lane(b,t)
    if not d or not side or not target or side==target or not living(u)or not living(t)
        or move.backendMoveOwner~=M.OWNER or not index(b,side,u.mon)or M.pending(b,t)then return false end
    if gen<d.generation and not(opts.rules.ownedGiftBattleCompatible
        and opts.rules.ownedGiftBattleCompatible(b.game,u.mon,b.data.pokemon[u.mon.species]))then return false end
    return true,id,gen,side,target
  end
  function M.cast(ctx)
    local b=ctx.battle;local ok,id,gen,source,target=M.canCast(ctx)
    if not ok then failed(b);return false end
    local row={move=id,native=ctx.move.id,source=source,sourceIndex=index(b,source,ctx.user.mon),
      sourceSpecies=ctx.user.mon.species,epoch=math.max(gen,defs[id].generation),appliedTurn=b.turnCount or 0}
    local move=M.hitMove(b,row)
    if row.epoch<=4 then
      -- Old games freeze the actual offensive AND defensive calculation at
      -- application, including variance/screens. No type, STAB or critical.
      -- Literal ??? is a neutral native TypeChart lookup, NOT opts.typeless
      -- (which is specifically confusion and skips the random factor).
      local f={phase='snapshot',user=ctx.user,target=ctx.target,move=move,epoch=row.epoch}
      frames[b]=f
      local out=pack(pcall(b.computeDamage,b,ctx.user,ctx.target,move,{rng=b.rng,forceCrit=false}))
      frames[b]=nil;if not out[1]then error(out[2],0)end
      assert(integer(out[2],1,65535)and out[3]and not out[3].crit and out[3].typeMult==10,
        'future snapshot must preserve neutral native damage')
      row.damage=out[2]
    end
    state(b,true)[target]=row
    b:sayNext(tr(id=='FUTURE_SIGHT'and'%s foresaw an attack!'or'%s chose Doom Desire as its destiny!',
      id=='FUTURE_SIGHT'and'%s sieht einen Angriff voraus!'or'%s wünscht einen verhängnisvollen Angriff!'):format(ctx.user.name))
    return true
  end
  local function sourceView(b,row)
    local mon=(list(b,row.source)or{})[row.sourceIndex]
    if not mon or mon.species~=row.sourceSpecies then return end
    local active=b[row.source]
    if active and active.mon==mon then return active,not living(active)end
    -- No switch/entry event, no stat migration, no new Pokemon. The exact
    -- checkpointed original party object supplies current unboosted stats.
    local view=B.makeBattler(b.data,mon,row.source=='player',row.source=='player'and b.game.save or nil)
    view.curStats=copy(mon.stats);view.stages={};view.faintQueued=true
    if opts.split then opts.split.prepare(b,view)end
    return view,true
  end
  function M.impact(b,key,row)
    if not M.epoch(b)or frames[b]then return false end
    local target=b[key];local user,inactive=sourceView(b,row)
    if not user or not living(target)or target.mon==user.mon then return false end
    local move=M.hitMove(b,row)
    local f={phase='impact',epoch=row.epoch,user=user,target=target,move=move,inactive=inactive}
    frames[b]=f
    if row.epoch>=6 and A.activeAbility(b,user)=='NORMALIZE'then move.type='NORMAL'end
    -- Future attacks do not carry the protect flag, and remove Endure
    -- before damage in the pinned slot condition. Other shields/history
    -- are not indiscriminately deleted or reset.
    local protection=mod.exports.pokemonProtection67
    if protection then local guard=protection.active(b,target)
      if guard=='PROTECT'or guard=='ENDURE'then
        local tokens=b.field.tokens[protection.OWNER];local guardRow=tokens and tokens[key]
        if guardRow then guardRow.guardTurn=nil end
      end
    end
    local rawFaint,oldFaint=rawget(b,'onFaint'),b.onFaint
    local priorAnim=b.moveAnimRow
    b.onFaint=function(self,w,...)
      if w==user and inactive then return end -- its real faint was already handled
      return oldFaint(self,w,...)
    end
    local ctx
    local function hit()
      b:sayNext(tr(row.move=='FUTURE_SIGHT'and'%s took the Future Sight attack!'or'%s took the Doom Desire attack!',
        row.move=='FUTURE_SIGHT'and'%s wird von Seher getroffen!'or'%s wird von Kismetwunsch getroffen!'):format(target.name))
      b.moveAnimRow=b:animNext(row.native,user.isPlayer)
      ctx=FX.makeCtx(b,user,target,move,{id=row.native,pp=0},false)
      local record={kind='full',hitCount=function()return 1 end}
      if row.damage then record.chooseDamage=function()return row.damage,{crit=false,typeMult=10}end end
      -- Normal accuracy/semi-invulnerability at IMPACT, not application.
      FX.runDamaging(b,ctx,record)
      -- No performMove is run here, so action-end costs/berries must enter
      -- their existing owners explicitly, after the actual direct strike.
      if ctx.totalDealt~=nil then
        local contact=mod.exports.pokemonContactAbilities67
        if contact and target.mon.hp>0 and not ctx.brokeSub and target.substituteHP==nil then
          if A.activeAbility(b,target)=='COLOR_CHANGE'then contact.colorChange(b,target,ctx.move)end
          contact.berserk(b,{user=user,target=target,move=ctx.move,realDamage=ctx.totalDealt})
        end
        local berries=mod.exports.pokemonModernBerries67
        if berries then berries.apply(b,true,target);if not inactive then berries.apply(b,true,user)end end
        local forms=mod.exports.pokemonHPForms67;if forms then forms.watch(b)end
      end
      -- The source's item event is explicit and outside trySpreadMoveHit
      -- in the canonical slot condition, even for a failed/immune strike.
      if row.epoch>=5 and not inactive and user.mon.hp>0 then
        local orb=mod.exports.pokemonLifeOrb67
        if orb and orb.item(b,user)and not A.blocksIndirect(b,user,'life_orb')then
          b:sayNext(tr('Life Orb!\nLost HP.','Leben-Orb!\nKP verloren.'))
          assert(opts.contact).indirectDamage(b,user,math.max(1,math.floor(user.mon.stats.hp/10)))
          if user.mon.hp<=0 then b:onFaint(user)end
        end
      end
    end
    local out=pack(pcall(function()return M.abilityScope(b,user,target,hit)end))
    b.onFaint=rawFaint;b.moveAnimRow=priorAnim;frames[b]=nil
    if not out[1]then error(out[2],0)end
    return ctx and ctx.totalDealt~=nil or false
  end
  function M.resolve(b,phase)
    local gen=M.epoch(b);local rows=state(b)
    if not gen or not rows then return 0 end
    if phase~=(gen<=2 and'beforeWeather'or gen<=4 and'afterStatus'or'beforeStatus')then return 0 end
    assert(M.validateCheckpoint(b),'invalid future strike checkpoint')
    local hits=0
    for _,key in ipairs({'player','enemy'})do
      local row=rows[key]
      if row and (b.turnCount or 0)>=row.appliedTurn+2 then
        rows[key]=nil -- consume BEFORE any callback/faint; never replay
        if M.impact(b,key,row)then hits=hits+1 end
      end
    end
    if not next(rows)then b.field.tokens[M.OWNER]=nil end
    return hits
  end
  function M.beforeWeather(b)return M.resolve(b,'beforeWeather')end
  function M.beforeStatus(b)return M.resolve(b,'beforeStatus')end
  function M.afterStatus(b)return M.resolve(b,'afterStatus')end
  function M.afterField(b)
    -- Resolve against the current factory's weather owner on hot reload,
    -- not a first-loaded weak-frame table captured by the native wrapper.
    assert(type(W.inResidualPass)=='function','Future Strikes requires weather residual-pass seam')
    if not W.inResidualPass(b)then return M.afterStatus(b)end
    return 0
  end
  function M.validateCheckpoint(b)
    if frames[b]then return false,'unsettled_future_strike'end
    local rows=state(b);if rows==nil then return true end
    if type(rows)~='table'then return false,'invalid_future_strike_container'end
    for key,r in pairs(rows)do
      if (key~='player'and key~='enemy')or type(r)~='table'or not defs[r.move]
          or aliases[r.native]~=r.move or (r.source~='player'and r.source~='enemy')or r.source==key
          or not integer(r.sourceIndex,1,6)or not integer(r.epoch,defs[r.move].generation,7)
          or not integer(r.appliedTurn,0,b.turnCount or 0)or(b.turnCount or 0)>r.appliedTurn+2
          or r.epoch<=4 and not integer(r.damage,1,65535)or r.epoch>=5 and r.damage~=nil then
        return false,'invalid_future_strike_timeline'
      end
      local gen=M.epoch(b)
      if gen and r.epoch~=math.max(gen,defs[r.move].generation)then return false,'future_strike_era_mismatch'end
      local p=(list(b,r.source)or{})[r.sourceIndex]
      if not p or p.species~=r.sourceSpecies or not b.data.moves[r.native]
          or b.data.moves[r.native].backendMoveOwner~=M.OWNER then return false,'invalid_future_strike_source'end
      for field in pairs(r)do
        if field~='move'and field~='native'and field~='source'and field~='sourceIndex'
            and field~='sourceSpecies'and field~='epoch'and field~='appliedTurn'and field~='damage'then
          return false,'unknown_future_strike_field'
        end
      end
    end
    return true
  end
  for id,d in pairs(defs)do
    for _,native in ipairs(opts.species.moveIds(id))do
      local old=assert(mod.content.moves:get(native),'missing future move '..native)
      assert(not old.backendMoveOwner,'foreign future move '..native)
      aliases[native]=id
      local effect='KA_FUTURE_STRIKE_67_'..native
      mod.content.move_effects:register(effect,{kind='primary',accuracyChecked=false,
        kascFutureStrikes67=M.OWNER,perform=function(ctx)M.cast(ctx)end})
      mod.content.moves:patch(native,{effect=effect,backendMoveOwner=M.OWNER,
        backendMoveNumber=d.number,backendLearnsetRevision=old.backendLearnsetRevision or 1})
      -- Keep the existing animation and every Pokemon sprite unchanged.
      assert(mod.content.battle_anims:get(native),'missing existing future animation '..native)
    end
  end
  mod.content.move_effects:patch('HEAL_EFFECT',{kascFutureStrikes67=M.OWNER})
  function M.install()
    B._kascFutureStrikes67=M
    if B._kascFutureStrikesWrapped67 then return end
    local ending,field=B.endOfTurn,B.applyFieldResiduals
    B.endOfTurn=function(b,...)
      B._kascFutureStrikes67.beforeWeather(b);return ending(b,...)
    end
    B.applyFieldResiduals=function(b,...)
      B._kascFutureStrikes67.afterField(b)
      return field(b,...)
    end
    B._kascFutureStrikesWrapped67=true
  end
  mod.events:on('battle.ended',function(ev)
    local b=ev and ev.battle;if b and b.field and b.field.tokens then b.field.tokens[M.OWNER]=nil end
  end,9000)
  M.install()
  if opts.supportLog and opts.supportLog.registerSegment then
    opts.supportLog.registerSegment({segmentId=M.CARD_ID,cardId=M.CARD_ID,
      schema='kasc.optional-feature-card/v1',version='1.0.0',owner=M.OWNER,active=true,
      dependencyStatus='native-typed-FX-and-residual-timeline-seams',
      providerStatus='gen2-7-deferred-slot-attacks-explicit-backwards-gifts',
      buildReceiptId='docs/FUTURE_STRIKES_67.md',rollbackReceiptId='docs/FUTURE_STRIKES_67.md'})
  end
  return M
end
