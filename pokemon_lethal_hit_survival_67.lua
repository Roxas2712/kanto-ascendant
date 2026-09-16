-- KASC-67-LETHAL-HIT-SURVIVAL. Direct incoming hits only, not damage previews.
-- No engine edits: narrow native dispatch adapters restore per-battle methods
-- even on failure. Held item consumption remains in the checkpointed mon.
return function(mod,opts)
  local M={CARD_ID='KASC-67-LETHAL-HIT-SURVIVAL',owner='kasc.lethal-hit-survival/v1'}
  local Battle=require('src.battle.BattleState')
  local Effects=require('src.battle.EffectRegistry')
  local tr=opts.i18n.text
  -- A valid incoming hit may remove zero HP (one-HP Focus Sash/Endure).
  -- Keep its pre-survival amount only during the synchronous damage call;
  -- it is neither a damage preview nor serializable battle state.
  local incoming=setmetatable({},{__mode='k'})
  function M.disguise()return mod.exports and mod.exports.pokemonDisguise67 end
  function M.incomingHit(b,who)
    local hit=incoming[b]
    return hit and hit.target==who and hit.amount>0 and hit.amount or nil
  end
  local spec={FOCUS_BAND={generation=2},FOCUS_SASH={generation=4}}
  local band=assert(opts.facts.item('FOCUS_BAND',2))
  assert(band.effect=='HELD_FOCUS_BAND' and band.parameter==30)
  for id,row in pairs(spec)do
    local source=assert(opts.facts.item(id,row.generation),'missing survival item '..id)
    local modern=assert(opts.facts.item(id,6))
    row.names=modern.names or {en=id,de=id}
    local eras={};for gen=row.generation,7 do eras[gen]=true end
    mod.content.items:register(id,{id=id,name=tr(row.names.en,row.names.de),names=row.names,
      originGeneration=row.generation,price=source.cost or 0,keyItem=false,tossable=true,
      kascSurvivalOwner67=M.owner,kascEquipmentRewardEpochs=eras})
  end
  local function epoch(b)
    local receipt=b and b.kascGenerationRulesReceipt
    if receipt then return receipt.mode=='off' and 1 or tonumber(receipt.activeEpoch) or 1 end
    local md=b and b.game and b.game.save and b.game.save.modData
    local st=md and md[mod.id] and md[mod.id][opts.rules.SAVE_KEY]
    return st and st.activeMode~='off' and st.activeEpoch or 1
  end
  local function native(b)
    return getmetatable(b)==Battle and not b.demo and b.kind~='link' and not b.result
      and b.player and b.player.mon and b.enemy and b.enemy.mon
      and epoch(b)>=2 and epoch(b)<=7
  end
  function M.supportsItem(game,id,gen)
    local row=spec[id];local def=game and game.data and game.data.items and game.data.items[id]
    return row~=nil and def~=nil and def.kascSurvivalOwner67==M.owner
      and type(gen)=='number' and gen>=row.generation and gen<=7
  end
  local function sturdy(b,who)
    return native(b) and opts.abilities.activeAbility(b,who)=='STURDY'
  end
  function M.bideImmune(b,user,target)
    -- Native Gen I Bide bypasses type immunity. IV+ releases a Normal
    -- damaging move instead; do this before the hit/contact scopes, not
    -- by reporting an immune attack as a zero-damage landed hit.
    if not native(b)or epoch(b)<4 or (user.bideTurns or 0)>1
        or (user.bideDamage or 0)<=0 then return false end
    if opts.abilities.activeAbility(b,user)=='SCRAPPY'then return false end
    if require('src.battle.TypeChart').effectiveness('NORMAL',target.curTypes)~=0 then return false end
    user.bideTurns,user.bideDamage=nil,nil
    b:cancelMoveAnim()
    b:sayNext(b:romText('_DoesntAffectMonText',"It doesn't affect\n%s!",target.name))
    return true
  end
  local function announce(b,who,id)
    local names=spec[id] and spec[id].names or id=='ENDURE' and {en='Endure',de='Ausdauer'}
      or {en='Sturdy',de='Robustheit'}
    b:sayNext(tr('%s hung on with %s!','%s hält durch mit %s!'):format(
      who.name or who.mon.species,tr(names.en,names.de)))
    b:drainNext()
  end
  function M.adjust(b,who,damage)
    if not native(b) or not who or not who.mon or who.substituteHP~=nil
        or type(damage)~='number' or damage<=0 then return damage end
    local hp,max=who.mon.hp,who.mon.stats and who.mon.stats.hp
    if not hp or hp<=0 then return damage end
    local gen=epoch(b)
    -- Endure applies to every direct hit this turn, even from partial/one HP.
    -- Resolve it before Sturdy or held items so no unused Sash is consumed
    -- and no Focus Band roll is spent on damage already made non-lethal.
    local protection=opts.protection and opts.protection()
    if damage>=hp and protection and protection.active(b,who)=='ENDURE'then
      return hp-1,'ENDURE'
    end
    if damage>=hp and hp==max and gen>=5 and sturdy(b,who) then
      return hp-1,'STURDY'
    end
    local id=opts.held(who.mon,b,who)
    if not M.supportsItem(b.game,id,gen) then return damage end
    if id=='FOCUS_BAND' then
      -- Crystal draws before checking lethal damage; preserve its 30/256
      -- byte probability. Later generations use ten percent, not 30/256.
      local success=gen==2 and b.rng(0,255)<band.parameter
      if gen~=2 then success=b.rng(1,100)<=10 end
      if success and damage>=hp then return hp-1,id end
    elseif damage>=hp and hp==max then return hp-1,id end
    return damage
  end
  function M.withDirectDamage(b,user,target,move,fn)
    if not native(b) or not user or user==target then return fn() end
    local rawDamage,rawSay=rawget(b,'applyDamage'),rawget(b,'sayNext')
    local previousDamage,previousSay=b.applyDamage,b.sayNext
    b.applyDamage=function(self,who,amount)
      local disguise=M.disguise()
      if who==target and disguise and disguise.absorb(self,who,amount,move)then
        local oldHit=incoming[self];incoming[self]={target=who,amount=amount}
        local ok,dealt=pcall(previousDamage,self,who,0);incoming[self]=oldHit
        if not ok then error(dealt,0)end
        return dealt
      end
      local adjusted,id=amount,nil
      if who==target then adjusted,id=M.adjust(self,who,amount)end
      local oldHit=incoming[self]
      if id then incoming[self]={target=who,amount=amount}end
      local hadSub=who.substituteHP~=nil
      local ok,dealt=pcall(previousDamage,self,who,adjusted)
      incoming[self]=oldHit
      if not ok then error(dealt,0)end
      local illusion=mod.exports and mod.exports.pokemonIllusion67
      if who==target and illusion then illusion.hit(self,who,dealt,hadSub)end
      if id then
        if id=='FOCUS_SASH' then
          who.mon.item=nil;who.mon.heldItem=nil
          if opts.abilities.onItemLost then opts.abilities.onItemLost(self,who,'FOCUS_SASH')end
        end
        announce(self,who,id)
      end
      return dealt
    end
    if move and move.effect=='OHKO_EFFECT' then
      local ohko=b:romText('_OHKOText','One-hit KO!')
      b.sayNext=function(self,text,...)
        if text==ohko and target.mon.hp>0 then return end
        return previousSay(self,text,...)
      end
    end
    local function pack(...)return {n=select('#',...),...}end
    local result=pack(pcall(fn))
    b.applyDamage,b.sayNext=rawDamage,rawSay
    if not result[1] then error(result[2],0)end
    return unpack(result,2,result.n)
  end
  -- One module-level wrapper per engine instance; hot reload replaces owner.
  Effects._kascSurvivalOwner67=M
  if not Effects._kascSurvivalWrapped67 then
    local original=Effects.runDamaging
    Effects.runDamaging=function(b,ctx,record)
      local owner=Effects._kascSurvivalOwner67
      local function run(selected)
        return owner.withDirectDamage(b,ctx.user,ctx.target,ctx.move,function()
          return original(b,ctx,selected)
        end)
      end
      local disguise=owner.disguise()
      if disguise then return disguise.run(b,ctx,record,run)end
      return run(record)
    end
    Effects._kascSurvivalWrapped67=true
  end
  Battle._kascSurvivalOwner67=M
  if not Battle._kascSurvivalWrapped67 then
    local original=Battle.continueBide
    Battle.continueBide=function(b,user,target)
      local owner=Battle._kascSurvivalOwner67
      if owner.bideImmune(b,user,target)then return end
      local move=b.data and b.data.moves and b.data.moves.BIDE
      local function run()
        return owner.withDirectDamage(b,user,target,move,function()return original(b,user,target)end)
      end
      local disguise=owner.disguise()
      if disguise then return disguise.run(b,{user=user,target=target,move=move},nil,run)end
      return run()
    end
    Battle._kascSurvivalWrapped67=true
  end
  local ohko=assert(mod.content.move_effects:get('OHKO_EFFECT'))
  local gate=assert(ohko.gate)
  mod.content.move_effects:patch('OHKO_EFFECT',{kascSurvivalOwner67=M.owner,gate=function(ctx)
    if sturdy(ctx.battle,ctx.target) then
      return false,tr('Sturdy protected %s!','Robustheit schützt %s!'):format(ctx.target.name)
    end
    return gate(ctx)
  end})
  return M
end
