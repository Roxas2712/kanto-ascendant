-- Native declaration evidence is battle-local, not a new learned-slot
-- permission. Lock-On is a source/target pair, never a transferable buff.
return function(mod,opts)
  local B=require('src.battle.BattleState');local FX=require('src.battle.EffectRegistry')
  local Player=require('src.battle.AnimPlayer')
  local M={CARD_ID='KASC-67-TARGET-MEMORY',OWNER='kasc.target-memory/v1'}
  local defs={LOCK_ON={number=199,pp=5},MIND_READER={number=170,pp=5},CONVERSION_2={number=176,pp=30}}
  local aliases={};for id in pairs(opts.facts.data.moves)do
    for _,alias in ipairs(opts.species.moveIds(id))do aliases[alias]=id end
  end
  local types={'NORMAL','FIGHTING','FLYING','POISON','GROUND','ROCK','BUG','GHOST','STEEL',
    'FIRE','WATER','GRASS','ELECTRIC','PSYCHIC_TYPE','ICE','DRAGON','DARK','FAIRY'}
  local known={};for _,id in ipairs(types)do known[id]=true end
  local frames=setmetatable({},{__mode='k'});local tr=opts.i18n.text;local validateState
  local function copy(v)if type(v)~='table'then return v end;local out={};for k,x in pairs(v)do out[k]=copy(x)end;return out end
  local function pack(...)return{n=select('#',...),...}end
  local function integer(v,a,z)return type(v)=='number'and v%1==0 and v>=a and v<=z end
  local function live(w)local p=w and w.mon;return p and integer(p.hp,1,99999)and not w.fainted
    and not(p.egg or p.isEgg or p.is_egg or p.eggSpecies or p.species=='EGG')end
  local function side(b,w)return w==b.player and'player'or w==b.enemy and'enemy'or nil end
  local function other(key)return key=='player'and'enemy'or'player'end
  local function party(b,key)return key=='player'and b:playerPartyView()or b.enemyParty or{b.enemy and b.enemy.mon}end
  local function index(b,w)local key=side(b,w);if not key then return end
    for i,p in ipairs(party(b,key)or{})do if i<=6 and p==w.mon then return i end end
  end
  local function rows(b,create)
    if create then b.field=b.field or{};b.field.tokens=b.field.tokens or{}
      b.field.tokens[M.OWNER]=b.field.tokens[M.OWNER]or{locks={},last={},chosen={}}end
    return b and b.field and b.field.tokens and b.field.tokens[M.OWNER]
  end
  function M.epoch(b)
    local r=b and b.kascGenerationRulesReceipt;local h=b and b.data and b.data.move_effects and b.data.move_effects.HEAL_EFFECT
    return getmetatable(b)==B and not b.demo and b.kind~='link'and not b.result and r and r.mode~='off'
      and integer(r.activeEpoch,1,7)and h and h.kascTargetMemory67==M.OWNER and r.activeEpoch or nil
  end
  function M.profile(b,u,t,m)
    local gen=M.epoch(b);local id=m and aliases[m.id];local d=id and defs[id]
    local e=d and b.data.move_effects[m.effect]
    if not gen or not d or not live(u)or not live(t)or u==t or not side(b,u)or not side(b,t)
        or not index(b,u)or not index(b,t)or m.backendMoveOwner~=M.OWNER or m.backendMoveNumber~=d.number
        or not e or e.kascTargetMemory67~=M.OWNER then return end
    if gen<2 and not(opts.rules.ownedGiftBattleCompatible
      and opts.rules.ownedGiftBattleCompatible(b.game,u.mon,b.data.pokemon[u.mon.species]))then return end
    return math.max(2,gen),id
  end
  local function validLast(b,key,row)
    local gen=M.epoch(b);local w=b[key];local id=type(row)=='table'and aliases[row.native]
    return gen and w and id and b.data.moves[row.native]and row.profile==gen and row.declarationReached==true
      and type(row.called)=='boolean'and integer(row.turn,0,b.turnCount or 0)
      and(row.phase=='declared'or row.phase=='charge'or row.phase=='hit')
      and(row.caller==nil or row.called and opts.facts.data.moves[row.caller]~=nil)
      and row.party==index(b,w)and row.species==w.mon.species
      and(known[row.type]and b.data.type_chart.types[row.type]or row.type=='???'or row.type=='CURSE_TYPE')or false
  end
  function M.lastUsed(b,w)
    local s=rows(b);local key=b and w and side(b,w);local row=type(s)=='table'and key and s.last and s.last[key]
    -- A detached return value cannot forge/change the authoritative lane.
    return row and validLast(b,key,row)and copy(row)or nil
  end
  local clearChosenII={METRONOME=true,MIMIC=true,MIRROR_MOVE=true,SKETCH=true,SLEEP_TALK=true,TRANSFORM=true}
  function M.lastChosen(b,w)
    local s=rows(b);local key=b and w and side(b,w);local row=type(s)=='table'and key and s.chosen and s.chosen[key]
    if not row or not validLast(b,key,row)or row.called or row.caller then return end
    -- Pokemon.moveUsed's II ClearLastMove applies to the chosen move,
    -- not to Conversion2's subsequently resolved lastMoveUsed child.
    if M.epoch(b)==2 and clearChosenII[aliases[row.native]]then return end
    return copy(row)
  end
  local function validLock(b,key,row)
    local gen=M.epoch(b);local u,t=b[key],b[other(key)];local id=type(row)=='table'and aliases[row.native]
    return gen and u and t and live(u)and live(t)and(id=='LOCK_ON'or id=='MIND_READER')
      and row.profile==gen and row.epoch==math.max(2,gen)and integer(row.applied,0,b.turnCount or 0)
      and row.expires==row.applied+1 and(b.turnCount or 0)<=row.expires
      and integer(row.lastTurn,row.applied-1,b.turnCount or 0)
      and row.sourceParty==index(b,u)and row.sourceSpecies==u.mon.species
      and row.targetParty==index(b,t)and row.targetSpecies==t.mon.species
      and b.data.moves[row.native]and b.data.moves[row.native].backendMoveOwner==M.OWNER or false
  end
  function M.locked(b,u,t)
    if not b then return end
    local s=rows(b);local key=b and u and side(b,u);local row=type(s)=='table'and key and s.locks and s.locks[key]
    return t==b[other(key)]and row and validLock(b,key,row)and row or nil
  end
  local phaseBugs={ATTRACT=true,CURSE=true,FORESIGHT=true,MEAN_LOOK=true,MIMIC=true,NIGHTMARE=true,SPIDER_WEB=true,TRANSFORM=true}
  function M.phaseBypass(b,u,t,m)
    local row=M.locked(b,u,t);if not row or not m then return false end
    if row.epoch>=3 then return true end
    local phase=t.charging and aliases[t.charging.id];local id=aliases[m.id]or m.id
    if(phase=='DIG'or phase=='FLY')and phaseBugs[id]then return false end
    if phase=='FLY'and(id=='EARTHQUAKE'or id=='MAGNITUDE'or id=='FISSURE')then return false end
    return phase=='DIG'or phase=='FLY'
  end
  local function immutable(b,u)
    local a=opts.abilities.activeAbility(b,u);return a=='MULTITYPE'or a=='RKS_SYSTEM'
  end
  local function has(w,id)for _,t in ipairs(w.curTypes or{})do if t==id then return true end end end
  function M.possibleTypes(b,u,t,m)
    local gen,id=M.profile(b,u,t,m);local out={};if not gen or id~='CONVERSION_2'or immutable(b,u)then return out end
    local used=M.lastUsed(b,t);if not used then return out end
    local attack=used.type
    if aliases[used.native]=='STRUGGLE'then
      -- Explicit era move rule, not a guessed current catalogue type.
      if gen<=4 then attack='NORMAL'else return out end
    end
    for _,kind in ipairs(types)do
      if(kind~='FAIRY'or gen>=6)and b.data.type_chart.types[kind]and(gen<=3 or not has(u,kind))then
        local mult=10
        for _,row in ipairs(b.data.type_chart.matchups)do
          if row.attacker==attack and row.defender==kind then mult=math.floor(mult*row.multiplier/10)end
        end
        if mult<10 then out[#out+1]=kind end
      end
    end;return out
  end
  function M.noUseful(b,u,t,m)
    local gen,id=M.profile(b,u,t,m);if not gen then return false end
    if t.invulnerable and not M.phaseBypass(b,u,t,m)then return true end
    if id=='CONVERSION_2'then return #M.possibleTypes(b,u,t,m)==0 end
    if t.substituteHP or M.locked(b,u,t)then return true end
    return gen==2 and(t.foresight==true or M.locked(b,t,u)~=nil)or false
  end
  function M.cast(ctx)
    local b,u,t,m=ctx.battle,ctx.user,ctx.target,ctx.move;local gen,id=M.profile(b,u,t,m)
    local function failed()return{tr('But, it failed!','Doch es schlug fehl!'),failed=true}end
    if not gen or not validateState(b)or t.invulnerable and not M.phaseBypass(b,u,t,m)then return failed()end
    if id=='CONVERSION_2'then
      local pool=M.possibleTypes(b,u,t,m);if #pool==0 then return failed()end
      local kind=pool[b.rng(1,#pool)];u.curTypes={kind}
      return{tr('%s changed its type!','%s verändert seinen Typ!'):format(u.name)}
    end
    if M.noUseful(b,u,t,m)or opts.priority.blocks(ctx)or opts.protection.blocks(ctx)then return failed()end
    if gen<=3 and not b:accuracyRoll(m,u,t)then return failed()end
    local s=rows(b,true);local turn=b.turnCount or 0
    s.locks[side(b,u)]={native=m.id,profile=M.epoch(b),epoch=gen,applied=turn,expires=turn+1,lastTurn=turn-1,
      sourceParty=index(b,u),sourceSpecies=u.mon.species,targetParty=index(b,t),targetSpecies=t.mon.species}
    return{tr('%s took aim at %s!','%s nimmt %s ins Visier!'):format(u.name,t.name)}
  end
  function M.accuracy(nextAccuracy,ctx)
    local b,u,t,m=ctx and ctx.battle,ctx and ctx.user,ctx and ctx.target,ctx and ctx.move
    if not M.epoch(b)or not m then return nextAccuracy(ctx)end
    if M.locked(b,u,t)then
      -- Lock-On never removes the separate OHKO level/Sturdy/type gates.
      if m.effect=='OHKO_EFFECT'and u.mon.level<t.mon.level then return false end
      return true
    end
    local gen,id=M.profile(b,u,t,m)
    if gen and(id=='CONVERSION_2'or gen>=4)then return true end
    return nextAccuracy(ctx)
  end
  function M.declared(ev)
    local b,u,m=ev and ev.battle,ev and ev.user,ev and ev.move;local f=b and frames[b]
    if f and M.epoch(b)and u==f.user and ev.target==f.target and m and m.id==f.native
      and ev.isCalled==f.called and live(u)and side(b,u)and index(b,u)then f.declared=true end
  end
  function M.context(original,b,u,t,...)
    local ctx=original(b,u,t,...);local f=frames[b];local m=ctx.move
    if f and f.declared and M.epoch(b)and ctx.user==f.user and ctx.target==f.target
        and m and m.id==f.native and aliases[m.id]
        and index(b,u)and(known[m.type]or m.type=='???'or m.type=='CURSE_TYPE')then
      local s=rows(b,true);local row={native=m.id,type=m.type,profile=M.epoch(b),turn=b.turnCount or 0,
        party=index(b,u),species=u.mon.species,declarationReached=true,called=f.called,phase='declared',caller=f.caller}
      s.last[side(b,u)]=row;f.row=row;f.ctx=ctx
      if not f.called then s.chosen[side(b,u)]=copy(row);f.chosen=s.chosen[side(b,u)]end
    end
    return ctx
  end
  function M.perform(original,b,u,t,inst,isCalled,...)
    if not M.epoch(b)or not live(u)or not side(b,u)or not index(b,u)or not inst then return original(b,u,t,inst,isCalled,...)end
    local prior=frames[b];local f={user=u,target=t,native=inst.id,called=isCalled or false};frames[b]=f
    if f.called and prior and prior.declared and prior.user==u
      and(b:effectRecord((b:moveDef({id=prior.native})or{}).effect)or{}).callsMove then f.caller=prior.caller or aliases[prior.native]end
    local m=b:moveDef(inst);local inv,charge=t and t.invulnerable,t and t.charging
    local bypass=t and inv and m and not(b:effectRecord(m.effect)or{}).callsMove and M.phaseBypass(b,u,t,m)
    if bypass then t.invulnerable=nil end
    local out=pack(pcall(original,b,u,t,inst,isCalled,...));frames[b]=prior
    if f.row and M.lastUsed(b,u)then
      if u.charging and u.charging.id==inst.id and u.chargeReady then f.row.phase='charge'
      elseif f.ctx and f.ctx.totalDealt~=nil then f.row.phase='hit'end
      if f.chosen then f.chosen.phase=f.row.phase end
    end
    if bypass and t.invulnerable==nil and t.charging==charge and t.mon.hp>0 then t.invulnerable=inv end
    if not out[1]then error(out[2],0)end;return unpack(out,2,out.n)
  end
  function M.switched(ev)
    local b,w=ev and ev.battle,ev and ev.battler;local key=b and w and side(b,w);local s=rows(b)
    if not key or not ev.previous or type(s)~='table'then return end
    -- No Baton Pass transfer. Either real partner leaving invalidates all
    -- pairs, but the other side's own last declaration remains its own.
    s.locks={};s.last[key]=nil;s.chosen[key]=nil
  end
  function M.endTurn(ev)
    local b=ev and ev.battle;local s=rows(b);if not M.epoch(b)or type(s)~='table'then return end
    local turn=b.turnCount or 0
    for key,row in pairs(s.locks)do
      if not validLock(b,key,row)or turn>=row.expires then s.locks[key]=nil else row.lastTurn=turn end
    end
  end
  validateState=function(b)
    local s=rows(b);if s==nil then return true end
    if type(s)~='table'or type(s.locks)~='table'or type(s.last)~='table'or type(s.chosen)~='table'or not M.epoch(b)then return false,'invalid_target_memory'end
    for key in pairs(s)do if key~='locks'and key~='last'and key~='chosen'then return false,'unknown_memory_container_field'end end
    local allowedLast={native=true,type=true,profile=true,turn=true,party=true,species=true,declarationReached=true,called=true,phase=true,caller=true}
    local allowedLock={native=true,profile=true,epoch=true,applied=true,expires=true,lastTurn=true,
      sourceParty=true,sourceSpecies=true,targetParty=true,targetSpecies=true}
    for _,name in ipairs({'locks','last','chosen'})do for key,row in pairs(s[name])do
      local declaration=name=='last'or name=='chosen'
      if(key~='player'and key~='enemy')or not(declaration and validLast(b,key,row)or name=='locks'and validLock(b,key,row))
        or name=='chosen'and(row.called or row.caller~=nil)then
        return false,'invalid_target_identity_or_timeline'end
      for field in pairs(row)do if not(declaration and allowedLast or allowedLock)[field]then return false,'unknown_memory_record_field'end end
    end end;return true
  end
  function M.validateCheckpoint(b)
    if frames[b]then return false,'native_declaration_unsettled'end
    return validateState(b)
  end
  function M.move(original,b,inst,...)
    local m=original(b,inst,...);local id=m and aliases[m.id];local d=id and defs[id]
    if not d or m.backendMoveOwner~=M.OWNER or not M.epoch(b)then return m end
    local out=copy(m);out.accuracy=100;out.flags=id=='CONVERSION_2'and{bypasssub=1}or{protect=1,mirror=1}
    return out
  end
  function M.position(p,id)
    local a=p.data and p.data.moveAnims and p.data.moveAnims[id];local hud=mod.exports.pokemonPartnerHits67
    if not defs[aliases[id]]or not a or a.source~=M.OWNER or not hud then return end
    for _,step in ipairs(p.steps or{})do local sprites={};for i,s in ipairs(step.sprites or{})do local q=copy(s)
      if q.x>0 and q.x<168 and q.y>0 and q.y<160 and hud.inHud(q)then q.x=0 end;sprites[i]=q
    end;step.sprites=sprites end
  end
  function M.install()
    B._kascTargetMemory67=M;FX._kascTargetMemory67=M;Player._kascTargetMemory67=M
    if not B._kascTargetMemoryWrapped67 then local perform,move=B.performMove,B.moveDef
      B.performMove=function(...)return B._kascTargetMemory67.perform(perform,...)end
      B.moveDef=function(...)return B._kascTargetMemory67.move(move,...)end;B._kascTargetMemoryWrapped67=true
    end
    if not FX._kascTargetMemoryWrapped67 then local make=FX.makeCtx
      FX.makeCtx=function(...)return FX._kascTargetMemory67.context(make,...)end;FX._kascTargetMemoryWrapped67=true
    end
    if not Player._kascTargetMemoryWrapped67 then local start=Player.start
      Player.start=function(self,id,...)local out=pack(start(self,id,...));Player._kascTargetMemory67.position(self,id);return unpack(out,1,out.n)end
      Player._kascTargetMemoryWrapped67=true
    end
  end
  for id,d in pairs(defs)do local fact=assert(opts.facts.move(id,7))
    assert(fact.number==d.number and fact.generation==2 and fact.pp==d.pp and fact.target==10
      and fact.category=='status'and fact.power==0 and fact.type=='NORMAL','target memory source drift '..id)
    for _,alias in ipairs(opts.species.moveIds(id))do local old=assert(mod.content.moves:get(alias))
      assert(not old.backendMoveOwner and old.effect=='KA_GEN_MOVE_UNSUPPORTED_'..alias,'foreign target memory owner '..alias)
      local effect='KA_TARGET_MEMORY_67_'..alias
      mod.content.move_effects:register(effect,{kind='primary',accuracyChecked=false,kascTargetMemory67=M.OWNER,run=M.cast})
      mod.content.moves:patch(alias,{effect=effect,backendMoveOwner=M.OWNER,backendMoveNumber=d.number,
        backendLearnsetRevision=old.backendLearnsetRevision or 1,pp=d.pp,
        flags=id=='CONVERSION_2'and{bypasssub=1}or{protect=1,mirror=1}})
      local animation={seq={},source=M.OWNER}
      for _,part in ipairs(id=='CONVERSION_2'and{'FOCUS_ENERGY','LIGHT_SCREEN'}or{'FOCUS_ENERGY'})do
        for _,step in ipairs(assert(mod.content.battle_anims:get(part)).seq)do animation.seq[#animation.seq+1]=copy(step)end
      end
      if mod.content.battle_anims:get(alias)then mod.content.battle_anims:patch(alias,animation)
      else mod.content.battle_anims:register(alias,animation)end
      for i=#opts.catalog.unsupportedStatus,1,-1 do if opts.catalog.unsupportedStatus[i]==alias then table.remove(opts.catalog.unsupportedStatus,i)end end
    end
  end
  mod.content.move_effects:patch('HEAL_EFFECT',{kascTargetMemory67=M.OWNER})
  mod.hooks:wrap('battle.accuracy',M.accuracy,40000)
  mod.events:on('battle.move_used',M.declared,40000)
  mod.events:on('battle.battler_switched',M.switched,32000)
  mod.events:on('battle.turn_ended',M.endTurn,-20000)
  mod.events:on('battle.ended',function(ev)frames[ev.battle]=nil;if rows(ev.battle)then ev.battle.field.tokens[M.OWNER]=nil end end,32000)
  M.install()
  if opts.supportLog and opts.supportLog.registerSegment then opts.supportLog.registerSegment({segmentId=M.CARD_ID,
    cardId=M.CARD_ID,schema='kasc.optional-feature-card/v1',version='1.0.0',owner=M.OWNER,active=true,
    dependencyStatus='native-declaration-final-typed-context-real-pair-and-type-chart',providerStatus='gen2-7-lock-on-mind-reader-conversion2',
    buildReceiptId='docs/TARGET_MEMORY_67.md',rollbackReceiptId='docs/TARGET_MEMORY_67.md'})end
  return M
end
