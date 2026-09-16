-- Qualification belongs to actual native declarations/consumption, not to
-- writable mon flags, a caller's slot, or public Runtime announcements.
return function(mod,opts)
  local B=require('src.battle.BattleState');local FX=require('src.battle.EffectRegistry')
  local Player=require('src.battle.AnimPlayer');local A=assert(opts.abilities)
  local M={CARD_ID='KASC-67-CONDITIONAL-USE',OWNER='kasc.conditional-use/v1'}
  local tr=opts.i18n.text;local aliases={}
  for name in pairs(opts.facts.data.moves)do for _,native in ipairs(opts.species.moveIds(name))do aliases[native]=name end end
  local defs={BELCH={number=562,birth=6,type='POISON',category='special',pp=10,accuracy=90,power=120,part='SLUDGE'},
    SYNCHRONOISE={number=485,birth=5,type='PSYCHIC_TYPE',category='special',pp=10,accuracy=100,power=120,part='PSYBEAM'},
    LAST_RESORT={number=387,birth=4,type='NORMAL',category='physical',pp=5,accuracy=100,power=140,part='DOUBLE_EDGE'}}
  local frames=setmetatable({},{__mode='k'});local eatFrames=setmetatable({},{__mode='k'})
  local flingFrames=setmetatable({},{__mode='k'});local lists=setmetatable({},{__mode='k'})
  local function copy(v)if type(v)~='table'then return v end;local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r end
  local function pack(...)return{n=select('#',...),...}end
  local function int(v,a,z)return type(v)=='number'and v%1==0 and v>=a and v<=z end
  local function name(m)return m and(aliases[m.id]or m.id)end
  local function side(b,w)return b and w and w.mon and b.player and b.enemy
    and(w.mon==b.player.mon and'player'or w.mon==b.enemy.mon and'enemy')end
  local function party(b,lane)return lane=='player'and b:playerPartyView()or b.enemyParty or{b.enemy.mon}end
  local function index(b,w)local lane=side(b,w);if not lane then return end
    for i,p in ipairs(party(b,lane)or{})do if i<=6 and p==w.mon then return i end end end
  local function live(w)local p=w and w.mon;return p and int(p.hp,1,999999)and not w.fainted
    and not(p.egg or p.isEgg or p.is_egg or p.eggSpecies or p.species=='EGG')end
  local function mode(b)local r=b and b.kascGenerationRulesReceipt
    if getmetatable(b)~=B or b.demo or b.kind=='link'or b.result or type(r)~='table'
      or not int(r.activeEpoch,1,7)or not(r.mode=='auto'or r.mode=='gen'..r.activeEpoch)then return end
    local heal=b.data and b.data.move_effects and b.data.move_effects.HEAL_EFFECT
    if not heal or heal.kascConditionalUse67~=M.OWNER then return end;return r.activeEpoch end
  function M.epoch(b,u,move)
    local gen=mode(b);if not move then return gen end
    local d=defs[name(move)];local e=gen and d and b.data.move_effects[move.effect]
    if not gen or not d or move.backendMoveOwner~=M.OWNER or move.backendMoveNumber~=d.number
      or not e or e.kascConditionalUse67~=M.OWNER then return end
    if gen<d.birth and not(live(u)and index(b,u)and opts.rules.monMoveAvailable
      and opts.rules.monMoveAvailable(b.game,u.mon,move.id,gen,true))then return end
    return math.max(gen,d.birth)
  end
  function M.project(b,u,move)
    local gen=M.epoch(b,u,move);if not gen then return move end
    local fact=assert(opts.facts.move(name(move),gen))
    if move.power==fact.power and move.pp==fact.pp and move.accuracy==fact.accuracy
      and move.category==fact.category then return move end
    local out=copy(move);out.power=fact.power;out.pp=fact.pp
    out.accuracy=fact.accuracy;out.category=fact.category
    -- The effective ability/item type is independently owned; the immutable
    -- source projection never refills or replaces the saved learned slot.
    return out
  end
  function M.move(nextMove,b,inst,...)
    local move=nextMove(b,inst,...);if not move or not defs[name(move)]then return move end
    for _,w in ipairs({b.player,b.enemy})do for _,slot in ipairs(w and w.curMoves or{})do
      if slot==inst then return M.project(b,w,move)end
    end end;return move
  end
  local function state(b,create)local tokens=b and b.field and b.field.tokens
    if not tokens then return end;local s=tokens[M.OWNER]
    if not s and create then s={ate={},used={}};tokens[M.OWNER]=s end;return s end
  local function berry(b,id)local d=type(id)=='string'and b.data.items[id]
    return d and d.kascConsumableBerry67==true and(d.kascModernBerryOwner or d.kascEquipmentOwner)and d or nil end
  local function ateKey(lane,i)return lane..':'..i end
  local function recordEating(b,w,id,kind)
    local gen=mode(b);local lane=side(b,w);local i=index(b,w)
    if not gen or not lane or not i or w~=b[lane]or not berry(b,id)or not live(w)then return end
    state(b,true).ate[ateKey(lane,i)]={species=w.mon.species,item=id,profile=gen,kind=kind,turn=b.turnCount or 0}
  end
  local function validAte(b,key,r,profile)
    local lane,i;if type(key)=='string'then lane,i=key:match('^(%a+):([1-6])$')end
    local mons=(lane=='player'or lane=='enemy')and party(b,lane);local p=mons and mons[tonumber(i)]
    if type(r)~='table'or not p or p.species~=r.species or r.profile~=(profile or mode(b))or not berry(b,r.item)
      or not int(r.turn,0,b.turnCount or 0)or(r.kind~='held'and r.kind~='fling')then return false end
    for k in pairs(r)do if k~='species'and k~='item'and k~='profile'and k~='kind'and k~='turn'then return false end end
    return true
  end
  function M.ateBerry(b,w)
    local s=state(b);local lane=side(b,w);local i=index(b,w)
    local key=lane and i and ateKey(lane,i);local r=key and s and s.ate and s.ate[key]
    return r and validAte(b,key,r)or false
  end
  local function listKind(w)return w.curMoves==w.mon.moves and'own'or'transform'end
  local function validUsed(b,lane,r,profile)
    local w=b[lane];local moves=w and w.curMoves
    if type(r)~='table'or not w or r.species~=w.mon.species or r.party~=index(b,w)or r.profile~=(profile or mode(b))
      or r.kind~=listKind(w)or type(r.slots)~='table'or not moves or#r.slots~=#moves or#moves>4 then return false end
    if lists[b]and lists[b][lane]and lists[b][lane]~=moves then return false end
    for k in pairs(r)do if k~='species'and k~='party'and k~='profile'and k~='kind'and k~='slots'then return false end end
    for i,s in ipairs(r.slots)do
      if type(s)~='table'or not moves[i]or s.native~=moves[i].id or not b.data.moves[s.native]or type(s.used)~='boolean'then return false end
      for k in pairs(s)do if k~='native'and k~='used'then return false end end
    end;return true
  end
  local function updateUsed(b,w,at,native)
    local gen=mode(b);local lane=side(b,w);local i=index(b,w)
    if not gen or not lane or not i or not w.curMoves or#w.curMoves>4 then return end
    local s=state(b,true);local old=s.used[lane];local refs=lists[b]or{};lists[b]=refs
    local compatible=old and old.party==i and old.species==w.mon.species and old.profile==gen
      and old.kind==listKind(w)and(refs[lane]==nil or refs[lane]==w.curMoves)
    local r={species=w.mon.species,party=i,profile=gen,kind=listKind(w),slots={}}
    for j,slot in ipairs(w.curMoves)do
      local prev=compatible and old.slots and old.slots[j]
      r.slots[j]={native=slot.id,used=prev and prev.native==slot.id and prev.used==true or false}
    end
    if at and r.slots[at]and r.slots[at].native==native then r.slots[at].used=true end
    refs[lane]=w.curMoves;s.used[lane]=r
  end
  function M.lastResortReady(b,w)
    local moves=w and w.curMoves;if not moves or#moves<2 or#moves>4 then return false end
    local s=state(b);local lane=side(b,w);local r=s and s.used and s.used[lane]
    if not r or not validUsed(b,lane,r)then return false end
    local known=false;for i,slot in ipairs(moves)do
      if name(slot)=='LAST_RESORT'then known=true elseif not r.slots[i].used then return false end
    end;return known
  end
  function M.sharedType(b,u,t)
    if not live(u)or not live(t)then return false end
    -- Psychic is never Scrappy's Normal/Fighting temporary target rewrite.
    -- Current curTypes therefore includes real Transform/type-change owners,
    -- and deliberately excludes the unchanged saved species' original types.
    for _,a in ipairs(u.curTypes or u.def.types or{})do for _,z in ipairs(t.curTypes or t.def.types or{})do
      if a==z and b.data.type_chart.types[a]then return true end
    end end;return false
  end
  function M.noUseful(b,u,t,move)
    if not M.epoch(b,u,move)then return false end
    if not live(u)or not live(t)or u.mon==t.mon or not side(b,u)or not side(b,t)or not index(b,u)or not index(b,t)then return true end
    local id=name(move)
    return id=='BELCH'and not M.ateBerry(b,u)or id=='LAST_RESORT'and not M.lastResortReady(b,u)
      or id=='SYNCHRONOISE'and not M.sharedType(b,u,t)or false
  end
  function M.blocksSelection(b,u,move)
    return name(move)=='BELCH'and M.epoch(b,u,move)~=nil and not M.ateBerry(b,u)or false
  end
  function M.gate(ctx)
    if not M.epoch(ctx.battle,ctx.user,ctx.move)or M.noUseful(ctx.battle,ctx.user,ctx.target,ctx.move)then
      return false,tr('But, it failed!','Doch es schlug fehl!')end;return true
  end
  function M.damage(nextDamage,ctx)
    if not ctx or ctx.opts and(ctx.opts.typeless or ctx.opts.typelessDamage)then return nextDamage(ctx)end
    if ctx and ctx.move and M.epoch(ctx.battle,ctx.user,ctx.move)
      and M.noUseful(ctx.battle,ctx.user,ctx.target,ctx.move)then return 0,{crit=false,typeMult=10,missed=true}end
    local move=ctx.move and M.project(ctx.battle,ctx.user,ctx.move)
    if move==ctx.move then return nextDamage(ctx)end
    local out={};for k,v in pairs(ctx)do out[k]=v end;out.move=move
    return nextDamage(out)
  end
  local function same(a,b)return a and b and a.id==b.id and a.effect==b.effect
    and a.backendMoveOwner==b.backendMoveOwner and a.backendMoveNumber==b.backendMoveNumber end
  function M.used(ev)local f=ev and frames[ev.battle]
    if f and f.user==ev.user and f.target==ev.target and same(f.move,ev.move)and ev.isCalled==f.called then f.declared=true end end
  function M.context(nextCtx,b,u,t,...)
    local ctx=nextCtx(b,u,t,...);local f=frames[b]
    if f and f.declared and f.user==u and f.target==t and same(f.move,ctx.move)then f.reached=true end;return ctx
  end
  function M.perform(nextMove,b,u,t,inst,called,...)
    local lane=side(b,u)
    if not mode(b)or not live(u)or not lane or u~=b[lane]or not index(b,u)or not inst then return nextMove(b,u,t,inst,called,...)end
    local move=b:moveDef(inst);if not move then return nextMove(b,u,t,inst,called,...)end
    -- Belch is disabled before selection/AP expenditure; it cannot become a
    -- legal forced use merely because a synthetic performer bypassed a menu.
    if M.blocksSelection(b,u,move)then b:sayNext(tr('A Berry must be eaten first!','Zuerst muss eine Beere gegessen werden!'));return end
    updateUsed(b,u)
    local at;if not called then for i,s in ipairs(u.curMoves)do if s==inst then at=i;break end end end
    local previous=frames[b];local f={user=u,target=t,move=move,called=called or false,at=at,native=inst.id}
    frames[b]=f;local out=pack(pcall(nextMove,b,u,t,inst,called,...));frames[b]=previous
    if not out[1]then error(out[2],0)end
    if f.declared and f.reached then updateUsed(b,u,f.at,f.native)end
    return unpack(out,2,out.n)
  end
  function M.berryApply(nextApply,owner,...)
    local args=pack(...);local b=args[1]
    if not mode(b)then return nextApply(unpack(args,1,args.n))end
    local scope={};for _,w in ipairs({b.player,b.enemy})do
      local held=opts.held(w.mon);if held and berry(b,held)then scope[w]={mon=w.mon,item=held}end
    end
    local prior=eatFrames[b];eatFrames[b]=scope;local out=pack(pcall(nextApply,unpack(args,1,args.n)));eatFrames[b]=prior
    if not out[1]then error(out[2],0)end;return unpack(out,2,out.n)
  end
  function M.onBerry(nextBerry,b,w,id,...)
    local r=eatFrames[b]and eatFrames[b][w]
    if r and r.mon==w.mon and r.item==id and not opts.held(w.mon)then recordEating(b,w,id,'held')end
    return nextBerry(b,w,id,...)
  end
  function M.afterProjectile(nextAfter,ctx,...)
    local b=ctx and ctx.battle;if not mode(b)then return nextAfter(ctx,...)end
    local prior=flingFrames[b];flingFrames[b]=ctx;local out=pack(pcall(nextAfter,ctx,...));flingFrames[b]=prior
    if not out[1]then error(out[2],0)end;return unpack(out,2,out.n)
  end
  function M.forcedBerry(nextEat,ctx,spec,...)
    local genuine=ctx and flingFrames[ctx.battle]==ctx and name(ctx.move)=='FLING'and spec and spec.berry
    local out=pack(nextEat(ctx,spec,...));if genuine and out[1]==true then recordEating(ctx.battle,ctx.target,spec.item,'fling')end
    return unpack(out,1,out.n)
  end
  function M.switched(ev)
    local b,w=ev and ev.battle,ev and ev.battler;local lane=side(b,w);local s=state(b)
    if lane and s and ev.previous and ev.previous~=w and ev.previous.mon~=w.mon then
      s.used[lane]=nil;if lists[b]then lists[b][lane]=nil end
    end
  end
  function M.validateCheckpoint(b)
    if frames[b]or eatFrames[b]or flingFrames[b]then return false,'conditional_use_unsettled'end
    local s=state(b);if s==nil then return true end
    -- Checkpoint validators precede frozen receipt reattachment. The parent
    -- generation owner separately validates its immutable schema/data hash.
    local frozen=b.field.tokens['kasc.generation-receipt/v1'];local gen=mode(b)
    if not gen and type(frozen)=='table'and int(frozen.activeEpoch,1,7)
      and(frozen.mode=='auto'or frozen.mode=='gen'..frozen.activeEpoch)then gen=frozen.activeEpoch end
    if not gen or type(s)~='table'or type(s.ate)~='table'or type(s.used)~='table'then return false,'invalid_conditional_use'end
    for k in pairs(s)do if k~='ate'and k~='used'then return false,'unknown_conditional_use_field'end end
    for k,r in pairs(s.ate)do if not validAte(b,k,r,gen)then return false,'invalid_eaten_berry'end end
    for k,r in pairs(s.used)do if(k~='player'and k~='enemy')or not validUsed(b,k,r,gen)then return false,'invalid_used_move_slots'end end
    return true
  end
  function M.resume(b)
    local ok,err=M.validateCheckpoint(b);assert(ok,err);local s=state(b);local r={};lists[b]=r
    if s then for lane in pairs(s.used)do r[lane]=b[lane].curMoves end end;return true
  end
  for _,id in ipairs({'BELCH','SYNCHRONOISE','LAST_RESORT'})do
    local d=defs[id];local fact=assert(opts.facts.move(id,7));local old=assert(mod.content.moves:get(id))
    assert(fact.number==d.number and fact.generation==d.birth and fact.pp==d.pp and fact.power==d.power
      and fact.accuracy==d.accuracy and fact.category==d.category and fact.type==d.type and fact.priority==0,'conditional-use source drift '..id)
    assert(not old.backendMoveOwner and old.effect=='NO_ADDITIONAL_EFFECT','foreign conditional-use owner '..id)
    local effect='KA_CONDITIONAL_USE_67_'..id
    mod.content.move_effects:register(effect,{kind='full',gate=M.gate,kascConditionalUse67=M.OWNER})
    local flags=id=='BELCH'and{protect=1,failmefirst=1,nosleeptalk=1,noassist=1,failcopycat=1,failmimic=1,failinstruct=1}
      or id=='LAST_RESORT'and{protect=1,contact=1,mirror=1,metronome=1}or{protect=1,mirror=1,metronome=1}
    for _,native in ipairs(opts.species.moveIds(id))do if mod.content.moves:get(native)then
      mod.content.moves:patch(native,{effect=effect,flags=flags,backendMoveOwner=M.OWNER,backendMoveNumber=d.number,
        originGeneration=d.birth,backendLearnsetRevision=old.backendLearnsetRevision or 1})end end
    local animation=copy(assert(mod.content.battle_anims:get(d.part),'missing established native animation '..d.part))
    animation.source=M.OWNER;mod.content.battle_anims:patch(id,animation)
  end
  mod.content.move_effects:patch('HEAL_EFFECT',{kascConditionalUse67=M.OWNER})
  function M.position(p,id)
    if not defs[id]or not p.data.moveAnims[id]or p.data.moveAnims[id].source~=M.OWNER then return end
    local hud=assert(mod.exports.pokemonPartnerHits67)
    for _,step in ipairs(p.steps or{})do for i,s in ipairs(step.sprites or{})do local q=copy(s)
      if q.x>0 and q.x<168 and q.y>0 and q.y<160 and(q.y<16 or hud.inHud(q))then q.x=0 end;step.sprites[i]=q end end
  end
  function M.install()
    B._kascConditionalUse67=M;FX._kascConditionalUse67=M;Player._kascConditionalUse67=M
    if not B._kascConditionalUseWrapped67 then local old=B.performMove
      B.performMove=function(...)return B._kascConditionalUse67.perform(old,...)end;B._kascConditionalUseWrapped67=true end
    if not B._kascConditionalUseMoveWrapped67 then local old=B.moveDef
      B.moveDef=function(...)return B._kascConditionalUse67.move(old,...)end;B._kascConditionalUseMoveWrapped67=true end
    if not FX._kascConditionalUseWrapped67 then local old=FX.makeCtx
      FX.makeCtx=function(...)return FX._kascConditionalUse67.context(old,...)end;FX._kascConditionalUseWrapped67=true end
    if not Player._kascConditionalUseWrapped67 then local old=Player.start
      Player.start=function(self,id,...)local out=pack(old(self,id,...));Player._kascConditionalUse67.position(self,id);return unpack(out,1,out.n)end
      Player._kascConditionalUseWrapped67=true end
    A._kascConditionalUse67=M
    if not A._kascConditionalUseWrapped67 then local old=A.onBerry
      A.onBerry=function(...)return A._kascConditionalUse67.onBerry(old,...)end;A._kascConditionalUseWrapped67=true end
    for _,key in ipairs({'pokemonEquipmentEffects67','pokemonModernBerries67'})do local owner=mod.exports[key]
      assert(owner and type(owner.apply)=='function','conditional-use needs native berry owner '..key)
      owner._kascConditionalUse67=M
      if not owner._kascConditionalUseWrapped67 then local old=owner.apply
        owner.apply=function(...)return owner._kascConditionalUse67.berryApply(old,owner,...)end;owner._kascConditionalUseWrapped67=true end
    end
    local projectiles=assert(mod.exports.pokemonHeldProjectiles67,'conditional-use needs native projectile owner')
    projectiles._kascConditionalUse67=M
    if not projectiles._kascConditionalUseWrapped67 then local after,eat=projectiles.afterDamage,projectiles.forcedBerry
      local effect='KA_HELD_PROJECTILE_67_FLING';local row=assert(mod.content.move_effects:get(effect))
      assert(row.kascHeldProjectile67==projectiles.OWNER and row.afterDamage==after,'foreign Fling Eat observer')
      projectiles.afterDamage=function(...)return projectiles._kascConditionalUse67.afterProjectile(after,...)end
      projectiles.forcedBerry=function(...)return projectiles._kascConditionalUse67.forcedBerry(eat,...)end
      -- Its registered callback captured the old function, not M.afterDamage.
      -- Dispatch the SAME original owned effect through its export so the
      -- observer scope surrounds only a genuinely validated forced Eat.
      mod.content.move_effects:patch(effect,{afterDamage=function(...)return projectiles.afterDamage(...)end,
        kascConditionalEatObserver67=M.OWNER})
      projectiles._kascConditionalUseWrapped67=true end
  end
  mod.hooks:wrap('battle.damage',M.damage,31542)
  mod.events:on('battle.move_used',M.used,32002);mod.events:on('battle.battler_switched',M.switched,32002);M.install()
  if opts.supportLog and opts.supportLog.registerSegment then opts.supportLog.registerSegment({segmentId=M.CARD_ID,cardId=M.CARD_ID,
    schema='kasc.optional-feature-card/v1',version='1.0.0',owner=M.OWNER,active=true,
    dependencyStatus='native-consumption-and-own-slot-declaration',providerStatus='three-source-bound-use-gates',
    buildReceiptId='docs/CONDITIONAL_USE_67.md',rollbackReceiptId='docs/CONDITIONAL_USE_67.md'})end
  return M
end
