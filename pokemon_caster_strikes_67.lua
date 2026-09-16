-- Source-specific caster checks and Fell Stinger's genuine knockout boost.
-- Original sleep/stat/protection records are preserved as private clones.
return function(mod,opts)
  local B=require('src.battle.BattleState');local FX=require('src.battle.EffectRegistry')
  local M={CARD_ID='KASC-67-CASTER-STRIKES',OWNER='kasc.caster-strikes/v1'}
  local rules,facts,species,identity=assert(opts.rules),assert(opts.facts),assert(opts.species),assert(opts.identity)
  local tr=opts.i18n.text;local frames=setmetatable({},{__mode='k'})
  local strikes=setmetatable({},{__mode='k'})
  local defs={FELL_STINGER={number=565,birth=6},DARK_VOID={number=464,birth=4},
    HYPERSPACE_FURY={number=621,birth=6}}
  local originals={}
  local function copy(v)if type(v)~='table'then return v end;local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r end
  local function shallow(v)local r={};for k,x in pairs(v or{})do r[k]=x end;return r end
  local function pack(...)return{n=select('#',...),...}end
  local function int(v,a,z)return type(v)=='number'and v%1==0 and v>=a and v<=z end
  local function live(w)local p=w and w.mon;return p and int(p.hp,1,999999)and not w.fainted
    and not(p.egg or p.isEgg or p.is_egg or p.eggSpecies or p.species=='EGG')end
  local function side(b,w)return b and w and w.mon and b.player and b.enemy
    and(w==b.player and'player'or w==b.enemy and'enemy')end
  -- Damage forecasts carry detached stat views. Canonicalize only this
  -- read-only adapter, never public cast/source proof or native scopes.
  local function actual(b,w)
    if side(b,w)then return w end
    if b and w and w.mon then for _,p in ipairs({b.player,b.enemy})do
      if p and p.mon==w.mon then return p end end end
  end
  local function party(b,key)return key=='player'and b:playerPartyView()or key=='enemy'and(b.enemyParty or{b.enemy.mon})end
  local function index(b,w)local key=side(b,w);for i,p in ipairs(party(b,key)or{})do
    if i<=6 and p==w.mon then return i end end end
  local function mode(b)local r=b and b.kascGenerationRulesReceipt
    local marker=b and b.data and b.data.move_effects and b.data.move_effects.HEAL_EFFECT
    if getmetatable(b)~=B or b.demo or b.kind=='link'or b.result or type(r)~='table'
      or not int(r.activeEpoch,1,7)or not(r.mode=='auto'or r.mode=='gen'..r.activeEpoch)
      or not marker or marker.kascCasterStrikes67~=M.OWNER then return end;return r.activeEpoch end
  local function owned(move)local d=move and defs[move.id];return d and move.backendMoveOwner==M.OWNER
    and move.backendMoveNumber==d.number and d or nil end
  local function same(a,z)return a and z and owned(a)and owned(z)and a.id==z.id and a.effect==z.effect end
  function M.epoch(b,u,move)
    local gen=mode(b);if not move then return gen end
    local d=owned(move);local rec=gen and d and b.data and b.data.move_effects[move.effect]
    if not gen or not d or not rec or rec.kascCasterStrikes67~=M.OWNER then return end
    if gen<d.birth and not(live(u)and index(b,u)
      and rules.monMoveAvailable(b.game,u.mon,move.id,gen,true))then return end
    return math.max(gen,d.birth)
  end
  function M.identityKey(b,w)
    local lane=side(b,w);w=lane and b[lane]or w
    local current=identity.current(b,w);if not current then return end
    local key=identity.formKey(b,w)or species.bySpecies[current]
    local catalog=opts.catalog.entries[key]
    if not catalog then return end
    -- The canonical catalog/form owner, not a display nickname or sprite.
    return key,catalog
  end
  local function reflected(b,u,move)
    local bounce=mod.exports and mod.exports.pokemonMagicBounce67
    return bounce and bounce.reflectionSource(b,u,move)~=nil or false
  end
  function M.canCast(b,u,t,move)
    -- Inactive cards preserve native fallback; an active but unlicensed
    -- forced future move must not acquire a new per-Pokemon exception.
    if not mode(b)or not owned(move)then return true end
    local gen=M.epoch(b,u,move)
    if not gen or not live(u)or not live(t)or u.mon==t.mon or not index(b,u)or not index(b,t)then return false end
    if move.id=='FELL_STINGER'then return true end
    local key,row=M.identityKey(b,u)
    if move.id=='DARK_VOID'then
      return gen<7 or reflected(b,u,move)
        or key=='dex:491'and row.nationalDex==491 and row.identifier=='darkrai'and row.isBase~=false or false
    end
    return key=='form:10086'and row.nationalDex==720 and row.identifier=='hoopa-unbound'and row.isBase==false or false
  end
  function M.noUseful(b,u,t,move)
    return mode(b)~=nil and owned(move)~=nil and not M.canCast(b,u,t,move)or false
  end
  function M.project(b,u,move)
    local gen=M.epoch(b,u,move);if not gen then return move end
    local fact=assert(facts.move(move.id,gen),'caster strike missing source era')
    if move.power==fact.power and move.pp==fact.pp and move.accuracy==fact.accuracy
      and move.category==fact.category then return move end
    local out=shallow(move);out.power=fact.power;out.pp=fact.pp;out.accuracy=fact.accuracy;out.category=fact.category
    return out
  end
  function M.move(nextMove,b,inst,...)
    local move=nextMove(b,inst,...);if not owned(move)then return move end
    local frame=frames[b]
    if frame and frame.inst==inst then return M.project(b,frame.user,move)end
    for _,w in ipairs({b.player,b.enemy})do for _,slot in ipairs(w and w.curMoves or{})do
      if slot==inst then return M.project(b,w,move)end end end;return move
  end
  function M.damage(nextDamage,ctx)
    if not ctx or not owned(ctx.move)or not mode(ctx.battle)
      or ctx.opts and(ctx.opts.typeless or ctx.opts.typelessDamage)then return nextDamage(ctx)end
    local user,target=actual(ctx.battle,ctx.user),actual(ctx.battle,ctx.target)
    if not user or not target or not M.canCast(ctx.battle,user,target,ctx.move)then
      return 0,{crit=false,typeMult=10,missed=true}end
    local move=M.project(ctx.battle,user,ctx.move);if move==ctx.move then return nextDamage(ctx)end
    local out=shallow(ctx);out.move=move;return nextDamage(out)
  end
  function M.fail(ctx)
    ctx.battle:cancelMoveAnim();ctx.battle:sayNext(tr('But, it failed!','Doch es schlug fehl!'))
  end
  function M.used(ev)local f=ev and frames[ev.battle]
    if f and f.user==ev.user and f.target==ev.target and same(f.move,ev.move)
      and ev.isCalled==f.called then f.declared=true end
  end
  function M.context(nextCtx,b,u,t,...)
    local ctx=nextCtx(b,u,t,...);local f=frames[b]
    if f and f.declared and f.user==u and f.target==t and same(f.move,ctx.move)then
      f.reached=true;ctx.move=M.project(b,u,ctx.move)
    end;return ctx
  end
  function M.perform(original,b,u,t,inst,called,...)
    local move=inst and b:moveDef(inst)
    if not mode(b)or not owned(move)or u~=b[side(b,u)]or t~=b[side(b,t)]or not index(b,u)or not index(b,t)then
      return original(b,u,t,inst,called,...)end
    local previous=frames[b];local f={user=u,target=t,move=move,inst=inst,called=called or false};frames[b]=f
    local raw,old=rawget(b,'effectRecord'),b.effectRecord
    b.effectRecord=function(self,id)
      local record=old(self,id)
      if id~=move.effect or not record then return record end
      -- Defer onTry to genuine native dispatch after PP/declaration and
      -- makeCtx, but before ordinary status accuracy or damaging checks.
      local proxy={};for k,v in pairs(record)do if k~='perform'then proxy[k]=v end end
      return setmetatable(proxy,{__index=function(_,key)
        if key=='perform'and f.declared and f.reached and not M.canCast(b,u,t,move)then return M.fail end
        return record[key]
      end})
    end
    local out=pack(pcall(original,b,u,t,inst,called,...))
    b.effectRecord=raw;frames[b]=previous
    if not out[1]then error(out[2],0)end;return unpack(out,2,out.n)
  end
  function M.hit(ev)
    local f=ev and strikes[ev.battle];local frame=ev and frames[ev.battle]
    local body=mod.exports and mod.exports.pokemonBodyCounter67
    local proof=body and body.nativeHit(ev.battle,ev)
    if f and frame and frame.declared and frame.reached and f.ctx.user==ev.user and f.ctx.target==ev.target
      and same(f.ctx.move,ev.move)and proof and proof.direct and not proof.substitute
      and proof.damage>0 and ev.target.mon.hp<=0 then f.bodyKO=true end
  end
  function M.faint(ev)
    local f=ev and strikes[ev.battle]
    if f and f.bodyKO and f.ctx.target==ev.battler and ev.battler.mon.hp<=0
      and ev.battler.faintQueued==true then f.fainted=true end
  end
  function M.furyAfterDamage(ctx,total)
    local b=ctx and ctx.battle;local f=b and strikes[b]
    -- Native secondary.run intentionally skips a defeated recipient.
    -- Fury's self drop still belongs to the genuine body's afterDamage
    -- phase, before onFaint. No public event or standalone FX proof fits.
    if not f or f.ctx~=ctx or f.furyDrop or ctx.move.id~='HYPERSPACE_FURY'
      or not f.bodyKO or not(type(total)=='number'and total>0)
      or ctx.target.mon.hp>0 or not M.epoch(b,ctx.user,ctx.move)
      or not live(ctx.user)or not index(b,ctx.user)then return end
    f.furyDrop=true
    for _,message in ipairs(assert(opts.split).changeStage(ctx,ctx.user,'defense',-1,false))do b:sayNext(message)end
  end
  function M.run(original,b,ctx,record)
    local frame=frames[b]
    if not ctx or not(ctx.move.id=='FELL_STINGER'or ctx.move.id=='HYPERSPACE_FURY')or not M.epoch(b,ctx.user,ctx.move)
      or not frame or not frame.declared or not frame.reached or frame.user~=ctx.user or frame.target~=ctx.target
      or not same(frame.move,ctx.move)then return original(b,ctx,record)end
    local previous=strikes[b];local f={ctx=ctx};strikes[b]=f
    -- Fury's own canonical VI+ effect bypasses the recipient's doll, even
    -- for an authenticated older gift. Only this actual declared, licensed
    -- caster scope does so: no global native-I Substitute change and no
    -- permission for a standalone FX forecast/public event.
    local target=ctx.target;local sub=ctx.move.id=='HYPERSPACE_FURY'and M.canCast(b,ctx.user,target,ctx.move)
      and target.substituteHP or nil
    if sub~=nil then target.substituteHP=nil end
    local out=pack(pcall(original,b,ctx,record));strikes[b]=previous
    if sub~=nil and live(target)and index(b,target)then target.substituteHP=sub end
    if not out[1]then error(out[2],0)end
    -- KO proof requires both the private body-hit and actual native faint
    -- inside this dispatch. Contact recoil/Destiny Bond can kill the user;
    -- a dead source must not receive the post-move boost.
    if ctx.move.id=='FELL_STINGER'and f.bodyKO and f.fainted and live(ctx.user)and index(b,ctx.user)then
      local gen=M.epoch(b,ctx.user,ctx.move);local split=assert(opts.split)
      for _,message in ipairs(split.changeStage(ctx,ctx.user,'attack',gen>=7 and 3 or 2,false))do b:sayNext(message)end
    end
    return unpack(out,2,out.n)
  end
  function M.validateCheckpoint(b)return not frames[b]and not strikes[b],'caster_strikes_unsettled'end
  for id,d in pairs(defs)do
    local f=assert(facts.move(id,7));local old=assert(mod.content.moves:get(id))
    assert(f.number==d.number and f.generation==d.birth and not old.backendMoveOwner,'caster strike source/owner drift '..id)
    local source=assert(mod.content.move_effects:get(old.effect));originals[id]={id=old.effect,record=copy(source)}
    local effect='KA_CASTER_STRIKE_67_'..id;local record=copy(source);record.kascCasterStrikes67=M.OWNER
    -- Preserve native run/afterDamage/charge/etc. The cast-specific onTry
    -- proxy and read-only forecast gates are independent of those owners.
    if id=='HYPERSPACE_FURY'then
      local after=record.afterDamage
      record.afterDamage=function(ctx,total)
        if after then after(ctx,total)end
        M.furyAfterDamage(ctx,total)
      end
    end
    mod.content.move_effects:register(effect,record)
    mod.content.moves:patch(id,{effect=effect,backendMoveOwner=M.OWNER,backendMoveNumber=d.number,
      originGeneration=d.birth,backendLearnsetRevision=old.backendLearnsetRevision or 1})
    assert(mod.content.battle_anims:get(id),'caster strike lacks existing native animation '..id)
  end
  M.originalEffects=originals
  mod.content.move_effects:patch('HEAL_EFFECT',{kascCasterStrikes67=M.OWNER})
  mod.hooks:wrap('battle.damage',M.damage,31661)
  mod.events:on('battle.move_used',M.used,95000)
  mod.events:on('battle.damage_dealt',M.hit,95000)
  mod.events:on('battle.fainted',M.faint,95000)
  function M.install()
    B._kascCasterStrikes67=M;FX._kascCasterStrikes67=M
    if B.moveDef~=B._kascCasterStrikesMove67 then local move=B.moveDef
      local wrapper=function(...)return B._kascCasterStrikes67.move(move,...)end
      B.moveDef=wrapper;B._kascCasterStrikesMove67=wrapper end
    if B.performMove~=B._kascCasterStrikesPerform67 then local perform=B.performMove
      local wrapper=function(...)return B._kascCasterStrikes67.perform(perform,...)end
      B.performMove=wrapper;B._kascCasterStrikesPerform67=wrapper end
    if FX.makeCtx~=FX._kascCasterStrikesContext67 then local make=FX.makeCtx
      local wrapper=function(...)return FX._kascCasterStrikes67.context(make,...)end
      FX.makeCtx=wrapper;FX._kascCasterStrikesContext67=wrapper end
    if FX.runDamaging~=FX._kascCasterStrikesRun67 then local run=FX.runDamaging
      local wrapper=function(...)return FX._kascCasterStrikes67.run(run,...)end
      FX.runDamaging=wrapper;FX._kascCasterStrikesRun67=wrapper end
  end
  M.install()
  if opts.supportLog and opts.supportLog.registerSegment then opts.supportLog.registerSegment({
    segmentId=M.CARD_ID,cardId=M.CARD_ID,schema='kasc.optional-feature-card/v1',version='1.0.0',owner=M.OWNER,
    active=true,dependencyStatus='private-native-body-faint-and-canonical-caster',providerStatus='fell-stinger-dark-void-hyperspace-fury',
    buildReceiptId='docs/CASTER_STRIKES_67.md',rollbackReceiptId='docs/CASTER_STRIKES_67.md'})end
  return M
end
