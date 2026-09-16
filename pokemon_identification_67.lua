-- Identification belongs to the actual current battler, not its saved type.
return function(mod,opts)
  local B=require('src.battle.BattleState');local FX=require('src.battle.EffectRegistry')
  local Chart=require('src.battle.TypeChart');local Player=require('src.battle.AnimPlayer')
  local M={CARD_ID='KASC-67-IDENTIFICATION',OWNER='kasc.identification/v1'}
  local defs={ODOR_SLEUTH={number=316,birth=3,kind='foresight'},MIRACLE_EYE={number=357,birth=4,kind='miracleeye'}}
  local frames=setmetatable({},{__mode='k'});local queries={};local aliases={}
  for id in pairs(defs)do for _,native in ipairs(opts.species.moveIds(id))do aliases[native]=id end end
  local function shallow(v)local r={};for k,x in pairs(v or{})do r[k]=x end;return r end
  local function copy(v)if type(v)~='table'then return v end;local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r end
  local function pack(...)return{n=select('#',...),...}end
  local function int(v,a,z)return type(v)=='number'and v%1==0 and v>=a and v<=z end
  local function side(b,w)return b and(w==b.player and'player'or w==b.enemy and'enemy')end
  local function index(b,w)local lane=side(b,w);local ps=lane=='player'and b:playerPartyView()or lane=='enemy'and(b.enemyParty or{w.mon})
    for i,p in ipairs(ps or{})do if i<=6 and p==w.mon then return i end end end
  local function live(w)local p=w and w.mon;return p and int(p.hp,1,999999)and not w.fainted
    and not(p.egg or p.isEgg or p.is_egg or p.eggSpecies or p.species=='EGG')end
  local function seal(h)local out=copy(h);out.proof=nil;return opts.rules.receipts.hash(M.OWNER..':'..opts.rules.receipts.canonical(out))end
  local function state(b,create)local t=b and b.field and b.field.tokens;if not t then return end
    if create and not t[M.OWNER]then t[M.OWNER]={}end;return t[M.OWNER]end
  function M.epoch(b,u,move)
    local r=b and b.kascGenerationRulesReceipt;local h=b and b.data and b.data.move_effects and b.data.move_effects.HEAL_EFFECT
    if getmetatable(b)~=B or b.demo or b.kind=='link'or b.result or not r or not int(r.activeEpoch,1,7)
      or not(r.mode=='auto'or r.mode=='gen'..r.activeEpoch)or not h or h.kascIdentification67~=M.OWNER then return end
    if not move then return r.activeEpoch end
    local id=aliases[move.id];local d=id and defs[id];local e=d and b.data.move_effects[move.effect]
    if not d or move.backendMoveOwner~=M.OWNER or move.backendMoveNumber~=d.number or not e or e.kascIdentification67~=M.OWNER
      or not live(u)or not index(b,u)then return end
    if r.activeEpoch<d.birth and not opts.rules.monMoveAvailable(b.game,u.mon,move.id,r.activeEpoch,true)then return end
    return math.max(d.birth,r.activeEpoch),id
  end
  local function valid(b,lane,h,gen)
    local w=b[lane]
    return type(h)=='table'and w and h.species==w.mon.species and h.party==index(b,w)and h.profile==gen
      and(h.kind=='foresight'or h.kind=='miracleeye')and h.epoch==math.max(gen,h.kind=='foresight'and 3 or 4)
      and int(h.turn,0,b.turnCount or 0)and h.proof==seal(h)
  end
  function M.marked(b,w)
    local gen=M.epoch(b);local s=state(b);local lane=side(b,w);local h=s and lane and s[lane]
    return gen and valid(b,lane,h,gen)and h or nil
  end
  function M.noUseful(b,u,t,move)
    if not M.epoch(b,u,move)then return false end
    return not live(t)or not index(b,t)or u==t or t.invulnerable or M.marked(b,t)~=nil or t._kascForesightIdentified==true
  end
  function M.cast(ctx)
    local b,u,t,move=ctx.battle,ctx.user,ctx.target,ctx.move;local gen,id=M.epoch(b,u,move);local f=frames[b]
    local fail={opts.i18n.text('But, it failed!','Doch es schlug fehl!'),failed=true}
    if not gen or not f or f.user~=u or f.target~=t or f.slot~=ctx.moveInst or f.id~=id or M.noUseful(b,u,t,move)then return fail end
    local protect=mod.exports.pokemonProtection67;local priority=mod.exports.pokemonPriorityAbilities67
    if protect.blocks(ctx)then return{protect.notice(ctx,true),failed=true}end
    if priority.blocks(ctx)then return fail end
    -- III Odor Sleuth has numeric accuracy 100; IV+ is always accurate.
    -- Neither is a type-immunity test. bypasssub reaches the real owner.
    if id=='ODOR_SLEUTH'and gen==3 and not ctx.accuracyRoll()then return fail end
    local h={species=t.mon.species,party=index(b,t),profile=M.epoch(b),epoch=gen,kind=defs[id].kind,turn=b.turnCount or 0}
    h.proof=seal(h);state(b,true)[side(b,t)]=h
    return{opts.i18n.text('%s was identified!','%s wurde identifiziert!'):format(t.name)}
  end
  function M.perform(original,b,u,t,slot,...)
    local move=slot and b:moveDef(slot);local gen,id=M.epoch(b,u,move)
    if not gen then return original(b,u,t,slot,...)end
    local old=frames[b];frames[b]={user=u,target=t,slot=slot,id=id}
    local out=pack(pcall(original,b,u,t,slot,...));frames[b]=old
    if not out[1]then error(out[2],0)end;return unpack(out,2,out.n)
  end
  function M.accuracy(nextAccuracy,ctx)
    local h=ctx and M.marked(ctx.battle,ctx.target);if not h then return nextAccuracy(ctx)end
    local eva=ctx.target.stages and ctx.target.stages.evasion or 0
    local acc=ctx.user.stages and ctx.user.stages.accuracy or 0
    if h.epoch<=3 and eva<acc or h.epoch>=4 and eva<=0 then return nextAccuracy(ctx)end
    local out=shallow(ctx);out.target=shallow(ctx.target);out.target.stages=shallow(ctx.target.stages)
    out.target.stages.evasion=0
    if h.epoch<=3 then out.user=shallow(ctx.user);out.user.stages=shallow(ctx.user.stages);out.user.stages.accuracy=0 end
    return nextAccuracy(out)
  end
  function M.scope(b,u,t,m,fn)
    local h=M.marked(b,t)
    queries[#queries+1]=h and live(u)and index(b,u)and{b=b,u=u,t=t,m=m,h=h}or false
    local out=pack(pcall(fn));queries[#queries]=nil
    if not out[1]then error(out[2],0)end;return unpack(out,2,out.n)
  end
  function M.filtered(kind,types)
    local f=queries[#queries];if not f or kind~=f.m.type or type(types)~='table'then return end
    local excluded=f.h.kind=='foresight'and(kind=='NORMAL'or kind=='FIGHTING')and'GHOST'
      or f.h.kind=='miracleeye'and kind=='PSYCHIC_TYPE'and'DARK'
    if not excluded then return end
    local current=f.t.curTypes or{};if#types~=#current then return end
    for i,t in ipairs(types)do if t~=current[i]then return end end
    local out={};for _,t in ipairs(types)do if t~=excluded then out[#out+1]=t end end;return out
  end
  function M.damage(nextDamage,ctx)
    if not ctx or ctx.opts and ctx.opts.typeless then return nextDamage(ctx)end
    return M.scope(ctx.battle,ctx.user,ctx.target,ctx.move,function()return nextDamage(ctx)end)
  end
  function M.validateCheckpoint(b)
    if frames[b]then return false,'identification_in_flight'end
    local s=state(b);if s==nil then return true end;if type(s)~='table'then return false,'invalid_identification_container'end
    local saved=b.field.tokens['kasc.generation-receipt/v1'];local gen=saved and saved.mode~='off'and saved.activeEpoch or M.epoch(b)
    if not int(gen,1,7)then return false,'invalid_identification_epoch'end
    for lane,h in pairs(s)do
      if(lane~='player'and lane~='enemy')or not valid(b,lane,h,gen)then return false,'invalid_identification_row'end
      for k in pairs(h)do if k~='species'and k~='party'and k~='profile'and k~='epoch'and k~='kind'and k~='turn'and k~='proof'then return false,'unknown_identification_field'end end
    end;return true
  end
  function M.clear(ev)local b=ev.battle;local s=state(b);if not s then return end
    if not ev.previous then b.field.tokens[M.OWNER]=nil else s[ev.previous.isPlayer and'player'or'enemy']=nil end end
  function M.install()
    B._kascIdentification67=M;FX._kascIdentification67=M;Chart._kascIdentification67=M;Player._kascIdentification67=M
    if not B._kascIdentificationWrapped67 then local old=B.performMove
      B.performMove=function(...)return B._kascIdentification67.perform(old,...)end;B._kascIdentificationWrapped67=true end
    if not FX._kascIdentificationWrapped67 then local old=FX.runDamaging
      FX.runDamaging=function(b,ctx,record)return FX._kascIdentification67.scope(b,ctx.user,ctx.target,ctx.move,function()return old(b,ctx,record)end)end
      FX._kascIdentificationWrapped67=true end
    if not Chart._kascIdentificationWrapped67 then local rows,mult=Chart.rows,Chart.effectiveness
      Chart.rows=function(kind,types,...)return rows(kind,Chart._kascIdentification67.filtered(kind,types)or types,...)end
      Chart.effectiveness=function(kind,types,...)return mult(kind,Chart._kascIdentification67.filtered(kind,types)or types,...)end
      Chart._kascIdentificationWrapped67=true end
    if not Player._kascIdentificationWrapped67 then local old=Player.start
      Player.start=function(self,id,...)local out=pack(old(self,id,...));local row=self.data.moveAnims[id]
        if row and row.source==M.OWNER then for _,step in ipairs(self.steps or{})do for _,s in ipairs(step.sprites or{})do
          if s.y<16 or mod.exports.pokemonPartnerHits67.inHud(s)then s.x=0 end end end end;return unpack(out,1,out.n)end
      Player._kascIdentificationWrapped67=true end
  end
  for id,d in pairs(defs)do local fact=assert(opts.facts.move(id,7));local old=assert(mod.content.moves:get(id))
    assert(fact.number==d.number and fact.generation==d.birth and fact.pp==40 and fact.alwaysHits and not old.backendMoveOwner,'identification source/owner drift '..id)
    local effect='KA_IDENTIFICATION_67_'..id
    mod.content.move_effects:register(effect,{kind='primary',accuracyChecked=false,run=M.cast,kascIdentification67=M.OWNER})
    mod.content.moves:patch(id,{effect=effect,backendMoveOwner=M.OWNER,backendMoveNumber=d.number,originGeneration=d.birth,
      backendLearnsetRevision=old.backendLearnsetRevision or 1,flags={protect=1,reflectable=1,mirror=1,bypasssub=1,metronome=1}})
    local anim=copy(assert(mod.content.battle_anims:get('FORESIGHT')));anim.source=M.OWNER;mod.content.battle_anims:patch(id,anim)
    for i=#opts.moves.unsupportedStatus,1,-1 do if opts.moves.unsupportedStatus[i]==id then table.remove(opts.moves.unsupportedStatus,i)end end
  end
  mod.content.move_effects:patch('HEAL_EFFECT',{kascIdentification67=M.OWNER})
  mod.hooks:wrap('battle.accuracy',M.accuracy,22005);mod.hooks:wrap('battle.damage',M.damage,30005)
  mod.events:on('battle.battler_switched',M.clear,8000);mod.events:on('battle.ended',M.clear,8000);M.install()
  if opts.supportLog and opts.supportLog.registerSegment then opts.supportLog.registerSegment({segmentId=M.CARD_ID,cardId=M.CARD_ID,
    schema='kasc.optional-feature-card/v1',version='1.0.0',owner=M.OWNER,active=true,dependencyStatus='actual-battler-and-scoped-type-query',
    providerStatus='odor-sleuth-and-miracle-eye',buildReceiptId='docs/IDENTIFICATION_67.md',rollbackReceiptId='docs/IDENTIFICATION_67.md'})end
  return M
end
