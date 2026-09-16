-- HP assignments and an intentional self-cost are not direct attack hits.
return function(mod,opts)
  local B=require('src.battle.BattleState');local Stats=require('src.pokemon.Stats')
  local Effects=require('src.battle.MoveEffects');local Anim=require('src.battle.AnimPlayer')
  local M={CARD_ID='KASC-67-HP-EXCHANGE',OWNER='kasc.hp-exchange/v1'}
  local tr=opts.i18n.text
  local defs={PAIN_SPLIT={number=220,pp=20,target=10,parts={'RECOVER','PSYBEAM'}},
    BELLY_DRUM={number=187,pp=10,target=7,parts={'FOCUS_ENERGY','COMET_PUNCH'}}}
  local pending=setmetatable({},{__mode='k'})
  local function copy(v)if type(v)~='table'then return v end;local o={};for k,x in pairs(v)do o[k]=copy(x)end;return o end
  local function pack(...)return{n=select('#',...),...}end
  local function int(v,lo,hi)return type(v)=='number'and v%1==0 and v>=lo and v<=hi end
  local function side(b,w)return w==b.player and'player'or w==b.enemy and'enemy'end
  local function live(w)return w and w.mon and int(w.mon.hp,1,99999)and not w.fainted
    and not(w.mon.isEgg or w.mon.egg or w.mon.is_egg or w.mon.eggSpecies)end
  function M.epoch(b,move,w)
    local r=b and b.kascGenerationRulesReceipt
    local d=move and defs[move.id];local e=d and b.data and b.data.move_effects[move.effect]
    if getmetatable(b)~=B or b.demo or b.kind=='link'or b.result or not r or r.mode=='off'
        or not int(r.activeEpoch,1,7)or r.mode~='gen'..r.activeEpoch or not d
        or move.backendMoveOwner~=M.OWNER or move.backendMoveNumber~=d.number
        or not e or e.kascHpExchange67~=M.OWNER then return end
    if r.activeEpoch<2 and not(live(w)and opts.rules.ownedGiftBattleCompatible
        and opts.rules.ownedGiftBattleCompatible(b.game,w.mon,b.data.pokemon[w.mon.species]))then return end
    return math.max(2,r.activeEpoch)
  end
  function M.plan(b,u,t,move)
    local gen=M.epoch(b,move,u)
    if not gen or not live(u)or not side(b,u)or pending[b]
        or not u.mon.stats or not int(u.mon.stats.hp,1,99999)then return end
    if move.id=='PAIN_SPLIT'then
      if not live(t)or not side(b,t)or t==u or t.invulnerable or t.substituteHP
          or not t.mon.stats or not int(t.mon.stats.hp,1,99999)then return end
      local ctx={battle=b,user=u,target=t,move=move}
      if mod.exports.pokemonProtection67.blocks(ctx)or mod.exports.pokemonPriorityAbilities67.blocks(ctx)then return end
      local average=math.max(1,math.floor((u.mon.hp+t.mon.hp)/2))
      return{kind='assign',user=math.min(u.mon.stats.hp,average),target=math.min(t.mon.stats.hp,average)}
    end
    local old=u.stages and u.stages.attack or 0
    if not int(old,-6,6)or old>=6 then return end
    if u.mon.hp<=u.mon.stats.hp/2 or u.mon.stats.hp==1 then
      if gen==2 then return{kind='failed-boost',delta=2}end
      return
    end
    local delta=12
    if gen==2 then
      if not u.curStats or not int(u.curStats.attack,1,9999)then return end
      -- GSC tests the old stage's capped Attack at each two-stage step.
      -- A failed low-HP attempt still gives +2; that bug does not persist III+.
      local current=old
      while current<6 do
        local previous=current;current=math.min(6,current+2)
        if Stats.applyStage(u.curStats.attack,previous)>=999 then current=current-1;break end
      end
      delta=current-old
    end
    return{kind='cost-boost',cost=math.floor(u.mon.stats.hp/2),delta=delta}
  end
  function M.noUseful(b,u,t,move)
    if not M.epoch(b,move,u)then return false end
    return opts.abilities.moveScope(b,u,t,true,function()
      local p=M.plan(b,u,t,move);if not p then return true end
      if p.kind=='assign'then return p.user<=u.mon.hp and p.target>=t.mon.hp end
      local delta=opts.abilities.stageDelta(b,u,p.delta)
      local old=u.stages and u.stages.attack or 0
      return delta<=0 or old>=6 or p.kind=='cost-boost'and u.mon.hp-p.cost<=u.mon.stats.hp/4
    end,move)
  end
  local function failed()return{tr('But, it failed!','Doch es schlug fehl!'),failed=true}end
  -- sethp is not a heal: Heal Block, Liquid Ooze and heal multipliers do not
  -- affect it. Decreases still reach the genuine HP-loss observer, but never
  -- accumulate Substitute/Bide damage or emit an invented direct-hit event.
  local function assign(b,w,hp)
    if hp<w.mon.hp then
      local sub,bide,rage=w.substituteHP,w.bideTurns,w.rageMove
      w.substituteHP,w.bideTurns,w.rageMove=nil,nil,nil
      local out=pack(pcall(b.applyDamage,b,w,w.mon.hp-hp))
      w.substituteHP,w.bideTurns,w.rageMove=sub,bide,rage
      if not out[1]then error(out[2],0)end
    else w.mon.hp=hp end
  end
  function M.cast(ctx)
    local b,u,t=ctx.battle,ctx.user,ctx.target;local p=M.plan(b,u,t,ctx.move)
    if not p then return failed()end
    pending[b]=true
    local out=pack(pcall(function()
      if p.kind=='assign'then
        assign(b,t,p.target);assign(b,u,p.user)
        return{tr('The battlers shared their pain!','Die Pokémon teilen ihr Leid!')}
      end
      if p.cost then assign(b,u,u.mon.hp-p.cost)end
      local rows=Effects.changeStage(b,u,'attack',p.delta,false)
      if p.kind=='failed-boost'then rows[#rows+1]=failed()[1];rows.failed=true end
      return rows
    end))
    pending[b]=nil;if not out[1]then error(out[2],0)end
    return out[2]
  end
  function M.validateCheckpoint(b)return not pending[b],'hp_exchange_unsettled'end
  for id,d in pairs(defs)do
    local f=assert(opts.facts.move(id,2));local old=assert(mod.content.moves:get(id))
    assert(f.number==d.number and f.generation==2 and f.pp==d.pp and f.category=='status'
      and f.power==0 and f.alwaysHits and f.target==d.target,'HP exchange source drift '..id)
    assert(not old.backendMoveOwner and old.effect=='KA_GEN_MOVE_UNSUPPORTED_'..id,'foreign HP exchange owner '..id)
    local effect='KA_HP_EXCHANGE_67_'..id
    mod.content.move_effects:register(effect,{kind='primary',accuracyChecked=false,run=M.cast,kascHpExchange67=M.OWNER})
    local flags={metronome=1};if id=='PAIN_SPLIT'then flags.protect=1;flags.mirror=1 else flags.snatch=1 end
    mod.content.moves:patch(id,{effect=effect,backendMoveOwner=M.OWNER,backendMoveNumber=d.number,
      backendLearnsetRevision=old.backendLearnsetRevision or 1,power=0,pp=d.pp,accuracy=100,
      category='status',target=d.target,flags=flags,originGeneration=2})
    local anim={source=M.OWNER,seq={}}
    for _,part in ipairs(d.parts)do for _,step in ipairs(assert(mod.content.battle_anims:get(part)).seq)do anim.seq[#anim.seq+1]=copy(step)end end
    mod.content.battle_anims:patch(id,anim)
    for i=#opts.catalog.unsupportedStatus,1,-1 do if opts.catalog.unsupportedStatus[i]==id then table.remove(opts.catalog.unsupportedStatus,i)end end
  end
  function M.position(player,id)
    local a=player.data and player.data.moveAnims and player.data.moveAnims[id]
    if not defs[id]or not a or a.source~=M.OWNER then return end
    for _,step in ipairs(player.steps or{})do local sprites={};for i,s in ipairs(step.sprites or{})do local q=copy(s)
      if q.x>0 and q.x<168 and q.y>0 and q.y<160 and mod.exports.pokemonPartnerHits67.inHud(q)then q.x=0 end
      sprites[i]=q end;step.sprites=sprites end
  end
  function M.install()
    Anim._kascHpExchange67=M
    if not Anim._kascHpExchangeWrapped67 then local original=Anim.start
      Anim.start=function(self,id,...)local out=pack(original(self,id,...));Anim._kascHpExchange67.position(self,id);return unpack(out,1,out.n)end
      Anim._kascHpExchangeWrapped67=true end
  end
  M.install()
  if opts.supportLog and opts.supportLog.registerSegment then opts.supportLog.registerSegment({segmentId=M.CARD_ID,
    cardId=M.CARD_ID,schema='kasc.optional-feature-card/v1',version='1.0.0',owner=M.OWNER,active=true,
    dependencyStatus='native-hp-assignment-stage-and-actual-status-action',providerStatus='pain-split-and-era-belly-drum',
    buildReceiptId='docs/HP_EXCHANGE_67.md',rollbackReceiptId='docs/HP_EXCHANGE_67.md'})end
  return M
end
