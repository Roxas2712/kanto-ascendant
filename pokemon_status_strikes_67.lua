-- Two real move effects: a conditional body cure, and an if-hit self KO.
return function(mod,opts)
  local B=require('src.battle.BattleState');local FX=require('src.battle.EffectRegistry')
  local M={CARD_ID='KASC-67-STATUS-STRIKES',OWNER='kasc.status-strikes/v1'}
  local frames=setmetatable({},{__mode='k'});local tr=opts.i18n.text
  local defs={MEMENTO={number=262},SMELLING_SALTS={number=265}}
  local function pack(...)return{n=select('#',...),...}end
  local function shallow(v)local r={};for k,x in pairs(v or{})do r[k]=x end;return r end
  local function live(w)local p=w and w.mon;return p and(tonumber(p.hp)or 0)>0 and not w.fainted
    and not(p.isEgg or p.egg or p.is_egg or p.eggSpecies)end
  local function side(b,w)return w==b.player and'player'or w==b.enemy and'enemy'or nil end
  function M.epoch(b,u,move)
    local r=b and b.kascGenerationRulesReceipt;local h=b and b.data and b.data.move_effects and b.data.move_effects.HEAL_EFFECT
    if getmetatable(b)~=B or b.demo or b.kind=='link'or b.result or not r or r.mode=='off'
        or type(r.activeEpoch)~='number'or r.activeEpoch%1~=0 or r.activeEpoch<1 or r.activeEpoch>7
        or not h or h.kascStatusStrikes67~=M.OWNER then return end
    if not move then return r.activeEpoch end
    local d=defs[move.id];local rec=d and b.data.move_effects[move.effect]
    if not d or move.backendMoveOwner~=M.OWNER or move.backendMoveNumber~=d.number or not rec or rec.kascStatusStrikes67~=M.OWNER then return end
    if r.activeEpoch<3 and not(live(u)and side(b,u)and opts.rules.monMoveAvailable(b.game,u.mon,move.id,r.activeEpoch,true))then return end
    return math.max(3,r.activeEpoch)
  end
  function M.power(b,u,t,move)
    local gen=M.epoch(b,u,move)
    if not gen or move.id~='SMELLING_SALTS'or not live(u)or not live(t)or not side(b,u)or not side(b,t)or u==t then return end
    return(gen<=5 and 60 or 70)*(t.mon.status=='PAR'and 2 or 1)
  end
  function M.damage(nextDamage,ctx)
    local power=ctx and ctx.move and M.power(ctx.battle,ctx.user,ctx.target,ctx.move)
    if not power or ctx.opts and ctx.opts.typeless then return nextDamage(ctx)end
    local out=shallow(ctx);out.move=shallow(ctx.move);out.move.power=power
    return nextDamage(out)
  end
  function M.salt(ctx)
    local f=frames[ctx.battle]
    if not f or f.user~=ctx.user or f.target~=ctx.target or f.move.id~='SMELLING_SALTS'
        or ctx.move.id~='SMELLING_SALTS'or not M.epoch(ctx.battle,ctx.user,ctx.move)
        or ctx.totalDealt==nil or ctx.brokeSub or ctx.target.substituteHP or ctx.target.mon.status~='PAR'then return end
    ctx.target.mon.status=nil;ctx.target.toxicCounter=nil
    mod.exports.pokemonStatusLifecycle67.clear(ctx.target,ctx.battle)
    ctx.battle:sayNext(tr('%s is no longer paralyzed!','%s ist nicht mehr paralysiert!'):format(ctx.target.name))
  end
  local function fail(ctx)
    ctx.battle:cancelMoveAnim();ctx.battle:sayNext(tr('But, it failed!','Doch es schlug fehl!'))
  end
  function M.memento(ctx)
    local b,u,t,move=ctx.battle,ctx.user,ctx.target,ctx.move;local gen=M.epoch(b,u,move);local f=frames[b]
    if not gen or not f or f.user~=u or f.target~=t or f.move.id~=move.id or not live(u)or not live(t)or u==t
        or not side(b,u)or not side(b,t)or t.invulnerable or t.substituteHP then return fail(ctx)end
    local protect=mod.exports.pokemonProtection67;local priority=mod.exports.pokemonPriorityAbilities67
    if protect.blocks(ctx)then b:cancelMoveAnim();b:sayNext(protect.notice(ctx,true));return end
    if priority.blocks(ctx)or gen>=4 and not ctx.accuracyRoll()then return fail(ctx)end
    -- Gen III is genuinely always-hit. If-hit selfdestruct is independent
    -- of whether Mist/Clear Body/stat caps permit the actual boost change.
    local split=mod.exports.backendSplitSpecial67
    for _,stat in ipairs({'attack','specialAttack'})do
      for _,msg in ipairs(split.changeStage(ctx,t,stat,-2,true))do b:sayNext(msg)end
    end
    mod.exports.pokemonFatalConditions67.directLoss(b,u,u.mon.hp)
    ctx.drain()
  end
  function M.noUseful(b,u,t,move)
    if not M.epoch(b,u,move)or move.id~='MEMENTO'then return false end
    if not live(u)or not live(t)or u==t or t.substituteHP or t.invulnerable then return true end
    local stages=t.stages or{}
    return(stages.attack or 0)<=-6 and(stages.specialAttack or 0)<=-6
  end
  function M.perform(original,b,u,t,slot,...)
    local move=slot and b:moveDef(slot)
    if not move or not M.epoch(b,u,move)then return original(b,u,t,slot,...)end
    local previous=frames[b];frames[b]={user=u,target=t,move=move}
    local out=pack(pcall(original,b,u,t,slot,...));frames[b]=previous
    if not out[1]then error(out[2],0)end;return unpack(out,2,out.n)
  end
  function M.validateCheckpoint(b)return not frames[b],'status_strike_unsettled'end
  for id,d in pairs(defs)do
    local f=assert(opts.facts.move(id,7));local old=assert(mod.content.moves:get(id))
    assert(f.number==d.number and f.generation==3 and not old.backendMoveOwner,'status strike source/owner drift '..id)
    local effect='KA_STATUS_STRIKE_67_'..id
    local rec={kascStatusStrikes67=M.OWNER}
    if id=='MEMENTO'then rec.kind='primary';rec.perform=M.memento
    else rec.kind='secondary';rec.afterDamage=M.salt end
    mod.content.move_effects:register(effect,rec)
    mod.content.moves:patch(id,{effect=effect,backendMoveOwner=M.OWNER,backendMoveNumber=d.number,
      backendLearnsetRevision=old.backendLearnsetRevision or 1,originGeneration=3})
    assert(mod.content.battle_anims:get(id),'status strike lacks existing native animation '..id)
  end
  mod.content.move_effects:patch('HEAL_EFFECT',{kascStatusStrikes67=M.OWNER})
  mod.hooks:wrap('battle.damage',M.damage,31545)
  function M.install()
    B._kascStatusStrikes67=M
    if not B._kascStatusStrikesWrapped67 then local perform=B.performMove
      B.performMove=function(...)return B._kascStatusStrikes67.perform(perform,...)end
      B._kascStatusStrikesWrapped67=true end
  end
  M.install()
  if opts.supportLog and opts.supportLog.registerSegment then opts.supportLog.registerSegment({
    segmentId=M.CARD_ID,cardId=M.CARD_ID,schema='kasc.optional-feature-card/v1',version='1.0.0',owner=M.OWNER,
    active=true,dependencyStatus='native-fx-status-cure-and-if-hit-self-faint',providerStatus='memento-and-smelling-salts',
    buildReceiptId='docs/STATUS_STRIKES_67.md',rollbackReceiptId='docs/STATUS_STRIKES_67.md'})end
  return M
end
