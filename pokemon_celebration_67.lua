-- Happy Hour is a battle-side payout license; Celebrate intentionally has
-- no stat/status effect. Neither writes an invented money reward event.
return function(mod,opts)
  local B=require('src.battle.BattleState');local FX=require('src.battle.EffectRegistry')
  local Player=require('src.battle.AnimPlayer')
  local M={OWNER='kasc.celebration/v1',CARD_ID='KASC-67-CELEBRATION'}
  local tr=opts.i18n.text;local defs={
    HAPPY_HOUR={number=603,pp=30,target=4,part='PAY_DAY'},
    CELEBRATE={number=606,pp=40,target=7,part='GROWTH'}}
  local aliases={};local frames=setmetatable({},{__mode='k'});local payments=setmetatable({},{__mode='k'})
  for id in pairs(defs)do for _,a in ipairs(opts.species.moveIds(id))do aliases[a]=id end end
  local function copy(v)if type(v)~='table'then return v end;local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r end
  local function pack(...)return{n=select('#',...),...}end
  local function int(v,a,z)return type(v)=='number'and v%1==0 and v>=a and v<=z end
  local function side(b,w)return b and(w==b.player and'player'or w==b.enemy and'enemy')end
  local function party(b,key)return key=='player'and b:playerPartyView()
    or key=='enemy'and(b.enemyParty or{b.enemy and b.enemy.mon})or{}end
  local function index(b,w)local key=side(b,w);if not key then return end
    for i,p in ipairs(party(b,key))do if i<=6 and p==w.mon then return i end end end
  local function live(w)local p=w and w.mon;return p and int(p.hp,1,999999)and not w.fainted
    and not(p.egg or p.isEgg or p.is_egg or p.eggSpecies or p.species=='EGG')end
  local function seal(h)local q=copy(h);q.proof=nil
    return opts.rules.receipts.hash(M.OWNER..':'..opts.rules.receipts.canonical(q))end
  local function rows(b,create)
    if create then b.field=b.field or{};b.field.tokens=b.field.tokens or{}
      b.field.tokens[M.OWNER]=b.field.tokens[M.OWNER]or{sides={}}end
    return b and b.field and b.field.tokens and b.field.tokens[M.OWNER]
  end
  function M.epoch(b,u,move)
    local r=b and b.kascGenerationRulesReceipt;local h=b and b.data and b.data.move_effects and b.data.move_effects.HEAL_EFFECT
    -- The authentic rule receipt remains valid during native winning payout.
    -- Move authorization below still rejects a completed battle.
    if getmetatable(b)~=B or b.demo or b.kind=='link'or not r or not int(r.activeEpoch,1,7)
      or not(r.mode=='auto'or r.mode=='gen'..r.activeEpoch)or not h or h.kascCelebration67~=M.OWNER then return end
    if not move then return r.activeEpoch end
    local id=aliases[move.id]or move.id;local d=defs[id];local e=d and b:effectRecord(move.effect)
    if b.result or not d or move.backendMoveOwner~=M.OWNER or move.backendMoveNumber~=d.number
      or move.type~='NORMAL'or move.category~='status'or move.power~=0 or move.target~=d.target
      or not e or e.kascCelebration67~=M.OWNER or not live(u)or not index(b,u)then return end
    if r.activeEpoch<6 and not opts.rules.monMoveAvailable(b.game,u.mon,move.id,r.activeEpoch,true)then return end
    return math.max(6,r.activeEpoch),id
  end
  local function valid(b,h,key)
    local profile=M.epoch(b)
    if not profile or type(h)~='table'or h.source~=key or h.profile~=profile or h.epoch~=math.max(6,profile)
      or not int(h.party,1,6)or not int(h.applied,0,b.turnCount or 0)
      or type(h.prizePaid)~='boolean'or type(h.payDayPaid)~='boolean'or h.proof~=seal(h)then return false end
    local p=party(b,key)[h.party]
    return p and p.species==h.species and not(p.egg or p.isEgg or p.is_egg or p.eggSpecies)or false
  end
  function M.active(b,key)
    key=type(key)=='table'and side(b,key)or key or'player'
    if key~='player'and key~='enemy'then return end
    local r=rows(b);local h=r and type(r.sides)=='table'and r.sides[key]
    if valid(b,h,key)then return h end
  end
  local function failed()return{tr('But, it failed!','Doch es schlug fehl!'),failed=true}end
  function M.cast(ctx)
    local b,u,t,m=ctx.battle,ctx.user,ctx.target,ctx.move;local gen,id=M.epoch(b,u,m);local f=frames[b]
    if not gen or not f or not f.used or f.ctx~=ctx or f.user~=u or f.target~=t or f.slot~=ctx.moveInst or f.id~=id then return failed()end
    if id=='CELEBRATE'then
      return{tr('Congratulations, %s!','Herzlichen Glückwunsch, %s!'):format(b.game.save.player.name)}
    end
    local key=side(b,u)
    -- A second native use succeeds cosmetically, but does not stack or
    -- replace the first authentic source, expiry or payment state.
    if not M.active(b,key)then
      local h={source=key,species=u.mon.species,party=index(b,u),profile=M.epoch(b),epoch=gen,
        applied=b.turnCount or 0,prizePaid=false,payDayPaid=false};h.proof=seal(h);rows(b,true).sides[key]=h
    end
    return{tr('%s used %s! Prize money will be doubled!','%s setzt %s ein! Das Preisgeld wird verdoppelt!'):format(u.name,m.name)}
  end
  function M.noUseful(b,u,t,move)
    local gen,id=M.epoch(b,u,move);if not gen then return false end
    if id=='CELEBRATE'or side(b,u)~='player'or M.active(b,'player')then return true end
    if b.kind=='trainer'and b.trainer and(tonumber(b.trainer.baseMoney)or 0)>0 then return false end
    for _,s in ipairs(u.curMoves or{})do
      local m=b:moveDef(s);local name=m and(aliases[m.id]or m.id)
      if m and(s.pp or 0)>0 and(name=='PAY_DAY'or name=='PAYDAY')then return false end
    end
    return true
  end
  function M.perform(original,b,u,t,slot,called,...)
    local m=slot and b:moveDef(slot);local gen,id;if m then gen,id=M.epoch(b,u,m)end
    if not gen then return original(b,u,t,slot,called,...)end
    local prior=frames[b];frames[b]={user=u,target=t,slot=slot,id=id}
    local out=pack(pcall(original,b,u,t,slot,called,...));frames[b]=prior
    if not out[1]then error(out[2],0)end;return unpack(out,2,out.n)
  end
  function M.used(ev)local f=ev and frames[ev.battle]
    if f and ev.user==f.user and ev.target==f.target and(aliases[ev.move.id]or ev.move.id)==f.id
      and M.epoch(ev.battle,ev.user,ev.move)then f.used=true end
  end
  function M.context(b,ctx,u,t,slot)local f=frames[b]
    if f and f.used and f.user==u and f.target==t and f.slot==slot and f.id==(aliases[ctx.move.id]or ctx.move.id)
      and M.epoch(b,u,ctx.move)then f.ctx=ctx end;return ctx
  end
  -- The actual final native trainer branch computes, credits and prints
  -- the multiplied prize itself. Its trainer identity is restored exactly.
  function M.prize(original,b,...)
    local h=M.active(b,'player');local trainer=b.trainer
    if not h or h.prizePaid or payments[b]or b.result or b.kind~='trainer'or not trainer
      or not int(trainer.baseMoney or 0,0,999999)or not b.enemy or not b.enemy.mon or b.enemy.mon.hp>0 then return original(b,...)end
    for _,p in ipairs(b.enemyParty or{})do if p.hp>0 then return original(b,...)end end
    local overlay={};for k,v in pairs(trainer)do overlay[k]=v end;overlay.baseMoney=(trainer.baseMoney or 0)*2
    local previous=payments[b];payments[b]={kind='prize'};b.trainer=overlay
    local out=pack(pcall(original,b,...));b.trainer=trainer;payments[b]=previous
    if b.result=='win'then h.prizePaid=true;h.proof=seal(h)end
    if not out[1]then error(out[2],0)end;return unpack(out,2,out.n)
  end
  -- Native finish consumes payDay once and displays that same amount. It
  -- is a separate payout from trainer money; no other reward is multiplied.
  function M.finish(original,b,...)
    local h=M.active(b,'player');local amount=b.payDay
    if not h or h.payDayPaid or payments[b]or b.result~='win'or not int(amount,1,999999)then return original(b,...)end
    local previous=payments[b];payments[b]={kind='payday'};b.payDay=amount*2
    local out=pack(pcall(original,b,...));payments[b]=previous
    if b.payDay==nil then h.payDayPaid=true;h.proof=seal(h)
    elseif b.payDay==amount*2 then b.payDay=amount end
    if not out[1]then error(out[2],0)end;return unpack(out,2,out.n)
  end
  function M.validateCheckpoint(b)
    if frames[b]or payments[b]then return false,'celebration_unsettled'end
    local r=rows(b);if r==nil then return true end
    if not M.epoch(b)or type(r)~='table'or type(r.sides)~='table'then return false,'invalid_celebration_container'end
    for k in pairs(r)do if k~='sides'then return false,'unknown_celebration_container_field'end end
    local known={source=true,species=true,party=true,profile=true,epoch=true,applied=true,prizePaid=true,payDayPaid=true,proof=true}
    for key,h in pairs(r.sides)do
      if key~='player'and key~='enemy'or not valid(b,h,key)then return false,'invalid_celebration_identity'end
      if key=='enemy'and(h.prizePaid or h.payDayPaid)then return false,'invalid_enemy_celebration_payment'end
      for k in pairs(h)do if not known[k]then return false,'unknown_celebration_record_field'end end
    end;return true
  end
  function M.position(player,id)
    local r=player.data and player.data.moveAnims and player.data.moveAnims[id]
    if not defs[id]or not r or r.source~=M.OWNER then return end
    for _,step in ipairs(player.steps or{})do local sprites={}
      for i,s in ipairs(step.sprites or{})do local q=copy(s)
        if q.x>0 and q.x<168 and q.y>0 and q.y<160 and(q.y<16 or mod.exports.pokemonPartnerHits67.inHud(q))then q.x=0 end
        sprites[i]=q
      end;step.sprites=sprites
    end
  end
  function M.install()
    B._kascCelebration67=M;FX._kascCelebration67=M;Player._kascCelebration67=M
    if not B._kascCelebrationWrapped67 then local original=B.performMove
      B.performMove=function(...)return B._kascCelebration67.perform(original,...)end;B._kascCelebrationWrapped67=true end
    if not FX._kascCelebrationWrapped67 then local original=FX.makeCtx
      FX.makeCtx=function(b,u,t,m,slot,...)return FX._kascCelebration67.context(b,original(b,u,t,m,slot,...),u,t,slot)end
      FX._kascCelebrationWrapped67=true
    end
    if not B._kascCelebrationPrizeWrapped67 then local original=B.enemyMonFainted
      B.enemyMonFainted=function(...)return B._kascCelebration67.prize(original,...)end;B._kascCelebrationPrizeWrapped67=true end
    if not B._kascCelebrationFinishWrapped67 then local original=B.finish
      B.finish=function(...)return B._kascCelebration67.finish(original,...)end;B._kascCelebrationFinishWrapped67=true end
    if not Player._kascCelebrationWrapped67 then local original=Player.start
      Player.start=function(self,id,...)local out=pack(original(self,id,...));Player._kascCelebration67.position(self,id);return unpack(out,1,out.n)end
      Player._kascCelebrationWrapped67=true
    end
  end
  for _,id in ipairs({'HAPPY_HOUR','CELEBRATE'})do local d=defs[id];local f=assert(opts.facts.move(id,6));local old=assert(mod.content.moves:get(id))
    assert(f.number==d.number and f.generation==6 and f.category=='status'and f.power==0 and f.pp==d.pp
      and f.alwaysHits and f.priority==0 and f.target==d.target and f.type=='NORMAL','Celebration source drift '..id)
    assert(not old.backendMoveOwner and old.effect=='KA_GEN_MOVE_UNSUPPORTED_'..id,'foreign Celebration owner '..id)
    local part
    for _,a in ipairs(opts.species.moveIds(d.part))do if mod.content.moves:get(a)and mod.content.battle_anims:get(a)then part=a;break end end
    assert(part,'missing native Celebration animation '..d.part)
    local effect='KA_CELEBRATION_67_'..id
    mod.content.move_effects:register(effect,{kind='primary',accuracyChecked=false,kascCelebration67=M.OWNER,run=M.cast})
    local flags=id=='HAPPY_HOUR'and{metronome=1}or{nosleeptalk=1,noassist=1,failcopycat=1,failmimic=1,failinstruct=1}
    mod.content.moves:patch(id,{name=tr(f.names.en,f.names.de),effect=effect,backendMoveOwner=M.OWNER,backendMoveNumber=d.number,
      originGeneration=6,backendLearnsetRevision=old.backendLearnsetRevision or 1,type='NORMAL',category='status',power=0,
      pp=d.pp,priority=0,target=d.target,accuracy=100,contact=false,flags=flags,anim=copy(mod.content.moves:get(part).anim)})
    local anim=copy(mod.content.battle_anims:get(part));anim.source=M.OWNER;mod.content.battle_anims:patch(id,anim)
    for i=#opts.catalog.unsupportedStatus,1,-1 do if opts.catalog.unsupportedStatus[i]==id then table.remove(opts.catalog.unsupportedStatus,i)end end
  end
  mod.content.move_effects:patch('HEAL_EFFECT',{kascCelebration67=M.OWNER});M.install()
  mod.events:on('battle.move_used',M.used,100211)
  mod.events:on('battle.ended',function(ev)if rows(ev.battle)then ev.battle.field.tokens[M.OWNER]=nil end
    frames[ev.battle]=nil;payments[ev.battle]=nil end,-27001)
  if opts.supportLog and opts.supportLog.registerSegment then opts.supportLog.registerSegment({
    segmentId=M.CARD_ID,cardId=M.CARD_ID,schema='kasc.optional-feature-card/v1',version='1.0.0',owner=M.OWNER,active=true,
    dependencyStatus='native-actions-final-trainer-payday-checkpoint',providerStatus='happy-hour-and-celebrate',
    buildReceiptId='docs/CELEBRATION_67.md',rollbackReceiptId='docs/CELEBRATION_67.md'})end
  return M
end
