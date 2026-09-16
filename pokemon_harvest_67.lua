-- Consumed items belong to a party slot for this battle, not a battler
-- visit or a permanent Pokemon field. Harvest reuses the berry owners.
return function(mod,opts)
  local Battle=require('src.battle.BattleState')
  local M={CARD_ID='KASC-67-HARVEST',OWNER='kasc.consumed-items/v1'}
  local tr=opts.i18n.text
  local function state(b,create)
    if create then
      b.field=b.field or{};b.field.tokens=b.field.tokens or{}
      b.field.tokens[M.OWNER]=b.field.tokens[M.OWNER]or{records={}}
    end
    return b and b.field and b.field.tokens and b.field.tokens[M.OWNER]
  end
  function M.epoch(b)
    local gen=b and opts.status.epoch(b)
    if getmetatable(b)==Battle and not b.result and not b.demo and b.kind~='link'
        and gen and gen>=2 and gen<=7 then return gen end
  end
  local function party(b,lane)
    if lane=='player'then return b.game and b.game.save and b.game.save.party end
    return b.kind=='trainer'and b.enemyParty or{b.enemy and b.enemy.mon}
  end
  local function identity(b,w)
    local lane=w==b.player and 'player'or w==b.enemy and 'enemy'
    if not lane then return end
    for i,mon in ipairs(party(b,lane)or{})do
      if mon==w.mon and i<=6 then return lane..':'..i end
    end
  end
  local function item(b,id)
    return type(id)=='string'and b.data and b.data.items and b.data.items[id]
  end
  function M.validateCheckpoint(b)
    local s=state(b);if s==nil then return true end
    if type(s)~='table'or type(s.records)~='table'then return false,'invalid_consumed_items'end
    if s.lastTurn~=nil and not(type(s.lastTurn)=='number'and s.lastTurn%1==0
        and s.lastTurn>=1 and s.lastTurn<=(b.turnCount or 0))then
      return false,'invalid_harvest_turn'
    end
    for k in pairs(s)do if k~='records'and k~='lastTurn'then return false,'unknown_consumed_field'end end
    for key,r in pairs(s.records)do
      local lane,index
      if type(key)=='string'then lane,index=key:match('^(%a+):([1-6])$')end
      local mons=(lane=='player'or lane=='enemy')and party(b,lane)
      local mon=mons and mons[tonumber(index)]
      if not mon or type(r)~='table'or r.species~=mon.species or not item(b,r.item)then
        return false,'invalid_consumed_identity'
      end
      for field in pairs(r)do
        if field~='species'and field~='item'then return false,'unknown_consumed_record_field'end
      end
    end
    return true
  end
  function M.remember(b,w,id)
    if not M.epoch(b)or not w or not w.mon then return end
    local key=identity(b,w);if not key then return end
    -- Unspecified loss (e.g. theft) is not consumption. Neither manufacture
    -- a new candidate nor erase an earlier, genuinely consumed item.
    if not item(b,id)then return end
    state(b,true).records[key]={species=w.mon.species,item=id}
    local pickup=mod.exports and mod.exports.pokemonPickup67
    if pickup then pickup.remember(b,w,id)end
  end
  function M.consumed(b,w)
    if not M.epoch(b)or not w or not w.mon then return end
    local key=identity(b,w);local s=state(b);local r=s and key and s.records[key]
    if r and r.species==w.mon.species and item(b,r.item)then return r.item,item(b,r.item),key end
  end
  function M.claim(b,w,id)
    local actual,_,key=M.consumed(b,w)
    if not actual or actual~=id then return false end
    state(b).records[key]=nil
    local pickup=mod.exports and mod.exports.pokemonPickup67
    if pickup then pickup.forget(b,w)end
    return true
  end
  function M.candidate(b,w,berryOnly)
    if not M.epoch(b)or not w or not w.mon or w.mon.hp<=0 then return false end
    local held,err=opts.held(w.mon)
    if held or err then return false end
    local key=identity(b,w);local s=state(b);local r=s and key and s.records[key]
    local def=r and r.species==w.mon.species and item(b,r.item)
    if not def or berryOnly and not def.kascConsumableBerry67 then return false end
    return r.item,def,key
  end
  function M.restoreConsumed(b,w,berryOnly)
    local id,def,key=M.candidate(b,w,berryOnly)
    if not id then return false end
    if not M.claim(b,w,id)then return false end -- before callbacks/reconsumption
    w.mon.item=id;w.mon.heldItem=id
    local transfer=mod.exports and mod.exports.pokemonItemTransfer67
    if transfer then transfer.recycled(b,w)end
    opts.abilities.clearItemLoss(b,w)
    return id,def
  end
  function M.activateRestored(b,w,afterAction)
    opts.berries.apply(b,afterAction,w)
    -- Only berries have an immediate-use check. A received/recycled
    -- Leftovers must wait for its normal residual, not heal on receipt.
    local id=opts.held(w.mon)
    if item(b,id)and item(b,id).kascConsumableBerry67 then opts.legacy.apply(b,w)end
  end
  function M.recover(b,w)
    local gen=M.epoch(b)
    if not gen or gen<5 or not w or not w.mon or w.mon.hp<=0
        or opts.abilities.activeAbility(b,w)~='HARVEST'
        or not M.candidate(b,w,true)then return false end
    local sunny=opts.weather.current(b)=='sun'
    if not sunny and b.rng(1,2)~=1 then return false end
    local id,def=M.restoreConsumed(b,w,true)
    if not id then return false end
    local names=def.names or{}
    b:sayNext(tr('%s regrew %s with Harvest!','%s gewinnt %s durch Ernte zurück!')
      :format(w.name or w.mon.species,tr(names.en or def.name or id,names.de or def.name or id)))
    b:drainNext()
    -- A regrown berry can be eaten immediately, once, if its normal trigger
    -- is still satisfied. Unnerve still blocks eating, not regrowth.
    M.activateRestored(b,w,false)
    return true
  end
  function M.endTurn(ev)
    local b=ev and ev.battle;local turn=ev and ev.turn
    local gen=M.epoch(b)
    if not gen or gen<5 or type(turn)~='number'or turn%1~=0 or turn<1 then return end
    local s=state(b)
    if s and s.lastTurn==turn then return end
    local active={}
    local pickup=mod.exports and mod.exports.pokemonPickup67
    for _,w in ipairs({b.player,b.enemy})do
      local id=w and w.mon and w.mon.hp>0 and opts.abilities.activeAbility(b,w)
      if id=='HARVEST'or id=='PICKUP'and pickup then active[#active+1]=w end
    end
    if #active==0 then return end
    state(b,true).lastTurn=turn
    if #active==2 then
      local first,second=opts.speed(b,active[1]),opts.speed(b,active[2])
      if first<second or first==second and b.rng(0,1)==1 then active[1],active[2]=active[2],active[1]end
    end
    for _,w in ipairs(active)do
      if opts.abilities.activeAbility(b,w)=='PICKUP'then pickup.recover(b,w)
      else M.recover(b,w)end
    end
  end
  mod.content.move_effects:patch('HEAL_EFFECT',{kascHarvest67=M.OWNER})
  mod.events:on('battle.turn_ended',M.endTurn,-100)
  mod.events:on('battle.ended',function(ev)
    local b=ev and ev.battle
    if b and b.field and b.field.tokens then b.field.tokens[M.OWNER]=nil end
  end,100)
  if opts.supportLog and opts.supportLog.registerSegment then
    opts.supportLog.registerSegment({segmentId=M.CARD_ID,cardId=M.CARD_ID,
      schema='kasc.optional-feature-card/v1',version='1.0.0',owner=M.OWNER,active=true,
      dependencyStatus='native-consumption-weather-and-checkpoint',providerStatus='harvest-v-vii',
      buildReceiptId='docs/GEN6_WAVE15_SCOPE_20260909.md',rollbackReceiptId='docs/GEN6_WAVE15_SCOPE_20260909.md'})
  end
  return M
end
