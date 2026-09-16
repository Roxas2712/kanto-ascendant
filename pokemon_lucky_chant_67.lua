-- Lucky Chant is a five-turn SIDE condition, independent of Armor abilities.
-- Its only mutation window is an actual native declaration and final ctx.
return function(mod,opts)
  local B=require('src.battle.BattleState');local FX=require('src.battle.EffectRegistry')
  local Player=require('src.battle.AnimPlayer')
  local M={CARD_ID='KASC-67-LUCKY-CHANT',OWNER='kasc.lucky-chant/v1'}
  local id,effect='LUCKY_CHANT','KA_LUCKY_CHANT_67';local aliases={}
  local frames=setmetatable({},{__mode='k'});local tr=opts.i18n.text
  local function copy(v)if type(v)~='table'then return v end;local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r end
  local function pack(...)return{n=select('#',...),...}end
  local function int(v,lo,hi)return type(v)=='number'and v%1==0 and v>=lo and v<=hi end
  local function side(b,w)return b and w and(w==b.player and'player'or w==b.enemy and'enemy')end
  local function live(w)local p=w and w.mon;return p and int(p.hp,1,999999)and not w.fainted
    and not(p.egg or p.isEgg or p.is_egg or p.eggSpecies or p.status=='EGG')end
  local function index(b,w)local lane=side(b,w);local list=lane=='player'and b:playerPartyView()
    or lane=='enemy'and(b.enemyParty or{w.mon});for i,p in ipairs(list or{})do if i<=6 and p==w.mon then return i end end end
  local function owned(m)return m and aliases[m.id]and m.backendMoveOwner==M.OWNER and m.backendMoveNumber==381 end
  local function mode(b)
    local r=b and b.kascGenerationRulesReceipt;local marker=b and b.data and b.data.move_effects and b.data.move_effects[effect]
    if getmetatable(b)==B and not b.demo and not b.result and b.kind~='link'and type(r)=='table'
      and int(r.activeEpoch,1,7)and(r.mode=='auto'or r.mode=='gen'..r.activeEpoch)
      and marker and marker.kascLuckyChant67==M.OWNER then return r.activeEpoch end
  end
  function M.epoch(b,u,m)
    local gen=mode(b);if not m then return gen end
    if not gen or not owned(m)or m.effect~=effect then return end
    if gen<4 and not(live(u)and index(b,u)and opts.rules.monMoveAvailable(b.game,u.mon,m.id,gen,true))then return end
    return math.max(4,gen)
  end
  local function rows(b,create)
    if create then b.field=b.field or{};b.field.tokens=b.field.tokens or{};b.field.tokens[M.OWNER]=b.field.tokens[M.OWNER]or{}end
    return b and b.field and b.field.tokens and b.field.tokens[M.OWNER]
  end
  local function profile(b)
    local gen=mode(b);if gen then return gen end
    local r=b and b.field and b.field.tokens and b.field.tokens['kasc.generation-receipt/v1']
    if type(r)=='table'and int(r.activeEpoch,1,7)and(r.mode=='auto'or r.mode=='gen'..r.activeEpoch)then return r.activeEpoch end
  end
  local function seal(v)local r=copy(v);r.proof=nil;return opts.rules.receipts.hash(M.OWNER..':'..opts.rules.receipts.canonical(r))end
  local function valid(b,r,gen)
    if type(r)~='table'or not gen or r.profile~=gen or r.epoch~=math.max(4,gen)
      or not int(r.applied,0,b.turnCount or 0)or r.expires~=r.applied+4
      or not int(r.last,r.applied-1,b.turnCount or 0)or(b.turnCount or 0)>r.expires or r.proof~=seal(r)then return false end
    for k in pairs(r)do if not({profile=true,epoch=true,applied=true,expires=true,last=true,proof=true})[k]then return false end end
    return true
  end
  function M.active(b,w)
    local lane=side(b,w);local r=rows(b);local v=lane and r and r[lane]
    return live(w)and index(b,w)and mode(b)and valid(b,v,mode(b))or false
  end
  function M.blocksCritical(b,w)
    -- Damage hooks may receive detached stat projections. This adapter is
    -- pure; public casts never borrow the native side by mon equality.
    if not side(b,w)and w and w.mon then
      if b and b.player and b.player.mon==w.mon then w=b.player
      elseif b and b.enemy and b.enemy.mon==w.mon then w=b.enemy end
    end
    return M.active(b,w)
  end
  function M.noUseful(b,u,t,m)
    if not mode(b)or not owned(m)then return false end
    return not M.epoch(b,u,m)or not live(u)or not index(b,u)or M.active(b,u)
  end
  local function fail()return{tr('But, it failed!','Doch es schlug fehl!'),failed=true}end
  local function same(a,z)return owned(a)and owned(z)and a.id==z.id and a.effect==z.effect end
  function M.used(ev)local f=ev and frames[ev.battle]
    if f and f.user==ev.user and f.target==ev.target and same(f.move,ev.move)and f.called==ev.isCalled then f.declared=true end end
  function M.context(nextCtx,b,u,t,...)
    local ctx=nextCtx(b,u,t,...);local f=frames[b]
    if f and f.declared and f.user==u and f.target==t and same(f.move,ctx.move)then f.ctx=ctx end;return ctx
  end
  function M.perform(original,b,u,t,inst,called,...)
    local m=inst and b:moveDef(inst)
    if not mode(b)or not owned(m)or not side(b,u)or not index(b,u)or not side(b,t)or not index(b,t)then
      return original(b,u,t,inst,called,...)end
    local old=frames[b];frames[b]={user=u,target=t,inst=inst,move=m,called=called or false}
    local out=pack(pcall(original,b,u,t,inst,called,...));frames[b]=old
    if not out[1]then error(out[2],0)end;return unpack(out,2,out.n)
  end
  function M.cast(ctx)
    local b,u,m=ctx.battle,ctx.user,ctx.move;local f=frames[b];local gen=M.epoch(b,u,m)
    if not gen or not f or not f.declared or f.ctx~=ctx or f.user~=u or not same(f.move,m)
      or not live(u)or not index(b,u)or M.active(b,u)then return fail()end
    local turn=b.turnCount or 0;local v={profile=mode(b),epoch=gen,applied=turn,expires=turn+4,last=turn-1}
    v.proof=seal(v);rows(b,true)[side(b,u)]=v
    return{tr('Lucky Chant shields your team from critical hits!','Glücksbringer schützt dein Team vor Volltreffern!')}
  end
  function M.damage(nextDamage,ctx)
    if not ctx or not ctx.move or ctx.move.category=='status'or(tonumber(ctx.move.power)or 0)<=0
      or ctx.opts and(ctx.opts.typeless or ctx.opts.typelessDamage)or not M.blocksCritical(ctx.battle,ctx.target)then return nextDamage(ctx)end
    local q={};for k,v in pairs(ctx)do q[k]=v end;q.opts={};for k,v in pairs(ctx.opts or{})do q.opts[k]=v end
    q.opts.forceCrit=false;return nextDamage(q)
  end
  function M.endTurn(ev)
    local b=ev and ev.battle;local r=rows(b);if not r then return end;local turn=b.turnCount or 0
    for _,lane in ipairs({'player','enemy'})do local v=r[lane]
      if v then if not valid(b,v,mode(b))then r[lane]=nil
        elseif v.last~=turn then if turn>=v.expires then r[lane]=nil
          b:sayNext(tr('Lucky Chant wore off!','Glücksbringer ist verschwunden!'))
        else v.last=turn;v.proof=seal(v)end end end
    end
    if not next(r)then b.field.tokens[M.OWNER]=nil end
  end
  function M.finish(ev)local b=ev and ev.battle;if rows(b)then b.field.tokens[M.OWNER]=nil end;frames[b]=nil end
  function M.validateCheckpoint(b)
    if frames[b]then return false,'lucky_chant_unsettled'end
    local r=rows(b);if r==nil then return true end
    if type(r)~='table'then return false,'invalid_lucky_chant_container'end
    for lane,v in pairs(r)do if(lane~='player'and lane~='enemy')or not b[lane]
      or not valid(b,v,profile(b))then return false,'invalid_lucky_chant_side_timeline'end end
    return true
  end
  local f=assert(opts.facts.move(id,7));local old=assert(mod.content.moves:get(id))
  assert(f.number==381 and f.generation==4 and f.type=='NORMAL'and f.category=='status'and f.power==0
    and f.pp==30 and f.alwaysHits and f.priority==0 and f.target==4,'Lucky Chant source drift')
  assert(not old.backendMoveOwner and old.effect=='KA_GEN_MOVE_UNSUPPORTED_'..id,'foreign Lucky Chant owner')
  mod.content.move_effects:register(effect,{kind='primary',accuracyChecked=false,kascLuckyChant67=M.OWNER,run=M.cast})
  for _,alias in ipairs(opts.species.moveIds(id))do aliases[alias]=true;if mod.content.moves:get(alias)then
    mod.content.moves:patch(alias,{effect=effect,backendMoveOwner=M.OWNER,backendMoveNumber=381,
      originGeneration=4,backendLearnsetRevision=old.backendLearnsetRevision or 1,pp=30,power=0,category='status',target=4})end end
  aliases[id]=true
  local anim=copy(assert(mod.content.battle_anims:get('LIGHT_SCREEN')));anim.source=M.OWNER
  mod.content.battle_anims:patch(id,anim)
  for i=#opts.catalog.unsupportedStatus,1,-1 do if opts.catalog.unsupportedStatus[i]==id then table.remove(opts.catalog.unsupportedStatus,i)end end
  function M.position(p,name)
    local row=p.data and p.data.moveAnims and p.data.moveAnims[name];if not aliases[name]or not row or row.source~=M.OWNER then return end
    local hud={{0,0,88,30},{72,56,160,94},{0,98,160,144}}
    for _,step in ipairs(p.steps or{})do local out={};for i,s in ipairs(step.sprites or{})do local q=copy(s)
      local x,y=q.x-8,q.y-16
      if q.y>0 and q.y<16 then q.x=0 end
      for _,box in ipairs(hud)do if x<box[3]and x+8>box[1]and y<box[4]and y+8>box[2]then q.x=0;break end end;out[i]=q
    end;step.sprites=out end
  end
  function M.install()
    B._kascLuckyChant67=M;FX._kascLuckyChant67=M;Player._kascLuckyChant67=M
    if B.performMove~=B._kascLuckyChantPerform67 then local prev=B.performMove
      local wrap=function(...)return B._kascLuckyChant67.perform(prev,...)end;B.performMove=wrap;B._kascLuckyChantPerform67=wrap end
    if FX.makeCtx~=FX._kascLuckyChantContext67 then local prev=FX.makeCtx
      local wrap=function(...)return FX._kascLuckyChant67.context(prev,...)end;FX.makeCtx=wrap;FX._kascLuckyChantContext67=wrap end
    if Player.start~=Player._kascLuckyChantAnim67 then local prev=Player.start
      local wrap=function(self,name,...)local out=pack(prev(self,name,...));Player._kascLuckyChant67.position(self,name);return unpack(out,1,out.n)end
      Player.start=wrap;Player._kascLuckyChantAnim67=wrap end
  end
  M.install();mod.hooks:wrap('battle.damage',M.damage,20999)
  mod.events:on('battle.move_used',M.used,100200);mod.events:on('battle.turn_ended',M.endTurn,92)
  mod.events:on('battle.ended',M.finish,10100)
  if opts.supportLog and opts.supportLog.registerSegment then opts.supportLog.registerSegment({
    segmentId=M.CARD_ID,cardId=M.CARD_ID,schema='kasc.optional-feature-card/v1',version='1.0.0',owner=M.OWNER,
    active=true,dependencyStatus='genuine-declaration-and-native-critical-chain',providerStatus='five-turn-side-critical-guard',
    buildReceiptId='docs/LUCKY_CHANT_67.md',rollbackReceiptId='docs/LUCKY_CHANT_67.md'})end
  return M
end
