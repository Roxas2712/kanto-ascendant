-- Native battle-local type changes. Stored Pokemon/species/chart stay intact.
return function(mod,opts)
  local B=require('src.battle.BattleState');local Player=require('src.battle.AnimPlayer')
  local M={OWNER='kasc.type-changes/v1',CARD_ID='KASC-67-TYPE-CHANGES'};local tr=opts.i18n.text
  local defs={CONVERSION={number=160,birth=1,pp=30,self=true,always=true,type='NORMAL',anim='CONVERSION'},
    CAMOUFLAGE={number=293,birth=3,pp=20,self=true,always=true,type='NORMAL',anim='BARRIER'},
    SOAK={number=487,birth=5,pp=20,type='WATER',anim='WATER_GUN'},
    REFLECT_TYPE={number=513,birth=5,pp=15,always=true,type='NORMAL',anim='CONVERSION'},
    TRICK_OR_TREAT={number=567,birth=6,pp=20,type='GHOST',anim='CONFUSE_RAY'},
    FORESTS_CURSE={number=571,birth=6,pp=20,type='GRASS',anim='LEECH_SEED'},
    ELECTRIFY={number=582,birth=6,pp=20,always=true,type='ELECTRIC',anim='THUNDER_WAVE'}}
  local aliases={};for id in pairs(opts.facts.data.moves)do for _,a in ipairs(opts.species.moveIds(id))do aliases[a]=id end end
  local types={NORMAL=true,FIGHTING=true,FLYING=true,POISON=true,GROUND=true,ROCK=true,BUG=true,GHOST=true,STEEL=true,
    FIRE=true,WATER=true,GRASS=true,ELECTRIC=true,PSYCHIC=true,PSYCHIC_TYPE=true,ICE=true,DRAGON=true,DARK=true,FAIRY=true,['???']=true}
  local frames=setmetatable({},{__mode='k'});local originalConversion
  local function copy(v)if type(v)~='table'then return v end;local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r end
  local function pack(...)return{n=select('#',...),...}end
  local function int(v,a,z)return type(v)=='number'and v%1==0 and v>=a and v<=z end
  local function equal(a,z)if type(a)~='table'or type(z)~='table'or#a~=#z then return false end;for i,x in ipairs(a)do if z[i]~=x then return false end end;return true end
  local function validTypes(v,min,max)if type(v)~='table'or#v<min or#v>max then return false end
    for i,x in pairs(v)do if not int(i,1,#v)or not types[x]then return false end end;return true end
  local function has(v,x)for _,t in ipairs(v or{})do if t==x then return true end end;return false end
  local function side(b,w)return w==b.player and'player'or w==b.enemy and'enemy'or nil end
  local function party(b,key)return key=='player'and b:playerPartyView()or key=='enemy'and(b.enemyParty or{b.enemy.mon})end
  local function index(b,w)for i,p in ipairs(party(b,side(b,w))or{})do if i<=6 and p==w.mon then return i end end end
  local function live(w)local p=w and w.mon;return p and int(p.hp,1,999999)and not w.fainted
    and not(p.egg or p.isEgg or p.is_egg or p.eggSpecies or p.species=='EGG')end
  local function rows(b,create)if create then b.field=b.field or{};b.field.tokens=b.field.tokens or{}
    b.field.tokens[M.OWNER]=b.field.tokens[M.OWNER]or{added={},electrify={},entries={}}end
    return b and b.field and b.field.tokens and b.field.tokens[M.OWNER]end
  local function seal(v)local r=copy(v);r.proof=nil;return opts.rules.receipts.hash(M.OWNER..':'..opts.rules.receipts.canonical(r))end
  function M.epoch(b,u,move)
    local r=b and b.kascGenerationRulesReceipt;local e=b and b.data and b.data.move_effects and b.data.move_effects.HEAL_EFFECT
    if getmetatable(b)~=B or b.demo or b.kind=='link'or b.result or not r or not int(r.activeEpoch,1,7)
      or not(r.mode=='auto'or r.mode=='gen'..r.activeEpoch)or not e or e.kascTypeChanges67~=M.OWNER then return end
    if not move then return r.activeEpoch end
    local id=aliases[move.id]or move.id;local d=defs[id];local rec=d and b:effectRecord(move.effect)
    if not d or move.backendMoveOwner~=M.OWNER or move.backendMoveNumber~=d.number or not rec or rec.kascTypeChanges67~=M.OWNER then return end
    if r.activeEpoch<d.birth and not(live(u)and index(b,u)and opts.rules.monMoveAvailable(b.game,u.mon,move.id,r.activeEpoch,true))then return end
    return math.max(d.birth,r.activeEpoch),id
  end
  local function semanticDex(b,w)
    local identity=mod.exports.pokemonBattleIdentity67;local key=identity and identity.current(b,w)or w.mon.species
    local d=key and b.data.pokemon[key];return d and(d.sourceDex or d.dex)
  end
  function M.immutable(b,w,gen,reflect)
    local dex=semanticDex(b,w)
    return(reflect or gen>=5)and(dex==493 or dex==773)or gen==4 and opts.abilities.activeAbility(b,w)=='MULTITYPE'or false
  end
  local function sameIdentity(b,w,h)return type(h)=='table'and h.species==w.mon.species and h.party==index(b,w)
    and h.profile==M.epoch(b)and h.proof==seal(h)end
  function M.added(b,w)
    local r=rows(b);local h=r and r.added and r.added[side(b,w)]
    if not M.epoch(b)or not sameIdentity(b,w,h)then return end
    if equal(w.curTypes,h.types)then return h end
    local heal=mod.exports.pokemonHealingMoves67
    if heal and heal.roostActive(b,w)and equal(heal.typesForTransform(b,w),h.types)then return h end
  end
  function M.parts(b,w)
    local h=M.added(b,w);if not h then return copy(w.curTypes),nil end
    local base=copy(h.base);local heal=mod.exports.pokemonHealingMoves67
    if heal and heal.roostActive(b,w)and not equal(w.curTypes,h.types)then
      local out={};for _,t in ipairs(base)do if t~='FLYING'then out[#out+1]=t end end;base=out
    end
    return base,h.added
  end
  local function saveAdded(b,w,base,added)
    local full=copy(base);full[#full+1]=added
    local h={species=w.mon.species,party=index(b,w),profile=M.epoch(b),base=copy(base),added=added,types=full}
    h.proof=seal(h);rows(b,true).added[side(b,w)]=h;w.curTypes=copy(full);return h
  end
  function M.clearAdded(b,w)local r=rows(b);if r and r.added then r.added[side(b,w)]=nil end end
  function M.setTypes(b,w,base,added)
    M.clearAdded(b,w);w.curTypes=copy(base);if added then saveAdded(b,w,base,added)end
  end
  -- Exact semantic copy, called only after the genuine Transform owner.
  function M.transformed(b,w,target)
    local identity=mod.exports.pokemonBattleIdentity67;local h=M.added(b,target)
    M.clearAdded(b,w)
    if M.epoch(b)and h and identity and identity.transformed(w)and identity.current(b,w)==identity.current(b,target)
      and equal(w.curTypes,h.types)then saveAdded(b,w,h.base,h.added)end
  end
  function M.fireLost(ctx)
    local b,w=ctx.battle,ctx.user;local burn=mod.exports.pokemonBurnUp67;local r=rows(b);local h=r and r.added and r.added[side(b,w)]
    if not M.epoch(b)or not burn or not burn.active(b,ctx.move)or not sameIdentity(b,w,h)then return end
    local base=copy(h.base);local full=copy(h.types);for i,t in ipairs(base)do if t=='FIRE'then base[i]='???'end end
    for i,t in ipairs(full)do if t=='FIRE'then full[i]='???'end end
    local heal=mod.exports.pokemonHealingMoves67;local current=heal and heal.typesForTransform(b,w)or w.curTypes
    if equal(current,full)then h.base=base;h.types=full;h.proof=seal(h)end
  end
  function M.typesMatch(b,w,base)
    local h=M.added(b,w);return h~=nil and equal(h.base,base)
  end
  -- A repeated Multitype/RKS sync is not a real item/forme change. Keep
  -- the genuine added slot (including its Roost-filtered live view) only
  -- while the source item-selected BASE still matches exactly.
  function M.typeItemProjection(b,w,base)
    if M.typesMatch(b,w,base)then return copy(w.curTypes)end
  end
  local environments={grass=true,long_grass=true,sand=true,underwater=true,water=true,pond=true,mountain=true,cave=true,
    building=true,plain=true,snow=true,ice=true,marsh=true,bridge=true}
  function M.environment(b)
    local r=rows(b);if r and r.environment then return r.environment.kind end
    local called=mod.exports.pokemonCalledMoves67;return called and called.environment(b)or'building'
  end
  function M.camouflageType(b,gen)
    local terrain=mod.exports.pokemonTerrain67;local t=gen>=6 and terrain and terrain.current(b)
    if t then return({electric='ELECTRIC',grassy='GRASS',misty='FAIRY',psychic='PSYCHIC_TYPE'})[t]end
    local env=M.environment(b)
    if env=='grass'or env=='long_grass'then return'GRASS'
    elseif env=='water'or env=='pond'or env=='underwater'then return'WATER'
    elseif env=='sand'then return'GROUND'
    elseif env=='cave'or env=='mountain'then return'ROCK'
    elseif gen>=4 and(env=='snow'or env=='ice')then return'ICE'
    elseif gen>=4 and(env=='marsh'or env=='plain')then return'GROUND'
    elseif gen>=4 and env=='bridge'then return'FLYING'end
    -- Host authored backgrounds use the actual Emerald III / Platinum
    -- IV tables; the latter remains KASC's authored IV--VII mapping.
    -- Building is Normal even in V: Showdown's Ground V default models
    -- its Wi-Fi background, not a real indoor map observation.
    return'NORMAL'
  end
  function M.conversionTypes(b,u,gen)
    local out={};if M.immutable(b,u,gen)then return out end
    for i,slot in ipairs(u.curMoves or{})do if i>4 or gen>=6 and i>1 then break end
      -- Conversion reads the database type, NOT Hidden Power's genetic
      -- type, Normalize/-ate, item signature types or current Electrify.
      local move=b.data.moves[slot.id];local id=aliases[slot.id]or slot.id;local typ=move and move.type
      if typ=='CURSE_TYPE'or typ=='???'then typ=nil end
      if types[typ]and not has(u.curTypes,typ)and not((gen==4 or gen==5)and id=='CONVERSION')then out[#out+1]=typ end
    end;return out
  end
  local function newlyEntered(b,w)
    local r=rows(b);local h=r and r.entries and r.entries[side(b,w)]
    return sameIdentity(b,w,h)and h.turn==(b.turnCount or 0)or false
  end
  local function pending(b,w)local c=mod.exports.pokemonCalledMoves67;return c and c.pending(b,w)end
  function M.electrified(b,w)
    local r=rows(b);local h=r and r.electrify and r.electrify[side(b,w)]
    return M.epoch(b)and sameIdentity(b,w,h)and h.turn==(b.turnCount or 0)and h or nil
  end
  function M.electrifyProject(b,u,move)
    if not move or move.id=='STRUGGLE'or move.kascElectrified67==M.OWNER or not M.electrified(b,u)then return move end
    local future=mod.exports.pokemonFutureStrikes67;if future and future.preservesType(b,u,move)then return move end
    local out=copy(move);out.type='ELECTRIC';out.kascElectrified67=M.OWNER;return out
  end
  function M.noUseful(b,u,t,move)
    local gen,id=M.epoch(b,u,move);if not gen then return false end
    if id=='CONVERSION'and gen==1 then return not live(t)or not live(u)or not not t.invulnerable end
    if not live(u)or not live(t)then return true end
    if id=='CONVERSION'then return#M.conversionTypes(b,u,gen)==0
    elseif id=='CAMOUFLAGE'then local typ=M.camouflageType(b,gen);return M.immutable(b,u,gen)or(gen<=4 and has(u.curTypes,typ)or gen>=6 and equal(u.curTypes,{typ}))
    elseif id=='REFLECT_TYPE'then local base,added=M.parts(b,t);local usable={};for _,typ in ipairs(base)do if typ~='???'then usable[#usable+1]=typ end end
      return M.immutable(b,u,gen,true)or#usable==0 and not added
    elseif id=='SOAK'then return M.immutable(b,t,gen)or gen>=6 and equal(t.curTypes,{'WATER'})
    elseif id=='TRICK_OR_TREAT'or id=='FORESTS_CURSE'then local base=M.parts(b,t)
      return not validTypes(base,0,2)or has(t.curTypes,id=='TRICK_OR_TREAT'and'GHOST'or'GRASS')
    else return M.electrified(b,t)~=nil or not pending(b,t)and not newlyEntered(b,t)end
  end
  local function fail(animate)return{tr('But, it failed!','Doch es schlug fehl!'),failed=not animate or nil}end
  function M.cast(ctx)
    local b,u,t,move=ctx.battle,ctx.user,ctx.target,ctx.move;local gen,id=M.epoch(b,u,move)
    if id=='CONVERSION'and gen==1 or not gen and(aliases[move.id]or move.id)=='CONVERSION'then return originalConversion(ctx)end
    if not gen or not live(u)or not live(t)or not index(b,u)or not index(b,t)then return fail()end
    local d=defs[id]
    if not d.self then
      if opts.priority.blocks(ctx)or opts.protection.blocks(ctx)or id~='REFLECT_TYPE'and t.substituteHP then return fail()end
      local memory=mod.exports.pokemonTargetMemory67
      if t.invulnerable and not(memory and memory.phaseBypass(b,u,t,move))then return fail()end
      if id=='ELECTRIFY'and M.noUseful(b,u,t,move)then return fail()end
      local absorb=mod.exports.pokemonTypeAbsorption67;if absorb and absorb.absorb(b,ctx)then return{}end
      if not d.always and not b:accuracyRoll(move,u,t)then return fail()end
    end
    if M.noUseful(b,u,t,move)then return fail(id=='SOAK')end
    if id=='CONVERSION'then local p=M.conversionTypes(b,u,gen);M.setTypes(b,u,{p[b.rng(1,#p)]})
    elseif id=='CAMOUFLAGE'then local r=rows(b,true);if not r.environment then
      r.environment={kind=M.environment(b),map=b.checkpointOrigin and b.checkpointOrigin.map};r.environment.proof=seal(r.environment)end
      M.setTypes(b,u,{M.camouflageType(b,gen)})
    elseif id=='SOAK'then M.setTypes(b,t,{'WATER'})
    elseif id=='REFLECT_TYPE'then local base,added=M.parts(b,t);local real={};for _,typ in ipairs(base)do if typ~='???'then real[#real+1]=typ end end
      if#real==0 then real={'NORMAL'}end;M.setTypes(b,u,real,added)
    elseif id=='TRICK_OR_TREAT'or id=='FORESTS_CURSE'then local base=M.parts(b,t);saveAdded(b,t,base,id=='TRICK_OR_TREAT'and'GHOST'or'GRASS')
    else local h={species=t.mon.species,party=index(b,t),profile=M.epoch(b),epoch=gen,turn=b.turnCount or 0};h.proof=seal(h)
      rows(b,true).electrify[side(b,t)]=h;return{tr('%s was electrified!','%s wurde elektrifiziert!'):format(t.name)}end
    return{tr('The battle type changed!','Der Kampftyp hat sich verändert!')}
  end
  function M.entered(ev)
    local b=ev.battle;if not M.epoch(b)then return end;local r=rows(b,true)
    local function add(w)local key=side(b,w);if live(w)and key and index(b,w)then
      r.added[key]=nil;r.electrify[key]=nil;local h={species=w.mon.species,party=index(b,w),profile=M.epoch(b),turn=b.turnCount or 0};h.proof=seal(h);r.entries[key]=h end end
    if ev.battler then add(ev.battler)else add(b.player);add(b.enemy)end
  end
  function M.reconcile(b)
    local r=rows(b);if not r or not M.epoch(b)or type(r)~='table'or type(r.added)~='table'or type(r.electrify)~='table'then return end
    for _,key in ipairs({'player','enemy'})do local w=b[key]
      if r.added[key]and(not w or not M.added(b,w))then r.added[key]=nil end
      local h=r.electrify[key];if h and(not w or not sameIdentity(b,w,h)or h.turn~=(b.turnCount or 0))then r.electrify[key]=nil end
    end
  end
  function M.perform(original,b,...)
    if not M.epoch(b)then return original(b,...)end
    M.reconcile(b);local old=frames[b];frames[b]=true;local out=pack(pcall(original,b,...));frames[b]=old;M.reconcile(b)
    if not out[1]then error(out[2],0)end;return unpack(out,2,out.n)
  end
  function M.validateCheckpoint(b)
    if frames[b]then return false,'type_changes_unsettled'end
    local r=rows(b);if not r then return true end
    if not M.epoch(b)or type(r)~='table'or type(r.added)~='table'or type(r.electrify)~='table'or type(r.entries)~='table'then return false,'invalid_type_changes_container'end
    for k in pairs(r)do if k~='added'and k~='electrify'and k~='entries'and k~='environment'then return false,'unknown_type_changes_field'end end
    for _,kind in ipairs({'added','electrify','entries'})do for key,h in pairs(r[kind])do local w=(key=='player'or key=='enemy')and b[key]
      if not w or not sameIdentity(b,w,h)then return false,'invalid_type_changes_identity'end
      if kind=='added'then
        if not validTypes(h.base,0,2)or not validTypes(h.types,1,3)or(h.added~='GHOST'and h.added~='GRASS')or not M.added(b,w)then return false,'invalid_added_type'end
        local full=copy(h.base);full[#full+1]=h.added;if not equal(full,h.types)then return false,'invalid_added_type_projection'end
      elseif not int(h.turn,0,b.turnCount or 0)or kind=='electrify'and(h.turn~=(b.turnCount or 0)or h.epoch~=math.max(6,M.epoch(b)))then return false,'invalid_electrify_turn'end
      for k in pairs(h)do if k~='species'and k~='party'and k~='profile'and k~='proof'and not(kind=='added'and(k=='base'or k=='types'or k=='added')or kind=='electrify'and(k=='turn'or k=='epoch')or kind=='entries'and k=='turn')then return false,'unknown_type_changes_row_field'end end
    end end
    local e=r.environment;if e then
      if type(e)~='table'or not environments[e.kind]or e.map~=(b.checkpointOrigin and b.checkpointOrigin.map)or e.proof~=seal(e)then return false,'invalid_camouflage_environment'end
      for k in pairs(e)do if k~='kind'and k~='map'and k~='proof'then return false,'unknown_camouflage_environment_field'end end
    end;return true
  end
  for id,d in pairs(defs)do local f=assert(opts.facts.move(id,7));local old=assert(mod.content.moves:get(id));local e='KA_TYPE_CHANGE_67_'..id
    assert(f.number==d.number and f.generation==d.birth and f.pp==d.pp and f.power==0 and f.category=='status'and f.accuracy==100 and f.alwaysHits==not not d.always,'type move source drift '..id)
    assert(not old.backendMoveOwner,'foreign type move owner '..id)
    if id=='CONVERSION'then assert(old.effect=='CONVERSION_EFFECT','foreign native Conversion effect');originalConversion=assert(mod.content.move_effects:get(old.effect)).run
    else assert(old.effect=='KA_GEN_MOVE_UNSUPPORTED_'..id,'foreign unsupported type effect '..id)end
    mod.content.move_effects:register(e,{kind='primary',run=M.cast,accuracyChecked=false,kascTypeChanges67=M.OWNER})
    local flags={metronome=1};if d.self then flags.snatch=1 elseif id=='REFLECT_TYPE'then flags.protect=1;flags.bypasssub=1;flags.allyanim=1
    else flags.protect=1;flags.mirror=1;flags.allyanim=1;if id~='ELECTRIFY'then flags.reflectable=1 end end
    mod.content.moves:patch(id,{effect=e,power=0,pp=d.pp,type=d.type,category='status',accuracy=100,target=d.self and 7 or 10,
      flags=flags,backendMoveOwner=M.OWNER,backendMoveNumber=d.number,originGeneration=d.birth,backendLearnsetRevision=old.backendLearnsetRevision or 1})
    local anim=copy(assert(mod.content.battle_anims:get(d.anim)));anim.source=M.OWNER;mod.content.battle_anims:patch(id,anim)
    for i=#opts.catalog.unsupportedStatus,1,-1 do if opts.catalog.unsupportedStatus[i]==id then table.remove(opts.catalog.unsupportedStatus,i)end end
  end
  mod.content.move_effects:patch('HEAL_EFFECT',{kascTypeChanges67=M.OWNER})
  function M.position(p,id)local a=p.data and p.data.moveAnims and p.data.moveAnims[id]
    if not defs[id]or not a or a.source~=M.OWNER then return end
    for _,step in ipairs(p.steps or{})do for _,s in ipairs(step.sprites or{})do if s.x>0 and s.x<168 and s.y>0 and s.y<160 and mod.exports.pokemonPartnerHits67.inHud(s)then s.x=0 end end end
  end
  function M.install()
    B._kascTypeChanges67=M;Player._kascTypeChanges67=M
    if not B._kascTypeChangesWrapped67 then local perform=B.performMove
      B.performMove=function(...)return B._kascTypeChanges67.perform(perform,...)end;B._kascTypeChangesWrapped67=true end
    if not Player._kascTypeChangesWrapped67 then local start=Player.start
      Player.start=function(self,id,...)local out=pack(start(self,id,...));Player._kascTypeChanges67.position(self,id);return unpack(out,1,out.n)end;Player._kascTypeChangesWrapped67=true end
  end
  mod.events:on('battle.started',M.entered,8001);mod.events:on('battle.battler_switched',M.entered,8001)
  mod.events:on('battle.turn_ended',function(ev)local r=rows(ev.battle);if r then r.electrify={}end end,8001)
  mod.events:on('battle.ended',function(ev)if rows(ev.battle)then ev.battle.field.tokens[M.OWNER]=nil end end,8001)
  M.install()
  if opts.supportLog and opts.supportLog.registerSegment then opts.supportLog.registerSegment({segmentId=M.CARD_ID,cardId=M.CARD_ID,
    schema='kasc.optional-feature-card/v1',version='1.0.0',owner=M.OWNER,active=true,dependencyStatus='native-curTypes-and-final-type-projection',
    providerStatus='seven-source-era-type-changing-moves',buildReceiptId='docs/TYPE_CHANGES_67.md',rollbackReceiptId='docs/TYPE_CHANGES_67.md'})end
  return M
end
