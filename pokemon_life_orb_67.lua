-- Life Orb owns one after-move cost, not one cost per hit. Damage previews
-- only receive a modifier; they never create a cost or a consumption record.
return function(mod,opts)
  local B=require('src.battle.BattleState');local Effects=require('src.battle.EffectRegistry')
  local A=opts.abilities
  local M={CARD_ID='KASC-67-LIFE-ORB',OWNER='kasc.life-orb/v1'}
  local turns=setmetatable({},{__mode='k'})
  local hits=setmetatable({},{__mode='k'})
  local function pack(...)return {n=select('#',...),...}end
  local function copy(v)local out={};for k,x in pairs(v or{})do out[k]=x end;return out end
  function M.itemMetadata(id)
    if id=='LIFE_ORB'then return {id=id,generation=4,names={en='LIFE ORB',de='LEBEN-ORB'},
      flags={'holdable','holdable-passive'}}end
  end
  do
    local fields={kascLifeOrb67=M.OWNER,kascEquipmentRewardEpochs={[4]=true,[5]=true,[6]=true,[7]=true}}
    if mod.content.items:get('LIFE_ORB')then mod.content.items:patch('LIFE_ORB',fields)
    else
      fields.id='LIFE_ORB';fields.name=opts.i18n.text('LIFE ORB','LEBEN-ORB')
      fields.names={en='LIFE ORB',de='LEBEN-ORB'};fields.price=(opts.facts.item('LIFE_ORB',4)or{}).cost or 0
      fields.keyItem=false;fields.field=false;fields.battle=false
      mod.content.items:register('LIFE_ORB',fields)
    end
  end
  function M.supportsItem(game,id,gen)
    local d=game and game.data;local item=d and d.items and d.items[id]
    local marker=d and d.move_effects and d.move_effects.HEAL_EFFECT
    return id=='LIFE_ORB'and item and item.kascLifeOrb67==M.OWNER
      and marker and marker.kascLifeOrb67==M.OWNER
      and type(gen)=='number'and gen%1==0 and gen>=4 and gen<=7 or false
  end
  function M.epoch(b)
    local gen=b and opts.status.epoch(b)
    if getmetatable(b)==B and not b.demo and b.kind~='link'and not b.result
        and gen and gen>=4 and gen<=7 then return gen end
  end
  function M.item(b,w)
    local gen=M.epoch(b)
    if not gen or not w or not w.mon or w.mon.hp<=0 then return end
    local id,err=opts.held(w.mon,b,w)
    return not err and M.supportsItem(b.game,id,gen)and id or nil
  end
  function M.damage(nextDamage,ctx)
    local gen=M.epoch(ctx and ctx.battle);local move=ctx and ctx.move
    if not gen or not move or move.category=='status' or (tonumber(move.power)or 0)<=0
        or ctx.opts and ctx.opts.typeless or not M.item(ctx.battle,ctx.user)
        or gen==4 and (move.id=='FUTURE_SIGHT'or move.id=='DOOM_DESIRE')then return nextDamage(ctx)end
    local adjusted=copy(ctx);adjusted.opts=copy(ctx.opts);adjusted.opts.kascLifeOrb67=true
    local damage,info=nextDamage(adjusted)
    -- Gen IV's recoil flag belongs to actual power-based hits, not fixed
    -- damage. A hit against a Substitute never raises that old flag.
    local hit=hits[ctx.battle]
    if gen==4 and hit and hit.user==ctx.user and hit.target==ctx.target
        and not ctx.target.substituteHP and damage>0 then hit.powered=true end
    return damage,info
  end
  function M.hit(original,b,ctx,record)
    local whole=turns[b]
    if not whole or not ctx.user or not ctx.target or ctx.user==ctx.target then return original(b,ctx,record)end
    local prior=hits[b];local hit={user=ctx.user,target=ctx.target};hits[b]=hit
    whole.move=ctx.move
    whole.sheer=whole.sheer or A.sheerForce(b,ctx.user,ctx.move)
    local raw,old=rawget(b,'applyDamage'),b.applyDamage
    b.applyDamage=function(self,w,amount)
      local target=w==ctx.target and w.mon.hp>0
      local incoming=opts.survival.incomingHit(self,w)
      local damage=old(self,w,amount)
      if target and (damage>0 or incoming) then
        whole.landed=true
        if hit.powered then whole.powered=true end
      end
      return damage
    end
    local result=pack(pcall(original,b,ctx,record));b.applyDamage=raw;hits[b]=prior
    if not result[1]then error(result[2],0)end
    return unpack(result,2,result.n)
  end
  function M.finishMove(b,whole)
    local u=whole.user;local move=whole.move;local gen=whole.gen
    if not whole.landed or not move or move.category=='status' or u.mon.hp<=0
        or move.id=='FUTURE_SIGHT'or move.id=='DOOM_DESIRE'
        or A.blocksIndirect(b,u,'life_orb')
        or gen>=5 and whole.sheer and A.activeAbility(b,u)=='SHEER_FORCE'then return end
    if gen==4 and not whole.powered or gen>=5 and not M.item(b,u)then return end
    b:sayNext(opts.i18n.text('Life Orb!\nLost HP.','Leben-Orb!\nKP verloren.'))
    opts.contact.indirectDamage(b,u,math.max(1,math.floor(u.mon.stats.hp/10)))
    if u.mon.hp<=0 then b:onFaint(u)end
  end
  function M.perform(original,b,u,t,...)
    local gen=M.epoch(b)
    if not gen or not u or not t or u==t then return original(b,u,t,...)end
    local prior=turns[b];local whole={user=u,target=t,gen=gen};turns[b]=whole
    local result=pack(pcall(original,b,u,t,...));turns[b]=prior
    if not result[1]then error(result[2],0)end
    M.finishMove(b,whole)
    return unpack(result,2,result.n)
  end
  B._kascLifeOrb67=M;Effects._kascLifeOrb67=M
  if not B._kascLifeOrbWrapped67 then
    local original=B.performMove
    B.performMove=function(b,u,t,...)return B._kascLifeOrb67.perform(original,b,u,t,...)end
    local bide=B.continueBide
    B.continueBide=function(b,u,t)
      local function perform(self,user,target)
        return Effects._kascLifeOrb67.hit(function()return bide(self,user,target)end,
          self,{user=user,target=target,move=self.data.moves.BIDE})
      end
      return B._kascLifeOrb67.perform(perform,b,u,t)
    end
    B._kascLifeOrbWrapped67=true
  end
  if not Effects._kascLifeOrbWrapped67 then
    local original=Effects.runDamaging
    Effects.runDamaging=function(b,ctx,record)return Effects._kascLifeOrb67.hit(original,b,ctx,record)end
    Effects._kascLifeOrbWrapped67=true
  end
  mod.content.move_effects:patch('HEAL_EFFECT',{kascLifeOrb67=M.OWNER})
  mod.hooks:wrap('battle.damage',M.damage,22000)
  if opts.supportLog and opts.supportLog.registerSegment then
    opts.supportLog.registerSegment({segmentId=M.CARD_ID,cardId=M.CARD_ID,
      schema='kasc.optional-feature-card/v1',version='1.0.0',owner=M.OWNER,active=true,
      dependencyStatus='native-damage-and-contact-owners',providerStatus='life-orb',
      buildReceiptId='docs/GEN6_WAVE15_SCOPE_20260909.md',rollbackReceiptId='docs/GEN6_WAVE15_SCOPE_20260909.md'})
  end
  return M
end
