-- Item possession, suppression and donation are different owners. Embargo
-- never removes an item or creates consumption; Bestow uses ItemTransfer.
return function(mod,opts)
  local B=require('src.battle.BattleState');local FX=require('src.battle.EffectRegistry')
  local Items=require('src.inventory.ItemEffects');local AI=require('src.battle.TrainerAI')
  local Player=require('src.battle.AnimPlayer')
  local M={CARD_ID='KASC-67-ITEM-ACCESS',OWNER='kasc.item-access/v1'}
  local tr=opts.i18n.text;local rules=assert(opts.rules);local transfer=assert(opts.transfer)
  local frames=setmetatable({},{__mode='k'});local passes=setmetatable({},{__mode='k'})
  local defs={EMBARGO={number=373,birth=4,anim='DISABLE'},BESTOW={number=516,birth=5,anim='PAY_DAY'}}
  local function copy(v)if type(v)~='table'then return v end;local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r end
  local function pack(...)return{n=select('#',...),...}end
  local function int(v,a,z)return type(v)=='number'and v%1==0 and v>=a and v<=z end
  local function live(w)local p=w and w.mon;return p and int(p.hp,1,999999)and not w.fainted
    and not(p.egg or p.isEgg or p.is_egg or p.eggSpecies or p.species=='EGG')end
  local function side(b,w)return b and w and(w==b.player and'player'or w==b.enemy and'enemy')end
  local function party(b,lane)return lane=='player'and b.game.save.party or lane=='enemy'and(b.enemyParty or{b.enemy.mon})end
  local function at(b,lane,p)for i,mon in ipairs(party(b,lane)or{})do if i<=6 and mon==p then return i end end end
  local function index(b,w)local lane=side(b,w);return lane and at(b,lane,w.mon)end
  local function actual(b,w)
    if side(b,w)then return w end
    if w and w.mon then return b and b.player and b.player.mon==w.mon and b.player
      or b and b.enemy and b.enemy.mon==w.mon and b.enemy end
  end
  local function mode(b)
    local r=b and b.kascGenerationRulesReceipt;local h=b and b.data and b.data.move_effects and b.data.move_effects.HEAL_EFFECT
    if getmetatable(b)==B and not b.demo and not b.result and b.kind~='link'and type(r)=='table'
      and int(r.activeEpoch,1,7)and(r.mode=='auto'or r.mode=='gen'..r.activeEpoch)
      and h and h.kascItemAccess67==M.OWNER then return r.activeEpoch end
  end
  local function owned(m)local d=m and defs[m.id]
    return d and m.backendMoveOwner==M.OWNER and m.backendMoveNumber==d.number and d or nil end
  function M.epoch(b,u,m)
    local gen=mode(b);if not m then return gen end;local d=owned(m)
    local e=gen and d and b.data.move_effects[m.effect]
    if not gen or not d or not e or e.kascItemAccess67~=M.OWNER then return end
    if gen<d.birth and not(live(u)and index(b,u)and rules.monMoveAvailable(b.game,u.mon,m.id,gen,true))then return end
    return math.max(gen,d.birth)
  end
  local function rows(b,create)
    if create then b.field=b.field or{};b.field.tokens=b.field.tokens or{}
      b.field.tokens[M.OWNER]=b.field.tokens[M.OWNER]or{}end
    return b and b.field and b.field.tokens and b.field.tokens[M.OWNER]
  end
  local function profile(b)
    local gen=mode(b);if gen then return gen end
    -- Checkpoint validation precedes frozen receipt reattachment. The
    -- generation owner separately validates this immutable receipt/hash.
    local r=b and b.field and b.field.tokens and b.field.tokens['kasc.generation-receipt/v1']
    if type(r)=='table'and int(r.activeEpoch,1,7)and(r.mode=='auto'or r.mode=='gen'..r.activeEpoch)then return r.activeEpoch end
  end
  local function valid(b,lane,r,w,gen)
    w=w or b[lane];gen=gen or mode(b)
    if not gen or(lane~='player'and lane~='enemy')or type(r)~='table'or not w or not w.mon
      or r.party~=at(b,lane,w.mon)or r.species~=w.mon.species or r.profile~=gen or r.epoch~=math.max(4,gen)
      or not int(r.applied,0,b.turnCount or 0)or r.expires~=r.applied+4
      or not int(r.lastTurn,r.applied-1,b.turnCount or 0)or(b.turnCount or 0)>r.expires then return false end
    for k in pairs(r)do if k~='party'and k~='species'and k~='profile'and k~='epoch'
      and k~='applied'and k~='expires'and k~='lastTurn'then return false end end
    return true
  end
  function M.active(b,w)
    local lane=side(b,w);local r=rows(b);local row=lane and r and r[lane]
    return live(w)and row and valid(b,lane,row,w)and row or false
  end
  function M.itemSuppressed(b,w,id)
    -- Primal-orb form activation is independent. Embargo, unlike Klutz,
    -- suppresses the battle penalties of training items too.
    return type(id)=='string'and id~='BLUE_ORB'and id~='RED_ORB'
      and M.active(b,actual(b,w))~=false or false
  end
  function M.blocksMove(b,w,id)
    return(id=='FLING'or id=='NATURAL_GIFT')and M.active(b,actual(b,w))~=false or false
  end
  function M.blocksBag(b,w)return M.active(b,w)~=false end
  function M.uiSuppression(game,mon)
    -- A read-only status-menu seam; do not relabel Embargo as Klutz or
    -- erase the carried item in order to render its inactive effect.
    for _,b in ipairs(game and game.stack and game.stack.states or{})do
      if getmetatable(b)==B and b.game==game then local w=actual(b,{mon=mon});local row=M.active(b,w)
        local id=opts.held(mon)
        if row and M.itemSuppressed(b,w,id)then return{owner=M.OWNER,reasonCode='embargo',turns=row.expires-(b.turnCount or 0)+1,
          en='Embargo temporarily disables the held effect and targeted item treatment; the item remains carried.',
          de='Itemsperre deaktiviert vorübergehend die Tragewirkung und gezielte Itembehandlung; das Item bleibt getragen.'}end
      end
    end
  end
  local function guard(b,t,m,gen)
    local p=mod.exports.pokemonProtection67;local g=p and p.active(b,t)
    if m.id=='BESTOW'then return gen==5 and g and g~='ENDURE'and g~='KINGS_SHIELD'or false end
    return p and p.blocks({battle=b,user=t==b.player and b.enemy or b.player,target=t,move=m})or false
  end
  function M.canBestow(b,u,t,m)
    local gen=M.epoch(b,u,m)
    if not gen or m.id~='BESTOW'or not live(u)or not live(t)or not side(b,u)or not side(b,t)
      or u==t or not index(b,u)or not index(b,t)or t.invulnerable
      or gen==5 and t.substituteHP or guard(b,t,m,gen)then return false end
    local id,err=opts.held(u.mon);local mine,merr=opts.held(t.mon)
    if err or merr or not id or mine or not b.data.items[id]then return false end
    -- A pure explicit source-era restriction query grants no transaction.
    -- Only bestowProof's real native transaction window permits transfer.
    if transfer.bound(b,u,id,false,gen)or transfer.bound(b,t,id,false,gen)then return false end
    return true,id
  end
  function M.noUseful(b,u,t,m)
    if not mode(b)or not owned(m)then return false end
    local gen=M.epoch(b,u,m)
    if not gen or not live(u)or not live(t)or not side(b,u)or not side(b,t)
      or u==t or not index(b,u)or not index(b,t)then return true end
    local function forecast()
      local priority=mod.exports.pokemonPriorityAbilities67
      if priority and priority.blocks({battle=b,user=u,target=t,move=m})then return true end
      if m.id=='BESTOW'then return not M.canBestow(b,u,t,m)end
      if M.active(b,t)or t.substituteHP or t.invulnerable or guard(b,t,m,gen)then return true end
      local id,err=opts.held(t.mon)
      -- Embargo can legally prevent future bag treatment with no held item;
      -- do not make this real use fail just because AI finds it less useful.
      return err~=nil or not id and b.kind~='trainer'
    end
    local abilities=mod.exports.pokemonAbilityEffects67
    if abilities then return abilities.moveScope(b,u,t,true,forecast,m)end
    return forecast()
  end
  local function same(a,z)return a and z and owned(a)and owned(z)and a.id==z.id and a.effect==z.effect end
  function M.used(ev)local f=ev and frames[ev.battle]
    if f and f.user==ev.user and f.target==ev.target and same(f.move,ev.move)and f.called==ev.isCalled then f.declared=true end end
  function M.context(nextCtx,b,u,t,...)
    local ctx=nextCtx(b,u,t,...);local f=frames[b]
    if f and f.declared and f.user==u and f.target==t and same(f.move,ctx.move)then
      f.ctx=ctx;ctx.move=M.project(b,u,ctx.move)
    end;return ctx
  end
  function M.bestowProof(b,u,t,m)
    local f=frames[b];local gen=M.epoch(b,u,m)
    if not f or not f.window or not f.declared or not f.ctx or f.ctx.user~=u or f.ctx.target~=t
      or f.user~=u or f.target~=t or not same(f.move,m)or m.id~='BESTOW'or not gen
      or not M.canBestow(b,u,t,m)then return end
    return{owner=M.OWNER,epoch=gen,profile=mode(b),item=opts.held(u.mon),
      sourceParty=index(b,u),targetParty=index(b,t),sourceSpecies=u.mon.species,targetSpecies=t.mon.species}
  end
  local function failure()return{tr('But, it failed!','Doch es schlug fehl!'),failed=true}end
  function M.cast(ctx)
    local b,u,t,m=ctx.battle,ctx.user,ctx.target,ctx.move;local f=frames[b];local gen=M.epoch(b,u,m)
    if not gen or not f or not f.declared or f.ctx~=ctx or f.user~=u or f.target~=t
      or not same(f.move,m)or not live(u)or not live(t)or not side(b,u)or not side(b,t)
      or u==t or not index(b,u)or not index(b,t)or t.invulnerable then return failure()end
    local priority=mod.exports.pokemonPriorityAbilities67
    if priority and priority.blocks(ctx)or guard(b,t,m,gen)then return failure()end
    if m.id=='BESTOW'then
      if not M.canBestow(b,u,t,m)then return failure()end
      assert(type(transfer.bestow)=='function','ItemAccess requires reviewed ItemTransfer.bestow owner')
      f.window=true;local out=pack(pcall(transfer.bestow,b,u,t,m));f.window=nil
      if not out[1]then error(out[2],0)end
      local id=out[2];if not id then return failure()end
      local d=b.data.items[id];local name=d and d.name or id
      return{tr('%s received\n%s!','%s erhält\n%s!'):format(t.name,name)}
    end
    if t.substituteHP or M.active(b,t)then return failure()end
    local turn=b.turnCount or 0
    rows(b,true)[side(b,t)]={party=index(b,t),species=t.mon.species,profile=mode(b),epoch=gen,
      applied=turn,expires=turn+4,lastTurn=turn-1}
    return{tr('%s cannot use\nitems!','%s kann keine\nItems einsetzen!'):format(t.name)}
  end
  function M.project(b,u,m)
    local gen=M.epoch(b,u,m);if not gen then return m end
    local out=copy(m);out.power=0;out.category='status';out.accuracy=100
    -- GenV Bestow is Protect-checked and cannot penetrate Substitute;
    -- VI+ bypasses Substitute and Protect. Its always-hit accuracy remains.
    out.flags=m.id=='EMBARGO'and{protect=1,reflectable=1,mirror=1,metronome=1}
      or gen==5 and{protect=1,mirror=1,noassist=1,failcopycat=1}
      or{mirror=1,bypasssub=1,allyanim=1,noassist=1,failcopycat=1}
    return out
  end
  function M.move(original,b,inst,...)
    local m=original(b,inst,...);if not owned(m)then return m end
    local f=frames[b];if f and f.inst==inst then return M.project(b,f.user,m)end
    for _,w in ipairs({b.player,b.enemy})do for _,s in ipairs(w and w.curMoves or{})do if s==inst then return M.project(b,w,m)end end end
    return m
  end
  function M.perform(original,b,u,t,inst,called,...)
    local m=inst and b:moveDef(inst)
    if not mode(b)or not owned(m)or not side(b,u)or not side(b,t)or not index(b,u)or not index(b,t)then
      return original(b,u,t,inst,called,...)end
    local prior=frames[b];frames[b]={user=u,target=t,inst=inst,move=m,called=called or false}
    local out=pack(pcall(original,b,u,t,inst,called,...));frames[b]=prior
    if not out[1]then error(out[2],0)end;return unpack(out,2,out.n)
  end
  function M.clear(b,w)local r=rows(b);if not r then return end
    if w then local lane=side(b,w);if lane then r[lane]=nil end else b.field.tokens[M.OWNER]=nil end
  end
  function M.endTurn(ev)
    local b=ev and ev.battle;local r=rows(b);if not r then return end
    local turn=b.turnCount or 0
    for _,lane in ipairs({'player','enemy'})do local row=r[lane];local w=b[lane]
      if row then
        if not valid(b,lane,row,w)or not live(w)then r[lane]=nil
        elseif row.lastTurn~=turn then row.lastTurn=turn
          if turn>=row.expires then r[lane]=nil;b:sayNext(tr('%s can use\nitems again!','%s kann wieder\nItems einsetzen!'):format(w.name))end
        end
      end
    end
  end
  function M.transfer(b,old,new)
    local lane=side(b,new);local r=rows(b);local row=lane and r and r[lane]
    if not mode(b)or not lane or old==new or not old or old.mon==new.mon
      or old.isPlayer~=new.isPlayer or not live(old)or not live(new)or not index(b,new)
      or not row or not valid(b,lane,row,old)then return false end
    local received=copy(row);received.party=index(b,new);received.species=new.mon.species
    passes[b]={lane=lane,previous=old,battler=new,row=received};return true
  end
  function M.switched(ev)
    local b=ev and ev.battle;local lane=b and side(b,ev.battler);local r=rows(b)
    if lane and r and ev.previous and ev.previous~=ev.battler and ev.previous.mon~=ev.battler.mon then r[lane]=nil end
  end
  function M.restorePass(ev)
    local b=ev and ev.battle;local p=b and passes[b]
    if not p then return end
    local baton=mod.exports.pokemonBatonPass67
    if baton and ev.sourceCard==baton.CARD_ID and ev.previous==p.previous and ev.battler==p.battler
      and b[p.lane]==p.battler and valid(b,p.lane,p.row,p.battler)then rows(b,true)[p.lane]=p.row end
    passes[b]=nil
  end
  function M.validateCheckpoint(b)
    if frames[b]or passes[b]then return false,'item_access_unsettled'end
    local r=rows(b);if r==nil then return true end
    if type(r)~='table'or not profile(b)then return false,'invalid_embargo_container'end
    for lane,row in pairs(r)do if not valid(b,lane,row,nil,profile(b))then return false,'invalid_embargo_receipt'end end
    return true
  end
  local implicit={X_ATTACK=true,X_DEFEND=true,X_SPEED=true,X_SPECIAL=true,X_ACCURACY=true,DIRE_HIT=true,GUARD_SPEC=true}
  function M.itemUse(original,data,save,id,target,b,...)
    if mode(b)and b.game and b.game.save==save and b.data==data and data.items[id]
      and(target==b.player.mon or not target and implicit[id])and M.blocksBag(b,b.player)then
      return'failed',{tr('Embargo prevents\nusing items!','Itemsperre verhindert\nden Itemeinsatz!')}
    end
    return original(data,save,id,target,b,...)
  end
  function M.trainerItem(original,b,id,...)
    if mode(b)and b.data.items[id]and M.blocksBag(b,b.enemy)then
      return{tr('Embargo prevents\nusing items!','Itemsperre verhindert\nden Itemeinsatz!')}
    end
    return original(b,id,...)
  end
  function M.enemyAction(original,b,...)
    local action=original(b,...)
    if not action or action.special~='aiItem'or not M.blocksBag(b,b.enemy)then return action end
    local hb=mod.exports.pokemonHealBlock67;local pool=hb and hb.usable(b,b.enemy)or{}
    local best=pool[1];for _,s in ipairs(pool)do local d=b:moveDef(s)
      if d and d.category~='status'and(d.power or 0)>0 then best=s;break end end
    return best or{id='STRUGGLE',pp=1,struggle=true}
  end
  function M.position(p,id)
    local anim=p.data and p.data.moveAnims and p.data.moveAnims[id]
    if not defs[id]or not anim or anim.source~=M.OWNER then return end
    local hud=assert(mod.exports.pokemonPartnerHits67)
    for _,step in ipairs(p.steps or{})do local sprites={};for i,s in ipairs(step.sprites or{})do local q=copy(s)
      if q.x>0 and q.x<168 and q.y>0 and q.y<160 and(q.y<16 or hud.inHud(q))then q.x=0 end;sprites[i]=q end;step.sprites=sprites end
  end
  function M.install()
    B._kascItemAccess67=M;FX._kascItemAccess67=M;Items._kascItemAccess67=M;AI._kascItemAccess67=M;Player._kascItemAccess67=M
    if B.performMove~=B._kascItemAccessPerform67 then local old=B.performMove;local w=function(...)return B._kascItemAccess67.perform(old,...)end
      B.performMove=w;B._kascItemAccessPerform67=w end
    if B.moveDef~=B._kascItemAccessMove67 then local old=B.moveDef;local w=function(...)return B._kascItemAccess67.move(old,...)end
      B.moveDef=w;B._kascItemAccessMove67=w end
    if FX.makeCtx~=FX._kascItemAccessContext67 then local old=FX.makeCtx;local w=function(...)return FX._kascItemAccess67.context(old,...)end
      FX.makeCtx=w;FX._kascItemAccessContext67=w end
    if Items.use~=Items._kascItemAccessUse67 then local old=Items.use;local w=function(...)return Items._kascItemAccess67.itemUse(old,...)end
      Items.use=w;Items._kascItemAccessUse67=w end
    if AI.useItem~=AI._kascItemAccessUse67 then local old=AI.useItem;local w=function(...)return AI._kascItemAccess67.trainerItem(old,...)end
      AI.useItem=w;AI._kascItemAccessUse67=w end
    if B.enemyAction~=B._kascItemAccessEnemy67 then local old=B.enemyAction;local w=function(...)return B._kascItemAccess67.enemyAction(old,...)end
      B.enemyAction=w;B._kascItemAccessEnemy67=w end
    if Player.start~=Player._kascItemAccessStart67 then local old=Player.start;local w=function(self,id,...)
      local out=pack(old(self,id,...));Player._kascItemAccess67.position(self,id);return unpack(out,1,out.n)end
      Player.start=w;Player._kascItemAccessStart67=w end
    local held=opts.heldEffect
    if held and not held._kascItemAccessWrapped67 then local suppress,blocks=held.suppressed,held.blocksMove
      held.suppressed=function(b,w,id)return M.itemSuppressed(b,w,id)or suppress(b,w,id)end
      held.blocksMove=function(b,w,id)return M.blocksMove(b,w,id)or blocks(b,w,id)end
      held._kascItemAccessWrapped67=true
    end
  end
  for id,d in pairs(defs)do local fact=assert(opts.facts.move(id,d.birth));local old=assert(mod.content.moves:get(id))
    assert(fact.number==d.number and fact.generation==d.birth and fact.power==0 and fact.category=='status'
      and fact.pp==15 and fact.target==10 and not old.backendMoveOwner,'item access source drift '..id)
    assert(old.effect=='KA_GEN_MOVE_UNSUPPORTED_'..id,'item access foreign effect '..id)
    local effect='KA_ITEM_ACCESS_67_'..id
    mod.content.move_effects:register(effect,{kind='primary',accuracyChecked=id=='EMBARGO',run=M.cast,kascItemAccess67=M.OWNER})
    mod.content.moves:patch(id,{effect=effect,backendMoveOwner=M.OWNER,backendMoveNumber=d.number,
      originGeneration=d.birth,backendLearnsetRevision=old.backendLearnsetRevision or 1})
    local anim=copy(assert(mod.content.battle_anims:get(d.anim)));anim.source=M.OWNER;mod.content.battle_anims:patch(id,anim)
    for i=#opts.catalog.unsupportedStatus,1,-1 do if opts.catalog.unsupportedStatus[i]==id then table.remove(opts.catalog.unsupportedStatus,i)end end
  end
  mod.content.move_effects:patch('HEAL_EFFECT',{kascItemAccess67=M.OWNER})
  mod.events:on('battle.move_used',M.used,95000)
  mod.events:on('battle.turn_ended',M.endTurn,95)
  mod.events:on('battle.battler_switched',M.switched,8000)
  mod.events:on('battle.battler_switched',M.restorePass,7999)
  mod.events:on('battle.fainted',function(ev)if ev.battle and ev.battler and ev.battler.mon.hp<=0 then M.clear(ev.battle,ev.battler)end end,8000)
  mod.events:on('battle.ended',function(ev)if ev and ev.battle then M.clear(ev.battle);passes[ev.battle]=nil end end,8100)
  M.install()
  if opts.supportLog and opts.supportLog.registerSegment then opts.supportLog.registerSegment({
    segmentId=M.CARD_ID,cardId=M.CARD_ID,schema='kasc.optional-feature-card/v1',version='1.0.0',owner=M.OWNER,active=true,
    dependencyStatus='native-declaration-held-effect-and-transaction-owners',providerStatus='embargo-and-lawful-bestow',
    buildReceiptId='docs/ITEM_ACCESS_67.md',rollbackReceiptId='docs/ITEM_ACCESS_67.md'})end
  return M
end
