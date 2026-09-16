-- A Gem powers the whole move, even after the held item is consumed.
-- Previews project the future empty slot; only a real hit commits it.
return function(mod,opts)
  local B=require('src.battle.BattleState');local FX=require('src.battle.EffectRegistry')
  local M={CARD_ID='KASC-67-GEMS',OWNER='kasc.gems/v1'}
  local scopes=setmetatable({},{__mode='k'})
  local names={NORMAL='NORMAL',FIRE='FEUER',WATER='WASSER',ELECTRIC='ELEKTRO',GRASS='PFLANZEN',
    ICE='EIS',FIGHTING='KAMPF',POISON='GIFT',GROUND='BODEN',FLYING='FLUG',PSYCHIC='PSYCHO',
    BUG='KAEFER',ROCK='GESTEINS',GHOST='GEIST',DRAGON='DRACHEN',DARK='UNLICHT',STEEL='STAHL',FAIRY='FEEN'}
  local function pack(...)return {n=select('#',...),...}end
  local function copy(v)local r={};for k,x in pairs(v or{})do r[k]=x end;return r end
  function M.itemMetadata(id)
    local typ=type(id)=='string'and id:match('^(%u+)_GEM$')
    if typ and names[typ]then return {id=id,generation=typ=='FAIRY'and 6 or 5,
      names={en=typ..' GEM',de=names[typ]..'JUWEL'},flags={'holdable','holdable-passive'}}end
  end
  for typ in pairs(names)do
    local id=typ..'_GEM';local meta=M.itemMetadata(id);local epochs={}
    for gen=meta.generation,7 do epochs[gen]=true end
    local fields={kascGem67=M.OWNER,kascEquipmentRewardEpochs=epochs}
    if mod.content.items:get(id)then mod.content.items:patch(id,fields)
    else
      fields.id=id;fields.names=meta.names;fields.name=opts.i18n.text(meta.names.en,meta.names.de)
      fields.price=0;fields.keyItem=false;fields.field=false;fields.battle=false
      mod.content.items:register(id,fields)
    end
  end
  function M.supportsItem(game,id,gen)
    local meta=M.itemMetadata(id);local data=game and game.data
    local item=data and data.items and data.items[id]
    local marker=data and data.move_effects and data.move_effects.HEAL_EFFECT
    return meta and item and item.kascGem67==M.OWNER and marker and marker.kascGem67==M.OWNER
      and type(gen)=='number'and gen%1==0 and gen>=meta.generation and gen<=7 or false
  end
  function M.epoch(b)
    local gen=b and opts.status.epoch(b)
    if getmetatable(b)==B and not b.demo and b.kind~='link'and not b.result
        and gen and gen>=5 and gen<=7 then return gen end
  end
  function M.match(b,u,move)
    local gen=M.epoch(b)
    if not gen or not u or not u.mon or u.mon.hp<=0 or not move or not names[move.type]or move.category=='status'
        or move.id=='STRUGGLE'or move.id=='FUTURE_SIGHT'or move.id=='DOOM_DESIRE'
        or move.id=='FLING'or move.pledgecombo then return end
    local id,err=opts.held(u.mon,b,u)
    if not err and M.supportsItem(b.game,id,gen)and id==move.type..'_GEM'then return id,gen end
  end
  function M.emptyAfterHit(b,u,move)
    return M.match(b,u,move)~=nil
  end
  function M.projectedSpeed(b,u,move)
    if M.emptyAfterHit(b,u,move)then return opts.weather.speed(b,u,1,true)end
  end
  function M.damage(nextDamage,ctx)
    if not ctx or not ctx.user or not ctx.move or ctx.opts and ctx.opts.typeless then return nextDamage(ctx)end
    local b,u,move=ctx.battle,ctx.user,ctx.move
    local id,gen=M.match(b,u,move);local scope=scopes[b]
    local used=scope and scope.user.mon==u.mon and scope.used and scope.moveId==move.id
    if (not id and not used)or (tonumber(move.power)or 0)<=0 then return nextDamage(ctx)end
    local adjusted=copy(ctx);adjusted.opts=copy(ctx.opts)
    adjusted.opts.kascGemPower67=(gen or scope.gen)==5 and 6144 or 5325
    return nextDamage(adjusted)
  end
  function M.hit(original,b,ctx,record)
    local scope=scopes[b]
    if not scope or scope.user~=ctx.user or ctx.user==ctx.target then return original(b,ctx,record)end
    local raw,prior=rawget(b,'applyDamage'),b.applyDamage
    local rawCompute,compute=rawget(b,'computeDamage'),b.computeDamage
    local function commit()
      if scope.used then return end
      local id=M.match(b,ctx.user,ctx.move)
      if id then
        scope.used=id;scope.moveId=ctx.move.id
        ctx.user.mon.item=nil;ctx.user.mon.heldItem=nil
        opts.abilities.onItemLost(b,ctx.user,id,scope.gen>=7)
        b:sayNext(opts.i18n.text('Gem activated!','Juwel aktiviert!'))
      end
    end
    local symbiosis=mod.exports and mod.exports.pokemonSymbiosis67
    if scope.gen==6 and symbiosis and symbiosis.hasSource(b,ctx.user)then
      b.computeDamage=function(self,u,t,move,options)
        if u==ctx.user and t==ctx.target and t.mon.hp>0 and not scope.used and M.match(self,u,move)then
          -- This call site is after native accuracy and effect gates. Use
          -- the existing side-effect-free preview chain to reject type /
          -- ability immunity without spending battle RNG or a Gem. Then
          -- perform the sole real roll with the newly donated item.
          local probe=copy(options);probe.forceCrit=false
          probe.rng=function(lo,hi)return hi or lo end
          local amount,info=compute(self,u,t,move,probe)
          if amount>0 and info and info.typeMult~=0 and not info.missed then commit()end
        end
        return compute(self,u,t,move,options)
      end
    end
    b.applyDamage=function(self,w,amount)
      -- Native accuracy, move gates and immunity have already succeeded.
      -- Commit before damage/contact so Thief/Magician see an empty slot.
      local incoming=opts.survival.incomingHit(self,w)
      if w==ctx.target and w.mon.hp>0 and (amount>0 or incoming) and not scope.used then
        commit()
      end
      return prior(self,w,amount)
    end
    local result=pack(pcall(original,b,ctx,record));b.applyDamage=raw;b.computeDamage=rawCompute
    if not result[1]then error(result[2],0)end
    return unpack(result,2,result.n)
  end
  function M.perform(original,b,u,t,...)
    local gen=M.epoch(b)
    if not gen or not u or not t or u==t then return original(b,u,t,...)end
    local prior=scopes[b];local scope={user=u,gen=gen};scopes[b]=scope
    local result=pack(pcall(original,b,u,t,...));scopes[b]=prior
    if not result[1]then error(result[2],0)end
    -- VII moved Symbiosis after the entire triggering attack, including
    -- the old held item's after-move cost. Never consume a donated Gem in
    -- the same move or grant a new Life Orb retroactive damage/recoil.
    if gen>=7 and scope.used then opts.abilities.afterItemConsumed(b,u,scope.used)end
    return unpack(result,2,result.n)
  end
  B._kascGems67=M;FX._kascGems67=M
  if not B._kascGemsWrapped67 then
    local old=B.performMove
    B.performMove=function(b,u,t,...)return B._kascGems67.perform(old,b,u,t,...)end
    B._kascGemsWrapped67=true
  end
  if not FX._kascGemsWrapped67 then
    local old=FX.runDamaging
    FX.runDamaging=function(b,ctx,record)return FX._kascGems67.hit(old,b,ctx,record)end
    FX._kascGemsWrapped67=true
  end
  mod.hooks:wrap('battle.damage',M.damage,29500)
  mod.content.move_effects:patch('HEAL_EFFECT',{kascGem67=M.OWNER})
  if opts.supportLog and opts.supportLog.registerSegment then
    opts.supportLog.registerSegment({segmentId=M.CARD_ID,cardId=M.CARD_ID,schema='kasc.optional-feature-card/v1',
      version='1.0.0',owner=M.OWNER,active=true,dependencyStatus='native-hit-and-consumed-item-owners',
      providerStatus='eighteen-gems',buildReceiptId='docs/GEN6_WAVE15_SCOPE_20260909.md',
      rollbackReceiptId='docs/GEN6_WAVE15_SCOPE_20260909.md'})
  end
  return M
end
