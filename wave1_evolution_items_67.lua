-- Reviewed item routes; no wild pools, save migration, automatic gifts or equips.
-- Prices/names: pinned PokeAPI items 885,1174,1175,2109,2045,1677.
-- Metal Alloy (2232) has source cost 0: 3000 is an explicit KASC shop price,
-- matching Ice Stone, not a claim about its original game's currency/shop.
return function(mod,opts)
  local tr=opts.i18n.text
  local C={CARD_ID='KASC-WAVE1-EVOLUTION-ITEMS',ready=false}
  local rows={
    {id='AUSPICIOUS_ARMOR',price=3000,dex=935,en='AUSPICIOUS ARMOR',de='GLORIENRÜSTUNG',
      helpEn='Use from the Bag on Charcadet to evolve it into Armarouge. Consumed once.',
      helpDe='Im Beutel auf Knarbon anwenden: Entwicklung zu Crimanzo. Einmaliger Verbrauch.'},
    {id='MALICIOUS_ARMOR',price=750,dex=935,en='MALICIOUS ARMOR',de='FLUCHRÜSTUNG',
      helpEn='Use from the Bag on Charcadet to evolve it into Ceruledge. Consumed once.',
      helpDe='Im Beutel auf Knarbon anwenden: Entwicklung zu Azugladis. Einmaliger Verbrauch.'},
    {id='TART_APPLE',price=2200,dex=840,en='TART APPLE',de='SAURER APFEL',
      helpEn='Use from the Bag on Applin to evolve it into Flapple. Consumed once.',
      helpDe='Im Beutel auf Knapfel anwenden: Entwicklung zu Drapfel. Einmaliger Verbrauch.'},
    {id='SWEET_APPLE',price=2200,dex=840,en='SWEET APPLE',de='SÜSSER APFEL',
      helpEn='Use from the Bag on Applin to evolve it into Appletun. Consumed once.',
      helpDe='Im Beutel auf Knapfel anwenden: Entwicklung zu Schlapfel. Einmaliger Verbrauch.'},
    {id='SYRUPY_APPLE',price=500,dex=840,en='SYRUPY APPLE',de='SAFTIGER APFEL',
      helpEn='Use from the Bag on Applin to evolve it into Dipplin. Consumed once.',
      helpDe='Im Beutel auf Knapfel anwenden: Entwicklung zu Sirapfel. Einmaliger Verbrauch.'},
    {id='METAL_ALLOY',price=3000,dex=884,en='METAL ALLOY',de='LEGIERUNGSMETALL',
      helpEn='Use from the Bag on Duraludon to evolve it into Archaludon. Consumed once.',
      helpDe='Im Beutel auf Duraludon anwenden: Entwicklung zu Briduradon. Einmaliger Verbrauch.'},
    {id='ICE_STONE',price=3000,en='ICE STONE',de='EISSTEIN',routes={
      {key='form:10176',targetKey='form:10177',
      helpEn='Use on Galarian Darumaka to evolve it into Galarian Darmanitan. Consumed once.',
      helpDe='Auf Galar-Flampion anwenden: Entwicklung zu Galar-Flampivian. Einmaliger Verbrauch.'},
      {dex=739,
      helpEn='Use from the Bag on Crabrawler to evolve it into Crabominable. Consumed once.',
      helpDe='Im Beutel auf Krabbox anwenden: Entwicklung zu Krawell. Einmaliger Verbrauch.'},
      {dex=974,
      helpEn='Use from the Bag on Cetoddle to evolve it into Cetitan. Consumed once.',
      helpDe='Im Beutel auf Flaniwal anwenden: Entwicklung zu Kolowal. Einmaliger Verbrauch.'}}},
  }
  for _,row in ipairs(rows)do
    assert(not mod.content.items:get(row.id),'evolution item already owned '..row.id)
    mod.content.items:register(row.id,{id=row.id,name=tr(row.en,row.de),price=row.price,
      needsTarget=true,battle=false})
  end
  -- Hoenn owns these definitions and its single-player ITEM adaptations.
  -- Offer the existing items; do not replace their prices, effects or owner.
  C.hoennOffers={}
  for _,row in ipairs({
    {id='PRISM_SCALE',price=2100,dex=349,target=350,en='PRISM SCALE',de='SCHÖNSCHUPPE',
      helpEn='Use from the Bag on Feebas to evolve it into Milotic. Consumed once.',
      helpDe='Im Beutel auf Barschwa anwenden: Entwicklung zu Milotic. Einmaliger Verbrauch.'},
    {id='DEEP_SEA_TOOTH',price=2100,dex=366,target=367,en='DEEP SEA TOOTH',de='ABYSSZAHN',
      helpEn='Use from the Bag on Clamperl to evolve it into Huntail. Consumed once.',
      helpDe='Im Beutel auf Perlu anwenden: Entwicklung zu Aalabyss. Einmaliger Verbrauch.'},
    {id='DEEP_SEA_SCALE',price=2100,dex=366,target=368,en='DEEP SEA SCALE',de='ABYSSPLATTE',
      helpEn='Use from the Bag on Clamperl to evolve it into Gorebyss. Consumed once.',
      helpDe='Im Beutel auf Perlu anwenden: Entwicklung zu Saganabyss. Einmaliger Verbrauch.'},
  })do
    local owned=mod.content.items:get(row.id)
    local valid=owned and owned.price==row.price and owned.needsTarget==true
      and owned.effect=='KA_HOENN_EVOLUTION_ITEM_EFFECT'
    C.hoennOffers[row.id]=valid and 'reused' or 'owner_unavailable'
    if valid then rows[#rows+1]=row end
  end
  -- Reuse Late Species' existing reward item. Its registry price stays 0;
  -- the optional shop charges the pinned Dawn Stone purchase price (3000).
  local dawn=mod.content.items:get('DAWN_STONE')
  C.dawnOffer=dawn and dawn.needsTarget==true
    and dawn.effect=='KA_LATE_SPECIES_67_EVOLUTION_ITEM' and 'reused' or 'owner_unavailable'
  if C.dawnOffer=='reused' then
    rows[#rows+1]={id='DAWN_STONE',price=3000,en='DAWN STONE',de='FUNKELSTEIN',routes={
      {dex=281,target=475,
        helpEn='Use on male Kirlia to evolve it into Gallade. Consumed once.',
        helpDe='Auf männliches Kirlia anwenden: Entwicklung zu Galagladi. Einmaliger Verbrauch.'},
      {dex=361,target=478,
        helpEn='Use on female Snorunt to evolve it into Froslass. Consumed once.',
        helpDe='Auf weibliches Schneppke anwenden: Entwicklung zu Frosdedje. Einmaliger Verbrauch.'}}}
  end
  -- These items are registered later by the atomic Kubfu family owner.
  -- Only expose them when both scrolls/forms were validated successfully.
  for _,row in ipairs({
    {id='SCROLL_OF_DARKNESS',price=3000,key='dex:891',targetKey='dex:892',
      en='SCROLL OF DARKNESS',de='UNLICHT-SCHRIFTROLLE',
      helpEn='Use on Kubfu: Urshifu, Single Strike Style. Consumed once.',
      helpDe='Auf Dakuma: Wulaosu im fokussierten Stil. Einmaliger Verbrauch.'},
    {id='SCROLL_OF_WATERS',price=3000,key='dex:891',targetKey='form:10191',
      en='SCROLL OF WATERS',de='WASSER-SCHRIFTROLLE',
      helpEn='Use on Kubfu: Urshifu, Rapid Strike Style. Consumed once.',
      helpDe='Auf Dakuma: Wulaosu im fließenden Stil. Einmaliger Verbrauch.'},
  })do row.owner='wave1Kubfu67';rows[#rows+1]=row end
  for _,row in ipairs({
    {id='CRACKED_POT',price=1600,key='dex:854',targetKey='dex:855',
      en='CRACKED POT',de='RISSIGE KANNE',
      helpEn='Use on Phony Sinistea: Polteageist. Consumed once.',
      helpDe='Auf Fatalitee (Fälschung): Entwicklung zu Mortipot. Einmaliger Verbrauch.'},
    {id='UNREMARKABLE_TEACUP',price=400,key='dex:1012',targetKey='dex:1013',
      en='UNREMARKABLE TEACUP',de='SIMPLE TEESCHALE',
      helpEn='Use on Counterfeit Poltchageist: Sinistcha. Consumed once.',
      helpDe='Auf Mortcha (Fälschung): Entwicklung zu Fatalitcha. Einmaliger Verbrauch.'},
  })do
    row.owner='wave1Tea67';row.effect='KA_WAVE1_TEA_ITEM_'..row.id;rows[#rows+1]=row
  end
  C.ready=true
  function C.offers(game,mon)
    local out={}
    if not (game and game.save and type(mon)=='table') or mon.isEgg or mon.egg or mon.eggSpecies then return out end
    local present=false
    for _,member in ipairs(game.save.party or {})do if member==mon then present=true end end
    if not present then return out end
    local alola=mod.exports and mod.exports.pokemonAlolaEvolutions67
    if alola and alola.ready then
      for _,offer in ipairs(alola.offers(game,mon))do out[#out+1]=offer end
    end
    local species=mod.exports and mod.exports.backendGiftSpecies67
    local key=species and species.bySpecies[mon.species]
    local sneasler=mod.exports and mod.exports.wave1Sneasler67
    local clawOffer=sneasler and sneasler.ready and type(sneasler.offer)=='function'
      and sneasler.offer(game,mon)
    if clawOffer then out[#out+1]=clawOffer end
    local cord=mod.exports and mod.exports.wave1LinkingCord67
    local heldOffer=cord and cord.ready and type(cord.heldOffer)=='function' and cord.heldOffer(game,mon)
    if heldOffer then out[#out+1]=heldOffer end
    local paired=mod.exports and mod.exports.wave1PairedLink67
    local pairedOffer=paired and paired.ready and paired.offer(game,mon)
    if pairedOffer then out[#out+1]=pairedOffer end
    local cordItem=cord and mod.content.items:get('LINKING_CORD')
    if cord and cord.ready and cordItem and cordItem.price==8000
        and cordItem.effect=='KA_WAVE1_LINKING_CORD_EFFECT' then
      for _,route in ipairs(cord.routes)do
        if key==route.fromKey and require('src.pokemon.Evolution').pendingFor(game,mon,
            {kind='item',item='LINKING_CORD'})==route.target then
          out[#out+1]={id='LINKING_CORD',price=8000,name=tr('LINKING CORD','VERBINDUNGSSCHNUR'),
            help=route.heldItem and tr('Use while holding the required evolution item. Cord and held item are consumed.',
              'Mit dem benötigten Entwicklungsitem tragen lassen und anwenden. Schnur und Trageitem werden verbraucht.')
              or tr('Solo trade evolution. Keeps its size. Consumed once.',
                'Solo-Tauschentwicklung. Größe bleibt erhalten. Einmaliger Verbrauch.')}
          break
        end
      end
    end
    for _,row in ipairs(rows)do
      for _,route in ipairs(row.routes or {row})do
        local eligible=key==(route.key or 'dex:'..route.dex)
        if eligible and row.owner then
          local owner=mod.exports[row.owner];local item=mod.content.items:get(row.id)
          eligible=owner and owner.ready and item and item.price==row.price
            and item.effect==(row.effect or 'KA_WAVE1_KUBFU_SCROLL_'..row.id)
        end
        if eligible and (route.target or route.targetKey) then
          local target=species.byKey[route.targetKey or 'dex:'..route.target]
          eligible=target~=nil and (tonumber(mon.hp) or 0)>0
            and require('src.pokemon.Evolution').pendingFor(game,mon,
              {kind='item',item=row.id})==target
        end
        if eligible then
          out[#out+1]={id=row.id,price=row.price,name=tr(row.en,row.de),help=tr(route.helpEn,route.helpDe)}
        end
      end
    end
    return out
  end
  function C.canBuy(game,mon)return #C.offers(game,mon)>0 end
  local buying=setmetatable({},{__mode='k'})
  function C.buyOne(game,mon,item)
    local offer
    for _,row in ipairs(C.offers(game,mon))do if row.id==item then offer=row end end
    if not offer then return false,'not_offered' end
    if buying[game] then return false,'transaction_busy' end
    local equipment=mod.exports.pokemonEquipment67
    if not equipment then return false,'equipment_unavailable' end
    local ready,why=equipment.initialize(game)
    if not ready then return false,why end
    local save=game.save
    if type(save.money)~='number' or save.money~=math.floor(save.money) or save.money==math.huge
        or save.money<offer.price then return false,'not_enough_money' end
    if type(save.inventory)~='table' then return false,'save_unavailable' end
    local inventory,order,money=save.inventory,save.bagOrder,save.money
    local nextInventory={};for k,v in pairs(inventory)do nextInventory[k]=v end
    local nextOrder=order and {};for k,v in pairs(order or {})do nextOrder[k]=v end
    save.inventory=nextInventory;save.bagOrder=nextOrder
    if not require('src.inventory.Bag').add(save,item,1,game.data) then
      save.inventory=inventory;save.bagOrder=order;return false,'bag_full'
    end
    save.money=money-offer.price;buying[game]=true
    local ok,wrote=pcall(game.writeSave,game);buying[game]=nil
    if not ok or wrote~=true then
      save.inventory=inventory;save.bagOrder=order;save.money=money
      return false,'save_failed'
    end
    return true
  end
  function C.openShop(game,mon,onQuit)
    if not C.canBuy(game,mon) then return false end
    local factory=assert(mod.ui.KantoListMenu,'evolution items need fullscreen menu facade')
    local show
    show=function(message)
      local offers=C.offers(game,mon)
      if #offers==0 then if onQuit then onQuit()end;return end
      local choices={}
      for _,offer in ipairs(offers)do
        choices[#choices+1]={label=offer.name,value=offer.id,right=tostring(offer.price),
          help=message or offer.help,offer=offer}
      end
      choices[#choices+1]={label=tr('BACK','ZURÜCK'),value='back',help=tr('Back to Equipment.','Zurück zur Ausrüstung.')}
      local selected=false
      game.stack:push(factory.new(game,tr('EVOLUTION ITEMS','ENTWICKLUNGSITEMS'),choices,{
        footer=tr('A:SELECT  B:BACK','A:WAHL  B:ZURÜCK'),
        ascendantFocusHelp=function(row)return row.help end,onCancel=onQuit,
        onChoose=function(row,list)
          if selected then return end;selected=true;list:close()
          if row.value=='back' then if onQuit then onQuit()end;return end
          local answered=false
          local confirmation=factory.new(game,tr('BUY FOR ','KAUFEN FÜR ')..row.offer.price..'?',{
            {value=false,label=tr('NO','NEIN'),help=tr('Keep your money.','Dein Geld behalten.')},
            {value=true,label=tr('YES','JA'),help=row.offer.help},
          },{footer=tr('A:SELECT  B:BACK','A:WAHL  B:ZURÜCK'),
            ascendantFocusHelp=function(choice)return choice.help end,onCancel=function()show()end,
            onChoose=function(choice,confirm)
              if answered then return end;answered=true;confirm:close()
              if not choice.value then show();return end
              local bought,why=C.buyOne(game,mon,row.value)
              local messages={
                not_enough_money=tr('Not enough money. Nothing spent.','Nicht genug Geld. Nichts ausgegeben.'),
                bag_full=tr('Bag full. Nothing spent.','Beutel voll. Nichts ausgegeben.'),
                save_failed=tr('Save failed. Item and money restored.','Speichern fehlgeschlagen. Item und Geld zurückgesetzt.'),
              }
              show(bought and (tr('Received one. ','Eines erhalten. ')..row.offer.help)
                or messages[why] or tr('Purchase unavailable. Nothing spent.','Kauf nicht möglich. Nichts ausgegeben.'))
            end})
          -- Shared menus may restore a remembered YES cursor for the same
          -- price. Every new purchase must start on NO regardless of memory.
          confirmation.index=1;confirmation.scroll=0
          game.stack:push(confirmation)
        end}))
    end
    show();return true
  end
  return C
end
