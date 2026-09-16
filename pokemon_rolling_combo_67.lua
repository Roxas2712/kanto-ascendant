-- Stateful strength belongs to a real move use, not a damage forecast or
-- each Familienbande strike. Tokens contain data only; no saved mon changes.
return function(mod,opts)
  local B=require('src.battle.BattleState');local FX=require('src.battle.EffectRegistry')
  local Runtime=require('src.mods.Runtime')
  local M={CARD_ID='KASC-67-ROLLING-COMBO',OWNER='kasc.rolling-combo/v1'}
  local defs={ROLLOUT={number=205,gen=2,power=30,pp=20,accuracy=90,animation='ROCK_THROW'},
    ICE_BALL={number=301,gen=3,power=30,pp=20,accuracy=90,animation='ICE_BEAM'},
    FURY_CUTTER={number=210,gen=2,power=40,pp=20,accuracy=95,animation='SLASH'},
    ECHOED_VOICE={number=497,gen=5,power=40,pp=15,accuracy=100,animation='GROWL'},
    ROUND={number=496,gen=5,power=60,pp=15,accuracy=100,animation='GROWL'}}
  local aliases,uses,actions,planned={},setmetatable({},{__mode='k'}),
    setmetatable({},{__mode='k'}),setmetatable({},{__mode='k'})
  local tr=opts.i18n.text
  local function copy(v)local r={};for k,x in pairs(v or{})do r[k]=x end;return r end
  local function clone(v)if type(v)~='table'then return v end;local out={};for k,x in pairs(v)do out[k]=clone(x)end;return out end
  local function pack(...)return{n=select('#',...),...}end
  local function integer(v,lo,hi)return type(v)=='number'and v%1==0 and v>=lo and v<=hi end
  local function id(m)return m and(aliases[m.id]or m.id)end
  local function side(b,w)return w==b.player and'player'or w==b.enemy and'enemy'or nil end
  local function live(w)
    local p=w and w.mon
    return p and p.hp>0 and not w.fainted and not(p.egg or p.isEgg or p.is_egg or p.eggSpecies)
  end
  local function state(b,create)
    if create then b.field=b.field or{};b.field.tokens=b.field.tokens or{}
      b.field.tokens[M.OWNER]=b.field.tokens[M.OWNER]or{lanes={}}end
    return b and b.field and b.field.tokens and b.field.tokens[M.OWNER]
  end
  function M.epoch(b,w,m)
    local r=b and b.kascGenerationRulesReceipt
    local marker=b and b.data and b.data.move_effects and b.data.move_effects.HEAL_EFFECT
    if getmetatable(b)~=B or b.demo or b.kind=='link'or b.result or not r or r.mode=='off'
        or not integer(r.activeEpoch,1,7)or not marker or marker.kascRollingCombo67~=M.OWNER then return end
    if not m then return r.activeEpoch end
    local d=defs[id(m)];local effect=b.data.move_effects[m.effect]
    if not d or m.backendMoveOwner~=M.OWNER or not effect or effect.kascRollingCombo67~=M.OWNER then return end
    if r.activeEpoch<d.gen and not(live(w)and opts.rules.ownedGiftBattleCompatible
        and opts.rules.ownedGiftBattleCompatible(b.game,w.mon,b.data.pokemon[w.mon.species]))then return end
    return math.max(d.gen,r.activeEpoch),id(m)
  end
  local function lane(b,w,create)
    local s=state(b,create);local key=side(b,w)
    if s and key then
      local row=s.lanes[key]
      if row and row.species~=w.mon.species then row=nil end
      if create and not row then row={species=w.mon.species};s.lanes[key]=row end
      return row
    end
  end
  local function slotIndex(w,inst)
    for i,slot in ipairs(w.curMoves or{})do if i<=4 and slot==inst then return i end end
    return 0
  end
  local function furyBase(gen)return gen<=4 and 10 or gen==5 and 20 or 40 end
  function M.profile(b,u,t,m)
    local gen,source=M.epoch(b,u,m)
    if gen and live(u)and live(t)and u~=t and side(b,u)and side(b,t)then return gen,source end
  end
  function M.nextPower(b,u,m)
    local gen,source=M.epoch(b,u,m);if not gen then return end
    local f=uses[b];if f and f.user.mon==u.mon and f.id==source and f.power then return f.power end
    local row=lane(b,u);local turn=b.turnCount or 0
    if source=='ROLLOUT'or source=='ICE_BALL'then
      local roll=row and row.roll
      local count=roll and roll.id==source and roll.turn>=turn-1 and roll.contacts or 0
      return 30*2^count*(row and row.curl and 2 or 1)
    elseif source=='FURY_CUTTER'then
      local fury=row and row.fury
      return math.min(160,furyBase(gen)*(fury and fury.turn>=turn-1 and fury.multiplier*2 or 1))
    elseif source=='ECHOED_VOICE'then
      local echo=state(b)and state(b).echo
      local mult=echo and(echo.turn==turn and echo.multiplier or echo.turn==turn-1
        and math.min(5,echo.multiplier+1))or 1
      return 40*mult
    elseif source=='ROUND'then
      local a=actions[b];local row=a and a.user==u and a.scheduled
      return row and row.pulled and 120 or 60
    end
  end
  function M.project(b,u,m)
    if m and m.kascRollingStorage67==M.OWNER then return m end
    local power=M.nextPower(b,u,m);if not power then return m end
    local gen,source=M.epoch(b,u,m)
    -- A native child strike or damage forecast may visit the projection
    -- several times. Reuse the already-correct per-use view, so an outer
    -- authentic strike owner retains its move identity. Recompute after a
    -- real streak/epoch change; never freeze a forecast's earlier power.
    if m.kascRollingProjection67==M.OWNER and m.kascRollingProjectionEpoch67==gen
        and m.power==power then return m end
    local out=copy(m);out.power=power;out.kascRollingProjection67=M.OWNER
    out.kascRollingProjectionEpoch67=gen
    if source=='ROUND'or source=='ECHOED_VOICE'then
      out.kascBypassSub67=gen>=6 or nil;out.flags=copy(m.flags)
      if gen<=5 then out.flags.bypasssub=nil end
    end
    return out
  end
  function M.damage(nextDamage,ctx)
    if not ctx or ctx.opts and ctx.opts.typeless then return nextDamage(ctx)end
    local b=ctx.battle;local u=ctx.user
    if b and u then
      if b.player and u.mon==b.player.mon then u=b.player
      elseif b.enemy and u.mon==b.enemy.mon then u=b.enemy end
    end
    if M.epoch(b)==7 and live(u)and side(b,u)and ctx.move and ctx.move.category~='status'
        and not ctx.move.kascRollingStorage67 then
      local row=lane(b,u);local stored=row and row.storage
      if stored then
        local adjusted=copy(ctx);adjusted.move=copy(ctx.move)
        local rawMove=b.data.moves[ctx.move.id]
        adjusted.move.power=math.max(1,rawMove and rawMove.power or ctx.move.power)*2^stored.contacts*(row.curl and 2 or 1)
        adjusted.move.kascRollingStorage67=M.OWNER;return nextDamage(adjusted)
      end
    end
    local gen=M.profile(b,u,ctx.target,ctx.move)
    -- Defensive views can be detached as well; only actual native mon
    -- identity, never a look-alike cloned mon, establishes this projection.
    if not gen and b and ctx.target then
      local t=b.player and ctx.target.mon==b.player.mon and b.player
        or b.enemy and ctx.target.mon==b.enemy.mon and b.enemy
      gen=M.profile(b,u,t,ctx.move)
    end
    if not gen then return nextDamage(ctx)end
    local adjusted=copy(ctx);adjusted.move=M.project(b,u,ctx.move)
    return nextDamage(adjusted)
  end
  function M.try(b,f)
    if f.tried then return end;f.tried=true
    f.power=M.nextPower(b,f.user,f.move)
    local turn=b.turnCount or 0
    if f.id=='ECHOED_VOICE'then state(b,true).echo={turn=turn,multiplier=f.power/40}
    elseif f.id=='ROUND'then
      local s=state(b);local schedule=s and s.round
      -- Singles has one remaining native turn action. Pull only a real
      -- queued Round; called/repeated attacks do not acquire its bonus.
      if schedule and schedule.turn==turn then
        for key,row in pairs(schedule.queued)do
          if key~=side(b,f.user)and row.status=='pending'and row.id=='ROUND'then row.pulled=true;break end
        end
      end
    end
  end
  function M.commit(b,f)
    if not f.tried then return end
    local row=lane(b,f.user,true);if not row then return end
    local turn=b.turnCount or 0
    if f.id=='FURY_CUTTER'then
      row.fury=f.landed and{turn=turn,multiplier=f.power/furyBase(f.gen)}or nil
    elseif f.id=='ROLLOUT'or f.id=='ICE_BALL'then
      local previous=row.roll;local hitCount=previous and previous.id==f.id and previous.turn>=turn-1 and previous.hits or 0
      local contacts=previous and previous.id==f.id and previous.turn>=turn-1 and previous.contacts or 0
      if not f.landed or f.user.mon.status=='SLP'then row.roll=nil;return end
      hitCount=hitCount+1;contacts=contacts+(f.disguise and f.gen==7 and 0 or 1)
      if hitCount>=5 then
        row.roll=nil
        -- VII's documented Disguise storage glitch has an actual one-use
        -- base-power receipt, not an invented permanent stat change.
        if f.gen==7 and contacts<5 then row.storage={turn=turn,contacts=contacts}end
      else row.roll={id=f.id,native=f.move.id,slot=slotIndex(f.user,f.inst),turn=turn,
        hits=hitCount,contacts=contacts}end
    end
  end
  function M.run(original,b,ctx,record)
    local gen,source=M.profile(b,ctx.user,ctx.target,ctx.move)
    if not gen then return original(b,ctx,record)end
    local f=uses[b];local own=not(f and f.user==ctx.user and f.id==source)
    local prior=f
    if own then f={user=ctx.user,target=ctx.target,move=ctx.move,inst=ctx.moveInst,id=source,gen=gen};uses[b]=f end
    M.try(b,f)
    local move=M.project(b,ctx.user,ctx.move)
    local adjusted=FX.makeCtx(b,ctx.user,ctx.target,move,ctx.moveInst,ctx.isCalled)
    -- Sound bypasses an actual Substitute only from VI onward. Flags in
    -- a modern catalog are not permission to retroactively grant it in V.
    local sub=(source=='ROUND'or source=='ECHOED_VOICE')and gen>=6 and ctx.target.substituteHP
    if sub then ctx.target.substituteHP=nil end
    local disguise=mod.exports and mod.exports.pokemonDisguise67
    local wasReady=disguise and disguise.ready(b,ctx.target)
    local out=pack(pcall(original,b,adjusted,record))
    if sub and ctx.target.mon.hp>0 then ctx.target.substituteHP=sub end
    if not out[1]then if own then uses[b]=prior end;error(out[2],0)end
    if adjusted.totalDealt~=nil then
      f.landed=true
      if wasReady and disguise.busted(b,ctx.target)and adjusted.totalDealt==0 then f.disguise=true end
    end
    for _,key in ipairs({'hits','totalDealt','rawDamage','brokeSub','hitSfx'})do ctx[key]=adjusted[key]end
    if own then M.commit(b,f);uses[b]=prior end
    return unpack(out,2,out.n)
  end
  function M.storageRun(original,b,ctx,record)
    if M.epoch(b)~=7 or not ctx or not live(ctx.user)or not live(ctx.target)
        or not side(b,ctx.user)or ctx.user==ctx.target or not ctx.move
        or ctx.move.category=='status'then return original(b,ctx,record)end
    local row=lane(b,ctx.user);local stored=row and row.storage
    if not stored then return original(b,ctx,record)end
    local raw,damage=rawget(b,'computeDamage'),b.computeDamage
    -- Source VII's storage is consumed by the next real base-power
    -- evaluation, including a DIFFERENT move; accuracy/Protect and fixed
    -- damage bypass it. A pure AI preview never enters this native scope.
    b.computeDamage=function(self,u,t,m,o)
      if u==ctx.user and t==ctx.target and m and m.id==ctx.move.id and not(o and o.typeless)
          and row.storage==stored and not m.kascRollingStorage67 then
        local projected=copy(m)
        local rawMove=self.data.moves[m.id]
        projected.power=math.max(1,rawMove and rawMove.power or m.power)*2^stored.contacts*(row.curl and 2 or 1)
        projected.kascRollingStorage67=M.OWNER;row.storage=nil
        return damage(self,u,t,projected,o)
      end
      return damage(self,u,t,m,o)
    end
    local out=pack(pcall(original,b,ctx,record));b.computeDamage=raw
    if not out[1]then error(out[2],0)end;return unpack(out,2,out.n)
  end
  function M.used(ev)
    local b,u,m=ev and ev.battle,ev and ev.user,ev and ev.move
    if not M.epoch(b)or not u or not m then return end
    local row=lane(b,u);if not row then return end
    local record=b:effectRecord(m.effect)
    if record and record.callsMove then return end
    if id(m)~='FURY_CUTTER'then row.fury=nil end
    if id(m)~='ROLLOUT'and id(m)~='ICE_BALL'then row.roll=nil end
  end
  function M.isContinuation(b,w,inst,isCalled)
    if isCalled or not live(w)or not inst or not M.epoch(b,w,b:moveDef(inst))then return false end
    local row=lane(b,w);local roll=row and row.roll;local turn=b.turnCount or 0
    if not roll or roll.native~=inst.id or roll.turn<turn-1 or roll.hits>=5 then return false end
    if roll.slot>0 then return w.curMoves and w.curMoves[roll.slot]==inst end
    return inst.kascRollingContinuation67==M.OWNER and inst.pp==0
  end
  function M.lock(b,w)
    if not M.epoch(b)or not live(w)then return end
    local row=lane(b,w);local r=row and row.roll
    if not r or r.turn<(b.turnCount or 0)-1 then return end
    local inst=r.slot>0 and w.curMoves and w.curMoves[r.slot]
      or{id=r.native,pp=0,kascRollingContinuation67=M.OWNER}
    if M.isContinuation(b,w,inst,false)then return inst end
  end
  function M.continueNative(b,u,t,inst)
    local move=b:moveDef(inst);local record=move and b:effectRecord(move.effect)
    assert(M.isContinuation(b,u,inst,false)and record and record.kind=='full'
      and not record.perform and not record.callsMove and not record.charge,'invalid native rolling continuation')
    b.moveAnimRow=nil
    b:sayNextAuto(b:romText('_ItemUseText001','%s\nused %s!',FX.displayName(u),move.name))
    b.nextInsert=(b.nextInsert or 0)+1
    b.moveAnimRow={anim=move.id,attackerIsPlayer=u.isPlayer}
    table.insert(b.queue,b.nextInsert,b.moveAnimRow)
    Runtime.emit('battle.move_used',{battle=b,user=u,target=t,move=move,isCalled=false})
    u.lastMove=move.id
    FX.runDamaging(b,FX.makeCtx(b,u,t,move,inst,false),record)
  end
  function M.continueOwned(b,u,t,inst)
    -- The native status/action gauntlet has already run. The pure-damage
    -- continuation is specific to these two owned moves, with no PP write,
    -- caller flag, recharge/charge branch or second executeAction.
    local ex=mod.exports or{}
    local core=function(bb,ww,tt,ii)return M.continueNative(bb,ww,tt,ii)end
    for _,name in ipairs({'pokemonLifeOrb67','pokemonGems67','pokemonContactAbilities67',
        'pokemonChoiceItems67','pokemonMoveRestrictions67','pokemonMoveLock67','pokemonStanceChange67'})do
      local owner=ex[name]
      if owner and owner.perform then local nextFn=core
        core=function(...)return owner.perform(nextFn,...)end
      end
    end
    local function act()
      local grounding=ex.pokemonGrounding67
      if grounding then return grounding.scope(b,u,t,b:moveDef(inst),function()return core(b,u,t,inst,false)end)end
      return core(b,u,t,inst,false)
    end
    local function bypass()
      local ability=opts.abilities or ex.pokemonAbilityEffects67
      if ability then return ability.moveScope(b,u,t,false,act,b:moveDef(inst))end
      return act()
    end
    local forms=ex.pokemonHPForms67;if forms then forms.watch(b)end
    local emergency=ex.pokemonEmergencyExit67
    local out=pack(pcall(function()
      if emergency then return emergency.scope(b,'move',u,b:moveDef(inst),bypass)end
      return bypass()
    end))
    if forms then forms.watch(b)end
    if not out[1]then error(out[2],0)end;return unpack(out,2,out.n)
  end
  function M.perform(original,b,u,t,inst,called)
    local move=inst and b:moveDef(inst);local gen,source=M.profile(b,u,t,move)
    if not gen then return original(b,u,t,inst,called)end
    local prior=uses[b];local f={user=u,target=t,move=move,inst=inst,id=source,gen=gen};uses[b]=f
    local continuation=M.isContinuation(b,u,inst,called)
    local out=pack(pcall(function()
      if continuation then return M.continueOwned(b,u,t,inst)end
      return original(b,u,t,inst,called)
    end))
    if out[1]then M.commit(b,f)end;uses[b]=prior
    if not out[1]then error(out[2],0)end
    return unpack(out,2,out.n)
  end
  function M.begin(ev)
    local b=ev and ev.battle;if not M.epoch(b)then return end
    local s=state(b,true);s.round={turn=b.turnCount or 0,queued={}}
    for _,key in ipairs({'player','enemy'})do
      local w,a=b[key],ev[key..'Action'];local m=a and not a.special and b:moveDef(a)
      if m and id(m)=='ROUND'and M.epoch(b,w,m)and not(m.isZ or m.isMax)then
        local index=slotIndex(w,a)
        if index>0 then s.round.queued[key]={id='ROUND',native=a.id,slot=index,
          species=w.mon.species,status='pending'}end
      end
    end
  end
  function M.action(original,b,u,t,a)
    if not M.epoch(b)then return original(b,u,t,a)end
    local lock=M.lock(b,u);if lock and not(a and a.special=='recharge')then a=lock end
    local prior=actions[b];local row
    local schedule=state(b)and state(b).round
    if planned[b]and schedule and schedule.turn==(b.turnCount or 0)then
      row=schedule.queued[side(b,u)]
      if not(row and row.status=='pending'and row.species==u.mon.species
          and u.curMoves[row.slot]==a and row.native==a.id)then row=nil end
      if row then row.status='running'end
    end
    actions[b]={user=u,scheduled=row}
    local forced=b.enemyActionForced
    if lock and u==b.enemy then b.enemyActionForced=true end
    local before=lane(b,u);local previousRoll=before and before.roll;local previousFury=before and before.fury
    local out=pack(pcall(original,b,u,t,a));actions[b]=prior
    if lock and u==b.enemy then b.enemyActionForced=forced end
    if row then row.status='done'end
    -- A status-interrupted action never enters FX and cannot keep the chain.
    local after=lane(b,u)
    if after and after.roll==previousRoll and previousRoll and previousRoll.turn<(b.turnCount or 0)then after.roll=nil end
    if after and after.fury==previousFury and previousFury and previousFury.turn<(b.turnCount or 0)then after.fury=nil end
    if not out[1]then error(out[2],0)end;return unpack(out,2,out.n)
  end
  function M.resolve(original,b,...)
    if not M.epoch(b)then return original(b,...)end
    local raw,act=rawget(b,'act'),b.act
    b.act=function(self,fn)
      return act(self,function()
        local prior=planned[self];planned[self]=true
        local out=pack(pcall(fn));planned[self]=prior
        if not out[1]then error(out[2],0)end;return unpack(out,2,out.n)
      end)
    end
    local out=pack(pcall(original,b,...));b.act=raw
    if not out[1]then error(out[2],0)end;return unpack(out,2,out.n)
  end
  function M.clear(b,w,partial)
    local s=state(b);if not s then return end
    if not w then b.field.tokens[M.OWNER]=nil;return end
    local key=side(b,w)
    if key then
      if partial then local row=s.lanes[key];if row then row.roll=nil;row.fury=nil end
      else s.lanes[key]=nil;if s.round then s.round.queued[key]=nil end end
    end
  end
  function M.endTurn(ev)
    local b=ev and ev.battle;local s=state(b);if not s then return end
    local turn=b.turnCount or 0
    if s.echo and s.echo.turn<turn then s.echo=nil end
    s.round=nil
    for key,row in pairs(s.lanes)do
      if not live(b[key])or row.species~=b[key].mon.species then s.lanes[key]=nil
      else
        if row.roll and row.roll.turn<turn then row.roll=nil end
        if row.fury and row.fury.turn<turn then row.fury=nil end
        if row.storage and row.storage.turn<turn then row.storage=nil end
      end
    end
  end
  function M.validateCheckpoint(b)
    if uses[b]or actions[b]or planned[b]then return false,'rolling_combo_unsettled'end
    local s=state(b);if not s then return true end
    if type(s)~='table'or type(s.lanes)~='table'then return false,'invalid_rolling_container'end
    for k in pairs(s)do if k~='lanes'and k~='echo'and k~='round'then return false,'unknown_rolling_container_field'end end
    local turn=b.turnCount or 0
    if s.echo and(type(s.echo)~='table'or not integer(s.echo.turn,turn-1,turn)
        or not integer(s.echo.multiplier,1,5))then return false,'invalid_echoed_voice'end
    if s.echo then for k in pairs(s.echo)do if k~='turn'and k~='multiplier'then return false,'unknown_echoed_voice_field'end end end
    if s.round then return false,'round_actions_pending'end
    for key,row in pairs(s.lanes)do
      local w=(key=='player'or key=='enemy')and b[key]
      if not w or type(row)~='table'or row.species~=w.mon.species then return false,'invalid_rolling_actor'end
      for k in pairs(row)do if k~='species'and k~='curl'and k~='roll'and k~='fury'and k~='storage'then return false,'unknown_rolling_actor_field'end end
      if row.curl~=nil and row.curl~=true then return false,'invalid_defense_curl'end
      local r=row.roll
      if r and(type(r)~='table'or(r.id~='ROLLOUT'and r.id~='ICE_BALL')or not integer(r.slot,0,4)
          or not integer(r.turn,turn-1,turn)or not integer(r.hits,1,4)or not integer(r.contacts,0,r.hits)
          or M.epoch(b)~=7 and r.contacts~=r.hits
          or not b.data.moves[r.native]or id(b.data.moves[r.native])~=r.id
          or r.slot>0 and(not w.curMoves[r.slot]or w.curMoves[r.slot].id~=r.native))then return false,'invalid_rolling_lock'end
      if r then for k in pairs(r)do if k~='id'and k~='native'and k~='slot'and k~='turn'and k~='hits'and k~='contacts'then return false,'unknown_rolling_lock_field'end end end
      local f=row.fury
      if f and(type(f)~='table'or not integer(f.turn,turn-1,turn)
          or(f.multiplier~=1 and f.multiplier~=2 and f.multiplier~=4 and f.multiplier~=8 and f.multiplier~=16)
          or f.multiplier>160/furyBase(M.epoch(b)or 7))then return false,'invalid_fury_cutter'end
      if f then for k in pairs(f)do if k~='turn'and k~='multiplier'then return false,'unknown_fury_cutter_field'end end end
      local stored=row.storage
      if stored and(type(stored)~='table'or M.epoch(b)~=7 or not integer(stored.turn,turn-1,turn)
          or not integer(stored.contacts,0,4))then return false,'invalid_rollout_storage'end
      if stored then for k in pairs(stored)do if k~='turn'and k~='contacts'then return false,'unknown_rollout_storage_field'end end end
    end
    return true
  end
  for source,d in pairs(defs)do
    local fact=assert(opts.facts.move(source,math.max(4,d.gen)))
    assert(fact.number==d.number and fact.generation==d.gen and fact.pp==d.pp
      and fact.accuracy==d.accuracy,'rolling source drift '..source)
    for _,native in ipairs(opts.species.moveIds(source))do
      local prior=assert(mod.content.moves:get(native),'missing existing rolling move '..source)
      assert(not prior.backendMoveOwner,'foreign rolling owner '..native)
      aliases[native]=source
      local effect='KA_ROLLING_COMBO_67_'..native
      mod.content.move_effects:register(effect,{kind='full',kascRollingCombo67=M.OWNER})
      mod.content.moves:patch(native,{effect=effect,backendMoveOwner=M.OWNER,backendMoveNumber=d.number,
        backendLearnsetRevision=prior.backendLearnsetRevision or 1,pp=d.pp,power=fact.power,
        contact=source=='ROLLOUT'or source=='ICE_BALL'or source=='FURY_CUTTER',
        flags=copy(opts.facts.data.moves[source].flags)})
      -- Some preserved Johto move rows have no animation row, because the
      -- general catalog only animated moves it newly registered. Preserve
      -- any genuine existing sequence; otherwise clone the same appropriate
      -- native primitive as that catalog (with cutter's actual slash path).
      if not mod.content.battle_anims:get(native)then
        local animation=clone(assert(mod.content.battle_anims:get(d.animation),
          'missing native rolling animation primitive '..d.animation))
        animation.source=M.OWNER;mod.content.battle_anims:register(native,animation)
        if not prior.anim then
          local part=assert(mod.content.moves:get(d.animation))
          mod.content.moves:patch(native,{anim=clone(part.anim)})
        end
      end
    end
  end
  do
    local move=assert(mod.content.moves:get('DEFENSE_CURL'));local prior=assert(mod.content.move_effects:get(move.effect))
    local fields=copy(prior);local run=assert(prior.run)
    fields.run=function(ctx)
      local result=run(ctx)
      if M.epoch(ctx.battle)and live(ctx.user)then lane(ctx.battle,ctx.user,true).curl=true end
      return result
    end
    fields.kascRollingCombo67=M.OWNER
    mod.content.move_effects:register('KA_ROLLING_DEFENSE_CURL_67',fields)
    mod.content.moves:patch('DEFENSE_CURL',{effect='KA_ROLLING_DEFENSE_CURL_67'})
  end
  function M.install()
    B._kascRollingCombo67=M;FX._kascRollingCombo67=M
    if not B._kascRollingComboWrapped67 then
      local perform,action,resolve,menu,clear=B.performMove,B.executeAction,B.resolveTurn,B.menuLockedAction,B.clearVolatiles
      B.performMove=function(...)return B._kascRollingCombo67.perform(perform,...)end
      B.executeAction=function(...)return B._kascRollingCombo67.action(action,...)end
      B.resolveTurn=function(...)return B._kascRollingCombo67.resolve(resolve,...)end
      B.menuLockedAction=function(b,w)return menu(b,w)or B._kascRollingCombo67.lock(b,w)end
      B.clearVolatiles=function(b,w,...)B._kascRollingCombo67.clear(b,w,true);return clear(b,w,...)end
      B._kascRollingComboWrapped67=true
    end
    if not FX._kascRollingComboWrapped67 then
      local run,make=FX.runDamaging,FX.makeCtx
      FX.runDamaging=function(b,ctx,record)
        return FX._kascRollingCombo67.storageRun(function(...)
          return FX._kascRollingCombo67.run(run,...)end,b,ctx,record)
      end
      FX.makeCtx=function(b,u,t,...)
        local ctx=make(b,u,t,...);ctx.move=FX._kascRollingCombo67.project(b,u,ctx.move);return ctx
      end
      FX._kascRollingComboWrapped67=true
    end
  end
  mod.content.move_effects:patch('HEAL_EFFECT',{kascRollingCombo67=M.OWNER})
  mod.hooks:wrap('battle.damage',M.damage,47000)
  mod.events:on('battle.move_used',M.used,8000)
  mod.events:on('battle.turn_started',M.begin,7000)
  mod.events:on('battle.turn_ended',M.endTurn,-6000)
  mod.events:on('battle.battler_switched',function(ev)M.clear(ev.battle,ev.battler)end,8000)
  mod.events:on('battle.ended',function(ev)M.clear(ev.battle)end,8000)
  M.install()
  if opts.supportLog and opts.supportLog.registerSegment then opts.supportLog.registerSegment({segmentId=M.CARD_ID,
    cardId=M.CARD_ID,schema='kasc.optional-feature-card/v1',version='1.0.0',owner=M.OWNER,active=true,
    dependencyStatus='native-turn-actions-and-owned-per-use-PP-continuation',providerStatus='rolling-fury-echoed-voice-round-singles',
    buildReceiptId='docs/ROLLING_COMBO_67.md',rollbackReceiptId='docs/ROLLING_COMBO_67.md'})end
  return M
end
