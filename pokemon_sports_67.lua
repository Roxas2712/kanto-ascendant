-- Sports are base-power effects, not weather, terrain, or saved Pokemon buffs.
return function(mod,opts)
  local B=require('src.battle.BattleState');local FX=require('src.battle.EffectRegistry')
  local Player=require('src.battle.AnimPlayer')
  local M={OWNER='kasc.sports/v1',CARD_ID='KASC-67-SPORTS'}
  local tr=opts.i18n.text;local defs={
    MUD_SPORT={number=300,type='GROUND',weakens='ELECTRIC',part='SAND_ATTACK'},
    WATER_SPORT={number=346,type='WATER',weakens='FIRE',part='WATER_GUN'}}
  local order={'MUD_SPORT','WATER_SPORT'};local aliases={}
  local frames=setmetatable({},{__mode='k'});local transfers=setmetatable({},{__mode='k'})
  assert(opts.damage.kascSports67==M.OWNER,'Sports require actual shared base-power math')
  for id in pairs(defs)do for _,a in ipairs(opts.species.moveIds(id))do aliases[a]=id end end
  local function copy(v)if type(v)~='table'then return v end;local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r end
  local function pack(...)return{n=select('#',...),...}end
  local function int(v,a,z)return type(v)=='number'and v%1==0 and v>=a and v<=z end
  local function side(b,w)return b and(w==b.player and'player'or w==b.enemy and'enemy')or nil end
  local function party(b,key)return key=='player'and b:playerPartyView()
    or key=='enemy'and(b.enemyParty or{b.enemy and b.enemy.mon})or{}end
  local function index(b,w,key)for i,p in ipairs(party(b,key or side(b,w)))do if i<=6 and p==w.mon then return i end end end
  local function live(w)local p=w and w.mon;return p and int(p.hp,1,999999)and not w.fainted
    and not(p.egg or p.isEgg or p.is_egg or p.eggSpecies or p.species=='EGG')end
  local function rows(b,create)if create then b.field=b.field or{};b.field.tokens=b.field.tokens or{}
    b.field.tokens[M.OWNER]=b.field.tokens[M.OWNER]or{fields={},volatiles={player={},enemy={}}}end
    return b and b.field and b.field.tokens and b.field.tokens[M.OWNER]end
  local function seal(h)local q=copy(h);q.proof=nil
    return opts.rules.receipts.hash(M.OWNER..':'..opts.rules.receipts.canonical(q))end
  function M.epoch(b,u,move)
    local r=b and b.kascGenerationRulesReceipt;local h=b and b.data and b.data.move_effects and b.data.move_effects.HEAL_EFFECT
    if getmetatable(b)~=B or b.demo or b.kind=='link'or b.result or not r or not int(r.activeEpoch,1,7)
      or not(r.mode=='auto'or r.mode=='gen'..r.activeEpoch)or not h or h.kascSports67~=M.OWNER then return end
    if not move then return r.activeEpoch end
    local id=aliases[move.id]or move.id;local d=defs[id];local e=d and b:effectRecord(move.effect)
    if not d or move.backendMoveOwner~=M.OWNER or move.backendMoveNumber~=d.number
      or move.type~=d.type or move.category~='status'or move.power~=0 or move.target~=12
      or not e or e.kascSports67~=M.OWNER or not live(u)or not side(b,u)or not index(b,u)then return end
    if r.activeEpoch<3 and not opts.rules.monMoveAvailable(b.game,u.mon,move.id,r.activeEpoch,true)then return end
    return math.max(3,r.activeEpoch),id
  end
  local function valid(b,id,h,volatile,key,ignoreCurrent)
    local profile=M.epoch(b);local turn=b and(b.turnCount or 0)
    if not profile or not defs[id]or type(h)~='table'or h.profile~=profile or h.epoch~=math.max(3,profile)
      or not int(h.applied,0,turn)or h.source~='player'and h.source~='enemy'or not int(h.party,1,6)
      or h.proof~=seal(h)then return false end
    local p=party(b,h.source)[h.party]
    if not p or p.species~=h.species or p.egg or p.isEgg or p.is_egg or p.eggSpecies then return false end
    if volatile then
      return h.epoch<=5 and h.source==key and(ignoreCurrent or b[key]and b[key].mon==p and live(b[key]))
    end
    return h.epoch>=6 and h.expires==h.applied+4 and turn<=h.expires
  end
  function M.active(b,id,w)
    if not defs[id]or not M.epoch(b)then return end
    local r=rows(b);if type(r)~='table'or type(r.fields)~='table'or type(r.volatiles)~='table'then return end
    local gen=math.max(3,M.epoch(b));local key=side(b,w)
    local h=gen>=6 and r.fields[id]or key and r.volatiles[key]and r.volatiles[key][id]
    if valid(b,id,h,gen<=5,key)then return h end
  end
  -- Fresh detached factors are composed by the real shared power stage.
  -- Original III/IV tests ANY active Sport once, unlike the simulator's
  -- generic per-volatile callbacks. V uses its pinned fixed-point callback.
  -- Reserved Pokemon never contributes a volatile.
  function M.powerModifiers(b,move)
    if not M.epoch(b)or not move or move.category=='status'or(tonumber(move.power)or 0)<=0 then return end
    local id=move.type=='ELECTRIC'and'MUD_SPORT'or move.type=='FIRE'and'WATER_SPORT'
    if not id then return end
    local out={};local gen=math.max(3,M.epoch(b))
    if gen>=6 then if M.active(b,id)then out[1]=1352 end
    else for _,key in ipairs({'player','enemy'})do if M.active(b,id,b[key])then
      out[#out+1]=gen<=4 and 2048 or 1352;if gen<=4 then break end
    end end end
    return #out>0 and out or nil
  end
  function M.damage(nextDamage,ctx)
    if not ctx or ctx.opts and(ctx.opts.typeless or ctx.opts.typelessDamage)then return nextDamage(ctx)end
    local factors=M.powerModifiers(ctx.battle,ctx.move);if not factors then return nextDamage(ctx)end
    if ctx.opts and ctx.opts.kascSports67==M.OWNER then return nextDamage(ctx)end
    local out={};for k,v in pairs(ctx)do out[k]=v end;out.opts=copy(ctx.opts or{})
    out.opts.kascSports67=M.OWNER;out.opts.kascSportsPower67=factors;out.opts.kascSportsEpoch67=M.epoch(ctx.battle)
    -- Native Gen-I Damage has no later power hook. Use the equivalent KASC
    -- calculation ONLY with an authentic active Sport; untouched I still
    -- falls through with precisely its original calculation and RNG draws.
    if M.epoch(ctx.battle)==1 then return opts.damage.compute(ctx.ruleset,ctx.user,ctx.target,ctx.move,out.opts)end
    return nextDamage(out)
  end
  local function failed()return{tr('But, it failed!','Doch es schlug fehl!'),failed=true}end
  function M.noUseful(b,u,t,move)
    local gen,id=M.epoch(b,u,move);if not gen then return false end
    if M.active(b,id,u)then return true end
    if not live(t)or not side(b,t)or not index(b,t)then return true end
    local conversion=mod.exports.pokemonMoveConversion67
    for _,slot in ipairs(t.curMoves or{})do local m=b:moveDef(slot)
      local unlimited=M.epoch(b)==1 and not t.isPlayer and b.ruleset and b.ruleset.enemyUnlimitedPP
      if m and(unlimited or(tonumber(slot.pp)or 0)>0)and m.category~='status'and(tonumber(m.power)or 0)>0 then
        if conversion then m=conversion.project(b,t,m)end
        if m.type==defs[id].weakens then return false end
      end
    end
    return true
  end
  function M.cast(ctx)
    local b,u,m=ctx.battle,ctx.user,ctx.move;local gen,id=M.epoch(b,u,m);local f=frames[b]
    if not gen or not f or f.ctx~=ctx or not f.used or f.user~=u or f.target~=ctx.target
      or f.slot~=ctx.moveInst or f.id~=id or M.active(b,id,u)then return failed()end
    local h={source=side(b,u),species=u.mon.species,party=index(b,u),profile=M.epoch(b),epoch=gen,applied=b.turnCount or 0}
    if gen>=6 then h.expires=h.applied+4 end;h.proof=seal(h)
    local r=rows(b,true);if gen>=6 then r.fields[id]=h else r.volatiles[side(b,u)][id]=h end
    return{tr('%s weakened %s moves!','%s schwächt %s-Attacken!'):format(m.name,
      id=='MUD_SPORT'and tr('Electric','Elektro')or tr('Fire','Feuer'))}
  end
  function M.perform(original,b,u,t,slot,called,...)
    local move=slot and b:moveDef(slot);local gen,id
    if move then gen,id=M.epoch(b,u,move)end
    if not gen then return original(b,u,t,slot,called,...)end
    local prior=frames[b];local f={user=u,target=t,slot=slot,id=id};frames[b]=f
    local out=pack(pcall(original,b,u,t,slot,called,...));frames[b]=prior
    if not out[1]then error(out[2],0)end;return unpack(out,2,out.n)
  end
  function M.used(ev)
    local f=ev and frames[ev.battle]
    if f and ev.user==f.user and ev.target==f.target and(aliases[ev.move.id]or ev.move.id)==f.id
      and M.epoch(ev.battle,ev.user,ev.move)then f.used=true end
  end
  function M.context(b,ctx,u,t,slot)
    local f=frames[b]
    if f and f.used and f.user==u and f.target==t and f.slot==slot and f.id==(aliases[ctx.move.id]or ctx.move.id)
      and M.epoch(b,u,ctx.move)then f.ctx=ctx end
    return ctx
  end
  function M.switch(ev)
    local b=ev and ev.battle;local r=rows(b);local key=side(b,ev and ev.battler)
    if r and type(r.volatiles)=='table'and key then r.volatiles[key]={}end
  end
  function M.endTurn(ev)
    local b=ev and ev.battle;local r=rows(b);if not r or not M.epoch(b)or not M.validateCheckpoint(b)then return end
    for _,id in ipairs({'WATER_SPORT','MUD_SPORT'})do local h=r.fields[id]
      if h and(b.turnCount or 0)>=h.expires then r.fields[id]=nil
        local m=b.data.moves[id];b:sayNext(tr('%s wore off!','%s lässt nach!'):format(m.name))end
    end
    for _,key in ipairs({'player','enemy'})do if not live(b[key])then r.volatiles[key]={}end end
  end
  -- Explicit Baton callback only: ordinary swaps clear early volatiles.
  -- III/IV are passable; V noCopy and VI+ global fields are NOT copied.
  function M.prepareTransfer(b,old,new)
    local profile=M.epoch(b);local key=side(b,new);local r=rows(b)
    if not profile or math.max(profile,3)>4 or not key or not live(old)or not live(new)or not index(b,new)
      or not r or type(r.volatiles)~='table'or type(r.volatiles[key])~='table'then return end
    local saved={}
    for _,id in ipairs(order)do local h=r.volatiles[key][id]
      if valid(b,id,h,true,key,true)and h.species==old.mon.species and party(b,key)[h.party]==old.mon then
        h=copy(h);h.species=new.mon.species;h.party=index(b,new);h.proof=seal(h);saved[id]=h
      end
    end
    if next(saved)then transfers[b]={previous=old,battler=new,key=key,rows=saved}end
  end
  function M.restoreTransfer(ev)
    local b=ev and ev.battle;local h=b and transfers[b]
    if h and ev.sourceCard=='KASC-67-BATON-PASS'and ev.previous==h.previous and ev.battler==h.battler
      and b[h.key]==h.battler then rows(b,true).volatiles[h.key]=h.rows;transfers[b]=nil end
  end
  function M.validateCheckpoint(b)
    if frames[b]or transfers[b]then return false,'sports_unsettled'end
    local r=rows(b);if r==nil then return true end
    if not M.epoch(b)or type(r)~='table'or type(r.fields)~='table'or type(r.volatiles)~='table'
      or type(r.volatiles.player)~='table'or type(r.volatiles.enemy)~='table'then return false,'invalid_sports_container'end
    for k in pairs(r)do if k~='fields'and k~='volatiles'then return false,'unknown_sports_container_field'end end
    for k in pairs(r.volatiles)do if k~='player'and k~='enemy'then return false,'invalid_sports_side'end end
    local fields={source=true,species=true,party=true,profile=true,epoch=true,applied=true,proof=true}
    local function list(list,volatile,key)
      for id,h in pairs(list)do if not valid(b,id,h,volatile,key)then return false,'invalid_sports_identity'end
        for k in pairs(h)do if not fields[k]and not(k=='expires'and not volatile)then return false,'unknown_sports_record_field'end end
      end;return true
    end
    local ok,why=list(r.fields,false);if not ok then return ok,why end
    for _,key in ipairs({'player','enemy'})do ok,why=list(r.volatiles[key],true,key);if not ok then return ok,why end end
    return true
  end
  function M.install()
    B._kascSports67=M;FX._kascSports67=M;Player._kascSports67=M
    if not B._kascSportsWrapped67 then local original=B.performMove
      B.performMove=function(...)return B._kascSports67.perform(original,...)end;B._kascSportsWrapped67=true end
    if not FX._kascSportsWrapped67 then local original=FX.makeCtx
      FX.makeCtx=function(b,u,t,move,slot,...)
        return FX._kascSports67.context(b,original(b,u,t,move,slot,...),u,t,slot)
      end;FX._kascSportsWrapped67=true
    end
    if not Player._kascSportsWrapped67 then local original=Player.start
      Player.start=function(self,id,...)
        local out=pack(original(self,id,...));Player._kascSports67.position(self,id);return unpack(out,1,out.n)
      end;Player._kascSportsWrapped67=true
    end
  end
  function M.position(player,id)
    local r=player.data and player.data.moveAnims and player.data.moveAnims[id]
    if not defs[id]or not r or r.source~=M.OWNER then return end
    for _,step in ipairs(player.steps or{})do local sprites={}
      for i,s in ipairs(step.sprites or{})do local q=copy(s)
        if q.x>0 and q.x<168 and q.y>0 and q.y<160
          and(q.y<16 or mod.exports.pokemonPartnerHits67.inHud(q))then q.x=0 end
        sprites[i]=q
      end;step.sprites=sprites
    end
  end
  for _,id in ipairs(order)do local d=defs[id];local f=assert(opts.facts.move(id,3));local old=assert(mod.content.moves:get(id))
    assert(f.number==d.number and f.generation==3 and f.category=='status'and f.power==0 and f.pp==15
      and f.alwaysHits and f.priority==0 and f.target==12 and f.type==d.type,'Sports source drift '..id)
    assert(not old.backendMoveOwner and old.effect=='KA_GEN_MOVE_UNSUPPORTED_'..id,'foreign Sports owner '..id)
    local part
    for _,a in ipairs(opts.species.moveIds(d.part))do if mod.content.moves:get(a)and mod.content.battle_anims:get(a)then part=a;break end end
    assert(part,'missing native Sports animation '..d.part)
    local effect='KA_SPORTS_67_'..id
    mod.content.move_effects:register(effect,{kind='primary',accuracyChecked=false,kascSports67=M.OWNER,run=M.cast})
    mod.content.moves:patch(id,{name=tr(f.names.en,f.names.de),effect=effect,backendMoveOwner=M.OWNER,backendMoveNumber=d.number,
      originGeneration=3,backendLearnsetRevision=old.backendLearnsetRevision or 1,category='status',power=0,type=d.type,
      pp=15,target=12,priority=0,accuracy=100,contact=false,flags={nonsky=1,metronome=1},
      anim=copy(mod.content.moves:get(part).anim)})
    local anim=copy(mod.content.battle_anims:get(part));anim.source=M.OWNER;mod.content.battle_anims:patch(id,anim)
    for i=#opts.catalog.unsupportedStatus,1,-1 do if opts.catalog.unsupportedStatus[i]==id then table.remove(opts.catalog.unsupportedStatus,i)end end
  end
  mod.content.move_effects:patch('HEAL_EFFECT',{kascSports67=M.OWNER})
  M.install();mod.hooks:wrap('battle.damage',M.damage,-7101)
  mod.events:on('battle.move_used',M.used,100210)
  mod.events:on('battle.battler_switched',M.switch,8000)
  mod.events:on('battle.battler_switched',M.restoreTransfer,7999)
  mod.events:on('battle.fainted',M.switch,8000)
  mod.events:on('battle.turn_ended',M.endTurn,-27000)
  mod.events:on('battle.ended',function(ev)if rows(ev.battle)then ev.battle.field.tokens[M.OWNER]=nil end
    frames[ev.battle]=nil;transfers[ev.battle]=nil end,-27000)
  if opts.supportLog and opts.supportLog.registerSegment then opts.supportLog.registerSegment({
    segmentId=M.CARD_ID,cardId=M.CARD_ID,schema='kasc.optional-feature-card/v1',version='1.0.0',owner=M.OWNER,active=true,
    dependencyStatus='native-perform-ctx-power-phase-baton-entry-checkpoint',providerStatus='historical-mud-water-sport',
    buildReceiptId='docs/SPORTS_67.md',rollbackReceiptId='docs/SPORTS_67.md'})end
  return M
end
