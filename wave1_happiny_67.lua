-- Bounded family owner: Wonneira -> Chaneira -> Heiteira.
-- PokeAPI d4f9a4af58ade123fbc0558f68b1c69daa97d9e4, evolution rows
-- 67/127, item 110. Holding comes from held_item_id, not a guessed flag.
return function(mod,opts)
  local H={CARD_ID='KASC-WAVE1-HAPPINY',ITEM='OVAL_STONE',ready=false}
  local tr=opts.i18n.text
  local day=assert(opts.timeMode,'Happiny needs the established AUTO clock')
  local methods=mod.content.evolution_methods
  local function healthy(mon)
    return type(mon)=='table' and not mon.isEgg and not mon.egg and not mon.eggSpecies
      and (tonumber(mon.hp) or 0)>0
  end
  local function held(mon)
    local equipment=mod.exports and mod.exports.pokemonEquipment67
    return equipment and equipment.heldId(mon)
  end
  local baby=mod.content.pokemon:get('HAPPINY')
  local chansey=mod.content.pokemon:get('CHANSEY')
  local native=methods:get('FRIENDSHIP')
  if not baby or not chansey or not mod.content.pokemon:get('BLISSEY') or not native then return H end
  assert(#baby.evolutions==1 and baby.evolutions[1].method=='KA_HAPPINY_OVAL_DAY'
    and baby.evolutions[1].species=='CHANSEY','Happiny evolution owner changed')
  assert(#chansey.evolutions==1 and chansey.evolutions[1].method=='FRIENDSHIP'
    and chansey.evolutions[1].species=='BLISSEY','Chansey evolution owner changed')
  assert(not mod.content.items:get(H.ITEM),'Oval Stone belongs to another item owner')
  mod.content.items:register(H.ITEM,{
    id=H.ITEM,name=tr('OVAL STONE','OVALER STEIN'),price=2000,
  })
  methods:register('KA_HAPPINY_OVAL_DAY',{
    check=function(_,mon,_,trigger)
      return healthy(mon) and mon.species=='HAPPINY' and trigger and trigger.kind=='levelup'
        and held(mon)==H.ITEM and day()=='day' or false
    end,
    describe=function() return tr('Level up by day holding an Oval Stone',
      'Levelaufstieg am Tag mit getragenem Ovalen Stein') end,
  })
  methods:register('KA_WAVE1_CHANSEY_FRIENDSHIP',{
    check=function(game,mon,evo,trigger)
      return healthy(mon) and mon.species=='CHANSEY' and trigger and trigger.kind=='levelup'
        and native.check(game,mon,evo,trigger) or false
    end,
    describe=function()return tr('High friendship','Hohe Freundschaft')end,
  })
  mod.content.pokemon:patch('CHANSEY',{evolutions={
    {method='KA_WAVE1_CHANSEY_FRIENDSHIP',species='BLISSEY'},
  }})
  H.ready=true
  function H.item(id)
    if id~=H.ITEM then return nil end
    return {id=id,generation=4,names={en='OVAL STONE',de='OVALER STEIN'},
      flags={'holdable'},fieldEvolutionOnly=true,sourceItem=110}
  end
  function H.familyChansey(game,mon)
    if not healthy(mon) or mon.species~='CHANSEY' then return false end
    local archive=mod.exports and mod.exports.eventArchive
    if not archive then return false end
    local valid,_,profile=archive.battleCompatibleGift(mon)
    return valid and profile and profile.backendKey=='dex:440'
      and profile.species=='HAPPINY' or false
  end
  -- Eligibility checks never mutate equipment. Only Evolution.apply emits
  -- this event after an accepted film. Species and item then persist together
  -- in the native save; repeated events cannot remove another bag item.
  mod.events:on('pokemon.evolved',function(ev)
    if ev and ev.fromSpecies=='HAPPINY' and ev.toSpecies=='CHANSEY'
        and ev.via=='KA_HAPPINY_OVAL_DAY' and ev.mon and ev.mon.species=='CHANSEY'
        and held(ev.mon)==H.ITEM then
      ev.mon.item=nil;ev.mon.heldItem=nil
    end
  end,900)
  -- A repeatable, paid native purchase is reachable from a hatched Happiny's
  -- equipment menu even for an early gift. No automatic equip, egg spoiler, free
  -- re-grant or change to ordinary mart stock / generation unlocks.
  function H.canBuy(game,mon)
    if not H.ready or not mon or mon.species~='HAPPINY' or mon.isEgg or mon.egg or mon.eggSpecies
        then return false end
    local owned=false
    for _,member in ipairs(game and game.save and game.save.party or {}) do
      if member==mon then owned=true end
    end
    return owned
  end
  local buying=setmetatable({},{__mode='k'})
  function H.buyOne(game,mon)
    local equipment=mod.exports.pokemonEquipment67
    if not H.canBuy(game,mon) then return false,'mon_not_owned' end
    if buying[game] then return false,'transaction_busy' end
    if not equipment then return false,'equipment_not_initialized' end
    local ready,why=equipment.initialize(game)
    if not ready then return false,why end
    local save=game.save
    local price=2000
    if type(save.money)~='number' or save.money~=math.floor(save.money) or save.money<price then
      return false,'not_enough_money'
    end
    if type(save.inventory)~='table' then return false,'save_unavailable' end
    local inventory,order,money=save.inventory,save.bagOrder,save.money
    local nextInventory={};for k,v in pairs(inventory)do nextInventory[k]=v end
    local nextOrder=order and {};for k,v in pairs(order or {})do nextOrder[k]=v end
    save.inventory=nextInventory;save.bagOrder=nextOrder
    if not require('src.inventory.Bag').add(save,H.ITEM,1,game.data) then
      save.inventory=inventory;save.bagOrder=order
      return false,'bag_full'
    end
    save.money=money-price;buying[game]=true
    local ok,wrote=pcall(game.writeSave,game)
    buying[game]=nil
    if not ok or wrote~=true then
      save.inventory=inventory;save.bagOrder=order;save.money=money
      return false,'save_failed'
    end
    return true
  end
  function H.openShop(game,mon,onQuit)
    if not H.canBuy(game,mon) then return false end
    local equipment=mod.exports.pokemonEquipment67
    if not equipment or not equipment.initialize(game) then return false end
    local factory=assert(mod.ui.KantoListMenu,'Happiny requires the KASC fullscreen facade')
    local help=tr('Let Happiny hold it and level up by day. Consumed on accepted evolution. No battle bonus.',
      'Wonneira tragen lassen und tagsüber aufleveln. Verbrauch bei angenommener Entwicklung. Kein Kampfbonus.')
    local show
    show=function(message)
      local rows={{value='buy',label=tr('BUY ONE','EINEN KAUFEN'),right='2000',help=message or help},
        {value='back',label=tr('BACK','ZURÜCK'),help=tr('Back to Equipment.','Zurück zur Ausrüstung.')}}
      local chosen=false
      local list=factory.new(game,tr('OVAL STONE','OVALER STEIN'),rows,{
        ascendantFocusHelp=function(row)return row.help end,
        onCancel=onQuit,
        onChoose=function(row,current)
          if chosen then return end
          chosen=true;current:close()
          if row.value=='back' then if onQuit then onQuit() end;return end
          local answered=false
          local confirmation=factory.new(game,tr('BUY FOR 2000?','FÜR 2000 KAUFEN?'),{
            {value=true,label=tr('YES','JA'),help=help},
            {value=false,label=tr('NO','NEIN'),help=tr('Keep your money.','Dein Geld behalten.')},
          },{ascendantFocusHelp=function(choice)return choice.help end,
            onCancel=function()show()end,
            onChoose=function(choice,confirm)
              if answered then return end
              answered=true;confirm:close()
              if not choice.value then show();return end
              local bought,reason=H.buyOne(game,mon)
              local messages={
                not_enough_money=tr('Not enough money. Nothing was spent.','Nicht genug Geld. Nichts ausgegeben.'),
                bag_full=tr('Bag full. Nothing was spent.','Beutel voll. Nichts ausgegeben.'),
                save_failed=tr('Save failed. Money and item restored.','Speichern fehlgeschlagen. Geld und Item zurückgesetzt.'),
              }
              show(bought and tr('Received one Oval Stone. Give it through Equipment.',
                'Einen Ovalen Stein erhalten. Gib ihn über Ausrüstung.')
                or messages[reason] or tr('Purchase unavailable. Nothing spent.','Kauf nicht möglich. Nichts ausgegeben.'))
            end})
          game.stack:push(confirmation)
        end})
      game.stack:push(list)
    end
    show();return true
  end
  return H
end
