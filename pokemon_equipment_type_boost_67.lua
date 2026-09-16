-- KASC-67-HELD-TYPE-BOOST. Preserve native Gen1 without an active item.
-- Gen2: +10% base damage before +2; Gen3: +10% offensive stat;
-- Gen4+: +20% move power. Do not multiply the final rounded damage.
return function(mod,opts)
  local facts=assert(opts.facts)
  local rules=assert(opts.rules)
  local held=assert(opts.held)
  local mathOwner=assert(opts.damage)
  local M={CARD_ID='KASC-67-HELD-TYPE-BOOST',owner='kasc.held-type-boost/v1'}
  local types={}
  for id,row in pairs(facts.data.gen2Held.items)do
    local kind=row.effect and row.effect:match('^HELD_(.+)_BOOST$')
    if kind then types[id]=kind end
  end
  for id,kind in pairs({MYSTIC_WATER='WATER',NEVER_MELT_ICE='ICE',
      TWISTED_SPOON='PSYCHIC',SILVER_POWDER='BUG',BLACK_GLASSES='DARK',
      DRAGON_FANG='DRAGON',SILK_SCARF='NORMAL',BLACK_BELT='FIGHTING'})do types[id]=kind end
  local function validEpoch(id,gen)
    if type(gen)~='number' or gen%1~=0 or gen<2 or gen>7 then return false end
    if id=='DRAGON_SCALE' then return gen==2 end -- native Gen2 item bug
    if gen==2 then
      local row=facts.data.gen2Held.items[id=='BLACK_BELT' and 'BLACKBELT_I' or id]
      return row and row.effect and row.effect:match('^HELD_(.+)_BOOST$')~=nil or false
    end
    return true
  end
  for id in pairs(types)do
    local def=mod.content.items:get(id)
    if def then
      local readiness={}
      for gen=2,7 do if validEpoch(id,gen)then readiness[gen]=true end end
      mod.content.items:patch(id,{kascEquipmentTypeBoostOwner=M.owner,
        kascEquipmentRewardEpochs=readiness})
    end
  end
  function M.supportsItem(game,id,gen)
    local row=game and game.data and game.data.items and game.data.items[id]
    return types[id]~=nil and row and row.kascEquipmentTypeBoostOwner==M.owner
      and validEpoch(id,gen) or false
  end
  local function copy(value)local r={};for k,v in pairs(value or {})do r[k]=v end;return r end
  function M.damage(nextDamage,ctx)
    local b=ctx and ctx.battle
    if not b or b.demo or b.kind=='link' or not b.player or not b.player.mon
        or not ctx.user or not ctx.user.mon or not ctx.move
        or (ctx.opts and ctx.opts.typeless) or ctx.move.category=='status'
        or (tonumber(ctx.move.power) or 0)<=0 then return nextDamage(ctx)end
    local game=b.game;local bucket=game.save.modData and game.save.modData[mod.id]
    local state=bucket and bucket[rules.SAVE_KEY]
    local receipt=b.kascGenerationRulesReceipt
    if receipt and receipt.mode=='off' or not receipt and state and state.activeMode=='off' then
      return nextDamage(ctx)
    end
    local gen=receipt and receipt.activeEpoch or state and state.activeEpoch or 1
    local id=held(ctx.user.mon,b,ctx.user)
    local kind=types[id];local moveType=ctx.move.type
    if kind=='PSYCHIC' or kind=='PSYCHIC_TYPE' then
      if moveType=='PSYCHIC_TYPE' or moveType=='PSYCHIC' then kind=moveType end
    end
    if kind~=moveType or not M.supportsItem(game,id,gen)then return nextDamage(ctx)end
    local adjusted=copy(ctx)
    if gen==2 then
      local options=copy(ctx.opts);options.kascHeldTypePercent=10
      return mathOwner.compute(ctx.ruleset,ctx.user,ctx.target,ctx.move,options)
    elseif gen==3 then
      adjusted.user=copy(ctx.user);adjusted.user.curStats=copy(ctx.user.curStats)
      local category=ctx.move.category or require('src.battle.TypeChart').category(ctx.move.type)
      local stat=category=='special' and 'special' or 'attack'
      adjusted.user.curStats[stat]=math.floor(adjusted.user.curStats[stat]*110/100)
    else
      -- IV truncates item -> user ability -> target ability; V+ chains them.
      -- Both require the original power to survive until the damage owner.
      adjusted.opts=copy(ctx.opts);adjusted.opts.kascHeldTypeBoost67=true
    end
    return nextDamage(adjusted)
  end
  mod.hooks:wrap('battle.damage',M.damage,-8000)
  return M
end
