-- Kanto Ascendant 6.7: exact-once Rocket raid item delivery.
--
-- Trainer Cards remain owned by trainer_card_collection.lua.  This module
-- registers only supported machine items, chooses renewable evolution items
-- from the live species registry and keeps a persistent FIFO when the Bag is
-- full. Unsupported generations never become decorative, unusable rewards.

return function(mod, opts)
  opts = opts or {}
  local data = assert(opts.data, "Rocket reward data missing")
  local generationRules = opts.generationRules
  local R = { schema="kanto-ascendant-rocket-rewards/v1",version=1,
    stateKey="rocket_recovery_rewards_67",game=nil }

  local function copy(value,seen)
    if type(value)~="table" then return value end
    seen=seen or {};if seen[value] then return seen[value] end
    local out={};seen[value]=out
    for key,child in pairs(value) do out[copy(key,seen)]=copy(child,seen) end
    return out
  end

  local function state()
    local s=mod.save:get(R.stateKey)
    if type(s)~="table" or s.schema~=R.schema or s.version~=R.version then
      s={schema=R.schema,version=R.version,receipts={},pending={}}
      mod.save:set(R.stateKey,s)
    end
    s.receipts=type(s.receipts)=="table" and s.receipts or {}
    s.pending=type(s.pending)=="table" and s.pending or {}
    return s
  end

  local function flush(game)
    if not (game and type(game.writeSave)=="function") then return true end
    local ok,result=pcall(game.writeSave,game)
    return ok and result~=false
  end

  local function supportedMove(id)
    local registry=mod.content and mod.content.moves
    return registry and type(registry.get)=="function" and registry:get(id)~=nil
  end

  local function registerContent()
    local items=mod.content and mod.content.items
    if not (items and type(items.get)=="function"
        and type(items.register)=="function") then return end
    for _,row in ipairs(data.moveRewards or {}) do
      if supportedMove(row.move) and not items:get(row.item) then
        items:register(row.item,{id=row.item,name=("TM%02d"):format(row.number),
          price=0,tossable=true,needsTarget=true,lootExcluded=true,
          machine={kind="TM",move=row.move,number=row.number},
          rocketRaidReward=true,originEpoch=row.epoch})
      end
    end
    if not items:get("ROCKET_COMPONENT") then
      items:register("ROCKET_COMPONENT",{id="ROCKET_COMPONENT",
        name="ROCKET PART",price=0,tossable=false,lootExcluded=true,
        rocketRaidReward=true})
    end
  end
  registerContent()

  local function addItem(game,id,qty)
    if type(opts.addItem)=="function" then return opts.addItem(game,id,qty) end
    local ok,Bag=pcall(require,"src.inventory.Bag")
    if ok and Bag and type(Bag.add)=="function" then
      local added=Bag.add(game.save,id,qty,game.data)
      if added then return true end
      return false,"bag_full"
    end
    local inventory=game and game.save and game.save.inventory
    if type(inventory)~="table" then return false,"inventory_unavailable" end
    inventory[id]=(tonumber(inventory[id])or 0)+qty
    return true
  end

  local function evolutionItems(game)
    local ids={}
    local resolved=generationRules and generationRules.resolve(game)
    local activeEpoch=resolved and resolved.activeEpoch or 1
    for _,species in pairs(game and game.data and game.data.pokemon or {}) do
      for _,evo in ipairs(species.evolutions or {}) do
        local id=evo.method=="ITEM" and evo.item or nil
        local item=game.data.items and game.data.items[id]
        if id and item and item.lootExcluded~=true
            and item.progressionItem~=true
            and (tonumber(item.originEpoch or item.originGeneration)or 1)
              <=activeEpoch then ids[id]=true end
      end
    end
    local out={};for id in pairs(ids) do out[#out+1]=id end
    table.sort(out);return out
  end

  local function pickEvolutionItem(game,seed)
    local rows=evolutionItems(game)
    if #rows==0 then return "ROCKET_COMPONENT" end
    local n=0;seed=tostring(seed or "")
    for index=1,#seed do n=(n+seed:byte(index)*index)%2147483647 end
    return rows[(n%#rows)+1]
  end

  local function deliveries(game,plan,key)
    local out={}
    if type(plan.item)=="string" and game.data.items
        and game.data.items[plan.item] and game.data.moves
        and game.data.moves[plan.move] then
      out[#out+1]={item=plan.item,qty=1,kind="tm"}
    end
    if plan.evolutionCache then
      out[#out+1]={item=pickEvolutionItem(game,
        tostring(plan.scaleHash)..":"..tostring(key)),qty=1,kind="evolution"}
    end
    if type(plan.special)=="string" and game.data.items
        and game.data.items[plan.special] then
      out[#out+1]={item=plan.special,qty=1,kind="special"}
    end
    if opts.equipmentRewards and generationRules and generationRules.resolve then
      local resolved=generationRules.resolve(game)
      local item=opts.equipmentRewards.pick(game.data,
        {activeEpoch=resolved and resolved.activeEpoch or 1},'rocket:'..key)
      if item then out[#out+1]={item=item.item,qty=item.qty,kind='equipment'} end
    end
    return out
  end

  function R.retry(game)
    local s=state();local retained={}
    for _,row in ipairs(s.pending) do
      local ok=addItem(game,row.item,row.qty)
      if not ok then retained[#retained+1]=row end
    end
    s.pending=retained;mod.save:set(R.stateKey,s)
    return #retained==0,#retained
  end

  function R.awardPlan(game,key,plan)
    if type(key)~="string" or type(plan)~="table" then
      return false,"invalid_reward_plan"
    end
    local s=state()
    if s.receipts[key] then return true,"already-delivered",copy(s.receipts[key]) end
    local rows=deliveries(game,plan,key)
    for _,row in ipairs(rows) do
      local ok=addItem(game,row.item,row.qty)
      if not ok then s.pending[#s.pending+1]={key=key,item=row.item,
        qty=row.qty,kind=row.kind} end
    end
    s.receipts[key]={key=key,plan=copy(plan),deliveries=copy(rows)}
    mod.save:set(R.stateKey,s)
    if not flush(game) then return false,"reward_receipt_save_failed" end
    return true,"delivered",copy(s.receipts[key])
  end

  function R.status() return copy(state()) end
  function R.install(game) R.game=game;R.retry(game);return true end
  return R
end
