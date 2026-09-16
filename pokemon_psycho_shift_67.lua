-- Transfer through the real StatusRegistry. No major-status byte is copied
-- into a target, and no caller/preview is granted an infliction permission.
return function(mod,opts)
  local B=require('src.battle.BattleState');local FX=require('src.battle.EffectRegistry')
  local Player=require('src.battle.AnimPlayer')
  local M={CARD_ID='KASC-67-PSYCHO-SHIFT',OWNER='kasc.psycho-shift/v1'}
  local id,effect='PSYCHO_SHIFT','KA_PSYCHO_SHIFT_67';local aliases={};local A=assert(opts.abilities)
  local frames=setmetatable({},{__mode='k'});local tr=opts.i18n.text
  local statuses={PSN=true,BRN=true,PAR=true,SLP=true,FRZ=true}
  local function copy(v)if type(v)~='table'then return v end;local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r end
  local function pack(...)return{n=select('#',...),...}end
  local function int(v,lo,hi)return type(v)=='number'and v%1==0 and v>=lo and v<=hi end
  local function side(b,w)return b and w and(w==b.player and'player'or w==b.enemy and'enemy')end
  local function live(w)local p=w and w.mon;return p and int(p.hp,1,999999)and not w.fainted
    and not(p.egg or p.isEgg or p.is_egg or p.eggSpecies or p.status=='EGG')end
  local function index(b,w)local lane=side(b,w);local list=lane=='player'and b:playerPartyView()
    or lane=='enemy'and(b.enemyParty or{w.mon});for i,p in ipairs(list or{})do if i<=6 and p==w.mon then return i end end end
  local function owned(m)return m and aliases[m.id]and m.backendMoveOwner==M.OWNER and m.backendMoveNumber==375 end
  local function same(a,z)return owned(a)and owned(z)and a.id==z.id and a.effect==z.effect end
  local function mode(b)
    local r=b and b.kascGenerationRulesReceipt;local marker=b and b.data and b.data.move_effects and b.data.move_effects[effect]
    if getmetatable(b)==B and not b.demo and not b.result and b.kind~='link'and type(r)=='table'
      and int(r.activeEpoch,1,7)and(r.mode=='auto'or r.mode=='gen'..r.activeEpoch)
      and marker and marker.kascPsychoShift67==M.OWNER then return r.activeEpoch end
  end
  function M.epoch(b,u,m)
    local gen=mode(b);if not m then return gen end
    if not gen or not owned(m)or m.effect~=effect then return end
    if gen<4 and not(live(u)and index(b,u)and opts.rules.monMoveAvailable(b.game,u.mon,m.id,gen,true))then return end
    return math.max(4,gen)
  end
  local function has(w,typ)for _,t in ipairs(w.curTypes or{})do if t==typ then return true end end;return false end
  local function blocked(ctx)
    local p=mod.exports.pokemonProtection67;local priority=mod.exports.pokemonPriorityAbilities67
    return p and p.blocks(ctx)or priority and priority.blocks(ctx)or false
  end
  local function immune(b,u,t,m,gen,status)
    -- Status moves ignore Psychic-vs-Dark *damage* immunity. Status-type
    -- immunities use the transfer's licensed rule era, not a raw name.
    local corrosion=gen>=7 and A.activeAbility(b,u)=='CORROSION'
    if status=='PSN'and(has(t,'POISON')or has(t,'STEEL'))and not corrosion then return true end
    if status=='BRN'and has(t,'FIRE')or status=='FRZ'and has(t,'ICE')
      or status=='PAR'and gen>=6 and has(t,'ELECTRIC')then return true end
    if A.blockStatus(b,t,status,{source=m.id,moveType=m.type,kascStatusSource67=u})then return true end
    local recovery=mod.exports.pokemonTeamRecovery67
    return recovery and recovery.blocksStatus(b,t,status,{source=m.id,moveType=m.type,kascStatusSource67=u})or false
  end
  function M.noUseful(b,u,t,m)
    if not mode(b)or not owned(m)then return false end
    local gen=M.epoch(b,u,m)
    if not gen or not live(u)or not live(t)or not index(b,u)or not index(b,t)or u==t
      or not statuses[u.mon.status]or t.mon.status then return true end
    return A.moveScope(b,u,t,true,function()
      local memory=mod.exports.pokemonTargetMemory67
      return not not(t.invulnerable and not(memory and memory.phaseBypass(b,u,t,m))or t.substituteHP
        or blocked({battle=b,user=u,target=t,move=m})or immune(b,u,t,m,gen,u.mon.status))
    end,m)
  end
  function M.project(b,u,m)
    local gen=M.epoch(b,u,m);if not gen then return m end
    local row=assert(opts.facts.move(id,gen));local q=copy(m);q.accuracy=gen<=5 and 90 or 100
    assert(row.accuracy==q.accuracy and row.pp==10,'Psycho Shift historical accuracy drift')
    return q
  end
  function M.move(nextMove,b,inst,...)
    local m=nextMove(b,inst,...);if not owned(m)then return m end
    local f=frames[b];if f and f.inst==inst then return M.project(b,f.user,m)end
    for _,w in ipairs({b.player,b.enemy})do for _,s in ipairs(w and w.curMoves or{})do if s==inst then return M.project(b,w,m)end end end
    return m
  end
  function M.used(ev)local f=ev and frames[ev.battle]
    if f and f.user==ev.user and f.target==ev.target and same(f.move,ev.move)and f.called==ev.isCalled then f.declared=true end end
  function M.context(nextCtx,b,u,t,...)
    local ctx=nextCtx(b,u,t,...);local f=frames[b]
    if f and f.declared and f.user==u and f.target==t and same(f.move,ctx.move)then f.ctx=ctx;ctx.move=M.project(b,u,ctx.move)end;return ctx
  end
  function M.perform(original,b,u,t,inst,called,...)
    local m=inst and b:moveDef(inst)
    if not mode(b)or not owned(m)or not side(b,u)or not side(b,t)or not index(b,u)or not index(b,t)then
      return original(b,u,t,inst,called,...)end
    local old=frames[b];frames[b]={user=u,target=t,inst=inst,move=m,called=called or false}
    local out=pack(pcall(original,b,u,t,inst,called,...));frames[b]=old
    if not out[1]then error(out[2],0)end;return unpack(out,2,out.n)
  end
  function M.authorizedStatusEpoch(b,t,status,options)
    local f=frames[b];local o=options or{};local ctx=f and f.ctx
    if not f or not f.declared or not f.window or not f.inflicting or not ctx or ctx.target~=t
      or f.target~=t or f.user~=ctx.user or not same(f.move,ctx.move)or o.source~=ctx.move.id
      or o.secondary or o.kascStatusSource67~=f.user or status~=f.status or not statuses[status]
      or not live(t)or not index(b,t)or not live(f.user)or not index(b,f.user)
      or f.user.mon.status~=status or not not o.toxic~=f.toxic then return end
    return M.epoch(b,f.user,ctx.move)
  end
  function M.inflicted(ev)
    local f=ev and frames[ev.battle]
    if f and f.window and f.inflicting and f.declared and f.ctx and ev.target==f.target
      and ev.source==f.ctx.move.id and ev.status==f.status and ev.target.mon.status==f.status
      and live(ev.target)and index(ev.battle,ev.target)then f.landed=true end
  end
  local function fail()return{tr('But, it failed!','Doch es schlug fehl!'),failed=true}end
  function M.cast(ctx)
    local b,u,t,m=ctx.battle,ctx.user,ctx.target,ctx.move;local f=frames[b];local gen=M.epoch(b,u,m)
    if not gen or not f or not f.declared or not f.window or f.ctx~=ctx or f.user~=u or f.target~=t
      or not same(f.move,m)or not live(u)or not live(t)or not index(b,u)or not index(b,t)or u==t
      or not statuses[u.mon.status]or t.mon.status or t.substituteHP then return fail()end
    f.status=u.mon.status;f.toxic=f.status=='PSN'and int(u.toxicCounter,1,999999)or false
    local options={source=m.id,moveType=m.type,kascStatusSource67=u,toxic=f.toxic}
    f.inflicting=true;local out=pack(pcall(ctx.inflict,t,f.status,options));f.inflicting=false
    if not out[1]then error(out[2],0)end
    if not f.landed then return fail()end
    -- Synchronize has already run while source.status is occupied, exactly
    -- as native AfterSetStatus precedes the move's self cure. A berry may
    -- have cured the recipient after that genuine successful application.
    ctx.cure(u);assert(mod.exports.pokemonStatusLifecycle67,'Psycho Shift needs actual sleep lifecycle').clear(u,b)
    local messages=out[2]or{};messages[#messages+1]=tr('%s transferred its status problem!','%s hat sein Statusproblem übertragen!'):format(u.name)
    return messages
  end
  function M.resolve(ctx)
    local b,u,t,m=ctx.battle,ctx.user,ctx.target,ctx.move;local f=frames[b];local gen=M.epoch(b,u,m)
    local function report(msgs)if msgs.failed then b:cancelMoveAnim()end;for _,line in ipairs(msgs)do b:sayNext(line)end end
    if not gen or not f or not f.declared or f.ctx~=ctx or not live(u)or not live(t)
      or not index(b,u)or not index(b,t)or u==t then report(fail());return end
    return A.moveScope(b,u,t,true,function()
      local memory=mod.exports.pokemonTargetMemory67
      if t.invulnerable and not(memory and memory.phaseBypass(b,u,t,m))then
        b:cancelMoveAnim();b:sayNext(tr('The attack missed!','Die Attacke ging daneben!'));return end
      -- IV checks accuracy before general TryHit (Protect); V–VII checks
      -- TryHit first. The move-specific no-status test and Substitute are
      -- later than accuracy in every applicable source era.
      if gen>=5 and blocked(ctx)then report(fail());return end
      if not ctx.accuracyRoll()then b:cancelMoveAnim();b:sayNext(tr('The attack missed!','Die Attacke ging daneben!'));return end
      if gen==4 and blocked(ctx)then report(fail());return end
      local prior=f.window;f.window=true;local out=pack(pcall(M.cast,ctx));f.window=prior
      if not out[1]then error(out[2],0)end;report(out[2]);b:drainNext()
    end,m)
  end
  function M.validateCheckpoint(b)return not frames[b],'psycho_shift_unsettled'end
  local f=assert(opts.facts.move(id,7));local old=assert(mod.content.moves:get(id))
  assert(f.number==375 and f.generation==4 and f.type=='PSYCHIC_TYPE'and f.category=='status'and f.power==0
    and f.pp==10 and f.accuracy==100 and not f.alwaysHits and f.priority==0 and f.target==10,'Psycho Shift source drift')
  for _,flag in ipairs(f.flags or{})do assert(flag~='reflectable','Psycho Shift must not become Magic Bounce reflectable')end
  assert(not old.backendMoveOwner and old.effect=='KA_GEN_MOVE_UNSUPPORTED_'..id,'foreign Psycho Shift owner')
  mod.content.move_effects:register(effect,{kind='primary',accuracyChecked=false,kascPsychoShift67=M.OWNER,perform=M.resolve,run=M.cast})
  for _,alias in ipairs(opts.species.moveIds(id))do aliases[alias]=true;if mod.content.moves:get(alias)then
    mod.content.moves:patch(alias,{effect=effect,backendMoveOwner=M.OWNER,backendMoveNumber=375,
      originGeneration=4,backendLearnsetRevision=old.backendLearnsetRevision or 1,pp=10,power=0,category='status',target=10})end end;aliases[id]=true
  local anim=copy(assert(mod.content.battle_anims:get('CONFUSE_RAY')));anim.source=M.OWNER;mod.content.battle_anims:patch(id,anim)
  for i=#opts.catalog.unsupportedStatus,1,-1 do if opts.catalog.unsupportedStatus[i]==id then table.remove(opts.catalog.unsupportedStatus,i)end end
  function M.position(p,name)
    local row=p.data and p.data.moveAnims and p.data.moveAnims[name];if not aliases[name]or not row or row.source~=M.OWNER then return end
    local hud={{0,0,88,30},{72,56,160,94},{0,98,160,144}}
    for _,step in ipairs(p.steps or{})do local out={};for i,s in ipairs(step.sprites or{})do local q=copy(s);local x,y=q.x-8,q.y-16
      if q.y>0 and q.y<16 then q.x=0 end
      for _,box in ipairs(hud)do if x<box[3]and x+8>box[1]and y<box[4]and y+8>box[2]then q.x=0;break end end;out[i]=q
    end;step.sprites=out end
  end
  function M.install()
    B._kascPsychoShift67=M;FX._kascPsychoShift67=M;Player._kascPsychoShift67=M
    if B.performMove~=B._kascPsychoShiftPerform67 then local prev=B.performMove
      local wrap=function(...)return B._kascPsychoShift67.perform(prev,...)end;B.performMove=wrap;B._kascPsychoShiftPerform67=wrap end
    if B.moveDef~=B._kascPsychoShiftMove67 then local prev=B.moveDef
      local wrap=function(...)return B._kascPsychoShift67.move(prev,...)end;B.moveDef=wrap;B._kascPsychoShiftMove67=wrap end
    if FX.makeCtx~=FX._kascPsychoShiftContext67 then local prev=FX.makeCtx
      local wrap=function(...)return FX._kascPsychoShift67.context(prev,...)end;FX.makeCtx=wrap;FX._kascPsychoShiftContext67=wrap end
    if Player.start~=Player._kascPsychoShiftAnim67 then local prev=Player.start
      local wrap=function(self,name,...)local out=pack(prev(self,name,...));Player._kascPsychoShift67.position(self,name);return unpack(out,1,out.n)end
      Player.start=wrap;Player._kascPsychoShiftAnim67=wrap end
  end
  M.install();mod.events:on('battle.move_used',M.used,100201)
  mod.events:on('battle.status_inflicted',M.inflicted,200000)
  mod.events:on('battle.ended',function(ev)frames[ev.battle]=nil end,10101)
  if opts.supportLog and opts.supportLog.registerSegment then opts.supportLog.registerSegment({
    segmentId=M.CARD_ID,cardId=M.CARD_ID,schema='kasc.optional-feature-card/v1',version='1.0.0',owner=M.OWNER,
    active=true,dependencyStatus='genuine-declaration-and-shared-status-lifecycle',providerStatus='source-correct-status-transfer',
    buildReceiptId='docs/PSYCHO_SHIFT_67.md',rollbackReceiptId='docs/PSYCHO_SHIFT_67.md'})end
  return M
end
