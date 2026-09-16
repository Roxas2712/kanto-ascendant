-- A genuine native Sketch replaces its own permanent slot, not the caller's
-- slot or a Transform/Mimic shadow. Declaration evidence belongs to TargetMemory.
return function(mod,opts)
  local B=require('src.battle.BattleState');local FX=require('src.battle.EffectRegistry')
  local Player=require('src.battle.AnimPlayer')
  local M={CARD_ID='KASC-67-SKETCH',OWNER='kasc.sketch/v1',SCHEMA='kasc.sketched-moves/v1'}
  local tr=opts.i18n.text;local frames=setmetatable({},{__mode='k'});local aliases={}
  for name in pairs(opts.facts.data.moves)do for _,native in ipairs(opts.species.moveIds(name))do aliases[native]=name end end
  local function copy(v)if type(v)~='table'then return v end;local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r end
  local function pack(...)return{n=select('#',...),...}end
  local function int(v,a,z)return type(v)=='number'and v%1==0 and v>=a and v<=z end
  local function id(m)return m and(aliases[m.id]or m.id)end
  local function same(a,b)return a and b and a.id==b.id and a.effect==b.effect
    and a.backendMoveOwner==b.backendMoveOwner and a.backendMoveNumber==b.backendMoveNumber end
  local function side(b,w)return b and w and(w==b.player and'player'or w==b.enemy and'enemy')end
  local function index(b,w)
    local lane=side(b,w);if not lane then return end
    local party=lane=='player'and b:playerPartyView()or b.enemyParty or{b.enemy.mon}
    for i,p in ipairs(party or{})do if i<=6 and p==w.mon then return i end end
  end
  local function live(w)local p=w and w.mon;return p and int(p.hp,1,999999)and not w.fainted
    and not(p.egg or p.isEgg or p.is_egg or p.eggSpecies or p.species=='EGG')end
  local function sketchSlot(w)
    if not w or not w.mon or w.curMoves~=w.mon.moves then return end
    for i,s in ipairs(w.mon.moves or{})do if i<=4 and id(s)=='SKETCH'then return s,i end end
  end
  function M.epoch(b,u,move)
    local r=b and b.kascGenerationRulesReceipt;local h=b and b.data and b.data.move_effects and b.data.move_effects.HEAL_EFFECT
    if getmetatable(b)~=B or b.demo or b.kind=='link'or b.result or type(r)~='table'
        or not int(r.activeEpoch,1,7)or not(r.mode=='auto'or r.mode=='gen'..r.activeEpoch)
        or not h or h.kascSketch67~=M.OWNER then return end
    if not move then return r.activeEpoch end
    local e=b.data.move_effects[move.effect]
    if id(move)~='SKETCH'or move.backendMoveOwner~=M.OWNER or move.backendMoveNumber~=166
        or not e or e.kascSketch67~=M.OWNER then return end
    if r.activeEpoch<2 and not(live(u)and index(b,u)
        and opts.rules.monMoveAvailable(b.game,u.mon,move.id,r.activeEpoch,true))then return end
    return math.max(2,r.activeEpoch)
  end
  local iiExcluded={METRONOME=true,MIMIC=true,MIRROR_MOVE=true,SKETCH=true,SLEEP_TALK=true,TRANSFORM=true,
    EXPLOSION=true,SELF_DESTRUCT=true,SELFDESTRUCT=true}
  function M.sketchable(b,name,gen,nativeId)
    local known=name and opts.facts.data.moves[name]
    -- A genuine licensed future declaration can be sketched in an older
    -- host. The fact authority deliberately rejects unintroduced III–VI
    -- moves at that old era; resolve its real birth, while retaining the
    -- COPYING era's own exclusion rules below. This is not learnability.
    local fact=known and int(known.generation,1,7)and opts.facts.move(name,math.max(gen,2,known.generation))
    local native=b and b.data and b.data.moves[nativeId or name]
    if not fact or not native or not int(fact.number,1,100000)or not int(fact.generation,1,7)
        or name=='SKETCH'or name=='STRUGGLE'or gen==2 and iiExcluded[name]
        or gen>=4 and name=='CHATTER'or native.isZ or native.isMax
        or type(native.effect)~='string'or native.effect:find('UNSUPPORTED',1,true)then return false end
    -- Gen VIII explicitly restores Dark Void/Hyperspace Fury's sketchability;
    -- do not import their later Gen-IX nosketch flags into II-VII.
    return true
  end
  local function identity(mon)
    local d=mon.dvs or{};local gift=mon.eventDistribution and mon.eventDistribution.giftCode or{}
    local parts={M.SCHEMA,mon.species,tostring(mon.otId or mon.trainerId or''),tostring(mon.otName or'')}
    for _,k in ipairs({'hp','attack','defense','speed','special'})do parts[#parts+1]=k..':'..tostring(d[k]or'')end
    parts[#parts+1]=tostring(gift.digest or'');return table.concat(parts,'|')
  end
  local function seal(binding,name,row)
    local s=row.source
    return table.concat({binding.identity,name,row.native,tostring(row.number),tostring(row.originGeneration),
      s.species,tostring(s.party),tostring(s.profile),tostring(s.turn),s.native},'|')
  end
  function M.validMon(game,mon)
    local p=type(mon)=='table'and mon._kascSketch67
    local definition=game and game.data and type(mon)=='table'and game.data.pokemon[mon.species]
    if type(p)~='table'or p.owner~=M.OWNER or p.schema~=M.SCHEMA or p.version~=1
        or p.originSpecies~=mon.species or p.identity~=identity(mon)or type(p.moves)~='table'
        or not definition or(definition.sourceDex or definition.dex)~=235 then return false end
    for k in pairs(p)do if k~='owner'and k~='schema'and k~='version'and k~='originSpecies'and k~='identity'and k~='moves'then return false end end
    local count=0;for name,r in pairs(p.moves)do
      count=count+1;local fact=opts.facts.move(name,7);local s=type(r)=='table'and r.source
      if count>1000 or not fact or type(s)~='table'or(aliases[r.native]or r.native)~=name or r.number~=fact.number
          or not int(r.originGeneration,2,7)or not int(s.profile,1,7)or r.originGeneration~=math.max(2,s.profile)
          or not int(s.party,1,6)or not int(s.turn,0,10000000)or not game.data.pokemon[s.species]
          or s.native~=r.native or not M.sketchable({data=game.data},name,r.originGeneration,r.native)
          or r.proof~=seal(p,name,r)then return false end
      for k in pairs(r)do if k~='native'and k~='number'and k~='originGeneration'and k~='source'and k~='proof'then return false end end
      for k in pairs(s)do if k~='species'and k~='party'and k~='profile'and k~='turn'and k~='native'then return false end end
    end;return count>0
  end
  -- The root gift provider must FIRST authenticate the durable gift and actual
  -- ownership. This predicate only grants the single exact copied move.
  function M.legalCopiedMove(game,mon,native,epoch)
    local name=aliases[native]or native;local p=mon and mon._kascSketch67
    return int(epoch,1,7)and M.validMon(game,mon)and p.moves[name]~=nil or false
  end
  function M.choice(b,u,t,move)
    local gen=M.epoch(b,u,move);local slot,at=sketchSlot(u)
    if not gen or not live(u)or not live(t)or u==t or not index(b,u)or not index(b,t)or not slot then return end
    local source=b.data.pokemon[u.mon.species]
    if not source or(source.sourceDex or source.dex)~=235 then return end
    if gen<=4 and t.substituteHP~=nil then return end
    local identityOwner=assert(mod.exports.pokemonBattleIdentity67,'Sketch needs the native identity owner')
    if gen==2 and identityOwner.transformed(t)then return end
    -- Crystal/Emerald Sketch do not perform an accuracy/phase hit test.
    -- Later native generations use the existing No Guard/Lock-On owners.
    if gen>=4 and opts.abilities.moveScope(b,u,t,true,function()
      local memory=mod.exports.pokemonTargetMemory67
      return t.invulnerable and not(memory and memory.phaseBypass(b,u,t,move))
    end,move)then return end
    local memory=assert(mod.exports.pokemonTargetMemory67,'Sketch needs the native target-declaration owner')
    assert(type(memory.lastChosen)=='function','Sketch needs TargetMemory.lastChosen, not lastMoveUsed')
    local used=memory.lastChosen(b,t);local name=used and(aliases[used.native]or used.native)
    if not used or not M.sketchable(b,name,gen,used.native)then return end
    for _,s in ipairs(u.mon.moves)do if id(s)==name then return end end
    return{slot=slot,index=at,move=b.data.moves[used.native],native=used.native,name=name,used=used,epoch=gen}
  end
  function M.noUseful(b,u,t,move)return M.epoch(b,u,move)and not M.choice(b,u,t,move)or false end
  local function fail()return{tr('But, it failed!','Doch es schlug fehl!'),failed=true}end
  function M.cast(ctx)
    local b,u,t,move=ctx.battle,ctx.user,ctx.target,ctx.move;local f=frames[b]
    if not f or not f.declared or not f.reached or f.ctx~=ctx or f.user~=u or f.target~=t or not same(f.move,move)
        or not f.source or u.mon.moves[f.index]~=f.source then return fail()end
    local p=M.choice(b,u,t,move);if not p or p.slot~=f.source or p.index~=f.index then return fail()end
    local memory=mod.exports.generationMoveMemory
    assert(memory and memory.markEdited,'Sketch needs the native generation move-memory owner')
    local binding=u.mon._kascSketch67
    if binding and not M.validMon(b.game,u.mon)then return fail()end
    binding=binding or{schema=M.SCHEMA,owner=M.OWNER,version=1,originSpecies=u.mon.species,identity=identity(u.mon),moves={}}
    local used=p.used;local row={native=p.native,number=opts.facts.move(p.name,7).number,originGeneration=p.epoch,
      source={species=used.species,party=used.party,profile=used.profile,turn=used.turn,native=p.native}}
    row.proof=seal(binding,p.name,row)
    local ups=p.epoch>=3 and p.epoch<=4 and int(p.slot.ppUps or 0,0,3)and(p.slot.ppUps or 0)or 0
    -- Keep the actual source slot object: Grudge/Pressure/native move-used
    -- observers cannot acquire a detached/new caller slot as a side effect.
    for k in pairs(p.slot)do p.slot[k]=nil end
    p.slot.id=p.native;p.slot.pp=p.move.pp;p.slot.ppUps=ups
    p.slot.acquisition={kind='sketch',owner=M.OWNER,sourceSpecies=used.species,generation=p.epoch}
    binding.moves[p.name]=row;u.mon._kascSketch67=binding
    u.mon.moveProvenance=u.mon.moveProvenance or{};u.mon.moveProvenance[p.native]=copy(p.slot.acquisition)
    memory.markEdited(u.mon,'sketch')
    return{tr('%s sketched %s!','%s hat %s nachgeahmt!'):format(u.name,p.move.name)}
  end
  function M.used(ev)
    local f=ev and frames[ev.battle]
    if f and ev.user==f.user and ev.target==f.target and same(ev.move,f.move)and ev.isCalled==f.called then f.declared=true end
  end
  function M.context(original,b,u,t,...)
    local ctx=original(b,u,t,...);local f=frames[b]
    if f and f.declared and ctx.user==f.user and ctx.target==f.target and same(ctx.move,f.move)then f.reached=true;f.ctx=ctx end
    return ctx
  end
  function M.perform(original,b,u,t,inst,called,...)
    if not M.epoch(b)or not live(u)or not inst then return original(b,u,t,inst,called,...)end
    local move=b:moveDef(inst);if not move then return original(b,u,t,inst,called,...)end
    local prior=frames[b];local own=sketchSlot(u);local source,at
    if id(move)=='SKETCH'then
      if not called and inst==own then source,at=sketchSlot(u)
      elseif called and prior and prior.user==u and prior.declared and prior.reached
          and prior.move.id=='SLEEP_TALK'and M.epoch(b)<=4 and own then source,at=sketchSlot(u)end
    end
    local f={user=u,target=t,move=move,called=called or false,source=source,index=at};frames[b]=f
    local out=pack(pcall(original,b,u,t,inst,called,...));frames[b]=prior
    if not out[1]then error(out[2],0)end;return unpack(out,2,out.n)
  end
  function M.validateCheckpoint(b)
    if frames[b]then return false,'sketch_unsettled'end
    for _,lane in ipairs({'player','enemy'})do local w=b and b[lane]
      if w and w.mon._kascSketch67 and not M.validMon(b.game,w.mon)then return false,'invalid_sketched_moves'end
    end;return true
  end
  local fact=assert(opts.facts.move('SKETCH',7));local old=assert(mod.content.moves:get('SKETCH'))
  assert(fact.number==166 and fact.generation==2 and fact.pp==1 and fact.power==0 and fact.alwaysHits
    and fact.accuracy==100 and fact.category=='status'and fact.type=='NORMAL'and fact.target==10 and fact.priority==0,'Sketch source drift')
  assert(not old.backendMoveOwner and old.effect=='KA_GEN_MOVE_UNSUPPORTED_SKETCH','foreign Sketch owner')
  local effect='KA_SKETCH_67';mod.content.move_effects:register(effect,{kind='primary',run=M.cast,accuracyChecked=false,kascSketch67=M.OWNER})
  for _,native in ipairs(opts.species.moveIds('SKETCH'))do if mod.content.moves:get(native)then
    mod.content.moves:patch(native,{effect=effect,power=0,pp=1,noPPBoosts=true,category='status',type='NORMAL',target=10,
      flags={bypasssub=1,failencore=1,noassist=1,failcopycat=1,failmimic=1,failinstruct=1,nosketch=1},
      kascBypassSub67=true,backendMoveOwner=M.OWNER,backendMoveNumber=166,originGeneration=2,
      backendLearnsetRevision=old.backendLearnsetRevision or 1})end end
  mod.content.move_effects:patch('HEAL_EFFECT',{kascSketch67=M.OWNER})
  for i=#opts.catalog.unsupportedStatus,1,-1 do if opts.catalog.unsupportedStatus[i]=='SKETCH'then table.remove(opts.catalog.unsupportedStatus,i)end end
  local anim=copy(assert(mod.content.battle_anims:get('MIMIC')));anim.source=M.OWNER;mod.content.battle_anims:patch('SKETCH',anim)
  function M.position(p,name)
    if name~='SKETCH'or not p.data.moveAnims[name]or p.data.moveAnims[name].source~=M.OWNER then return end
    local hud=assert(mod.exports.pokemonPartnerHits67)
    for _,step in ipairs(p.steps or{})do for i,s in ipairs(step.sprites or{})do local q=copy(s)
      if q.x>0 and q.x<168 and q.y>0 and q.y<160 and(q.y<16 or hud.inHud(q))then q.x=0 end;step.sprites[i]=q
    end end
  end
  function M.install()
    B._kascSketch67=M;FX._kascSketch67=M;Player._kascSketch67=M
    if not B._kascSketchWrapped67 then local perform=B.performMove
      B.performMove=function(...)return B._kascSketch67.perform(perform,...)end;B._kascSketchWrapped67=true end
    if not FX._kascSketchWrapped67 then local make=FX.makeCtx
      FX.makeCtx=function(...)return FX._kascSketch67.context(make,...)end;FX._kascSketchWrapped67=true end
    if not Player._kascSketchWrapped67 then local start=Player.start
      Player.start=function(self,name,...)local r=pack(start(self,name,...));Player._kascSketch67.position(self,name);return unpack(r,1,r.n)end
      Player._kascSketchWrapped67=true end
  end
  mod.events:on('battle.move_used',M.used,32001);M.install()
  if opts.supportLog and opts.supportLog.registerSegment then opts.supportLog.registerSegment({segmentId=M.CARD_ID,cardId=M.CARD_ID,
    schema='kasc.optional-feature-card/v1',version='1.0.0',owner=M.OWNER,active=true,
    dependencyStatus='native-own-slot-and-target-chosen-declaration',providerStatus='permanent-source-bound-sketch',
    buildReceiptId='docs/SKETCH_67.md',rollbackReceiptId='docs/SKETCH_67.md'})end
  return M
end
