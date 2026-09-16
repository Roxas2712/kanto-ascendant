-- KASC-67-WILD-EQUIPMENT. Roll once on the actual encounter mon; capture
-- keeps that same receipt. Never walk old storage to assign wild items.
return function(mod,opts)
  local facts=assert(opts.facts)
  local binding=assert(opts.abilities)
  local held=assert(opts.held)
  local rules=assert(opts.rules)
  local M={CARD_ID='KASC-67-WILD-EQUIPMENT',schema='kasc.wild-equipment/v1'}
  local function holdable(row)
    if row.effect then return true end
    for _,flag in ipairs(row.flags or {})do
      if flag=='holdable' or flag=='holdable-active' or flag=='holdable-passive' then return true end
    end
    return false
  end
  -- Item existence is independent of effect readiness. Keep native prices,
  -- bag-use handlers, machines and all existing feature definitions intact.
  function M.registerItems()
    local n=0
    local function register(row)
      if holdable(row) and not mod.content.items:get(row.id) then
        local names=row.names or {en=row.id,de=row.id}
        mod.content.items:register(row.id,{id=row.id,name=opts.i18n.text(names.en,names.de),
          names=names,price=row.cost or 0,keyItem=false,tossable=true,needsTarget=false,
          originGeneration=row.generation or 2,kascEquipmentCatalog=true})
        n=n+1
      end
    end
    for _,row in pairs(facts.data.gen2Held.items)do register(row)end
    for _,row in pairs(facts.data.items)do if row.generation<=3 then register(row)end end
    return n
  end
  function M.prepare(event)
    local b=event and event.battle
    if not b or b.demo or b.kind~='wild' or not b.player or not b.player.mon
        or not b.enemy or not b.enemy.mon then return false,'not_native_wild' end
    local mon=b.enemy.mon
    if mon._kascWildEquipment67 then return false,'already_rolled' end
    if mon.isEgg or mon.eggSpecies then return false,'egg' end
    local existing,err=held(mon)
    if existing==nil then return nil,err end
    local key=binding.key(b.game,mon)
    if not key then return false,'unknown_species' end
    local bucket=b.game.save.modData and b.game.save.modData[mod.id]
    local state=bucket and bucket[rules.SAVE_KEY]
    local epoch=state and state.activeEpoch or 1
    local item,why,version=false,nil,nil
    local origin=opts.origin and opts.origin(b) or nil
    if existing then item,why=existing,'preserved'
    else
      local rng=b.rng
      if origin then
        -- Visible Wilds may reconstruct the battle object on another click.
        -- Its encounter identity, not the click or current clock, seeds the
        -- isolated item stream. This does not consume battle combat RNG.
        local index=0
        rng=function(lo,hi)
          index=index+1
          return lo+tonumber(opts.digest(origin..':held:'..index):sub(1,8),16)%(hi-lo+1)
        end
      end
      item,why,version=facts.rollHeld(key,epoch,nil,rng)
      if item==nil then return nil,why end
      if item and not b.game.data.items[item] then return nil,'item_not_registered' end
    end
    if item and not existing then mon.item=item;mon.heldItem=item end
    mon._kascWildEquipment67={schema=M.schema,key=key,epoch=epoch,
      version=version,itemId=item,origin=origin,reason=why}
    return true
  end
  M.registered=M.registerItems()
  mod.events:on('battle.started',M.prepare,8000)
  return M
end
