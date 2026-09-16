-- Magic Coat and Snatch redirect one honest native use, never its learned slot.
return function(mod,opts)
  local B=require('src.battle.BattleState');local TC=require('src.battle.TypeChart')
  local Player=require('src.battle.AnimPlayer');local Order=require('src.battle.TurnOrder')
  local A=assert(opts.abilities);local tr=opts.i18n.text
  local M={CARD_ID='KASC-67-MOVE-REDIRECTION',OWNER='kasc.move-redirection/v1'}
  local defs={MAGIC_COAT={number=277,pp=15,type='PSYCHIC_TYPE'},SNATCH={number=289,pp=10,type='DARK'}}
  local frames=setmetatable({},{__mode='k'});local scopes=setmetatable({},{__mode='k'});local activeScope
  local aliases={};for id in pairs(opts.facts.data.moves)do for _,alias in ipairs(opts.species.moveIds(id))do aliases[alias]=id end end
  local function copy(v)if type(v)~='table'then return v end;local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r end
  local function pack(...)return{n=select('#',...),...}end
  local function integer(v,a,z)return type(v)=='number'and v%1==0 and v>=a and v<=z end
  local function live(w)local mon=w and w.mon;return mon and(tonumber(mon.hp)or 0)>0 and not w.fainted
    and not(mon.isEgg or mon.egg or mon.is_egg or mon.eggSpecies)end
  local function side(b,w)return w==b.player and'player'or w==b.enemy and'enemy'or nil end
  local function foe(b,w)return w==b.player and b.enemy or w==b.enemy and b.player or nil end
  local function party(b,key)if key=='player'then return b.game.save.party elseif key=='enemy'then return b.kind=='wild'and{b.enemy.mon}or b.enemyParty end end
  local function index(b,w)for i,mon in ipairs(party(b,side(b,w))or{})do if i<=6 and mon==w.mon then return i end end end
  local function ownSlot(w,slot)for i,s in ipairs(w.curMoves or{})do if i<=4 and s==slot then return i end end end
  local function namedSlot(w,id)for i,s in ipairs(w.curMoves or{})do if i<=4 and s.id==id then return i end end end
  local function rows(b,create)if create then b.field=b.field or{};b.field.tokens=b.field.tokens or{};b.field.tokens[M.OWNER]=b.field.tokens[M.OWNER]or{}end
    return b and b.field and b.field.tokens and b.field.tokens[M.OWNER]end
  function M.epoch(b,u,move)
    local r=b and b.kascGenerationRulesReceipt;local mark=b and b.data and b.data.move_effects and b.data.move_effects.KA_REDIRECT_67_SNATCH
    if getmetatable(b)~=B or b.demo or b.kind=='link'or b.result or not r or r.mode=='off'or not integer(r.activeEpoch,1,7)
        or not mark or mark.kascMoveRedirection67~=M.OWNER then return end
    if not move then return r.activeEpoch end
    local d=defs[move.id];local rec=d and b:effectRecord(move.effect)
    if not d or move.backendMoveOwner~=M.OWNER or move.backendMoveNumber~=d.number or not rec or rec.kascMoveRedirection67~=M.OWNER then return end
    if r.activeEpoch<3 and not(live(u)and opts.rules.monMoveAvailable(b.game,u.mon,move.id,r.activeEpoch,true))then return end
    return math.max(3,r.activeEpoch)
  end
  -- Full source flag replacements, pinned base then VII→III. Current
  -- future facts are capped by their true introduction below.
  local permissions={[3]={reflectable={[28]=true,[39]=true,[43]=true,[45]=true,[47]=true,[48]=true,[73]=true,[77]=true,[78]=true,[79]=true,[81]=true,[86]=true,[92]=true,[95]=true,[103]=true,[108]=true,[109]=true,[134]=true,[137]=true,[139]=true,[142]=true,[147]=true,[148]=true,[169]=true,[178]=true,[184]=true,[186]=true,[204]=true,[207]=true,[212]=true,[213]=true,[230]=true,[260]=true,[261]=true,[281]=true,[297]=true,[313]=true,[319]=true,[320]=true,[321]=true,[335]=true,[380]=true,[388]=true,[445]=true,[464]=true,[477]=true,[487]=true,[493]=true,[494]=true,[505]=true,[564]=true,[567]=true,[568]=true,[571]=true,[575]=true,[576]=true,[589]=true,[590]=true,[598]=true,[599]=true,[600]=true,[608]=true,[666]=true,[668]=true,[671]=true,[672]=true,[685]=true,[715]=true,[738]=true},snatch={[14]=true,[54]=true,[74]=true,[96]=true,[97]=true,[104]=true,[105]=true,[106]=true,[107]=true,[110]=true,[111]=true,[112]=true,[113]=true,[115]=true,[116]=true,[133]=true,[135]=true,[151]=true,[156]=true,[159]=true,[164]=true,[187]=true,[208]=true,[215]=true,[219]=true,[234]=true,[235]=true,[236]=true,[244]=true,[254]=true,[256]=true,[268]=true,[275]=true,[287]=true,[293]=true,[294]=true,[303]=true,[312]=true,[322]=true,[334]=true,[336]=true,[339]=true,[347]=true,[349]=true,[355]=true,[366]=true,[367]=true,[397]=true,[417]=true,[455]=true,[456]=true,[468]=true,[469]=true,[475]=true,[483]=true,[489]=true,[501]=true,[504]=true,[508]=true,[526]=true,[538]=true,[561]=true,[602]=true,[659]=true,[673]=true,[674]=true,[694]=true}},
    [5]={reflectable={[18]=true,[28]=true,[39]=true,[43]=true,[45]=true,[46]=true,[47]=true,[48]=true,[50]=true,[73]=true,[77]=true,[78]=true,[79]=true,[81]=true,[86]=true,[92]=true,[95]=true,[103]=true,[108]=true,[109]=true,[134]=true,[137]=true,[139]=true,[142]=true,[147]=true,[148]=true,[169]=true,[178]=true,[180]=true,[184]=true,[186]=true,[191]=true,[193]=true,[204]=true,[207]=true,[212]=true,[213]=true,[227]=true,[230]=true,[259]=true,[260]=true,[261]=true,[269]=true,[281]=true,[297]=true,[313]=true,[316]=true,[319]=true,[320]=true,[321]=true,[335]=true,[357]=true,[373]=true,[377]=true,[380]=true,[388]=true,[390]=true,[432]=true,[445]=true,[446]=true,[464]=true,[477]=true,[487]=true,[493]=true,[494]=true,[505]=true,[564]=true,[567]=true,[568]=true,[571]=true,[575]=true,[576]=true,[589]=true,[590]=true,[598]=true,[599]=true,[600]=true,[608]=true,[666]=true,[668]=true,[671]=true,[672]=true,[685]=true,[715]=true,[738]=true},snatch={[14]=true,[54]=true,[74]=true,[96]=true,[97]=true,[104]=true,[105]=true,[106]=true,[107]=true,[110]=true,[111]=true,[112]=true,[113]=true,[115]=true,[116]=true,[133]=true,[135]=true,[151]=true,[156]=true,[159]=true,[160]=true,[164]=true,[187]=true,[208]=true,[215]=true,[219]=true,[234]=true,[235]=true,[236]=true,[254]=true,[256]=true,[268]=true,[273]=true,[275]=true,[278]=true,[286]=true,[287]=true,[293]=true,[294]=true,[303]=true,[312]=true,[322]=true,[334]=true,[336]=true,[339]=true,[347]=true,[349]=true,[355]=true,[361]=true,[366]=true,[379]=true,[381]=true,[392]=true,[393]=true,[397]=true,[417]=true,[455]=true,[456]=true,[461]=true,[468]=true,[469]=true,[475]=true,[483]=true,[489]=true,[501]=true,[504]=true,[508]=true,[526]=true,[538]=true,[561]=true,[602]=true,[659]=true,[673]=true,[674]=true,[694]=true}}}
  permissions[4]=permissions[3];permissions[6]=permissions[5];permissions[7]=permissions[5]
  local function fact(move)return move and opts.facts.data.moves[aliases[move.id]or move.id]end
  local function sourceAllowed(b,u,move,epoch)
    local f=fact(move);local rec=move and b:effectRecord(move.effect)
    return live(u)and f and f.generation<=7 and rec and not move.effect:find('UNSUPPORTED',1,true)
      and not(move.isZ or move.isMax or move.isZOrMaxPowered)
      and opts.rules.monMoveAvailable(b.game,u.mon,move.id,M.epoch(b),true)and f or nil
  end
  function M.allowed(b,u,move,epoch,flag)
    if not integer(epoch,3,7)or(flag~='reflectable'and flag~='snatch')then return false end
    local f=sourceAllowed(b,u,move,epoch);local era=f and math.max(epoch,f.generation)
    return f and permissions[era]and permissions[era][flag][f.number]or false
  end
  function M.row(b,w,id)
    local r=rows(b);local v=r and r[side(b,w)];local h=v and v[id]
    return M.epoch(b)and h and h.applied==(b.turnCount or 0)and h.species==w.mon.species and h.party==index(b,w)and h or nil
  end
  function M.clear(b,w,id)
    local r=rows(b);if not r then return end
    local key=w and side(b,w);if not w then b.field.tokens[M.OWNER]=nil
    elseif key then if id and r[key]then r[key][id]=nil;if not next(r[key])then r[key]=nil end else r[key]=nil end end
  end
  local function integrity(h)local q=copy(h);q.proof=nil;return opts.rules.receipts.hash(M.OWNER..':'..opts.rules.receipts.canonical(q))end
  function M.arm(ctx)
    local b,u,move=ctx.battle,ctx.user,ctx.move;local epoch=M.epoch(b,u,move)
    if not epoch or not live(u)or not side(b,u)or not index(b,u)or M.row(b,u,move.id)then return{tr('But, it failed!','Doch es schlug fehl!'),failed=true}end
    local h={species=u.mon.species,party=index(b,u),profile=M.epoch(b),epoch=epoch,applied=b.turnCount or 0,
      slot=ownSlot(u,ctx.moveInst)or namedSlot(u,move.id),prankster=epoch>=5 and A.activeAbility(b,u)=='PRANKSTER'or false}
    h.proof=integrity(h);local r=rows(b,true);r[side(b,u)]=r[side(b,u)]or{};r[side(b,u)][move.id]=h
    return{move.id=='MAGIC_COAT'and tr('%s surrounds itself with a Magic Coat!','%s umgibt sich mit einem Magiemantel!'):format(u.name)
      or tr('%s waits to snatch a move!','%s wartet auf eine Übernahme!'):format(u.name)}
  end
  function M.isSnatched(ctx)
    local s=ctx and scopes[ctx.battle]
    return s and s.kind=='SNATCH'and s.receiver==ctx.user and ctx.move and ctx.move.id==s.move and s or nil
  end
  function M.swallowLayers(ctx)
    local s=M.isSnatched(ctx);local stock=mod.exports.pokemonStockpile67
    return s and s.epoch>=5 and(stock.layers(ctx.battle,ctx.user)>0 and stock.layers(ctx.battle,ctx.user)or 1)or nil
  end
  function M.reflectedPrankster(b,u,move)
    local s=scopes[b];if s and s.kind=='MAGIC_COAT'and s.receiver==u and move and move.id==s.move then return s.prankster end
  end
  function M.permission(game,mon,id,epoch,extensions)
    local s=activeScope
    return extensions~=false and s and not s.checking and s.battle.game==game and s.receiver.mon==mon and s.move==id
      and epoch==s.profile and s.source.mon.species==s.sourceSpecies and s.sourceAvailable and M.epoch(s.battle)==epoch or false
  end
  function M.coat(ctx)
    local b,u,t,move=ctx.battle,ctx.user,ctx.target,ctx.move;local h=M.row(b,t,'MAGIC_COAT')
    local caster=mod.exports.pokemonCasterStrikes67
    if caster and not caster.canCast(b,u,t,move)then return end
    local bounce=mod.exports.pokemonMagicBounce67
    if not h or not live(t)or u==t or scopes[b]and scopes[b].kind=='MAGIC_COAT'
        or bounce and bounce.reflectionSource(b,u,move)or not M.allowed(b,u,move,h.epoch,'reflectable')then return end
    local hazards=mod.exports.pokemonEntryHazards67;local sideTarget=hazards and hazards.sideTarget(b,u,move)
    local frame=frames[b];local semi=t.invulnerable or frame and frame.invulnerable
    if sideTarget and h.epoch<=4 or semi and(not sideTarget and h.epoch>=5 or sideTarget and h.epoch>=6)then return end
    if not sideTarget and mod.exports.pokemonProtection67.blocks(ctx)then return end
    if h.epoch<=6 and(aliases[move.id]or move.id)=='THUNDER_WAVE'and TC.effectiveness(move.type,t.curTypes or{})==0 then return end
    return{receiver=t,source=u,kind='MAGIC_COAT',row=h,epoch=h.epoch,sideTarget=not not sideTarget}
  end
  local function preparationAllowed(ctx)
    local b,u,move=ctx.battle,ctx.user,ctx.move;local id=aliases[move.id]or move.id
    local stock=mod.exports.pokemonStockpile67;local ground=mod.exports.pokemonGrounding67
    if id=='REST'then return u.mon.status~='SLP'and u.mon.hp<u.mon.stats.hp
      and not({COMATOSE=true,INSOMNIA=true,VITAL_SPIRIT=true})[A.activeAbility(b,u)]
    elseif id=='STOCKPILE'then return stock and stock.layers(b,u)<3
    elseif id=='SWALLOW'then return stock and(stock.layers(b,u)>0 or M.isSnatched(ctx)and M.isSnatched(ctx).epoch>=5)
    elseif id=='MAGNET_RISE'then
      -- An Iron Ball grounds the holder, but does not fail Magnet Rise's
      -- original onTry. Only genuine pinned volatiles/Gravity do that.
      return ground and ground.canRise(b,u)
    elseif id=='AURORA_VEIL'then return mod.exports.pokemonWeather67.current(b)=='hail'end
    return true
  end
  local function speed(b,w)local weather=mod.exports.pokemonWeather67;return weather and weather.speed(b,w)or Order.effectiveSpeed(w)end
  function M.snatch(ctx,pure)
    local b,u,t,move=ctx.battle,ctx.user,ctx.target,ctx.move;local scope=scopes[b];local candidates={}
    if not preparationAllowed(ctx)or scope and scope.kind=='SNATCH'and scope.epoch>=5 then return end
    for _,w in ipairs({b.player,b.enemy})do local h=M.row(b,w,'SNATCH')
      if live(w)and h and not w.skyDropped and not w.isSkyDropped and M.allowed(b,u,move,h.epoch,'snatch')then candidates[#candidates+1]={receiver=w,source=u,kind='SNATCH',row=h,epoch=h.epoch}end
    end
    if#candidates==0 then return end
    if#candidates==2 then local a,z=speed(b,candidates[1].receiver),speed(b,candidates[2].receiver)
      if z>a or a==z and not pure and b.rng(0,1)==1 then candidates[1],candidates[2]=candidates[2],candidates[1]end
    end
    return candidates[1]
  end
  function M.redirect(ctx,p)
    local b,u,move=ctx.battle,ctx.user,ctx.move;local receiver=p.receiver;local original=scopes[b];local oldActive=activeScope
    if p.kind=='MAGIC_COAT'and p.epoch<=4 or p.kind=='SNATCH'then M.clear(b,receiver,p.kind)end
    local s={battle=b,receiver=receiver,source=u,sourceSpecies=u.mon.species,sourceAvailable=true,move=move.id,profile=M.epoch(b),epoch=p.epoch,
      kind=p.kind,prankster=p.kind=='MAGIC_COAT'and not p.sideTarget and p.row.prankster or false}
    scopes[b]=s;activeScope=s
    local last=receiver.lastMove
    local out=pack(pcall(function()
    if p.kind=='MAGIC_COAT'then
      local bounce=assert(mod.exports.pokemonMagicBounce67);assert(type(bounce.reflect)=='function','Magic Coat requires owned native Magic Bounce reflection seam')
      return bounce.reflect(ctx,tr('Magic Coat reflected the move!','Der Magiemantel wirft die Attacke zurück!'))
    else
      b:cancelMoveAnim();b:sayNext(tr('%s snatched the move!','%s übernimmt die Attacke!'):format(receiver.name))
      if p.epoch<=4 and A.activeAbility(b,u)=='PRESSURE'and u~=receiver then
        local slot=p.row.slot and receiver.curMoves[p.row.slot];if slot and slot.id=='SNATCH'then slot.pp=math.max(0,slot.pp-1)end
      end
      local f=fact(move);local target=move.target or f.target
      local other=(target==4 or target==5 or target==7 or target==13 or target==15)and receiver or foe(b,receiver)
      return b:performMove(receiver,other,{id=move.id,pp=1},true)
    end
    end));if p.kind=='SNATCH'then receiver.lastMove=last end
    scopes[b]=original;activeScope=oldActive;if not out[1]then error(out[2],0)end;return unpack(out,2,out.n)
  end
  function M.perform(original,b,u,t,slot,...)
    local move=slot and b:moveDef(slot);local raw=M.epoch(b)
    if not raw or not move or not live(u)or not live(t)or not side(b,u)or not side(b,t)then return original(b,u,t,slot,...)end
    local previous=frames[b];local frame={invulnerable=t and t.invulnerable};frames[b]=frame
    local oldRaw,old=rawget(b,'effectRecord'),b.effectRecord
    local checked,decision=false
    b.effectRecord=function(self,id)local rec=old(self,id)
      if id~=move.effect or not rec then return rec end
      local proxy={};for k,v in pairs(rec)do if k~='perform'then proxy[k]=v end end
      return setmetatable(proxy,{__index=function(_,key)
        if key=='perform'and frames[b]==frame then
          local ctx={battle=b,user=u,target=t,move=move,moveInst=slot,rng=b.rng}
          -- Snatch's PrepareHit precedes Magic Coat's TryHit.
          if not checked then checked=true;decision=M.snatch(ctx,false)or M.coat(ctx)end
          if decision then return function(actual)return M.redirect(actual,decision)end end
        end
        return rec[key]
      end})
    end
    local out=pack(pcall(original,b,u,t,slot,...));b.effectRecord=oldRaw;frames[b]=previous
    if not out[1]then error(out[2],0)end;return unpack(out,2,out.n)
  end
  function M.expire(b)
    local r=rows(b);if not r or not M.epoch(b)then return end
    for key,v in pairs(r)do for id,h in pairs(v)do if h.applied~=(b.turnCount or 0)or not b[key]or not live(b[key])then v[id]=nil end end
      if not next(v)then r[key]=nil end
    end
  end
  function M.noUseful(b,u,t,move)
    local epoch=M.epoch(b,u,move);if not epoch then return false end
    if not live(u)or not live(t)or M.row(b,u,move.id)then return true end
    local flag=move.id=='MAGIC_COAT'and'reflectable'or'snatch'
    for _,slot in ipairs(t.curMoves or{})do local incoming=b:moveDef(slot)
      local rec=incoming and b:effectRecord(incoming.effect)
      if M.allowed(b,t,incoming,epoch,flag)or rec and rec.callsMove then return false end
    end
    return true
  end
  function M.validateCheckpoint(b)
    if frames[b]or scopes[b]then return false,'move_redirection_unsettled'end
    local r=rows(b);if not r then return true end
    if not M.epoch(b)or type(r)~='table'then return false,'invalid_move_redirection_container'end
    for key,v in pairs(r)do local w=(key=='player'or key=='enemy')and b[key]
      if not w or type(v)~='table'then return false,'invalid_move_redirection_side'end
      for id,h in pairs(v)do
        if not defs[id]or type(h)~='table'or h.species~=w.mon.species or h.party~=index(b,w)or h.profile~=M.epoch(b)
            or h.epoch~=math.max(3,M.epoch(b))or h.applied~=(b.turnCount or 0)or type(h.prankster)~='boolean'
            or h.slot~=nil and not integer(h.slot,1,4)or h.proof~=integrity(h)then return false,'invalid_move_redirection_receipt'end
        for k in pairs(h)do if k~='species'and k~='party'and k~='profile'and k~='epoch'and k~='applied'and k~='slot'and k~='prankster'and k~='proof'then return false,'unknown_move_redirection_field'end end
      end
    end
    return true
  end
  for id,d in pairs(defs)do local f=assert(opts.facts.move(id,7));local old=assert(mod.content.moves:get(id))
    assert(f.number==d.number and f.generation==3 and f.category=='status'and f.power==0 and f.pp==d.pp and f.priority==4,'redirection source drift '..id)
    assert(not old.backendMoveOwner and old.effect=='KA_GEN_MOVE_UNSUPPORTED_'..id,'foreign redirection owner '..id)
    local effect='KA_REDIRECT_67_'..id
    mod.content.move_effects:register(effect,{kind='primary',accuracyChecked=false,run=M.arm,kascMoveRedirection67=M.OWNER})
    mod.content.moves:patch(id,{effect=effect,power=0,pp=d.pp,accuracy=100,priority=4,type=d.type,category='status',target=7,
      flags=id=='MAGIC_COAT'and{metronome=1}or{bypasssub=1,mustpressure=1,noassist=1,failcopycat=1},
      backendMoveOwner=M.OWNER,backendMoveNumber=d.number,originGeneration=3,backendLearnsetRevision=old.backendLearnsetRevision or 1})
    local anim=copy(assert(mod.content.battle_anims:get(id=='MAGIC_COAT'and'BARRIER'or'METRONOME')));anim.source=M.OWNER;mod.content.battle_anims:patch(id,anim)
    for i=#opts.moves.unsupportedStatus,1,-1 do if opts.moves.unsupportedStatus[i]==id then table.remove(opts.moves.unsupportedStatus,i)end end
  end
  function M.position(player,id)local anim=player.data and player.data.moveAnims and player.data.moveAnims[id]
    if not defs[id]or not anim or anim.source~=M.OWNER then return end
    for _,step in ipairs(player.steps or{})do for _,s in ipairs(step.sprites or{})do
      if s.x>0 and s.x<168 and s.y>0 and s.y<160 and mod.exports.pokemonPartnerHits67.inHud(s)then s.x=0 end
    end end
  end
  function M.install()
    B._kascMoveRedirection67=M;Player._kascMoveRedirection67=M
    if not B._kascMoveRedirectionWrapped67 then local perform,execute=B.performMove,B.executeAction
      B.performMove=function(...)return B._kascMoveRedirection67.perform(perform,...)end
      B.executeAction=function(b,...)B._kascMoveRedirection67.expire(b);return execute(b,...)end
      B._kascMoveRedirectionWrapped67=true end
    if not Player._kascMoveRedirectionWrapped67 then local start=Player.start
      Player.start=function(self,id,...)local out=pack(start(self,id,...));Player._kascMoveRedirection67.position(self,id);return unpack(out,1,out.n)end
      Player._kascMoveRedirectionWrapped67=true end
  end
  mod.events:on('battle.turn_started',function(ev)M.expire(ev.battle)end,5999)
  mod.events:on('battle.turn_ended',function(ev)M.clear(ev.battle)end,5999)
  mod.events:on('battle.battler_switched',function(ev)M.clear(ev.battle,ev.battler)end,8001)
  mod.events:on('battle.ended',function(ev)M.clear(ev.battle)end,8001)
  M.install()
  if opts.supportLog and opts.supportLog.registerSegment then opts.supportLog.registerSegment({segmentId=M.CARD_ID,cardId=M.CARD_ID,
    schema='kasc.optional-feature-card/v1',version='1.0.0',owner=M.OWNER,active=true,dependencyStatus='native-reflection-scope-and-status-dispatch',
    providerStatus='source-era-coat-and-snatch-singles',buildReceiptId='docs/MOVE_REDIRECTION_67.md',rollbackReceiptId='docs/MOVE_REDIRECTION_67.md'})end
  return M
end
