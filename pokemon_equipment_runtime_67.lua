-- KASC-67-EQUIPMENT-VIEW. KASC owns commands and the native fallback;
-- VASC may consume the same immutable view without writing save tables.
return function(mod,opts)
  local rules=assert(opts.rules)
  local facts=assert(opts.facts)
  local evidence=assert(opts.evidence)
  local i18n=assert(opts.i18n)
  local function tr(en,de)return i18n.text(en,de)end
  local function copy(v)
    if type(v)~='table' then return v end
    local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r
  end
  local function sameStoredValue(a,b)
    if a==b then return true end
    if type(a)~='table' or type(b)~='table' then return false end
    for k,v in pairs(a)do if not sameStoredValue(v,b[k])then return false end end
    for k in pairs(b)do if a[k]==nil then return false end end
    return true
  end
  local reasons={
    no_item={'No held item.','Kein getragenes Item.'},
    no_ability={'No ability assigned.','Keine Fähigkeit zugeordnet.'},
    invalid_ability_binding={'Stored ability data is invalid. Nothing was changed.','Gespeicherte Fähigkeitsdaten sind ungültig. Nichts wurde verändert.'},
    egg_unrevealed={'An egg does not reveal its future ability.','Ein Ei verrät seine spätere Fähigkeit noch nicht.'},
    egg={'Eggs cannot be equipped.','Eier können keine Items erhalten.'},
    inactive_generation={'Preserved; its effect is dormant in this generation.','Bleibt erhalten; die Wirkung ruht in dieser Generation.'},
    effect_not_implemented={'This effect is not available yet.','Diese Wirkung ist noch nicht verfügbar.'},
    unknown_item={'This item is not supported. Nothing was removed.','Dieses Item wird nicht unterstützt. Nichts wurde entfernt.'},
    item_not_holdable={'This item cannot be held.','Dieses Item kann nicht getragen werden.'},
    item_not_owned={'The item is no longer in your bag.','Das Item ist nicht mehr im Beutel.'},
    bag_full={'There is no room for the returned item.','Für das zurückgegebene Item ist kein Platz.'},
    save_failed={'Saving failed. The item change was rolled back.','Speichern fehlgeschlagen. Die Itemänderung wurde zurückgenommen.'},
    stale_revision={'The Pokémon or rules changed. Please select again.','Pokémon oder Regeln haben sich geändert. Bitte erneut wählen.'},
    conflicting_item_aliases={'Conflicting held-item data. Nothing was changed.','Widersprüchliche Trageitemdaten. Nichts wurde verändert.'},
    invalid_item_encoding={'Unknown held-item format. Nothing was changed.','Unbekanntes Trageitemformat. Nichts wurde verändert.'},
    ambiguous_mon_handle={'The Pokémon identity is duplicated. No change was made.','Die Pokémon-ID ist doppelt vorhanden. Keine Änderung vorgenommen.'},
    mon_not_owned={'This Pokémon is no longer in your local storage.','Dieses Pokémon ist nicht mehr in deinem lokalen Bestand.'},
    transaction_active={'Finish the current battle or transfer first.','Beende zuerst den laufenden Kampf oder Transfer.'},
    transaction_busy={'An item transaction is already running.','Eine Itemtransaktion läuft bereits.'},
    link_active={'Close the link session first.','Beende zuerst die Verbindung.'},
    save_identity_missing={'The save identity is not available.','Die Spielstand-ID ist nicht verfügbar.'},
    equipment_not_initialized={'Open Equipment once to initialize its identities.','Öffne Ausrüstung einmal, um die IDs einzurichten.'},
    unsupported_equipment_schema={'Unsupported equipment save version.','Nicht unterstützte Ausrüstungsversion im Spielstand.'},
    request_id_conflict={'This request ID was already used for a different action.','Diese Anfrage-ID wurde bereits für eine andere Aktion verwendet.'},
    command_not_allowed={'This action is not available.','Diese Aktion ist nicht verfügbar.'},
    same_item={'This Pokémon already holds that item.','Dieses Pokémon trägt dieses Item bereits.'},
    invalid_request={'Invalid equipment request.','Ungültige Ausrüstungsanfrage.'},
    invalid_item={'Invalid item selection.','Ungültige Itemauswahl.'},
    invalid_mon_handle={'Invalid Pokémon identity.','Ungültige Pokémon-ID.'},
    save_unavailable={'No writable save is available.','Kein beschreibbarer Spielstand verfügbar.'},
    unsafe_save_checkpoint={'Wait for a safe save point.','Warte auf einen sicheren Speicherzeitpunkt.'},
  }
  local function localRows(game)
    local out={}
    for _,row in ipairs(evidence.ownedSurfaces(game.save,game))do
      local label=row.label or ''
      if not row.unhatched and (label:match('^party:') or label=='party'
          or label:match('^box%d+:') or label:match('^legacy_box:')
          or label:match('^daycare_plus_parent:') or label:match('^daycare:')
          or label=='daycare')then
        out[#out+1]={mon=row.mon,location=label}
      end
    end
    return out
  end
  local function epoch(game)
    -- Read the last committed/resolved rule state. Calling resolve() here
    -- would mutate evidence during a supposedly read-only UI snapshot.
    local bucket=game.save.modData and game.save.modData[mod.id]
    local state=bucket and bucket[rules.SAVE_KEY]
    return state and state.activeEpoch or 1
  end
  local function effectOwner()
    return opts.effects and opts.effects() or nil
  end
  local function item(id,gen,game)
    local native=game.data and game.data.items and game.data.items[id]
    if not native then return nil end
    local metadata=facts.item(id,gen) or facts.item(id,2)
    if not metadata then return nil end
    local holdable=metadata.effect~=nil -- pinned Gen2 held slot identities
    for _,flag in ipairs(metadata.flags or {})do
      if flag=='holdable' or flag=='holdable-passive' or flag=='holdable-active' then holdable=true end
    end
    local effects=effectOwner()
    local names=copy(metadata.names or native.names or {en=native.name or id,de=native.name or id})
    return {id=id,names=names,generation=metadata.generation,holdable=holdable,
      icon=native.icon or false,effectSupported=effects and effects.supportsItem
        and effects.supportsItem(game,id,gen)==true or false}
  end
  local function canWrite(game)
    if not (game and game.save and type(game.writeSave)=='function') then return false,'save_unavailable' end
    return rules.safeBoundary(game)
  end
  local core=opts.makeCore({modId=mod.id,owned=localRows,item=item,generation=epoch,
    canWrite=canWrite,canEdit=function(game)return rules.safeBoundary(game)end,
    digest=opts.digest,bag=require('src.inventory.Bag'),
    writeSave=function(game)return game:writeSave()end,
    prepareMon=opts.abilities and opts.abilities.plan,
    ability=function(game,mon,gen)
      if opts.abilities then return opts.abilities.view(game,mon,gen)end
      local effects=effectOwner()
      return effects and effects.abilityView and effects.abilityView(game,mon,gen)
        or {id=false,active=false,reasonCode='no_ability'}
    end})
  local U={schema=core.schema,version=1,owner=core.OWNER,CARD_ID='KASC-67-EQUIPMENT-VIEW',
    snapshot=core.snapshot,command=core.command,subscribe=core.subscribe,
    heldId=core.held}
  function U.reason(code)
    local value=reasons[code] or {tostring(code),tostring(code)}
    return {code=code,en=value[1],de=value[2]}
  end
  local function reasonText(code)
    local r=U.reason(code);return tr(r.en,r.de)
  end
  local function name(value)
    if not value or value.id==false then return tr('NONE','KEINE')end
    local names=value.names or {};return tr(names.en or value.id,names.de or value.id)
  end
  function U.capabilities()
    local bank=mod.exports and mod.exports.legacyBankBridge
    return {schema=U.schema,version=1,readOnlySnapshots=true,revisionBoundCommands=true,
      nativeFallback=true,heldItemTransactions=true,effectProvider=effectOwner()~=nil,
      bankSplit=bank~=nil and bank.EQUIPMENT_SPLIT_SCHEMA=='kasc.bank-held-split/v1'
        and type(bank.migrateHeldEquipment)=='function' or false}
  end
  function U.initialize(game,forceCommit)
    local ready,reason=canWrite(game);if not ready then return nil,reason end
    local meta=game.save.meta
    if not (meta and (meta.playthroughId or meta.saveIdentity) or game.save.playthroughId) then
      if not (mod.storage and mod.storage.context) then return nil,'save_identity_missing' end
      local ok,context=pcall(mod.storage.context,mod.storage,game)
      if not ok or type(context)~='table' then return nil,'save_identity_missing' end
    end
    return core.bind(game,forceCommit)
  end
  -- Acquisition is observed only on real local ownership surfaces. A caught
  -- event can also fire when all boxes are full, and is not ownership proof.
  -- Checkpoints are outside battle/link/transfer transactions; snapshots never
  -- call this path. The save-object key deliberately invalidates on reload.
  local checkpoints=setmetatable({},{__mode='k'})
  local activeGame
  local function ownershipStamp(game)
    local parts={tostring(epoch(game))}
    for _,row in ipairs(localRows(game))do
      local mon=row.mon;local binding=mon._kascAbility67
      parts[#parts+1]=table.concat({tostring(mon),tostring(mon.species),
        tostring(mon.isEgg),tostring(mon.eggSpecies),tostring(mon._kascEquipmentHandle),
        tostring(binding and binding.slot)},':')
    end
    return table.concat(parts,'|')
  end
  function U.checkpoint(game)
    local ready,reason=canWrite(game);if not ready then return nil,reason end
    if #localRows(game)==0 then return true end -- title/demo scaffolding
    local stamp=ownershipStamp(game)
    if checkpoints[game.save]==stamp then return true end
    local previous=copy(game.save.modData)
    if rules.resolve then rules.resolve(game)end
    -- A reload or party reorder invalidates the in-memory stamp, but does
    -- not by itself require another durable save. Core.bind still commits
    -- new identities/abilities; force a commit only for resolved rule changes.
    local rulesChanged=not sameStoredValue(previous,game.save.modData)
    local ok,why=U.initialize(game,rulesChanged)
    if not ok then
      game.save.modData=previous
      if type(game.adoptSave)=='function' then game:adoptSave(game.save) end
      return nil,why
    end
    if rulesChanged and rules.syncData then rules.syncData(game)end
    checkpoints[game.save]=ownershipStamp(game)
    return true
  end
  if mod.events and mod.events.on then
    mod.events:on('game.ready',function(ev)activeGame=ev and ev.game or activeGame end,-9300)
    mod.events:on('save.loaded',function(ev)
      activeGame=ev and ev.game or activeGame
      if activeGame and activeGame.save then checkpoints[activeGame.save]=nil end
    end,-9300)
    mod.events:on('world.stepped',function(ev)
      local game=ev and ev.game or activeGame
      if game then U.checkpoint(game)end
    end,-9950)
  end
  function U.snapshotForMon(game,mon)
    if type(mon)~='table' or not mon._kascEquipmentHandle then return nil,'equipment_not_initialized' end
    return core.snapshot(game,mon._kascEquipmentHandle)
  end
  function U.inventory(game,handle)
    local view,reason=core.snapshot(game,handle);if not view then return nil,reason end
    local out={}
    for id,quantity in pairs(game.save.inventory or {})do
      local value=item(id,view.generation,game)
      if value and value.holdable and quantity>0 and id~=view.item.id then
        out[#out+1]={id=id,names=copy(value.names),quantity=quantity}
      end
    end
    table.sort(out,function(a,b)return a.id<b.id end)
    return {revision=view.revision,items=out}
  end
  local function menu(game,title,rows,onChoose)
    local list=(mod.ui.KantoListMenu or mod.ui.ListMenu).new(game,title,rows,
      {pageJump=true,onChoose=onChoose})
    game.stack:push(list);return list
  end
  local function notice(game,code)
    return menu(game,tr('EQUIPMENT','AUSRÜSTUNG'),{{label=tr('BACK','ZURÜCK'),
      value='back',help=reasonText(code)}},function(_,list)list:close()end)
  end
  local requestSerial=0
  local function submit(game,view,action,itemId)
    requestSerial=requestSerial+1
    return core.command(game,{requestId='native-'..opts.digest(view.handle..':'..view.revision
      ..':'..action..':'..tostring(itemId)..':'..requestSerial),handle=view.handle,
      expectedRevision=view.revision,action=action,itemId=itemId})
  end
  function U.openNative(game,monOrHandle)
    local ready,reason=U.initialize(game)
    if not ready then notice(game,reason);return nil,reason end
    local handle=type(monOrHandle)=='table' and monOrHandle._kascEquipmentHandle or monOrHandle
    local view,why=core.snapshot(game,handle)
    if not view then notice(game,why);return nil,why end
    local rows={{label=tr('ITEM: ','ITEM: ')..name(view.item),value='item',
      help=view.item.reasonCode and reasonText(view.item.reasonCode) or tr('The held effect is active.','Die Tragewirkung ist aktiv.')},
      {label=tr('ABILITY: ','FÄHIGKEIT: ')..name(view.ability),value='ability',
       help=view.ability.reasonCode and reasonText(view.ability.reasonCode) or ''}}
    if view.commands.give then rows[#rows+1]={label=tr('GIVE ITEM','ITEM GEBEN'),value='give'}end
    if view.commands.take then rows[#rows+1]={label=tr('TAKE ITEM','ITEM NEHMEN'),value='take'}end
    if view.commands.swap then rows[#rows+1]={label=tr('SWAP ITEM','ITEM TAUSCHEN'),value='swap'}end
    rows[#rows+1]={label=tr('BACK','ZURÜCK'),value='back'}
    return menu(game,tr('EQUIPMENT','AUSRÜSTUNG'),rows,function(selected,list)
      local action=selected.value
      if action=='back' then list:close();return end
      if action=='item' or action=='ability' then return end -- help stays in this menu
      local function finish(itemId,picker)
        local result,errorCode=submit(game,view,action,itemId)
        if picker then picker:close()end
        list:close()
        if not result then notice(game,errorCode);return end
        U.openNative(game,handle)
      end
      if action=='take' then finish();return end
      local inventory,errorCode=U.inventory(game,handle)
      if not inventory then notice(game,errorCode);return end
      local choices={}
      for _,value in ipairs(inventory.items)do
        choices[#choices+1]={label=name(value),right=tostring(value.quantity),value=value.id}
      end
      choices[#choices+1]={label=tr('CANCEL','ABBRECHEN'),value=false}
      menu(game,tr('CHOOSE ITEM','ITEM WÄHLEN'),choices,function(chosen,picker)
        if chosen.value==false then picker:close();return end
        finish(chosen.value,picker)
      end)
    end)
  end
  mod.hooks:wrap('ui.party.submenu',function(nextItems,game,items,mon,ctx)
    local out=nextItems(game,items,mon,ctx)
    if type(out)~='table' or type(mon)~='table' then return out end
    local result={};for _,row in ipairs(out)do result[#result+1]=row end
    for _,row in ipairs(result)do if row.id=='kasc_equipment_67' then return result end end
    result[#result+1]={id='kasc_equipment_67',label=tr('EQUIPMENT','AUSRÜSTUNG'),
      onSelect=function()U.openNative(game,mon)end}
    return result
  end,270)
  if opts.supportLog and opts.supportLog.registerSegment then
    opts.supportLog.registerSegment({segmentId=U.CARD_ID,cardId=U.CARD_ID,version='1.0.0',
      schema='kasc.optional-feature-card/v1',owner='kasc.pokemon-equipment-view/v1',
      active=true,dependencyStatus='local-transactions',providerStatus='native-view-loaded',
      buildReceiptId='docs/KASC_67_HELD_ITEMS_ABILITIES_HATCHING.md',
      rollbackReceiptId='remove-equipment-view-wiring-preserve-save-fields'})
  end
  return U
end
